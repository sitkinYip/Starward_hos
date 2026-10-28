#!/usr/bin/env python3
"""Serve an explicit public visual-report allowlist on IPv4 loopback only."""
import argparse
import errno
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import stat
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / 'artifacts'
WEB_GROUPS = frozenset({
    'web-baseline', 'web-baseline-font-controlled', 'web-content-login-reference',
    'web-isolated-content', 'web-isolated-forced', 'web-isolated-waiting',
    'web-isolated-expired', 'web-isolated-locked', 'web-isolated-error',
    'web-legacy-pre-system-content', 'web-legacy-pre-system-forced',
    'web-pre-edge-to-edge-content', 'web-pre-edge-to-edge-forced',
})
NATIVE_GROUPS = frozenset({
    'native-before-visual', 'native-atlas-background-observed',
    'native-login-offset-verified', 'native-https-visual',
    'native-legacy-pre-system', 'native-system-visual', 'native-pre-edge-to-edge',
})
VALIDATION_FILES = frozenset({
    'native-tls-and-metrics.json', 'login-visual-comparison.json', 'web-atlas-layout.json',
    'forced-visual-comparison.json',
    'visual-report-server-summary.json',
})
WEB_STATE_FILE = re.compile(r'(?:login|forced-password|home|detail|history|logout|error)-(?:dark|light)\.(?:png|json)\Z')
PNG_FILE = re.compile(r'[a-z0-9][a-z0-9-]*\.png\Z')
SAFE_METADATA = frozenset({'capture-summary.json', 'provenance.json'})


def permitted_parts(raw_path):
    try:
        url = urlsplit(raw_path)
        if url.scheme or url.netloc:
            return None
        path = unquote(url.path, encoding='utf-8', errors='strict')
    except (UnicodeError, ValueError):
        return None
    # Decode exactly once, then reject ambiguous encoded paths and separators.
    if '%' in path or '\\' in path or '\x00' in path or not path.startswith('/'):
        return None
    parts = path[1:].split('/')
    if len(parts) != 2 or any(part in ('', '.', '..') for part in parts):
        return None
    group, filename = parts
    if group == 'visual-comparison':
        return parts if filename in ('index.html','pairs.json','criteria.json','legacy-index.html','legacy-pairs.json') else None
    if group in WEB_GROUPS:
        return parts if WEB_STATE_FILE.fullmatch(filename) or filename in SAFE_METADATA else None
    if group in NATIVE_GROUPS:
        # Raw UiTest trees may contain entered field values. Only public PNGs
        # and explicitly authored provenance are served from native groups.
        return parts if PNG_FILE.fullmatch(filename) or filename == 'provenance.json' else None
    if group == 'validation':
        return parts if filename in VALIDATION_FILES else None
    return None


class ReportServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, port):
        flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
        self.artifacts_fd = os.open(ARTIFACTS, flags)
        try:
            super().__init__(('127.0.0.1', port), ReportHandler)
        except BaseException:
            if self.artifacts_fd is not None:
                os.close(self.artifacts_fd)
                self.artifacts_fd = None
            raise

    def server_close(self):
        super().server_close()
        if self.artifacts_fd is not None:
            os.close(self.artifacts_fd)
            self.artifacts_fd = None


class ReportHandler(BaseHTTPRequestHandler):
    server_version = 'StarwardVisualReport'
    sys_version = ''

    def log_message(self, format, *args):
        # Do not echo paths, query strings, client addresses or field contents.
        pass

    def public_headers(self, status_code, content_type, length):
        self.send_response(status_code)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(length))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Cross-Origin-Resource-Policy', 'same-origin')
        self.send_header('Content-Security-Policy', "default-src 'none'; img-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'none'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
        self.end_headers()

    def missing(self):
        body = b'Not found\n'
        self.public_headers(404, 'text/plain; charset=utf-8', len(body))
        if self.command != 'HEAD':
            self.wfile.write(body)

    def serve(self):
        port = self.server.server_address[1]
        if self.headers.get('Host') not in (f'127.0.0.1:{port}', f'localhost:{port}'):
            self.missing()
            return
        parts = permitted_parts(self.path)
        if parts is None:
            self.missing()
            return
        group, filename = parts
        directory_fd = file_fd = None
        headers_sent = False
        try:
            # openat + O_NOFOLLOW guards both directory and final file, including
            # a link swapped between path checking and open; no directory scan.
            directory_fd = os.open(group, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                                   dir_fd=self.server.artifacts_fd)
            file_fd = os.open(filename, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory_fd)
            information = os.fstat(file_fd)
            if not stat.S_ISREG(information.st_mode):
                self.missing()
                return
            content_type = 'image/png' if filename.endswith('.png') else 'application/json; charset=utf-8' if filename.endswith('.json') else 'text/html; charset=utf-8'
            self.public_headers(200, content_type, information.st_size)
            headers_sent = True
            if self.command != 'HEAD':
                with os.fdopen(file_fd, 'rb', closefd=False) as source:
                    shutil.copyfileobj(source, self.wfile)
        except OSError as error:
            if not headers_sent and error.errno in (errno.ENOENT, errno.ENOTDIR, errno.ELOOP, errno.EACCES):
                self.missing()
            elif not headers_sent and error.errno not in (errno.EPIPE, errno.ECONNRESET):
                self.missing()
        finally:
            if file_fd is not None:
                os.close(file_fd)
            if directory_fd is not None:
                os.close(directory_fd)

    do_GET = serve
    do_HEAD = serve


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=5179, help='Loopback port (0 selects a temporary port; default 5179)')
    args = parser.parse_args()
    if not 0 <= args.port <= 65535:
        parser.error('--port must be from 0 through 65535')
    server = ReportServer(args.port)
    print(json.dumps({'url':f'http://127.0.0.1:{server.server_address[1]}/visual-comparison/index.html', 'bind':'127.0.0.1', 'privateFilesServed':False}), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

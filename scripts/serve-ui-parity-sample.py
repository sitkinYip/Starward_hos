#!/usr/bin/env python3
"""Prepare/serve only the first UI sample's verified local original screenshots.

No default IO. The viewer is a private, self-contained HTML file; the optional
loopback server exposes that document only, never an artifacts directory.
"""
import argparse
import base64
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import html
import json
import os
from pathlib import Path
import stat
import struct

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'artifacts/private'
PUBLIC = ROOT / 'artifacts/validation'


def require(value):
    if not value:
        raise ValueError('The explicit sample evidence boundary did not hold')


def read(value, base, private=False):
    path = (ROOT / value).absolute() if not value.is_absolute() else value.absolute()
    require(path == path.resolve() and path.is_relative_to(base) and path != base)
    for item in (path, *path.parents):
        require(not item.is_symlink())
        if item == ROOT:
            break
    info = path.stat()
    require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid() and 0 < info.st_size < 20 * 1024 * 1024)
    if private:
        require(stat.S_IMODE(info.st_mode) == 0o600)
    return path.read_bytes()


def sha(value):
    return hashlib.sha256(value).hexdigest()


def prepare(args):
    native_bytes, web_bytes = read(args.native_report, PUBLIC), read(args.web_report, PUBLIC)
    native, web = json.loads(native_bytes), json.loads(web_bytes)
    require(native['status'] == 'captured_native_sample' and web['status'] == 'captured_render_reference')
    require(native['privateFixture']['sha256'] == web['fixtureSha256'] and
            web['viewport']['width'] == 376 and web['viewport']['height'] == 742)
    native_shots = {Path(row['file']).stem: row for row in native['privateScreenshots']}
    web_shots = {(row['state'], row['theme']): row['screenshot'] for row in web['states']}
    sections = []
    for theme in ('light', 'dark'):
        for state, label in (('sidebar-home', '侧栏头部与高度'), ('session-header', 'RANK 留白')):
            images = []
            for origin, row, expected in (
                ('Web 正式版 · 本地同数据重放', web_shots[(state, theme)], (376, 742)),
                ('ArkUI · 真机原图（含系统栏）', native_shots[state + '-' + theme], (1316, 2832))):
                raw = read(Path(row['file']), PRIVATE, True)
                require(sha(raw) == row['sha256'] and raw[:8] == b'\x89PNG\r\n\x1a\n' and
                        struct.unpack('>II', raw[16:24]) == expected)
                images.append('<figure><figcaption>' + html.escape(origin) + '</figcaption><img alt="' +
                    html.escape(label + ' ' + theme + ' ' + origin) + '" src="data:image/png;base64,' +
                    base64.b64encode(raw).decode() + '"></figure>')
            sections.append('<section id="' + state + '-' + theme + '"><h2>' +
                ('日间' if theme == 'light' else '夜间') + ' · ' + label + '</h2><div class="pair">' +
                ''.join(images) + '</div></section>')
    markup = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>首组 UI 样板对照</title>
<style>body{margin:0;background:#ebece9;color:#213832;font:15px/1.6 system-ui,sans-serif}
main{max-width:820px;margin:auto;padding:28px 20px 60px}h1{font-size:24px;margin:0 0 12px}h2{font-size:19px}
p{max-width:760px}nav{display:flex;gap:18px;flex-wrap:wrap}a{color:#166b5c}section{margin-top:36px;scroll-margin-top:20px}
.pair{display:grid;grid-template-columns:repeat(2,376px);gap:24px;align-items:start;overflow-x:auto}
figure{margin:0;width:376px}figcaption{margin-bottom:10px;font-size:13px}img{display:block;width:376px;height:auto}
code{font:12px ui-monospace,monospace;word-break:break-all}</style><main>
<h1>首组 UI 样板 · 同数据对照</h1>
<p>本次确认：侧栏单行小头部、关闭按钮、默认高度与 RANK 底距。侧栏中段沿用已认可的现有样式，玩法内容还原另做后续切片。</p>
<p>两侧内容宽均为 376（Web CSS px / 原生 vp），正常字号。同一隔离玩家、场次及进度；原生包含系统状态栏和手势区，Web 为 742px 内容视口。原图仅等比例显示，未裁切或修图。官方玻璃材质、系统栏及容器边界属于已批准差异。</p>
<nav><a href="#sidebar-home-light">日间侧栏</a><a href="#session-header-light">日间 RANK</a>
<a href="#sidebar-home-dark">夜间侧栏</a><a href="#session-header-dark">夜间 RANK</a></nav>'''
    markup += ''.join(sections) + '<p>HAP <code>' + html.escape(native['hapSha256']) + '</code></p></main></html>'
    output = (ROOT / args.output).absolute() if not args.output.is_absolute() else args.output.absolute()
    require(output == output.resolve() and output.is_relative_to(PRIVATE) and output.suffix == '.html')
    for item in (output, *output.parents):
        require(not item.is_symlink())
        if item == ROOT:
            break
    require(output.parent.is_dir() and stat.S_IMODE(output.parent.stat().st_mode) == 0o700)
    with os.fdopen(os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600), 'w') as target:
        target.write(markup)
    print(json.dumps({'status': 'prepared_original_comparison', 'pairs': 4, 'htmlSha256': sha(markup.encode()),
                     'nativeReportSha256': sha(native_bytes), 'webReportSha256': sha(web_bytes)}))


def serve(args):
    require(1024 <= args.port <= 65535)
    markup = read(args.html, PRIVATE, True)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            if self.path not in ('/', '/index.html'):
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(markup)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Content-Security-Policy', "default-src 'none'; img-src data:; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'")
            self.end_headers()
            self.wfile.write(markup)

    with ThreadingHTTPServer(('127.0.0.1', args.port), Handler) as server:
        print(json.dumps({'status': 'serving_only_sample_html', 'port': args.port}), flush=True)
        server.serve_forever()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action')
    p = sub.add_parser('prepare')
    p.add_argument('--native-report', type=Path, required=True)
    p.add_argument('--web-report', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p = sub.add_parser('serve')
    p.add_argument('--html', type=Path, required=True)
    p.add_argument('--port', type=int, default=5181)
    args = parser.parse_args()
    if args.action is None:
        parser.print_help()
        return 0
    try:
        prepare(args) if args.action == 'prepare' else serve(args)
        return 0
    except (ValueError, OSError, KeyError):
        print(json.dumps({'status': 'incomplete_sample_viewer_boundary'}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

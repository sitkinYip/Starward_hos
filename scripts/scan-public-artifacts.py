#!/usr/bin/env python3
"""Scan Git-visible files without printing credentials or reading device tools."""

import argparse
import base64
import datetime
import errno
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = Path('artifacts/validation/public-artifact-scan.json')
PRIVATE_STATES = (
    Path('artifacts/private/https-isolation/state.json'),
    Path('artifacts/private/https-isolation/pre-edge-environment-state.json'),
    Path('artifacts/private/https-isolation/final-environment-state.json'),
)
CATEGORIES = (
    'known_account', 'known_auth_token', 'known_control_token',
    'known_device_identifier', 'known_password',
)
SIGNING_EXTENSIONS = {
    '.p12', '.pfx', '.jks', '.keystore', '.p7b', '.p7c', '.csr',
    '.cer', '.cert', '.der', '.mobileprovision', '.provisionprofile', '.key',
}
JWT = re.compile(
    rb'(?<![A-Za-z0-9_-])([A-Za-z0-9_-]{8,})\.([A-Za-z0-9_-]{8,})'
    rb'\.([A-Za-z0-9_-]{8,})(?![A-Za-z0-9_-])'
)
PEM_PRIVATE = re.compile(rb'-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----')


def git(*args, input_data=None, allowed=(0,)):
    result = subprocess.run(
        ['git', '-C', str(ROOT), *args], input=input_data,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if result.returncode not in allowed:
        raise RuntimeError('git_query_failed')
    return result.stdout


def ignored_paths(paths):
    if not paths:
        return set()
    return set(git('check-ignore', '--no-index', '-z', '--stdin',
                   input_data=b'\0'.join(paths) + b'\0', allowed=(0, 1)).split(b'\0'))


def read_regular(relative):
    """Use no-follow directory handles so a candidate cannot escape via symlinks."""
    parts = relative.parts
    if relative.is_absolute() or not parts or any(p in ('', '.', '..') for p in parts):
        raise ValueError('invalid_relative_path')
    directory = os.open(ROOT, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in parts[:-1]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                            dir_fd=directory)
            os.close(directory)
            directory = child
        if not stat.S_ISREG(os.stat(parts[-1], dir_fd=directory, follow_symlinks=False).st_mode):
            return None
        descriptor = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                             dir_fd=directory)
        try:
            if not stat.S_ISREG(os.fstat(descriptor).st_mode):
                return None
            with os.fdopen(descriptor, 'rb', closefd=False) as source:
                return source.read()
        finally:
            os.close(descriptor)
    except OSError as error:
        if error.errno in (errno.ELOOP, errno.ENOTDIR):
            return None
        raise
    finally:
        os.close(directory)


def credential_category(key):
    normalized = re.sub(r'[^a-z0-9]', '', key.lower())
    if any(word in normalized for word in ('password', 'passwd', 'passphrase')):
        return 'known_password'
    if 'control' in normalized and 'token' in normalized:
        return 'known_control_token'
    if 'token' in normalized:
        return 'known_auth_token'
    if normalized in ('account', 'accounts', 'username', 'loginaccount', 'identity', 'email'):
        return 'known_account'
    if normalized in ('deviceid', 'deviceids', 'deviceidentifier', 'deviceserial',
                      'serialnumber', 'udid', 'udids'):
        return 'known_device_identifier'
    return None


def collect_known(value, known, key=''):
    if isinstance(value, dict):
        for child_key, child_value in value.items():
            collect_known(child_value, known, child_key)
    elif isinstance(value, list):
        for item in value:
            collect_known(item, known, key)
    elif isinstance(value, str) and value:
        category = credential_category(key)
        if category:
            known[category].add(value.encode('utf-8'))


def decoded_json(segment):
    if len(segment) > 1024 * 1024:
        return None
    try:
        decoded = base64.b64decode(segment + b'=' * (-len(segment) % 4),
                                   altchars=b'-_', validate=True)
        return json.loads(decoded)
    except (ValueError, UnicodeError):
        return None


def jwt_count(contents):
    count = 0
    for match in JWT.finditer(contents):
        header, payload = decoded_json(match[1]), decoded_json(match[2])
        if (isinstance(header, dict) and isinstance(header.get('alg'), str)
                and bool(header['alg']) and isinstance(payload, dict)):
            count += 1
    return count


def repository_status_counts():
    rows = []
    for name in ('questions-web', 'sitkin-pb-backend-management'):
        result = subprocess.run(
            ['git', '-C', str(ROOT.parent / name), 'status', '--porcelain=v1', '-z'],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
        if result.returncode:
            raise RuntimeError('source_repository_status_failed')
        entries, count, index = result.stdout.split(b'\0'), 0, 0
        while index < len(entries) and entries[index]:
            status_code = entries[index][:2]
            count += 1
            index += 2 if b'R' in status_code or b'C' in status_code else 1
        rows.append({'repository': name, 'change_entry_count': count})
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--known-device-stdin', action='store_true',
                        help='Read a JSON array of device identifiers from stdin, only into memory.')
    args = parser.parse_args()
    known = {category: set() for category in CATEGORIES}
    errors, findings, references = [], [], []
    for private_path in PRIVATE_STATES:
        try:
            encoded = os.fsencode(private_path)
            if encoded not in ignored_paths([encoded]):
                raise ValueError('private_state_not_ignored')
            contents = read_regular(private_path)
            if contents is None:
                raise ValueError('private_state_not_regular')
            collect_known(json.loads(contents), known)
        except FileNotFoundError:
            continue
        except (OSError, ValueError, UnicodeError, RuntimeError):
            errors.append({'file': private_path.as_posix(), 'category': 'private_state_read_error'})
    if args.known_device_stdin:
        try:
            identifiers = json.load(sys.stdin)
            if not isinstance(identifiers, list) or any(
                    not isinstance(value, str) or not value for value in identifiers):
                raise ValueError('invalid_device_input')
            known['known_device_identifier'].update(value.encode('utf-8') for value in identifiers)
        except (OSError, ValueError, UnicodeError):
            errors.append({'category': 'device_stdin_read_error'})

    candidates = sorted(set(filter(None, git('ls-files', '--cached', '--others',
                                            '--exclude-standard', '-z').split(b'\0'))))
    excluded = ignored_paths(candidates)
    scanned, skipped = 0, 0
    for encoded in candidates:
        if encoded in excluded:
            continue
        relative = Path(os.fsdecode(encoded))
        # Defense in depth even if an ignore rule is removed accidentally.
        if relative == Path('artifacts/private') or Path('artifacts/private') in relative.parents:
            continue
        name = relative.as_posix()
        try:
            contents = read_regular(relative)
            if contents is None:
                skipped += 1
                continue
        except (OSError, ValueError):
            errors.append({'file': name, 'category': 'public_file_read_error'})
            continue
        scanned += 1
        counts = {category: sum(contents.count(value) for value in values)
                  for category, values in known.items()}
        counts['jwt_shape'] = jwt_count(contents)
        counts['pem_private_key_header'] = len(PEM_PRIVATE.findall(contents))
        counts['signing_material_extension'] = int(relative.suffix.lower() in SIGNING_EXTENSIONS)
        findings.extend({'file': name, 'category': category, 'count': count}
                        for category, count in counts.items() if count)
        if name in ('entry/src/main/ets/platform/AppEnvironment.ets', 'scripts/configure-integration.py'):
            count = contents.count(b'PRIVATE KEY')
            if count:
                references.append({'file': name, 'category': 'private_key_rejection_check_reference',
                                   'count': count})

    report = {
        'status': 'failed' if errors or findings else 'passed',
        'scanned_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'scope': 'Git-visible regular files; known private-state literals, optional in-memory device identifiers, decoded JWT shapes, private PEM headers and signing file extensions',
        'public_candidate_file_count': scanned,
        'skipped_nonregular_file_count': skipped,
        'read_error_count': len(errors), 'read_errors': errors,
        'private_state_field_counts': [{'category': category, 'count': len(known[category])}
                                       for category in CATEGORIES],
        'sensitive_finding_count': sum(row['count'] for row in findings),
        'sensitive_findings': findings,
        'private_key_rejection_check_references': references,
        'source_repository_status_counts': repository_status_counts(),
    }
    destination = ROOT / OUTPUT
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(report, ensure_ascii=True, indent=2) + '\n', encoding='utf-8')
    temporary.replace(destination)
    print(json.dumps({'status': report['status'], 'public_files': scanned,
                      'sensitive_findings': report['sensitive_finding_count'],
                      'read_errors': len(errors)}))
    return 1 if errors or findings else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError):
        # No exception text: OS/JSON diagnostics can contain sensitive input.
        print('Public artifact scan could not complete; no sensitive values were printed.', file=sys.stderr)
        sys.exit(1)

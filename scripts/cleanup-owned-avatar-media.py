#!/usr/bin/env python3
"""Prepare or execute exact, SHA-guarded cleanup of the five owned avatar fixtures.

prepare is offline: it binds the original private import receipts and local
fixture bytes into a new mode0600 plan. It neither reads nor changes a device.
cleanup requires that plan, its unchanged original receipts/source bytes, and
exactly one connected target. Each original URI is re-exported and SHA-verified
before its exact mediatool delete. Each recorded temporary export is separately
read back and SHA-verified before its exact rm. No all, wildcard, folder delete,
media traversal, import, fixture rename or original-receipt mutation exists.

Root must finish every phone scope that needs these fixtures before cleanup.
The helper never logs in, changes application data, or stops any service.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import shlex
import stat
import subprocess
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'artifacts/private'
BASE = PRIVATE / 'owned-avatar-cleanup'
PUBLIC = ROOT / 'artifacts/validation/profile/owned-avatar-media-cleanup.json'
KINDS = ('main-png', 'oversize-png', 'unsupported-gif', 'jpeg-exif6', 'webp-rgb')


class SafeFailure(RuntimeError):
    pass


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def file_in(value, directory, private=True):
    original = Path(value).absolute()
    path = original.resolve()
    if not path.is_relative_to(directory.resolve()):
        raise SafeFailure('An owned cleanup input is outside its allowed project directory')
    for item in (original, *original.parents):
        if item.is_symlink():
            raise SafeFailure('Owned cleanup inputs cannot contain symlinks')
        if item == directory.absolute():
            break
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or private and (info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077):
        raise SafeFailure('Private cleanup inputs must be owned regular mode0600 files')
    return path


def save(path, value):
    if path.is_symlink() or not path.resolve().is_relative_to(PRIVATE.resolve()):
        raise SafeFailure('Cleanup identity and command records must remain private')
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.parent.chmod(0o700)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'w') as target:
        json.dump(value, target, ensure_ascii=False, indent=2)
        target.write('\n')
    path.chmod(0o600)


def read(path):
    return json.loads(file_in(path, PRIVATE).read_text())


def relative(path):
    return str(Path(path).relative_to(ROOT))


def uri_valid(uri, name):
    parsed = urlparse(uri)
    parts = PurePosixPath(parsed.path).parts
    return (parsed.scheme == 'file' and parsed.netloc == 'media' and not parsed.query and not parsed.fragment and
            len(parts) >= 4 and parts[1] == 'Photo' and parts[2].isdigit() and int(parts[2]) > 0 and parts[-1] == name)


def validate_identity(item):
    kind, name = item['kind'], item['displayName']
    extension = {'main-png': 'png', 'oversize-png': 'png', 'unsupported-gif': 'gif',
                 'jpeg-exif6': 'jpg', 'webp-rgb': 'webp'}[kind]
    prefix = 'starward-avatar-' if kind == 'main-png' else 'starward-filter-' if kind in KINDS[1:3] else 'starward-source-'
    # These are the actual two importers' distinct original name formats.
    random_name = r'[a-f0-9]{32}' if kind in KINDS[3:] else r'[a-f0-9]{16}'
    if (not re.fullmatch(prefix + random_name + r'\.' + extension, name) or
            not re.fullmatch(r'[a-f0-9]{64}', item['fixtureSha256']) or
            not uri_valid(item['mediaUri'], name) or not isinstance(item['bytes'], int) or item['bytes'] <= 0 or
            not re.fullmatch(r'/mnt/data/[0-9]+/media_fuse/Photo/[^/]+/' + re.escape(name), item['devicePath'])):
        raise SafeFailure('A recorded exact owned fixture identity is invalid')
    for temporary in item['temporaryExports']:
        value = temporary['path']
        pattern = (r'/data/local/tmp/starward-source-export-[a-f0-9]{32}\.' + extension
                   if kind in KINDS[3:] else r'/data/local/tmp/' + prefix + r'[a-f0-9]{16}\.' + extension)
        if not re.fullmatch(pattern, value) or temporary['expectedSha256'] != item['fixtureSha256']:
            raise SafeFailure('An original exact temporary-export identity is invalid')


def prepare(args):
    main_path = file_in(args.main_receipt, PRIVATE)
    filter_path = file_in(args.filter_receipt, PRIVATE)
    main, filters = read(main_path), read(filter_path)
    filter_manifest_path = file_in(args.filter_manifest, PRIVATE)
    filter_manifest = read(filter_manifest_path)
    source_manifest_path = file_in(args.source_manifest, PRIVATE)
    source_manifest = read(source_manifest_path)
    if (main.get('shaVerified') is not True or main.get('fixtureSha256') != main.get('readbackSha256') or
            not isinstance(filters, list) or len(filters) != 2 or len(args.source_receipt) != 2):
        raise SafeFailure('Exactly the completed main, two negative and two source import receipts are required')
    entries = []

    def entry(kind, receipt_path, record, source):
        source = file_in(source, ROOT / 'artifacts/validation' if kind == 'main-png' else PRIVATE, kind != 'main-png')
        digest, size = sha(source), source.stat().st_size
        if record.get('readbackSha256') != digest or record.get('fixtureSha256', record.get('sourceSha256')) != digest:
            raise SafeFailure('Original fixture and verified readback SHA do not agree')
        if kind != 'main-png' and (record.get('importSent') is not True or record.get('sourceBytes') != size or record.get('readbackBytes') != size):
            raise SafeFailure('A negative/source receipt has no completed exact-byte import/readback')
        exports = {record.get('temporaryExport')}
        for temporary in record.get('ownedTemporaryExports', []):
            if temporary.get('removed'):
                raise SafeFailure('Original source receipt records an already removed export; preserve its separate cleanup')
            if temporary.get('shaVerified') is not True or temporary.get('sha256') != digest:
                raise SafeFailure('An original temporary export is not SHA-verified')
            exports.add(temporary.get('path'))
        if None in exports or not exports:
            raise SafeFailure('A completed original exact temporary export receipt is required')
        value = {'kind': kind, 'originReceipt': relative(receipt_path), 'originReceiptSha256': sha(receipt_path),
                 'source': relative(source), 'fixtureSha256': digest, 'bytes': size,
                 'displayName': record['displayName'], 'devicePath': record['devicePath'], 'mediaUri': record['mediaUri'],
                 'temporaryExports': [{'path': path, 'expectedSha256': digest, 'removed': False} for path in sorted(exports)],
                 'mediaDeleted': False, 'queryAfterCount': None}
        validate_identity(value)
        entries.append(value)

    entry('main-png', main_path, main, args.main_fixture)
    for kind, key in [('oversize-png', 'oversizePng'), ('unsupported-gif', 'unsupportedGif')]:
        rows = [row for row in filters if row.get('kind') == key]
        fixture = filter_manifest.get(key, {})
        if len(rows) != 1 or fixture.get('sha256') != rows[0].get('sourceSha256'):
            raise SafeFailure('The exact private negative fixture manifest is missing or ambiguous')
        entry(kind, filter_path, rows[0], fixture['path'])
    sources = {}
    for path in args.source_receipt:
        path = file_in(path, PRIVATE)
        value = read(path)
        kind = value.get('case')
        if (kind not in KINDS[3:] or kind in sources or value.get('ownedTool') != 'device-import-avatar-source.py' or
                value.get('status') != 'imported_sha_verified' or value.get('shaVerified') is not True or
                value.get('sourceManifestSha256') != sha(source_manifest_path)):
            raise SafeFailure('The two exact completed source importer receipts are required')
        sources[kind] = (path, value)
    for kind in KINDS[3:]:
        matches = [row for row in source_manifest.get('cases', []) if row.get('case') == kind]
        if len(matches) != 1:
            raise SafeFailure('A source fixture manifest entry is missing or ambiguous')
        source = matches[0]['source']
        path, value = sources[kind]
        if source.get('sha256') != value.get('fixtureSha256') or source.get('bytes') != value.get('sourceBytes'):
            raise SafeFailure('The source importer receipt and original manifest do not agree')
        entry(kind, path, value, ROOT / source['file'])
    if (tuple(row['kind'] for row in entries) != KINDS or len({row['mediaUri'] for row in entries}) != 5 or
            len({row['displayName'] for row in entries}) != 5 or
            len({tmp['path'] for row in entries for tmp in row['temporaryExports']}) != sum(len(row['temporaryExports']) for row in entries)):
        raise SafeFailure('Five distinct owned fixtures and nonoverlapping exact exports are required')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    directory = BASE / ('cleanup-' + stamp)
    directory.mkdir(parents=True, exist_ok=False, mode=0o700)
    plan = {'status': 'prepared_not_device_executed', 'createdAt': now(), 'driverSha256': sha(Path(__file__)),
            'directory': relative(directory), 'entries': entries, 'commandCount': 0,
            'manifestInputs': [{'file': relative(path), 'sha256': sha(path)} for path in (filter_manifest_path, source_manifest_path)]}
    save(directory / 'plan.json', plan)
    print(json.dumps({'status': plan['status'], 'privatePlan': relative(directory / 'plan.json'), 'fixtureCount': 5,
                      'deviceActionsExecuted': 0, 'next': 'Root runs cleanup --plan only after all fixture-dependent phone scopes finish'}))


class Cleanup:
    def __init__(self, plan_path):
        self.plan_path = file_in(plan_path, PRIVATE)
        self.plan = read(self.plan_path)
        self.directory = self.plan_path.parent
        self.target = None  # Held in memory only and pinned for every device command.
        if (self.plan.get('driverSha256') != sha(Path(__file__)) or self.plan.get('directory') != relative(self.directory) or
                not self.directory.resolve().is_relative_to(BASE.resolve()) or
                tuple(row.get('kind') for row in self.plan.get('entries', [])) != KINDS):
            raise SafeFailure('The exact offline-created cleanup plan or its driver changed')
        for source in self.plan['manifestInputs']:
            if sha(file_in(ROOT / source['file'], PRIVATE)) != source['sha256']:
                raise SafeFailure('An original fixture manifest changed after cleanup planning')
        for item in self.plan['entries']:
            validate_identity(item)
            if sha(file_in(ROOT / item['originReceipt'], PRIVATE)) != item['originReceiptSha256']:
                raise SafeFailure('An original import receipt changed after cleanup planning')
            path = file_in(ROOT / item['source'], ROOT / 'artifacts/validation' if item['kind'] == 'main-png' else PRIVATE,
                           item['kind'] != 'main-png')
            if sha(path) != item['fixtureSha256'] or path.stat().st_size != item['bytes']:
                raise SafeFailure('Original fixture bytes changed after cleanup planning')

    def write(self):
        save(self.plan_path, self.plan)

    def run(self, args, label, timeout=60, contains_identifiers=False):
        if self.target is not None and args and args[0] == 'hdc':
            args = ['hdc', '-t', self.target, *args[1:]]
        try:
            result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
        except Exception:
            raise SafeFailure('Official cleanup command did not finish: ' + label) from None
        self.plan['commandCount'] += 1
        record = {'label': label, 'returncode': result.returncode}
        if not contains_identifiers:
            record.update({'stdoutSha256': hashlib.sha256(result.stdout.encode()).hexdigest(),
                           'stderrSha256': hashlib.sha256(result.stderr.encode()).hexdigest()})
        save(self.directory / ('command-' + str(self.plan['commandCount']).zfill(3) + '.json'),
             record)
        self.write()
        if result.returncode or re.search(r'\[fail\]|\[error\]|error:|permission denied|not connected', result.stdout + '\n' + result.stderr, re.I):
            raise SafeFailure('Official cleanup command failed: ' + label + '; addresses and identifiers omitted')
        return result.stdout

    def shell(self, args, label, timeout=60):
        return self.run(['hdc', 'shell', shlex.join(args)], label, timeout)

    def query(self, item, label):
        output = self.shell(['mediatool', 'query', item['displayName'], '-u'], label)
        counts = re.findall(r'\bfind\s+(\d+)\s+result\b', output, re.I)
        uris = re.findall(r'"(file://media/Photo/[^"\r\n]+)"', output)
        if len(counts) != 1 or int(counts[0]) != len(uris) or any(not uri_valid(uri, item['displayName']) for uri in uris):
            raise SafeFailure('Exact-name media query count and URI rows are ambiguous')
        return int(counts[0]), uris

    def exists(self, path, label):
        # An exact literal path only; neither enumeration nor globbing occurs.
        command = 'if test -e ' + shlex.quote(path) + '; then printf present; else printf absent; fi'
        result = self.run(['hdc', 'shell', command], label).strip()
        if result not in ('present', 'absent'):
            raise SafeFailure('The exact owned temporary path existence was not observable')
        return result == 'present'

    def check_temporary(self, item, temporary, label):
        if not self.exists(temporary['path'], label + '-exists'):
            temporary.update({'removed': True, 'alreadyAbsentWhenChecked': True})
            self.write()
            return
        destination = self.directory / ('readback-' + secrets.token_hex(16) + PurePosixPath(temporary['path']).suffix)
        self.run(['hdc', 'file', 'recv', temporary['path'], str(destination)], label + '-readback', timeout=120)
        destination.chmod(0o600)
        if sha(destination) != item['fixtureSha256'] or destination.stat().st_size != item['bytes']:
            raise SafeFailure('An exact owned temporary export no longer matches its source; it was not removed')
        self.shell(['rm', temporary['path']], label + '-remove-only-sha-matched-file')
        if self.exists(temporary['path'], label + '-verify-absent'):
            raise SafeFailure('The exact owned temporary export remains after rm')
        temporary.update({'removed': True, 'freshReadbackSha256': item['fixtureSha256'], 'alreadyAbsentWhenChecked': False})
        self.write()

    def clean_item(self, item):
        kind = item['kind']
        count, uris = self.query(item, kind + '-query-before')
        if item['mediaDeleted']:
            if count != 0:
                raise SafeFailure('An already deleted owned fixture appeared again; no new asset was deleted')
        else:
            if count != 1 or uris != [item['mediaUri']]:
                raise SafeFailure('The exact original owned name/URI changed; no media was deleted')
            temporary = {'path': '/data/local/tmp/starward-cleanup-proof-' + secrets.token_hex(16) + PurePosixPath(item['displayName']).suffix,
                         'expectedSha256': item['fixtureSha256'], 'removed': False, 'createdByCleanup': True}
            if self.exists(temporary['path'], kind + '-proof-must-be-absent'):
                raise SafeFailure('A unique owned cleanup export unexpectedly exists')
            item.setdefault('cleanupExports', []).append(temporary)
            self.write()
            self.shell(['mediatool', 'recv', item['mediaUri'], temporary['path']], kind + '-fresh-exact-uri-export', timeout=120)
            destination = self.directory / ('media-proof-' + kind + '-' + secrets.token_hex(16) + PurePosixPath(item['displayName']).suffix)
            self.run(['hdc', 'file', 'recv', temporary['path'], str(destination)], kind + '-fresh-export-readback', timeout=120)
            destination.chmod(0o600)
            if sha(destination) != item['fixtureSha256'] or destination.stat().st_size != item['bytes']:
                raise SafeFailure('Fresh exact-URI bytes differ from the original owned fixture; media was not deleted')
            item['freshMediaReadbackSha256'] = item['fixtureSha256']
            self.write()
            output = self.shell(['mediatool', 'delete', item['mediaUri']], kind + '-delete-only-sha-matched-uri')
            if 'delete success' not in output.lower():
                raise SafeFailure('Official exact-URI deletion did not acknowledge success')
            count, _ = self.query(item, kind + '-query-after')
            if count != 0:
                raise SafeFailure('The exact owned fixture is still indexed after deletion')
            item.update({'mediaDeleted': True, 'queryAfterCount': 0})
            self.write()
        for index, temporary in enumerate([*item['temporaryExports'], *item.get('cleanupExports', [])]):
            if temporary.get('createdByCleanup') and not re.fullmatch(r'/data/local/tmp/starward-cleanup-proof-[a-f0-9]{32}\.(png|gif|jpg|webp)', temporary['path']):
                raise SafeFailure('A cleanup-created exact export identity changed')
            if not temporary.get('removed'):
                self.check_temporary(item, temporary, kind + '-temp-' + str(index))

    def report(self, status, error=None):
        value = {'status': status, 'scope': 'Only five SHA-verified owned avatar test-media URIs and their exact temporary exports',
                 'updatedAt': now(), 'driverSha256': sha(Path(__file__)), 'privatePlanSha256': sha(self.plan_path),
                 'fixtureCount': 5, 'connectedTargetCount': self.plan.get('connectedTargetCount'),
                 'identifiersPersisted': False, 'noApplicationOrServiceChanges': True,
                 'entries': [{'kind': item['kind'], 'fixtureSha256': item['fixtureSha256'], 'bytes': item['bytes'],
                              'freshMediaReadbackSha256': item.get('freshMediaReadbackSha256'), 'mediaDeleted': item['mediaDeleted'],
                              'queryAfterCount': item['queryAfterCount'],
                              'exactTemporaryExports': len(item['temporaryExports']) + len(item.get('cleanupExports', [])),
                              'allExactExportsAbsent': all(row.get('removed') for row in [*item['temporaryExports'], *item.get('cleanupExports', [])])}
                             for item in self.plan['entries']]}
        if error:
            value['error'] = error
        if PUBLIC.is_symlink():
            raise SafeFailure('Public cleanup report cannot be a symlink')
        PUBLIC.parent.mkdir(parents=True, exist_ok=True)
        PUBLIC.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

    def execute(self):
        if self.plan.get('status') == 'passed':
            raise SafeFailure('This cleanup already completed; its report is not replayed as new device evidence')
        if PUBLIC.exists() and self.plan.get('status') == 'prepared_not_device_executed':
            raise SafeFailure('Preserve the existing public cleanup evidence before running a different plan')
        # Query output is held in memory; never persist or print device IDs.
        output = self.run(['hdc', 'list', 'targets'], 'connected-target-count', contains_identifiers=True)
        targets = [line.strip() for line in output.splitlines() if line.strip() and '[Empty]' not in line]
        self.plan['connectedTargetCount'] = len(targets)
        if len(targets) != 1 or any(char.isspace() for char in targets[0]):
            raise SafeFailure('Exactly one connected target is required; identifiers omitted')
        self.target = targets[0]
        self.plan['status'] = 'running'
        self.write()
        try:
            for item in self.plan['entries']:
                self.clean_item(item)
            self.plan.update({'status': 'passed', 'completedAt': now()})
            self.write()
            self.report('passed')
        except Exception as error:
            self.plan.update({'status': 'incomplete', 'lastAttemptAt': now()})
            self.write()
            self.report('incomplete', str(error) if isinstance(error, SafeFailure) else 'Owned exact-file cleanup stopped; private plan retained')
            raise
        print(json.dumps({'status': 'passed', 'fixtureCount': 5, 'report': relative(PUBLIC), 'identifiersPersisted': False}))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action', required=True)
    prepare_parser = sub.add_parser('prepare', help='Offline ownership/SHA plan; no device commands')
    prepare_parser.add_argument('--main-receipt', type=Path, default=PRIVATE / 'profile-device/avatar-import-receipt.json')
    prepare_parser.add_argument('--main-fixture', type=Path, default=ROOT / 'artifacts/validation/profile/avatar-fixture.png')
    prepare_parser.add_argument('--filter-receipt', type=Path, default=PRIVATE / 'profile-device/filter-import-receipt.json')
    prepare_parser.add_argument('--filter-manifest', type=Path, default=PRIVATE / 'profile-filter-fixtures/manifest.json')
    prepare_parser.add_argument('--source-manifest', type=Path, required=True)
    prepare_parser.add_argument('--source-receipt', type=Path, required=True, action='append', help='Exactly two original source importer receipts')
    cleanup_parser = sub.add_parser('cleanup', help='Root-only actual device cleanup after all fixture-dependent scopes')
    cleanup_parser.add_argument('--plan', type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.action == 'prepare':
            prepare(args)
        else:
            Cleanup(args.plan).execute()
        return 0
    except Exception as error:
        print(json.dumps({'status': 'incomplete', 'error': str(error) if isinstance(error, SafeFailure) else
                          'Exact owned media operation stopped; private values omitted', 'deviceIdentifiersPrinted': False}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

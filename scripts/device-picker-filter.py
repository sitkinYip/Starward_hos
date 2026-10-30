#!/usr/bin/env python3
"""Staged, conservative real system-Picker filename/filter observation.

Root runs this only after the same-base core/S2/main-avatar acceptance passes:
  begin
  search --case positive-before
  review --proof <private actual-result receipt>
  search/review oversize-png, unsupported-gif, positive-after, in that order
  finish

Search semantics and empty-result UI have NOT been observed during preparation.
Each search therefore stops for root to inspect its PRIVATE raw metadata. It
cannot pass merely because an image is absent from a screen. A positive result
needs a complete, submitted full-filename search with one exact owned URI; each
negative needs a root-observed explicit empty indicator in a complete result
surface, with no media result item. Unknown/semantic/unindexed search is reported
not_observable. No library traversal, thumbnail export, selection or upload exists.

Private proof schema (values must come from THIS run actual raw, never guessed):
  {"case":"positive-before", "rawSha256":"...", "querySha256":"...",
   "querySubmittedAndSearchCompleted":true, "fullResultSurfaceObserved":true,
   "filenameSearchSemanticsConfirmed":true, "noSemanticOrIndexingAmbiguity":true,
   "resultRoot":{"id":"<actual result container id>","type":"<actual type>"},
   "itemIdentityPrefix":"<actual CachedImage id prefix before owned media URI>",
   "systemExplicitlyReportsZeroResults":true,
   "emptyIndicator":{"id":"<actual id, may be empty>","type":"Text",
                     "text":"<actual explicit-empty copy>"}}
itemIdentityPrefix is established by the first positive exact-owned result and
must stay identical later. emptyIndicator is required only for the negatives.
Root booleans attest the observed search completion/scope; this driver separately
checks query bytes, exact fixture identity, actual node structure and geometry.
If such evidence is unavailable, run finish to cancel and report not_observable.
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shlex
import shutil
import stat
import subprocess
import time
import uuid

from isolated_snapshot import ReadonlySnapshot
from native_device_ui import ROOT, IsolationControl, SafeFailure

SPEC = importlib.util.spec_from_file_location('picker_filter_profile', Path(__file__).with_name('device-profile-acceptance.py'))
CORE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CORE)
OUT = ROOT / 'artifacts/validation/profile'
PRIVATE = ROOT / 'artifacts/private/picker-filter-device'
SESSION = PRIVATE / 'session.json'
REPORT = OUT / 'device-picker-filter.json'
HAP = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
BUNDLE = 'com.sitkin.starward'
GRID = 'ThirdSelectAlbum_Gird'
SEARCH = 'SearchView'
FIELD = '__SearchField__SearchView'
PROFILE = '/api/questions/v1/me/profile'
CHANGE = '/api/questions/v1/me/change-password'
ORDER = ('positive-before', 'oversize-png', 'unsupported-gif', 'positive-after')
CASE_KEYS = {'positive-before': 'smallPng', 'oversize-png': 'oversizePng',
             'unsupported-gif': 'unsupportedGif', 'positive-after': 'smallPng'}


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def text_sha(value):
    return hashlib.sha256(value.encode('utf-8')).hexdigest()


def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def private_write(path, value):
    if path.is_symlink():
        raise SafeFailure('Private Picker output cannot be a symlink')
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        json.dump(value, output, ensure_ascii=False, indent=2)
        output.write('\n')
    path.chmod(0o600)


def input_path(value, directory, private=False):
    original = Path(value).absolute()
    path = original.resolve()
    if not path.is_relative_to(directory.resolve()):
        raise SafeFailure('Picker evidence resolved outside its permitted project directory')
    for parent in (original, *original.parents):
        if parent.is_symlink():
            raise SafeFailure('Picker evidence paths cannot contain symlinks')
        if parent == directory.absolute():
            break
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or private and (info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077):
        raise SafeFailure('Private Picker receipts must be owned regular mode0600 files')
    return path


def nodes(value):
    if isinstance(value, list):
        for item in value:
            yield from nodes(item)
    elif isinstance(value, dict):
        if isinstance(value.get('attributes'), dict):
            yield value['attributes']
        for child in value.get('children', []):
            yield from nodes(child)


def tree_nodes(value):
    if isinstance(value, list):
        for item in value:
            yield from tree_nodes(item)
    elif isinstance(value, dict):
        if isinstance(value.get('attributes'), dict):
            yield value
        for child in value.get('children', []):
            yield from tree_nodes(child)


def rect(row):
    match = re.fullmatch(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', row.get('bounds', ''))
    if not match:
        raise SafeFailure('The actual Picker node did not expose integer bounds')
    return [int(value) for value in match.groups()]


def inside(inner, outer):
    return outer[0] <= inner[0] < inner[2] <= outer[2] and outer[1] <= inner[1] < inner[3] <= outer[3]


def visible(row):
    return row.get('visible') == 'true'


class Picker:
    """Every input is preceded by the observed embedded Picker surface guard."""
    def __init__(self, directory, window, host_window=None, result_surface=None):
        self.directory, self.window, self.host_window = directory, window, host_window
        self.result_surface = result_surface
        self.sequence, self.artifacts, self.submitted = 0, [], False

    def run(self, *args):
        try:
            result = subprocess.run([str(value) for value in args], cwd=ROOT, capture_output=True, text=True, timeout=30)
        except Exception:
            raise SafeFailure('Official scoped Picker command did not return; private values omitted') from None
        if result.returncode or result.stdout.lstrip().startswith(('Error:', '[Fail]')):
            raise SafeFailure('Official scoped Picker command failed; private values omitted')
        return result.stdout

    def dump(self, label):
        self.sequence += 1
        token = uuid.uuid4().hex
        target = self.directory / ('raw-' + label + '-' + token + '.json')
        remote = '/data/local/tmp/starward-picker-filter-' + token + '.json'
        try:
            self.run('hdc', 'shell', 'uitest', 'dumpLayout', '-b', BUNDLE, '-p', remote)
            self.run('hdc', 'file', 'recv', remote, target)
            target.chmod(0o600)
            self.artifacts.append({'file': str(target.relative_to(ROOT)), 'sha256': sha(target), 'label': label})
        finally:
            self.run('hdc', 'shell', 'rm', remote)
        try:
            tree = json.loads(target.read_text())
        except Exception:
            raise SafeFailure('Scoped Picker raw metadata was not JSON') from None
        rows = list(nodes(tree))
        bundles = {row['bundleName'] for row in rows if row.get('bundleName')}
        if bundles != {BUNDLE}:
            raise SafeFailure('Scoped raw metadata no longer belongs solely to this App embedded Picker')
        return {'file': str(target.relative_to(ROOT)), 'sha256': sha(target), 'tree': tree, 'rows': rows}

    def screen(self):
        return [0, 0, self.window['widthPx'], self.window['heightPx']]

    def guard(self, capture, require_grid=True, require_focus=False):
        rows = capture['rows']
        controls = {}
        for identifier, kind in ((SEARCH, 'Search'), (FIELD, 'SearchField')):
            matches = [row for row in rows if row.get('id') == identifier and row.get('type') == kind and visible(row)]
            if len(matches) != 1 or matches[0].get('enabled') != 'true' or not inside(rect(matches[0]), self.screen()):
                raise SafeFailure('The actual Picker Search controls are not uniquely visible and enabled')
            controls[identifier] = matches[0]
        hosts = {controls[key].get('hostWindowId') for key in controls}
        if len(hosts) != 1 or not isinstance(next(iter(hosts)), str) or not next(iter(hosts)):
            raise SafeFailure('Actual Picker Search controls do not share one observed host window')
        host = next(iter(hosts))
        if self.host_window is not None and host != self.host_window:
            raise SafeFailure('The embedded Picker host window changed; no background App input was sent')
        if require_grid:
            grids = [row for row in rows if row.get('id') == GRID and row.get('type') == 'Grid' and visible(row)]
            original = (len(grids) == 1 and grids[0].get('hostWindowId') == host and grids[0].get('enabled') == 'true' and
                        inside(rect(grids[0]), self.screen()))
            approved = [] if self.result_surface is None else [row for row in rows
                if row.get('id') == self.result_surface['id'] and row.get('type') == self.result_surface['type'] and
                row.get('hostWindowId') == host and visible(row) and inside(rect(row), self.screen())]
            if not original and len(approved) != 1:
                raise SafeFailure('The actually observed embedded Picker Grid is not available')
        field, owner = controls[FIELD], controls[SEARCH]
        if not inside(rect(field), rect(owner)):
            raise SafeFailure('The native Picker SearchField is outside its observed Search owner')
        # The actual API26 raw tree marks the enclosing Search as focused while
        # its internal SearchField remains false. Accept only one of these two
        # already-validated controls in the same embedded Picker host window.
        focused = field if field.get('focused') == 'true' else owner if owner.get('focused') == 'true' else None
        if require_focus and focused is None:
            raise SafeFailure('The actual Picker SearchField focus could not be observed; no text was sent')
        self.host_window = host
        # In the observed native tree focus belongs to Search, while the actual
        # text/originalText value belongs to its internal SearchField.
        return field

    def action(self, *args, require_grid=False, require_focus=False):
        capture = self.dump('before-input')
        self.guard(capture, require_grid, require_focus)
        self.run(*args)

    def query(self, query):
        self.submitted = False
        before = self.dump('before-query')
        field = self.guard(before, require_grid=True)
        bounds = rect(field)
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'click', (bounds[0] + bounds[2]) // 2, (bounds[1] + bounds[3]) // 2)
        self.action('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017', require_focus=True)
        self.action('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', '2055', require_focus=True)
        cleared = self.dump('cleared-query')
        field = self.guard(cleared, require_grid=False, require_focus=True)
        if field.get('text', '') or field.get('originalText', ''):
            raise SafeFailure('The native full-filename search query was not cleared exactly')
        self.action('hdc', 'shell', 'uitest uiInput text ' + shlex.quote(query), require_focus=True)
        typed = self.dump('typed-query')
        field = self.guard(typed, require_grid=False, require_focus=True)
        if not self.full_query(field, query):
            return [typed], 'query_not_observable_or_truncated'
        # Fixed API26 keyCode declaration: KEYCODE_ENTER=2054. The before-input
        # guard still requires the actual focused Picker field, never an App form.
        self.action('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', '2054', require_focus=True)
        self.submitted = True
        captures = []
        for index in range(3):
            if index:
                time.sleep(.6)
            captures.append(self.dump('search-result-' + str(index)))
        return captures, None

    @staticmethod
    def full_query(field, query):
        values = [field[key] for key in ('text', 'originalText') if isinstance(field.get(key), str) and field[key]]
        return bool(values) and all(value == query for value in values)


class Acceptance:
    def __init__(self, args):
        self.args, self.control = args, IsolationControl()
        self.state = self.control.state
        self.hap = sha(HAP)
        if not self.state.get('account', '').startswith('hm_'):
            raise SafeFailure('Picker filtering requires this dedicated generated player')
        core_path = input_path(OUT / 'device-profile-acceptance.json', OUT)
        core = json.loads(core_path.read_text())
        runtime_value = args.runtime_report or ROOT / core.get('runtime', {}).get('file', '')
        self.input_paths = {'runtime': input_path(runtime_value, OUT),
            'core': core_path, 's2': OUT / 'device-profile-password-uncertain.json',
            'avatar': OUT / 'device-profile-avatar.json',
            'positiveReceipt': input_path(args.positive_receipt, ROOT / 'artifacts/private', True),
            'negativeReceipts': input_path(args.negative_receipts, ROOT / 'artifacts/private', True),
            'fixtureManifest': input_path(args.fixture_manifest, ROOT / 'artifacts/private', True),
            'driver': Path(__file__).resolve(), 'uiHelper': Path(__file__).with_name('device-profile-acceptance.py').resolve(),
            'nativeHelper': Path(__file__).with_name('native_device_ui.py').resolve(),
            'snapshotHelper': Path(__file__).with_name('isolated_snapshot.py').resolve(),
            'state': input_path(self.control.state_path, ROOT / 'artifacts/private', True),
            'config': ROOT / 'entry/src/main/resources/rawfile/integration.json'}
        self.input_shas = {key: sha(path) for key, path in self.input_paths.items()}
        runtime = json.loads(self.input_paths['runtime'].read_text())
        window = runtime.get('window', {})
        if (runtime.get('status') != 'passed' or runtime.get('installedHapSha256') != self.hap or
                not all(finite(window.get(key)) and window[key] > 0 for key in ('density', 'widthPx', 'heightPx'))):
            raise SafeFailure('Actual Picker-filter runtime must match the current installed HAP')
        core, s2, avatar = [json.loads(self.input_paths[key].read_text()) for key in ('core', 's2', 'avatar')]
        for value in (core, s2, avatar):
            if (value.get('status') != 'passed' or value.get('hap', {}).get('packagedSha256') != self.hap or
                    value.get('runtime', {}).get('sha256') != self.input_shas['runtime']):
                raise SafeFailure('Complete matching core/S2/main-avatar basic acceptance before Picker filtering')
        if (not all(all(value.get('cleanup', {}).get(key) is True for key in ('loggedOut', 'faultNeutralised'))
                    for value in (core, s2)) or s2.get('corePrerequisite', {}).get('sha256') != self.input_shas['core'] or
                avatar.get('corePrerequisite', {}).get('sha256') != self.input_shas['core'] or
                avatar.get('securityPrerequisiteSha256') != self.input_shas['s2'] or
                avatar.get('injectedStorageFault', {}).get('restored') is not True or
                avatar.get('injectedStorageFault', {}).get('cleanupLoggedOut') is not True):
            raise SafeFailure('Picker-filter base account prerequisites do not share a clean epoch')
        config = json.loads(self.input_paths['config'].read_text())
        self.password_key = s2.get('finalPasswordKey')
        if (config.get('isolated') is not True or config.get('endpoint') != self.state['tls']['base'] or
                self.password_key not in ('initialPassword', 'newPassword') or avatar.get('finalPasswordKey') != self.password_key):
            raise SafeFailure('The packaged dedicated environment and verified current password key are required')
        self.owner = text_sha(self.state['account'] + self.state['playerId'] + self.state['controlBase'])
        self.fixtures = self.read_fixtures()
        if args.action == 'begin':
            if SESSION.exists():
                if not args.new_attempt:
                    raise SafeFailure('A filter session exists; --new-attempt preserves it for an intentional retry')
                stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
                archived = PRIVATE / ('session-' + stamp + '.json')
                shutil.copyfile(SESSION, archived)
                archived.chmod(0o600)
            directory = PRIVATE / ('run-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
            directory.mkdir(parents=True, exist_ok=False, mode=0o700)
            directory.chmod(0o700)
            self.session = {'startedAt': now(), 'ownerSha256': self.owner, 'hapSha256': self.hap,
                'inputShas': self.input_shas, 'directory': str(directory.relative_to(ROOT)),
                'stage': 'starting', 'results': [], 'hostWindowId': None, 'itemIdentityPrefix': None,
                'approvedResultSurface': None,
                'guardedCancelBackCount': 0,
                'notObservableReason': None, 'cleanup': {'pickerCancelled': False, 'profileUnchanged': False,
                    'noNewProfilePatch': False, 'noNewPasswordWrite': False, 'loggedOut': False, 'emptyLoginInputs': False}}
            if REPORT.exists():
                private_write(directory / 'previous-public-report.json', json.loads(REPORT.read_text()))
        else:
            self.session = json.loads(input_path(SESSION, ROOT / 'artifacts/private', True).read_text())
            if (self.session.get('ownerSha256') != self.owner or self.session.get('hapSha256') != self.hap or
                    self.session.get('inputShas') != self.input_shas):
                raise SafeFailure('The staged Picker session belongs to a different HAP/account/input epoch')
            directory = ROOT / self.session['directory']
            if directory.is_symlink() or not directory.resolve().is_relative_to(PRIVATE.resolve()):
                raise SafeFailure('The unique staged Picker directory is invalid')
        self.directory = directory
        self.ui = CORE.ProfileUI(self.state, window['density'])
        self.ui.output = self.ui.shots = self.directory
        self.picker = Picker(self.directory, window, self.session.get('hostWindowId'), self.session.get('approvedResultSurface'))

    def read_fixtures(self):
        manifest = json.loads(self.input_paths['fixtureManifest'].read_text())
        positive = json.loads(self.input_paths['positiveReceipt'].read_text())
        negatives = json.loads(self.input_paths['negativeReceipts'].read_text())
        if not isinstance(negatives, list) or len(negatives) != 2:
            raise SafeFailure('Exactly the two imported negative-fixture receipts are required')
        output = {}
        for key in ('smallPng', 'oversizePng', 'unsupportedGif'):
            record = manifest.get(key, {})
            if key == 'smallPng':
                path = input_path(record.get('path', ''), OUT)
                if path != (OUT / 'avatar-fixture.png').resolve():
                    raise SafeFailure('The positive control must be the exact generated public QA PNG')
            else:
                path = input_path(record.get('path', ''), ROOT / 'artifacts/private', True)
            value, size = sha(path), path.stat().st_size
            if record.get('sha256') != value or record.get('bytes') != size:
                raise SafeFailure('Original private filter fixture bytes do not match their manifest')
            if key == 'smallPng':
                receipt = positive
                verified = positive.get('shaVerified') is True and positive.get('fixtureSha256') == positive.get('readbackSha256') == value
            else:
                matches = [item for item in negatives if item.get('kind') == key and item.get('sourceSha256') == value]
                if len(matches) != 1:
                    raise SafeFailure('An exact negative import receipt is missing or ambiguous')
                receipt = matches[0]
                verified = (receipt.get('importSent') is True and receipt.get('sourceBytes') == size and
                            receipt.get('readbackBytes') == size and receipt.get('readbackSha256') == value)
            query, uri = receipt.get('displayName', ''), receipt.get('mediaUri', '')
            if (not verified or not isinstance(query, str) or not 1 <= len(query.encode('utf-8')) <= 255 or
                    any(char in query for char in '/\\\r\n\x00') or
                    not isinstance(uri, str) or not uri.startswith('file://media/Photo/') or '?' in uri):
                raise SafeFailure('Only exact imported/readback-verified private fixture identities may be queried')
            output[key] = {'path': str(path.relative_to(ROOT)), 'sha256': value, 'bytes': size,
                'format': record.get('format'), 'query': query, 'querySha256': text_sha(query), 'mediaUri': uri}
        if (output['oversizePng']['bytes'] != 50 * 1024 * 1024 + 1 or output['oversizePng']['format'] != 'PNG' or
                output['unsupportedGif']['format'] != 'GIF' or output['smallPng']['format'] != 'PNG' or
                output['smallPng']['bytes'] >= 50 * 1024 * 1024 or
                len({value['query'] for value in output.values()}) != 3 or len({value['mediaUri'] for value in output.values()}) != 3):
            raise SafeFailure('Positive PNG, exact50MiB+1 PNG and unsupported GIF fixture identities must be distinct')
        return output

    def immutable(self):
        if sha(HAP) != self.hap or any(sha(path) != self.input_shas[key] for key, path in self.input_paths.items()) or any(
                sha(ROOT / record['path']) != record['sha256'] for record in self.fixtures.values()):
            raise SafeFailure('A staged Picker prerequisite, fixture or driver changed')

    def writes(self):
        rows = self.control.requests()
        return {'patch': sum(row.get('path') == PROFILE and row.get('method') == 'PATCH' for row in rows),
                'password': sum(row.get('path') == CHANGE and row.get('method') == 'POST' for row in rows)}

    def save(self, status='not_observable', error=None):
        self.last_status = status
        self.session['updatedAt'] = now()
        private_write(SESSION, self.session)
        results = []
        for item in self.session['results']:
            fixture = self.fixtures[CASE_KEYS[item['case']]]
            results.append({'case': item['case'], 'status': item.get('status', 'not_observable'),
                'fixtureSha256': fixture['sha256'], 'originalFileBytes': fixture['bytes'],
                'querySha256': fixture['querySha256'], 'rawFileSha256': [value['sha256'] for value in item['captures']],
                'reviewReceiptSha256': item.get('reviewReceiptSha256'), 'resultStructureCounts': item.get('counts'),
                'notObservableReason': item.get('notObservableReason')})
        public = {'status': status, 'scope': 'Actual owned-fixture system Picker filename/filter observations only',
            'startedAt': self.session['startedAt'], 'updatedAt': self.session['updatedAt'],
            'hap': {'packagedSha256': self.hap}, 'inputSha256': self.input_shas,
            'stage': self.session['stage'], 'cases': results, 'cleanup': self.session['cleanup'],
            'notObservableReason': self.session.get('notObservableReason'),
            'privateOriginals': str(self.directory.relative_to(ROOT)), 'libraryTraversed': False,
            'thumbnailsExported': False, 'mediaSelected': False, 'nativeUploadClaimed': False,
            'notExecuted': ['No automatic assumption about semantic-search or media indexing',
                'No entire-library enumeration or acceptance based on one screen lacking a fixture',
                'No profile save, protected-file write, image crop or format normalization in this filter-only scope']}
        if error:
            public['error'] = error
        if REPORT.is_symlink():
            raise SafeFailure('The public Picker report cannot be a symlink')
        OUT.mkdir(parents=True, exist_ok=True)
        REPORT.write_text(json.dumps(public, ensure_ascii=False, indent=2) + '\n')
        private_write(self.directory / 'report.json', public)

    def begin(self):
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state[self.password_key])
        player = snapshot.request('/api/questions/v1/me')
        snapshot.token = ''
        if player.get('id') != self.state['playerId'] or player.get('account') != self.state['account'] or player.get('mustChangePassword') is not False:
            raise SafeFailure('Read-only authentication did not identify the dedicated current player')
        self.session['beforeWrites'] = self.writes()
        self.session['profileName'] = player.get('displayName')
        self.ui.launch()
        self.ui.wait(lambda ui: ui.find('account') is not None, 'pre-existing empty filter login')
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('Finish the prior device scope at empty login before beginning the filter probe')
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state[self.password_key])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'dedicated filter home')
        self.ui.tap('nav-profile')
        self.ui.seek('profile-name')
        if self.ui.find('profile-name').get('text') != player.get('displayName') or self.ui.find('profile-avatar-pending') is not None:
            raise SafeFailure('The native profile is not the unchanged dedicated baseline')
        self.ui.tap('profile-avatar-pick')
        capture = self.picker.dump('opened-picker')
        self.picker.guard(capture, require_grid=True)
        self.session['hostWindowId'] = self.picker.host_window
        self.session['openingRaw'] = {key: capture[key] for key in ('file', 'sha256')}
        self.session['stage'] = 'picker-open'
        self.save('awaiting_filename_probe')

    def search(self):
        completed = [item for item in self.session['results'] if item.get('status') == 'reviewed']
        if self.session.get('notObservableReason') or len(completed) != len(self.session['results']) or len(completed) >= len(ORDER):
            raise SafeFailure('Finish or review the preceding exact search before another query')
        if self.args.case != ORDER[len(completed)]:
            raise SafeFailure('Use positive-before, oversize-png, unsupported-gif, positive-after in that exact order')
        fixture = self.fixtures[CASE_KEYS[self.args.case]]
        record = {'case': self.args.case, 'status': 'not_observable', 'captures': [],
                  'notObservableReason': None, 'counts': None, 'querySubmitted': False}
        self.session['results'].append(record)
        self.session['stage'] = 'awaiting-actual-search-review'
        private_write(self.directory / ('query-' + self.args.case + '.json'),
                      {'case': self.args.case, 'query': fixture['query'], 'querySha256': fixture['querySha256']})
        start = len(self.picker.artifacts)
        try:
            captures, reason = self.picker.query(fixture['query'])
            record['notObservableReason'] = reason
            if reason:
                self.session['notObservableReason'] = reason
        finally:
            # Preserve unknown actual result IDs and private query evidence even
            # when the first probe cannot recognise the new system search page.
            record['captures'] = list(self.picker.artifacts[start:])
            record['querySubmitted'] = self.picker.submitted
        self.save('not_observable')

    @staticmethod
    def anchor(rows, description, host):
        if not isinstance(description, dict) or not isinstance(description.get('id'), str) or not isinstance(description.get('type'), str):
            raise SafeFailure('A reviewed actual result node id/type is required')
        matches = [row for row in rows if row.get('id', '') == description['id'] and row.get('type') == description['type'] and
                   visible(row) and row.get('hostWindowId') == host and
                   ('text' not in description or row.get('text', '') == description['text'])]
        if len(matches) != 1:
            raise SafeFailure('The reviewed actual result node is not unique and visible in this raw host window')
        return matches[0]

    def review(self):
        if not self.args.proof or not self.session['results'] or self.session['results'][-1].get('status') == 'reviewed':
            raise SafeFailure('An outstanding search and its private actual-evidence receipt are required')
        proof_path = input_path(self.args.proof, ROOT / 'artifacts/private', True)
        proof = json.loads(proof_path.read_text())
        item = self.session['results'][-1]
        fixture = self.fixtures[CASE_KEYS[item['case']]]
        if (proof.get('case') != item['case'] or proof.get('querySha256') != fixture['querySha256'] or
                any(proof.get(key) is not True for key in ('querySubmittedAndSearchCompleted', 'fullResultSurfaceObserved',
                    'filenameSearchSemanticsConfirmed', 'noSemanticOrIndexingAmbiguity'))):
            raise SafeFailure('Actual full-filename query completion/scope/semantics must be explicitly reviewed')
        captures = [value for value in item['captures'] if value['sha256'] == proof.get('rawSha256') and
                    value.get('label', '').startswith('search-result-')]
        if len(captures) != 1 or item.get('querySubmitted') is not True:
            raise SafeFailure('Review receipt does not bind one original raw result from this exact query')
        capture_path = input_path(ROOT / captures[0]['file'], ROOT / 'artifacts/private', True)
        if sha(capture_path) != proof['rawSha256']:
            raise SafeFailure('An original raw result changed before review')
        tree = json.loads(capture_path.read_text())
        capture = {'tree': tree, 'rows': list(nodes(tree))}
        field = self.picker.guard(capture, require_grid=False)
        if not self.picker.full_query(field, fixture['query']):
            raise SafeFailure('The exact full query bytes were not observable in the reviewed native SearchField')
        root = self.anchor(capture['rows'], proof.get('resultRoot'), self.picker.host_window)
        if root.get('type') not in ('Grid', 'List', 'Scroll', 'Column', 'Stack', 'Flex', 'GridRow'):
            raise SafeFailure('The reviewed complete result root must be an actual result container, not a thumbnail or label')
        root_rect = rect(root)
        if not inside(root_rect, self.picker.screen()):
            raise SafeFailure('The reviewed complete result surface is clipped outside the actual window')
        roots = [node for node in tree_nodes(tree) if node['attributes'] is root]
        if len(roots) != 1:
            raise SafeFailure('The actual reviewed result subtree is ambiguous')
        result_rows = list(nodes(roots[0]))
        prefix = proof.get('itemIdentityPrefix')
        if not isinstance(prefix, str) or not 1 <= len(prefix) <= 160 or any(char in prefix for char in '/?\r\n'):
            raise SafeFailure('The actual media item identity prefix has not been established')
        if self.session['itemIdentityPrefix'] and prefix != self.session['itemIdentityPrefix']:
            raise SafeFailure('The native search result identity format changed between positive and negative controls')
        identities, all_images = [], []
        for row in result_rows:
            if row.get('type') != 'CachedImage' or not visible(row) or row.get('hostWindowId') != self.picker.host_window:
                continue
            all_images.append(row)
            values = [row[key] for key in ('id', 'key') if isinstance(row.get(key), str)]
            if any(value.startswith(prefix + 'file://media/Photo/') for value in values):
                if not inside(rect(row), root_rect):
                    raise SafeFailure('A native media result is not fully contained in the reviewed result surface')
                identities.append(row)
        if len(all_images) != len(identities):
            raise SafeFailure('The complete result subtree contains another image identity format; an empty result cannot be inferred')
        exact = re.compile('^' + re.escape(prefix) + re.escape(fixture['mediaUri']) + r'(?:\?|$)')
        owned = [row for row in identities if any(isinstance(row.get(key), str) and exact.search(row[key])
                                                  for key in ('id', 'key'))]
        if item['case'].startswith('positive-'):
            if len(identities) != 1 or len(owned) != 1 or owned[0].get('enabled') != 'true':
                raise SafeFailure('The actual complete filename-search result is not the one exact owned enabled fixture')
            bounds = rect(owned[0])
            if bounds[2] - bounds[0] < 100 or abs((bounds[2] - bounds[0]) - (bounds[3] - bounds[1])) > 3:
                raise SafeFailure('The exact owned positive result is not a fully visible square')
            self.session['itemIdentityPrefix'] = prefix
        else:
            if self.session['itemIdentityPrefix'] is None or identities or owned:
                raise SafeFailure('A negative query did not expose an explicitly empty complete media result')
            if proof.get('systemExplicitlyReportsZeroResults') is not True:
                raise SafeFailure('The actual system indicator must explicitly mean zero completed search results')
            description = proof.get('emptyIndicator')
            if not isinstance(description, dict) or not isinstance(description.get('text'), str) or not description['text'].strip():
                raise SafeFailure('Root must supply the actual explicit-empty system text; no empty-state id or copy is guessed')
            empty = self.anchor(result_rows, description, self.picker.host_window)
            if not inside(rect(empty), root_rect):
                raise SafeFailure('The actual explicit-empty system indicator is outside the reviewed complete result surface')
        item.update({'status': 'reviewed', 'notObservableReason': None, 'reviewReceiptSha256': sha(proof_path),
            'counts': {'visibleMediaResults': len(identities), 'exactOwnedResults': len(owned),
                'explicitEmptyIndicator': not item['case'].startswith('positive-'), 'fullQueryObserved': True,
                'queryCompletionAndScopeReviewed': True}})
        self.session['approvedResultSurface'] = {key: root[key] for key in ('id', 'type')}
        self.session['stage'] = 'awaiting-next-query' if len(self.session['results']) < len(ORDER) else 'awaiting-cancel-and-cleanup'
        self.save('awaiting_next_stage')

    def app_profile(self, capture):
        rows = capture['rows']
        return (self.session.get('guardedCancelBackCount', 0) > 0 and
                not any(visible(row) and (row.get('id') in (GRID, SEARCH, FIELD) or
                    row.get('type') in ('Search', 'SearchField', 'CachedImage', 'Grid')) for row in rows) and
                any(visible(row) and row.get('id') == 'profile-scroll' for row in rows))

    def finish(self):
        # Unknown search pages are not handled with generic App UI or blind Back.
        # Root may manually return to the originally observed Picker Grid, then
        # rerun finish. Only that guarded surface can receive the cancel key.
        for attempt in range(4):
            capture = self.picker.dump('before-cancel-' + str(attempt))
            if self.app_profile(capture):
                break
            self.picker.guard(capture, require_grid=True)
            self.picker.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', 'Back')
            self.session['guardedCancelBackCount'] = self.session.get('guardedCancelBackCount', 0) + 1
            private_write(SESSION, self.session)
        else:
            raise SafeFailure('The known Picker did not cancel; no generic background-App action was attempted')
        self.session['cleanup']['pickerCancelled'] = True
        self.ui.wait(lambda ui: ui.find('profile-scroll') is not None, 'actual profile after Picker cancellation')
        self.ui.seek('profile-name')
        unchanged = (self.ui.find('profile-name').get('text') == self.session.get('profileName') and
                     self.ui.find('profile-avatar-pending') is None)
        self.session['cleanup']['profileUnchanged'] = unchanged
        if not unchanged:
            raise SafeFailure('Picker-only observations changed the native profile or pending avatar')
        writes = self.writes()
        self.session['cleanup']['noNewProfilePatch'] = writes['patch'] == self.session['beforeWrites']['patch']
        self.session['cleanup']['noNewPasswordWrite'] = writes['password'] == self.session['beforeWrites']['password']
        self.ui.tap('account-menu')
        self.ui.seek('logout')
        self.ui.tap('logout')
        self.ui.wait(lambda ui: ui.find('account') is not None, 'filter explicit logout')
        self.session['cleanup']['loggedOut'] = True
        self.session['cleanup']['emptyLoginInputs'] = self.ui.input_empty('account') and self.ui.input_empty('password')
        final_writes = self.writes()
        self.session['cleanup']['noNewProfilePatch'] = final_writes['patch'] == self.session['beforeWrites']['patch']
        self.session['cleanup']['noNewPasswordWrite'] = final_writes['password'] == self.session['beforeWrites']['password']
        self.immutable()
        complete = (len(self.session['results']) == len(ORDER) and
                    [item['case'] for item in self.session['results']] == list(ORDER) and
                    all(item.get('status') == 'reviewed' for item in self.session['results']) and
                    all(self.session['cleanup'].values()) and not self.session.get('notObservableReason'))
        self.session['stage'] = 'finished'
        if not complete and not self.session.get('notObservableReason'):
            self.session['notObservableReason'] = 'full_filename_search_or_explicit_empty_result_not_proven'
        self.save('passed' if complete else 'not_observable')
        return 0 if complete else 2

    def run(self):
        try:
            self.immutable()
            result = getattr(self, self.args.action)()
            print(json.dumps({'status': self.last_status, 'stage': self.session['stage'],
                              'report': str(REPORT.relative_to(ROOT)), 'cleanup': self.session['cleanup']}, ensure_ascii=False))
            return result or 0
        except Exception as error:
            message = str(error) if isinstance(error, SafeFailure) else 'Picker filtering stopped before actual evidence was established'
            self.save('not_observable', message)
            print(json.dumps({'status': 'not_observable', 'error': message, 'report': str(REPORT.relative_to(ROOT)),
                              'cleanup': self.session['cleanup']}, ensure_ascii=False))
            return 2


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('action', choices=('begin', 'search', 'review', 'finish'))
    parser.add_argument('--case', choices=ORDER)
    parser.add_argument('--proof', type=Path)
    parser.add_argument('--new-attempt', action='store_true')
    parser.add_argument('--runtime-report', type=Path, help='Defaults to the current passed core report actual runtime.file, with its SHA checked')
    parser.add_argument('--positive-receipt', type=Path, default=ROOT / 'artifacts/private/profile-device/avatar-import-receipt.json')
    parser.add_argument('--negative-receipts', type=Path, default=ROOT / 'artifacts/private/profile-device/filter-import-receipt.json')
    parser.add_argument('--fixture-manifest', type=Path, default=ROOT / 'artifacts/private/profile-filter-fixtures/manifest.json')
    args = parser.parse_args()
    if args.action == 'search' and args.case is None:
        parser.error('search requires --case')
    if args.action == 'review' and args.proof is None:
        parser.error('review requires --proof')
    try:
        return Acceptance(args).run()
    except Exception as error:
        message = str(error) if isinstance(error, SafeFailure) else 'Picker-filter setup stopped before any acceptance claim'
        print(json.dumps({'status': 'not_observable', 'scope': 'Picker-filter setup only', 'error': message}, ensure_ascii=False))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())

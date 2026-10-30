#!/usr/bin/env python3
"""Independent actual owned oversize-PNG/GIF source rejection and recovery checks.

  begin --case oversize-png|unsupported-gif
    Root runs the existing exact-owned selector using the private normalized
    selector receipt printed by begin, then presses the real Picker Complete.
  verify --case <same>
    Observes actual App outcome, cancels error Sheet or recognised Picker, checks
    authoritative avatar/name unchanged and zero PATCH/password writes, logs out.

An error-only crop Sheet is a legitimate rejection state: sheetPresented is
recorded, and success requires the exact source-specific message, no valid crop
preview, disabled confirm, no pending avatar, no writes and full recovery.
If still in Picker, absence/disabled Complete alone is NOT claimed as rejection.
verify saves private raw metadata and performs guarded cancellation, reporting
not_observable. Optional OFFLINE review-block --proof <private actual receipt>
can separately establish an explicit official rejection in that saved raw:
 {"case":"...","fixtureSha256":"...","rawSha256":"...",
  "systemExplicitlyRejectsThisOwnedFixture":true,"exactFixtureAssociationReviewed":true,
  "kind":"completion-blocked"|"selection-disabled",
  "completeAttemptObserved":true,
  "message":{"id":"<actual id or empty>","type":"<actual type>",
             "text":"<actual explicit rejection copy>"}}
completion-blocked also requires the actual exact-selector evidence for this
session; selection-disabled requires its exact-owned CachedImage enabled=false.
Both require root review, a real visible system message, and already completed
no-write/logout cleanup. No guessed system text/id, media-library traversal,
host upload, altered fixture or production write exists in this driver.
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
import shutil
import stat
import subprocess
import time
import uuid

from isolated_snapshot import ReadonlySnapshot
from native_device_ui import ROOT, IsolationControl, SafeFailure

SPEC = importlib.util.spec_from_file_location('boundary_avatar_ui', Path(__file__).with_name('device-profile-avatar.py'))
AVATAR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AVATAR)
OUT = ROOT / 'artifacts/validation/profile'
PRIVATE = ROOT / 'artifacts/private/avatar-input-boundaries'
HAP = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
SELECTIONS = OUT / 'picker-selections.json'
PROFILE = '/api/questions/v1/me/profile'
CHANGE = '/api/questions/v1/me/change-password'
BUNDLE = 'com.sitkin.starward'
GRID, SEARCH, FIELD = 'ThirdSelectAlbum_Gird', 'SearchView', '__SearchField__SearchView'
CASES = {'oversize-png': {'key': 'oversizePng', 'format': 'PNG',
    'message': '原图超过 50 MB，请选择小一点的图片。', 'code': 'AVATAR_TOO_LARGE'},
    'unsupported-gif': {'key': 'unsupportedGif', 'format': 'GIF',
    'message': '请选择 JPG、PNG 或 WebP 图片。', 'code': 'AVATAR_INVALID_TYPE'}}


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def private_write(path, value):
    if path.is_symlink():
        raise SafeFailure('Private boundary output cannot be a symlink')
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        json.dump(value, output, ensure_ascii=False, indent=2)
        output.write('\n')
    path.chmod(0o600)


def path_in(value, directory, private=False):
    original = Path(value).absolute()
    path = original.resolve()
    if not path.is_relative_to(directory.resolve()):
        raise SafeFailure('Boundary input resolved outside its permitted project directory')
    for item in (original, *original.parents):
        if item.is_symlink():
            raise SafeFailure('Boundary inputs cannot contain symlinks')
        if item == directory.absolute():
            break
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or private and (info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077):
        raise SafeFailure('Private boundary inputs must be owned regular mode0600 files')
    return path


def raw_nodes(value):
    if isinstance(value, list):
        for item in value:
            yield from raw_nodes(item)
    elif isinstance(value, dict):
        if isinstance(value.get('attributes'), dict):
            yield value['attributes']
        for item in value.get('children', []):
            yield from raw_nodes(item)


def bounds(row):
    match = re.fullmatch(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', row.get('bounds', ''))
    if not match:
        raise SafeFailure('Actual boundary UI bounds are unavailable')
    return [int(value) for value in match.groups()]


def contained(inner, outer):
    return outer[0] <= inner[0] < inner[2] <= outer[2] and outer[1] <= inner[1] < inner[3] <= outer[3]


def visible(row):
    return row.get('visible') == 'true'


class Surface:
    """Raw official bundle-scoped evidence; no generic App input on a Picker."""
    def __init__(self, directory, window, host=None):
        self.directory, self.window, self.host = directory, window, host

    def run(self, *args):
        try:
            value = subprocess.run([str(arg) for arg in args], cwd=ROOT, capture_output=True, text=True, timeout=30)
        except Exception:
            raise SafeFailure('Official boundary command did not return; private values omitted') from None
        if value.returncode or value.stdout.lstrip().startswith(('Error:', '[Fail]')):
            raise SafeFailure('Official boundary command failed; private values omitted')
        return value.stdout

    def dump(self, phase):
        identifier = uuid.uuid4().hex
        path = self.directory / ('raw-' + phase + '-' + identifier + '.json')
        remote = '/data/local/tmp/starward-input-boundary-' + identifier + '.json'
        try:
            self.run('hdc', 'shell', 'uitest', 'dumpLayout', '-b', BUNDLE, '-p', remote)
            self.run('hdc', 'file', 'recv', remote, path)
            path.chmod(0o600)
        finally:
            self.run('hdc', 'shell', 'rm', remote)
        rows = list(raw_nodes(json.loads(path.read_text())))
        if {row['bundleName'] for row in rows if row.get('bundleName')} != {BUNDLE}:
            raise SafeFailure('Actual raw UI no longer belongs solely to the owned App embedded surface')
        return {'file': str(path.relative_to(ROOT)), 'sha256': sha(path), 'rows': rows}

    def screen(self):
        return [0, 0, self.window['widthPx'], self.window['heightPx']]

    def unique(self, rows, identifier):
        values = [row for row in rows if row.get('id') == identifier and visible(row)]
        return values[0] if len(values) == 1 else None

    def picker(self, capture):
        rows = capture['rows']
        grid, search, field = [self.unique(rows, key) for key in (GRID, SEARCH, FIELD)]
        candidates = [item for item in (grid, search, field) if item]
        if len(candidates) != 3:
            complete = self.unique(rows, 'Complete')
            candidates = [complete] if complete else []
        if not candidates:
            return False
        hosts = {item.get('hostWindowId') for item in candidates}
        if len(hosts) != 1 or not isinstance(next(iter(hosts)), str) or not next(iter(hosts)):
            return False
        host = next(iter(hosts))
        if self.host is not None and host != self.host:
            return False
        if any(not contained(bounds(item), self.screen()) for item in candidates):
            return False
        self.host = host
        return True

    @staticmethod
    def app(capture):
        rows = capture['rows']
        if any(visible(row) and (row.get('id') in (GRID, SEARCH, FIELD, 'Complete') or
                row.get('type') in ('Search', 'SearchField', 'CachedImage')) for row in rows):
            return False
        return any(visible(row) and row.get('id') in ('profile-scroll', 'avatar-crop-error',
                   'avatar-crop-loading', 'avatar-crop-confirm', 'account') for row in rows)


class Acceptance:
    def __init__(self, args):
        self.args, self.control = args, IsolationControl()
        self.state, self.case = self.control.state, CASES[args.case]
        self.hap = sha(HAP)
        core_path = path_in(OUT / 'device-profile-acceptance.json', OUT)
        core = json.loads(core_path.read_text())
        runtime_path = path_in(args.runtime_report or ROOT / core.get('runtime', {}).get('file', ''), OUT)
        self.inputs = {'core': core_path, 'runtime': runtime_path,
            's2': OUT / 'device-profile-password-uncertain.json', 'mainAvatar': OUT / 'device-profile-avatar.json',
            'receipts': path_in(args.receipts, ROOT / 'artifacts/private', True),
            'fixtures': path_in(args.fixture_manifest, ROOT / 'artifacts/private', True),
            'state': path_in(self.control.state_path, ROOT / 'artifacts/private', True),
            'driver': Path(__file__).resolve(), 'avatarUI': Path(AVATAR.__file__),
            'profileUI': Path(__file__).with_name('device-profile-acceptance.py'),
            'nativeUI': Path(__file__).with_name('native_device_ui.py'),
            'snapshot': Path(__file__).with_name('isolated_snapshot.py'),
            'selector': Path(__file__).with_name('select-owned-picker-fixture.py'),
            'integration': ROOT / 'entry/src/main/resources/rawfile/integration.json',
            'editor': ROOT / 'entry/src/main/ets/platform/AvatarEditor.ets',
            'crop': ROOT / 'entry/src/main/ets/ui/StarwardAvatarCrop.ets'}
        self.input_shas = {key: sha(path) for key, path in self.inputs.items()}
        runtime, s2, avatar = [json.loads(self.inputs[key].read_text()) for key in ('runtime', 's2', 'mainAvatar')]
        density = runtime.get('window', {}).get('density')
        if (runtime.get('status') != 'passed' or runtime.get('installedHapSha256') != self.hap or
                not isinstance(density, (int, float)) or isinstance(density, bool) or not math.isfinite(density) or density <= 0):
            raise SafeFailure('Actual boundary runtime must match the currently installed signed HAP')
        for value in (core, s2, avatar):
            if (value.get('status') != 'passed' or value.get('hap', {}).get('packagedSha256') != self.hap or
                    value.get('runtime', {}).get('sha256') != self.input_shas['runtime']):
                raise SafeFailure('Complete same-current-HAP/runtime core/S2/main-avatar prerequisites first')
        if (not all(all(value.get('cleanup', {}).get(key) is True for key in ('loggedOut', 'faultNeutralised'))
                    for value in (core, s2)) or s2.get('corePrerequisite', {}).get('sha256') != self.input_shas['core'] or
                avatar.get('corePrerequisite', {}).get('sha256') != self.input_shas['core'] or
                avatar.get('securityPrerequisiteSha256') != self.input_shas['s2'] or
                avatar.get('injectedStorageFault', {}).get('restored') is not True or
                avatar.get('injectedStorageFault', {}).get('cleanupLoggedOut') is not True):
            raise SafeFailure('The boundary prerequisites do not share a clean dedicated account epoch')
        config = json.loads(self.inputs['integration'].read_text())
        self.password_key = s2.get('finalPasswordKey')
        if (not self.state.get('account', '').startswith('hm_') or config.get('isolated') is not True or
                config.get('endpoint') != self.state['tls']['base'] or self.password_key not in ('initialPassword', 'newPassword') or
                avatar.get('finalPasswordKey') != self.password_key):
            raise SafeFailure('Only this packaged dedicated player and verified current password key are supported')
        manifest, receipts = [json.loads(self.inputs[key].read_text()) for key in ('fixtures', 'receipts')]
        record = manifest.get(self.case['key'], {})
        self.fixture = path_in(record.get('path', ''), ROOT / 'artifacts/private', True)
        self.fixture_sha, self.fixture_bytes = sha(self.fixture), self.fixture.stat().st_size
        if (record.get('format') != self.case['format'] or record.get('sha256') != self.fixture_sha or
                record.get('bytes') != self.fixture_bytes or not isinstance(receipts, list)):
            raise SafeFailure('The original case fixture must match its verified private manifest')
        matches = [row for row in receipts if row.get('kind') == self.case['key'] and row.get('sourceSha256') == self.fixture_sha]
        if len(matches) != 1:
            raise SafeFailure('Exactly one original case import receipt is required')
        self.receipt = matches[0]
        if (self.receipt.get('importSent') is not True or self.receipt.get('readbackSha256') != self.fixture_sha or
                self.receipt.get('sourceBytes') != self.fixture_bytes or self.receipt.get('readbackBytes') != self.fixture_bytes or
                not re.fullmatch(r'file://media/Photo/[^?\s]+', self.receipt.get('mediaUri', '')) or
                not isinstance(self.receipt.get('displayName'), str) or not self.receipt['displayName'] or
                args.case == 'oversize-png' and self.fixture_bytes != 50 * 1024 * 1024 + 1 or
                args.case == 'unsupported-gif' and not 0 < self.fixture_bytes < 50 * 1024 * 1024):
            raise SafeFailure('Exact source/readback SHA, original bytes and owned imported media identity are required')
        self.owner = hashlib.sha256((self.state['account'] + self.state['playerId'] + self.state['controlBase']).encode()).hexdigest()
        self.session_path = PRIVATE / (args.case + '-session.json')
        self.report_path = OUT / ('avatar-input-' + args.case + '.json')
        if args.action == 'begin':
            if self.session_path.exists():
                if not args.new_attempt:
                    raise SafeFailure('This boundary case exists; --new-attempt preserves it before an intentional retry')
                archived = PRIVATE / (args.case + '-session-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '.json')
                shutil.copyfile(self.session_path, archived)
                archived.chmod(0o600)
            self.directory = PRIVATE / ('run-' + args.case + '-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
            self.directory.mkdir(parents=True, exist_ok=False, mode=0o700)
            self.directory.chmod(0o700)
            self.session = {'case': args.case, 'ownerSha256': self.owner, 'hapSha256': self.hap,
                'inputShas': self.input_shas, 'fixtureSha256': self.fixture_sha, 'directory': str(self.directory.relative_to(ROOT)),
                'startedAt': now(), 'stage': 'starting', 'checks': [], 'raw': [], 'privateScreenshots': [],
                'outcome': {'kind': 'not_observable', 'sheetPresented': None, 'validCropPreviewAbsent': None,
                    'exactSourceMessage': None, 'confirmDisabled': None},
                'cleanup': {'cropOrPickerCancelled': False, 'profileAndPendingUnchanged': False,
                    'authoritativePlayerUnchanged': False, 'noProfilePatch': False, 'noPasswordWrite': False,
                    'loggedOut': False, 'emptyLoginInputs': False}}
            if self.report_path.exists():
                private_write(self.directory / 'previous-report.json', json.loads(self.report_path.read_text()))
        else:
            self.session = json.loads(path_in(self.session_path, ROOT / 'artifacts/private', True).read_text())
            if (self.session.get('ownerSha256') != self.owner or self.session.get('hapSha256') != self.hap or
                    self.session.get('inputShas') != self.input_shas or self.session.get('fixtureSha256') != self.fixture_sha):
                raise SafeFailure('The staged input case belongs to a different build/account/fixture epoch')
            self.directory = ROOT / self.session['directory']
            if self.directory.is_symlink() or not self.directory.resolve().is_relative_to(PRIVATE.resolve()):
                raise SafeFailure('The private boundary run directory is invalid')
        self.ui = AVATAR.AvatarUI(self.state, density)
        self.ui.output = self.ui.shots = self.directory
        self.ui.private_screenshots = self.session['privateScreenshots']
        self.surface = Surface(self.directory, runtime['window'], self.session.get('pickerHostWindowId'))

    def immutable(self):
        if sha(HAP) != self.hap or sha(self.fixture) != self.fixture_sha or any(sha(path) != self.input_shas[key] for key, path in self.inputs.items()):
            raise SafeFailure('A boundary HAP, source fixture, account epoch or prerequisite changed')
        normalized_sha = self.session.get('selectorReceiptSha256')
        if normalized_sha and sha(self.directory / 'selector-receipt.json') != normalized_sha:
            raise SafeFailure('The exact normalized source-selector receipt changed')

    def dump(self, phase):
        value = self.surface.dump(phase)
        self.session['raw'].append({'phase': phase, 'file': value['file'], 'sha256': value['sha256']})
        return value

    def writes(self):
        rows = self.control.requests()
        return {'profilePatch': sum(row.get('path') == PROFILE and row.get('method') == 'PATCH' for row in rows),
                'passwordPost': sum(row.get('path') == CHANGE and row.get('method') == 'POST' for row in rows)}

    def player(self):
        snapshot = ReadonlySnapshot(self.state)
        try:
            snapshot.login(self.state[self.password_key])
            player = snapshot.request('/api/questions/v1/me')
        finally:
            snapshot.token = ''
        if player.get('id') != self.state['playerId'] or player.get('account') != self.state['account'] or player.get('mustChangePassword') is not False:
            raise SafeFailure('Strict read-only HTTPS did not return the owned current player')
        return {key: player.get(key) for key in ('id', 'account', 'displayName', 'avatar')}

    def selection_count(self):
        value = json.loads(SELECTIONS.read_text()) if SELECTIONS.exists() else {'selections': []}
        rows = value.get('selections')
        if not isinstance(rows, list):
            raise SafeFailure('The separate exact-selector evidence has an invalid shape')
        return rows

    def selection_evidence(self):
        rows = self.selection_count()[self.session['selectionCountBefore']:]
        if not rows:
            self.session['selectionEvidence'] = {'exactSelectionRecorded': False, 'newSelectionRecords': 0}
            return False
        if len(rows) != 1:
            raise SafeFailure('More than one new root selection was recorded; this single-source boundary is ambiguous')
        row = rows[0]
        normalized = self.directory / 'selector-receipt.json'
        if (row.get('status') != 'selection_sent' or row.get('fixtureSha256') != self.fixture_sha or
                row.get('importReceiptSha256') != sha(normalized) or row.get('driverSha256') != self.input_shas['selector']):
            raise SafeFailure('The root selection is not this exact normalized case receipt/fixture/selector')
        directory = ROOT / row.get('privateEvidence', '')
        actual_path = path_in(directory / 'selection.json', ROOT / 'artifacts/private', True)
        actual = json.loads(actual_path.read_text())
        raw_path = path_in(directory / 'raw.json', ROOT / 'artifacts/private', True)
        if (actual.get('mediaUri') != self.receipt['mediaUri'] or actual.get('fixtureSha256') != self.fixture_sha or
                actual.get('importReceiptSha256') != sha(normalized) or
                actual.get('rawSha256') != row.get('rawSha256') or sha(raw_path) != row.get('rawSha256')):
            raise SafeFailure('Root actual selection raw/URI evidence no longer matches this owned fixture')
        private_write(self.directory / 'root-selection.json', row)
        self.session['selectionEvidence'] = {'exactSelectionRecorded': True, 'newSelectionRecords': 1,
            'selectionRawSha256': row['rawSha256'], 'privateSelectionSha256': sha(actual_path)}
        return True

    def save(self, status, error=None):
        self.session['updatedAt'] = now()
        private_write(self.session_path, self.session)
        value = {'status': status, 'scope': 'Actual owned source-input boundary and recovery; not proof of automatic Picker filtering',
            'case': self.args.case, 'startedAt': self.session['startedAt'], 'updatedAt': self.session['updatedAt'],
            'hap': {'packagedSha256': self.hap}, 'inputSha256': self.input_shas,
            'runtime': {'file': str(self.inputs['runtime'].relative_to(ROOT)), 'sha256': self.input_shas['runtime']},
            'fixture': {'sha256': self.fixture_sha, 'bytes': self.fixture_bytes, 'format': self.case['format'],
                'sourceAndReadbackShaVerified': True, 'normalizedSelectorReceiptSha256': self.session.get('selectorReceiptSha256')},
            'stage': self.session['stage'], 'outcome': self.session['outcome'],
            'expectedBusinessError': {'code': self.case['code'], 'message': self.case['message']},
            'checks': self.session['checks'], 'selectionEvidence': self.session.get('selectionEvidence'),
            'rawEvidence': [{'phase': row['phase'], 'sha256': row['sha256']} for row in self.session['raw']],
            'privateScreenshots': self.session['privateScreenshots'], 'cleanup': self.session['cleanup'],
            'privateOriginals': str(self.directory.relative_to(ROOT)), 'hostTraffic': 'Authentication/me GET only; no host upload',
            'notExecuted': ['No production, profile save, password change or native crop confirmation is performed',
                'A visible enabled Picker item is not claimed to prove filtering or official rejection',
                'System Picker screenshots/personal thumbnail pixels are not exported by this driver']}
        if error:
            value['error'] = error
        if self.report_path.is_symlink():
            raise SafeFailure('Public boundary report cannot be a symlink')
        self.report_path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
        private_write(self.directory / 'report.json', value)

    def begin(self):
        baseline = self.player()
        self.session['baselinePlayer'] = baseline
        self.session['beforeWrites'] = self.writes()
        self.session['selectionCountBefore'] = len(self.selection_count())
        normalized = {'fixtureSha256': self.fixture_sha, 'readbackSha256': self.fixture_sha,
            'mediaUri': self.receipt['mediaUri'], 'displayName': self.receipt['displayName'],
            'shaVerified': True, 'sourceBytes': self.fixture_bytes, 'readbackBytes': self.fixture_bytes,
            'sourceReceiptSha256': self.input_shas['receipts'], 'sourceKind': self.case['key'],
            'normalization': 'One existing verified list entry; no new media import or readback was fabricated'}
        normalized_path = self.directory / 'selector-receipt.json'
        private_write(normalized_path, normalized)
        self.session['selectorReceiptSha256'] = sha(normalized_path)
        self.ui.launch()
        self.ui.wait(lambda ui: ui.find('account') is not None, 'pre-existing empty boundary login')
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('Finish the prior device scope at empty login first')
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state[self.password_key])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'dedicated boundary home')
        self.ui.tap('nav-profile')
        self.ui.seek('profile-name')
        self.ui.capture('profile-before-source')
        if (self.ui.find('profile-name').get('text') != baseline['displayName'] or
                self.ui.find('profile-avatar-pending') is not None or self.ui.find('profile-error') is not None):
            raise SafeFailure('Boundary selection requires a clean authoritative profile without pending upload/error')
        self.ui.private_shot('profile-before-source')
        self.ui.tap('profile-avatar-pick')
        capture = self.dump('picker-open')
        if not self.surface.picker(capture):
            raise SafeFailure('The actual owned embedded Picker was not recognised')
        self.session['pickerHostWindowId'] = self.surface.host
        self.session['stage'] = 'awaiting_exact_owned_selection_and_complete'
        self.save('awaiting_system_selection')
        print(json.dumps({'status': 'awaiting_system_selection', 'selectorReceipt': str(normalized_path.relative_to(ROOT)),
            'fixture': str(self.fixture.relative_to(ROOT)), 'next': 'Root runs exact-owned selector and actual Picker Complete; then verify this same case'}, ensure_ascii=False))

    def observe_app(self):
        self.ui.wait(lambda ui: any(ui.find(key) is not None for key in
                     ('avatar-crop-error', 'profile-error', 'avatar-crop-preview')),
                     'actual terminal source preparation result', timeout=30)
        self.ui.wait(lambda ui: ui.find('avatar-crop-loading') is None, 'source preparation finishes', timeout=30)
        self.ui.capture('source-result')
        preview = self.ui.find('avatar-crop-preview')
        error = self.ui.find('avatar-crop-error') or self.ui.find('profile-error')
        sheet = self.ui.find('avatar-crop-confirm') is not None or self.ui.find('avatar-crop-error') is not None
        outcome = self.session['outcome']
        outcome.update({'sheetPresented': sheet, 'validCropPreviewAbsent': preview is None,
            'exactSourceMessage': error is not None and error.get('text') == self.case['message']})
        if preview is not None:
            outcome['kind'] = 'invalid_source_entered_valid_crop'
            return 'failed'
        if error is None or error.get('text') != self.case['message']:
            outcome['kind'] = 'missing_or_wrong_source_error'
            self.ui.private_shot('source-result-unexpected')
            return 'failed' if error is not None else 'not_observable'
        if sheet:
            self.ui.seek('avatar-crop-confirm')
            raw = self.dump('source-error-confirm-state')
            valid_ids = {'avatar-crop-preview', 'avatar-crop-zoom', 'avatar-crop-horizontal', 'avatar-crop-vertical'}
            if any(row.get('id') in valid_ids for row in raw['rows']):
                outcome.update({'validCropPreviewAbsent': False, 'kind': 'invalid_source_exposed_crop_preview_or_adjustment_controls'})
                return 'failed'
            matches = [row for row in raw['rows'] if row.get('id') == 'avatar-crop-confirm' and visible(row)]
            outcome['confirmDisabled'] = len(matches) == 1 and matches[0].get('enabled') == 'false'
            if len(matches) != 1 or matches[0].get('enabled') not in ('true', 'false'):
                outcome['kind'] = 'confirm_enabled_state_not_observable'
                return 'not_observable'
            if not outcome['confirmDisabled']:
                outcome['kind'] = 'invalid_source_confirm_enabled'
                return 'failed'
            outcome['kind'] = 'native_error_sheet_rejected_source'
        else:
            outcome['confirmDisabled'] = None
            outcome['kind'] = 'native_profile_rejected_before_crop_sheet'
        self.ui.private_shot('source-specific-rejection')
        self.session['checks'].append({'label': 'Actual source-specific native message; no valid crop preview and error-Sheet confirm disabled when present'})
        return 'passed'

    def cleanup(self):
        app_seen = False
        for attempt in range(5):
            raw = self.dump('before-cleanup-' + str(attempt))
            if self.surface.picker(raw):
                self.surface.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', 'Back')
                continue
            if not self.surface.app(raw):
                raise SafeFailure('The source result is not a recognised App/crop/Picker; no background-App action was attempted')
            app_seen = True
            break
        if not app_seen:
            raise SafeFailure('The recognised Picker did not cancel in the bounded cleanup')
        self.ui.capture()
        if self.ui.find('avatar-crop-confirm') is not None or self.ui.find('avatar-crop-error') is not None:
            self.ui.tap('avatar-crop-cancel')
        self.ui.wait(lambda ui: ui.find('profile-scroll') is not None and ui.find('avatar-crop-confirm') is None,
                     'original profile after rejected source cancellation')
        self.session['cleanup']['cropOrPickerCancelled'] = True
        self.ui.seek('profile-name')
        unchanged = (self.ui.find('profile-name').get('text') == self.session['baselinePlayer']['displayName'] and
                     self.ui.find('profile-avatar-pending') is None)
        self.session['cleanup']['profileAndPendingUnchanged'] = unchanged
        self.session['cleanup']['authoritativePlayerUnchanged'] = self.player() == self.session['baselinePlayer']
        self.ui.private_shot('profile-after-source-cancel')
        self.ui.tap('account-menu')
        self.ui.seek('logout')
        self.ui.tap('logout')
        self.ui.wait(lambda ui: ui.find('account') is not None, 'boundary explicit logout')
        self.session['cleanup']['loggedOut'] = True
        self.session['cleanup']['emptyLoginInputs'] = self.ui.input_empty('account') and self.ui.input_empty('password')
        writes = self.writes()
        self.session['cleanup']['noProfilePatch'] = writes['profilePatch'] == self.session['beforeWrites']['profilePatch']
        self.session['cleanup']['noPasswordWrite'] = writes['passwordPost'] == self.session['beforeWrites']['passwordPost']
        self.immutable()
        if not all(self.session['cleanup'].values()):
            raise SafeFailure('Boundary cleanup did not preserve the original player/draft and zero-write empty-login state')

    def verify(self):
        if self.session['stage'] != 'awaiting_exact_owned_selection_and_complete':
            raise SafeFailure('Verify only the outstanding exact-source Picker session')
        result, error = 'not_observable', None
        try:
            selected = self.selection_evidence()
            raw = self.dump('source-result-before-generic-app-ui')
            if self.surface.picker(raw):
                self.session['outcome']['kind'] = 'still_picker_without_proven_official_rejection'
                self.session['outcome']['pickerObservationRawSha256'] = raw['sha256']
            elif self.surface.app(raw) and selected:
                result = self.observe_app()
            else:
                self.session['outcome']['kind'] = 'selection_or_foreground_result_not_observable'
        except Exception as failure:
            error = str(failure) if isinstance(failure, SafeFailure) else 'Actual input-boundary outcome was not observable'
        finally:
            try:
                self.cleanup()
            except Exception:
                error = error or 'The rejected source could not be safely cancelled and cleared to empty login'
            self.session['stage'] = 'observed_and_cleaned' if all(self.session['cleanup'].values()) else 'cleanup_incomplete'
            self.save('incomplete' if error else result, error)
        return 1 if error or result == 'failed' else 0 if result == 'passed' else 2

    def review_block(self):
        if not self.args.proof or self.session['stage'] != 'observed_and_cleaned' or not all(self.session['cleanup'].values()):
            raise SafeFailure('Official-block review requires the actual saved Picker observation and completed cleanup')
        proof_path = path_in(self.args.proof, ROOT / 'artifacts/private', True)
        proof = json.loads(proof_path.read_text())
        raw_sha = self.session['outcome'].get('pickerObservationRawSha256')
        if (not raw_sha or proof.get('rawSha256') != raw_sha or proof.get('fixtureSha256') != self.fixture_sha or
                proof.get('case') != self.args.case or proof.get('systemExplicitlyRejectsThisOwnedFixture') is not True or
                proof.get('exactFixtureAssociationReviewed') is not True):
            raise SafeFailure('Root must bind an actual explicit system rejection to this exact saved source/Picker raw')
        captures = [row for row in self.session['raw'] if row['sha256'] == raw_sha]
        if len(captures) != 1:
            raise SafeFailure('The actual Picker rejection raw is missing or ambiguous')
        path = path_in(ROOT / captures[0]['file'], ROOT / 'artifacts/private', True)
        if sha(path) != raw_sha:
            raise SafeFailure('The actual saved Picker rejection raw changed')
        capture = {'rows': list(raw_nodes(json.loads(path.read_text())))}
        if not self.surface.picker(capture):
            raise SafeFailure('The reviewed official rejection is not on the observed embedded Picker surface')
        description = proof.get('message', {})
        if not isinstance(description.get('text'), str) or not description['text'].strip():
            raise SafeFailure('An actual explicit system rejection message is required; no text is invented')
        messages = [row for row in capture['rows'] if row.get('id', '') == description.get('id') and
                    row.get('type') == description.get('type') and row.get('text') == description['text'] and visible(row) and
                    row.get('hostWindowId') == self.surface.host and contained(bounds(row), self.surface.screen())]
        if len(messages) != 1:
            raise SafeFailure('The reviewed actual system rejection message is not uniquely visible')
        kind = proof.get('kind')
        if kind == 'completion-blocked':
            if not self.session.get('selectionEvidence', {}).get('exactSelectionRecorded') or proof.get('completeAttemptObserved') is not True:
                raise SafeFailure('Official completion blocking needs the actual exact owned selection and root-observed Complete attempt')
        elif kind == 'selection-disabled':
            pattern = re.compile(r'^ThirdSelectAlbumGridBase_GridItem' + re.escape(self.receipt['mediaUri']) + r'(?:\?|$)')
            assets = [row for row in capture['rows'] if row.get('type') == 'CachedImage' and visible(row) and
                      row.get('hostWindowId') == self.surface.host and
                      any(isinstance(row.get(key), str) and pattern.search(row[key]) for key in ('id', 'key'))]
            if len(assets) != 1 or assets[0].get('enabled') != 'false':
                raise SafeFailure('Official selection blocking requires the actual exact owned disabled asset')
            asset_bounds = bounds(assets[0])
            if (asset_bounds[2] - asset_bounds[0] < 100 or
                    abs((asset_bounds[2] - asset_bounds[0]) - (asset_bounds[3] - asset_bounds[1])) > 3 or
                    not contained(asset_bounds, self.surface.screen())):
                raise SafeFailure('The actual exact owned disabled asset is not fully visible as a square result')
        else:
            raise SafeFailure('The official rejection kind is not supported')
        self.session['outcome'].update({'kind': 'official_picker_explicit_rejection',
            'officialRejectionKind': kind, 'rootReviewReceiptSha256': sha(proof_path),
            'nativeAvatarEditorExercised': False})
        self.session['stage'] = 'official_block_reviewed_after_cleanup'
        self.save('passed')
        return 0

    def run(self):
        try:
            self.immutable()
            result = getattr(self, self.args.action.replace('-', '_'))()
            print(json.dumps({'report': str(self.report_path.relative_to(ROOT)), 'stage': self.session['stage'],
                              'outcome': self.session['outcome']['kind'], 'cleanup': self.session['cleanup']}, ensure_ascii=False))
            return result or 0
        except Exception as failure:
            message = str(failure) if isinstance(failure, SafeFailure) else 'Boundary preparation/observation did not complete'
            self.save('not_observable', message)
            print(json.dumps({'status': 'not_observable', 'error': message, 'report': str(self.report_path.relative_to(ROOT))}, ensure_ascii=False))
            return 2


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('action', choices=('begin', 'verify', 'review-block'))
    parser.add_argument('--case', required=True, choices=tuple(CASES))
    parser.add_argument('--runtime-report', type=Path, help='Defaults to the current passed core.runtime.file; same-HAP/S2/main-avatar SHA chain required')
    parser.add_argument('--receipts', type=Path, default=ROOT / 'artifacts/private/profile-device/filter-import-receipt.json')
    parser.add_argument('--fixture-manifest', type=Path, default=ROOT / 'artifacts/private/profile-filter-fixtures/manifest.json')
    parser.add_argument('--proof', type=Path, help='Only the actual root-reviewed official rejection receipt, never a simulated message')
    parser.add_argument('--new-attempt', action='store_true')
    args = parser.parse_args()
    if args.action == 'review-block' and not args.proof:
        parser.error('review-block requires --proof')
    try:
        return Acceptance(args).run()
    except Exception as failure:
        message = str(failure) if isinstance(failure, SafeFailure) else 'Boundary setup stopped before any acceptance claim'
        print(json.dumps({'status': 'not_observable', 'scope': 'Owned-input boundary setup only', 'error': message}, ensure_ascii=False))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())

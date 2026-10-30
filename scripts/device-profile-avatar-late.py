#!/usr/bin/env python3
"""Independent real late-avatar/logout check on a private 15000ms HAP variant.

Root must finish one current same-HAP core/S2/main-avatar scope, archive that HAP,
then build/install ONLY the private integration timeout2000->15000 variant and
capture its actual runtime. Root also resumes the existing TLS identity with the
opt-in response gate. This driver never builds, installs, restarts services,
imports/selects media, writes a profile/password, or changes the base reports.

  python3 scripts/device-profile-avatar-late.py --runtime-report <variant.json>
      --base-hap-manifest artifacts/validation/profile/base-hap.json

The base HAP/source/ABC/configuration come only from that frozen manifest and
its private archive. Its actual runtime comes from the passed core.runtime
file/SHA. No historic HAP hash/runtime or previous product checks are inherited.

All login values, current owned avatar addresses/bytes, UI trees and screenshots
remain private. A pass applies to the15000ms transport variant only. It does not
turn an unexecuted/failed2000ms late-response experiment into a base-HAP pass.
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
import signal
import ssl
import stat
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

from isolated_snapshot import ReadonlySnapshot
from native_device_ui import ROOT, IsolationControl, SafeFailure, sanitise
from hap_timeout_variant import VariantMismatch, validate_timeout_entries

SPEC = importlib.util.spec_from_file_location('late_profile_ui', Path(__file__).with_name('device-profile-acceptance.py'))
CORE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CORE)

OUT = ROOT / 'artifacts/validation/profile'
PRIVATE = ROOT / 'artifacts/private/avatar-late-device'
REPORT = OUT / 'device-profile-avatar-late.json'
HAP = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
CONFIG_ENTRY = 'resources/rawfile/integration.json'
CA_ENTRY = 'resources/rawfile/integration-ca.pem'
AUTH = '/api/collections/game_players/auth-with-password'
ME = '/api/questions/v1/me'
TOKEN = '/api/files/token'
PROFILE = '/api/questions/v1/me/profile'
CHANGE = '/api/questions/v1/me/change-password'
MENU_IDS = ('menu-home', 'menu-rewards', 'menu-notifications', 'menu-profile')
AUTHENTICATED_IDS = (*MENU_IDS, 'account-menu', 'current-tab', 'history-tab', 'nav-home',
    'nav-rewards', 'nav-notifications', 'nav-profile', 'profile-scroll', 'profile-passport',
    'profile-account', 'profile-name', 'profile-avatar-pick', 'profile-avatar-pending',
    'avatar-error', 'avatar-retry', 'avatar-crop-preview', 'logout', 'forced-logout')
EVENTS = ('armed', 'requestReceived', 'held', 'released', 'downstreamFinished', 'clientAborted', 'failed')


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def digest(value):
    return hashlib.sha256(value).hexdigest()


def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def checked_path(value, directory, private=False):
    path = Path(value).absolute()
    resolved = path.resolve()
    if not resolved.is_relative_to(directory.resolve()):
        raise SafeFailure('Evidence input resolved outside its permitted project directory')
    for item in (path, *path.parents):
        if item.is_symlink():
            raise SafeFailure('Evidence paths cannot contain symlinks')
        if item == directory.absolute():
            break
    info = path.stat()
    if not stat.S_ISREG(info.st_mode):
        raise SafeFailure('Evidence input must be a regular file')
    if private and (stat.S_IMODE(info.st_mode) & 0o077 or info.st_uid != os.getuid()):
        raise SafeFailure('Private evidence must be owned by this user and mode0600')
    return resolved


def private_write(path, value, binary=False):
    if path.is_symlink():
        raise SafeFailure('Private output cannot be a symlink')
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'wb' if binary else 'w') as output:
        output.write(value if binary else json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    path.chmod(0o600)


def load(path):
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise SafeFailure('Evidence JSON must be an object')
    return value


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Gate:
    """Secret control is loopback-only; no control request body enters a report."""
    def __init__(self, state, owner, directory):
        value = state.get('tls', {}).get('responseGate', {}).get('receiptPath')
        if not isinstance(value, str):
            raise SafeFailure('Root must enable the isolated response gate before this independent run')
        self.receipt_path = checked_path(value, ROOT / 'artifacts/private', True)
        self.receipt_sha = sha(self.receipt_path)
        receipt = load(self.receipt_path)
        base = urllib.parse.urlsplit(receipt.get('controlBase', ''))
        if (base.scheme != 'http' or base.hostname != '127.0.0.1' or not base.port or
                not 1024 <= base.port <= 65535 or base.username or base.password or
                base.path not in ('', '/') or base.query or base.fragment or
                receipt.get('ownerSha256') != owner or receipt.get('pid') != state['tls'].get('pid') or
                not re.fullmatch(r'[a-f0-9]{32}', receipt.get('instanceId', '')) or
                not isinstance(receipt.get('controlToken'), str) or len(receipt['controlToken']) < 32):
            raise SafeFailure('Response-gate receipt does not bind this dedicated TLS process and player')
        manifest = receipt.get('manifest', {})
        expected = {'version': 1, 'enabled': True, 'maxTtlMs': 14000, 'singleUsePerArm': True,
                    'bufferedInMemoryOnly': True, 'verifiesOriginalBodySha256': True}
        if any(manifest.get(key) != item for key, item in expected.items()):
            raise SafeFailure('Response-gate capabilities do not match this driver')
        self.base, self.token = receipt['controlBase'].rstrip('/'), receipt['controlToken']
        self.instance, self.manifest = receipt['instanceId'], manifest
        self.directory, self.records, self.gate_id, self.last = directory, [], None, None
        self.arm_attempted = False
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

    def call(self, route, body=None):
        if route not in ('/arm', '/status', '/release', '/cancel') or sha(self.receipt_path) != self.receipt_sha:
            raise SafeFailure('Response-gate control or receipt changed during acceptance')
        request = urllib.request.Request(self.base + route, data=json.dumps(body or {}).encode(), method='POST',
            headers={'Authorization': self.token, 'Content-Type': 'application/json'})
        try:
            with self.opener.open(request, timeout=3) as response:
                status, raw = response.status, response.read(65537)
        except urllib.error.HTTPError as error:
            status, raw = error.code, error.read(65537)
        except Exception:
            raise SafeFailure('Private response-gate control did not return') from None
        try:
            value = json.loads(raw) if len(raw) <= 65536 else None
        except ValueError:
            value = None
        self.records.append({'at': now(), 'route': route, 'httpStatus': status, 'response': value})
        private_write(self.directory / 'gate-control-responses.json', self.records)
        if status != 200 or not isinstance(value, dict):
            raise SafeFailure('Response-gate control rejected ' + route)
        return value

    def status(self):
        value = self.call('/status')
        if value.get('manifest') != self.manifest or not isinstance(value.get('history'), list):
            raise SafeFailure('Response-gate status manifest changed')
        current = value.get('current')
        if current is not None:
            self.public_ledger(current)  # Validate before retaining even safe public fields.
        if self.gate_id and (not current or current.get('gateId') != self.gate_id):
            raise SafeFailure('The current response gate is no longer this run exact gate')
        self.last = current
        return current

    @staticmethod
    def public_ledger(row):
        if (not isinstance(row, dict) or not re.fullmatch(r'[a-f0-9]{32}', row.get('gateId', '')) or
                row.get('state') not in ('armed', 'receiving', 'held', 'released', 'finished', 'failed') or
                not isinstance(row.get('bodySha256Matched'), bool) or
                not isinstance(row.get('ttlMs'), int) or isinstance(row.get('ttlMs'), bool)):
            raise SafeFailure('Response-gate ledger structure was invalid')
        result = {key: row[key] for key in ('gateId', 'state', 'ttlMs', 'bodySha256Matched')}
        for name in EVENTS:
            event = row.get(name)
            if event is not None:
                if (not isinstance(event, dict) or not isinstance(event.get('at'), str) or
                        not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z', event['at']) or
                        not finite(event.get('elapsedMs')) or event['elapsedMs'] < 0):
                    raise SafeFailure('Response-gate event structure was invalid')
                safe = {key: event[key] for key in ('at', 'elapsedMs')}
                if name == 'failed':
                    reason = event.get('reason', '')
                    if not re.fullmatch(r'[A-Z][A-Z0-9_]{0,63}', reason):
                        raise SafeFailure('Response-gate failure reason was invalid')
                    safe['reason'] = reason
                result[name] = safe
            else:
                result[name] = None
        return result

    def arm(self, path, expected_sha):
        current = self.status()
        if current and current['state'] not in ('finished', 'failed'):
            raise SafeFailure('Another response gate remains active; it was not changed')
        self.arm_attempted = True
        row = self.call('/arm', {'path': path, 'expectedSha256': expected_sha, 'ttlMs': 14000})
        if re.fullmatch(r'[a-f0-9]{32}', row.get('gateId', '')):
            self.gate_id = row['gateId']
        self.public_ledger(row)
        if row['state'] != 'armed' or row.get('failed') or row.get('clientAborted'):
            raise SafeFailure('The exact owned response gate was not armed')
        self.gate_id, self.last = row['gateId'], row

    def await_state(self, wanted, timeout):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            row = self.status()
            if row and row.get('state') == wanted:
                return row
            if row and (row.get('failed') or row.get('clientAborted') or row.get('state') == 'failed'):
                raise SafeFailure('The native gated request failed or disconnected; no late response is credited')
            time.sleep(.025)
        raise SafeFailure('The real native response did not reach the required gate state')

    def neutralise(self):
        if self.gate_id is None:
            # A lost/malformed arm acknowledgement is not proof that no gate
            # was armed. Do not claim cleanup or cancel an unidentified gate.
            return not self.arm_attempted
        row = self.status()
        if row['state'] not in ('finished', 'failed'):
            self.call('/cancel', {'gateId': self.gate_id})
            row = self.status()
        return row['state'] in ('finished', 'failed')


class LateUI(CORE.ProfileUI):
    def __init__(self, state, density, window, directory):
        super().__init__(state, density)
        self.output = self.shots = directory
        self.window, self.menu_scrolling, self.recorded_swipes = window, False, None

    def capture(self, name=None):
        result = super().capture()
        if abs(self.width - self.window['widthPx']) > 1 or abs(self.height - self.window['heightPx']) > 1:
            raise SafeFailure('The native window changed after variant runtime/calibration')
        if name:
            private_write(self.output / ('ui-' + name + '.json'), self.redact(sanitise(self.tree)))
        return result

    def swipe(self, direction):
        if not self.menu_scrolling:
            return super().swipe(direction)
        self.capture()
        scroll = None
        for node_id in (*MENU_IDS, 'logout', 'theme-picker'):
            scroll = next((node for node in reversed(self.path_to(node_id) or [])
                           if node.get('type') == 'Scroll' and node.get('bounds')), None)
            if scroll:
                break
        if scroll is None:
            raise SafeFailure('Native menu Scroll could not be identified for calibration')
        app, bounds = self.app_rect(), scroll['bounds']
        left, top, right, bottom = max(app[0], bounds[0]), max(app[1], bounds[1]), min(app[2], bounds[2]), min(app[3], bounds[3])
        if right - left < 80 or bottom - top < 150:
            raise SafeFailure('Native menu Scroll viewport is too small')
        x = int(left + (right - left) * .58)
        high, low = int(top + (bottom - top) * .30), int(top + (bottom - top) * .76)
        start, end = (low, high) if direction == 'down' else (high, low)
        points = [x, start, x, end]
        # The calibration and race use the SAME official UiTest swipe command,
        # including its default speed, rather than assuming CLI/hdc speeds match.
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'swipe', *points)
        if self.recorded_swipes is not None:
            self.recorded_swipes.append(points)


class Acceptance:
    def __init__(self, args):
        self.args, self.control = args, IsolationControl()
        self.state = self.control.state
        self.started_at, self.checks, self.observations = now(), [], []
        self.ready = False
        self.cleanup = {'ownGateNeutralised': False, 'loggedOut': False, 'emptyLoginInputs': False,
                        'backAndRelaunchEmpty': False, 'noBusinessWrites': False}
        self.inputs = {}
        self.input_shas = {}
        self.owner = digest((self.state['account'] + self.state['playerId'] + self.state['controlBase']).encode())
        if not self.state['account'].startswith('hm_') or not re.fullmatch(r'[a-z0-9]{15}', self.state['playerId']):
            raise SafeFailure('Only this dedicated generated player is supported')
        self.base_manifest = self.input('baseHap', args.base_hap_manifest)
        self.base_sha = self.base_manifest.get('hapSha256', '')
        if not re.fullmatch(r'[a-f0-9]{64}', self.base_sha):
            raise SafeFailure('The explicit frozen base-HAP manifest must identify one signed-HAP SHA')
        self.core = self.input('core', args.core_report)
        runtime_record = self.core.get('runtime', {})
        if (self.core.get('status') != 'passed' or not isinstance(runtime_record.get('file'), str) or
                not re.fullmatch(r'[a-f0-9]{64}', runtime_record.get('sha256', ''))):
            raise SafeFailure('The current passed core report must identify its actual base runtime file and SHA')
        self.base_runtime = self.input('baseRuntime', args.base_runtime_report or ROOT / runtime_record['file'])
        self.base_runtime_sha = self.input_shas['baseRuntime']
        if self.base_runtime_sha != runtime_record['sha256']:
            raise SafeFailure('The frozen base runtime bytes do not match the passed core.runtime SHA')
        self.s2 = self.input('s2', args.security_report)
        self.avatar = self.input('mainAvatar', args.avatar_report)
        self.runtime = self.input('variantRuntime', args.runtime_report)
        self.hap = sha(HAP)
        self.validate_provenance()
        self.validate_base_business()
        self.optional_inputs = {}
        for key, filename in (('jpegExif6', 'avatar-source-jpeg-exif6.json'),
                              ('webpRgb', 'avatar-source-webp-rgb.json'), ('visualReview', 'visual-review.json')):
            path = OUT / filename
            if path.exists():
                value = self.input(key, path)
                self.optional_inputs[key] = {'file': str(path.relative_to(ROOT)), 'sha256': self.input_shas[key],
                    'status': value.get('status'), 'sameBaseHap': value.get('hap', {}).get('packagedSha256') == self.base_sha,
                    'requiredForThisIndependentScope': False}
        self.password_key = self.s2.get('finalPasswordKey')
        if self.password_key not in ('initialPassword', 'newPassword') or self.avatar.get('finalPasswordKey') != self.password_key:
            raise SafeFailure('The completed base account epoch does not identify one verified password key')
        self.avatar_session_path = checked_path(ROOT / 'artifacts/private/profile-device/avatar-session.json', ROOT / 'artifacts/private', True)
        session = load(self.avatar_session_path)
        if (session.get('ownerSha256') != self.owner or session.get('hapSha256') != self.base_sha or
                session.get('runtimeSha256') != self.base_runtime_sha or session.get('coreSha256') != self.input_shas['core'] or
                session.get('securitySha256') != self.input_shas['s2'] or 'avatar-saved' not in session.get('phases', [])):
            raise SafeFailure('The original native-upload session does not bind this dedicated base account')
        self.frozen_files = {HAP: self.hap, self.archive: self.base_sha,
            self.avatar_session_path: sha(self.avatar_session_path),
            self.config_path: sha(self.config_path), self.ca_path: sha(self.ca_path)}
        self.state_path = checked_path(self.control.state_path, ROOT / 'artifacts/private', True)
        self.frozen_files[self.state_path] = sha(self.state_path)
        for filename in ('device-profile-avatar-late.py', 'device-profile-acceptance.py', 'native_device_ui.py',
                         'isolated_snapshot.py', 'isolated-response-gate.mjs', 'isolated-tls.mjs',
                         'hap_timeout_variant.py'):
            path = ROOT / 'scripts' / filename
            self.frozen_files[path] = sha(path)
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        self.directory = PRIVATE / ('run-' + stamp)
        self.directory.mkdir(parents=True, exist_ok=False, mode=0o700)
        self.directory.chmod(0o700)
        self.ui = LateUI(self.state, self.runtime['window']['density'], self.runtime['window'], self.directory)
        self.gate = Gate(self.state, self.owner, self.directory)
        self.current_avatar, self.race, self.traffic = None, {}, []
        self.initial_rows = self.control.requests()
        self.report('running')

    def input(self, key, path):
        path = checked_path(path, OUT)
        self.inputs[key], self.input_shas[key] = path, sha(path)
        return load(path)

    @staticmethod
    def hap_entries(path):
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            if len(names) != len(set(names)) or any(info.file_size > 30 * 1024 * 1024 for info in archive.infolist()):
                raise SafeFailure('HAP entry structure was invalid')
            return {name: archive.read(name) for name in names if not name.endswith('/')}

    def validate_provenance(self):
        base = self.base_manifest
        if self.hap == self.base_sha:
            raise SafeFailure('This independent driver requires a distinct timeout variant of the explicitly frozen base HAP')
        self.archive = checked_path(ROOT / base['privateArchive'], ROOT / 'artifacts/private', True)
        if sha(self.archive) != self.base_sha:
            raise SafeFailure('The private base signed-HAP archive changed')
        rows = base.get('sourceFiles', [])
        if not isinstance(rows, list) or not rows:
            raise SafeFailure('Frozen base source-file manifest is missing')
        expected = {}
        for row in rows:
            name, value = row.get('file', ''), row.get('sha256', '')
            if (not re.fullmatch(r'entry/src/main/ets/[A-Za-z0-9_./-]+\.(ets|ts)', name) or
                    '..' in Path(name).parts or name in expected or not re.fullmatch(r'[a-f0-9]{64}', value)):
                raise SafeFailure('Frozen source-file manifest contains an invalid entry')
            expected[name] = value
        actual = {str(path.relative_to(ROOT)) for path in (ROOT / 'entry/src/main/ets').rglob('*')
                  if path.is_file() and path.suffix in ('.ets', '.ts')}
        if actual != set(expected):
            raise SafeFailure('Current ArkTS source-file set differs from the frozen base')
        for name, value in expected.items():
            path = checked_path(ROOT / name, ROOT / 'entry/src/main/ets')
            if sha(path) != value:
                raise SafeFailure('Current ArkTS source bytes differ from the frozen base')
        self.source_files = expected
        base_entries, current_entries = self.hap_entries(self.archive), self.hap_entries(HAP)
        abc = {name: digest(value) for name, value in base_entries.items() if name.endswith('.abc')}
        records = base.get('arktsBytecode', [])
        if not records or len(records) != len({row.get('file') for row in records}) or abc != {row.get('file'): row.get('sha256') for row in records}:
            raise SafeFailure('Frozen base ABC entry manifest differs from its archived HAP')
        if {name for name in current_entries if name.endswith('.abc')} != set(abc) or any(
                current_entries[name] != base_entries[name] for name in abc):
            raise SafeFailure('The current variant ABC bytes differ from the frozen base')
        try:
            entry_comparison = validate_timeout_entries(base_entries, current_entries)
        except VariantMismatch as error:
            raise SafeFailure(str(error)) from None
        raw_directory = ROOT / 'entry/src/main/resources/rawfile'
        self.config_path = checked_path(raw_directory / 'integration.json', raw_directory)
        self.ca_path = checked_path(raw_directory / 'integration-ca.pem', raw_directory)
        original, current = json.loads(base_entries[CONFIG_ENTRY]), json.loads(current_entries[CONFIG_ENTRY])
        required = dict(original)
        required['timeoutMs'] = 15000
        if (original != base.get('configuration') or original.get('timeoutMs') != 2000 or current != required or
                current.get('isolated') is not True or current.get('endpoint') != self.state['tls']['base'] or
                self.config_path.read_bytes() != current_entries[CONFIG_ENTRY]):
            raise SafeFailure('Variant configuration must differ only by timeout2000-to15000')
        ca = base_entries.get(CA_ENTRY)
        # A public CA certificate generated by openssl may correctly be0644;
        # credentials/control receipts and avatar bytes still require0600.
        state_ca = checked_path(self.state['tls']['caPath'], ROOT / 'artifacts/private')
        if (not ca or current_entries.get(CA_ENTRY) != ca or self.ca_path.read_bytes() != ca or
                state_ca.read_bytes() != ca or digest(ca) != self.state['tls'].get('caSha256')):
            raise SafeFailure('Base, variant, source resource and actual TLS authority must retain identical CA bytes')
        self.frozen_ca_path = state_ca
        base_runtime = self.base_runtime
        runtime = self.runtime
        if (base_runtime.get('status') != 'passed' or base_runtime.get('installedHapSha256') != self.base_sha or
                runtime.get('status') != 'passed' or runtime.get('installedHapSha256') != self.hap):
            raise SafeFailure('Actual base and variant runtimes must each bind their own signed HAP')
        window = runtime.get('window', {})
        if (not finite(window.get('density')) or window['density'] <= 0 or
                any(not finite(window.get(key)) for key in ('widthPx', 'heightPx', 'fontScale')) or
                any(window.get(key) != base_runtime.get('window', {}).get(key)
                    for key in ('widthPx', 'heightPx', 'density', 'fontScale', 'topInsetPx', 'bottomInsetPx')) or
                any(runtime.get('tls', {}).get(key) is not True
                    for key in ('customCaAccepted', 'untrustedCaRejected', 'wrongHostnameRejected'))):
            raise SafeFailure('The actual variant window/font and strict TLS runtime evidence are incomplete')
        self.provenance = {'basePackagedSha256': self.base_sha, 'variantPackagedSha256': self.hap,
            'sourceFileCount': len(expected), 'sourceFileSetAndSha256Match': True,
            'abcEntries': [{'file': name, 'sha256': value} for name, value in sorted(abc.items())],
            'abcBytesIdentical': True, **entry_comparison,
            'baseTimeoutMs': 2000, 'variantTimeoutMs': 15000, 'caSha256': digest(ca), 'caBytesIdentical': True,
            'provenanceHelperSha256': sha(ROOT / 'scripts/hap_timeout_variant.py')}

    def validate_base_business(self):
        for name, value in (('core', self.core), ('S2', self.s2), ('main avatar', self.avatar)):
            if (value.get('status') != 'passed' or value.get('hap', {}).get('packagedSha256') != self.base_sha or
                    value.get('runtime', {}).get('sha256') != self.base_runtime_sha):
                raise SafeFailure('Complete the current same-base-HAP/runtime ' + name + ' prerequisite first')
        if (any(not all(value.get('cleanup', {}).get(key) is True for key in ('loggedOut', 'faultNeutralised'))
                for value in (self.core, self.s2)) or
                self.s2.get('corePrerequisite', {}).get('sha256') != self.input_shas['core'] or
                self.avatar.get('corePrerequisite', {}).get('sha256') != self.input_shas['core'] or
                self.avatar.get('securityPrerequisiteSha256') != self.input_shas['s2']):
            raise SafeFailure('The completed base prerequisites do not share one clean account epoch')
        required = {'avatar-saved', 'recovery-and-logout', 'decode-corrupt-restored', 'visual-reviewed'}
        fault = self.avatar.get('injectedStorageFault', {})
        if (not required.issubset(self.avatar.get('phases', [])) or fault.get('restored') is not True or
                fault.get('cleanupLoggedOut') is not True or fault.get('restoredSha256') != fault.get('originalSha256')):
            raise SafeFailure('Complete base avatar upload/recovery/restoration and ordinary logout first')

    def immutable(self):
        current_set = {str(path.relative_to(ROOT)) for path in (ROOT / 'entry/src/main/ets').rglob('*')
                       if path.is_file() and path.suffix in ('.ets', '.ts')}
        if (any(sha(path) != value for path, value in self.frozen_files.items()) or any(
                sha(path) != self.input_shas[key] for key, path in self.inputs.items()) or any(
                sha(ROOT / name) != value for name, value in self.source_files.items()) or
                current_set != set(self.source_files) or
                sha(self.frozen_ca_path) != self.provenance['caSha256']):
            raise SafeFailure('A frozen source, HAP, runtime, private account epoch or helper changed during this run')

    def report(self, status, error=None):
        gate_row = (Gate.public_ledger(self.gate.last) if self.gate.last and self.gate.gate_id and
                    self.gate.last.get('gateId') == self.gate.gate_id else None)
        value = {'status': status, 'scope': 'Independent actual late protected-avatar response after native logout on the15000ms private integration variant',
            'startedAt': self.started_at, 'updatedAt': now(), 'environment': 'Dedicated real PocketBase over strict USB HTTPS; controlled real-response holding',
            'base2000msLateResponseAccepted': False, 'productionFault': False,
            'injectedTransportGate': True, 'hap': {'packagedSha256': self.hap}, 'provenance': self.provenance,
            'prerequisites': {key: {'file': str(path.relative_to(ROOT)), 'sha256': self.input_shas[key]} for key, path in self.inputs.items()},
            'optionalIndependentEvidence': self.optional_inputs, 'count': len(self.checks), 'checks': self.checks,
            'currentOwnedAvatar': ({key: self.current_avatar[key] for key in ('sha256', 'bytes', 'contentType')} if self.current_avatar else None),
            'gate': {'receiptSha256': self.gate.receipt_sha, 'instanceId': self.gate.instance,
                'manifestVersion': self.gate.manifest['version'], 'ledger': gate_row,
                'finishMeaning': 'Node TLS downstream response finish/flush; native image decoding is not acknowledged by this event'},
            'lateResponse': self.race, 'requestStructureCounts': self.traffic, 'cleanup': self.cleanup,
            'businessWritesObserved': self.write_delta, 'privateOriginals': str(self.directory.relative_to(ROOT)),
            'privateScreenshots': self.ui.private_screenshots,
            'observations': self.observations,
            'notExecuted': ['The2000ms base HAP late-response race is not accepted by this variant run',
                'Actual switching to another credentialed account during a protected-file request is outside this run',
                'The transport finish event is not a native image-decode callback or a pixel-identity assertion',
                'Foldable, hover and split-window scenarios remain deferred']}
        if error:
            value['error'] = error if isinstance(error, str) else 'Independent late-response acceptance did not complete'
        OUT.mkdir(parents=True, exist_ok=True)
        if REPORT.is_symlink():
            raise SafeFailure('The independent public report cannot be a symlink')
        REPORT.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
        private_write(self.directory / 'run-report.json', value)

    @property
    def write_delta(self):
        return getattr(self, 'writes_observed', None)

    def check(self, condition, label):
        if not condition:
            raise SafeFailure('Independent late-response expectation did not hold: ' + label)
        self.checks.append({'case': 'A4-late-15000ms-variant', 'label': label})
        self.report('running')
        print(json.dumps({'count': len(self.checks), 'passed': label}, ensure_ascii=False), flush=True)

    @staticmethod
    def mutation_rows(rows):
        return [row for row in rows if row.get('method') in ('POST', 'PATCH', 'PUT', 'DELETE') and
                row.get('path') not in (AUTH, TOKEN)]

    def file_rows(self, path):
        return [row for row in self.control.requests() if row.get('method') == 'GET' and row.get('path') == path]

    def read_owned_avatar(self):
        current = self.gate.status()
        if current and current['state'] not in ('finished', 'failed'):
            raise SafeFailure('A response gate is active before the Host read-only ownership probe')
        snapshot = ReadonlySnapshot(self.state)
        try:
            snapshot.login(self.state[self.password_key])
            player = snapshot.request(ME)
            filename = player.get('avatar', '')
            if (player.get('id') != self.state['playerId'] or player.get('account') != self.state['account'] or
                    player.get('mustChangePassword') is not False or
                    not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,199}', filename)):
                raise SafeFailure('The current real me DTO does not own one valid uploaded avatar')
            path = '/api/files/game_players/' + self.state['playerId'] + '/' + urllib.parse.quote(filename, safe='')
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect(),
                urllib.request.HTTPSHandler(context=ssl.create_default_context(cafile=self.state['tls']['caPath'])))
            request = urllib.request.Request(self.state['tls']['hostBase'] + TOKEN, data=b'{}', method='POST',
                headers={'Authorization': snapshot.token, 'Content-Type': 'application/json'})
            with opener.open(request, timeout=15) as response:
                token_body = response.read(65537)
                if response.status != 200 or len(token_body) > 65536:
                    raise SafeFailure('The owned file-token read did not succeed')
                file_token = json.loads(token_body).get('token')
            if not isinstance(file_token, str) or not file_token:
                raise SafeFailure('The owned file-token read returned no token')
            request = urllib.request.Request(self.state['tls']['hostBase'] + path + '?token=' + urllib.parse.quote(file_token, safe=''))
            with opener.open(request, timeout=15) as response:
                body = response.read(200 * 1024 + 1)
                content_type = response.headers.get_content_type()
                if response.status != 200 or content_type != 'image/jpeg' or not body or len(body) > 200 * 1024:
                    raise SafeFailure('The current real owned avatar readback was not the expected bounded JPEG')
        except SafeFailure:
            raise
        except Exception:
            raise SafeFailure('The current owned avatar HTTPS read failed; credentials and addresses omitted') from None
        finally:
            snapshot.token = ''
        self.ui.secrets.extend([player.get('displayName', ''), filename])
        private_write(self.directory / 'current-player.json', player)
        private_write(self.directory / 'current-avatar.jpg', body, True)
        result = {'path': path, 'sha256': digest(body), 'bytes': len(body), 'contentType': content_type,
                  'displayName': player.get('displayName', '')}
        private_write(self.directory / 'current-owned-avatar.json', result)
        return result

    def blank(self, phase, capture=True):
        if capture:
            self.ui.capture(phase)
        account, password = self.ui.find('account'), self.ui.find('password')
        absent = all(self.ui.find(key) is None for key in AUTHENTICATED_IDS)
        private_texts = (self.state['account'], (self.current_avatar or {}).get('displayName', ''))
        private_text_absent = all(not text or text not in self.ui.texts() for text in private_texts)
        if (not account or not password or account.get('text', '') or password.get('text', '') or
                self.ui.find('primary-action') is None or not absent or not private_text_absent):
            raise SafeFailure('Native UI did not expose empty login without authenticated avatar/profile/menu content')
        self.observations.append({'phase': phase, 'observedAt': now(), 'emptyLoginInputs': True,
            'authenticatedRouteAndAvatarContainersAbsent': True, 'privatePlayerTextAbsent': True})
        return True

    @staticmethod
    def point(node):
        left, top, right, bottom = node['bounds']
        return [int((left + right) / 2), int((top + bottom) / 2)]

    def prepare_login(self):
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state[self.password_key])
        return self.point(self.ui.seek('primary-action'))

    def calibrate(self):
        before = len(self.file_rows(self.current_avatar['path']))
        self.prepare_login()
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'variant calibration home')
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            rows = self.file_rows(self.current_avatar['path'])[before:]
            if rows and rows[0].get('status'):
                break
            time.sleep(.1)
        else:
            raise SafeFailure('The actual variant calibration avatar request did not finish')
        self.check(len(rows) == 1 and rows[0].get('status') == 200 and not rows[0].get('fault') and
                   rows[0].get('fileTokenProvided') is True,
                   'The same installed15000ms variant first completes a normal native owned-avatar GET200')
        menu = self.ui.seek('account-menu')
        menu_bounds = list(menu['bounds'])
        menu_point = self.point(menu)
        self.ui.tap('account-menu')
        self.ui.menu_scrolling, self.ui.recorded_swipes = True, []
        try:
            logout = self.ui.seek('logout')
            logout_point = self.point(logout)
            swipes = list(self.ui.recorded_swipes)
            self.ui.capture('calibrated-logout')
        finally:
            self.ui.recorded_swipes = None
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', *logout_point)
        self.ui.menu_scrolling = False
        self.ui.wait(lambda ui: ui.find('account') is not None, 'variant calibration explicit logout')
        self.blank('after-calibration-logout')
        geometry = {'hapSha256': self.hap, 'runtimeSha256': self.input_shas['variantRuntime'],
            'menuBoundsPx': menu_bounds, 'menuPointPx': menu_point, 'logoutPointPx': logout_point,
            'swipes': swipes, 'command': 'official hdc shell uitest uiInput, calibrated and replayed identically'}
        private_write(self.directory / 'native-calibration.json', geometry)
        self.check(True, 'Native menu and reachable logout geometry/swipes are calibrated and actually log out on this same variant')
        return geometry

    def collect_traffic(self):
        rows = self.control.requests()
        self.writes_observed = len(self.mutation_rows(rows)) - len(self.mutation_rows(self.initial_rows))
        counts = {}
        for row in rows[len(self.initial_rows):]:
            path = row.get('path', '')
            if path.startswith('/api/files/game_players/'):
                path = '/api/files/game_players/[owner]/[current-avatar]'
            elif re.fullmatch(r'/api/questions/v1/assignments/[a-z0-9]{15}', path):
                path = '/api/questions/v1/assignments/[fixture]'
            elif path not in (AUTH, ME, TOKEN, PROFILE, CHANGE, '/api/questions/v1/assignments', '/api/health'):
                path = '[other route omitted]'
            key = (row.get('method'), path, row.get('status'), bool(row.get('fault')),
                   bool(row.get('bearer')), bool(row.get('fileTokenProvided')))
            counts[key] = counts.get(key, 0) + 1
        self.traffic = [{'method': key[0], 'route': key[1], 'status': key[2], 'fault': key[3],
            'bearer': key[4], 'fileTokenProvided': key[5], 'count': count} for key, count in counts.items()]
        return rows

    def experiment(self, geometry):
        latest = self.read_owned_avatar()
        if any(latest[key] != self.current_avatar[key] for key in ('path', 'sha256', 'bytes', 'displayName')):
            raise SafeFailure('The owned avatar identity/bytes changed between calibration and arm')
        login_point = self.prepare_login()
        self.immutable()
        ledger_start = len(self.control.requests())
        self.race = {'executed': True, 'appTimeoutMs': 15000, 'gateTtlMs': 14000,
            'calibratedMenuSwipes': len(geometry['swipes']), 'sameVariantNativeCalibration': True,
            'original200BodySha256Held': False, 'emptyLoginObservedWhileHeld': False,
            'downstreamFinishedWithoutAbort': False, 'emptyAfterResponseBackAndRelaunch': False}
        self.gate.arm(self.current_avatar['path'], self.current_avatar['sha256'])
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', *login_point)
        held = self.gate.await_state('held', 12)
        if (not held.get('bodySha256Matched') or not held.get('requestReceived') or not held.get('held') or
                held.get('released') or held.get('downstreamFinished') or held.get('failed') or held.get('clientAborted')):
            raise SafeFailure('The gate did not hold the exact original real200 body before any downstream release')
        self.race['original200BodySha256Held'] = True
        self.ui.capture('authenticated-while-avatar-held')
        menu = self.ui.find('account-menu')
        if (self.ui.find('current-tab') is None or menu is None or
                any(abs(a - b) > 1 for a, b in zip(menu.get('bounds', []), geometry['menuBoundsPx'])) or
                len(menu.get('bounds', [])) != 4):
            raise SafeFailure('The held-response native home/menu does not match its calibrated geometry')
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', *geometry['menuPointPx'])
        for points in geometry['swipes']:
            self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'swipe', *points)
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', *geometry['logoutPointPx'])
        self.blank('empty-login-before-gate-release')
        before_release = self.gate.status()
        if (before_release['state'] != 'held' or not before_release.get('bodySha256Matched') or
                before_release.get('released') or before_release.get('downstreamFinished') or
                before_release.get('failed') or before_release.get('clientAborted')):
            raise SafeFailure('The real response was no longer held when native empty login was observed')
        self.race['emptyLoginObservedWhileHeld'] = True
        self.race['emptyLoginObservedAt'] = now()
        released = self.gate.call('/release', {'gateId': self.gate.gate_id})
        if released.get('gateId') != self.gate.gate_id:
            raise SafeFailure('Response-gate release did not acknowledge this exact request')
        finished = self.gate.await_state('finished', 5)
        ordered = [finished.get(key) for key in ('armed', 'requestReceived', 'held', 'released', 'downstreamFinished')]
        if (any(event is None for event in ordered) or
                [event['elapsedMs'] for event in ordered] != sorted(event['elapsedMs'] for event in ordered) or
                finished.get('failed') or finished.get('clientAborted') or not finished.get('bodySha256Matched')):
            raise SafeFailure('The real held response did not finish after release without a client abort')
        self.race['downstreamFinishedWithoutAbort'] = True
        self.check(True, 'Actual native empty login is observed before release of the SHA-matched real200 body, followed by downstream finish without client abort')
        rows = self.control.requests()[ledger_start:]
        files = [row for row in rows if row.get('path') == self.current_avatar['path'] and row.get('method') == 'GET']
        tokens = [row for row in rows if row.get('path') == TOKEN and row.get('method') == 'POST']
        self.check(len(files) == 1 and files[0].get('status') == 200 and files[0].get('fileTokenProvided') is True and
                   not files[0].get('fault') and not files[0].get('bearer') and
                   any(row.get('status') == 200 and row.get('authenticated') is True and not row.get('bearer') for row in tokens),
                   'The gated experiment contains one real native protected-file GET200 and authenticated nonBearer file-token traffic, with no Host file read after arm')
        self.race['nativeTraffic'] = {'protectedGetCount': len(files), 'fileTokenPostCount': len(tokens), 'hostFileReadsAfterArm': 0}
        self.blank('after-downstream-finish')
        self.ui.private_shot('late-after-real-response')
        time.sleep(.35)
        self.blank('after-response-stable')
        self.ui.back()
        self.ui.launch()
        self.ui.wait(lambda ui: ui.find('account') is not None, 'late response Back and Ability relaunch')
        self.blank('after-back-and-ability-relaunch')
        self.ui.private_shot('late-after-back-and-relaunch')
        self.ui.launch(cold=True)
        self.ui.wait(lambda ui: ui.find('account') is not None, 'late response cold Ability boundary')
        self.blank('after-cold-relaunch')
        self.ui.private_shot('late-after-cold-relaunch')
        self.race['emptyAfterResponseBackAndRelaunch'] = True
        self.cleanup['backAndRelaunchEmpty'] = True
        self.check(True, 'After the actual response finishes, native UI, OS Back/Ability relaunch and cold launch remain at empty login with authenticated avatar/profile/menu containers absent')

    def ui_cleanup(self):
        self.ui.capture()
        if self.ui.find('account') is None:
            menu_open = any(self.ui.find(key) is not None for key in (*MENU_IDS, 'logout')) or self.ui.has_text('冒险者菜单')
            if not menu_open:
                self.ui.tap('account-menu')
            self.ui.menu_scrolling = True
            try:
                self.ui.tap('logout')
            finally:
                self.ui.menu_scrolling = False
            self.ui.wait(lambda ui: ui.find('account') is not None, 'independent late-response cleanup logout')
        for key in ('account', 'password'):
            node = self.ui.find(key)
            if node and node.get('text', ''):
                self.ui.fill(key, '')
        self.blank('final-empty-login')
        self.cleanup['loggedOut'], self.cleanup['emptyLoginInputs'] = True, True

    def run(self):
        failure = None
        previous_handlers = {}
        def interrupted(signum, frame):
            raise SafeFailure('Independent late-response run interrupted; only its exact gate will be cancelled')
        try:
            for number in (signal.SIGINT, signal.SIGTERM):
                previous_handlers[number] = signal.getsignal(number)
                signal.signal(number, interrupted)
            self.ui.launch()
            self.blank('pre-existing-empty-login')
            self.ready = True
            self.current_avatar = self.read_owned_avatar()
            self.check(True, 'Fresh authenticated read-only me/file-token/file reads establish this dedicated player current owned avatar and exact original-body SHA')
            geometry = self.calibrate()
            self.experiment(geometry)
        except Exception as error:
            failure = str(error) if isinstance(error, SafeFailure) else 'Independent late-response run stopped before completing acceptance'
        finally:
            for number in previous_handlers:
                signal.signal(number, signal.SIG_IGN)
            try:
                self.cleanup['ownGateNeutralised'] = self.gate.neutralise()
            except Exception:
                failure = failure or 'This run exact response gate could not be neutralised'
            if self.ready:
                try:
                    self.ui_cleanup()
                except Exception:
                    failure = failure or 'Independent late-response explicit empty-login cleanup did not finish'
            try:
                self.collect_traffic()
                self.cleanup['noBusinessWrites'] = self.write_delta == 0
                self.immutable()
                if not failure and (not all(self.cleanup.values()) or len(self.checks) != 6 or
                                    not self.race.get('emptyAfterResponseBackAndRelaunch')):
                    failure = 'Independent late-response coverage or its no-write cleanup is incomplete'
            except Exception:
                failure = failure or 'Independent late-response provenance/write-boundary verification did not finish'
            try:
                self.report('incomplete' if failure else 'passed', failure)
            finally:
                for number, handler in previous_handlers.items():
                    signal.signal(number, handler)
        print(json.dumps({'status': 'incomplete' if failure else 'passed', 'scope': 'Independent15000ms timeout variant only',
            'count': len(self.checks), 'report': str(REPORT.relative_to(ROOT)), 'cleanup': self.cleanup,
            'base2000msLateResponseAccepted': False}, ensure_ascii=False))
        return 1 if failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--runtime-report', type=Path, required=True, help='Actual newly installed15000ms variant runtime report')
    parser.add_argument('--base-hap-manifest', '--base-hap-report', dest='base_hap_manifest', type=Path,
                        default=OUT / 'base-hap.json', help='Explicit frozen base HAP/source/ABC/configuration and private archive manifest')
    parser.add_argument('--base-runtime-report', type=Path,
                        help='Defaults to passed core.runtime.file; any explicit file must match core.runtime.sha256')
    parser.add_argument('--core-report', type=Path, default=OUT / 'device-profile-acceptance.json')
    parser.add_argument('--security-report', type=Path, default=OUT / 'device-profile-password-uncertain.json')
    parser.add_argument('--avatar-report', type=Path, default=OUT / 'device-profile-avatar.json')
    args = parser.parse_args()
    try:
        return Acceptance(args).run()
    except Exception as error:
        message = str(error) if isinstance(error, SafeFailure) else 'Independent late-response setup stopped before acceptance'
        print(json.dumps({'status': 'incomplete', 'scope': 'Independent15000ms variant setup', 'error': message,
                          'base2000msLateResponseAccepted': False}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

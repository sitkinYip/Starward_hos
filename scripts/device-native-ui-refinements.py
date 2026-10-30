#!/usr/bin/env python3
"""New-phone checks for the reviewed native-UI patch; never inherit old UI checks.

Root alone owns the phone and disposable HTTPS environment. Run after applying
the private UI patch, official build/install, and a fresh six-check runtime:

  run --runtime-report <new.json> --patch-manifest <private draft/manifest.json>
  drag-begin <same arguments>
  drag <same arguments> --direction home-to-profile
  drag <same arguments> --direction profile-to-home
  drag <same arguments> --gesture-kind drag --direction home-to-profile
  drag <same arguments> --gesture-kind drag --direction profile-to-home
  drag-finish <same arguments>

The optional drag stages separately record official swipe/drag commands and the
actual native callbacks/destination. Default kind is swipe. Official drag uses
its native default press duration; the CLI offers no duration argument. Neither
kind requires a destination change, invents product hit testing, or concludes
that manual system drag-selection is supported. Root
reviews the private originals separately. `cleanup` retries guarded main cleanup
after an incomplete run; `drag-cleanup` does the same for an incomplete drag
stage. Neither command promotes failed checks or rewrites a passed main run.

Only the original generated hm_ player is allowed, using the passed S2 password
key and a new strict-HTTPS identity read. No preview account, profile PATCH,
password POST, service reset, Picker operation or production traffic exists.
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
import subprocess
import time
import uuid
import zipfile

from isolated_snapshot import ReadonlySnapshot
from native_device_ui import ROOT, IsolationControl, SafeFailure, flatten

SPEC = importlib.util.spec_from_file_location('native_refinement_core',
    Path(__file__).with_name('device-profile-acceptance.py'))
CORE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CORE)
OUT = ROOT / 'artifacts/validation/profile'
PRIVATE = ROOT / 'artifacts/private/native-ui-refinements'
REPORT = OUT / 'device-native-ui-refinements.json'
DRAG_REPORT = OUT / 'native-ui-refinements-drag.json'
HAP = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
MAIN_IDS = ('nav-home', 'nav-rewards', 'nav-notifications', 'nav-profile')
PASSWORD_IDS = ('security-old-password', 'security-new-password', 'security-confirm-password')
PROBES = ('UI-Only-Old-Probe', 'UI-Only-New-Probe', 'UI-Only-New-Probe')
UI_FILES = frozenset(('entry/src/main/ets/pages/Index.ets',
    'entry/src/main/ets/ui/StarwardTabs.ets', 'entry/src/main/ets/ui/StarwardMaterial.ets'))
SIDE_PANEL_FILE = 'entry/src/main/ets/ui/StarwardSidePanel.ets'
PANEL_ID = 'account-side-panel'
PANEL_CLOSE_ID = 'account-close'
PANEL_SCROLL_ID = 'account-menu-scroll'
RUNTIME_CHECKS = ('actualWindowReported', 'actualImmersiveWindow', 'transparentSystemBars',
    'requestedFontScaleReported', 'threeIndependentTlsCases', 'actualLightAndDarkBarContent')


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise SafeFailure(message)


def checked(path, directory, existing=True):
    path = Path(path).absolute()
    target = path.resolve()
    require(target.is_relative_to(directory.resolve()) and not path.is_symlink(),
            'Evidence must stay in its intended project directory')
    for parent in path.parents:
        require(not parent.is_symlink(), 'Evidence parent symlinks are not allowed')
        if parent == ROOT:
            break
    require(not existing or target.is_file(), 'Required evidence is not a regular file')
    return target


def load(path):
    try:
        value = json.loads(Path(path).read_text())
    except Exception:
        raise SafeFailure('A required evidence JSON could not be read') from None
    require(isinstance(value, dict), 'A required evidence object is not a JSON object')
    return value


def write(path, value, private=False):
    require(not path.is_symlink(), 'Evidence output symlinks are not allowed')
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700 if private else 0o755)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW,
                 0o600 if private else 0o644)
    with os.fdopen(fd, 'w') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    path.chmod(0o600 if private else 0o644)


def rows(value):
    if isinstance(value, list):
        for child in value:
            yield from rows(child)
    elif isinstance(value, dict):
        if isinstance(value.get('attributes'), dict):
            yield value['attributes']
        yield from rows(value.get('children', []))


def rect(value):
    if isinstance(value, list) and len(value) == 4 and all(isinstance(v, (int, float)) for v in value):
        return list(value)
    numbers = re.findall(r'-?\d+', value) if isinstance(value, str) else []
    require(len(numbers) == 4, 'An actual UI rectangle is unavailable')
    return [int(v) for v in numbers]


def positive(bounds):
    return bounds[2] > bounds[0] and bounds[3] > bounds[1]


def inside(bounds, viewport, tolerance=0):
    return (bounds[0] >= viewport[0] - tolerance and bounds[1] >= viewport[1] - tolerance and
            bounds[2] <= viewport[2] + tolerance and bounds[3] <= viewport[3] + tolerance)


def exposed(row):
    return row.get('visible') == 'true' and positive(rect(row.get('bounds')))


class RefinementUI(CORE.ProfileUI):
    """Keep originals private; inspect actual IME geometry rather than a screen size."""
    def __init__(self, state, density, directory, side_panel=False):
        super().__init__(state, density)
        self.output = directory
        self.shots = directory
        self.secret_literals = [state.get(k, '') for k in ('initialPassword', 'newPassword', 'controlToken')]
        self.private_trees = []
        self.ime_evidence = []
        self.raw_evidence = []
        self.remote_cleanup_ok = True
        self.ime_bottom = None
        self.main_bar_hidden_observed = False
        self.side_panel = side_panel

    def minimum_height(self, node_id, node):
        if node_id in ('profile-save', 'security-save'):
            return 52 * self.density - 2
        return super().minimum_height(node_id, node)

    def persist_raw(self, path, raw):
        # The actual credentials must remain absent even from private UI files.
        require(not any(value and value in raw for value in self.secret_literals),
                'Sensitive credential text was not persisted')
        value = json.loads(raw)
        require(not path.is_symlink(), 'A private raw-output symlink is not allowed')
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'w') as stream:
            stream.write(raw)
        path.chmod(0o600)
        return value

    def capture(self, name=None):
        # An official custom Dialog can own the focused window, so its visible
        # identifiers must be accepted without relying on a background page.
        known = {'environment-badge', 'account', 'password', 'old-password', 'new-password', 'confirm-password',
            'primary-action', 'account-menu', 'start-assignment', 'return-home', 'forced-logout', 'logout',
            'error-return-home', 'profile-scroll', 'profile-name', 'security-old-password',
            'security-new-password', 'security-confirm-password'}
        # A transient focused system Toast can hide the own-App CLI tree. Wait
        # read-only for its real markers to return; never accept the Toast, send
        # input to an unknown window, or persist its contents. Clear stale UI so
        # a failed wait cannot leave a previously recognised page usable.
        self.tree, self.flat, self.width, self.height = None, [], 0, 0
        deadline = time.monotonic() + 10
        while True:
            remaining = deadline - time.monotonic()
            require(remaining > 0,
                    'Expected own App or its reviewed Dialog is not foreground; other apps were not touched')
            raw = self.run('devecocli', 'ui', 'layout', '--format', 'json', '--mode', 'full', timeout=remaining)
            try:
                candidate = json.loads(raw)
            except ValueError:
                raise SafeFailure('Official own-App UI dump was not valid JSON') from None
            candidate_flat = flatten(candidate)
            # The reviewed host deliberately clears private content before a
            # native close completes; its unique root can be the only marker.
            panel_owned = self.side_panel and any(node.get('id') == PANEL_ID and node.get('bounds')
                for node in candidate_flat)
            if panel_owned or any(node.get('id') in known or node.get('text') == 'QUEST SESSION'
                                  for node in candidate_flat):
                self.tree, self.flat = candidate, candidate_flat
                break
            remaining = deadline - time.monotonic()
            require(remaining > 0,
                    'Expected own App or its reviewed Dialog is not foreground; other apps were not touched')
            time.sleep(min(.35, remaining))
        roots = self.tree if isinstance(self.tree, list) else [self.tree]
        bounds = next((rect(node['bounds']) for node in roots if node.get('bounds')), None)
        require(bounds is not None and positive(bounds), 'Actual own-App root bounds are unavailable')
        self.width, self.height = bounds[2] - bounds[0], bounds[3] - bounds[1]
        if name:
            path = self.output / ('ui-' + name + '-' + uuid.uuid4().hex + '.json')
            self.persist_raw(path, json.dumps(self.tree, ensure_ascii=False))
            self.private_trees.append({'file': str(path.relative_to(ROOT)), 'sha256': sha(path),
                'source': 'Official CLI full tree; input credential literals checked absent'})
        return self.flat

    def windows(self):
        raw = self.run('devecocli', 'ui', 'window', 'list', '--all', '--format', 'json')
        try:
            value = json.loads(raw)
            result = value if isinstance(value, list) else value['windows']
            require(isinstance(result, list) and result, 'Official window inventory is empty')
            return result, raw
        except (ValueError, KeyError, TypeError):
            raise SafeFailure('Official window inventory was not valid JSON') from None

    def keyboard_windows(self):
        windows, _ = self.windows()
        return [item for item in windows if any(part in str(item.get('name', '')).lower()
                for part in ('inputmethod', 'input_method', 'keyboard', 'hmosime'))]

    def keyboard_visible(self):
        # Do not convert a tool failure into a false keyboard result.
        return bool(self.keyboard_windows())

    def actual_ime(self, label):
        self.main_bar_hidden_observed = False
        self.capture()
        app = self.app_rect()
        windows, raw = self.windows()
        candidates = [item for item in windows if any(part in str(item.get('name', '')).lower()
            for part in ('inputmethod', 'input_method', 'keyboard', 'hmosime'))]
        require(len(candidates) == 1, 'Exactly one actual IME window is required for this straight-phone check')
        window_id = str(candidates[0].get('id', ''))
        require(re.fullmatch(r'\d+', window_id) is not None, 'The observed IME window id is invalid')
        # Read the observed system IME root only, without key/suggestion subtrees.
        layout = self.run('devecocli', 'ui', 'layout', '--window', window_id,
                          '--format', 'json', '--mode', 'full', '--depth', '1')
        data = json.loads(layout)
        roots = data if isinstance(data, list) else [data]
        bounds = [rect(item.get('bounds')) for item in roots if item.get('bounds')]
        require(len(bounds) == 1, 'An unambiguous actual IME root rectangle is required')
        box = bounds[0]
        require(positive(box) and box[1] > app[1] and box[3] - box[1] < self.height * .85 and
                box[2] - box[0] >= (app[2] - app[0]) * .5,
                'A full-screen or ambiguous rectangle cannot stand in for the actual IME viewport')
        self.ime_bottom = box[1]
        windows_path = self.output / ('windows-' + label + '-' + uuid.uuid4().hex + '.json')
        ime_path = self.output / ('ime-root-' + label + '-' + uuid.uuid4().hex + '.json')
        self.persist_raw(windows_path, raw)
        self.persist_raw(ime_path, layout)
        record = {'label': label, 'boundsPx': box, 'heightVp': (box[3] - box[1]) / self.density,
            'source': 'Actual named IME window from official CLI inventory, root-only layout',
            'privateInventory': {'file': str(windows_path.relative_to(ROOT)), 'sha256': sha(windows_path)},
            'privateRoot': {'file': str(ime_path.relative_to(ROOT)), 'sha256': sha(ime_path)}}
        self.ime_evidence.append(record)
        self.capture()
        return record

    def viewport(self, node_id=None):
        # A hidden native bar may remain in a CLI tree with original bounds.
        # Bypass the old bar clipping only after its raw hidden state is observed.
        bounds = (CORE.DeviceUI.viewport(self, node_id) if self.ime_bottom is not None and
                  self.main_bar_hidden_observed else super().viewport(node_id))
        if self.ime_bottom is not None:
            bounds[3] = min(bounds[3], self.ime_bottom)
        elif any(node.get('id') in ('current-scroll', 'history-scroll')
                 for node in self.path_to(node_id) or []):
            bar_path = self.path_to('nav-home')
            bar = next((node for node in reversed(bar_path or [])
                        if node.get('type') == 'TabBar' and node.get('bounds')), None)
            if bar and bounds[1] < bar['bounds'][1] < bounds[3]:
                bounds[3] = bar['bounds'][1]
        return bounds

    def hide_keyboard(self):
        # Refuse to send Back to another foreground app or a system screen.
        self.capture()
        super().hide_keyboard()
        self.ime_bottom = None
        self.main_bar_hidden_observed = False

    def swipe(self, direction):
        self.capture()
        menu = self.find(PANEL_SCROLL_ID) if self.side_panel else None
        menu = menu or next((n for target in ('theme-picker', 'logout', 'menu-home')
                     for n in reversed(self.path_to(target) or [])
                     if n.get('type') == 'Scroll' and n.get('bounds')), None)
        bounds = menu['bounds'] if menu else self.viewport('profile-scroll' if self.find('profile-scroll') else None)
        left, top, right, bottom = bounds
        require(right - left > 80 and bottom - top > 150, 'The actual scroll viewport is too small')
        x = int(left + (right - left) * .58)
        low, high = int(top + (bottom - top) * .76), int(top + (bottom - top) * .30)
        start, end = (low, high) if direction == 'down' else (high, low)
        self.run('devecocli', 'ui', 'swipe', x, start, x, end)

    def raw_app(self, label):
        self.capture()
        remote = '/data/local/tmp/starward_ui_refinement_' + uuid.uuid4().hex + '.json'
        path = self.output / ('raw-' + label + '-' + uuid.uuid4().hex + '.json')
        received = self.output / ('.received-' + uuid.uuid4().hex + '.json')
        record = {'label': label, 'source': 'Official bundle-scoped HDC UiTest raw dumpLayout',
                  'file': str(path.relative_to(ROOT)), 'remoteRemoved': False}
        try:
            self.run('hdc', 'shell', 'uitest', 'dumpLayout', '-b', 'com.sitkin.starward', '-p', remote)
            # A private directory and precreated0600 receive target prevent broad permissions.
            fd = os.open(received, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            os.close(fd)
            self.run('hdc', 'file', 'recv', remote, received)
            received.chmod(0o600)
            data = self.persist_raw(path, received.read_text())
            record['sha256'] = sha(path)
            return list(rows(data)), record
        finally:
            received.unlink(missing_ok=True)
            try:
                self.run('hdc', 'shell', 'rm', '-f', remote)
                record['remoteRemoved'] = True
            except Exception:
                self.remote_cleanup_ok = False
                raise
            finally:
                self.raw_evidence.append(record)

    def fill_without_dismiss(self, node_id, value):
        self.hide_keyboard()
        self.seek(node_id)
        self.run('devecocli', 'ui', 'click', '--id', node_id)
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017')
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', '2055')
        self.capture()
        require(self.find(node_id) is not None and not self.find(node_id).get('text', ''),
                'Official field clearing was not verified')
        if value:
            self.run('hdc', 'shell', 'uitest uiInput text ' + shlex.quote(value))
        self.capture()
        require(self.find(node_id) is not None and self.find(node_id).get('text') == value,
                'The nickname probe was not present after actual input')


class Acceptance:
    def __init__(self, args):
        self.args = args
        self.control = IsolationControl()
        self.state = self.control.state
        self.runtime_path = checked(args.runtime_report, OUT)
        self.base_path = checked(args.base_hap_manifest, OUT)
        self.patch_manifest_path = checked(args.patch_manifest, ROOT / 'artifacts/private')
        self.core_path = checked(args.core_report, OUT)
        self.s2_path = checked(args.security_report, OUT)
        self.patch_manifest = load(self.patch_manifest_path)
        self.hap = sha(HAP)
        self.runtime = load(self.runtime_path)
        self.base = load(self.base_path)
        self.core, self.s2 = load(self.core_path), load(self.s2_path)
        self.validate_sources()
        window = self.runtime.get('window', {})
        density = window.get('density')
        require(self.runtime.get('status') == 'passed' and self.runtime.get('installedHapSha256') == self.hap and
                self.hap != self.base.get('hapSha256') and
                all(self.runtime.get('checks', {}).get(k) is True for k in RUNTIME_CHECKS) and
                isinstance(density, (int, float)) and not isinstance(density, bool) and math.isfinite(density) and density > 0,
                'A new installed-HAP six-check runtime is required; base UI checks cannot be inherited')
        require(window.get('fontScale') == self.local_configuration.get('fontScale') == 1 and
                isinstance(window.get('widthPx'), (int, float)) and isinstance(window.get('heightPx'), (int, float)) and
                320 <= window['widthPx'] / density < 600 and window['heightPx'] > window['widthPx'],
                'This run covers the actual portrait straight-phone font1 window only')
        for old in (self.core, self.s2):
            require(old.get('status') == 'passed' and old.get('count', 0) > 0 and
                    old.get('hap', {}).get('packagedSha256') == self.base['hapSha256'] and
                    old.get('cleanup', {}).get('loggedOut') is True and
                    old.get('cleanup', {}).get('faultNeutralised') is True,
                    'Old reports may supply only a completed base account/password epoch')
        require(self.s2.get('corePrerequisite', {}).get('sha256') == sha(self.core_path) and
                self.s2.get('finalPasswordKey') == 'newPassword' and
                self.state.get('account', '').startswith('hm_') and
                isinstance(self.state.get('newPassword'), str) and self.state['newPassword'],
                'Only the original generated S2 new-password player is allowed')
        self.owner = hashlib.sha256((self.state['account'] + self.state['playerId'] + self.state['controlBase']).encode()).hexdigest()
        self.epoch_path = checked(args.account_epoch_receipt, ROOT / 'artifacts/private')
        epoch = load(self.epoch_path)
        require(epoch.get('ownerSha256') == self.owner and epoch.get('hapSha256') == self.base['hapSha256'] and
                epoch.get('coreSha256') == sha(self.core_path) and epoch.get('securitySha256') == sha(self.s2_path),
                'The private original account witness does not match this base core/S2 owner')
        self.is_drag = args.action.startswith('drag')
        self.public_path = DRAG_REPORT if self.is_drag else REPORT
        self.locator_path = PRIVATE / ('drag-current.json' if self.is_drag else 'main-current.json')
        source_paths = {'driver': Path(__file__), 'profileUi': Path(CORE.__file__),
            'nativeUi': ROOT / 'scripts/native_device_ui.py', 'snapshot': ROOT / 'scripts/isolated_snapshot.py',
            'runtime': self.runtime_path, 'base': self.base_path, 'patchManifest': self.patch_manifest_path,
            'coreEpoch': self.core_path, 's2Epoch': self.s2_path, 'accountEpochWitness': self.epoch_path}
        self.binding = {'hapSha256': self.hap, 'ownerSha256': self.owner,
            'sha256': {k: sha(p) for k, p in source_paths.items()}}
        self.source_paths = source_paths
        if args.action == 'drag-begin':
            main = load(checked(REPORT, OUT))
            require(main.get('status') == 'passed' and main.get('hap', {}).get('packagedSha256') == self.hap and
                    main.get('runtime', {}).get('sha256') == sha(self.runtime_path) and
                    main.get('sourceBinding', {}).get('patchManifestSha256') == sha(self.patch_manifest_path) and
                    main.get('driver', {}).get('sha256') == self.binding['sha256']['driver'] and
                    main.get('count', 0) > 0 and all(main.get('cleanup', {}).values()),
                    'The independent drag session needs this new-HAP main run before a new session is created')
        fresh = args.action in ('run', 'drag-begin')
        if fresh:
            if self.locator_path.exists():
                prior = load(checked(ROOT / load(self.locator_path)['session'], PRIVATE))
                require(args.new_attempt and all(prior.get('cleanup', {}).values()),
                        'Preserve the previous attempt and complete cleanup before an explicit new attempt')
            if self.public_path.exists():
                require(args.new_attempt, 'Existing public evidence needs --new-attempt archival')
                archive = OUT / 'attempts' / (self.public_path.stem + '-' +
                    datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '.json')
                archive.parent.mkdir(exist_ok=True)
                shutil.copyfile(self.public_path, archive)
            stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
            self.directory = PRIVATE / (('drag-' if self.is_drag else 'main-') + stamp)
            self.directory.mkdir(parents=True, mode=0o700)
            self.session_path = self.directory / 'session.json'
            self.session = {'status': 'preparing', 'stage': 'preparing', 'startedAt': now(), 'binding': self.binding,
                'directory': str(self.directory.relative_to(ROOT)), 'checks': [], 'observations': [],
                'screenshots': [], 'geometry': [], 'themeActions': [], 'dragObservations': [],
                'cleanup': {'themeRestoredToSystem': False, 'loggedOut': False, 'loginInputsEmpty': False,
                    'noBusinessWrites': False, 'remoteDumpsRemoved': True, 'logStopped': True}}
            write(self.locator_path, {'session': str(self.session_path.relative_to(ROOT))}, True)
        else:
            locator = load(checked(self.locator_path, PRIVATE))
            self.session_path = checked(ROOT / locator['session'], PRIVATE)
            self.session = load(self.session_path)
            require(self.session.get('binding') == self.binding, 'The staged run source/HAP/runtime/owner binding changed')
            self.directory = checked(self.session_path.parent, PRIVATE, False)
        if args.action in ('cleanup', 'drag-cleanup'):
            require(self.session.get('status') == 'incomplete',
                    'Recovery cleanup is only for an incomplete matching session, never a passed main run')
        self.ui = RefinementUI(self.state, density, self.directory, self.side_panel)
        self.ui.private_screenshots = self.session.get('screenshots', [])
        self.ui.private_trees = self.session.get('privateTrees', [])
        self.ui.raw_evidence = self.session.get('rawEvidence', [])
        self.ui.ime_evidence = self.session.get('imeEvidence', [])
        self.ui.remote_cleanup_ok = self.session['cleanup']['remoteDumpsRemoved']
        self.log_process = None
        self.log_sink = None
        self.save()

    def validate_sources(self):
        original = self.base.get('sourceFiles', [])
        require(isinstance(original, list) and original, 'The explicit base source manifest is missing')
        baseline = {entry['file']: entry['sha256'] for entry in original}
        manifest = self.patch_manifest
        new_sources = manifest.get('newUiSources', [])
        require(isinstance(new_sources, list) and len(new_sources) <= 1 and
                all(isinstance(item, dict) and item.get('file') == SIDE_PANEL_FILE and
                    re.fullmatch(r'[a-f0-9]{64}', str(item.get('sha256', ''))) for item in new_sources),
                'Only the explicitly reviewed StarwardSidePanel UI source may be added')
        added = {item['file']: item['sha256'] for item in new_sources}
        self.side_panel = bool(added)
        require(not set(added).intersection(baseline), 'A new UI declaration cannot overwrite a base business source')
        current = {str(p.relative_to(ROOT)) for p in (ROOT / 'entry/src/main/ets').rglob('*.ets')}
        require(current == set(baseline) | set(added), 'The base and proposed application source sets differ unexpectedly')
        require(set(manifest.get('sourceBaseline', {})) == UI_FILES and
                all(manifest['sourceBaseline'][p] == baseline[p] for p in UI_FILES),
                'The UI patch original source set does not match the frozen base')
        patch = checked(ROOT / manifest.get('rootRelativePatch', ''), ROOT / 'artifacts/private')
        require(sha(patch) == manifest.get('patchSha256'), 'The proposed UI patch bytes changed')
        proposed = checked(ROOT / manifest.get('privateProposedRoot', ''), ROOT / 'artifacts/private', False)
        self.app_sources = {}
        for path, expected in baseline.items():
            target = checked(ROOT / path, ROOT / 'entry/src/main/ets')
            desired = sha(checked(proposed / path, proposed)) if path in UI_FILES else expected
            require(sha(target) == desired, 'Current application source is outside the reviewed UI-only patch')
            self.app_sources[path] = desired
        for path, expected in added.items():
            require(sha(checked(ROOT / path, ROOT / 'entry/src/main/ets/ui')) == expected and
                    sha(checked(proposed / path, proposed)) == expected,
                    'The one added official-panel source must match the reviewed merged proposal exactly')
            self.app_sources[path] = expected
        require(all(self.app_sources[p] != baseline[p] for p in UI_FILES), 'The new UI patch has not been applied')
        archive = checked(ROOT / self.base.get('privateArchive', ''), ROOT / 'artifacts/private')
        require(sha(archive) == self.base.get('hapSha256'), 'The base HAP archive has changed')
        config_path = ROOT / 'entry/src/main/resources/rawfile/integration.json'
        config = load(config_path)
        expected_config = {**self.base['configuration'], 'timeoutMs': self.args.expected_timeout_ms}
        require(config == expected_config and config.get('isolated') is True and
                config.get('endpoint') == self.state['tls']['base'],
                'Only the explicitly selected base isolation configuration is allowed')
        icons = manifest.get('icons', [])
        require(len(icons) == 8 and len({item.get('file') for item in icons}) == 8,
                'The reviewed patch must identify exactly eight source-bound navigation SVGs')
        with zipfile.ZipFile(HAP) as current_zip, zipfile.ZipFile(archive) as old_zip:
            require(json.loads(current_zip.read('resources/rawfile/integration.json')) == config,
                    'Packaged integration configuration differs from reviewed local configuration')
            require(current_zip.read('resources/rawfile/integration-ca.pem') ==
                    old_zip.read('resources/rawfile/integration-ca.pem'), 'The UI-only HAP changed its original trust anchor')
            old_resources = {name for name in old_zip.namelist() if name.startswith('resources/') and not name.endswith('/')}
            new_resources = {name for name in current_zip.namelist() if name.startswith('resources/') and not name.endswith('/')}
            icon_entries = {'resources/base/media/' + Path(item['file']).name for item in icons}
            require(not icon_entries.intersection(old_resources) and new_resources == old_resources | icon_entries,
                    'The UI-only HAP may add only the eight reviewed navigation resource files')
            for entry in old_resources - {'resources/rawfile/integration.json'}:
                require(current_zip.read(entry) == old_zip.read(entry),
                        'A packaged resource outside the reviewed UI-only additions changed')
            for item in icons:
                source = checked(ROOT / item['file'], ROOT / 'entry/src/main/resources/base/media')
                private_source = checked(proposed / item['file'], proposed)
                require(sha(source) == sha(private_source) == item['sha256'], 'A proposed icon no longer matches its source')
                entry = 'resources/base/media/' + source.name
                require(hashlib.sha256(current_zip.read(entry)).hexdigest() == item['sha256'],
                        'An installed-HAP navigation SVG does not match the proposed vector')
        for item in manifest.get('licensesRetained', []):
            require(sha(checked(ROOT / item['file'], ROOT)) == item['sha256'], 'A retained icon license changed')
        self.local_configuration = config

    def immutable(self):
        require(sha(HAP) == self.hap and all(sha(p) == self.binding['sha256'][k]
                for k, p in self.source_paths.items()) and
                all(sha(ROOT / name) == value for name, value in self.app_sources.items()),
                'The staged HAP, sources or prerequisite evidence changed')

    def counts(self):
        ledger = self.control.requests()
        return {'profilePatch': sum(r.get('path') == CORE.PROFILE and r.get('method') == 'PATCH' for r in ledger),
                'passwordPost': sum(r.get('path') == CORE.CHANGE and r.get('method') == 'POST' for r in ledger)}

    def player(self):
        reader = ReadonlySnapshot(self.state)
        reader.login(self.state['newPassword'])
        player = reader.request(CORE.ME)
        require(player.get('id') == self.state['playerId'] and player.get('account') == self.state['account'] and
                player.get('mustChangePassword') is False, 'The dedicated original S2 identity is not currently authoritative')
        return {key: player[key] for key in ('id', 'displayName', 'avatar')}

    def save(self, status=None):
        if status:
            self.session['status'] = status
        self.session['updatedAt'] = now()
        if hasattr(self, 'ui'):
            self.session.update({'screenshots': self.ui.private_screenshots, 'privateTrees': self.ui.private_trees,
                'imeEvidence': self.ui.ime_evidence, 'rawEvidence': self.ui.raw_evidence})
            self.session['cleanup']['remoteDumpsRemoved'] = self.ui.remote_cleanup_ok
        write(self.session_path, self.session, True)
        public = {'status': self.session['status'], 'stage': self.session['stage'],
            'scope': 'New UI-only HAP straight-phone checks' if not self.is_drag else 'Independent official injected native-bar gesture observation',
            'startedAt': self.session['startedAt'], 'updatedAt': self.session['updatedAt'],
            'environment': 'Original disposable S2 player over strict USB HTTPS; no fixed preview player',
            'hap': {'packagedSha256': self.hap},
            'runtime': {'file': str(self.runtime_path.relative_to(ROOT)), 'sha256': sha(self.runtime_path)},
            'sourceBinding': {'baseHapSha256': self.base['hapSha256'], 'patchSha256': self.patch_manifest['patchSha256'],
                'patchManifestSha256': sha(self.patch_manifest_path), 'businessSourcesUnchanged': True,
                'oldUiChecksInherited': False, 'configurationTimeoutMs': self.local_configuration['timeoutMs'],
                'newUiSources': [entry for entry in self.patch_manifest.get('newUiSources', [])],
                'accountMenuContainer': 'official_prompt_action_side_panel' if self.side_panel else 'official_sheet'},
            'credentialEpochOnly': {'coreSha256': sha(self.core_path), 's2Sha256': sha(self.s2_path),
                'privateOwnerWitnessSha256': sha(self.epoch_path), 'newPasswordKey': 'newPassword',
                'freshHttpsIdentityCheck': self.session.get('identityConfirmed', False)},
            'driver': {'file': 'scripts/device-native-ui-refinements.py', 'sha256': self.binding['sha256']['driver'],
                'profileUiHelperSha256': self.binding['sha256']['profileUi']},
            'count': len(self.session['checks']), 'checks': self.session['checks'],
            'observations': self.session['observations'], 'geometry': self.session['geometry'],
            'privateScreenshots': self.session['screenshots'], 'privateTrees': self.session.get('privateTrees', []),
            'rawEvidence': self.session.get('rawEvidence', []), 'imeEvidence': self.session.get('imeEvidence', []),
            'themeActions': self.session['themeActions'], 'visualReview': 'pending_root_original_image_review',
            'dragObservations': self.session['dragObservations'],
            'dragCapabilityConclusion': 'not_determined_by_injection',
            'businessWriteDelta': self.session.get('writeDelta'), 'cleanup': self.session['cleanup'],
            'limitations': ['Visual normal/fill and optical effects require separate Root original-image review',
                'No foldable, hover, split-window or reader/physical-keyboard acceptance is claimed',
                'Hidden-bar proof checks actual exposed native nodes; no tap is injected into the system keyboard',
                'A scripted swipe or drag is not proof of the manual system drag-selection capability',
                'Account panel geometry alone does not prove material pixels or entry/exit motion direction',
                'No profile save, password save, game-start, answer, reward or notification-read action is performed']}
        if self.session.get('failure'):
            public['error'] = self.session['failure']
        write(self.public_path, public)

    def check(self, condition, label, case):
        require(condition, 'Native UI refinement expectation failed: ' + label)
        self.session['checks'].append({'case': case, 'label': label})
        self.save('running')
        print(json.dumps({'count': len(self.session['checks']), 'passed': label}, ensure_ascii=False), flush=True)

    def take(self, label):
        self.ui.capture(label)
        self.ui.private_shot(label)
        self.save()

    def destination(self, label):
        raw, evidence = self.ui.raw_app(label)
        profile = any(row.get('id') == 'profile-scroll' and exposed(row) for row in raw)
        home = any(row.get('id') == 'current-tab' and exposed(row) for row in raw)
        require(profile != home, 'The actual visible home/profile destination is ambiguous')
        return ('profile' if profile else 'home'), evidence

    def navigate(self, target):
        self.ui.tap('nav-' + target)
        self.ui.wait(lambda u: u.find('profile-scroll' if target == 'profile' else 'current-tab') is not None,
                     'native destination after actual tab click')
        observed, _ = self.destination('destination-' + target)
        require(observed == target, 'A real bottom-tab click did not retain its target destination')

    def panel_visible(self, label):
        raw, evidence = self.ui.raw_app(label)
        panels = [row for row in raw if row.get('id') == PANEL_ID and exposed(row)]
        require(len(panels) <= 1, 'The reviewed official account panel identity is ambiguous')
        return panels, raw, evidence

    def wait_panel_closed(self, label, underlying='account-menu'):
        require(underlying in ('account-menu', 'account', 'own-page'),
                'Only the actual own-App avatar or login field may prove panel dismissal')
        deadline = time.monotonic() + 12
        while True:
            panels, raw, evidence = self.panel_visible(label)
            close = [row for row in raw if row.get('id') == PANEL_CLOSE_ID and exposed(row)]
            allowed = ('account-menu', 'account') if underlying == 'own-page' else (underlying,)
            anchor = [row for row in raw if row.get('id') in allowed and exposed(row)]
            if not panels and not close and len(anchor) == 1:
                return evidence
            require(time.monotonic() < deadline, 'The official account Dialog did not finish dismissing')
            time.sleep(.1)

    @staticmethod
    def panel_background(raw):
        markers = {
            'home': [row for row in raw if row.get('id') == 'current-tab' and exposed(row)],
            'profile': [row for row in raw if row.get('id') == 'profile-scroll' and exposed(row)],
            'detail': [row for row in raw if row.get('type') == 'Text' and
                       row.get('originalText') == 'QUEST SESSION' and exposed(row)]}
        require(all(len(value) <= 1 for value in markers.values()),
                'The account-panel underlying destination markers are not unique')
        actual = [name for name, value in markers.items() if value]
        require(len(actual) == 1, 'The actual account-panel underlying destination is ambiguous')
        return actual[0]

    def open_panel(self, label, expected_destination):
        require(self.side_panel, 'The merged proposal does not declare the official side panel')
        require(expected_destination in ('home', 'profile', 'detail'),
                'The panel pointer needs an explicit reviewed underlying destination')
        self.ui.hide_keyboard()
        # raw_app first proves the own-App foreground via CLI, then reads only
        # its official bundle-scoped raw tree. A background app dump alone can
        # never authorise a pointer. No CLI id click or alternate click follows.
        before_raw, before_evidence = self.ui.raw_app('panel-' + label + '-before-pointer')
        before_destination = self.panel_background(before_raw)
        require(before_destination == expected_destination,
                'The requested account panel is not on its expected actual destination')
        require(not any(row.get('id') in (PANEL_ID, PANEL_CLOSE_ID) and exposed(row) for row in before_raw),
                'The first pointer requires the account panel to be actually closed')
        anchors = [row for row in before_raw if row.get('id') == 'account-menu' and exposed(row)]
        require(len(anchors) == 1 and anchors[0].get('clickable') == 'true' and
                anchors[0].get('enabled') == 'true',
                'Exactly one actual visible, enabled, clickable avatar is required')
        anchor_bounds = rect(anchors[0]['bounds'])
        window_bounds, viewport = list(self.ui.app_rect()), list(self.ui.viewport('account-menu'))
        minimum = 44 * self.ui.density - 2  # At most two physical pixels of layout rounding.
        require(anchor_bounds[2] - anchor_bounds[0] >= minimum and
                anchor_bounds[3] - anchor_bounds[1] >= minimum and
                inside(anchor_bounds, viewport) and inside(anchor_bounds, window_bounds),
                'The complete actual 44vp avatar must fit the visible own-App viewport')
        point = [round((anchor_bounds[0] + anchor_bounds[2]) / 2),
                 round((anchor_bounds[1] + anchor_bounds[3]) / 2)]
        center = (anchor_bounds[0] + anchor_bounds[2]) / 2
        side = 'right' if center > (window_bounds[0] + window_bounds[2]) / 2 else 'left'
        command = ['hdc', 'shell', 'uitest', 'uiInput', 'click', *point]
        pointer_path = self.directory / ('avatar-pointer-' + label + '-' + uuid.uuid4().hex + '.json')
        write(pointer_path, {'at': now(), 'label': label,
            'source': 'Own-foreground CLI guard plus fresh official bundle-scoped raw avatar',
            'sourceRawSha256': before_evidence['sha256'], 'anchorBoundsPx': anchor_bounds,
            'windowBoundsPx': window_bounds, 'visibleViewportPx': viewport,
            'pointPx': point, 'officialCommand': [str(value) for value in command],
            'beforeDestination': before_destination, 'expectedDestination': expected_destination,
            'maximumPointerCount': 1, 'fallbackClickPermitted': False}, True)
        pointer = {'case': 'PANEL_POINTER', 'label': label, 'status': 'command_initiated',
            'sourceRawSha256': before_evidence['sha256'], 'beforeDestination': before_destination,
            'privatePointer': {'file': str(pointer_path.relative_to(ROOT)), 'sha256': sha(pointer_path)},
            'pointerAttemptCount': 1, 'commandReturnedSuccessfully': False,
            'fallbackClickUsed': False, 'backgroundObservations': []}
        self.session['observations'].append(pointer)
        self.save()
        self.ui.run(*command)  # This is the one first tap; a failed opening is not retried.
        pointer['status'] = 'command_sent'
        pointer['commandReturnedSuccessfully'] = True
        self.save()
        deadline = time.monotonic() + 25
        while True:
            panels, raw, evidence = self.panel_visible('panel-' + label + '-after-pointer')
            actual = self.panel_background(raw)
            pointer['backgroundObservations'].append({'destination': actual,
                'sourceRawSha256': evidence['sha256'], 'matchesBefore': actual == before_destination})
            pointer['backgroundDestinationStable'] = actual == before_destination
            self.save()
            require(actual == before_destination,
                    'The one real avatar pointer changed the underlying destination; no retry was attempted')
            if panels:
                pointer['status'] = 'panel_observed'
                self.save()
                break
            require(time.monotonic() < deadline,
                    'The actual account Dialog did not appear after the one verified avatar pointer')
            time.sleep(.2)  # Read-only polling between fresh observed trees, never another click.
        require(len(panels) == 1, 'The actual official account panel is not exposed')
        closes = [row for row in raw if row.get('id') == PANEL_CLOSE_ID and exposed(row)]
        scrolls = [row for row in raw if row.get('id') == PANEL_SCROLL_ID and exposed(row)]
        require(len(closes) == 1 and closes[0].get('enabled') == 'true' and
                closes[0].get('clickable') == 'true' and len(scrolls) == 1,
                'The official panel close action and preserved content Scroll must be genuinely exposed')
        box = rect(panels[0]['bounds'])
        left_gap, right_gap = box[0] - window_bounds[0], window_bounds[2] - box[2]
        require(inside(box, window_bounds, 2) and positive(box),
                'The observed account panel is outside the actual window')
        tolerance = 2
        observed_alignment = ('right' if right_gap + tolerance < left_gap else
                              'left' if left_gap + tolerance < right_gap else 'centered')
        self.check(True, 'The actual official panel fits its window and exposes its close action and content Scroll', 'PANEL')
        measurement = {'label': label, 'expectedSideFromActualAnchor': side, 'anchorBoundsPx': anchor_bounds,
            'windowBoundsPx': window_bounds, 'panelBoundsPx': box, 'leftGapPx': left_gap, 'rightGapPx': right_gap,
            'observedFinalAlignment': observed_alignment,
            'sourceRawSha256': evidence['sha256'], 'motionAndMaterialPixels': 'pending_root_original_review'}
        self.session['geometry'].append(measurement)
        self.take('official-panel-' + label)
        return measurement

    def account_panels(self):
        if not self.side_panel:
            self.session['observations'].append({'case': 'PANEL', 'status': 'not_executed',
                'reason': 'The first UI-only proposal retains Sheet; it does not claim a new side panel'})
            return
        self.navigate('home')
        self.open_panel('home-close', 'home')
        self.ui.tap(PANEL_CLOSE_ID)
        self.wait_panel_closed('home-close-finished')
        actual, _ = self.destination('home-after-panel-close')
        self.check(actual == 'home', 'The native panel close action retains home', 'PANEL')
        self.navigate('profile')
        self.navigate('home')
        self.open_panel('home-back', 'home')
        self.ui.back()
        self.wait_panel_closed('home-back-finished')
        actual, _ = self.destination('home-after-panel-back')
        self.check(actual == 'home', 'Official Back dismisses the account Dialog before leaving home', 'PANEL')
        geometry = self.open_panel('home-mask', 'home')
        box, frame = geometry['panelBoundsPx'], geometry['windowBoundsPx']
        gap = geometry['leftGapPx'] if geometry['expectedSideFromActualAnchor'] == 'right' else geometry['rightGapPx']
        if gap >= 16:
            x = round(frame[0] + gap / 2 if geometry['expectedSideFromActualAnchor'] == 'right' else frame[2] - gap / 2)
            y = round((box[1] + box[3]) / 2)
            require(inside([x, y, x + 1, y + 1], frame) and not inside([x, y, x + 1, y + 1], box),
                    'The one mask probe must lie inside the observed window and outside the panel')
            self.ui.run('devecocli', 'ui', 'click', x, y)
            self.wait_panel_closed('home-mask-finished')
            actual, _ = self.destination('home-after-panel-mask')
            self.check(actual == 'home', 'A click on the observed official modal mask dismisses the panel and retains home', 'PANEL')
            self.session['observations'].append({'case': 'PANEL', 'label': 'official-mask-probe', 'pointPx': [x, y]})
        else:
            self.session['observations'].append({'case': 'PANEL', 'label': 'official-mask-probe',
                'status': 'not_observable', 'reason': 'No safe positive-width mask gap was exposed; no background click injected'})
            self.ui.tap(PANEL_CLOSE_ID)
            self.wait_panel_closed('home-mask-unobservable-close')
        self.ui.tap('assignment-' + self.state['assignmentId'])
        self.ui.wait(lambda u: u.find('start-assignment') is not None, 'owned existing read-only assignment detail')
        self.ui.seek('start-assignment')
        self.check(self.ui.has_text('QUEST SESSION'), 'The existing read-only detail is visible before its avatar menu', 'PANEL')
        self.open_panel('detail-back', 'detail')
        self.ui.back()
        self.wait_panel_closed('detail-panel-back-finished')
        self.ui.seek('start-assignment')
        self.check(self.ui.has_text('QUEST SESSION'), 'Back first closes the detail-side account panel and retains the detail', 'PANEL')
        self.ui.back()
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'Back from owned detail after panel dismissal')
        actual, _ = self.destination('home-after-detail-panel')
        self.check(actual == 'home', 'A subsequent Back returns the unchanged read-only detail to home', 'PANEL')
        self.check(self.counts() == self.session['beforeCounts'], 'Account panel open/close and read-only detail submit no profile/password write', 'PANEL')
        self.navigate('profile')

    def theme(self, mode):
        self.ui.hide_keyboard()
        self.ui.capture()
        opened_menu = any(self.ui.find(node_id) is not None for node_id in ('menu-home', 'logout')) or self.ui.has_text('冒险者菜单')
        if self.side_panel and self.ui.find(PANEL_ID) is not None:
            opened_menu = bool(self.panel_visible('theme-existing-panel')[0])
        if self.ui.find('theme-picker') is None and not opened_menu:
            self.ui.tap('account-menu')
            self.ui.wait(lambda u: u.find(PANEL_ID if self.side_panel else 'menu-home') is not None,
                         'official account menu after avatar action')
            opened_menu = True
        self.ui.seek('theme-' + mode)
        self.ui.tap('theme-' + mode)
        self.ui.wait(lambda u: u.find('theme-' + mode) is not None or self.side_panel and
                     u.find(PANEL_ID) is None and u.find('account-menu') is not None,
                     'theme control or dismissed native panel after configuration update')
        require(self.ui.find('theme-error-message') is None, 'The native theme action returned an error')
        node = self.ui.find('theme-' + mode)
        flags = {key: node[key] for key in ('selected', 'accessibilitySelected') if node is not None and key in node}
        require(all(value in (True, 'true') for value in flags.values()), 'An exposed theme selected flag is false')
        self.session['themeActions'].append({'requested': mode, 'selectedFlagsObservable': bool(flags),
            'selectedFlags': flags, 'actualPixels': 'pending_root_review'})
        if opened_menu:
            if self.side_panel:
                if self.panel_visible('theme-after-configuration')[0]:
                    self.ui.back()
                self.wait_panel_closed('theme-menu-dismissed', 'own-page')
            else:
                self.ui.back()
                self.ui.wait(lambda u: u.find('theme-picker') is None and u.find('account-menu') is not None,
                             'official Back dismisses the account menu')

    def prepare_login(self):
        self.immutable()
        self.session['beforeCounts'] = self.counts()
        self.session['baselinePlayer'] = self.player()
        self.session['identityConfirmed'] = True
        self.ui.launch()
        self.session['deviceStarted'] = True
        self.ui.wait(lambda u: u.find('account') is not None, 'pre-existing empty isolated login')
        if self.side_panel:
            self.wait_panel_closed('initial-login-panel-absent', 'account')
        self.check(self.ui.input_empty('account') and self.ui.input_empty('password') and
                   self.ui.has_text('隔离测试环境') and not self.ui.has_text('演示环境'),
                   'The new HAP starts at empty login in the original disposable HTTPS environment', 'LOGIN')
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'new HAP ordinary authenticated home')
        observed, _ = self.destination('ordinary-login-home')
        self.check(observed == 'home', 'The original S2 password reaches home without a forced-password write', 'LOGIN')

    def navigation(self):
        for index in range(2):
            for target in ('profile', 'home'):
                self.navigate(target)
                for node_id in ('nav-rewards', 'nav-notifications'):
                    self.ui.tap(node_id)
                    self.ui.capture()
                    actual, _ = self.destination('deferred-' + target + '-' + str(index))
                    self.check(actual == target, 'A deferred tab leaves the actually visible destination unchanged', 'NAV')
        self.navigate('profile')

    def hidden_bar(self, label):
        raw, evidence = self.ui.raw_app(label)
        related = [row for row in raw if row.get('id') in (*MAIN_IDS, 'starward-native-tabbar')]
        require(all(row.get('visible') in ('true', 'false') for row in related),
                'Raw main-bar visibility attributes must be explicit when nodes are present')
        exposed_rows = [row for row in related if exposed(row)]
        # CLI drops false flags, so an inert hidden id may still be listed. If
        # its positive rectangle survives, require explicit raw hidden state.
        unresolved_cli = [node_id for node_id in MAIN_IDS
            if self.ui.find(node_id) is not None and positive(rect(self.ui.find(node_id).get('bounds'))) and
            not any(row.get('id') == node_id and row.get('visible') == 'false' for row in related)]
        self.check(not exposed_rows and not unresolved_cli,
            'The actual IME viewport exposes no native main bar or navigation hit targets', 'IME')
        self.ui.main_bar_hidden_observed = True
        return {'nativeMainNodes': len(related), 'exposedNativeMainNodes': len(exposed_rows),
            'sourceRawSha256': evidence.get('sha256'), 'directTapIntoIme': False,
            'meaning': 'Actual UiTest exposure and native Visibility.None semantics; no keyboard hit probe'}

    def whole_action(self, node_id, label):
        action = self.ui.seek(node_id)
        bounds, view = action['bounds'], self.ui.viewport(node_id)
        require(self.ui.keyboard_visible(), 'The keyboard disappeared before the whole-action measurement')
        self.check(bounds[3] - bounds[1] >= 52 * self.ui.density - 2 and inside(bounds, view),
                   'The complete52vp primary action is inside the actual IME-clipped interaction viewport', 'IME')
        self.session['geometry'].append({'label': label, 'nodeId': node_id, 'boundsPx': bounds,
            'interactionViewportPx': view, 'heightVp': (bounds[3] - bounds[1]) / self.ui.density})
        self.take(label)

    def bar_restored(self, label):
        deadline = time.monotonic() + 12
        while True:
            raw, evidence = self.ui.raw_app(label)
            bars = [row for row in raw if row.get('id') == 'starward-native-tabbar' and exposed(row)]
            targets = [[row for row in raw if row.get('id') == node_id and exposed(row) and
                        row.get('enabled') == 'true' and row.get('clickable') == 'true'] for node_id in MAIN_IDS]
            if len(bars) == 1 and all(len(found) == 1 for found in targets):
                bar = rect(bars[0]['bounds'])
                if inside(bar, self.ui.app_rect()) and all(inside(rect(found[0]['bounds']), bar) for found in targets):
                    self.session['geometry'].append({'label': label, 'nativeBarBoundsPx': bar,
                        'visibleEnabledClickableNativeItems': len(targets), 'sourceRawSha256': evidence['sha256']})
                    self.check(True, 'IME dismissal restores the actual visible bar and four enabled native hit targets', 'IME')
                    return
            require(time.monotonic() < deadline, 'The actual native main bar did not finish restoring after IME dismissal')
            time.sleep(.1)

    def nickname_keyboard(self):
        self.ui.tap('profile-identity-tab')
        draft = '底栏键盘草稿·未提交'
        self.ui.fill_without_dismiss('profile-name', draft)
        self.ui.wait(lambda u: u.keyboard_visible(), 'actual nickname IME window after input')
        ime = self.ui.actual_ime('nickname')
        self.check(ime['heightVp'] > 0, 'An actual positive-height IME window is observed for nickname editing', 'IME')
        hidden = self.hidden_bar('nickname-bar-hidden')
        self.session['observations'].append({'case': 'IME', 'label': 'nickname-hidden-bar', **hidden})
        self.whole_action('profile-save', 'nickname-ime-whole-save')
        self.ui.hide_keyboard()
        self.bar_restored('nickname-ime-bar-restored')
        self.ui.seek('profile-name')
        self.check(self.ui.find('profile-name').get('text') == draft,
                   'Dismissing IME restores the bar while preserving the unsaved nickname draft', 'IME')
        self.check(self.counts() == self.session['beforeCounts'], 'Keyboard focus and draft edit submit no business write', 'IME')
        self.take('nickname-ime-dismissed-draft')
        self.ui.fill('profile-name', self.session['baselinePlayer']['displayName'])

    def security_keyboard(self):
        self.ui.tap('profile-security-tab')
        for node_id, probe in zip(PASSWORD_IDS, PROBES):
            self.ui.fill(node_id, probe)
        self.ui.seek(PASSWORD_IDS[-1])
        self.ui.run('devecocli', 'ui', 'click', '--id', PASSWORD_IDS[-1])
        self.ui.wait(lambda u: u.keyboard_visible(), 'actual security IME window after focus')
        ime = self.ui.actual_ime('security-confirm')
        self.check(ime['heightVp'] > 0, 'An actual positive-height IME window is observed for password editing', 'IME')
        hidden = self.hidden_bar('security-bar-hidden')
        self.session['observations'].append({'case': 'IME', 'label': 'security-hidden-bar', **hidden})
        self.whole_action('security-save', 'security-ime-whole-save')
        self.ui.back()
        deadline = time.monotonic() + 10
        while self.ui.keyboard_visible() and time.monotonic() < deadline:
            time.sleep(.1)
        require(not self.ui.keyboard_visible(), 'The first actual Back did not dismiss IME')
        self.ui.ime_bottom = None
        self.ui.main_bar_hidden_observed = False
        self.bar_restored('security-ime-bar-restored')
        observed, _ = self.destination('security-first-back')
        self.check(observed == 'profile', 'The first Back dismisses IME while retaining the profile destination', 'BACK')
        self.check(all(self.field_has_probe(node_id, probe) for node_id, probe in zip(PASSWORD_IDS, PROBES)),
                   'IME dismissal alone preserves all three unsubmitted password fields', 'BACK')
        self.ui.back()
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'second Back returns to home')
        observed, _ = self.destination('security-second-back')
        self.check(observed == 'home', 'The second Back returns from profile to home', 'BACK')
        self.navigate('profile')
        self.ui.tap('profile-security-tab')
        self.check(all(self.ui.input_empty(node_id) for node_id in PASSWORD_IDS),
                   'Leaving the profile route clears the three password fields on re-entry', 'BACK')
        self.check(self.counts() == self.session['beforeCounts'], 'Password input and Back actions submit zero password/profile writes', 'BACK')

    def field_has_probe(self, node_id, probe):
        node = self.ui.seek(node_id)
        text = node.get('text', '')
        return text == probe or bool(text) and len(text) == len(probe) and all(c in '*•●·' for c in text)

    def visuals(self):
        for mode in ('dark', 'light'):
            self.theme(mode)
            self.navigate('home')
            self.take('native-bar-home-' + mode)
            self.navigate('profile')
            self.ui.tap('profile-identity-tab')
            self.take('native-bar-profile-' + mode)
            if self.side_panel:
                self.open_panel('profile-' + mode, 'profile')
                self.ui.tap(PANEL_CLOSE_ID)
                self.wait_panel_closed('profile-' + mode + '-panel-closed')
        self.check(True, 'Four new-HAP home/profile originals after theme requests are captured for separate icon/material review', 'CAPTURE')

    def cleanup(self):
        self.ui.hide_keyboard()
        self.ui.capture()
        self.theme('system')
        self.session['cleanup']['themeRestoredToSystem'] = True
        self.ui.capture()
        if self.ui.find('account') is None:
            if self.ui.find('logout') is None and not self.ui.has_text('冒险者菜单'):
                self.ui.tap('account-menu')
            self.ui.seek('logout')
            self.ui.tap('logout')
            self.ui.wait(lambda u: u.find('account') is not None, 'explicit new-HAP logout')
            if self.side_panel:
                self.wait_panel_closed('logout-panel-dismissed', 'account')
        else:
            # An earlier failed login may have kept form drafts. Clearing these
            # local fields is not another authentication or password operation.
            self.ui.fill('account', '')
            self.ui.fill('password', '')
        self.session['cleanup']['loggedOut'] = True
        require(self.ui.input_empty('account') and self.ui.input_empty('password'), 'Logout did not clear login fields')
        self.session['cleanup']['loginInputsEmpty'] = True
        if self.session.get('identityConfirmed'):
            require(self.player() == self.session['baselinePlayer'], 'Read-only checks changed the authoritative nickname or avatar')
        after, before = self.counts(), self.session.get('beforeCounts')
        require(isinstance(before, dict), 'The write baseline is unavailable')
        self.session['writeDelta'] = {key: after[key] - before[key] for key in before}
        require(all(value == 0 for value in self.session['writeDelta'].values()), 'A forbidden profile/password write was observed')
        self.session['cleanup']['noBusinessWrites'] = True
        self.immutable()
        self.save()

    def main_run(self):
        self.session['stage'] = 'main-running'
        self.prepare_login()
        self.navigation()
        self.account_panels()
        self.nickname_keyboard()
        self.security_keyboard()
        self.visuals()
        self.cleanup()
        self.session['stage'] = 'main-complete-visual-review-pending'
        self.save('passed')

    def drag_begin(self):
        main = load(checked(REPORT, OUT))
        require(main.get('status') == 'passed' and main.get('hap', {}).get('packagedSha256') == self.hap and
                main.get('runtime', {}).get('sha256') == sha(self.runtime_path) and
                main.get('sourceBinding', {}).get('patchManifestSha256') == sha(self.patch_manifest_path) and
                main.get('count', 0) > 0 and all(main.get('cleanup', {}).values()),
                'Independent drag observation requires this new-HAP main check and completed cleanup')
        self.session['mainReportSha256'] = sha(REPORT)
        self.prepare_login()
        self.session['stage'] = 'awaiting-official-gesture'
        self.save('awaiting_next_stage')

    def start_log(self):
        path = self.directory / ('navigation-' + uuid.uuid4().hex + '.log')
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        self.log_sink = os.fdopen(fd, 'w')
        self.log_process = subprocess.Popen(['hdc', 'shell', 'hilog', '-T', 'StarwardNavigation'],
            stdout=self.log_sink, stderr=subprocess.STDOUT)
        self.session['cleanup']['logStopped'] = False
        deadline, previous, stable = time.monotonic() + 5, None, 0
        while time.monotonic() < deadline:
            require(self.log_process.poll() is None, 'The native callback log process exited before the gesture')
            size = path.stat().st_size
            stable = stable + 1 if size == previous else 0
            if size > 0 and stable >= 2:
                break
            previous = size
            time.sleep(.25)
        require(size > 0 and stable >= 2, 'Initial callback log history did not drain before the gesture')
        return path

    def stop_log(self):
        if self.log_process is not None:
            self.log_process.terminate()
            try:
                self.log_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.log_process.kill()
                self.log_process.wait(timeout=5)
            self.log_process = None
        if self.log_sink is not None:
            self.log_sink.close()
            self.log_sink = None
        self.session['cleanup']['logStopped'] = True

    def drag(self):
        require(self.session.get('stage') == 'awaiting-official-gesture' and
                self.session.get('status') in ('awaiting_next_stage', 'observed') and self.args.direction,
                'An outstanding independent drag session and explicit direction are required')
        require(sha(REPORT) == self.session.get('mainReportSha256'), 'The main report changed during gesture observation')
        gesture_kind = self.args.gesture_kind
        require(not any(v.get('direction') == self.args.direction and
                        v.get('gestureKind', 'swipe') == gesture_kind for v in self.session['dragObservations']),
                'This gesture kind and direction was already observed; do not overwrite or silently replay it')
        source, target = ('home', 'profile') if self.args.direction == 'home-to-profile' else ('profile', 'home')
        self.ui.launch()
        self.ui.capture()
        self.navigate(source)  # Explicit preparation click, separate from the measured gesture.
        self.ui.hide_keyboard()
        self.ui.capture()
        source_node, target_node = self.ui.seek('nav-' + source), self.ui.seek('nav-' + target)
        gesture_label = gesture_kind + '-' + self.args.direction
        raw, before_raw = self.ui.raw_app(gesture_label + '-before')
        bars = [row for row in raw if row.get('id') == 'starward-native-tabbar' and exposed(row)]
        require(len(bars) == 1, 'One actual exposed native TabBar is required')
        bar = rect(bars[0]['bounds'])
        points = [[round((node['bounds'][0] + node['bounds'][2]) / 2),
                   round((node['bounds'][1] + node['bounds'][3]) / 2)] for node in (source_node, target_node)]
        require(all(inside([x, y, x + 1, y + 1], bar) for x, y in points) and
                abs(points[0][1] - points[1][1]) <= 3 * self.ui.density,
                'Only actual same-row native item centers may be used for the official injected gesture')
        log_path = self.start_log()
        # Drain initial history before measuring this one gesture. No log clear is performed.
        offset = log_path.stat().st_size
        # Official UiTest guide: uiInput drag x1 y1 x2 y2 [speed], 200..40000
        # px/s (default600). Drag includes the native pre-drag long press; this
        # CLI exposes no press-duration parameter. Do not invent one or combine
        # a separate longclick with a released swipe.
        command = ['devecocli', 'ui', gesture_kind, *points[0], *points[1], '--speed', 600]
        observation = {'direction': self.args.direction, 'gestureKind': gesture_kind,
            'status': 'command_initiated', 'initiatedAt': now(),
            'sourceDestination': source, 'requestedTarget': target, 'officialInjectedGesturePx': points,
            'officialCliCommand': [str(part) for part in command], 'speedPxPerSecond': 600,
            'preDragLongPress': ('native_default_duration_not_measured' if gesture_kind == 'drag' else 'not_requested'),
            'nativeBarBoundsPx': bar, 'sourceRawSha256': before_raw['sha256'],
            'privateLogFile': str(log_path.relative_to(ROOT)), 'measuredOffsetBytes': offset,
            'productCustomGestureUsed': False, 'targetClickFallbackUsed': False}
        self.session['dragObservations'].append(observation)
        self.save('running')
        try:
            self.ui.run(*command)
            observation['status'] = 'command_sent'
            self.save()
            time.sleep(.4)
            actual, after_raw = self.destination(gesture_label + '-after')
            self.take('gesture-' + gesture_label)
        finally:
            self.stop_log()
        new_log = log_path.read_bytes()[offset:].decode('utf-8', errors='replace')
        events = []
        for line in new_log.splitlines():
            if 'StarwardNavigation' not in line:
                continue
            kind = re.search(r'\b(appear|param|will|change|click|intent|ignore)\b', line)
            if kind:
                values = {key: int(value) for key, value in re.findall(
                    r'\b(index|selected|active|current|coming|param)=(-?\d+)', line)}
                events.append({'kind': kind.group(1), **values})
        observation.update({'status': 'observed', 'observedAt': now(),
            'preparation': 'Separate normal native click establishes the source before log offset',
            'sourceDestination': source, 'requestedTarget': target, 'actualEndDestination': actual,
            'destinationChangedToTarget': actual == target, 'nativeBarBoundsPx': bar,
            'officialInjectedGesturePx': points, 'officialCallbackWrapperEvents': events,
            'sourceRawSha256': before_raw['sha256'], 'endRawSha256': after_raw['sha256'],
            'privateLog': {'file': str(log_path.relative_to(ROOT)), 'sha256': sha(log_path), 'measuredOffsetBytes': offset},
            'productCustomGestureUsed': False, 'targetClickFallbackUsed': False,
            'capabilityAcceptance': 'Root must distinguish injection outcome, manual gesture and official support'})
        require(self.counts() == self.session['beforeCounts'], 'A gesture unexpectedly submitted a business write')
        self.immutable()
        self.save('observed')

    def drag_finish(self):
        require(self.session.get('stage') == 'awaiting-official-gesture' and
                self.session.get('status') in ('awaiting_next_stage', 'observed'),
                'No healthy independent drag session is pending; use drag-cleanup for a failed stage')
        self.cleanup()
        self.session['stage'] = 'gesture-finished-root-review-pending'
        self.save('observed' if self.session['dragObservations'] else 'not_executed')

    def execute(self):
        try:
            if self.args.action == 'run':
                self.main_run()
            elif self.args.action == 'drag-begin':
                self.drag_begin()
            elif self.args.action == 'drag':
                self.drag()
            elif self.args.action == 'drag-finish':
                self.drag_finish()
            else:
                self.cleanup()
                self.session['stage'] = 'incomplete-run-cleaned'
                self.save('incomplete')
            print(json.dumps({'status': self.session['status'], 'stage': self.session['stage'],
                'count': len(self.session['checks']), 'report': str(self.public_path.relative_to(ROOT)),
                'visualReview': 'pending_root_original_image_review', 'cleanup': self.session['cleanup']}), flush=True)
            return 0
        except Exception as error:
            self.stop_log()
            self.session['failure'] = 'A guarded native UI stage stopped; inspect private evidence and actual foreground before continuing'
            diagnostic = {'at': now(), 'stage': self.session['stage'], 'type': type(error).__name__,
                'safeMessage': str(error) if isinstance(error, SafeFailure) else 'Unexpected driver error; original values omitted'}
            write(self.directory / ('failure-' + uuid.uuid4().hex + '.json'), diagnostic, True)
            if self.session.get('deviceStarted'):
                try:
                    self.ui.capture('failure-last-own-app')
                except Exception:
                    pass
            # A monolithic main failure may clean only the recognised own App.
            if self.args.action == 'run' and self.session.get('deviceStarted'):
                try:
                    self.cleanup()
                except Exception:
                    pass
            self.save('incomplete')
            print(json.dumps({'status': 'incomplete', 'stage': self.session['stage'],
                'report': str(self.public_path.relative_to(ROOT)), 'cleanup': self.session['cleanup']}), flush=True)
            return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('action', choices=('run', 'cleanup', 'drag-begin', 'drag', 'drag-finish', 'drag-cleanup'))
    parser.add_argument('--runtime-report', required=True, type=Path)
    parser.add_argument('--patch-manifest', required=True, type=Path)
    parser.add_argument('--base-hap-manifest', type=Path, default=OUT / 'base-hap.json')
    parser.add_argument('--core-report', type=Path, default=CORE.REPORT)
    parser.add_argument('--security-report', type=Path, default=OUT / 'device-profile-password-uncertain.json')
    parser.add_argument('--account-epoch-receipt', type=Path,
        default=ROOT / 'artifacts/private/profile-device/avatar-session.json',
        help='Private original owner/core/S2 witness only; no avatar UI checks are inherited')
    parser.add_argument('--expected-timeout-ms', type=int, choices=(2000, 15000), default=2000,
        help='Explicit configuration lineage; no timeout difference is silently accepted')
    parser.add_argument('--direction', choices=('home-to-profile', 'profile-to-home'))
    parser.add_argument('--gesture-kind', choices=('swipe', 'drag'), default='swipe',
        help='Independent official injection kind; drag uses native pre-drag press with no CLI duration option')
    parser.add_argument('--new-attempt', action='store_true')
    args = parser.parse_args()
    try:
        return Acceptance(args).execute()
    except Exception as error:
        value = {'status': 'not_started', 'error': 'New-HAP source, runtime or dedicated-account prerequisites failed'}
        if isinstance(error, SafeFailure):
            value['reason'] = str(error)
        print(json.dumps(value))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())

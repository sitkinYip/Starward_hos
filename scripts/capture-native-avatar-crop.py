#!/usr/bin/env python3
"""Capture the real native crop Sheet in two separately staged App themes.

begin --theme dark|light --runtime-report <passed current runtime>
  -> root selects the exact imported PNG using select-owned-picker-fixture.py
  -> root presses the real system Picker Complete action
capture --theme <same theme> --runtime-report <same runtime>

This helper neither selects media nor confirms/uploads a crop. Captured means
SHA-bound evidence and cleanup completed; root visual review remains separate.
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

from isolated_snapshot import ReadonlySnapshot
from native_device_ui import ROOT, IsolationControl, SafeFailure

SPEC = importlib.util.spec_from_file_location('crop_visual_avatar', Path(__file__).with_name('device-profile-avatar.py'))
AVATAR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AVATAR)
OUT = ROOT / 'artifacts/validation/profile'
PRIVATE = ROOT / 'artifacts/private/profile-device/native-avatar-crop'
REPORT = OUT / 'native-avatar-crop-visual.json'
HAP = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
FIXTURE = OUT / 'avatar-fixture.png'
SELECTIONS = OUT / 'picker-selections.json'
PROFILE = '/api/questions/v1/me/profile'
CHANGE = '/api/questions/v1/me/change-password'
ME = '/api/questions/v1/me'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def require(condition, message):
    if not condition:
        raise SafeFailure(message)


def within(path, directory):
    path = Path(path)
    resolved = path.resolve()
    require(not path.is_symlink() and resolved.is_relative_to(directory.resolve()),
            'An evidence path is outside its owned directory')
    return resolved


def private_write(path, value):
    require(not path.is_symlink(), 'Private evidence cannot be a symlink')
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.parent.chmod(0o700)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as output:
        json.dump(value, output, ensure_ascii=False, indent=2)
        output.write('\n')
    path.chmod(0o600)


class CropUI(AVATAR.AvatarUI):
    def __init__(self, state, density, directory):
        super().__init__(state, density)
        self.output = directory
        self.shots = directory
        self.private_trees = []

    def capture(self, name=None):
        result = super().capture()
        if name:
            target = self.shots / ('ui-' + name + '.json')
            # Unmodified CLI tree stays private, including any media identifiers.
            private_write(target, self.tree)
            self.private_trees.append({'file': str(target.relative_to(ROOT)), 'sha256': sha(target)})
        return result

    def swipe(self, direction):
        self.capture()
        crop = next((n.get('id') for n in self.flat
                     if str(n.get('id', '')).startswith('avatar-crop-') and n.get('bounds')), None)
        menu = next((node_id for node_id in ('theme-picker', 'logout') if self.find(node_id)), None)
        target = crop or menu or ('profile-avatar-pick' if self.find('profile-avatar-pick') else None)
        left, top, right, bottom = self.viewport(target)
        require(right - left >= 80 and bottom - top >= 150, 'The active owned Sheet viewport is too small')
        # Use the actual active control's Scroll ancestor. A background profile
        # Scroll can be larger than this independent crop/menu Sheet.
        x = int(left + min(12 * self.density, (right - left) * .06))
        low, high = int(top + (bottom - top) * .76), int(top + (bottom - top) * .30)
        start, end = (low, high) if direction == 'down' else (high, low)
        self.run('devecocli', 'ui', 'swipe', x, start, x, end)


class Capture:
    def __init__(self, args):
        self.args = args
        self.control = IsolationControl()
        self.state = self.control.state
        self.hap = sha(HAP)
        self.runtime_path = within(args.runtime_report, OUT)
        self.inputs = {'runtime': self.runtime_path, 'core': OUT / 'device-profile-acceptance.json',
                       's2': OUT / 'device-profile-password-uncertain.json',
                       'mainAvatar': OUT / 'device-profile-avatar.json'}
        self.input_shas = {key: sha(path) for key, path in self.inputs.items()}
        runtime, core, s2, avatar = (json.loads(self.inputs[key].read_text())
                                     for key in ('runtime', 'core', 's2', 'mainAvatar'))
        density = runtime.get('window', {}).get('density')
        require(runtime.get('status') == 'passed' and runtime.get('installedHapSha256') == self.hap and
                isinstance(density, (int, float)) and not isinstance(density, bool) and
                math.isfinite(density) and density > 0, 'A passed current installed-HAP runtime and density are required')
        for value in (core, s2, avatar):
            require(value.get('status') == 'passed' and value.get('hap', {}).get('packagedSha256') == self.hap and
                    value.get('runtime', {}).get('sha256') == self.input_shas['runtime'],
                    'Core, S2 and main avatar must all pass on this exact HAP/runtime')
        require(all(core.get('cleanup', {}).get(k) is True and s2.get('cleanup', {}).get(k) is True
                    for k in ('loggedOut', 'faultNeutralised')) and
                s2.get('corePrerequisite', {}).get('sha256') == self.input_shas['core'] and
                avatar.get('corePrerequisite', {}).get('sha256') == self.input_shas['core'] and
                avatar.get('securityPrerequisiteSha256') == self.input_shas['s2'],
                'Prerequisites must share the completed core/S2 account epoch')
        phases = avatar.get('phases', [])
        require(all(p in phases for p in ('recovery-and-logout', 'decode-corrupt-restored', 'visual-reviewed')) and
                avatar.get('injectedStorageFault', {}).get('restored') is True and
                avatar.get('injectedStorageFault', {}).get('cleanupLoggedOut') is True,
                'Main avatar basic recovery and storage-fault cleanup must be complete')
        self.password_key = s2.get('finalPasswordKey')
        require(self.password_key in ('initialPassword', 'newPassword') and
                avatar.get('finalPasswordKey') == self.password_key and
                isinstance(self.state.get(self.password_key), str) and self.state[self.password_key],
                'A verified unchanged S2 password key is required')
        config_path = ROOT / 'entry/src/main/resources/rawfile/integration.json'
        config = json.loads(config_path.read_text())
        require(config.get('isolated') is True and config.get('endpoint') == self.state['tls']['base'] and
                self.state.get('account', '').startswith('hm_'), 'Only the packaged dedicated HTTPS environment is allowed')
        self.receipt_path = within(args.receipt, ROOT / 'artifacts/private')
        self.receipt = json.loads(self.receipt_path.read_text())
        self.fixture_sha = sha(FIXTURE)
        require(self.receipt.get('fixtureSha256') == self.fixture_sha and
                self.receipt.get('readbackSha256') == self.fixture_sha and
                isinstance(self.receipt.get('mediaUri'), str) and
                re.fullmatch(r'file://media/Photo/[^?\s]+', self.receipt['mediaUri']) is not None,
                'The fixed PNG needs an exact private official import/readback receipt')
        self.bound_paths = {**self.inputs, 'importReceipt': self.receipt_path, 'fixture': FIXTURE,
                           'driver': Path(__file__), 'avatarUI': Path(AVATAR.__file__),
                           'profileUI': ROOT / 'scripts/device-profile-acceptance.py',
                           'pickerSelector': ROOT / 'scripts/select-owned-picker-fixture.py',
                           'nativeUI': ROOT / 'scripts/native_device_ui.py',
                           'snapshot': ROOT / 'scripts/isolated_snapshot.py', 'integration': config_path}
        self.binding = {'hapSha256': self.hap, 'sha256': {key: sha(path) for key, path in self.bound_paths.items()}}
        self.owner = hashlib.sha256((self.state['account'] + self.state['playerId'] + self.state['controlBase']).encode()).hexdigest()
        self.session_path = PRIVATE / (args.theme + '-session.json')
        self.public = json.loads(REPORT.read_text()) if REPORT.exists() else {'binding': self.binding, 'themes': {}}
        require(self.public.get('binding') == self.binding and isinstance(self.public.get('themes'), dict),
                'Existing crop evidence belongs to another build or prerequisite set; preserve it separately')
        if args.action == 'begin':
            require(not self.session_path.exists() and args.theme not in self.public['themes'],
                    'This theme already has a session; prior evidence cannot be overwritten')
            for other in ('dark', 'light'):
                active = PRIVATE / (other + '-session.json')
                if active.exists():
                    prior = json.loads(active.read_text())
                    require(prior.get('status') == 'captured' and prior.get('binding') == self.binding,
                            'Finish the other independent theme session before beginning this one')
            stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
            self.directory = PRIVATE / (args.theme + '-' + stamp)
            self.directory.mkdir(parents=True, exist_ok=False, mode=0o700)
            self.directory.chmod(0o700)
            self.session = {'status': 'preparing', 'theme': args.theme, 'startedAt': now(),
                            'directory': str(self.directory.relative_to(ROOT)), 'ownerSha256': self.owner,
                            'binding': self.binding, 'passwordKey': self.password_key, 'checks': [],
                            'privateScreenshots': [], 'privateTrees': [], 'geometry': {},
                            'cleanup': {'cropCancelled': False, 'themeRestoredToSystem': False,
                                        'loggedOut': False, 'emptyLoginInputs': False, 'noBusinessWrites': False}}
        else:
            self.session = json.loads(self.session_path.read_text())
            require(self.session.get('ownerSha256') == self.owner and self.session.get('binding') == self.binding and
                    self.session.get('passwordKey') == self.password_key and
                    self.session.get('status') == 'awaiting_system_selection',
                    'Capture requires this exact outstanding theme Picker session')
            self.directory = within(ROOT / self.session['directory'], PRIVATE)
        self.ui = CropUI(self.state, density, self.directory)
        self.ui.private_screenshots = self.session['privateScreenshots']
        self.ui.private_trees = self.session['privateTrees']

    def immutable(self):
        require(sha(HAP) == self.hap and all(sha(path) == self.binding['sha256'][key]
                                            for key, path in self.bound_paths.items()),
                'A crop HAP, helper, fixture, receipt or prerequisite changed')

    def save(self, status=None):
        self.immutable()
        if status:
            self.session['status'] = status
        self.session['updatedAt'] = now()
        private_write(self.session_path, self.session)
        record = {key: self.session[key] for key in ('status', 'theme', 'startedAt', 'updatedAt', 'checks',
                  'privateScreenshots', 'privateTrees', 'geometry', 'cleanup')}
        record.update({'themeVerified': False, 'themeVerification': 'Root visual review of private originals is pending',
                       'themeAction': self.session.get('themeAction'),
                       'selectionEvidence': self.session.get('selectionEvidence'),
                       'businessWriteDelta': self.session.get('businessWriteDelta'),
                       'privateSession': {'file': str(self.session_path.relative_to(ROOT)), 'sha256': sha(self.session_path)}})
        self.public['themes'][self.args.theme] = record
        complete = all(self.public['themes'].get(k, {}).get('status') == 'captured' for k in ('dark', 'light'))
        self.public.update({'status': 'complete' if complete else self.session['status'],
            'scope': 'Real native crop Sheet theme evidence only; no visual acceptance or avatar upload',
            'environment': 'Dedicated disposable PocketBase over strict USB HTTPS', 'updatedAt': now(),
            'runtime': {'file': str(self.runtime_path.relative_to(ROOT)), 'sha256': self.input_shas['runtime']},
            'hap': {'packagedSha256': self.hap}, 'prerequisiteSha256': self.input_shas,
            'fixture': {'file': str(FIXTURE.relative_to(ROOT)), 'sha256': self.fixture_sha,
                        'nonPrivateGeneratedImage': True, 'importReceiptSha256': self.binding['sha256']['importReceipt']},
            'driverSha256': self.binding['sha256']['driver'], 'visualReview': 'pending',
            'limitations': ['Captured/complete describe evidence collection and cleanup, not root visual approval',
                            'Picker selection and Complete are separate actual root actions',
                            'No system color-mode metric is inferred from the requested theme',
                            'Foldable and other device scopes remain deferred']})
        OUT.mkdir(parents=True, exist_ok=True)
        REPORT.write_text(json.dumps(self.public, ensure_ascii=False, indent=2) + '\n')

    def check(self, condition, label):
        require(condition, label)
        self.session['checks'].append(label)

    def counts(self):
        rows = self.control.requests()
        return {'profilePatch': sum(r.get('path') == PROFILE and r.get('method') == 'PATCH' for r in rows),
                'passwordPost': sum(r.get('path') == CHANGE and r.get('method') == 'POST' for r in rows)}

    def player(self):
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state[self.password_key])
        player = snapshot.request(ME)
        require(player.get('id') == self.state['playerId'] and player.get('mustChangePassword') is False and
                isinstance(player.get('displayName'), str) and isinstance(player.get('avatar'), str),
                'Strict HTTPS must identify the dedicated ordinary player')
        return {key: player[key] for key in ('id', 'displayName', 'avatar')}

    def theme(self, theme):
        self.ui.tap('account-menu')
        self.ui.wait(lambda u: u.find('theme-picker') is not None, 'owned account theme Sheet')
        self.ui.tap('theme-' + theme)
        self.ui.wait(lambda u: u.find('theme-' + theme) is not None, 'theme control after reconfiguration')
        require(self.ui.find('theme-error-message') is None, 'The App reported a theme operation error')
        node = self.ui.seek('theme-' + theme)
        observed = {k: node[k] for k in ('selected', 'accessibilitySelected') if k in node}
        require(all(v in (True, 'true') for v in observed.values()), 'An exposed theme selection flag is false')
        self.ui.back()
        self.ui.wait(lambda u: u.find('theme-picker') is None and u.find('account-menu') is not None,
                     'theme Sheet dismissed by official Back')
        return {'requested': theme, 'selectionObservable': bool(observed), 'selectionFlags': observed,
                'pixelThemeVerified': False}

    def begin(self):
        self.ui.launch()
        self.ui.wait(lambda u: u.find('account') is not None, 'pre-existing empty login')
        self.check(self.ui.input_empty('account') and self.ui.input_empty('password'),
                   'The independent theme session starts at empty login')
        self.session['beforeCounts'] = self.counts()
        self.session['baselinePlayer'] = self.player()
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state[self.password_key])
        self.ui.tap('primary-action')
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'authenticated home')
        self.session['themeAction'] = self.theme(self.args.theme)
        self.ui.tap('nav-profile')
        self.ui.wait(lambda u: u.find('profile-scroll') is not None, 'native profile')
        self.ui.seek('profile-name')
        self.check(self.ui.find('profile-name').get('text') == self.session['baselinePlayer']['displayName'],
                   'The profile nickname starts at its authoritative saved value')
        self.ui.seek('profile-avatar-pick')
        self.check(self.ui.find('profile-avatar-pending') is None, 'No avatar draft is pending before Picker')
        selections = json.loads(SELECTIONS.read_text()).get('selections', []) if SELECTIONS.exists() else []
        require(isinstance(selections, list), 'Picker selection evidence has an invalid shape')
        self.session['selectionCountBefore'] = len(selections)
        self.ui.tap('profile-avatar-pick')
        # No system-Picker inspection, host selection, or claimed Popup success.
        self.save('awaiting_system_selection')
        print(json.dumps({'status': 'awaiting_system_selection', 'theme': self.args.theme,
                          'next': 'Root selects the exact imported PNG and presses actual Picker Complete, then runs capture'}))

    def selection_evidence(self):
        document = json.loads(SELECTIONS.read_text())
        records = document.get('selections', [])
        require(isinstance(records, list), 'Actual owned Picker selection evidence is unavailable')
        new = records[self.session['selectionCountBefore']:]
        require(len(new) == 1, 'Exactly one separately recorded owned selection is required for this session')
        record = new[0]
        require(record.get('status') == 'selection_sent' and record.get('fixtureSha256') == self.fixture_sha and
                record.get('importReceiptSha256') == self.binding['sha256']['importReceipt'] and
                record.get('driverSha256') == self.binding['sha256']['pickerSelector'],
                'The separate root selection does not bind this exact imported PNG')
        directory = within(ROOT / record['privateEvidence'], ROOT / 'artifacts/private/profile-picker')
        actual = json.loads((directory / 'selection.json').read_text())
        require(actual.get('mediaUri') == self.receipt['mediaUri'] and
                actual.get('fixtureSha256') == self.fixture_sha and
                actual.get('importReceiptSha256') == self.binding['sha256']['importReceipt'] and
                actual.get('rawSha256') == record.get('rawSha256') == sha(directory / 'raw.json'),
                'Private actual Picker identity or raw evidence no longer matches the owned fixture')
        frozen = self.directory / 'picker-selection-report.json'
        private_write(frozen, document)
        self.session['selectionEvidence'] = {'status': 'selection_sent_separately',
            'reportFile': str(SELECTIONS.relative_to(ROOT)), 'observedReportSha256': sha(SELECTIONS),
            'privateFrozenReport': str(frozen.relative_to(ROOT)), 'privateFrozenReportSha256': sha(frozen),
            'actualSelectionRawSha256': record['rawSha256'],
            'cropPresented': 'Independently checked by actual App crop controls in this stage'}

    def geometry(self, node_id, node):
        bounds = node['bounds']
        return {'nodeId': node_id, 'boundsPx': bounds, 'viewportPx': self.ui.viewport(node_id),
                'widthVp': (bounds[2] - bounds[0]) / self.ui.density,
                'heightVp': (bounds[3] - bounds[1]) / self.ui.density}

    def capture(self):
        self.selection_evidence()
        self.ui.wait(lambda u: u.find('avatar-crop-preview') is not None, 'actual owned crop preview after Picker Complete')
        preview = self.ui.seek('avatar-crop-preview')
        rect = preview['bounds']
        self.check(rect[2] - rect[0] > 100 and abs((rect[2] - rect[0]) - (rect[3] - rect[1])) <= 3,
                   'The actual native crop preview is fully reachable and square')
        self.session['geometry']['preview'] = self.geometry('avatar-crop-preview', preview)
        self.ui.capture('crop-top')
        self.ui.private_shot('crop-' + self.args.theme + '-top')
        confirm = self.ui.seek('avatar-crop-confirm')
        self.check(confirm['bounds'][3] - confirm['bounds'][1] >= 52 * self.ui.density - 3,
                   'The complete native 52vp crop confirm action is reachable without confirming')
        self.session['geometry']['confirm'] = self.geometry('avatar-crop-confirm', confirm)
        self.ui.capture('crop-controls')
        self.ui.private_shot('crop-' + self.args.theme + '-controls')
        self.cleanup()
        self.save('captured')
        print(json.dumps({'status': 'captured', 'theme': self.args.theme,
                          'report': str(REPORT.relative_to(ROOT)), 'visualReview': 'pending'}))

    def cleanup(self):
        self.ui.capture()
        if self.ui.find('avatar-crop-preview') is not None:
            self.ui.tap('avatar-crop-cancel')
            self.ui.wait(lambda u: u.find('avatar-crop-preview') is None and u.find('profile-scroll') is not None,
                         'actual crop cancelled back to native profile')
            self.session['cleanup']['cropCancelled'] = True
        require(self.session['cleanup']['cropCancelled'], 'Actual crop cancellation has not been observed')
        self.ui.seek('profile-name')
        self.check(self.ui.find('profile-name').get('text') == self.session['baselinePlayer']['displayName'],
                   'Cancelling crop preserves the original nickname editor')
        self.ui.seek('profile-avatar-pick')
        self.check(self.ui.find('profile-avatar-pending') is None, 'Cancelling crop leaves no pending avatar draft')
        self.check(self.player() == self.session['baselinePlayer'], 'Strict HTTPS confirms original nickname and avatar unchanged')
        self.theme('system')
        self.session['cleanup']['themeRestoredToSystem'] = True
        self.ui.tap('account-menu')
        self.ui.seek('logout')
        self.ui.tap('logout')
        self.ui.wait(lambda u: u.find('account') is not None, 'explicit logout after crop evidence')
        self.session['cleanup']['loggedOut'] = True
        self.check(self.ui.input_empty('account') and self.ui.input_empty('password'), 'Explicit logout clears both login inputs')
        self.session['cleanup']['emptyLoginInputs'] = True
        after = self.counts()
        before = self.session['beforeCounts']
        delta = {key: after[key] - before[key] for key in before}
        self.session['businessWriteDelta'] = delta
        self.check(all(value == 0 for value in delta.values()), 'Crop evidence submits zero profile PATCH and password POST writes')
        self.session['cleanup']['noBusinessWrites'] = True

    def run(self):
        try:
            getattr(self, self.args.action)()
            return 0
        except Exception:
            # Never touch an unrecognised Picker surface or replay an action on
            # error. Preserve partial evidence for the exclusive root operator.
            self.session['failure'] = 'Crop visual stage stopped; cleanup may be incomplete and needs root review'
            self.save('incomplete')
            print(json.dumps({'status': 'incomplete', 'theme': self.args.theme,
                              'error': 'Crop visual stage stopped; inspect the private session and actual foreground before continuing'}))
            return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('begin', 'capture'))
    parser.add_argument('--theme', required=True, choices=('dark', 'light'))
    parser.add_argument('--runtime-report', required=True, type=Path)
    parser.add_argument('--receipt', type=Path, default=ROOT / 'artifacts/private/profile-device/avatar-import-receipt.json')
    args = parser.parse_args()
    try:
        return Capture(args).run()
    except Exception:
        print(json.dumps({'status': 'not_started', 'error': 'Crop visual prerequisites or immutable evidence guards failed'}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

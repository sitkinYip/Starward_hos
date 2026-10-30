#!/usr/bin/env python3
"""Task1 core phone acceptance against the dedicated, real HTTPS player.

Own the device and control endpoint before running. Picker/crop/avatar and the
lost-password-response case remain separately reported; this core run never
claims that unexecuted capabilities passed. Credentials and account text are
kept out of public trees, output and screenshots.
"""
import argparse
import datetime
import hashlib
import json
import math
from pathlib import Path
import shutil
import time

from isolated_snapshot import ReadonlySnapshot
from native_device_ui import ROOT, DeviceUI, IsolationControl, SafeFailure, sanitise

PROFILE = '/api/questions/v1/me/profile'
CHANGE = '/api/questions/v1/me/change-password'
ME = '/api/questions/v1/me'
OUT = ROOT / 'artifacts/validation/profile'
REPORT = OUT / 'device-profile-acceptance.json'
PRIVATE_SHOTS = ROOT / 'artifacts/private/profile-device'
NAME = '原生资料验收者'
DRAFT = '尚未保存的旅人'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class ProfileUI(DeviceUI):
    def __init__(self, state, density):
        super().__init__(OUT, PRIVATE_SHOTS)
        self.density = density
        self.secrets = [state.get(key, '') for key in ('account', 'initialPassword', 'newPassword', 'controlToken')]
        self.private_screenshots = []

    def redact(self, value):
        if isinstance(value, list):
            return [self.redact(item) for item in value]
        if isinstance(value, dict):
            return {key: self.redact(item) for key, item in value.items()}
        if isinstance(value, str):
            for secret in self.secrets:
                if secret:
                    value = value.replace(secret, '[isolated value omitted]')
            if '?token=' in value or value.startswith(('file://', 'datashare://', 'content://')):
                return '[private media address omitted]'
        return value

    def capture(self, name=None):
        result = super().capture()
        if name:
            (self.output / ('ui-' + name + '.json')).write_text(json.dumps(
                self.redact(sanitise(self.tree)), ensure_ascii=False, indent=2) + '\n')
        return result

    def viewport(self, node_id=None):
        view = super().viewport(node_id)
        target_path = self.path_to(node_id) if node_id else None
        # Every control in this Scroll must be brought above the floating bar,
        # including avatar-retry. Crop/menu Sheets have separate ancestors and
        # must keep their own viewport instead of inheriting the covered bar.
        if any(node.get('id') == 'profile-scroll' for node in target_path or []):
            path = self.path_to('nav-home')
            bar = next((node for node in reversed(path or [])
                        if node.get('type') == 'TabBar' and node.get('bounds')), None)
            if bar and view[1] < bar['bounds'][1] < view[3]:
                view[3] = bar['bounds'][1]
        return view

    def minimum_height(self, node_id, node):
        if node_id in ('profile-save', 'security-save'):
            return 52 * self.density * .9
        if node_id in ('profile-identity-tab', 'profile-security-tab'):
            return (15 if node.get('type') == 'Text' else 53) * self.density * .9
        if node_id.startswith('menu-'):
            return 44 * self.density * .9
        return super().minimum_height(node_id, node) * self.density / 3.375

    def private_shot(self, name):
        # A real account is a required read-only field on this page. Raw images
        # remain private rather than silently masking or editing the evidence.
        target = super().screenshot(name)
        target.chmod(0o600)
        self.private_screenshots.append({'file': str(target.relative_to(ROOT)), 'sha256': sha(target),
                                         'scope': 'Private original; may show the dedicated test account'})


class Acceptance:
    def __init__(self, runtime_path, resume_password_gate=False):
        self.control = IsolationControl()
        self.state = self.control.state
        config = json.loads((ROOT / 'entry/src/main/resources/rawfile/integration.json').read_text())
        if (config.get('isolated') is not True or config.get('endpoint') != self.state['tls']['base'] or
                not self.state.get('account', '').startswith('hm_')):
            raise SafeFailure('A packaged dedicated HTTPS environment is required')
        self.hap_sha = sha(ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap')
        self.runtime_path = runtime_path.resolve()
        if not self.runtime_path.is_relative_to((ROOT / 'artifacts/validation/profile').resolve()):
            raise SafeFailure('Task1 runtime report must remain in the profile validation directory')
        runtime = json.loads(self.runtime_path.read_text())
        window = runtime.get('window', {})
        density = window.get('density')
        if (runtime.get('status') != 'passed' or runtime.get('installedHapSha256') != self.hap_sha or
                not isinstance(density, (float, int)) or not math.isfinite(density) or density <= 0):
            raise SafeFailure('Actual Task1 runtime must match the packaged HAP')
        self.ui = ProfileUI(self.state, density)
        self.resume_password_gate = resume_password_gate
        self.forced_gate_prerequisite = None
        if resume_password_gate:
            previous = json.loads(REPORT.read_text())
            forced_label = 'One real forced password change reaches the authenticated home'
            if (previous.get('hap', {}).get('packagedSha256') != self.hap_sha or
                    previous.get('runtime', {}).get('sha256') != sha(self.runtime_path) or
                    previous.get('cleanup', {}).get('loggedOut') is not True or
                    previous.get('cleanup', {}).get('faultNeutralised') is not True or
                    previous.get('finalPasswordKey') != 'newPassword' or
                    not any(c.get('case') == 'R1' and c.get('label') == forced_label
                            for c in previous.get('checks', []))):
                raise SafeFailure('Resume requires the actually completed forced gate on the same HAP/runtime and explicit logout')
        self.checks = []
        self.observations = []
        self.started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        self.cleanup = {'faultNeutralised': False, 'loggedOut': False}
        self.final_password_key = 'initialPassword'
        self.started = False
        OUT.mkdir(parents=True, exist_ok=True)
        if REPORT.exists():
            attempts = OUT / 'attempts'
            attempts.mkdir(exist_ok=True)
            target = attempts / ('core-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '.json')
            shutil.copyfile(REPORT, target)
            if resume_password_gate:
                self.forced_gate_prerequisite = {'file': str(target.relative_to(ROOT)), 'sha256': sha(target),
                    'scope': 'Only the actual prior forced-password gate on this same HAP/runtime; other failed checks are not carried forward'}
        self.report('running')

    def report(self, status, error=None):
        value = {'status': status, 'scope': 'Task1 core navigation, nickname and ordinary password change',
                 'environment': 'real isolated PocketBase over strict USB HTTPS', 'deviceApi': 26,
                 'startedAt': self.started_at, 'updatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                 'count': len(self.checks), 'checks': self.checks, 'observations': self.observations,
                 'hap': {'packagedSha256': self.hap_sha,
                         'installationEvidence': 'Separate official scripts/hm.sh run log is required'},
                 'runtime': {'file': str(self.runtime_path.relative_to(ROOT)), 'sha256': sha(self.runtime_path)},
                 'requestLedger': self.control.ledger, 'cleanup': self.cleanup,
                 'finalPasswordKey': self.final_password_key,
                 'bootstrapMode': 'resume_verified_forced_gate' if self.resume_password_gate else 'fresh_disposable_player_reset',
                 'forcedPasswordPerformedThisRun': not self.resume_password_gate,
                 'forcedGatePrerequisite': self.forced_gate_prerequisite,
                 'privateScreenshots': self.ui.private_screenshots,
                 'notExecuted': ['A1/A2/A3/A4 system picker, crop, upload and protected-avatar handling',
                                 'S2 ordinary-password response-loss recovery',
                                 'Foldable/hover/split-window work is deferred by user instruction'],
                 'limitations': ['CLI/UiTest core checks are not Hypium instrument tests',
                                 'Injected failures are labelled, not observed production failures',
                                 'No production, start, answer, reward or notification-read write']}
        if error:
            value['error'] = self.ui.redact(error)
        REPORT.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

    def check(self, condition, label, case, injected=False):
        if not condition:
            raise SafeFailure('Task1 expectation did not hold: ' + label)
        self.checks.append({'case': case, 'label': label, 'injectedResilience': injected})
        self.report('running')
        print(json.dumps({'count': len(self.checks), 'passed': label}, ensure_ascii=False), flush=True)

    def rows(self, path, method):
        return [row for row in self.control.requests() if row.get('path') == path and row.get('method') == method]

    def request(self, path, method, before, status, fault=False):
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            rows = self.rows(path, method)
            if len(rows) > before and rows[before].get('status'):
                row = rows[before]
                if row['status'] != status or row.get('fault') is not fault:
                    raise SafeFailure('Expected new request did not have the required status and fault origin')
                return row
            time.sleep(.15)
        raise SafeFailure('Expected new HTTPS request did not finish')

    def checkpoint(self, phase):
        keys = ('method', 'path', 'status', 'fault', 'responseDropped', 'authenticated', 'bearer',
                'bodyKind', 'avatarPartPresent', 'requestBytes', 'fileTokenProvided')
        rows = []
        for row in self.control.requests():
            item = {key: row[key] for key in keys if key in row}
            if str(item.get('path', '')).startswith('/api/files/game_players/'):
                item['path'] = '/api/files/game_players/[owner]/[avatar]'
            rows.append(item)
        self.control.ledger.append({'phase': phase, 'requests': rows})
        self.report('running')

    def login(self, key):
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state[key])
        self.ui.tap('primary-action')

    def profile(self):
        self.ui.tap('nav-profile')
        self.ui.wait(lambda u: u.find('profile-scroll') is not None, 'profile identity editor')
        self.ui.seek('profile-name')

    def bootstrap(self):
        if self.resume_password_gate:
            snapshot = ReadonlySnapshot(self.state)
            snapshot.login(self.state['newPassword'])
            player = snapshot.request(ME)
            if player.get('id') != self.state['playerId'] or player.get('mustChangePassword') is not False:
                raise SafeFailure('The dedicated player no longer matches the verified password gate')
            self.started = True
            self.final_password_key = 'newPassword'
            self.ui.launch(cold=True)
            self.ui.wait(lambda u: u.find('account') is not None, 'resume empty isolated login')
            self.check(self.ui.has_text('隔离测试环境') and not self.ui.has_text('演示环境'),
                       'The phone is explicitly using the dedicated HTTPS environment', 'R1')
            self.login('newPassword')
            self.ui.wait(lambda u: u.find('current-tab') is not None, 'resume authenticated home')
            self.check(self.ui.find('old-password') is None,
                       'A new phone login reaches home using the previously verified changed password', 'R1')
            self.profile()
            return
        self.control.reset()
        self.started = True
        self.ui.launch(cold=True)
        self.ui.wait(lambda u: u.find('account') is not None, 'empty isolated login')
        self.check(self.ui.has_text('隔离测试环境') and not self.ui.has_text('演示环境'),
                   'The phone is explicitly using the dedicated HTTPS environment', 'R1')
        self.login('initialPassword')
        self.ui.wait(lambda u: u.find('old-password') is not None, 'mandatory password gate')
        for field, key in [('old-password', 'initialPassword'), ('new-password', 'newPassword'), ('confirm-password', 'newPassword')]:
            self.ui.fill(field, self.state[key])
        before = len(self.rows(CHANGE, 'POST'))
        self.ui.tap('primary-action')
        self.request(CHANGE, 'POST', before, 200)
        self.final_password_key = 'newPassword'
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'home after one forced change')
        self.check(len(self.rows(CHANGE, 'POST')) == before + 1,
                   'One real forced password change reaches the authenticated home', 'R1')
        self.profile()

    def navigation(self):
        self.ui.tap('account-menu')
        self.ui.wait(lambda u: u.find('menu-profile') is not None, 'complete native account menu')
        for node_id in ['menu-home', 'menu-rewards', 'menu-notifications', 'menu-profile', 'logout']:
            self.ui.seek(node_id)
        self.check(True, 'Account menu exposes the four formal destinations and logout', 'N1')
        self.ui.back()
        self.ui.wait(lambda u: u.find('menu-home') is None and u.find('profile-scroll') is not None,
                     'Back closes the account menu and restores the profile page')
        self.check(self.ui.find('profile-scroll') is not None,
                   'System Back dismisses the menu while preserving the profile page', 'N1')
        self.ui.tap('nav-home')
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'native home destination')
        self.check(self.ui.has_text('下一段故事，等你落笔。'), 'The home tab still reaches the real assignment list', 'R1')
        self.ui.tap('account-menu')
        self.ui.wait(lambda u: u.find('menu-profile') is not None, 'menu on home')
        self.ui.tap('menu-profile')
        self.ui.wait(lambda u: u.find('profile-scroll') is not None and u.find('menu-home') is None, 'menu route to profile')
        self.check(True, 'The account menu opens the same usable profile destination as the bottom tab', 'N1')
        self.ui.seek('profile-account')
        account = self.ui.find('profile-account')
        self.check(account.get('text') == self.state['account'] and account.get('type') not in ('TextInput', 'TextArea'),
                   'The real account is displayed as read-only text', 'N2')
        self.ui.private_shot('profile-identity')
        self.check(self.ui.find('profile-avatar-pick') is not None or self.ui.seek('profile-avatar-pick') is not None,
                   'The real profile exposes its avatar-selection action', 'N2')
        for node_id in ['nav-rewards', 'nav-notifications']:
            self.ui.tap(node_id)
            self.ui.wait(lambda u: u.find('profile-scroll') is not None, 'deferred bottom destination preserves profile')
            self.check(True, 'Deferred destination stays out of an empty page: ' + node_id, 'N1')
        for node_id in ['menu-rewards', 'menu-notifications']:
            self.ui.tap('account-menu')
            self.ui.wait(lambda u: u.find(node_id) is not None, 'deferred menu destination')
            self.ui.tap(node_id)
            self.ui.capture()
            if self.ui.find('menu-home') is not None:
                self.ui.back()
            self.ui.wait(lambda u: u.find('profile-scroll') is not None and u.find('menu-home') is None,
                         'deferred menu destination preserves profile')
            self.check(True, 'Deferred menu action stays out of an empty page: ' + node_id, 'N1')
        self.ui.tap('account-menu')
        self.ui.wait(lambda u: u.find('menu-home') is not None, 'home menu destination')
        self.ui.tap('menu-home')
        self.ui.wait(lambda u: u.find('current-tab') is not None and u.find('menu-profile') is None,
                     'menu reaches the home page')
        self.check(True, 'The account menu home action reaches the usable home page', 'N1')
        self.profile()

    def nickname(self):
        self.ui.seek('profile-name')
        self.ui.run('devecocli', 'ui', 'click', '--id', 'profile-name')
        self.ui.wait(lambda u: u.keyboard_visible(), 'real nickname keyboard')
        field = self.ui.seek('profile-name')
        view = self.ui.viewport('profile-name')
        self.check(field['bounds'][1] >= view[1] and field['bounds'][3] <= view[3],
                   'The nickname input is reachable inside the actual keyboard-resized viewport', 'P1')
        action = self.ui.seek('profile-save')
        view = self.ui.viewport('profile-save')
        self.check(self.ui.keyboard_visible() and action['bounds'][3] - action['bounds'][1] >= 52 * self.ui.density - 2 and
                   action['bounds'][1] >= view[1] and action['bounds'][3] <= view[3],
                   'The whole52vp profile action is reachable while the native keyboard remains open', 'P1')
        self.ui.hide_keyboard()
        before = len(self.rows(PROFILE, 'PATCH'))
        self.ui.fill('profile-name', ' ')
        self.ui.tap('profile-save')
        self.ui.wait(lambda u: u.has_text('给自己起个名字，再出发吧。'), 'blank nickname validation')
        self.check(len(self.rows(PROFILE, 'PATCH')) == before, 'Whitespace-only nickname sends no profile PATCH', 'P1')
        self.ui.fill('profile-name', '  ' + NAME + '  ')
        self.control.call('/fault', {'path': PROFILE, 'method': 'PATCH', 'delayMs': 1000})
        self.ui.seek('profile-save')
        self.ui.run('devecocli', 'ui', 'doubleclick', '--id', 'profile-save')
        row = self.request(PROFILE, 'PATCH', before, 200, fault=True)
        self.ui.wait(lambda u: u.find('profile-saved') is not None, 'successful nickname save')
        self.check(len(self.rows(PROFILE, 'PATCH')) == before + 1,
                   'Two taps during an injected in-flight delay make one real profile write', 'P3', injected=True)
        self.check(row.get('bodyKind') == 'json' and row.get('avatarPartPresent') is False,
                   'Nickname-only saving uses JSON and sends no avatar part', 'P2')
        self.ui.seek('profile-name')
        self.check(self.ui.find('profile-name').get('text') == NAME,
                   'Successful save replaces the draft with the server-normalised nickname', 'P2')
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state[self.final_password_key])
        self.check(snapshot.request(ME).get('displayName') == NAME,
                   'A new strict-HTTPS me read confirms the persisted nickname', 'P2')
        self.ui.fill('profile-name', DRAFT)
        before_me = len(self.rows(ME, 'GET'))
        self.ui.foreground_cycle()
        self.request(ME, 'GET', before_me, 200)
        self.ui.wait(lambda u: u.find('profile-scroll') is not None, 'profile after foreground refresh')
        self.ui.seek('profile-name')
        self.check(self.ui.find('profile-name').get('text') == DRAFT,
                   'A real foreground me refresh preserves the unsaved nickname draft', 'P1')
        before = len(self.rows(PROFILE, 'PATCH'))
        self.control.call('/fault', {'path': PROFILE, 'method': 'PATCH', 'status': 503,
                                    'body': {'error': {'code': 'TEST_PROFILE_UNAVAILABLE', 'message': '隔离资料服务暂时不可用'}}})
        self.ui.tap('profile-save')
        self.request(PROFILE, 'PATCH', before, 503, fault=True)
        self.ui.wait(lambda u: u.find('profile-error') is not None, 'profile error persists')
        self.ui.seek('profile-name')
        self.check(self.ui.find('profile-name').get('text') == DRAFT,
                   'Injected profile503 retains the user draft and shows a persistent error', 'P3', injected=True)
        self.ui.tap('profile-save')
        self.request(PROFILE, 'PATCH', before + 1, 200)
        self.ui.wait(lambda u: u.find('profile-saved') is not None, 'explicit new profile retry')
        self.check(len(self.rows(PROFILE, 'PATCH')) == before + 2,
                   'An explicit retry creates one new successful real profile PATCH', 'P3')
        snapshot.login(self.state[self.final_password_key])
        self.check(snapshot.request(ME).get('displayName') == DRAFT,
                   'Successful retry is confirmed by a fresh authoritative me read', 'P2')
        self.ui.private_shot('profile-saved')
        self.checkpoint('nickname-and-navigation')

    def passwords(self, old, new, confirmation):
        for node_id, value in [('security-old-password', old), ('security-new-password', new), ('security-confirm-password', confirmation)]:
            self.ui.fill(node_id, value)

    def security(self):
        self.ui.tap('profile-security-tab')
        self.ui.wait(lambda u: u.find('security-old-password') is not None, 'ordinary security form')
        before = len(self.rows(CHANGE, 'POST'))
        self.passwords(self.state['newPassword'], self.state['initialPassword'], self.state['initialPassword'] + 'x')
        self.ui.tap('security-save')
        self.ui.wait(lambda u: u.find('security-error') is not None, 'ordinary confirmation validation')
        self.check(len(self.rows(CHANGE, 'POST')) == before,
                   'Ordinary password mismatch sends no change-password POST', 'S1')
        self.passwords('Deliberately-Wrong-Old-Password', self.state['initialPassword'], self.state['initialPassword'])
        self.ui.tap('security-save')
        self.request(CHANGE, 'POST', before, 400)
        self.ui.wait(lambda u: u.has_text('旧密码不正确', contains=True), 'real old-password rejection')
        self.check(len(self.rows(CHANGE, 'POST')) == before + 1,
                   'Wrong old password makes one real POST and keeps the security page', 'S1')
        self.passwords(self.state['newPassword'], self.state['initialPassword'], self.state['initialPassword'])
        self.ui.tap('security-save')
        self.request(CHANGE, 'POST', before + 1, 200)
        self.final_password_key = 'initialPassword'
        self.ui.wait(lambda u: u.find('security-saved') is not None, 'ordinary password success')
        self.check(len(self.rows(CHANGE, 'POST')) == before + 2,
                   'The ordinary password change is submitted exactly once and confirmed200', 'S1')
        self.check(all(self.ui.input_empty(node_id) for node_id in
                       ['security-old-password', 'security-new-password', 'security-confirm-password']),
                   'Confirmed password rotation clears all three native password fields', 'S1')
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state[self.final_password_key])
        player = snapshot.request(ME)
        self.check(player.get('mustChangePassword') is False and player.get('displayName') == DRAFT,
                   'The newly set password really authenticates without a forced-change gate', 'S1')
        self.ui.private_shot('profile-security-saved')
        self.logout()
        self.login(self.final_password_key)
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'phone login using the changed password')
        self.check(self.ui.find('old-password') is None,
                   'The phone can log in with the changed password and reaches home directly', 'S1')
        self.ui.tap('assignment-' + self.state['assignmentId'])
        self.ui.wait(lambda u: u.find('start-assignment') is not None, 'existing read-only detail')
        self.ui.seek('start-assignment')
        self.check(self.ui.find('start-assignment').get('clickable') is not True,
                   'The existing assignment remains explicitly read-only', 'R1')
        self.ui.tap('account-menu')
        self.ui.wait(lambda u: u.find('menu-profile') is not None, 'menu from the assignment')
        self.ui.tap('menu-profile')
        self.ui.wait(lambda u: u.find('profile-scroll') is not None and u.find('menu-home') is None,
                     'profile entered from assignment')
        self.ui.tap('account-menu')
        self.ui.wait(lambda u: u.find('menu-return-assignment') is not None, 'preserved assignment return target')
        self.ui.tap('menu-return-assignment')
        self.ui.wait(lambda u: u.find('start-assignment') is not None and u.find('menu-home') is None,
                     'menu returns to the same assignment')
        self.check(self.ui.has_text('星辰探险'),
                   'Profile navigation preserves the original assignment return relationship', 'N1')
        self.ui.back()
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'Back from existing detail')
        self.check(True, 'System Back returns from the existing detail to the authenticated home', 'R1')
        writes = [row for row in self.control.requests() if row.get('path') in (PROFILE, CHANGE)]
        self.check(bool(writes) and all(row.get('authenticated') and row.get('bearer') is False for row in writes),
                   'Every profile and password write keeps the original token authorisation without Bearer', 'R1')
        self.checkpoint('ordinary-password-and-existing-chain')

    def logout(self):
        self.ui.hide_keyboard()
        self.ui.capture()
        if self.ui.find('forced-logout') is not None:
            self.ui.tap('forced-logout')
        elif self.ui.find('account-menu') is not None:
            self.ui.tap('account-menu')
            self.ui.seek('logout')
            self.ui.tap('logout')
        self.ui.wait(lambda u: u.find('account') is not None, 'empty login after logout')
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('Logout did not clear the login inputs')

    def run(self):
        failure = None
        try:
            self.bootstrap()
            self.navigation()
            self.nickname()
            self.security()
        except Exception as error:
            failure = str(error) if isinstance(error, SafeFailure) else 'Task1 helper stopped before acceptance completed'
        finally:
            if self.started:
                try:
                    self.control.call('/fault', {'path': '/__never_forward_profile_fault__', 'method': 'GET', 'status': 503})
                    self.cleanup['faultNeutralised'] = True
                except Exception:
                    failure = failure or 'Task1 fault cleanup did not complete'
                try:
                    self.logout()
                    self.ui.back()
                    self.ui.launch()
                    self.ui.wait(lambda u: u.find('account') is not None, 'logout Back and Ability gate')
                    self.cleanup['loggedOut'] = self.ui.input_empty('account') and self.ui.input_empty('password')
                    if not self.cleanup['loggedOut']:
                        raise SafeFailure('Task1 logout gate was not restored')
                except Exception:
                    failure = failure or 'Task1 UI cleanup did not complete'
            if sha(ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap') != self.hap_sha:
                failure = failure or 'Packaged HAP changed during the phone run'
            if not failure and not {'N1', 'N2', 'P1', 'P2', 'P3', 'S1', 'R1'}.issubset({c['case'] for c in self.checks}):
                failure = 'Task1 core coverage was incomplete'
            try:
                self.checkpoint('final-cleanup')
            except Exception:
                failure = failure or 'Task1 final request ledger could not be collected'
            self.report('incomplete' if failure else 'passed', failure)
        print(json.dumps({'status': 'incomplete' if failure else 'passed', 'count': len(self.checks),
                          'scope': 'core only; avatar and uncertain-password scopes are separate',
                          'report': str(REPORT.relative_to(ROOT)), 'cleanup': self.cleanup}, ensure_ascii=False))
        return 1 if failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-report', type=Path, default=OUT / 'runtime.json')
    parser.add_argument('--resume-password-gate', action='store_true',
                        help='Keep the same dedicated player only after a linked same-HAP forced gate and explicit logout')
    args = parser.parse_args()
    try:
        return Acceptance(args.runtime_report, args.resume_password_gate).run()
    except Exception as error:
        # Do not echo arbitrary JSON, OS or authentication exception payloads.
        text = str(error) if isinstance(error, SafeFailure) else 'Task1 setup stopped before acceptance completed'
        print(json.dumps({'status': 'incomplete', 'scope': 'core setup', 'error': text}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

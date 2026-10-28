#!/usr/bin/env python3
"""Default-font auth visuals with ONE real password change on the disposable player.

This is a mutating visual prerequisite, separate from the read-only detail captures.
Only blank auth forms are photographed. A password change is never retried.
Use the bundled Python runtime with Pillow for the quickest PNG verification.
"""
import datetime
import json
import sys
import time

from native_device_ui import ROOT, IsolationControl, SafeFailure
from isolated_snapshot import ReadonlySnapshot, private_json, ME, LIST
from native_system_visual import CRITERIA, SystemVisualUI, canvas_evidence, capture_options

OUTPUT = ROOT / 'artifacts/native-system-visual'
WINDOW_VERSION = 'edge-to-edge-v1'
REPORT = OUTPUT / 'auth-capture-summary.json'
CHANGE = '/api/questions/v1/me/change-password'
MASKS = '*•●·'


def safe_error(error, capture, fallback):
    message = str(error) if isinstance(error, SafeFailure) else fallback
    if capture:
        for key in ('account', 'initialPassword', 'newPassword', 'controlToken'):
            secret = capture.state.get(key, '')
            if secret:
                message = message.replace(secret, '[omitted]')
    return message


class AuthCapture:
    def __init__(self):
        self.control = IsolationControl()
        self.state = self.control.state
        config = json.loads((ROOT / 'entry/src/main/resources/rawfile/integration.json').read_text())
        if (config.get('isolated') is not True or config.get('fontScale', 1) != 1 or
                config.get('endpoint') != self.state['tls']['base'] or
                not self.state.get('account', '').startswith('hm_')):
            raise SafeFailure('Only this disposable HTTPS player and default-font build are supported')
        self.ui = SystemVisualUI(OUTPUT, OUTPUT, WINDOW_VERSION)
        self.records = []
        self.owns_player = False
        self.change_attempts = 0
        self.change_confirmed = False
        self.refreshes = []
        self.cleanup = {'singleReadyRestored': False, 'newPasswordConfirmed': False, 'loggedOut': False}

    def report(self, status, error=None):
        value = {'status': status, 'visualCriteria': CRITERIA, 'count': len(self.records), 'states': self.records,
                 'capturedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                 'environment': 'real isolated PocketBase over verified HTTPS',
                 'fontScale': 1, 'window': self.ui.window, 'hap': self.ui.hap,
                 'immersionVersion': self.ui.hap['immersionVersion'], 'mutatingVisualPrerequisite': True,
                 'passwordChangeAttempts': self.change_attempts,
                 'passwordChangeResponseConfirmed': self.change_confirmed, 'cleanup': self.cleanup,
                 'requestLedger': self.control.ledger,
                 'nativeRefreshes': self.refreshes,
                 'limitations': ['This auth precondition performs one real isolated password change',
                                 'It is separate from the read-only visual capture script',
                                 'No production, start, answer or reward operation is performed',
                                 'Capture is not a completed visual comparison']}
        if error:
            value['error'] = error
        REPORT.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

    def wait_request(self, path, number):
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            rows = [row for row in self.control.requests() if row.get('path') == path]
            if len(rows) >= number and rows[number - 1].get('status'):
                row = rows[number - 1]
                if row['status'] != 200 or row.get('fault') is not False:
                    raise SafeFailure('The expected real HTTPS request did not succeed')
                return
            time.sleep(.15)
        raise SafeFailure('The expected real HTTPS request did not finish')

    def top(self):
        self.ui.hide_keyboard()
        self.ui.scroll_body_top()

    def take(self, state, theme):
        self.top()
        self.ui.theme_choice(theme, authenticated=False)
        self.top()
        self.ui.capture()
        if not self.ui.has_text('隔离测试环境') or self.ui.has_text('演示环境'):
            raise SafeFailure('The auth App must visibly identify the isolated HTTPS environment')
        if any(node.get('text', '') for node in self.ui.flat
               if node.get('type') in ('TextInput', 'TextArea', 'SearchField')):
            raise SafeFailure('Non-empty auth input prevented screenshot capture')
        title = next((node for node in self.ui.flat if node.get('text') == '答案之外，\n另有天地。'), None)
        if not title or not title.get('bounds') or abs((title['bounds'][3] - title['bounds'][1]) / self.ui.density - 95.2) > 3:
            raise SafeFailure('The complete default-font story title is not visible')
        name = state + '-' + theme
        self.ui.capture(name)
        target = self.ui.screenshot(name)
        evidence = canvas_evidence(self.ui, target, theme,
                                   'account' if state == 'login' else 'old-password')
        self.records.append({'state': state, 'theme': theme, 'screenshot': target.name,
                             'uiTree': 'ui-' + name + '.json', **evidence,
                             'storyTitleBounds': title['bounds'], 'scrollPosition': 'original top',
                             'visibleInputsEmpty': True})
        self.report('running')
        if not evidence['themeVerified']:
            raise SafeFailure('Auth screenshot does not show the requested theme')

    def password_mask(self, node_id, expected):
        node = self.ui.seek(node_id)
        value = node.get('text', '')
        if not value or len(value) != len(expected) or any(char not in MASKS for char in value):
            raise SafeFailure('Native password masking was not verified: ' + node_id)

    def logout(self):
        self.ui.tap('account-menu')
        self.ui.tap('logout')
        self.ui.wait(lambda u: u.find('account') is not None, 'auth capture logout')

    def run(self):
        self.owns_player = True
        self.control.reset()
        self.ui.launch(cold=True)
        self.ui.wait(lambda u: u.find('account') is not None, 'fresh default-font login')
        for theme in ('dark', 'light'):
            self.take('login', theme)
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state['initialPassword'])
        self.password_mask('password', self.state['initialPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda u: u.find('old-password') is not None, 'real mandatory password gate')
        if any(row.get('path', '').startswith(LIST) for row in self.control.requests()):
            raise SafeFailure('A protected list or detail was requested before password change')
        # Actual /me only: no protected list/detail is fetched while the gate is closed.
        forced = ReadonlySnapshot(self.state)
        forced.login(self.state['initialPassword'])
        player = forced.request(ME)
        if player.get('mustChangePassword') is not True:
            raise SafeFailure('The real test player is not behind the mandatory password gate')
        forced_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        private_json('visual-forced-player.json', {'player': player, 'capturedAt': forced_at})
        for theme in ('dark', 'light'):
            # Capture the original top before seeking any password field or CTA.
            self.take('forced-password', theme)
        for node_id, key in (('old-password', 'initialPassword'), ('new-password', 'newPassword'),
                             ('confirm-password', 'newPassword')):
            self.ui.fill(node_id, self.state[key])
            self.password_mask(node_id, self.state[key])
        if any(row.get('path', '').startswith(LIST) for row in self.control.requests()):
            raise SafeFailure('Protected reads occurred before the mandatory gate was cleared')
        before = self.control.count(CHANGE, 'POST')
        if before != 0:
            raise SafeFailure('Unexpected password write appeared before the single planned submission')
        self.change_attempts = 1
        self.report('running')
        self.ui.tap('primary-action')  # The only change-password submission in this script.
        self.wait_request(CHANGE, before + 1)
        self.change_confirmed = True
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'home after real password change')
        if self.control.count(CHANGE, 'POST') != before + 1:
            raise SafeFailure('Password change must have exactly one request')
        self.control.call('/scenario', {'singleAssignment': True})
        self.control.call('/scenario', {'status': 'assigned'})
        self.refreshes.append(self.ui.pull_refresh(self.control, LIST))
        canonical = ReadonlySnapshot(self.state)
        canonical.login(self.state['newPassword'])
        data = canonical.capture()
        if (data['player'].get('mustChangePassword') is not False or
                len(data['assignments'].get('items', [])) != 1 or data['assignment'].get('status') != 'assigned'):
            raise SafeFailure('Canonical new-password single-ready state was not confirmed')
        captured_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        private_json('visual-responses.json', {**data, 'provenance': {
            'environment': 'real isolated PocketBase over verified HTTPS', 'capturedAt': captured_at,
            'operations': 'real auth and GET after native password change; one ready assignment',
            'responseRewriting': False}})
        private_json('visual-responses-forced.json', {**data, 'player': player, 'provenance': {
            'player': 'actual forced GET /me at ' + forced_at,
            'assignmentAndList': 'actual post-gate GET at ' + captured_at,
            'visualUse': 'forced UI consumes only the original forced player',
            'mixedCaptureTimes': True, 'responseRewriting': False}})
        self.cleanup['newPasswordConfirmed'] = True
        self.logout()
        if len(self.records) != 4:
            raise SafeFailure('All four blank auth visuals were not captured')

    def restore(self):
        if not self.owns_player:
            return
        try:
            self.control.call('/scenario', {'status': 'assigned'})
            self.control.call('/scenario', {'singleAssignment': True})
            self.cleanup['singleReadyRestored'] = True
            # Resolve the result with authentication; never repeat the password write.
            confirmed = ReadonlySnapshot(self.state)
            confirmed.login(self.state['newPassword'])
            self.cleanup['newPasswordConfirmed'] = confirmed.request(ME).get('mustChangePassword') is False
            if not self.cleanup['newPasswordConfirmed']:
                raise SafeFailure('The canonical new password was not confirmed')
        finally:
            try:
                self.ui.hide_keyboard()
                self.ui.capture()
                if not self.ui.find('account'):
                    self.logout()
                if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
                    raise SafeFailure('Auth cleanup requires cleared login inputs')
            except SafeFailure:
                self.ui.launch(cold=True)
                self.ui.wait(lambda u: u.find('account') is not None, 'auth cleanup cold login')
            self.cleanup['loggedOut'] = self.ui.input_empty('account') and self.ui.input_empty('password')
            if not self.cleanup['loggedOut']:
                raise SafeFailure('Auth cleanup did not leave the App logged out')
            self.control.checkpoint('mutating-auth-visual-prerequisite')


def main():
    global OUTPUT, REPORT, WINDOW_VERSION
    options = capture_options()
    OUTPUT = options.output_dir
    WINDOW_VERSION = options.window_version
    REPORT = OUTPUT / 'auth-capture-summary.json'
    OUTPUT.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps({'status': 'running', 'visualCriteria': CRITERIA, 'count': 0, 'states': []}) + '\n')
    capture, failure = None, None
    try:
        capture = AuthCapture()
        capture.report('running')
        capture.run()
    except Exception as error:
        failure = safe_error(error, capture, 'Auth visual prerequisite needs review')
    finally:
        if capture:
            try:
                capture.restore()
            except Exception as error:
                detail = safe_error(error, capture, 'Auth cleanup needs review')
                failure = (failure + '; ' if failure else '') + detail
            capture.report('incomplete' if failure else 'captured', failure)
        elif failure:
            REPORT.write_text(json.dumps({'status': 'incomplete', 'visualCriteria': CRITERIA,
                                         'count': 0, 'states': [], 'error': failure}) + '\n')
    print(json.dumps({'status': 'incomplete' if failure else 'captured',
                      'count': len(capture.records) if capture else 0,
                      'report': str(REPORT.relative_to(ROOT)), 'error': failure}, ensure_ascii=False))
    return 1 if failure else 0


if __name__ == '__main__':
    sys.exit(main())

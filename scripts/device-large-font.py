#!/usr/bin/env python3
"""Own-device API26 fontScale=1.3 acceptance on the disposable HTTPS backend.

Never changes system settings. Plaintext password-eye probes stay only in memory.
"""
import datetime
import hashlib
import math
import json
import shlex
import sys
import time
import urllib.request

from native_device_ui import ROOT, DeviceUI, IsolationControl, SafeFailure, flatten
from isolated_snapshot import ReadonlySnapshot

OUT = ROOT / 'artifacts/validation/large-font'
REPORT = ROOT / 'artifacts/validation/device-large-font.json'
DENSITY = 3.375  # Replaced by this installed build's actual runtime before any UI operation.
SCALE = 1.3
TITLE = '答案之外，\n另有天地。'
AUTH = '/api/collections/game_players/auth-with-password'
ME = '/api/questions/v1/me'
LIST = '/api/questions/v1/assignments'
CHANGE = '/api/questions/v1/me/change-password'
MASKS = '*•●·'


def masked(value):
    return bool(value) and all(char in MASKS for char in value)


def intersect(a, b):
    return [max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])]


class AppViewportUI(DeviceUI):
    """Scroll inside the current App root/Scroll intersection, including with IME."""
    def app_rect(self):
        node = next((node for node in self.flat if node.get('type') == 'root' and node.get('bounds')), None)
        if node is None:
            raise SafeFailure('Current App root bounds are unavailable')
        return node['bounds']

    def path_to(self, node_id):
        def visit(value, parents):
            if isinstance(value, list):
                for child in value:
                    result = visit(child, parents)
                    if result is not None:
                        return result
            elif isinstance(value, dict):
                if value.get('id') == node_id:
                    return parents + [value]
                for child in value.get('children', []):
                    result = visit(child, parents + [value])
                    if result is not None:
                        return result
            return None
        return visit(self.tree, [])

    def viewport(self, node_id=None):
        app = self.app_rect()
        path = self.path_to(node_id) if node_id else None
        scrolls = [node for node in (path or self.flat) if node.get('type') == 'Scroll' and node.get('bounds')]
        if path is not None:
            scroll = scrolls[-1] if scrolls else None
        else:
            scroll = max(scrolls, key=lambda node: max(0, node['bounds'][2] - node['bounds'][0]) *
                         max(0, node['bounds'][3] - node['bounds'][1])) if scrolls else None
        view = intersect(app, scroll['bounds']) if scroll else app
        if scroll and scroll.get('id') in ('current-scroll', 'history-scroll'):
            # The content intentionally paints beneath the native floating bar.
            # A whole-control interaction must use its unobscured region.
            bar_path = self.path_to('nav-home')
            bar = next((node for node in reversed(bar_path or []) if node.get('type') == 'TabBar' and node.get('bounds')), None)
            if bar and bar['bounds'][1] > view[1]:
                view[3] = min(view[3], bar['bounds'][1])
        return view

    def swipe(self, direction):
        self.capture()
        left, top, right, bottom = self.viewport()
        if right - left < 80 or bottom - top < 150:
            raise SafeFailure('App scroll viewport is too small for a safe gesture')
        x = int(left + (right - left) * .58)
        low = int(top + (bottom - top) * .76)
        high = int(top + (bottom - top) * .30)
        start, end = (low, high) if direction == 'down' else (high, low)
        self.run('devecocli', 'ui', 'swipe', x, start, x, end)

    def seek(self, node_id, max_swipes=9):
        for direction in ('down', 'up'):
            previous = None
            for attempt in range(max_swipes + 1):
                self.capture()
                node = self.find(node_id)
                if node and node.get('bounds'):
                    left, top, right, bottom = node['bounds']
                    visible = self.viewport(node_id)
                    minimum = 52 * DENSITY * .9 if node.get('type') == 'TextInput' or node_id in ('primary-action', 'start-assignment') else (16 * SCALE * DENSITY * .9 if node_id == 'assignment-sync-note-text' else (45.6 * DENSITY * .9 if node_id == 'login-help' else 1))
                    if (right > left and bottom - top >= minimum and left >= visible[0] + 4 and
                            right <= visible[2] - 4 and top >= visible[1] + 8 and bottom <= visible[3] - 8):
                        return node
                fingerprint = self.visible_fingerprint()
                if fingerprint == previous:
                    break
                previous = fingerprint
                if attempt < max_swipes:
                    self.swipe(direction)
        raise SafeFailure('Whole App control is not reachable inside its viewport: ' + node_id)

    def fill(self, node_id, value):
        # Same official replacement driver as native_device_ui.fill, with a
        # fresh bounded seek after focusing has resized the App for the IME.
        self.hide_keyboard()
        self.seek(node_id)
        self.run('devecocli', 'ui', 'click', '--id', node_id)
        self.wait(lambda u: u.keyboard_visible(), 'large-font input keyboard after focus')
        self.seek(node_id)
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017')
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', '2055')
        self.capture()
        cleared = self.find(node_id)
        if cleared is None or cleared.get('text', ''):
            raise SafeFailure('Large-font input clearing was not verified: ' + node_id)
        if value:
            self.run('hdc', 'shell', 'uitest uiInput text ' + shlex.quote(value))
        self.back()
        self.capture()
        node = self.find(node_id)
        observed = node.get('text', '') if node else ''
        if node is None or not (observed == value or (masked(observed) and len(observed) == len(value))):
            raise SafeFailure('Large-font input replacement was not verified: ' + node_id)


def restore_isolated_password_after_test(state):
    """Explicit cleanup mutation, never a UI pass or an automatic write retry."""
    snapshot = ReadonlySnapshot(state)
    try:
        snapshot.login(state['newPassword'])
        if snapshot.request(ME).get('mustChangePassword') is False:
            return {'newPasswordConfirmed': True, 'passwordWritePerformed': False}
    except SafeFailure:
        pass
    snapshot.login(state['initialPassword'])
    request = urllib.request.Request(state['tls']['hostBase'] + CHANGE, method='POST',
        data=json.dumps({'oldPassword': state['initialPassword'], 'password': state['newPassword'],
                         'passwordConfirm': state['newPassword']}).encode(),
        headers={'Authorization': snapshot.token, 'Content-Type': 'application/json', 'Accept': 'application/json'})
    write_response_confirmed = False
    try:
        with urllib.request.urlopen(request, context=snapshot.context, timeout=25) as response:
            write_response_confirmed = response.status == 200
            response.read()
    except Exception:
        # A lost write response must be resolved by login, never by replaying it.
        pass
    confirmed = ReadonlySnapshot(state)
    confirmed.login(state['newPassword'])
    if confirmed.request(ME).get('mustChangePassword') is not False:
        raise SafeFailure('Cleanup could not confirm the changed test password')
    return {'newPasswordConfirmed': True, 'passwordWritePerformed': True,
            'writeResponseConfirmed': write_response_confirmed, 'uiAcceptanceCredit': False}


class LargeFontAcceptance:
    def __init__(self):
        config = json.loads((ROOT / 'entry/src/main/resources/rawfile/integration.json').read_text())
        if config.get('isolated') is not True or config.get('fontScale') != SCALE:
            raise SafeFailure('Install the isolated fontScale=1.3 test build before this run')
        global DENSITY
        runtime_path = ROOT / 'artifacts/validation/native-system-font-runtime.json'
        runtime_raw = runtime_path.read_bytes()
        self.runtime_evidence = json.loads(runtime_raw)
        self.window = self.runtime_evidence['window']
        if (not isinstance(self.window.get('fontScale'), (int,float)) or
                not math.isfinite(self.window['fontScale']) or abs(self.window['fontScale']-SCALE) > .001 or self.window.get('immersiveLayout') != 'enabled' or
                not isinstance(self.window.get('density'), (int,float)) or
                not math.isfinite(self.window['density']) or self.window['density'] <= 0):
            raise SafeFailure('Actual immersive fontScale=1.3 window evidence is required')
        DENSITY = float(self.window['density'])
        self.runtime_source = {'path': str(runtime_path.relative_to(ROOT)), 'sha256': hashlib.sha256(runtime_raw).hexdigest()}
        self.control = IsolationControl()
        self.state = self.control.state
        self.ui = AppViewportUI(OUT, OUT)
        self.checks = []
        self.geometry = []
        self.cleanup = {'newPasswordConfirmed': False, 'singleReadyRestored': False, 'loggedOut': False}
        self.password_keyboard_observations = []
        self.owns_player = False
        self.report('running')

    def report(self, status, error=None):
        data = {'status': status, 'count': len(self.checks), 'checks': self.checks,
                'environment': 'real isolated PocketBase over strictly verified HTTPS',
                'visualCriteria': 'arkui-system-v1', 'immersionVersion': 'edge-to-edge-v1',
                'installedHapSha256': self.runtime_evidence.get('installedHapSha256'), 'fontScale': SCALE, 'density': DENSITY, 'densitySource': self.runtime_source, 'window': self.window,
                'geometry': self.geometry, 'passwordFocusKeyboardObservations': self.password_keyboard_observations, 'cleanup': self.cleanup, 'requestLedger': self.control.ledger,
                'capturedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                'limitations': ['No actual screen reader or spoken accessibility validation',
                                'Only this App fontSizeScale test configuration; system-wide settings were not changed',
                                'Whole-control visibility and scrolling are device evidence; not an accessibility audit',
                                'Cleanup mutations do not count as successful UI acceptance']}
        if error:
            data['error'] = error
        REPORT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

    def check(self, condition, label):
        if not condition:
            raise SafeFailure('Large-font expectation did not hold: ' + label)
        self.checks.append(label)
        self.report('running')
        print(json.dumps({'passed': label, 'count': len(self.checks)}, ensure_ascii=False), flush=True)

    def wait_request(self, path, number):
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            rows = [row for row in self.control.requests() if row.get('path') == path]
            if len(rows) >= number and rows[number - 1].get('status'):
                if rows[number - 1]['status'] != 200 or rows[number - 1].get('fault') is not False:
                    raise SafeFailure('Expected new real HTTPS request did not return 200: ' + path)
                return rows[number - 1]
            time.sleep(.15)
        raise SafeFailure('Expected new HTTPS request did not finish: ' + path)

    def evidence(self, name):
        self.ui.capture()
        # No screenshot is permitted with any visible plaintext input, including
        # the synthetic username and the non-sensitive eye probe.
        if any(node.get('text', '') and not masked(node.get('text', ''))
               for node in self.ui.flat if node.get('type') in ('TextInput', 'TextArea', 'SearchField')):
            raise SafeFailure('Plaintext input prevented screenshot capture')
        self.ui.capture(name)
        self.ui.screenshot(name)

    def reachable(self, node_id, label):
        node = self.ui.seek(node_id)
        self.geometry.append({'control': node_id, 'bounds': node['bounds'],
                              'viewport': self.ui.viewport(node_id), 'appRoot': self.ui.app_rect()})
        self.check(True, label)

    def keyboard(self, field, context):
        self.ui.tap(field)
        self.ui.wait(lambda u: u.keyboard_visible(), context + ' keyboard visible')
        self.reachable(field, context + ' focused field is wholly visible above the keyboard')
        self.reachable('primary-action', context + ' primary action is reachable inside the App with the keyboard open')
        self.check(self.ui.keyboard_visible(), context + ' scrolling did not require a gesture inside the keyboard')
        if field == 'account':
            self.evidence(context + '-keyboard-cta')
        else:
            # Earlier secure-password IME snapshots were entirely withheld.
            # Keep actual UiTest reachability evidence; no black PNG is called a
            # successful theme or visual capture, and no plaintext probe is saved.
            self.ui.capture(context + '-keyboard-cta')
            self.password_keyboard_observations.append({
                'field': field, 'keyboardVisible': True, 'source': 'official UiTest bounds above actual IME',
                'screenshotAttempted': False, 'visualThemeAcceptanceCredit': False,
                'reason': 'Previous password-focus snapshots were entirely black; exact OS cause is unconfirmed'})
        self.ui.back()
        self.ui.wait(lambda u: not u.keyboard_visible(), context + ' keyboard dismissed')
        self.check(True, context + ' native keyboard opens and closes')

    def eye(self):
        probe = 'VisibilityProbe42'  # Public, non-sensitive, never printed or saved.
        self.ui.fill('password', probe)
        self.ui.seek('password')
        value = self.ui.find('password').get('text', '')
        self.check(masked(value) and len(value) == len(probe), 'Password probe starts masked')
        for visible in (True, False):
            field = self.ui.seek('password')
            candidates = [node for node in flatten(field.get('children', []))
                          if node.get('type') == 'Stack' and node.get('clickable') in (True, 'true') and node.get('bounds')]
            if not candidates:
                raise SafeFailure('Current native password-eye control is not exposed')
            eye = max(candidates, key=lambda node: node['bounds'][0])
            left, top, right, bottom = eye['bounds']
            self.ui.run('devecocli', 'ui', 'click', (left + right) // 2, (top + bottom) // 2)
            # Raw trees remain in memory here. No screenshot or saved tree.
            self.ui.capture()
            value = self.ui.find('password').get('text', '') if self.ui.find('password') else ''
            if visible:
                self.check(value == probe, 'Native password eye reveals only the non-sensitive probe in memory')
            else:
                self.check(masked(value) and len(value) == len(probe), 'Native password eye restores masking')
        self.ui.hide_keyboard()
        self.ui.fill('password', '')

    def run(self):
        # A dropped control response may still have reset the account, so own
        # cleanup responsibility before sending this local mutation.
        self.owns_player = True
        self.control.reset()
        self.control.call('/scenario', {'singleAssignment': True})
        self.ui.launch(cold=True)
        self.ui.wait(lambda u: u.find('account') is not None, 'large-font login')
        self.check(self.ui.has_text('隔离测试环境'), 'App identifies the isolated HTTPS environment')
        title = None
        for _ in range(10):
            self.ui.capture()
            title = next((node for node in self.ui.flat if node.get('text') == TITLE), None)
            if title and title.get('bounds') and title['bounds'][1] > self.ui.app_rect()[1] + 8:
                break
            self.ui.swipe('up')
        if not title or not title.get('bounds'):
            raise SafeFailure('The complete two-line story title was not found')
        height_vp = (title['bounds'][3] - title['bounds'][1]) / DENSITY
        expected_vp = 47.6 * 2 * SCALE
        self.geometry.append({'control': 'two-line-story-title', 'bounds': title['bounds'], 'heightVp': height_vp,
                              'expectedHeightVp': expected_vp, 'defaultHeightVp': 47.6 * 2})
        self.check(abs(height_vp - expected_vp) <= 3,
                   'Two-line story title height proves the installed App uses fontScale 1.3')
        self.evidence('large-font-login-title')
        for field in ('account', 'password', 'primary-action'):
            self.reachable(field, 'Login control remains wholly reachable: ' + field)
        self.reachable('login-help', 'Larger-font account-help disclosure remains wholly reachable')
        self.ui.tap('login-help')
        self.ui.wait(lambda u:u.has_text('账号由游戏管理员提供，暂不开放注册。忘记密码时，请联系游戏管理员重置。'),
                     'larger-font account help')
        self.check(True, 'Native animation-backed account help still opens at the larger font size')
        self.ui.tap('login-help')
        self.ui.wait(lambda u:not u.has_text('账号由游戏管理员提供，暂不开放注册。忘记密码时，请联系游戏管理员重置。'),
                     'larger-font help closes')
        self.eye()
        self.keyboard('password', 'large-font-login-password')
        self.keyboard('account', 'large-font-login-account')
        self.check(self.control.count(AUTH, 'POST') == 0, 'Visibility and keyboard probes send no authentication request')
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state['initialPassword'])
        auth_before = self.control.count(AUTH, 'POST')
        self.ui.tap('primary-action')
        self.wait_request(AUTH, auth_before + 1)
        self.ui.wait(lambda u: u.find('old-password') is not None, 'large-font mandatory password gate')
        self.check(self.control.count(LIST, 'GET') == 0, 'Real initial-password login remains behind the mandatory gate')
        for field in ('old-password', 'new-password', 'confirm-password', 'primary-action'):
            self.reachable(field, 'Mandatory password control remains wholly reachable: ' + field)
        self.evidence('large-font-forced-controls')
        for field in ('old-password', 'new-password', 'confirm-password'):
            self.keyboard(field, 'large-font-forced-' + field)
        self.ui.fill('old-password', self.state['initialPassword'])
        self.ui.fill('new-password', self.state['newPassword'])
        self.ui.fill('confirm-password', self.state['newPassword'])
        before = self.control.count(CHANGE, 'POST')
        list_before = self.control.count(LIST, 'GET')
        self.ui.tap('primary-action')
        self.wait_request(CHANGE, before + 1)
        self.wait_request(LIST, list_before + 1)
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'large-font home')
        self.check(self.control.count(CHANGE, 'POST') == before + 1, 'One real password change unlocks the large-font home')
        self.ui.capture()
        bars=[node['bounds'] for node in self.ui.flat if node.get('type')=='TabBar' and node.get('bounds') and node['bounds'][1]>self.window['heightPx']*.6]
        if not bars:
            raise SafeFailure('Larger-font native floating bar was not exposed')
        actual_bar=max(bars,key=lambda bounds:bounds[1])
        safe_bottom=self.window['heightPx']-self.window['bottomInsetPx']
        self.geometry.append({'control':'large-font-floating-bar','bounds':actual_bar,'safeBottomPx':safe_bottom})
        self.check(actual_bar[3]<=safe_bottom, 'Larger-font native bar stays above the actual gesture region')
        self.evidence('large-font-home')
        self.reachable('assignment-sync-note-text', 'Larger-font final sync sentence is fully reachable above the floating bar')
        self.evidence('large-font-home-scroll-end')
        card = 'assignment-' + self.state['assignmentId']
        detail = LIST + '/' + self.state['assignmentId']
        before = self.control.count(detail, 'GET')
        self.ui.tap(card)
        self.wait_request(detail, before + 1)
        self.reachable('start-assignment', 'Read-only detail start control is wholly reachable at the larger font size')
        self.evidence('large-font-detail')
        self.ui.back()
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'large-font detail system Back')
        self.check(True, 'System Back from detail returns to the larger-font home')
        self.logout()
        self.check(self.ui.input_empty('account') and self.ui.input_empty('password'), 'Explicit logout clears both login fields')
        self.evidence('large-font-logout')

    def logout(self):
        self.ui.tap('account-menu')
        self.ui.tap('logout')
        self.ui.wait(lambda u: u.find('account') is not None, 'large-font logout')

    def restore(self):
        if not self.owns_player:
            return
        try:
            self.cleanup.update(restore_isolated_password_after_test(self.state))
        finally:
            try:
                self.control.call('/scenario', {'status': 'assigned'})
                self.control.call('/scenario', {'singleAssignment': True})
                self.cleanup['singleReadyRestored'] = True
            finally:
                try:
                    self.ui.hide_keyboard()
                    self.ui.capture()
                    if not self.ui.find('account'):
                        self.logout()
                    if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
                        raise SafeFailure('Cleanup needs a fresh empty login page')
                except SafeFailure:
                    self.ui.launch(cold=True)
                    self.ui.wait(lambda u: u.find('account') is not None, 'large-font cleanup cold login')
                self.cleanup['loggedOut'] = self.ui.input_empty('account') and self.ui.input_empty('password')
                if not self.cleanup['loggedOut']:
                    raise SafeFailure('Large-font cleanup could not verify empty logged-out inputs')
                self.control.checkpoint('large-font-including-explicit-cleanup')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps({'status': 'running', 'count': 0, 'checks': []}) + '\n')
    run, failure = None, None
    try:
        run = LargeFontAcceptance()
        run.run()
    except Exception as error:
        failure = str(error) if isinstance(error, SafeFailure) else 'Large-font driver needs review: ' + type(error).__name__
    finally:
        if run:
            try:
                run.restore()
            except Exception as error:
                cleanup_error = str(error) if isinstance(error, SafeFailure) else 'Large-font cleanup needs review'
                failure = (failure + '; ' if failure else '') + cleanup_error
            run.report('incomplete' if failure else 'passed', failure)
        elif failure:
            REPORT.write_text(json.dumps({'status': 'incomplete', 'count': 0, 'checks': [], 'error': failure}) + '\n')
    print(json.dumps({'status': 'incomplete' if failure else 'passed', 'count': len(run.checks) if run else 0,
                      'report': 'artifacts/validation/device-large-font.json', 'error': failure}, ensure_ascii=False))
    return 1 if failure else 0


if __name__ == '__main__':
    sys.exit(main())

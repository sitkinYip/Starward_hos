#!/usr/bin/env python3
"""Official ArkUI visuals on the disposable verified-HTTPS test environment.

Requires the changed test password, one ready assignment and a logged-out App.
Never changes a password, starts an assignment or submits an answer.
Use the bundled Python runtime with Pillow for the quickest PNG verification.
"""
import datetime
import hashlib
import statistics
import json
import sys
import time

from native_device_ui import ROOT, IsolationControl, SafeFailure, flatten
from isolated_snapshot import ReadonlySnapshot, private_json
from native_system_visual import CRITERIA, SystemVisualUI, canvas_evidence, capture_options, png_pixels, COLORS

OUTPUT = ROOT / 'artifacts/native-system-visual'
WINDOW_VERSION = 'edge-to-edge-v1'
RESUME_DARK_CHECKPOINT = None
AUTH = '/api/collections/game_players/auth-with-password'
LIST = '/api/questions/v1/assignments'
DETAIL_FAULT_BODY = {'error': {'code': 'NOT_FOUND', 'message': '场次暂时无法打开，请返回首页。'}}


def safe_error(error, capture, fallback):
    message = str(error) if isinstance(error, SafeFailure) else fallback
    if capture:
        for key in ('account', 'initialPassword', 'newPassword', 'controlToken'):
            secret = capture.state.get(key, '')
            if secret:
                message = message.replace(secret, '[omitted]')
    return message


class Capture:
    def __init__(self):
        self.control = IsolationControl()
        self.state = self.control.state
        if not self.state.get('account', '').startswith('hm_') or not self.state.get('newPassword'):
            raise SafeFailure('Only the generated disposable test player is supported')
        config = json.loads((ROOT / 'entry/src/main/resources/rawfile/integration.json').read_text())
        if (config.get('isolated') is not True or config.get('fontScale', 1) != 1 or
                config.get('endpoint') != self.state['tls']['base']):
            raise SafeFailure('Only the disposable HTTPS environment and default-font build are supported')
        self.ui = SystemVisualUI(OUTPUT, OUTPUT, WINDOW_VERSION)
        self.records = []
        self.observations = []
        prior_blackout = ROOT / 'artifacts/validation/keyboard-snapshot-analysis.json'
        if prior_blackout.is_file():
            prior = json.loads(prior_blackout.read_text())
            self.observations.append({
                'kind': 'historical password-focus screenshot blackout',
                'source': str(prior_blackout.relative_to(ROOT)),
                'sourceScreenshot': prior.get('sourceScreenshot'),
                'screenshotSha256': prior.get('screenshotSha256'),
                'keyboardFocus': 'password',
                'themeVerified': False,
                'acceptanceCredit': False,
                'cause': 'Exact OS cause unconfirmed; secure-keyboard snapshot protection is an inference'
            })
        self.snapshots = []
        self.fault_recoveries = []
        self.baseline = len(self.control.requests())
        self.cleanup = {'scenarioRestored': False, 'loggedOut': False, 'faultNeutralised': False}
        self.preserved = [name for name in ('login-light.png', 'login-dark.png',
                          'forced-password-light.png', 'forced-password-dark.png')
                          if (OUTPUT / name).exists()]
        self.resumed_from = None
        self.retained_count = 0
        if RESUME_DARK_CHECKPOINT is not None:
            self.load_dark_checkpoint(RESUME_DARK_CHECKPOINT)

    def load_dark_checkpoint(self, source):
        """Retain an exact legal same-build prefix; never inherit a failed row."""
        source = source if source.is_absolute() else ROOT / source
        source = source.resolve()
        try:
            source.relative_to((ROOT / 'artifacts').resolve())
        except ValueError:
            raise SafeFailure('The visual checkpoint must remain under project artifacts') from None
        raw = source.read_bytes()
        checkpoint = json.loads(raw)
        if (checkpoint.get('status') != 'incomplete' or checkpoint.get('visualCriteria') != CRITERIA or
                checkpoint.get('immersionVersion') != WINDOW_VERSION or
                checkpoint.get('hap') != self.ui.hap or checkpoint.get('window') != self.ui.window or
                checkpoint.get('count') != len(checkpoint.get('states', [])) or
                not all(checkpoint.get('cleanup', {}).get(key) is True for key in
                        ('scenarioRestored', 'loggedOut', 'faultNeutralised'))):
            raise SafeFailure('The archived visual checkpoint has a different build, window or incomplete cleanup')
        archived = {row['path']: row['sha256'] for row in
                    json.loads((source.parent / 'archive-manifest.json').read_text())['files']}
        expected = [(state, theme) for theme in ('dark', 'light')
                    for state in ('home', 'detail', 'history', 'logout', 'login-keyboard')]
        count = next((number for number in (10, 9, 8, 5) if len(checkpoint['states']) >= number and
                      all(row.get('themeVerified') is True for row in checkpoint['states'][:number])), None)
        if count is None:
            raise SafeFailure('The visual checkpoint has no complete legal prefix')
        rows = checkpoint['states'][:count]
        if [(row.get('state'), row.get('theme')) for row in rows] != expected[:count]:
            raise SafeFailure('The visual checkpoint does not have the required state/theme prefix')
        previous = checkpoint.get('resumedFrom')
        ancestor, seen = previous, set()
        for _ in range(16):
            if not ancestor:
                break
            previous_source = (ROOT / ancestor['source']).resolve()
            try:
                previous_source.relative_to((ROOT / 'artifacts').resolve())
            except ValueError:
                raise SafeFailure('The previous resume source is outside project artifacts') from None
            if previous_source in seen:
                raise SafeFailure('The visual checkpoint resume history contains a cycle')
            seen.add(previous_source)
            previous_raw = previous_source.read_bytes()
            if hashlib.sha256(previous_raw).hexdigest() != ancestor.get('sha256'):
                raise SafeFailure('A prior visual resume source no longer matches its recorded SHA')
            previous_report = json.loads(previous_raw)
            if previous_report.get('hap') != self.ui.hap or previous_report.get('window') != self.ui.window:
                raise SafeFailure('A prior visual resume source belongs to a different build or window')
            ancestor = previous_report.get('resumedFrom')
        else:
            raise SafeFailure('The visual resume history exceeded its bounded review limit')
        retained = []
        for row in rows:
            state, theme = row['state'], row['theme']
            png_name, ui_name = state + '-' + theme + '.png', 'ui-' + state + '-' + theme + '.json'
            if (row.get('screenshot') != png_name or row.get('uiTree') != ui_name or
                    row.get('themeVerified') is not True or row.get('sampleFlat') is not True or
                    row.get('visibleInputsEmpty') is not True or
                    (state == 'login-keyboard' and (row.get('keyboard') is not True or row.get('keyboardFocus') != 'account'))):
                raise SafeFailure('A retained visual row did not satisfy its original prerequisites')
            digests = {}
            for name in (png_name, ui_name):
                old, current = source.parent / name, OUTPUT / name
                if old.is_symlink() or current.is_symlink():
                    raise SafeFailure('Visual checkpoint files must not be symlinks')
                digest = hashlib.sha256(old.read_bytes()).hexdigest()
                if archived.get(name) != digest or hashlib.sha256(current.read_bytes()).hexdigest() != digest:
                    raise SafeFailure('A retained visual file changed after its archived attempt')
                digests[name] = digest
            if row.get('screenshotSha256') != digests[png_name]:
                raise SafeFailure('A retained PNG hash does not match its capture record')
            x, y = row['sample']
            width, height, channels, pixels = png_pixels(OUTPUT / png_name, through_row=y + 2)
            if row.get('pixels') != [width, height] or not (2 <= x < width - 2 and 2 <= y < height - 2):
                raise SafeFailure('A retained PNG size or sample is invalid')
            values = [[pixels[py][px * channels + channel] for py in range(y - 2, y + 3)
                       for px in range(x - 2, x + 3)] for channel in range(3)]
            observed = [int(statistics.median(value)) for value in values]
            if (observed != row.get('canvasRGB') or row.get('expectedRGB') != list(COLORS[theme]) or
                    not all(max(value) - min(value) <= 4 for value in values) or
                    not all(abs(actual - wanted) <= 4 for actual, wanted in zip(observed, COLORS[theme]))):
                raise SafeFailure('A retained PNG did not independently pass the original strict pixel check')
            retained.append({'state': state, 'theme': theme, 'screenshotSha256': digests[png_name],
                             'uiTreeSha256': digests[ui_name]})
        home_tree = json.loads((source.parent / 'ui-home-dark.json').read_text())
        if not any(node.get('id') == 'assignment-' + self.state['assignmentId'] for node in flatten(home_tree)):
            raise SafeFailure('The retained home does not belong to the current disposable backend epoch')
        self.records = rows
        self.retained_count = count
        self.resumed_from = {'source': str(source.relative_to(ROOT)),
            'sha256': hashlib.sha256(raw).hexdigest(), 'originalStatus': 'incomplete',
            'originalCount': checkpoint['count'], 'retainedCount': count, 'newExpectedCount': 18 - count,
            'previousResume': previous,
            'epochVerification': 'Archived home assignment ID matches the current disposable backend state',
            'retained': retained,
            'discardedRows': [{'state': row.get('state'), 'theme': row.get('theme'),
                               'themeVerified': row.get('themeVerified')} for row in checkpoint['states'][count:]],
            'note': 'Final 18 combines the explicitly verified retained prefix and newly captured states; not one uninterrupted run'}

    def environment(self):
        self.ui.capture()
        if not self.ui.has_text('隔离测试环境') or self.ui.has_text('演示环境'):
            raise SafeFailure('The foreground App must identify the isolated HTTPS environment')

    def wait_request(self, path, minimum, status=200, injected=None):
        deadline = time.monotonic() + 25
        while time.monotonic() < deadline:
            rows = [row for row in self.control.requests() if row.get('path') == path and row.get('method') == 'GET']
            if len(rows) >= minimum and rows[minimum - 1].get('status'):
                selected = rows[minimum - 1]
                if selected['status'] != status or (injected is not None and selected.get('fault') is not injected):
                    raise SafeFailure('The specific isolated read did not match the expected status and fault origin')
                return selected
            time.sleep(.15)
        raise SafeFailure('The expected isolated read did not finish')

    def login(self):
        self.environment()
        if not self.ui.find('account') or self.ui.find('old-password'):
            raise SafeFailure('Visual capture requires the logged-out login page')
        before = self.control.count(LIST, 'GET')
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda u: u.find('current-tab') is not None or u.find('old-password') is not None,
                     'changed-password login reaches home')
        if self.ui.find('old-password'):
            raise SafeFailure('Password change is still required; capture never performs it')
        self.wait_request(LIST, before + 1, injected=False)
        self.ui.wait(lambda u: u.find('assignment-' + self.state['assignmentId']) is not None,
                     'ready assignment loaded')

    def theme(self, name, authenticated=True):
        self.ui.theme_choice(name, authenticated)

    def take(self, state, theme, anchor, keyboard=False, fault=None, keyboard_focus=None, authoritative_progress_hidden=None):
        if not keyboard:
            self.ui.scroll_body_top()
        self.ui.seek(anchor)
        self.ui.capture()
        if not self.ui.empty_visible_inputs():
            raise SafeFailure('Non-empty visible input prevented screenshot capture')
        if keyboard and not self.ui.keyboard_visible():
            raise SafeFailure('The native keyboard disappeared before its screenshot')
        if authoritative_progress_hidden is True and (self.ui.find('detail-progress') is not None or
                not self.ui.has_text(DETAIL_FAULT_BODY['error']['message'])):
            raise SafeFailure('The fatal detail view must show its error and hide unavailable authoritative progress')
        name = state + '-' + theme
        self.ui.capture(name)
        target = self.ui.screenshot(name)
        evidence = canvas_evidence(self.ui, target, theme, anchor)
        self.records.append({'state': state, 'theme': theme, 'screenshot': target.name,
                             'uiTree': 'ui-' + name + '.json', **evidence,
                             'keyboard': keyboard, 'keyboardFocus': keyboard_focus, 'visibleInputsEmpty': True,
                             'injectedResilience': fault is not None,
                             'authoritativeProgressHidden': authoritative_progress_hidden,
                             'fault': fault})
        self.report('running')
        if not evidence['themeVerified']:
            raise SafeFailure('Actual screenshot canvas does not match the requested theme')

    def behind_bar_evidence(self):
        """Supplemental real multi-card image; never changes the 18-state count."""
        self.ui.hide_keyboard()
        self.ui.scroll_body_top()
        self.ui.capture()
        if (not self.ui.empty_visible_inputs() or self.ui.keyboard_visible() or
                self.ui.find('current-scroll') is None):
            self.observations.append({'kind': 'multi-card content behind floating bar',
                'extraEvidence': True, 'status': 'not captured',
                'reason': 'The blank-input, no-IME home precondition was not satisfied',
                'countsTowardMain18': False})
            return
        name = 'system-home-behind-bar'
        self.ui.capture(name)
        target = self.ui.screenshot(name)
        evidence = canvas_evidence(self.ui, target, 'light', 'current-tab')
        bar_path = self.ui.path_to('nav-home')
        bar = next((node['bounds'] for node in reversed(bar_path or [])
                    if node.get('type') == 'TabBar' and node.get('bounds')), None)
        self.observations.append({'kind': 'multi-card content behind floating bar',
            'extraEvidence': True, 'status': 'captured', 'countsTowardMain18': False,
            'screenshot': target.name, 'uiTree': 'ui-' + name + '.json',
            'visibleInputsEmpty': True, 'keyboard': False, 'theme': 'light',
            'scrollPosition': 'original top', 'scrollBounds': self.ui.find('current-scroll')['bounds'],
            'floatingBarBounds': bar, **evidence})
        self.report('running')

    def detail(self, kind):
        assignment_id = self.state['assignments'][kind]['assignmentId']
        path = LIST + '/' + assignment_id
        before = self.control.count(path, 'GET')
        self.ui.tap('assignment-' + assignment_id)
        self.wait_request(path, before + 1, injected=False)
        start = self.ui.seek('start-assignment')
        clickable = start.get('clickable')
        if clickable is True or (isinstance(clickable, str) and clickable.lower() == 'true'):
            raise SafeFailure('The first-slice start control must remain disabled')
        observed = 'disabled' if clickable is False or (isinstance(clickable, str) and clickable.lower() == 'false') else 'not exposed by UI dump'
        self.observations.append({'kind': kind, 'startClickable': clickable if isinstance(clickable, (bool, str)) else None,
                                  'disabledObservation': observed})

    def supplemental_snapshots(self):
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state['newPassword'])
        for kind in ('waiting', 'expired', 'locked'):
            name = 'visual-responses-' + kind + '.json'
            data = snapshot.capture(self.state['assignments'][kind]['assignmentId'])
            if data['player'].get('mustChangePassword') is not False or data['assignment'].get('status') != 'assigned':
                raise SafeFailure('Supplemental visual snapshot is outside the read-only assigned state')
            private_json(name, {**data, 'provenance': {
                'environment': 'real isolated PocketBase; strict host HTTPS with temporary CA',
                'capturedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                'scenario': kind, 'responseRewriting': False,
                'operations': 'read-only authentication then actual GET me, fixed generated assignment, assignments',
                'visualUse': 'Web response replay for this real time/rank detail; browser network remains intercepted'}})
            self.snapshots.append({'kind': kind, 'file': 'artifacts/private/https-isolation/' + name,
                                   'source': 'real successful player GETs', 'containsCredentials': False})
        data = snapshot.capture()
        fault = {'requestPath': LIST + '/' + self.state['assignmentId'], 'method': 'GET', 'status': 404,
                 'body': DETAIL_FAULT_BODY, 'pagePath': '/play/' + self.state['assignmentId']}
        private_json('visual-responses-detail404.json', {**data, 'error': fault, 'provenance': {
            'environment': 'real isolated PocketBase; actual successful player DTOs',
            'capturedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'errorOrigin': 'explicit synthetic 404 fault configuration, not an observed real backend failure',
            'injectedResilience': True, 'responseRewriting': 'only the separately labelled error response',
            'visualUse': 'Web --states error replay of exactly the configured native fault'}})
        self.snapshots.append({'kind': 'detail404-fault', 'file': 'artifacts/private/https-isolation/visual-responses-detail404.json',
                               'source': 'real success DTOs plus explicit synthetic error parameters', 'injectedResilience': True})
        self.report('running')

    def detail_fault(self, theme):
        # First establish real data, then revoke its visible cache with an
        # explicitly injected terminal response. Successful recovery is GET only.
        self.theme(theme)
        self.detail('ready')
        path = LIST + '/' + self.state['assignmentId']
        fault = {'path': path, 'method': 'GET', 'status': 404, 'body': DETAIL_FAULT_BODY}
        before = self.control.count(path, 'GET')
        self.control.call('/fault', fault)
        self.ui.foreground_cycle()
        self.wait_request(path, before + 1, status=404, injected=True)
        self.ui.wait(lambda u: u.has_text(DETAIL_FAULT_BODY['error']['message']) and
                     u.find('account-menu') is not None and u.find('detail-progress') is None,
                     'explicit detail 404 shows its error and hides unavailable progress')
        self.take('detail-404-fault', theme, 'account-menu', fault={
            'method': 'GET', 'path': path, 'status': 404,
            'kind': 'explicit resilience injection; not a real backend business failure',
            'webSnapshot': 'visual-responses-detail404.json'}, authoritative_progress_hidden=True)
        before = self.control.count(path, 'GET')
        self.ui.tap('request-retry')
        recovered = self.wait_request(path, before + 1, status=200, injected=False)
        self.ui.seek('start-assignment')
        self.ui.wait(lambda u: u.find('detail-progress') is not None,
                     'real successful detail recovery restores authoritative progress')
        self.fault_recoveries.append({'theme': theme, 'method': recovered['method'], 'path': path,
                                      'status': recovered['status'], 'injected': False,
                                      'authoritativeProgressRestored': True})
        self.back_home()

    def back_home(self):
        self.ui.back()
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'return to home')

    def logout(self):
        self.ui.tap('account-menu')
        self.ui.tap('logout')
        self.ui.wait(lambda u: u.find('account') is not None, 'explicit logout')
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('Logout did not clear the input fields')

    def keyboard(self, theme):
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('Keyboard visual requires empty logged-out input fields')
        # Keep the visual capture on the ordinary blank account field. A prior
        # password-focus screenshot blacked out both App and IME; it remains a
        # separate failed observation, never a passing theme/keyboard image.
        # Password-field reachability is checked separately through the UI tree.
        self.ui.tap('account')
        self.ui.wait(lambda u: u.keyboard_visible(), 'native ordinary-account keyboard')
        # IME resizes the App. Re-resolve the complete focused field in its new
        # viewport; pre-focus coordinates can describe only a clipped fragment.
        self.ui.seek('account')
        self.take('login-keyboard', theme, 'account', keyboard=True, keyboard_focus='account')
        self.ui.back()
        self.ui.wait(lambda u: not u.keyboard_visible(), 'keyboard dismissed')

    def run(self):
        self.environment()
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('Capture must start from the cleared logged-out App')
        core_themes = ('dark', 'light') if self.retained_count == 0 else ('light',) if self.retained_count == 5 else ()
        for theme in core_themes:
            self.login()
            self.theme(theme)
            self.take('home', theme, 'current-tab')
            self.detail('ready')
            self.theme(theme)
            self.take('detail', theme, 'account-menu')
            self.back_home()
            self.ui.tap('history-tab')
            self.ui.wait(lambda u: u.has_text('故事的第一页，还空着。'), 'history empty state')
            self.take('history', theme, 'current-tab')
            self.logout()
            self.theme(theme, authenticated=False)
            self.take('logout', theme, 'account')
            self.keyboard(theme)
        if self.retained_count in (8, 9):
            self.theme('light', authenticated=False)
            if self.retained_count == 8:
                self.take('logout', 'light', 'account')
            self.keyboard('light')
        self.control.call('/scenario', {'emptyAssignments': False})
        self.supplemental_snapshots()
        self.login()
        self.behind_bar_evidence()
        for kind in ('waiting', 'expired', 'locked'):
            self.detail(kind)
            for theme in ('dark', 'light'):
                self.theme(theme)
                self.take('detail-' + kind, theme, 'account-menu')
            if kind == 'expired':
                self.ui.tap('expired-return-home')
                self.ui.wait(lambda u: u.find('current-tab') is not None,
                             'expired detail native return-home action')
            else:
                self.back_home()
        for theme in ('dark', 'light'):
            self.detail_fault(theme)
        self.logout()
        if len(self.records) != 18:
            raise SafeFailure('The complete visual set must contain 18 new captures')

    def restore(self):
        try:
            # This non-whitelisted path cannot match any player request. The
            # current control API has no clear verb; neutralise our pending fault.
            self.control.call('/fault', {'path': '/__isolated_visual_fault_disabled__', 'method': 'GET'})
            self.cleanup['faultNeutralised'] = True
            self.control.call('/scenario', {'status': 'assigned'})
            self.control.call('/scenario', {'singleAssignment': True})
            self.cleanup['scenarioRestored'] = True
        finally:
            try:
                self.ui.hide_keyboard()
                self.ui.capture()
            except SafeFailure:
                self.ui.launch(cold=True)
                self.ui.wait(lambda u: u.find('account') is not None, 'cleanup App foreground')
            if not self.ui.find('account'):
                try:
                    self.logout()
                except SafeFailure:
                    # No credential persistence exists: a cold restart safely clears an interrupted UI session.
                    self.ui.launch(cold=True)
                    self.ui.wait(lambda u: u.find('account') is not None, 'cleanup login gate')
            if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
                self.ui.launch(cold=True)
                self.ui.wait(lambda u: u.find('account') is not None, 'cleanup cleared inputs')
            self.cleanup['loggedOut'] = self.ui.input_empty('account') and self.ui.input_empty('password')
            if not self.cleanup['loggedOut']:
                raise SafeFailure('Visual cleanup did not leave cleared logged-out inputs')

    def report(self, status, error=None):
        result = {'status': status, 'visualCriteria': CRITERIA,
                  'environment': 'real isolated PocketBase over verified HTTPS',
                  'capturedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  'window': self.ui.window, 'hap': self.ui.hap,
                  'immersionVersion': self.ui.hap['immersionVersion'],
                  'count': len(self.records), 'states': self.records, 'preservedExisting': self.preserved,
                  'cleanup': self.cleanup, 'snapshots': self.snapshots,
                  'observations': self.observations, 'faultRecoveries': self.fault_recoveries,
                  'resumedFrom': self.resumed_from,
                  'newCapturedCount': len(self.records) - self.retained_count,
                  'limitations': ['No password change, entry, answer, reward or production writes',
                                  'Supplemental states publish existing disposable test sessions only',
                                  'Two 404 screenshots use an explicit synthetic fault; recovery must be a real GET 200',
                                  'Keyboard visuals focus the blank ordinary account field; password-focus blackouts are separate failed observations',
                                  'Screenshots and sanitised UI trees; visual comparison is a separate assessment']}
        if error:
            result['error'] = error
        (OUTPUT / 'capture-summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')


def main():
    global OUTPUT, WINDOW_VERSION, RESUME_DARK_CHECKPOINT
    options = capture_options(allow_resume=True)
    OUTPUT = options.output_dir
    WINDOW_VERSION = options.window_version
    RESUME_DARK_CHECKPOINT = options.resume_dark_checkpoint
    capture, failure = None, None
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'capture-summary.json').write_text(json.dumps({'status': 'running', 'visualCriteria': CRITERIA,
                                                          'count': 0, 'states': []}) + '\n')
    try:
        capture = Capture()
        capture.report('running')
        capture.run()
    except Exception as error:
        failure = safe_error(error, capture, 'Visual helper did not complete safely')
    finally:
        if capture:
            try:
                capture.restore()
                rows = capture.control.requests()[capture.baseline:]
                if any(row.get('method') != 'GET' and not (row.get('method') == 'POST' and
                       row.get('path') in (AUTH, '/api/files/token')) for row in rows):
                    raise SafeFailure('Unexpected player write appeared during visual capture')
            except Exception as error:
                detail = safe_error(error, capture, 'Visual cleanup needs review')
                failure = (failure + '; ' if failure else '') + detail
            capture.report('incomplete' if failure else 'captured', failure)
        elif failure:
            (OUTPUT / 'capture-summary.json').write_text(json.dumps({'status': 'incomplete', 'visualCriteria': CRITERIA,
                                                                    'count': 0, 'states': [],
                                                                    'error': failure}) + '\n')
    print(json.dumps({'status': 'incomplete' if failure else 'captured',
                      'count': len(capture.records) if capture else 0,
                      'report': str((OUTPUT / 'capture-summary.json').relative_to(ROOT)), 'error': failure}, ensure_ascii=False))
    return 1 if failure else 0


if __name__ == '__main__':
    sys.exit(main())

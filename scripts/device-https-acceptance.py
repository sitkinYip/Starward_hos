#!/usr/bin/env python3
"""API26 native acceptance against this repository's disposable, real HTTPS backend.

Run only while owning the device. No credentials enter reports, command output or
UI JSON. Fault injection is deliberately labelled separately from real PB cases.
"""
import argparse
import datetime
import hashlib
import json
import sys
import time

from native_device_ui import ROOT, DeviceUI, IsolationControl, SafeFailure
from isolated_snapshot import ReadonlySnapshot, private_json

AUTH = '/api/collections/game_players/auth-with-password'
ME = '/api/questions/v1/me'
LIST = '/api/questions/v1/assignments'
CHANGE = '/api/questions/v1/me/change-password'
REPORT = ROOT / 'artifacts/validation/device-https-acceptance.json'
PRIVATE = ROOT / 'artifacts/private/https-isolation'
CORE_CHECKPOINT = ROOT / 'artifacts/validation/device-https-checkpoint-core-20.json'
RESILIENCE_CHECKPOINT = ROOT / 'artifacts/validation/device-https-checkpoint-core-28.json'


class Acceptance:
    def __init__(self, phase):
        self.control = IsolationControl()
        self.state = self.control.state
        self.phase = phase
        self.started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        self.current_phase = 'setup'
        self.checks = []
        self.phases = []
        self.observations = []
        self.resumed_from = None
        self.ui = DeviceUI(ROOT / 'artifacts/validation/https-device', ROOT / 'artifacts/screenshots/https')
        self.detail = LIST + '/' + self.state['assignmentId']
        self.card = 'assignment-' + self.state['assignmentId']
        self.progress('running')

    def progress(self, status, error=None):
        report = {'status': status, 'requestedPhase': self.phase, 'currentPhase': self.current_phase,
                  'startedAt': self.started_at, 'updatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  'environment': 'real isolated PocketBase 0.40.1 over verified HTTPS and official USB forwarding',
                  'deviceApi': 26, 'count': len(self.checks), 'checks': self.checks, 'phases': self.phases,
                  'requestLedger': self.control.ledger, 'observations': self.observations,
                  'resumedFrom': self.resumed_from,
                  'limitations': ['CLI/UiTest device evidence; not a Hypium instrument report',
                                  'Injected failures test resilience; they are not observed production failures',
                                  'No production environment, start, answer or reward writes were performed']}
        if error:
            report['error'] = error
        REPORT.parent.mkdir(parents=True, exist_ok=True)
        REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')

    def check(self, condition, label, cases, injected=False):
        if not condition:
            raise SafeFailure('Acceptance expectation did not hold: ' + label)
        self.checks.append({'label': label, 'cases': cases, 'phase': self.current_phase,
                            'injectedResilience': injected})
        self.progress('running')
        print(json.dumps({'passed': label, 'count': len(self.checks)}, ensure_ascii=False), flush=True)

    def phase_start(self, name):
        self.current_phase = name
        self.progress('running')
        print(json.dumps({'phase': name, 'status': 'running'}), flush=True)

    def phase_end(self):
        self.control.checkpoint(self.current_phase)
        self.phases.append({'phase': self.current_phase, 'status': 'passed'})
        self.progress('running')

    def login(self, password, normalise=False, double_tap=False):
        self.ui.fill('account', ('  ' + self.state['account'].upper() + '  ') if normalise else self.state['account'])
        self.ui.fill('password', password)
        if double_tap:
            self.ui.seek('primary-action')
            self.ui.run('devecocli', 'ui', 'doubleclick', '--id', 'primary-action')
        else:
            self.ui.tap('primary-action')

    def passwords(self, old=None, new=None, confirmation=None):
        self.ui.fill('old-password', self.state['initialPassword'] if old is None else old)
        self.ui.fill('new-password', self.state['newPassword'] if new is None else new)
        self.ui.fill('confirm-password', self.state['newPassword'] if confirmation is None else confirmation)

    def forced(self):
        self.ui.wait(lambda u: u.has_text('首次登录，请先修改密码'), 'mandatory password gate')

    def home(self):
        self.ui.wait(lambda u: u.find('refresh-assignments') is not None, 'authenticated home')

    def loaded_detail(self, minimum_count):
        # The caller takes this sequence number before its click. A retained
        # card or an earlier successful request cannot satisfy the assertion.
        self.wait_requests(self.detail, minimum_count, expected_status=200)
        self.ui.wait(lambda u: u.has_text('星辰探险') or u.find('start-assignment') is not None,
                     'read-only detail', save='detail-ready')
        self.ui.seek('start-assignment')

    def refresh(self):
        before = self.control.count(LIST, 'GET')
        self.ui.tap('refresh-assignments')
        self.wait_requests(LIST, before + 1)

    def wait_requests(self, path, count, timeout=25, expected_status=None, expected_fault=None):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            rows = self.control.requests()
            matching = [row for row in rows if row.get('path') == path]
            if len(matching) >= count and matching[count - 1].get('status'):
                observed = matching[count - 1]
                if expected_status is not None and observed['status'] != expected_status:
                    raise SafeFailure('This isolated request returned unexpected HTTP status: ' + path + ' ' + str(observed['status']))
                if expected_fault is not None and observed.get('fault') is not expected_fault:
                    raise SafeFailure('This isolated request did not have the expected fault origin: ' + path)
                return observed
            time.sleep(.15)
        raise SafeFailure('Expected isolated request did not finish: ' + path)

    def fault(self, path, status=503, code='TEST_FAULT', message='隔离网络故障注入', **options):
        self.control.call('/fault', {'path': path, 'method': 'POST' if path == AUTH else 'GET', 'status': status,
                                    'body': {'error': {'code': code, 'message': message}}, **options})

    def bootstrap(self):
        self.control.reset()
        self.ui.launch(cold=True)
        self.ui.wait(lambda u: u.find('account') is not None, 'fresh login')
        self.login(self.state['initialPassword'])
        self.forced()
        self.passwords()
        self.ui.tap('primary-action')
        self.home()
        self.ui.seek(self.card)

    def core(self):
        self.phase_start('core')
        self.control.reset()
        # Capture actual forced /me before any native mutation. Its detail/list
        # are intentionally fetched later, once the real password gate permits.
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state['initialPassword'])
        forced_player = snapshot.request(ME)
        if forced_player.get('mustChangePassword') is not True:
            raise SafeFailure('The disposable player did not require password change')
        private_json('visual-forced-player.json', {'player': forced_player, 'capturedAt': datetime.datetime.now(datetime.timezone.utc).isoformat()})
        self.control.checkpoint('host-readonly-forced-snapshot')
        self.ui.launch('starward://assignment/' + self.state['assignmentId'], cold=True)
        self.ui.wait(lambda u: u.find('account') is not None, 'cold deep-link login', save='login-deep-link')
        self.check(self.ui.find('environment-badge') is not None and self.ui.has_text('隔离测试环境'),
                   'Native App visibly identifies the isolated HTTPS environment', ['A01'])
        before = self.control.count(AUTH, 'POST')
        self.ui.tap('primary-action')
        self.ui.wait(lambda u: u.has_text('请输入账号和密码。'), 'empty input validation')
        self.check(self.control.count(AUTH, 'POST') == before, 'Empty login sends no authentication POST', ['A02'])
        wrong_auth = self.control.count(AUTH, 'POST')
        self.login('Deliberately-Wrong-Test-Password')
        rejected = self.wait_requests(AUTH, wrong_auth + 1, expected_status=400, expected_fault=False)
        self.ui.wait(lambda u: u.find('error-message') is not None, 'wrong password error', save='login-wrong-password')
        self.check(rejected.get('method') == 'POST' and self.control.count(AUTH, 'POST') == wrong_auth + 1 and
                   self.ui.find('account') is not None and not self.ui.has_text('远航者'),
                   'Real wrong-password response stays on login without private content', ['A04'])
        # Explicit malformed server and service failure injections, never called real DTOs.
        failed_auth = self.control.count(AUTH, 'POST')
        before_service_me = self.control.count(ME, 'GET')
        self.fault(AUTH, 503)
        self.ui.fill('password', self.state['initialPassword'])
        self.ui.tap('primary-action')
        self.wait_requests(AUTH, failed_auth + 1, expected_status=503, expected_fault=True)
        self.ui.wait(lambda u: u.has_text('隔离网络故障注入', contains=True), 'login service fault')
        self.check(self.control.count(AUTH, 'POST') == failed_auth + 1 and self.control.count(ME, 'GET') == before_service_me and
                   self.ui.find('account') is not None, 'Injected login 503 remains recoverable in place', ['A04'], True)
        before_contract_auth = self.control.count(AUTH, 'POST')
        before_contract_me = self.control.count(ME, 'GET')
        self.fault(ME, 200, rawBody='{"id": 7}')
        self.ui.tap('primary-action')
        contract_auth = self.wait_requests(AUTH, before_contract_auth + 1, expected_status=200, expected_fault=False)
        contract_me = self.wait_requests(ME, before_contract_me + 1, expected_status=200, expected_fault=True)
        contract_message = '服务返回了不兼容的数据，请更新应用或联系管理员。'
        self.ui.wait(lambda u: u.find('error-message') is not None and
                     u.find('error-message').get('text') == contract_message,
                     'exact invalid /me contract error', save='login-me-contract-error')
        self.check(contract_auth.get('method') == 'POST' and contract_me.get('method') == 'GET' and
                   contract_me.get('authenticated') is True and
                   self.control.count(AUTH, 'POST') == before_contract_auth + 1 and
                   self.control.count(ME, 'GET') == before_contract_me + 1 and
                   self.control.count(self.detail) == 0 and self.control.count(LIST) == 0 and
                   self.ui.find('account') is not None and self.ui.find('old-password') is None and
                   not self.ui.has_text('远航者'),
                   'A new authenticated /me GET consumes the injected 200 invalid DTO and shows the exact contract error without entering protected UI', ['A05'], True)
        self.observations.append({'case': 'A05', 'auth': {'method': 'POST', 'status': contract_auth['status'], 'fault': contract_auth['fault']},
                                  'me': {'method': 'GET', 'status': contract_me['status'], 'fault': contract_me['fault']},
                                  'uiError': contract_message})
        before_double = self.control.count(AUTH, 'POST')
        self.control.call('/fault', {'path': AUTH, 'method': 'POST', 'delayMs': 1000})
        self.login(self.state['initialPassword'], normalise=True, double_tap=True)
        self.forced()
        self.check(self.control.count(AUTH, 'POST') == before_double + 1,
                   'A native double tap during delayed authentication sends exactly one normalized login POST', ['A03'], True)
        self.ui.capture('forced-password')
        self.ui.screenshot('forced-password')
        self.check(self.control.count(self.detail) == 0 and self.control.count(LIST) == 0,
                   'Cold protected deep link stops at mandatory password gate without list or detail requests', ['A01', 'A03', 'A06'])
        self.ui.back()
        self.ui.launch()
        self.ui.wait(lambda u: u.find('old-password') is not None or u.find('account') is not None, 'forced gate after Back')
        if self.ui.find('account') is not None:
            # The Ability may close on system Back; replay the explicit test URI.
            self.ui.launch('starward://assignment/' + self.state['assignmentId'])
            self.login(self.state['initialPassword'])
            self.forced()
        self.check(self.ui.has_text('首次登录，请先修改密码') and self.control.count(self.detail) == 0,
                   'System Back cannot bypass mandatory password change', ['A06'])
        self.ui.edge_back()
        try:
            self.ui.capture()
            gesture_result = 'App retained mandatory gate'
        except SafeFailure:
            gesture_result = 'Ability closed; relaunch remained gated'
            self.ui.launch('starward://assignment/' + self.state['assignmentId'])
            self.ui.wait(lambda u: u.find('old-password') is not None or u.find('account') is not None, 'edge gesture relaunch')
        if self.ui.find('account') is not None:
            self.login(self.state['initialPassword'])
            self.forced()
        self.check(self.ui.find('old-password') is not None and self.control.count(self.detail) == 0,
                   'Actual OS edge swipe cannot reveal a protected page before password change', ['A06', 'V03'])
        self.observations.append({'case': 'V03', 'action': 'actual left-edge horizontal swipe', 'gateOutcome': gesture_result,
                                  'recognition': 'not inferred from keyEvent Back'})
        invalid = [('short', 'short', 'short', '10—71'),
                   ('same-as-old', self.state['initialPassword'], self.state['initialPassword'], '不能与当前密码相同'),
                   ('confirmation', self.state['newPassword'], self.state['newPassword'] + 'x', '两次新密码不一致'),
                   ('utf8-limit', '星' * 25, '星' * 25, '72 字节')]
        for label, password, confirmation, expected in invalid:
            before = self.control.count(CHANGE, 'POST')
            self.passwords(new=password, confirmation=confirmation)
            self.ui.tap('primary-action')
            self.ui.wait(lambda u: u.has_text(expected, contains=True), 'password validation ' + label)
            self.check(self.control.count(CHANGE, 'POST') == before,
                       'Invalid password input ' + label + ' sends no password POST', ['A07'])
        before = self.control.count(CHANGE, 'POST')
        self.passwords(old='Deliberately-Wrong-Old-Password')
        self.ui.tap('primary-action')
        self.ui.wait(lambda u: u.has_text('旧密码不正确', contains=True), 'real old-password rejection')
        self.check(self.control.count(CHANGE, 'POST') == before + 1 and self.ui.find('old-password') is not None,
                   'Wrong old password performs one real POST and retains the mandatory gate', ['A08'])
        self.passwords()
        expected_detail = self.control.count(self.detail, 'GET') + 1
        self.ui.tap('primary-action')
        self.loaded_detail(expected_detail)
        self.check(self.control.count(CHANGE, 'POST') == before + 2 and self.control.count(self.detail) >= 1,
                   'One successful real password change automatically resumes the pending native detail route', ['A01', 'A08', 'B01'])
        self.check(self.ui.has_text('此切片仅查看场次，暂不支持开始冒险。') and self.ui.find('start-assignment') is not None,
                   'Detail presents the explicit read-only scope beside the start control', ['B01', 'B02'])
        self.ui.capture('detail-readonly')
        self.ui.screenshot('detail-readonly')
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state['newPassword'])
        after = snapshot.capture()
        private_json('visual-responses-forced.json', {**after, 'player': forced_player,
            'provenance': {'environment': 'real isolated PocketBase; strict HTTPS',
                           'player': 'actual GET /me before native password change; mustChangePassword remains true',
                           'assignmentAndList': 'actual GET after successful native password change; unavailable (403) before gate clears',
                           'visualUse': 'forced page consumes only player; other DTOs are later supporting data, not a claim of gate bypass'}})
        self.ui.edge_back()
        try:
            self.ui.capture()
            gesture_home = self.ui.find('refresh-assignments') is not None
        except SafeFailure:
            gesture_home = False
        if gesture_home:
            self.check(True, 'Actual OS edge swipe from detail returns to native home', ['V03', 'B01'])
        else:
            self.observations.append({'case': 'V03', 'action': 'actual left-edge horizontal swipe from detail',
                                      'result': 'system gesture not confirmed; no pass claimed'})
            self.ui.tap('return-home')
        self.home()
        self.check(not self.ui.has_text('2 道等待解开'), 'Detail return restores the native home', ['B01'])
        self.ui.screenshot('home-ready')
        self.core_tail()

    def assignment_state(self, kind_or_id, expected):
        assignment_id = self.state['assignments'][kind_or_id]['assignmentId'] if kind_or_id in self.state['assignments'] else kind_or_id
        node = self.ui.seek('assignment-state-' + assignment_id)
        if node.get('type') != 'Text' or node.get('text') != expected:
            raise SafeFailure('The identified assignment status text did not match its expected state')
        return node

    def core_tail(self):
        for kind, label in [('ready', '可以出发'), ('waiting', '静候启程'), ('expired', '已过开放时间'), ('locked', '等级暂不符合')]:
            self.assignment_state(kind, label)
            self.check(True, 'Real assigned card presents state ' + kind, ['H01', 'H03'])
            self.ui.capture('home-' + kind)
        self.ui.tap('history-tab')
        self.ui.wait(lambda u: u.has_text('故事的第一页，还空着。'), 'history empty state', save='history-empty')
        self.check(True, 'History has its own empty-state wording', ['H02'])
        self.ui.tap('current-tab')
        self.control.call('/scenario', {'emptyAssignments': True})
        self.refresh()
        self.ui.wait(lambda u: u.has_text('下一场奇遇，正在酝酿。'), 'real empty assignments', save='current-empty')
        self.check(not any((n.get('id') or '').startswith('assignment-') for n in self.ui.flat),
                   'Archiving real test sessions produces the distinct current-list empty state', ['H02'])
        self.control.call('/scenario', {'emptyAssignments': False})
        self.refresh()
        self.ui.seek(self.card)
        for status, label, history in [('active', '探索进行中', False), ('completed', '故事已解开', True), ('cancelled', '旅程已撤回', True)]:
            self.control.call('/scenario', {'status': status})
            self.refresh()
            self.ui.tap('history-tab' if history else 'current-tab')
            self.assignment_state(self.state['assignmentId'], label)
            self.check(True, 'Real test assignment status ' + status + ' has correct category and label', ['H01', 'H03'])
            self.ui.capture('home-' + status)
        self.control.call('/scenario', {'status': 'assigned'})
        self.refresh()
        self.ui.tap('current-tab')
        self.ui.seek(self.card)
        self.check(not any(row.get('bearer') for row in self.control.requests()),
                   'All observed authenticated native requests preserve Authorization token without Bearer', ['A03'])
        self.phase_end()

    def resume_core(self):
        raw = CORE_CHECKPOINT.read_bytes()
        checkpoint = json.loads(raw)
        prior = checkpoint.get('checks', [])
        if (checkpoint.get('status') != 'incomplete' or checkpoint.get('requestedPhase') != 'all' or
                checkpoint.get('currentPhase') != 'core' or checkpoint.get('count') != 20 or len(prior) != 20 or
                checkpoint.get('deviceApi') != 26 or checkpoint.get('environment') != 'real isolated PocketBase 0.40.1 over verified HTTPS and official USB forwarding' or
                any(item.get('phase') != 'core' for item in prior) or
                prior[0].get('label') != 'Native App visibly identifies the isolated HTTPS environment' or
                prior[17].get('label') != 'Detail return restores the native home' or
                [item.get('label') for item in prior[18:]] != ['Real assigned card presents state ready', 'Real assigned card presents state waiting']):
            raise SafeFailure('Resume checkpoint does not match the expected interrupted core-20 run')
        self.accept_resume_checkpoint(CORE_CHECKPOINT, raw, checkpoint, 18)
        self.resume_reattach()
        self.phase_start('core')
        self.core_tail()

    def accept_resume_checkpoint(self, path, raw, checkpoint, preserved, previous=None):
        prior = checkpoint['checks']
        detail_rows = [row for group in checkpoint.get('requestLedger', []) for row in group.get('requests', [])
                       if isinstance(row.get('path'), str) and row['path'].startswith(LIST + '/')]
        if (not detail_rows or any(row['path'] != self.detail for row in detail_rows) or
                not any(row.get('method') == 'GET' and row.get('status') == 200 and row.get('authenticated') is True for row in detail_rows)):
            raise SafeFailure('Resume checkpoint belongs to a different generated assignment or lacks its successful GET evidence')
        digest = hashlib.sha256(raw).hexdigest()
        chain = [{'file': str(path.relative_to(ROOT)), 'sha256': digest,
                  'sourceStatus': checkpoint['status'], 'preservedCheckCount': preserved}]
        if previous:
            chain.insert(0, {'file': previous['file'], 'sha256': previous['sha256'],
                             'sourceStatus': previous['sourceStatus'], 'preservedCheckCount': previous['preservedCheckCount']})
        self.checks = [{**item, 'preservedEvidence': {'checkpointSha256': digest,
                        'checkpointShaChain': [entry['sha256'] for entry in chain]}} for item in prior[:preserved]]
        self.observations = checkpoint.get('observations', [])
        self.resumed_from = {'file': str(path.relative_to(ROOT)), 'sha256': digest,
                             'sourceStatus': checkpoint['status'], 'sourceCount': checkpoint['count'], 'preservedCheckCount': preserved,
                             'preservedChecksNotReexecuted': [item['label'] for item in prior[:preserved]],
                             'discardedChecksToRetest': [item['label'] for item in prior[preserved:]],
                             'interruptedAttemptCountedAsPassedPhase': False,
                             'matchingDetailPath': self.detail, 'backendResetForReattachment': False,
                             'checkpointChain': chain}
        safe_keys = ('method', 'path', 'status', 'fault', 'responseDropped', 'bearer', 'authenticated')
        self.control.ledger = [{'phase': 'checkpoint.' + group.get('phase', 'unknown'),
                                'sourceAttemptStatus': 'incomplete',
                                'requests': [{key: row[key] for key in safe_keys if key in row} for row in group.get('requests', [])]}
                               for group in checkpoint.get('requestLedger', [])]

    def resume_resilience(self):
        raw = RESILIENCE_CHECKPOINT.read_bytes()
        checkpoint = json.loads(raw)
        prior = checkpoint.get('checks', [])
        previous = checkpoint.get('resumedFrom', {})
        previous_digest = hashlib.sha256(CORE_CHECKPOINT.read_bytes()).hexdigest()
        if (checkpoint.get('status') != 'incomplete' or checkpoint.get('requestedPhase') != 'resume' or
                checkpoint.get('currentPhase') != 'resilience' or checkpoint.get('count') != 29 or len(prior) != 29 or
                checkpoint.get('deviceApi') != 26 or checkpoint.get('environment') != 'real isolated PocketBase 0.40.1 over verified HTTPS and official USB forwarding' or
                any(item.get('phase') != 'core' for item in prior[:28]) or
                prior[27].get('label') != 'All observed authenticated native requests preserve Authorization token without Bearer' or
                prior[28].get('phase') != 'resilience' or prior[28].get('label') != 'Injected list 503 preserves the previous valid list' or
                checkpoint.get('phases') != [{'phase': 'core', 'status': 'passed'}] or
                previous.get('file') != str(CORE_CHECKPOINT.relative_to(ROOT)) or previous.get('sha256') != previous_digest or
                previous.get('matchingDetailPath') != self.detail or previous.get('sourceStatus') != 'incomplete' or
                previous.get('sourceCount') != 20 or previous.get('preservedCheckCount') != 18):
            raise SafeFailure('Resilience checkpoint or its core-20 SHA chain does not match this interrupted run')
        self.accept_resume_checkpoint(RESILIENCE_CHECKPOINT, raw, checkpoint, 28, previous)
        self.phases = [{'phase': 'core', 'status': 'passed', 'preservedEvidence': {
            'checkpointSha256': self.resumed_from['sha256']}}]
        self.resume_reattach()

    def resume_reattach(self):
        self.phase_start('resume-reattach')
        # Reinstallation clears in-memory credentials. Reauthenticate using the
        # already changed password; never reset or change this backend here.
        auth = self.control.count(AUTH, 'POST')
        me = self.control.count(ME, 'GET')
        listing = self.control.count(LIST, 'GET')
        self.ui.launch(cold=True)
        self.ui.wait(lambda u: u.find('account') is not None, 'resume fresh App login')
        self.login(self.state['newPassword'])
        self.wait_requests(AUTH, auth + 1, expected_status=200, expected_fault=False)
        self.wait_requests(ME, me + 1, expected_status=200, expected_fault=False)
        self.wait_requests(LIST, listing + 1, expected_status=200, expected_fault=False)
        self.home()
        self.ui.tap('current-tab')
        self.ui.capture('resume-home')
        self.resumed_from['newPasswordReattachmentConfirmed'] = True
        self.control.checkpoint('resume-reattach-readonly-authentication')

    def resilience(self, prepared=False):
        self.phase_start('resilience')
        if not prepared:
            self.bootstrap()
        self.fault(LIST)
        self.refresh()
        self.ui.wait(lambda u: u.find('error-message') is not None, 'list 503 error')
        self.ui.seek(self.card)
        self.check(self.ui.find(self.card) is not None, 'Injected list 503 preserves the previous valid list', ['H02', 'B04'], True)
        self.ui.capture('list-503-preserved')
        expected_list = self.control.count(LIST, 'GET') + 1
        self.ui.tap('request-retry')
        self.wait_requests(LIST, expected_list, expected_status=200)
        self.ui.wait(lambda u: u.find('error-message') is None, 'list retry recovery')
        self.ui.seek(self.card)
        self.check(True, 'List retry recovers from the explicitly injected service failure', ['H02'], True)
        expected_detail = self.control.count(self.detail, 'GET') + 1
        self.ui.tap(self.card)
        self.loaded_detail(expected_detail)
        self.fault(self.detail)
        self.ui.foreground_cycle()
        self.ui.wait(lambda u: u.find('error-message') is not None, 'detail 503 error')
        self.ui.seek('start-assignment')
        self.check(self.ui.find('start-assignment') is not None, 'Injected detail 503 retains the previous valid detail', ['B04'], True)
        self.ui.capture('detail-503-preserved')
        expected_detail = self.control.count(self.detail, 'GET') + 1
        self.ui.tap('request-retry')
        self.ui.wait(lambda u: u.find('error-message') is None, 'detail retry recovery')
        self.loaded_detail(expected_detail)
        self.check(True, 'Detail retry replaces the temporary error with a real successful GET', ['B04'], True)
        for status, code in [(404, 'NOT_FOUND'), (403, 'FORBIDDEN'), (410, 'GONE'), (409, 'SESSION_OFFLINE')]:
            message = '隔离详情终态 ' + str(status)
            self.fault(self.detail, status, code, message)
            self.ui.foreground_cycle()
            self.ui.wait(lambda u: u.has_text(message), 'terminal detail ' + str(status))
            self.check(self.ui.find('start-assignment') is None and not self.ui.has_text('星辰探险'),
                       'Injected terminal detail ' + str(status) + ' clears the old private detail', ['B03'], True)
            self.ui.capture('detail-terminal-' + str(status))
            expected_detail = self.control.count(self.detail, 'GET') + 1
            self.ui.tap('request-retry')
            self.loaded_detail(expected_detail)
        self.control.call('/fault', {'path': self.detail, 'method': 'GET', 'delayMs': 18000})
        self.ui.foreground_cycle()
        self.ui.wait(lambda u: u.has_text('超时', contains=True), 'native request timeout', timeout=35, save='detail-timeout')
        self.check(True, 'Injected 18-second delay reaches the native timeout and exposes retry', ['A04', 'B04'], True)
        expected_detail = self.control.count(self.detail, 'GET') + 1
        self.ui.tap('request-retry')
        self.loaded_detail(expected_detail)
        self.check(True, 'Explicit retry succeeds after a timed-out detail read', ['B04'], True)
        before = self.control.count(ME, 'GET')
        self.ui.foreground_cycle()
        self.wait_requests(ME, before + 1)
        self.check(self.control.count(ME, 'GET') > before, 'Foreground restoration makes a real /me round trip', ['H04'])
        self.control.call('/player', {'disabled': True})
        self.ui.foreground_cycle()
        self.ui.wait(lambda u: u.find('account') is not None, 'disabled player session expires', save='disabled-player-login')
        self.check(not self.ui.has_text('远航者') and self.ui.find('start-assignment') is None and self.ui.find(self.card) is None,
                   'Real server-disabled player returns to login and clears protected content', ['A09', 'B03'])
        self.check(any(r.get('path') == ME and r.get('status') == 401 for r in self.control.requests()),
                   'Server disable was observed as an actual player /me 401', ['A09'])
        self.control.call('/player', {'disabled': False})
        self.phase_end()

    def rotation(self):
        self.phase_start('password-response-loss')
        self.control.checkpoint('before-reset-for-response-loss')
        self.control.reset()
        self.ui.launch(cold=True)
        self.ui.wait(lambda u: u.find('account') is not None, 'response-loss fresh login')
        self.login(self.state['initialPassword'])
        self.forced()
        self.passwords()
        before = self.control.count(CHANGE, 'POST')
        self.control.call('/fault', {'path': CHANGE, 'method': 'POST', 'dropResponse': True})
        self.ui.tap('primary-action')
        self.ui.wait(lambda u: u.has_text('密码修改结果尚未确认', contains=True), 'unconfirmed real password write', timeout=35, save='password-result-unconfirmed')
        rows = [r for r in self.control.requests() if r.get('path') == CHANGE and r.get('method') == 'POST']
        self.check(len(rows) == before + 1 and rows[-1].get('status') == 200 and rows[-1].get('responseDropped') is True,
                   'Injected lost response happens after exactly one completed real password write', ['A08'], True)
        time.sleep(1)
        self.check(self.control.count(CHANGE, 'POST') == before + 1,
                   'Unconfirmed password change is never replayed automatically', ['A08'], True)
        self.ui.tap('forced-logout')
        self.ui.wait(lambda u: u.find('account') is not None, 'forced logout')
        self.check(self.ui.input_empty('account') and self.ui.input_empty('password'),
                   'Explicit forced-page logout clears account and password inputs', ['A09'])
        self.login(self.state['newPassword'])
        self.home()
        self.ui.seek(self.card)
        self.check(True, 'New-password login confirms the real write whose response was lost', ['A08'], True)
        self.phase_end()

    def visual(self):
        self.phase_start('visual-data-snapshot')
        self.control.call('/scenario', {'status': 'assigned'})
        self.control.call('/scenario', {'singleAssignment': True})
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state['newPassword'])
        data = snapshot.capture()
        self.check(data['player'].get('mustChangePassword') is False and len(data['assignments'].get('items', [])) == 1,
                   'Final paired-visual data is one real ready assignment after mandatory password change', ['V01'])
        private_json('visual-responses.json', {**data, 'provenance': {
            'environment': 'real isolated PocketBase; strict host HTTPS with app test CA',
            'capturedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'operations': 'real auth then GET me, assignment and assignments; other three real test sessions archived',
            'responseRewriting': False, 'visualComparison': 'snapshot preparation only; paired screenshot assessment is separate'}})
        forced_file = PRIVATE / 'visual-forced-player.json'
        if forced_file.exists():
            before = json.loads(forced_file.read_text())
            private_json('visual-responses-forced.json', {**data, 'player': before['player'], 'provenance': {
                'player': 'actual GET /me before native password change, captured ' + before['capturedAt'],
                'assignmentAndList': 'actual later GET after gate cleared and singleAssignment was enabled',
                'visualUse': 'forced page only consumes the original player; no claim of protected GET access before password change',
                'responseRewriting': False, 'mixedCaptureTimes': True}})
        self.phase_end()

    def logout(self):
        self.phase_start('explicit-logout')
        self.home()
        self.ui.tap('refresh-assignments')
        self.ui.tap('account-menu')
        self.ui.tap('logout')
        self.ui.wait(lambda u: u.find('account') is not None, 'explicit logout', save='explicit-logout')
        self.check(self.ui.input_empty('account') and self.ui.input_empty('password') and not self.ui.has_text('远航者'),
                   'Explicit account-menu logout clears credentials and protected content', ['A09'])
        self.ui.back()
        self.ui.launch()
        self.ui.wait(lambda u: u.find('account') is not None, 'logout Back remains gated')
        self.check(not self.ui.has_text('远航者') and self.ui.find(self.card) is None,
                   'Back and Ability restoration cannot recover private pages after logout', ['A09'])
        for theme in ('dark', 'light', 'system'):
            self.ui.tap('theme-' + theme)
            self.ui.capture('login-theme-' + theme)
            self.ui.screenshot('login-theme-' + theme)
        self.check(True, 'All three native theme controls remain reachable after logout', ['V02'])
        self.phase_end()

    def run(self):
        if self.phase == 'resume':
            self.resume_core()
        if self.phase == 'resume-resilience':
            self.resume_resilience()
        if self.phase in ('all', 'core'):
            self.core()
        if self.phase in ('all', 'resume', 'resume-resilience', 'resilience'):
            self.resilience(prepared=self.phase in ('all', 'resume', 'resume-resilience'))
        if self.phase in ('all', 'resume', 'resume-resilience', 'rotation'):
            self.rotation()
        if self.phase in ('all', 'resume', 'resume-resilience', 'visual'):
            self.visual()
        if self.phase in ('all', 'resume', 'resume-resilience'):
            self.logout()
        self.progress('passed')
        print(json.dumps({'status': 'passed', 'phase': self.phase, 'count': len(self.checks),
                          'report': str(REPORT)}, ensure_ascii=False), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', choices=('all', 'resume', 'resume-resilience', 'core', 'resilience', 'rotation', 'visual'), default='all',
                        help='resume preserves 18 core checks; resume-resilience preserves 28 core checks and validates both checkpoint SHAs; reattachment never resets the backend')
    args = parser.parse_args()
    # Replace a prior pass before loading private state or using the device.
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps({'status': 'running', 'requestedPhase': args.phase, 'count': 0, 'checks': []}) + '\n')
    run = None
    try:
        run = Acceptance(args.phase)
        run.run()
    except Exception as error:
        safe = str(error) if isinstance(error, SafeFailure) else 'Harness failed safely: ' + type(error).__name__
        if run:
            try:
                run.control.checkpoint('failure')
            except Exception:
                pass
            run.progress('incomplete', {'classification': 'tool-or-expectation-needs-review', 'message': safe,
                                        'businessFailureClaimed': False})
        else:
            REPORT.write_text(json.dumps({'status': 'incomplete', 'count': 0, 'checks': [], 'error': safe}) + '\n')
        print(json.dumps({'status': 'incomplete', 'passedCount': len(run.checks) if run else 0,
                          'error': safe, 'report': str(REPORT)}, ensure_ascii=False), flush=True)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())

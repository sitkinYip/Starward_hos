#!/usr/bin/env python3
"""Narrow real-device text field acceptance on one reviewed isolated actor.

Default/help is inert. Run permits Host authentication and exact own reads,
an explicitly requested single native start, and one native answer submission.
Original trees, images, fixture DTOs and receipt details are private.
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

from native_device_ui import ROOT

OUT = ROOT / 'artifacts/validation/ui-gameplay-text-20261106'
PRIVATE_REFERENCE = ROOT / 'artifacts/private/ui-reference'
FIXTURE = PRIVATE_REFERENCE / 'native-content-fixture-20261104-01/fixture.json'
FIXTURE_SHA = '1ad7a59cc1f13e6dd7ec5550c8f5ab4a5906b90f9a9b56ac948143a4995e8745'
FIELD, SUBMIT = 'gameplay-answer-input', 'gameplay-submit'
DRAFT = '填空草稿验收 123'
ME = '/api/questions/v1/me'

SPEC = importlib.util.spec_from_file_location('text_field_frame', ROOT / 'scripts/device-question-frame.py')
FRAME = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FRAME)
require, sha, UI = FRAME.require, FRAME.sha, FRAME.UI


def raw_boolean(node, name):
    value = node.get(name)
    require(value in ('true', 'false') or type(value) is bool, 'An actual raw boolean is absent')
    return value is True or value == 'true'


class TextFieldSample(FRAME.FrameSample):
    def __init__(self, args):
        FRAME.fresh(args.output, OUT)
        FRAME.fresh(args.private_dir, PRIVATE_REFERENCE, directory=True)
        args.expected_fixture_sha = FIXTURE_SHA
        super().__init__(args)
        require(self.case['sourceContent']['sourceCaseIndex'] == 0 and self.case['fixtureLevelKinds'] == ['text'],
                'Only the explicit original text case0 is allowed')
        self.answer_path = self.detail + '/answers'
        self.start_invoked = self.submit_invoked = False
        self.baseline = None
        self.original_start_receipts = None
        self.pending_observed = self.answer_matches_server = False
        self.readonly_touch_observed = False
        self.web_fixtures, self.final_facts, self.final_ledger = {}, None, None
        self.draft_probe = None

        fixture = FRAME.ENTRY.guarded(args.fixture_file, FRAME.PRIVATE, True)
        require(sha(fixture) == FIXTURE_SHA, 'The exact reviewed content fixture is required')
        data = json.loads(fixture.read_text())
        packet = data['cases'][0]
        source = packet['sourceRefs']
        registry = self.state['uiContent']['imports'][self.import_id]
        mapping = registry['sourceTargetMap']
        self.source_ids = tuple(source.values())
        self.question_id = mapping['game_questions'][source['questionId']]
        self.level_id = mapping['game_session_levels'][source['sessionLevelId']]
        require(mapping['game_sessions'][source['sessionId']] == self.case['assignments']['ready']['sessionId'],
                'The case session must map to the original text source')
        self.expected_question = packet['expectedQuestion']
        keys = data['sourceRecords']['game_answer_keys']
        matches = [(row, parsed) for row, parsed in zip(keys['rawRows'], keys['decodedJsonByRow'])
                   if row['question'] == source['questionId']]
        settings = [row for row in data['sourceRecords']['game_question_settings']['rawRows']
                    if row['question'] == source['questionId']]
        require(len(matches) == len(settings) == 1 and settings[0]['answerMatchMode'] == 'exact' and
                matches[0][0]['normalizationVersion'] == 'nfkc-v1', 'The source must have one exact text answer key')
        row, parsed = matches[0]
        answers = parsed['acceptedAnswers']['value']
        require(isinstance(answers, list) and len(answers) == 1 and isinstance(answers[0], str) and
                0 < len(answers[0]) <= 4000 and answers[0] == answers[0].strip() and
                all(char.isprintable() for char in answers[0]) and json.loads(row['acceptedAnswers']) == answers and
                answers[0] != DRAFT, 'The source text answer is not one usable exact input')
        self.correct_answer = answers[0]
        self.device_ref = FRAME.ENTRY.guarded(args.device_ref, FRAME.PRIVATE, True)
        device = json.loads(self.device_ref.read_text())
        self.serial = device.get('deviceSerial', '')
        require(set(device) == {'deviceSerial'} and re.fullmatch(r'[A-Za-z0-9]{8,80}', self.serial),
                'An explicit reviewed private device reference is required')
        paths = {'textFieldDriver': Path(__file__), 'sourceFixture': fixture, 'deviceReference': self.device_ref,
                 'gameplayViewModel': ROOT / 'entry/src/main/ets/features/GameplayViewModel.ets',
                 'textFieldUI': ROOT / 'entry/src/main/ets/ui/StarwardAnswerInput.ets'}
        for key, path in paths.items():
            self.bound[key], self.binding[key] = path, sha(path)

    def credentials(self):
        return self.case['newPassword'], self.state['controlToken'], self.token

    def device_binding(self):
        require(self.ui.run('hdc', 'list', 'targets').split() == [self.serial], 'The exact sole reviewed phone is required')
        forwards = [line.split() for line in self.ui.run('hdc', '-t', self.serial, 'fport', 'ls').splitlines()]
        require([row for row in forwards if len(row) > 1 and row[1] == 'tcp:18443'] ==
                [[self.serial, 'tcp:18443', 'tcp:' + str(self.state['tls']['hostPort']), '[Reverse]']],
                'The phone lacks the exact own disposable USB TLS mapping')

    def facts(self, status, starts, answer_count):
        value = self.request(True, '/case-progress', {'caseId': self.case_id, 'kind': 'ready'})
        progress = int(status != 'assigned')
        xp = 50 * answer_count
        expected = {'assignmentStatus': status, 'startedAtPresent': bool(progress),
                    'completedAtPresent': bool(answer_count), 'progressRows': progress,
                    'completedProgressRows': answer_count, 'wrongCountTotal': 0, 'lockedProgressRows': 0,
                    'startReceiptCount': starts, 'answerSubmissionCount': answer_count,
                    'answerReceiptCount': answer_count, 'xpLedgerCount': answer_count, 'xpDeltaSum': xp,
                    'playerTotalXp': xp, 'submissionResults': {'correct': answer_count, 'incorrect': 0, 'manual': 0}}
        require(value.get('caseId') == self.case_id and value.get('assignmentKind') == 'ready' and
                value.get('readOnlyDiagnostic') is True and value.get('rawAnswersOrCredentialsReturned') is False and
                all(type(value.get(key)) is type(expected_value) and value[key] == expected_value
                    for key, expected_value in expected.items()),
                'Exact own answer, progress, penalty and XP facts do not match the required state')
        for key, count in (('startRequestIdSha256', starts), ('answerRequestIdSha256', answer_count)):
            hashes = value.get(key)
            require(isinstance(hashes, list) and len(hashes) == count and
                    all(isinstance(item, str) and re.fullmatch(r'[a-f0-9]{64}', item) for item in hashes),
                    'Exact request-to-receipt identities are unavailable')
        return value, expected

    def dto_for(self, status):
        dto = self.snapshot()
        assignment = dto['assignment']
        session = self.case['assignments']['ready']['sessionId']
        completed = status == 'completed'
        listing = dto['assignments']['items'][0]
        require(assignment.get('session') == listing.get('session') == session and listing.get('player') == self.case['playerId'] and
                listing.get('status') == assignment.get('status') == status and assignment.get('totalLevels') == 1 and
                assignment.get('completedLevels') == int(completed) and bool(assignment.get('startedAt')) == (status != 'assigned') and
                bool(assignment.get('completedAt')) == completed and dto['player'].get('totalXp') == 50 * int(completed),
                'Own Host DTO does not reflect the exact required one-question state')
        levels = assignment.get('levels')
        require(isinstance(levels, list) and len(levels) == 1, 'Expected a single own text level')
        level = levels[0]
        require(level.get('id') == self.level_id and level.get('xp') == 50 and level.get('wrongCount') == 0 and
                level.get('locked') is False and bool(level.get('completedAt')) == completed and
                level.get('lastAnswer') == (self.correct_answer if completed else ''),
                'Expected exact mapped level and authoritative text answer state')
        question = level.get('question')
        if status == 'assigned':
            require(question is None, 'A not-started case must protect its question')
        else:
            require(isinstance(question, dict) and question.get('id') == self.question_id and
                    {key: value for key, value in question.items() if key != 'id'} == self.expected_question,
                    'The actual text question differs from its complete frozen source')
        return dto

    def added_requests(self):
        rows = self.ledger()
        require(self.baseline is not None and rows[:len(self.baseline)] == self.baseline, 'The request ledger changed or was truncated')
        return rows[len(self.baseline):]

    def verify_ledger(self):
        self.cleanup['zeroForbiddenWrites'] = False
        added = self.added_requests()
        require(all((row.get('method') == 'GET' and row.get('path') in ('/api/health', ME, FRAME.BASE, self.detail)) or
                    (row.get('method') == 'POST' and row.get('path') in (FRAME.AUTH, self.start, self.answer_path)) for row in added),
                'A request escaped the exact own login/read/start/answer allowlist')
        require(all(row.get('status') == 200 and row.get('fault') is False and not row.get('responseDropped') and
                    not row.get('responseAwaitingDelay') for row in added), 'A request has an unexpected response or fault')
        starts = [row for row in added if row['method'] == 'POST' and row['path'] == self.start]
        answers = [row for row in added if row['method'] == 'POST' and row['path'] == self.answer_path]
        actor = hashlib.sha256((self.state['controlToken'] + ':actor:' + self.case['playerId']).encode()).hexdigest()
        level = hashlib.sha256(self.level_id.encode()).hexdigest()
        require(len(starts) <= int(self.start_invoked) and len(answers) <= int(self.submit_invoked) and
                all(row.get('operation') == operation and row.get('authenticated') is True and row.get('bearer') is False and
                    row.get('actorVerifiedByBackendResponse') is True and row.get('actorSha256') == actor and
                    re.fullmatch(r'[a-f0-9]{64}', row.get('requestIdSha256', '')) and
                    (operation == 'start' or row.get('sessionLevelIdSha256') == level)
                    for operation, records in (('start', starts), ('answer', answers)) for row in records),
                'Only one successful actor-confirmed native answer and the explicitly allowed start may appear')
        start_receipts = self.original_start_receipts + [row['requestIdSha256'] for row in starts]
        status = 'completed' if answers else ('active' if start_receipts else 'assigned')
        value, self.final_facts = self.facts(status, len(start_receipts), len(answers))
        require(value['startRequestIdSha256'] == start_receipts and
                value['answerRequestIdSha256'] == [row['requestIdSha256'] for row in answers],
                'The exact native requests must match the real receipts')
        self.final_ledger = {'baseline': self.baseline, 'added': added}
        self.cleanup['zeroForbiddenWrites'] = True
        return len(starts), len(answers)

    def field(self, raw, text, editable):
        node = FRAME.own(raw, FIELD)
        box = UI.rect(node['bounds'])
        density = self.ui.density
        require(node.get('type') == 'TextInput' and UI.exposed(node) and raw_boolean(node, 'enabled') == editable and
                node.get('text', '') == text and UI.inside(box, self.ui.viewport(FIELD), 2) and
                abs((box[2] - box[0]) / density - 314) <= 2 / density and
                abs((box[3] - box[1]) / density - 58) <= 2 / density,
                'The actual native text field value, enabled flag or full314x58vp geometry differs')
        identity = tuple(node.get(key) for key in ('accessibilityId', 'hashcode'))
        require(all(type(value) in (str, int) and bool(value) for value in identity), 'Native field instance identity is unavailable')
        return node, box, identity

    def sample(self, position, theme, text, editable, *, ime=None, require_unfocused=False):
        self.ui.seek(FIELD)
        if editable:
            self.ui.seek(SUBMIT)
        raw, evidence = self.ui.raw_app(position)
        node, box, identity = self.field(raw, text, editable)
        focused = raw_boolean(node, 'focused')
        if require_unfocused:
            require(not focused, 'The actual input is still focused in the intended idle state')
        button_box = None
        if editable:
            button = FRAME.own(raw, SUBMIT)
            button_box = UI.rect(button['bounds'])
            require(UI.exposed(button) and raw_boolean(button, 'enabled') and UI.inside(button_box, self.ui.viewport(SUBMIT), 2),
                    'The native submit action is not enabled and fully visible')
        else:
            require(any(row.get('id') == 'gameplay-answer-completed' and UI.exposed(row) for row in raw) and
                    not any(row.get('id') == SUBMIT for row in raw),
                    'Completed read-only field must show completion and have no submit action')
        if ime:
            require(focused and self.ui.keyboard_visible() and UI.inside(box, ime['availableViewportPx'], 2) and
                    UI.inside(button_box, ime['availableViewportPx'], 2) and
                    self.ui.profile_root_geometry() == ime['currentAppRootPx'],
                    'The focused text field and submit must remain in the observed actual IME viewport')
        self.ui.private_shot(position)
        self.states.append({'position': position, 'themeRequested': theme, 'enabled': editable, 'focused': focused,
                            'inputBoundsPx': box, 'submitBoundsPx': button_box, 'inputHeightVp': (box[3] - box[1]) / self.ui.density,
                            'rawSha256': evidence['sha256'], 'screenshot': self.ui.private_screenshots[-1],
                            'imeMeasurementMode': ime['measurementMode'] if ime else None})
        return identity, box

    def wait_gameplay(self):
        self.ui.wait(lambda ui: ui.find('gameplay-page') is not None and ui.find('gameplay-loading') is None and
                     ui.find('gameplay-question-card') is not None, 'own native text gameplay', timeout=40)

    def begin(self):
        self.immutable()
        self.device_binding()
        auth = self.request(False, FRAME.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str) and auth['token'],
                'Strict Host authentication must identify the own dedicated text actor')
        self.token = auth['token']
        status = self.args.entry_mode
        self.dto_for(status)
        self.original_start_receipts = self.facts(status, int(status == 'active'), 0)[0]['startRequestIdSha256']
        self.baseline = self.ledger()
        self.stage = 'native-text-login-and-entry'
        self.device_started = True
        self.ui.launch(cold=True)
        self.ui.wait(lambda ui: ui.find('account') is not None, 'empty isolated own login')
        require(self.ui.input_empty('account') and self.ui.input_empty('password') and self.ui.has_text('隔离测试环境'),
                'The native isolated login must be empty')
        self.ui.fill('account', self.case['account'])
        self.ui.fill('password', self.case['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('old-password') is None, 'ordinary own login')
        self.ui.tap('assignment-' + self.assignment_id)
        if status == 'assigned':
            self.immutable()
            self.ui.seek('start-assignment')
            self.start_invoked = True
            self.ui.run('devecocli', 'ui', 'click', '--id', 'start-assignment')
        self.wait_gameplay()
        self.web_fixtures['active'] = FRAME.write_private(self.directory / 'active-web-dtos.json', self.dto_for('active'), self.credentials())
        self.draft_probe = FRAME.write_private(self.directory / 'draft-probe.json', {'draft': DRAFT}, self.credentials())
        self.check(self.verify_ledger() == (int(status == 'assigned'), 0),
                   'Exact original text question opens with its authorized entry count and zero answer or XP')

    def empty_and_ime(self):
        self.stage = 'native-text-idle-and-empty'
        for theme in ('dark', 'light'):
            self.theme(theme)
            self.sample('idle-' + theme, theme, '', True, require_unfocused=True)
        before = len(self.ledger())
        for candidate in ('', '   '):
            if candidate:
                self.ui.fill(FIELD, candidate)
                require(self.ui.find('gameplay-answer-error') is None, 'The prior blank validation still occupies the edited form')
            self.ui.tap(SUBMIT)
            self.ui.wait(lambda ui: ui.find('gameplay-answer-error') is not None and ui.has_text('请先输入或选择答案。'),
                         'blank answer local validation')
            require(len(self.ledger()) == before, 'A blank native answer produced a request')
            self.facts('active', 1, 0)
        self.check(True, 'Empty and whitespace-only native validation create zero POST, answer receipts or XP')

        self.stage = 'native-text-ime-and-draft'
        before = len(self.ledger())
        for theme in ('light', 'dark'):
            if theme == 'dark':
                self.theme(theme)
                self.sample('draft-blurred-dark', theme, DRAFT, True, require_unfocused=True)
            self.ui.fill_without_dismiss(FIELD, DRAFT)
            ime = self.ui.actual_ime('text-' + theme)
            identity, _ = self.sample('draft-focused-' + theme, theme, DRAFT, True, ime=ime)
            self.ui.hide_keyboard()
            require(not self.ui.keyboard_visible() and self.ui.profile_root_geometry() == ime['noKeyboardBaseline']['boundsPx'],
                    'System Back must dismiss observed IME and restore the own App viewport')
            after, _ = self.sample('draft-after-ime-' + theme, theme, DRAFT, True)
            require(after == identity and len(self.ledger()) == before, 'IME Back changed the actual input instance, draft or request ledger')
            self.check(True, 'Observed ' + theme + ' IME leaves submit reachable and Back preserves the same field and draft')

    def settle(self):
        self.stage = 'one-native-text-submit'
        self.ui.fill(FIELD, self.correct_answer)
        self.ui.seek(SUBMIT)
        raw, _ = self.ui.raw_app('ready-one-text-submit')
        _, _, identity = self.field(raw, self.correct_answer, True)
        require(raw_boolean(FRAME.own(raw, SUBMIT), 'enabled'), 'The one intended native submit is not enabled')
        self.check(self.verify_ledger() == (int(self.args.entry_mode == 'assigned'), 0), 'Pre-submit exact own ledger has no answers')
        self.immutable()
        self.device_binding()
        self.submit_invoked = True
        self.ui.run('devecocli', 'ui', 'click', '--id', SUBMIT)
        pending, _ = self.ui.raw_app('after-one-text-submit')
        button = next((row for row in pending if row.get('id') == SUBMIT and row.get('text') == '正在提交…' and UI.exposed(row)), None)
        if button is not None:
            self.field(pending, self.correct_answer, False)
            require(not raw_boolean(button, 'enabled'), 'The actually observed pending submit is still enabled')
            self.pending_observed = True
        self.ui.wait(lambda ui: ui.find('gameplay-answer-completed') is not None and ui.find(SUBMIT) is None,
                     'one authoritative completed text answer', timeout=40)
        self.web_fixtures['completed'] = FRAME.write_private(
            self.directory / 'completed-web-dtos.json', self.dto_for('completed'), self.credentials())
        completed_id, box = self.sample('completed-dark', 'dark', self.correct_answer, False, require_unfocused=True)
        require(completed_id == identity, 'Completion recreated the actual native text field')
        before = len(self.ledger())
        self.ui.run('devecocli', 'ui', 'click', round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))
        self.ui.seek(FIELD)
        touched, _ = self.ui.raw_app('completed-after-touch')
        node, _, touched_id = self.field(touched, self.correct_answer, False)
        require(touched_id == identity and not raw_boolean(node, 'focused') and not self.ui.keyboard_visible() and
                len(self.ledger()) == before, 'Touching the completed field changed its value, focus, keyboard or ledger')
        self.readonly_touch_observed = True
        self.theme('light')
        self.sample('completed-light', 'light', self.correct_answer, False, require_unfocused=True)
        self.check(self.verify_ledger() == (int(self.args.entry_mode == 'assigned'), 1),
                   'One correct native answer and receipt yields 50 XP and the same input becomes read-only')
        self.answer_matches_server = True

    def reenter(self):
        self.stage = 'native-text-completed-history'
        self.ui.back()
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('gameplay-page') is None, 'own history home')
        self.ui.tap('history-tab')
        target = 'assignment-' + self.assignment_id
        self.ui.seek(target)
        before = len(self.ledger())
        self.ui.tap(target)
        self.wait_gameplay()
        added = self.ledger()[before:]
        require(len(added) == 2 and all(row.get('method') == 'GET' and row.get('path') == self.detail and
                    row.get('status') == 200 and row.get('authenticated') is True and row.get('bearer') is False for row in added),
                'Completed native history entry did not produce its two authenticated detail GET200 responses')
        self.sample('history-readonly-light', 'light', self.correct_answer, False, require_unfocused=True)
        self.check(self.verify_ledger() == (int(self.args.entry_mode == 'assigned'), 1),
                   'History reentry reads the same completed answer without another business write')

    def main(self):
        self.begin()
        self.empty_and_ime()
        self.settle()
        self.reenter()

    def execute(self):
        try:
            self.main()
        except Exception as error:
            reason = str(error)
            for item in (*self.credentials(), self.correct_answer):
                if item:
                    reason = reason.replace(item, '[private value omitted]')
            FRAME.write_private(self.directory / 'failure-diagnostic.json',
                                {'stage': self.stage, 'exceptionType': type(error).__name__, 'reason': reason}, self.credentials())
            self.failure = 'The narrow native text acceptance is incomplete; the answer was never retried'
        finally:
            try:
                self.immutable()
                if self.device_started:
                    self.device_binding()
                    self.ui.hide_keyboard()
                    self.logout()
                    self.verify_ledger()
            except Exception:
                self.failure = self.failure or 'Exact cleanup or request ownership could not be confirmed'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not all(self.cleanup.values()):
                self.failure = self.failure or 'Native text cleanup is incomplete'
        ledger = FRAME.write_private(self.directory / 'request-ledger.json', self.final_ledger, self.credentials()) if self.final_ledger else None
        if self.failure is None:
            self.stage = 'text-field-complete'
        report = {'status': 'incomplete' if self.failure else 'captured_native_text_field', 'stage': self.stage,
                  'scope': 'Narrow native single text input, blank validation, actual IME, correct submission and read-only',
                  'hapSha256': self.hap_sha, 'expectedFixtureSha256': FIXTURE_SHA, 'sourceCaseIndex': 0, 'bindingSha256': self.binding,
                  'checksPassed': len(self.checks), 'checks': self.checks, 'states': self.states, 'cleanup': self.cleanup,
                  'sameDataWebFixtures': self.web_fixtures, 'draftProbe': self.draft_probe,
                  'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
                  'imeMeasurements': self.ui.ime_evidence, 'privateReadOnlyLedger': ledger, 'observedReadOnlyFacts': self.final_facts,
                  'singleNativeSubmitInvoked': self.submit_invoked, 'submittedProbeMatchesAuthoritativeAnswerAndReceipt': self.answer_matches_server,
                  'pendingDisabledActuallyObserved': self.pending_observed,
                  'completedTouchActuallyObserved': self.readonly_touch_observed, 'visualReview': 'pending_root_original_review',
                  'wholePageParityAccepted': False, 'fixedPreviewTouched': False, 'failure': self.failure,
                  'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        secrets = (*self.credentials(), self.correct_answer, self.serial, self.case_id, self.case['account'],
                   self.case['playerId'], self.assignment_id, self.case['assignments']['ready']['sessionId'],
                   self.level_id, self.question_id, *self.source_ids)
        require(not any(value and value in encoded for value in secrets) and not re.search(r'https?://', encoded),
                'A private literal would enter the public text report')
        FRAME.fresh(self.report, OUT)
        self.report.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        descriptor = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(encoded)
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks),
                          'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 1 if self.failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    run = parser.add_subparsers(dest='action').add_parser('run')
    for name in ('runtime', 'case-ref', 'output', 'private-dir'):
        run.add_argument('--' + name, type=Path, required=True)
    run.add_argument('--expected-hap', required=True)
    run.add_argument('--entry-mode', choices=('active', 'assigned'), default='active')
    run.add_argument('--fixture-file', type=Path, default=FIXTURE)
    run.add_argument('--device-ref', type=Path, default=PRIVATE_REFERENCE / 'image-viewer-multitouch-device-02.json')
    args = parser.parse_args()
    if args.action is None:
        parser.print_help()
        return 0
    try:
        return TextFieldSample(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Exact isolated case/fixture/runtime/owner/output guards failed; private values omitted'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

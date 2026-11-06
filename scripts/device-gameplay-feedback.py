#!/usr/bin/env python3
"""Narrow real-phone checks for one fresh, formally imported text-feedback case."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import time
import urllib.request

from native_device_ui import ROOT, SafeFailure

OUT = ROOT / 'artifacts/validation/ui-gameplay-feedback-20261106'
SOURCE = ROOT / 'scripts/device-gameplay-text-field.py'
SPEC = importlib.util.spec_from_file_location('feedback_text_guard', SOURCE)
TEXT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TEXT)
TEXT.OUT = OUT
FRAME, UI, require = TEXT.FRAME, TEXT.UI, TEXT.require
FIELD, SUBMIT = TEXT.FIELD, TEXT.SUBMIT
HINT, HINT_CONTENT = 'question-hint-0', 'question-hint-content-0'
FEEDBACK, TITLE, MESSAGE = 'gameplay-feedback', 'gameplay-feedback-title', 'gameplay-feedback-message'
ERROR = 'gameplay-answer-error'
COMPLETED = 'gameplay-completed-state'
DIALOG, RETRY = 'gameplay-answer-retry-dialog', 'gameplay-answer-retry'
STAY, INLINE = 'gameplay-answer-retry-stay', 'gameplay-answer-retry-inline'
HASH_KEYS = ('requestIdSha256', 'requestBodySha256', 'actorSha256', 'sessionLevelIdSha256')


class FeedbackUI(FRAME.FrameUI):
    def minimum_height(self, node_id, node):
        if node_id in (SUBMIT, RETRY, STAY, INLINE):
            return 44 * self.density - 2
        return super().minimum_height(node_id, node)

    def quick_private_shot(self, label):
        # The caller has just observed the real state. Avoid another full
        # layout command while short feedback can legitimately expire.
        target = self.shots / (label + '.png')
        require(not target.exists() and not target.is_symlink(), 'A new private PNG path is required')
        self.run('devecocli', 'ui', 'screenshot', '--path', target)
        target.chmod(0o600)
        self.private_screenshots.append({'file': str(target.relative_to(ROOT)), 'sha256': FRAME.sha(target),
                                         'scope': 'Private original on the exact dedicated feedback case'})


class FeedbackSample(TEXT.TextFieldSample):
    def __init__(self, args):
        args.entry_mode = 'active' if args.resume_report is not None else 'assigned'
        super().__init__(args)
        self.expected_new_starts = int(args.entry_mode == 'assigned')
        self.resume_start_hash = None
        self.resume_evidence = None
        blocks = self.expected_question['content']
        require(len(blocks) == 1 and isinstance(blocks[0].get('hint'), str) and blocks[0]['hint'],
                'The exact original text case must contain its one reviewed hint')
        self.hint = blocks[0]['hint']
        self.ui = FeedbackUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
                              'controlToken': self.state['controlToken']}, self.ui.density, self.directory)
        self.sent = 0
        self.fault_armed = False
        self.cleanup['faultCleared'] = True
        self.retry_pending_observed = self.replay_verified = False
        self.bound.update({
            'feedbackDriver': Path(__file__),
            'questHintUI': ROOT / 'entry/src/main/ets/ui/StarwardQuestHint.ets',
            'questFeedbackUI': ROOT / 'entry/src/main/ets/ui/StarwardQuestFeedback.ets',
            'answerRecoveryUI': ROOT / 'entry/src/main/ets/ui/StarwardAnswerRecovery.ets',
            'dayColors': ROOT / 'entry/src/main/resources/base/element/color.json',
            'nightColors': ROOT / 'entry/src/main/resources/dark/element/color.json',
        })
        if args.resume_report is not None:
            self.bind_resume(args.resume_report)
        self.binding = {key: FRAME.sha(path) for key, path in self.bound.items()}

    def bind_resume(self, path):
        report_path = FRAME.ENTRY.guarded(path, OUT)
        old = json.loads(report_path.read_text())
        facts = old['observedReadOnlyFacts']
        require(old['status'] == 'incomplete' and old['stage'] == 'local-empty-answer-feedback'
                and all(old['cleanup'].values()) and old['checksPassed'] == 2
                and facts['assignmentStatus'] == 'active' and facts['startReceiptCount'] == 1
                and facts['answerSubmissionCount'] == facts['answerReceiptCount'] == facts['xpLedgerCount'] == 0
                and old['bindingSha256']['caseReference'] == FRAME.sha(self.reference)
                and old['bindingSha256']['questHintUI'] == FRAME.sha(self.bound['questHintUI']),
                'Resume requires the same own started, unanswered case and unchanged tested hint')
        ledger_ref = old['privateReadOnlyLedger']
        ledger = FRAME.ENTRY.guarded(Path(ledger_ref['file']), FRAME.PRIVATE, True)
        require(FRAME.sha(ledger) == ledger_ref['sha256'], 'Original private ledger changed')
        rows = json.loads(ledger.read_text())['added']
        writes = [row for row in rows if row.get('method') == 'POST' and row.get('path') in (self.start, self.answer_path)]
        require(len(writes) == 1 and writes[0]['path'] == self.start and writes[0].get('status') == 200,
                'The prior round must have issued only the one exact native entry')
        self.resume_start_hash = writes[0]['requestIdSha256']
        self.resume_evidence = {'file': str(report_path.relative_to(ROOT)), 'sha256': FRAME.sha(report_path),
                                'scope': 'Previous app package actually verified hint disclosure only; earlier checks not counted'}
        self.bound.update({'resumeReport': report_path, 'resumeLedger': ledger})

    def answers(self):
        return [row for row in self.added_requests() if row.get('method') == 'POST' and row.get('path') == self.answer_path]

    def facts(self, status, starts, answer_count, incorrect=0):
        value = self.request(True, '/case-progress', {'caseId': self.case_id, 'kind': 'ready'})
        completed = int(status == 'completed')
        expected = {'assignmentStatus': status, 'startedAtPresent': status != 'assigned',
                    'completedAtPresent': bool(completed), 'progressRows': int(status != 'assigned'),
                    'completedProgressRows': completed, 'wrongCountTotal': 0, 'lockedProgressRows': 0,
                    'startReceiptCount': starts, 'answerSubmissionCount': answer_count, 'answerReceiptCount': answer_count,
                    'xpLedgerCount': completed, 'xpDeltaSum': completed * 50, 'playerTotalXp': completed * 50,
                    'submissionResults': {'correct': completed, 'incorrect': incorrect, 'manual': 0}}
        require(value.get('caseId') == self.case_id and value.get('assignmentKind') == 'ready' and
                value.get('readOnlyDiagnostic') is True and value.get('rawAnswersOrCredentialsReturned') is False and
                all(type(value.get(key)) is type(item) and value[key] == item for key, item in expected.items()),
                'The exact own progress, receipts, error and XP facts differ')
        for key, count in (('startRequestIdSha256', starts), ('answerRequestIdSha256', answer_count)):
            hashes = value.get(key)
            require(isinstance(hashes, list) and len(hashes) == count and
                    all(isinstance(item, str) and re.fullmatch(r'[a-f0-9]{64}', item) for item in hashes),
                    'The exact backend receipt identities are unavailable')
        return value, expected

    def verify_ledger(self):
        self.cleanup['zeroForbiddenWrites'] = False
        rows = self.added_requests()
        require(all((row.get('method') == 'GET' and row.get('path') in ('/api/health', TEXT.ME, FRAME.BASE, self.detail)) or
                    (row.get('method') == 'POST' and row.get('path') in (FRAME.AUTH, self.start, self.answer_path)) for row in rows),
                'Traffic escaped the exact own auth/read/start/answer allowlist')
        require(all(row.get('status') == 200 and not row.get('responseAwaitingDelay') for row in rows),
                'Unexpected upstream failure or a still-pending response')
        starts = [row for row in rows if row['method'] == 'POST' and row['path'] == self.start]
        answers = self.answers()
        require(len(starts) <= int(self.start_invoked) and len(answers) <= self.sent <= 3 and
                all(not row.get('fault') and not row.get('responseDropped') for row in rows if row not in answers),
                'A non-answer request used a fault or an unexpected action')
        actor = hashlib.sha256((self.state['controlToken'] + ':actor:' + self.case['playerId']).encode()).hexdigest()
        level = hashlib.sha256(self.level_id.encode()).hexdigest()
        for operation, records in (('start', starts), ('answer', answers)):
            require(all(row.get('operation') == operation and row.get('authenticated') is True and row.get('bearer') is False and
                        row.get('actorVerifiedByBackendResponse') is True and row.get('actorSha256') == actor and
                        isinstance(row.get('requestIdSha256'), str) and
                        (operation == 'start' or row.get('sessionLevelIdSha256') == level) for row in records),
                    'A real write did not verify its exact actor, authentication or question')
        require(not answers or (answers[0].get('fault') is False and not answers[0].get('responseDropped')),
                'The one incorrect response must be delivered without a fault')
        if len(answers) >= 2:
            require(answers[1].get('fault') is True and answers[1].get('responseDropped') is True and
                    answers[1].get('upstreamFinished') is True and answers[0]['requestIdSha256'] != answers[1]['requestIdSha256'],
                    'The first correct response must have committed before its reply was dropped')
        if len(answers) == 3:
            require(answers[2].get('fault') is True and not answers[2].get('responseDropped') and
                    answers[2].get('matchesPriorRequestIdentity') is True and
                    all(isinstance(answers[1].get(key), str) and answers[1][key] == answers[2].get(key) for key in HASH_KEYS),
                    'Explicit reconnect did not use the identical command, actor and question')
        start_hashes = [row['requestIdSha256'] for row in starts]
        if self.resume_start_hash is not None:
            start_hashes.insert(0, self.resume_start_hash)
        status = 'completed' if len(answers) >= 2 else ('active' if start_hashes else 'assigned')
        value, self.final_facts = self.facts(status, len(start_hashes), min(len(answers), 2), incorrect=int(bool(answers)))
        require(value['startRequestIdSha256'] == start_hashes and
                sorted(value['answerRequestIdSha256']) == sorted(row['requestIdSha256'] for row in answers[:2]),
                'Exact native writes differ from the real backend receipts')
        self.final_ledger = {'baseline': self.baseline, 'added': rows}
        self.cleanup['zeroForbiddenWrites'] = True
        return len(starts), len(answers)

    def set_fault(self, delay=None, drop=False):
        self.immutable()
        body = None if delay is None else {'path': self.answer_path, 'method': 'POST',
                                           'responseDelayMs': delay, 'dropResponse': drop}
        require(body is None or (delay, drop) in ((10000, True), (12000, False)), 'The scoped fault parameters changed')
        self.cleanup['faultCleared'] = False
        self.fault_armed = True
        request = urllib.request.Request(self.control_base + '/fault', data=json.dumps(body).encode(), method='POST',
                                         headers={'Authorization': self.state['controlToken'], 'Content-Type': 'application/json'})
        try:
            with self.control_opener.open(request, timeout=5) as response:
                require(response.status == 200 and json.load(response).get('configured') is True,
                        'The exact local fault controller did not acknowledge the change')
        except Exception:
            raise SafeFailure('The exact local scoped fault operation failed') from None
        if body is None:
            self.fault_armed = False
            self.cleanup['faultCleared'] = True

    def observed(self, raw, node_id, *, enabled=None):
        node = FRAME.own(raw, node_id)
        require(UI.exposed(node), 'A required own feedback node is not visible: ' + node_id)
        if enabled is not None:
            require(TEXT.raw_boolean(node, 'enabled') is enabled, 'A required native enabled flag differs: ' + node_id)
        return node

    def has_label(self, raw, node_id, label):
        node = self.observed(raw, node_id)
        return node.get('text') == label or any(
            row.get('text') == label and UI.exposed(row) and
            UI.inside(UI.rect(row['bounds']), UI.rect(node['bounds']), 2) for row in raw)

    def state_sample(self, label, theme, raw, evidence, node_ids):
        self.ui.private_shot(label)
        bounds = {node_id: UI.rect(self.observed(raw, node_id)['bounds']) for node_id in node_ids}
        self.states.append({'position': label, 'themeRequested': theme, 'boundsPx': bounds,
                            'rawSha256': evidence['sha256'], 'screenshot': self.ui.private_screenshots[-1]})

    def hints(self):
        self.stage = 'hint-and-unchanged-draft'
        self.ui.fill(FIELD, TEXT.DRAFT)
        for theme in ('dark', 'light'):
            self.theme(theme)
            self.ui.seek(FIELD)
            raw, _ = self.ui.raw_app('feedback-draft-before-hint-' + theme)
            _, _, identity = self.field(raw, TEXT.DRAFT, True)
            self.ui.seek(HINT)
            before, evidence = self.ui.raw_app('hint-collapsed-' + theme)
            self.observed(before, HINT, enabled=True)
            require(self.has_label(before, HINT, '查看提示') and
                    not any(row.get('id') == HINT_CONTENT and UI.exposed(row) for row in before),
                    'The hint must begin collapsed with the reviewed disclosure label')
            self.state_sample('hint-collapsed-' + theme, theme, before, evidence, [HINT])
            self.ui.tap(HINT)
            self.ui.wait(lambda ui: ui.find(HINT_CONTENT) is not None, 'expanded own hint')
            opened, evidence = self.ui.raw_app('hint-expanded-' + theme)
            self.observed(opened, HINT, enabled=True)
            require(self.observed(opened, HINT_CONTENT).get('text') == self.hint and
                    self.has_label(opened, HINT, '查看提示'),
                    'Expanded actual disclosure did not show the exact frozen hint with a stable label')
            self.state_sample('hint-expanded-' + theme, theme, opened, evidence, [HINT, HINT_CONTENT])
            self.ui.tap(HINT)
            self.ui.wait(lambda ui: ui.find(HINT_CONTENT) is None, 'closed own hint')
            self.ui.seek(FIELD)
            after, _ = self.ui.raw_app('feedback-draft-after-hint-' + theme)
            _, _, after_identity = self.field(after, TEXT.DRAFT, True)
            require(after_identity == identity, 'The actual input instance or draft changed when toggling the hint')
        self.check(self.verify_ledger() == (self.expected_new_starts, 0),
                   'Light and dark hint disclosure preserve the same draft and issue zero answer POSTs')

    def pointer(self, control_id, baseline, draft=None):
        self.ui.seek(control_id)
        raw, _ = self.ui.raw_app('ready-' + control_id + '-' + str(baseline))
        button = self.observed(raw, control_id, enabled=True)
        if draft is not None:
            self.field(raw, draft, True)
        box = UI.rect(button['bounds'])
        require(button.get('type') == 'Button' and TEXT.raw_boolean(button, 'clickable') and
                UI.inside(box, self.ui.viewport(control_id), 2) and len(self.answers()) == baseline and self.sent == baseline,
                'The exact own write action is not ready in the available native viewport')
        return [round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2)]

    def click_once(self, point, baseline):
        self.immutable()
        self.device_binding()
        require(self.sent == baseline and len(self.answers()) == baseline, 'Another answer request appeared before the native touch')
        self.sent += 1
        self.ui.run('hdc', '-t', self.serial, 'shell', 'uitest', 'uiInput', 'click', *point)

    def transient(self, title, label, theme, message_id=MESSAGE):
        ids = (FEEDBACK, TITLE, message_id)
        if title == '验证未通过':
            # The actual PNG and layout are independent observations of a three-second state.
            time.sleep(.35)
            with ThreadPoolExecutor(max_workers=2) as executor:
                screen = executor.submit(self.ui.quick_private_shot, label)
                layout = executor.submit(self.ui.capture)
                screen.result()
                layout.result()
        else:
            self.ui.wait(lambda ui: all(ui.find(node_id) is not None for node_id in ids) and
                         ui.find(TITLE).get('text') == title and bool(ui.find(message_id).get('text')),
                         'actual native feedback title and message', timeout=30)
            self.ui.quick_private_shot(label)
        path = self.directory / ('cli-layout-' + label + '.json')
        proof = FRAME.write_private(path, self.ui.tree, self.credentials())
        require(all(self.ui.find(node_id) is not None for node_id in ids) and self.ui.find(TITLE).get('text') == title
                and bool(self.ui.find(message_id).get('text')), 'The fresh official layout did not observe the compact feedback copy')
        bounds = {node_id: self.ui.find(node_id)['bounds'] for node_id in ids}
        require(72 <= (bounds[FEEDBACK][3] - bounds[FEEDBACK][1]) / self.ui.density <= 105,
                'The actual narrow feedback card is not compact and fully visible')
        self.states.append({'position': label, 'themeRequested': theme, 'boundsPx': bounds,
                            'layoutSource': 'Official devecocli UI layout paired with the native screenshot',
                            'layoutEvidence': proof, 'screenshot': self.ui.private_screenshots[-1]})

    def empty_feedback(self):
        self.stage = 'local-empty-answer-feedback'
        self.ui.fill(FIELD, '')
        point = self.pointer(SUBMIT, 0, '')
        self.ui.run('hdc', '-t', self.serial, 'shell', 'uitest', 'uiInput', 'click', *point)
        self.transient('验证未通过', 'feedback-empty-light', 'light', ERROR)
        require(self.ui.find(ERROR).get('text') == '请先输入或选择答案。' and not self.answers(),
                'Empty feedback must carry the local validation copy and issue no answer')
        self.ui.wait(lambda ui: ui.find(TITLE) is None, 'expired empty feedback', timeout=12)
        self.ui.fill(FIELD, TEXT.DRAFT)
        self.check(self.verify_ledger() == (self.expected_new_starts, 0),
                   'Empty validation shows the transient feedback card and issues zero answer POSTs')

    def incorrect(self):
        self.stage = 'real-incorrect-feedback'
        point = self.pointer(SUBMIT, 0, TEXT.DRAFT)
        self.click_once(point, 0)
        self.transient('验证未通过', 'feedback-incorrect-light', 'light')
        self.ui.wait(lambda ui: ui.find(TITLE) is None, 'expired incorrect feedback', timeout=12)
        self.ui.seek(FIELD)
        raw, _ = self.ui.raw_app('feedback-incorrect-expired')
        self.field(raw, TEXT.DRAFT, True)
        dto = self.snapshot()
        require(dto['assignment']['status'] == 'active' and dto['assignment']['levels'][0].get('lastAnswer') == TEXT.DRAFT,
                'The own live DTO did not preserve the actual incorrect submission')
        self.web_fixtures['incorrect'] = FRAME.write_private(self.directory / 'incorrect-web-dtos.json', dto, self.credentials())
        self.check(self.verify_ledger() == (self.expected_new_starts, 1),
                   'A real incorrect response keeps the draft editable and changes neither progress nor XP')

    def expect_delay(self, baseline):
        rows = self.answers()
        require(len(rows) == baseline + 1 and rows[-1].get('responseAwaitingDelay') is True and
                rows[-1].get('status') == 200 and rows[-1].get('upstreamFinished') is True,
                'The exact real upstream answer is not being held during the sampled pending state')

    def delay_active(self, count):
        rows = self.answers()
        return len(rows) == count and rows[-1].get('responseAwaitingDelay') is True

    def drop_and_retry(self):
        self.stage = 'correct-answer-pending-with-held-upstream'
        original = '  ' + self.correct_answer + '  '
        self.ui.fill(FIELD, original)
        point = self.pointer(SUBMIT, 1, original)
        self.set_fault(10000, True)
        self.click_once(point, 1)
        self.ui.wait(lambda ui: self.delay_active(2),
                     'exact correct answer begins its bounded reply delay', timeout=7)
        raw, evidence = self.ui.raw_app('answer-pending-light')
        self.field(raw, original, False)
        self.observed(raw, SUBMIT, enabled=False)
        require(self.has_label(raw, SUBMIT, '提交答案') and
                not any(row.get('id') == DIALOG and UI.exposed(row) for row in raw),
                'Pending must disable submit and input before the uncertainty dialog appears')
        self.state_sample('answer-pending-light', 'light', raw, evidence, [FIELD, SUBMIT])
        self.expect_delay(1)
        self.pending_observed = True
        self.check(True, 'Actual native submit and unchanged answer are disabled while the real reply is pending')

        self.stage = 'lost-response-and-explicit-stay'
        self.ui.wait(lambda ui: ui.find(RETRY) is not None and ui.find(STAY) is not None,
                     'lost-response native modal', timeout=25)
        raw, evidence = self.ui.raw_app('retry-dialog-light')
        self.observed(raw, RETRY, enabled=True)
        self.observed(raw, STAY, enabled=True)
        self.state_sample('retry-dialog-light', 'light', raw, evidence, [DIALOG, RETRY, STAY])
        self.check(self.verify_ledger() == (self.expected_new_starts, 2),
                   'Client reply was dropped after the real correct submission committed exactly one 50 XP award')
        self.ui.tap(STAY)
        self.ui.wait(lambda ui: ui.find(INLINE) is not None and ui.find(RETRY) is None, 'dismissed modal with inline reconnect')
        self.ui.seek(FIELD)
        raw, evidence = self.ui.raw_app('retry-stayed-light')
        self.field(raw, original, False)
        self.observed(raw, INLINE, enabled=True)
        require(not any(row.get('id') in (SUBMIT, COMPLETED) and UI.exposed(row) for row in raw),
                'Staying cannot expose a new submit or premature completion')
        self.state_sample('retry-stayed-light', 'light', raw, evidence, [FIELD, INLINE])
        self.check(len(self.answers()) == 2, 'Stay preserves the blocked original answer and does not automatically retry')

        self.stage = 'explicit-reconnect-held-replay'
        self.ui.tap(INLINE)
        self.ui.wait(lambda ui: ui.find(RETRY) is not None and ui.find(STAY) is not None, 'reopened same reconnect dialog')
        self.ui.back()
        self.ui.wait(lambda ui: ui.find(INLINE) is not None and ui.find(RETRY) is None, 'system Back to the unchanged own draft')
        raw, _ = self.ui.raw_app('retry-after-system-back-light')
        self.field(raw, original, False)
        require(len(self.answers()) == 2, 'System Back cannot replay or replace the uncertain answer')
        self.ui.tap(INLINE)
        self.ui.wait(lambda ui: ui.find(RETRY) is not None and ui.find(STAY) is not None, 'second explicit reopen')
        point = self.pointer(RETRY, 2)
        self.set_fault(12000, False)
        self.click_once(point, 2)
        self.ui.wait(lambda ui: self.delay_active(3),
                     'the exact replay starts its reply delay', timeout=6)
        raw, evidence = self.ui.raw_app('retry-pending-light')
        self.observed(raw, RETRY, enabled=False)
        self.observed(raw, STAY, enabled=False)
        self.state_sample('retry-pending-light', 'light', raw, evidence, [DIALOG, RETRY, STAY])
        self.ui.back()
        self.ui.wait(lambda ui: ui.find(RETRY) is not None and self.delay_active(3),
                     'pending reconnect blocks system Back', timeout=4)
        self.expect_delay(2)
        self.retry_pending_observed = True
        self.check(True, 'Both real modal actions are disabled while the explicit reconnect is pending')

        self.stage = 'replayed-settlement-and-correct-feedback'
        self.transient('验证通过', 'feedback-correct-light', 'light')
        self.ui.seek(FIELD)
        raw, _ = self.ui.raw_app('feedback-settled-readonly-light')
        self.field(raw, self.correct_answer, False)
        require(not any(row.get('id') in (SUBMIT, RETRY, INLINE) and UI.exposed(row) for row in raw),
                'A completed answer must no longer be submittable or reconnectable')
        self.ui.seek(COMPLETED)
        self.web_fixtures['completed'] = FRAME.write_private(
            self.directory / 'completed-web-dtos.json', self.dto_for('completed'), self.credentials())
        self.check(self.verify_ledger() == (self.expected_new_starts, 3),
                   'Identical request ID, request body, actor and question replay the same receipt with only one correct answer and 50 XP')
        self.replay_verified = True

    def main(self):
        self.begin()
        if self.resume_evidence is None:
            self.hints()
        self.empty_feedback()
        self.incorrect()
        self.drop_and_retry()

    def execute(self):
        try:
            self.main()
        except Exception as error:
            reason = str(error)
            for item in self.private_literals():
                if item:
                    reason = reason.replace(item, '[private value omitted]')
            FRAME.write_private(self.directory / 'failure-diagnostic.json',
                                {'stage': self.stage, 'exceptionType': type(error).__name__, 'reason': reason}, self.credentials())
            self.failure = 'A scoped native feedback assertion failed'
        finally:
            if self.fault_armed:
                try:
                    self.set_fault()
                except Exception:
                    self.failure = self.failure or 'Scoped fault cleanup could not be confirmed'
            try:
                self.immutable()
                if self.device_started:
                    self.device_binding()
                    self.ui.wait(lambda ui: not any(row.get('responseAwaitingDelay') for row in self.answers()),
                                 'own scoped upstream response is no longer delayed', timeout=20)
                    if self.ui.find(DIALOG) is not None and self.ui.find(STAY) is not None:
                        self.ui.tap(STAY)
                    self.ui.hide_keyboard()
                    self.logout()
                    self.verify_ledger()
            except Exception:
                self.failure = self.failure or 'Exact native logout or owned write cleanup could not be confirmed'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not all(self.cleanup.values()):
                self.failure = self.failure or 'The narrow native feedback cleanup is incomplete'
        self.save()
        return int(self.failure is not None)

    def private_literals(self):
        return (*self.credentials(), self.correct_answer, self.hint, self.serial, self.case_id, self.case['account'],
                self.case['playerId'], self.assignment_id, self.case['assignments']['ready']['sessionId'],
                self.level_id, self.question_id, *self.source_ids)

    def save(self):
        ledger = FRAME.write_private(self.directory / 'request-ledger.json', self.final_ledger, self.credentials()) if self.final_ledger else None
        report = {'status': 'incomplete' if self.failure else 'captured_native_gameplay_feedback',
                  'stage': self.stage if self.failure else 'feedback-complete',
                  'scope': 'Hint disclosure, text answer feedback, and exact reconnect on one disposable text case',
                  'hapSha256': self.hap_sha, 'sourceCaseIndex': 0, 'bindingSha256': self.binding,
                  'checksPassed': len(self.checks), 'checks': self.checks, 'states': self.states, 'cleanup': self.cleanup,
                  'sameDataWebFixtures': self.web_fixtures, 'draftProbe': self.draft_probe,
                  'hintEvidenceFrom': self.resume_evidence,
                  'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
                  'privateReadOnlyLedger': ledger, 'observedReadOnlyFacts': self.final_facts,
                  'pendingDisabledActuallyObserved': self.pending_observed,
                  'retryPendingDisabledActuallyObserved': self.retry_pending_observed, 'identicalCommandReplayVerified': self.replay_verified,
                  'fixedPreviewTouched': False, 'visualReview': 'pending_root_original_review', 'failure': self.failure,
                  'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        require(not any(item and item in encoded for item in self.private_literals()) and not re.search(r'https?://', encoded),
                'A private literal would enter the public feedback report')
        FRAME.fresh(self.report, OUT)
        self.report.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream:
            stream.write(encoded)
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks),
                          'report': str(self.report.relative_to(ROOT))}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    run = parser.add_subparsers(dest='action').add_parser('run')
    for name in ('runtime', 'case-ref', 'output', 'private-dir'):
        run.add_argument('--' + name, type=Path, required=True)
    run.add_argument('--expected-hap', required=True)
    run.add_argument('--resume-report', type=Path)
    run.add_argument('--fixture-file', type=Path, default=TEXT.FIXTURE)
    run.add_argument('--device-ref', type=Path, default=TEXT.PRIVATE_REFERENCE / 'image-viewer-multitouch-device-02.json')
    args = parser.parse_args()
    if args.action is None:
        parser.print_help()
        return 0
    try:
        return FeedbackSample(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Exact scoped feedback case, package, runtime, owner or output guards failed'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

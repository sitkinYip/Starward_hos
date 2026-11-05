#!/usr/bin/env python3
"""Root-only native answer checks. Default help performs no private/device IO.

The shared EntryMain binding is reused with its imported OUT explicitly limited
to the answer validation directory. A-source files and A-reports are unchanged.
Only the text stage is implemented here; followups use the exported AnswerDevice.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import time
import uuid

from native_device_ui import ROOT, SafeFailure

SPEC = importlib.util.spec_from_file_location('answer_entry_binding', ROOT / 'scripts/device-gameplay-entry.py')
ENTRY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ENTRY)
ANSWEROUT = ROOT / 'artifacts/validation/gameplay-answer-20261104'
# This isolated imported module's path guard now authorizes only B evidence.
ENTRY.OUT = ANSWEROUT
PRIVATE = ENTRY.PRIVATE
UI = ENTRY.UI


class GameplayUI(UI.RefinementUI):
    def minimum_height(self, node_id, node):
        heights = {'gameplay-submit': 52, 'gameplay-next': 48, 'gameplay-answer-retry': 48,
                   'gameplay-leave': 44}
        return heights[node_id] * self.density - 2 if node_id in heights else super().minimum_height(node_id, node)

    def profile_root_geometry(self):
        # Reuse the reviewed actual_ime geometry algorithm with this actual own
        # gameplay Scroll, rather than substituting the full display wrapper.
        roots = [node for node in self.flat if node.get('type') == 'root' and node.get('bounds')]
        pages = [node for node in self.flat if node.get('id') == 'gameplay-page']
        ENTRY.require(len(roots) == len(pages) == 1 and self.find(UI.PANEL_ID) is None and
                      any(node is pages[0] for node in UI.flatten(roots[0])),
                      'A unique own gameplay Scroll/root without an account panel is required')
        app, page = UI.rect(roots[0]['bounds']), UI.rect(pages[0].get('bounds'))
        ENTRY.require(UI.positive(app) and UI.positive(page) and UI.inside(page, app),
                      'The actual gameplay Scroll is outside its own App root')
        return app

    def hide_keyboard(self):
        super().hide_keyboard()
        if self.find('gameplay-page') is not None and self.find(UI.PANEL_ID) is None:
            ENTRY.require(not self.keyboard_visible(), 'The gameplay baseline still has an observed IME')
            app = self.profile_root_geometry()
            path = self.output / ('no-keyboard-gameplay-root-' + uuid.uuid4().hex + '.json')
            self.persist_raw(path, json.dumps({'type': 'root', 'bounds': app,
                'scope': 'Actual own gameplay typed-root after observed IME absence; descendants omitted'}))
            self.no_keyboard_baseline = {'boundsPx': app, 'sourceRoot': {
                'file': str(path.relative_to(ROOT)), 'sha256': ENTRY.sha(path)},
                'sourcePage': 'gameplay', 'observedImeAbsent': True}


class AnswerDevice(ENTRY.EntryMain):
    def __init__(self, args):
        super().__init__(args)
        ENTRY.require(self.state['gameplay'].get('answerProtocol') == {
            'version': 1, 'playerPostAnswers': True, 'ownSessionFixtures': True,
            'readOnlyAnswerDiagnostics': True}, 'The exact reviewed answer protocol is required')
        expected = {'manual': ['text', 'choice'], 'auto-next': ['text', 'choice'],
                    'choice-cooldown': ['choice'], 'choice-lock': ['choice'], 'single-normal': ['text']}
        ENTRY.require(self.case.get('fixture') in expected and
                      self.case.get('fixtureLevelKinds') == expected[self.case['fixture']] and
                      not self.case.get('label', '').startswith('answer-host-'),
                      'The explicit phone case is not a supported separate native answer fixture')
        self.answer_path = self.detail + '/answers'
        for name, path in {'answerDriver': Path(__file__),
            'gameplayPage': ROOT / 'entry/src/main/ets/features/GameplayPage.ets',
            'gameplayViewModel': ROOT / 'entry/src/main/ets/features/GameplayViewModel.ets',
            'httpsRepository': ROOT / 'entry/src/main/ets/data/HttpsGameRepository.ets',
            'gameplayDecoder': ROOT / 'entry/src/main/ets/data/GameplayDecoder.ets'}.items():
            self.bound[name], self.binding[name] = path, ENTRY.sha(path)
        self.ui = GameplayUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
            'controlToken': self.state['controlToken']}, self.ui.density, self.directory, side_panel=True)

    def save(self, status):
        result = {'status': status, 'stage': self.stage, 'answerKind': self.args.stage,
            'scope': 'Native answer slice only; entry/login are setup, no unexecuted followup credit',
            'hapSha256': self.hap_sha, 'bindingSha256': self.binding, 'checksPassed': len(self.checks),
            'checks': self.checks, 'observations': self.observations, 'cleanup': self.cleanup,
            'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
            'visualReview': 'pending_root_original_review', 'fixedPreviewTouched': False,
            'privateCredentialsOrRecordIdsPersisted': False,
            'writeScope': 'Native exact-case start/answer only; Host authentication/read and disposable fault control. No creation/reset/profile/password/reward/admin write.'}
        if self.failure:
            result['failure'] = self.failure
        encoded = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
        ENTRY.require(not any(secret and secret in encoded for secret in self.secrets()),
                      'A private literal would enter the public answer report')
        self.report.parent.mkdir(parents=True, exist_ok=True)
        descriptor = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o644)
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(encoded)

    def secrets(self):
        values = super().secrets()
        values += [item.get('sessionId', '') for item in self.case['assignments'].values()]
        values += [item.get('id', '') for item in self.state['gameplay']['questions']]
        return values

    def answers(self):
        return [row for row in self.requests() if row.get('method') == 'POST' and row.get('path') == self.answer_path]

    def wait_question(self):
        self.ui.wait(lambda ui: ui.find('gameplay-page') is not None and ui.find('gameplay-loading') is None,
                     'native answer gameplay page', timeout=40)
        self.ui.seek('question-title')

    @staticmethod
    def facts(value):
        return {key: value.get(key) for key in ('assignmentStatus', 'startedAtPresent', 'completedAtPresent',
            'progressRows', 'completedProgressRows', 'wrongCountTotal', 'lockedProgressRows',
            'answerSubmissionCount', 'startReceiptCount', 'answerReceiptCount', 'answerRequestIdSha256',
            'xpLedgerCount', 'xpDeltaSum', 'playerTotalXp', 'submissionResults')}

    def assert_counts(self, submissions, receipts, completed, xp, wrong=0, locked=0):
        value = self.diagnostic()
        self.check(value.get('answerSubmissionCount') == submissions and value.get('answerReceiptCount') == receipts and
                   value.get('completedProgressRows') == value.get('xpLedgerCount') == completed and
                   value.get('xpDeltaSum') == value.get('playerTotalXp') == xp and
                   value.get('wrongCountTotal') == wrong and value.get('lockedProgressRows') == locked,
                   'Real native answer facts match expected submissions, receipts, completion, penalty and XP counts')
        return value

    def prepare(self, fresh=True):
        self.stage = 'answer-ordinary-setup'
        auth = self.host_read(ENTRY.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        ENTRY.require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str),
                      'Strict Host authentication did not identify the explicit answer player')
        self.token = auth['token']
        player, snapshot, facts = self.host_read('/api/questions/v1/me'), self.host_read(self.detail), self.diagnostic()
        ENTRY.require(player.get('id') == self.case['playerId'] and player.get('mustChangePassword') is False and
                      snapshot.get('id') == self.assignment_id and snapshot.get('player') == self.case['playerId'] and
                      len(snapshot.get('levels', [])) == len(self.case['fixtureLevelKinds']),
                      'The ordinary answer snapshot does not belong to the exact native case')
        if fresh:
            ENTRY.require(snapshot.get('status') == 'assigned' and not snapshot.get('startedAt') and
                          all(row.get('question') is None for row in snapshot['levels']) and
                          all(facts.get(key) == 0 for key in ('progressRows', 'startReceiptCount',
                              'answerReceiptCount', 'answerSubmissionCount', 'xpLedgerCount', 'xpDeltaSum', 'playerTotalXp')) and
                          not self.starts() and not self.answers(), 'The native answer case is not pristine')
        else:
            ENTRY.require(snapshot.get('status') in ('active', 'completed') and bool(snapshot.get('startedAt')) and
                          facts.get('startReceiptCount') == 1, 'The existing answer case has no single real entry')
        self.ui.launch(cold=True)
        self.ui.wait(lambda ui: ui.find('account') is not None, 'empty native answer login')
        self.device_started = True
        ENTRY.require(self.ui.input_empty('account') and self.ui.input_empty('password') and self.ui.has_text('隔离测试环境'),
                      'The answer login is not empty and isolated')
        self.ui.fill('account', self.case['account'])
        self.ui.fill('password', self.case['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'ordinary answer home')
        self.ui.tap('assignment-' + self.assignment_id)
        if fresh:
            self.ui.wait(lambda ui: ui.find('start-assignment') is not None, 'native answer detail')
            self.ui.tap('start-assignment')
        self.wait_question()
        self.immutable()
        return self.host_read(self.detail), self.diagnostic()

    def logout(self):
        self.ui.hide_keyboard()
        self.ui.back()
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('gameplay-page') is None, 'answer home before logout')
        self.ui.tap('account-menu')
        self.ui.tap('logout')
        self.ui.wait(lambda ui: ui.find('account') is not None, 'answer logout')
        self.cleanup['loggedOut'] = True
        self.cleanup['loginInputsEmpty'] = self.ui.input_empty('account') and self.ui.input_empty('password')
        self.cleanup['privateGameplayAbsent'] = self.ui.find('gameplay-page') is None and self.ui.find('question-title') is None
        self.check(self.cleanup['loginInputsEmpty'] and self.cleanup['privateGameplayAbsent'],
                   'Native answer logout clears login inputs and private gameplay')

    def text(self):
        ENTRY.require(self.case.get('fixture') == 'manual', 'Text stage requires its fresh manual own-session case')
        snapshot, initial = self.prepare(fresh=True)
        first = snapshot['levels'][0]['id']
        ENTRY.require(snapshot.get('currentIndex') == 0 and snapshot['levels'][1].get('question') is None and
                      snapshot['levels'][0].get('autoNext') is False, 'Text fixture is not the manual first question')
        self.stage = 'text-local-validation'
        self.ui.seek('gameplay-answer-input')
        ENTRY.require(self.ui.find('gameplay-answer-input').get('text', '') == '', 'The fresh answer draft is not empty')
        for value in ('', '   '):
            if value:
                self.ui.fill('gameplay-answer-input', value)
            self.ui.tap('gameplay-submit')
            self.ui.wait(lambda ui: ui.find('gameplay-answer-error') is not None and ui.has_text('请先输入或选择答案。'),
                         'empty or whitespace validation')
            self.check(not self.answers() and self.facts(self.diagnostic()) == self.facts(initial),
                       'Empty or whitespace native validation explains the missing answer without a POST or business write')
        self.stage = 'text-actual-ime-wrong'
        self.ui.fill_without_dismiss('gameplay-answer-input', '隔离错误答案')
        ime = self.ui.actual_ime('answer-text')
        field = self.ui.seek('gameplay-answer-input')
        submit = self.ui.seek('gameplay-submit')
        viewport = ime['availableViewportPx']
        self.check(UI.inside(field['bounds'], viewport) and UI.inside(submit['bounds'], viewport) and
                   self.ui.keyboard_visible(), 'Actual observed IME leaves the answer input and scroll-reachable submit within its measured available App viewport')
        self.observations['ime'] = {key: ime.get(key) for key in ('measurementMode', 'availableViewportHeightVp',
            'imeWindowHeightVp', 'appViewportReductionPx', 'appViewportReductionVp', 'rootClassifications')}
        self.ui.private_shot('answer-text-ime')
        self.ui.tap('gameplay-submit')
        self.ui.wait(lambda ui: ui.find('gameplay-feedback') is not None and ui.has_text('答案不正确，可以继续尝试。'),
                     'real incorrect text200')
        wrong_rows = self.answers()
        self.check(len(wrong_rows) == 1 and wrong_rows[0].get('status') == 200 and
                   wrong_rows[0].get('actorVerifiedByBackendResponse') is True and
                   self.ui.find('gameplay-answer-input') is not None and
                   self.ui.find('gameplay-answer-input').get('text') == '隔离错误答案',
                   'Incorrect text returns real200 and retains the editable original input')
        wrong_facts = self.assert_counts(1, 1, 0, 0)
        self.stage = 'text-correct-pending'
        raw_answer = '  星辰大海  '
        self.ui.fill('gameplay-answer-input', raw_answer)
        self.ui.seek('gameplay-submit')
        self.control('/fault', {'path': self.answer_path, 'method': 'POST', 'responseDelayMs': self.args.delay_ms})
        self.fault_configured = True
        self.ui.run('devecocli', 'ui', 'click', '--id', 'gameplay-submit')
        raw, evidence = self.ui.raw_app('answer-text-pending')
        inputs = [row for row in raw if row.get('id') == 'gameplay-answer-input']
        buttons = [row for row in raw if row.get('id') == 'gameplay-submit' and UI.exposed(row)]
        self.check(len(inputs) == len(buttons) == 1 and inputs[0].get('text') == raw_answer and
                   inputs[0].get('enabled') == buttons[0].get('enabled') == 'false' and
                   buttons[0].get('text') == '正在提交…',
                   'Raw actual pending input and submit are disabled while preserving the original spaced answer')
        self.ui.wait(lambda ui: ui.find('gameplay-answer-completed') is not None and
                     ui.find('gameplay-submit') is None, 'real correct text settlement', timeout=35)
        self.ui.seek('gameplay-answer-input')
        settled_raw, _ = self.ui.raw_app('answer-text-completed')
        completed_inputs = [row for row in settled_raw if row.get('id') == 'gameplay-answer-input']
        self.check(len(completed_inputs) == 1 and completed_inputs[0].get('enabled') == 'false' and
                   completed_inputs[0].get('text') == '星辰大海' and self.ui.find('gameplay-answer-completed') is not None,
                   'Completed first question displays the authoritative normalized last answer as read-only')
        self.ui.seek('gameplay-next')
        self.ui.seek('question-title')
        self.check(self.ui.has_text('星辰之门') and not self.ui.has_text('守门人的选择'),
                   'Manual completion stays on the first question with an explicit next action')
        self.ui.seek('gameplay-progress')
        self.check(self.ui.has_text('已解开 1 / 2'), 'Native progress displays exactly one of the two authoritative completions')
        final = self.assert_counts(2, 2, 1, 50)
        after, player, rows = self.host_read(self.detail), self.host_read('/api/questions/v1/me'), self.answers()
        self.check(after.get('status') == 'active' and after.get('currentIndex') == 1 and
                   after.get('completedLevels') == 1 and isinstance(after['levels'][1].get('question'), dict) and
                   player.get('totalXp') == 50 and len(rows) == 2 and all(row.get('status') == 200 and
                       row.get('operation') == 'answer' and row.get('actorVerifiedByBackendResponse') is True and
                       row.get('authenticated') is True and row.get('bearer') is False and
                       row.get('sessionLevelIdSha256') == hashlib.sha256(first.encode()).hexdigest()
                       for row in rows),
                   'Strict backend reads confirm active1/2, two answer receipts, one XP award and the unlocked next question')
        self.observations['text'] = self.facts(final) | {'emptyAndWhitespacePosts': 0,
            'manualRemainsOnFirst': True, 'readonlyAuthoritativeLastAnswer': True, 'nextQuestionUnlocked': True,
            'nativeAnswerRequests': len(rows), 'wrongTextHasNoPenalty': wrong_facts['wrongCountTotal'] == 0,
            'rawAuthorizationNoBearer': True}
        self.ui.private_shot('answer-text-one-of-two')
        self.logout()
        self.immutable()

    def main(self):
        self.text()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-only native first text slice on a separate fresh manual case')
    run.add_argument('--stage', choices=('text',), default='text')
    run.add_argument('--runtime', type=Path, default=ANSWEROUT / 'runtime-01.json')
    run.add_argument('--case-ref', type=Path, default=PRIVATE / 'phone-answer-manual-case-ref.json')
    run.add_argument('--output', type=Path, default=ANSWEROUT / 'device-answer-text.json')
    run.add_argument('--expected-hap')
    run.add_argument('--delay-ms', type=int, default=10000)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return AnswerDevice(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'The explicit answer case, matching runtime, HTTPS or fresh output guard failed; private values omitted'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())

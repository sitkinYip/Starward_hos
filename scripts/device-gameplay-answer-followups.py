#!/usr/bin/env python3
"""Root-only narrow native answer followups; default help does no private/device IO.

Run each stage only after the prior small slice is accepted. Cases are explicit
private references prepared by Root. This helper never creates/resets accounts,
submits Host answers, changes a fixture, or touches the fixed preview player.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import time

from native_device_ui import ROOT

SPEC = importlib.util.spec_from_file_location('answer_device_reused', ROOT / 'scripts/device-gameplay-answer.py')
BASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)
ENTRY, UI = BASE.ENTRY, BASE.UI


class FollowupUI(BASE.GameplayUI):
    def viewport(self, node_id=None):
        value = super().viewport(node_id)
        if node_id and node_id.startswith('gameplay-level-') and node_id != 'gameplay-level-navigation':
            path = self.path_to(node_id) or []
            pages = [node for node in path if node.get('id') == 'gameplay-page']
            bars = [node for node in path if node.get('id') == 'gameplay-level-navigation']
            ENTRY.require(len(pages) == len(bars) == 1,
                          'Question navigation must belong to its actual own vertical and horizontal Scrolls')
            page, bar, app = UI.rect(pages[0]['bounds']), UI.rect(bars[0]['bounds']), self.app_rect()
            ENTRY.require(UI.positive(page) and UI.positive(bar), 'Question navigation has no positive measured Scroll')
            # The horizontal Scroll is exactly as tall as its buttons. The
            # generic seek's vertical8px inset must use the vertical page, while
            # horizontal clipping still uses the actual navigation Scroll.
            value = [max(app[0], page[0], bar[0]), max(app[1], page[1]),
                     min(app[2], page[2], bar[2]), min(app[3], page[3])]
            if self.available_bottom is not None:
                value[3] = min(value[3], self.available_bottom)
        return value


class AnswerFollowups(BASE.AnswerDevice):
    def __init__(self, args):
        super().__init__(args)
        self.bound['followupDriver'] = Path(__file__)
        self.binding['followupDriver'] = ENTRY.sha(Path(__file__))
        fixtures = {'manual-complete': 'manual', 'auto-next': 'auto-next',
                    'single-normal': 'single-normal', 'choice-cooldown': 'choice-cooldown',
                    'choice-lock': 'choice-lock'}
        ENTRY.require(self.case.get('fixture') == fixtures[args.stage],
                      'The explicit native case does not match this followup fixture')
        self.ui = FollowupUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
            'controlToken': self.state['controlToken']}, self.ui.density, self.directory, side_panel=True)

    def snapshot(self):
        value = self.host_read(self.detail)
        ENTRY.require(value.get('id') == self.assignment_id and value.get('player') == self.case['playerId'] and
                      isinstance(value.get('levels'), list) and
                      len(value['levels']) == len(self.case['fixtureLevelKinds']),
                      'The current followup snapshot lost its exact case identity')
        return value

    def choice(self, snapshot, index):
        level = snapshot['levels'][index]
        question = level.get('question')
        ENTRY.require(isinstance(question, dict) and question.get('kind') == 'choice' and
                      [row.get('key') for row in question.get('options', [])] == ['A', 'B'],
                      'The own choice fixture is not the reviewed pair of options')
        return level

    def wait_feedback(self):
        self.ui.wait(lambda ui: ui.find('gameplay-feedback') is not None and
                     not ui.has_text('正在提交…') and not ui.has_text('正在重新连接…'),
                     'authoritative native answer feedback', timeout=35)

    def choose_and_submit(self, index):
        self.ui.tap('gameplay-option-' + str(index))
        self.submit_ready(index)
        self.wait_feedback()

    def submit_ready(self, option_index=None):
        self.ui.seek('gameplay-submit')
        deadline = time.monotonic() + 6
        button = None
        while time.monotonic() < deadline:
            raw, _ = self.ui.raw_app('followup-ready-submit')
            buttons = [row for row in raw if row.get('id') == 'gameplay-submit' and UI.exposed(row)]
            selected = option_index is None or any(row.get('id') == 'gameplay-option-' + str(option_index) and
                row.get('checked') == 'true' for row in raw)
            if len(buttons) == 1 and buttons[0].get('enabled') == 'true' and selected:
                button = buttons[0]
                break
            time.sleep(.1)
        ENTRY.require(button is not None, 'The intended selection and enabled submit were not observed before touch')
        box = UI.rect(button['bounds'])
        ENTRY.require(UI.positive(box) and UI.inside(box, self.ui.viewport('gameplay-submit')),
                      'The ready submit is outside its actual available App Scroll')
        count = len(self.answers())
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click',
                    round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))
        deadline = time.monotonic() + 5
        rows = self.answers()
        while time.monotonic() < deadline and (len(rows) < count + 1 or rows[-1].get('status') == 0):
            time.sleep(.1)
            rows = self.answers()
        self.check(len(rows) == count + 1 and rows[-1].get('status') == 200 and
                   rows[-1].get('actorVerifiedByBackendResponse') is True,
                   'One measured ready-submit touch creates exactly one new real answer200 before UI feedback is assessed')

    def text_and_submit(self):
        values = [row.get('answer') for row in self.state['gameplay']['questions'] if row.get('kind') == 'text']
        ENTRY.require(len(values) == 1 and isinstance(values[0], str) and values[0].strip(),
                      'The explicit disposable text fixture answer is absent')
        self.ui.fill('gameplay-answer-input', values[0])
        self.submit_ready()

    def answer_ledger(self, expected_count, levels):
        rows = self.answers()
        hashes = {hashlib.sha256(value.encode()).hexdigest() for value in levels}
        self.check(len(rows) == expected_count and all(row.get('status') == 200 and row.get('operation') == 'answer' and
                   row.get('actorVerifiedByBackendResponse') is True and row.get('authenticated') is True and
                   row.get('bearer') is False and row.get('sessionLevelIdSha256') in hashes for row in rows),
                   'Answer request ledger retains exact-case level and backend-confirmed account binding with raw Authorization')
        return rows

    def completed(self, count, xp):
        snapshot, player = self.snapshot(), self.host_read('/api/questions/v1/me')
        self.check(snapshot.get('status') == 'completed' and bool(snapshot.get('completedAt')) and
                   snapshot.get('completedLevels') == snapshot.get('totalLevels') == count and
                   all(bool(row.get('completedAt')) for row in snapshot['levels']) and
                   player.get('id') == self.case['playerId'] and player.get('totalXp') == xp,
                   'Strict real backend reads confirm completion and the full authoritative player XP')
        return snapshot

    def no_multi_dialog(self):
        self.ui.capture()
        self.check(not self.ui.has_text('组合谜题全部破解') and not self.ui.has_text('知晓了'),
                   'No new multi-question completion dialog appears for this state')

    def acknowledge_completion(self):
        self.ui.capture()
        labels = [node for node in self.ui.flat if node.get('text') == '知晓了' and node.get('bounds')]
        ENTRY.require(len(labels) == 1 and self.ui.has_text('组合谜题全部破解'),
                      'A unique measured completion confirmation label is required')
        box = UI.rect(labels[0]['bounds'])
        ENTRY.require(UI.positive(box) and UI.inside(box, self.ui.app_rect()),
                      'The official completion confirmation label is outside its own App')
        self.ui.raw_app('manual-completion-dialog')
        # AlertDialog may expose the label as a Text child of its Button.
        # Click its exact observed label, without a generic seek/swipe that
        # could cancel a modal by beginning outside its content.
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click',
                    round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))

    def return_home(self):
        self.ui.hide_keyboard()
        self.ui.back()
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('gameplay-page') is None,
                     'followup home after native Back')

    def manual_complete(self):
        snapshot, _ = self.prepare(fresh=False)
        self.stage = 'manual-authoritative-reentry'
        self.assert_counts(2, 2, 1, 50)
        ENTRY.require(snapshot.get('status') == 'active' and snapshot.get('currentIndex') == 1 and
                      snapshot['levels'][0].get('completedAt') and snapshot['levels'][0].get('autoNext') is False and
                      len(self.answers()) == 2 and len(self.starts()) == 1,
                      'Manual followup requires the exact text-stage settlement and no intervening answers')
        first, second = snapshot['levels'][0], self.choice(snapshot, 1)
        self.check(self.ui.has_text(second['question']['title']) and self.ui.find('gameplay-option-0') is not None,
                   'GET reentry opens the server current choice without submitting another answer')
        self.ui.tap('gameplay-level-0')
        self.ui.seek('gameplay-answer-input')
        raw, _ = self.ui.raw_app('manual-previous-readonly')
        inputs = [row for row in raw if row.get('id') == 'gameplay-answer-input']
        self.check(len(inputs) == 1 and inputs[0].get('enabled') == 'false' and
                   inputs[0].get('text') == first.get('lastAnswer') and
                   self.ui.find('gameplay-submit') is None and len(self.answers()) == 2,
                   'The previous completed text remains read-only with its authoritative last answer')
        self.ui.tap('gameplay-next')
        self.ui.wait(lambda ui: ui.has_text(second['question']['title']) and ui.find('gameplay-option-0') is not None,
                     'explicit manual next question')
        self.stage = 'manual-choice-incorrect'
        self.choose_and_submit(0)
        self.assert_counts(3, 3, 1, 50, wrong=1)
        after_wrong = self.snapshot()
        self.check(after_wrong.get('status') == 'active' and after_wrong['levels'][1].get('lastAnswer') == 'A' and
                   not after_wrong['levels'][1].get('locked') and not after_wrong['levels'][1].get('cooldownUntil') and
                   self.ui.find('gameplay-submit') is not None,
                   'Incorrect choice200 preserves the selection, increments only server wrong count and remains actionable')
        self.stage = 'manual-choice-complete'
        self.ui.tap('gameplay-option-1')
        self.submit_ready(1)
        self.ui.wait(lambda ui: ui.has_text('组合谜题全部破解') and ui.has_text('知晓了'),
                     'fresh official multi-question completion dialog', timeout=35)
        self.check(self.ui.has_text('你已完成本次组合中的 2 道谜题。'),
                   'The fresh official completion dialog displays the authoritative completed count')
        self.ui.private_shot('manual-completion-dialog')
        self.acknowledge_completion()
        self.ui.wait(lambda ui: not ui.has_text('组合谜题全部破解') and ui.find('gameplay-completed-state') is not None,
                     'official completion notice dismissal')
        final = self.assert_counts(4, 4, 2, 100, wrong=1)
        completed = self.completed(2, 100)
        self.answer_ledger(4, [first['id'], second['id']])
        self.stage = 'manual-completed-get-only'
        before_gets = len([row for row in self.requests() if row.get('method') == 'GET' and row.get('path') == self.detail])
        self.ui.tap('primary-action')
        self.wait_question()
        self.no_multi_dialog()
        self.check(self.facts(self.diagnostic()) == self.facts(final) and len(self.answers()) == 4 and len(self.starts()) == 1,
                   'Completed synchronization only reads and never resubmits or settles XP again')
        self.return_home()
        self.ui.tap('history-tab')
        self.ui.seek('assignment-' + self.assignment_id)
        self.check(self.ui.find('assignment-state-' + self.assignment_id) is not None and
                   self.ui.find('assignment-state-' + self.assignment_id).get('text') == '故事已解开' and
                   self.ui.has_text('已解开 2 / 2'),
                   'Returned history displays this real completed assignment and its two-of-two progress')
        self.ui.private_shot('manual-completed-history')
        self.ui.tap('assignment-' + self.assignment_id)
        self.wait_question()
        self.no_multi_dialog()
        self.ui.seek('gameplay-option-1')
        raw, _ = self.ui.raw_app('manual-completed-revisit')
        options = [row for row in raw if row.get('id') in ('gameplay-option-0', 'gameplay-option-1')]
        self.check(len(options) == 2 and all(row.get('enabled') == 'false' for row in options) and
                   self.ui.find('gameplay-submit') is None and completed['levels'][1].get('lastAnswer') == 'B' and
                   self.facts(self.diagnostic()) == self.facts(final) and len(self.answers()) == 4 and len(self.starts()) == 1,
                   'Completed revisit is read-only with no additional answer, entry or celebration')
        after_gets = len([row for row in self.requests() if row.get('method') == 'GET' and row.get('path') == self.detail])
        self.check(after_gets >= before_gets + 3, 'Synchronization and detail/gameplay revisit use fresh real GET requests')
        self.observations['manualComplete'] = self.facts(final) | {'officialCompletionDialog': True,
            'previousQuestionReadOnly': True, 'explicitManualNext': True, 'completedRevisitReadOnly': True,
            'noAdditionalStartOrAnswerOnGet': True, 'totalAnswerRequestsIncludingPriorText': 4,
            'priorTextAnswerRequests': 2, 'nativeChoiceAnswerRequestsInThisStage': 2}

    def auto_next(self):
        snapshot, _ = self.prepare(fresh=True)
        first = snapshot['levels'][0]
        ENTRY.require(first.get('autoNext') is True and snapshot.get('currentIndex') == 0 and
                      snapshot['levels'][1].get('question') is None, 'The fresh case is not the reviewed auto-next fixture')
        self.stage = 'auto-next-answer'
        self.text_and_submit()
        self.ui.wait(lambda ui: ui.find('gameplay-option-0') is not None and ui.has_text('守门人的选择'),
                     'official native auto-next after the settled server flag', timeout=35)
        final = self.assert_counts(1, 1, 1, 50)
        after = self.snapshot()
        self.check(after.get('status') == 'active' and after.get('currentIndex') == 1 and
                   after['levels'][0].get('autoNext') is True and after['levels'][0].get('completedAt') and
                   isinstance(after['levels'][1].get('question'), dict) and self.ui.find('gameplay-answer-input') is None,
                   'One real text answer automatically advances the visible question without a manual next click or another write')
        self.answer_ledger(1, [first['id']])
        self.no_multi_dialog()
        self.ui.private_shot('auto-next-current-choice')
        self.observations['autoNext'] = self.facts(final) | {'automaticVisibleAdvance': True, 'manualNextClicks': 0,
            'nativeAnswerRequests': 1, 'nextChoiceAnswered': False}

    def single_normal(self):
        snapshot, _ = self.prepare(fresh=True)
        ENTRY.require(len(snapshot['levels']) == 1 and snapshot.get('presentation', {}).get('completionStyle') == 'normal' and
                      snapshot.get('completionTarget') is None, 'The single case is not an ordinary text completion')
        self.stage = 'single-normal-complete'
        self.text_and_submit()
        self.ui.wait(lambda ui: ui.find('gameplay-completed-state') is not None and
                     ui.find('gameplay-answer-completed') is not None, 'single answer inline completion', timeout=35)
        self.ui.seek('gameplay-answer-input')
        raw, _ = self.ui.raw_app('single-normal-completed')
        inputs = [row for row in raw if row.get('id') == 'gameplay-answer-input']
        self.check(len(inputs) == 1 and inputs[0].get('enabled') == 'false' and self.ui.find('gameplay-submit') is None,
                   'A single normal scene has a read-only settled answer and an inline completed state')
        final = self.assert_counts(1, 1, 1, 50)
        self.completed(1, 50)
        self.answer_ledger(1, [snapshot['levels'][0]['id']])
        self.no_multi_dialog()
        self.ui.private_shot('single-normal-inline-completion')
        self.observations['singleNormal'] = self.facts(final) | {'inlineCompletion': True,
            'multiQuestionDialogShown': False, 'nativeAnswerRequests': 1}

    def choice_cooldown(self):
        snapshot, _ = self.prepare(fresh=True)
        level = self.choice(snapshot, 0)
        self.stage = 'choice-unselected-local-validation'
        self.ui.seek('gameplay-submit')
        raw, evidence = self.ui.raw_app('choice-unselected-before-touch')
        buttons = [row for row in raw if row.get('id') == 'gameplay-submit' and UI.exposed(row)]
        options = [row for row in raw if row.get('id') in ('gameplay-option-0', 'gameplay-option-1')]
        ENTRY.require(len(buttons) == 1 and buttons[0].get('enabled') == 'true' and
                      len(options) == 2 and all(row.get('checked') == 'false' for row in options),
                      'Unselected validation requires both native Radios unchecked and an enabled submit')
        box = UI.rect(buttons[0]['bounds'])
        ENTRY.require(UI.positive(box) and UI.inside(box, self.ui.viewport('gameplay-submit')),
                      'The unselected submit is outside the actual available App Scroll')
        before = self.facts(self.diagnostic())
        ENTRY.require(len(self.answers()) == 0, 'Fresh choice validation already has answer requests')
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click',
                    round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))
        self.ui.wait(lambda ui: ui.has_text('请先输入或选择答案。'), 'native unselected choice explanation')
        self.check(len(self.answers()) == 0 and self.facts(self.diagnostic()) == before,
                   'An unselected native choice explains validation locally with zero answer POSTs or changed business facts')
        self.observations['unselectedChoice'] = {'nativeSubmitTouches': 1, 'answerRequests': 0,
            'businessFactsUnchanged': True, 'rawEvidenceSha256': evidence['sha256']}
        self.stage = 'choice-cooldown-active'
        self.choose_and_submit(0)
        self.ui.seek('gameplay-submit')
        raw, evidence = self.ui.raw_app('choice-cooldown-disabled')
        buttons = [row for row in raw if row.get('id') == 'gameplay-submit' and UI.exposed(row)]
        options = [row for row in raw if row.get('id') in ('gameplay-option-0', 'gameplay-option-1')]
        before = self.diagnostic()
        self.check(before.get('steps', [{}])[0].get('cooldownActive') is True and
                   len(buttons) == 1 and buttons[0].get('enabled') == 'false' and len(options) == 2 and
                   all(row.get('enabled') == 'false' for row in options) and
                   self.ui.has_text('距离再次尝试还有', contains=True),
                   'Before real server expiry the native countdown is visible and both choice and submit are disabled')
        self.assert_counts(1, 1, 0, 0, wrong=1)
        # Click only the already-measured disabled own button, with enough real
        # server time remaining to avoid turning this into another answer.
        until = before['steps'][0].get('cooldownUntil', '')
        from datetime import datetime
        remaining = datetime.fromisoformat(until.replace('Z', '+00:00')).timestamp() - time.time()
        ENTRY.require(remaining >= 2, 'The short cooldown expired before a safe disabled-button probe')
        box = UI.rect(buttons[0].get('bounds'))
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click',
                    round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))
        self.check(len(self.answers()) == 1 and self.facts(self.diagnostic()) == self.facts(before),
                   'Touching the measured disabled submit creates no additional answer request or business fact')
        self.ui.private_shot('choice-cooldown-countdown')
        self.stage = 'choice-cooldown-expired'
        deadline = time.monotonic() + 18
        while time.monotonic() < deadline and self.diagnostic()['steps'][0]['cooldownActive']:
            time.sleep(.5)
        ENTRY.require(self.diagnostic()['steps'][0]['cooldownActive'] is False,
                      'The real server cooldown did not expire inside the bounded window')
        self.ui.wait(lambda ui: ui.find('gameplay-penalty') is None and ui.find('gameplay-submit') is not None,
                     'native visual clock allows a new attempt after server expiry')
        self.choose_and_submit(1)
        self.ui.wait(lambda ui: ui.find('gameplay-completed-state') is not None, 'correct choice after real cooldown')
        final = self.assert_counts(2, 2, 1, 50, wrong=1)
        self.completed(1, 50)
        self.answer_ledger(2, [level['id']])
        self.no_multi_dialog()
        self.ui.private_shot('choice-after-cooldown-completed')
        self.observations['cooldown'] = self.facts(final) | {'countdownAndDisabledObservedBeforeExpiry': True,
            'disabledSubmitExtraPosts': 0, 'realServerExpiryObserved': True, 'nativeAnswerRequests': 2,
            'rawDisabledEvidenceSha256': evidence['sha256'], 'directHostAnswerPosts': 0}

    def choice_lock(self):
        snapshot, _ = self.prepare(fresh=True)
        level = self.choice(snapshot, 0)
        self.stage = 'choice-permanent-lock'
        self.choose_and_submit(0)
        self.ui.seek('gameplay-submit')
        raw, evidence = self.ui.raw_app('choice-lock-disabled')
        controls = [row for row in raw if row.get('id') in ('gameplay-submit', 'gameplay-option-0', 'gameplay-option-1')]
        final = self.assert_counts(1, 1, 0, 0, wrong=1, locked=1)
        self.check(len(controls) == 3 and all(row.get('enabled') == 'false' for row in controls) and
                   self.ui.has_text('永久锁定', contains=True) and self.snapshot()['levels'][0].get('locked') is True,
                   'The real locked response disables editing and submission with a persistent native lock explanation')
        self.stage = 'choice-lock-get-recovery'
        self.return_home()
        self.ui.tap('assignment-' + self.assignment_id)
        self.wait_question()
        self.ui.seek('gameplay-submit')
        raw, _ = self.ui.raw_app('choice-lock-revisit')
        controls = [row for row in raw if row.get('id') in ('gameplay-submit', 'gameplay-option-0', 'gameplay-option-1')]
        self.check(len(controls) == 3 and all(row.get('enabled') == 'false' for row in controls) and
                   self.ui.has_text('永久锁定', contains=True) and self.facts(self.diagnostic()) == self.facts(final) and
                   len(self.answers()) == len(self.starts()) == 1,
                   'Return and GET reentry preserve the real permanent lock without another answer or entry')
        self.answer_ledger(1, [level['id']])
        self.ui.private_shot('choice-permanent-lock-revisit')
        self.observations['lock'] = self.facts(final) | {'readonlyLockedControls': True,
            'lockSurvivesGetReentry': True, 'nativeAnswerRequests': 1, 'rawDisabledEvidenceSha256': evidence['sha256']}

    def main(self):
        actions = {'manual-complete': self.manual_complete, 'auto-next': self.auto_next,
                   'single-normal': self.single_normal, 'choice-cooldown': self.choice_cooldown,
                   'choice-lock': self.choice_lock}
        actions[self.args.stage]()
        self.logout()
        self.immutable()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-only one explicit native followup stage; no Host answer writes')
    run.add_argument('--stage', choices=('manual-complete', 'auto-next', 'single-normal',
                                       'choice-cooldown', 'choice-lock'), required=True)
    run.add_argument('--runtime', type=Path, required=True)
    run.add_argument('--case-ref', type=Path, required=True)
    run.add_argument('--output', type=Path)
    run.add_argument('--expected-hap')
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    args.output = args.output or BASE.ANSWEROUT / ('device-answer-' + args.stage + '.json')
    args.delay_ms = 10000  # Retain the shared runtime guard; followups configure no fault.
    try:
        return AnswerFollowups(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'The exact native followup case, current runtime or fresh report guard failed; private values omitted'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())

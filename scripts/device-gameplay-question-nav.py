#!/usr/bin/env python3
"""Narrow native question-navigation evidence using one disposable manual case."""

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib.parse import urlparse

from native_device_ui import ROOT, flatten


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


FOLLOWUP = load('navigation_followup', 'device-gameplay-answer-followups.py')
FRAME = load('navigation_frame', 'device-question-frame.py')
ENTRY, UI = FOLLOWUP.ENTRY, FOLLOWUP.UI
require, sha = ENTRY.require, ENTRY.sha
OUT = ROOT / 'artifacts/validation/ui-gameplay-question-nav-20261106'
ENTRY.OUT = FRAME.VALIDATION
NAV = 'gameplay-level-navigation'
SECOND_NUMBER = 'gameplay-level-1'
FIELD = 'gameplay-answer-input'
ME = '/api/questions/v1/me'


class NavigationUI(FOLLOWUP.FollowupUI):
    gameplay_foreground = False

    def capture(self, name=None):
        if not self.gameplay_foreground:
            return super().capture(name)
        # The shared capture requires a title control, which can be absent
        # after actual scrolling or during answer-input focus.
        require(name is None, 'Use the private raw collector during native gameplay')
        self.tree, self.flat, self.width, self.height = None, [], 0, 0
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            tree = json.loads(self.run('devecocli', 'ui', 'layout', '--format', 'json', '--mode', 'full'))
            flat = flatten(tree)
            roots = [node for node in flat if node.get('type') == 'root' and node.get('bounds')]
            pages = [node for node in flat if node.get('id') == 'gameplay-page' and
                     node.get('type') == 'Scroll' and node.get('bounds')]
            if len(roots) == len(pages) == 1 and any(node is pages[0] for node in flatten(roots[0])):
                app, page = UI.rect(roots[0]['bounds']), UI.rect(pages[0]['bounds'])
                require(UI.positive(app) and UI.positive(page) and UI.inside(page, app),
                        'The identified gameplay Scroll is outside its own App root')
                self.tree, self.flat = tree, flat
                self.width, self.height = app[2] - app[0], app[3] - app[1]
                return flat
            time.sleep(.2)
        require(False, 'The own foreground gameplay Scroll is not observed')

    def minimum_height(self, node_id, node):
        if node_id == 'gameplay-submit' or node_id.startswith('gameplay-level-'):
            return 44 * self.density - 2
        return super().minimum_height(node_id, node)


class NavigationSample(FOLLOWUP.AnswerFollowups):
    def __init__(self, args):
        FRAME.fresh(args.output, OUT)
        require(re.fullmatch(r'[a-f0-9]{64}', args.expected_hap or ''), 'An explicit HAP SHA256 is required')
        args.stage, args.delay_ms = 'manual-complete', 10000
        super().__init__(args)
        require(self.case['label'] == 'question-nav-phone' and self.case['fixture'] == 'manual',
                'Use the exact fresh, dedicated manual case labelled question-nav-phone')
        reference = ENTRY.guarded(args.device_ref, FRAME.PRIVATE, True)
        device = json.loads(reference.read_text())
        self.serial = device.get('deviceSerial', '')
        require(set(device) == {'deviceSerial'} and re.fullmatch(r'[A-Za-z0-9]{8,80}', self.serial),
                'An explicit reviewed private phone reference is required')
        self.ui = NavigationUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
            'controlToken': self.state['controlToken']}, self.ui.density, self.directory, side_panel=True)
        self.bound.update({'navDriver': Path(__file__), 'deviceReference': reference,
                           'frameGuard': Path(FRAME.__file__)})
        self.binding = {name: sha(path) for name, path in self.bound.items()}
        self.baseline, self.allowed_starts, self.allowed_answers = None, 0, 0
        self.states, self.fixtures = [], {}
        self.first_level = ''
        self.first_settled = False
        self.cleanup.pop('faultNeutralised')
        self.cleanup['zeroUnexpectedWrites'] = False
        self.births = self.owners()

    def owners(self):
        runner = ROOT / 'scripts/isolated-backend.mjs'
        proxy = ENTRY.loopback(self.state.get('proxyBase'), 'http')
        return [FRAME.owner(self.state['pid'], runner, {'start'},
                            [urlparse(proxy).port, urlparse(self.control_base).port]),
                FRAME.owner(self.state['tls']['pid'], ROOT / 'scripts/isolated-tls.mjs', {'start', 'resume'},
                            [urlparse(self.host).port])]

    def device_binding(self):
        require(self.ui.run('hdc', 'list', 'targets').split() == [self.serial], 'The exact sole reviewed phone is required')
        forwards = [line.split() for line in self.ui.run('hdc', '-t', self.serial, 'fport', 'ls').splitlines()]
        require([row for row in forwards if len(row) > 1 and row[1] == 'tcp:18443'] ==
                [[self.serial, 'tcp:18443', 'tcp:' + str(self.state['tls']['hostPort']), '[Reverse]']],
                'The phone lacks the exact own disposable USB TLS mapping')

    def control(self, path, body=None):
        require(path in ('/requests', '/case-progress'), 'This check only reads local diagnostics')
        return super().control(path, body)

    def check(self, value, label):
        require(value, label)
        self.checks.append(label)
        print(json.dumps({'checksPassed': len(self.checks), 'passed': label}), flush=True)

    def wait_question(self):
        self.ui.wait(lambda ui: ui.find('gameplay-page') is not None and ui.find('gameplay-loading') is None,
                     'native navigation gameplay page', timeout=40)
        self.ui.gameplay_foreground = True
        self.ui.seek('question-title')

    def return_home(self):
        self.ui.hide_keyboard()
        self.ui.back()
        self.ui.gameplay_foreground = False
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('gameplay-page') is None,
                     'navigation home after native Back')

    def logout(self):
        self.ui.capture()
        if self.ui.find('gameplay-page') is not None:
            self.return_home()
        if self.ui.find('account') is None:
            self.ui.tap('account-menu')
            self.ui.tap('logout')
        self.ui.wait(lambda ui: ui.find('account') is not None, 'native navigation empty login')
        self.cleanup['loggedOut'] = True
        self.cleanup['loginInputsEmpty'] = self.ui.input_empty('account') and self.ui.input_empty('password')
        self.cleanup['privateGameplayAbsent'] = all(self.ui.find(node_id) is None for node_id in
            ('gameplay-page', 'question-title', FIELD))
        self.check(self.cleanup['loginInputsEmpty'] and self.cleanup['privateGameplayAbsent'],
                   'Native navigation logout clears inputs and private gameplay')

    def ledger(self, exact=True):
        rows = self.requests()
        require(self.baseline is not None and rows[:len(self.baseline)] == self.baseline,
                'The original private ledger changed')
        added = rows[len(self.baseline):]
        require(all(((row.get('method') == 'GET' and row.get('path') in ('/api/health', ME, ENTRY.BASE, self.detail)) or
                     (row.get('method') == 'POST' and row.get('path') in (ENTRY.AUTH, self.start, self.answer_path))) and
                    row.get('status') == 200 and row.get('fault') is False and not row.get('responseDropped') and
                    not row.get('responseAwaitingDelay') for row in added), 'Unexpected route, failure or fault in the owned ledger')
        starts = [row for row in added if row['method'] == 'POST' and row['path'] == self.start]
        answers = [row for row in added if row['method'] == 'POST' and row['path'] == self.answer_path]
        actor = hashlib.sha256((self.state['controlToken'] + ':actor:' + self.case['playerId']).encode()).hexdigest()
        for operation, records, maximum in (('start', starts, self.allowed_starts), ('answer', answers, self.allowed_answers)):
            require((len(records) == maximum if exact else len(records) <= maximum) and
                    all(row.get('operation') == operation and row.get('authenticated') is True and
                        row.get('bearer') is False and row.get('actorVerifiedByBackendResponse') is True and
                        row.get('actorSha256') == actor and (operation == 'start' or
                            row.get('sessionLevelIdSha256') == hashlib.sha256(self.first_level.encode()).hexdigest())
                        for row in records), 'A native write does not match the expected count, actor or first question')
        facts = self.diagnostic()
        require(facts.get('startRequestIdSha256') == [row.get('requestIdSha256') for row in starts] and
                facts.get('answerRequestIdSha256') == [row.get('requestIdSha256') for row in answers] and
                facts.get('answerSubmissionCount') == facts.get('answerReceiptCount') == len(answers) and
                facts.get('xpLedgerCount') == facts.get('completedProgressRows') == len(answers) and
                facts.get('xpDeltaSum') == facts.get('playerTotalXp') == 50 * len(answers),
                'Exact real backend receipts, progress or XP differ from native writes')
        self.observations['writeCounts'] = {'starts': len(starts), 'answers': len(answers), 'xp': facts['xpDeltaSum']}
        return added

    def nav_state(self, label, current, enabled, title, *, shot=False):
        self.ui.wait(lambda ui: ui.has_text(title) and ui.find(NAV) is not None, 'expected own title and question navigator')
        raw, evidence = self.ui.raw_app(label)
        nodes = []
        statuses = ('已完成' if self.first_settled else '第 1 题', '第 2 题')
        for index, usable in enumerate(enabled):
            rows = [row for row in raw if row.get('id') == f'gameplay-level-{index}' and UI.exposed(row)]
            require(len(rows) == 1 and rows[0].get('enabled') == str(usable).lower(),
                    'The exact visible question-number button enabled state differs')
            box = UI.rect(rows[0]['bounds'])
            require(any(row.get('type') == 'Text' and row.get('text') == statuses[index] and UI.exposed(row) and
                        UI.inside(UI.rect(row['bounds']), box, 2) for row in raw),
                    'The expected visible status is absent from its measured question-number button')
            nodes.append(rows[0])
        require(any(row.get('id') == 'question-title' and row.get('text') == title and UI.exposed(row) for row in raw),
                'The expected exact question title is absent in official raw UiTest evidence')
        selected = [index for index, row in enumerate(nodes)
                    if row.get('selected') == 'true' or '当前题目' in str(row.get('description', ''))]
        require(not selected or selected == [current], 'An exposed current-question state belongs to another button')
        self.states.append({'state': label, 'viewedQuestion': current + 1, 'buttonEnabled': list(enabled),
                            'buttonLabels': list(statuses),
                            'rawCurrentStateObserved': selected == [current], 'rawEvidence': evidence})
        if shot:
            self.ui.private_shot(label)
        return nodes

    def touch_number(self, index, row):
        button_id = f'gameplay-level-{index}'
        box = UI.rect(row.get('bounds'))
        require(row.get('id') == button_id and UI.positive(box) and UI.inside(box, self.ui.viewport(button_id)),
                'The exact number-button touch is outside its measured Scroll')
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click',
                    round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))

    def save_fixture(self, label, detail):
        player, assignments = self.host_read(ME), self.host_read(ENTRY.BASE)
        require(player.get('id') == self.case['playerId'] and detail.get('player') == self.case['playerId'] and
                detail.get('id') == self.assignment_id, 'The same-data fixture lost its dedicated actor or assignment')
        self.fixtures[label] = FRAME.write_private(self.directory / (label + '-web-dtos.json'),
            {'player': player, 'assignments': assignments, 'assignment': detail},
            (self.token, self.case['newPassword'], self.state['controlToken']))

    def main(self):
        self.device_binding()
        self.baseline = self.requests()
        self.allowed_starts = 1
        initial, _ = self.prepare()
        first, locked = initial['levels']
        self.first_level = first['id']
        require(initial['currentIndex'] == 0 and first['autoNext'] is False and locked['question'] is None and
                isinstance(first.get('question'), dict), 'Real entry did not expose just the first question')
        self.save_fixture('first-current-second-locked', initial)
        first_title = first['question']['title']
        self.stage = 'locked-and-current-touch'
        buttons = self.nav_state('first-current-second-locked', 0, (True, False), first_title, shot=True)
        self.touch_number(1, buttons[1])
        buttons = self.nav_state('locked-touch-keeps-first', 0, (True, False), first_title)
        self.touch_number(0, buttons[0])
        self.nav_state('same-current-touch-keeps-first', 0, (True, False), first_title)
        self.ledger()
        self.check(True, 'Real entry exposes the first question only; physical locked and same-current taps keep it without a new write')

        self.stage = 'one-first-answer-setup'
        self.allowed_answers = 1
        self.text_and_submit()
        self.ui.wait(lambda ui: ui.find('gameplay-next') is not None, 'first exact question completion', timeout=30)
        settled = self.snapshot()
        require(settled['status'] == 'active' and settled['currentIndex'] == 1 and settled['levels'][0].get('completedAt') and
                isinstance(settled['levels'][1].get('question'), dict), 'The real first correct answer did not unlock the second question')
        self.ledger()
        self.first_settled = True
        self.save_fixture('first-complete-second-unlocked', settled)
        second_title = settled['levels'][1]['question']['title']
        self.stage = 'viewed-and-completed-question-switches'
        # Seeking the Scroll itself cannot satisfy seek's insets against its
        # own viewport. The second button is inside the left-aligned track.
        self.ui.seek(SECOND_NUMBER)
        buttons = self.nav_state('first-complete-still-viewed', 0, (True, True), first_title, shot=True)
        self.touch_number(1, buttons[1])
        self.nav_state('second-current-first-complete', 1, (True, True), second_title, shot=True)
        self.ui.tap('gameplay-option-0')
        self.ui.seek(SECOND_NUMBER)
        buttons = self.nav_state('second-current-with-draft', 1, (True, True), second_title)
        self.touch_number(1, buttons[1])
        self.ui.seek('gameplay-option-0')
        raw, _ = self.ui.raw_app('same-current-choice-draft')
        require(any(row.get('id') == 'gameplay-option-0' and row.get('checked') == 'true' for row in raw),
                'Touching the currently viewed number did not preserve the unsubmitted selection')
        self.ui.seek(SECOND_NUMBER)
        buttons = self.nav_state('before-return-to-completed-first', 1, (True, True), second_title)
        self.touch_number(0, buttons[0])
        self.nav_state('completed-first-viewed-again', 0, (True, True), first_title, shot=True)
        self.ui.seek(FIELD)
        raw, _ = self.ui.raw_app('completed-first-authoritative-readonly')
        require(any(row.get('id') == FIELD and row.get('enabled') == 'false' and
                    row.get('text') == settled['levels'][0]['lastAnswer'] for row in raw) and
                not any(row.get('id') == 'gameplay-submit' for row in raw),
                'The previously completed question is not authoritative read-only')
        self.ui.seek(SECOND_NUMBER)
        buttons = self.nav_state('before-return-to-second', 0, (True, True), first_title)
        self.touch_number(1, buttons[1])
        self.nav_state('second-viewed-again', 1, (True, True), second_title)
        self.ledger()
        self.check(True, 'Unlocked and completed numbers switch the viewed question; same-current preserves selection and the first question remains read-only')

        self.stage = 'back-and-authoritative-get-resume'
        self.return_home()
        before = self.ledger()
        self.ui.tap('assignment-' + self.assignment_id)
        self.wait_question()
        self.nav_state('resume-opens-server-current-second', 1, (True, True), second_title)
        require(any(row.get('method') == 'GET' and row.get('path') == self.detail for row in self.ledger()[len(before):]),
                'Back and reentry did not make a fresh exact GET')
        self.check(True, 'Back and reentry resume the authoritative second question without another start or answer')

    def execute(self):
        try:
            self.main()
        except Exception as error:
            self.failure = self.safe_failure(error)
        finally:
            try:
                self.immutable()
                require(self.owners() == self.births, 'The exact disposable environment owners changed')
                if self.device_started:
                    self.device_binding()
                    self.logout()
                if self.baseline is not None:
                    self.ledger(exact=self.failure is None)
                    self.cleanup['zeroUnexpectedWrites'] = True
            except Exception as error:
                self.failure = self.failure or self.safe_failure(error)
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not all(self.cleanup.values()):
                self.failure = self.failure or 'Own native cleanup remains incomplete'
        self.save('incomplete' if self.failure else 'captured_native_question_navigation')
        return int(self.failure is not None)

    def save(self, status):
        result = {'status': status, 'stage': self.stage, 'hapSha256': self.hap_sha, 'checksPassed': len(self.checks),
                  'scope': 'One disposable two-question phone case; excludes horizontal overflow and title collapse',
                  'checks': self.checks, 'states': self.states, 'cleanup': self.cleanup, 'bindingSha256': self.binding,
                  'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
                  'sameDataWebFixtures': self.fixtures, 'observations': self.observations,
                  'fixedPreviewTouched': False, 'visualReview': 'pending_root_original_review', 'failure': self.failure}
        encoded = json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        require(not any(value and value in encoded for value in (*self.secrets(), self.serial)) and
                not re.search(r'https?://', encoded), 'A private literal would enter the navigation report')
        FRAME.fresh(self.report, OUT)
        self.report.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream:
            stream.write(encoded)
        print(json.dumps({'status': status, 'checksPassed': len(self.checks),
                          'report': str(self.report.relative_to(ROOT))}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    run = parser.add_subparsers(dest='action').add_parser('run')
    for name in ('runtime', 'case-ref', 'device-ref', 'output'):
        run.add_argument('--' + name, type=Path, required=True)
    run.add_argument('--expected-hap', required=True)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return NavigationSample(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Exact navigation case, package, runtime, owner or output guards failed'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

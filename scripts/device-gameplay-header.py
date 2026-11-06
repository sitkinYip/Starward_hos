#!/usr/bin/env python3
"""Collect native title collapse evidence on the existing long choice case."""

import argparse
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import sys
import time

from native_device_ui import ROOT, flatten


SPEC = importlib.util.spec_from_file_location('gameplay_header_frame', ROOT / 'scripts/device-question-frame.py')
FRAME = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FRAME)
UI, require, sha = FRAME.UI, FRAME.require, FRAME.sha
OUT = FRAME.VALIDATION / 'ui-gameplay-question-nav-20261106'
FIXTURE_SHA = '1ad7a59cc1f13e6dd7ec5550c8f5ab4a5906b90f9a9b56ac948143a4995e8745'
PRIOR = FRAME.VALIDATION / 'ui-gameplay-feedback-20261106/native-choice-cooldown-02.json'
PAGE, CARD, ANCHOR = 'gameplay-page', 'gameplay-question-card', 'question-number'
TITLE, TAIL = 'account-menu', ('gameplay-option-2', 'gameplay-submit', 'gameplay-clue-notice')
TAG = 'StarwardQuestHeader'


def transitions(log, pid):
    events = []
    for line in log.splitlines():
        match = re.fullmatch(
            r'\s*\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+(\d+)\s+\d+\s+[DIWEF]\s+'
            r'\S*/' + TAG + r':\s*hidden=(true|false)\s+offset=(-?\d+(?:\.\d+)?)\s+'
            r'threshold=(\d+(?:\.\d+)?)\s*', line)
        if match and match[1] == pid:
            events.append({'hidden': match[2] == 'true', 'offsetVp': float(match[3]), 'thresholdVp': float(match[4])})
    return events


class HeaderUI(FRAME.FrameUI):
    gameplay_foreground = False

    def private_shot(self, name):
        super().private_shot(name)
        try:
            self.capture()
        except Exception:
            # A system overlay can take focus between the layout and screenshot.
            path = ROOT / self.private_screenshots.pop()['file']
            path.unlink()
            raise

    def capture(self, name=None):
        if not self.gameplay_foreground:
            return super().capture(name)
        # The test's normal foreground marker is inside the collapsing title.
        # While testing the header, require the exact vertical gameplay Scroll
        # and its own root even when the title is absent.
        require(name is None, 'Gameplay evidence uses the private raw collector')
        self.tree, self.flat, self.width, self.height = None, [], 0, 0
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            tree = json.loads(self.run('devecocli', 'ui', 'layout', '--format', 'json', '--mode', 'full'))
            flat = flatten(tree)
            pages = [node for node in flat if node.get('id') == PAGE and node.get('type') == 'Scroll' and node.get('bounds')]
            roots = [node for node in flat if node.get('type') == 'root' and node.get('bounds')]
            if len(pages) == len(roots) == 1 and any(node is pages[0] for node in flatten(roots[0])):
                app, page = UI.rect(roots[0]['bounds']), UI.rect(pages[0]['bounds'])
                require(UI.positive(app) and UI.positive(page) and UI.inside(page, app),
                        'The identified gameplay viewport is outside its own App root')
                self.tree, self.flat = tree, flat
                self.width, self.height = app[2] - app[0], app[3] - app[1]
                return flat
            time.sleep(.2)
        require(False, 'The own foreground gameplay Scroll is not observed')


class HeaderSample(FRAME.FrameSample):
    def __init__(self, args):
        FRAME.fresh(args.output, OUT)
        args.expected_fixture_sha = FIXTURE_SHA
        super().__init__(args)
        prior = FRAME.ENTRY.guarded(PRIOR, FRAME.VALIDATION)
        old = json.loads(prior.read_text())
        require(old.get('status') == 'captured_native_choice_cooldown' and old.get('sourceCaseIndex') == 1 and
                old.get('bindingSha256', {}).get('caseReference') == sha(self.reference) and
                self.case['sourceContent']['sourceCaseIndex'] == 1 and self.case['fixtureLevelKinds'] == ['choice'],
                'Use the same previously checked long choice case and receipt')
        device_ref = FRAME.ENTRY.guarded(args.device_ref, FRAME.PRIVATE, True)
        device = json.loads(device_ref.read_text())
        self.serial = device.get('deviceSerial', '')
        require(set(device) == {'deviceSerial'} and re.fullmatch(r'[A-Za-z0-9]{8,80}', self.serial),
                'The reviewed private phone reference is required')
        self.bound.update({'headerDriver': Path(__file__), 'deviceReference': device_ref, 'priorChoiceReceipt': prior,
                           'indexPage': ROOT / 'entry/src/main/ets/pages/Index.ets'})
        self.binding = {key: sha(path) for key, path in self.bound.items()}
        self.ui = HeaderUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
                            'controlToken': self.state['controlToken']}, self.ui.density, self.directory)
        self.baseline = self.baseline_facts = self.top = None
        self.pid, self.trace = '', []
        self.cleanup['ordinaryScrollReadOnly'] = False

    def device_binding(self):
        require(self.ui.run('hdc', 'list', 'targets').split() == [self.serial], 'The exact sole reviewed phone is required')
        forwards = [line.split() for line in self.ui.run('hdc', '-t', self.serial, 'fport', 'ls').splitlines()]
        require([row for row in forwards if len(row) > 1 and row[1] == 'tcp:18443'] ==
                [[self.serial, 'tcp:18443', 'tcp:' + str(self.state['tls']['hostPort']), '[Reverse]']],
                'The phone lacks the exact own disposable USB TLS mapping')

    def facts(self):
        value = self.request(True, '/case-progress', {'caseId': self.case_id, 'kind': 'ready'})
        expected = {'caseId': self.case_id, 'assignmentKind': 'ready', 'readOnlyDiagnostic': True,
                    'rawAnswersOrCredentialsReturned': False, 'assignmentStatus': 'active',
                    'startedAtPresent': True, 'completedAtPresent': False, 'startReceiptCount': 1, 'progressRows': 1,
                    'answerSubmissionCount': 1, 'answerReceiptCount': 1, 'wrongCountTotal': 1,
                    'lockedProgressRows': 0, 'completedProgressRows': 0, 'xpLedgerCount': 0, 'xpDeltaSum': 0,
                    'playerTotalXp': 0, 'submissionResults': {'correct': 0, 'incorrect': 1, 'manual': 0}}
        steps = value.get('steps')
        require(all(type(value.get(key)) is type(item) and value[key] == item for key, item in expected.items()) and
                isinstance(steps, list) and len(steps) == 1 and steps[0].get('cooldownActive') is False,
                'The long case must be active with exactly its prior wrong answer and an expired cooldown')
        return value

    def verify_ledger(self):
        rows = self.ledger()
        require(rows[:len(self.baseline)] == self.baseline, 'The original private ledger changed')
        added = rows[len(self.baseline):]
        require(all(((row.get('method') == 'GET' and row.get('path') in ('/api/health', '/api/questions/v1/me', FRAME.BASE, self.detail)) or
                     (row.get('method') == 'POST' and row.get('path') == FRAME.AUTH)) and row.get('status') == 200 and
                    row.get('fault') is False and not row.get('responseDropped') and not row.get('responseAwaitingDelay')
                    for row in added) and self.facts() == self.baseline_facts,
                'Unexpected traffic or a changed real progress, receipt or XP fact')
        self.final_ledger = {'baseline': self.baseline, 'added': added}
        self.cleanup['zeroForbiddenWrites'] = True
        return sum(row.get('method') == 'GET' and row.get('path') == self.detail for row in added)

    def observe(self, label, shot=False):
        raw, record = self.ui.raw_app(label)
        exposed = [row for row in raw if UI.exposed(row)]
        by_id = {row.get('id'): UI.rect(row['bounds']) for row in exposed
                 if row.get('id') in (PAGE, CARD, ANCHOR, *TAIL)}
        require(PAGE in by_id, 'The raw gameplay Scroll is absent')
        bars = [UI.rect(node['bounds']) for node in self.ui.path_to(TITLE) or []
                if node.get('type') in ('TitleBar', 'NavDestinationTitleBar') and node.get('bounds')]
        title_exposed = any(row.get('id') == TITLE for row in exposed)
        require(len(bars) <= 1 and (not title_exposed or len(bars) == 1),
                'Official title geometry and its menu control disagree')
        sample = {'state': label, 'viewportPx': by_id[PAGE], 'titleVisible': title_exposed,
                  'titleBarPx': bars[0] if title_exposed else None, 'cardPx': by_id.get(CARD),
                  'numberPx': by_id.get(ANCHOR), 'tailPx': {key: by_id[key] for key in TAIL if key in by_id},
                  'rawEvidence': record}
        if self.top:
            require(sample['viewportPx'] == self.top['viewportPx'], 'The Scroll viewport jumped during a title transition')
            anchor = sample['numberPx']
            first = self.top['numberPx']
            if anchor is not None and abs((anchor[3] - anchor[1]) - (first[3] - first[1])) <= 1:
                sample['offsetPx'] = first[1] - anchor[1]
                sample['unclippedCardTopPx'] = self.top['cardPx'][1] - sample['offsetPx']
        self.states.append(sample)
        if shot:
            self.ui.private_shot(label)
        return sample

    def gesture(self, sample, delta_vp, mode='drag', speed=200):
        left, top, right, bottom = sample['viewportPx']
        size = round(delta_vp * self.ui.density)
        require(0 < abs(size) < (bottom - top) * .8, 'The requested measured gesture is outside its viewport')
        # The outside gutter avoids long-pressing text, answers or image controls.
        x = round(right - 7 * self.ui.density)
        center = (top + bottom) / 2
        start, end = round(center - size / 2), round(center + size / 2)
        self.ui.run('devecocli', 'ui', mode, x, start, x, end, '--speed', speed)
        time.sleep(.35)

    def logs(self):
        output = self.ui.run('hdc', 'shell', 'hilog', '-x', '-T', TAG, '-P', self.pid)
        self.trace = transitions(output, self.pid)
        return self.trace

    def collapse(self):
        baseline = self.top
        gap = baseline['cardPx'][1] - baseline['titleBarPx'][3]
        density = self.ui.density
        before = hidden = None
        self.stage = 'threshold-crossing'
        for index, distance in enumerate((5, 8, 11, 11, 13, 16, 21, 25)):
            self.gesture(baseline, -distance)
            sample = self.observe(f'threshold-{index + 1}')
            if not sample['titleVisible']:
                hidden = sample
                break
            if 2 < sample.get('offsetPx', 0) < gap:
                before = sample
                self.ui.private_shot(f'before-threshold-{index + 1}')
        require(before is not None and hidden is not None and hidden.get('offsetPx', -1) >= gap - 2 and
                hidden['offsetPx'] > before['offsetPx'], 'Official physical captures did not bracket the title threshold')
        logs = self.logs()
        require(len(logs) == 1 and logs[0]['hidden'] and
                abs(logs[0]['thresholdVp'] - gap / density) <= 3 and
                logs[0]['offsetVp'] >= logs[0]['thresholdVp'] - .5 and
                logs[0]['offsetVp'] <= hidden['offsetPx'] / density + 2,
                'The first native transition does not corroborate the observed question-card threshold')
        self.ui.private_shot('first-title-hidden')
        self.check(True, 'The real Scroll moves while the title remains visible before the edge, then hides at the measured question-card threshold')
        return hidden

    def reverse_and_bottom(self, hidden):
        self.stage = 'minor-reverse-and-bottom'
        for index, distance in enumerate((6, 9, 12)):
            self.gesture(hidden, distance)
            sample = self.observe(f'reverse-{index + 1}')
            offset = sample.get('offsetPx')
            require(not sample['titleVisible'] and offset is not None and offset > 2,
                    'A minor reverse motion showed the title or reached the page top')
            if offset < hidden['offsetPx'] - 2:
                self.ui.private_shot('title-still-hidden-after-minor-reverse')
                self.check(True, 'The question visibly moves back toward the top while the title stays hidden')
                break
        else:
            require(False, 'A nonzero partial reverse Scroll movement was not observed')

        for index in range(10):
            self.gesture(sample, -230, 'swipe', 600)
            next_sample = self.observe(f'near-bottom-{index + 1}')
            require(not next_sample['titleVisible'], 'The title appeared during deeper scrolling')
            if ('gameplay-submit' in next_sample['tailPx'] and next_sample['tailPx'] == sample['tailPx']):
                require(len(self.logs()) == 1 and self.trace[0]['hidden'],
                        'A second title transition happened before returning to top')
                self.ui.private_shot('title-still-hidden-at-bottom')
                self.check(True, 'The title remains hidden at the physically observed bottom of the question')
                return next_sample
            sample = next_sample
        require(False, 'The physical bottom and its stable submit area were not observed')

    def restore(self, sample):
        self.stage = 'true-top-restores-title'
        for index in range(12):
            remaining = sample.get('offsetPx')
            distance = 230 if remaining is None else min(230, max(0, remaining) / self.ui.density + 8)
            self.gesture(sample, distance, 'swipe' if distance > 40 else 'drag', 600 if distance > 40 else 200)
            sample = self.observe(f'return-top-{index + 1}')
            if sample['titleVisible']:
                require(abs(sample.get('offsetPx', math.inf)) <= 2 and sample['cardPx'] == self.top['cardPx'] and
                        sample['titleBarPx'] == self.top['titleBarPx'], 'The title appeared before the original page top')
                events = self.logs()
                require(len(events) == 2 and events[0]['hidden'] and not events[1]['hidden'] and
                        abs(events[1]['offsetVp']) <= .5, 'The second native transition is not the actual Scroll origin')
                self.ui.private_shot('title-restored-at-origin')
                self.check(True, 'Only the actual Scroll origin restores the original native title and card geometry')
                return sample
        require(False, 'The measured top and title did not return in bounded gestures')

    def main(self):
        self.device_binding()
        self.baseline = self.ledger()
        self.baseline_facts = self.facts()
        auth = self.request(False, FRAME.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str) and auth['token'],
                'Host authentication did not identify the dedicated long choice actor')
        self.token = auth['token']
        self.dto = self.snapshot()
        question, _ = self.question()
        require(len(question['options']) >= 3 and any(option.get('imageUrl') for option in question['options']),
                'The guarded reference does not expose the original long choice content')
        self.immutable()
        self.stage = 'native-open-long-choice'
        self.ui.launch(cold=True)
        self.device_started = True
        pids = self.ui.run('hdc', 'shell', 'pidof', 'com.sitkin.starward').split()
        require(len(pids) == 1 and re.fullmatch(r'[1-9][0-9]*', pids[0]), 'A unique own cold App process is required')
        self.pid = pids[0]
        self.ui.wait(lambda ui: ui.find('account') is not None, 'empty isolated login')
        require(self.ui.input_empty('account') and self.ui.input_empty('password') and
                self.ui.has_text('隔离测试环境'), 'The own isolated login is not empty')
        self.ui.fill('account', self.case['account'])
        self.ui.fill('password', self.case['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'same-actor native home')
        self.ui.tap('assignment-' + self.assignment_id)
        self.ui.wait(lambda ui: ui.find(CARD) is not None and ui.find('gameplay-loading') is None and
                     ui.find(TITLE) is not None, 'active long choice and native title')
        self.ui.gameplay_foreground = True
        self.top = self.observe('natural-top', shot=True)
        require(self.top['titleVisible'] and self.top['titleBarPx'] and self.top['cardPx'] and self.top['numberPx'] and
                6 <= (self.top['cardPx'][1] - self.top['titleBarPx'][3]) / self.ui.density <= 32 and not self.logs(),
                'The natural top, meaningful card gap and fresh title trace were not observed')
        before = self.verify_ledger()
        restored = self.restore(self.reverse_and_bottom(self.collapse()))
        require(self.verify_ledger() == before, 'Ordinary scroll unexpectedly issued a real detail GET')
        self.cleanup['ordinaryScrollReadOnly'] = True
        if self.args.refresh:
            self.stage = 'explicit-top-pull-refresh'
            self.gesture(restored, 160, 'swipe', 600)
            deadline = time.monotonic() + 12
            while time.monotonic() < deadline:
                ready = [row for row in self.ledger()[len(self.baseline):] if row.get('method') == 'GET' and
                         row.get('path') == self.detail and row.get('status') == 200]
                if len(ready) > before:
                    break
                time.sleep(.25)
            require(self.verify_ledger() == before + 1, 'Explicit pull did not issue exactly one real detail GET')
            sample = self.observe('top-title-after-real-refresh', shot=True)
            require(sample['titleVisible'] and abs(sample.get('offsetPx', math.inf)) <= 2,
                    'The top title did not remain visible after real refresh')
            self.check(True, 'Explicit pull at the restored top performs one real detail GET without changing progress')

    def execute(self):
        try:
            self.main()
        except Exception as error:
            safe = str(error) if isinstance(error, FRAME.SafeFailure) else type(error).__name__
            FRAME.write_private(self.directory / 'failure-diagnostic.json', {'stage': self.stage, 'reason': safe},
                                (self.case['newPassword'], self.state['controlToken'], self.token))
            self.failure = 'An exact native title observation remains incomplete'
        finally:
            try:
                self.immutable()
                if self.device_started:
                    self.device_binding()
                    if self.ui.gameplay_foreground:
                        self.ui.capture()
                        self.ui.back()
                        self.ui.gameplay_foreground = False
                        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'own home after leaving long choice')
                    self.logout()
                if self.baseline is not None:
                    self.verify_ledger()
            except Exception:
                self.failure = self.failure or 'Exact cleanup or zero-write facts remain incomplete'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
        self.save()
        return int(self.failure is not None)

    def save(self):
        result = {'status': 'incomplete' if self.failure else 'captured_native_gameplay_header',
                  'stage': self.stage, 'failure': self.failure, 'scope': 'Existing long choice case, exact no-write title behavior',
                  'checks': self.checks, 'checksPassed': len(self.checks), 'states': self.states, 'headerTransitions': self.trace,
                  'cleanup': self.cleanup, 'hapSha256': self.hap_sha, 'bindingSha256': self.binding,
                  'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
                  'statusBarVisualReview': 'pending_original_review', 'fixedPreviewTouched': False}
        encoded = json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        private = (self.serial, self.case_id, self.case['account'], self.case['playerId'], self.assignment_id,
                   self.case['newPassword'], self.token, self.state['controlToken'])
        require(not any(value and value in encoded for value in private) and not re.search(r'https?://', encoded),
                'A private literal would enter the header report')
        FRAME.fresh(self.report, OUT)
        self.report.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream:
            stream.write(encoded)
        print(json.dumps({'status': result['status'], 'checksPassed': len(self.checks),
                          'report': str(self.report.relative_to(ROOT))}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    run = parser.add_subparsers(dest='action').add_parser('run')
    for name in ('runtime', 'case-ref', 'device-ref', 'output', 'private-dir'):
        run.add_argument('--' + name, type=Path, required=True)
    run.add_argument('--expected-hap', required=True)
    run.add_argument('--refresh', action='store_true')
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return HeaderSample(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Exact long-case, HAP, runtime, owner or output guards failed'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

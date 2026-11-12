#!/usr/bin/env python3
"""Read-only straight-phone acceptance for a pre-settled clue link actor.

The operator measures inline Span taps from private screenshots because UiTest
may expose a paragraph as one Text node. Only guarded app and system Back taps
are sent. No fixture provisioning, gameplay submissions or preview operations.
"""
import argparse
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import re
import sys
import time

from native_device_ui import ROOT, SafeFailure, flatten

SPEC = spec_from_file_location('inline_clue_combination', ROOT / 'scripts/device-gameplay-combination-clues.py')
C = module_from_spec(SPEC)
SPEC.loader.exec_module(C)
D, ENTRY, FRAME, UI, require, sha = C.D, C.ENTRY, C.FRAME, C.UI, C.require, C.sha
OUT = FRAME.VALIDATION / 'ui-gameplay-clue-links-20261112'
PRIVATE = FRAME.PRIVATE / 'gameplay-links-20261112'
APP = 'com.sitkin.starward'
HANDLER = re.compile(r'browser|autonavi|amap|huawei[.].*map', re.I)


class ClueLinks(D.OrdinaryClues):
    def __init__(self, args):
        FRAME.fresh(args.output, OUT)
        require(re.fullmatch(r'[a-f0-9]{64}', args.expected_hap), 'The reviewed signed HAP hash is required')
        ENTRY.PRIVATE = FRAME.PRIVATE
        args.case_ref = ENTRY.guarded(args.fixture, PRIVATE, True)
        args.delay_ms = 10000
        ENTRY.EntryMain.__init__(self, args)
        self.fixture = json.loads(self.reference_path.read_text())
        self.combination = args.kind == 'combination'
        role, case_label = ('web', 'clue-links-web') if self.combination else ('phone', 'clue-links-phone')
        assignment = self.fixture.get('assignmentId', '')
        registered = {row.get('assignmentId') for case in self.state['gameplay']['cases'].values()
                      for row in case.get('assignments', {}).values()}
        require(self.case.get('label') == case_label and self.fixture.get('usage') == role and
                self.fixture.get('formatVersion') == 1 and self.fixture.get('status') == 'verified_ready' and
                self.fixture.get('controlIdentitySha256') == C.hashlib.sha256(self.state['controlToken'].encode()).hexdigest() and
                self.fixture.get('playerSha256') == C.hashlib.sha256(self.case['playerId'].encode()).hexdigest() and
                C.ID.fullmatch(assignment) and C.ID.fullmatch(self.fixture.get('sessionId', '')) and
                assignment != self.state['assignmentId'] and assignment not in registered,
                'The owned pre-settled link assignment is not bound to the isolated actor')
        self.assignment_id = assignment
        self.ids.add(assignment)
        self.detail = ENTRY.BASE + '/' + assignment
        self.expected, self.titles = self.fixture['expected'], self.fixture['titles']
        device_path = ENTRY.guarded(args.device_ref, FRAME.PRIVATE, True)
        device = json.loads(device_path.read_text())
        self.serial = device.get('deviceSerial', '')
        require(set(device) == {'deviceSerial'} and re.fullmatch(r'[A-Za-z0-9]{8,80}', self.serial),
                'The exact private USB device receipt is required')
        self.ui = C.CombinationUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
                                   'controlToken': self.state['controlToken']}, self.ui.density, self.directory,
                                  side_panel=True)
        self.ui.serial = self.serial
        self.bound.update({'driver': Path(__file__), 'combinationDriver': Path(C.__file__),
                           'ordinaryDriver': Path(D.__file__), 'deviceReference': device_path})
        app = ROOT / 'entry/src/main/ets'
        for name in ('features/GameplayPage.ets', 'features/GameplayViewModel.ets', 'pages/Index.ets',
                     'platform/ExternalClueLink.ets', 'business/GameplayClues.ets',
                     'ui/StarwardClueParagraph.ets', 'ui/StarwardClueTextDialog.ets', 'ui/StarwardCombinationDialog.ets'):
            self.bound[Path(name).stem] = app / name
        self.binding = {key: sha(path) for key, path in self.bound.items()}
        self.births = self.owners()
        self.baseline, self.initial_facts, self.pending_handler = None, None, None
        self.states, self.fixtures, self.levels = [], {}, []
        self.theme_overridden = False
        self.cleanup.pop('faultNeutralised')
        self.cleanup.update(zeroUnexpectedWrites=False, appThemeRestored=True)
        self.observations['window'] = {key: value for key, value in json.loads(self.runtime_path.read_text())['window'].items()
                                       if key in ('widthPx', 'heightPx', 'density', 'fontScale')}
        self.dialog, self.title, self.paragraph = ((C.DIALOG, C.TITLE, 'gameplay-combination-paragraph-0') if self.combination else
                                                  (D.DIALOG, D.DIALOG_TITLE, 'gameplay-clue-paragraph-0'))
        self.expected_title = self.expected['combinationTitle' if self.combination else 'ordinaryTitle']

    def ledger(self, exact=True):
        rows = self.requests()
        require(rows[:len(self.baseline)] == self.baseline, 'The settled fixture request prefix changed')
        added = rows[len(self.baseline):]
        require(all(((r.get('method') == 'GET' and r.get('path') in ('/api/health', D.ME, ENTRY.BASE, self.detail)) or
                     (r.get('method') == 'POST' and r.get('path') == ENTRY.AUTH)) and r.get('status') == 200 and
                    r.get('fault') is False and not r.get('responseDropped') and not r.get('responseAwaitingDelay')
                    for r in added), 'The owned ledger contains an unexpected route, write, or fault')
        self.observations['businessWrites'] = {'starts': 0, 'answers': 0}
        return added

    def facts(self):
        detail, player = self.snapshot(), self.host_read(D.ME)
        done = 2 if self.combination else 1
        require(detail.get('status') == ('completed' if self.combination else 'active') and
                detail.get('totalLevels') == 2 and detail.get('completedLevels') == done and
                detail.get('currentIndex') == 1 and detail.get('startedAt') and
                player.get('id') == self.case['playerId'] and player.get('totalXp') == done * 50 and
                player.get('mustChangePassword') is False and
                [level['question']['title'] for level in detail['levels']] == [self.titles['first'], self.titles['second']],
                'The real read-only actor, XP, or question settlement differs from the fixture')
        ordinary = (self.expected['ordinaryTitle'], self.expected['ordinaryText'], 'start')
        combination = (self.expected['combinationTitle'], self.expected['combinationText'], 'session_completed')
        require([(clue['content']['title'], clue['content']['text'], clue['trigger']) for clue in detail['clues']] ==
                ([ordinary, combination] if self.combination else [ordinary]) and all(
                    clue.get('kind') == 'text' and clue.get('source') == 'session' and not clue.get('sessionLevel')
                    for clue in detail['clues']), 'The real clue grants do not match the reviewed exact bodies')
        self.levels = [level['id'] for level in detail['levels']]
        return detail, (detail['startedAt'], detail.get('completedAt'), player['totalXp'],
                        tuple(level.get('completedAt') for level in detail['levels']))

    def focus(self):
        windows, _ = self.ui.windows()
        candidates = [row for row in windows if row.get('focused') is True and row.get('displayId') == 0]
        require(len(candidates) == 1 and type(candidates[0].get('pid')) is int,
                'The official primary-display foreground window could not be uniquely identified')
        return candidates[0]

    def app_pid(self):
        raw = self.ui.run('hdc', 'shell', 'pidof', APP).split()
        require(len(raw) == 1 and re.fullmatch(r'[1-9][0-9]*', raw[0]), 'The own App PID is unavailable')
        return int(raw[0])

    def handler_process(self, window):
        # Some window names are simply MainAbility. Resolve only its actual PID.
        if HANDLER.search(str(window.get('name', ''))):
            return str(window['name'])
        for line in self.ui.run('hdc', 'shell', 'ps', '-A').splitlines():
            columns = line.split()
            if len(columns) > 2 and columns[1] == str(window['pid']) and HANDLER.search(columns[-1]):
                return columns[-1]
        return None

    def check(self, value, label):
        require(value, label)
        self.checks.append(label)
        print(json.dumps({'checksPassed': len(self.checks), 'passed': label}), flush=True)

    def wait_dialog(self):
        self.ui.wait(lambda ui: ui.find(self.dialog) and ui.find(self.title) and
                     ui.find(self.title).get('text') == self.expected_title and ui.find(self.paragraph),
                     'the exact authorized clue dialog')

    def measure(self, name, *, screenshot=False):
        self.wait_dialog()
        rows, source = self.ui.raw_app(name)
        keys = (self.dialog, self.paragraph, self.title)
        result = {}
        for key in keys:
            nodes = [node for node in rows if key in (node.get('id'), node.get('key')) and UI.exposed(node)]
            require(len(nodes) == 1, 'A unique actual visible dialog control is missing')
            item = nodes[0]
            identity = (item.get('accessibilityId'), item.get('hashcode'))
            require(all(type(value) in (int, str) and bool(value) for value in identity),
                    'Official UiTest did not expose actual control instance identities')
            result[key] = (UI.rect(item['bounds']), identity, item.get('text', ''))
        record = {'state': name, 'rawSha256': source['sha256'],
                  'geometryPx': {key: result[key][0] for key in keys}}
        self.states.append(record)
        if screenshot:
            self.ui.private_shot(name)
            record['privateOriginal'] = self.ui.private_screenshots[-1]
        return result, record

    def point(self, label, before, record):
        bounds = before[self.paragraph][0]
        print(json.dumps({'input': 'Enter x y in original screenshot pixels for the indicated text',
                          'target': label, 'privateOriginal': record['privateOriginal']['file'],
                          'paragraphBoundsPx': bounds}), flush=True)
        value = input().strip()
        require(re.fullmatch(r'[0-9]{1,5}\s+[0-9]{1,5}', value), 'A measured inline text point is required')
        x, y = map(int, value.split())
        require(bounds[0] < x < bounds[2] and bounds[1] < y < bounds[3] and
                self.focus()['pid'] == self.app_pid(), 'The measured point is outside the focused own clue paragraph')
        self.wait_dialog()
        require(UI.rect(self.ui.find(self.paragraph)['bounds']) == bounds,
                'The visible paragraph moved after the original measurement')
        record['tapPx'] = [x, y]
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', x, y)

    def wait_for_get(self, checkpoint):
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            reads = [row for row in self.requests()[checkpoint:] if row.get('path') == self.detail and row.get('method') == 'GET']
            require(len(reads) <= 1, 'A single foreground return made repeated assignment reads')
            if reads and reads[0].get('status') == 200 and reads[0].get('authenticated') is True and reads[0].get('bearer') is False:
                return
            time.sleep(.2)
        raise SafeFailure('The foreground return did not make its authorized HTTPS detail GET')

    def tap_inert(self, target):
        before, state = self.measure('before-' + target, screenshot=True)
        own_pid = self.app_pid()
        checkpoint = len(self.requests())
        self.point(target, before, state)
        for _ in range(3):
            time.sleep(.3)
            require(self.focus()['pid'] == own_pid, 'A non-link tap unexpectedly left the owning App')
        after, _ = self.measure('after-' + target)
        require(before == after and len(self.requests()) == checkpoint,
                'A non-link tap changed the visible dialog, control identity, or backend traffic')
        self.check(True, 'No handoff or gameplay request for ' + target)

    def tap_external(self, target):
        before, state = self.measure('before-' + target, screenshot=True)
        checkpoint = len(self.requests())
        own_pid = self.app_pid()
        self.point(target, before, state)
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            window = self.focus()
            if window['pid'] != own_pid:
                handler = self.handler_process(window)
                require(handler, 'An unrecognized window became focused after the link tap; no input was sent to it')
                self.pending_handler = window['pid']
                state['systemHandlerObserved'] = 'browser' if 'browser' in handler.lower() else 'associated-map-app'
                break
            time.sleep(.25)
        require(self.pending_handler is not None, 'The measured inline tap did not focus an external link handler')
        back_presses = self.return_from_handler(own_pid)
        self.wait_for_get(checkpoint)
        after, _ = self.measure('after-' + target, screenshot=True)
        require(before == after and self.app_pid() == own_pid,
                'System Back changed the original dialog identity, visible text, or reading geometry')
        state['systemBackPresses'] = back_presses
        self.check(True, 'System handoff and Back retain the exact dialog and visible reading position for ' + target)

    def return_from_handler(self, own_pid):
        for number in range(1, 4):
            window = self.focus()
            if window['pid'] == own_pid:
                self.pending_handler = None
                return number - 1
            require(window['pid'] == self.pending_handler and self.handler_process(window),
                    'The recognized external handler lost focus; further Back input was stopped')
            self.ui.back()
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                if self.focus()['pid'] == own_pid:
                    self.pending_handler = None
                    return number
                time.sleep(.15)
        raise SafeFailure('System Back did not return to the same running Starward App')

    def login(self):
        self.ui.launch(cold=True)
        self.device_started = True
        self.ui.wait(lambda ui: ui.find('account') and ui.input_empty('account') and ui.input_empty('password') and
                     ui.has_text('隔离测试环境'), 'an empty owned isolated login')
        self.ui.fill('account', self.case['account'])
        self.ui.fill('password', self.case['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') and not ui.find('old-password'), 'direct isolated home')

    def open_assignment(self):
        if self.combination:
            self.ui.tap('history-tab')
        self.ui.tap('assignment-' + self.assignment_id)
        self.ui.gameplay_foreground = True
        self.wait_title('second')

    def ordinary_checks(self):
        self.ui.fill(D.ANSWER, self.expected['draft'])
        self.ui.tap_question_number(0)
        self.wait_title('first')
        self.ui.tap(D.CLUE + '0')
        self.wait_dialog()
        self.tap_inert('plain-neighbor-text')
        self.tap_inert('blocked-scheme-label')
        self.tap_external('safe-browser-link')
        self.ui.tap_observed(D.DIALOG_CLOSE)
        self.ui.tap_question_number(1)
        self.wait_title('second')
        self.ui.seek(D.ANSWER)
        require(self.ui.find(D.ANSWER).get('text') == self.expected['draft'], 'The Q2 draft did not survive clue link return')
        self.check(True, 'The exact unsubmitted draft survives reading a clue from the previous completed question')
        self.ui.tap_question_number(0)
        self.wait_title('first')
        self.ui.tap(D.CLUE + '0')
        self.wait_dialog()
        checkpoint = len(self.requests())
        own_pid = self.app_pid()
        require(self.focus()['pid'] == own_pid, 'Normal background check must start at the own clue')
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', 'Home')
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline and self.focus()['pid'] == own_pid:
            time.sleep(.15)
        require(self.focus()['pid'] != own_pid, 'The normal background transition did not leave the App')
        self.ui.launch()
        self.wait_for_get(checkpoint)
        self.wait_title('first')
        require(not self.ui.find(self.dialog), 'Normal background unexpectedly retained the clue')
        self.check(True, 'A normal Home transition closes the clue and keeps the previous question on return')

    def main(self):
        self.stage = 'verify-owned-settled-fixture'
        self.device_binding()
        self.baseline = self.requests()
        C.CombinationClues.authenticate_host(self)
        detail, self.initial_facts = self.facts()
        self.save_fixture(self.args.kind + '-same-data', detail)
        self.stage = 'native-login-and-open-assignment'
        self.login()
        self.theme(self.args.theme)
        self.open_assignment()
        self.stage = 'actual-native-link-taps'
        if self.combination:
            self.ui.tap_observed(C.LAUNCHER)
            self.wait_dialog()
            self.tap_external('authored-combination-link')
            self.ui.tap_observed(C.ACK)
            self.ui.wait(lambda ui: ui.find(C.LAUNCHER) and not ui.find(C.DIALOG), 'closed combination clue and launcher')
        else:
            self.ordinary_checks()

    def logout(self):
        if self.pending_handler is not None:
            self.return_from_handler(self.app_pid())
        C.CombinationClues.logout(self)

    def execute(self):
        try:
            self.main()
        except (Exception, KeyboardInterrupt) as error:
            self.failure = self.safe_failure(error)
        finally:
            try:
                self.immutable()
                require(self.owners() == self.births, 'The exact isolated environment owners changed')
                if self.device_started:
                    self.device_binding()
                    self.logout()
            except Exception as error:
                self.failure = self.failure or self.safe_failure(error)
            try:
                if self.baseline is not None:
                    self.ledger()
                    if self.initial_facts is not None:
                        require(self.facts()[1] == self.initial_facts, 'Authoritative timestamps or XP changed during link acceptance')
                        self.ledger()
                    self.cleanup['zeroUnexpectedWrites'] = True
            except Exception as error:
                self.failure = self.failure or self.safe_failure(error)
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not all(self.cleanup.values()):
                self.failure = self.failure or 'Owned native cleanup remains incomplete'
        self.save('incomplete' if self.failure else 'captured_native_clue_links')
        return int(self.failure is not None)

    def save(self, status):
        report = {'status': status, 'stage': self.stage, 'scope': self.args.kind, 'theme': self.args.theme,
                  'hapSha256': self.hap_sha, 'bindingSha256': self.binding, 'checksPassed': len(self.checks),
                  'checks': self.checks, 'states': self.states, 'observations': self.observations, 'cleanup': self.cleanup,
                  'sameDataWebFixtures': self.fixtures, 'privateScreenshots': self.ui.private_screenshots,
                  'privateRawEvidence': self.ui.raw_evidence, 'visualReview': 'pending_original_review',
                  'fixedPreviewTouched': False, 'failure': self.failure}
        content = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        require(not any(value and value in content for value in (*self.secrets(), self.serial,
                    self.fixture['sessionId'], *self.levels)) and not re.search(r'https?://', content),
                'A private literal would enter the public link report')
        FRAME.fresh(self.report, OUT)
        self.report.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
        print(json.dumps({'status': status, 'checksPassed': len(self.checks),
                          'report': str(self.report.relative_to(ROOT))}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    run = parser.add_subparsers(dest='action').add_parser('run')
    for name in ('runtime', 'fixture', 'device-ref', 'output'):
        run.add_argument('--' + name, type=Path, required=True)
    run.add_argument('--expected-hap', required=True)
    run.add_argument('--kind', choices=('ordinary', 'combination'), required=True)
    run.add_argument('--theme', choices=('light', 'dark'), required=True)
    args = parser.parse_args()
    if args.action is None:
        parser.print_help()
        return 0
    try:
        return ClueLinks(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Exact clue-link fixture, package, runtime, owner or output guards failed'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

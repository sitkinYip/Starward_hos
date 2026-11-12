#!/usr/bin/env python3
"""Exercise the native combination clue sequence on one disposable HTTPS case."""
import argparse
import hashlib
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import re
import sys
import time

from native_device_ui import ROOT, SafeFailure, flatten

SPEC = spec_from_file_location('combination_ordinary_driver', ROOT / 'scripts/device-gameplay-ordinary-clues.py')
D = module_from_spec(SPEC)
SPEC.loader.exec_module(D)
ENTRY, FRAME, UI, require, sha = D.ENTRY, D.FRAME, D.UI, D.require, D.sha

OUT = FRAME.VALIDATION / 'ui-gameplay-combination-20261112'
CASE_LABEL = 'combination-clues-phone'
NEGATIVE_CASE_LABEL = 'combination-clues-negative'
LAUNCHER = 'gameplay-combination-launcher'
DIALOG = 'gameplay-combination-dialog'
TITLE = 'gameplay-combination-title'
CONTENT = 'gameplay-combination-content'
DESCRIPTION = 'gameplay-combination-description'
ACK = 'gameplay-combination-ack'
COMPLETION_ACK = '查看组合结果'
LAUNCHER_LABEL = '查看本场线索'
ID = re.compile(r'[a-z0-9]{15}')


class CombinationUI(D.ClueUI):
    @staticmethod
    def layout_node(raw):
        def visible_tree(node):
            if node.get('attributes', {}).get('visible') in ('false', False):
                return None
            children = [visible_tree(child) for child in node.get('children', [])]
            return {**node, 'children': [child for child in children if child is not None]}

        visible = visible_tree(raw)
        return D.ClueUI.layout_node(visible) if visible is not None else None

    def capture(self, name=None):
        require(name in (None, 'failure-last-view'), 'Use private evidence for combination clue captures')
        self.tree, self.flat, self.width, self.height = None, [], 0, 0
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            tree = [root for root in self.live_layout() if root is not None]
            flat = flatten(tree)
            for root in tree:
                if root.get('type') != 'root' or not root.get('bounds') or not UI.positive(root['bounds']):
                    continue
                if any(node.get('id') in (D.PAGE, D.DIALOG, DIALOG, D.VIEWER, 'account', 'account-menu', 'start-assignment')
                       or node.get('text') == D.COMPLETION_TITLE for node in flatten(root)):
                    self.tree, self.flat = tree, flat
                    left, top, right, bottom = root['bounds']
                    self.width, self.height = right - left, bottom - top
                    return flat
            time.sleep(.2)
        raise SafeFailure('The own gameplay window or combination dialog was not in foreground')

    def mask_point(self):
        self.capture()
        panel = self.find(DIALOG)
        require(panel and panel.get('bounds'), 'The actual combination dialog is required for a mask test')
        roots = [row for row in self.flat if row.get('type') == 'root' and row.get('bounds') and
                 any(node is panel for node in flatten(row))]
        require(len(roots) == 1, 'The combination dialog does not have a unique owning window')
        root, box = roots[0]['bounds'], panel['bounds']
        require(UI.positive(box) and UI.inside(box, root), 'Combination panel is outside its actual owning window')
        start, end = max(((root[1], box[1]), (box[3], root[3])), key=lambda span: span[1] - span[0])
        require(end - start >= 48 * self.density, 'The actual mask has no safe touch target')
        return (root[0] + root[2]) // 2, (start + end) // 2

    def swipe(self, direction):
        self.capture()
        launcher = self.find(LAUNCHER)
        if launcher is None:
            return super().swipe(direction)
        left, top, right, bottom = self.viewport()
        require(right - left >= 80 and bottom - top >= 150, 'The current question Scroll is too small to survey')
        box = launcher['bounds']
        points = (round(left + .22 * (right - left)), round(left + .78 * (right - left)))
        candidates = [x for x in points if x < box[0] - 4 or x > box[2] + 4]
        require(candidates, 'The completed question has no vertical gesture lane beside the launcher')
        a, b = round(top + .32 * (bottom - top)), round(top + .72 * (bottom - top))
        start, end = (b, a) if direction == 'down' else (a, b)
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'swipe', candidates[0], start, candidates[0], end)


class CombinationClues(D.OrdinaryClues):
    def __init__(self, args):
        FRAME.fresh(args.output, OUT)
        require(re.fullmatch(r'[a-f0-9]{64}', args.expected_hap), 'An exact signed HAP SHA256 is required')
        ENTRY.guarded(args.fixture, FRAME.PRIVATE / 'ui-reference', True)
        ENTRY.PRIVATE = FRAME.PRIVATE
        args.case_ref, args.delay_ms = args.fixture, 10000
        ENTRY.EntryMain.__init__(self, args)
        self.fixture = json.loads(self.reference_path.read_text())
        self.negative = args.action == 'run-negative'
        target = self.fixture.get('assignmentId', '')
        other_assignments = {row.get('assignmentId') for case_id, case in self.state['gameplay']['cases'].items()
                             if case_id != self.case_id for row in case.get('assignments', {}).values()}
        require(self.case.get('label') == (NEGATIVE_CASE_LABEL if self.negative else CASE_LABEL) and
                self.fixture.get('formatVersion') == 1 and
                self.fixture.get('usage') == ('negative' if self.negative else 'phone') and
                self.fixture.get('status') == 'verified_ready' and
                self.fixture.get('controlIdentitySha256') == hashlib.sha256(self.state['controlToken'].encode()).hexdigest() and
                self.fixture.get('playerSha256') == hashlib.sha256(self.case['playerId'].encode()).hexdigest() and
                self.case['playerId'] not in (self.state['playerId'], self.state.get('otherPlayerId')) and
                ID.fullmatch(self.fixture.get('sessionId', '')) and ID.fullmatch(target) and
                target != self.state['assignmentId'] and target not in other_assignments,
                'Use the exact newly prepared disposable combination clue assignment')
        self.assignment_id = target
        self.ids.add(target)
        self.detail = ENTRY.BASE + '/' + target
        self.start, self.answer_path = self.detail + '/start', self.detail + '/answers'
        self.registered_assignment = target == self.case['assignments']['ready']['assignmentId']
        self.titles, self.answers_input, self.expected = (self.fixture[key] for key in ('titles', 'answers', 'expected'))
        self.xp_per_correct = self.fixture['xpPerCorrect']
        self.validate_fixture_content()

        device_path = ENTRY.guarded(args.device_ref, FRAME.PRIVATE, True)
        device = json.loads(device_path.read_text())
        self.serial = device.get('deviceSerial', '')
        require(set(device) == {'deviceSerial'} and re.fullmatch(r'[A-Za-z0-9]{8,80}', self.serial),
                'A reviewed private USB straight-phone receipt is required')
        self.ui = CombinationUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
                                 'controlToken': self.state['controlToken']}, self.ui.density, self.directory,
                                side_panel=True)
        self.ui.serial = self.serial
        app = ROOT / 'entry/src/main/ets'
        self.bound.update({'combinationDriver': Path(__file__), 'ordinaryDriver': Path(D.__file__),
                           'navigationDriver': Path(D.NAV.__file__), 'deviceReference': device_path,
                           'page': app / 'features/GameplayPage.ets', 'playModel': app / 'features/GameplayViewModel.ets',
                           'selection': app / 'business/GameplayClues.ets'})
        for folder in ('business', 'ui'):
            for path in sorted((app / folder).glob('*Combination*.ets')):
                self.bound[path.stem] = path
        self.binding = {name: sha(path) for name, path in self.bound.items()}
        self.baseline, self.allowed_starts, self.allowed_answers, self.levels = None, 0, 0, []
        self.states, self.fixtures = [], {}
        self.negative_initial = None
        self.theme_overridden = False
        self.cleanup.pop('faultNeutralised')
        self.cleanup.update(zeroUnexpectedWrites=False, appThemeRestored=True)
        window = json.loads(self.runtime_path.read_text())['window']
        self.observations['window'] = {key: window[key] for key in ('widthPx', 'heightPx', 'density', 'fontScale')}
        self.births = self.owners()

    def validate_fixture_content(self):
        def filled(value):
            return isinstance(value, str) and bool(value.strip())

        require(type(self.xp_per_correct) is int and self.xp_per_correct > 0 and
                all(filled(self.titles.get(key)) for key in ('session', 'first', 'second')) and
                all(filled(self.answers_input.get(key)) for key in ('first', 'second')) and
                self.answers_input['first'] != self.answers_input['second'],
                'The fixture must contain two exact distinct correct text answers')
        rows = self.expected.get('combinations')
        require(isinstance(rows, list) and len(rows) == (0 if self.negative else 2) and all(
            all(isinstance(row.get(key), str) for key in ('title', 'description', 'buttonText')) and
            all(filled(row.get(key)) for key in ('body', 'displayTitle', 'displayDescription', 'displayButtonText')) and
            type(row.get('position')) is int and type(row.get('autoPlay')) is bool and
            isinstance(row.get('bodyFragments'), list) and row['bodyFragments'] and
            all(filled(fragment) for fragment in row['bodyFragments']) for row in rows) and
            (self.negative or rows[0]['displayTitle'] != rows[1]['displayTitle']),
            'The fixture requires the exact positive or negative set of combinations')
        for key in ('ordinaryTitles', 'secondOrdinaryTitles'):
            ordinary = self.expected.get(key)
            require(isinstance(ordinary, list) and ordinary and all(filled(item) for item in ordinary),
                    'The fixture requires ordinary-clue exclusion controls')

    def authoritative(self, dto, complete):
        combos = [row for row in dto['clues'] if row.get('source', 'session') == 'session' and
                  row.get('trigger') == 'session_completed' and not row.get('sessionLevel') and row.get('kind') == 'text']
        combos.sort(key=lambda row: (row['position'], row.get('definitionId') or row['id'], row['id']))
        if not complete:
            require(dto['status'] != 'completed' and not combos, 'The backend released a combination before completion')
            return
        require(dto['status'] == 'completed' and dto.get('totalLevels') == 2 and dto.get('completedLevels') == 2 and
                all(level.get('completedAt') for level in dto['levels']), 'The backend did not settle the completed case')
        require(len(combos) == len(self.expected['combinations']) and all(
            actual['content'].get('title', '') == target['title'] and actual['content'].get('text') == target['body'] and
            actual['content'].get('description', '') == target['description'] and
            actual['content'].get('buttonText', '') == target['buttonText'] and
            actual.get('position') == target['position'] and actual.get('autoPlay') is target['autoPlay']
            for actual, target in zip(combos, self.expected['combinations'])),
            'The actual authorized combination texts or their stable order differ from the fixture')
        ordinary = {row['content'].get('title') for row in dto['clues'] if row not in combos}
        require(set(self.expected['ordinaryTitles']).issubset(ordinary),
                'The ordinary exclusion controls are not present in the real completed DTO')

    def observe(self, label, *ids):
        rows, evidence = self.ui.raw_app(label)
        rectangles = {}
        for key in ids:
            nodes = [row for row in rows if row.get('id') == key and UI.exposed(row)]
            require(len(nodes) == 1, 'A required visible control was not unique in the official UiTest tree: ' + key)
            rectangles[key] = UI.rect(nodes[0]['bounds'])
        self.ui.private_shot(label)
        self.states.append({'state': label, 'rawSha256': evidence['sha256'], 'geometryPx': rectangles})
        return rectangles

    def no_combination_in_page(self, label, launcher=False, second_ordinary_only=False):
        titles = [row['displayTitle'] for row in self.expected['combinations']]
        previous = None
        for _ in range(12):
            self.ui.capture()
            require(self.ui.find(D.PAGE) and not self.ui.find(DIALOG) and not self.ui.has_text(D.COMPLETION_TITLE) and
                    bool(self.ui.find(LAUNCHER)) == launcher and not any(self.ui.has_text(title) for title in titles),
                    'A combination was unexpectedly exposed in the question or overlay')
            if second_ordinary_only:
                require(not self.ui.find(D.CLUE + str(len(self.expected['secondOrdinaryTitles']))),
                        'An extra clue was exposed in the completed second question archive')
            fingerprint = self.ui.visible_fingerprint()
            if fingerprint == previous:
                self.observe(label, *([LAUNCHER] if launcher else []))
                return
            previous = fingerprint
            self.ui.swipe('down')
        raise SafeFailure('The actual question bottom was not reached during the combination visibility survey')

    def verify_second_ordinary_archive(self):
        for index, title in enumerate(self.expected['secondOrdinaryTitles']):
            self.ui.seek(D.CLUE + str(index))
            require(self.contained_title(self.ui.find('gameplay-clue-title-' + str(index)), title),
                    'The second question ordinary archive is not intact in its authoritative order')

    def dialog_matches(self, ui, expected):
        content = ui.find(CONTENT)
        if not (ui.find(DIALOG) and ui.find(TITLE) and content and ui.find(DESCRIPTION) and ui.find(ACK)):
            return False
        body = ''.join(str(row.get('text', '')) for row in flatten(content))
        return (ui.find(TITLE).get('text') == expected['displayTitle'] and
                self.contained_title(ui.find(DESCRIPTION), expected['displayDescription']) and
                self.contained_title(ui.find(ACK), expected['displayButtonText']) and
                all(fragment in body for fragment in expected['bodyFragments']))

    def wait_dialog(self, index):
        expected = self.expected['combinations'][index]
        self.ui.wait(lambda ui: self.dialog_matches(ui, expected), 'exact ordered combination dialog', timeout=25)
        require(not self.ui.find(LAUNCHER) and not self.ui.has_text(D.COMPLETION_TITLE) and
                not any(self.ui.has_text(title) and self.contained_title(self.ui.find(CONTENT), title)
                        for title in self.expected['ordinaryTitles']),
                'The launcher, completion acknowledgement or an ordinary clue overlapped the combination')

    def wait_launcher(self):
        self.ui.wait(lambda ui: ui.find(D.PAGE) and ui.find(LAUNCHER) and not ui.find(DIALOG) and
                     not ui.has_text(D.COMPLETION_TITLE), 'the completed launcher without a modal', timeout=25)
        node = self.ui.find(LAUNCHER)
        require(self.contained_title(node, LAUNCHER_LABEL) or node.get('description') == LAUNCHER_LABEL,
                'The visible completed launcher does not carry its public label')
        return node['bounds']

    def drag_launcher(self):
        before = self.wait_launcher()
        root = self.ui.app_rect()
        require(UI.inside(before, root), 'The launcher is outside its measured app viewport')
        cx, cy = (before[0] + before[2]) // 2, (before[1] + before[3]) // 2
        width, height = root[2] - root[0], root[3] - root[1]
        was_right = cx > root[0] + width / 2
        x = round(root[0] + width * (.20 if was_right else .80))
        y = max(round(root[1] + .22 * height), round(cy - .20 * height))
        require(abs(x - cx) >= .20 * width and abs(y - cy) >= 16 * self.ui.density,
                'The measured launcher position cannot produce a distinct in-viewport drag')
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'drag', cx, cy, x, y, 600)

        def moved(ui):
            node = ui.find(LAUNCHER)
            if node is None or ui.find(DIALOG):
                return False
            box = node['bounds']
            new_x = (box[0] + box[2]) / 2
            edge_gap = box[0] - root[0] if was_right else root[2] - box[2]
            return (UI.inside(box, root) and ((new_x < root[0] + width / 2) == was_right) and
                    edge_gap <= 30 * self.ui.density and abs(box[1] - before[1]) >= 16 * self.ui.density)
        self.ui.wait(moved, 'the launcher dragged without opening and snapped to the opposite edge', timeout=12)
        time.sleep(.3)
        after = self.observe('launcher-dragged', LAUNCHER)[LAUNCHER]
        self.observations['launcherDrag'] = {'beforePx': before, 'afterPx': after,
                                             'viewportPx': root, 'gesturePx': [cx, cy, x, y]}
        return after

    def login(self):
        self.device_started = True
        self.ui.launch(cold=True)
        self.ui.wait(lambda ui: ui.find('account'), 'empty isolated native login')
        require(self.ui.input_empty('account') and self.ui.input_empty('password') and
                self.ui.has_text('隔离测试环境'), 'The native login is not empty and isolated')
        self.ui.fill('account', self.case['account'])
        self.ui.fill('password', self.case['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') and not ui.find('old-password'), 'direct isolated native home')

    def logout(self):
        # A failed check can leave the completion acknowledgement or either
        # queued combination open. Back and acknowledgement are UI-only.
        for _ in range(4):
            self.ui.capture()
            if self.ui.find(DIALOG):
                self.ui.back()
            elif self.ui.has_text(D.COMPLETION_TITLE) and self.ui.has_text(COMPLETION_ACK):
                self.ui.tap_observed(text=COMPLETION_ACK)
            else:
                break
            time.sleep(.25)
        D.OrdinaryClues.logout(self)
        self.cleanup['privateGameplayAbsent'] = (self.cleanup['privateGameplayAbsent'] and
                                                not self.ui.find(DIALOG) and not self.ui.find(LAUNCHER))
        require(self.cleanup['privateGameplayAbsent'], 'Logout did not clear the private combination launcher and dialog')

    def authenticate_host(self):
        auth = self.host_read(ENTRY.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str) and
                auth['token'], 'Strict Host auth did not identify the exact disposable combination actor')
        self.token = auth['token']

    def negative_facts(self):
        player, detail = self.host_read(D.ME), self.snapshot()
        self.authoritative(detail, True)
        require(player.get('id') == self.case['playerId'] and player.get('mustChangePassword') is False and
                player.get('totalXp') == 2 * self.xp_per_correct, 'The negative actor settlement is not exact')
        self.levels = [row['id'] for row in detail['levels']]
        return (detail.get('startedAt'), detail.get('completedAt'),
                tuple(row.get('completedAt') for row in detail['levels']), player['totalXp'])

    def ledger(self, exact=True):
        if not self.negative:
            return super().ledger(exact)
        if self.negative_initial is not None:
            require(self.negative_facts() == self.negative_initial, 'Negative fixture timestamps or XP changed')
        rows = self.requests()
        require(rows[:len(self.baseline)] == self.baseline, 'The negative fixture request ledger prefix changed')
        added = rows[len(self.baseline):]
        require(all(((row['method'] == 'GET' and row['path'] in ('/api/health', D.ME, ENTRY.BASE, self.detail)) or
                    (row['method'] == 'POST' and row['path'] == ENTRY.AUTH)) and row['status'] == 200 and
                    row['fault'] is False and not row.get('responseDropped') and not row.get('responseAwaitingDelay')
                    for row in added), 'Negative verification made an unexpected request, write or fault')
        self.observations['businessWrites'] = {'starts': 0, 'answers': 0}
        return added

    def require_history_get(self, checkpoint):
        require(any(row['method'] == 'GET' and row['path'] == self.detail and row['status'] == 200 and
                    row.get('authenticated') is True and row.get('bearer') is False for row in self.requests()[checkpoint:]),
                'Native history reentry did not perform the exact authenticated HTTPS detail GET')

    def open_history(self):
        self.ui.tap('history-tab')
        checkpoint = len(self.requests())
        self.ui.tap('assignment-' + self.assignment_id)
        self.ui.gameplay_foreground = True
        self.ui.wait(lambda ui: ui.find(D.PAGE) and not ui.find('gameplay-loading') and ui.find('question-title'),
                     'the exact completed history question')
        self.require_history_get(checkpoint)

    def run_negative(self):
        self.stage = 'completed-case-without-a-combination'
        self.device_binding()
        self.baseline = self.requests()
        self.authenticate_host()
        self.negative_initial = self.negative_facts()
        self.save_fixture('completed-without-combination', self.snapshot())
        self.login()
        self.theme('light')
        self.open_history()
        current = self.ui.find('question-title')
        if current is None or current.get('text') != self.titles['second']:
            self.ui.tap_question_number(1)
        self.wait_title('second')
        self.verify_second_ordinary_archive()
        self.no_combination_in_page('completed-without-combination', second_ordinary_only=True)
        self.ledger()
        self.check(True, 'A completed real case without combination grants retains ordinary clues and shows no launcher or auto-dialog')

    def main(self):
        if self.negative:
            self.run_negative()
            return
        self.stage = 'pristine-combination-case'
        self.device_binding()
        self.baseline = self.requests()
        require(not any(row['method'] == 'POST' and row['path'] in (self.start, self.answer_path)
                        for row in self.baseline), 'The exact case already has a start or answer in its receipt history')
        self.authenticate_host()
        player, pristine = self.host_read(D.ME), self.snapshot()
        require(player.get('id') == self.case['playerId'] and player.get('mustChangePassword') is False and
                player.get('totalXp') == 0 and pristine['status'] == 'assigned' and not pristine.get('startedAt') and
                not pristine['clues'] and all(row.get('question') is None for row in pristine['levels']),
                'The exact disposable assignment is not pristine or directly loggable')
        self.levels = [row['id'] for row in pristine['levels']]
        self.save_fixture('pristine', pristine)
        self.login()
        self.theme('light')
        self.ui.tap('assignment-' + self.assignment_id)
        self.ui.wait(lambda ui: ui.find('start-assignment'), 'exact isolated assignment detail')
        self.allowed_starts = 1
        self.ui.tap('start-assignment')
        self.ui.gameplay_foreground = True
        self.wait_title('first')
        initial = self.snapshot()
        require(initial['status'] == 'active' and initial['currentIndex'] == 0 and
                initial['levels'][0].get('autoNext') is False and initial['levels'][1].get('question') is None,
                'Native entry did not open the reviewed manual two-question case')
        self.authoritative(initial, False)
        self.save_fixture('started', initial)
        self.no_combination_in_page('first-question-no-combination')

        self.stage = 'before-final-answer'
        self.allowed_answers = 1
        self.ui.fill(D.ANSWER, self.answers_input['first'])
        self.submit_ready()
        first = self.snapshot()
        self.authoritative(first, False)
        require(first['levels'][0].get('completedAt') and not first['levels'][1].get('completedAt'),
                'The first answer did not uniquely settle the first question')
        self.save_fixture('first-completed', first)
        self.ui.tap('gameplay-next')
        self.wait_title('second')
        self.no_combination_in_page('before-completion')
        self.ledger()
        self.check(True, 'The initial and final editable questions expose no combination dialog or launcher')

        self.stage = 'completion-acknowledgement'
        self.allowed_answers = 2
        self.ui.fill(D.ANSWER, self.answers_input['second'])
        self.submit_ready()
        def completion_shown(ui):
            return ui.has_text(D.COMPLETION_TITLE) and ui.has_text(COMPLETION_ACK)
        self.ui.wait(completion_shown, 'completion acknowledgement before combination clues', timeout=30)
        require(not self.ui.find(LAUNCHER) and not self.ui.find(DIALOG),
                'A combination launcher or dialog appeared before completion acknowledgement')
        self.observe('completion-acknowledgement')
        self.ui.back()
        self.ui.wait(completion_shown, 'completion acknowledgement survives system Back', timeout=8)
        settled = self.snapshot()
        self.authoritative(settled, True)
        self.save_fixture('completed', settled)
        self.ledger()
        self.check(True, 'The final correct answer settles the case and displays the existing acknowledgement first')

        self.stage = 'combination-auto-order-and-dismissal'
        self.ui.tap_observed(text=COMPLETION_ACK)
        self.wait_dialog(0)
        self.observe('first-combination-auto', DIALOG, TITLE, CONTENT, DESCRIPTION, ACK)
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', *self.ui.mask_point())
        self.wait_dialog(0)
        self.observe('first-combination-mask-ignored', DIALOG, TITLE, ACK)
        self.ui.tap_observed(ACK)
        self.wait_dialog(1)
        self.observe('last-combination-auto', DIALOG, TITLE, CONTENT, DESCRIPTION, ACK)
        self.ui.back()
        self.wait_launcher()
        self.observe('launcher-after-queue', LAUNCHER)
        self.verify_second_ordinary_archive()
        self.no_combination_in_page('ordinary-archive-separation', launcher=True, second_ordinary_only=True)
        self.check(True, 'The exact sorted automatic dialogs preserve raw copy and fallback copy; outside touch is ignored and Back closes the last dialog')

        self.stage = 'manual-reopen-and-drag'
        self.ui.tap_observed(LAUNCHER)
        self.wait_dialog(1)
        self.observe('last-combination-reopened-light', DIALOG, TITLE, CONTENT, DESCRIPTION, ACK)
        self.ui.tap_observed(ACK)
        self.wait_launcher()
        dragged = self.drag_launcher()
        self.check(True, 'The completed launcher opens only the latest clue and can drag without opening the dialog')

        self.stage = 'completed-history-no-replay'
        self.return_home()
        self.theme('dark')
        self.open_history()
        reopened = self.wait_launcher()
        require(all(abs(left - right) <= 4 * self.ui.density for left, right in zip(dragged, reopened)),
                'The dragged launcher position was not restored on history reentry')
        self.observe('launcher-reentry', LAUNCHER)
        self.ui.tap_observed(LAUNCHER)
        self.wait_dialog(1)
        self.observe('last-combination-reopened', DIALOG, TITLE, CONTENT, DESCRIPTION, ACK)
        self.ui.tap_observed(ACK)
        self.wait_launcher()
        self.authoritative(self.snapshot(), True)
        self.ledger()
        self.check(True, 'History GET restores the launcher position without replay; manual reopen reads the latest clue with no extra gameplay writes')

    def save(self, status):
        if status != 'incomplete':
            status = 'captured_native_no_combination' if self.negative else 'captured_native_combination_clues'
        report = {'status': status, 'stage': self.stage, 'hapSha256': self.hap_sha, 'checksPassed': len(self.checks),
                  'scope': 'Dedicated real HTTPS two-question combination clue acceptance on the reviewed straight phone',
                  'checks': self.checks, 'states': self.states, 'cleanup': self.cleanup, 'bindingSha256': self.binding,
                  'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
                  'sameDataWebFixtures': self.fixtures, 'observations': self.observations,
                  'fixedPreviewTouched': False, 'visualReview': 'pending_original_review', 'failure': self.failure}
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        require(not any(value and value in encoded for value in
                        (*self.secrets(), self.serial, self.fixture['sessionId'], *self.levels)) and
                not re.search(r'https?://', encoded), 'A private value would enter the combination clue report')
        FRAME.fresh(self.report, OUT)
        self.report.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream:
            stream.write(encoded)
        print(json.dumps({'status': status, 'checksPassed': len(self.checks),
                          'report': str(self.report.relative_to(ROOT))}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest='action')
    run = actions.add_parser('run', help='One native start and two correct answers on the pristine positive fixture')
    negative = actions.add_parser('run-negative', help='Read-only history check on the settled no-combination fixture')
    for command in (run, negative):
        for name in ('runtime', 'fixture', 'device-ref', 'output'):
            command.add_argument('--' + name, type=Path, required=True)
        command.add_argument('--expected-hap', required=True)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return CombinationClues(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Exact combination fixture, package, runtime, owner or output guards failed'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

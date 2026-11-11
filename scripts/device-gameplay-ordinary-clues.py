#!/usr/bin/env python3
"""Narrow straight-phone ordinary clue acceptance on a dedicated real backend.

Help performs no device or private IO. run never provisions or resets players,
touches the fixed preview, changes the build, or writes through a Host client.
The only business writes are one native start and two exact native answers.
"""
import argparse
import hashlib
from importlib.util import module_from_spec, spec_from_file_location
import json
import os
from pathlib import Path
import re
import sys
import time
import uuid

from native_device_ui import ROOT, SafeFailure, flatten

SPEC = spec_from_file_location('clue_navigation_guard', ROOT / 'scripts/device-gameplay-question-nav.py')
NAV = module_from_spec(SPEC)
SPEC.loader.exec_module(NAV)
ENTRY, FRAME, UI, require, sha = NAV.ENTRY, NAV.FRAME, NAV.UI, NAV.require, NAV.sha

OUT = FRAME.VALIDATION / 'ui-gameplay-clues-20261111'
CASE_LABEL = 'ordinary-clues-phone'
PAGE, CARD = 'gameplay-page', 'gameplay-question-card'
PANEL, CLUE = 'gameplay-clues-panel', 'gameplay-clue-'
DIALOG, DIALOG_CLOSE = 'gameplay-clue-text-dialog', 'gameplay-clue-text-close'
DIALOG_TITLE, DIALOG_CONTENT = 'gameplay-clue-text-title', 'gameplay-clue-text-content'
VIEWER, VIEWER_CLOSE = 'image-viewer', 'image-viewer-close'
ME = '/api/questions/v1/me'
ANSWER = 'gameplay-answer-input'
COMPLETION_TITLE, COMPLETION_ACK = '组合谜题全部破解', '知晓了'


class ClueUI(NAV.NavigationUI):
    serial = ''

    def minimum_height(self, node_id, node):
        if node_id == 'gameplay-next':
            # GameplayPage declares a 46 vp button, not the older driver's 48 vp.
            return 46 * self.density - 2
        return super().minimum_height(node_id, node)

    def run(self, *args, timeout=45):
        if args[:2] == ('devecocli', 'ui'):
            require(bool(self.serial), 'An explicitly reviewed UI device is required')
            if args[2] == 'click':
                if args[3] == '--id':
                    self.capture()
                    node = self.find(args[4])
                    require(node is not None and UI.positive(node['bounds']), 'The exact native button is not exposed')
                    a, b, c, d = node['bounds']
                    args = ('hdc', 'shell', 'uitest', 'uiInput', 'click', (a + c) // 2, (b + d) // 2)
                else:
                    args = ('hdc', 'shell', 'uitest', 'uiInput', 'click', *args[3:])
            elif args[2] == 'swipe':
                args = ('hdc', 'shell', 'uitest', 'uiInput', 'swipe', *(arg for arg in args[3:] if arg != '--speed'))
            else:
                args = (*args, '--device', self.serial)
        if args[0] == 'hdc' and args[1] not in ('list', '-t'):
            require(bool(self.serial), 'An explicitly reviewed HDC device is required')
            args = ('hdc', '-t', self.serial, *args[1:])
        return super().run(*args, timeout=timeout)

    @staticmethod
    def layout_node(raw):
        attrs = raw.get('attributes', {})
        result = {key: attrs[key] for key in ('type', 'text', 'description', 'selected', 'checked', 'enabled',
                                             'focused', 'scrollable') if key in attrs}
        result['id'] = attrs.get('key', '')
        result['bounds'] = UI.rect(attrs['bounds']) if attrs.get('bounds') else None
        result['children'] = [ClueUI.layout_node(child) for child in raw.get('children', [])]
        return result

    def live_layout(self):
        # Use the API26 bundle-scoped UiTest source directly for polling: the
        # CLI layout normalizer intermittently stalls after a successful tap.
        name = 'starward-clue-poll-' + uuid.uuid4().hex + '.json'
        remote = '/data/local/tmp/' + name
        received = self.output / ('.' + name)
        try:
            self.run('hdc', 'shell', 'uitest', 'dumpLayout', '-b', 'com.sitkin.starward', '-p', remote, timeout=14)
            fd = os.open(received, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            os.close(fd)
            self.run('hdc', 'file', 'recv', remote, received, timeout=10)
            raw = json.loads(received.read_text())
            children = raw.get('children', [])
            require(any(node.get('attributes', {}).get('bundleName') == 'com.sitkin.starward' for node in children),
                    'The owned bundle is not exposed by official UiTest')
            return [self.layout_node(node) for node in children
                    if node.get('attributes', {}).get('bundleName') == 'com.sitkin.starward']
        finally:
            received.unlink(missing_ok=True)
            try:
                self.run('hdc', 'shell', 'rm', '-f', remote, timeout=6)
            except Exception:
                self.remote_cleanup_ok = False
                raise

    def capture(self, name=None):
        require(name is None or name == 'failure-last-view', 'Use private original captures')
        self.tree, self.flat, self.width, self.height = None, [], 0, 0
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            tree = self.live_layout()
            flat = flatten(tree)
            roots = [node for node in flat if node.get('type') == 'root' and node.get('bounds')]
            owned = [root for root in roots if any(
                node.get('id') in (PAGE, DIALOG, VIEWER, 'account', 'account-menu', 'start-assignment') or
                node.get('text') == COMPLETION_TITLE
                for node in flatten(root))]
            if owned:
                self.tree, self.flat = tree, flat
                bounds = UI.rect(owned[0]['bounds'])
                require(UI.positive(bounds), 'The actual own gameplay window has no positive bounds')
                self.width, self.height = bounds[2] - bounds[0], bounds[3] - bounds[1]
                return flat
            time.sleep(.2)
        raise SafeFailure('Own gameplay or its clue/completion overlay was not in foreground')

    def tap_observed(self, node_id=None, *, text=None):
        self.capture()
        rows = [row for row in self.flat if row.get('bounds') and
                (row.get('id') == node_id if node_id else row.get('text') == text)]
        require(len(rows) == 1, 'The expected actual modal control is not uniquely visible')
        box = UI.rect(rows[0]['bounds'])
        require(UI.positive(box) and any(UI.inside(box, UI.rect(root['bounds'])) for root in self.flat
            if root.get('type') == 'root' and root.get('bounds') and
            any(node is rows[0] for node in flatten(root))),
            'The expected modal control is outside its own window')
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'click',
                 (box[0] + box[2]) // 2, (box[1] + box[3]) // 2)

    def tap_question_number(self, index):
        # The horizontal strip intentionally has less vertical padding than
        # the generic Scroll helper requires. Measure against the outer page.
        key = 'gameplay-level-' + str(index)
        for _ in range(7):
            self.capture()
            node, page = self.find(key), self.find(PAGE)
            if node and page and node.get('bounds') and page.get('bounds'):
                box, view = UI.rect(node['bounds']), UI.rect(page['bounds'])
                if (UI.inside(box, view, 2) and box[3] - box[1] > 45 * self.density and
                        node.get('enabled') in (True, 'true')):
                    self.tap_observed(key)
                    return
            self.swipe('up')
        raise SafeFailure('The question-number control did not expose an enabled, measured tap target')

    def swipe(self, direction):
        self.capture()
        if self.find(DIALOG) is None or self.find(VIEWER) is not None:
            require(self.find(VIEWER) is None, 'Do not scroll the background below a clue image viewer')
            return super().swipe(direction)
        dialog = UI.rect(self.find(DIALOG)['bounds'])
        require(UI.positive(dialog) and dialog[3] - dialog[1] > 80 * self.density,
                'The actual text dialog is too small for its own scroll gesture')
        x = round((dialog[0] + dialog[2]) / 2)
        a = round(dialog[1] + (dialog[3] - dialog[1]) * .31)
        b = round(dialog[1] + (dialog[3] - dialog[1]) * .73)
        start, end = (b, a) if direction == 'down' else (a, b)
        self.run('devecocli', 'ui', 'swipe', x, start, x, end)

    def press_mask(self):
        self.capture()
        panel = self.find(DIALOG)
        require(panel and panel.get('bounds'), 'An actual dialog panel is required before outside dismissal')
        root = next((node for node in self.flat if node.get('type') == 'root' and node.get('bounds') and
                     any(child is panel for child in flatten(node))), None)
        require(root is not None, 'The actual dialog window was not identified')
        outer, inside = UI.rect(root['bounds']), UI.rect(panel['bounds'])
        require(UI.positive(outer) and UI.positive(inside) and UI.inside(inside, outer),
                'The dialog and its actual focused window have inconsistent bounds')
        # Prefer a vertical gap near the middle, never a system-edge gesture.
        candidates = ((outer[1], inside[1]), (inside[3], outer[3]))
        gap = max(candidates, key=lambda pair: pair[1] - pair[0])
        require(gap[1] - gap[0] > 48 * self.density, 'No safe outside-dialog click is available')
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'click', (outer[0] + outer[2]) // 2,
                 (gap[0] + gap[1]) // 2)


class OrdinaryClues(NAV.NavigationSample):
    def __init__(self, args):
        FRAME.fresh(args.output, OUT)
        require(re.fullmatch(r'[a-f0-9]{64}', args.expected_hap), 'An exact signed HAP SHA256 is required')
        ENTRY.guarded(args.fixture, FRAME.PRIVATE / 'ui-reference', True)
        ENTRY.PRIVATE = FRAME.PRIVATE
        args.case_ref, args.delay_ms = args.fixture, 10000
        ENTRY.EntryMain.__init__(self, args)
        require(self.case.get('label') == CASE_LABEL, 'Use an exact disposable ordinary clue actor')
        self.fixture = json.loads(self.reference_path.read_text())
        target = self.fixture.get('assignmentId', '')
        require(self.fixture.get('formatVersion') == 1 and self.fixture.get('status') == 'verified_ready' and
                self.fixture.get('usage') == 'phone' and self.fixture.get('playerSha256') ==
                hashlib.sha256(self.case['playerId'].encode()).hexdigest() and
                self.case['playerId'] not in (self.state['playerId'], self.state.get('otherPlayerId')) and
                re.fullmatch(r'[a-z0-9]{15}', self.fixture.get('sessionId', '')) and
                re.fullmatch(r'[a-z0-9]{15}', target) and target != self.state['assignmentId'] and
                target not in {a.get('assignmentId') for case_id, case in self.state['gameplay']['cases'].items()
                               if case_id != self.case_id for a in case.get('assignments', {}).values()},
                'The assignment does not belong to the exact reviewed disposable fixture namespace')
        self.assignment_id = target
        self.ids.add(target)
        self.detail = ENTRY.BASE + '/' + target
        self.start = self.detail + '/start'
        self.answer_path = self.detail + '/answers'
        self.titles, self.answers_input, self.expected = (self.fixture[key] for key in ('titles', 'answers', 'expected'))
        self.xp_per_correct = self.fixture.get('xpPerCorrect', 50)
        self.registered_assignment = target == self.case['assignments']['ready']['assignmentId']
        require(type(self.xp_per_correct) is int and self.xp_per_correct >= 0 and
                all(isinstance(self.titles.get(key), str) and self.titles[key] for key in ('session', 'first', 'second')) and
                all(isinstance(self.answers_input.get(key), str) and self.answers_input[key].strip()
                    for key in ('first', 'second')), 'The private question fixtures lack their exact titles or text answers')
        for key in ('first', 'second'):
            require(isinstance(self.expected[key], list) and self.expected[key] and
                    all(row['kind'] in ('text', 'image') and row['source'] in ('session', 'question') and row['title']
                        for row in self.expected[key]), 'Expected ordinary clue cards are absent')
        require({row['kind'] for row in self.expected['first']} == {'text', 'image'},
                'The first completed question must exercise both ordinary clue kinds')
        require(isinstance(self.expected.get('excludedTitles'), list), 'The private exclusions must be explicit')
        device_ref = ENTRY.guarded(args.device_ref, FRAME.PRIVATE, True)
        device = json.loads(device_ref.read_text())
        self.serial = device.get('deviceSerial', '')
        require(set(device) == {'deviceSerial'} and re.fullmatch(r'[A-Za-z0-9]{8,80}', self.serial),
                'A reviewed private reference to the new straight phone is required')
        self.ui = ClueUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
                         'controlToken': self.state['controlToken']}, self.ui.density, self.directory, side_panel=True)
        self.ui.serial = self.serial
        self.bound.update({'clueDriver': Path(__file__), 'deviceReference': device_ref,
                           'navigationDriver': Path(NAV.__file__),
                           'page': ROOT / 'entry/src/main/ets/features/GameplayPage.ets',
                           'cluePresentation': ROOT / 'entry/src/main/ets/business/GameplayClues.ets',
                           'imageViewer': ROOT / 'entry/src/main/ets/ui/StarwardImageViewer.ets',
                           'inlineImages': ROOT / 'entry/src/main/ets/ui/StarwardQuestionImages.ets',
                           'lightColors': ROOT / 'entry/src/main/resources/base/element/color.json',
                           'darkColors': ROOT / 'entry/src/main/resources/dark/element/color.json'})
        for key, filename in (('cluePanel', 'StarwardClueArchive.ets'), ('clueDialog', 'StarwardClueTextDialog.ets')):
            path = ROOT / 'entry/src/main/ets/ui' / filename
            if path.is_file():
                self.bound[key] = path
        media_manifest = args.media_manifest or self.fixture.get('mediaManifestFile')
        require(media_manifest, 'An exact media replay manifest is required')
        self.bound['mediaManifest'] = ENTRY.guarded(Path(media_manifest), FRAME.PRIVATE, True)
        require(sha(self.bound['mediaManifest']) == self.fixture.get('mediaManifestSha256'),
                'The reviewed clue media manifest changed')
        self.binding = {name: sha(path) for name, path in self.bound.items()}
        self.baseline, self.allowed_starts, self.allowed_answers, self.levels = None, 0, 0, []
        self.states, self.fixtures = [], {}
        self.theme_overridden = False
        self.cleanup.pop('faultNeutralised')
        self.cleanup['zeroUnexpectedWrites'] = False
        self.cleanup['appThemeRestored'] = True
        runtime_window = json.loads(self.runtime_path.read_text())['window']
        self.observations['window'] = {key: runtime_window[key] for key in
                                      ('widthPx', 'heightPx', 'density', 'fontScale') if key in runtime_window}
        self.births = self.owners()

    def device_binding(self):
        targets = [line.split() for line in self.ui.run('hdc', 'list', 'targets', '-v').splitlines() if line.strip()]
        require(all(len(row) == 5 and row[2] in ('Connected', 'Offline') for row in targets) and
                [row[:2] for row in targets if row[2] == 'Connected'] == [[self.serial, 'USB']],
                'The reviewed USB phone must be the sole online target')
        forwards = [line.split() for line in self.ui.run('hdc', '-t', self.serial, 'fport', 'ls').splitlines()]
        expected = ['tcp:18443', 'tcp:' + str(self.state['tls']['hostPort']), '[Reverse]']
        relevant = [row for row in forwards if 'tcp:18443' in row]
        require(relevant in ([expected], [[self.serial, *expected]]),
                'The reviewed USB phone lacks the exact isolated TLS mapping')

    def safe_failure(self, error):
        return super().safe_failure(error).replace(self.serial, '[private device omitted]')

    def snapshot(self):
        dto = self.host_read(self.detail)
        require(dto.get('id') == self.assignment_id and dto.get('player') == self.case['playerId'] and
                dto.get('session') == self.fixture['sessionId'] and
                len(dto.get('levels', [])) == 2 and dto.get('title') == self.titles['session'] and
                isinstance(dto.get('clues'), list), 'The real clue DTO has an unexpected actor, title, or question count')
        return dto

    def authoritative_clues(self, dto, key):
        by_id = {row['id']: row for row in dto['levels']}
        index = int(key == 'second')
        viewed = dto['levels'][index]['id']
        def visible(row):
            if row['kind'] not in ('text', 'image'):
                return False
            level = row.get('sessionLevel', '')
            if row.get('source', 'session') == 'question':
                return level == viewed
            return (not level or level == viewed) and not (not level and row['trigger'] == 'session_completed'
                                                            and row['kind'] == 'text')
        actual = sorted((row for row in dto['clues'] if visible(row)),
                        key=lambda row: (int(row.get('source', 'session') != 'session'),
                            by_id.get(row.get('sessionLevel'), {}).get('position', 0)
                                if row.get('source') == 'question' else 0,
                            row['position'], row.get('definitionId') or row['id'], row['id']))
        expected = self.expected[key]
        require(len(actual) == len(expected) and all(row.get('source', 'session') == target['source'] and
            row['kind'] == target['kind'] and row['content']['title'] == target['title'] and
            (row['content']['text'] == target['body'] if target['kind'] == 'text'
             else len(row['content']['imageUrls']) == target['imageCount']) for row, target in zip(actual, expected)),
            'The reviewed clue fixture does not match the actual sorted server-authorized text/images')
        return actual

    def wait_title(self, key):
        self.ui.wait(lambda ui: ui.find(PAGE) and ui.find('gameplay-loading') is None and
                     ui.find('question-title') and ui.find('question-title').get('text') == self.titles[key],
                     'the exact visible question', timeout=30)

    def dismiss_completed(self):
        self.ui.wait(lambda ui: ui.has_text(COMPLETION_TITLE) and ui.has_text(COMPLETION_ACK),
                     'the existing authoritative multi-question completion acknowledgement', timeout=30)
        self.ui.tap_observed(text=COMPLETION_ACK)
        self.ui.wait(lambda ui: ui.find(PAGE) and not ui.has_text(COMPLETION_TITLE), 'existing completion notice closes')

    def no_clue_panel(self, label):
        # Verify the actual scroll through the content below the question.
        # A missing off-screen node from one UiTest dump is not negative proof.
        previous = None
        for _ in range(10):
            self.ui.capture()
            require(self.ui.find(PAGE) and not any(self.ui.find(node) for node in
                    (PANEL, CLUE + '0', DIALOG, VIEWER, 'gameplay-clue-notice')),
                    'An unfinished question exposed an ordinary clue, false placeholder or overlay')
            require(not any(self.ui.has_text(title) for title in self.expected['excludedTitles']),
                    'An excluded clue title was exposed on an unfinished question')
            fingerprint = self.ui.visible_fingerprint()
            if fingerprint == previous:
                self.ui.raw_app(label)
                self.ui.private_shot(label)
                return
            previous = fingerprint
            self.ui.swipe('down')
        raise SafeFailure('The native page bottom was not observed while surveying hidden clues')

    @staticmethod
    def contained_title(node, value):
        if not node:
            return False
        candidates = [str(row.get(key, '')) for row in flatten(node)
                      for key in ('text', 'description', 'accessibilityText')]
        return any(value in item for item in candidates)

    def visible_geometry(self, row, markers):
        boxes = {}
        for key, node_id, text in markers:
            candidates = [node for node in flatten(row) if node.get('bounds') and
                          ((node_id and node.get('id') == node_id) or (text and node.get('text') == text))]
            if len(candidates) == 1:
                box = UI.rect(candidates[0]['bounds'])
                if UI.positive(box):
                    boxes[key] = box
        return boxes

    def inspect_panel(self, key, label, *, open_cards=False):
        self.ui.seek(CLUE + '0')
        require(any(node.get('id') == CARD for node in self.ui.path_to(PANEL) or []),
                'The archive must be inside the active completed question card')
        count = len(self.expected[key])
        for index, expected in enumerate(self.expected[key]):
            node_id = CLUE + str(index)
            self.ui.seek(node_id)
            title = self.ui.find('gameplay-clue-title-' + str(index))
            require(self.contained_title(self.ui.find(node_id), expected['title']) or
                    self.contained_title(title, expected['title']), 'A visible clue title or order differs from the server fixture')
            require(not self.ui.find(DIALOG) and not self.ui.find(VIEWER) and
                    not any(self.ui.has_text(title) for title in self.expected['excludedTitles']),
                    'An unsupported clue or automatic overlay is visible')
            shot = label + '-card-' + str(index)
            rows, evidence = self.ui.raw_app(shot)
            raw = [row for row in rows if row.get('id') == node_id and UI.exposed(row)]
            require(len(raw) == 1, 'The actual bundle tree lacks a unique visible clue card')
            box = UI.rect(raw[0]['bounds'])
            self.states.append({'state': shot, 'boundsPx': box, 'rawSha256': evidence['sha256'],
                'visibleGeometryPx': self.visible_geometry(self.ui.tree, (
                    ('question', CARD, None), ('archive', PANEL, None),
                    ('archiveHeading', 'gameplay-clues-heading', '通关线索'),
                    ('archiveCount', 'gameplay-clues-count', '件已解锁'),
                    ('questionContent', 'question-content', None), ('page', PAGE, None)))})
            self.ui.private_shot(shot)
            if open_cards:
                if expected['kind'] == 'text':
                    self.open_text(node_id, expected, shot, all_dismissals=index == 0)
                else:
                    self.open_images(node_id, expected, shot)
        previous = None
        for _ in range(10):
            self.ui.capture()
            require(not any(self.ui.find(node) for node in (CLUE + str(count), 'gameplay-clue-notice')) and
                    not any(self.ui.has_text(title) for title in self.expected['excludedTitles']),
                    'An unsupported or duplicate card follows the expected archive')
            fingerprint = self.ui.visible_fingerprint()
            if fingerprint == previous:
                return
            previous = fingerprint
            self.ui.swipe('down')
        raise SafeFailure('The native page bottom was not observed after the final clue card')

    def close_to_card(self):
        self.ui.wait(lambda ui: ui.find(PAGE) and ui.find(CARD) and not ui.find(DIALOG) and not ui.find(VIEWER),
                     'clue closes to the same completed gameplay card')

    def open_text(self, node, expected, label, *, all_dismissals):
        for dismissal in ('close', 'back', 'mask') if all_dismissals else ('close',):
            self.ui.tap(node)
            self.ui.wait(lambda ui: ui.find(DIALOG) and ui.find(DIALOG_TITLE) and ui.find(DIALOG_CONTENT),
                         'the native clue text dialog')
            require(self.ui.find(DIALOG_TITLE).get('text') == expected['title'],
                    'The actual dialog did not preserve the authorized clue title')
            if dismissal == 'close':
                _, evidence = self.ui.raw_app(label + '-text-dialog')
                geometry = self.visible_geometry(self.ui.tree, (
                    ('dialog', DIALOG, None), ('title', DIALOG_TITLE, None),
                    ('content', DIALOG_CONTENT, None), ('close', DIALOG_CLOSE, None)))
                require(set(geometry) == {'dialog', 'title', 'content', 'close'} and
                        all(UI.inside(geometry[key], geometry['dialog'], 2) for key in ('title', 'close')),
                        'The text dialog title or close control escapes its actual window')
                self.states.append({'state': label + '-text-dialog', 'rawSha256': evidence['sha256'],
                                    'visibleGeometryPx': geometry})
                self.ui.private_shot(label + '-text-dialog')
                self.read_text_body(expected, label)
                self.ui.tap_observed(DIALOG_CLOSE)
            elif dismissal == 'back':
                self.ui.back()
            else:
                self.ui.press_mask()
            self.close_to_card()

    def read_text_body(self, expected, label):
        fragments = expected.get('bodyFragments', [expected['body']])
        paragraphs = expected.get('paragraphs', [])
        if paragraphs:
            observed = []
            for item in paragraphs:
                node_id = 'gameplay-clue-paragraph-' + str(item['partIndex'])
                self.ui.seek(node_id)
                rows = [str(row.get('text', '')) for row in flatten(self.ui.find(node_id))]
                actual = [value.strip() for value in rows if value.strip()]
                normalized = item['text'].strip()
                require((normalized in actual or ''.join(actual) == normalized) and
                        all('[[' not in text and ']]' not in text for text in actual),
                        'An actual rich paragraph did not preserve the text/highlight span order')
                observed.extend(actual)
            require(all(any(fragment in value for value in observed) for fragment in fragments),
                    'One of the reviewed rich text fragments is missing')
        else:
            require(all(self.contained_title(self.ui.find(DIALOG_CONTENT), fragment) for fragment in fragments),
                    'The actual dialog did not preserve the authorized clue text')
        for part_index in expected.get('inlineImageParts', []):
            prefix = f'gameplay-clue-inline-{part_index}-0-'
            self.ui.seek(prefix + 'open')
            self.ui.wait(lambda ui: ui.find(prefix + 'pixels'), 'the real rich inline clue image')
            self.ui.private_shot(label + '-inline-' + str(part_index))
            self.ui.tap_observed(prefix + 'open')
            self.ui.wait(lambda ui: ui.find(VIEWER) and ui.find('image-viewer-pixels'),
                         'the existing image viewer above the rich text dialog', timeout=30)
            self.ui.private_shot(label + '-inline-viewer-' + str(part_index))
            self.ui.tap_observed(VIEWER_CLOSE)
            self.ui.wait(lambda ui: ui.find(DIALOG) and not ui.find(VIEWER) and ui.find(prefix + 'pixels'),
                         'closing the viewer restores the same text dialog and loaded inline image')
            self.ui.seek(DIALOG_TITLE)
            require(self.ui.find(DIALOG_TITLE) and self.ui.find(DIALOG_TITLE).get('text') == expected['title'],
                    'Closing an inline image did not restore its own text clue title')

    def open_images(self, node, expected, label):
        states = expected.get('imageStates', ['pixels'] * expected['imageCount'])
        require(len(states) == expected['imageCount'] > 0 and set(states) <= {'pixels', 'error'},
                'Image expectations must name each gallery index and allowed outcome')
        self.ui.tap(node)
        for index, state in enumerate(states):
            self.ui.wait(lambda ui: ui.find('image-viewer-' + state) is not None, 'the actual clue image ' + state, timeout=30)
            if len(states) > 1:
                badge = self.ui.find('image-viewer-index')
                require(badge and badge.get('text') == f'{index + 1} / {len(states)}',
                        'The clue gallery index or grouping differs')
            if state == 'pixels':
                stage, image = (UI.rect(self.ui.find('image-viewer-' + key)['bounds']) for key in ('stage', 'pixels'))
                require(UI.positive(image) and UI.inside(image, stage, 2), 'Clue pixels do not fit the actual gallery stage')
            else:
                self.ui.tap_observed('image-viewer-retry')
                self.ui.wait(lambda ui: ui.find('image-viewer-error') is not None, 'the reviewed failure remains retryable')
            self.ui.private_shot(label + '-image-' + str(index))
            if index + 1 < len(states):
                self.ui.tap_observed('image-viewer-next')
        self.ui.tap_observed(VIEWER_CLOSE)
        self.close_to_card()
        self.ui.tap(node)
        self.ui.wait(lambda ui: ui.find('image-viewer-' + states[0]) is not None, 'reopening the first image')
        if len(states) > 1:
            require(self.ui.find('image-viewer-index').get('text') == f'1 / {len(states)}',
                    'Reopen did not reset to the first clue image')
        self.ui.back()
        self.close_to_card()

    def ledger(self, exact=True):
        rows = self.requests()
        require(self.baseline is not None and rows[:len(self.baseline)] == self.baseline,
                'The private request baseline is not an immutable prefix')
        added = rows[len(self.baseline):]
        require(all(((row['method'] == 'GET' and row['path'] in ('/api/health', ME, ENTRY.BASE, self.detail)) or
                    (row['method'] == 'POST' and row['path'] in (ENTRY.AUTH, self.start, self.answer_path))) and
                    row['status'] == 200 and row['fault'] is False and not row.get('responseDropped') and
                    not row.get('responseAwaitingDelay') for row in added), 'The isolated request ledger contains an unexpected route, fault or response')
        starts = [row for row in added if row['method'] == 'POST' and row['path'] == self.start]
        answers = [row for row in added if row['method'] == 'POST' and row['path'] == self.answer_path]
        actor = hashlib.sha256((self.state['controlToken'] + ':actor:' + self.case['playerId']).encode()).hexdigest()
        for operation, records, allowed in (('start', starts, self.allowed_starts), ('answer', answers, self.allowed_answers)):
            require((len(records) == allowed if exact else len(records) <= allowed) and
                    all(row.get('operation') == operation and row.get('authenticated') is True and row.get('bearer') is False and
                        row.get('actorVerifiedByBackendResponse') is True and row.get('actorSha256') == actor and
                        re.fullmatch(r'[a-f0-9]{64}', row.get('requestIdSha256', '')) for row in records),
                    'A start or answer escaped the exact native actor/count boundary')
        require([row.get('sessionLevelIdSha256') for row in answers] ==
                [hashlib.sha256(level.encode()).hexdigest() for level in self.levels[:len(answers)]],
                'A native answer targeted another level or repeated a submitted level')
        if self.token:
            dto, me = self.snapshot(), self.host_read(ME)
            require(sum(bool(row.get('completedAt')) for row in dto['levels']) == len(answers) and
                    me.get('totalXp') == self.xp_per_correct * len(answers),
                    'Strict backend reads disagree with the native completed levels or XP')
            if self.registered_assignment:
                facts = self.diagnostic()
                require(facts.get('startRequestIdSha256') == [row['requestIdSha256'] for row in starts] and
                        facts.get('answerRequestIdSha256') == [row['requestIdSha256'] for row in answers] and
                        facts.get('answerSubmissionCount') == facts.get('answerReceiptCount') == len(answers),
                        'The backend receipt identities disagree with the native request ledger')
        self.observations['businessWrites'] = {'starts': len(starts), 'answers': len(answers),
                                               'readOnlyReceiptDiagnosticAvailable': self.registered_assignment}
        return added

    def return_home(self):
        self.ui.hide_keyboard()
        self.ui.back()
        self.ui.gameplay_foreground = False
        self.ui.wait(lambda ui: ui.find('current-tab') and not ui.find(PAGE), 'home after native Back')

    def theme(self, mode):
        self.ui.tap('account-menu')
        self.ui.wait(lambda ui: ui.find('account-side-panel'), 'own account panel for app theme')
        self.theme_overridden = True
        self.cleanup['appThemeRestored'] = False
        self.ui.tap('theme-' + mode)
        self.ui.capture()
        require(not self.ui.find('theme-error-message'), 'The app theme request failed')
        selected = self.ui.find('theme-' + mode)
        flags = {key: selected[key] for key in ('selected', 'accessibilitySelected') if selected is not None and key in selected}
        require(all(value in (True, 'true') for value in flags.values()), 'A reported selected app theme flag is false')
        self.observations.setdefault('appThemeActions', []).append({'mode': mode, 'selectedFlagsObserved': bool(flags)})
        if self.ui.find('account-side-panel'):
            self.ui.back()
        self.ui.wait(lambda ui: not ui.find('account-side-panel') and ui.find('current-tab'), 'own home after theme selection')
        if mode == 'system':
            self.theme_overridden = False
            self.cleanup['appThemeRestored'] = True

    def logout(self):
        self.ui.capture()
        for modal in (VIEWER, DIALOG):
            if self.ui.find(modal):
                self.ui.tap_observed(VIEWER_CLOSE if modal == VIEWER else DIALOG_CLOSE)
                self.close_to_card()
        if self.ui.has_text(COMPLETION_TITLE) and self.ui.has_text(COMPLETION_ACK):
            self.dismiss_completed()
        if self.ui.find(PAGE):
            self.return_home()
        if self.ui.find('account') is None:
            if self.theme_overridden:
                if self.ui.find('account-side-panel'):
                    self.ui.back()
                self.theme('system')
            if not self.ui.find('account-side-panel'):
                self.ui.tap('account-menu')
            self.ui.tap('logout')
        self.ui.wait(lambda ui: ui.find('account') is not None, 'native empty login after clue logout')
        self.cleanup['loggedOut'] = True
        self.cleanup['loginInputsEmpty'] = self.ui.input_empty('account') and self.ui.input_empty('password')
        self.cleanup['privateGameplayAbsent'] = not any(self.ui.find(node) for node in
                                                       (PAGE, PANEL, DIALOG, VIEWER, ANSWER))
        require(self.cleanup['loginInputsEmpty'] and self.cleanup['privateGameplayAbsent'],
                'Logging out did not clear gameplay and its clue overlays')

    def main(self):
        self.device_binding()
        self.baseline = self.requests()
        self.stage = 'fresh-owned-clue-assignment'
        auth = self.host_read(ENTRY.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str),
                'Strict Host authentication did not identify the exact clue test actor')
        self.token = auth['token']
        player, pristine = self.host_read(ME), self.snapshot()
        require(player.get('id') == self.case['playerId'] and player.get('mustChangePassword') is False and
                player.get('totalXp') == 0 and pristine.get('status') == 'assigned' and not pristine.get('startedAt') and
                not pristine['clues'] and all(row.get('question') is None for row in pristine['levels']),
                'The exact disposable clue actor/assignment is not pristine and directly loggable')
        self.levels = [row['id'] for row in pristine['levels']]
        self.ui.launch(cold=True)
        self.ui.wait(lambda ui: ui.find('account'), 'empty isolated native login')
        self.device_started = True
        require(self.ui.input_empty('account') and self.ui.input_empty('password') and
                self.ui.has_text('隔离测试环境'), 'The native login is not empty and isolated')
        self.ui.fill('account', self.case['account'])
        self.ui.fill('password', self.case['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab'), 'ordinary isolated native home')
        self.theme('light')
        self.ui.tap('assignment-' + self.assignment_id)
        self.ui.wait(lambda ui: ui.find('start-assignment'), 'own isolated native detail')
        self.allowed_starts = 1
        self.ui.tap('start-assignment')
        self.ui.gameplay_foreground = True
        self.wait_title('first')
        initial = self.snapshot()
        require(initial['status'] == 'active' and initial['currentIndex'] == 0 and initial['levels'][1]['question'] is None
                and initial['levels'][0].get('autoNext') is False, 'The fresh two-question case is not the reviewed manual-next flow')
        self.save_fixture('uncompleted-first', initial)
        self.stage = 'first-locked-clues'
        self.no_clue_panel('uncompleted-first')
        self.ledger()
        self.check(True, 'Before answering, the actual card scrolls to its end with no clue panel or placeholder')

        self.stage = 'first-completed-ordinary-clues'
        self.allowed_answers = 1
        self.ui.fill(ANSWER, self.answers_input['first'])
        self.submit_ready()
        self.ui.seek(CLUE + '0')
        after_first = self.snapshot()
        require(after_first['levels'][0].get('completedAt') and not after_first['levels'][1].get('completedAt'),
                'The real first answer did not unlock the exact first completed question')
        self.authoritative_clues(after_first, 'first')
        self.save_fixture('completed-first', after_first)
        self.inspect_panel('first', 'completed-first', open_cards=True)
        self.ledger()
        self.check(True, 'The first completed question shows ordered authorized cards; text and images open, dismiss and reopen without business writes')

        self.stage = 'second-editable'
        self.ui.tap('gameplay-next')
        self.wait_title('second')
        self.no_clue_panel('uncompleted-second')
        self.check(True, 'The second editable question does not render already authorized clues from the completed first question')

        self.stage = 'second-completed-source-filter'
        self.allowed_answers = 2
        self.ui.fill(ANSWER, self.answers_input['second'])
        self.submit_ready()
        self.dismiss_completed()
        settled = self.snapshot()
        require(settled['status'] == 'completed' and all(row.get('completedAt') for row in settled['levels']),
                'The real second answer did not complete both reviewed levels')
        server_titles = {row['content']['title'] for row in settled['clues']}
        require(set(self.expected['excludedTitles']).issubset(server_titles),
                'The negative cases were not returned by the server and do not test native filtering')
        self.authoritative_clues(settled, 'second')
        self.save_fixture('completed-second', settled)
        self.inspect_panel('second', 'completed-second')
        self.ledger()
        self.check(True, 'The second completed question keeps applicable common clues, excludes the other question’s clues and leaves unsupported content out')

        self.stage = 'night-get-reentry-and-logout'
        self.return_home()
        self.theme('dark')
        self.ui.tap('history-tab')
        self.ui.tap('assignment-' + self.assignment_id)
        self.ui.gameplay_foreground = True
        self.ui.wait(lambda ui: ui.find(PAGE) and not ui.find('gameplay-loading'), 'real completed gameplay GET reentry')
        self.ui.tap_question_number(0)
        self.wait_title('first')
        revisited = self.snapshot()
        self.authoritative_clues(revisited, 'first')
        self.inspect_panel('first', 'revisited-first-night')
        sample_index = next(index for index, row in enumerate(self.expected['first']) if row['kind'] == 'text')
        self.open_text(CLUE + str(sample_index), self.expected['first'][sample_index], 'revisited-first-night',
                       all_dismissals=False)
        self.ledger()
        self.check(True, 'Completed GET reentry and a question tap restore the same clues without another start, answer or XP settlement')

    def save(self, status):
        status = 'captured_native_ordinary_clues' if status != 'incomplete' else status
        report = {'status': status, 'stage': self.stage, 'hapSha256': self.hap_sha, 'checksPassed': len(self.checks),
                  'scope': 'One dedicated real HTTPS two-question clue case; no production or fixed preview operations',
                  'checks': self.checks, 'states': self.states, 'cleanup': self.cleanup, 'bindingSha256': self.binding,
                  'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
                  'sameDataWebFixtures': self.fixtures, 'observations': self.observations,
                  'fixedPreviewTouched': False, 'visualReview': 'pending_original_review', 'failure': self.failure}
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        require(not any(value and value in encoded for value in
                        (*self.secrets(), self.serial, self.fixture['sessionId'], *self.levels)) and
                not re.search(r'https?://', encoded), 'A private value would enter the ordinary clue report')
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
    for name in ('runtime', 'fixture', 'device-ref', 'output'):
        run.add_argument('--' + name, type=Path, required=True)
    run.add_argument('--expected-hap', required=True)
    run.add_argument('--media-manifest', type=Path)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return OrdinaryClues(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Exact clue fixture, package, runtime, owner or output guards failed'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

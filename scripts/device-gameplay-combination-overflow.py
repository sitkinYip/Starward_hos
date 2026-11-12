#!/usr/bin/env python3
"""Measure the combination clue footer and body on an isolated completed assignment."""
import argparse
import hashlib
from importlib.util import module_from_spec, spec_from_file_location
import json
import re
import time
from pathlib import Path
import sys

from native_device_ui import ROOT, SafeFailure

SPEC = spec_from_file_location('overflow_clue_link_driver', ROOT / 'scripts/device-gameplay-clue-links.py')
L = module_from_spec(SPEC)
SPEC.loader.exec_module(L)
L.OUT = L.FRAME.VALIDATION / 'ui-gameplay-combination-overflow-20261112'
L.PRIVATE = L.FRAME.PRIVATE / 'gameplay-combination-overflow-20261112'
require, sha, C, ENTRY, FRAME, UI = L.require, L.sha, L.C, L.ENTRY, L.FRAME, L.UI
SCROLL = 'gameplay-combination-scroll'
FOOTER = 'gameplay-combination-footer'
IMAGE = 'gameplay-combination-inline-1-0-pixels'
TAIL = 'gameplay-combination-paragraph-2'
BUTTON_MIN_VP = 46
BOTTOM_PADDING_VP = 18


class OverflowClue(L.ClueLinks):
    def __init__(self, args):
        args.kind = 'combination'
        FRAME.fresh(args.output, L.OUT)
        require(re.fullmatch(r'[a-f0-9]{64}', args.expected_hap), 'The reviewed signed HAP hash is required')
        ENTRY.PRIVATE = FRAME.PRIVATE
        args.case_ref = ENTRY.guarded(args.fixture, L.PRIVATE, True)
        args.delay_ms = 10000
        ENTRY.EntryMain.__init__(self, args)
        self.fixture = json.loads(self.reference_path.read_text())
        label = 'clue-overflow-short' if args.probe == 'short' else 'clue-links-web'
        assignment = self.fixture.get('assignmentId', '')
        registered = {row.get('assignmentId') for case in self.state['gameplay']['cases'].values()
                      for row in case.get('assignments', {}).values()}
        require(self.case.get('label') == label and self.fixture.get('usage') == 'web' and
                self.fixture.get('formatVersion') == 1 and self.fixture.get('status') == 'verified_ready' and
                self.fixture.get('controlIdentitySha256') == hashlib.sha256(self.state['controlToken'].encode()).hexdigest() and
                self.fixture.get('playerSha256') == hashlib.sha256(self.case['playerId'].encode()).hexdigest() and
                C.ID.fullmatch(assignment) and C.ID.fullmatch(self.fixture.get('sessionId', '')) and
                assignment != self.state['assignmentId'] and assignment not in registered,
                'The approved pre-settled overflow assignment is not bound to its actor')
        self.assignment_id = assignment
        self.ids.add(assignment)
        self.detail = ENTRY.BASE + '/' + assignment
        self.combination = True
        self.expected, self.titles = self.fixture['expected'], self.fixture['titles']
        device = ENTRY.guarded(args.device_ref, FRAME.PRIVATE, True)
        receipt = json.loads(device.read_text())
        self.serial = receipt.get('deviceSerial', '')
        require(set(receipt) == {'deviceSerial'} and re.fullmatch(r'[A-Za-z0-9]{8,80}', self.serial),
                'The exact private USB device receipt is required')
        self.ui = C.CombinationUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
                                  'controlToken': self.state['controlToken']}, self.ui.density, self.directory,
                                  side_panel=True)
        self.ui.serial = self.serial
        self.bound.update({'overflowDriver': Path(__file__).resolve(), 'readOnlyDriver': Path(L.__file__),
                           'combinationDriver': Path(C.__file__), 'deviceReference': device,
                           'dialogSource': ROOT / 'entry/src/main/ets/ui/StarwardCombinationDialog.ets'})
        self.binding = {key: sha(path) for key, path in self.bound.items()}
        self.births = self.owners()
        self.baseline = self.initial_facts = self.pending_handler = None
        self.states, self.fixtures, self.levels = [], {}, []
        self.theme_overridden = False
        self.cleanup.pop('faultNeutralised')
        self.cleanup.update(zeroUnexpectedWrites=False, appThemeRestored=True)
        window = json.loads(self.runtime_path.read_text())['window']
        self.observations.update(probe=args.probe, window={key: window[key] for key in
                                ('widthPx', 'heightPx', 'density', 'fontScale')})
        self.dialog, self.title, self.paragraph = C.DIALOG, C.TITLE, 'gameplay-combination-paragraph-0'
        self.expected_title = self.expected['combinationTitle']

    def measured_view(self, name):
        rows, source = self.ui.raw_app(name)
        controls = {}
        for key in (C.DIALOG, SCROLL, FOOTER, C.ACK, C.TITLE, C.DESCRIPTION, IMAGE, TAIL):
            matching = [row for row in rows if key in (row.get('id'), row.get('key')) and UI.exposed(row)]
            require(len(matching) <= 1, 'A measured control appears more than once')
            if matching:
                controls[key] = matching[0]
        required = [C.DIALOG, SCROLL, FOOTER]
        if self.args.probe != 'baseline':
            required.append(C.ACK)
        require(all(key in controls for key in required), 'The expected dialog, scrolling body or footer is not exposed')
        self.ui.private_shot(name)
        boxes = {key: UI.rect(row['bounds']) for key, row in controls.items()}
        record = {'state': name, 'rawSha256': source['sha256'], 'geometryPx': boxes,
                  'privateOriginal': self.ui.private_screenshots[-1],
                  'bodyScrollable': controls[SCROLL].get('scrollable') in (True, 'true')}
        if C.ACK in controls:
            button, footer, panel = (boxes[key] for key in (C.ACK, FOOTER, C.DIALOG))
            height = max(0, min(button[3], footer[3], panel[3]) - max(button[1], footer[1], panel[1]))
            record['buttonVisibleHeightVp'] = height / self.ui.density
            record['buttonBottomPaddingVp'] = (min(footer[3], panel[3]) - button[3]) / self.ui.density
        self.states.append(record)
        return controls, record

    def verify_full_button(self, controls, record):
        boxes = record['geometryPx']
        button, footer, panel = (boxes[key] for key in (C.ACK, FOOTER, C.DIALOG))
        require(UI.inside(button, footer, 1) and UI.inside(footer, panel, 1) and
                record['buttonVisibleHeightVp'] >= BUTTON_MIN_VP - 2 / self.ui.density and
                record['buttonBottomPaddingVp'] >= BOTTOM_PADDING_VP - 2 / self.ui.density and
                boxes[SCROLL][3] <= footer[1] + 1 and
                controls[C.ACK].get('clickable') in (True, 'true') and
                controls[C.ACK].get('enabled') in (True, 'true'),
                'The confirmation button or its footer is clipped, disabled, or overlaps the scrolling body')
        identity = tuple(controls[C.ACK].get(key) for key in ('accessibilityId', 'hashcode'))
        require(all(identity), 'UiTest omitted the button instance identity')
        return (identity, button, footer, panel)

    def scroll_body(self):
        self.ui.capture()
        viewport = self.ui.find(SCROLL)
        require(viewport and viewport.get('bounds') and viewport.get('scrollable') in (True, 'true'),
                'The long dialog body is not an exposed scroll target')
        left, top, right, bottom = UI.rect(viewport['bounds'])
        require(right - left > 100 and bottom - top > 130, 'The measured body is too small for a safe swipe')
        x = round(left + (right - left) * .04)
        start, end = round(top + (bottom - top) * .78), round(top + (bottom - top) * .28)
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'swipe', x, start, x, end, 600)
        time.sleep(.25)

    def reach_tail(self):
        image_seen = False
        for _ in range(10):
            self.scroll_body()
            self.ui.capture()
            scroll = self.ui.find(SCROLL)
            image = self.ui.find(IMAGE)
            tail = self.ui.find(TAIL)
            if not image_seen and image and image.get('bounds') and UI.positive(UI.rect(image['bounds'])) and (
                    UI.inside(UI.rect(image['bounds']), scroll['bounds'], 1)):
                _, image_record = self.measured_view('dialog-body-image')
                image_seen = IMAGE in image_record['geometryPx']
            if tail and self.expected['tailText'] in tail.get('text', '') and (
                    scroll['bounds'][3] - tail['bounds'][3] >= 25 * self.ui.density):
                require(image_seen, 'The real decoded in-body image was never exposed inside the scroll viewport')
                return
        raise SafeFailure('The tail paragraph was not reachable in the dialog body')

    def main(self):
        self.stage = 'verify-owned-settled-fixture'
        self.device_binding()
        self.baseline = self.requests()
        C.CombinationClues.authenticate_host(self)
        detail, self.initial_facts = self.facts()
        self.save_fixture('overflow-same-data', detail)
        require(bool(self.expected.get('imageUrl')) == (self.args.probe != 'short'),
                'The probe must use the corresponding long or short fixture')
        self.stage = 'native-open-combination'
        self.login()
        self.theme(self.args.theme)
        self.open_assignment()
        self.ui.tap_observed(C.LAUNCHER)
        self.wait_dialog()
        start, initial = self.measured_view('dialog-initial')

        if self.args.probe == 'baseline':
            self.check(initial['bodyScrollable'] and
                       (C.ACK not in start or initial['buttonVisibleHeightVp'] < BUTTON_MIN_VP - 2 / self.ui.density or
                        initial['buttonBottomPaddingVp'] < BOTTOM_PADDING_VP - 2 / self.ui.density),
                       'The baseline long dialog exposes a cropped button or loses its bottom padding')
            self.ui.back()
        else:
            button = self.verify_full_button(start, initial)
            self.check(True, 'Initial confirmation button is fully exposed with the footer bottom padding')
            if self.args.probe == 'short':
                panel = initial['geometryPx'][C.DIALOG]
                self.check(not initial['bodyScrollable'] and (panel[3] - panel[1]) <
                           .8 * self.observations['window']['heightPx'],
                           'Short content stays compact and does not require body scrolling')
            else:
                self.stage = 'scroll-long-body'
                self.reach_tail()
                end, final = self.measured_view('dialog-body-tail')
                require(TAIL in end and self.expected['tailText'] in end[TAIL].get('text', ''),
                        'The same authorized tail is not visible in the final raw layout')
                self.check(self.verify_full_button(end, final) == button,
                           'The long body scrolls past its decoded image to the tail while the same footer stays fixed')
            self.stage = 'tap-confirmation'
            self.ui.tap_observed(C.ACK)
        self.ui.wait(lambda ui: ui.find(C.LAUNCHER) and not ui.find(C.DIALOG), 'closed combination and visible launcher')
        self.check(True, 'Closing the dialog restores the completed question and launcher')

    def save(self, status):
        if status == 'captured_native_clue_links':
            status = ('baseline_clipping_reproduced' if self.args.probe == 'baseline'
                      else 'passed_combination_footer_layout')
        super().save(status)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    run = parser.add_subparsers(dest='action').add_parser('run')
    run.add_argument('--probe', choices=('baseline', 'fixed', 'short'), required=True)
    run.add_argument('--theme', choices=('light', 'dark'), default='light')
    for name in ('runtime', 'fixture', 'device-ref', 'output'):
        run.add_argument('--' + name, type=Path, required=True)
    run.add_argument('--expected-hap', required=True)
    args = parser.parse_args()
    if args.action is None:
        parser.print_help()
        return 0
    try:
        return OverflowClue(args).execute()
    except Exception:
        print('Exact overflow fixture, package, runtime, owner or output guards failed', flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

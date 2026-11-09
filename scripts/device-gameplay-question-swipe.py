#!/usr/bin/env python3
"""Verify native card focus and physical swipes on one fresh disposable auto-next case."""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import time

from native_device_ui import ROOT


SPEC = importlib.util.spec_from_file_location('question_swipe_nav', ROOT / 'scripts/device-gameplay-question-nav.py')
NAV = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NAV)
ENTRY, UI, FRAME = NAV.ENTRY, NAV.UI, NAV.FRAME
require, sha = NAV.require, NAV.sha
OUT = FRAME.VALIDATION / 'ui-gameplay-question-swipe-20261106'
PAGE, CARD, TITLE, SWIPER = 'gameplay-page', 'gameplay-question-card', 'account-menu', 'gameplay-question-swiper'


class SwipeSample(NAV.NavigationSample):
    def __init__(self, args):
        FRAME.fresh(args.output, OUT)
        require(re.fullmatch(r'[a-f0-9]{64}', args.expected_hap or ''), 'An exact HAP SHA256 is required')
        args.stage, args.delay_ms = 'auto-next', 10000
        NAV.FOLLOWUP.AnswerFollowups.__init__(self, args)
        require(self.case['label'] == 'question-swipe-phone', 'The exact dedicated swipe fixture is required')
        reference = ENTRY.guarded(args.device_ref, FRAME.PRIVATE, True)
        device = json.loads(reference.read_text())
        self.serial = device.get('deviceSerial', '')
        require(set(device) == {'deviceSerial'} and re.fullmatch(r'[A-Za-z0-9]{8,80}', self.serial),
                'The reviewed private phone reference is required')
        self.ui = NAV.NavigationUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
            'controlToken': self.state['controlToken']}, self.ui.density, self.directory, side_panel=True)
        self.bound.update({'swipeDriver': Path(__file__), 'navDriver': Path(NAV.__file__),
                           'deviceReference': reference, 'frameGuard': Path(FRAME.__file__)})
        self.binding = {name: sha(path) for name, path in self.bound.items()}
        self.baseline, self.allowed_starts, self.allowed_answers = None, 0, 0
        self.states, self.fixtures = [], {}
        self.first_level, self.first_settled = '', False
        self.cleanup.pop('faultNeutralised')
        self.cleanup['zeroUnexpectedWrites'] = False
        self.births = self.owners()

    def wait_question(self):
        # The normal foreground control is inside the title, which may already be hidden.
        self.ui.gameplay_foreground = True
        self.ui.wait(lambda ui: ui.find(PAGE) and ui.find(SWIPER) and ui.find('question-title') and
                     ui.find('gameplay-loading') is None, 'native Swiper and first title', timeout=25)

    def geometry(self, rows, title, *, raw=False):
        def visible(row):
            if raw:
                return UI.exposed(row)
            return bool(row.get('bounds')) and UI.positive(UI.rect(row['bounds']))

        page = next((UI.rect(row['bounds']) for row in rows if row.get('id') == PAGE and visible(row)), None)
        swiper = next((UI.rect(row['bounds']) for row in rows if row.get('id') == SWIPER and visible(row)), None)
        if page is None or swiper is None:
            return None
        headings = [UI.rect(row['bounds']) for row in rows if row.get('id') == 'question-title' and
                    row.get('text') == title and visible(row)]
        cards = [UI.rect(row['bounds']) for row in rows if row.get('id') == CARD and visible(row)]
        pairs = [(heading, card) for heading in headings for card in cards if UI.inside(heading, card, 2) and
                 UI.inside(heading, page, 2)]
        if len(pairs) != 1:
            return None
        heading, card = pairs[0]
        return {'pagePx': page, 'swiperPx': swiper, 'cardPx': card, 'headingPx': heading,
                'titleVisible': any(row.get('id') == TITLE and visible(row) for row in rows)}

    def focus_sample(self, label, title, index, *, shot=True):
        def focused(ui):
            geometry = self.geometry(ui.flat, title)
            if geometry is None or geometry['titleVisible']:
                return False
            gap = (geometry['cardPx'][1] - geometry['pagePx'][1]) / ui.density
            return -1 <= gap <= 24

        self.ui.wait(focused, 'unassisted title collapse and card alignment', timeout=18)
        raw, evidence = self.ui.raw_app(label)
        geometry = self.geometry(raw, title, raw=True)
        require(geometry is not None and not geometry['titleVisible'], 'The official raw focused card or title state differs')
        gap = (geometry['cardPx'][1] - geometry['pagePx'][1]) / self.ui.density
        require(-1 <= gap <= 24, 'The focused card is outside the measured top alignment')
        self.states.append({'state': label, 'viewedQuestion': index + 1, 'gapVp': round(gap, 2),
                            'rawEvidence': evidence, **geometry})
        if shot:
            self.ui.private_shot(label)
            try:
                self.ui.capture()
                require(focused(self.ui), 'The same focused card did not retain foreground after the screenshot')
            except Exception:
                removed = self.ui.private_screenshots.pop()
                (ROOT / removed['file']).unlink(missing_ok=True)
                raise
        return geometry

    def rail_at_top(self, label, index, enabled, title):
        for _ in range(10):
            self.ui.capture()
            geometry = self.geometry(self.ui.flat, title)
            if geometry and geometry['titleVisible'] and self.ui.find(NAV.SECOND_NUMBER):
                buttons = self.nav_state(label, index, enabled, title)
                require(self.states[-1]['rawCurrentStateObserved'], 'The official rail did not identify the current question')
                return buttons
            page = self.ui.find(PAGE)
            require(page, 'The native gameplay page disappeared while returning to its top')
            left, top, right, bottom = UI.rect(page['bounds'])
            x = round(right - 8 * self.ui.density)
            center = round(top + (bottom - top) * .36)
            end = center + round(65 * self.ui.density)
            require(left < x < right and top < center < end < bottom, 'Unsafe vertical return gesture')
            self.ui.run('devecocli', 'ui', 'drag', x, center, x, end, '--speed', 250)
            time.sleep(.25)
        require(False, 'Returning vertically did not restore the official title and rail')

    def swipe_card(self, geometry, toward_next):
        card, swiper, page, heading = (geometry[key] for key in ('cardPx', 'swiperPx', 'pagePx', 'headingPx'))
        left = max(card[0], swiper[0], page[0])
        right = min(card[2], swiper[2], page[2])
        y = round((heading[1] + heading[3]) / 2)
        require(right - left >= 140 * self.ui.density and page[1] < y < min(card[3], swiper[3], page[3]),
                'Unsafe horizontal Swiper gesture geometry')
        low, high = round(left + (right - left) * .19), round(left + (right - left) * .81)
        start, end = (high, low) if toward_next else (low, high)
        self.ui.run('devecocli', 'ui', 'swipe', start, y, end, y, '--speed', 800)

    def assert_settled_readonly(self, answer):
        self.ui.seek(NAV.FIELD)
        raw, _ = self.ui.raw_app('swiped-first-readonly')
        require(any(row.get('id') == NAV.FIELD and row.get('enabled') == 'false' and
                    row.get('text') == answer and UI.exposed(row) for row in raw) and
                not any(row.get('id') == 'gameplay-submit' and UI.exposed(row) for row in raw),
                'The completed card did not preserve its authoritative read-only answer')

    def assert_choice_draft(self, label):
        raw, _ = self.ui.raw_app(label)
        require(any(row.get('id') == 'gameplay-option-0' and row.get('checked') == 'true' and UI.exposed(row) for row in raw),
                'Physical question navigation lost the unsubmitted choice')

    def main(self):
        self.device_binding()
        self.baseline = self.requests()
        self.allowed_starts = 1
        initial, _ = self.prepare()
        first, future = initial['levels']
        self.first_level = first['id']
        require(initial['currentIndex'] == 0 and first['autoNext'] is True and first['question'] is not None and
                future['question'] is None, 'The assigned case did not expose exactly the first auto-next question')
        first_title = first['question']['title']
        self.stage = 'initial-focus-and-locked-swipe'
        self.focus_sample('first-entry-focused', first_title, 0)
        self.save_fixture('first-current-second-locked', initial)
        self.rail_at_top('before-locked-swipe', 0, (True, False), first_title)
        self.ui.capture()
        geometry = self.geometry(self.ui.flat, first_title)
        require(geometry is not None and geometry['titleVisible'], 'The exact locked-swipe starting card is unavailable')
        self.swipe_card(geometry, toward_next=True)
        time.sleep(.7)
        self.nav_state('after-locked-swipe', 0, (True, False), first_title)
        self.ledger()
        self.check(True, 'Native first entry focuses without a gesture; at top a physical swipe cannot reach the locked future question')

        self.stage = 'first-correct-and-native-auto-next'
        self.allowed_answers = 1
        self.text_and_submit()
        settled = self.snapshot()
        require(settled['status'] == 'active' and settled['currentIndex'] == 1 and settled['levels'][0]['completedAt'] and
                isinstance(settled['levels'][1]['question'], dict), 'The one correct answer did not unlock the second question')
        self.first_settled = True
        self.save_fixture('first-complete-second-unlocked', settled)
        second_title = settled['levels'][1]['question']['title']
        second = self.focus_sample('second-auto-next-focused', second_title, 1)
        self.ledger()
        self.check(True, 'The real first settlement unlocks the second question and native auto-next focuses it')

        self.stage = 'horizontal-native-swipes'
        self.ui.tap('gameplay-option-0')
        second = self.focus_sample('second-with-draft-before-swipe', second_title, 1, shot=False)
        self.swipe_card(second, toward_next=False)
        self.focus_sample('first-focused-by-swipe', first_title, 0)
        self.assert_settled_readonly(settled['levels'][0]['lastAnswer'])
        self.ui.capture()
        first_geometry = self.geometry(self.ui.flat, first_title)
        require(first_geometry is not None, 'The completed card is outside the viewport for the return swipe')
        self.swipe_card(first_geometry, toward_next=True)
        self.focus_sample('second-focused-by-swipe', second_title, 1)
        self.assert_choice_draft('second-draft-after-swiping-back')
        self.ledger()
        self.check(True, 'Physical horizontal swipes switch both ways between unlocked cards and preserve settled and draft answers')

        self.stage = 'question-number-focus-and-reentry'
        buttons = self.rail_at_top('before-same-current-number', 1, (True, True), second_title)
        self.touch_number(1, buttons[1])
        self.focus_sample('same-current-number-refocused', second_title, 1)
        self.assert_choice_draft('second-draft-after-current-number')
        buttons = self.rail_at_top('before-other-number', 1, (True, True), second_title)
        self.touch_number(0, buttons[0])
        self.focus_sample('other-number-focused', first_title, 0)
        self.return_home()
        before = self.ledger()
        self.ui.tap('assignment-' + self.assignment_id)
        self.wait_question()
        self.focus_sample('reentry-current-focused', second_title, 1)
        require(any(row.get('method') == 'GET' and row.get('path') == self.detail for row in self.ledger()[len(before):]),
                'Reentry did not perform a fresh real assignment GET')
        self.check(True, 'Same-current and other-number taps refocus; reentry uses the fresh server current question')

    def save(self, status):
        report = {'status': 'captured_native_question_swipe' if status != 'incomplete' else status, 'stage': self.stage,
                  'scope': 'One fresh disposable auto-next two-question phone case', 'hapSha256': self.hap_sha,
                  'checksPassed': len(self.checks), 'checks': self.checks, 'states': self.states, 'cleanup': self.cleanup,
                  'bindingSha256': self.binding, 'privateScreenshots': self.ui.private_screenshots,
                  'privateRawEvidence': self.ui.raw_evidence, 'sameDataWebFixtures': self.fixtures,
                  'observations': self.observations, 'fixedPreviewTouched': False, 'failure': self.failure}
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        require(not any(value and value in encoded for value in (*self.secrets(), self.serial)) and
                not re.search(r'https?://', encoded), 'A private literal would enter the swipe report')
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
    for name in ('runtime', 'case-ref', 'device-ref', 'output'):
        run.add_argument('--' + name, type=Path, required=True)
    run.add_argument('--expected-hap', required=True)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return SwipeSample(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Exact swipe case, package, runtime, owner or output guards failed'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

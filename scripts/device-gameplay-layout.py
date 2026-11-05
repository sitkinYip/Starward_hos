#!/usr/bin/env python3
"""Root-reviewed active-case0 layout/Refresh/IME/logout sample; help is inert.

Only Host auth/reads, native GETs and exact detail-GET one-shot test faults.
No start, answer, profile/password write, reset, seed or service operation.
Visual review remains separate from measured interaction checks.
"""
import argparse, datetime, hashlib, importlib.util, json, os, sys, time, urllib.request
from pathlib import Path
from native_device_ui import ROOT, SafeFailure

SPEC = importlib.util.spec_from_file_location('layout_frame_guards', ROOT / 'scripts/device-question-frame.py')
FRAME = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FRAME)
require, UI = FRAME.require, FRAME.UI
OUT = ROOT / 'artifacts/validation/ui-gameplay-layout-20261104'
DRAFT = 'UiLayoutDraftOnly-DoNotSubmit'


class Layout(FRAME.FrameSample):
    def __init__(self, args):
        FRAME.fresh(args.output, OUT)
        super().__init__(args)
        require(self.case['sourceContent']['sourceCaseIndex'] == 0 and self.case['fixtureLevelKinds'] == ['text'],
                'Only explicit real-content case0 text is supported')
        for name, filename in {'layoutDriver': Path(__file__), 'viewModel': ROOT / 'entry/src/main/ets/features/GameplayViewModel.ets',
                'index': ROOT / 'entry/src/main/ets/pages/Index.ets', 'refreshWrapper': ROOT / 'entry/src/main/ets/ui/StarwardRefresh.ets'}.items():
            self.bound[name], self.binding[name] = filename, FRAME.sha(filename)
        self.registered, self.armed = [], False
        self.draft_checks, self.late_evidence = {}, {}
        self.cleanup['faultNeutralised'] = False

    def fault(self, key=None, value=None):
        require((key is None and value is None) or (key == 'status' and type(value) is int and value in (503, 404)) or
                (key == 'responseDelayMs' and type(value) is int and value == 12000), 'The exact detail GET fault is unsupported')
        self.immutable()
        # The runner assigns JSON body directly to fault; JSON null truly clears
        # it. A delay0 object would leave a one-shot fault for the next request.
        body = None if key is None else {'path': self.detail, 'method': 'GET', key: value}
        request = urllib.request.Request(self.control_base + '/fault', data=json.dumps(body).encode(), method='POST',
            headers={'Content-Type': 'application/json', 'Authorization': self.state['controlToken']})
        with self.control_opener.open(request, timeout=20) as response:
            require(response.status == 200 and json.load(response).get('configured') is True, 'The exact GET fault was not registered')
        self.armed = body is not None
        if body is not None:
            self.registered.append({'status': value if key == 'status' else 200, 'delayMs': value if key == 'responseDelayMs' else 0})

    def reads(self):
        return [row for row in self.ledger()[len(self.baseline):] if row.get('method') == 'GET' and row.get('path') == self.detail]

    def verify_ledger(self):
        self.cleanup['zeroForbiddenWrites'] = False
        rows = self.ledger()
        require(rows[:len(self.baseline)] == self.baseline, 'The exact request ledger changed or was truncated')
        added = rows[len(self.baseline):]
        require(all((row.get('method') == 'GET' and row.get('path') in ('/api/health', '/api/questions/v1/me', FRAME.BASE, self.detail)) or
                    (row.get('method') == 'POST' and row.get('path') == FRAME.AUTH) for row in added), 'A forbidden start/answer/business write occurred')
        faults = [row for row in added if row.get('fault')]
        require(len(faults) <= len(self.registered) and all(row.get('method') == 'GET' and row.get('path') == self.detail and
                row.get('status') == plan['status'] and not row.get('responseDropped') and not row.get('responseAwaitingDelay')
                for row, plan in zip(faults, self.registered)), 'An unregistered or unfinished GET fault appeared')
        require(all(row.get('status') == 200 and not row.get('responseDropped') for row in added if not row.get('fault')),
                'An ordinary owned request failed')
        facts = self.facts()
        require(facts.get('startReceiptCount') == facts.get('progressRows') == 1, 'The active single-question entry facts changed')
        self.final_ledger = {'baseline': self.baseline, 'added': added, 'registeredFaults': self.registered}
        self.cleanup['zeroForbiddenWrites'] = True

    def ready(self):
        self.ui.wait(lambda ui: ui.find('gameplay-question-card') is not None and ui.find('gameplay-loading') is None and
                     ui.find('gameplay-refresh-error') is None, 'active page ready after exact GET')

    def reenter(self):
        self.ui.back()
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('gameplay-page') is None, 'Back to same-account home')
        self.ui.tap('assignment-' + self.assignment_id)
        self.ready()

    def pull(self):
        # Never use inherited scroll_top(): a finger-down search would refresh.
        self.ui.capture()
        view = self.ui.viewport('gameplay-page')
        require(UI.positive(view) and view[3] - view[1] > 220 * self.ui.density, 'The measured pull viewport is too small')
        x, start = round((view[0] + view[2]) / 2), round(view[1] + 32 * self.ui.density)
        end = round(min(view[3] - 20 * self.ui.density, start + 160 * self.ui.density))
        self.ui.run('devecocli', 'ui', 'swipe', x, start, x, end, '--speed', 600)

    def geometry(self, label):
        self.ui.capture()
        bars = [node for node in self.ui.path_to('account-menu') or []
                if node.get('type') in ('TitleBar', 'NavDestinationTitleBar') and node.get('bounds')]
        require(len(bars) == 1, 'A unique actual native title bar is required')
        raw, record = self.ui.raw_app(label)
        card, bar = UI.rect(FRAME.own(raw, 'gameplay-question-card')['bounds']), UI.rect(bars[0]['bounds'])
        return card, bar, raw, record

    def quantitative_top(self, label):
        before, density = len(self.reads()), self.ui.density
        for index in range(12):
            card, bar, _, _ = self.geometry('top-' + label + '-' + str(index))
            remaining = bar[3] + 16 * density - card[1]
            require(len(self.reads()) == before, 'Quantitative return-to-top triggered an extra GET')
            if abs(remaining) <= 2:
                self.draft_checks['quantitativeTopNoExtraGet-' + label] = True
                return
            if remaining < 0:
                time.sleep(.2)  # Let an observed small edge rebound settle; do not drag again.
                continue
            view = self.ui.viewport('gameplay-page')
            require(UI.positive(view) and view[3] - view[1] > 160 * density, 'The actual return-to-top viewport is too small')
            # Distance is derived anew from the raw card offset, with only8vp
            # touch-slop allowance. The GET ledger must remain unchanged.
            distance = min(remaining + 8 * density, (view[3] - view[1]) * .4)
            x, center = round((view[0] + view[2]) / 2), round((view[1] + view[3]) / 2)
            self.ui.run('devecocli', 'ui', 'swipe', x, round(center - distance / 2), x, round(center + distance / 2), '--speed', 600)
        raise SafeFailure('Raw geometry did not confirm page top without an additional GET')

    def draft(self, label, initial=False, empty=False):
        raw, _ = self.ui.raw_app('input-' + label)
        rows = [row for row in raw if row.get('id') == 'gameplay-answer-input']
        require(len(rows) == 1 and rows[0].get('text', '') == ('' if empty else DRAFT), 'The actual input draft did not match its required state')
        identity = {key: rows[0].get(key) for key in ('accessibilityId', 'hashcode')}
        require(all(type(value) in (str, int) and bool(value) for value in identity.values()), 'Raw input instance identity is absent')
        if initial:
            self.input_identity = identity
        elif not empty:
            require(identity == self.input_identity, 'The raw input instance changed across a retained refresh or sidebar')
        FRAME.write_private(self.directory / ('input-instance-' + label + '.json'), {'identity': identity, 'draftMatches': True},
                            (self.case['newPassword'], self.state['controlToken'], self.token))
        self.draft_checks[label] = True

    def sample(self, theme):
        card, bar, raw, record = self.geometry('layout-' + theme)
        gap = (card[1] - bar[3]) / self.ui.density
        visible = [row for row in raw if UI.exposed(row)]
        require(abs(gap - 16) <= 2 / self.ui.density and FRAME.own(raw, 'detail-progress'), 'The natural-top card gap is16vp with valid header facts')
        require(not any(row.get('id') in ('gameplay-title', 'gameplay-progress', 'gameplay-leave') or
                        row.get('text') in ('同步进度', '回到首页') for row in visible), 'Duplicate or permanent gameplay blocks remain visible')
        self.ui.private_shot('layout-' + theme)
        self.states.append({'themeRequested': theme, 'titleBarBoundsPx': bar, 'cardBoundsPx': card,
                            'titleBarToCardVp': gap, 'rawSha256': record['sha256']})
        self.check(True, 'Natural-top layout has16vp card separation and no duplicate or permanent controls')

    def fast_late_logout(self):
        observed = time.monotonic()
        require(self.reads()[-1].get('responseAwaitingDelay') is True, 'The late GET is no longer awaiting before the menu')
        self.late_evidence = {'delayMs': 12000, 'awaitingBeforeMenu': True}
        self.ui.run('devecocli', 'ui', 'click', '--id', 'account-menu')
        self.ui.wait(lambda ui: ui.find('account-side-panel') is not None and ui.find('logout') is not None, 'own logout panel over pending gameplay')
        require(self.reads()[-1].get('responseAwaitingDelay') is True and
                UI.inside(UI.rect(self.ui.find('logout')['bounds']), self.ui.app_rect()), 'Pending delivery or visible own logout was lost')
        self.late_evidence['awaitingWithPanel'] = True
        self.ui.run('devecocli', 'ui', 'click', '--id', 'logout')
        self.ui.wait(lambda ui: all(ui.find(key) is not None and not ui.find(key).get('text', '') for key in ('account', 'password')) and
                     all(ui.find(key) is None for key in ('gameplay-page', 'question-title', 'detail-progress')), 'empty login after direct menu logout')
        require(self.reads()[-1].get('responseAwaitingDelay') is True, 'The response arrived before logout; no late-boundary pass is claimed')
        self.late_evidence.update({'awaitingAfterEmptyLogin': True, 'logoutElapsedMsFromAwaitingObservation': round((time.monotonic() - observed) * 1000)})
        self.cleanup.update({'loggedOut': True, 'loginInputsEmpty': True, 'privateGameplayAbsent': True})

    def main(self):
        self.stage = 'active-case0-prerequisites'
        auth = self.request(False, FRAME.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str), 'The same ordinary case0 account is required')
        self.token, self.dto = auth['token'], None
        self.dto = self.snapshot()
        self.question()
        require(self.facts().get('startReceiptCount') == 1, 'Case0 must already be active with one entry receipt')
        self.fixture = FRAME.write_private(self.directory / 'web-dtos.json', self.dto, (self.case['newPassword'], self.state['controlToken'], self.token))
        self.baseline = self.ledger()
        self.device_started = True
        self.ui.launch(cold=True)
        self.ui.wait(lambda ui: ui.find('account') is not None, 'empty own login')
        require(self.ui.input_empty('account') and self.ui.input_empty('password') and self.ui.has_text('隔离测试环境'), 'The isolated login must start empty')
        self.ui.fill('account', self.case['account']); self.ui.fill('password', self.case['newPassword']); self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('old-password') is None, 'ordinary direct home')
        self.ui.tap('assignment-' + self.assignment_id); self.ready()
        for theme in ('light', 'dark'):
            self.theme(theme)
            if theme == 'dark': self.reenter()
            self.sample(theme)
        self.stage = 'native-refresh-success-and-failures'
        self.ui.fill_without_dismiss('gameplay-answer-input', DRAFT)
        self.draft('refresh-initial', initial=True)
        self.ui.hide_keyboard()
        self.quantitative_top('before-success')
        before = len(self.reads()); self.pull()
        self.ui.wait(lambda ui: len(self.reads()) == before + 1 and self.reads()[-1].get('status') == 200, 'one real pull GET')
        self.ready()
        self.draft('after-success')
        self.check(True, 'One pull GET retains the exact raw input instance and its real unsubmitted draft')
        before = len(self.reads()); self.fault('status', 503); self.pull()
        self.ui.wait(lambda ui: ui.find('gameplay-refresh-error') is not None and ui.find('gameplay-refresh-retry') is not None, 'transient refresh error')
        require(len(self.reads()) == before + 1 and self.reads()[-1].get('status') == 503, 'The exact injected503 GET was not consumed')
        self.armed = False
        require(self.ui.find('gameplay-question-card') is not None and self.ui.find('detail-progress') is not None, 'Transient refresh lost its retained facts')
        self.draft('after-503')
        self.ui.private_shot('refresh-503')
        self.ui.tap('gameplay-refresh-retry')
        self.ui.wait(lambda ui: len(self.reads()) == before + 2 and self.reads()[-1].get('status') == 200, 'explicit successful retry GET')
        self.ready()
        self.draft('after-retry')
        require(len(self.reads()) == before + 2 and self.reads()[-1].get('status') == 200, 'Explicit refresh retry did not perform one GET')
        self.check(True, '503 and explicit retry preserve the same raw input instance and draft')
        self.quantitative_top('before-fatal')
        self.draft('before-fatal')
        before = len(self.reads())
        self.fault('status', 404)
        self.pull()
        self.ui.wait(lambda ui: ui.find('request-retry') is not None and ui.find('gameplay-question-card') is None and
                     ui.find('detail-progress') is None and ui.find('gameplay-answer-input') is None, 'fatal404 clears old question, input and header facts')
        require(len(self.reads()) == before + 1 and self.reads()[-1].get('status') == 404, 'The fatal exact GET was not consumed')
        self.armed = False
        self.ui.private_shot('refresh-404')
        self.ui.tap('request-retry')
        self.ready()
        self.draft('cleared-after-fatal', empty=True)
        require(len(self.reads()) == before + 2 and self.ui.find('detail-progress') is not None, 'Reload did not restore authoritative header facts')
        self.check(True, 'Fatal404 removes stale facts/input and reload restores facts with a cleared draft')
        self.stage = 'ime-draft-sidebar'
        self.ui.hide_keyboard(); self.ui.fill_without_dismiss('gameplay-answer-input', DRAFT)
        self.draft('ime-initial', initial=True)
        ime = self.ui.actual_ime('layout-draft'); self.ui.seek('gameplay-submit'); self.ui.capture()
        require(self.ui.keyboard_visible() and all(UI.inside(self.ui.find(key)['bounds'], ime['availableViewportPx'])
                for key in ('gameplay-answer-input', 'gameplay-submit')), 'Input and untouched submit are not inside the actual IME viewport')
        self.ui.private_shot('layout-ime'); self.ui.hide_keyboard()
        self.ui.tap('account-menu'); self.ui.wait(lambda ui: ui.find('account-side-panel') is not None, 'same-page sidebar')
        self.ui.back(); self.ui.wait(lambda ui: ui.find('account-side-panel') is None, 'Back closes only sidebar')
        self.draft('after-sidebar')
        self.check(True, 'Actual IME and sidebar Back preserve the unsubmitted same-page draft')
        self.verify_ledger()
        self.reenter()
        self.stage = 'logout-before-late-get'
        self.fault('responseDelayMs', 12000)
        self.pull()
        self.ui.wait(lambda ui: ui.find('gameplay-page') is not None and ui.find('account-menu') is not None and
                     bool(self.reads()) and self.reads()[-1].get('responseAwaitingDelay') is True, 'exact late GET awaiting delivery in own gameplay')
        self.armed = False
        self.fast_late_logout()
        self.ui.wait(lambda ui: not self.reads()[-1].get('responseAwaitingDelay'), 'late response completes after logout', timeout=15)
        time.sleep(.4); self.ui.capture()
        require(self.ui.input_empty('account') and self.ui.input_empty('password') and all(self.ui.find(key) is None for key in
                ('gameplay-page', 'question-title', 'detail-progress')), 'The late GET restored private content or login inputs')
        self.check(True, 'A real delayed GET completes after logout without restoring the private page')
        self.verify_ledger(); require(len([row for row in self.final_ledger['added'] if row.get('fault')]) == 3, 'Not all three registered GET faults were observed')

    def execute(self):
        try:
            self.main()
        except Exception as error:
            reason = str(error)
            for secret in (self.case['newPassword'], self.state['controlToken'], self.token): reason = reason.replace(secret, '[credential omitted]') if secret else reason
            FRAME.write_private(self.directory / 'failure-diagnostic.json', {'stage': self.stage, 'exceptionType': type(error).__name__, 'reason': reason},
                                (self.case['newPassword'], self.state['controlToken'], self.token))
            self.failure = 'The narrow layout/Refresh run is incomplete; private diagnostics retained'
        finally:
            try:
                self.immutable()
                if self.armed:
                    self.fault()
                self.cleanup['faultNeutralised'] = not self.armed
                if self.device_started:
                    self.logout()
                    self.verify_ledger()
            except Exception:
                self.failure = self.failure or 'Same-owner fault neutralization, logout or zero-write checks were not confirmed'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not all(self.cleanup.values()): self.failure = self.failure or 'Narrow cleanup is incomplete'
        evidence = FRAME.write_private(self.directory / 'request-ledger.json', getattr(self, 'final_ledger', {}), (self.case['newPassword'], self.state['controlToken'], self.token))
        report = {'status': 'incomplete' if self.failure else 'passed', 'stage': self.stage, 'scope': 'Active case0 layout/Refresh/IME/Back/logout only',
            'hapSha256': self.hap_sha, 'bindingSha256': self.binding, 'checks': self.checks, 'checksPassed': len(self.checks), 'states': self.states,
            'expectedFixtureSha256': self.args.expected_fixture_sha, 'sourceCaseIndex': 0, 'fixedPreviewTouched': False,
            'draftInstanceChecks': self.draft_checks, 'lateGet': self.late_evidence, 'unusedFaultClearPayload': 'JSON null',
            'cleanup': self.cleanup, 'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
            'sameDataWebFixture': getattr(self, 'fixture', None), 'privateReadOnlyLedger': evidence, 'failure': self.failure,
            'visualReview': 'pending_root_original_review', 'startAnswerOrProfileWritesPermitted': False, 'UiRefreshingDirectlyObserved': False,
            'writeScope': 'Host authentication/read; exact own detail-GET faults503/404/12000ms only; JSON null clears an unused own fault',
            'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        require(not any(value and value in encoded for value in (self.case_id, self.case['account'], self.case['newPassword'], self.case['playerId'],
                self.assignment_id, self.case['assignments']['ready']['sessionId'], self.state['controlToken'], self.token, DRAFT)), 'A private literal would enter the report')
        FRAME.fresh(self.report, OUT)
        self.report.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream: stream.write(encoded)
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks), 'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 1 if self.failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action'); run = sub.add_parser('run')
    for name in ('runtime', 'case-ref', 'output', 'private-dir'): run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-hap', 'expected-fixture-sha'): run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return Layout(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded', 'error': 'Exact layout prerequisites/report guards failed; raw values omitted'})); return 1


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Verify the native Aurora lobby with one prepared disposable HTTPS player."""
import argparse
from datetime import datetime
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import ssl
import time
import urllib.request
import uuid
import zipfile

from native_device_ui import DeviceUI, ROOT, SafeFailure, flatten

PRIVATE = ROOT / 'artifacts/private/aurora-glass-v2-20261125/slice-2/disposable'
OUT = ROOT / 'artifacts/validation/aurora-glass-v2-20261125/slice-2/disposable'
ME = '/api/questions/v1/me'
POLL_SECONDS = 5
KINDS = ('ready', 'waiting', 'expired', 'locked')
FIXTURE_LABEL = 'aurora-lobby'


def sibling(filename):
    spec = importlib.util.spec_from_file_location(filename.stem, filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


ENTRY = sibling(ROOT / 'scripts/device-gameplay-entry.py')
PREVIEW = sibling(ROOT / 'scripts/device-aurora-preview-smoke.py')
AUTH, LIST = ENTRY.AUTH, ENTRY.BASE


class CheckFailure(SafeFailure):
    """Only fixed, public-safe diagnostic strings are raised by this driver."""


def require(condition, message):
    if not condition:
        raise CheckFailure(message)


def positive(bounds):
    return bounds and bounds[0] < bounds[2] and bounds[1] < bounds[3]


class LobbyUI(ENTRY.UI.RefinementUI):
    def __init__(self, state, density, directory, serial):
        super().__init__(state, density, directory)
        self.serial = serial

    def run(self, *args, timeout=45):
        if args[:1] == ('hdc',):
            return super().run('hdc', '-t', self.serial, *args[1:], timeout=timeout)
        # The installed DevEco UI CLI chooses the connected target itself.
        output = super().run('hdc', 'list', 'targets')
        targets = [line.strip() for line in output.splitlines() if line.strip() and '[Empty]' not in line]
        require(targets == [self.serial], 'The only connected target must be the explicitly bound disposable phone')
        return super().run(*args, timeout=timeout)

    def capture(self, name=None):
        # Persist only deliberately selected raw evidence from the signed App.
        return DeviceUI.capture(self)

    def section(self, name):
        pane = self.find('journey-panes')
        scroll = self.find(name + '-scroll')
        if not pane or not scroll or not positive(pane.get('bounds')) or not positive(scroll.get('bounds')):
            return None
        panel, usable = pane['bounds'], scroll['bounds']
        overlap_width = min(panel[2], usable[2]) - max(panel[0], usable[0])
        overlap_height = min(panel[3], usable[3]) - max(panel[1], usable[1])
        path = self.path_to(name + '-scroll')
        if (overlap_width >= (panel[2] - panel[0]) * .9 and overlap_height >= (panel[3] - panel[1]) * .9 and
                any(node is pane for node in path or [])):
            return scroll
        return None

    def select(self, name):
        PREVIEW.select_journey_section(self, name, require)
        self.wait(lambda ui: ui.section(name), 'selected native journey viewport')


class LobbyCheck:
    def __init__(self, args):
        self.state = ENTRY.read_state(args.backend_commit)
        ref = json.loads(ENTRY.guarded(args.case_ref, PRIVATE, True).read_text())
        device = json.loads(ENTRY.guarded(args.device_ref, PRIVATE, True).read_text())
        case_id = ref.get('caseId', '')
        serial = device.get('deviceSerial', '')
        require(set(ref) == {'caseId'} and re.fullmatch(r'[a-f0-9]{16}', case_id) and
                set(device) == {'deviceSerial'} and re.fullmatch(r'[A-Za-z0-9]{8,80}', serial),
                'The private fixture and phone references are invalid')
        self.case_id = case_id
        self.case = self.state['gameplay']['cases'].get(case_id, {})
        require(self.case.get('label') == FIXTURE_LABEL and self.case.get('setupStatus') == 'ready' and
                self.case.get('ordinaryLoginPrepared') is True and set(self.case.get('assignments', {})) == set(KINDS) and
                re.fullmatch(r'hm_[a-f0-9]{12}', self.case.get('account', '')) and
                re.fullmatch(r'[a-z0-9]{15}', self.case.get('playerId', '')) and len(self.case.get('newPassword', '')) >= 24,
                'Only the prepared ordinary aurora-lobby case is authorized')
        self.ids = {kind: self.case['assignments'][kind].get('assignmentId', '') for kind in KINDS}
        require(len(set(self.ids.values())) == len(KINDS) and all(re.fullmatch(r'[a-z0-9]{15}', v) for v in self.ids.values())
                and self.state['assignmentId'] not in self.ids.values(), 'The fixture does not own four fresh assignments')
        self.detail = LIST + '/' + self.ids['locked']

        tls = self.state['tls']
        self.host = ENTRY.loopback(tls['hostBase'], 'https')
        self.control_base = ENTRY.loopback(self.state['controlBase'], 'http')
        ca = ENTRY.guarded(ENTRY.ISOLATION / 'tls/ca.pem', ENTRY.ISOLATION)
        ca_sha = ENTRY.sha(ca)
        require(tls.get('base') == 'https://127.0.0.1:18443' and tls.get('caPath') == str(ca) and
                tls.get('caSha256') == ca_sha, 'The disposable runner CA does not match its TLS receipt')
        hap = ENTRY.guarded(args.hap, ROOT)
        runtime_path = ENTRY.guarded(args.runtime_report, ROOT / 'artifacts/validation')
        runtime = json.loads(runtime_path.read_text())
        hap_sha = ENTRY.sha(hap)
        density = runtime.get('window', {}).get('density')
        require(runtime.get('status') == 'passed' and runtime.get('installedHapSha256') == hap_sha and
                all(runtime.get('checks', {}).get(key) is True for key in ENTRY.CHECKS) and
                runtime.get('window', {}).get('fontScale') == 1 and
                type(density) in (int, float) and math.isfinite(density) and density > 0,
                'The exact disposable HAP requires a fresh passing runtime and measured default font')
        with zipfile.ZipFile(hap) as archive:
            configs = [name for name in archive.namelist() if name.endswith('/rawfile/integration.json')]
            authorities = [name for name in archive.namelist() if name.endswith('/rawfile/integration-ca.pem')]
            require(len(configs) == len(authorities) == 1 and
                    hashlib.sha256(archive.read(authorities[0])).hexdigest() == ca_sha,
                    'The exact signed HAP must embed the disposable runner CA')
            config = json.loads(archive.read(configs[0]))
            require(config.get('isolated') is True and config.get('probeTls') is True and
                    config.get('endpoint') == tls['base'], 'The signed HAP is not the designated disposable HTTPS build')

        context = ssl.create_default_context(cafile=str(ca))
        self.host_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), ENTRY.NoRedirect(),
                                                      urllib.request.HTTPSHandler(context=context))
        self.control_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), ENTRY.NoRedirect())
        directory = PRIVATE / ('run-' + uuid.uuid4().hex)
        directory.mkdir(mode=0o700)
        self.ui = LobbyUI({'account': self.case['account'], 'newPassword': self.case['newPassword'],
                           'controlToken': self.state['controlToken']}, density, directory, serial)
        self.report = {'status': 'incomplete', 'stage': 'private-prerequisites', 'checks': [],
                       'installedHapSha256': hap_sha, 'runtimeSha256': ENTRY.sha(runtime_path),
                       'driverSha256': ENTRY.sha(__file__), 'fixture': FIXTURE_LABEL,
                       'backendSourceCommit': args.backend_commit}
        self.logged_in = False
        self.fault_armed = False

    def http(self, opener, base, path, body=None, token=''):
        return ENTRY.EntryMain.request(self, opener, base, path, body, token)

    def control(self, path, body=None):
        require(path in ('/requests', '/case-progress', '/fault'), 'Unknown disposable control action')
        return self.http(self.control_opener, self.control_base, path, body or {}, self.state['controlToken'])

    @staticmethod
    def ledger_key(row):
        return row['time'], row['method'], row['path']

    def ledger(self):
        rows = self.control('/requests').get('requests')
        require(isinstance(rows, list), 'The disposable ledger is absent')
        return rows

    def cursor(self):
        rows = self.ledger()
        return self.ledger_key(rows[-1]) if rows else None

    def after(self, cursor):
        rows = self.ledger()
        if cursor is None:
            require(len(rows) < 1000, 'The disposable ledger exceeded the run evidence window')
            return rows
        positions = [index for index, row in enumerate(rows) if self.ledger_key(row) == cursor]
        require(len(positions) == 1, 'The disposable ledger cursor was lost or ambiguous')
        return rows[positions[0] + 1:]

    def wait_read(self, cursor, path, status=200, fault=False, timeout=18):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            matching = [row for row in self.after(cursor) if row['method'] == 'GET' and row['path'] == path]
            if matching and matching[0].get('status'):
                first = matching[0]
                require(first['status'] == status and first.get('fault') is fault and
                        first.get('authenticated') is True and first.get('bearer') is False,
                        'The first isolated GET did not have the expected status, fault and authenticated headers')
                return first
            time.sleep(.15)
        raise CheckFailure('The expected isolated GET did not finish')

    def snapshot(self):
        credentials = {'identity': self.case['account'], 'password': self.case['newPassword']}
        auth = self.http(self.host_opener, self.host, AUTH, credentials)
        token = auth.get('token')
        require(token and auth.get('record', {}).get('id') == self.case['playerId'],
                'Host HTTPS authentication returned a different fixture player')
        player = self.http(self.host_opener, self.host, ME, token=token)
        data = self.http(self.host_opener, self.host, LIST, token=token)
        items = data.get('items', [])
        require(player.get('id') == self.case['playerId'] and player.get('mustChangePassword') is False and
                len(items) == len(self.ids) and {item['id'] for item in items} == set(self.ids.values()) and
                all(item.get('status') == 'assigned' and item.get('completedLevels') == 0 for item in items),
                'The authoritative fresh lobby must contain four unstarted current assignments and no history')
        locked = next(item for item in items if item['id'] == self.ids['locked'])
        require(locked['minLevel'] > player['level']['order'], 'The fixture must actually be locked by server rank')
        return items[0]['id'], locked['minLevel']

    def progress(self):
        result = {}
        counters = ('progressRows', 'completedProgressRows', 'wrongCountTotal', 'answerSubmissionCount',
                    'lockedProgressRows', 'xpLedgerCount', 'xpDeltaSum', 'startReceiptCount',
                    'answerReceiptCount', 'playerTotalXp')
        for kind in KINDS:
            facts = self.control('/case-progress', {'caseId': self.case_id, 'kind': kind})
            require(facts.get('caseId') == self.case_id and facts.get('assignmentKind') == kind and
                    facts.get('readOnlyDiagnostic') is True and facts.get('rawAnswersOrCredentialsReturned') is False and
                    facts.get('assignmentStatus') == 'assigned' and facts.get('startedAtPresent') is False and
                    facts.get('completedAtPresent') is False and all(facts.get(key) == 0 for key in counters),
                    'The case progress, command or experience facts are no longer pristine')
            result[kind] = facts
        return result

    def verify_initial_error(self):
        ui = self.ui
        self.report['stage'] = 'native-first-load-503'
        ui.launch(cold=True)
        ui.wait(lambda value: value.find('account') or value.find('lobby-identity'), 'isolated login gate')
        require(ui.find('account') is not None and ui.input_empty('account') and ui.input_empty('password'),
                'The disposable phone must start with empty login controls')
        ui.fill('account', self.case['account'])
        ui.fill('password', self.case['newPassword'])
        cursor = self.cursor()
        self.control('/fault', {'path': LIST, 'method': 'GET', 'status': 503,
                               'body': {'error': {'code': 'TEST_FAULT', 'message': '隔离首载重试'}}})
        self.fault_armed = True
        self.logged_in = True
        ui.tap('primary-action')
        failed = self.wait_read(cursor, LIST, status=503, fault=True)
        self.fault_armed = False
        def initial_error(value):
            current = value.section('current')
            ids = {node.get('id') for node in flatten(current)} if current is not None else set()
            return {'error-message', 'request-retry'}.issubset(ids)

        ui.wait(initial_error, 'first request error and retry')
        require(not any(node.get('id') in ('assignment-' + key for key in self.ids.values()) for node in ui.flat)
                and ui.find('journey-current-empty') is None, 'An initial 503 showed cards or a false empty result')
        current = ui.section('current')
        retry = next(node for node in flatten(current) if node.get('id') == 'request-retry').get('bounds')
        require(positive(retry) and ENTRY.UI.inside(retry, current['bounds']),
                'The first-load retry is not a visible native action')
        begin = time.time()
        ui.run('devecocli', 'ui', 'click', (retry[0] + retry[2]) // 2, (retry[1] + retry[3]) // 2)
        recovered = self.wait_read(self.ledger_key(failed), LIST)
        recovered_at = datetime.fromisoformat(recovered['time'])
        elapsed = (recovered_at - datetime.fromisoformat(failed['time'])).total_seconds()
        require(recovered_at.timestamp() >= begin and 0 <= elapsed < POLL_SECONDS,
                'Recovery was not isolated from the later automatic poll')
        ui.wait(lambda value: value.section('current') and value.find('assignment-' + self.ids['ready']) and
                value.find('error-message') is None, 'real assignments after retry')
        self.report['checks'].append('First native list GET returned injected 503, showed retry, and recovered by real GET')

    def verify_lock(self, minimum):
        ui = self.ui
        self.report['stage'] = 'native-locked-card'
        card = PREVIEW.seek_journey_item(ui, 'current', 'assignment-' + self.ids['locked'],
                                        44 * ui.density - 1, require)
        require(card['type'] == 'Button' and any(node.get('text') == 'Lv.' + str(minimum) for node in flatten(card)) and
                ui.find('journey-progress-' + self.ids['locked']) is None,
                'The native locked card must show its server minimum and omit the progress ring')
        x0, y0, x1, y1 = card['bounds']
        cursor = self.cursor()
        ui.run('devecocli', 'ui', 'click', x0 + (x1 - x0) // 3, (y0 + y1) // 2)
        self.wait_read(cursor, self.detail)
        ui.wait(lambda value: value.find('detail-state-hint') and value.find('start-assignment'), 'locked briefing')
        require(ui.find('detail-state-hint').get('text') == '等级暂不符合，请确认场次的参与等级。',
                'The locked briefing does not explain its authoritative level restriction')
        rows, evidence = ui.raw_app('aurora-locked-briefing')
        starts = [row for row in rows if row.get('id') == 'start-assignment']
        require(len(starts) == 1 and starts[0].get('enabled') in (False, 'false'),
                'The raw native layout did not confirm a disabled entrance control')
        self.report['lockedRawLayoutSha256'] = evidence['sha256']
        ui.back()
        ui.wait(lambda value: value.section('current') and value.find('detail-state-hint') is None,
                'back to the current journey list')
        self.report['checks'].append('Whole locked card opened real briefing and its native entry is disabled')

    def verify_history_and_refresh(self, first):
        ui = self.ui
        self.report['stage'] = 'native-history-empty'
        ui.select('history')
        ui.wait(lambda value: value.section('history') and value.find('journey-history-empty'), 'empty real history')
        history = ui.section('history')
        require(any(node.get('text') == '故事的第一页，还空着。' for node in flatten(history)) and
                not any((node.get('id') or '').startswith('assignment-' + key)
                        for node in flatten(history) for key in self.ids.values()), 'The history viewport is not empty')
        ui.select('current')
        self.report['checks'].append('Official history segment shows the empty state for the real fixture')

        self.report['stage'] = 'native-pull-to-refresh'
        for _ in range(5):
            ui.capture()
            card = ui.find('assignment-' + first)
            scroll = ui.section('current')
            if (card is not None and scroll is not None and abs(card['bounds'][1] - scroll['bounds'][1]) <= 8 and
                    card['bounds'][3] - card['bounds'][1] >= 94 * ui.density - 1):
                break
            ui.swipe('up')
        else:
            require(False, 'The complete first assignment was not at the real current Scroll origin')
        left, top, right, bottom = scroll['bounds']
        require(right - left > 100 and bottom - top > 300, 'The active Scroll viewport is too small for the gesture')
        anchor = self.wait_read(self.cursor(), LIST)
        begin = time.time()
        x = left + (right - left) // 2
        ui.run('devecocli', 'ui', 'swipe', x, top + (bottom - top) // 5, x, top + (bottom - top) * 3 // 4)
        manual = self.wait_read(self.ledger_key(anchor), LIST, timeout=POLL_SECONDS)
        difference = (datetime.fromisoformat(manual['time']) - datetime.fromisoformat(anchor['time'])).total_seconds()
        require(datetime.fromisoformat(manual['time']).timestamp() >= begin and 0 <= difference < POLL_SECONDS and
                sum(row['method'] == 'GET' and row['path'] == LIST for row in self.after(self.ledger_key(anchor))) == 1,
                'A single real gesture-triggered GET was not isolated from the five-second poll')
        self.report['refreshLatencyFromPriorPollMs'] = round(difference * 1000)
        self.report['checks'].append('One real assignments GET followed the official pull gesture before the next poll')

    def cleanup(self):
        if self.fault_armed:
            self.control('/fault', {'path': '/__aurora_lobby_unused_fault__', 'method': 'GET', 'status': 503})
        if not self.logged_in:
            return
        ui = self.ui
        ui.capture()
        if ui.find('detail-state-hint') or (ui.find('return-home') and not ui.find('nav-profile')):
            ui.back()
            ui.wait(lambda view: view.find('nav-profile'), 'owned lobby after back')
        if ui.find('nav-profile'):
            ui.tap('nav-profile')
            ui.wait(lambda view: view.find('profile-account'), 'isolated profile identity')
            require(ui.find('profile-account').get('text') == self.case['account'],
                    'Cleanup cannot sign out a different identity')
            ui.tap('logout')
        ui.wait(lambda view: view.find('account') and view.find('password'), 'disposable test signout')
        require(ui.input_empty('account') and ui.input_empty('password'), 'Disposable login inputs were not cleared')
        self.report['disposableSignedOut'] = True

    def execute(self):
        baseline, cursor = None, None
        try:
            self.report['stage'] = 'authoritative-disposable-snapshot'
            first, minimum = self.snapshot()
            baseline = self.progress()
            cursor = self.cursor()
            self.verify_initial_error()
            self.verify_lock(minimum)
            self.verify_history_and_refresh(first)
            self.report['stage'] = 'reconcile-and-signout'
        except CheckFailure as error:
            self.report['failure'] = str(error)
        except Exception:
            self.report['failure'] = 'The device or disposable HTTPS check could not finish. Private details omitted.'
        try:
            self.cleanup()
        except Exception:
            self.report['cleanupIncomplete'] = True
        try:
            if baseline is not None:
                ledger = self.after(cursor)
                writes = sum(row['method'] != 'GET' and (row['method'], row['path']) != ('POST', AUTH)
                             for row in ledger)
                self.report['forbiddenRequestCount'] = writes
                self.report['unchangedProgress'] = self.progress() == baseline
                require(writes == 0 and self.report['unchangedProgress'], 'The immutable progress or request guard failed')
        except Exception:
            self.report['reconcileIncomplete'] = True
        if (self.report['stage'] == 'reconcile-and-signout' and self.report.get('disposableSignedOut') and
                not any(key in self.report for key in ('failure', 'cleanupIncomplete', 'reconcileIncomplete')) and
                self.ui.remote_cleanup_ok):
            self.report.update(status='passed', stage='complete')
        return self.report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run')
    run.add_argument('--case-ref', type=Path, required=True)
    run.add_argument('--device-ref', type=Path, required=True)
    run.add_argument('--runtime-report', type=Path, required=True)
    run.add_argument('--backend-commit', required=True, help='Exact source commit of the disposable backend')
    run.add_argument('--hap', type=Path, default=ENTRY.HAP)
    run.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    output = args.output.absolute()
    try:
        require(re.fullmatch(r'[a-f0-9]{40}', args.backend_commit), 'Set the full disposable backend commit')
        require(output.suffix == '.json' and output.resolve().is_relative_to(OUT.resolve()) and not output.exists() and
                not any(path.is_symlink() for path in (output, *output.parents)), 'Choose a fresh Aurora disposable report')
        output.parent.mkdir(parents=True, exist_ok=True)
        report = LobbyCheck(args).execute()
        descriptor = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(descriptor, 'w') as stream:
            json.dump(report, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
        print(json.dumps({'status': report['status'], 'stage': report['stage'], 'checks': len(report['checks'])}))
        return 0 if report['status'] == 'passed' else 1
    except Exception:
        print(json.dumps({'status': 'guarded', 'error': 'Private fixture, disposable HAP or report guard did not complete'}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

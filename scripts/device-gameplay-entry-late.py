#!/usr/bin/env python3
"""Root-only pending-entry logout check; default help is inert.

Full acceptance requires the exact current App process's probe-only receipt after
transport.send and before assertCurrent. Missing client receipt stays unverified.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from native_device_ui import ROOT, SafeFailure

SPEC = importlib.util.spec_from_file_location('entry_recovery_reused',
                                             ROOT / 'scripts/device-gameplay-entry-recovery.py')
RECOVERY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RECOVERY)
ENTRY = RECOVERY.ENTRY


class LateEntry(RECOVERY.RecoveryEntry):
    def __init__(self, args):
        super().__init__(args)
        self.bound['lateDriver'] = Path(__file__)
        self.binding['lateDriver'] = ENTRY.sha(Path(__file__))
        source = ROOT / 'entry/src/main/ets/data/HttpsGameRepository.ets'
        self.bound['clientBoundarySource'] = source
        self.binding['clientBoundarySource'] = ENTRY.sha(source)
        boundary = source.read_text()
        ENTRY.require(re.search(
            r"const response: TransportResponse = await this\.transport\.send\(request\);\s*"
            r"if \(this\.probeBoundary.*?hilog\.info\(0x0000, 'StarwardGameBoundary', "
            r"'operation=start received=%\{public\}d sessionCurrent=%\{public\}s',\s*"
            r"response\.status, \(generation === this\.generation\)\.toString\(\)\);\s*}\s*"
            r"this\.assertCurrent\(generation\);\s*return response;", boundary, re.S),
            'The bound client receipt is not immediately before stale-session rejection')
        self.client_pid = None
        self.log_process = None
        self.log_sink = None
        self.log_file = None
        self.log_offset = 0
        self.client_delivery_observed = False

    def current_pid(self):
        values = self.ui.run('hdc', 'shell', 'pidof', 'com.sitkin.starward').strip().split()
        ENTRY.require(len(values) == 1 and re.fullmatch(r'[1-9][0-9]*', values[0]),
                      'The own App has no unique current process')
        return values[0]

    def begin_client_capture(self):
        self.client_pid = self.current_pid()
        self.log_file = self.directory / 'late-client-boundary.log'
        descriptor = os.open(self.log_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        self.log_sink = os.fdopen(descriptor, 'wb', buffering=0)
        self.log_process = subprocess.Popen(
            ['hdc', 'shell', 'hilog', '-T', 'StarwardGameBoundary', '-P', self.client_pid],
            cwd=ROOT, stdin=subprocess.DEVNULL, stdout=self.log_sink, stderr=subprocess.STDOUT)
        time.sleep(.5)
        ENTRY.require(self.log_process.poll() is None, 'The own client-boundary capture stopped before the entry')
        self.log_offset = self.log_file.stat().st_size

    def matching_client_receipts(self):
        if not self.log_file:
            return 0
        with self.log_file.open('rb') as stream:
            stream.seek(self.log_offset)
            value = stream.read().decode('utf-8', errors='replace')
        count = 0
        for line in value.splitlines():
            match = re.fullmatch(
                r'\s*\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+(\d+)\s+\d+\s+[DIWEF]\s+'
                r'\S*/StarwardGameBoundary:\s*(.*?)\s*', line)
            if match and match[1] == self.client_pid and match[2] == 'operation=start received=200 sessionCurrent=false':
                count += 1
        return count

    def stop_client_capture(self):
        if self.log_process is not None:
            if self.log_process.poll() is None:
                self.log_process.terminate()
                try:
                    self.log_process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.log_process.kill()
                    self.log_process.wait(timeout=3)
            self.cleanup['ownClientCaptureStopped'] = self.log_process.poll() is not None
        if self.log_sink is not None:
            self.log_sink.close()
            self.log_sink = None

    def main(self):
        self.prepare(fresh=True)
        self.begin_client_capture()
        avatar = self.ui.find('account-menu')
        ENTRY.require(avatar and avatar.get('bounds') and len(avatar['bounds']) == 4,
                      'The pending brief has no measurable own avatar action')
        box = avatar['bounds']
        x, y = round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2)
        ENTRY.require(0 < x < self.ui.width and 0 < y < self.ui.height, 'The own avatar action is outside the App viewport')
        self.stage = 'native-late-pending'
        self.control('/fault', {'path': self.start, 'method': 'POST', 'responseDelayMs': 12000})
        self.fault_configured = True
        self.ui.run('devecocli', 'ui', 'click', '--id', 'start-assignment')
        deadline = time.monotonic() + 4
        row = None
        while time.monotonic() < deadline:
            rows = self.starts()
            if len(rows) == 1 and rows[0].get('upstreamFinished') is True:
                row = rows[0]
                break
            time.sleep(.1)
        self.check(row and row.get('status') == 200 and row.get('responseAwaitingDelay') is True and
                   row.get('actorVerifiedByBackendResponse') is True,
                   'The real entry is committed while its native response is still delayed')
        pending_seen = time.monotonic()
        self.stage = 'native-late-direct-logout'
        # Official coordinates are taken from the existing brief's own avatar.
        # No Back or navigation-away is used before logout.
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', x, y)
        logout = self.ui.seek('logout', max_swipes=2)
        box = logout['bounds']
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click',
                    round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))
        self.ui.wait(lambda ui: ui.find('account') is not None, 'direct pending logout')
        account, password = self.ui.find('account'), self.ui.find('password')
        self.cleanup['loggedOut'] = True
        self.cleanup['loginInputsEmpty'] = account is not None and password is not None and \
            account.get('text', '') == password.get('text', '') == ''
        self.cleanup['privateGameplayAbsent'] = self.ui.find('gameplay-page') is None and \
            self.ui.find('question-title') is None and self.ui.find('current-tab') is None
        rows = self.starts()
        self.check(self.cleanup['loginInputsEmpty'] and self.cleanup['privateGameplayAbsent'] and
                   len(rows) == 1 and rows[0].get('responseAwaitingDelay') is True,
                   'Direct avatar-menu logout reaches empty authentication before the delayed reply is released')
        at_logout_count = len(self.requests())
        elapsed_ms = round((time.monotonic() - pending_seen) * 1000)
        self.stage = 'native-late-observation'
        deadline = time.monotonic() + 20
        delay_completed = False
        while time.monotonic() < deadline:
            rows = self.starts()
            if len(rows) == 1 and rows[0].get('responseAwaitingDelay') is False:
                delay_completed = True
                break
            time.sleep(.25)
        self.check(delay_completed and rows[0].get('upstreamFinished') is True and rows[0].get('status') == 200,
                   'The proxy finished its response delay after the upstream entry200')
        time.sleep(3)
        ENTRY.require(self.current_pid() == self.client_pid,
                      'The App process changed during the pending response observation')
        client_receipts = self.matching_client_receipts()
        self.client_delivery_observed = client_receipts == 1
        ENTRY.require(client_receipts <= 1, 'The fresh pending entry has duplicate client-boundary receipts')
        self.ui.capture()
        account, password = self.ui.find('account'), self.ui.find('password')
        self.check(account is not None and password is not None and account.get('text', '') == password.get('text', '') == '' and
                   self.ui.find('current-tab') is None and self.ui.find('gameplay-page') is None and
                   self.ui.find('question-title') is None and len(self.requests()) == at_logout_count,
                   'Authentication stays empty with no private page, route restoration or new player request in the observation window')
        self.check(self.entered_facts(self.diagnostic()) and len(self.starts()) == 1,
                   'The disposed player still has exactly its one committed entry and no answer or XP facts')
        self.observations['late'] = {'upstreamCommitted200': True, 'logoutObservedBeforeDelayEnded': True,
            'elapsedFromPendingObservationToLogoutMs': elapsed_ms, 'configuredResponseDelayMs': 12000,
            'proxyDelayFinished': True, 'privateOrNavigationRestoreObserved': False,
            'newPlayerRequestsAfterLogout': 0, 'clientBodyDeliveryObserved': self.client_delivery_observed,
            'staleSessionRejectedBeforeDecode': self.client_delivery_observed,
            'sameColdAppProcessConfirmed': True, 'matchingClientReceiptCount': client_receipts,
            'deliveryMeaning': 'An exact current-process probe line proves transport.send returned200 after logout; the bound next statement rejects the stale generation before decode',
            'acceptanceLimit': None if self.client_delivery_observed else
                'Client receipt was not observed; upstream200 and completed delay alone are insufficient'}
        if self.client_delivery_observed:
            self.check(True, 'The same cold App process received the complete entry200 after logout and rejected its stale session before decode')
        self.ui.private_shot('entry-late-empty-login')
        self.immutable()

    def execute(self):
        self.save('running')
        try:
            self.main()
        except Exception as error:
            self.failure = self.safe_failure(error)
        finally:
            try:
                self.stop_client_capture()
            except Exception:
                self.failure = self.failure or 'The own client-boundary capture cleanup was not confirmed'
            try:
                self.immutable()
                self.control('/fault', {'path': '/__unused_gameplay_entry_fault__', 'method': 'GET', 'status': 503})
                self.cleanup['faultNeutralised'] = True
            except Exception:
                self.failure = self.failure or 'Fault neutralization could not be confirmed for the same environment'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not self.cleanup['remoteRawFilesRemoved']:
                self.failure = self.failure or 'An exact own remote raw file cleanup was not confirmed'
            status = ('passed' if self.client_delivery_observed else 'observed_client_delivery_unverified') if self.failure is None else 'incomplete'
            self.stage = ('late-complete' if self.client_delivery_observed else 'late-complete-delivery-unverified') if self.failure is None else self.stage
            self.save(status)
        print(json.dumps({'status': status, 'checksPassed': len(self.checks),
                          'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 0 if self.failure is None else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-only pending logout; passed requires the exact own-process client receipt')
    run.add_argument('--runtime', type=Path, default=ENTRY.OUT / 'runtime-03.json')
    run.add_argument('--case-ref', type=Path, default=ENTRY.PRIVATE / 'entry-late-case-ref.json')
    run.add_argument('--output', type=Path, default=ENTRY.OUT / 'device-entry-late.json')
    run.add_argument('--expected-hap')
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    args.stage, args.delay_ms = 'late', 10000
    try:
        return LateEntry(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'The explicit late case, runtime or output guards did not complete; values omitted'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())

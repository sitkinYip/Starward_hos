#!/usr/bin/env python3
"""Root-only narrow native entry recovery checks; default help does no IO.

503/drop require separate pristine cases created by Root. read-retry reuses the
already-started main case. This helper never creates/resets a player or answers.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

from native_device_ui import ROOT, SafeFailure

SPEC = importlib.util.spec_from_file_location('entry_main_reused', ROOT / 'scripts/device-gameplay-entry.py')
ENTRY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ENTRY)


class RecoveryEntry(ENTRY.EntryMain):
    def __init__(self, args):
        super().__init__(args)
        self.bound['recoveryDriver'] = Path(__file__)
        self.binding['recoveryDriver'] = ENTRY.sha(Path(__file__))

    def save(self, status):
        result = {'status': status, 'stage': self.stage, 'recoveryKind': self.args.stage,
            'scope': 'Native entry recovery only with controlled disposable faults; no answer acceptance credit',
            'hapSha256': self.hap_sha, 'bindingSha256': self.binding, 'checksPassed': len(self.checks),
            'checks': self.checks, 'observations': self.observations, 'cleanup': self.cleanup,
            'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
            'visualReview': 'pending_root_original_review', 'fixedPreviewTouched': False,
            'privateCredentialsOrRecordIdsPersisted': False,
            'writeScope': 'Native entry attempts only, or GET-only read-retry; Host auth/read and exact fault control. No player creation/reset/answer/profile/password write.'}
        if self.failure:
            result['failure'] = self.failure
        encoded = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
        ENTRY.require(not any(secret and secret in encoded for secret in self.secrets()),
                      'A private literal would enter the public recovery report')
        self.report.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream:
            stream.write(encoded)

    @staticmethod
    def facts(value):
        return {k: value.get(k) for k in ('assignmentStatus', 'startedAtPresent', 'completedAtPresent',
            'progressRows', 'completedProgressRows', 'wrongCountTotal', 'lockedProgressRows',
            'answerSubmissionCount', 'xpLedgerCount', 'xpDeltaSum', 'startReceiptCount', 'startRequestIdSha256')}

    @staticmethod
    def no_answer_or_xp(value):
        return all(type(value.get(k)) is int and value[k] == 0 for k in (
            'completedProgressRows', 'wrongCountTotal', 'lockedProgressRows',
            'answerSubmissionCount', 'xpLedgerCount', 'xpDeltaSum'))

    def entered_facts(self, value):
        return value.get('assignmentStatus') == 'active' and value.get('startedAtPresent') is True and \
            value.get('progressRows') == 2 and value.get('startReceiptCount') == 1 and self.no_answer_or_xp(value)

    def prepare(self, fresh=True):
        self.stage = 'host-prerequisites'
        auth = self.host_read(ENTRY.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        ENTRY.require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str),
                      'Host authentication did not identify the explicit recovery player')
        self.token = auth['token']
        player = self.host_read('/api/questions/v1/me')
        snapshot = self.host_read(self.detail)
        facts = self.diagnostic()
        ENTRY.require(player.get('id') == self.case['playerId'] and player.get('mustChangePassword') is False and
                      snapshot.get('id') == self.assignment_id and snapshot.get('player') == self.case['playerId'],
                      'The recovery snapshot does not belong to the explicit ordinary player')
        if fresh:
            self.check(snapshot.get('status') == 'assigned' and not snapshot.get('startedAt') and
                len(snapshot.get('levels', [])) == 2 and all(x.get('question') is None for x in snapshot['levels']) and
                facts.get('assignmentStatus') == 'assigned' and facts.get('startedAtPresent') is False and
                facts.get('progressRows') == facts.get('startReceiptCount') == 0 and
                self.no_answer_or_xp(facts) and len(self.starts()) == 0,
                'Fresh explicit recovery case has hidden questions and no prior entry facts')
        else:
            self.check(self.entered_facts(facts) and len(self.starts()) == 1 and
                snapshot.get('status') == 'active' and isinstance(snapshot.get('levels', [{}])[0].get('question'), dict),
                'Explicit existing main case is active with exactly one entry and no answers or XP')
        self.ui.launch(cold=True)
        self.ui.wait(lambda ui: ui.find('account') is not None, 'owned empty recovery login')
        self.device_started = True
        ENTRY.require(self.ui.input_empty('account') and self.ui.input_empty('password') and
                      self.ui.has_text('隔离测试环境'), 'Native recovery did not start at empty isolated login')
        self.ui.fill('account', self.case['account'])
        self.ui.fill('password', self.case['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'ordinary recovery home')
        self.ui.tap('assignment-' + self.assignment_id)
        if fresh:
            self.ui.wait(lambda ui: ui.find('start-assignment') is not None, 'fresh recovery detail')
            self.ui.seek('start-assignment')
        else:
            self.wait_question()
        self.check(self.ui.find('old-password') is None, 'Ordinary recovery account reaches its exact native assignment')
        return snapshot, facts

    def wait_question(self):
        self.ui.wait(lambda ui: ui.find('gameplay-page') is not None, 'native gameplay page', timeout=40)
        self.ui.seek('question-title')

    def logout(self):
        self.ui.back()
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('gameplay-page') is None,
                     'home before recovery logout')
        self.ui.tap('account-menu')
        self.ui.tap('logout')
        self.assert_empty_logout()

    def assert_empty_logout(self):
        self.ui.wait(lambda ui: ui.find('account') is not None, 'explicit recovery logout')
        self.cleanup['loggedOut'] = True
        self.cleanup['loginInputsEmpty'] = self.ui.input_empty('account') and self.ui.input_empty('password')
        self.cleanup['privateGameplayAbsent'] = self.ui.find('gameplay-page') is None and self.ui.find('question-title') is None
        self.check(self.cleanup['loginInputsEmpty'] and self.cleanup['privateGameplayAbsent'],
                   'Recovery logout leaves empty login inputs and no private gameplay')

    def entry_retry(self):
        self.prepare(fresh=True)
        self.stage = 'native-' + self.args.stage + '-first-attempt'
        fault = {'path': self.start, 'method': 'POST'}
        fault.update({'status': 503} if self.args.stage == '503' else {'dropResponse': True})
        self.control('/fault', fault)
        self.fault_configured = True
        self.ui.tap('start-assignment')
        self.ui.wait(lambda ui: ui.find('start-assignment') is not None and ui.has_text('重试入场'),
                     'explicit retry after entry failure', timeout=40)
        self.ui.seek('request-retry')
        raw, evidence = self.ui.raw_app('entry-' + self.args.stage + '-error')
        self.check(any(row.get('id') == 'error-message' and row.get('text') and ENTRY.UI.exposed(row) for row in raw) and
                   not any(row.get('id') == 'question-title' for row in raw),
                   'Native entry failure displays a real error and an explicit retry without a private question')
        self.ui.private_shot('entry-' + self.args.stage + '-error')
        first_rows = self.starts()
        first_facts = self.diagnostic()
        ENTRY.require(len(first_rows) == 1 and first_rows[0].get('fault') is True,
                      'The controlled first attempt did not produce exactly one native start')
        if self.args.stage == '503':
            self.check(first_rows[0].get('status') == 503 and first_rows[0].get('upstreamFinished') is not True and
                       first_facts.get('assignmentStatus') == 'assigned' and first_facts.get('startedAtPresent') is False and
                       first_facts.get('progressRows') == first_facts.get('startReceiptCount') == 0 and
                       self.no_answer_or_xp(first_facts),
                       'Injected503 occurs before forwarding and creates no entry, progress or XP facts')
            first_started_at = None
        else:
            self.check(first_rows[0].get('status') == 200 and first_rows[0].get('upstreamFinished') is True and
                       first_rows[0].get('responseDropped') is True and self.entered_facts(first_facts),
                       'Dropped client response follows a real committed entry with two progress rows and one receipt')
            first_started_at = self.host_read(self.detail).get('startedAt')
        self.stage = 'native-' + self.args.stage + '-explicit-retry'
        self.ui.tap('request-retry')
        self.wait_question()
        rows = self.starts()
        facts = self.diagnostic()
        after = self.host_read(self.detail)
        self.check(self.entered_facts(facts) and len(rows) == 2 and rows[1].get('status') == 200 and
                   rows[1].get('fault') is False and rows[1].get('actorVerifiedByBackendResponse') is True and
                   (first_started_at is None or after.get('startedAt') == first_started_at),
                   'Explicit frozen retry restores the real current question without duplicate entry facts')
        keys = ('requestIdSha256', 'requestBodySha256', 'actorSha256')
        self.check(all(re.fullmatch(r'[a-f0-9]{64}', row.get(key, '') or '') for row in rows for key in keys) and
                   all(rows[0][key] == rows[1][key] for key in keys) and
                   rows[1].get('matchesPriorRequestIdentity') is True and
                   all(row.get('authenticated') is True and row.get('bearer') is False for row in rows),
                   'Real native retry preserves the exact request ID, body and account identity with raw Authorization')
        self.observations['retry'] = {'requestCount': 2, 'sameRequestIdBodyActor': True,
            'progressRows': 2, 'startReceiptCount': 1, 'answerSubmissionCount': 0, 'xpLedgerCount': 0,
            'firstResponseDroppedAfterCommit': self.args.stage == 'drop', 'rawErrorEvidenceSha256': evidence['sha256']}
        self.ui.private_shot('entry-' + self.args.stage + '-recovered')
        self.logout()
        self.immutable()

    def read_retry(self):
        _, baseline = self.prepare(fresh=False)
        self.stage = 'native-read-failure'
        before_gets = sum(row.get('method') == 'GET' and row.get('path') == self.detail for row in self.requests())
        self.control('/fault', {'path': self.detail, 'method': 'GET', 'status': 503})
        self.fault_configured = True
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('gameplay-page') is not None and ui.find('error-message') is not None,
                     'native read failure')
        self.ui.seek('request-retry')
        raw, evidence = self.ui.raw_app('entry-read-error')
        self.check(any(row.get('id') == 'error-message' and row.get('text') and ENTRY.UI.exposed(row) for row in raw) and
                   not any(row.get('id') in ('question-title', 'gameplay-progress', 'gameplay-question-card') for row in raw),
                   'Read failure shows its native error without question content or empty-model body progress')
        self.ui.private_shot('entry-read-error')
        self.stage = 'native-read-retry'
        self.ui.tap('request-retry')
        self.wait_question()
        rows = [row for row in self.requests() if row.get('method') == 'GET' and row.get('path') == self.detail]
        delta = rows[before_gets:]
        self.check(len(delta) == 2 and delta[0].get('status') == 503 and delta[0].get('fault') is True and
                   delta[1].get('status') == 200 and delta[1].get('fault') is False and
                   self.facts(self.diagnostic()) == self.facts(baseline) and len(self.starts()) == 1,
                   'Explicit read retry makes a fresh real GET and restores the question without another entry or business write')
        self.observations['readRetry'] = {'getRequests': 2, 'firstFault503': True, 'secondReal200': True,
            'startCountStillOne': True, 'authoritativeFactsUnchanged': True, 'rawErrorEvidenceSha256': evidence['sha256']}
        self.ui.private_shot('entry-read-recovered')
        self.logout()
        self.immutable()

    def main(self):
        if self.args.stage == 'read-retry':
            self.read_retry()
        else:
            self.entry_retry()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-only real phone stage, explicit case and current HAP/runtime required')
    run.add_argument('--stage', choices=('503', 'drop', 'read-retry'), required=True)
    run.add_argument('--runtime', type=Path, default=ENTRY.OUT / 'runtime-02.json')
    run.add_argument('--case-ref', type=Path)
    run.add_argument('--output', type=Path)
    run.add_argument('--expected-hap')
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    defaults = {'503': 'entry-fault-case-ref.json', 'drop': 'entry-drop-case-ref.json',
                'read-retry': 'entry-phone-case-ref2.json'}
    args.case_ref = args.case_ref or ENTRY.PRIVATE / defaults[args.stage]
    args.output = args.output or ENTRY.OUT / ('device-entry-' + args.stage + '.json')
    args.delay_ms = 10000  # Retain the reused main's existing runtime/config guard.
    try:
        return RecoveryEntry(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'The explicit recovery case, runtime or output guards did not complete; values omitted'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())

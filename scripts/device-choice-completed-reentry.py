#!/usr/bin/env python3
"""Read-only history reentry for the already settled, isolated choice case.

Default/help is inert. Run binds both prior reports, the exact same HAP,
sources and case, and verifies the original answer receipt still exists.
The completed collector is reused only for its guards and read observations.
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

from native_device_ui import ROOT

DRIVER = ROOT / 'scripts/device-choice-completed.py'
DRIVER_SHA = 'bf9d81311a7d89a1c36185d4f9433d65bc0bf9d8a81a22ddb3687b5ca6f73e26'
PRIOR_SHA = '85bfa38ee6000aa9717e609c7888ae384d8e84574991de75392bfe512e7d9a5b'
FACT_KEYS = ('answerSubmissionCount', 'answerReceiptCount', 'completedProgressRows', 'xpLedgerCount',
             'xpDeltaSum', 'startReceiptCount', 'progressRows', 'playerTotalXp', 'submissionResults')
EXPECTED = dict(zip(FACT_KEYS, (1, 1, 1, 1, 50, 1, 1, 50, {'correct': 1, 'incorrect': 0, 'manual': 0})))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def execute(args):
    if sha(DRIVER) != DRIVER_SHA:
        raise RuntimeError('The frozen completed collector changed')
    spec = importlib.util.spec_from_file_location('choice_completed_reentry_guards', DRIVER)
    completed = importlib.util.module_from_spec(spec); spec.loader.exec_module(completed)
    normal = completed.load_normal(args.expected_normal_driver_sha)
    frame = normal.load('choice_reentry_frame', 'scripts/device-question-frame.py', normal.FRAME_SHA)
    require = frame.require
    value = completed.create(args)
    prior_path = frame.ENTRY.guarded(args.prior_completed_report, completed.OUT)
    require(sha(prior_path) == args.expected_prior_completed_sha == PRIOR_SHA,
            'Use the exact prior completed01 report')
    prior = json.loads(prior_path.read_text())
    require(prior.get('status') == 'incomplete' and prior.get('stage') == 'completed-get-only-reentry' and
            prior.get('bindingSha256') == value.binding and prior.get('hapSha256') == value.hap_sha and
            prior.get('normalReportSha256') == args.expected_normal_sha and prior.get('checksPassed') == 2 and
            prior.get('cleanup') and all(flag is True for flag in prior['cleanup'].values()) and
            prior.get('observedReadOnlyFacts') == EXPECTED and prior.get('singleNativeSubmitInvoked') is True and
            prior.get('sameInstancesBeforeAndAfterCompletion') is True and len(prior.get('disabledTouchObservations', [])) == 3 and
            {state.get('themeRequested') for state in prior.get('states', [])} == {'light', 'dark'} and
            all(state.get('disabledRadioCount') == 4 and state.get('disabledImageButtonCount') == 3 for state in prior['states']),
            'The prior completed run has no exact settled state and narrow reentry boundary')
    prior_ledger = prior['privateReadOnlyLedger']
    ledger_path = frame.ENTRY.guarded(Path(prior_ledger['file']), frame.PRIVATE, True)
    require(sha(ledger_path) == prior_ledger['sha256'], 'The prior private ledger changed')
    original = [row for row in json.loads(ledger_path.read_text())['added']
                if row.get('method') == 'POST' and row.get('path') == value.answer_path]
    require(len(original) == 1 and original[0].get('status') == 200 and original[0].get('actorVerifiedByBackendResponse') is True and
            re.fullmatch(r'[a-f0-9]{64}', original[0].get('requestIdSha256', '')), 'The single prior answer receipt binding is absent')
    for name, path in {'priorCompletedReport': prior_path, 'priorCompletedLedger': ledger_path, 'reentryDriver': Path(__file__)}.items():
        value.bound[name], value.binding[name] = path, sha(path)
    value.committed = True  # Read oracle only. This runner never calls main or submit.
    value.submit_invoked = False
    failure = None
    entry_reads = []

    def settled_facts():
        facts = value.facts()
        require(facts.get('answerRequestIdSha256') == [original[0]['requestIdSha256']],
                'The exact original answer receipt must remain unchanged')
        return facts

    try:
        value.stage = 'settled-owned-reentry-prerequisites'
        serials = value.ui.run('hdc', 'list', 'targets').split()
        require(len(serials) == 1 and re.fullmatch(r'[A-Za-z0-9]{8,80}', serials[0]), 'One exact connected phone is required')
        forwards = [row.split() for row in value.ui.run('hdc', '-t', serials[0], 'fport', 'ls').splitlines() if row.strip()]
        require([row for row in forwards if len(row) > 1 and row[1] == 'tcp:18443'] ==
                [[serials[0], 'tcp:18443', 'tcp:' + str(value.state['tls']['hostPort']), '[Reverse]']],
                'The exact own disposable USB TLS mapping must still be attached')
        auth = value.request(False, frame.AUTH, {'identity': value.case['account'], 'password': value.case['newPassword']})
        require(auth.get('record', {}).get('id') == value.case['playerId'] and isinstance(auth.get('token'), str) and auth['token'],
                'Host authentication must identify the same completed actor')
        value.token = auth['token']; value.dto = value.snapshot()
        assignment = value.dto['assignment']; level = value.level()
        require(assignment.get('status') == 'completed' and assignment.get('completedLevels') == assignment.get('totalLevels') == 1 and
                bool(assignment.get('completedAt')) and bool(level.get('completedAt')) and level.get('lastAnswer') == value.correct_key and
                value.dto['player'].get('totalXp') == 50, 'The same completed DTO and authoritative last answer are required')
        before = settled_facts(); value.start_hashes = before['startRequestIdSha256']; value.baseline = value.ledger(); value.immutable()

        value.stage = 'native-history-tab-reentry'
        value.device_started = True; value.ui.launch(cold=True)
        value.ui.wait(lambda ui: ui.find('account') is not None, 'own isolated cold login')
        require(value.ui.input_empty('account') and value.ui.input_empty('password') and value.ui.has_text('隔离测试环境'),
                'The isolated cold login must be empty')
        value.ui.fill('account', value.case['account']); value.ui.fill('password', value.case['newPassword']); value.ui.tap('primary-action')
        value.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('old-password') is None, 'ordinary own home')
        value.ui.tap('history-tab')
        target = 'assignment-' + value.assignment_id
        value.ui.wait(lambda ui: ui.find(target) is not None, 'same completed scene in actual history tab')
        offset = len(value.ledger()); value.immutable(); value.ui.tap(target)
        value.ui.wait(lambda ui: ui.find('gameplay-question-card') is not None and ui.find('gameplay-loading') is None,
                      'completed history scene opens by GET', timeout=40)
        entry = value.ledger()[offset:]
        entry_reads = [row for row in entry if row.get('method') == 'GET' and row.get('path') == value.detail]
        require(len(entry_reads) == 2 and all(row.get('method') == 'GET' for row in entry) and
                all(row.get('status') == 200 and row.get('authenticated') is True and row.get('bearer') is False for row in entry_reads),
                'Native history reentry must obtain its two authenticated detail GET200 responses')
        value.theme('dark'); value.record_completed('dark', 'history-reentry-completed-dark')
        value.verify_ledger(); require(settled_facts() == before, 'Completed reentry changed its own answer, progress or XP facts')
        require(len([row for row in value.ledger()[offset:] if row.get('method') == 'GET' and row.get('path') == value.detail]) == 2,
                'Completed controls issued an extra detail GET')
        value.check(True, 'History opens the same completed scene with two GET200 and preserves all read-only controls and settlement')
        value.stage = 'completed-history-reentry-observed'
    except Exception as error:
        reason = str(error)
        for item in value.credentials():
            if item: reason = reason.replace(item, '[credential omitted]')
        frame.write_private(value.directory / 'failure-diagnostic.json', {'stage': value.stage,
            'exceptionType': type(error).__name__, 'reason': reason}, value.credentials())
        failure = 'The read-only completed history reentry remains incomplete'
    finally:
        try:
            value.immutable()
            if value.device_started:
                value.logout(); value.verify_ledger()
                require(settled_facts() == before, 'Final logout changed the already settled facts')
        except Exception:
            failure = failure or 'Exact own logout or unchanged completed facts could not be confirmed'
        value.cleanup['remoteRawFilesRemoved'] = value.ui.remote_cleanup_ok
        if not all(value.cleanup.values()): failure = failure or 'Completed history cleanup remains incomplete'
    ledger = frame.write_private(value.directory / 'request-ledger.json', getattr(value, 'final_ledger', {}), value.credentials())
    report = {'status': 'incomplete' if failure else 'captured_native_choice_completed_reentry', 'stage': value.stage,
        'scope': 'Read-only completed case1 history tab and same-authority GET reentry', 'hapSha256': value.hap_sha,
        'priorCompletedReportSha256': PRIOR_SHA, 'normalReportSha256': args.expected_normal_sha, 'bindingSha256': value.binding,
        'nativeDetailGetStatuses': [row.get('status') for row in entry_reads], 'nativeStartOrAnswerInvoked': False,
        'observedReadOnlyFacts': {key: value.final_facts[key] for key in FACT_KEYS} if hasattr(value, 'final_facts') else None,
        'checks': value.checks, 'checksPassed': len(value.checks), 'states': value.states, 'cleanup': value.cleanup,
        'privateScreenshots': value.ui.private_screenshots, 'privateRawEvidence': value.ui.raw_evidence,
        'privateReadOnlyLedger': ledger, 'visualReview': 'pending_root_original_review', 'failure': failure,
        'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
    private = [value.case_id, value.case['account'], value.case['playerId'], value.assignment_id,
               value.case['assignments']['ready']['sessionId'], *value.credentials()]
    require(not re.search(r'https?://', encoded) and not any(item and item in encoded for item in private), 'A private literal would enter the reentry report')
    frame.fresh(value.report, completed.OUT); value.report.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(value.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
    with os.fdopen(fd, 'w') as stream: stream.write(encoded)
    print(json.dumps({'status': report['status'], 'report': str(value.report.relative_to(ROOT))}), flush=True)
    return 1 if failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    run = parser.add_subparsers(dest='action').add_parser('run')
    for name in ('runtime', 'case-ref', 'output', 'private-dir', 'images-manifest', 'fixture-file', 'normal-report', 'prior-completed-report'):
        run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-hap', 'expected-normal-sha', 'expected-normal-driver-sha', 'expected-prior-completed-sha'):
        run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if args.action is None: parser.print_help(); return 0
    try: return execute(args)
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded', 'reason': 'Exact prior/current runtime, case, report, source or output guard failed'})); return 1


if __name__ == '__main__':
    sys.exit(main())

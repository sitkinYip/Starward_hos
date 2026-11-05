#!/usr/bin/env python3
"""Root-only strict HTTPS answer protocol checks on newly created own cases.

Default help is inert. This never runs services or operates a phone. The caller
must supply the exact independently reviewed runner SHA. No preview case/reset.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('host_entry_binding', ROOT / 'scripts/gameplay-host-entry-check.py')
BASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)
require = BASE.require


class HostAnswerCheck(BASE.HostEntryCheck):
    def __init__(self, args):
        require(re.fullmatch(r'[a-f0-9]{64}', args.expected_runner), 'A reviewed runner SHA256 is required')
        output = args.output.absolute()
        allowed = ROOT / 'artifacts/validation'
        require(output == output.resolve() and output.is_relative_to(allowed) and output.suffix == '.json',
                'The report escaped the validation directory or contains an indirect path')
        BASE.REPORT, BASE.EXPECTED_RUNNER = output, args.expected_runner
        super().__init__()
        require(self.state['gameplay'].get('answerProtocol') == {
            'version': 1, 'playerPostAnswers': True, 'ownSessionFixtures': True,
            'readOnlyAnswerDiagnostics': True}, 'The reviewed answer protocol is absent')
        require(not any(row.get('label', '').startswith('answer-host-') for row in self.state['gameplay']['cases'].values()),
                'Prior host-answer preparation exists; this helper never silently resumes a partial run')
        self.report = output
        self.owned = {}
        self.ledger_expectations = []
        self.source_binding['entryBindingHelper'] = BASE.sha_file(ROOT / 'scripts/gameplay-host-entry-check.py')
        self.source_binding['helper'] = BASE.sha_file(Path(__file__))

    def immutable(self):
        fresh = BASE.read_state()
        require(self.environment_identity(fresh) == self.identity and fresh['controlToken'] == self.state['controlToken'] and
                BASE.sha_file(BASE.RUNNER) == BASE.EXPECTED_RUNNER and BASE.sha_file(self.ca) == self.source_binding['ca'] and
                BASE.sha_file(Path(__file__)) == self.source_binding['helper'] and
                BASE.sha_file(ROOT / 'scripts/gameplay-host-entry-check.py') == self.source_binding['entryBindingHelper'],
                'The strict owned environment or reviewed source binding changed')
        return fresh

    def control(self, route, body):
        require(route in ('/new-case', '/case-progress', '/requests', '/case-cancel'), 'Unsupported answer control operation')
        self.immutable()
        status, value = self.request(self.control_opener, self.control_base, route, body, self.state['controlToken'])
        require(status == 200, 'An owned answer control did not return200')
        return value

    def player(self, route, body=None):
        common = ('/api/collections/game_players/auth-with-password', '/api/questions/v1/me')
        allowed = {suffix for item in self.owned.values() for suffix in (
            '/api/questions/v1/assignments/' + item['assignmentId'],
            '/api/questions/v1/assignments/' + item['assignmentId'] + '/start',
            '/api/questions/v1/assignments/' + item['assignmentId'] + '/answers',
            '/api/questions/v1/assignments/' + item['assignmentId'] + '/finish')}
        require(route in common or route in allowed, 'A request escaped the newly owned answer cases')
        self.immutable()
        return self.request(self.player_opener, self.player_base, route, body, self.token)

    def new_case(self, fixture, label=None):
        label = 'answer-host-' + (label or fixture)
        prepared = self.control('/new-case', {'label': label, 'fixture': fixture})
        require(prepared.get('created') is True and prepared.get('ordinaryLoginPrepared') is True and
                re.fullmatch(r'[a-f0-9]{16}', prepared.get('caseId', '')), 'Fresh host-only answer case preparation failed')
        fresh = self.immutable()
        case = fresh['gameplay']['cases'].get(prepared['caseId'])
        require(isinstance(case, dict) and case.get('label') == label and case.get('fixture') == fixture and
                case.get('setupStatus') == 'ready' and case.get('ordinaryLoginPrepared') is True and
                re.fullmatch(r'hm_[a-f0-9]{12}', case.get('account', '')) and
                re.fullmatch(r'[a-z0-9]{15}', case.get('playerId', '')) and
                isinstance(case.get('newPassword'), str) and len(case['newPassword']) >= 24 and
                set(case.get('assignments', {})) == set(BASE.KINDS), 'The new answer case identity is invalid')
        require(all(re.fullmatch(r'[a-z0-9]{15}', item.get(key, '')) for item in case['assignments'].values()
                    for key in ('sessionId', 'assignmentId')), 'The new answer case record boundaries are invalid')
        prior_sessions = {item['sessionId'] for old in self.owned.values() for item in old['assignments'].values()} | \
            {item['sessionId'] for item in fresh['assignments'].values()}
        sessions = [item['sessionId'] for item in case['assignments'].values()]
        require(len(set(sessions)) == 4 and not set(sessions) & prior_sessions,
                'A host answer case reused a prior case or legacy session')
        self.owned[case['caseId']] = case
        self.use_case(case)
        status, auth = self.player('/api/collections/game_players/auth-with-password',
                                  {'identity': case['account'], 'password': case['newPassword']})
        require(status == 200 and isinstance(auth.get('token'), str) and auth.get('record', {}).get('id') == case['playerId'],
                'The new ordinary answer player failed real HTTPS authentication')
        case['_token'] = auth['token']
        self.token = auth['token']
        status, me = self.player('/api/questions/v1/me')
        self.check(status == 200 and me.get('id') == case['playerId'] and me.get('mustChangePassword') is False and
                   me.get('totalXp') == 0 and self.pristine(self.diagnostic()) and
                   self.diagnostic().get('answerReceiptCount') == 0,
                   fixture + ': fresh ordinary own-session case has zero answer/progress/XP facts')
        return case

    def use_case(self, case):
        self.case, self.case_id = case, case['caseId']
        self.token = case.get('_token')
        self.route = '/api/questions/v1/assignments/' + case['assignmentId']

    def start(self):
        status, result = self.player(self.route + '/start', {'requestId': str(uuid.uuid4())})
        require(status == 200 and result.get('player') == self.case['playerId'] and result.get('status') == 'active' and
                isinstance(result.get('levels'), list) and len(result['levels']) == len(self.case['fixtureLevelKinds']),
                'The real answer fixture did not enter its exact assignment')
        return result

    @staticmethod
    def body(level, answer):
        return json.dumps({'sessionLevelId': level, 'answer': answer, 'requestId': str(uuid.uuid4())},
                          ensure_ascii=False, separators=(',', ':')).encode()

    def answer(self, body, code=None, result=None):
        status, value = self.player(self.route + '/answers', body)
        if code:
            self.check(status == 409 and value.get('error', {}).get('code') == code,
                       self.case['fixture'] + ': authoritative answer rejection ' + code)
        else:
            self.check(status == 200 and value.get('result') == result and
                       value.get('assignment', {}).get('player') == self.case['playerId'] and
                       value.get('player', {}).get('id') == self.case['playerId'],
                       self.case['fixture'] + ': real owned answer result ' + result)
        parsed = json.loads(body)
        self.ledger_expectations.append({'path': self.route + '/answers', 'status': status,
            'requestIdSha256': BASE.sha_bytes(parsed['requestId'].encode()), 'requestBodySha256': BASE.sha_bytes(body),
            'sessionLevelIdSha256': BASE.sha_bytes(parsed['sessionLevelId'].encode()),
            'actorSha256': BASE.sha_bytes((self.state['controlToken'] + ':actor:' + self.case['playerId']).encode())})
        return value

    @staticmethod
    def facts(value):
        keys = ('assignmentStatus', 'startedAtPresent', 'completedAtPresent', 'progressRows', 'completedProgressRows',
                'wrongCountTotal', 'lockedProgressRows', 'answerSubmissionCount', 'xpLedgerCount', 'xpDeltaSum',
                'startReceiptCount', 'startRequestIdSha256', 'answerReceiptCount', 'answerRequestIdSha256',
                'submissionResults', 'playerTotalXp')
        return {key: value.get(key) for key in keys} | {'steps': [{key: row.get(key) for key in (
            'position', 'sessionLevelIdSha256', 'autoNext', 'xp', 'progressPresent', 'completedAtPresent',
            'wrongCount', 'locked', 'cooldownActive', 'submissionCount', 'xpLedgerCount', 'xpDeltaSum')}
            for row in value.get('steps', [])]}

    def count_facts(self, submissions, receipts, completed, xp, wrong=0, locked=0):
        value = self.diagnostic()
        self.check(value.get('answerSubmissionCount') == submissions and value.get('answerReceiptCount') == receipts and
                   value.get('completedProgressRows') == completed and value.get('xpLedgerCount') == completed and
                   value.get('xpDeltaSum') == value.get('playerTotalXp') == xp and
                   value.get('wrongCountTotal') == wrong and value.get('lockedProgressRows') == locked,
                   self.case['fixture'] + ': authoritative receipt/submission/completion/penalty/XP counts match')
        return value

    def unchanged(self, before):
        self.check(self.facts(self.diagnostic()) == self.facts(before),
                   self.case['fixture'] + ': rejected or replayed command creates no extra answer or XP facts')

    def stage(self):
        manual = self.new_case('manual')
        before = self.player(self.route)[1]
        self.answer(self.body(before['levels'][0]['id'], '隔离错误答案'), code='NOT_STARTED')
        self.check(self.pristine(self.diagnostic()), 'Answer before entry creates no business facts')
        snapshot = self.start()
        first, second = [row['id'] for row in snapshot['levels']]
        self.answer(self.body(second, 'B'), code='PREVIOUS_LEVEL_REQUIRED')
        self.count_facts(0, 0, 0, 0)
        self.answer(self.body(first, '隔离错误答案'), result='incorrect')
        self.count_facts(1, 1, 0, 0)
        raw_correct = self.body(first, '  星辰大海  ')
        good = self.answer(raw_correct, result='correct')
        self.check(good.get('xpDelta') == 50 and good['assignment'].get('currentIndex') == 1 and
                   good['assignment']['levels'][0].get('autoNext') is False and
                   isinstance(good['assignment']['levels'][1].get('question'), dict),
                   'Manual text completion normalizes input and reveals the next question with server XP')
        after = self.count_facts(2, 2, 1, 50)
        self.answer(raw_correct, result='correct')
        self.unchanged(after)
        altered = json.loads(raw_correct)
        altered['answer'] = '星辰大海'
        conflict = json.dumps(altered, ensure_ascii=False, separators=(',', ':')).encode()
        self.answer(conflict, code='IDEMPOTENCY_CONFLICT')
        self.unchanged(after)
        self.answer(self.body(first, '星辰大海'), result='already_completed')
        self.count_facts(2, 3, 1, 50)
        self.answer(self.body(second, 'A'), result='incorrect')
        self.count_facts(3, 4, 1, 50, wrong=1)
        final = self.answer(self.body(second, 'B'), result='correct')
        self.check(final['assignment'].get('status') == 'completed' and bool(final['assignment'].get('completedAt')) and
                   final['assignment'].get('completedLevels') == final['assignment'].get('totalLevels') == 2 and
                   final['player'].get('totalXp') == 100 and final.get('xpDelta') == 50,
                   'The final answer itself returns completed assignment and authoritative player XP')
        completed = self.count_facts(4, 5, 2, 100, wrong=1)
        status, rejected = self.player(self.route + '/finish', {'requestId': str(uuid.uuid4())})
        self.check(status == 404, 'No separate finish endpoint is needed or exposed')
        self.unchanged(completed)
        status, me = self.player('/api/questions/v1/me')
        self.check(status == 200 and me.get('totalXp') == final['player']['totalXp'],
                   'Fresh player read independently agrees with final authoritative XP')
        self.observed['manual'] = self.facts(completed)

        other = self.new_case('auto-next')
        other_snapshot = self.start()
        other_level = other_snapshot['levels'][0]['id']
        other_route = self.route
        self.use_case(manual)
        status, denied = self.player(other_route + '/answers', self.body(other_level, '星辰大海'))
        self.check(status == 404 and denied.get('error', {}).get('code') == 'NOT_FOUND',
                   'Another dedicated host player cannot answer the other own-session assignment')
        self.use_case(other)
        self.count_facts(0, 0, 0, 0)
        auto = self.answer(self.body(other_level, '星辰大海'), result='correct')
        self.check(auto['assignment']['levels'][0].get('autoNext') is True and auto['assignment'].get('currentIndex') == 1,
                   'Auto-next is an authoritative per-step flag with currentIndex advanced; no native animation credit')
        self.observed['autoNext'] = self.facts(self.count_facts(1, 1, 1, 50))

        self.new_case('choice-cooldown')
        level = self.start()['levels'][0]['id']
        wrong_body = self.body(level, 'A')
        wrong = self.answer(wrong_body, result='incorrect')
        self.check(wrong['assignment']['levels'][0].get('wrongCount') == 1 and
                   bool(wrong['assignment']['levels'][0].get('cooldownUntil')),
                   'Incorrect choice receives real server cooldown and wrong count')
        cooldown = self.count_facts(1, 1, 0, 0, wrong=1)
        self.answer(wrong_body, result='incorrect')
        self.unchanged(cooldown)
        self.answer(self.body(level, 'B'), code='COOLDOWN')
        self.unchanged(cooldown)
        deadline = time.monotonic() + 16
        while time.monotonic() < deadline and self.diagnostic()['steps'][0]['cooldownActive']:
            time.sleep(.5)
        require(self.diagnostic()['steps'][0]['cooldownActive'] is False, 'The real server cooldown did not expire in the bounded window')
        self.answer(self.body(level, 'B'), result='correct')
        self.observed['cooldown'] = self.facts(self.count_facts(2, 2, 1, 50, wrong=1))

        self.new_case('choice-lock')
        level = self.start()['levels'][0]['id']
        self.answer(self.body(level, 'A'), result='incorrect')
        locked = self.count_facts(1, 1, 0, 0, wrong=1, locked=1)
        self.answer(self.body(level, 'B'), code='LOCKED')
        self.unchanged(locked)
        self.observed['lock'] = self.facts(locked)

        self.new_case('single-normal')
        level = self.start()['levels'][0]['id']
        single = self.answer(self.body(level, '星辰大海'), result='correct')
        self.check(single['assignment'].get('status') == 'completed' and
                   single['assignment'].get('completionTarget') is None and
                   single['assignment'].get('presentation', {}).get('completionStyle') == 'normal',
                   'A single normal scene completes directly from its answer without a narrative or finish write')
        self.observed['single'] = self.facts(self.count_facts(1, 1, 1, 50))

        self.new_case('manual', 'cancel')
        level = self.start()['levels'][0]['id']
        original = self.body(level, '星辰大海')
        self.answer(original, result='correct')
        before_cancel = self.count_facts(1, 1, 1, 50)
        cancelled = self.control('/case-cancel', {'caseId': self.case_id})
        require(cancelled.get('cancelled') is True and cancelled.get('caseId') == self.case_id and
                cancelled.get('officialAdminAction') is True, 'The exact own case was not officially cancelled')
        replay = self.answer(original, result='correct')
        self.check(replay['assignment'].get('status') == 'cancelled' and replay['player'].get('totalXp') == 50,
                   'A cancelled scene exact replay preserves historical result and returns current cancelled facts')
        after_cancel = self.count_facts(1, 1, 1, 50)
        self.check({k: v for k, v in self.facts(before_cancel).items() if k != 'assignmentStatus'} ==
                   {k: v for k, v in self.facts(after_cancel).items() if k != 'assignmentStatus'},
                   'Official cancellation and historical replay preserve settled answer and XP facts')
        self.answer(self.body(level, '星辰大海'), code='ASSIGNMENT_CANCELLED')
        self.unchanged(after_cancel)
        self.observed['cancel'] = self.facts(after_cancel)

        rows = self.control('/requests', {}).get('requests')
        require(isinstance(rows, list), 'Answer request ledger is absent')
        for expectation in self.ledger_expectations:
            matched = [row for row in rows if all(row.get(key) == value for key, value in expectation.items())]
            require(matched and all(row.get('method') == 'POST' and row.get('operation') == 'answer' and
                    row.get('authenticated') is True and row.get('bearer') is False and row.get('fault') is False and
                    (row.get('status') != 200 or row.get('actorVerifiedByBackendResponse') is True) for row in matched),
                    'A real answer request lost its raw-body/request/level/backend-account identity binding')
        replay_id = BASE.sha_bytes(json.loads(raw_correct)['requestId'].encode())
        selected = [row for row in rows if row.get('path') == '/api/questions/v1/assignments/' + manual['assignmentId'] + '/answers' and
                    row.get('requestIdSha256') == replay_id]
        self.check(len(selected) == 3 and [row.get('matchesPriorRequestIdentity') for row in selected] == [None, True, False] and
                   [row.get('status') for row in selected] == [200, 200, 409],
                   'Exact retry and semantic-but-body-different conflict are distinguished by all original request hashes')
        self.observed['answerIdentityChecks'] = len(self.ledger_expectations)
        self.observed['newDedicatedCases'] = len(self.owned)
        self.check(True, 'Every expected answer request uses raw Authorization and backend-confirmed actors on success')
        self.immutable()

    def execute(self):
        failure = None
        try:
            self.stage()
        except Exception as error:
            failure = str(error) if isinstance(error, BASE.CheckFailure) else 'Host answer checks stopped; raw values omitted'
        report = {'status': 'passed' if failure is None else 'incomplete',
            'scope': 'Host strict HTTPS answer protocol only; no native UI acceptance credit',
            'backendCommit': BASE.BACKEND_COMMIT, 'sourceSha256': self.source_binding,
            'checksPassed': len(self.checks), 'checks': self.checks, 'observed': self.observed,
            'fixedPreviewTouched': False, 'phoneOperations': 0, 'productionRequests': 0,
            'privateCredentialsOrRecordIdsPersisted': False,
            'writeScope': 'Fresh own players/sessions/first-password setup; start/answer and one official own-case cancel. No reset, shared fixture mutation, profile or reward write.'}
        if failure:
            report['failure'] = failure
        encoded = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
        secrets = [self.state['controlToken'], self.token or '']
        for case in self.owned.values():
            secrets += [case.get(key, '') for key in ('caseId', 'account', 'newPassword', 'initialPassword', 'playerId', '_token')]
            secrets += [item[key] for item in case['assignments'].values() for key in ('assignmentId', 'sessionId')]
        secrets += [item.get('id', '') for item in self.state['gameplay']['questions']]
        require(not any(value and value in encoded for value in secrets), 'A private literal would enter the public answer report')
        self.report.parent.mkdir(parents=True, exist_ok=True)
        for item in (self.report.parent, *self.report.parent.parents):
            require(not item.is_symlink(), 'Public evidence path contains a symlink')
            if item == ROOT:
                break
        descriptor = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(encoded)
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks),
                          'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 0 if failure is None else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-only checks; creates six dedicated cases and submits real answers')
    run.add_argument('--expected-runner', required=True)
    run.add_argument('--output', type=Path, default=ROOT / 'artifacts/validation/gameplay-answer-20261104/host-answer.json')
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return HostAnswerCheck(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Strict ownership/runtime/report guards failed; private values omitted'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())

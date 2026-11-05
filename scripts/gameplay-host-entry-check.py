#!/usr/bin/env python3
"""Strict HTTPS entry/snapshot checks for a NEW disposable host-only player.

Default invocation prints help. Root alone runs this after starting the exact
disposable backend and TLS gateway. It never invokes reset, uses the persistent
preview player, answers a question, or operates a phone.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import ssl
import stat
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse
import uuid


ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'artifacts/private/https-isolation'
STATE = PRIVATE / 'state.json'
REPORT = ROOT / 'artifacts/validation/gameplay-entry-20261104/host-entry.json'
RUNNER = ROOT / 'scripts/isolated-backend.mjs'
EXPECTED_RUNNER = 'f51c8456c99cf522c93aa6e0d4baac2c5f2f3ead7217cdb8b8d5111952c78c45'
BACKEND_COMMIT = 'c28f488d6b682ae213713ccdd2d992595a941ae3'
LABEL = 'entry-host'
KINDS = ('ready', 'waiting', 'expired', 'locked')


class CheckFailure(Exception):
    """Only fixed, non-sensitive explanatory text enters this exception."""


def require(value, message):
    if not value:
        raise CheckFailure(message)


def sha_bytes(value):
    return hashlib.sha256(value).hexdigest()


def sha_file(path):
    return sha_bytes(path.read_bytes())


def private_file(path, exact_mode=None):
    path = Path(path)
    require(path.is_relative_to(PRIVATE), 'A private input escaped the disposable directory')
    for item in (path, *path.parents):
        require(not item.is_symlink(), 'A private input or directory is a symlink')
        if item == ROOT:
            break
    info = path.stat()
    require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid(), 'A private input is not an owned regular file')
    if exact_mode is not None:
        require(stat.S_IMODE(info.st_mode) == exact_mode, 'The private state must be mode600')
    else:
        require(info.st_mode & 0o022 == 0, 'The public test CA is writable by another user')
    return path


def read_state():
    directory = PRIVATE.stat()
    require(not PRIVATE.is_symlink() and stat.S_ISDIR(directory.st_mode) and
            directory.st_uid == os.getuid() and stat.S_IMODE(directory.st_mode) == 0o700,
            'The disposable directory must be owned mode700')
    value = json.loads(private_file(STATE, 0o600).read_text())
    require(isinstance(value, dict) and value.get('mode') == 'real isolated PocketBase' and
            value.get('version') == '0.40.1' and value.get('backendSourceCommit') == BACKEND_COMMIT and
            re.fullmatch(r'hm_[a-f0-9]{10}', value.get('account', '')) is not None and
            re.fullmatch(r'sha256:[a-f0-9]{64}', value.get('imageId', '')) is not None and
            isinstance(value.get('controlToken'), str) and len(value['controlToken']) >= 24,
            'The state does not identify the expected disposable runtime')
    require(isinstance(value.get('gameplay'), dict) and value['gameplay'].get('schema') == 1 and
            value['gameplay'].get('phase') == 'entry-snapshot' and
            isinstance(value['gameplay'].get('cases'), dict), 'The entry fixture metadata is absent')
    source = Path(value.get('sourceDirectory', ''))
    require(source.is_absolute() and source.is_relative_to(PRIVATE) and not source.is_symlink() and
            source.name.startswith('questions-pb-test-') and source.is_dir(),
            'The database directory is outside the owned disposable namespace')
    return value


def loopback_base(value, scheme):
    require(isinstance(value, str), 'A runner endpoint is missing')
    parsed = urlparse(value)
    require(parsed.scheme == scheme and parsed.hostname == '127.0.0.1' and
            parsed.username is None and parsed.password is None and
            parsed.port is not None and 1024 <= parsed.port <= 65535 and
            not parsed.path and not parsed.query and not parsed.fragment and
            value == scheme + '://127.0.0.1:' + str(parsed.port),
            'A runner endpoint is not the exact loopback origin')
    return value


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file, code, message, headers, new_url):
        raise CheckFailure('A runner request attempted a redirect; no redirected request was sent')


class HostEntryCheck:
    def __init__(self):
        require(not REPORT.exists() and not REPORT.is_symlink(), 'The host entry report already exists; preserve it before another run')
        for item in (REPORT.parent, *REPORT.parent.parents):
            require(not item.is_symlink(), 'The public evidence directory contains a symlink')
            if item == ROOT:
                break
        require(sha_file(RUNNER) == EXPECTED_RUNNER, 'The reviewed entry runner source changed')
        self.state = read_state()
        self.control_base = loopback_base(self.state['controlBase'], 'http')
        loopback_base(self.state['proxyBase'], 'http')
        loopback_base(self.state['backendBase'], 'http')
        tls = self.state.get('tls', {})
        self.player_base = loopback_base(tls.get('hostBase'), 'https')
        require(tls.get('base') == 'https://127.0.0.1:18443' and
                urlparse(self.player_base).port == tls.get('hostPort'), 'The saved TLS origin is inconsistent')
        self.ca = private_file(PRIVATE / 'tls/ca.pem')
        require(tls.get('caPath') == str(self.ca) and sha_file(self.ca) == tls.get('caSha256'),
                'The exact owned test CA does not match the runner receipt')
        require(not any(item.get('label') == LABEL for item in self.state['gameplay']['cases'].values()),
                'A prior host-entry case exists; this helper does not replay its preparation')
        context = ssl.create_default_context(cafile=str(self.ca))
        require(context.check_hostname and context.verify_mode == ssl.CERT_REQUIRED,
                'Strict certificate and hostname verification is required')
        self.player_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect(),
                                                       urllib.request.HTTPSHandler(context=context))
        self.control_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        self.identity = self.environment_identity(self.state)
        self.case_id = None
        self.case = None
        self.token = None
        self.checks = []
        self.setup = {}
        self.observed = {}
        self.source_binding = {'runner': EXPECTED_RUNNER, 'helper': sha_file(Path(__file__)), 'ca': sha_file(self.ca)}

    @staticmethod
    def environment_identity(value):
        return {key: value.get(key) for key in ('pid', 'mode', 'version', 'backendSourceCommit', 'imageId',
                                               'controlBase', 'proxyBase', 'backendBase', 'sourceDirectory')}, value.get('tls')

    def check(self, condition, label):
        require(condition, label)
        self.checks.append(label)

    def request(self, opener, base, route, body=None, token=None):
        data = None if body is None else body if isinstance(body, bytes) else json.dumps(
            body, ensure_ascii=False, separators=(',', ':')).encode()
        request = urllib.request.Request(base + route, data=data,
            method='GET' if data is None else 'POST',
            headers={'Accept': 'application/json', **({'Content-Type': 'application/json'} if data is not None else {}),
                     **({'Authorization': token} if token else {})})
        try:
            try:
                response = opener.open(request, timeout=25)
            except urllib.error.HTTPError as error:
                response = error
            with response:
                status = response.status
                value = json.loads(response.read())
            require(isinstance(value, dict), 'A runner response was not a JSON object')
            return status, value
        except CheckFailure:
            raise
        except Exception:
            raise CheckFailure('A strict owned-runner request did not complete; raw values omitted') from None

    def control(self, route, body):
        require(route in ('/new-case', '/case-progress', '/requests'), 'The helper attempted an unsupported control operation')
        status, value = self.request(self.control_opener, self.control_base, route, body, self.state['controlToken'])
        require(status == 200, 'An owned control operation did not return200')
        return value

    def player(self, route, body=None):
        allowed = ('/api/collections/game_players/auth-with-password', '/api/questions/v1/me',
                   '/api/questions/v1/assignments')
        if route not in allowed:
            ids = [value['assignmentId'] for value in self.case['assignments'].values()] + [self.state['assignmentId']]
            require(any(route == '/api/questions/v1/assignments/' + record or
                        route == '/api/questions/v1/assignments/' + record + '/start' for record in ids),
                    'A player request escaped the exact owned assignment set')
        return self.request(self.player_opener, self.player_base, route, body, self.token)

    def diagnostic(self, kind='ready'):
        value = self.control('/case-progress', {'caseId': self.case_id, 'kind': kind})
        require(value.get('caseId') == self.case_id and value.get('assignmentKind') == kind and
                value.get('readOnlyDiagnostic') is True and value.get('rawAnswersOrCredentialsReturned') is False,
                'A diagnostic did not identify the exact host case')
        return value

    @staticmethod
    def pristine(value):
        return value.get('assignmentStatus') == 'assigned' and value.get('startedAtPresent') is False and \
            value.get('completedAtPresent') is False and all(type(value.get(key)) is int and value[key] == 0 for key in (
                'progressRows', 'completedProgressRows', 'wrongCountTotal', 'lockedProgressRows',
                'answerSubmissionCount', 'xpLedgerCount', 'xpDeltaSum', 'startReceiptCount'))

    @staticmethod
    def diagnostic_facts(value):
        return {key: value.get(key) for key in ('assignmentStatus', 'startedAtPresent', 'completedAtPresent',
            'progressRows', 'completedProgressRows', 'wrongCountTotal', 'lockedProgressRows',
            'answerSubmissionCount', 'xpLedgerCount', 'xpDeltaSum', 'startReceiptCount', 'startRequestIdSha256')}

    def stage(self):
        prepared = self.control('/new-case', {'label': LABEL})
        require(prepared.get('created') is True and prepared.get('ordinaryLoginPrepared') is True and
                re.fullmatch(r'[a-f0-9]{16}', prepared.get('caseId', '')) is not None,
                'A fresh ordinary host-only gameplay case was not prepared')
        self.case_id = prepared['caseId']
        fresh = read_state()
        require(self.environment_identity(fresh) == self.identity, 'The disposable environment changed during case creation')
        self.case = fresh['gameplay']['cases'].get(self.case_id)
        require(self.case and self.case.get('label') == LABEL and self.case.get('setupStatus') == 'ready' and
                self.case.get('ordinaryLoginPrepared') is True and
                re.fullmatch(r'hm_[a-f0-9]{12}', self.case.get('account', '')) is not None and
                re.fullmatch(r'[a-z0-9]{15}', self.case.get('playerId', '')) is not None and
                set(self.case.get('assignments', {})) == set(KINDS) and
                isinstance(self.case.get('newPassword'), str) and len(self.case['newPassword']) >= 24,
                'The newly saved host-only player is not the exact prepared case')
        ids = [entry.get('assignmentId') for entry in self.case['assignments'].values()]
        require(len(set(ids)) == 4 and all(re.fullmatch(r'[a-z0-9]{15}', item or '') for item in ids) and
                self.state['assignmentId'] not in ids, 'The host assignment identities are invalid')
        questions = fresh['gameplay'].get('questions')
        require(isinstance(questions, list) and len(questions) == 2 and
                [row.get('kind') for row in questions] == ['text', 'choice'] and
                all(re.fullmatch(r'[a-z0-9]{15}', row.get('id', '')) for row in questions),
                'The exact two-question fixture identities are invalid')
        self.setup = {'newDedicatedHostCaseCreated': True, 'ordinaryFirstPasswordSetupConfirmed': True,
                      'fixtureKinds': ['text', 'choice'], 'fixedPreviewUsed': False}
        status, auth = self.player('/api/collections/game_players/auth-with-password',
                                  {'identity': self.case['account'], 'password': self.case['newPassword']})
        require(status == 200 and isinstance(auth.get('token'), str) and
                auth.get('record', {}).get('id') == self.case['playerId'], 'Real dedicated player authentication failed')
        self.token = auth['token']
        status, me = self.player('/api/questions/v1/me')
        self.check(status == 200 and me.get('id') == self.case['playerId'] and me.get('mustChangePassword') is False,
                   'Dedicated ordinary player authenticates over strict HTTPS')
        status, listing = self.player('/api/questions/v1/assignments')
        self.check(status == 200 and isinstance(listing.get('items'), list) and
                   {row.get('id') for row in listing['items']} == set(ids),
                   'Real assignment list exactly matches the four dedicated host assignments')
        route = '/api/questions/v1/assignments/' + self.case['assignments']['ready']['assignmentId']
        status, before = self.player(route)
        self.check(status == 200 and before.get('status') == 'assigned' and
                   isinstance(before.get('levels'), list) and len(before['levels']) == 2 and
                   all(level.get('question') is None for level in before['levels']),
                   'Unstarted protected snapshot hides every question')
        self.check(self.pristine(self.diagnostic()), 'Before entry there are no progress, receipts, submissions or XP facts')
        request_id = str(uuid.uuid4())
        body = json.dumps({'requestId': request_id}, separators=(',', ':')).encode()
        status, started = self.player(route + '/start', body)
        self.check(status == 200 and started.get('id') == before.get('id') and
                   started.get('player') == self.case['playerId'] and started.get('status') == 'active' and
                   bool(started.get('startedAt')) and started.get('currentIndex') == 0 and
                   started.get('completedLevels') == 0 and started.get('totalLevels') == 2,
                   'Real start returns the owned active assignment with authoritative progress')
        self.check(isinstance(started.get('levels'), list) and len(started['levels']) == 2 and
                   isinstance(started['levels'][0].get('question'), dict) and
                   started['levels'][0]['question'].get('kind') == 'text' and
                   started['levels'][0]['question'].get('id') == questions[0]['id'] and
                   started['levels'][1].get('question') is None,
                   'Start reveals the current text question while the future choice remains protected')
        after_start = self.diagnostic()
        self.check(after_start.get('assignmentStatus') == 'active' and after_start.get('startedAtPresent') is True and
                   after_start.get('progressRows') == 2 and after_start.get('startReceiptCount') == 1 and
                   after_start.get('completedProgressRows') == 0 and after_start.get('answerSubmissionCount') == 0 and
                   after_start.get('xpLedgerCount') == 0 and after_start.get('xpDeltaSum') == 0 and
                   after_start.get('startRequestIdSha256') == [sha_bytes(request_id.encode())],
                   'Database reads confirm exactly two progress rows and one start receipt with no answer or XP writes')
        status, snapshot = self.player(route)
        self.check(status == 200 and snapshot.get('status') == 'active' and
                   snapshot.get('startedAt') == started.get('startedAt') and snapshot.get('levels') == started.get('levels'),
                   'A fresh GET independently returns the current question and protected future question')
        status, replay = self.player(route + '/start', body)
        self.check(status == 200 and replay.get('status') == 'active' and replay.get('startedAt') == started.get('startedAt'),
                   'Exact request ID and original body can replay the real start successfully')
        self.check(self.diagnostic_facts(self.diagnostic()) == self.diagnostic_facts(after_start),
                   'Start replay does not duplicate progress rows, receipts, submissions or XP')
        conflict_body = json.dumps({'requestId': request_id, 'probe': 'different-content'}, separators=(',', ':')).encode()
        status, conflict = self.player(route + '/start', conflict_body)
        self.check(status == 409 and conflict.get('error', {}).get('code') == 'IDEMPOTENCY_CONFLICT',
                   'Same request ID with a different body is rejected as an idempotency conflict')
        self.check(self.diagnostic_facts(self.diagnostic()) == self.diagnostic_facts(after_start),
                   'Conflicting replay leaves all authoritative entry facts unchanged')
        for kind, code in (('waiting', 'NOT_STARTED'), ('expired', 'EXPIRED'), ('locked', 'LEVEL_NOT_ELIGIBLE')):
            target = '/api/questions/v1/assignments/' + self.case['assignments'][kind]['assignmentId'] + '/start'
            status, rejected = self.player(target, {'requestId': str(uuid.uuid4())})
            self.check(status == 409 and rejected.get('error', {}).get('code') == code,
                       'Real ' + kind + ' admission is rejected with its authoritative business code')
            self.check(self.pristine(self.diagnostic(kind)), 'Rejected ' + kind + ' admission creates no gameplay facts')
        foreign = '/api/questions/v1/assignments/' + self.state['assignmentId']
        status, denied = self.player(foreign)
        self.check(status == 404 and denied.get('error', {}).get('code') == 'NOT_FOUND',
                   'Another owned test player assignment cannot be read by the host player')
        status, denied = self.player(foreign + '/start', {'requestId': str(uuid.uuid4())})
        self.check(status == 404 and denied.get('error', {}).get('code') == 'NOT_FOUND',
                   'Another owned test player assignment cannot be entered by the host player')
        request_rows = self.control('/requests', {}).get('requests')
        require(isinstance(request_rows, list), 'The real proxy request ledger is missing')
        ready_rows = [row for row in request_rows if row.get('method') == 'POST' and
                      row.get('path') == route + '/start' and row.get('requestIdSha256') == sha_bytes(request_id.encode())]
        self.check(len(ready_rows) == 3 and [row.get('status') for row in ready_rows] == [200, 200, 409] and
                   all(row.get('authenticated') is True and row.get('bearer') is False and row.get('fault') is False
                       for row in ready_rows), 'Proxy ledger confirms raw Authorization and the exact successful, replayed and conflicting requests')
        self.check(ready_rows[0].get('requestBodySha256') == ready_rows[1].get('requestBodySha256') == sha_bytes(body) and
                   ready_rows[2].get('requestBodySha256') == sha_bytes(conflict_body) and
                   re.fullmatch(r'[a-f0-9]{64}', ready_rows[0].get('actorSha256', '')) is not None and
                   len({row.get('actorSha256') for row in ready_rows}) == 1 and
                   ready_rows[1].get('matchesPriorRequestIdentity') is True and
                   ready_rows[2].get('matchesPriorRequestIdentity') is False and
                   all(row.get('actorVerifiedByBackendResponse') is True for row in ready_rows[:2]),
                   'Request and actor hashes bind the retry to the original body and backend-confirmed account')
        self.observed = {'startProgressRows': 2, 'startReceiptCount': 1, 'startXpDelta': 0,
                         'retrySameRequestIdBodyActor': True, 'rawAuthorizationNoBearer': True,
                         'timeAndLevelRejectionsHaveNoFacts': True, 'foreignAssignmentDenied': True}
        self.check(self.environment_identity(read_state()) == self.identity and sha_file(RUNNER) == EXPECTED_RUNNER and
                   sha_file(self.ca) == self.source_binding['ca'], 'Environment and reviewed runner identity remain unchanged')

    def execute(self):
        failure = None
        try:
            self.stage()
        except Exception as error:
            failure = str(error) if isinstance(error, CheckFailure) else 'Host entry checks stopped; raw values omitted'
        report = {'status': 'passed' if failure is None else 'incomplete', 'scope': 'Host strict HTTPS entry and question-snapshot checks only; no native UI acceptance credit',
                  'backendCommit': BACKEND_COMMIT, 'sourceSha256': self.source_binding, 'setup': self.setup,
                  'checksPassed': len(self.checks), 'checks': self.checks, 'observed': self.observed,
                  'productionRequests': 0, 'fixedPreviewTouched': False, 'phoneOperations': 0,
                  'privateCredentialsOrRecordIdsPersisted': False,
                  'writeScope': 'Fresh host-only fixture and its first-password setup via owned controller, then entry commands only; no reset, answer, profile or reward write',
                  'cleanup': 'The host case is intentionally retained for evidence; later phone checks must create their own separate case'}
        if failure:
            report['failure'] = failure
        REPORT.parent.mkdir(parents=True, exist_ok=True)
        for item in (REPORT.parent, *REPORT.parent.parents):
            require(not item.is_symlink(), 'The public evidence directory contains a symlink')
            if item == ROOT:
                break
        descriptor = os.open(REPORT, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(descriptor, 'w') as stream:
            json.dump(report, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks),
                          'report': str(REPORT.relative_to(ROOT))}))
        return 0 if failure is None else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action')
    sub.add_parser('run', help='Root-only real host checks; requires a fresh disposable backend and TLS gateway')
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return HostEntryCheck().execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Private ownership, runtime or report guard did not complete; raw values omitted'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())

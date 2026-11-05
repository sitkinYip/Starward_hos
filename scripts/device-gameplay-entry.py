#!/usr/bin/env python3
"""Root-only native entry/snapshot checks for one explicitly referenced disposable case.

Default invocation prints help without reading private state, HTTP or the phone.
Only `run --stage main` performs operations. It never creates/reset cases, uses
the persistent preview account, answers questions, or changes profile/passwords.
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import ssl
import stat
import sys
import time
import urllib.error
import urllib.request
from urllib.parse import urlparse
import zipfile

from native_device_ui import ROOT, SafeFailure

OUT = ROOT / 'artifacts/validation/gameplay-entry-20261104'
PRIVATE = ROOT / 'artifacts/private/gameplay-20261104'
ISOLATION = ROOT / 'artifacts/private/https-isolation'
STATE = ISOLATION / 'state.json'
HAP = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
CONFIG = ROOT / 'entry/src/main/resources/rawfile/integration.json'
AUTH = '/api/collections/game_players/auth-with-password'
BASE = '/api/questions/v1/assignments'
BACKEND_COMMIT = 'c28f488d6b682ae213713ccdd2d992595a941ae3'
CHECKS = {'actualWindowReported', 'actualImmersiveWindow', 'transparentSystemBars',
          'requestedFontScaleReported', 'threeIndependentTlsCases'}
SPEC = importlib.util.spec_from_file_location('gameplay_entry_refinement',
                                             ROOT / 'scripts/device-native-ui-refinements.py')
UI = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(UI)


def require(value, message):
    if not value:
        raise SafeFailure(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def guarded(path, directory, private=False):
    path = (ROOT / path).absolute() if not Path(path).is_absolute() else Path(path).absolute()
    require(path.resolve().is_relative_to(directory.resolve()), 'An input escaped its authorized directory')
    for item in (path, *path.parents):
        require(not item.is_symlink(), 'An evidence or private input path is a symlink')
        if item == ROOT:
            break
    info = path.stat()
    require(stat.S_ISREG(info.st_mode), 'An input is not a regular file')
    if private:
        require(info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o600,
                'A private input must be owned mode600')
    return path


def read_state():
    info = ISOLATION.stat()
    require(not ISOLATION.is_symlink() and stat.S_ISDIR(info.st_mode) and
            info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o700,
            'The disposable environment directory must be owned mode700')
    value = json.loads(guarded(STATE, ISOLATION, True).read_text())
    require(value.get('mode') == 'real isolated PocketBase' and value.get('version') == '0.40.1' and
            value.get('backendSourceCommit') == BACKEND_COMMIT and
            re.fullmatch(r'hm_[a-f0-9]{10}', value.get('account', '')) and
            isinstance(value.get('controlToken'), str) and len(value['controlToken']) >= 24,
            'The expected disposable environment is absent')
    require(value.get('gameplay', {}).get('schema') == 1 and
            value['gameplay'].get('phase') == 'entry-snapshot' and
            isinstance(value['gameplay'].get('cases'), dict), 'The real entry fixtures are absent')
    return value


def loopback(value, scheme):
    parsed = urlparse(value) if isinstance(value, str) else None
    require(parsed and parsed.scheme == scheme and parsed.hostname == '127.0.0.1' and
            parsed.username is None and parsed.password is None and parsed.port is not None and
            1024 <= parsed.port <= 65535 and not parsed.path and not parsed.query and not parsed.fragment and
            value == scheme + '://127.0.0.1:' + str(parsed.port), 'A runner origin is not exact loopback')
    return value


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file, code, message, headers, new_url):
        raise SafeFailure('An owned-runner request attempted a redirect')


class EntryMain:
    def __init__(self, args):
        self.args = args
        self.report = (ROOT / args.output).absolute() if not args.output.is_absolute() else args.output.absolute()
        require(self.report.resolve().is_relative_to(OUT.resolve()) and not self.report.exists() and
                not self.report.is_symlink(), 'Choose a fresh report in the entry validation directory')
        for item in (self.report.parent, *self.report.parent.parents):
            require(not item.is_symlink(), 'An output directory is a symlink')
            if item == ROOT:
                break
        self.state = read_state()
        self.reference_path = guarded(args.case_ref, PRIVATE, True)
        reference = json.loads(self.reference_path.read_text())
        self.case_id = reference.get('caseId')
        require(re.fullmatch(r'[a-f0-9]{16}', self.case_id or ''), 'The explicit phone case reference is invalid')
        self.case = self.state['gameplay']['cases'].get(self.case_id)
        require(isinstance(self.case, dict) and self.case.get('setupStatus') == 'ready' and
                self.case.get('ordinaryLoginPrepared') is True and
                re.fullmatch(r'hm_[a-f0-9]{12}', self.case.get('account', '')) and
                re.fullmatch(r'[a-z0-9]{15}', self.case.get('playerId', '')) and
                isinstance(self.case.get('newPassword'), str) and len(self.case['newPassword']) >= 24 and
                set(self.case.get('assignments', {})) == {'ready', 'waiting', 'expired', 'locked'},
                'The explicit case is not a prepared ordinary disposable player')
        self.ids = {v.get('assignmentId') for v in self.case['assignments'].values()}
        require(len(self.ids) == 4 and all(re.fullmatch(r'[a-z0-9]{15}', v or '') for v in self.ids) and
                self.state['assignmentId'] not in self.ids, 'The phone case assignment set is invalid')
        self.assignment_id = self.case['assignments']['ready']['assignmentId']
        self.detail = BASE + '/' + self.assignment_id
        self.start = self.detail + '/start'
        self.environment = self.identity(self.state)
        self.case_identity = json.dumps(self.case, sort_keys=True)
        tls = self.state.get('tls', {})
        self.host = loopback(tls.get('hostBase'), 'https')
        self.control_base = loopback(self.state.get('controlBase'), 'http')
        require(tls.get('base') == 'https://127.0.0.1:18443' and tls.get('hostPort') == urlparse(self.host).port,
                'The device and Host TLS receipt do not match')
        self.ca = guarded(ISOLATION / 'tls/ca.pem', ISOLATION)
        require(tls.get('caPath') == str(self.ca) and tls.get('caSha256') == sha(self.ca),
                'The exact disposable CA does not match its TLS receipt')
        self.runtime_path = guarded(args.runtime, OUT)
        runtime = json.loads(self.runtime_path.read_text())
        self.hap_sha = sha(HAP)
        density = runtime.get('window', {}).get('density')
        require(runtime.get('status') == 'passed' and runtime.get('installedHapSha256') == self.hap_sha and
                set(runtime.get('checks', {})) == CHECKS and all(runtime['checks'].values()) and
                runtime.get('window', {}).get('fontScale') == 1 and
                isinstance(density, (int, float)) and not isinstance(density, bool) and
                math.isfinite(density) and density > 0, 'A fresh matching five-check runtime and density are required')
        if args.expected_hap:
            require(self.hap_sha == args.expected_hap, 'The installed package is not the requested entry package')
        config = json.loads(CONFIG.read_text())
        require(config == {'isolated': True, 'endpoint': tls['base'], 'timeoutMs': 15000,
                           'probeTls': True, 'fontScale': 1}, 'The local config is not this entry environment')
        require(sha(CONFIG.parent / 'integration-ca.pem') == sha(self.ca), 'The local raw CA belongs to another environment')
        with zipfile.ZipFile(HAP) as archive:
            names = archive.namelist()
            configs = [n for n in names if n.endswith('/rawfile/integration.json')]
            authorities = [n for n in names if n.endswith('/rawfile/integration-ca.pem')]
            require(len(configs) == len(authorities) == 1 and archive.read(configs[0]) == CONFIG.read_bytes() and
                    hashlib.sha256(archive.read(authorities[0])).hexdigest() == sha(self.ca),
                    'The signed package does not contain this exact integration config and CA')
        require(6000 <= args.delay_ms <= 10000, 'The pending-entry delay must stay below the client timeout')
        context = ssl.create_default_context(cafile=str(self.ca))
        require(context.check_hostname and context.verify_mode == ssl.CERT_REQUIRED, 'TLS verification is required')
        self.host_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect(),
                                                      urllib.request.HTTPSHandler(context=context))
        self.control_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        self.bound = {'hap': HAP, 'runtime': self.runtime_path, 'caseReference': self.reference_path,
                      'ca': self.ca, 'config': CONFIG, 'driver': Path(__file__),
                      'nativeUI': ROOT / 'scripts/native_device_ui.py',
                      'refinementUI': ROOT / 'scripts/device-native-ui-refinements.py',
                      'runner': ROOT / 'scripts/isolated-backend.mjs'}
        self.binding = {name: sha(path) for name, path in self.bound.items()}
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        self.directory = PRIVATE / ('entry-main-' + stamp)
        self.directory.mkdir(mode=0o700, parents=True)
        self.ui = UI.RefinementUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
                                  'controlToken': self.state['controlToken']}, density, self.directory, side_panel=True)
        self.token = ''
        self.checks = []
        self.stage = 'prerequisites-complete'
        self.observations = {}
        self.cleanup = {'faultNeutralised': False, 'loggedOut': False, 'loginInputsEmpty': False,
                        'privateGameplayAbsent': False, 'remoteRawFilesRemoved': True}
        self.device_started = False
        self.fault_configured = False
        self.failure = None

    @staticmethod
    def identity(state):
        return {k: state.get(k) for k in ('pid', 'mode', 'version', 'backendSourceCommit', 'imageId',
                                         'backendBase', 'proxyBase', 'controlBase', 'controlToken', 'sourceDirectory')}, state.get('tls')

    def immutable(self):
        state = read_state()
        require(self.identity(state) == self.environment and
                json.dumps(state['gameplay']['cases'].get(self.case_id), sort_keys=True) == self.case_identity and
                all(sha(path) == self.binding[name] for name, path in self.bound.items()),
                'The exact environment, case or package binding changed')

    def request(self, opener, base, path, body=None, token=''):
        request = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(),
            method='GET' if body is None else 'POST', headers={'Accept': 'application/json',
            **({'Content-Type': 'application/json'} if body is not None else {}), **({'Authorization': token} if token else {})})
        try:
            with opener.open(request, timeout=25) as response:
                require(response.status == 200, 'An owned runner request did not return200')
                result = json.load(response)
                require(isinstance(result, dict), 'An owned runner response is not a JSON object')
                return result
        except SafeFailure:
            raise
        except Exception:
            raise SafeFailure('A strict owned-runner request did not complete; raw values omitted') from None

    def host_read(self, path, body=None):
        require((path == AUTH and body is not None) or
                (path in ('/api/questions/v1/me', BASE, self.detail) and body is None),
                'The Host helper attempted an endpoint outside authentication and exact-case reads')
        return self.request(self.host_opener, self.host, path, body, self.token)

    def control(self, path, body=None):
        require(path in ('/case-progress', '/requests', '/fault'), 'Unsupported local control operation')
        return self.request(self.control_opener, self.control_base, path, body or {}, self.state['controlToken'])

    def requests(self):
        rows = self.control('/requests').get('requests')
        require(isinstance(rows, list), 'The private request ledger is absent')
        return rows

    def starts(self):
        return [row for row in self.requests() if row.get('method') == 'POST' and row.get('path') == self.start]

    def diagnostic(self):
        result = self.control('/case-progress', {'caseId': self.case_id, 'kind': 'ready'})
        require(result.get('caseId') == self.case_id and result.get('assignmentKind') == 'ready' and
                result.get('readOnlyDiagnostic') is True and result.get('rawAnswersOrCredentialsReturned') is False,
                'The diagnostic did not identify the explicit phone case')
        return result

    def check(self, value, label):
        require(value, label)
        self.checks.append(label)
        self.save('running')
        print(json.dumps({'checksPassed': len(self.checks), 'passed': label}), flush=True)

    def save(self, status):
        result = {'status': status, 'stage': self.stage, 'scope': 'Native entry and read-only question snapshot only',
                  'hapSha256': self.hap_sha, 'bindingSha256': self.binding, 'checksPassed': len(self.checks),
                  'checks': self.checks, 'observations': self.observations, 'cleanup': self.cleanup,
                  'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
                  'visualReview': 'pending_root_original_review', 'fixedPreviewTouched': False,
                  'privateCredentialsOrRecordIdsPersisted': False,
                  'writeScope': 'Native start command only; Host authentication/read and exact disposable fault control. No answer/profile/password/admin/reset request.'}
        if self.failure:
            result['failure'] = self.failure
        encoded = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
        require(not any(secret and secret in encoded for secret in self.secrets()),
                'A private literal would enter the public report')
        self.report.parent.mkdir(parents=True, exist_ok=True)
        flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW
        descriptor = os.open(self.report, flags, 0o644)
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(encoded)

    def secrets(self):
        return [self.case_id, self.case['account'], self.case['newPassword'], self.case['initialPassword'],
                self.case['playerId'], self.state['controlToken'], self.token, *self.ids]

    def safe_failure(self, error):
        message = str(error) if isinstance(error, SafeFailure) else 'Entry checks stopped; raw diagnostics omitted'
        for value in self.secrets():
            if value:
                message = message.replace(value, '[private value omitted]')
        return message

    def main(self):
        self.stage = 'host-prerequisites'
        auth = self.host_read(AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str),
                'The fresh Host login did not identify the explicit ordinary phone player')
        self.token = auth['token']
        player = self.host_read('/api/questions/v1/me')
        before = self.host_read(self.detail)
        facts = self.diagnostic()
        self.check(player.get('id') == self.case['playerId'] and player.get('mustChangePassword') is False and
                   before.get('id') == self.assignment_id and before.get('player') == self.case['playerId'] and
                   before.get('status') == 'assigned' and not before.get('startedAt') and
                   isinstance(before.get('levels'), list) and len(before['levels']) == 2 and
                   all(level.get('question') is None for level in before['levels']) and
                   facts.get('assignmentStatus') == 'assigned' and facts.get('startedAtPresent') is False and
                   all(type(facts.get(key)) is int and facts[key] == 0 for key in ('progressRows',
                    'startReceiptCount', 'answerSubmissionCount', 'xpLedgerCount', 'xpDeltaSum')),
                   'Strict Host HTTPS confirms an ordinary player, hidden questions and zero entry facts')
        require(len(self.starts()) == 0, 'The explicit phone assignment already has start attempts')
        self.stage = 'native-login'
        self.ui.launch(cold=True)
        self.ui.wait(lambda ui: ui.find('account') is not None, 'empty owned native login')
        self.device_started = True
        self.check(self.ui.input_empty('account') and self.ui.input_empty('password') and
                   self.ui.has_text('隔离测试环境'), 'Native login starts empty in the isolated HTTPS configuration')
        self.ui.fill('account', self.case['account'])
        self.ui.fill('password', self.case['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'ordinary phone player home')
        self.check(self.ui.find('old-password') is None, 'The prepared ordinary phone player reaches home without changing password')
        self.ui.tap('assignment-' + self.assignment_id)
        self.ui.wait(lambda ui: ui.find('start-assignment') is not None, 'ready detail start action')
        self.ui.seek('start-assignment')
        self.check(not self.starts() and self.ui.find('question-title') is None,
                   'Ready detail does not start implicitly or render a protected question')
        self.stage = 'native-entry-pending'
        self.control('/fault', {'path': self.start, 'method': 'POST', 'responseDelayMs': self.args.delay_ms})
        self.fault_configured = True
        self.ui.run('devecocli', 'ui', 'click', '--id', 'start-assignment')
        raw, evidence = self.ui.raw_app('entry-pending')
        buttons = [row for row in raw if row.get('id') == 'start-assignment' and UI.exposed(row)]
        self.observations['pending'] = {'rawEvidenceSha256': evidence['sha256'],
            'enabled': buttons[0].get('enabled') if len(buttons) == 1 else None,
            'enteringLabelObserved': any(row.get('text') == '正在进入…' for row in raw)}
        self.check(len(buttons) == 1 and buttons[0].get('enabled') == 'false' and
                   self.observations['pending']['enteringLabelObserved'],
                   'Original native pending tree shows the entering label and disabled start action')
        self.stage = 'native-gameplay'
        self.ui.wait(lambda ui: ui.find('gameplay-page') is not None and ui.find('question-title') is not None,
                     'native current question after real entry', timeout=30)
        after = self.host_read(self.detail)
        question = after.get('levels', [{}])[0].get('question')
        require(isinstance(question, dict) and question.get('kind') == 'text' and
                len(after['levels']) == 2 and after['levels'][1].get('question') is None,
                'The authoritative started snapshot is not the expected protected text fixture')
        self.ui.seek('gameplay-title')
        title_ok = self.ui.find('gameplay-title').get('text') == after.get('title')
        self.ui.seek('question-title')
        question_ok = self.ui.find('question-title').get('text') == question.get('title')
        self.ui.seek('question-content-text-0')
        self.check(title_ok and question_ok and self.ui.find('question-content-text-0').get('text') == question['content'][0]['text'],
                   'Native gameplay displays the authoritative assignment, question title and text')
        raw, evidence = self.ui.raw_app('entry-current-question')
        self.check(not any(row.get('text') == '守门人的选择' for row in raw) and
                   sum(row.get('id') == 'question-title' for row in raw) == 1 and
                   after['levels'][1].get('question') is None,
                   'Future question remains null on the server and absent from the native tree')
        self.ui.private_shot('entry-current-question')
        facts = self.diagnostic()
        starts = self.starts()
        self.check(after.get('status') == 'active' and facts.get('startedAtPresent') is True and
                   facts.get('progressRows') == 2 and facts.get('startReceiptCount') == 1 and
                   facts.get('completedProgressRows') == facts.get('answerSubmissionCount') ==
                   facts.get('xpLedgerCount') == facts.get('xpDeltaSum') == 0 and len(starts) == 1 and
                   starts[0].get('status') == 200 and starts[0].get('authenticated') is True and
                   starts[0].get('bearer') is False and starts[0].get('actorVerifiedByBackendResponse') is True,
                   'Real entry creates exactly two progress rows and one raw-Authorization receipt, with no answer or XP writes')
        self.observations['entry'] = {'progressRows': 2, 'startReceiptCount': 1,
            'answerSubmissionCount': 0, 'xpLedgerCount': 0, 'rawAuthorizationNoBearer': True,
            'requestIdBodyActorHashesPresent': all(re.fullmatch(r'[a-f0-9]{64}', starts[0].get(k, '') or '')
                for k in ('requestIdSha256', 'requestBodySha256', 'actorSha256'))}
        self.stage = 'native-return-and-resume'
        self.ui.back()
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('gameplay-page') is None,
                     'native Back from gameplay to home')
        self.ui.tap('assignment-' + self.assignment_id)
        self.ui.wait(lambda ui: ui.find('gameplay-page') is not None and ui.find('question-title') is not None,
                     'active assignment resumes by GET')
        self.check(len(self.starts()) == 1, 'Back and re-entry restore the active question without another start POST')
        before_reads = sum(row.get('path') == self.detail and row.get('method') == 'GET' for row in self.requests())
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('gameplay-page') is not None and ui.find('primary-action') is not None and
                     ui.find('gameplay-loading') is None,
                     'read-only question refresh')
        self.ui.seek('question-title')
        self.check(sum(row.get('path') == self.detail and row.get('method') == 'GET' for row in self.requests()) > before_reads and
                   len(self.starts()) == 1, 'Gameplay synchronization makes a real GET and preserves the single entry command')
        self.ui.private_shot('entry-resumed-question')
        self.ui.back()
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'home before explicit logout')
        self.ui.tap('account-menu')
        self.ui.tap('logout')
        self.ui.wait(lambda ui: ui.find('account') is not None, 'explicit gameplay test logout')
        self.cleanup['loggedOut'] = True
        self.cleanup['loginInputsEmpty'] = self.ui.input_empty('account') and self.ui.input_empty('password')
        self.cleanup['privateGameplayAbsent'] = self.ui.find('gameplay-page') is None and self.ui.find('question-title') is None
        self.check(self.cleanup['loginInputsEmpty'] and self.cleanup['privateGameplayAbsent'],
                   'Explicit logout returns empty login inputs and removes the private gameplay view')
        self.immutable()

    def execute(self):
        self.save('running')
        try:
            self.main()
        except Exception as error:
            self.failure = self.safe_failure(error)
        finally:
            try:
                self.immutable()
                self.control('/fault', {'path': '/__unused_gameplay_entry_fault__', 'method': 'GET', 'status': 503})
                self.cleanup['faultNeutralised'] = True
            except Exception:
                self.failure = self.failure or 'Fault neutralization could not be confirmed for the same environment'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not self.cleanup['remoteRawFilesRemoved']:
                self.failure = self.failure or 'An exact own remote raw file cleanup was not confirmed'
            self.stage = 'main-complete' if self.failure is None else self.stage
            self.save('passed' if self.failure is None else 'incomplete')
        print(json.dumps({'status': 'passed' if self.failure is None else 'incomplete',
                          'checksPassed': len(self.checks), 'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 0 if self.failure is None else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-only actual phone main stage; all inputs must bind to the new runtime')
    run.add_argument('--stage', choices=('main',), default='main')
    run.add_argument('--runtime', '--runtime-report', dest='runtime', type=Path,
                     default=OUT / 'runtime-02.json')
    run.add_argument('--case-ref', type=Path, default=PRIVATE / 'entry-phone-case-ref2.json')
    run.add_argument('--output', type=Path, default=OUT / 'device-entry-main.json')
    run.add_argument('--expected-hap', help='Optional exact newly installed HAP SHA256 in addition to runtime binding')
    run.add_argument('--delay-ms', type=int, default=10000)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return EntryMain(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Private case, exact runtime, HTTPS or output guards did not complete; raw values omitted'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())

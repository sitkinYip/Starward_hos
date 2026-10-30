#!/usr/bin/env python3
"""Read-only native smoke for the separate fixed preview player.

Default invocation prints help. Root runs `run --runtime-report <current.json>`
only after preview-environment start/status/configure and official installation.
This never instantiates the disposable test control, resets a password, edits
profile data, or starts/stops a service. --leave-logged-in leaves the second
verified home session available for the reviewer's own inspection.
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
import subprocess
import sys
import urllib.request
from urllib.parse import urlparse
import zipfile

from native_device_ui import ROOT, SafeFailure

BASE = ROOT / 'artifacts/private/profile-preview'
PRIVATE = ROOT / 'artifacts/private/profile-preview-native'
OUT = ROOT / 'artifacts/validation/profile'
REPORT = OUT / 'preview-native-smoke.json'
HAP = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
NODE = '/Applications/DevEco-Studio.app/Contents/tools/node/bin/node'
RUNNER = ROOT / 'scripts/preview-environment.mjs'
CONFIG = ROOT / 'entry/src/main/resources/rawfile/integration.json'
CA = BASE / 'tls/ca.pem'
ENDPOINT = 'https://127.0.0.1:18443'
ACCOUNT = 'starward_preview'
RUNTIME_CHECKS = ('actualWindowReported', 'actualImmersiveWindow', 'transparentSystemBars',
                  'requestedFontScaleReported', 'threeIndependentTlsCases', 'actualLightAndDarkBarContent')
SPEC = importlib.util.spec_from_file_location('preview_refinement_ui', ROOT / 'scripts/device-native-ui-refinements.py')
NATIVE_UI = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NATIVE_UI)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise SafeFailure(message)


def guarded(path, directory, private=False):
    original = Path(path).absolute()
    actual = original.resolve()
    require(actual.is_relative_to(directory.resolve()), 'An evidence path escaped its owned directory')
    for item in (original, *original.parents):
        require(not item.is_symlink(), 'Evidence and preview identity paths cannot be symlinks')
        if item == ROOT:
            break
    info = actual.stat()
    require(stat.S_ISREG(info.st_mode), 'Evidence inputs must be regular files')
    if private:
        require(info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o600,
                'Preview private identity and credential files must be owned mode600 files')
    return actual


def read_private(name):
    return json.loads(guarded(BASE / name, BASE, True).read_text())


def save(path, value, private=False):
    require(not path.is_symlink(), 'Evidence output cannot replace a symlink')
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700 if private else 0o755)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW,
                         0o600 if private else 0o644)
    with os.fdopen(descriptor, 'w') as target:
        json.dump(value, target, ensure_ascii=False, indent=2)
        target.write('\n')
    if private:
        path.chmod(0o600)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file, code, message, headers, new_url):
        raise SafeFailure('The dedicated preview HTTPS request did not stay on its exact loopback origin')


class Smoke:
    def __init__(self, args):
        self.args = args
        self.manifest = read_private('manifest.json')
        self.run = read_private('run.json')
        self.login = read_private('login.json')
        require(self.manifest.get('mode') == 'persistent isolated player preview' and
                self.manifest.get('initialized') is True and self.manifest.get('initializationStatus') == 'complete' and
                self.manifest.get('account') == self.login.get('account') == ACCOUNT and
                self.run.get('owner') == self.manifest.get('owner') and self.run.get('mode') == self.manifest['mode'] and
                self.login.get('endpoint') == ENDPOINT and isinstance(self.login.get('password'), str) and
                len(self.login['password']) >= 10 and re.fullmatch(r'[a-z0-9]{15}', self.manifest.get('playerId', '')),
                'Only the initialized fixed preview account is authorized for this smoke')
        origin = urlparse(self.run.get('hostBase', ''))
        require(origin.scheme == 'https' and origin.hostname == '127.0.0.1' and origin.port == self.run.get('hostPort') and
                not origin.path and not origin.query and not origin.fragment and not origin.username,
                'Preview Host HTTPS origin must be the exact recorded loopback gateway')
        self.runtime_path = guarded(args.runtime_report, OUT)
        self.runtime = json.loads(self.runtime_path.read_text())
        self.hap_sha = sha(HAP)
        window = self.runtime.get('window', {})
        density = window.get('density')
        checks = self.runtime.get('checks', {})
        require(self.runtime.get('status') == 'passed' and self.runtime.get('installedHapSha256') == self.hap_sha and
                set(checks) == set(RUNTIME_CHECKS) and all(checks[key] is True for key in RUNTIME_CHECKS) and window.get('fontScale') == 1 and
                isinstance(density, (int, float)) and not isinstance(density, bool) and math.isfinite(density) and density > 0,
                'The actual six-check installed-HAP runtime and font1 density are required')
        self.ca_path = guarded(CA, BASE, True)
        require(sha(self.ca_path) == self.manifest.get('caSha256'), 'The dedicated preview CA changed')
        config = json.loads(CONFIG.read_text())
        require(config == {'isolated': True, 'endpoint': ENDPOINT, 'timeoutMs': 15000, 'probeTls': True, 'fontScale': 1},
                'The local build configuration does not identify only the fixed preview environment')
        require(sha(CONFIG.parent / 'integration-ca.pem') == self.manifest['caSha256'], 'Packaged local CA belongs to another environment')
        with zipfile.ZipFile(HAP) as package:
            entries = package.namelist()
            config_names = [name for name in entries if name.endswith('/rawfile/integration.json')]
            ca_names = [name for name in entries if name.endswith('/rawfile/integration-ca.pem')]
            require(len(config_names) == len(ca_names) == 1 and
                    package.read(config_names[0]) == CONFIG.read_bytes() and
                    hashlib.sha256(package.read(ca_names[0])).hexdigest() == self.manifest['caSha256'],
                    'Signed HAP does not contain the exact dedicated preview config and CA')
        self.host_report = guarded(OUT / 'preview-environment.json', OUT)
        host = json.loads(self.host_report.read_text())
        require(host.get('status') == 'host_ready_native_pending' and host.get('mode') == self.manifest['mode'] and
                host.get('directLoginValidation') == 'verified_direct_login' and host.get('caSha256') == self.manifest['caSha256'] and
                host.get('tlsChecks', {}).get('positive200') is True and host['tlsChecks'].get('untrustedRejected') is True and
                host['tlsChecks'].get('wrongHostnameRejected') is True,
                'The independent preview host readiness/TLS/direct-login report must already pass')
        # The runner performs its own UID/argv/cwd/birth/listener/container checks.
        status = subprocess.run([NODE, str(RUNNER), 'status'], cwd=ROOT, capture_output=True, text=True, timeout=40)
        require(status.returncode == 0, 'The exact independent preview runner did not confirm its owner/status')
        observed = json.loads(status.stdout)
        require(observed.get('running') is True and observed.get('owner') == self.manifest['owner'] and
                observed.get('loginValidation') == 'verified_direct_login',
                'Saved preview login is no longer verified; no automatic reset was attempted')
        self.context = ssl.create_default_context(cafile=self.ca_path)
        self.opener = urllib.request.build_opener(NoRedirect(), urllib.request.HTTPSHandler(context=self.context))
        self.bound = {'hap': HAP, 'runtime': self.runtime_path, 'manifest': BASE / 'manifest.json',
                      'runner': RUNNER, 'hostReadiness': self.host_report, 'config': CONFIG, 'ca': self.ca_path,
                      'profileUI': ROOT / 'scripts/device-profile-acceptance.py', 'nativeUI': ROOT / 'scripts/native_device_ui.py',
                      'refinementUI': ROOT / 'scripts/device-native-ui-refinements.py',
                      'driver': Path(__file__)}
        self.binding = {key: sha(path) for key, path in self.bound.items()}
        if REPORT.exists():
            require(False, 'A preview-native report already exists; preserve prior evidence before a fresh run')
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        PRIVATE.mkdir(parents=True, mode=0o700, exist_ok=True)
        PRIVATE.chmod(0o700)
        self.directory = PRIVATE / ('capture-' + stamp)
        self.directory.mkdir(mode=0o700)
        # Reuse only the reviewed UI class; no disposable Acceptance/control is constructed.
        self.ui = NATIVE_UI.RefinementUI({'account': self.login['account'], 'initialPassword': self.login['password']},
                                         density, self.directory, side_panel=True)
        self.checks = []
        self.cleanup = {'firstExplicitLogoutObserved': False, 'firstLogoutInputsEmpty': False,
                        'secondDirectLoginObserved': False, 'finalStateObserved': False}
        self.device_started = False

    def request(self, route, body=None, token=''):
        require(route in ('/api/collections/game_players/auth-with-password', '/api/questions/v1/me', '/api/questions/v1/assignments') and
                (body is None or route == '/api/collections/game_players/auth-with-password'), 'The preview smoke Host API scope is read-only plus authentication')
        request = urllib.request.Request(self.run['hostBase'] + route,
            data=None if body is None else json.dumps(body).encode(), method='GET' if body is None else 'POST',
            headers={'Accept': 'application/json', **({'Authorization': token} if token else {}),
                     **({'Content-Type': 'application/json'} if body is not None else {})})
        try:
            with self.opener.open(request, timeout=25) as response:
                require(response.status == 200, 'A dedicated preview Host read did not return200')
                return json.load(response)
        except Exception:
            raise SafeFailure('Strict dedicated preview HTTPS read/authentication did not complete; values omitted') from None

    def check(self, condition, label):
        require(condition, label)
        self.checks.append(label)

    def immutable(self):
        require(all(sha(path) == self.binding[key] for key, path in self.bound.items()),
                'Preview HAP/runtime/identity/helper evidence changed during the smoke')

    def login_native(self):
        self.ui.fill('account', self.login['account'])
        self.ui.fill('password', self.login['password'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'fixed preview enters authenticated home directly')
        self.check(self.ui.find('old-password') is None and self.ui.find('forced-logout') is None,
                   'The fixed preview login reaches home without the first-password gate')
        for assignment in self.manifest['assignments'].values():
            self.ui.seek('assignment-' + assignment['assignmentId'])
        self.check(True, 'All dedicated real preview assignment identities are reachable in native home')

    def logout(self):
        self.ui.tap('account-menu')
        self.ui.seek('logout')
        self.ui.tap('logout')
        self.ui.wait(lambda ui: ui.find('account') is not None, 'explicit preview logout')
        self.check(self.ui.input_empty('account') and self.ui.input_empty('password'),
                   'Explicit preview logout returns to both empty login inputs')

    def execute(self):
        failure = None
        try:
            auth = self.request('/api/collections/game_players/auth-with-password',
                                {'identity': self.login['account'], 'password': self.login['password']})
            player = self.request('/api/questions/v1/me', token=auth['token'])
            assignments = self.request('/api/questions/v1/assignments', token=auth['token'])
            expected = {value['assignmentId'] for value in self.manifest['assignments'].values()}
            self.check(player.get('id') == auth.get('record', {}).get('id') == self.manifest['playerId'] and
                       player.get('account') == ACCOUNT and player.get('mustChangePassword') is False and
                       isinstance(player.get('displayName'), str), 'Fresh strict Host HTTPS confirms the ordinary fixed preview identity')
            self.check(isinstance(assignments.get('items'), list) and
                       {item.get('id') for item in assignments['items']} == expected,
                       'Fresh Host assignment list exactly matches the dedicated seeded preview records')
            # No token or full player DTO is written into evidence.
            del auth
            self.ui.launch()
            self.ui.wait(lambda ui: ui.find('account') is not None, 'pre-existing empty login before fixed preview smoke')
            self.check(self.ui.input_empty('account') and self.ui.input_empty('password'), 'Fixed preview smoke starts at empty native login')
            self.device_started = True
            self.ui.launch(cold=True)
            self.ui.wait(lambda ui: ui.find('account') is not None, 'cold native preview login')
            self.check(self.ui.has_text('隔离测试环境') and not self.ui.has_text('演示环境'), 'Native login visibly identifies its isolated real HTTPS configuration')
            self.login_native()
            self.ui.private_shot('first-direct-home')
            self.ui.tap('nav-profile')
            self.ui.wait(lambda ui: ui.find('profile-scroll') is not None, 'fixed preview native passport')
            self.ui.seek('profile-name')
            self.check(self.ui.find('profile-name').get('text') == player['displayName'], 'Native profile nickname matches the fresh authoritative preview player')
            self.ui.seek('profile-account')
            account = self.ui.find('profile-account')
            self.check(account.get('text') == ACCOUNT and account.get('type') not in ('TextInput', 'TextArea'),
                       'Native profile shows the fixed preview account as read-only')
            self.ui.private_shot('fixed-preview-profile')
            self.ui.tap('account-menu')
            self.ui.wait(lambda ui: ui.find('menu-home') is not None or ui.find('logout') is not None, 'fixed preview account menu')
            self.ui.back()
            self.ui.wait(lambda ui: ui.find('menu-home') is None and ui.find('profile-scroll') is not None, 'official Back closes only the account menu')
            self.check(True, 'Account menu Back returns to the same native profile')
            self.logout()
            self.cleanup['firstExplicitLogoutObserved'] = True
            self.cleanup['firstLogoutInputsEmpty'] = True
            self.login_native()
            self.cleanup['secondDirectLoginObserved'] = True
            self.ui.private_shot('second-direct-home')
            if self.args.leave_logged_in:
                self.ui.capture()
                self.check(self.ui.find('current-tab') is not None and self.ui.find('account') is None,
                           'The second direct session is left on authenticated home for the reviewer')
            else:
                self.logout()
            self.cleanup['finalStateObserved'] = True
            self.immutable()
        except Exception as error:
            failure = str(error) if isinstance(error, SafeFailure) else 'Preview smoke stopped; raw values and diagnostics omitted'
        report = {'status': 'passed' if failure is None else 'incomplete', 'scope': 'Fixed isolated preview direct-login/read-only native smoke',
                  'hapSha256': self.hap_sha, 'bindingSha256': self.binding, 'checksPassed': len(self.checks), 'checks': self.checks,
                  'privateScreenshots': self.ui.private_screenshots, 'cleanup': self.cleanup,
                  'leftLoggedInForReview': failure is None and self.args.leave_logged_in,
                  'businessWriteLedgerObserved': False,
                  'writeScope': 'Commands only authenticate/read/navigate/logout; no profile-save, password-save, reset or fault control is invoked. No server write-ledger claim.',
                  'appCredentialsPersisted': False, 'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        if failure:
            report['failure'] = failure
            report['cleanupMeaning'] = 'Flags record only completed observations; root must inspect the actual foreground before further actions'
        save(REPORT, report)
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks),
                          'leftLoggedInForReview': report['leftLoggedInForReview'], 'report': str(REPORT.relative_to(ROOT))}))
        return 0 if failure is None else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-only actual phone smoke after separate preview install/runtime evidence')
    run.add_argument('--runtime-report', type=Path, required=True)
    run.add_argument('--leave-logged-in', action='store_true', help='Leave the second verified preview home session for manual review')
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return Smoke(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started', 'error': 'Fixed preview prerequisites/ownership/runtime guards did not complete; no device action is claimed'}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

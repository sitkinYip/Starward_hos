#!/usr/bin/env python3
"""S2 phone acceptance: a real password write whose response is deliberately lost.

Run only after device-profile-acceptance.py passes against the same dedicated
HTTPS backend and HAP. Own the phone and local fault-control endpoint. This
script never resets or repeats the password write to recover from uncertainty.
It finishes with the newly set password and an explicitly logged-out phone.
"""
import argparse
import datetime
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import time

from native_device_ui import ROOT, IsolationControl, SafeFailure
from isolated_snapshot import ReadonlySnapshot

SPEC = importlib.util.spec_from_file_location('profile_acceptance', Path(__file__).with_name('device-profile-acceptance.py'))
CORE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CORE)
OUT = CORE.OUT
REPORT = OUT / 'device-profile-password-uncertain.json'
MESSAGE = '密码修改结果尚未确认。请退出登录，尝试使用新密码登录确认结果。'
CHANGE = CORE.CHANGE
PROFILE = CORE.PROFILE


class PasswordUncertainAcceptance:
    def __init__(self, runtime_path, core_path, reverse_from_prior=None):
        self.control = IsolationControl()
        self.state = self.control.state
        self.runtime_path = runtime_path.resolve()
        self.core_path = core_path.resolve()
        for path in (self.runtime_path, self.core_path):
            if not path.is_relative_to(OUT.resolve()):
                raise SafeFailure('S2 prerequisite reports must remain in the profile validation directory')
        self.hap_path = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
        self.hap_sha = CORE.sha(self.hap_path)
        self.runtime_sha = CORE.sha(self.runtime_path)
        self.core_sha = CORE.sha(self.core_path)
        runtime = json.loads(self.runtime_path.read_text())
        core = json.loads(self.core_path.read_text())
        config = json.loads((ROOT / 'entry/src/main/resources/rawfile/integration.json').read_text())
        density = runtime.get('window', {}).get('density')
        if (config.get('isolated') is not True or config.get('endpoint') != self.state['tls']['base'] or
                not self.state.get('account', '').startswith('hm_')):
            raise SafeFailure('A packaged dedicated HTTPS environment is required for S2')
        if (runtime.get('status') != 'passed' or runtime.get('installedHapSha256') != self.hap_sha or
                not isinstance(density, (int, float)) or not math.isfinite(density) or density <= 0):
            raise SafeFailure('Actual S2 runtime must match the packaged HAP')
        if (core.get('status') != 'passed' or core.get('finalPasswordKey') != 'initialPassword' or
                core.get('cleanup', {}).get('loggedOut') is not True or
                core.get('cleanup', {}).get('faultNeutralised') is not True or
                core.get('hap', {}).get('packagedSha256') != self.hap_sha or
                core.get('runtime', {}).get('sha256') != self.runtime_sha):
            raise SafeFailure('S2 requires the passed core run, initial password and completed logout on the same HAP/runtime')
        self.source_password_key = 'initialPassword'
        self.target_password_key = 'newPassword'
        self.prior_provenance = None
        prior = None
        prior_path = None
        if reverse_from_prior is not None:
            prior_path = reverse_from_prior.resolve()
            if not prior_path.is_relative_to(OUT.resolve()) or prior_path == self.core_path or prior_path == self.runtime_path:
                raise SafeFailure('The prior S2 report must be a separate report inside the profile validation directory')
            prior = json.loads(prior_path.read_text())
            dropped_success = any(
                row.get('path') == CHANGE and row.get('method') == 'POST' and row.get('status') == 200 and
                row.get('responseDropped') is True and row.get('fault') is True
                for phase in prior.get('requestLedger', []) for row in phase.get('requests', []))
            if (prior.get('status') not in ('incomplete', 'passed') or prior.get('finalPasswordKey') != 'newPassword' or
                    prior.get('cleanup', {}).get('loggedOut') is not True or
                    prior.get('cleanup', {}).get('faultNeutralised') is not True or not dropped_success or
                    prior.get('hap', {}).get('packagedSha256') != self.hap_sha or
                    prior.get('runtime', {}).get('sha256') != self.runtime_sha or
                    prior.get('corePrerequisite', {}).get('sha256') != self.core_sha):
                raise SafeFailure('Reverse S2 requires a prior new-password result and clean logout on the same HAP/runtime/core')
            self.source_password_key = 'newPassword'
            self.target_password_key = 'initialPassword'
        self.driver_sha = CORE.sha(Path(__file__))
        self.profile_helper_sha = CORE.sha(Path(__file__).with_name('device-profile-acceptance.py'))
        self.ui = CORE.ProfileUI(self.state, density)
        self.checks = []
        self.started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        self.start_ledger = len(self.control.requests())
        self.before_change = None
        self.before_profile = None
        self.final_password_key = self.source_password_key
        self.cleanup = {'faultNeutralised': False, 'loggedOut': False}
        self.fault_armed = False
        self.device_started = False
        self.readiness_confirmed = False
        self.raw_layout_evidence = []
        OUT.mkdir(parents=True, exist_ok=True)
        previous_archive = None
        if REPORT.exists():
            previous_archive = self.archive(REPORT)
        if prior_path is not None:
            prior_sha = CORE.sha(prior_path)
            archived = previous_archive if prior_path == REPORT.resolve() else self.archive(prior_path)
            if archived is None or CORE.sha(archived) != prior_sha:
                raise SafeFailure('The previous S2 report could not be archived byte for byte')
            self.prior_provenance = {'file': str(archived.relative_to(ROOT)), 'sha256': prior_sha,
                                     'originalFile': str(prior_path.relative_to(ROOT)),
                                     'status': prior['status'], 'count': prior.get('count'),
                                     'finalPasswordKey': prior['finalPasswordKey'], 'cleanup': prior['cleanup'],
                                     'sameHapRuntimeCore': True}
        self.command_argv = ['python3', 'scripts/device-profile-password-uncertain.py', '--runtime-report',
                             str(self.runtime_path.relative_to(ROOT)), '--core-report', str(self.core_path.relative_to(ROOT))]
        if prior_path is not None:
            self.command_argv += ['--reverse-from-prior', str(prior_path.relative_to(ROOT))]
        self.report('running')

    def archive(self, path):
        attempts = OUT / 'attempts'
        attempts.mkdir(exist_ok=True)
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        digest = CORE.sha(path)
        target = attempts / ('password-uncertain-' + stamp + '-' + digest[:12] + '.json')
        shutil.copyfile(path, target)
        if CORE.sha(target) != digest:
            raise SafeFailure('S2 report archival did not preserve its bytes')
        return target

    def report(self, status, error=None):
        result = {
            'status': status, 'scope': 'S2 ordinary password response-loss recovery on the real phone',
            'environment': 'real isolated PocketBase over strict USB HTTPS', 'deviceApi': 26,
            'startedAt': self.started_at, 'updatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'count': len(self.checks), 'checks': self.checks,
            'hap': {'packagedSha256': self.hap_sha,
                    'installationEvidence': 'Separate official scripts/hm.sh run log is required'},
            'runtime': {'file': str(self.runtime_path.relative_to(ROOT)), 'sha256': self.runtime_sha},
            'corePrerequisite': {'file': str(self.core_path.relative_to(ROOT)), 'sha256': self.core_sha},
            'driver': {'file': 'scripts/device-profile-password-uncertain.py', 'sha256': self.driver_sha,
                       'profileHelperSha256': self.profile_helper_sha,
                       'enabledSource': 'Official bundle-scoped HDC UiTest dumpLayout node.attributes.enabled; strict true/false strings'},
            'experiment': {'mode': 'reverse-from-prior' if self.prior_provenance else 'initial-to-new',
                           'sourcePasswordKey': self.source_password_key, 'targetPasswordKey': self.target_password_key,
                           'invokedCommandArgv': self.command_argv,
                           'scope': 'One separately invoked experiment with a new explicit password command; no replay or resumed checks'},
            'priorExperiment': self.prior_provenance, 'rawLayoutEvidence': self.raw_layout_evidence,
            'requestLedger': self.control.ledger, 'privateScreenshots': self.ui.private_screenshots,
            'cleanup': self.cleanup, 'finalPasswordKey': self.final_password_key,
            'limitations': ['The response loss is explicitly injected after the real upstream response',
                            'CLI/UiTest checks are not Hypium instrument tests',
                            'No reset or recovery password write is performed',
                            'This run does not accept avatar, production or deferred device scopes']}
        if error:
            result['error'] = self.ui.redact(error)
        REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')

    def check(self, condition, label):
        if not condition:
            raise SafeFailure('S2 expectation did not hold: ' + label)
        self.checks.append({'case': 'S2', 'label': label, 'injectedResilience': True})
        self.report('running')
        print(json.dumps({'count': len(self.checks), 'passed': label}, ensure_ascii=False), flush=True)

    def rows(self, path, method):
        return [row for row in self.control.requests() if row.get('path') == path and row.get('method') == method]

    def checkpoint(self, phase):
        allowed = ('method', 'path', 'status', 'fault', 'responseDropped', 'authenticated', 'bearer',
                   'bodyKind', 'avatarPartPresent', 'requestBytes', 'fileTokenProvided')
        rows = []
        for row in self.control.requests()[self.start_ledger:]:
            item = {key: row[key] for key in allowed if key in row}
            path = str(item.get('path', '')).split('?', 1)[0]
            if path.startswith('/api/files/game_players/'):
                path = '/api/files/game_players/[owner]/[avatar]'
            item['path'] = path
            rows.append(item)
        self.control.ledger.append({'phase': phase, 'requests': rows})
        self.report('running')

    def login(self, password_key):
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state[password_key])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'S2 authenticated home')
        if self.ui.find('old-password') is not None:
            raise SafeFailure('S2 unexpectedly entered the mandatory-password gate')

    def logout(self, explicit_uncertain=False):
        self.ui.hide_keyboard()
        self.ui.capture()
        if explicit_uncertain:
            self.ui.tap('security-unconfirmed-logout')
        elif self.ui.find('account') is None:
            if self.ui.find('account-menu') is None:
                raise SafeFailure('S2 could not find a safe explicit logout action')
            self.ui.tap('account-menu')
            self.ui.seek('logout')
            self.ui.tap('logout')
        self.ui.wait(lambda ui: ui.find('account') is not None, 'S2 empty login after logout')
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('S2 logout did not clear the login fields')

    def disabled(self, node_id):
        self.ui.seek(node_id)
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        remote = '/data/local/tmp/starward-own-layout-s2-' + stamp + '.json'
        target = CORE.PRIVATE_SHOTS / ('raw-s2-layout-' + stamp + '.json')
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        os.close(descriptor)
        evidence = {'nodeId': node_id, 'file': str(target.relative_to(ROOT)),
                    'source': 'Official HDC UiTest raw dumpLayout', 'remoteRemoved': False}
        try:
            # The installed official CLI uses these UiTest dump/recv commands
            # internally. Its public full tree drops enabled and false flags;
            # preserve the unmodified raw file privately for this assertion.
            self.ui.run('hdc', 'shell', 'uitest', 'dumpLayout', '-b', 'com.sitkin.starward', '-p', remote)
            self.ui.run('hdc', 'file', 'recv', remote, target)
            target.chmod(0o600)
            evidence['sha256'] = CORE.sha(target)
            raw = json.loads(target.read_text())
            matches = []

            def visit(value):
                if isinstance(value, list):
                    for child in value:
                        visit(child)
                elif isinstance(value, dict):
                    attributes = value.get('attributes')
                    if isinstance(attributes, dict) and attributes.get('id') == node_id:
                        matches.append(attributes)
                    visit(value.get('children', []))

            visit(raw)
            evidence['matchingNodes'] = len(matches)
            if len(matches) != 1:
                raise SafeFailure('Raw UiTest enabled state is unknown: expected one exact control: ' + node_id)
            enabled = matches[0].get('enabled')
            if not isinstance(enabled, str) or enabled not in ('true', 'false'):
                evidence['enabled'] = 'unknown'
                raise SafeFailure('Raw UiTest enabled attribute is missing or unsupported: ' + node_id)
            evidence['enabled'] = enabled == 'true'
            return enabled == 'false'
        except SafeFailure:
            raise
        except Exception:
            raise SafeFailure('Raw UiTest enabled state could not be read: ' + node_id) from None
        finally:
            target.chmod(0o600)
            try:
                # Delete only the unique raw dump created by this invocation.
                self.ui.run('hdc', 'shell', 'rm', '-f', remote)
                evidence['remoteRemoved'] = True
            finally:
                self.raw_layout_evidence.append(evidence)

    def no_additional_writes(self):
        return (len(self.rows(CHANGE, 'POST')) == self.before_change + 1 and
                len(self.rows(PROFILE, 'PATCH')) == self.before_profile)

    def prepare(self):
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state[self.source_password_key])
        if snapshot.request(CORE.ME).get('mustChangePassword') is not False:
            raise SafeFailure('S2 requires the dedicated player after its completed ordinary password change')
        self.readiness_confirmed = True
        self.ui.launch()
        self.device_started = True
        self.ui.wait(lambda ui: ui.find('account') is not None, 'S2 prerequisite logged-out phone')
        self.check(self.ui.input_empty('account') and self.ui.input_empty('password') and
                   self.ui.has_text('隔离测试环境') and not self.ui.has_text('演示环境'),
                   'The same dedicated HTTPS phone starts logged out with empty inputs')
        self.login(self.source_password_key)
        self.ui.tap('nav-profile')
        self.ui.wait(lambda ui: ui.find('profile-scroll') is not None, 'S2 profile identity form')
        self.ui.tap('profile-security-tab')
        self.ui.wait(lambda ui: ui.find('security-old-password') is not None, 'S2 ordinary security form')
        for node_id, key in [('security-old-password', self.source_password_key),
                             ('security-new-password', self.target_password_key),
                             ('security-confirm-password', self.target_password_key)]:
            self.ui.fill(node_id, self.state[key])

    def lose_response(self):
        self.before_change = len(self.rows(CHANGE, 'POST'))
        self.before_profile = len(self.rows(PROFILE, 'PATCH'))
        self.control.call('/fault', {'path': CHANGE, 'method': 'POST', 'dropResponse': True})
        self.fault_armed = True
        # Until the authoritative ledger is collected, do not claim which of
        # the two passwords now applies if device or network handling fails.
        self.final_password_key = 'unconfirmed'
        self.ui.tap('security-save')
        deadline = time.monotonic() + 35
        row = None
        while time.monotonic() < deadline:
            rows = self.rows(CHANGE, 'POST')
            if len(rows) > self.before_change and rows[self.before_change].get('status'):
                row = rows[self.before_change]
                break
            time.sleep(.15)
        if not row or row.get('status') != 200 or row.get('fault') is not True or row.get('responseDropped') is not True:
            raise SafeFailure('S2 did not observe a real successful upstream password response followed by the injected loss')
        self.final_password_key = self.target_password_key
        self.check(row.get('authenticated') is True and row.get('bearer') is False,
                   'One authenticated upstream password write really returns200 before its response is deliberately dropped')
        self.ui.wait(lambda ui: ui.find('security-error') is not None and ui.has_text(MESSAGE),
                     'S2 persistent uncertain-password explanation', timeout=35, save='s2-security-response-lost')
        self.check(self.ui.find('security-saved') is None and self.no_additional_writes(),
                   'The lost response produces an explicit unknown result without success or automatic password replay')
        self.check(self.disabled('security-save') and all(self.disabled(node_id) for node_id in
                   ('security-old-password', 'security-new-password', 'security-confirm-password')),
                   'The uncertain security form disables its password fields and save action')
        self.ui.tap('security-save')
        self.ui.capture()
        self.check(self.no_additional_writes() and self.ui.has_text(MESSAGE),
                   'Tapping the disabled password action preserves the explanation and sends no replay')
        self.ui.private_shot('s2-password-result-uncertain')
        self.ui.tap('profile-identity-tab')
        self.ui.wait(lambda ui: ui.find('profile-scroll') is not None, 'S2 identity tab after uncertain write')
        self.check(self.disabled('profile-name') and self.disabled('profile-save') and self.disabled('profile-avatar-pick'),
                   'The same uncertain session also disables nickname and avatar writes')
        self.ui.tap('profile-save')
        self.ui.foreground_cycle()
        self.ui.wait(lambda ui: ui.find('profile-scroll') is not None and ui.has_text(MESSAGE),
                     'S2 persistent explanation after foreground refresh', save='s2-identity-write-blocked')
        self.check(self.no_additional_writes() and self.ui.find('profile-security-unconfirmed') is not None,
                   'The unknown result remains visible after changing tabs and foregrounding, with no profile or password replay')
        self.ui.tap('profile-security-tab')
        self.ui.wait(lambda ui: ui.find('profile-scroll') is not None, 'S2 security Scroll after tab switch')
        # CLI layouts contain the visible viewport only. Reach the recovery
        # action through the real Scroll before checking its persistent copy.
        self.ui.seek('security-unconfirmed-logout')
        self.check(self.ui.has_text(MESSAGE) and self.ui.find('security-saved') is None and self.no_additional_writes(),
                   'Returning to security retains the unknown result and an explicit logout recovery action')
        self.checkpoint('response-loss-and-write-boundary')

    def confirm_recovery(self):
        self.logout(explicit_uncertain=True)
        self.check(True, 'Explicit logout from the uncertain state clears both native login fields')
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state[self.target_password_key])
        player = snapshot.request(CORE.ME)
        self.check(player.get('mustChangePassword') is False,
                   'A fresh strict-HTTPS authentication confirms that this experiment target password is authoritative')
        self.login(self.target_password_key)
        self.check(self.ui.find('old-password') is None and self.no_additional_writes(),
                   'The phone logs in with the target password and reaches home without a second password write')
        self.ui.tap('nav-profile')
        self.ui.wait(lambda ui: ui.find('profile-scroll') is not None, 'S2 profile after fresh authentication')
        self.check(not self.disabled('profile-name') and not self.disabled('profile-save') and
                   self.ui.find('profile-security-unconfirmed') is None,
                   'Fresh authentication restores the usable profile editor and clears old-session uncertainty')
        self.logout()
        self.ui.back()
        self.ui.launch()
        self.ui.wait(lambda ui: ui.find('account') is not None, 'S2 logout Back and Ability gate')
        self.cleanup['loggedOut'] = self.ui.input_empty('account') and self.ui.input_empty('password')
        self.check(self.cleanup['loggedOut'] and self.no_additional_writes(),
                   'Final Back and Ability relaunch stay at empty login after exactly one password write')
        self.checkpoint('target-password-confirmed-and-logged-out')

    def run(self):
        failure = None
        try:
            self.prepare()
            self.lose_response()
            self.confirm_recovery()
        except Exception as error:
            failure = str(error) if isinstance(error, SafeFailure) else 'S2 helper stopped before acceptance completed'
        finally:
            # Neutralise only this script's matcher; never reset the player or
            # submit a second password change as cleanup.
            if self.fault_armed:
                try:
                    self.control.call('/fault', {'path': '/__never_forward_s2_fault__', 'method': 'GET', 'status': 503})
                    self.cleanup['faultNeutralised'] = True
                except Exception:
                    failure = failure or 'S2 fault cleanup did not complete'
            if self.device_started and self.readiness_confirmed and not self.cleanup['loggedOut']:
                try:
                    self.logout()
                    self.cleanup['loggedOut'] = True
                except Exception:
                    failure = failure or 'S2 explicit logout cleanup did not complete'
            try:
                if (CORE.sha(self.hap_path) != self.hap_sha or CORE.sha(self.runtime_path) != self.runtime_sha or
                        CORE.sha(self.core_path) != self.core_sha or CORE.sha(Path(__file__)) != self.driver_sha or
                        CORE.sha(Path(__file__).with_name('device-profile-acceptance.py')) != self.profile_helper_sha or
                        (self.prior_provenance is not None and
                         CORE.sha(ROOT / self.prior_provenance['file']) != self.prior_provenance['sha256'])):
                    failure = failure or 'S2 prerequisite evidence changed during the phone run'
                self.checkpoint('final-cleanup')
            except Exception:
                failure = failure or 'S2 final evidence could not be collected'
            try:
                if not failure and (len(self.checks) < 12 or self.final_password_key != self.target_password_key or
                                    not all(self.cleanup.values()) or not self.no_additional_writes()):
                    failure = 'S2 recovery coverage was incomplete'
            except Exception:
                failure = failure or 'S2 final write-boundary check could not be collected'
            self.report('incomplete' if failure else 'passed', failure)
        print(json.dumps({'status': 'incomplete' if failure else 'passed', 'count': len(self.checks),
                          'scope': 'S2 response-loss only', 'report': str(REPORT.relative_to(ROOT)),
                          'finalPasswordKey': self.final_password_key, 'cleanup': self.cleanup}, ensure_ascii=False))
        return 1 if failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-report', type=Path, default=OUT / 'runtime.json')
    parser.add_argument('--core-report', type=Path, default=OUT / 'device-profile-acceptance.json')
    parser.add_argument('--reverse-from-prior', type=Path,
                        help='Run a separately invoked newPassword-to-initialPassword experiment using this prior S2 report')
    args = parser.parse_args()
    try:
        return PasswordUncertainAcceptance(args.runtime_report, args.core_report, args.reverse_from_prior).run()
    except Exception as error:
        text = str(error) if isinstance(error, SafeFailure) else 'S2 setup stopped before acceptance completed'
        print(json.dumps({'status': 'incomplete', 'scope': 'S2 setup', 'error': text}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

#!/usr/bin/env python3
"""Root-only fixed-preview direct-login/list smoke after gameplay validation.

Default help performs no private or device IO. Explicit run preserves the
original preview ownership, identity, HAP, CA, Host-readiness and runner guards.
Only cold login and the real read-only assignment list are checked; the final
authenticated home remains available for the reviewer. No business write ledger
is queried or claimed, and no start/answer/profile/password/reset/seed command or
service start/stop/change is issued by this helper.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

from native_device_ui import ROOT, SafeFailure

SPEC = importlib.util.spec_from_file_location('gameplay_fixed_preview_binding', ROOT / 'scripts/device-preview-smoke.py')
PREVIEW = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREVIEW)
BOUT = ROOT / 'artifacts/validation/gameplay-answer-20261104'
# This narrow smoke requires the five actual checks captured for the restored
# package. It does not add a fabricated light/dark result or alter runtime data.
PREVIEW.RUNTIME_CHECKS = ('actualWindowReported', 'actualImmersiveWindow', 'transparentSystemBars',
                          'requestedFontScaleReported', 'threeIndependentTlsCases')
# OUT remains the original profile directory for runtime/Host-readiness guards.
PREVIEW.REPORT = BOUT / 'preview-login-list-smoke.json'


def fresh_report_path(value):
    path = (ROOT / value).absolute() if not value.is_absolute() else value.absolute()
    PREVIEW.require(path.resolve().is_relative_to(BOUT.resolve()) and path.suffix == '.json' and
                    not path.exists() and not path.is_symlink(),
                    'Choose a fresh JSON report in the gameplay-answer validation directory')
    for item in (path.parent, *path.parent.parents):
        PREVIEW.require(not item.is_symlink(), 'The gameplay preview report directory is a symlink')
        if item == ROOT:
            break
    return path


def save_fresh_report(path, report, secrets):
    fresh_report_path(path)
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    PREVIEW.require(not any(value and value in encoded for value in secrets),
                    'A private literal would enter the public gameplay preview report')
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
    with os.fdopen(descriptor, 'w') as stream:
        stream.write(encoded)


class GameplayPreviewSmoke(PREVIEW.Smoke):
    def execute(self):
        self.bound['gameplayPreviewDriver'] = Path(__file__)
        self.binding['gameplayPreviewDriver'] = PREVIEW.sha(Path(__file__))
        self.cleanup = {'coldEmptyLoginObserved': False, 'directHomeObserved': False,
                        'finalHomeObserved': False, 'remoteRawFilesRemoved': True}
        self.stage = 'expected-package'
        failure = None
        expected = set()
        token = ''
        secrets = [self.login['account'], self.login['password'], self.manifest['playerId'],
                   self.manifest.get('owner', '')]
        records = self.manifest.get('assignments')
        if isinstance(records, dict):
            for value in records.values():
                if isinstance(value, dict):
                    secrets.extend(value.get(key, '') for key in ('assignmentId', 'sessionId'))
        secrets = [value for value in secrets if isinstance(value, str)]
        try:
            PREVIEW.require(self.hap_sha == self.args.expected_hap,
                            'The restored preview package is not the explicit requested HAP')
            self.stage = 'cold-empty-login'
            self.device_started = True
            self.ui.launch(cold=True)
            self.ui.wait(lambda ui: ui.find('account') is not None, 'cold restored-preview login')
            self.check(self.ui.input_empty('account') and self.ui.input_empty('password') and
                       self.ui.has_text('隔离测试环境') and not self.ui.has_text('演示环境'),
                       'The cold restored preview starts with empty login inputs and its real isolated-environment label')
            self.cleanup['coldEmptyLoginObserved'] = True
            self.stage = 'strict-host-identity-and-list'
            auth = self.request('/api/collections/game_players/auth-with-password',
                                {'identity': self.login['account'], 'password': self.login['password']})
            PREVIEW.require(isinstance(auth, dict) and isinstance(auth.get('token'), str) and auth['token'],
                            'The exact preview Host authentication did not return its token')
            token = auth['token']
            secrets.append(token)
            player = self.request('/api/questions/v1/me', token=token)
            assignments = self.request('/api/questions/v1/assignments', token=token)
            self.check(isinstance(player, dict) and player.get('id') == auth.get('record', {}).get('id') == self.manifest['playerId'] and
                       player.get('account') == PREVIEW.ACCOUNT and player.get('mustChangePassword') is False,
                       'Fresh strict Host authentication and me confirm the same ordinary fixed-preview player')
            PREVIEW.require(isinstance(records, dict) and records and all(isinstance(value, dict) and
                            re.fullmatch(r'[a-z0-9]{15}', value.get('assignmentId', '') or '') for value in records.values()),
                            'The fixed-preview manifest has no valid exact assignment identity set')
            expected = {value['assignmentId'] for value in records.values()}
            items = assignments.get('items') if isinstance(assignments, dict) else None
            self.check(len(expected) == len(records) and isinstance(items, list) and
                       len(items) == len(expected) and all(isinstance(item, dict) for item in items) and
                       {item.get('id') for item in items} == expected,
                       'The fresh strict Host list exactly matches the fixed-preview assignment identities')
            del auth, player, assignments
            self.stage = 'native-direct-login-and-list'
            # Reuse the original narrow login/list method only. No profile,
            # account menu, logout/relogin or other old navigation is exercised.
            self.login_native()
            self.cleanup['directHomeObserved'] = True
            first = next(iter(records.values()))['assignmentId']
            self.ui.seek('assignment-' + first)
            self.ui.private_shot('gameplay-fixed-preview-home')
            self.ui.capture()
            self.check(self.ui.find('current-tab') is not None and self.ui.find('account') is None and
                       self.ui.find('old-password') is None and self.ui.find('forced-logout') is None and
                       self.ui.find('gameplay-page') is None,
                       'The verified fixed-preview session remains on authenticated home for review')
            self.cleanup['finalHomeObserved'] = True
            self.immutable()
            self.stage = 'preview-login-list-complete'
        except Exception as error:
            failure = str(error) if isinstance(error, SafeFailure) else 'Preview login/list smoke stopped; raw values omitted'
            for value in secrets:
                if value:
                    failure = failure.replace(value, '[private value omitted]')
        finally:
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not self.cleanup['remoteRawFilesRemoved']:
                failure = failure or 'An exact own remote raw-file cleanup was not confirmed'
            try:
                self.immutable()
            except Exception:
                failure = failure or 'The exact restored-preview package or ownership evidence changed'
        report = {'status': 'passed' if failure is None else 'incomplete', 'stage': self.stage,
                  'scope': 'Restored fixed isolated preview: direct login and read-only native assignment list only',
                  'hapSha256': self.hap_sha, 'bindingSha256': self.binding,
                  'checksPassed': len(self.checks), 'checks': self.checks,
                  'assignmentCount': len(expected), 'privateScreenshots': self.ui.private_screenshots,
                  'visualReview': 'pending_root_original_review', 'cleanup': self.cleanup,
                  'leftLoggedInForReview': failure is None and self.cleanup['finalHomeObserved'],
                  'businessWriteLedgerObserved': False,
                  'writeScope': 'Host authentication/me/list and native login/list scroll only, with inherited read-only runner status guard; no start, answer, profile, password, reset, seed, fault control or service change. No business write-ledger claim.',
                  'appCredentialsPersisted': False, 'privateCredentialsOrRecordIdsPersisted': False,
                  'createdAt': PREVIEW.datetime.datetime.now(PREVIEW.datetime.timezone.utc).isoformat()}
        if failure:
            report['failure'] = failure
            report['cleanupMeaning'] = 'Only completed observations are recorded; Root must inspect the actual foreground before further action'
        save_fresh_report(PREVIEW.REPORT, report, secrets)
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks),
                          'leftLoggedInForReview': report['leftLoggedInForReview'],
                          'report': str(PREVIEW.REPORT.relative_to(ROOT))}), flush=True)
        return 0 if failure is None else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-only direct-login/list smoke after restoring and installing fixed preview')
    run.add_argument('--runtime-report', type=Path, required=True)
    run.add_argument('--output', type=Path, required=True)
    run.add_argument('--expected-hap', required=True)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        PREVIEW.require(re.fullmatch(r'[a-f0-9]{64}', args.expected_hap or ''),
                        'An exact expected restored-preview HAP SHA256 is required')
        PREVIEW.REPORT = fresh_report_path(args.output)
        args.runtime_report = (ROOT / args.runtime_report).absolute() if not args.runtime_report.is_absolute() else args.runtime_report.absolute()
        return GameplayPreviewSmoke(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'The fixed-preview ownership/runtime/HAP or fresh output guards did not complete; private values omitted'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())

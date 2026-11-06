#!/usr/bin/env python3
"""Existing-HAP case0 image/input retention across one successful native Refresh.

Default/help is inert. Explicit run alone reads private guards and operates the
phone. No case creation, start/answer, backend fault, image download from Host,
product/source mutation or service operation is permitted. This is an instance
probe, not cancellation, late-result, CDN-wire or visual parity acceptance.
"""
import argparse
import datetime
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from native_device_ui import ROOT, SafeFailure

SPEC = importlib.util.spec_from_file_location('image_refresh_normal_guards', ROOT / 'scripts/device-question-images.py')
NORMAL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NORMAL)
FRAME, UI, require = NORMAL.FRAME, NORMAL.UI, NORMAL.require
LAYOUT_SPEC = importlib.util.spec_from_file_location('image_refresh_top_methods', ROOT / 'scripts/device-gameplay-layout.py')
LAYOUT = importlib.util.module_from_spec(LAYOUT_SPEC)
LAYOUT_SPEC.loader.exec_module(LAYOUT)
OUT = ROOT / 'artifacts/validation/ui-question-images-20261104'
SLOT = 'question-images-0-0'
DRAFT = 'ImageRefreshDraftOnly-DoNotSubmit'
INSTANCE_IDS = (SLOT, SLOT + '-frame', SLOT + '-pixels', 'gameplay-answer-input')
EVENT_FIELDS = {'slot', 'state', 'httpStatus', 'naturalWidthPx', 'naturalHeightPx', 'decodedWidthPx', 'decodedHeightPx'}


def parse_events(text, pid, natural):
    """Only complete current-own-PID event lines; no URLs or raw errors escape."""
    if not text.endswith('\n'):
        text = text[:text.rfind('\n') + 1]
    values = []
    for line in text.splitlines():
        match = re.fullmatch(r'\s*\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+(\d+)\s+\d+\s+[DIWEF]\s+\S*/StarwardQuestionImage:\s*(.*?)\s*', line)
        if not match or match[1] != pid:
            continue
        value = json.loads(match[2])
        require(isinstance(value, dict) and set(value) == EVENT_FIELDS and value['slot'] == SLOT and
                value['state'] in ('loading', 'ready') and type(value['httpStatus']) is int and
                all(type(value[key]) is int for key in EVENT_FIELDS - {'slot', 'state', 'httpStatus'}),
                'Only the exact normal body-image slot and integer image receipt are allowed')
        if value['state'] == 'loading':
            require(value['httpStatus'] == 0 and all(value[key] == 0 for key in
                    ('naturalWidthPx', 'naturalHeightPx', 'decodedWidthPx', 'decodedHeightPx')),
                    'A loading receipt must contain no decoded pixel claims')
        else:
            require(value['httpStatus'] == 200 and (value['naturalWidthPx'], value['naturalHeightPx']) == tuple(natural) and
                    all(0 < value[key] <= 2048 for key in ('decodedWidthPx', 'decodedHeightPx')),
                    'The initial normal image needs a real200 decoded natural-size receipt')
        values.append(value)
    return values


def one_initial_pair(values):
    require(len(values) == 2 and [value['state'] for value in values] == ['loading', 'ready'],
            'Exactly one initial image load is required, with no reload during Refresh')


def instances(raw):
    result = {}
    for node_id in INSTANCE_IDS:
        nodes = [row for row in raw if row.get('id') == node_id]
        require(len(nodes) == 1, 'A unique retained image/input node is required')
        identity = {key: nodes[0].get(key) for key in ('accessibilityId', 'hashcode')}
        require(all(type(value) in (str, int) and bool(value) for value in identity.values()),
                'Actual nonempty accessibilityId/hashcode values are required, not just stable id labels')
        result[node_id] = identity
        if node_id == 'gameplay-answer-input':
            require(nodes[0].get('text', '') == DRAFT, 'The actual unsubmitted draft changed during image Refresh')
    require(not any(row.get('id') in (SLOT + '-loading', SLOT + '-error', SLOT + '-retry') for row in raw),
            'The retained ready image must not expose loading or failure nodes')
    return result


def submit_enabled(raw):
    node = FRAME.own(raw, 'gameplay-submit')
    require(node.get('type') == 'Button' and type(node.get('enabled')) is str and
            node['enabled'] in ('true', 'false'),
            'The actual native submit must expose an explicit true/false enabled state')
    return node['enabled'] == 'true'


class ImageRefresh(NORMAL.Images):
    def __init__(self, args):
        super().__init__(args)
        require(self.index == 0 and self.case['fixtureLevelKinds'] == ['text'], 'Only the explicit real-content text case0 is supported')
        for name, filename in {'imageRefreshDriver': Path(__file__), 'normalImageGuard': ROOT / 'scripts/device-question-images.py',
                'quantitativeTopGuard': ROOT / 'scripts/device-gameplay-layout.py',
                'refreshWrapper': ROOT / 'entry/src/main/ets/ui/StarwardRefresh.ets'}.items():
            self.bound[name], self.binding[name] = filename, FRAME.sha(filename)
        self.expected_starts = 0
        self.cleanup.update({'ownLogCaptureStopped': False, 'imageAndDraftAbsentAfterLogout': False})
        self.log_process, self.log_sink, self.log_file, self.client_pid = None, None, None, None
        self.log_offset, self.draft_checks, self.observations = 0, {}, {}
        self.initial_events, self.initial_instances = None, None
        self.completed_capture = None
        self.image_specs = []

    # Reuse only measured geometry/pull methods, not Layout's fault operations or
    # full layout/IME/error workflow. Source hashes are bound independently.
    geometry = LAYOUT.Layout.geometry
    quantitative_top = LAYOUT.Layout.quantitative_top
    pull = LAYOUT.Layout.pull

    def reads(self):
        return [row for row in self.ledger()[len(self.baseline):] if row.get('method') == 'GET' and row.get('path') == self.detail]

    def current_pid(self):
        values = self.ui.run('hdc', 'shell', 'pidof', 'com.sitkin.starward').strip().split()
        require(len(values) == 1 and re.fullmatch(r'[1-9][0-9]*', values[0]), 'The own image App must have one current PID')
        return values[0]

    def begin_capture(self):
        self.client_pid = self.current_pid()
        self.log_file = self.directory / 'own-app-image-refresh.log'
        descriptor = os.open(self.log_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        self.log_sink = os.fdopen(descriptor, 'wb', buffering=0)
        self.log_process = subprocess.Popen(['hdc', 'shell', 'hilog', '-T', 'StarwardQuestionImage', '-P', self.client_pid],
            cwd=ROOT, stdin=subprocess.DEVNULL, stdout=self.log_sink, stderr=subprocess.STDOUT)
        time.sleep(.5)
        require(self.log_process.poll() is None, 'The own image log capture stopped before entry')
        self.log_offset = self.log_file.stat().st_size

    def events(self):
        require(self.log_process is not None and self.log_process.poll() is None and self.current_pid() == self.client_pid,
                'The exact image App/capture process must remain alive')
        with self.log_file.open('rb') as stream:
            stream.seek(self.log_offset)
            return parse_events(stream.read().decode('utf-8', errors='replace'), self.client_pid, self.image_specs[0]['natural'])

    def observe_instances(self, label, captured=None):
        raw, evidence = captured if captured is not None else self.ui.raw_app('image-refresh-' + label)
        value = instances(raw)
        enabled = submit_enabled(raw)
        if self.initial_instances is None:
            self.initial_instances = value
        else:
            require(value == self.initial_instances, 'Refresh recreated an image cell/frame/pixels or answer-input instance')
        private = FRAME.write_private(self.directory / ('instances-' + label + '.json'),
            {'identities': value, 'draftMatches': True}, self.credentials())
        return {'rawSha256': evidence['sha256'], 'privateInstanceEvidence': private, 'submitEnabled': enabled}

    def response_finished(self, before):
        reads = self.reads()
        require(len(reads) <= before + 1, 'A single pull issued more than one assignment GET')
        return len(reads) == before + 1 and reads[-1].get('status') == 200 and reads[-1].get('upstreamFinished') is True

    def refresh_complete(self, before):
        if not self.response_finished(before):
            return False
        raw, evidence = self.ui.raw_app('image-refresh-complete')
        FRAME.own(raw, 'gameplay-question-card')
        require(not any(row.get('id') == 'gameplay-refresh-error' for row in raw),
                'The successful detail GET must not leave a Refresh error')
        if not submit_enabled(raw):
            return False
        self.completed_capture = (raw, evidence)
        return True

    def verify_ledger(self):
        self.cleanup['zeroForbiddenWrites'] = False
        super().verify_ledger()
        self.cleanup['zeroForbiddenWrites'] = False
        require(self.final_facts.get('assignmentStatus') == 'active' and self.final_facts.get('startedAtPresent') is True and
                self.final_facts.get('startReceiptCount') == self.final_facts.get('progressRows') == 1 and
                self.final_facts.get('playerTotalXp') == 0, 'The already-active image-only entry/XP facts changed')
        self.cleanup['zeroForbiddenWrites'] = True

    def main(self):
        self.stage = 'active-normal-case0-prerequisites'
        auth = self.request(False, FRAME.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str) and auth['token'],
                'Host authentication did not identify the exact ordinary case0 actor')
        self.token = auth['token']; self.dto = self.snapshot()
        require(self.dto['assignment'].get('status') == 'active' and bool(self.dto['assignment'].get('startedAt')) and
                self.dto['assignment'].get('completedLevels') == 0 and self.dto['assignment'].get('totalLevels') == 1,
                'This probe must not enter a fresh assignment or observe a settled case')
        self.image_specs = self.specs(); require(len(self.image_specs) == 1, 'Case0 needs exactly one existing body image')
        facts = self.facts()
        require(facts.get('assignmentStatus') == 'active' and facts.get('startedAtPresent') is True and
                facts.get('startReceiptCount') == facts.get('progressRows') == 1 and facts.get('playerTotalXp') == 0,
                'The media-only probe requires one prior start and zero settlement/XP')
        self.baseline = self.ledger(); self.immutable()
        self.stage = 'native-login-and-initial-image'
        self.device_started = True; self.ui.launch(cold=True)
        self.ui.wait(lambda ui: ui.find('account') is not None, 'cold isolated empty login')
        require(self.ui.input_empty('account') and self.ui.input_empty('password') and self.ui.has_text('隔离测试环境'), 'The cold isolated login must be empty')
        self.begin_capture()
        self.ui.fill('account', self.case['account']); self.ui.fill('password', self.case['newPassword']); self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('old-password') is None, 'ordinary same-case home')
        self.ui.tap('assignment-' + self.assignment_id)
        self.ui.wait(lambda ui: ui.find('gameplay-question-card') is not None and ui.find('gameplay-loading') is None and
                     ui.find('start-assignment') is None, 'GET-only already-active question')
        self.ready_images(self.image_specs)
        self.initial_events = self.events(); one_initial_pair(self.initial_events)
        self.verify_ledger(); self.immutable()
        self.stage = 'one-native-refresh-retains-instances'
        self.ui.fill('gameplay-answer-input', DRAFT)
        self.quantitative_top('image-before-refresh')
        before = self.observe_instances('before')
        self.ui.private_shot('image-refresh-before')
        require(self.events() == self.initial_events, 'Filling the draft or reaching the top reloaded the body image')
        require(before['submitEnabled'] is True,
                'The actual normal case0 submit must be enabled before the read-only pull')
        self.api_before = self.ledger(); reads_before = len(self.reads())
        self.pull()  # Exactly one measured native gesture; no automatic second pull.
        pending_raw, pending_raw_evidence = self.ui.raw_app('image-refresh-pending')
        pending_disabled = not submit_enabled(pending_raw)
        observed_reads = self.reads()
        require(len(observed_reads) <= reads_before + 1, 'A single pull issued an extra assignment GET')
        pending = bool(len(observed_reads) == reads_before + 1 and observed_reads[-1].get('upstreamFinished') is not True and
                       pending_disabled and any(row.get('id') == 'gameplay-question-card' for row in pending_raw) and
                       not any(row.get('id') == 'gameplay-refresh-error' for row in pending_raw))
        pending_evidence = self.observe_instances('pending', (pending_raw, pending_raw_evidence)) if pending else None
        self.ui.wait(lambda ui: self.refresh_complete(reads_before),
                     'one successful detail GET and the actual submit re-enabled', timeout=40)
        after = self.observe_instances('after', self.completed_capture)
        self.ui.private_shot('image-refresh-after')
        require(self.events() == self.initial_events, 'Successful same-question Refresh started another image load')
        rows = self.ledger()
        require(rows[:len(self.api_before)] == self.api_before and len(rows) == len(self.api_before) + 1 and
                rows[-1].get('method') == 'GET' and rows[-1].get('path') == self.detail and rows[-1].get('status') == 200 and
                rows[-1].get('fault') is False and rows[-1].get('upstreamFinished') is True,
                'Only the one successful unfaulted assignment GET may occur during the Refresh probe')
        self.verify_ledger(); self.immutable()
        self.check(True, 'One successful native pull GET retains actual image cell/frame/pixels and input accessibilityId/hashcode plus the unsubmitted draft')
        self.check(True, 'The same own-App PID reports one initial loading/ready pair and no image reload across draft/top positioning or Refresh')
        self.observations = {'imageCellFramePixelsAndInputInstancesRetained': True, 'actualDraftRetained': True,
            'initialAppImageLoadAttempts': 1, 'refreshAppImageLoadAttempts': 0, 'assignmentGetsDuringRefresh': 1,
            'nativeStartCommands': 0, 'answerRequests': 0, 'playerTotalXp': 0,
            'pendingUiDirectlyObserved': pending, 'pendingRaw': pending_evidence, 'before': before, 'after': after}
        self.stage = 'image-refresh-instance-probe-complete'

    def credentials(self):
        return (self.case['newPassword'], self.state['controlToken'], self.token)

    def logout(self):
        for key in ('loggedOut', 'loginInputsEmpty', 'privateGameplayAbsent', 'imageAndDraftAbsentAfterLogout'):
            self.cleanup[key] = False
        super().logout()
        raw, _ = self.ui.raw_app('image-refresh-logout-absent')
        require(not any(str(row.get('id', '')).startswith('question-images-') or row.get('id') in
                    ('gameplay-page', 'gameplay-question-card', 'gameplay-answer-input') or row.get('text') == DRAFT for row in raw),
                'Logout retained image or private draft nodes')
        self.cleanup['imageAndDraftAbsentAfterLogout'] = True

    def stop_capture(self):
        if self.log_process is not None:
            if self.log_process.poll() is None:
                self.log_process.terminate()
                try: self.log_process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.log_process.kill(); self.log_process.wait(timeout=3)
            self.cleanup['ownLogCaptureStopped'] = self.log_process.poll() is not None
        else:
            self.cleanup['ownLogCaptureStopped'] = True
        if self.log_sink is not None:
            self.log_sink.close(); self.log_sink = None

    def execute(self):
        try:
            self.main()
        except Exception as error:
            reason = str(error)
            for secret in self.credentials():
                if secret: reason = reason.replace(secret, '[credential omitted]')
            FRAME.write_private(self.directory / 'failure-diagnostic.json', {'stage': self.stage, 'exceptionType': type(error).__name__, 'reason': reason}, self.credentials())
            self.failure = 'The narrow image/input Refresh probe is incomplete; raw diagnostics remain private'
        finally:
            self.cleanup['zeroForbiddenWrites'] = False
            try:
                self.immutable()
                if self.device_started:
                    self.logout(); self.verify_ledger()
                    if self.failure is None:
                        require(self.events() == self.initial_events, 'Another image attempt appeared before logout completed')
            except Exception:
                self.failure = self.failure or 'Same-owner logout, unchanged image events or zero business writes are incomplete'
            finally:
                try: self.stop_capture()
                except Exception:
                    self.cleanup['ownLogCaptureStopped'] = False
                    self.failure = self.failure or 'The own log capture could not be stopped'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not all(self.cleanup.values()): self.failure = self.failure or 'Image Refresh cleanup is incomplete'
        ledger = FRAME.write_private(self.directory / 'request-ledger.json', getattr(self, 'final_ledger', {}), self.credentials())
        log = {'file': str(self.log_file.relative_to(ROOT)), 'sha256': FRAME.sha(self.log_file)} if self.log_file is not None else None
        report = {'status': 'incomplete' if self.failure else 'passed', 'stage': self.stage,
            'scope': 'Loaded real-case0 body image and input instance retention across one successful native Refresh GET only',
            'sourceCaseIndex': 0, 'hapSha256': self.hap_sha, 'expectedFixtureSha256': self.args.expected_fixture_sha,
            'imagesManifestSha256': self.args.expected_images_manifest_sha, 'bindingSha256': self.binding,
            'checksPassed': len(self.checks), 'checks': self.checks, 'observations': self.observations, 'cleanup': self.cleanup,
            'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence, 'privateReadOnlyLedger': ledger,
            'privateOwnAppLog': log, 'fixedPreviewTouched': False, 'backendFaultInjected': False,
            'nativeDownloadSha256Observed': False, 'cdnWireRequestsObserved': False, 'cancellationVerified': False,
            'lateResultDiscardVerified': False, 'visualReview': 'not_claimed_instance_probe_only',
            'httpEvidenceSource': 'Current own-App image state events and the owned assignment-GET ledger; no CDN-wire capture',
            'writeScope': 'Host auth/read and one native pull GET; no start/answer/profile/password/fault/admin/service write',
            'excludedAcceptance': ['in-flight cancellation', 'late image/decode release', 'CDN wire/hash', 'image viewing', 'choice images', 'whole page'],
            'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        secrets = [self.case_id, self.case['account'], self.case['playerId'], self.assignment_id,
            self.case['assignments']['ready']['sessionId'], DRAFT, *self.credentials(), *self.assets]
        require(not any(value and value in encoded for value in secrets) and not re.search(r'https?://', encoded), 'A private image/account/draft literal would enter the public report')
        FRAME.fresh(self.report, OUT); self.report.parent.mkdir(parents=True, exist_ok=True)
        descriptor = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(descriptor, 'w') as stream: stream.write(encoded)
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks), 'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 1 if self.failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action'); run = sub.add_parser('run')
    for name in ('runtime', 'case-ref', 'output', 'private-dir', 'images-manifest', 'web-case0', 'web-case1', 'web-case2'):
        run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-hap', 'expected-fixture-sha', 'expected-images-manifest-sha'):
        run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if not args.action: parser.print_help(); return 0
    try: return ImageRefresh(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded', 'error': 'Exact existing-HAP image/case/runtime/owner/output guards failed; values omitted'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

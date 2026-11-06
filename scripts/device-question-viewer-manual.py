#!/usr/bin/env python3
"""Inert manual viewer prepare/finish; Root reviews and runs each explicit phase.

No SDK/cache operation or automatic multi-pointer injection. prepare leaves the
own real case2 viewer open. finish requires Root's --user-reported-normal AFTER
the user's reply. User-reported caps/remaining-finger behavior stay separate from
actual raw pose/PNG/Reset/close/input/logout observations. No time-based SDK TTL.
Explicit runtime/case/package inputs allow a fresh isolated environment after
reboot; the historical normal capture remains historical, never inherited.
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
import shutil
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
PARENT = ROOT / 'scripts/device-question-image-viewer.py'
NORMAL = ROOT / 'artifacts/validation/ui-image-viewer-20261105/native-case2-03.json'
DEVICE = ROOT / 'artifacts/private/ui-reference/image-viewer-multitouch-device-02.json'
HDC = Path('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc')
PARENT_SHA = 'a1d5d608f76647760246139ffd4ab95cbb1a386eb9ac60880f57f460531388fd'
NORMAL_SHA = 'c5dc711968b0f878b19d08b8702e5126a0ffd746eb2b43b7d557a87dccf9a3b9'
DEVICE_SHA = '27aa661a7efe1be5c7a77c35ebf987d0d6ad83b8adb95c5bb82e99ee9496bf22'
HDC_SHA = 'f170c24ea37472562bba90860586c31b77928ba36830ed8dc1e5a2c5d19ff3cc'
HISTORICAL_HAP_SHA = 'c7895c09a3b414e9237d18f08786fca6f5bcd4a5c8564b5ee6c606e587208641'
FIXTURE_SHA = '1ad7a59cc1f13e6dd7ec5550c8f5ab4a5906b90f9a9b56ac948143a4995e8745'
RECOVERY_BINDINGS = frozenset(('hap', 'runtime', 'caseReference', 'config', 'ca'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build(args):
    if sha(PARENT) != PARENT_SHA or sha(NORMAL) != NORMAL_SHA:
        raise RuntimeError('Frozen manual reference/helper changed')
    spec = importlib.util.spec_from_file_location('manual_normal_viewer', PARENT)
    parent = importlib.util.module_from_spec(spec); spec.loader.exec_module(parent)
    frame, require = parent.FRAME, parent.require
    normal = json.loads(NORMAL.read_text()); binding = normal['bindingSha256']
    require(normal.get('status') == 'captured_native_viewer_narrow' and normal.get('sourceCaseIndex') == 2 and
            normal.get('failure') is None and normal.get('cleanup') and all(value is True for value in normal['cleanup'].values()) and
            normal.get('hapSha256') == HISTORICAL_HAP_SHA, 'The approved historical normal capture is incomplete')
    args.images_manifest = ROOT / 'artifacts/private/ui-reference/real-question-images-referer-20261104/manifest-sniffed.json'
    args.web_reference = ROOT / 'artifacts/validation/ui-image-viewer-20261105/web-reference-01.json'
    args.expected_fixture_sha = FIXTURE_SHA
    for attribute, key in (('images_manifest', 'imageManifest'), ('web_reference', 'webViewerReference'),
                           ('viewer', 'viewer'), ('gameplay_page', 'gameplay_page'), ('window', 'window'), ('surfaces', 'surfaces')):
        setattr(args, 'expected_' + attribute + '_sha', binding[key])
    value = parent.Viewer(args)
    require(value.index == 2 and set(value.binding) == set(binding) and len(binding) == 31 and
            RECOVERY_BINDINGS.issubset(binding) and
            all(value.binding[key] == binding[key] for key in binding if key not in RECOVERY_BINDINGS),
            'Live case2 differs outside the five explicit recovery bindings')
    value.recovery_binding_changes = sorted(key for key in binding if value.binding[key] != binding[key])
    value.unchanged_historical_bindings = len(binding) - len(RECOVERY_BINDINGS)
    for name, path in (('manualDriver', Path(__file__)), ('manualNormalReference', NORMAL), ('manualDeviceReference', DEVICE)):
        value.bound[name], value.binding[name] = path, sha(path)
    return parent, value


def device_guard(parent, value, empty):
    frame, require = parent.FRAME, parent.require
    path = frame.ENTRY.guarded(DEVICE, frame.PRIVATE, True)
    require(sha(path) == DEVICE_SHA and Path(shutil.which('hdc') or '') == HDC and sha(HDC) == HDC_SHA, 'Current device/HDC reference changed')
    reference = json.loads(path.read_text())
    require(set(reference) == {'deviceSerial'} and re.fullmatch(r'[A-Za-z0-9]{8,80}', reference['deviceSerial']), 'The exact current device reference is invalid')
    serial = reference['deviceSerial']
    require(value.ui.run(str(HDC), 'list', 'targets').split() == [serial], 'The sole current device differs from its reference')
    rows = [line.split() for line in value.ui.run(str(HDC), '-t', serial, 'fport', 'ls').splitlines() if line.strip()]
    require(rows == [[serial, 'tcp:18443', 'tcp:' + str(value.state['tls']['hostPort']), '[Reverse]']], 'Only the exact owned isolated TLS reverse is allowed')
    require(not re.search(r'\b(?:uitest|singleness|wukong)\b', value.ui.run(str(HDC), '-t', serial, 'shell', 'ps', '-ef'), re.I), 'A UITest/Wukong process is unexpectedly active')
    value.ui.capture()
    if empty:
        require(value.ui.find('account') is not None and value.ui.input_empty('account') and value.ui.input_empty('password') and
                value.ui.find('gameplay-page') is None and value.ui.find('image-viewer') is None and value.ui.has_text('隔离测试环境'), 'The actual isolated login is not empty')


def authenticate(parent, value):
    auth = value.request(False, parent.FRAME.AUTH, {'identity': value.case['account'], 'password': value.case['newPassword']})
    parent.require(auth.get('record', {}).get('id') == value.case['playerId'] and isinstance(auth.get('token'), str) and auth['token'], 'Host auth identified another actor')
    value.token = auth['token']; value.dto = value.snapshot(); value.question()
    facts = value.facts()
    parent.require(facts.get('playerTotalXp') == 0 and facts.get('assignmentStatus') == 'active' and
                   facts.get('progressRows') == facts.get('startReceiptCount') == 1, 'The own active case has changed answer/XP/entry facts')


def context_identity(parent, value):
    return {'scriptSha256': sha(__file__), 'normalSha256': NORMAL_SHA, 'deviceReferenceSha256': DEVICE_SHA,
            'bindings': value.binding, 'environmentSha256': hashlib.sha256(parent.canonical(value.environment).encode()).hexdigest(),
            'registrySha256': hashlib.sha256(value.registry_identity.encode()).hexdigest()}


def zoomed_observation(parent, value):
    raw, evidence = value.ui.raw_app('manual-final-zoomed')
    parent.require(all(any(row.get('id') == key for row in raw) for key in parent.IDS) and
                   not any(row.get('id') in ('image-viewer-loading', 'image-viewer-error', 'image-viewer-retry') for row in raw), 'Actual ready viewer is unavailable')
    pose = parent.pose(parent.FRAME.own(raw, 'image-viewer-stage'))
    parent.require(parent.FRAME.own(raw, 'image-viewer-index').get('text') == '2 / 3' and 100 < pose['percent'] <= 400 and
                   all(math.isfinite(pose[key]) and abs(pose[key]) >= .1 for key in ('xVp', 'yVp')) and
                   parent.FRAME.own(raw, 'image-viewer-percent').get('text') == str(pose['percent']) + '%', 'Actual final pose must remain on2/3, zoomed and panned in both axes')
    value.states.append({'position': 'manual-final-zoomed', 'pose': pose, 'imageIndex': 2, 'rawSha256': evidence['sha256'],
        'stageBoundsPx': parent.UI.rect(parent.FRAME.own(raw, 'image-viewer-stage')['bounds']), **value.screenshot('manual-final-zoomed', 'light', raw)})


def execute(args):
    parent, value = build(args)
    frame, require = parent.FRAME, parent.require
    context = frame.fresh(args.context, frame.PRIVATE) if args.action == 'prepare' else frame.ENTRY.guarded(args.context, frame.PRIVATE, True)
    require(args.action != 'prepare' or context == value.directory / 'manual-context.json', 'Prepare context belongs only to its fresh private evidence directory')
    prepared, failed = False, None
    try:
        value.stage = 'strict-manual-' + args.action
        device_guard(parent, value, args.action == 'prepare')
        value.expected_starts = 0
        if args.action == 'finish':
            require(args.user_reported_normal and context.stat().st_size <= 5 * 1024 * 1024, 'Root must explicitly confirm the user reply before finish')
            raw_context = context.read_bytes()
            require(re.fullmatch(r'[a-f0-9]{64}', args.expected_context_sha) and hashlib.sha256(raw_context).hexdigest() == args.expected_context_sha,
                    'Use the context SHA recorded by the successful prepare report')
            saved = json.loads(raw_context)
            require(saved.get('schema') == 1 and saved.get('status') == 'awaiting_manual_gestures' and
                    saved.get('identity') == context_identity(parent, value) and isinstance(saved.get('baselineLedger'), list) and
                    set(saved.get('inputIdentity', {})) == {'accessibilityId', 'hashcode'}, 'The exact prepared handoff context changed')
            value.baseline, value.input_identity = saved['baselineLedger'], saved['inputIdentity']
        else:
            require(not args.user_reported_normal, 'The user-reported flag belongs only to finish')
            value.baseline = value.ledger()
        authenticate(parent, value); value.immutable()
        if args.action == 'prepare':
            value.device_started = True
            value.ui.fill('account', value.case['account']); value.ui.fill('password', value.case['newPassword']); value.ui.tap('primary-action')
            value.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('old-password') is None, 'ordinary own direct login')
            before = len([row for row in value.ledger() if row.get('method') == 'GET' and row.get('path') == value.detail])
            value.ui.tap('assignment-' + value.assignment_id)
            value.ui.wait(lambda ui: ui.find('gameplay-question-card') is not None and ui.find('gameplay-loading') is None, 'own existing active case2')
            reads = [row for row in value.ledger() if row.get('method') == 'GET' and row.get('path') == value.detail][before:]
            require(len(reads) == 2 and all(row.get('status') == 200 for row in reads), 'Existing entry must issue its two GET200 responses')
            value.theme('light'); value.ready_images(value.specs())
            value.ui.fill('gameplay-answer-input', parent.DRAFT); value.draft('manual-initial', initial=True)
            value.open_image(1); value.observe('manual-initial-100', 'light', 1)
            value.verify_ledger(); value.immutable()
            value.cleanup['remoteRawFilesRemoved'] = value.ui.remote_cleanup_ok
            require(value.cleanup['remoteRawFilesRemoved'], 'Owned raw capture cleanup is incomplete')
            frame.write_private(context, {'schema': 1, 'status': 'awaiting_manual_gestures', 'identity': context_identity(parent, value),
                'inputIdentity': value.input_identity, 'baselineLedger': value.baseline,
                'initialStagePose': value.states[-1]['pose'], 'initialStageBoundsPx': value.states[-1]['geometryPx']['image-viewer-stage']},
                (value.case['newPassword'], value.state['controlToken'], value.token))
            prepared = True
        else:
            value.draft('manual-finish-before-reset'); value.device_started = True
            zoomed_observation(parent, value)
            value.ui.run('devecocli', 'ui', 'click', '--id', 'image-viewer-reset')
            value.observe('manual-reset-100', 'light', 1)
            value.close_image('x', 'light'); value.verify_ledger(); value.immutable()
    except Exception:
        failed = 'The narrow manual handoff/finish observations are incomplete; private originals retained'
    finally:
        if not prepared:
            try:
                value.immutable()
                if value.device_started:
                    value.ui.capture()
                    if value.ui.find('image-viewer') is not None:
                        value.ui.run('devecocli', 'ui', 'click', '--id', 'image-viewer-close')
                        value.ui.wait(lambda ui: ui.find('image-viewer') is None, 'close only the own viewer before logout')
                    value.logout()
                if hasattr(value, 'baseline'): value.verify_ledger()
            except Exception:
                failed = failed or 'Owned logout/zero-write observations could not be confirmed'
            value.cleanup['remoteRawFilesRemoved'] = value.ui.remote_cleanup_ok
            if not all(value.cleanup.values()): failed = failed or 'The manual sample cleanup remains incomplete'
    ledger = frame.write_private(value.directory / 'request-ledger.json', value.final_ledger,
        (value.case['newPassword'], value.state['controlToken'], value.token)) if hasattr(value, 'final_ledger') else None
    report = {'status': 'incomplete' if failed else 'prepared_awaiting_manual' if prepared else 'captured_manual_finish',
        'scope': 'Real case2 manual image-viewer handoff and observed pose/Reset/close/input/logout only',
        'action': args.action, 'bindingSha256': value.binding, 'hapSha256': value.hap_sha, 'normalSha256': NORMAL_SHA,
        'historicalNormalHapSha256': HISTORICAL_HAP_SHA,
        'historicalNormalAcceptanceInherited': False,
        'changedRecoveryBindings': value.recovery_binding_changes,
        'unchangedHistoricalSourceAndReferenceBindingCount': value.unchanged_historical_bindings,
        'states': value.states, 'cleanup': value.cleanup, 'privateContextSha256': sha(context) if context.exists() else None,
        'privateScreenshots': value.ui.private_screenshots, 'privateRawEvidence': value.ui.raw_evidence, 'privateReadOnlyLedger': ledger, 'failure': failed,
        'userReportedCapsAndRemainingFinger': bool(args.action == 'finish' and args.user_reported_normal),
        'instrumentedCapsOrRemainingFingerClaimed': False, 'realMultiPointerInjectedByAutomation': False,
        'observedReadOnlyFacts': {key: value.final_facts[key] for key in ('answerSubmissionCount', 'answerReceiptCount', 'xpLedgerCount',
            'xpDeltaSum', 'wrongCountTotal', 'lockedProgressRows', 'completedProgressRows', 'startReceiptCount', 'progressRows', 'playerTotalXp')}
            if hasattr(value, 'final_facts') else None,
        'viewerAcceptanceComplete': False, 'handoffViewerIntentionallyOpen': prepared,
        'pendingAcceptance': ['Root original-image visual review', 'Viewer media failure/retry and cancellation'],
        'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    data = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
    require(not re.search(r'https?://', data) and not any(item and item in data for item in
            (value.case_id, value.case['account'], value.case['newPassword'], value.case['playerId'], value.assignment_id,
             value.case['assignments']['ready']['sessionId'], value.state['controlToken'], value.token, *value.assets)), 'A private literal would enter the public report')
    frame.fresh(value.report, parent.OUT)
    fd = os.open(value.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
    with os.fdopen(fd, 'w') as stream: stream.write(data)
    print(json.dumps({'status': report['status'], 'report': str(value.report.relative_to(ROOT))}), flush=True)
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action')
    for action in ('prepare', 'finish'):
        command = sub.add_parser(action)
        for name in ('output', 'private-dir', 'context'): command.add_argument('--' + name, type=Path, required=True)
        command.add_argument('--runtime', type=Path, required=True, help='Actual five-check runtime for the explicitly installed package')
        command.add_argument('--case-ref', type=Path, required=True, help='Explicit own active real-content case2 reference in this environment')
        command.add_argument('--expected-hap', required=True, help='SHA256 of the explicitly installed package; historical normal acceptance is not inherited')
        if action == 'finish':
            command.add_argument('--user-reported-normal', action='store_true', required=True)
            command.add_argument('--expected-context-sha', required=True)
        else: command.set_defaults(user_reported_normal=False)
    args = parser.parse_args()
    if args.action is None: parser.print_help(); return 0
    try: return execute(args)
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded', 'reason': 'Strict source/case/context/runtime/output prerequisites failed; raw values omitted'})); return 1


if __name__ == '__main__':
    sys.exit(main())

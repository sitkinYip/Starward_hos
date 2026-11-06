#!/usr/bin/env python3
"""Targeted completed text input verification after a color-only fix.

Default/help is inert. Run permits only exact own authentication and reads.
It reuses the original isolated actor and never invokes entry or submission.
"""
import argparse
import datetime
import importlib.util
import json
import os
from pathlib import Path
import re
import sys

from native_device_ui import ROOT

DRIVER = ROOT / 'scripts/device-gameplay-text-field.py'
DRIVER_SHA = 'a60a7262170b3f9521c02709434db36391c28394c06a41a0090ba5ad766d6977'
PRIOR_SHA = '61a83d46f73776615f956490522cd0ebb074b0893cca455bac16161c20d5a1c9'


def load_driver():
    spec = importlib.util.spec_from_file_location('text_readonly_driver', DRIVER)
    driver = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(driver)
    driver.require(driver.sha(DRIVER) == DRIVER_SHA, 'The exact accepted text collector is required')
    return driver


def execute(text, args):
    frame, require = text.FRAME, text.require
    value = text.TextFieldSample(args)
    prior_path = frame.ENTRY.guarded(text.OUT / 'native-01.json', text.OUT)
    require(text.sha(prior_path) == PRIOR_SHA, 'The exact accepted native-01 report is required')
    prior = json.loads(prior_path.read_text())
    require(prior.get('status') == 'captured_native_text_field' and prior.get('sourceCaseIndex') == 0 and
            prior.get('checksPassed') == 7 and all(prior['cleanup'].values()) and
            prior.get('submittedProbeMatchesAuthoritativeAnswerAndReceipt') is True,
            'Prior text acceptance did not settle the exact actor and clean up')
    historic = prior['bindingSha256']
    require(set(historic) == set(value.binding) and historic['hap'] == prior['hapSha256'] and
            {key for key in historic if historic[key] != value.binding[key]} == {'hap', 'runtime', 'textFieldUI'},
            'Only the package, runtime and text field styling may differ from original acceptance')
    original_dto = prior['sameDataWebFixtures']['completed']
    original_ledger = prior['privateReadOnlyLedger']
    sources = {'originalCompletedDto': original_dto, 'originalRequestLedger': original_ledger}
    for key, evidence in sources.items():
        path = frame.ENTRY.guarded(Path(evidence['file']), frame.PRIVATE, True)
        require(text.sha(path) == evidence['sha256'], 'An original private settlement binding changed')
        value.bound[key], value.binding[key] = path, evidence['sha256']
    for key, path in {
            'readonlyDriver': Path(__file__), 'originalNativeReport': prior_path,
            'lightThemeColors': ROOT / 'entry/src/main/resources/base/element/color.json',
            'darkThemeColors': ROOT / 'entry/src/main/resources/dark/element/color.json'}.items():
        value.bound[key], value.binding[key] = path, text.sha(path)
    older = json.loads(value.bound['originalRequestLedger'].read_text())
    receipts = {}
    for operation, route in (('start', value.start), ('answer', value.answer_path)):
        rows = [row for row in older['added'] if row.get('method') == 'POST' and row.get('path') == route]
        require(len(rows) == 1 and rows[0].get('operation') == operation and rows[0].get('status') == 200 and
                rows[0].get('actorVerifiedByBackendResponse') is True and
                re.fullmatch(r'[a-f0-9]{64}', rows[0].get('requestIdSha256', '')),
                'The original own start and answer receipts are required')
        receipts[operation] = [rows[0]['requestIdSha256']]

    def settlement():
        facts, public = value.facts('completed', 1, 1)
        require(public == prior['observedReadOnlyFacts'] and
                facts['startRequestIdSha256'] == receipts['start'] and facts['answerRequestIdSha256'] == receipts['answer'],
                'The original completion, experience or exact receipts changed')
        return public

    def verify_ledger():
        value.cleanup['zeroForbiddenWrites'] = False
        added = value.added_requests()
        require(all((row.get('method') == 'GET' and row.get('path') in ('/api/health', text.ME, frame.BASE, value.detail)) or
                    (row.get('method') == 'POST' and row.get('path') == frame.AUTH) for row in added),
                'A request escaped the exact own login/read allowlist')
        require(all(row.get('status') == 200 and row.get('fault') is False and not row.get('responseDropped') and
                    not row.get('responseAwaitingDelay') for row in added), 'The targeted run has a failed request or fault')
        value.final_facts = settlement()
        value.final_ledger = {'baseline': value.baseline, 'added': added}
        value.cleanup['zeroForbiddenWrites'] = True

    def comparable(dto):
        return {**dto, 'assignment': {key: item for key, item in dto['assignment'].items() if key != 'serverTime'}}

    entry_reads = []
    try:
        value.stage = 'targeted-completed-prerequisites'
        value.immutable()
        value.device_binding()
        auth = value.request(False, frame.AUTH, {'identity': value.case['account'], 'password': value.case['newPassword']})
        require(auth.get('record', {}).get('id') == value.case['playerId'] and isinstance(auth.get('token'), str) and auth['token'],
                'Strict Host authentication must identify the original own actor')
        value.token = auth['token']
        current = value.dto_for('completed')
        original = json.loads(value.bound['originalCompletedDto'].read_text())
        require(comparable(current) == comparable(original), 'The complete settled DTO changed outside its server clock')
        settlement()
        value.baseline = value.ledger()

        value.stage = 'targeted-native-history-reentry'
        value.device_started = True
        value.ui.launch(cold=True)
        value.ui.wait(lambda ui: ui.find('account') is not None, 'original isolated empty login')
        require(value.ui.input_empty('account') and value.ui.input_empty('password') and value.ui.has_text('隔离测试环境'),
                'The original isolated native login must be empty')
        value.ui.fill('account', value.case['account'])
        value.ui.fill('password', value.case['newPassword'])
        value.ui.tap('primary-action')
        value.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('old-password') is None, 'ordinary original isolated login')
        value.ui.tap('history-tab')
        target = 'assignment-' + value.assignment_id
        value.ui.seek(target)
        before = len(value.ledger())
        value.ui.tap(target)
        value.wait_gameplay()
        entry_reads = value.ledger()[before:]
        require(len(entry_reads) == 2 and all(row.get('method') == 'GET' and row.get('path') == value.detail and
                    row.get('status') == 200 and row.get('authenticated') is True and row.get('bearer') is False for row in entry_reads),
                'Original native history entry must produce two authenticated detail GET200 responses')
        value.check(True, 'History opens the original settled scene through two authenticated detail reads')

        value.stage = 'targeted-completed-visual-and-disabled-touch'
        before = len(value.ledger())
        for theme in ('light', 'dark'):
            value.theme(theme)
            identity, box = value.sample('readonly-completed-' + theme, theme, value.correct_answer, False, require_unfocused=True)
            if theme == 'light':
                value.ui.run('devecocli', 'ui', 'click', round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))
                touched, _ = value.ui.raw_app('readonly-disabled-touch')
                node, _, after = value.field(touched, value.correct_answer, False)
                require(after == identity and not text.raw_boolean(node, 'focused') and not value.ui.keyboard_visible() and
                        not any(row.get('id') == text.SUBMIT for row in touched) and len(value.ledger()) == before,
                        'The actual disabled touch changed the field, focus, keyboard or request ledger')
                value.readonly_touch_observed = True
        require(len(value.ledger()) == before, 'Completed visuals or touch issued a request')
        verify_ledger()
        value.check(True, 'Both themes retain the authoritative disabled field; a measured touch cannot focus or open IME')
    except Exception as error:
        reason = str(error)
        for item in (*value.credentials(), value.correct_answer):
            if item:
                reason = reason.replace(item, '[private value omitted]')
        frame.write_private(value.directory / 'failure-diagnostic.json',
                            {'stage': value.stage, 'exceptionType': type(error).__name__, 'reason': reason}, value.credentials())
        value.failure = 'Targeted completed text verification is incomplete'
    finally:
        try:
            value.immutable()
            if value.device_started:
                value.device_binding()
                value.ui.hide_keyboard()
                value.logout()
                verify_ledger()
        except Exception:
            value.failure = value.failure or 'Exact read-only cleanup could not be confirmed'
        value.cleanup['remoteRawFilesRemoved'] = value.ui.remote_cleanup_ok
        if not all(value.cleanup.values()):
            value.failure = value.failure or 'Targeted cleanup is incomplete'

    ledger = frame.write_private(value.directory / 'request-ledger.json', value.final_ledger, value.credentials()) if value.final_ledger else None
    if value.failure is None:
        value.stage = 'targeted-completed-readonly-captured'
    report = {'status': 'incomplete' if value.failure else 'captured_native_text_readonly_visual', 'stage': value.stage,
              'scope': 'Completed text field color verification and read-only interaction only',
              'hapSha256': value.hap_sha, 'bindingSha256': value.binding, 'originalNativeReportSha256': PRIOR_SHA,
              'checksPassed': len(value.checks), 'checks': value.checks, 'states': value.states, 'cleanup': value.cleanup,
              'nativeDetailGetStatuses': [row.get('status') for row in entry_reads if row.get('method') == 'GET' and row.get('path') == value.detail],
              'originalSettlementUnchanged': value.cleanup['zeroForbiddenWrites'], 'observedReadOnlyFacts': value.final_facts,
              'completedTouchActuallyObserved': value.readonly_touch_observed, 'nativeStartOrAnswerInvoked': False,
              'sameDataCompletedWebFixture': original_dto, 'privateScreenshots': value.ui.private_screenshots,
              'privateRawEvidence': value.ui.raw_evidence, 'privateReadOnlyLedger': ledger,
              'visualReview': 'pending_root_original_review', 'wholePageParityAccepted': False,
              'fixedPreviewTouched': False, 'failure': value.failure, 'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
    secrets = (*value.credentials(), value.correct_answer, value.serial, value.case_id, value.case['account'],
               value.case['playerId'], value.assignment_id, value.case['assignments']['ready']['sessionId'],
               value.level_id, value.question_id, *value.source_ids, *receipts['start'], *receipts['answer'])
    require(not any(item and item in encoded for item in secrets) and not re.search(r'https?://', encoded),
            'A private literal would enter the targeted public report')
    frame.fresh(value.report, text.OUT)
    value.report.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    fd = os.open(value.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
    with os.fdopen(fd, 'w') as stream:
        stream.write(encoded)
    print(json.dumps({'status': report['status'], 'checksPassed': len(value.checks),
                      'report': str(value.report.relative_to(ROOT))}), flush=True)
    return 1 if value.failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    run = parser.add_subparsers(dest='action').add_parser('run')
    for name in ('runtime', 'case-ref', 'output', 'private-dir'):
        run.add_argument('--' + name, type=Path, required=True)
    run.add_argument('--expected-hap', required=True)
    run.add_argument('--fixture-file', type=Path, default=ROOT / 'artifacts/private/ui-reference/native-content-fixture-20261104-01/fixture.json')
    run.add_argument('--device-ref', type=Path, default=ROOT / 'artifacts/private/ui-reference/image-viewer-multitouch-device-02.json')
    args = parser.parse_args()
    if args.action is None:
        parser.print_help()
        return 0
    try:
        return execute(load_driver(), args)
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Exact original case, package, runtime, owner or output guards failed; values omitted'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

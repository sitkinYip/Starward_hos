#!/usr/bin/env python3
"""Targeted native choice photo evidence after separating Image and Button.

The completed run observes the same settled case in both themes. The active
run uses a fresh official import of the same real source case, already started
by the operator, and measures a photo touch while another option is selected.
Both runs only authenticate and read. Default/help performs no phone or backend
operations.
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

OUT = ROOT / 'artifacts/validation/ui-choice-options-20261105'
PRIVATE_REFERENCE = ROOT / 'artifacts/private/ui-reference'
NORMAL = ROOT / 'scripts/device-choice-options.py'
NORMAL_SHA = '38956ed52c65c1eb3c6b947c8383721adaf97f12d9fe27fd6644af63ecac79d0'
REENTRY_SHA = '3eacd6d866448494eebbe8e53fe21bf0c900529c7c77bed73efb45f8e4b57c8e'
CHOICE_SHA = 'ed7320dba5f7a7cccd717b87e156f94c47e42d6aa98b69b3531cf8e596844dba'
UPDATED_BINDINGS = {'hap', 'runtime', 'choiceUI'}
ME = '/api/questions/v1/me'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def execute(args):
    if sha(NORMAL) != NORMAL_SHA:
        raise RuntimeError('The accepted normal collector changed')
    spec = importlib.util.spec_from_file_location('choice_photo_normal_definitions', NORMAL)
    normal = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(normal)
    frame = normal.load('choice_photo_frame', 'scripts/device-question-frame.py', normal.FRAME_SHA)
    require, ui, boolean = frame.require, frame.UI, normal.boolean
    args.expected_fixture_sha = normal.FIXTURE_SHA
    frame.fresh(args.output, OUT)
    value = frame.FrameSample(args)
    completed = args.action == 'completed'
    require(value.case['sourceContent']['sourceCaseIndex'] == 1 and value.case['fixtureLevelKinds'] == ['choice'],
            'Use the explicit real-content choice case1 reference')

    old_reentry = OUT / 'native-completed-reentry-01.json'
    require(sha(old_reentry) == REENTRY_SHA, 'The exact prior completed reentry report changed')
    prior = json.loads(old_reentry.read_text())
    require(prior['status'] == 'captured_native_choice_completed_reentry' and prior['nativeDetailGetStatuses'] == [200, 200] and
            all(prior['cleanup'].values()), 'The prior completed history reentry is incomplete')
    old_completed = OUT / 'native-completed-01.json'
    complete_report = json.loads(old_completed.read_text())
    prior_ledger = frame.ENTRY.guarded(Path(complete_report['privateReadOnlyLedger']['file']), frame.PRIVATE, True)
    dto_record = complete_report['sameDataCompletedWebFixture']
    old_dto = frame.ENTRY.guarded(Path(dto_record['file']), frame.PRIVATE, True)
    require(sha(old_dto) == dto_record['sha256'], 'The private original completed DTO changed')
    fixture = frame.ENTRY.guarded(PRIVATE_REFERENCE / 'native-content-fixture-20261104-01/fixture.json', frame.PRIVATE, True)
    manifest = frame.ENTRY.guarded(PRIVATE_REFERENCE / 'real-question-images-referer-20261104/manifest-sniffed.json', frame.PRIVATE, True)
    paths = {**value.bound, **normal.SOURCE_PATHS, 'choiceDriver': NORMAL, 'imageManifest': manifest,
        'quantitativeTopHelper': ROOT / 'scripts/device-gameplay-layout.py', 'completedDriver': ROOT / 'scripts/device-choice-completed.py',
        'successfulNormalReport': OUT / 'native-normal-04.json', 'reviewedSourceFixture': fixture,
        'priorCompletedReport': old_completed, 'priorCompletedLedger': prior_ledger, 'reentryDriver': ROOT / 'scripts/device-choice-completed-reentry.py'}
    web = ROOT.parent / 'questions-web'
    paths.update({'frozenWebSource' + str(i): web / p for i, p in enumerate(normal.WEB_PATHS)})
    actual = {key: sha(path) for key, path in paths.items()}
    historic = prior['bindingSha256']
    updates = UPDATED_BINDINGS if completed else UPDATED_BINDINGS | {'caseReference'}
    require(len(historic) == 39 and set(actual) == set(historic) and
            {key for key in actual if actual[key] != historic[key]} == updates and actual['choiceUI'] == CHOICE_SHA,
            'Only the explicitly reviewed bindings for this mode may change')
    value.bound, value.binding = paths, actual
    value.bound.update({'photoColorDriver': Path(__file__), 'priorCompletedReentry': old_reentry, 'priorCompletedDTO': old_dto})
    value.binding.update({'photoColorDriver': sha(__file__), 'priorCompletedReentry': REENTRY_SHA, 'priorCompletedDTO': sha(old_dto)})
    registry_keys = ('uiContent', 'uiImageFailures', 'gameplay')
    registry = normal.canonical({key: value.state.get(key) for key in registry_keys})
    session_id = value.case['assignments']['ready']['sessionId']
    originals = value.state['uiContent']['imports']
    failures = value.state.get('uiImageFailures', {}).get('imports', {})
    cases = value.state['gameplay']['cases']
    case_ids = originals[value.import_id]['caseIds']
    require(len(originals) == 1 and all(cases[case_id]['fixture'] == 'ui-real-content' and
            cases[case_id]['setupStatus'] == 'ready' and cases[case_id]['sourceContent']['sourceCaseIndex'] == index and
            cases[case_id]['sourceContent']['fixtureSha256'] == normal.FIXTURE_SHA for index, case_id in enumerate(case_ids)),
            'One exact three-case official real-content import is required')
    if completed:
        require(len(failures) == 1 and len(cases) == 4 and set(cases) == {*case_ids, next(iter(failures.values()))['caseId']},
                'The original completed environment requires its exact four-case registry')
    else:
        require(not failures and len(cases) == 3 and set(cases) == set(case_ids), 'The fresh active environment must contain only the three real cases')
    packet = json.loads(fixture.read_text())['cases'][1]
    source = packet['sourceRefs']
    mapping = value.state['uiContent']['imports'][value.import_id]['sourceTargetMap']
    require(mapping['game_sessions'][source['sessionId']] == session_id, 'Original source session mapping differs')
    question_id = mapping['game_questions'][source['questionId']]
    level_id = mapping['game_session_levels'][source['sessionLevelId']]
    expected_question = packet['expectedQuestion']
    prior_last_answer = ''
    old_receipts = []
    if completed:
        prior_assignment = json.loads(old_dto.read_text())['assignment']
        require(prior_assignment['id'] == value.assignment_id and prior_assignment['player'] == value.case['playerId'],
                'The private prior DTO must identify the exact original completed actor')
        prior_last_answer = prior_assignment['levels'][0]['lastAnswer']
        old_receipts = [row['requestIdSha256'] for row in json.loads(prior_ledger.read_text())['added']
                        if row.get('method') == 'POST' and row.get('path') == value.detail + '/answers' and row.get('status') == 200]
        require(len(old_receipts) == 1, 'The original settled receipt is absent')
    else:
        archived_record = json.loads(paths['successfulNormalReport'].read_text())['sameDataWebFixture']
        archived_dto = frame.ENTRY.guarded(Path(archived_record['file']), frame.PRIVATE, True)
        require(sha(archived_dto) == archived_record['sha256'], 'The archived active normal DTO changed')
        archived_assignment = json.loads(archived_dto.read_text())['assignment']
        archived_question = archived_assignment['levels'][0]['question']
        expected_question = {key: item for key, item in archived_question.items() if key != 'id'}
        require(normal.canonical(expected_question) == normal.canonical(packet['expectedQuestion']) and archived_assignment['status'] == 'active' and
                archived_assignment['id'] != value.assignment_id and archived_assignment['player'] != value.case['playerId'] and
                archived_assignment['session'] != session_id and archived_question['id'] != question_id,
                'The fresh active case must remap identities and preserve the complete archived question content')
        value.bound['archivedActiveDTO'], value.binding['archivedActiveDTO'] = archived_dto, sha(archived_dto)
    expected_question_canonical = normal.canonical(expected_question)
    actor, detail = value.case, value.detail
    expected_status, expected_xp = ('completed', 50) if completed else ('active', 0)
    failure, entry_reads, final_facts, settlement_unchanged = None, [], None, False

    def credentials():
        return (actor['newPassword'], value.state['controlToken'], value.token)

    def immutable():
        value.immutable()
        current = frame.ENTRY.read_state()
        require(normal.canonical({key: current.get(key) for key in registry_keys}) == registry, 'Live fixture registry changed')

    def settlement():
        if not completed:
            facts = value.facts()
            require(facts.get('assignmentStatus') == 'active' and facts.get('startedAtPresent') is True and
                    facts.get('completedAtPresent') is False and facts.get('startReceiptCount') == facts.get('progressRows') == 1 and
                    facts.get('playerTotalXp') == 0, 'The new active case must have one start/progress row and zero answer or XP facts')
            return facts
        facts = value.request(True, '/case-progress', {'caseId': value.case_id, 'kind': 'ready'})
        require(facts.get('caseId') == value.case_id and facts.get('readOnlyDiagnostic') is True and
                facts.get('assignmentStatus') == 'completed' and facts.get('answerRequestIdSha256') == old_receipts and
                all(facts.get(key) == expected for key, expected in prior['observedReadOnlyFacts'].items()),
                'The original completed case must retain its exact authoritative settlement')
        return facts

    def snapshot():
        dto = value.snapshot()
        me, listing, assignment = dto['player'], dto['assignments'], dto['assignment']
        require(me.get('id') == actor['playerId'] and me.get('account') == actor['account'] and
                me.get('mustChangePassword') is False and me.get('totalXp') == expected_xp and
                assignment.get('id') == actor['assignmentId'] and assignment.get('player') == actor['playerId'] and
                assignment.get('session') == session_id and assignment.get('status') == expected_status and
                bool(assignment.get('startedAt')) and bool(assignment.get('completedAt')) == completed and
                assignment.get('totalLevels') == 1 and assignment.get('completedLevels') == int(completed),
                'Authoritative same-session actor/status/XP facts differ')
        items, levels = listing.get('items'), assignment.get('levels')
        require(isinstance(items, list) and len(items) == 1 and items[0].get('id') == actor['assignmentId'] and
                items[0].get('player') == actor['playerId'] and items[0].get('session') == session_id and
                isinstance(levels, list) and len(levels) == 1, 'Expected exactly one own source assignment and level')
        level = levels[0]; question = level.get('question')
        require(level.get('id') == level_id and level.get('wrongCount') == 0 and level.get('locked') is False and
                bool(level.get('completedAt')) == completed and
                (bool(prior_last_answer) and level.get('lastAnswer') == prior_last_answer if completed else not level.get('lastAnswer')) and
                isinstance(question, dict) and question.get('id') == question_id and
                normal.canonical({key: item for key, item in question.items() if key != 'id'}) == expected_question_canonical,
                'The same original one-question photo choice DTO is required')
        return {'status': expected_status, 'totalXp': expected_xp, 'completedLevels': int(completed), 'sameOriginalQuestion': True}

    def photo(index, label, editable):
        slot = 'gameplay-option-image-' + str(index)
        value.ui.seek(slot + '-frame')
        value.ui.wait(lambda screen: screen.find(slot + '-pixels') is not None or screen.find(slot + '-error') is not None,
                      'own option image ready', timeout=40)
        raw, evidence = value.ui.raw_app(label)
        image = frame.own(raw, slot + '-pixels'); button = frame.own(raw, slot + '-open'); surface = frame.own(raw, slot + '-frame')
        image_box, button_box, surface_box = [ui.rect(node['bounds']) for node in (image, button, surface)]
        density = value.ui.density
        require(image.get('type') == 'Image' and button.get('type') == 'Button' and boolean(button, 'enabled') == editable and
                all(abs(a - b) <= 2 for a, b in zip(image_box, button_box)) and ui.inside(image_box, surface_box, 2) and
                ui.inside(surface_box, value.ui.viewport(slot + '-frame'), 2) and
                abs((image_box[2] - image_box[0]) / density - 312) <= 2.8 and abs((image_box[3] - image_box[1]) / density - 129) <= 2 and
                not any(row.get('id') in (slot + '-error', slot + '-loading', slot + '-retry') for row in raw),
                'The full photo geometry or actual overlay Button state differs')
        frame.write_private(value.directory / (label + '-bounds.json'), {'image': image_box, 'button': button_box, 'surface': surface_box}, credentials())
        return image_box, evidence['sha256']

    def touch(box):
        immutable()
        value.ui.run('devecocli', 'ui', 'click', round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))

    def selected_b(label):
        value.ui.seek('gameplay-option-1')
        raw, evidence = value.ui.raw_app(label)
        node = frame.own(raw, 'gameplay-option-1')
        identity = tuple(node.get(key) for key in ('accessibilityId', 'hashcode'))
        require(node.get('type') == 'Radio' and boolean(node, 'checked') and boolean(node, 'enabled') and all(identity),
                'The same genuine checked B Radio must remain observable')
        return identity, evidence['sha256']

    def check_ledger(baseline):
        rows = value.ledger()
        require(rows[:len(baseline)] == baseline and all(
            row.get('status') == 200 and row.get('fault') is False and not row.get('responseDropped') and
            ((row.get('method') == 'POST' and row.get('path') == frame.AUTH) or
             (row.get('method') == 'GET' and row.get('path') in ('/api/health', ME, frame.BASE, detail))) for row in rows[len(baseline):]),
            'Photo verification traffic escaped the read-only actor scope')
        value.cleanup['zeroForbiddenWrites'] = True
        return {'baseline': baseline, 'added': rows[len(baseline):]}

    try:
        value.stage = 'exact-owned-photo-prerequisites'
        targets = value.ui.run('hdc', 'list', 'targets').split()
        require(len(targets) == 1 and re.fullmatch(r'[A-Za-z0-9]{8,80}', targets[0]), 'One connected phone is required')
        rows = [row.split() for row in value.ui.run('hdc', '-t', targets[0], 'fport', 'ls').splitlines()]
        require([row for row in rows if len(row) > 1 and row[1] == 'tcp:18443'] ==
                [[targets[0], 'tcp:18443', 'tcp:' + str(value.state['tls']['hostPort']), '[Reverse]']], 'Own exact isolated USB TLS mapping is required')
        initial_settlement = settlement(); baseline = value.ledger()
        auth = value.request(False, frame.AUTH, {'identity': actor['account'], 'password': actor['newPassword']})
        require(auth.get('record', {}).get('id') == actor['playerId'] and isinstance(auth.get('token'), str) and auth['token'], 'Exact actor authentication failed')
        value.token = auth['token']; initial = snapshot(); immutable()
        value.stage = 'ordinary-native-photo-case-entry'
        value.device_started = True; value.ui.launch(cold=True)
        value.ui.wait(lambda screen: screen.find('account') is not None, 'own empty isolated login')
        require(value.ui.input_empty('account') and value.ui.input_empty('password') and value.ui.has_text('隔离测试环境'), 'Own empty isolated login is required')
        value.ui.fill('account', actor['account']); value.ui.fill('password', actor['newPassword']); value.ui.tap('primary-action')
        value.ui.wait(lambda screen: screen.find('current-tab') is not None and screen.find('old-password') is None, 'ordinary own home')
        if completed: value.ui.tap('history-tab')
        target = 'assignment-' + actor['assignmentId']
        value.ui.wait(lambda screen: screen.find(target) is not None, 'own exact assignment')
        offset = len(value.ledger()); immutable(); value.ui.tap(target)
        value.ui.wait(lambda screen: screen.find('gameplay-question-card') is not None and screen.find('gameplay-loading') is None,
                      'same existing question by GET', timeout=40)
        added = value.ledger()[offset:]
        entry_reads = [row for row in added if row.get('path') == detail and row.get('method') == 'GET']
        require(len(entry_reads) == 2 and all(row.get('method') == 'GET' for row in added) and
                all(row.get('status') == 200 and row.get('authenticated') is True and row.get('bearer') is False for row in entry_reads),
                'Expected two authenticated real native detail GET200 requests')
        ui_offset = len(value.ledger())
        if completed:
            value.stage = 'completed-full-photos-and-disabled-touch'
            value.ui.seek('gameplay-answer-completed')
            for theme in ('light', 'dark'):
                value.theme(theme); evidence = []
                for index in range(3):
                    label = f'completed-{theme}-photo-{index}'
                    _, raw_sha = photo(index, label, False)
                    value.ui.private_shot(label)
                    evidence.append({'rawSha256': raw_sha, 'screenshot': value.ui.private_screenshots[-1]})
                value.states.append({'themeRequested': theme, 'fullPhotoGeometryCount': 3, 'disabledOverlayButtonCount': 3, 'photos': evidence})
            box, before_touch_sha = photo(0, 'completed-disabled-touch-target', False)
            touch(box)
            raw, after_touch = value.ui.raw_app('completed-disabled-touch-result')
            require(not any(str(row.get('id', '')).startswith('image-viewer') for row in raw), 'Disabled photo touch opened a viewer')
            value.states.append({'disabledPhotoTouchObserved': True, 'viewerAbsent': True, 'targetRawSha256': before_touch_sha, 'resultRawSha256': after_touch['sha256']})
        else:
            value.stage = 'active-measured-photo-hit-retains-selection'
            value.theme('light'); immutable(); value.ui.tap('gameplay-option-1')
            before_radio, before_sha = selected_b('active-checked-before-photo')
            box, target_sha = photo(0, 'active-overlay-hit-target', True)
            touch(box)
            value.ui.wait(lambda screen: screen.find('image-viewer-pixels') is not None or screen.find('image-viewer-error') is not None,
                          'own photo viewer ready', timeout=40)
            raw, opened = value.ui.raw_app('active-single-photo-opened')
            require(frame.own(raw, 'image-viewer-pixels') and frame.own(raw, 'image-viewer-percent').get('text') == '100%' and
                    not any(row.get('id') in ('image-viewer-index', 'image-viewer-navigation', 'image-viewer-error') for row in raw),
                    'Measured photo touch must open one ready image')
            value.ui.private_shot('active-single-photo-opened')
            value.ui.run('devecocli', 'ui', 'click', '--id', 'image-viewer-close')
            value.ui.wait(lambda screen: screen.find('image-viewer') is None and screen.find('gameplay-question-card') is not None, 'only own viewer closes')
            after_radio, after_sha = selected_b('active-checked-after-photo')
            require(after_radio == before_radio, 'Photo open/close changed the genuine checked B Radio instance')
            value.states.append({'themeRequested': 'light', 'fullPhotoGeometryObserved': True, 'enabledOverlayHit': True,
                'singletonViewerObserved': True, 'checkedSelectionAndRadioInstanceRetained': True, 'targetRawSha256': target_sha,
                'radioBeforeRawSha256': before_sha, 'viewerRawSha256': opened['sha256'], 'radioAfterRawSha256': after_sha,
                'screenshot': value.ui.private_screenshots[-1]})
        require(len(value.ledger()) == ui_offset, 'Photo interaction issued an additional API request')
        final_facts = snapshot()
        require(final_facts == initial and settlement() == initial_settlement, 'Photo interaction changed authoritative active/completed facts')
        value.stage = 'targeted-photo-observations-complete'
    except Exception as error:
        reason = str(error)
        for item in credentials():
            if item: reason = reason.replace(item, '[credential omitted]')
        frame.write_private(value.directory / 'failure-diagnostic.json', {'stage': value.stage, 'exceptionType': type(error).__name__, 'reason': reason}, credentials())
        failure = 'Targeted photo observations remain incomplete'
    finally:
        ledger = None
        try:
            immutable()
            if value.device_started:
                value.ui.capture()
                if value.ui.find('image-viewer') is not None:
                    value.ui.run('devecocli', 'ui', 'click', '--id', 'image-viewer-close')
                    value.ui.wait(lambda screen: screen.find('image-viewer') is None, 'close only own viewer before logout')
                value.logout()
                settled = settlement()
                require(settled == initial_settlement, 'Authoritative case facts changed during cleanup')
                settlement_unchanged = True
                if final_facts is not None:
                    final_facts.update({key: settled[key] for key in ('startReceiptCount', 'progressRows',
                        'answerSubmissionCount', 'answerReceiptCount', 'xpLedgerCount', 'xpDeltaSum')})
                ledger = frame.write_private(value.directory / 'request-ledger.json', check_ledger(baseline), credentials())
        except Exception:
            failure = failure or 'Exact own logout, settlement or read-only ledger could not be confirmed'
        value.cleanup['remoteRawFilesRemoved'] = value.ui.remote_cleanup_ok
        if not all(value.cleanup.values()): failure = failure or 'Targeted photo cleanup remains incomplete'
    report = {'status': 'incomplete' if failure else 'captured_native_choice_photo_' + args.action, 'stage': value.stage,
        'mode': args.action, 'hapSha256': value.hap_sha, 'bindingSha256': value.binding, 'priorCompletedReentrySha256': REENTRY_SHA,
        'changedHistoricalBindings': sorted(updates), 'unchangedHistoricalBindingCount': len(historic) - len(updates),
        'nativeDetailGetStatuses': [row.get('status') for row in entry_reads], 'observedActorFacts': final_facts,
        'actorSettlementUnchanged': settlement_unchanged, 'originalCompletedSettlementObservedLive': completed and settlement_unchanged,
        'states': value.states, 'cleanup': value.cleanup, 'privateScreenshots': value.ui.private_screenshots,
        'privateRawEvidence': value.ui.raw_evidence, 'privateReadOnlyLedger': ledger, 'visualReview': 'pending_root_original_review',
        'failure': failure, 'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
    protected = [value.case_id, *credentials(), actor['account'], actor['playerId'], value.assignment_id, session_id]
    require(not re.search(r'https?://', encoded) and not any(item and item in encoded for item in protected), 'Private literal escaped into photo report')
    frame.fresh(value.report, OUT); value.report.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(value.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
    with os.fdopen(fd, 'w') as stream: stream.write(encoded)
    print(json.dumps({'status': report['status'], 'report': str(value.report.relative_to(ROOT))}), flush=True)
    return 1 if failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest='action')
    for name in ('completed', 'active'):
        mode = modes.add_parser(name)
        for arg in ('runtime', 'case-ref', 'output', 'private-dir'): mode.add_argument('--' + arg, type=Path, required=True)
        mode.add_argument('--expected-hap', required=True)
    args = parser.parse_args()
    if args.action is None: parser.print_help(); return 0
    try: return execute(args)
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded', 'reason': 'Exact prior/source/runtime/case/output guard failed'})); return 1


if __name__ == '__main__':
    sys.exit(main())

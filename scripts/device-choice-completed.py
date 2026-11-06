#!/usr/bin/env python3
"""One explicit isolated correct choice submit, then completed read-only UI.

Default/help/plan is inert. Run requires a fully successful same-HAP normal
choice report and the unchanged reviewed source/fixture/environment. It never
retries a submit, creates/resets cases, injects faults or operates production.
The correct key exists only in memory; public evidence contains aggregate
match/disabled facts, never the answer, selected index or selected geometry.
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
FIXTURE_SHA = '1ad7a59cc1f13e6dd7ec5550c8f5ab4a5906b90f9a9b56ac948143a4995e8745'
PLAN = {'scope': 'One own case1 correct choice answer and completed read-only options/images',
        'requiredBefore': 'Successful same-HAP normal choice report, own active case, one start and zero answers/XP',
        'writes': 'Exactly one native own answer; no retries, start, fault, reset, profile or password write',
        'observations': ['authoritative1correct/receipt/submission/XP50/completed1',
            'four disabled Radios and three disabled image buttons', 'same instances before and after completion if exposed',
            'three fixed representative touches (headers0/1 andphoto0) do not select/open/request',
            'completed GET re-entry without new writes'],
        'pendingCaveat': 'Submitting-disabled is claimed only if an actual pending raw tree is captured; no delay is injected'}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_normal(expected):
    path = ROOT / 'scripts/device-choice-options.py'
    if not re.fullmatch(r'[a-f0-9]{64}', expected or '') or sha(path) != expected:
        raise RuntimeError('The explicitly reviewed normal collector changed')
    spec = importlib.util.spec_from_file_location('completed_choice_normal_definitions', path)
    value = importlib.util.module_from_spec(spec); spec.loader.exec_module(value)
    return value


def create(args):
    normal = load_normal(args.expected_normal_driver_sha)
    frame = normal.load('completed_choice_frame', 'scripts/device-question-frame.py', normal.FRAME_SHA)
    require, ui, boolean = frame.require, frame.UI, normal.boolean
    args.expected_fixture_sha = FIXTURE_SHA

    class Completed(frame.FrameSample):
        def __init__(self):
            frame.fresh(args.output, OUT)
            super().__init__(args)
            self.submit_invoked, self.committed = False, False
            self.pending_observed, self.same_instances_after_completion = False, False
            self.answer_path = self.detail + '/answers'
            self.normal_report = frame.ENTRY.guarded(args.normal_report, OUT)
            require(re.fullmatch(r'[a-f0-9]{64}', args.expected_normal_sha or '') and
                    sha(self.normal_report) == args.expected_normal_sha, 'Use the exact successful normal report SHA')
            record = json.loads(self.normal_report.read_text())
            require(record.get('status') == 'captured_native_choice_options' and record.get('failure') is None and
                    record.get('hapSha256') == self.hap_sha and record.get('sourceCaseIndex') == 1 and
                    record.get('checksPassed') == len(record.get('checks', [])) >= 8 and
                    record.get('cleanup') and all(value is True for value in record['cleanup'].values()) and
                    record.get('expectedFixtureSha256') == FIXTURE_SHA,
                    'The normal choice report must be complete for this exact package/case')
            paths = {**self.bound, **normal.SOURCE_PATHS,
                'choiceDriver': ROOT / 'scripts/device-choice-options.py',
                'imageManifest': frame.ENTRY.guarded(args.images_manifest, frame.PRIVATE, True),
                'quantitativeTopHelper': ROOT / 'scripts/device-gameplay-layout.py'}
            web = ROOT.parent / 'questions-web'
            require(frame.command('git', '-C', web, 'rev-parse', 'HEAD').strip() == normal.FROZEN_WEB and
                    not frame.command('git', '-C', web, 'status', '--porcelain').strip(), 'Frozen Web checkout changed')
            paths.update({'frozenWebSource' + str(index): web / relative for index, relative in enumerate(normal.WEB_PATHS)})
            require(set(paths) == set(record.get('bindingSha256', {})) and
                    all(sha(path) == record['bindingSha256'][key] for key, path in paths.items()),
                    'Every normal source/runtime/reference/package binding must remain exact')
            self.bound, self.binding = paths, {key: sha(path) for key, path in paths.items()}
            self.guard_registry()
            self.registry_identity = normal.canonical({key: self.state[key] for key in ('uiContent', 'uiImageFailures', 'gameplay')})
            fixture = frame.ENTRY.guarded(args.fixture_file, frame.PRIVATE, True)
            require(fixture.name == 'fixture.json' and sha(fixture) == FIXTURE_SHA, 'The exact reviewed private fixture is required')
            packet = json.loads(fixture.read_text()); source = packet['cases'][1]['sourceRefs']
            keys = packet['sourceRecords']['game_answer_keys']
            matches = [(row, parsed) for row, parsed in zip(keys['rawRows'], keys['decodedJsonByRow']) if row['question'] == source['questionId']]
            require(len(matches) == 1 and matches[0][0]['normalizationVersion'] == 'nfkc-v1', 'One original choice answer row is required')
            accepted = matches[0][1]['acceptedAnswers']['value']
            require(isinstance(accepted, list) and len(accepted) == 1 and isinstance(accepted[0], str) and
                    re.fullmatch(r'[A-D]', accepted[0]) and json.loads(matches[0][0]['acceptedAnswers']) == accepted,
                    'The reviewed source must have exactly one canonical choice key')
            self.correct_key = accepted[0]  # Never enter logs, public fields, labels or low-entropy answer hashes.
            mapping = self.state['uiContent']['imports'][self.import_id]['sourceTargetMap']
            self.target_question = mapping['game_questions'][source['questionId']]
            self.target_level = mapping['game_session_levels'][source['sessionLevelId']]
            for key, path in {'completedDriver': Path(__file__), 'successfulNormalReport': self.normal_report, 'reviewedSourceFixture': fixture}.items():
                self.bound[key], self.binding[key] = path, sha(path)

        def guard_registry(self):
            require(self.case['sourceContent']['sourceCaseIndex'] == 1 and self.case['fixtureLevelKinds'] == ['choice'],
                    'Only the explicit existing real-content choice case1 is allowed')
            originals, failures = self.state.get('uiContent', {}).get('imports', {}), self.state.get('uiImageFailures', {})
            entries = failures.get('imports', {})
            require(len(originals) == len(entries) == 1 and self.import_id in originals and failures.get('schema') == 1,
                    'The exact original plus independent failure registries are required')
            original, failure = originals[self.import_id], next(iter(entries.values()))
            require(original.get('verifiedRecordCount') == 19 and original.get('fixtureSha256') == FIXTURE_SHA and
                    failure.get('fixture') == 'ui-image-failure' and failure.get('status') == 'ready' and
                    failure.get('verifiedBy') == 'official-admin-and-player-readbacks' and failure.get('targetContentRecordCount') == 7 and
                    failure.get('baseFixtureSha256') == FIXTURE_SHA and failure.get('syntheticDerivation') is True and
                    failure.get('sourceRowsRewritten') is False and
                    set(self.state['gameplay']['cases']) == {*original['caseIds'], failure['caseId']}, 'The exact four own actors changed')

        def immutable(self):
            super().immutable()
            current = frame.ENTRY.read_state()
            require(normal.canonical({key: current[key] for key in ('uiContent', 'uiImageFailures', 'gameplay')}) == self.registry_identity,
                    'The four-actor registry changed during the explicit completed sample')

        def facts(self):
            value = self.request(True, '/case-progress', {'caseId': self.case_id, 'kind': 'ready'})
            require(value.get('caseId') == self.case_id and value.get('assignmentKind') == 'ready' and
                    value.get('readOnlyDiagnostic') is True and value.get('rawAnswersOrCredentialsReturned') is False,
                    'The diagnostic must identify only the explicit own case')
            expected = {'startReceiptCount': 1, 'progressRows': 1, 'wrongCountTotal': 0, 'lockedProgressRows': 0,
                'answerSubmissionCount': 1 if self.committed else 0, 'answerReceiptCount': 1 if self.committed else 0,
                'completedProgressRows': 1 if self.committed else 0, 'xpLedgerCount': 1 if self.committed else 0,
                'xpDeltaSum': 50 if self.committed else 0, 'playerTotalXp': 50 if self.committed else 0}
            require(all(type(value.get(key)) is int and value[key] == expected_value for key, expected_value in expected.items()) and
                    value.get('assignmentStatus') == ('completed' if self.committed else 'active') and
                    value.get('completedAtPresent') is self.committed and value.get('startedAtPresent') is True,
                    'Authoritative own progress/receipt/XP facts differ from this explicit phase')
            require(value.get('submissionResults') == {'correct': 1 if self.committed else 0, 'incorrect': 0, 'manual': 0},
                    'Only one correct submission and no incorrect/manual submission are allowed')
            if hasattr(self, 'start_hashes'):
                require(value.get('startRequestIdSha256') == self.start_hashes, 'The original single entry receipt changed')
            return value

        def verify_ledger(self):
            self.cleanup['zeroForbiddenWrites'] = False
            rows = self.ledger(); require(rows[:len(self.baseline)] == self.baseline, 'The ledger was reset or truncated')
            added = rows[len(self.baseline):]
            require(all((row.get('method') == 'GET' and row.get('path') in ('/api/health', '/api/questions/v1/me', frame.BASE, self.detail)) or
                        (row.get('method') == 'POST' and row.get('path') in (frame.AUTH, self.answer_path)) for row in added),
                        'A write/read escaped the exact own auth/GET/one-answer allowlist')
            require(all(row.get('status') == 200 and row.get('fault') is False and not row.get('responseDropped') and
                        not row.get('responseAwaitingDelay') for row in added), 'A request failed or unexpected fault/pending response occurred')
            answers = [row for row in added if row.get('method') == 'POST' and row.get('path') == self.answer_path]
            require(len(answers) == (1 if self.submit_invoked else 0) and all(row.get('operation') == 'answer' and
                    row.get('authenticated') is True and row.get('bearer') is False and row.get('actorVerifiedByBackendResponse') is True and
                    row.get('actorSha256') == hashlib.sha256((self.state['controlToken'] + ':actor:' + self.case['playerId']).encode()).hexdigest() and
                    row.get('sessionLevelIdSha256') == hashlib.sha256(self.target_level.encode()).hexdigest() and
                    re.fullmatch(r'[a-f0-9]{64}', row.get('requestIdSha256', '')) for row in answers),
                    'Only the single backend-verified own native answer is allowed, without retry')
            self.final_facts = self.facts()
            if answers:
                require(self.final_facts.get('answerRequestIdSha256') == [answers[0]['requestIdSha256']], 'One native request must match the one real answer receipt')
            self.final_ledger = {'baseline': self.baseline, 'added': added}
            self.cleanup['zeroForbiddenWrites'] = True

        def level(self):
            detail = self.dto['assignment']; levels = detail.get('levels')
            require(isinstance(levels, list) and len(levels) == 1 and levels[0].get('id') == self.target_level and
                    levels[0].get('xp') == 50 and levels[0].get('autoNext') is False and
                    levels[0].get('question', {}).get('id') == self.target_question and
                    levels[0]['question'].get('kind') == 'choice', 'The current DTO does not bind the exact mapped original question/level')
            require([item.get('key') for item in levels[0]['question'].get('options', [])] == ['A', 'B', 'C', 'D'], 'The four source options changed')
            return levels[0]

        def controls(self, raw, disabled, label):
            """Validate only actually present positive nodes; off-screen is unknown."""
            identities = {}
            present = {row.get('id'): row for row in raw if row.get('bounds') and ui.positive(ui.rect(row['bounds']))}
            for index, key in enumerate(('A', 'B', 'C', 'D')):
                radio_id = 'gameplay-option-' + str(index); radio = present.get(radio_id)
                if radio is not None:
                    require(radio.get('type') == 'Radio' and boolean(radio, 'enabled') is not disabled and
                            boolean(radio, 'checked') == (key == self.correct_key), 'Actual observed Radio selected/disabled state differs from authoritative answer')
                node_ids = [radio_id] if radio is not None else []
                if index < 3:
                    image = 'gameplay-option-image-' + str(index)
                    if image + '-open' in present:
                        require(boolean(present[image + '-open'], 'enabled') is not disabled, 'An actual observed image button has the wrong disabled state')
                    node_ids.extend(image + suffix for suffix in ('-frame', '-pixels', '-open') if image + suffix in present)
                for node_id in node_ids:
                    row = present[node_id]; identity = {name: row.get(name) for name in ('accessibilityId', 'hashcode')}
                    require(all(type(value) in (str, int) and bool(value) for value in identity.values()), 'Actual Radio/thumbnail instance identity is unavailable')
                    identities[node_id] = identity
            require(not any(row.get('id') in ('image-viewer', 'image-viewer-pixels') for row in raw), 'A disabled option unexpectedly opened a viewer')
            frame.write_private(self.directory / ('instances-' + label + '.json'), {'identities': identities,
                'fourRadiosDisabled': disabled, 'selectedMatchesAuthoritative': True}, self.credentials())
            return identities

        def aggregate_controls(self, disabled, label, include_images=True, captured=None, restore=None):
            expected = {'gameplay-option-' + str(index) for index in range(4)}
            if include_images:
                expected.update('gameplay-option-image-' + str(index) + suffix for index in range(3) for suffix in ('-frame', '-pixels', '-open'))
            identities, observations = {}, []

            def add(raw, evidence):
                values = self.controls(raw, disabled, label + '-part-' + str(len(observations)))
                values = {key: value for key, value in values.items() if key in expected}
                require(all(key not in identities or identities[key] == value for key, value in values.items()),
                        'An actual instance changed between bounded visible completed observations')
                identities.update(values)
                # No checked vector, selected key or geometry enters this public provenance.
                observations.append({'rawSha256': evidence['sha256'], 'observedNodeIds': sorted(values)})

            if captured is not None: add(*captured)
            for anchor in (0, 3, 1, 2):
                if expected.issubset(identities): break
                self.ui.seek('gameplay-choice-' + str(anchor))
                add(*self.ui.raw_app(label + '-anchor-' + str(anchor)))
            require(set(identities) == expected, 'Bounded real captures did not observe every required Radio/photo instance')
            if restore is not None: self.ui.seek('gameplay-choice-' + str(restore))
            return identities, observations

        def credentials(self):
            return (self.case['newPassword'], self.state['controlToken'], self.token)

        def ready_images(self):
            for index in range(3):
                slot = 'gameplay-option-image-' + str(index)
                self.ui.seek(slot + '-frame')
                self.ui.wait(lambda value: value.find(slot + '-pixels') is not None or value.find(slot + '-error') is not None,
                             'own completed-sample option pixels', timeout=40)
                require(self.ui.find(slot + '-pixels') is not None and self.ui.find(slot + '-error') is None,
                        'The exact normal option photo must remain ready')

        def record_completed(self, theme, label, identities_expected=None):
            self.ui.seek('gameplay-answer-completed')
            marker, marker_evidence = self.ui.raw_app(label + '-completed-marker')
            require(frame.own(marker, 'gameplay-answer-completed') and not any(row.get('id') == 'gameplay-submit' for row in marker),
                    'The actually observed completed form must be read-only and have no visible submit action')
            self.ready_images()
            ids, observations = self.aggregate_controls(True, label, restore=0)
            if identities_expected is not None:
                self.same_instances_after_completion = ids == identities_expected
                require(self.same_instances_after_completion, 'Completion recreated the actual Radio or thumbnail instances')
            raw, evidence = self.ui.raw_app(label + '-restored')
            visible = self.controls(raw, True, label + '-restored')
            require(all(ids[key] == value for key, value in visible.items()), 'A restored visible completed control changed')
            self.ui.private_shot(label)
            self.states.append({'position': label, 'themeRequested': theme, 'disabledRadioCount': 4, 'disabledImageButtonCount': 3,
                'onlyOneAuthoritativeLastAnswerSelected': True, 'rawSha256': evidence['sha256'], 'screenshot': self.ui.private_screenshots[-1],
                'completedMarkerRawSha256': marker_evidence['sha256'], 'actualControlObservations': observations})
            return ids

        def disabled_touch(self, node_id, sequence):
            self.immutable(); self.ui.seek(node_id)
            target_raw, target_evidence = self.ui.raw_app('disabled-target-' + str(sequence))
            node = frame.own(target_raw, node_id)
            require(not boolean(node, 'enabled'), 'The exact target must actually report disabled before its measured touch')
            box = ui.rect(node['bounds']); require(ui.positive(box) and ui.inside(box, self.ui.viewport(node_id), 2),
                    'The observed disabled target must fit its own actual viewport')
            before = len(self.ledger())
            self.ui.run('devecocli', 'ui', 'click', round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))
            raw, evidence = self.ui.raw_app('disabled-touch-' + str(sequence))
            _, observations = self.aggregate_controls(True, 'disabled-touch-' + str(sequence), include_images=False, captured=(raw, evidence))
            require(len(self.ledger()) == before, 'Touching a disabled header/image issued an API request')
            self.disabled_touches.append({'sequence': sequence, 'targetRawSha256': target_evidence['sha256'], 'rawSha256': evidence['sha256'],
                                          'selectionUnchanged': True, 'viewerAbsent': True, 'newApiRequests': 0,
                                          'actualRadioObservations': observations})

        def main(self):
            self.stage = 'strict-active-zero-answer-baseline'
            auth = self.request(False, frame.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
            require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str) and auth['token'], 'Host auth must identify the exact own normal actor')
            self.token = auth['token']; self.dto = self.snapshot(); level = self.level()
            require(self.dto['assignment'].get('status') == 'active' and not level.get('completedAt') and not level.get('lastAnswer'), 'The normal case must remain active and unsubmitted')
            facts = self.facts(); self.start_hashes = facts['startRequestIdSha256']; self.baseline = self.ledger(); self.immutable()
            self.device_started = True; self.ui.launch(cold=True)
            self.ui.wait(lambda value: value.find('account') is not None, 'own empty isolated login')
            require(self.ui.input_empty('account') and self.ui.input_empty('password') and self.ui.has_text('隔离测试环境'), 'The own isolated login is not empty')
            self.ui.fill('account', self.case['account']); self.ui.fill('password', self.case['newPassword']); self.ui.tap('primary-action')
            self.ui.wait(lambda value: value.find('current-tab') is not None and value.find('old-password') is None, 'ordinary own direct login')
            self.ui.tap('assignment-' + self.assignment_id)
            self.ui.wait(lambda value: value.find('gameplay-question-card') is not None and value.find('gameplay-loading') is None,
                         'existing active case GET entry')
            self.theme('light'); self.ready_images(); self.immutable()
            self.ui.tap('gameplay-option-' + str(('A', 'B', 'C', 'D').index(self.correct_key)))
            before_ids, self.before_observations = self.aggregate_controls(False, 'ready-one-submit')
            self.ui.seek('gameplay-submit'); raw, _ = self.ui.raw_app('ready-one-submit-restored')
            self.controls(raw, False, 'ready-one-submit-restored')
            require(boolean(frame.own(raw, 'gameplay-submit'), 'enabled'), 'The single intended submit must actually be enabled')
            self.verify_ledger(); self.immutable(); self.stage = 'one-native-correct-submit'
            self.submit_invoked = True
            self.ui.run('devecocli', 'ui', 'click', '--id', 'gameplay-submit')  # Exactly once; no retry path.
            pending, pending_evidence = self.ui.raw_app('after-single-submit')
            submit = next((row for row in pending if row.get('id') == 'gameplay-submit'), None)
            self.pending_observed = submit is not None and submit.get('text') == '正在提交…' and not boolean(submit, 'enabled')
            self.pending_radio_count = 0
            if self.pending_observed:
                observed = self.controls(pending, True, 'actual-pending')
                self.pending_radio_count = sum(key.startswith('gameplay-option-') and not key.startswith('gameplay-option-image-') for key in observed)
            self.ui.wait(lambda value: value.find('gameplay-answer-completed') is not None and value.find('gameplay-submit') is None,
                         'one authoritative completed choice', timeout=40)
            self.committed = True; self.dto = self.snapshot(); level = self.level()
            require(self.dto['assignment'].get('status') == 'completed' and self.dto['assignment'].get('completedLevels') ==
                    self.dto['assignment'].get('totalLevels') == 1 and bool(self.dto['assignment'].get('completedAt')) and
                    bool(level.get('completedAt')) and level.get('lastAnswer') == self.correct_key and self.dto['player'].get('totalXp') == 50,
                    'The server must confirm the one completed source question and authoritative lastAnswer/XP')
            self.facts(); self.fixture = frame.write_private(self.directory / 'completed-web-dtos.json', self.dto, self.credentials())
            self.record_completed('light', 'completed-light', before_ids)
            self.check(True, 'One correct native answer yields one real submission/receipt and50XP with the same read-only Radio/photo instances')
            self.disabled_touches = []
            for node_id in ('gameplay-option-0', 'gameplay-option-1', 'gameplay-option-image-0-open'):
                self.disabled_touch(node_id, len(self.disabled_touches) + 1)
            self.check(True, 'Three fixed representative disabled header/photo touches do not change selection, open a viewer or issue API requests')
            self.theme('dark'); self.record_completed('dark', 'completed-dark')
            self.verify_ledger(); self.immutable(); self.stage = 'completed-get-only-reentry'
            before = len(self.ledger()); self.ui.back(); self.ui.wait(lambda value: value.find('current-tab') is not None, 'own completed home')
            self.ui.tap('assignment-' + self.assignment_id)
            self.ui.wait(lambda value: value.find('gameplay-answer-completed') is not None and value.find('gameplay-loading') is None,
                         'completed own GET-only reentry')
            self.dto = self.snapshot(); require(self.level().get('lastAnswer') == self.correct_key, 'Completed GET changed authoritative lastAnswer')
            self.record_completed('dark', 'completed-reentered-dark'); self.verify_ledger()
            require(all(row.get('method') == 'GET' for row in self.ledger()[before:]), 'Completed Back/reentry issued another write')
            self.check(True, 'Completed Back and reentry remain disabled from authoritative GET without another answer or XP')

        def execute(self):
            try:
                self.main(); self.stage = 'completed-choice-sample-complete'
            except Exception as error:
                reason = str(error)
                for value in self.credentials():
                    if value: reason = reason.replace(value, '[credential omitted]')
                frame.write_private(self.directory / 'failure-diagnostic.json', {'stage': self.stage,
                    'exceptionType': type(error).__name__, 'reason': reason}, self.credentials())
                self.failure = 'The separate completed choice sample is incomplete; no submit retry was attempted'
            finally:
                try:
                    self.immutable()
                    if self.device_started:
                        self.ui.capture()
                        if self.ui.find('image-viewer') is not None:
                            self.ui.run('devecocli', 'ui', 'click', '--id', 'image-viewer-close')
                            self.ui.wait(lambda value: value.find('image-viewer') is None, 'unexpected own viewer cleanup')
                        self.logout(); self.verify_ledger()
                except Exception:
                    self.failure = self.failure or 'Own cleanup or exact one-answer facts remain unconfirmed'
                self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
                if not all(self.cleanup.values()): self.failure = self.failure or 'Completed-sample cleanup remains incomplete'
            ledger = frame.write_private(self.directory / 'request-ledger.json', getattr(self, 'final_ledger', {}), self.credentials())
            report = {'status': 'incomplete' if self.failure else 'captured_native_choice_completed', 'stage': self.stage,
                'scope': PLAN['scope'], 'normalReportSha256': args.expected_normal_sha, 'bindingSha256': self.binding,
                'hapSha256': self.hap_sha, 'reviewedSourceFixtureSha256': FIXTURE_SHA, 'correctKeyReadOnlyInMemory': True,
                'checks': self.checks, 'checksPassed': len(self.checks), 'states': self.states, 'cleanup': self.cleanup,
                'pendingDisabledActuallyObserved': self.pending_observed, 'sameInstancesBeforeAndAfterCompletion': self.same_instances_after_completion,
                'pendingRadiosActuallyObservedCount': getattr(self, 'pending_radio_count', 0),
                'allFourRadiosDuringPendingClaimed': self.pending_observed and getattr(self, 'pending_radio_count', 0) == 4,
                'disabledTouchObservations': getattr(self, 'disabled_touches', []), 'singleNativeSubmitInvoked': self.submit_invoked,
                'lastAnswerMatchesReviewedFixture': self.committed and self.failure is None,
                'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
                'sameDataCompletedWebFixture': getattr(self, 'fixture', None), 'privateReadOnlyLedger': ledger,
                'observedReadOnlyFacts': {key: self.final_facts[key] for key in ('answerSubmissionCount', 'answerReceiptCount', 'completedProgressRows',
                    'xpLedgerCount', 'xpDeltaSum', 'startReceiptCount', 'progressRows', 'playerTotalXp', 'submissionResults')}
                    if hasattr(self, 'final_facts') else None,
                'visualReview': 'pending_root_original_review', 'wholePageParityAccepted': False, 'failure': self.failure,
                'fixedPreviewTouched': False, 'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
            encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
            literals = [self.case_id, self.case['account'], self.case['newPassword'], self.case['playerId'], self.assignment_id,
                        self.case['assignments']['ready']['sessionId'], self.state['controlToken'], self.token]
            require(not re.search(r'https?://', encoded) and not any(value and value in encoded for value in literals), 'A private literal would enter the completed report')
            frame.fresh(self.report, OUT); self.report.parent.mkdir(parents=True, exist_ok=True)
            fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
            with os.fdopen(fd, 'w') as stream: stream.write(encoded)
            print(json.dumps({'status': report['status'], 'report': str(self.report.relative_to(ROOT))}), flush=True)
            return 1 if self.failure else 0

    return Completed()


def main():
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest='action'); sub.add_parser('plan')
    run = sub.add_parser('run')
    for name in ('runtime', 'case-ref', 'output', 'private-dir', 'images-manifest', 'fixture-file', 'normal-report'):
        run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-hap', 'expected-normal-sha', 'expected-normal-driver-sha'):
        run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if args.action is None: parser.print_help(); return 0
    if args.action == 'plan': print(json.dumps(PLAN, indent=2)); return 0
    try: return create(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded', 'reason': 'Exact successful-normal/source/runtime/case/fixture/output guards failed; values omitted'})); return 1


if __name__ == '__main__':
    sys.exit(main())

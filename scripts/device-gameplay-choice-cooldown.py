#!/usr/bin/env python3
"""One scoped wrong choice on a fresh real-content case1; inert without run."""

import argparse
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import urllib.request

from native_device_ui import ROOT, SafeFailure

OUT = ROOT / 'artifacts/validation/ui-gameplay-feedback-20261106'
PRIVATE = ROOT / 'artifacts/private/ui-reference'
FIXTURE = PRIVATE / 'native-content-fixture-20261104-01/fixture.json'
SPEC = importlib.util.spec_from_file_location('cooldown_choice_normal', ROOT / 'scripts/device-choice-options.py')
NORMAL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NORMAL)
FRAME = NORMAL.load('cooldown_real_content_frame', 'scripts/device-question-frame.py', NORMAL.FRAME_SHA)
UI, require, boolean = FRAME.UI, FRAME.require, NORMAL.boolean
SUBMIT, PENALTY = 'gameplay-submit', 'gameplay-penalty'
CHOICES, LAST = 'gameplay-choice-options', 'gameplay-choice-3'
TITLE, FEEDBACK, MESSAGE = 'gameplay-feedback-title', 'gameplay-feedback', 'gameplay-feedback-message'
RADIOS = tuple('gameplay-option-' + str(index) for index in range(4))
DELAY_MS = 6000


class CooldownUI(FRAME.FrameUI):
    def minimum_height(self, node_id, node):
        return 46 * self.density - 2 if node_id == SUBMIT else super().minimum_height(node_id, node)


class CooldownSample(FRAME.FrameSample):
    def __init__(self, args):
        FRAME.fresh(args.output, OUT)
        FRAME.fresh(args.private_dir, PRIVATE, directory=True)
        args.expected_fixture_sha = NORMAL.FIXTURE_SHA
        super().__init__(args)
        require(self.case['sourceContent']['sourceCaseIndex'] == 1 and self.case['fixtureLevelKinds'] == ['choice'],
                'Only the exact reviewed choice case1 is supported')
        fixture = FRAME.ENTRY.guarded(args.fixture_file, FRAME.PRIVATE, True)
        require(FRAME.sha(fixture) == NORMAL.FIXTURE_SHA, 'The original private content fixture changed')
        packet = json.loads(fixture.read_text())
        case = packet['cases'][1]
        source = case['sourceRefs']
        records = packet['sourceRecords']
        mapping = self.state['uiContent']['imports'][self.import_id]['sourceTargetMap']
        self.source_ids = tuple(source.values())
        self.question_id = mapping['game_questions'][source['questionId']]
        self.level_id = mapping['game_session_levels'][source['sessionLevelId']]
        require(mapping['game_sessions'][source['sessionId']] == self.case['assignments']['ready']['sessionId'],
                'The original private case session is not the exact own target')
        source_levels = [row for row in records['game_session_levels']['rawRows'] if row['id'] == source['sessionLevelId']]
        require(len(source_levels) == 1 and json.loads(source_levels[0]['penaltyPolicy'])[0] == {'type': 'cooldown', 'seconds': 30},
                'The reviewed first-error policy must be a 30-second cooldown')
        answer_keys = records['game_answer_keys']
        matches = [(row, parsed) for row, parsed in zip(answer_keys['rawRows'], answer_keys['decodedJsonByRow'])
                   if row['question'] == source['questionId']]
        require(len(matches) == 1 and matches[0][0]['normalizationVersion'] == 'nfkc-v1', 'Expected one exact source answer key')
        accepted = matches[0][1]['acceptedAnswers']['value']
        self.question_source = case['expectedQuestion']
        options = self.question_source['options']
        keys = [option['key'] for option in options]
        require(keys == ['A', 'B', 'C', 'D'] and len(accepted) == 1 and accepted[0] in keys and
                json.loads(matches[0][0]['acceptedAnswers']) == accepted, 'The exact four options and single accepted choice are required')
        # Choose a confirmed incorrect option nearest the capsule so one
        # viewport can observe a real disabled selected Radio and submit.
        self.wrong_index = next(index for index in range(3, -1, -1) if keys[index] not in accepted)
        self.wrong = keys[self.wrong_index]
        device_ref = FRAME.ENTRY.guarded(args.device_ref, FRAME.PRIVATE, True)
        device = json.loads(device_ref.read_text())
        self.serial = device.get('deviceSerial', '')
        require(set(device) == {'deviceSerial'} and re.fullmatch(r'[A-Za-z0-9]{8,80}', self.serial),
                'A private reviewed phone reference is required')
        paths = {**NORMAL.SOURCE_PATHS, 'cooldownDriver': Path(__file__), 'sourceFixture': fixture,
                 'deviceReference': device_ref, 'choiceDriver': Path(NORMAL.__file__),
                 'feedbackComponent': ROOT / 'entry/src/main/ets/ui/StarwardQuestFeedback.ets'}
        for key, path in paths.items():
            self.bound[key], self.binding[key] = path, FRAME.sha(path)
        self.ui = CooldownUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
                              'controlToken': self.state['controlToken']}, self.ui.density, self.directory)
        self.answer_path = self.detail + '/answers'
        self.start_invoked = self.submit_invoked = self.fault_armed = False
        self.transient_feedback_observed = False
        self.cleanup['faultCleared'] = True
        self.baseline, self.final_facts, self.final_ledger = None, None, None
        self.web_fixtures = {}
        self.prior_start_receipts = []
        self.resume_evidence = None
        if args.resume_report is not None:
            self.guard_resume(args.resume_report)

    def guard_resume(self, source):
        report = FRAME.ENTRY.guarded(source, OUT)
        require(report.name == 'native-choice-cooldown-01.json', 'Only the reviewed initial incomplete choice run may resume')
        prior = json.loads(report.read_text())
        prior_binding = prior.get('bindingSha256', {})
        require(prior.get('status') == 'incomplete' and prior.get('stage') == 'one-wrong-choice-and-actual-pending' and
                prior.get('sourceCaseIndex') == 1 and prior.get('hapSha256') == self.hap_sha and prior.get('checksPassed') == 1 and
                set(prior.get('cleanup', {})) == set(self.cleanup) and all(value is True for value in prior['cleanup'].values()) and
                set(prior_binding) == set(self.binding) and
                all(prior_binding[key] == self.binding[key] for key in self.binding if key != 'cooldownDriver'),
                'The initial clean failure does not bind the same phone, case, package, runtime and source')
        facts = prior.get('observedReadOnlyFacts', {})
        require(facts.get('assignmentStatus') == 'active' and facts.get('startReceiptCount') == facts.get('progressRows') == 1 and
                all(type(facts.get(key)) is int and facts[key] == 0 for key in ('answerSubmissionCount', 'answerReceiptCount',
                    'wrongCountTotal', 'lockedProgressRows', 'completedProgressRows', 'xpLedgerCount', 'xpDeltaSum', 'playerTotalXp')),
                'The initial incomplete run must preserve exactly one entry and zero answer, penalty and XP facts')
        receipt = prior.get('privateReadOnlyLedger', {})
        ledger = FRAME.ENTRY.guarded(Path(receipt['file']), FRAME.PRIVATE, True)
        archive = FRAME.ENTRY.guarded(ledger.parent / 'driver-reviewed.py', FRAME.PRIVATE, True)
        require(ledger.name == 'request-ledger.json' and FRAME.sha(ledger) == receipt['sha256'] and
                FRAME.sha(archive) == prior_binding.get('cooldownDriver'), 'The original private ledger or driver archive changed')
        added = json.loads(ledger.read_text())['added']
        require(isinstance(added, list) and all(isinstance(row, dict) and row.get('status') == 200 and row.get('fault') is False and
                not row.get('responseDropped') and not row.get('responseAwaitingDelay') for row in added),
                'The original private ledger has an unexpected request state')
        writes = [row for row in added if row.get('method') == 'POST' and row.get('path') != FRAME.AUTH]
        actor = hashlib.sha256((self.state['controlToken'] + ':actor:' + self.case['playerId']).encode()).hexdigest()
        require(len(writes) == 1 and writes[0].get('path') == self.start and writes[0].get('operation') == 'start' and
                writes[0].get('actorSha256') == actor and writes[0].get('actorVerifiedByBackendResponse') is True and
                writes[0].get('authenticated') is True and writes[0].get('bearer') is False and
                re.fullmatch(r'[a-f0-9]{64}', writes[0].get('requestIdSha256', '') or ''),
                'The original exact case start receipt is missing or an answer was sent')
        self.prior_start_receipts = [writes[0]['requestIdSha256']]
        for key, path in {'priorResumeReport': report, 'priorResumeLedger': ledger, 'priorResumeDriverArchive': archive}.items():
            self.bound[key], self.binding[key] = path, FRAME.sha(path)
        self.resume_evidence = {'priorReport': str(report.relative_to(ROOT)), 'priorReportSha256': FRAME.sha(report),
                                'priorDriverArchivedAndMatched': True}

    @property
    def expected_new_starts(self):
        return 0 if self.prior_start_receipts else 1

    def credentials(self):
        return self.case['newPassword'], self.state['controlToken'], self.token

    def device_binding(self):
        require(self.ui.run('hdc', 'list', 'targets').split() == [self.serial], 'The exact sole reviewed phone is required')
        rows = [line.split() for line in self.ui.run('hdc', '-t', self.serial, 'fport', 'ls').splitlines()]
        require([row for row in rows if len(row) > 1 and row[1] == 'tcp:18443'] ==
                [[self.serial, 'tcp:18443', 'tcp:' + str(self.state['tls']['hostPort']), '[Reverse]']],
                'The phone lacks the exact disposable USB TLS mapping')

    def diagnostic(self, started, wrong):
        value = self.request(True, '/case-progress', {'caseId': self.case_id, 'kind': 'ready'})
        expected = {'assignmentStatus': 'active' if started else 'assigned', 'startedAtPresent': bool(started),
                    'completedAtPresent': False, 'startReceiptCount': started, 'progressRows': started,
                    'answerSubmissionCount': wrong, 'answerReceiptCount': wrong, 'wrongCountTotal': wrong,
                    'completedProgressRows': 0, 'lockedProgressRows': 0, 'xpLedgerCount': 0, 'xpDeltaSum': 0,
                    'playerTotalXp': 0, 'submissionResults': {'correct': 0, 'incorrect': wrong, 'manual': 0}}
        steps = value.get('steps', [])
        require(value.get('caseId') == self.case_id and value.get('assignmentKind') == 'ready' and
                value.get('readOnlyDiagnostic') is True and value.get('rawAnswersOrCredentialsReturned') is False and
                all(type(value.get(key)) is type(item) and value[key] == item for key, item in expected.items()) and
                len(steps) == 1 and steps[0].get('sessionLevelIdSha256') == hashlib.sha256(self.level_id.encode()).hexdigest() and
                steps[0].get('locked') is False and steps[0].get('submissionCount') == wrong,
                'The exact own cooldown, answer and zero-XP facts differ')
        return value, expected

    def added(self):
        rows = self.ledger()
        require(self.baseline is not None and rows[:len(self.baseline)] == self.baseline, 'The request ledger changed or was truncated')
        return rows[len(self.baseline):]

    def answers(self):
        return [row for row in self.added() if row['method'] == 'POST' and row['path'] == self.answer_path]

    def verify_ledger(self):
        self.cleanup['zeroForbiddenWrites'] = False
        rows, answers = self.added(), self.answers()
        allowed_get = ('/api/health', '/api/questions/v1/me', FRAME.BASE, self.detail)
        require(all((row['method'] == 'GET' and row['path'] in allowed_get) or
                    (row['method'] == 'POST' and row['path'] in (FRAME.AUTH, self.start, self.answer_path)) for row in rows) and
                all(row.get('status') == 200 and not row.get('responseDropped') and not row.get('responseAwaitingDelay')
                    and row.get('fault') is (row in answers) for row in rows), 'An unexpected or unfinished scoped request was seen')
        starts = [row for row in rows if row['method'] == 'POST' and row['path'] == self.start]
        require(len(starts) <= min(self.expected_new_starts, int(self.start_invoked)) and len(answers) <= int(self.submit_invoked),
                'An additional native entry or answer request was observed')
        actor = hashlib.sha256((self.state['controlToken'] + ':actor:' + self.case['playerId']).encode()).hexdigest()
        level = hashlib.sha256(self.level_id.encode()).hexdigest()
        for operation, records in (('start', starts), ('answer', answers)):
            require(all(row.get('operation') == operation and row.get('actorSha256') == actor and
                        row.get('authenticated') is True and row.get('bearer') is False and
                        row.get('actorVerifiedByBackendResponse') is True and
                        (operation == 'start' or row.get('sessionLevelIdSha256') == level) for row in records),
                    'A real write did not verify its actor, authentication or choice question')
        start_receipts = self.prior_start_receipts + [row['requestIdSha256'] for row in starts]
        facts, self.final_facts = self.diagnostic(len(start_receipts), len(answers))
        require(facts['startRequestIdSha256'] == start_receipts and
                facts['answerRequestIdSha256'] == [row['requestIdSha256'] for row in answers],
                'Exact native write receipts differ from the backend facts')
        self.final_ledger = {'baseline': self.baseline, 'added': rows}
        self.cleanup['zeroForbiddenWrites'] = True
        return len(starts), len(answers)

    def set_delay(self, armed):
        self.immutable()
        self.fault_armed, self.cleanup['faultCleared'] = True, False
        body = {'path': self.answer_path, 'method': 'POST', 'responseDelayMs': DELAY_MS} if armed else None
        request = urllib.request.Request(self.control_base + '/fault', data=json.dumps(body).encode(), method='POST',
                                         headers={'Authorization': self.state['controlToken'], 'Content-Type': 'application/json'})
        try:
            with self.control_opener.open(request, timeout=5) as response:
                require(response.status == 200 and json.load(response).get('configured') is True,
                        'The exact local fault controller did not acknowledge the request')
        except Exception:
            raise SafeFailure('The exact own scoped fault operation failed') from None
        if not armed:
            self.fault_armed, self.cleanup['faultCleared'] = False, True

    def dto_for(self, status, last_answer):
        dto = self.snapshot()
        detail = dto['assignment']
        require(detail['status'] == status and detail['session'] == self.case['assignments']['ready']['sessionId'] and
                detail['totalLevels'] == 1 and detail['completedLevels'] == 0 and dto['player']['totalXp'] == 0 and
                len(detail['levels']) == 1 and detail['levels'][0]['id'] == self.level_id and
                detail['levels'][0]['lastAnswer'] == last_answer, 'The exact own assignment, answer or XP DTO differs')
        level = detail['levels'][0]
        require(level.get('locked') is False and level.get('wrongCount') == int(bool(last_answer)), 'The own choice DTO penalty facts differ')
        question = level['question']
        if status == 'assigned':
            require(question is None, 'The unentered question must remain protected')
        else:
            require(question['id'] == self.question_id and
                    {key: item for key, item in question.items() if key != 'id'} == self.question_source,
                    'The live case question differs from the entire frozen source')
        return dto

    def begin(self):
        self.stage = 'fresh-choice-actor-and-entry'
        self.immutable()
        self.device_binding()
        auth = self.request(False, FRAME.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str) and auth['token'],
                'Host authentication did not identify the exact dedicated case1')
        self.token = auth['token']
        prior_started = bool(self.prior_start_receipts)
        self.dto_for('active' if prior_started else 'assigned', '')
        facts, _ = self.diagnostic(int(prior_started), 0)
        require(facts['startRequestIdSha256'] == self.prior_start_receipts,
                'The current real backend must match the exact prior start receipt and zero answers')
        if self.resume_evidence is not None:
            self.resume_evidence['currentRealStartReceiptMatches'] = True
        self.baseline = self.ledger()
        self.device_started = True
        self.ui.launch(cold=True)
        self.ui.wait(lambda ui: ui.find('account') is not None, 'own empty login')
        require(self.ui.input_empty('account') and self.ui.input_empty('password') and self.ui.has_text('隔离测试环境'),
                'The native isolated login is not empty')
        self.ui.fill('account', self.case['account'])
        self.ui.fill('password', self.case['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('old-password') is None, 'ordinary case1 login')
        self.ui.tap('assignment-' + self.assignment_id)
        if not prior_started:
            self.ui.seek('start-assignment')
            self.start_invoked = True
            self.ui.run('devecocli', 'ui', 'click', '--id', 'start-assignment')
        self.ui.wait(lambda ui: ui.find(CHOICES) is not None, 'real native choice form', timeout=40)
        require(self.ui.find('start-assignment') is None, 'Native gameplay must not offer another start action')
        self.theme('light')
        dto = self.dto_for('active', '')
        self.web_fixtures['active'] = FRAME.write_private(self.directory / 'active-web-dtos.json', dto, self.credentials())
        self.check(self.verify_ledger() == (self.expected_new_starts, 0),
                   'Isolated choice entry has one authoritative start and zero answer or XP facts')

    def geometry(self, raw, enabled):
        submit = FRAME.own(raw, SUBMIT)
        option = FRAME.own(raw, RADIOS[self.wrong_index])
        capsule = UI.rect(submit['bounds'])
        group = UI.rect(FRAME.own(raw, CHOICES)['bounds'])
        last_option = UI.rect(FRAME.own(raw, LAST)['bounds'])
        observed = [node for node in raw if node.get('id') in RADIOS and UI.exposed(node)]
        density = self.ui.density
        require(UI.exposed(submit) and submit.get('type') == 'Button' and UI.inside(capsule, self.ui.viewport(SUBMIT), 2) and
                abs(capsule[0] - group[0]) <= 2 and capsule[2] - capsule[0] < (group[2] - group[0]) * .7 and
                abs((capsule[3] - capsule[1]) / density - 46) <= 2 / density and boolean(submit, 'enabled') is enabled,
                'Actual submit must be the left-aligned compact 46vp capsule with the required enabled state')
        require(UI.exposed(option) and observed and all(node.get('type') == 'Radio' and
                boolean(node, 'enabled') is enabled and boolean(node, 'checked') == (node['id'] == option['id']) for node in observed),
                'The actual visible Radio controls do not match the enabled state and retained wrong selection')
        return capsule, last_option, len(observed)

    def shot(self, label):
        target = self.directory / (label + '.png')
        require(not target.exists() and not target.is_symlink(), 'A new original PNG path is required')
        self.ui.run('devecocli', 'ui', 'screenshot', '--path', target)
        target.chmod(0o600)
        shot = {'file': str(target.relative_to(ROOT)), 'sha256': FRAME.sha(target), 'scope': 'Private original on own dedicated choice case'}
        self.ui.private_screenshots.append(shot)
        return shot

    def sample(self, label, evidence, capsule, count, **extra):
        self.states.append({'position': label, 'themeRequested': 'light', 'submitBoundsPx': capsule,
                            'visibleRadioCount': count, 'rawSha256': evidence['sha256'], 'screenshot': self.shot(label), **extra})

    def pending(self):
        self.stage = 'one-wrong-choice-and-actual-pending'
        self.ui.tap(RADIOS[self.wrong_index])
        self.ui.seek(SUBMIT)
        raw, evidence = self.ui.raw_app('choice-ready')
        capsule, _, count = self.geometry(raw, True)
        self.sample('choice-ready-light', evidence, capsule, count)
        require(not self.answers(), 'Choice selection must issue zero answer requests')
        self.set_delay(True)
        self.device_binding()
        require(not self.answers(), 'Another write appeared before the single choice submission')
        self.submit_invoked = True
        self.ui.run('hdc', '-t', self.serial, 'shell', 'uitest', 'uiInput', 'click',
                    round((capsule[0] + capsule[2]) / 2), round((capsule[1] + capsule[3]) / 2))
        raw, evidence = self.ui.raw_app('choice-pending')
        capsule, _, count = self.geometry(raw, False)
        self.sample('choice-pending-light', evidence, capsule, count)
        rows = self.answers()
        require(len(rows) == 1 and rows[0].get('status') == 200 and rows[0].get('upstreamFinished') is True and
                rows[0].get('responseAwaitingDelay') is True, 'The actual screenshot was not captured during the exact real pending reply')
        self.check(True, 'Real pending disables the actual visible Radio and capsule submit before the held reply arrives')

    def cooldown(self):
        self.stage = 'wrong-feedback-and-real-cooldown'
        scrolled = False

        def feedback_visible(ui):
            nonlocal scrolled
            title = ui.find(TITLE)
            if title is not None and title.get('text') == '验证未通过' and ui.find(MESSAGE) is not None and ui.find(PENALTY) is not None:
                return True
            if not scrolled and ui.find(PENALTY) is not None:
                # A real countdown can push the appended feedback below the
                # old viewport. Use one ordinary official scroll to reveal it.
                scrolled = True
                left, top, right, bottom = ui.viewport()
                require(right - left >= 80 and bottom - top >= 150, 'The choice viewport cannot be safely scrolled')
                x = round(left + (right - left) * .6)
                ui.run('devecocli', 'ui', 'swipe', x, round(top + (bottom - top) * .8),
                       x, round(top + (bottom - top) * .35), '--speed', 2800)
            return False

        try:
            self.ui.wait(feedback_visible, 'wrong feedback and real countdown together', timeout=10)
            self.transient_feedback_observed = True
        except SafeFailure as error:
            if str(error) != 'UI expectation timed out: wrong feedback and real countdown together' or self.ui.find(PENALTY) is None:
                raise
        if self.transient_feedback_observed:
            shot = self.shot('choice-wrong-feedback-light')
            live = FRAME.write_private(self.directory / 'feedback-and-cooldown-layout.json', self.ui.tree, self.credentials())
            self.states.append({'position': 'choice-wrong-feedback-light', 'themeRequested': 'light',
                                'officialCliLayoutEvidence': live, 'screenshot': shot, 'scrolledToAppendedFeedback': scrolled})
        dto = self.dto_for('active', self.wrong)
        self.web_fixtures['incorrect'] = FRAME.write_private(self.directory / 'incorrect-web-dtos.json', dto, self.credentials())
        self.ui.wait(lambda ui: ui.find(TITLE) is None and ui.find(PENALTY) is not None,
                     'feedback expires while actual countdown remains', timeout=12)
        raw, evidence = self.ui.raw_app('choice-cooldown-persistent')
        capsule, field, count = self.geometry(raw, False)
        penalty = FRAME.own(raw, PENALTY)
        box = UI.rect(penalty['bounds'])
        require(UI.exposed(penalty) and '距离再次尝试还有' in penalty.get('text', '') and
                box[1] >= field[3] and box[3] <= capsule[1] and
                not any(node.get('id') in (FEEDBACK, TITLE) and UI.exposed(node) for node in raw),
                'The persistent countdown must sit after the last choice and before submit after feedback disappears')
        self.sample('choice-cooldown-persistent-light', evidence, capsule, count, penaltyBoundsPx=box)
        facts, _ = self.diagnostic(1, 1)
        require(facts['steps'][0]['cooldownActive'] is True, 'The sampled persistent countdown must still be active on the real backend')
        require(self.verify_ledger() == (self.expected_new_starts, 1), 'One incorrect native choice must record one receipt and zero XP')
        self.check(True, 'The independently authoritative cooldown persists between choice field and submit after the transient feedback window')

        self.stage = 'cooldown-expires-and-controls-restore'
        self.ui.wait(lambda ui: ui.find(PENALTY) is None and ui.find(SUBMIT) is not None,
                     'authoritative cooldown expiry reaches native controls', timeout=38)
        raw, evidence = self.ui.raw_app('choice-cooldown-expired')
        capsule, _, count = self.geometry(raw, True)
        facts, _ = self.diagnostic(1, 1)
        require(facts['steps'][0]['cooldownActive'] is False and
                not any(node.get('id') == PENALTY and UI.exposed(node) for node in raw) and
                self.verify_ledger() == (self.expected_new_starts, 1), 'Cooldown must expire with controls restored and zero additional requests')
        self.sample('choice-cooldown-expired-light', evidence, capsule, count)
        self.check(True, 'Backend expiry restores actual choice and capsule interaction without a second write or XP')

    def literals(self):
        return (*self.credentials(), self.serial, self.case_id, self.case['account'], self.case['playerId'], self.assignment_id,
                self.case['assignments']['ready']['sessionId'], self.level_id, self.question_id, *self.source_ids)

    def execute(self):
        try:
            self.begin()
            self.pending()
            self.cooldown()
        except Exception as error:
            reason = str(error)
            for item in self.literals():
                if item:
                    reason = reason.replace(item, '[private value omitted]')
            FRAME.write_private(self.directory / 'failure-diagnostic.json',
                                {'stage': self.stage, 'exceptionType': type(error).__name__, 'reason': reason}, self.credentials())
            self.failure = 'The narrow native choice cooldown check is incomplete'
        finally:
            if self.fault_armed:
                try:
                    self.set_delay(False)
                except Exception:
                    self.failure = self.failure or 'Exact scoped fault cleanup could not be confirmed'
            try:
                self.immutable()
                if self.device_started:
                    self.device_binding()
                    self.ui.wait(lambda ui: not any(row.get('responseAwaitingDelay') for row in self.answers()),
                                 'the own delayed answer is no longer pending', timeout=12)
                    self.logout()
                    self.verify_ledger()
            except Exception:
                self.failure = self.failure or 'Exact logout or own write cleanup could not be confirmed'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not all(self.cleanup.values()):
                self.failure = self.failure or 'Native cooldown cleanup is incomplete'
        self.save()
        return int(self.failure is not None)

    def save(self):
        ledger = FRAME.write_private(self.directory / 'request-ledger.json', self.final_ledger, self.credentials()) if self.final_ledger else None
        report = {'status': 'incomplete' if self.failure else 'captured_native_choice_cooldown',
                  'stage': self.stage if self.failure else 'choice-cooldown-complete',
                  'scope': 'One scoped wrong choice, actual pending, persistent countdown and expiry on one disposable case1',
                  'hapSha256': self.hap_sha, 'sourceCaseIndex': 1, 'bindingSha256': self.binding,
                  'checksPassed': len(self.checks), 'checks': self.checks, 'states': self.states, 'cleanup': self.cleanup,
                  'sameDataWebFixtures': self.web_fixtures, 'privateScreenshots': self.ui.private_screenshots,
                  'privateRawEvidence': self.ui.raw_evidence, 'privateReadOnlyLedger': ledger, 'observedReadOnlyFacts': self.final_facts,
                  'resumedFrom': self.resume_evidence,
                  'newStartRequests': sum(row['method'] == 'POST' and row['path'] == self.start
                                          for row in self.final_ledger['added']) if self.final_ledger is not None else None,
                  'transientChoiceFeedbackActuallyObserved': self.transient_feedback_observed,
                  'allRadiosInferredFromViewport': False, 'fixedPreviewTouched': False, 'failure': self.failure,
                  'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        require(not any(item and item in encoded for item in self.literals()) and not re.search(r'https?://', encoded),
                'A private literal would enter the public cooldown report')
        FRAME.fresh(self.report, OUT)
        self.report.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream:
            stream.write(encoded)
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks),
                          'report': str(self.report.relative_to(ROOT))}), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    run = parser.add_subparsers(dest='action').add_parser('run')
    for name in ('runtime', 'case-ref', 'output', 'private-dir'):
        run.add_argument('--' + name, type=Path, required=True)
    run.add_argument('--expected-hap', required=True)
    run.add_argument('--resume-report', type=Path)
    run.add_argument('--fixture-file', type=Path, default=FIXTURE)
    run.add_argument('--device-ref', type=Path, default=PRIVATE / 'image-viewer-multitouch-device-02.json')
    args = parser.parse_args()
    if args.action is None:
        parser.print_help()
        return 0
    try:
        return CooldownSample(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'Exact scoped cooldown case, package, runtime, owner or output guards failed'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

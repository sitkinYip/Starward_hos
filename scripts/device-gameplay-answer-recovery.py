#!/usr/bin/env python3
"""Root-only native text-answer recovery checks; default help performs no IO.

503, drop and late each require a separate pristine manual case created by Root.
The helper never creates/resets a case, submits a Host answer, or touches the
fixed preview account. Late acceptance requires an exact current-process receipt
after transport.send returned the complete200 and before stale-session rejection.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import time

from native_device_ui import ROOT, SafeFailure

SPEC = importlib.util.spec_from_file_location('answer_device_reused', ROOT / 'scripts/device-gameplay-answer.py')
ANSWER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ANSWER)
ENTRY = ANSWER.ENTRY
RAW_ANSWER = '  星辰大海  '
HASH_KEYS = ('requestIdSha256', 'requestBodySha256', 'actorSha256', 'sessionLevelIdSha256')


class AnswerRecovery(ANSWER.AnswerDevice):
    def __init__(self, args):
        super().__init__(args)
        ENTRY.require(self.case.get('fixture') == 'manual' and self.case.get('fixtureLevelKinds') == ['text', 'choice'],
                      'Answer recovery requires its separate pristine manual text-first case')
        self.bound['answerRecoveryDriver'] = Path(__file__)
        self.binding['answerRecoveryDriver'] = ENTRY.sha(Path(__file__))
        self.report_identity = None
        self.client_pid = None
        self.log_process = None
        self.log_sink = None
        self.log_file = None
        self.log_offset = 0
        self.client_delivery_observed = False
        self.first_level_hash = None

    def save(self, status):
        # Reserve a new report once, then update only that exact owned inode.
        # An existing report, symlink or replaced path can never be truncated.
        result = {'status': status, 'stage': self.stage, 'answerRecoveryKind': self.args.stage,
            'scope': 'Native first text-answer recovery only on a separate disposable manual case',
            'hapSha256': self.hap_sha, 'bindingSha256': self.binding, 'checksPassed': len(self.checks),
            'checks': self.checks, 'observations': self.observations, 'cleanup': self.cleanup,
            'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
            'visualReview': 'pending_root_original_review', 'fixedPreviewTouched': False,
            'privateCredentialsOrRecordIdsPersisted': False,
            'writeScope': 'Native exact-case start/text-answer only; Host authentication/read and exact disposable fault control. No creation/reset/choice/profile/password/reward/admin write.'}
        if self.failure:
            result['failure'] = self.failure
        encoded = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
        ENTRY.require(not any(secret and secret in encoded for secret in self.secrets()),
                      'A private literal would enter the public answer recovery report')
        ENTRY.require(self.report.resolve().is_relative_to(ANSWER.ANSWEROUT.resolve()),
                      'The answer recovery report escaped its public directory')
        for item in (self.report, *self.report.parents):
            ENTRY.require(not item.is_symlink(), 'An answer recovery report path is a symlink')
            if item == ROOT:
                break
        self.report.parent.mkdir(parents=True, exist_ok=True)
        flags = os.O_WRONLY | os.O_NOFOLLOW
        if self.report_identity is None:
            flags |= os.O_CREAT | os.O_EXCL
        descriptor = os.open(self.report, flags, 0o644)
        try:
            info = os.fstat(descriptor)
            identity = (info.st_dev, info.st_ino)
            ENTRY.require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid(),
                          'The answer recovery report is not an owned regular file')
            if self.report_identity is None:
                self.report_identity = identity
            ENTRY.require(identity == self.report_identity,
                          'The answer recovery report was replaced during the run')
            os.ftruncate(descriptor, 0)
            with os.fdopen(descriptor, 'w') as stream:
                descriptor = None
                stream.write(encoded)
        finally:
            if descriptor is not None:
                os.close(descriptor)

    def prepare_text(self):
        snapshot, facts = self.prepare(fresh=True)
        levels = snapshot.get('levels', [])
        ENTRY.require(snapshot.get('status') == 'active' and snapshot.get('currentIndex') == 0 and
                      len(levels) == 2 and levels[0].get('autoNext') is False and
                      levels[0].get('xp') == 50 and not levels[0].get('completedAt') and
                      isinstance(levels[0].get('question'), dict) and levels[0]['question'].get('kind') == 'text' and
                      levels[1].get('question') is None and facts.get('startReceiptCount') == 1 and
                      facts.get('progressRows') == 2 and not self.answers(),
                      'The exact native recovery case is not an entered manual first text question')
        self.first_level_hash = hashlib.sha256(levels[0]['id'].encode()).hexdigest()
        self.ui.fill('gameplay-answer-input', RAW_ANSWER)
        self.ui.seek('gameplay-submit')
        self.check(self.ui.find('gameplay-answer-input') is not None and
                   self.ui.find('gameplay-answer-input').get('text') == RAW_ANSWER,
                   'The native first text answer retains both leading and trailing spaces before submission')
        return snapshot, facts

    def strict_one_award(self, facts, rows):
        steps = facts.get('steps', [])
        return facts.get('assignmentStatus') == 'active' and facts.get('startedAtPresent') is True and \
            facts.get('completedAtPresent') is False and facts.get('startReceiptCount') == 1 and \
            facts.get('progressRows') == 2 and facts.get('answerSubmissionCount') == 1 and \
            facts.get('answerReceiptCount') == 1 and facts.get('completedProgressRows') == 1 and \
            facts.get('xpLedgerCount') == 1 and facts.get('xpDeltaSum') == facts.get('playerTotalXp') == 50 and \
            facts.get('wrongCountTotal') == facts.get('lockedProgressRows') == 0 and \
            facts.get('submissionResults') == {'correct': 1, 'incorrect': 0, 'manual': 0} and \
            len(steps) == 2 and steps[0].get('sessionLevelIdSha256') == self.first_level_hash and \
            steps[0].get('completedAtPresent') is True and steps[0].get('submissionCount') == 1 and \
            steps[0].get('xpLedgerCount') == 1 and steps[0].get('xpDeltaSum') == 50 and \
            steps[1].get('completedAtPresent') is False and steps[1].get('submissionCount') == 0 and \
            steps[1].get('xpLedgerCount') == steps[1].get('xpDeltaSum') == 0 and \
            len(rows) >= 1 and facts.get('answerRequestIdSha256') == [rows[0].get('requestIdSha256')]

    def verify_replay_identity(self, rows):
        expected_actor = hashlib.sha256((self.state['controlToken'] + ':actor:' + self.case['playerId']).encode()).hexdigest()
        self.check(len(rows) == 2 and
                   all(re.fullmatch(r'[a-f0-9]{64}', row.get(key, '') or '') for row in rows for key in HASH_KEYS) and
                   all(rows[0][key] == rows[1][key] for key in HASH_KEYS) and
                   all(row.get('actorSha256') == expected_actor and
                       row.get('sessionLevelIdSha256') == self.first_level_hash and
                       row.get('operation') == 'answer' and row.get('authenticated') is True and
                       row.get('bearer') is False for row in rows) and
                   rows[1].get('matchesPriorRequestIdentity') is True and
                   rows[1].get('actorVerifiedByBackendResponse') is True,
                   'Actual explicit retry preserves request ID, exact raw body, account and session-level hashes with raw Authorization')

    def ready_answer_pointer(self, control_id, label, expected_baseline):
        ENTRY.require(control_id in ('gameplay-submit', 'gameplay-answer-retry'),
                      'Only the reviewed native answer write actions may use this pointer')
        self.ui.seek(control_id)
        raw, evidence = self.ui.raw_app(label)
        controls = [row for row in raw if row.get('id') == control_id and ENTRY.UI.exposed(row)]
        inputs = [row for row in raw if row.get('id') == 'gameplay-answer-input']
        ENTRY.require(len(controls) == len(inputs) == 1 and controls[0].get('type') == 'Button' and
                      controls[0].get('enabled') == controls[0].get('clickable') == 'true' and
                      inputs[0].get('text') == RAW_ANSWER,
                      'A unique actual exposed enabled answer action and unchanged spaced draft are required')
        box = ENTRY.UI.rect(controls[0]['bounds'])
        app = ENTRY.UI.rect(self.ui.app_rect())
        viewport = ENTRY.UI.rect(self.ui.viewport(control_id))
        ENTRY.require(ENTRY.UI.positive(app) and ENTRY.UI.positive(viewport) and ENTRY.UI.positive(box) and
                      ENTRY.UI.inside(viewport, app) and ENTRY.UI.inside(box, viewport) and
                      box[3] - box[1] >= self.ui.minimum_height(control_id, controls[0]),
                      'The complete measured answer action is outside its actual own-App available viewport')
        point = [round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2)]
        ENTRY.require(box[0] < point[0] < box[2] and box[1] < point[1] < box[3],
                      'The measured answer pointer center is not inside its actual action')
        baseline = self.answers()
        ENTRY.require(len(baseline) == expected_baseline,
                      'The native answer ledger changed before the measured action was ready')
        return {'control': control_id, 'point': point, 'baseline': expected_baseline,
                'rawEvidenceSha256': evidence['sha256']}

    def answer_pointer_once(self, ready):
        ENTRY.require(len(self.answers()) == ready['baseline'],
                      'The native answer ledger changed before the single measured pointer')
        clicked_at = time.monotonic()
        # Exactly one official measured pointer, with no by-id fallback or
        # second click if injection fails. The polling below is read-only.
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', *ready['point'])
        deadline = time.monotonic() + 3
        while True:
            rows = self.answers()
            ENTRY.require(ready['baseline'] <= len(rows) <= ready['baseline'] + 1,
                          'The single measured action produced an unexpected native answer count')
            if len(rows) == ready['baseline'] + 1:
                self.observations.setdefault('writePointers', []).append({
                    'control': ready['control'], 'rawEvidenceSha256': ready['rawEvidenceSha256'],
                    'baselineAnswerCount': ready['baseline'], 'observedAnswerCount': len(rows),
                    'pointerCount': 1, 'fallbackClickPermitted': False})
                return clicked_at
            ENTRY.require(time.monotonic() < deadline,
                          'The one measured pointer produced no answer request; no fallback was sent')
            time.sleep(.05)

    def retry(self):
        self.prepare_text()
        self.stage = 'answer-' + self.args.stage + '-first-attempt'
        ready = self.ready_answer_pointer('gameplay-submit', 'answer-' + self.args.stage + '-ready-submit', 0)
        fault = {'path': self.answer_path, 'method': 'POST'}
        fault.update({'status': 503} if self.args.stage == '503' else {'dropResponse': True})
        self.control('/fault', fault)
        self.fault_configured = True
        self.answer_pointer_once(ready)
        self.ui.wait(lambda ui: ui.find('gameplay-answer-retry') is not None and
                     ui.find('gameplay-answer-error') is not None, 'native explicit answer retry', timeout=40)
        self.ui.seek('gameplay-answer-retry')
        raw, evidence = self.ui.raw_app('answer-' + self.args.stage + '-error')
        self.check(any(row.get('id') == 'gameplay-answer-error' and row.get('text') and ENTRY.UI.exposed(row) for row in raw) and
                   any(row.get('id') == 'gameplay-answer-input' and row.get('text') == RAW_ANSWER for row in raw) and
                   not any(row.get('id') == 'gameplay-answer-completed' for row in raw) and
                   self.ui.has_text('暂时未能确认提交结果。你的输入仍在，重试会确认同一次提交，不会重复计次。'),
                   'Native uncertainty displays its real error, explicit reconnect and unchanged spaced answer without claiming completion')
        self.ui.private_shot('answer-' + self.args.stage + '-error')
        first_rows, first_facts = self.answers(), self.diagnostic()
        ENTRY.require(len(first_rows) == 1 and first_rows[0].get('fault') is True,
                      'The controlled native answer did not produce exactly one first attempt')
        if self.args.stage == '503':
            self.check(first_rows[0].get('status') == 503 and first_rows[0].get('upstreamFinished') is not True and
                       first_facts.get('assignmentStatus') == 'active' and first_facts.get('startReceiptCount') == 1 and
                       first_facts.get('progressRows') == 2 and all(first_facts.get(key) == 0 for key in
                       ('answerSubmissionCount', 'answerReceiptCount', 'completedProgressRows', 'xpLedgerCount',
                        'xpDeltaSum', 'playerTotalXp', 'wrongCountTotal', 'lockedProgressRows')),
                       'Injected503 is not forwarded and leaves zero answer submission, receipt, completion or XP facts')
            committed_at = None
        else:
            self.check(first_rows[0].get('status') == 200 and first_rows[0].get('upstreamFinished') is True and
                       first_rows[0].get('responseDropped') is True and
                       first_rows[0].get('actorVerifiedByBackendResponse') is True and
                       self.strict_one_award(first_facts, first_rows),
                       'Dropped client reply follows one real committed correct text submission, receipt and XP50 award')
            committed_at = self.host_read(self.detail)['levels'][0].get('completedAt')
            ENTRY.require(bool(committed_at), 'The committed text level has no completion timestamp')
        self.stage = 'answer-' + self.args.stage + '-explicit-retry'
        ready = self.ready_answer_pointer('gameplay-answer-retry', 'answer-' + self.args.stage + '-ready-retry', 1)
        self.answer_pointer_once(ready)
        self.ui.wait(lambda ui: ui.find('gameplay-answer-completed') is not None and
                     ui.find('gameplay-answer-retry') is None, 'real text answer recovery', timeout=40)
        self.ui.seek('gameplay-answer-input')
        rows, facts = self.answers(), self.diagnostic()
        after, player = self.host_read(self.detail), self.host_read('/api/questions/v1/me')
        self.check(len(rows) == 2 and rows[1].get('status') == 200 and rows[1].get('fault') is False and
                   self.strict_one_award(facts, rows) and after.get('status') == 'active' and
                   after.get('currentIndex') == 1 and after.get('completedLevels') == 1 and
                   after['levels'][0].get('lastAnswer') == RAW_ANSWER.strip() and
                   (committed_at is None or after['levels'][0].get('completedAt') == committed_at) and
                   isinstance(after['levels'][1].get('question'), dict) and player.get('totalXp') == 50,
                   'Explicit retry settles the current real snapshot with one submission, one receipt and one XP50 award without duplication')
        self.verify_replay_identity(rows)
        raw, _ = self.ui.raw_app('answer-' + self.args.stage + '-recovered')
        self.check(any(row.get('id') == 'gameplay-answer-input' and row.get('text') == '星辰大海' and
                       row.get('enabled') == 'false' for row in raw) and
                   any(row.get('id') == 'gameplay-answer-completed' for row in raw) and
                   not any(row.get('id') in ('gameplay-submit', 'gameplay-answer-retry') for row in raw),
                   'Recovered native first question shows the normalized authoritative last answer read-only')
        self.ui.seek('gameplay-next')
        self.ui.seek('question-title')
        self.check(self.ui.has_text('星辰之门') and not self.ui.has_text('守门人的选择'),
                   'Recovery keeps the manual first question until the explicit next action')
        self.observations['retry'] = {'nativeAnswerRequests': 2, 'sameRequestIdBodyActorAndSessionLevel': True,
            'leadingAndTrailingSpacesRetainedUntilAuthoritativeResponse': True,
            'firstResponseDroppedAfterCommit': self.args.stage == 'drop',
            'firstAttemptForwarded': self.args.stage == 'drop',
            'answerSubmissionCount': 1, 'answerReceiptCount': 1, 'completedProgressRows': 1,
            'xpLedgerCount': 1, 'xpDeltaSum': 50, 'playerTotalXp': 50,
            'rawErrorEvidenceSha256': evidence['sha256'], 'choiceAnswerSubmitted': False}
        self.ui.private_shot('answer-' + self.args.stage + '-recovered')
        self.immutable()

    def require_answer_boundary(self):
        boundary = self.bound['httpsRepository'].read_text()
        ENTRY.require(re.search(
            r"const response: TransportResponse = await this\.transport\.send\(request\);.*?"
            r"else if \(this\.probeBoundary && request\.method === 'POST' && request\.url\.endsWith\('/answers'\)\) \{\s*"
            r"hilog\.info\(0x0000, 'StarwardGameBoundary', 'operation=answer received=%\{public\}d sessionCurrent=%\{public\}s',\s*"
            r"response\.status, \(generation === this\.generation\)\.toString\(\)\);\s*}\s*"
            r"this\.assertCurrent\(generation\);\s*return response;", boundary, re.S),
            'The bound answer receipt is not immediately before stale-session rejection')

    def current_pid(self):
        values = self.ui.run('hdc', 'shell', 'pidof', 'com.sitkin.starward').strip().split()
        ENTRY.require(len(values) == 1 and re.fullmatch(r'[1-9][0-9]*', values[0]),
                      'The own answer App has no unique current process')
        return values[0]

    def begin_client_capture(self):
        self.require_answer_boundary()
        self.client_pid = self.current_pid()
        self.log_file = self.directory / 'late-answer-client-boundary.log'
        descriptor = os.open(self.log_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        self.log_sink = os.fdopen(descriptor, 'wb', buffering=0)
        self.log_process = subprocess.Popen(
            ['hdc', 'shell', 'hilog', '-T', 'StarwardGameBoundary', '-P', self.client_pid],
            cwd=ROOT, stdin=subprocess.DEVNULL, stdout=self.log_sink, stderr=subprocess.STDOUT)
        time.sleep(.5)
        ENTRY.require(self.log_process.poll() is None, 'The own client capture stopped before the answer')
        self.log_offset = self.log_file.stat().st_size

    def matching_client_receipts(self):
        if self.log_file is None:
            return 0
        with self.log_file.open('rb') as stream:
            stream.seek(self.log_offset)
            value = stream.read().decode('utf-8', errors='replace')
        count = 0
        for line in value.splitlines():
            match = re.fullmatch(
                r'\s*\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+(\d+)\s+\d+\s+[DIWEF]\s+'
                r'\S*/StarwardGameBoundary:\s*(.*?)\s*', line)
            if match and match[1] == self.client_pid and match[2] == 'operation=answer received=200 sessionCurrent=false':
                count += 1
        return count

    def stop_client_capture(self):
        # Stop exactly the subprocess created above, never another log collector.
        if self.log_process is not None:
            if self.log_process.poll() is None:
                self.log_process.terminate()
                try:
                    self.log_process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.log_process.kill()
                    self.log_process.wait(timeout=3)
            self.cleanup['ownClientCaptureStopped'] = self.log_process.poll() is not None
        if self.log_sink is not None:
            self.log_sink.close()
            self.log_sink = None

    def mark_empty_logout(self):
        self.ui.wait(lambda ui: ui.find('account') is not None, 'native answer empty logout')
        account, password = self.ui.find('account'), self.ui.find('password')
        self.cleanup['loggedOut'] = True
        self.cleanup['loginInputsEmpty'] = account is not None and password is not None and \
            account.get('text', '') == password.get('text', '') == ''
        self.cleanup['privateGameplayAbsent'] = all(self.ui.find(key) is None for key in
            ('gameplay-page', 'question-title', 'current-tab', 'gameplay-answer-input', 'gameplay-feedback'))
        ENTRY.require(self.cleanup['loginInputsEmpty'] and self.cleanup['privateGameplayAbsent'],
                      'Answer logout did not leave empty login inputs without private gameplay')

    def direct_logout(self, avatar=None):
        # The pointer uses this own App's measured top-bar avatar; no Back or
        # navigation away is performed while the answer is pending.
        avatar = avatar or self.ui.find('account-menu')
        ENTRY.require(avatar and avatar.get('bounds') and len(avatar['bounds']) == 4,
                      'The pending answer has no measurable own avatar action')
        box = avatar['bounds']
        x, y = round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2)
        ENTRY.require(0 < x < self.ui.width and 0 < y < self.ui.height,
                      'The own answer avatar action is outside the App viewport')
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', x, y)
        logout = self.ui.seek('logout', max_swipes=2)
        box = logout['bounds']
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click',
                    round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))
        self.mark_empty_logout()

    def late(self):
        self.prepare_text()
        self.begin_client_capture()
        self.ui.capture()
        avatar = self.ui.find('account-menu')
        ENTRY.require(avatar is not None, 'The entered text page has no direct avatar logout entry')
        self.stage = 'answer-late-pending'
        ready = self.ready_answer_pointer('gameplay-submit', 'answer-late-ready-submit', 0)
        avatar = self.ui.find('account-menu')
        ENTRY.require(avatar is not None, 'The measured ready answer page lost its direct avatar logout entry')
        self.control('/fault', {'path': self.answer_path, 'method': 'POST', 'responseDelayMs': 12000})
        self.fault_configured = True
        clicked_at = self.answer_pointer_once(ready)
        deadline = time.monotonic() + 4
        row = None
        while time.monotonic() < deadline:
            rows = self.answers()
            if len(rows) == 1 and rows[0].get('upstreamFinished') is True:
                row = rows[0]
                break
            time.sleep(.1)
        self.check(row is not None and row.get('status') == 200 and row.get('responseAwaitingDelay') is True and
                   row.get('actorVerifiedByBackendResponse') is True,
                   'The real text answer commits while its native200 response is still delayed')
        pending_seen = time.monotonic()
        self.stage = 'answer-late-direct-logout'
        self.direct_logout(avatar)
        rows = self.answers()
        self.check(self.cleanup['loginInputsEmpty'] and self.cleanup['privateGameplayAbsent'] and
                   len(rows) == 1 and rows[0].get('responseAwaitingDelay') is True,
                   'Direct top-bar avatar logout reaches empty authentication before the delayed answer reply is released')
        at_logout_count = len(self.requests())
        elapsed_ms = round((time.monotonic() - pending_seen) * 1000)
        self.stage = 'answer-late-observation'
        deadline = time.monotonic() + 20
        delay_completed = False
        while time.monotonic() < deadline:
            rows = self.answers()
            if len(rows) == 1 and rows[0].get('responseAwaitingDelay') is False:
                delay_completed = True
                break
            time.sleep(.25)
        self.check(delay_completed and rows[0].get('upstreamFinished') is True and rows[0].get('status') == 200,
                   'The proxy finishes the answer response delay after a real upstream200')
        time.sleep(3)
        ENTRY.require(self.current_pid() == self.client_pid,
                      'The own App process changed during the pending answer observation')
        client_receipts = self.matching_client_receipts()
        self.client_delivery_observed = client_receipts == 1
        self.observations['late'] = {'upstreamCommitted200': True, 'configuredResponseDelayMs': 12000,
            'logoutObservedBeforeDelayEnded': True, 'elapsedFromPendingObservationToLogoutMs': elapsed_ms,
            'elapsedFromMeasuredPointerToLogoutMs': round((pending_seen - clicked_at) * 1000) + elapsed_ms,
            'proxyDelayFinished': True, 'sameColdAppProcessConfirmed': True,
            'matchingClientReceiptCount': client_receipts, 'clientBodyDeliveryObserved': self.client_delivery_observed,
            'staleSessionRejectedBeforeDecode': self.client_delivery_observed,
            'deliveryMeaning': 'An exact current-process operation=answer line proves transport.send returned200 after logout; its bound next statement rejects the stale generation before decode',
            'acceptanceLimit': None if self.client_delivery_observed else
                'Exact client receipt missing or duplicated; upstream200 and completed delay alone are insufficient'}
        self.check(self.client_delivery_observed,
                   'The same cold App process receives the complete answer200 after logout and rejects its stale session before decode')
        self.ui.capture()
        self.mark_empty_logout()
        self.check(len(self.requests()) == at_logout_count,
                   'No private gameplay, navigation, credentials or player requests return after the complete stale answer reply')
        rows, facts = self.answers(), self.diagnostic()
        self.check(len(rows) == 1 and self.strict_one_award(facts, rows) and
                   rows[0].get('sessionLevelIdSha256') == self.first_level_hash and
                   all(re.fullmatch(r'[a-f0-9]{64}', rows[0].get(key, '') or '') for key in HASH_KEYS) and
                   rows[0].get('authenticated') is True and rows[0].get('bearer') is False,
                   'The disposed account retains exactly one real submission, one receipt and one XP50 award without retry')
        self.observations['late'].update({'privateOrNavigationRestoreObserved': False,
            'newPlayerRequestsAfterLogout': 0, 'nativeAnswerRequests': 1,
            'answerSubmissionCount': 1, 'answerReceiptCount': 1, 'xpLedgerCount': 1, 'xpDeltaSum': 50})
        self.ui.private_shot('answer-late-empty-login')
        self.immutable()

    def ensure_logout(self):
        if not self.device_started:
            return
        # A pre-reply logout is only an earlier observation. Re-observe after
        # every outcome, including a failed late receipt assertion, so cleanup
        # never reuses stale success flags if private navigation reappeared.
        self.cleanup.update({'loggedOut': False, 'loginInputsEmpty': False,
                             'privateGameplayAbsent': False})
        self.ui.capture()
        if self.ui.find('account') is not None:
            self.mark_empty_logout()
        elif self.ui.find('logout') is not None:
            self.ui.tap('logout')
            self.mark_empty_logout()
        elif self.args.stage == 'late':
            self.direct_logout()
        elif self.ui.find('gameplay-page') is not None:
            super().logout()
            self.mark_empty_logout()
        elif self.ui.find('current-tab') is not None:
            self.ui.tap('account-menu')
            self.ui.tap('logout')
            self.mark_empty_logout()
        else:
            raise SafeFailure('The own answer page is not in a reviewed logout state')
        self.check(self.cleanup['loginInputsEmpty'] and self.cleanup['privateGameplayAbsent'],
                   'Finally cleanup confirms empty login inputs and no private gameplay')

    def main(self):
        if self.args.stage == 'late':
            self.late()
        else:
            self.retry()

    def execute(self):
        self.save('running')
        try:
            self.main()
        except Exception as error:
            self.failure = self.safe_failure(error)
        finally:
            try:
                self.ensure_logout()
            except Exception:
                self.failure = self.failure or 'Finally logout could not be confirmed for the own native answer session'
            try:
                self.stop_client_capture()
            except Exception:
                self.failure = self.failure or 'The own answer client capture cleanup was not confirmed'
            try:
                self.immutable()
                self.control('/fault', {'path': '/__unused_gameplay_answer_fault__', 'method': 'GET', 'status': 503})
                self.cleanup['faultNeutralised'] = True
            except Exception:
                self.failure = self.failure or 'Answer fault neutralization could not be confirmed for the same environment'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not self.cleanup['remoteRawFilesRemoved']:
                self.failure = self.failure or 'An exact own remote answer raw file cleanup was not confirmed'
            self.stage = 'answer-' + self.args.stage + '-complete' if self.failure is None else self.stage
            status = 'passed' if self.failure is None else 'incomplete'
            self.save(status)
        print(json.dumps({'status': status, 'checksPassed': len(self.checks),
                          'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 0 if self.failure is None else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-only separate pristine manual-case answer fault stage')
    run.add_argument('--stage', choices=('503', 'drop', 'late'), required=True)
    run.add_argument('--runtime', type=Path, default=ANSWER.ANSWEROUT / 'runtime-01.json')
    run.add_argument('--case-ref', type=Path)
    run.add_argument('--output', type=Path)
    run.add_argument('--expected-hap')
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    defaults = {'503': 'phone-answer-fault-case-ref.json', 'drop': 'phone-answer-drop-case-ref.json',
                'late': 'phone-answer-late-case-ref.json'}
    args.case_ref = args.case_ref or ANSWER.PRIVATE / defaults[args.stage]
    args.output = args.output or ANSWER.ANSWEROUT / ('device-answer-' + args.stage + '.json')
    args.delay_ms = 10000  # Satisfy the shared runtime guard; late explicitly injects12000 below timeout15000.
    try:
        return AnswerRecovery(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'The separate answer case, bound runtime, HTTPS or fresh output guard failed; private values omitted'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Root-only isolated synthetic body-image404/retry sample; default/help is inert.

Only explicit run reads private state, authenticates/reads the isolated Host and
operates the phone. It never creates/reset cases, changes a source fixture,
answers, changes passwords, arms faults or downloads an image from the Host.
The new seven-record derivation has its own guards, not the old three-case guard.
"""
import argparse
import copy
import datetime
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import ssl
import subprocess
import sys
import time
import urllib.request
from urllib.parse import urlsplit, urlunsplit
import zipfile

from native_device_ui import ROOT, SafeFailure

SPEC = importlib.util.spec_from_file_location('image_failure_frame', ROOT / 'scripts/device-question-frame.py')
FRAME = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FRAME)
ENTRY, UI = FRAME.ENTRY, FRAME.UI
require, sha = FRAME.require, FRAME.sha
OUT = ROOT / 'artifacts/validation/ui-question-images-20261104'
SLOT = 'question-images-0-0'
DRAFT = 'ImageRetryDraftOnly-DoNotSubmit'
OVERRIDE = 'question.content[0].imageUrl'
HASH = r'[a-f0-9]{64}'
ID = r'[a-z0-9]{15}'


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False, allow_nan=False)


def literal_paths(value, literal, path=()):
    if isinstance(value, dict):
        return [found for key, child in value.items() for found in literal_paths(child, literal, (*path, key))]
    if isinstance(value, list):
        return [found for index, child in enumerate(value) for found in literal_paths(child, literal, (*path, index))]
    return [path] if value == literal else []


def private_json(filename):
    path = ENTRY.guarded(filename, FRAME.PRIVATE / 'ui-reference', True)
    for parent in path.parents:
        if parent == ROOT or ROOT not in parent.parents:
            break
        if parent == FRAME.PRIVATE or FRAME.PRIVATE in parent.parents:
            info = parent.stat()
            require(info.st_uid == os.getuid() and info.st_mode & 0o777 == 0o700,
                    'Private derivation ancestors must be owned mode700')
    require(path.stat().st_size <= 5 * 1024 * 1024, 'The private derivation input is too large')
    value = json.loads(path.read_text())
    require(isinstance(value, dict), 'A private derivation input must be an object')
    return path, value


class FailureUI(FRAME.FrameUI):
    def minimum_height(self, node_id, node):
        if node_id == SLOT + '-retry':
            return 44 * self.density - 2
        return super().minimum_height(node_id, node)


class ImageFailure(FRAME.FrameSample):
    # Deliberately do not call FrameSample.__init__: that guard remains exactly
    # three ui-real-content cases/19 records and cannot identify this derivation.
    def __init__(self, args):
        self.args = args
        require(all(re.fullmatch(HASH, value or '') for value in
                    (args.expected_hap, args.expected_fixture_sha, args.expected_derivation_sha)),
                'Explicit HAP, original fixture and derivation SHA256 are required')
        self.report = FRAME.fresh(args.output, OUT)
        self.directory = FRAME.fresh(args.private_dir, FRAME.PRIVATE, True)
        self.state = ENTRY.read_state()
        self.reference = ENTRY.guarded(args.case_ref, FRAME.PRIVATE, True)
        reference = json.loads(self.reference.read_text())
        self.case_id = reference.get('caseId')
        require(set(reference) == {'caseId'} and re.fullmatch(r'[a-f0-9]{16}', self.case_id or ''),
                'An explicit image-failure case reference is required')
        self.case = self.state['gameplay']['cases'].get(self.case_id)
        require(isinstance(self.case, dict) and self.case.get('caseId') == self.case_id and
                self.case.get('fixture') == 'ui-image-failure' and self.case.get('setupStatus') == 'ready' and
                self.case.get('ordinaryLoginPrepared') is True and self.case.get('fixtureLevelKinds') == ['text'] and
                re.fullmatch(r'hm_[a-f0-9]{12}', self.case.get('account', '')) and
                re.fullmatch(ID, self.case.get('playerId', '')) and
                isinstance(self.case.get('newPassword'), str) and len(self.case['newPassword']) >= 24 and
                set(self.case.get('assignments', {})) == {'ready'}, 'The explicit derived ordinary case is not ready')
        self.import_id = self.case.get('uiImageFailureImportId')
        registry = self.state.get('uiImageFailures', {})
        self.imported = registry.get('imports', {}).get(self.import_id)
        row = self.imported
        require(registry.get('schema') == 1 and isinstance(row, dict) and row.get('importId') == self.import_id and
                row.get('caseId') == self.case_id and row.get('fixture') == 'ui-image-failure' and row.get('status') == 'ready' and
                row.get('verifiedBy') == 'official-admin-and-player-readbacks' and row.get('targetContentRecordCount') == 7 and
                row.get('syntheticDerivation') is True and row.get('sourceRowsRewritten') is False and
                row.get('sourceCaseIndex') == 0 and row.get('overridePath') == OVERRIDE and
                row.get('baseFixtureSha256') == args.expected_fixture_sha and row.get('derivationSha256') == args.expected_derivation_sha and
                row.get('expectedImageHttpStatus') == 404 and row.get('observedImageHttpStatus') is None and
                row.get('imageFailureVerified') is False and row.get('gameplayStarted') is False and row.get('gameplayAnswered') is False,
                'The independent ready seven-record derivation registry is absent')
        expected_source = {'baseFixtureSha256': args.expected_fixture_sha, 'sourceCaseIndex': 0,
            'derivationSha256': args.expected_derivation_sha, 'overridePath': OVERRIDE,
            'originalImageUrlSha256': row.get('originalImageUrlSha256'), 'missingImageUrlSha256': row.get('missingImageUrlSha256')}
        require(self.case.get('sourceContent') == expected_source, 'The explicit case and derivation registry disagree')
        self.derivation_path, self.spec = private_json(args.derivation_file)
        require(sha(self.derivation_path) == args.expected_derivation_sha and
                row.get('derivationFile') == str(self.derivation_path.relative_to(ROOT)), 'The exact derivation bytes/path changed')
        originals = self.state.get('uiContent', {}).get('imports', {})
        matches = [value for value in originals.values() if value.get('fixtureSha256') == args.expected_fixture_sha]
        require(self.state.get('uiContent', {}).get('schema') == 1 and len(matches) == 1, 'The original source import is ambiguous')
        original = matches[0]
        require(original.get('fixture') == 'ui-real-content' and original.get('status') == 'ready' and
                original.get('verifiedRecordCount') == 19 and original.get('verifiedBy') == 'official-admin-and-player-readbacks' and
                len(original.get('caseIds', [])) == 3 and self.case_id not in original['caseIds'] and
                len(set(original['caseIds'])) == 3 and set(self.state['gameplay']['cases']) == {*original['caseIds'], self.case_id},
                'The original three real-content actors and separate derivation are not intact')
        self.fixture_path, packet = private_json(ROOT / original['fixtureFile'])
        require(sha(self.fixture_path) == args.expected_fixture_sha and packet.get('formatVersion') == 1 and
                packet.get('status') == 'prepared_offline_not_imported' and packet.get('importExecuted') is False and
                packet.get('productionWrites') is False and len(packet.get('cases', [])) == 3,
                'The original unmodified source packet is unavailable')
        self.base_case = packet['cases'][0]
        self.expected_question = self.base_case.get('expectedQuestion')
        require(isinstance(self.expected_question, dict) and self.expected_question.get('kind') == 'text' and
                isinstance(self.expected_question.get('content'), list) and self.expected_question['content'] and
                self.expected_question['content'][0].get('imageUrls') == [] and not self.expected_question['content'][0].get('videoUrl'),
                'The base first-text-question image scope changed')
        self.original_url = self.expected_question['content'][0].get('imageUrl')
        require(isinstance(self.original_url, str) and self.original_url, 'The registered original first image is absent')
        self.validate_derivation(packet, row)
        self.assignment_id = self.case.get('assignmentId')
        ready = self.case['assignments']['ready']
        require(set(ready) == {'assignmentId', 'sessionId'} and ready['assignmentId'] == self.assignment_id and
                all(re.fullmatch(ID, value or '') for value in ready.values()) and
                self.assignment_id != self.state['assignmentId'] and self.case['playerId'] != self.state['playerId'],
                'The derived player/assignment is not separate from the seed player')
        self.detail = FRAME.BASE + '/' + self.assignment_id
        self.start = self.detail + '/start'
        self.environment = ENTRY.EntryMain.identity(self.state)
        self.case_identity = canonical(self.case)
        self.registry_identity = canonical({'failure': registry, 'original': self.state['uiContent']})
        tls = self.state.get('tls', {})
        self.host = ENTRY.loopback(tls.get('hostBase'), 'https')
        self.control_base = ENTRY.loopback(self.state.get('controlBase'), 'http')
        proxy = ENTRY.loopback(self.state.get('proxyBase'), 'http')
        ENTRY.loopback(self.state.get('backendBase'), 'http')
        require(tls.get('base') == 'https://127.0.0.1:18443' and tls.get('hostPort') == urlsplit(self.host).port and
                re.fullmatch(r'sha256:' + HASH, self.state.get('imageId', '')), 'The isolated origin/image receipt changed')
        self.ca = ENTRY.guarded(ENTRY.ISOLATION / 'tls/ca.pem', ENTRY.ISOLATION)
        require(tls.get('caPath') == str(self.ca) and tls.get('caSha256') == sha(self.ca), 'The isolated CA receipt changed')
        source_directory = Path(self.state.get('sourceDirectory', ''))
        require(source_directory.is_absolute() and source_directory == source_directory.resolve() and
                source_directory.is_relative_to(ENTRY.ISOLATION) and source_directory.is_dir() and
                source_directory.name.startswith('questions-pb-test-'), 'The source DB is outside the disposable namespace')
        for parent in (source_directory, *source_directory.parents):
            require(not parent.is_symlink() and parent.stat().st_uid == os.getuid(), 'The disposable DB ownership changed')
            if parent == ENTRY.ISOLATION: break
        runtime_path = ENTRY.guarded(args.runtime, FRAME.VALIDATION)
        runtime = json.loads(runtime_path.read_text())
        self.hap_sha = sha(ENTRY.HAP)
        window, density = runtime.get('window', {}), runtime.get('window', {}).get('density')
        require(runtime.get('status') == 'passed' and runtime.get('installedHapSha256') == self.hap_sha == args.expected_hap and
                set(runtime.get('checks', {})) == ENTRY.CHECKS and all(value is True for value in runtime['checks'].values()) and
                window.get('fontScale') == 1 and type(density) in (int, float) and math.isfinite(density) and density > 0 and
                type(window.get('widthPx')) in (int, float) and abs(window['widthPx'] / density - 376) <= 1 / density,
                'The installed HAP needs its actual five-check376vp/font1 runtime')
        config = json.loads(ENTRY.CONFIG.read_text())
        require(config == {'isolated': True, 'endpoint': tls['base'], 'timeoutMs': 15000, 'probeTls': True, 'fontScale': 1} and
                sha(ENTRY.CONFIG.parent / 'integration-ca.pem') == sha(self.ca), 'The isolated probe config/CA changed')
        with zipfile.ZipFile(ENTRY.HAP) as archive:
            configs = [name for name in archive.namelist() if name.endswith('/rawfile/integration.json')]
            authorities = [name for name in archive.namelist() if name.endswith('/rawfile/integration-ca.pem')]
            require(len(configs) == len(authorities) == 1 and archive.read(configs[0]) == ENTRY.CONFIG.read_bytes() and
                    hashlib.sha256(archive.read(authorities[0])).hexdigest() == sha(self.ca), 'The actual HAP lacks the bound config/CA')
        self.ports = [urlsplit(proxy).port, urlsplit(self.control_base).port]
        self.births = self.ownership()
        files = {'driver': Path(__file__), 'caseReference': self.reference, 'runtime': runtime_path, 'hap': ENTRY.HAP,
            'config': ENTRY.CONFIG, 'ca': self.ca, 'derivation': self.derivation_path, 'sourceFixture': self.fixture_path,
            'imageManifest': self.manifest_path, 'frameGuard': ROOT / 'scripts/device-question-frame.py',
            'runner': ROOT / 'scripts/isolated-backend.mjs', 'tlsRunner': ROOT / 'scripts/isolated-tls.mjs',
            'failureSetup': ROOT / 'scripts/ui-image-failure-case.mjs', 'contentSetup': ROOT / 'scripts/ui-content-case.mjs',
            'entryGuard': ROOT / 'scripts/device-gameplay-entry.py', 'answerUI': ROOT / 'scripts/device-gameplay-answer.py',
            'refinementUI': ROOT / 'scripts/device-native-ui-refinements.py', 'nativeUI': ROOT / 'scripts/native_device_ui.py',
            'imageUI': ROOT / 'entry/src/main/ets/ui/StarwardQuestionImages.ets',
            'imageLoader': ROOT / 'entry/src/main/ets/platform/QuestionImageLoader.ets',
            'gameplayPage': ROOT / 'entry/src/main/ets/features/GameplayPage.ets',
            'viewModel': ROOT / 'entry/src/main/ets/features/GameplayViewModel.ets', 'index': ROOT / 'entry/src/main/ets/pages/Index.ets'}
        self.bound, self.binding = files, {name: sha(path) for name, path in files.items()}
        require("hilog.info(0x0000, 'StarwardQuestionImage'" in files['imageUI'].read_text() and
                'method: http.RequestMethod.GET' in files['imageLoader'].read_text(), 'The frozen own-App image receipt/GET contract is absent')
        context = ssl.create_default_context(cafile=str(self.ca))
        require(context.check_hostname and context.verify_mode == ssl.CERT_REQUIRED, 'Strict Host TLS is required')
        self.host_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), ENTRY.NoRedirect(), urllib.request.HTTPSHandler(context=context))
        self.control_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), ENTRY.NoRedirect())
        FRAME.private_directory(self.directory)
        self.ui = FailureUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
                             'controlToken': self.state['controlToken']}, density, self.directory)
        self.token, self.dto, self.checks, self.states = '', None, [], []
        self.stage, self.failure, self.device_started = 'prerequisites', None, False
        self.cleanup = {'loggedOut': False, 'loginInputsEmpty': False, 'privateGameplayAbsent': False,
            'remoteRawFilesRemoved': True, 'zeroForbiddenWrites': False, 'ownLogCaptureStopped': False,
            'imageAndDraftAbsentAfterLogout': False}
        self.log_process, self.log_sink, self.log_file, self.client_pid = None, None, None, None
        self.log_offset, self.observations = 0, {}

    def validate_derivation(self, packet, row):
        spec = self.spec
        keys = {'formatVersion', 'fixture', 'status', 'baseFixtureSha256', 'sourceSnapshotSha256', 'sourceCaseIndex',
            'overridePath', 'originalUrlSha256', 'missingUrl', 'nonce', 'referenceImage', 'expectedHttpStatus',
            'retryPolicy', 'networkVerified', 'importExecuted'}
        require(set(spec) == keys and type(spec.get('formatVersion')) is int and spec.get('formatVersion') == 1 and spec.get('fixture') == 'ui-image-failure' and
                spec.get('status') == 'prepared_offline_unverified_missing_candidate' and
                spec.get('baseFixtureSha256') == self.args.expected_fixture_sha and
                spec.get('sourceSnapshotSha256') == packet.get('sourceSnapshotSha256') == row.get('sourceSnapshotSha256') and
                type(spec.get('sourceCaseIndex')) is int and spec.get('sourceCaseIndex') == 0 and spec.get('overridePath') == OVERRIDE and
                spec.get('originalUrlSha256') == digest(self.original_url) == row.get('originalImageUrlSha256') and
                spec.get('expectedHttpStatus') == 404 and spec.get('retryPolicy') == 'same-url-explicit-get-only' and
                spec.get('networkVerified') is False and spec.get('importExecuted') is False and
                re.fullmatch(r'[a-f0-9]{32}', spec.get('nonce', '')), 'The offline derivation scope changed')
        original, missing = urlsplit(self.original_url), urlsplit(spec.get('missingUrl', ''))
        expected_path = original.path[:original.path.rfind('/') + 1] + 'starward-ui-missing-' + spec['nonce'] + '.png'
        require(original.scheme == 'https' and original.hostname and '.' in original.hostname and not original.username and
                not original.password and not original.fragment and original.port in (None, 443) and
                missing.geturl() == urlunsplit((original.scheme, original.netloc, expected_path, '', '')) and
                spec['missingUrl'] != self.original_url and digest(spec['missingUrl']) == row.get('missingImageUrlSha256'),
                'The derivation is not the exact same-directory single missing-image URL')
        identity = {'sourceSnapshotSha256': spec['sourceSnapshotSha256'], 'sourceCaseIndex': 0, 'overridePath': OVERRIDE,
            'originalUrlSha256': spec['originalUrlSha256'], 'missingUrlSha256': digest(spec['missingUrl'])}
        require(digest(canonical(identity)) == row.get('candidateIdentitySha256'), 'The registered candidate identity differs')
        reference = spec.get('referenceImage')
        require(isinstance(reference, dict) and set(reference) == {'manifestFile', 'manifestSha256', 'assetSha256', 'detectedMime', 'bytes'} and
                re.fullmatch(HASH, reference.get('manifestSha256', '')) and re.fullmatch(HASH, reference.get('assetSha256', '')),
                'The original image registration is incomplete')
        self.manifest_path, manifest = private_json(ROOT / reference['manifestFile'])
        require(sha(self.manifest_path) == reference['manifestSha256'] and manifest.get('status') == 'reference_image_bytes_captured' and
                manifest.get('fixtureSha256') == self.args.expected_fixture_sha and manifest.get('referer') == 'https://sitkin.top/' and
                manifest.get('nativeLoadVerified') is False and isinstance(manifest.get('assets'), list), 'The image manifest changed')
        assets = [asset for asset in manifest['assets'] if asset.get('url') == self.original_url]
        require(len(assets) == 1 and assets[0].get('sha256') == reference['assetSha256'] == row.get('referenceImageSha256') and
                assets[0].get('authorizationSent') is False and assets[0].get('detectedMime') == reference['detectedMime'] and
                reference['detectedMime'] in ('image/jpeg', 'image/png') and type(reference['bytes']) is int and
                0 < reference['bytes'] <= 5 * 1024 * 1024 and assets[0].get('bytes') == reference['bytes'],
                'The registered original asset does not bind this exact missing-image derivation')
        mappings = row.get('sourceTargetMap', {})
        require(set(mappings) == {'game_questions', 'game_answer_keys', 'game_question_settings', 'game_question_clues',
                'game_sessions', 'game_session_levels', 'game_clues'} and
                all(isinstance(value, dict) for value in mappings.values()) and
                sum(len(value) for value in mappings.values()) == 7 and
                len({value for mapping in mappings.values() for value in mapping.values()}) == 7 and
                all(re.fullmatch(ID, key) and re.fullmatch(ID, value) for mapping in mappings.values() for key, value in mapping.items()),
                'The seven fresh derived content records are not independently mapped')

    def immutable(self):
        current = ENTRY.read_state()
        require(ENTRY.EntryMain.identity(current) == self.environment and
                canonical(current['gameplay']['cases'].get(self.case_id)) == self.case_identity and
                canonical({'failure': current.get('uiImageFailures'), 'original': current.get('uiContent')}) == self.registry_identity and
                all(sha(path) == self.binding[name] for name, path in self.bound.items()) and self.ownership() == self.births,
                'The exact failure derivation, source, runtime or runner ownership changed')

    def facts(self):
        value = super().facts()
        require(value.get('playerTotalXp') == 0 and value.get('assignmentStatus') in ('assigned', 'active') and
                value.get('completedAtPresent') is False, 'The media-only sample has settlement/completion facts')
        active = value['assignmentStatus'] == 'active'
        require(value.get('startReceiptCount') == (1 if active else 0) and value.get('progressRows') == (1 if active else 0) and
                value.get('startedAtPresent') is active, 'The one-level media case has an inconsistent entry/progress receipt')
        return value

    def question(self):
        detail = self.dto['assignment']
        levels = detail.get('levels', [])
        require(detail.get('status') == 'active' and detail.get('completedLevels') == 0 and detail.get('totalLevels') == 1 and
                detail.get('currentIndex') == 0 and len(levels) == 1 and isinstance(levels[0].get('question'), dict),
                'The derived case needs one own active text question')
        question = copy.deepcopy(levels[0]['question'])
        source_refs, mapping = self.base_case['sourceRefs'], self.imported['sourceTargetMap']
        require(all(source_refs[source] in mapping[table] for source, table in
                    (('questionId', 'game_questions'), ('sessionId', 'game_sessions'), ('sessionLevelId', 'game_session_levels'))) and
                question.pop('id', None) == mapping['game_questions'].get(source_refs['questionId']) and
                detail.get('session') == mapping['game_sessions'].get(source_refs['sessionId']) and
                levels[0].get('id') == mapping['game_session_levels'].get(source_refs['sessionLevelId']) and
                question.get('content', [{}])[0].get('imageUrl') == self.spec['missingUrl'], 'The active DTO does not identify the exact derived records/URL')
        require(literal_paths(question, self.spec['missingUrl']) == [('content', 0, 'imageUrl')] and
                literal_paths(self.expected_question, self.original_url) == [('content', 0, 'imageUrl')],
                'The synthetic image source must cover exactly the one registered body-image slot')
        question['content'][0]['imageUrl'] = self.original_url
        require(question == self.expected_question and detail.get('presentation') == self.base_case['sessionPresentation'] and
                levels[0].get('presentationOverride') == self.base_case['levelPresentationOverride'],
                'Restoring the one image URL must recover the exact original question and presentation')
        return levels[0]['question'], self.base_case['expectedEffectivePresentation'].get('hideTitle', False)

    def current_pid(self):
        values = self.ui.run('hdc', 'shell', 'pidof', 'com.sitkin.starward').strip().split()
        require(len(values) == 1 and re.fullmatch(r'[1-9][0-9]*', values[0]), 'The own image App needs one current process')
        return values[0]

    def begin_capture(self):
        self.client_pid = self.current_pid()
        self.log_file = self.directory / 'own-app-image-events.log'
        descriptor = os.open(self.log_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        self.log_sink = os.fdopen(descriptor, 'wb', buffering=0)
        self.log_process = subprocess.Popen(['hdc', 'shell', 'hilog', '-T', 'StarwardQuestionImage', '-P', self.client_pid],
            cwd=ROOT, stdin=subprocess.DEVNULL, stdout=self.log_sink, stderr=subprocess.STDOUT)
        time.sleep(.5)
        require(self.log_process.poll() is None, 'The own image log capture stopped before entry')
        self.log_offset = self.log_file.stat().st_size

    def events(self):
        require(self.log_process is not None and self.log_process.poll() is None and self.current_pid() == self.client_pid,
                'The same own image App/capture must remain alive')
        with self.log_file.open('rb') as stream:
            stream.seek(self.log_offset)
            text = stream.read().decode('utf-8', errors='replace')
        if not text.endswith('\n'):
            text = text[:text.rfind('\n') + 1]  # A live capture may end midway through its next line.
        result = []
        for line in text.splitlines():
            match = re.fullmatch(r'\s*\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+(\d+)\s+\d+\s+[DIWEF]\s+\S*/StarwardQuestionImage:\s*(.*?)\s*', line)
            if not match or match[1] != self.client_pid: continue
            value = json.loads(match[2])
            require(isinstance(value, dict) and set(value) == {'slot', 'state', 'httpStatus', 'naturalWidthPx',
                    'naturalHeightPx', 'decodedWidthPx', 'decodedHeightPx'} and value['slot'] == SLOT and
                    value['state'] in ('loading', 'failed') and
                    all(type(value[key]) is int and value[key] == 0 for key in ('naturalWidthPx', 'naturalHeightPx', 'decodedWidthPx', 'decodedHeightPx')) and
                    value['httpStatus'] == (404 if value['state'] == 'failed' else 0),
                    'The exact own image slot did not report only zero-pixel loading/HTTP404 failure')
            result.append(value)
        return result

    def wait_404(self, expected):
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            self.ui.capture()
            values = self.events()
            failures = [value for value in values if value['state'] == 'failed']
            require(len(failures) <= expected and len(values) <= expected * 2, 'An unexpected extra image request/event occurred')
            if len(failures) == expected and self.ui.find(SLOT + '-error') is not None and self.ui.find(SLOT + '-retry') is not None:
                require(len(values) == expected * 2 and all(value['state'] == ('loading' if index % 2 == 0 else 'failed')
                        for index, value in enumerate(values)) and
                        all(self.ui.find(SLOT + suffix) is None for suffix in ('-loading', '-frame', '-pixels')),
                        'HTTP404 must end in a real native error/retry state with no decoded image')
                return values
            time.sleep(.25)
        raise SafeFailure('The own App HTTP404 and native failure state were not both observed')

    def draft(self, label, first=False, empty=False):
        raw, evidence = self.ui.raw_app('draft-' + label)
        rows = [row for row in raw if row.get('id') == 'gameplay-answer-input']
        require(len(rows) == 1 and rows[0].get('text', '') == ('' if empty else DRAFT), 'The actual image-page draft did not match')
        identity = {key: rows[0].get(key) for key in ('accessibilityId', 'hashcode')}
        require(all(type(value) in (str, int) and bool(value) for value in identity.values()), 'Raw answer input instance identity is absent')
        if first: self.input_identity = identity
        elif not empty: require(identity == self.input_identity, 'Image retry recreated the answer input instance')
        FRAME.write_private(self.directory / ('draft-instance-' + label + '.json'), {'identity': identity, 'draftMatches': True}, self.credentials())
        return evidence['sha256']

    def pointer_retry_once(self):
        self.ui.seek(SLOT + '-retry')
        raw, _ = self.ui.raw_app('ready-image-retry')
        targets = [row for row in raw if row.get('id') == SLOT + '-retry' and UI.exposed(row)]
        require(len(targets) == 1 and targets[0].get('type') == 'Button' and
                targets[0].get('enabled') == targets[0].get('clickable') == 'true', 'A unique exposed enabled native image retry is required')
        box, viewport = UI.rect(targets[0]['bounds']), self.ui.viewport(SLOT + '-retry')
        require(UI.positive(box) and UI.inside(box, viewport, 2) and box[3] - box[1] >= 44 * self.ui.density - 2,
                'The actual image retry touch target is clipped or too small')
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))

    def assert_absent(self, label):
        raw, evidence = self.ui.raw_app(label)
        require(not any(str(row.get('id', '')).startswith('question-images-') or row.get('id') in
                    ('gameplay-page', 'gameplay-question-card', 'gameplay-answer-input') or row.get('text') == DRAFT for row in raw),
                'Leaving the image page retained image or draft nodes')
        return evidence['sha256']

    def main(self):
        self.stage = 'host-auth-and-derived-dto'
        auth = self.request(False, FRAME.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str) and auth['token'],
                'Host auth did not identify the exact derived actor')
        self.token = auth['token']
        before, facts = self.snapshot(), self.facts()
        status, levels = before['assignment'].get('status'), before['assignment'].get('levels', [])
        self.expected_starts = 1 if status == 'assigned' else 0
        require(status in ('assigned', 'active') and len(levels) == 1 and
                facts.get('startReceiptCount') == (0 if self.expected_starts else 1) and
                facts.get('progressRows') == (0 if self.expected_starts else 1) and
                (levels[0].get('question') is None and not before['assignment'].get('startedAt') if self.expected_starts else
                 isinstance(levels[0].get('question'), dict) and bool(before['assignment'].get('startedAt'))),
                'The own derived entry baseline is inconsistent')
        self.baseline = self.ledger()
        self.immutable()
        self.stage = 'native-entry-and-real-image404'
        self.ui.launch(cold=True)
        self.device_started = True
        self.ui.wait(lambda ui: ui.find('account') is not None, 'cold isolated empty login')
        require(self.ui.input_empty('account') and self.ui.input_empty('password') and self.ui.has_text('隔离测试环境'),
                'The native isolated login is not empty')
        self.begin_capture()
        self.ui.fill('account', self.case['account']); self.ui.fill('password', self.case['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('old-password') is None, 'ordinary derived-case login')
        self.ui.tap('assignment-' + self.assignment_id)
        if self.expected_starts:
            self.ui.wait(lambda ui: ui.find('start-assignment') is not None, 'explicit derived assigned detail')
            self.ui.tap('start-assignment')
        self.ui.wait(lambda ui: ui.find('gameplay-question-card') is not None and ui.find('gameplay-loading') is None, 'derived active question', timeout=40)
        self.dto = self.snapshot(); self.question()
        self.wait_404(1)
        self.ui.seek(SLOT + '-retry')
        self.ui.private_shot('initial-image404')
        self.check(True, 'The exact derived active question reports loading then real HTTP404 and exposes native retry without pixels')
        self.verify_ledger(); self.immutable()
        self.stage = 'explicit-image-retry-retains-input'
        self.ui.fill('gameplay-answer-input', DRAFT)
        before_input = self.draft('before-retry', first=True)
        before_api = self.ledger()
        self.pointer_retry_once()
        self.wait_404(2)
        after_input = self.draft('after-retry')
        require(self.ledger() == before_api, 'Image-only retry issued an unexpected backend API request')
        self.ui.seek(SLOT + '-retry'); self.ui.private_shot('explicit-retry-image404')
        self.verify_ledger()
        self.check(True, 'One measured explicit image retry reports a second HTTP404 while the actual draft and input instance remain unchanged and no business request occurs')
        self.observations['retry'] = {'appReportedHttp404Count': 2, 'actualDraftRetained': True, 'sameAccessibilityIdAndHashcode': True,
            'beforeInputRawSha256': before_input, 'afterInputRawSha256': after_input, 'pixelsObserved': False,
            'nativeStartCommandsInThisRun': self.expected_starts, 'answerRequests': 0, 'xpDelta': 0}
        self.stage = 'back-and-get-only-revisit'
        self.ui.hide_keyboard()
        require(not self.ui.keyboard_visible(), 'Back navigation requires the observed IME to be absent')
        self.draft('before-navigation')
        reads = sum(row.get('method') == 'GET' and row.get('path') == self.detail for row in self.ledger())
        self.ui.back()
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('gameplay-page') is None, 'Back from failed image')
        self.assert_absent('home-image-draft-absent')
        self.ui.tap('assignment-' + self.assignment_id)
        self.ui.wait(lambda ui: ui.find('gameplay-question-card') is not None and ui.find('start-assignment') is None and
                     ui.find('gameplay-loading') is None, 'GET-only image revisit')
        self.wait_404(3)
        self.draft('get-revisit-empty', empty=True)
        require(sum(row.get('method') == 'GET' and row.get('path') == self.detail for row in self.ledger()) == reads + 1,
                'Revisit did not use exactly one assignment GET')
        self.verify_ledger(); self.immutable()
        self.check(True, 'Back clears image/input nodes and same active re-entry uses one GET with an empty draft, a fresh HTTP404 and no repeated start/answer/XP')
        self.observations['revisit'] = {'appReportedHttp404Count': 3, 'assignmentGets': 1, 'draftEmpty': True,
            'progressRows': 1, 'startReceiptCount': 1, 'answerSubmissionCount': 0, 'xpDelta': 0}
        self.stage = 'image-failure-sample-complete'

    def credentials(self):
        return (self.case['newPassword'], self.state['controlToken'], self.token)

    def logout(self):
        for key in ('loggedOut', 'loginInputsEmpty', 'privateGameplayAbsent', 'imageAndDraftAbsentAfterLogout'):
            self.cleanup[key] = False
        super().logout()
        self.assert_absent('logout-image-draft-absent')
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
            FRAME.write_private(self.directory / 'failure-diagnostic.json',
                {'stage': self.stage, 'exceptionType': type(error).__name__, 'reason': reason}, self.credentials())
            self.failure = 'The narrow image404/retry checks are incomplete; raw evidence remains private'
        finally:
            try:
                self.immutable()
                if self.device_started:
                    self.logout(); self.verify_ledger()
                    if self.failure is None:
                        require(len(self.events()) == 6, 'An extra image attempt appeared before logout cleanup finished')
            except Exception:
                self.failure = self.failure or 'Same-owner logout or zero-answer observations are incomplete'
            finally:
                try: self.stop_capture()
                except Exception:
                    self.cleanup['ownLogCaptureStopped'] = False
                    self.failure = self.failure or 'The own image log capture could not be stopped'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not all(self.cleanup.values()): self.failure = self.failure or 'Image-page cleanup is incomplete'
        ledger = FRAME.write_private(self.directory / 'request-ledger.json', getattr(self, 'final_ledger', {}), self.credentials())
        log = {'file': str(self.log_file.relative_to(ROOT)), 'sha256': sha(self.log_file)} if self.log_file is not None else None
        report = {'status': 'incomplete' if self.failure else 'passed', 'stage': self.stage,
            'scope': 'Explicit isolated synthetic first-body-image404, retry, retained draft, Back/GET re-entry and logout only',
            'hapSha256': self.hap_sha, 'expectedFixtureSha256': self.args.expected_fixture_sha,
            'expectedDerivationSha256': self.args.expected_derivation_sha, 'bindingSha256': self.binding,
            'checksPassed': len(self.checks), 'checks': self.checks, 'observations': self.observations,
            'cleanup': self.cleanup, 'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
            'privateOwnAppLog': log, 'privateReadOnlyLedger': ledger, 'failure': self.failure,
            'setupImageFailureVerifiedRemainsFalse': True, 'fixedPreviewTouched': False,
            'imageUrlFetchedByHost': False, 'cdnWireRequestsObserved': False,
            'httpEvidenceSource': 'Official current own-App PID-scoped StarwardQuestionImage HTTP-result events',
            'visualReview': 'pending_root_original_review',
            'excludedAcceptance': ['normal image success', 'image viewing', 'choice images', 'cancellation/late decode', 'video/BGM', 'whole page'],
            'writeScope': 'Host auth/read and optional one exact native start; no answer/profile/password/reset/fault/admin/service write',
            'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        secrets = [self.case_id, self.case['account'], self.case['playerId'], self.assignment_id,
            self.case['assignments']['ready']['sessionId'], self.original_url, self.spec['missingUrl'], *self.credentials()]
        require(not any(value and value in encoded for value in secrets) and not re.search(r'https?://', encoded),
                'A private account/image literal would enter the public report')
        FRAME.fresh(self.report, OUT); self.report.parent.mkdir(parents=True, exist_ok=True)
        descriptor = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(descriptor, 'w') as stream: stream.write(encoded)
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks), 'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 1 if self.failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action'); run = sub.add_parser('run')
    for name in ('runtime', 'case-ref', 'output', 'private-dir', 'derivation-file'):
        run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-hap', 'expected-fixture-sha', 'expected-derivation-sha'):
        run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if not args.action: parser.print_help(); return 0
    try: return ImageFailure(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded', 'error': 'Exact derived-case/runtime/ownership/output guards failed; values omitted'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

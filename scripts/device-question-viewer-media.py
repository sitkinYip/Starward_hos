#!/usr/bin/env python3
"""Inert-by-default native mixed-gallery sample for one explicit isolated actor.

Only ``run`` reads private inputs, performs the owned auth/read/native-entry
flow, or contacts the separate synthetic-media control. It does not start/stop
services, import a device SDK, fetch image bytes from the Host, submit answers,
change passwords, relax historical fixture guards, or claim late PixelMap proof.
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
import shlex
import ssl
import sys
import time
import urllib.request
from urllib.parse import urlsplit
import zipfile

from native_device_ui import ROOT, SafeFailure

SPEC = importlib.util.spec_from_file_location('mixed_viewer_definitions', ROOT / 'scripts/device-question-image-viewer.py')
VIEWER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VIEWER)
FRAME, ENTRY, UI = VIEWER.FRAME, VIEWER.FRAME.ENTRY, VIEWER.UI
require, sha, canonical = FRAME.require, FRAME.sha, VIEWER.canonical
OUT = ROOT / 'artifacts/validation/ui-image-viewer-20261105'
PRIVATE = FRAME.PRIVATE / 'ui-reference'
HASH, ID = r'[a-f0-9]{64}', r'[a-z0-9]{15}'
OVERRIDE = 'question.content[0].imageUrls'
DRAFT = 'NativeMixedViewerDraftOnly-DoNotSubmit'
TABLES = {'game_questions', 'game_answer_keys', 'game_question_settings', 'game_question_clues',
          'game_sessions', 'game_session_levels', 'game_clues'}
SERVER = ROOT / 'scripts/ui-viewer-test-media.mjs'


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def private_json(filename):
    path = ENTRY.guarded(Path(filename), PRIVATE, True)
    for parent in path.parents:
        if parent == FRAME.PRIVATE or FRAME.PRIVATE in parent.parents:
            info = parent.stat()
            require(info.st_uid == os.getuid() and info.st_mode & 0o777 == 0o700,
                    'Private input ancestors must be owned mode700')
    require(0 < path.stat().st_size <= 5 * 1024 * 1024, 'A private input size is invalid')
    value = json.loads(path.read_text())
    require(isinstance(value, dict), 'A private input must be an object')
    return path, value


def exact(value, keys, message):
    require(isinstance(value, dict) and set(value) == set(keys), message)


def paths_of(value, literal, path=()):
    if isinstance(value, dict):
        return [found for key, child in value.items() for found in paths_of(child, literal, (*path, key))]
    if isinstance(value, list):
        return [found for index, child in enumerate(value) for found in paths_of(child, literal, (*path, index))]
    return [path] if value == literal else []


class MediaUI(FRAME.FrameUI):
    def viewport(self, node_id=None):
        # A native cover has its own actual viewport. The retained underlying
        # gameplay Scroll must not clip its close/navigation controls.
        cover = self.find('image-viewer')
        if cover is not None and cover.get('bounds'):
            box, app = UI.rect(cover['bounds']), UI.rect(self.app_rect())
            return [max(box[0], app[0]), max(box[1], app[1]), min(box[2], app[2]), min(box[3], app[3])]
        return super().viewport(node_id)


class MixedViewer(FRAME.FrameSample):
    # This is an independent constructor, not a bypass of Frame's three/19 or
    # Failure's four-actor guards. Only their unchanged common read/UI methods run.
    def __init__(self, args):
        self.args = args
        require(all(re.fullmatch(HASH, getattr(args, name) or '') for name in
                    ('expected_hap', 'expected_fixture_sha', 'expected_derivation_sha', 'expected_media_receipt_sha',
                     'expected_viewer_sha', 'expected_gameplay_page_sha', 'expected_window_sha', 'expected_surfaces_sha')),
                'Explicit reviewed HAP, fixture, derivation, receipt and product SHA256 are required')
        self.report = FRAME.fresh(args.output, OUT)
        self.directory = FRAME.fresh(args.private_dir, PRIVATE, True)
        self.state = ENTRY.read_state()
        self.reference = ENTRY.guarded(args.case_ref, FRAME.PRIVATE, True)
        reference = json.loads(self.reference.read_text())
        exact(reference, {'caseId'}, 'The explicit case reference must contain only caseId')
        self.case_id = reference['caseId']
        require(re.fullmatch(r'[a-f0-9]{16}', self.case_id or ''), 'The explicit synthetic case ID is invalid')
        self.case = self.state.get('gameplay', {}).get('cases', {}).get(self.case_id)
        require(isinstance(self.case, dict) and self.case.get('caseId') == self.case_id and
                self.case.get('fixture') == 'ui-viewer-media' and self.case.get('setupStatus') == 'ready' and
                self.case.get('ordinaryLoginPrepared') is True and self.case.get('fixtureLevelKinds') == ['text'] and
                re.fullmatch(r'hm_[a-f0-9]{12}', self.case.get('account', '')) and
                re.fullmatch(ID, self.case.get('playerId', '')) and isinstance(self.case.get('newPassword'), str) and
                len(self.case['newPassword']) >= 24 and set(self.case.get('assignments', {})) == {'ready'},
                'The explicit ordinary mixed-gallery actor is not ready')
        self.import_id = self.case.get('uiViewerMediaImportId')
        original = self.registries(self.state)
        self.imported = self.state['uiViewerMedia']['imports'][self.import_id]
        self.derivation_path, self.spec = private_json(args.derivation_file)
        self.receipt_path, self.receipt = private_json(args.media_receipt)
        require(sha(self.derivation_path) == args.expected_derivation_sha and
                sha(self.receipt_path) == args.expected_media_receipt_sha,
                'The reviewed derivation or public media receipt bytes changed')
        self.fixture_path, packet = private_json(ROOT / original['fixtureFile'])
        require(sha(self.fixture_path) == args.expected_fixture_sha and packet.get('formatVersion') == 1 and
                packet.get('status') == 'prepared_offline_not_imported' and packet.get('importExecuted') is False and
                packet.get('productionWrites') is False and len(packet.get('cases', [])) == 3,
                'The unmodified original three-case packet is unavailable')
        self.base_case = packet['cases'][0]
        self.expected_question = self.base_case.get('expectedQuestion')
        require(isinstance(self.expected_question, dict) and self.expected_question.get('kind') == 'text' and
                self.expected_question.get('content') and self.expected_question['content'][0].get('imageUrls') == [] and
                self.expected_question['content'][0].get('videoUrl') == '', 'Original case0 first-image scope changed')
        self.good = self.expected_question['content'][0].get('imageUrl')
        require(isinstance(self.good, str) and self.good, 'The original GOOD image is absent')
        self.validate_derivation(packet)
        self.validate_receipt()
        self.media_state_path, media_state = private_json(args.media_state)
        self.media_identity = self.media_fixed(media_state)
        self.media_birth = self.media_owner(media_state)
        self.assignment_id = self.case.get('assignmentId')
        ready = self.case['assignments']['ready']
        exact(ready, {'assignmentId', 'sessionId'}, 'The exact one-assignment fixture is required')
        require(ready['assignmentId'] == self.assignment_id and all(re.fullmatch(ID, value or '') for value in ready.values()) and
                self.assignment_id != self.state['assignmentId'] and self.case['playerId'] != self.state['playerId'],
                'The mixed actor must be separate from the environment seed actor')
        self.detail, self.start = FRAME.BASE + '/' + self.assignment_id, FRAME.BASE + '/' + self.assignment_id + '/start'
        self.environment = ENTRY.EntryMain.identity(self.state)
        self.registry_identity = self.registry_bytes(self.state)
        tls = self.state.get('tls', {})
        self.host = ENTRY.loopback(tls.get('hostBase'), 'https')
        self.control_base = ENTRY.loopback(self.state.get('controlBase'), 'http')
        proxy = ENTRY.loopback(self.state.get('proxyBase'), 'http')
        ENTRY.loopback(self.state.get('backendBase'), 'http')
        require(tls.get('base') == 'https://127.0.0.1:18443' and tls.get('hostPort') == urlsplit(self.host).port and
                re.fullmatch(r'sha256:' + HASH, self.state.get('imageId', '')), 'The isolated TLS/image identity changed')
        self.ca = ENTRY.guarded(ENTRY.ISOLATION / 'tls/ca.pem', ENTRY.ISOLATION)
        require(tls.get('caPath') == str(self.ca) and tls.get('caSha256') == sha(self.ca), 'The isolated CA receipt changed')
        source_directory = Path(self.state.get('sourceDirectory', ''))
        require(source_directory.is_absolute() and source_directory == source_directory.resolve() and
                source_directory.is_relative_to(ENTRY.ISOLATION) and source_directory.is_dir() and
                source_directory.name.startswith('questions-pb-test-'), 'The DB is outside the owned disposable namespace')
        for parent in (source_directory, *source_directory.parents):
            require(not parent.is_symlink() and parent.stat().st_uid == os.getuid(), 'Disposable DB ownership changed')
            if parent == ENTRY.ISOLATION:
                break
        runtime_path = ENTRY.guarded(args.runtime, FRAME.VALIDATION)
        runtime = json.loads(runtime_path.read_text())
        self.hap_sha, self.window = sha(ENTRY.HAP), runtime.get('window', {})
        density = self.window.get('density')
        require(runtime.get('status') == 'passed' and runtime.get('installedHapSha256') == self.hap_sha == args.expected_hap and
                set(runtime.get('checks', {})) == ENTRY.CHECKS and all(value is True for value in runtime['checks'].values()) and
                self.window.get('fontScale') == 1 and type(density) in (int, float) and math.isfinite(density) and density > 0 and
                type(self.window.get('widthPx')) in (int, float) and abs(self.window['widthPx'] / density - 376) <= 1 / density,
                'The matching actual five-check376vp/font1 runtime is required')
        config = json.loads(ENTRY.CONFIG.read_text())
        require(config == {'isolated': True, 'endpoint': tls['base'], 'timeoutMs': 15000, 'probeTls': True, 'fontScale': 1} and
                sha(ENTRY.CONFIG.parent / 'integration-ca.pem') == sha(self.ca), 'The exact probe config/CA changed')
        with zipfile.ZipFile(ENTRY.HAP) as archive:
            configs = [name for name in archive.namelist() if name.endswith('/rawfile/integration.json')]
            authorities = [name for name in archive.namelist() if name.endswith('/rawfile/integration-ca.pem')]
            require(len(configs) == len(authorities) == 1 and archive.read(configs[0]) == ENTRY.CONFIG.read_bytes() and
                    hashlib.sha256(archive.read(authorities[0])).hexdigest() == sha(self.ca), 'The HAP lacks the bound config/CA')
        self.ports = [urlsplit(proxy).port, urlsplit(self.control_base).port]
        self.births = self.ownership()
        self.bound = {'driver': Path(__file__), 'reference': self.reference, 'runtime': runtime_path, 'hap': ENTRY.HAP,
            'config': ENTRY.CONFIG, 'ca': self.ca, 'derivation': self.derivation_path, 'fixture': self.fixture_path,
            'mediaReceipt': self.receipt_path, 'mediaSpec': self.media_spec_path, 'syntheticPng': self.png_path,
            'imageManifest': self.manifest_path, 'goodBytes': self.good_path,
            'mediaServer': SERVER, 'mediaSetup': ROOT / 'scripts/ui-viewer-media-case.mjs',
            'runner': ROOT / 'scripts/isolated-backend.mjs', 'tlsRunner': ROOT / 'scripts/isolated-tls.mjs',
            'frameGuard': ROOT / 'scripts/device-question-frame.py', 'viewerHelpers': ROOT / 'scripts/device-question-image-viewer.py',
            'imagesHelpers': ROOT / 'scripts/device-question-images.py', 'contentSetup': ROOT / 'scripts/ui-content-case.mjs',
            'failureSetup': ROOT / 'scripts/ui-image-failure-case.mjs', 'entryGuard': ROOT / 'scripts/device-gameplay-entry.py',
            'answerUI': ROOT / 'scripts/device-gameplay-answer.py', 'refinementUI': ROOT / 'scripts/device-native-ui-refinements.py',
            'nativeUI': ROOT / 'scripts/native_device_ui.py'}
        product = {'viewer': 'ui/StarwardImageViewer.ets', 'gameplay_page': 'features/GameplayPage.ets',
                   'window': 'platform/ImmersiveWindow.ets', 'surfaces': 'platform/ImmersiveSurfaces.ets',
                   'imageUI': 'ui/StarwardQuestionImages.ets', 'imageLoader': 'platform/QuestionImageLoader.ets',
                   'imageIO': 'platform/QuestionImageIO.ets', 'viewModel': 'features/GameplayViewModel.ets', 'index': 'pages/Index.ets'}
        for key, path in product.items():
            self.bound[key] = ROOT / 'entry/src/main/ets' / path
            if key in ('viewer', 'gameplay_page', 'window', 'surfaces'):
                require(sha(self.bound[key]) == getattr(args, 'expected_' + key + '_sha'), 'Reviewed product bytes changed')
        self.binding = {key: sha(path) for key, path in self.bound.items()}
        context = ssl.create_default_context(cafile=str(self.ca))
        require(context.check_hostname and context.verify_mode == ssl.CERT_REQUIRED, 'Strict isolated Host TLS is required')
        self.host_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), ENTRY.NoRedirect(), urllib.request.HTTPSHandler(context=context))
        self.control_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), ENTRY.NoRedirect())
        self.public_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), ENTRY.NoRedirect(),
                                                        urllib.request.HTTPSHandler(context=ssl.create_default_context()))
        FRAME.private_directory(self.directory)
        self.ui = MediaUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
                           'controlToken': self.state['controlToken']}, density, self.directory)
        self.token, self.dto, self.checks, self.states = '', None, [], []
        self.stage, self.failure, self.device_started = 'prerequisites', None, False
        self.gate_id, self.input_identity, self.gate_arm_attempted = None, None, False
        self.cleanup = {'loggedOut': False, 'loginInputsEmpty': False, 'privateGameplayAbsent': False,
                        'remoteRawFilesRemoved': True, 'zeroForbiddenWrites': False, 'viewerAndDraftAbsent': False,
                        'heldGateReleased': True, 'armedGateNeutralised': True}

    def registries(self, state):
        values = []
        for name in ('uiContent', 'uiImageFailures', 'uiViewerMedia'):
            registry = state.get(name)
            require(isinstance(registry, dict) and registry.get('schema') == 1 and isinstance(registry.get('imports'), dict) and
                    len(registry['imports']) == 1, 'The exact original/body-failure/viewer registries are required')
            values.append(next(iter(registry['imports'].values())))
        original, failure, viewer = values
        require(original.get('status') == 'ready' and original.get('fixture') == 'ui-real-content' and
                original.get('fixtureSha256') == self.args.expected_fixture_sha and original.get('verifiedRecordCount') == 19 and
                original.get('verifiedBy') == 'official-admin-and-player-readbacks' and len(original.get('caseIds', [])) == 3 and
                len(set(original['caseIds'])) == 3, 'The original three actors/19-record import changed')
        require(failure.get('status') == 'ready' and failure.get('fixture') == 'ui-image-failure' and
                failure.get('baseFixtureSha256') == self.args.expected_fixture_sha and failure.get('targetContentRecordCount') == 7 and
                failure.get('syntheticDerivation') is True and failure.get('sourceRowsRewritten') is False and
                failure.get('verifiedBy') == 'official-admin-and-player-readbacks', 'The separate body-failure seven-record import changed')
        require(viewer.get('importId') == self.import_id and state['uiViewerMedia']['imports'].get(self.import_id) == viewer and
                viewer.get('caseId') == self.case_id and viewer.get('fixture') == 'ui-viewer-media' and viewer.get('status') == 'ready' and
                viewer.get('baseFixtureSha256') == self.args.expected_fixture_sha and viewer.get('derivationSha256') == self.args.expected_derivation_sha and
                viewer.get('mediaReceiptSha256') == self.args.expected_media_receipt_sha and viewer.get('targetContentRecordCount') == 7 and
                viewer.get('syntheticDerivation') is True and viewer.get('sourceRowsRewritten') is False and viewer.get('nativeLoadVerified') is False and
                viewer.get('gameplayStarted') is False and viewer.get('gameplayAnswered') is False and
                viewer.get('verifiedBy') == 'official-admin-and-player-readbacks', 'The independent mixed-gallery seven-record import changed')
        actor_ids = [*original['caseIds'], failure.get('caseId'), self.case_id]
        cases = state.get('gameplay', {}).get('cases', {})
        require(len(actor_ids) == len(set(actor_ids)) == 5 and set(cases) == set(actor_ids), 'Exactly five separately registered fixture actors are required')
        for index, case_id in enumerate(original['caseIds']):
            case = cases[case_id]
            require(case.get('caseId') == case_id and case.get('fixture') == 'ui-real-content' and case.get('setupStatus') == 'ready' and
                    case.get('uiContentImportId') == original.get('importId') and case.get('ordinaryLoginPrepared') is True and
                    case.get('sourceContent', {}).get('fixtureSha256') == self.args.expected_fixture_sha and
                    case['sourceContent'].get('sourceCaseIndex') == index, 'An original actor provenance changed')
        require(cases[failure['caseId']].get('fixture') == 'ui-image-failure' and
                cases[failure['caseId']].get('uiImageFailureImportId') == failure.get('importId') and
                cases[failure['caseId']].get('setupStatus') == 'ready' and cases[failure['caseId']].get('ordinaryLoginPrepared') is True and
                len({case.get('playerId') for case in cases.values()}) == len({case.get('assignmentId') for case in cases.values()}) ==
                len({case.get('account') for case in cases.values()}) == 5 and
                state['playerId'] not in {case.get('playerId') for case in cases.values()}, 'The five actors are not distinct from each other and the seed')
        return original

    def validate_derivation(self, packet):
        spec, row = self.spec, self.imported
        exact(spec, {'formatVersion', 'fixture', 'status', 'baseFixtureSha256', 'sourceSnapshotSha256', 'sourceCaseIndex',
            'sourceRefs', 'sourceRevisions', 'overridePath', 'originalGoodUrlSha256', 'appendedUrls', 'referenceImage',
            'syntheticMedia', 'sourceRowsRewritten', 'nativeLoadVerified', 'importExecuted'}, 'The mixed derivation fields changed')
        require(spec.get('formatVersion') == 1 and spec.get('fixture') == 'ui-viewer-media' and spec.get('status') == 'prepared_offline_not_imported' and
                spec.get('baseFixtureSha256') == self.args.expected_fixture_sha and spec.get('sourceSnapshotSha256') == packet.get('sourceSnapshotSha256') == row.get('sourceSnapshotSha256') and
                type(spec.get('sourceCaseIndex')) is int and spec['sourceCaseIndex'] == row.get('sourceCaseIndex') == 0 and
                spec.get('overridePath') == row.get('overridePath') == OVERRIDE and spec.get('originalGoodUrlSha256') == row.get('originalGoodUrlSha256') == digest(self.good) and
                spec.get('sourceRefs') == row.get('sourceRefs') == self.base_case.get('sourceRefs') and
                spec.get('sourceRevisions') == row.get('sourceRevisions') and spec.get('sourceRowsRewritten') is False and
                spec.get('nativeLoadVerified') is False and spec.get('importExecuted') is False and
                row.get('derivationFile') == str(self.derivation_path.relative_to(ROOT)), 'The exact original case0 derivation provenance changed')
        source_rows = {}
        for table, ref in (('game_questions', 'questionId'), ('game_sessions', 'sessionId'), ('game_session_levels', 'sessionLevelId')):
            rows = packet.get('sourceRecords', {}).get(table, {}).get('rawRows', [])
            matches = [value for value in rows if value.get('id') == spec['sourceRefs'][ref]]
            require(len(matches) == 1, 'The original question/session/level source row is not unique')
            source_rows[table] = matches[0]
        require(spec['sourceRevisions'] == {'question': source_rows['game_questions']['revision'], 'session': source_rows['game_sessions']['revision']},
                'Source revisions differ from the frozen packet rows')
        self.source_level = source_rows['game_session_levels']
        require(type(self.source_level.get('autoNext')) in (bool, int) and self.source_level['autoNext'] in (0, 1),
                'The original autoNext value is not a supported source boolean')
        require(isinstance(spec.get('appendedUrls'), list) and len(spec['appendedUrls']) == 2 and
                all(isinstance(value, str) and value for value in spec['appendedUrls']) and
                len(set([self.good, *spec['appendedUrls']])) == 3, 'The group must preserve GOOD and append only missing/small')
        source_identity = digest(canonical({'fixture': 'ui-viewer-media', 'sourceSnapshotSha256': spec['sourceSnapshotSha256'],
            'sourceCaseIndex': 0, 'overridePath': OVERRIDE, 'originalGoodUrlSha256': digest(self.good)}))
        require(row.get('sourceIdentitySha256') == source_identity and row.get('appendedUrlSha256') == list(map(digest, spec['appendedUrls'])) and
                self.case.get('sourceContent') == {'baseFixtureSha256': self.args.expected_fixture_sha, 'sourceCaseIndex': 0,
                    'derivationSha256': self.args.expected_derivation_sha, 'sourceIdentitySha256': source_identity,
                    'overridePath': OVERRIDE, 'originalGoodUrlSha256': digest(self.good), 'appendedUrlSha256': list(map(digest, spec['appendedUrls']))},
                'The case and independent source identity disagree')
        mappings = row.get('sourceTargetMap')
        require(isinstance(mappings, dict) and set(mappings) == TABLES and all(isinstance(value, dict) for value in mappings.values()) and
                sum(map(len, mappings.values())) == len({target for mapping in mappings.values() for target in mapping.values()}) == 7 and
                all(re.fullmatch(ID, source) and re.fullmatch(ID, target) and source != target for mapping in mappings.values() for source, target in mapping.items()),
                'The seven fresh content records are not independently mapped')
        reference = spec['referenceImage']
        exact(reference, {'manifestFile', 'manifestSha256', 'file', 'sha256', 'bytes', 'detectedMime'}, 'The registered GOOD reference fields changed')
        self.manifest_path, manifest = private_json(ROOT / reference['manifestFile'])
        self.good_path = ENTRY.guarded(ROOT / reference['file'], PRIVATE, True)
        require(sha(self.manifest_path) == reference['manifestSha256'] and manifest.get('status') == 'reference_image_bytes_captured' and
                manifest.get('fixtureSha256') == self.args.expected_fixture_sha and manifest.get('referer') == 'https://sitkin.top/' and
                manifest.get('nativeLoadVerified') is False and len(manifest.get('assets', [])) == 8 and
                sha(self.good_path) == reference['sha256'] and self.good_path.stat().st_size == reference['bytes'], 'The original registered GOOD bytes changed')
        assets = [asset for asset in manifest['assets'] if asset.get('url') == self.good]
        require(len(assets) == 1 and assets[0].get('sha256') == reference['sha256'] and assets[0].get('detectedMime') == reference['detectedMime'] and
                assets[0].get('bytes') == reference['bytes'] and assets[0].get('authorizationSent') is False, 'The original GOOD registration changed')

    def validate_receipt(self):
        value = self.receipt
        exact(value, {'formatVersion', 'fixture', 'status', 'serverSourceFile', 'sourceSha256', 'specFile', 'specSha256',
                      'publicOrigin', 'paths', 'urls', 'png', 'nativeLoadVerified'}, 'The media receipt fields changed')
        require(value.get('formatVersion') == 1 and value.get('fixture') == 'ui-viewer-test-media' and
                value.get('status') == 'public_https_bound_not_native_verified' and value.get('nativeLoadVerified') is False and
                value.get('serverSourceFile') == 'scripts/ui-viewer-test-media.mjs' and value.get('sourceSha256') == sha(SERVER),
                'A real Root-bound public HTTPS media receipt is required before run')
        self.media_spec_path, self.media_spec = private_json(ROOT / value['specFile'])
        spec = self.media_spec
        exact(spec, {'formatVersion', 'fixture', 'status', 'createdAt', 'sourceSha256', 'mediaPort', 'controlPort', 'nonce', 'controlKey', 'paths', 'png'}, 'The synthetic server spec fields changed')
        require(sha(self.media_spec_path) == value.get('specSha256') and spec.get('formatVersion') == 1 and spec.get('fixture') == 'ui-viewer-test-media' and
                spec.get('status') == 'prepared_offline' and spec.get('sourceSha256') == value['sourceSha256'] and
                re.fullmatch(r'[a-f0-9]{32}', spec.get('nonce', '')) and re.fullmatch(HASH, spec.get('controlKey', '')) and
                all(type(spec.get(key)) is int and 1024 <= spec[key] <= 65535 for key in ('mediaPort', 'controlPort')) and
                spec['mediaPort'] != spec['controlPort'], 'The exact owned server spec changed')
        expected_paths = {'health': '/health', 'png': '/viewer-' + spec['nonce'] + '/small.png', 'missing': '/viewer-' + spec['nonce'] + '/missing.png'}
        origin = value.get('publicOrigin', '')
        parsed = urlsplit(origin)
        host = parsed.hostname or ''
        require(parsed.scheme == 'https' and parsed.netloc == host and not parsed.path and not parsed.query and not parsed.fragment and
                not parsed.username and not parsed.password and len(host.split('.')) >= 2 and not host.endswith('.') and
                all(re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', label) for label in host.split('.')) and
                not host.split('.')[-1].isdigit() and not re.search(r'(^|\.)(localhost|local|localdomain|internal|lan|home|test|invalid|onion)$', host) and
                host != 'home.arpa' and not host.endswith('.home.arpa') and value.get('paths') == spec['paths'] == expected_paths,
                'The media origin must be exact public system-TLS HTTPS with its registered literal paths')
        require(value.get('urls') == {'small': origin + expected_paths['png'], 'missing': origin + expected_paths['missing']} and
                self.spec['appendedUrls'] == [value['urls']['missing'], value['urls']['small']], 'The appended public sources changed')
        exact(value['png'], {'file', 'sha256', 'bytes', 'width', 'height', 'mime'}, 'Synthetic PNG fields changed')
        png = value['png']
        self.png_path = ENTRY.guarded(Path(png['file']), PRIVATE, True)
        data = self.png_path.read_bytes()
        require(png == spec['png'] and png.get('width') == 64 and png.get('height') == 40 and png.get('mime') == 'image/png' and
                png.get('bytes') == len(data) and 24 < len(data) <= 5 * 1024 * 1024 and png.get('sha256') == sha(self.png_path) and
                data[:8] == b'\x89PNG\r\n\x1a\n' and data[12:16] == b'IHDR' and int.from_bytes(data[16:20], 'big') == 64 and
                int.from_bytes(data[20:24], 'big') == 40, 'The exact synthetic64x40 PNG bytes changed')
        require(self.spec['syntheticMedia'] == {'receiptFile': str(self.receipt_path.relative_to(ROOT)),
                'receiptSha256': self.args.expected_media_receipt_sha, 'sourceSha256': value['sourceSha256'], 'specSha256': value['specSha256'],
                'smallUrl': value['urls']['small'], 'missingUrl': value['urls']['missing'], 'pngSha256': png['sha256'],
                'pngBytes': png['bytes'], 'width': 64, 'height': 40} and self.imported.get('syntheticPngSha256') == png['sha256'],
                'The mixed derivation and server receipt disagree')

    def registry_bytes(self, state):
        return canonical({key: state[key] for key in ('uiContent', 'uiImageFailures', 'uiViewerMedia', 'gameplay')})

    def media_fixed(self, state):
        keys = ('formatVersion', 'fixture', 'pid', 'uid', 'processBirth', 'processBirthNonce', 'sourceFile', 'sourceSha256',
                'specFile', 'specSha256', 'mediaPort', 'controlPort', 'controlKey', 'nonce', 'paths', 'png')
        require(state.get('status') == 'listening' and state.get('formatVersion') == 1 and state.get('fixture') == 'ui-viewer-test-media' and
                state.get('uid') == os.getuid() and type(state.get('pid')) is int and state['pid'] > 0 and
                state.get('sourceFile') == str(SERVER) and state.get('sourceSha256') == self.receipt['sourceSha256'] and
                state.get('specFile') == str(self.media_spec_path) and state.get('specSha256') == self.receipt['specSha256'] and
                all(state.get(key) == self.media_spec[key] for key in ('mediaPort', 'controlPort', 'controlKey', 'nonce', 'paths', 'png')) and
                isinstance(state.get('processBirth'), str) and state['processBirth'] and re.fullmatch(r'[a-f0-9-]{36}', state.get('processBirthNonce', '')),
                'The live owned media runtime does not bind the exact spec/source')
        return canonical({key: state[key] for key in keys})

    def media_owner(self, state):
        pid = state['pid']
        require(FRAME.command('ps', '-p', pid, '-o', 'uid=').strip() == str(os.getuid()), 'The media server belongs to another user')
        argv = shlex.split(FRAME.command('ps', '-p', pid, '-o', 'args=').strip())
        require(len(argv) == 9 and Path(argv[0]).name == 'node' and (ROOT / argv[1]).resolve() == SERVER and argv[2] == 'start' and
                argv[3] == '--spec' and (ROOT / argv[4]).resolve() == self.media_spec_path and argv[5] == '--expected-spec-sha' and
                argv[6] == self.receipt['specSha256'] and argv[7] == '--state' and (ROOT / argv[8]).resolve() == self.media_state_path,
                'The media process argv does not identify the exact reviewed spec/runtime')
        cwd = [line[1:] for line in FRAME.command('/usr/sbin/lsof', '-a', '-p', pid, '-d', 'cwd', '-Fn').splitlines() if line.startswith('n')]
        require(cwd == [str(ROOT)], 'The media server working directory changed')
        for port in (state['mediaPort'], state['controlPort']):
            rows = FRAME.command('/usr/sbin/lsof', '-nP', '-iTCP:' + str(port), '-sTCP:LISTEN', '-Fp')
            require({int(line[1:]) for line in rows.splitlines() if re.fullmatch(r'p[1-9][0-9]*', line)} == {pid},
                    'The media server is not the sole listener on both owned ports')
        return FRAME.command('ps', '-p', pid, '-o', 'lstart=').strip()

    def immutable(self):
        current = ENTRY.read_state()
        require(ENTRY.EntryMain.identity(current) == self.environment and self.registry_bytes(current) == self.registry_identity and
                all(sha(path) == self.binding[key] for key, path in self.bound.items()) and self.ownership() == self.births,
                'The exact environment/fixture/source/runtime ownership changed')
        _, media_state = private_json(self.media_state_path)
        require(self.media_fixed(media_state) == self.media_identity and self.media_owner(media_state) == self.media_birth,
                'The owned media runtime/process identity changed')

    def media(self, route='/requests', body=None):
        self.immutable()
        require(route == '/requests' and body is None or route == '/gateOnce' and body == {} or
                route == '/release' and body == {'gateId': self.gate_id} and self.gate_id is not None,
                'Synthetic media control escaped the exact own-gate allowlist')
        request = urllib.request.Request('http://127.0.0.1:' + str(self.media_spec['controlPort']) + route,
            data=None if body is None else canonical(body).encode(), method='GET' if body is None else 'POST',
            headers={'Authorization': self.media_spec['controlKey'], 'Accept': 'application/json',
                     **({'Content-Type': 'application/json'} if body is not None else {})})
        try:
            with self.control_opener.open(request, timeout=5) as response:
                require(response.status == 200, 'The exact synthetic media control did not return200')
                value = json.load(response)
                require(isinstance(value, dict), 'The synthetic media response is not an object')
                return value
        except Exception:
            raise SafeFailure('The exact owned synthetic media control failed; values omitted') from None

    def media_rows(self):
        value = self.media()
        exact(value, {'requests', 'gates', 'armed', 'held'}, 'Synthetic media diagnostics changed')
        rows = value['requests']
        require(isinstance(rows, list) and len(rows) < 256 and all(isinstance(row, dict) for row in rows) and
                [row.get('id') for row in rows] == list(range(1, len(rows) + 1)) and isinstance(value['gates'], list) and
                type(value['armed']) is bool and type(value['held']) is bool, 'The bounded sequential media ledger is invalid')
        for row in rows:
            if row.get('kind') in ('png', 'missing'):
                require(row.get('AuthPresent') is False and row.get('CookiePresent') is False and row.get('RefererMatchesWeb') is True and
                        type(row.get('requestError')) is bool and type(row.get('streamError')) is bool,
                        'A Native media request had credentials, wrong Referer or absent stream-error facts')
        self.last_media = copy.deepcopy(value)
        return value

    def poll_media(self, predicate, label, timeout=8):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            value = self.media_rows()
            if predicate(value):
                return value
            time.sleep(.12)
        raise SafeFailure('Synthetic media expectation timed out: ' + label)

    def facts(self):
        value = FRAME.FrameSample.facts(self)
        require(value.get('playerTotalXp') == 0 and value.get('assignmentStatus') in ('assigned', 'active') and
                value.get('completedAtPresent') is False, 'The media-only actor has settlement/completion facts')
        active = value['assignmentStatus'] == 'active'
        require(value.get('startReceiptCount') == value.get('progressRows') == (1 if active else 0) and value.get('startedAtPresent') is active,
                'The media case entry/progress receipts are inconsistent')
        return value

    def question(self):
        detail = self.dto['assignment']
        levels, refs, mapping = detail.get('levels', []), self.spec['sourceRefs'], self.imported['sourceTargetMap']
        require(detail.get('status') == 'active' and detail.get('completedLevels') == 0 and detail.get('totalLevels') == 1 and
                detail.get('currentIndex') == 0 and len(levels) == 1 and isinstance(levels[0].get('question'), dict),
                'The mixed gallery requires the one own uncompleted active question')
        question = copy.deepcopy(levels[0]['question'])
        require(question.pop('id', None) == mapping['game_questions'].get(refs['questionId']) and
                detail.get('session') == mapping['game_sessions'].get(refs['sessionId']) == self.case['assignments']['ready']['sessionId'] and
                levels[0].get('id') == mapping['game_session_levels'].get(refs['sessionLevelId']) and
                question.get('content', [{}])[0].get('imageUrl') == self.good and
                question['content'][0].get('imageUrls') == self.spec['appendedUrls'] and
                paths_of(question, self.good) == [('content', 0, 'imageUrl')] and
                paths_of(question, self.spec['appendedUrls'][0]) == [('content', 0, 'imageUrls', 0)] and
                paths_of(question, self.spec['appendedUrls'][1]) == [('content', 0, 'imageUrls', 1)],
                'The active content/mapping is not the exact GOOD/missing/small group')
        question['content'][0]['imageUrls'] = []
        require(question == self.expected_question and detail.get('presentation') == self.base_case['sessionPresentation'] and
                levels[0].get('presentationOverride') == self.base_case['levelPresentationOverride'] and
                levels[0].get('position') == self.source_level['position'] and levels[0].get('xp') == self.source_level['xp'] and
                levels[0].get('autoNext') == (self.source_level['autoNext'] in (True, 1)),
                'Removing only the two appended URLs must recover the complete original question/presentation')
        return levels[0]['question'], self.base_case['expectedEffectivePresentation'].get('hideTitle', False)

    def pointer(self, node_id, label):
        self.ui.seek(node_id)
        raw, _ = self.ui.raw_app(label)
        row = FRAME.own(raw, node_id)
        box = UI.rect(row['bounds'])
        root = UI.rect(FRAME.own(raw, 'image-viewer')['bounds']) if any(item.get('id') == 'image-viewer' for item in raw) else self.ui.viewport(node_id)
        require(row.get('type') == 'Button' and VIEWER.enabled(row) and row.get('clickable') in (True, 'true') and
                row.get('visible') in (True, 'true') and box[2] > box[0] and box[3] > box[1] and
                root[0] <= box[0] < box[2] <= root[2] and root[1] <= box[1] < box[3] <= root[3],
                'The exact native action is not uniquely exposed, enabled and wholly inside its current viewport')
        return [round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2)]

    def click(self, node_id, label):
        self.click_point(self.pointer(node_id, label))

    def click_point(self, point):
        # A single measured official injection only. Never补点 or retry a write.
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', *point)

    def draft(self, label, initial=False):
        raw, evidence = self.ui.raw_app('draft-' + label)
        row = FRAME.own(raw, 'gameplay-answer-input')
        identity = {key: row.get(key) for key in ('accessibilityId', 'hashcode')}
        require(row.get('text') == DRAFT and all(type(value) in (str, int) and bool(value) for value in identity.values()),
                'The actual DRAFT/input identity is absent')
        if initial:
            self.input_identity = identity
        else:
            require(identity == self.input_identity, 'Viewing/retrying replaced the actual answer-input instance')
        return evidence['sha256']

    def viewer(self, index, state, label, wait=True):
        if wait:
            self.ui.wait(lambda ui: ui.find('image-viewer-' + state) is not None, 'actual viewer ' + state, timeout=40)
        raw, evidence = self.ui.raw_app(label)
        require(FRAME.own(raw, 'image-viewer-index').get('text') == str(index + 1) + ' / 3' and
                VIEWER.enabled(FRAME.own(raw, 'image-viewer-previous')) == (index > 0) and
                VIEWER.enabled(FRAME.own(raw, 'image-viewer-next')) == (index < 2) and
                VIEWER.pose(FRAME.own(raw, 'image-viewer-stage')) == {'percent': 100, 'xVp': 0.0, 'yVp': 0.0} and
                FRAME.own(raw, 'image-viewer-percent').get('text') == '100%', 'The actual gallery index/disabled boundaries/baseline pose differ')
        for other in {'pixels', 'error', 'loading'} - {state}:
            require(not any(row.get('id') == 'image-viewer-' + other for row in raw), 'Conflicting viewer load states are visible')
        box = UI.rect(FRAME.own(raw, 'image-viewer-' + state)['bounds'])
        stage = UI.rect(FRAME.own(raw, 'image-viewer-stage')['bounds'])
        if state == 'pixels':
            require(stage[0] <= box[0] < box[2] <= stage[2] and stage[1] <= box[1] < box[3] <= stage[3], 'Ready pixels escape the actual stage')
        return {'rawSha256': evidence['sha256'], 'index': index + 1, 'state': state,
                'pixelsOrStateBoundsPx': box, 'stageBoundsPx': stage}

    def no_business(self):
        require(self.ledger() == self.overlay_ledger, 'Opening/switching/retrying/closing an image caused business HTTP traffic')
        self.facts()

    def media_delta(self, before, kind, count=1):
        def ready(value):
            rows = value['requests'][before:]
            require(len(rows) <= count and all(row.get('kind') == kind for row in rows), 'Unexpected concurrent synthetic-media traffic occurred')
            return len(rows) == count and all(row.get('responseFinished') is True for row in rows)
        value = self.poll_media(ready, 'exclusive viewer media response')
        rows = value['requests'][before:]
        status = 404 if kind == 'missing' else 200
        require(all(row.get('responseStatus') == status and row.get('gateId') == '' and row.get('requestError') is False and
                    row.get('streamError') is False for row in rows), 'The exclusive viewer response status/gate/errors differ')
        return len(value['requests'])

    def close(self, label):
        self.click('image-viewer-close', label + '-ready')
        self.ui.wait(lambda ui: ui.find('image-viewer') is None and ui.find('gameplay-question-card') is not None and
                     ui.find('current-tab') is None, 'close only the image cover')

    def main(self):
        self.stage = 'bound-public-health-and-own-login'
        self.immutable()
        request = urllib.request.Request(self.receipt['publicOrigin'] + self.receipt['paths']['health'],
                                         headers={'Accept': 'application/json'}, method='GET')
        try:
            with self.public_opener.open(request, timeout=10) as response:
                require(response.status == 200 and json.load(response) == {'status': 'healthy_synthetic_fixture'}, 'The bound public HTTPS health differs')
        except Exception:
            raise SafeFailure('The Root-bound public system-TLS health is unavailable; no image was fetched') from None
        baseline_media = self.media_rows()
        require(not baseline_media['gates'] and not baseline_media['armed'] and not baseline_media['held'] and
                all(row.get('kind') == 'health' for row in baseline_media['requests']),
                'The new dedicated media fixture already has image traffic or a gate')
        auth = self.request(False, FRAME.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str) and auth['token'],
                'Host authentication did not identify the explicit ordinary mixed actor')
        self.token = auth['token']
        before = self.snapshot()
        facts = self.facts()
        self.expected_starts = 1 if before['assignment'].get('status') == 'assigned' else 0
        require(before['assignment'].get('status') in ('assigned', 'active') and
                facts.get('startReceiptCount') == (0 if self.expected_starts else 1) and len(before['assignment'].get('levels', [])) == 1 and
                (before['assignment']['levels'][0].get('question') is None if self.expected_starts else
                 isinstance(before['assignment']['levels'][0].get('question'), dict)), 'The protected-question/start boundary is inconsistent')
        self.baseline = self.ledger()
        self.stage = 'native-direct-login-and-optional-entry'
        self.device_started = True
        self.ui.launch(cold=True)
        self.ui.wait(lambda ui: ui.find('account') is not None, 'cold empty isolated login')
        require(self.ui.input_empty('account') and self.ui.input_empty('password') and self.ui.has_text('隔离测试环境'), 'The isolated login is not empty')
        self.ui.fill('account', self.case['account'])
        self.ui.fill('password', self.case['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('old-password') is None, 'ordinary direct login')
        self.ui.tap('assignment-' + self.assignment_id)
        if self.expected_starts:
            self.ui.wait(lambda ui: ui.find('start-assignment') is not None, 'explicit assigned detail')
            self.ui.tap('start-assignment')
        self.ui.wait(lambda ui: ui.find('gameplay-question-card') is not None and ui.find('gameplay-loading') is None,
                     'one active mixed-gallery question', timeout=40)
        self.dto = self.snapshot()
        self.question()
        self.check(True, 'The five-actor bound ordinary fixture enters its exact derived one-question gallery')
        self.stage = 'native-body-preload-and-draft'
        for suffix, state in (('0', 'pixels'), ('1', 'error'), ('2', 'pixels')):
            slot = 'question-images-0-' + suffix
            self.ui.seek(slot)
            self.ui.wait(lambda ui, key=slot, value=state: ui.find(key + '-' + value) is not None and ui.find(key + '-loading') is None,
                         'actual mixed body image ' + state, timeout=40)
        body = self.media_rows()
        body_rows = body['requests'][len(baseline_media['requests']):]
        require(len(body_rows) == 2 and {row.get('kind') for row in body_rows} == {'missing', 'png'} and
                all(row.get('responseFinished') is True and row.get('responseStatus') == (200 if row['kind'] == 'png' else 404) and
                    row.get('requestError') is False and row.get('streamError') is False for row in body_rows) and
                any(row.get('kind') == 'png' and row.get('bytesSha256') == self.receipt['png']['sha256'] and row.get('width') == 64 and row.get('height') == 40 for row in body_rows),
                'The actual body preload does not have exactly one known PNG200 and one missing404')
        self.ui.fill('gameplay-answer-input', DRAFT)
        self.draft('initial', True)
        self.overlay_ledger = self.ledger()
        self.check(True, 'Native body preload completed GOOD/known64x40 PNG and an exclusive credential-free404; real DRAFT is retained')
        self.stage = 'viewer-missing-retry-and-small-ready'
        self.click('question-images-0-0-open', 'body-good-open')
        self.good_geometry = self.viewer(0, 'pixels', 'good-viewer')
        require(any(abs(actual / self.ui.density - expected) > 4 for actual, expected in
                    ((self.good_geometry['pixelsOrStateBoundsPx'][2] - self.good_geometry['pixelsOrStateBoundsPx'][0], 64),
                     (self.good_geometry['pixelsOrStateBoundsPx'][3] - self.good_geometry['pixelsOrStateBoundsPx'][1], 40))),
                'GOOD geometry cannot distinguish a stale synthetic64x40 image')
        before_media = len(self.media_rows()['requests'])
        self.click('image-viewer-next', 'next-missing')
        self.states.append(self.viewer(1, 'error', 'missing-viewer'))
        next_media = self.media_delta(before_media, 'missing')
        self.ui.private_shot('viewer-missing-404')
        self.draft('missing')
        self.no_business()
        self.click('image-viewer-retry', 'retry-missing')
        self.media_delta(next_media, 'missing')
        self.states.append(self.viewer(1, 'error', 'missing-retry-viewer'))
        self.draft('retried')
        self.no_business()
        self.check(True, 'Exclusive viewer404 and one explicit retry404 preserve the same real input/DRAFT and cause zero business HTTP traffic')
        before_media = len(self.media_rows()['requests'])
        self.click('image-viewer-next', 'next-small')
        state = self.viewer(2, 'pixels', 'small-viewer')
        self.media_delta(before_media, 'png')
        box = state['pixelsOrStateBoundsPx']
        require(abs((box[2] - box[0]) / self.ui.density - 64) <= 2 / self.ui.density and
                abs((box[3] - box[1]) / self.ui.density - 40) <= 2 / self.ui.density,
                'The actual known64x40 image was upscaled at100percent or has wrong geometry')
        self.states.append(state)
        self.ui.private_shot('viewer-small-64x40')
        self.click('image-viewer-reset', 'small-reset')
        self.viewer(2, 'pixels', 'small-reset-state')
        self.close('small-close')
        self.draft('small-closed')
        self.no_business()
        self.check(True, 'Known64x40 viewer pixels contain without upscale, reset at baseline and close without leaving gameplay')
        self.stage = 'held-native-image-close-reopen'
        self.good_point = self.pointer('question-images-0-0-open', 'gate-good-open')
        self.click_point(self.good_point)
        self.viewer(0, 'pixels', 'gate-good-ready')
        next_point = self.pointer('image-viewer-next', 'gate-next-ready')
        close_point = self.pointer('image-viewer-close', 'gate-close-ready')
        before_gate_rows = len(self.media_rows()['requests'])
        # A timed-out control response may still have armed a gate. Until its
        # exact returned ID/held request is known, cleanup cannot claim disarm.
        self.gate_arm_attempted = True
        self.cleanup['armedGateNeutralised'] = False
        self.cleanup['heldGateReleased'] = False
        arm = self.media('/gateOnce', {})
        require(set(arm) == {'status', 'gateId'} and arm.get('status') == 'armed' and
                re.fullmatch(r'[a-f0-9-]{36}', arm.get('gateId', '')), 'The exact new media gate was not armed')
        self.gate_id = arm['gateId']
        self.click_point(next_point)
        self.ui.wait(lambda ui: ui.find('image-viewer-error') is not None and ui.find('image-viewer-index').get('text') == '2 / 3',
                     'missing before held small')
        self.click_point(next_point)
        held = self.poll_media(lambda value: value['held'], 'actual native PNG held before bytes', timeout=4)
        gates = [gate for gate in held['gates'] if gate.get('id') == self.gate_id]
        delta = held['requests'][before_gate_rows:]
        require(len(gates) == 1 and gates[0].get('released') is False and len(delta) == 2 and
                delta[0].get('kind') == 'missing' and delta[0].get('responseStatus') == 404 and delta[0].get('responseFinished') is True and
                delta[1].get('kind') == 'png' and delta[1].get('gateId') == self.gate_id and delta[1].get('responseAttempted') is False and
                gates[0].get('requestId') == delta[1]['id'], 'The exact gate does not hold only the new viewer PNG request')
        self.cleanup['armedGateNeutralised'] = True
        self.ui.capture()
        require(self.ui.find('image-viewer-loading') is not None and self.ui.find('image-viewer-pixels') is None and
                self.ui.find('image-viewer-index').get('text') == '3 / 3', 'The held network request is not actual viewer loading without pixels')
        self.click_point(close_point)
        self.ui.wait(lambda ui: ui.find('image-viewer') is None and ui.find('gameplay-question-card') is not None,
                     'close while actual PNG bytes are held', timeout=3)
        self.click_point(self.good_point)
        self.ui.wait(lambda ui: ui.find('image-viewer') is not None and ui.find('image-viewer-index').get('text') == '1 / 3',
                     'new GOOD cover before old network release', timeout=3)
        before_release = self.media_rows()
        gate = next(gate for gate in before_release['gates'] if gate['id'] == self.gate_id)
        require(before_release['held'] is True and gate.get('released') is False and gate.get('releaseReason') == '',
                'The12second gate released before close/reopen was observed; this timing is incomplete')
        released = self.media('/release', {'gateId': self.gate_id})
        require(released == {'status': 'released', 'gateId': self.gate_id}, 'The exact old held gate was not explicitly released')
        self.cleanup['heldGateReleased'] = True
        self.states.append(self.viewer(0, 'pixels', 'new-good-after-release'))
        for _ in range(3):
            time.sleep(.5)
            observed = self.viewer(0, 'pixels', 'late-old-not-restored-' + str(_), wait=False)
            require(all(abs(a - b) <= 2 for a, b in zip(observed['pixelsOrStateBoundsPx'], self.good_geometry['pixelsOrStateBoundsPx'])),
                    'The old held synthetic image restored pixels into the new GOOD viewer session')
        final_media = self.media_rows()
        gate = next(gate for gate in final_media['gates'] if gate['id'] == self.gate_id)
        request = next(row for row in final_media['requests'] if row['id'] == gate['requestId'])
        require(gate.get('releaseReason') == 'explicit_release' and gate.get('released') is True and
                request.get('downstreamClosedBeforeRelease') is True and request.get('responseAttempted') is False,
                'The server did not observe downstream cancellation before explicit release; no cancellation pass is claimed')
        self.close('new-good-close')
        self.draft('gate-closed')
        self.no_business()
        self.check(True, 'A real held Native network request cancels before release; the new GOOD cover retains its own index/pixels and actual DRAFT')
        self.ui.private_shot('mixed-viewer-final-gameplay')
        self.verify_ledger()

    def logout(self):
        for key in ('loggedOut', 'loginInputsEmpty', 'privateGameplayAbsent', 'viewerAndDraftAbsent'):
            self.cleanup[key] = False
        self.ui.capture()
        if self.ui.find('image-viewer') is not None:
            self.close('cleanup-cover')
        self.ui.hide_keyboard()
        FRAME.FrameSample.logout(self)
        raw, _ = self.ui.raw_app('fresh-empty-logout')
        self.cleanup['viewerAndDraftAbsent'] = not any(row.get('id', '').startswith(('image-viewer', 'question-images-')) or
            row.get('id') == 'gameplay-answer-input' or row.get('text') == DRAFT for row in raw)
        require(self.cleanup['viewerAndDraftAbsent'], 'Logout retained private viewer/body pixels or an input/draft')

    def cleanup_gate(self):
        if self.gate_id is None:
            if self.gate_arm_attempted:
                self.cleanup['armedGateNeutralised'] = False
                self.cleanup['heldGateReleased'] = False
            return
        value = self.media_rows()
        gates = [gate for gate in value['gates'] if gate.get('id') == self.gate_id]
        require(len(gates) == 1, 'The owned gate disappeared during cleanup')
        gate = gates[0]
        if gate.get('requestId') is None:
            # There is no reviewed disarm endpoint. Never fetch a PNG to consume
            # the gate or pretend release works for an armed-only gate.
            self.cleanup['armedGateNeutralised'] = False
            self.cleanup['heldGateReleased'] = False
            return
        self.cleanup['armedGateNeutralised'] = True
        if gate.get('released') is False:
            self.media('/release', {'gateId': self.gate_id})
            value = self.media_rows()
            gate = next(row for row in value['gates'] if row['id'] == self.gate_id)
        self.cleanup['heldGateReleased'] = gate.get('released') is True

    def execute(self):
        try:
            self.main()
        except Exception as error:
            reason = str(error)
            for literal in self.private_literals():
                if literal:
                    reason = reason.replace(literal, '[private omitted]')
            FRAME.write_private(self.directory / 'failure.json', {'stage': self.stage, 'type': type(error).__name__, 'reason': reason}, self.credentials())
            self.failure = 'The dedicated mixed-gallery sample stopped; diagnostics remain private and incomplete'
        finally:
            try:
                self.immutable()
                self.cleanup_gate()
            except Exception:
                self.cleanup['heldGateReleased'] = False
                self.failure = self.failure or 'The exact owned media gate cleanup could not be confirmed'
            try:
                self.immutable()
                if self.device_started:
                    self.logout()
                if hasattr(self, 'baseline'):
                    self.verify_ledger()
            except Exception:
                self.failure = self.failure or 'Fresh logout/zero-write observations are incomplete'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not all(self.cleanup.values()):
                self.failure = self.failure or 'Gate/logout/zero-write cleanup remains incomplete; Root must inspect the owned fixture'
        evidence = {}
        for key, data in (('mediaLedger', getattr(self, 'last_media', None)), ('businessLedger', getattr(self, 'final_ledger', None))):
            if data is not None:
                evidence[key] = FRAME.write_private(self.directory / (key + '.json'), data, self.credentials())
        report = {'status': 'incomplete' if self.failure else 'passed', 'stage': self.stage, 'checksPassed': len(self.checks),
            'checks': self.checks, 'states': self.states, 'cleanup': self.cleanup, 'hapSha256': self.hap_sha,
            'bindingSha256': self.binding, 'expectedFixtureSha256': self.args.expected_fixture_sha,
            'expectedDerivationSha256': self.args.expected_derivation_sha, 'expectedMediaReceiptSha256': self.args.expected_media_receipt_sha,
            'privateEvidence': evidence, 'privateRawEvidence': self.ui.raw_evidence, 'privateScreenshots': self.ui.private_screenshots,
            'scope': 'Native synthetic mixed-gallery viewer404/retry/64x40 and network-pending close/reopen only',
            'latePixelMapReleaseClaimed': False, 'fullVisualParityClaimed': False, 'tunnelProcessOwnershipVerifiedByHelper': False,
            'tunnelOwnershipBoundary': 'Root external exact-process receipt; helper only verifies bound public HTTPS health',
            'productionOrFixedPreviewTouched': False, 'serviceStopOrGlobalNetworkFaultPerformed': False,
            'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        if self.failure:
            report['failure'] = self.failure
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        require(not any(literal and literal in encoded for literal in self.private_literals()) and not re.search(r'https?://', encoded),
                'A private URL/actor/credential literal would enter the public report')
        FRAME.fresh(self.report, OUT)
        self.report.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        descriptor = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(encoded)
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks), 'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 1 if self.failure else 0

    def credentials(self):
        return self.case['newPassword'], self.state['controlToken'], self.media_spec['controlKey'], self.token

    def private_literals(self):
        return [*self.credentials(), self.case_id, self.case['account'], self.case['playerId'], self.assignment_id,
                self.case['assignments']['ready']['sessionId'], self.good, self.receipt['publicOrigin'], *self.spec['appendedUrls']]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command')
    run = commands.add_parser('run', help='Root-only explicit future run against a bound disposable five-actor environment')
    for name in ('runtime', 'case-ref', 'output', 'private-dir', 'derivation-file', 'media-receipt', 'media-state'):
        run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-hap', 'expected-fixture-sha', 'expected-derivation-sha', 'expected-media-receipt-sha',
                 'expected-viewer-sha', 'expected-gameplay-page-sha', 'expected-window-sha', 'expected-surfaces-sha'):
        run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if args.command is None:
        parser.print_help()
        return 0
    try:
        return MixedViewer(args).execute()
    except Exception:
        result = {'status': 'incomplete', 'stage': 'prerequisites', 'checksPassed': 0,
                  'reason': 'Exact fresh owned fixture/public receipt/source/runtime binding unavailable; values omitted',
                  'nativeOrNetworkAcceptanceClaimed': False,
                  'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        try:
            report = FRAME.fresh(args.output, OUT)
            report.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
            descriptor = os.open(report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
            with os.fdopen(descriptor, 'w') as stream:
                stream.write(json.dumps(result, indent=2) + '\n')
            result['report'] = str(report.relative_to(ROOT))
        except Exception:
            result['freshReportWritten'] = False
        print(json.dumps(result))
        return 1


if __name__ == '__main__':
    sys.exit(main())

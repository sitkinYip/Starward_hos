#!/usr/bin/env python3
"""Narrow isolated native choice/thumbnail sample; default/help/plan is inert.

Only explicit run reads private guards and uses the phone. Host auth/read and
one optional native start are allowed; no answer, completion, fault, reset,
profile/password, service operation or Host image download is implemented.
Current DTOs are saved for a later independent same-data Web replay.
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

FRAME_SHA = 'f54881ab0cb72bf3478295639eb2c1728bc88a88c96782b4bde3bacc37ea945e'
LAYOUT_SHA = '05a13a2f2084048ec5fbf65b7a31ee1df36b121dfc460880f05919923ea597fd'
FIXTURE_SHA = '1ad7a59cc1f13e6dd7ec5550c8f5ab4a5906b90f9a9b56ac948143a4995e8745'
MANIFEST_SHA = 'f7f774b1e3f140db568e415502c7852457f0dcb7dc829f96a0475cc986d958d7'
FROZEN_WEB = '4b7d1a0a00051ac630e459b0fd6c074f821d7455'
OUT = ROOT / 'artifacts/validation/ui-choice-options-20261105'
SOURCE_PATHS = {
    'choiceUI': ROOT / 'entry/src/main/ets/ui/StarwardChoiceOption.ets',
    'gameplayPage': ROOT / 'entry/src/main/ets/features/GameplayPage.ets',
    'viewer': ROOT / 'entry/src/main/ets/ui/StarwardImageViewer.ets',
    'imageLoader': ROOT / 'entry/src/main/ets/platform/QuestionImageLoader.ets',
    'imageIO': ROOT / 'entry/src/main/ets/platform/QuestionImageIO.ets',
    'refreshWrapper': ROOT / 'entry/src/main/ets/ui/StarwardRefresh.ets',
    'viewModel': ROOT / 'entry/src/main/ets/features/GameplayViewModel.ets',
    'lightColors': ROOT / 'entry/src/main/resources/base/element/color.json',
    'darkColors': ROOT / 'entry/src/main/resources/dark/element/color.json',
}
WEB_PATHS = ('src/features/media/ChoiceOptions.tsx', 'src/features/quest/QuestAnswerForm.tsx',
             'src/styles/features/quest.css', 'src/styles/effects/quest-lighting.css',
             'src/styles/effects/answer-feedback.css', 'src/styles/foundation/base.css')
PLAN = {'scope': 'Own real-content case1 four choice options and three option thumbnails',
        'themes': ['light', 'dark'], 'states': ['initial-four-options', 'A-B-A-mutual-selection',
        'B-selected-open-A-singleton', 'close-preserves-four-radio-instances',
        'bounded-scroll-to-top-and-first-official-light-Refresh-preserves-selection-and-image-instances'],
        'writes': 'Optional exact one native start; no answer or settlement',
        'excluded': ['completed/locked/cooldown UI', 'image failures or cancellation',
                     'multi-pointer viewer gestures', 'whole-page parity', 'video/BGM']}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(name, relative, expected):
    path = ROOT / relative
    if sha(path) != expected:
        raise RuntimeError('A frozen local choice helper changed')
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec); spec.loader.exec_module(value)
    return value


def boolean(row, key):
    value = row.get(key)
    if type(value) is bool:
        return value
    if type(value) is str and value in ('true', 'false'):
        return value == 'true'
    raise RuntimeError('The actual native control Boolean field is absent')


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False, allow_nan=False)


def create(args):
    frame = load('choice_native_frame', 'scripts/device-question-frame.py', FRAME_SHA)
    layout = load('choice_native_top', 'scripts/device-gameplay-layout.py', LAYOUT_SHA)
    require, ui = frame.require, frame.UI

    class Choice(frame.FrameSample):
        def __init__(self):
            frame.fresh(args.output, OUT)
            super().__init__(args)
            require(args.expected_fixture_sha == FIXTURE_SHA and
                    self.case['sourceContent']['sourceCaseIndex'] == 1 and
                    self.case['fixtureLevelKinds'] == ['choice'], 'Only own complete real-content choice case1 is supported')
            web = ROOT.parent / 'questions-web'
            require(frame.command('git', '-C', web, 'rev-parse', 'HEAD').strip() == FROZEN_WEB and
                    not frame.command('git', '-C', web, 'status', '--porcelain').strip(),
                    'The reviewed frozen Web checkout is not clean at the exact commit')
            self.guard_registry()
            self.registry_identity = canonical({key: self.state[key] for key in ('uiContent', 'uiImageFailures', 'gameplay')})
            manifest = frame.ENTRY.guarded(args.images_manifest, frame.PRIVATE, True)
            require(args.expected_images_manifest_sha == MANIFEST_SHA == sha(manifest), 'The eight original image manifest changed')
            data = json.loads(manifest.read_text())
            require(data.get('status') == 'reference_image_bytes_captured' and data.get('fixtureSha256') == FIXTURE_SHA and
                    data.get('referer') == 'https://sitkin.top/' and data.get('nativeLoadVerified') is False and
                    len(data.get('assets', [])) == 8, 'The exact original eight-image registration is required')
            self.assets = {}
            for item in data['assets']:
                require(item.get('authorizationSent') is False and item.get('detectedMime') in ('image/png', 'image/jpeg') and
                        re.fullmatch(r'[a-f0-9]{64}', item.get('sha256', '')) and isinstance(item.get('url'), str) and
                        item['url'] not in self.assets, 'An original image registration is invalid')
                self.assets[item['url']] = item['sha256']
            for name, expected in (('choiceUI', args.expected_choice_ui_sha), ('gameplayPage', args.expected_gameplay_page_sha)):
                require(re.fullmatch(r'[a-f0-9]{64}', expected or '') and sha(SOURCE_PATHS[name]) == expected,
                        'An explicitly reviewed choice/Page source changed')
            for name, path in {**SOURCE_PATHS, 'choiceDriver': Path(__file__),
                               'imageManifest': manifest, 'quantitativeTopHelper': ROOT / 'scripts/device-gameplay-layout.py'}.items():
                self.bound[name], self.binding[name] = path, sha(path)
            for index, relative in enumerate(WEB_PATHS):
                key, path = 'frozenWebSource' + str(index), web / relative
                self.bound[key], self.binding[key] = path, sha(path)
            self.draft_checks, self.option_specs = {}, []
            self.initial_radio_instances = None
            self.selection_sequence = 0

        def guard_registry(self):
            originals = self.state.get('uiContent', {}).get('imports', {})
            failures = self.state.get('uiImageFailures', {})
            imports = failures.get('imports', {})
            require(len(originals) == 1 and self.import_id in originals and failures.get('schema') == 1 and len(imports) == 1,
                    'The exact original plus separate body-failure registry is required')
            original, failure = originals[self.import_id], next(iter(imports.values()))
            require(failure.get('fixture') == 'ui-image-failure' and failure.get('status') == 'ready' and
                    failure.get('verifiedBy') == 'official-admin-and-player-readbacks' and
                    failure.get('targetContentRecordCount') == 7 and failure.get('baseFixtureSha256') == FIXTURE_SHA and
                    failure.get('syntheticDerivation') is True and failure.get('sourceRowsRewritten') is False and
                    set(self.state['gameplay']['cases']) == {*original['caseIds'], failure['caseId']},
                    'The exact four own actors or independent seven-record derivation changed')
            for index, case_id in enumerate(original['caseIds']):
                case = self.state['gameplay']['cases'][case_id]
                require(case.get('fixture') == 'ui-real-content' and case.get('setupStatus') == 'ready' and
                        case.get('uiContentImportId') == self.import_id and case.get('sourceContent', {}).get('fixtureSha256') == FIXTURE_SHA and
                        case['sourceContent'].get('sourceCaseIndex') == index, 'An original case identity changed')

        def immutable(self):
            super().immutable()
            state = frame.ENTRY.read_state()
            require(canonical({key: state[key] for key in ('uiContent', 'uiImageFailures', 'gameplay')}) == self.registry_identity,
                    'The four-actor registry changed during the narrow choice capture')

        def verify_ledger(self):
            super().verify_ledger()
            self.cleanup['zeroForbiddenWrites'] = False
            require(self.final_facts.get('assignmentStatus') == 'active' and self.final_facts.get('startReceiptCount') ==
                    self.final_facts.get('progressRows') == 1 and self.final_facts.get('playerTotalXp') == 0,
                    'The normal choice sample must retain one entry and zero answers/settlement/XP')
            self.cleanup['zeroForbiddenWrites'] = True

        def specs(self):
            question, _ = self.question()
            options = question.get('options')
            require(isinstance(options, list) and len(options) == 4 and
                    [item.get('key') for item in options] == ['A', 'B', 'C', 'D'] and
                    all(isinstance(item.get('text'), str) and not item.get('videoUrl') for item in options),
                    'Only the explicit four-option photo-only case is supported')
            require(all(options[index].get('imageUrl') in self.assets for index in range(3)) and
                    not options[3].get('imageUrl'), 'Expected A/B/C original photos and text-only D')
            return [{'index': index, 'key': item['key'], 'text': item['text'],
                     'sourceSha256': self.assets.get(item.get('imageUrl', ''))} for index, item in enumerate(options)]

        def reads(self):
            return [row for row in self.ledger()[len(self.baseline):] if row.get('method') == 'GET' and row.get('path') == self.detail]

        geometry = layout.Layout.geometry
        quantitative_top = layout.Layout.quantitative_top
        pull = layout.Layout.pull

        def ready_images(self):
            for index in range(3):
                slot = 'gameplay-option-image-' + str(index)
                self.ui.seek(slot + '-frame')
                self.ui.wait(lambda value: value.find(slot + '-pixels') is not None or value.find(slot + '-error') is not None,
                             'own registered option photo decode', timeout=40)
                require(self.ui.find(slot + '-pixels') is not None and all(self.ui.find(slot + suffix) is None
                        for suffix in ('-loading', '-error', '-retry')), 'An option photo did not become pixels-ready')

        def identities(self, raw, selected, label, include_images=False):
            """Only real currently present nodes; never infer off-screen state."""
            identities = {}
            present = {row.get('id'): row for row in raw if row.get('bounds') and ui.positive(ui.rect(row['bounds']))}
            for index, spec in enumerate(self.option_specs):
                radio_id = 'gameplay-option-' + str(index)
                node = present.get(radio_id)
                if node is not None:
                    require(node.get('type') == 'Radio' and boolean(node, 'enabled') and
                            boolean(node, 'checked') == (selected == spec['key']), 'Actual observed Radio enabled/checked state differs from the expected draft')
                keys = [radio_id] if node is not None else []
                if include_images and index < 3:
                    keys.extend(key for suffix in ('-frame', '-pixels')
                                if (key := 'gameplay-option-image-' + str(index) + suffix) in present)
                for key in keys:
                    row = present[key]
                    identity = {name: row.get(name) for name in ('accessibilityId', 'hashcode')}
                    require(all(type(value) in (str, int) and bool(value) for value in identity.values()), 'A real native instance identity is unavailable')
                    identities[key] = identity
            frame.write_private(self.directory / ('instances-' + label + '.json'), {'identities': identities, 'selected': selected}, self.credentials())
            return identities

        def aggregate_identities(self, selected, label, include_images=False, captured=None, restore=None):
            expected = {'gameplay-option-' + str(index) for index in range(4)}
            if include_images:
                expected.update('gameplay-option-image-' + str(index) + suffix for index in range(3) for suffix in ('-frame', '-pixels'))
            result, observations = {}, []

            def add(raw, evidence, part):
                values = self.identities(raw, selected, label + '-part-' + str(part), include_images)
                require(all(key not in result or result[key] == value for key, value in values.items()),
                        'A control/image instance changed between bounded visible observations')
                result.update(values)
                observations.append({'rawSha256': evidence['sha256'], 'observedNodeIds': sorted(values)})

            if captured is not None: add(*captured, 0)
            # Two distant anchors normally cover all four rows. The remaining
            # two are bounded fallbacks only when a real photo/node was absent.
            for anchor in (0, 3, 1, 2):
                if expected.issubset(result): break
                self.ui.seek('gameplay-choice-' + str(anchor))
                raw, evidence = self.ui.raw_app(label + '-anchor-' + str(anchor))
                add(raw, evidence, len(observations))
            require(set(result) == expected, 'Bounded visible captures did not observe every required actual control/image identity')
            if restore is not None: self.ui.seek('gameplay-choice-' + str(restore))
            return result, observations

        def credentials(self):
            return (self.case['newPassword'], self.state['controlToken'], self.token)

        def capture_state(self, label, theme, selected, option=None, shot=True, full=True):
            if option is not None:
                self.ui.seek('gameplay-choice-' + str(option))
            raw, evidence = self.ui.raw_app(label)
            if full:
                ids, observations = self.aggregate_identities(selected, label, captured=(raw, evidence), restore=option)
                if self.initial_radio_instances is None: self.initial_radio_instances = ids
                else: require(ids == self.initial_radio_instances, 'An answer selection recreated a Radio instance')
                # Anchors can move the page. Geometry/PNG must correspond to a
                # fresh real target capture after its exact position is restored.
                raw, evidence = self.ui.raw_app(label + '-restored')
                visible = self.identities(raw, selected, label + '-restored')
                require(all(ids[key] == value for key, value in visible.items()), 'Restored visible Radio identity changed')
            else:
                visible = self.identities(raw, selected, label)
                require(self.initial_radio_instances is not None and all(self.initial_radio_instances[key] == value
                        for key, value in visible.items()), 'An idle visible Radio changed from the real full baseline')
                observations = [{'rawSha256': evidence['sha256'], 'observedNodeIds': sorted(visible)}]
            self.states.append({'position': label, 'themeRequested': theme, 'selected': selected,
                                'rawSha256': evidence['sha256'], 'option': option,
                                'radioIdentityObservations': observations, 'allFourRadiosActuallyObservedThisState': full})
            if shot:
                self.ui.private_shot(label); self.states[-1]['screenshot'] = self.ui.private_screenshots[-1]
            return raw

        def select(self, key, theme):
            self.immutable()
            index = ['A', 'B', 'C', 'D'].index(key)
            self.ui.tap('gameplay-option-' + str(index))
            # CLI's normalized layout omits checked/enabled. It only confirms
            # presence here; capture_state reads all actual raw checked fields.
            self.ui.wait(lambda value: value.find('gameplay-option-' + str(index)) is not None, 'own Radio remains present after selection')
            self.selection_sequence += 1
            return self.capture_state('selected-' + key + '-' + str(self.selection_sequence) + '-' + theme, theme, key, index)

        def sample(self, theme):
            if self.states:
                self.ui.back(); self.ui.wait(lambda value: value.find('current-tab') is not None, 'same actor home between themes')
                self.ui.tap('assignment-' + self.assignment_id)
                self.ui.wait(lambda value: value.find('gameplay-question-card') is not None and value.find('gameplay-loading') is None,
                             'same existing case resumes by GET')
            self.initial_radio_instances = None
            self.option_specs = self.specs(); self.ready_images()
            tolerance, density = 2 / self.ui.density, self.ui.density
            for index in range(4):
                raw = self.capture_state('initial-' + str(index) + '-' + theme, theme, '', index, full=index == 0)
                boxes = {key: ui.rect(frame.own(raw, key)['bounds']) for key in
                         ('gameplay-choice-' + str(index), 'gameplay-option-' + str(index) + '-header')}
                card, header = boxes.values()
                measured = {'cardWidthVp': (card[2] - card[0]) / density, 'cardHeightVp': (card[3] - card[1]) / density,
                            'headerWidthVp': (header[2] - header[0]) / density, 'headerHeightVp': (header[3] - header[1]) / density}
                require(abs(measured['cardWidthVp'] - 314) <= tolerance and abs(measured['headerWidthVp'] - 312) <= tolerance and
                        measured['headerHeightVp'] >= 58 - tolerance, 'Choice content widths or minimum header height differ from Web')
                if index < 3:
                    frame_box = ui.rect(frame.own(raw, 'gameplay-option-image-' + str(index) + '-frame')['bounds'])
                    pixels = ui.rect(frame.own(raw, 'gameplay-option-image-' + str(index) + '-pixels')['bounds'])
                    measured.update({'imageFrameWidthVp': (frame_box[2] - frame_box[0]) / density,
                                     'imageFrameHeightVp': (frame_box[3] - frame_box[1]) / density,
                                     'imagePixelsWidthVp': (pixels[2] - pixels[0]) / density,
                                     'imagePixelsHeightVp': (pixels[3] - pixels[1]) / density})
                    require(abs(measured['imageFrameWidthVp'] - 312) <= tolerance and abs(measured['imageFrameHeightVp'] - 130) <= tolerance and
                            abs((frame_box[1] - header[3]) / density) <= tolerance and ui.inside(pixels, frame_box, 2),
                            'Option Cover thumbnail frame is not the expected fullwidth130vp sibling after its header')
                else:
                    require(not any(str(row.get('id', '')).startswith('gameplay-option-image-3') for row in raw), 'Text-only D contains an empty image placeholder')
                require(abs(measured['cardHeightVp'] - measured['headerHeightVp'] - (132 if index < 3 else 2)) <= tolerance,
                        'The actual card height has extra image/header padding')
                key = frame.own(raw, 'gameplay-option-' + str(index) + '-key')
                text = frame.own(raw, 'gameplay-option-' + str(index) + '-text')
                require(key.get('text') == self.option_specs[index]['key'] and text.get('text') == self.option_specs[index]['text'], 'Actual option copy differs from authoritative DTO')
                self.states[-1]['geometryVp'] = measured
                self.states[-1]['registeredReferenceImageSha256'] = self.option_specs[index]['sourceSha256']
            self.check(True, 'Four options retain same copy, measured314/312 widths and three130vp photos with no empty D image')
            for key in ('A', 'B', 'A'):
                self.select(key, theme)
            self.check(True, 'A-B-A uses one actual checked Radio each time without recreating its instances')
            self.select('B', theme)
            before_ledger = len(self.ledger())
            self.ui.tap('gameplay-option-image-0-open')
            self.ui.wait(lambda value: value.find('image-viewer-pixels') is not None or value.find('image-viewer-error') is not None,
                         'A own singleton viewer', timeout=40)
            raw, evidence = self.ui.raw_app('viewer-A-' + theme)
            require(frame.own(raw, 'image-viewer-pixels') and not any(row.get('id') in ('image-viewer-navigation', 'image-viewer-index',
                    'image-viewer-previous', 'image-viewer-next', 'image-viewer-error', 'image-viewer-retry') for row in raw) and
                    frame.own(raw, 'image-viewer-percent').get('text') == '100%', 'An option image did not open as one ready image at100%')
            visible = self.identities(raw, 'B', 'viewer-A-' + theme)
            require(all(self.initial_radio_instances[key] == value for key, value in visible.items()),
                    'A genuinely observed underlying Radio changed while the cover was open')
            self.ui.private_shot('viewer-A-' + theme)
            self.states.append({'position': 'viewer-A-' + theme, 'themeRequested': theme, 'selected': 'B', 'imageCount': 1,
                                'rawSha256': evidence['sha256'], 'screenshot': self.ui.private_screenshots[-1],
                                'underlyingRadiosActuallyObserved': len(visible), 'allUnderlyingRadiosWhileCoverClaimed': len(visible) == 4,
                                'registeredReferenceImageSha256': self.option_specs[0]['sourceSha256']})
            if theme == 'light': self.ui.run('devecocli', 'ui', 'click', '--id', 'image-viewer-close')
            else: self.ui.back()
            self.ui.wait(lambda value: value.find('image-viewer') is None and value.find('gameplay-question-card') is not None, 'only option viewer closes')
            self.capture_state('closed-A-' + theme, theme, 'B', 1, shot=False)
            require(len(self.ledger()) == before_ledger, 'Option image viewing or close issued a business API request')
            self.check(True, 'Opening A while B is checked opens one image and closes without API traffic, selection or Radio replacement')
            if theme == 'light': self.refresh_sample(theme)
            self.verify_ledger(); self.immutable()

        def refresh_sample(self, theme):
            before_ids, before_observations = self.aggregate_identities('B', 'refresh-before', include_images=True)
            before = len(self.reads())
            gestures = []
            # Raw node bounds can be clipped by the title bar. They cannot tell
            # how far the Scroll is from its natural top. Scroll toward earlier
            # content and let the FIRST actual GET identify the official pull.
            # Never issue another gesture once that GET has been observed.
            for attempt in range(1, 9):
                self.immutable(); self.ui.capture()
                count = len(self.reads()) - before
                require(count <= 1, 'The bounded official Refresh phase issued more than one detail GET')
                if count == 1: break
                view = self.ui.viewport('gameplay-page')
                require(ui.positive(view) and view[3] - view[1] > 220 * self.ui.density,
                        'The actual Scroll viewport is too small for the bounded official downward swipe')
                x = round(view[0] + (view[2] - view[0]) * .58)
                start, end = round(view[1] + (view[3] - view[1]) * .20), round(view[1] + (view[3] - view[1]) * .80)
                self.ui.run('devecocli', 'ui', 'swipe', x, start, x, end, '--speed', 600)
                _, evidence = self.ui.raw_app('choice-refresh-scroll-' + str(attempt))
                count = len(self.reads()) - before
                require(count <= 1, 'One official downward swipe issued an extra assignment GET')
                gestures.append({'gesture': attempt, 'viewportBoundsPx': view, 'startPx': [x, start], 'endPx': [x, end],
                                 'rawSha256': evidence['sha256'], 'newDetailGetCount': count})
                if count == 1: break
            require(len(self.reads()) == before + 1, 'The bounded scroll-to-top/official-pull sequence did not produce its first detail GET')
            self.ui.wait(lambda value: len(self.reads()) == before + 1 and self.reads()[-1].get('status') == 200 and
                         self.reads()[-1].get('upstreamFinished') is True and value.find('gameplay-loading') is None,
                         'one actual successful choice Refresh GET')
            self.ui.seek('gameplay-submit')
            ready_raw, ready_evidence = self.ui.raw_app('choice-refresh-ready-submit')
            require(boolean(frame.own(ready_raw, 'gameplay-submit'), 'enabled') and
                    not any(row.get('id') == 'gameplay-refresh-error' for row in ready_raw),
                    'The actual selected-answer submit must be enabled after the completed Refresh')
            self.ready_images()
            after_ids, after_observations = self.aggregate_identities('B', 'refresh-after', include_images=True, restore=1)
            raw, evidence = self.ui.raw_app('choice-after-refresh-restored')
            require(len(self.reads()) == before + 1 and after_ids == before_ids,
                    'Refresh recreated Radio/thumbnail instances or changed the selected answer')
            self.ui.private_shot('choice-after-refresh')
            self.states.append({'position': 'after-refresh', 'themeRequested': theme, 'selected': 'B', 'newGetCount': 1,
                                'rawSha256': evidence['sha256'], 'screenshot': self.ui.private_screenshots[-1],
                                'actualBeforeIdentityObservations': before_observations, 'actualAfterIdentityObservations': after_observations,
                                'officialDownwardGestureCount': len(gestures), 'scrollAndFirstRefreshObservations': gestures,
                                'refreshReadySubmitRawSha256': ready_evidence['sha256'], 'quantitativeUnclippedTopClaimed': False})
            self.check(True, 'One successful native Refresh GET retains selected B and all actual Radio/thumbnail instances')

        def execute(self):
            try:
                self.main()
                self.stage = 'normal-choice-sample-complete'
            except Exception as error:
                reason = str(error)
                for value in self.credentials():
                    if value: reason = reason.replace(value, '[credential omitted]')
                frame.write_private(self.directory / 'failure-diagnostic.json', {'stage': self.stage,
                    'exceptionType': type(error).__name__, 'reason': reason}, self.credentials())
                self.failure = 'The narrow choice sample is incomplete; private diagnostic originals retained'
            finally:
                try:
                    self.immutable()
                    if self.device_started:
                        self.ui.capture()
                        if self.ui.find('image-viewer') is not None:
                            self.ui.run('devecocli', 'ui', 'click', '--id', 'image-viewer-close')
                            self.ui.wait(lambda value: value.find('image-viewer') is None, 'own viewer cleanup')
                        self.logout(); self.verify_ledger()
                except Exception:
                    self.failure = self.failure or 'Exact own logout or zero-answer cleanup could not be confirmed'
                self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
                if not all(self.cleanup.values()): self.failure = self.failure or 'Narrow cleanup remains incomplete'
            ledger = frame.write_private(self.directory / 'request-ledger.json', getattr(self, 'final_ledger', {}), self.credentials())
            report = {'status': 'incomplete' if self.failure else 'captured_native_choice_options', 'stage': self.stage,
                'scope': PLAN['scope'], 'plan': PLAN, 'bindingSha256': self.binding, 'hapSha256': self.hap_sha,
                'expectedFixtureSha256': FIXTURE_SHA, 'imagesManifestSha256': MANIFEST_SHA, 'sourceCaseIndex': 1,
                'checksPassed': len(self.checks), 'checks': self.checks, 'states': self.states, 'cleanup': self.cleanup,
                'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
                'sameDataWebFixture': getattr(self, 'fixture', None), 'privateReadOnlyLedger': ledger,
                'observedReadOnlyFacts': {key: self.final_facts[key] for key in ('answerSubmissionCount', 'answerReceiptCount',
                    'xpLedgerCount', 'xpDeltaSum', 'startReceiptCount', 'progressRows', 'playerTotalXp')}
                    if hasattr(self, 'final_facts') else None,
                'nativeDownloadSha256Observed': False, 'referenceImagesDownloadedByHelper': False,
                'visualReview': 'pending_root_original_review_and_same_data_Web_capture', 'wholePageParityAccepted': False,
                'completedChoiceAcceptanceClaimed': False, 'fixedPreviewTouched': False, 'failure': self.failure,
                'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
            encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
            private = [self.case_id, self.case['account'], self.case['newPassword'], self.case['playerId'], self.assignment_id,
                       self.case['assignments']['ready']['sessionId'], self.state['controlToken'], self.token, *self.assets]
            require(not re.search(r'https?://', encoded) and not any(value and value in encoded for value in private), 'A private literal would enter the public choice report')
            frame.fresh(self.report, OUT); self.report.parent.mkdir(parents=True, exist_ok=True)
            fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
            with os.fdopen(fd, 'w') as stream: stream.write(encoded)
            print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks), 'report': str(self.report.relative_to(ROOT))}), flush=True)
            return 1 if self.failure else 0

    return Choice()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action'); sub.add_parser('plan')
    run = sub.add_parser('run')
    for name in ('runtime', 'case-ref', 'output', 'private-dir', 'images-manifest'):
        run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-hap', 'expected-fixture-sha', 'expected-images-manifest-sha', 'expected-choice-ui-sha', 'expected-gameplay-page-sha'):
        run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if args.action is None: parser.print_help(); return 0
    if args.action == 'plan': print(json.dumps(PLAN, indent=2)); return 0
    try: return create(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded', 'reason': 'Exact choice/case/runtime/source/output prerequisites failed; raw values omitted'})); return 1


if __name__ == '__main__':
    sys.exit(main())

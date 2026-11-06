#!/usr/bin/env python3
"""Root-reviewed narrow native body-image viewer sample; default/help is inert.

One explicit already-active real-content case0 or case2 per run. Reuses the
unchanged Frame guards and Images positioning/source helpers. Only Host auth,
reads, native navigation/theme/input/viewer clicks and official single-finger
gestures are permitted. No start/answer/profile/fault/fixture/service operation.
Pinch, zoomed Pan, viewer404/cancellation and visual acceptance remain pending.
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
import statistics
import sys

from native_device_ui import ROOT

SPEC = importlib.util.spec_from_file_location('viewer_body_image_helpers', ROOT / 'scripts/device-question-images.py')
IMAGES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMAGES)
FRAME, UI = IMAGES.FRAME, IMAGES.UI
require, sha = FRAME.require, FRAME.sha
OUT = ROOT / 'artifacts/validation/ui-image-viewer-20261105'
DRAFT = 'NativeViewerDraftOnly-DoNotSubmit'
IDS = ('image-viewer', 'image-viewer-mask', 'image-viewer-panel', 'image-viewer-stage', 'image-viewer-pixels',
       'image-viewer-close', 'image-viewer-percent', 'image-viewer-reset', 'image-viewer-help')
PENDING = ['Real multi-pointer Pinch/zoomed Pan/reset-from-zoom/remaining-finger isolation',
           'Viewer-specific HTTP404/retry and pending-image cancellation; the body404 fixture cannot stand in for these',
           'Root original-image visual review, including system areas; metadata and pixel probes alone are not full parity']


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False, allow_nan=False)


def pose(row):
    values = {row[key] for key in ('description', 'accessibilityDescription') if isinstance(row.get(key), str) and row[key]}
    parsed = [re.fullmatch(r'缩放(\d+)%；水平偏移(-?\d+(?:\.\d+)?)vp；垂直偏移(-?\d+(?:\.\d+)?)vp', value) for value in values]
    parsed = [match for match in parsed if match]
    require(len(parsed) == 1, 'The actual stage accessibility pose is unavailable or ambiguous')
    return {'percent': int(parsed[0][1]), 'xVp': float(parsed[0][2]), 'yVp': float(parsed[0][3])}


def enabled(row):
    require(type(row.get('enabled')) is bool or type(row.get('enabled')) is str and row['enabled'] in ('true', 'false'), 'Actual control enabled state is absent')
    return row['enabled'] is True or row['enabled'] == 'true'


def light_probe(image, boxes):
    samples = []
    for box in boxes:
        left, top, right, bottom = [round(value) for value in box]
        require(0 <= left < right <= image.width and 0 <= top < bottom <= image.height, 'A real pixel probe escapes its original PNG')
        samples.extend(image.getpixel((x, y)) for y in range(top, bottom) for x in range(left, right))
    require(samples, 'A real pixel probe has no samples')
    luminance = lambda value: .2126 * value[0] + .7152 * value[1] + .0722 * value[2]
    background = statistics.median(luminance(value) for value in samples)
    foreground = [value for value in samples if abs(luminance(value) - background) >= 70 and max(value) - min(value) <= 45]
    light = sum(min(value) >= 190 for value in foreground)
    dark = sum(max(value) <= 100 for value in foreground)
    return {'sampledPixels': len(samples), 'neutralContrastPixels': len(foreground), 'backgroundMedianLuma': background,
            'lightContrastPixels': light, 'darkContrastPixels': dark,
            'lightFraction': light / len(foreground) if foreground else 0, 'darkFraction': dark / len(foreground) if foreground else 0}


def mask_point(root, panel, top_inset, bottom_inset, density):
    left, top, right, bottom = root
    candidates = [((left + right) / 2, (top + top_inset + panel[1]) / 2),
                  ((left + right) / 2, (panel[3] + bottom - bottom_inset) / 2),
                  ((left + panel[0]) / 2, (panel[1] + panel[3]) / 2)]
    for x, y in candidates:
        if left + 3 * density <= x <= right - 3 * density and top + top_inset + 3 * density <= y <= bottom - bottom_inset - 3 * density and \
                not (panel[0] - 2 <= x <= panel[2] + 2 and panel[1] - 2 <= y <= panel[3] + 2):
            return [round(x), round(y)]
    raise FRAME.SafeFailure('There is no observed safe mask point outside the real panel')


class Viewer(IMAGES.Images):
    def __init__(self, args):
        # Images' constructor deliberately retains its historical output/Web-frame
        # namespace. This new viewer uses Frame's unchanged actor/19-record guards
        # plus the same eight-image source policy and its own Web-viewer reference.
        FRAME.fresh(args.output, OUT)
        FRAME.FrameSample.__init__(self, args)
        self.index = self.case['sourceContent']['sourceCaseIndex']
        require(self.index in (0, 2) and self.case['fixtureLevelKinds'] == ['text'], 'Only explicit real-content case0/case2 text is supported')
        self.guard_registry(self.state)
        self.registry_identity = canonical({key: self.state[key] for key in ('uiContent', 'uiImageFailures', 'gameplay')})
        for key in ('expected_images_manifest_sha', 'expected_web_reference_sha', 'expected_viewer_sha',
                    'expected_gameplay_page_sha', 'expected_window_sha', 'expected_surfaces_sha'):
            require(re.fullmatch(r'[a-f0-9]{64}', getattr(args, key) or ''), 'Explicit image/Web/viewer/platform source SHA256 is required')
        manifest_path = FRAME.ENTRY.guarded(args.images_manifest, FRAME.PRIVATE, True)
        require(sha(manifest_path) == args.expected_images_manifest_sha, 'The approved registered image manifest changed')
        manifest = json.loads(manifest_path.read_text())
        require(manifest.get('status') == 'reference_image_bytes_captured' and manifest.get('fixtureSha256') == args.expected_fixture_sha and
                manifest.get('referer') == 'https://sitkin.top/' and manifest.get('nativeLoadVerified') is False and len(manifest.get('assets', [])) == 8,
                'The exact original eight-image manifest is required')
        self.assets = {}
        for asset in manifest['assets']:
            require(isinstance(asset, dict) and isinstance(asset.get('url'), str) and asset['url'] not in self.assets and
                    re.fullmatch(r'[a-f0-9]{64}', asset.get('sha256', '')) and asset.get('authorizationSent') is False and
                    asset.get('detectedMime') in ('image/png', 'image/jpeg'), 'A registered image mapping is invalid')
            self.assets[asset['url']] = asset['sha256']
        reference = FRAME.ENTRY.guarded(args.web_reference, OUT)
        require(reference.name == 'web-reference-01.json' and sha(reference) == args.expected_web_reference_sha, 'The reviewed actual Web viewer report changed')
        self.web = json.loads(reference.read_text())
        require(self.web.get('status') == 'captured_web_image_viewer_reference' and self.web.get('sourceCommit') == IMAGES.FROZEN_WEB and
                self.web.get('expectedFixtureSha256') == args.expected_fixture_sha and self.web.get('imagesManifestSha256') == args.expected_images_manifest_sha and
                self.web.get('backendRequestsContinued') == self.web.get('externalRequestsContinued') == 0 and
                set(self.web.get('registeredImageSha256', [])) == set(self.assets.values()) and len(self.web.get('states', [])) == 12 and
                self.web.get('counts', {}).get('checks') == 4 and self.web['counts'].get('schemaChecks') == 12 and self.web['counts'].get('servedSourceChecks') == 112,
                'The complete reviewed two-case/two-theme Web viewer reference is required')
        self.natural, self.reference_order = [{}, {}, {}], [{}, {}, {}]
        for state in self.web['states']:
            image, case_index = state.get('currentImage'), state.get('case')
            if image is not None:
                require(case_index in (0, 2) and image.get('sourceSha256') in set(self.assets.values()) and image.get('complete') is True and
                        all(type(image.get(key)) is int and image[key] > 0 for key in ('naturalWidth', 'naturalHeight')), 'A Web viewer image has no real registered natural dimensions')
                key, size = image['sourceSha256'], (image['naturalWidth'], image['naturalHeight'])
                require(key not in self.natural[case_index] or self.natural[case_index][key] == size, 'A Web source SHA has inconsistent natural dimensions')
                self.natural[case_index][key] = size
                image_index = 0 if case_index == 0 else state.get('index', 0) - 1
                require(type(image_index) is int and 0 <= image_index < (1 if case_index == 0 else 3) and
                        (image_index not in self.reference_order[case_index] or self.reference_order[case_index][image_index] == key),
                        'The Web viewer index/source order is incomplete or inconsistent')
                self.reference_order[case_index][image_index] = key
        require(set(self.reference_order[0]) == {0} and set(self.reference_order[2]) == {0, 1, 2}, 'Every same-data Web viewer index is required')
        source_files = {'viewer': 'ui/StarwardImageViewer.ets', 'gameplay_page': 'features/GameplayPage.ets',
                        'window': 'platform/ImmersiveWindow.ets', 'surfaces': 'platform/ImmersiveSurfaces.ets'}
        for name, path in source_files.items():
            filename = ROOT / 'entry/src/main/ets' / path
            require(sha(filename) == getattr(args, 'expected_' + name + '_sha'), 'A reviewed viewer/platform source changed')
            self.bound[name], self.binding[name] = filename, sha(filename)
        for name, filename in {'viewerDriver': Path(__file__), 'imagesHelper': ROOT / 'scripts/device-question-images.py', 'webViewerReference': reference,
                'imageManifest': manifest_path, 'imageUI': ROOT / 'entry/src/main/ets/ui/StarwardQuestionImages.ets',
                'imageLoader': ROOT / 'entry/src/main/ets/platform/QuestionImageLoader.ets', 'imageIO': ROOT / 'entry/src/main/ets/platform/QuestionImageIO.ets',
                'viewModel': ROOT / 'entry/src/main/ets/features/GameplayViewModel.ets', 'index': ROOT / 'entry/src/main/ets/pages/Index.ets',
                'failureSetup': ROOT / 'scripts/ui-image-failure-case.mjs', 'webViewerHelper': ROOT / 'scripts/capture-web-image-viewer.py'}.items():
            self.bound[name], self.binding[name] = filename, sha(filename)
        require(self.binding['webViewerHelper'] == self.web.get('helperSha256'), 'The reviewed Web capture helper bytes changed')
        self.window = json.loads(self.bound['runtime'].read_text())['window']
        require(all(type(self.window.get(key)) in (int, float) and math.isfinite(self.window[key]) and self.window[key] >= 0
                    for key in ('topInsetPx', 'bottomInsetPx', 'widthPx', 'heightPx')) and self.window['topInsetPx'] > 8 * self.ui.density,
                    'Actual runtime system-area geometry is required for original-pixel probes')
        self.input_identity, self.viewer_checks = None, []

    def guard_registry(self, state):
        originals = state.get('uiContent', {}).get('imports', {})
        failures = state.get('uiImageFailures', {})
        imports = failures.get('imports', {})
        require(len(originals) == 1 and self.import_id in originals and failures.get('schema') == 1 and len(imports) == 1,
                'The exact original three-case plus independent one-failure environment is required')
        original, failure = originals[self.import_id], next(iter(imports.values()))
        actors = state['gameplay']['cases']
        require(isinstance(failure, dict) and failure.get('fixture') == 'ui-image-failure' and failure.get('status') == 'ready' and
                failure.get('verifiedBy') == 'official-admin-and-player-readbacks' and failure.get('targetContentRecordCount') == 7 and
                failure.get('baseFixtureSha256') == self.args.expected_fixture_sha and failure.get('syntheticDerivation') is True and
                failure.get('sourceRowsRewritten') is False and failure.get('caseId') not in original['caseIds'] and
                set(actors) == {*original['caseIds'], failure['caseId']}, 'The separate seven-record failure registry or exact actor set changed')
        for index, case_id in enumerate(original['caseIds']):
            case = actors[case_id]
            require(case.get('fixture') == 'ui-real-content' and case.get('setupStatus') == 'ready' and case.get('uiContentImportId') == self.import_id and
                    case.get('sourceContent', {}).get('fixtureSha256') == self.args.expected_fixture_sha and
                    case['sourceContent'].get('sourceCaseIndex') == index, 'The original three real-content cases changed')

    def immutable(self):
        super().immutable()
        current = FRAME.ENTRY.read_state()
        require(canonical({key: current[key] for key in ('uiContent', 'uiImageFailures', 'gameplay')}) == self.registry_identity,
                'The original/failure registry or actor metadata changed during viewer capture')

    def snapshot(self):
        value = super().snapshot()
        require(value['assignment'].get('status') == 'active', 'Viewer capture requires an already-active own case; it never starts a case')
        return value

    def specs(self):
        result = super().specs()
        require(all(item['sourceSha256'] == self.reference_order[self.index][index] for index, item in enumerate(result)),
                'The active native body group order differs from the reviewed same-data Web viewer')
        return result

    def facts(self):
        value = super().facts()
        require(value.get('startReceiptCount') == value.get('progressRows') == 1, 'The existing single entry/progress facts changed')
        return value

    def verify_ledger(self):
        self.cleanup['zeroForbiddenWrites'] = False
        try:
            super().verify_ledger()
            require(self.expected_starts == 0 and all(row.get('method') != 'POST' or row.get('path') == FRAME.AUTH for row in self.final_ledger['added']),
                    'Viewer capture must contain zero native start and zero business writes')
        except Exception:
            self.cleanup['zeroForbiddenWrites'] = False
            raise

    def draft(self, label, initial=False):
        raw, evidence = self.ui.raw_app('viewer-input-' + label)
        row = FRAME.own(raw, 'gameplay-answer-input')
        identity = {key: row.get(key) for key in ('accessibilityId', 'hashcode')}
        require(row.get('text') == DRAFT and all(type(value) in (str, int) and bool(value) for value in identity.values()), 'Actual draft/input identity is absent')
        if initial: self.input_identity = identity
        else: require(identity == self.input_identity, 'The actual answer-input instance changed while viewing an image')
        FRAME.write_private(self.directory / ('viewer-input-' + label + '.json'), {'identity': identity, 'draftMatches': True},
                            (self.case['newPassword'], self.state['controlToken'], self.token))
        return evidence['sha256']

    def screenshot(self, label, theme, raw=None):
        self.ui.private_shot(label)
        evidence = self.ui.private_screenshots[-1]
        image = FRAME.OriginalPng(ROOT / evidence['file'])
        width, height, top = image.width, image.height, self.window['topInsetPx']
        require(abs(width - self.window['widthPx']) <= 1 and abs(height - self.window['heightPx']) <= 1, 'Original PNG and actual runtime dimensions differ')
        status = light_probe(image, [[width * .03, top * .20, width * .30, top * .80], [width * .72, top * .20, width * .97, top * .80]])
        expected = 'lightFraction' if raw is not None or theme == 'dark' else 'darkFraction'
        require(status['neutralContrastPixels'] >= max(12, self.ui.density ** 2 * 2) and status[expected] >= .60,
                'Original status-area pixels do not show the expected viewer/restored icon polarity')
        percent = None
        if raw is not None:
            percent = light_probe(image, [UI.rect(FRAME.own(raw, 'image-viewer-percent')['bounds'])])
            require(percent['neutralContrastPixels'] >= max(4, self.ui.density ** 2) and percent['lightFraction'] >= .60,
                    'The actual percent glyph pixels are not light on the dark viewer in this theme')
        return {'screenshot': evidence, 'statusBarPixelProbe': status, 'percentPixelProbe': percent,
                'pixelProbeMeaning': 'Original local contrast/polarity observations; Root must review the complete original'}

    def observe(self, label, theme, index, original=True):
        self.ui.wait(lambda ui: ui.find('image-viewer-pixels') is not None or ui.find('image-viewer-error') is not None,
                     'actual viewer decoder result', timeout=40)
        raw, evidence = self.ui.raw_app(label)
        require(all(any(row.get('id') == node_id for row in raw) for node_id in IDS) and
                all(not any(row.get('id') == 'image-viewer-' + suffix for row in raw) for suffix in ('loading', 'error', 'retry')),
                'The normal viewer lacks ready pixels or retains loading/error state')
        nodes = {node_id: FRAME.own(raw, node_id) for node_id in IDS}
        actual_pose = pose(nodes['image-viewer-stage'])
        require(actual_pose == {'percent': 100, 'xVp': 0.0, 'yVp': 0.0} and nodes['image-viewer-percent'].get('text') == '100%', 'The opened/selected image did not reset to its actual baseline pose')
        if self.index == 0:
            require(not any(row.get('id') in ('image-viewer-navigation', 'image-viewer-index', 'image-viewer-previous', 'image-viewer-next') for row in raw),
                    'A single image must not add gallery navigation')
        else:
            require(FRAME.own(raw, 'image-viewer-index').get('text') == str(index + 1) + ' / 3' and
                    enabled(FRAME.own(raw, 'image-viewer-previous')) == (index > 0) and enabled(FRAME.own(raw, 'image-viewer-next')) == (index < 2),
                    'Actual non-loop gallery index/disabled boundaries differ')
        panel = UI.rect(nodes['image-viewer-panel']['bounds'])
        require(abs((panel[2] - panel[0]) / self.ui.density - 348) <= 2 / self.ui.density, 'The actual376vp viewer panel is not348vp')
        state = {'themeRequested': theme, 'position': label, 'imageIndex': index + 1, 'imageCount': 1 if self.index == 0 else 3,
                 'pose': actual_pose, 'geometryPx': {key: UI.rect(value['bounds']) for key, value in nodes.items()},
                 'sourceSha256': self.specs()[index]['sourceSha256'], 'rawSha256': evidence['sha256']}
        if original: state.update(self.screenshot(label, theme, raw))
        self.states.append(state)
        return raw

    def open_image(self, index):
        # The already-reviewed frame remains a Stack; the new official Button
        # keeps its own44vp hit target without changing the measured image frame.
        self.ui.tap(self.specs()[index]['slot'] + '-open')
        self.ui.wait(lambda ui: ui.find('image-viewer') is not None, 'own native body-image viewer')

    def unchanged_index(self, index):
        for _ in range(3):
            self.ui.capture()
            require(self.ui.find('image-viewer-index') is not None and self.ui.find('image-viewer-index').get('text') == str(index + 1) + ' / 3' and
                    self.ui.find('image-viewer-percent').get('text') == '100%', 'A nonqualifying gesture unexpectedly changed image or pose')

    def swipe(self, dx_vp, dy_vp):
        self.ui.capture()
        box, density = UI.rect(self.ui.find('image-viewer-stage')['bounds']), self.ui.density
        cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
        points = [round(cx - dx_vp * density / 2), round(cy - dy_vp * density / 2),
                  round(cx + dx_vp * density / 2), round(cy + dy_vp * density / 2)]
        require(all(box[0] + 12 * density <= points[i] <= box[2] - 12 * density and
                    box[1] + 12 * density <= points[i + 1] <= box[3] - 12 * density for i in (0, 2)), 'The planned single-finger gesture escapes the measured stage')
        self.ui.run('devecocli', 'ui', 'swipe', *points, '--speed', 600)
        return {'deltaVp': [dx_vp, dy_vp], 'endpointsPx': points, 'officialSinglePointerCommandCount': 1}

    def close_image(self, method, theme):
        if method == 'x': self.ui.run('devecocli', 'ui', 'click', '--id', 'image-viewer-close')
        elif method == 'back': self.ui.back()
        else:
            self.ui.capture()
            point = mask_point(UI.rect(self.ui.find('image-viewer')['bounds']), UI.rect(self.ui.find('image-viewer-panel')['bounds']),
                               self.window['topInsetPx'], self.window['bottomInsetPx'], self.ui.density)
            self.ui.run('devecocli', 'ui', 'click', *point)
        self.ui.wait(lambda ui: ui.find('image-viewer') is None and ui.find('gameplay-question-card') is not None and ui.find('current-tab') is None,
                     'viewer closes without popping the active gameplay destination')
        input_sha = self.draft(theme + '-' + method)
        state = {'themeRequested': theme, 'position': 'closed-' + method, 'inputRawSha256': input_sha, 'sameInputIdentityAndDraft': True}
        state.update(self.screenshot('viewer-closed-' + theme + '-' + method, theme))
        self.states.append(state)

    def sample(self, theme):
        if self.states: self.reopen()  # The reused implementation requires the established two GET200 responses.
        before = len(self.ledger())
        self.ready_images(self.specs())
        self.ui.fill('gameplay-answer-input', DRAFT)
        self.draft(theme + '-initial', initial=True)
        baseline = self.screenshot('viewer-before-' + theme, theme)
        self.states.append({'themeRequested': theme, 'position': 'before-open', **baseline})
        first = len(self.specs()) - 1
        self.open_image(first); self.observe('viewer-open-' + theme, theme, first)
        if self.index == 2:
            for index in (1, 0):
                self.ui.run('devecocli', 'ui', 'click', '--id', 'image-viewer-previous')
                self.ui.wait(lambda ui: ui.find('image-viewer-index') is not None and ui.find('image-viewer-index').get('text') == str(index + 1) + ' / 3', 'one actual gallery selection')
                self.observe('viewer-previous-' + str(index + 1) + '-' + theme, theme, index)
            if theme == 'light':
                for kind, dx, dy in (('subthreshold', -20, 0), ('diagonal', -100, -100)):
                    gesture = self.swipe(dx, dy); self.unchanged_index(0)
                    self.viewer_checks.append({'theme': theme, 'gesture': kind, **gesture, 'indexUnchanged': True})
                gesture = self.swipe(-120, 0)
                self.ui.wait(lambda ui: ui.find('image-viewer-index') is not None and ui.find('image-viewer-index').get('text') == '2 / 3', 'one real baseline swipe changes exactly one image')
                self.unchanged_index(1); self.observe('viewer-single-swipe-' + theme, theme, 1)
                self.viewer_checks.append({'theme': theme, 'gesture': 'qualifying-horizontal', **gesture, 'oneIndexChange': True})
        self.close_image('x', theme)
        if theme == 'light':
            for method in ('back', 'mask'):
                self.open_image(first); self.observe('viewer-reopen-' + method, theme, first, original=False)
                self.close_image(method, theme)
        require(len(self.ledger()) == before, 'Image positioning/input/viewer gestures unexpectedly issued a business request')
        self.verify_ledger()
        self.sample_end_detail_reads = len([row for row in self.ledger() if row.get('method') == 'GET' and row.get('path') == self.detail])
        self.check(True, 'The theme viewer/closing original pixels, exact gallery bounds and retained native input are recorded without business traffic')

    def execute(self):
        try:
            FRAME.FrameSample.main(self)
            tail = [row for row in self.ledger() if row.get('method') == 'GET' and row.get('path') == self.detail][self.sample_end_detail_reads:]
            require(len(tail) == 2 and all(row.get('status') == 200 for row in tail),
                    'Final active re-entry must issue its established projection/snapshot GET200 pair')
            self.stage = 'native-viewer-narrow-captured'
        except Exception as error:
            reason = str(error)
            for value in (self.case['newPassword'], self.state['controlToken'], self.token):
                if value: reason = reason.replace(value, '[credential omitted]')
            FRAME.write_private(self.directory / 'failure-diagnostic.json', {'stage': self.stage, 'exceptionType': type(error).__name__, 'reason': reason},
                                (self.case['newPassword'], self.state['controlToken'], self.token))
            self.failure = 'The narrow native viewer checks are incomplete; private originals/diagnostics retained'
        finally:
            try:
                self.immutable()
                if self.device_started:
                    self.ui.capture()
                    if self.ui.find('image-viewer') is not None:
                        self.ui.run('devecocli', 'ui', 'click', '--id', 'image-viewer-close')
                        self.ui.wait(lambda ui: ui.find('image-viewer') is None, 'viewer dismissed before owned cleanup')
                    self.logout(); self.verify_ledger()
            except Exception:
                self.failure = self.failure or 'Owned logout/zero-write/source observations could not be confirmed'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not all(self.cleanup.values()): self.failure = self.failure or 'Narrow viewer cleanup is incomplete'
        ledger = None
        if hasattr(self, 'final_ledger'):
            ledger = FRAME.write_private(self.directory / 'request-ledger.json', self.final_ledger, (self.case['newPassword'], self.state['controlToken'], self.token))
        report = {'status': 'incomplete' if self.failure else 'captured_native_viewer_narrow', 'scope': 'Normal body-image viewer baseline/index/close/input/status-area sample',
            'viewerAcceptanceComplete': False, 'pendingAcceptance': PENDING, 'visualReview': 'pending_root_original_review',
            'sourceCaseIndex': self.index, 'hapSha256': self.hap_sha, 'bindingSha256': self.binding, 'checksPassed': len(self.checks), 'checks': self.checks,
            'viewerChecks': self.viewer_checks, 'states': self.states, 'cleanup': self.cleanup, 'failure': self.failure,
            'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence, 'privateReadOnlyLedger': ledger,
            'sameDataWebFixture': getattr(self, 'fixture', None), 'realPinchOrZoomedPanInjected': False, 'nativeDownloadSha256Observed': False,
            'otherTestCountsInherited': False, 'fixedPreviewTouched': False, 'writeScope': 'Host auth/read only; zero start/answer/profile/password/fault/reset',
            'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        literals = [self.case_id, self.case['account'], self.case['newPassword'], self.case['playerId'], self.assignment_id,
                    self.case['assignments']['ready']['sessionId'], self.state['controlToken'], self.token, *self.assets]
        require(not re.search(r'https?://', encoded) and not any(value and value in encoded for value in literals), 'A private literal would enter the public viewer report')
        FRAME.fresh(self.report, OUT); self.report.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream: stream.write(encoded)
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks), 'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 1 if self.failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action'); run = sub.add_parser('run')
    for name in ('runtime', 'case-ref', 'output', 'private-dir', 'images-manifest', 'web-reference'):
        run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-hap', 'expected-fixture-sha', 'expected-images-manifest-sha', 'expected-web-reference-sha',
                 'expected-viewer-sha', 'expected-gameplay-page-sha', 'expected-window-sha', 'expected-surfaces-sha'):
        run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if not args.action: parser.print_help(); return 0
    try: return Viewer(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded', 'error': 'Explicit viewer/source/case/registry/runtime/output guards failed; raw values omitted'})); return 1


if __name__ == '__main__':
    sys.exit(main())

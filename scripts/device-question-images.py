#!/usr/bin/env python3
"""Root-reviewed normal body-image sample for one explicit real-content case.

Default/help is inert. FrameSample owns strict case/19-record/runner/CA/HAP
guards and native login/optional single start/GET-only resume. This helper only
adds decoded body-image geometry, order and private originals. No image is
clicked; choice images, viewing, failure/cancellation and whole-page parity are
not accepted here. References are read locally; the helper never downloads them.
"""
import argparse, datetime, importlib.util, json, math, os, re, sys
from pathlib import Path
from native_device_ui import ROOT

SPEC = importlib.util.spec_from_file_location('question_images_frame', ROOT / 'scripts/device-question-frame.py')
FRAME = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FRAME)
require, UI = FRAME.require, FRAME.UI
OUT = ROOT / 'artifacts/validation/ui-question-images-20261104'
FROZEN_WEB = '4b7d1a0a00051ac630e459b0fd6c074f821d7455'


def body_sources(block):
    require(isinstance(block, dict) and isinstance(block.get('imageUrls', []), list), 'A body content block is invalid')
    if block.get('videoUrl', ''):
        return []
    values = [block.get('imageUrl', ''), *block.get('imageUrls', [])]
    require(all(isinstance(value, str) for value in values), 'Body image sources must be strings')
    return list(dict.fromkeys(value for value in values if value))


def image_plan(width, dimensions):
    require(math.isfinite(width) and width > 2 and dimensions, 'Actual group width/natural image dimensions are absent')
    columns = min(len(dimensions), max(1, math.floor((width + 10) / 160)))
    cell = (width - (columns - 1) * 10) / columns
    require(columns == 1 or cell >= 150, 'The actual gallery cannot retain150vp minimum columns')
    result, top = [], 0
    for start in range(0, len(dimensions), columns):
        row = []
        for index, (natural_width, natural_height) in enumerate(dimensions[start:start + columns]):
            scale = min(1, (cell - 2) / natural_width, 338 / natural_height)
            frame_width, frame_height = natural_width * scale + 2, natural_height * scale + 2
            row.append({'cellWidth': cell, 'cellX': index * (cell + 10), 'rowY': top,
                        'frameWidth': frame_width, 'frameHeight': frame_height,
                        'frameX': index * (cell + 10) + (cell - frame_width) / 2})
        result.extend(row)
        top += max(item['frameHeight'] for item in row) + 10
    return result, top - 10, columns


def natural_reference(report, asset_shas):
    require(report.get('status') == 'captured_frame_render_reference' and report.get('sourceCommit') == FROZEN_WEB and
            report.get('backendRequestsContinued') == report.get('externalRequestsContinued') == 0 and
            report.get('counts', {}).get('unknownImageRequests') == 0 and report['counts'].get('imageReplayRequests', 0) > 0 and
            report.get('viewport') == {'width': 376, 'height': 742, 'deviceScaleFactor': 1}, 'An approved same-byte Web reference is incomplete')
    require(set(report.get('registeredImageSha256', [])) == asset_shas, 'The Web report uses another registered image set')
    result, themes = {}, set()
    for state in report.get('states', []):
        themes.add(state.get('theme'))
        for item in state.get('geometry', {}).get('images', []):
            key = item.get('sourceSha256')
            dimensions = (item.get('naturalWidth'), item.get('naturalHeight'))
            require(key in asset_shas and item.get('complete') is True and
                    all(type(value) is int and value > 0 for value in dimensions), 'A registered Web image has no real decoded natural size')
            require(key not in result or result[key] == dimensions, 'The same image SHA has inconsistent natural dimensions')
            result[key] = dimensions
    require(themes == {'light', 'dark'} and result, 'Both approved Web themes and natural dimensions are required')
    return result


class Images(FRAME.FrameSample):
    def __init__(self, args):
        FRAME.fresh(args.output, OUT)
        super().__init__(args)
        require(re.fullmatch(r'[a-f0-9]{64}', args.expected_images_manifest_sha or ''), 'An explicit registered-image manifest SHA is required')
        manifest_path = FRAME.ENTRY.guarded(args.images_manifest, FRAME.PRIVATE, True)
        require(FRAME.sha(manifest_path) == args.expected_images_manifest_sha, 'The approved sniffed manifest bytes changed')
        manifest = json.loads(manifest_path.read_text())
        require(manifest.get('status') == 'reference_image_bytes_captured' and manifest.get('fixtureSha256') == args.expected_fixture_sha and
                manifest.get('referer') == 'https://sitkin.top/' and manifest.get('nativeLoadVerified') is False and
                isinstance(manifest.get('assets'), list) and len(manifest['assets']) == 8, 'The exact eight-asset reference manifest is required')
        self.assets = {}
        for asset in manifest['assets']:
            require(isinstance(asset, dict) and isinstance(asset.get('url'), str) and asset['url'] not in self.assets and
                    re.fullmatch(r'[a-f0-9]{64}', asset.get('sha256', '')) and asset.get('authorizationSent') is False and
                    asset.get('detectedMime') in ('image/png', 'image/jpeg'), 'A sniffed image mapping is invalid')
            self.assets[asset['url']] = asset['sha256']
        self.natural = []
        for index, stem in enumerate(('web-case0-02', 'web-case1-01', 'web-case2-01')):
            filename = FRAME.ENTRY.guarded(getattr(args, 'web_case' + str(index)), FRAME.VALIDATION)
            require(filename.name == stem + '.json', 'Use the three explicitly approved existing Web reports')
            report = json.loads(filename.read_text())
            require(report.get('expectedFixtureSha256') == args.expected_fixture_sha and
                    report.get('imagesManifestSha256') == args.expected_images_manifest_sha, 'A Web reference is bound to another source packet or image manifest')
            self.natural.append(natural_reference(report, set(self.assets.values())))
            self.bound['webCase' + str(index)], self.binding['webCase' + str(index)] = filename, FRAME.sha(filename)
        self.index = self.case['sourceContent']['sourceCaseIndex']
        for name, filename in {'imageDriver': Path(__file__), 'imageManifest': manifest_path,
                'imageUI': ROOT / 'entry/src/main/ets/ui/StarwardQuestionImages.ets',
                'imageLoader': ROOT / 'entry/src/main/ets/platform/QuestionImageLoader.ets',
                'imageIO': ROOT / 'entry/src/main/ets/platform/QuestionImageIO.ets',
                'viewModel': ROOT / 'entry/src/main/ets/features/GameplayViewModel.ets',
                'index': ROOT / 'entry/src/main/ets/pages/Index.ets'}.items():
            self.bound[name], self.binding[name] = filename, FRAME.sha(filename)

    def specs(self):
        question, _ = self.question()
        result = []
        for block_index, block in enumerate(question['content']):
            for image_index, source in enumerate(body_sources(block)):
                require(source in self.assets and self.assets[source] in self.natural[self.index], 'A body image lacks the approved same-byte natural-size reference')
                result.append({'block': block_index, 'image': image_index, 'sourceSha256': self.assets[source],
                    'natural': self.natural[self.index][self.assets[source]], 'slot': f'question-images-{block_index}-{image_index}'})
        require(len(result) == (1, 1, 3)[self.index], 'The approved normal body-image scope is1/1/3 only')
        return result

    def reopen(self):
        before = len([row for row in self.ledger() if row.get('method') == 'GET' and row.get('path') == self.detail])
        self.ui.back()
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'same-case home before image GET resume')
        self.ui.tap('assignment-' + self.assignment_id)
        self.ui.wait(lambda ui: ui.find('gameplay-question-card') is not None and ui.find('gameplay-loading') is None, 'active image page resumes by GET')
        reads = [row for row in self.ledger() if row.get('method') == 'GET' and row.get('path') == self.detail][before:]
        require(len(reads) == 2 and all(row.get('status') == 200 for row in reads),
                'Natural-top image resume must issue the detail projection and gameplay snapshot GET200 pair')
        self.verify_ledger()

    def ready_images(self, specs):
        for item in specs:
            slot = item['slot']
            self.ui.seek(slot)
            self.ui.wait(lambda ui: ui.find(slot + '-error') is not None or
                         ui.find(slot + '-pixels') is not None and ui.find(slot + '-frame') is not None,
                         'registered body image decoder result', timeout=40)
            require(self.ui.find(slot + '-pixels') is not None and all(self.ui.find(slot + suffix) is None for suffix in
                    ('-loading', '-error', '-retry')), 'A body image did not reach real decoded pixels-ready state')

    def sample(self, theme):
        if self.states:
            self.reopen()  # Never use scroll_top after Refresh was introduced.
        specs = self.specs()
        before = len(self.ledger())
        self.ready_images(specs)
        measurements = []
        tolerance, density = 2 / self.ui.density, self.ui.density
        for item in reversed(specs):
            self.ui.seek(item['slot'] + '-frame')
            raw, evidence = self.ui.raw_app('body-image-' + str(item['block']) + '-' + str(item['image']) + '-' + theme)
            box = lambda node: UI.rect(FRAME.own(raw, node)['bounds'])
            group, cell = box('question-images-' + str(item['block'])), box(item['slot'])
            frame, pixels = box(item['slot'] + '-frame'), box(item['slot'] + '-pixels')
            group_width = (group[2] - group[0]) / density
            require(abs(group_width - 314) <= tolerance, 'The actual body image group width is not314vp')
            peers = [entry for entry in specs if entry['block'] == item['block']]
            plan, group_height, columns = image_plan(group_width, [entry['natural'] for entry in peers])
            expected = plan[item['image']]
            measured = {'frameWidth': (frame[2] - frame[0]) / density, 'frameHeight': (frame[3] - frame[1]) / density,
                'frameX': (frame[0] - group[0]) / density, 'rowY': (frame[1] - group[1]) / density,
                'cellWidth': (cell[2] - cell[0]) / density, 'cellX': (cell[0] - group[0]) / density}
            require(all(abs(measured[key] - expected[key]) <= tolerance for key in measured) and
                    abs((group[3] - group[1]) / density - group_height) <= tolerance, 'Natural-size/cap/centering/gallery geometry differs from its measured-width reference')
            require(all(abs(value / density - 1) <= tolerance for value in
                    (pixels[0] - frame[0], pixels[1] - frame[1], frame[2] - pixels[2], frame[3] - pixels[3])) and
                    UI.inside(frame, self.ui.viewport(item['slot'] + '-frame'), 2), 'The real decoded image lacks its1vp frame or complete viewport visibility')
            require(all(not any(row.get('id') == item['slot'] + suffix for row in raw) for suffix in ('-loading', '-error', '-retry')),
                    'A sampled image still exposes a loading or failed state')
            self.ui.private_shot('body-image-' + str(item['block']) + '-' + str(item['image']) + '-' + theme)
            measurements.append({'block': item['block'], 'image': item['image'], 'sourceSha256': item['sourceSha256'],
                'referenceNaturalWidthPx': item['natural'][0], 'referenceNaturalHeightPx': item['natural'][1],
                'groupWidthVp': group_width, 'columns': columns, 'expectedVp': expected, 'measuredVp': measured,
                'frameBoundsPx': frame, 'pixelsBoundsPx': pixels, 'rawSha256': evidence['sha256']})
        order = self.block_order(specs, theme)
        require(len(self.ledger()) == before, 'Read-only image positioning unexpectedly triggered an API request or Refresh')
        self.states.append({'themeRequested': theme, 'readyBodyImageCount': len(specs), 'images': sorted(measurements, key=lambda item: (item['block'], item['image'])),
                            'blockOrder': order, 'normalDisplayOnly': True})
        self.check(True, 'All expected normal body images decode before originals and retain natural-size gallery/order geometry')

    def block_order(self, specs, theme):
        question, _ = self.question()
        result, previous_end = [], None
        for index, block in enumerate(question['content']):
            targets = (['question-images-' + str(index)] if any(item['block'] == index for item in specs) else [])
            if block.get('text'): targets.append('question-content-text-' + str(index))
            if block.get('hint'): targets.append('question-hint-' + str(index))
            require(targets, 'An empty/video-only content block is outside this normal-image sample')
            last = targets[-1]
            if last.startswith('question-content-text-'): self.ui.reveal_text(last)
            elif last.startswith('question-hint-'): self.ui.seek(last)
            raw, _ = self.ui.raw_app('body-order-' + str(index) + '-' + theme)
            card = UI.rect(FRAME.own(raw, 'gameplay-question-card')['bounds'])
            boxes = [UI.rect(FRAME.own(raw, node)['bounds']) for node in targets]
            gaps = [(boxes[position][1] - boxes[position - 1][3]) / self.ui.density for position in range(1, len(boxes))]
            require(all(abs(value - 13) <= 2 / self.ui.density for value in gaps), 'Image/text/hint order or13vp spacing differs')
            first, end = (boxes[0][1] - card[1]) / self.ui.density, (boxes[-1][3] - card[1]) / self.ui.density
            block_gap = None if previous_end is None else first - previous_end
            require(block_gap is None or abs(block_gap - 20) <= 2 / self.ui.density, 'Content blocks do not retain20vp spacing')
            result.append({'block': index, 'elementOrder': ['images' if key.startswith('question-images-') else 'text' if key.startswith('question-content-text-') else 'hint' for key in targets],
                           'withinBlockGapsVp': gaps, 'previousBlockGapVp': block_gap})
            previous_end = end
        return result

    def main(self):
        super().main()  # Auth/entry/GET resume only; sample() above replaces all frame/type work.
        self.stage = 'normal-body-image-sample-complete'

    def execute(self):
        try:
            self.main()
        except Exception as error:
            reason = str(error)
            for secret in (self.case['newPassword'], self.state['controlToken'], self.token):
                if secret: reason = reason.replace(secret, '[credential omitted]')
            FRAME.write_private(self.directory / 'failure-diagnostic.json', {'stage': self.stage, 'exceptionType': type(error).__name__, 'reason': reason},
                                (self.case['newPassword'], self.state['controlToken'], self.token))
            self.failure = 'Normal body-image checks are incomplete; private diagnostics retained'
        finally:
            try:
                self.immutable()
                if self.device_started: self.logout(); self.verify_ledger()
            except Exception:
                self.failure = self.failure or 'Same-owner logout or zero-answer checks could not be confirmed'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not all(self.cleanup.values()): self.failure = self.failure or 'Narrow image cleanup is incomplete'
        evidence = FRAME.write_private(self.directory / 'request-ledger.json', getattr(self, 'final_ledger', {}), (self.case['newPassword'], self.state['controlToken'], self.token))
        report = {'status': 'incomplete' if self.failure else 'passed', 'scope': 'Normal decoded body-photo/gallery display only', 'stage': self.stage,
            'sourceCaseIndex': self.index, 'bodyImageCount': (1, 1, 3)[self.index], 'hapSha256': self.hap_sha, 'bindingSha256': self.binding,
            'expectedFixtureSha256': self.args.expected_fixture_sha, 'imagesManifestSha256': self.args.expected_images_manifest_sha,
            'checksPassed': len(self.checks), 'checks': self.checks, 'states': self.states, 'cleanup': self.cleanup,
            'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence, 'privateReadOnlyLedger': evidence,
            'sameDataWebFixture': getattr(self, 'fixture', None), 'failure': self.failure, 'visualReview': 'pending_root_original_review',
            'naturalDimensionSource': 'Registered source-byte SHA in the approved Web geometry.images', 'nativeDownloadSha256Observed': False,
            'referenceImagesDownloadedByHelper': False, 'fixedPreviewTouched': False,
            'excludedAcceptance': ['image failure/retry', 'cancellation/late image', 'choice images', 'image viewing', 'video/BGM', 'whole page'],
            'writeScope': 'Host authentication/read and the optional exact single native start only; no answer/profile/password/fault/reset',
            'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        secrets = [self.case_id, self.case['account'], self.case['newPassword'], self.case['playerId'], self.assignment_id,
                   self.case['assignments']['ready']['sessionId'], self.state['controlToken'], self.token, *self.assets]
        require(not any(value and value in encoded for value in secrets) and not re.search(r'https?://', encoded), 'A private image/account literal would enter the public report')
        FRAME.fresh(self.report, OUT); self.report.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream: stream.write(encoded)
        print(json.dumps({'status': report['status'], 'bodyImageCount': report['bodyImageCount'], 'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 1 if self.failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action'); run = sub.add_parser('run')
    for name in ('runtime', 'case-ref', 'output', 'private-dir', 'images-manifest', 'web-case0', 'web-case1', 'web-case2'):
        run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-hap', 'expected-fixture-sha', 'expected-images-manifest-sha'): run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if not args.action: parser.print_help(); return 0
    try: return Images(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded', 'error': 'Exact image/reference/environment guards failed; raw values omitted'})); return 1


if __name__ == '__main__':
    sys.exit(main())

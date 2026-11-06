#!/usr/bin/env python3
"""Read-only completed-choice Web reference; default/help/plan is inert.

Run consumes the explicit real post-submit private DTO. Only owned headless Web
rendering and registered image-byte replay occur. Public output deliberately
omits the correct key, selected index/vector, per-option geometry and answer hash.
No select, media-open, submit, backend, device or service operation is performed.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import types
from urllib.parse import quote, urlparse

ROOT = Path(__file__).resolve().parents[1]
NORMAL_SHA = 'c4f59152ba5aca19a97e45e47caa8a502af9974756d13f8e363a98e522f8e3e9'
FIXTURE_SHA = '1ad7a59cc1f13e6dd7ec5550c8f5ab4a5906b90f9a9b56ac948143a4995e8745'
PLAN = {'scope': 'Real completed case1 DTO, readonly single choice question and disabled thumbnails',
    'themes': ['light', 'dark'], 'width': 376, 'height': 742, 'fontScale': 1, 'hasTouch': True,
    'statesPerTheme': ['completed-answer', 'completed-tail'], 'publicSelectionAndGeometryOmitted': True,
    'syntheticAuthentication': True, 'syntheticCompletion': False, 'businessAcceptance': False,
    'limitations': ['Real post-submit DTO replay only; no new completion or backend request',
        'No selecting, submit, image opening, gesture, playback, Native UI or disabled-touch interaction']}


def require(value):
    if not value:
        raise ValueError('The explicit readonly completed-reference boundary did not hold')


def load():
    source = ROOT / 'scripts/capture-web-choice-options.py'; data = source.read_bytes()
    require(hashlib.sha256(data).hexdigest() == NORMAL_SHA)
    normal = types.ModuleType('completed_choice_normal_helpers'); normal.__file__ = str(source)
    exec(compile(data, str(source), 'exec'), normal.__dict__)
    frame, path, frame_bytes = normal.helpers()
    return normal, source, data, frame, path, frame_bytes


def completed_fixtures(value):
    require(isinstance(value, dict) and set(value) == {'player', 'assignments', 'assignment'})
    player, scene, listing = value['player'], value['assignment'], value['assignments']
    require(all(isinstance(item, dict) for item in (player, scene, listing)) and
        re.fullmatch(r'hm_[a-f0-9]{12}', player.get('account', '')) and player.get('mustChangePassword') is False and
        re.fullmatch(r'[a-z0-9]{15}', player.get('id', '')) and player.get('totalXp') == 50 and
        re.fullmatch(r'[a-z0-9]{15}', scene.get('id', '')) and scene.get('player') == player['id'] and
        scene.get('status') == 'completed' and bool(scene.get('startedAt')) and bool(scene.get('completedAt')) and
        scene.get('currentIndex') == 0 and scene.get('completedLevels') == scene.get('totalLevels') == 1 and
        isinstance(scene.get('levels'), list) and len(scene['levels']) == 1 and
        isinstance(listing.get('items'), list) and len(listing['items']) == 1)
    summary, level = listing['items'][0], scene['levels'][0]
    require(isinstance(summary, dict) and summary.get('id') == scene['id'] and summary.get('player') == player['id'] and
        summary.get('status') == 'completed' and summary.get('completedLevels') == summary.get('totalLevels') == 1 and
        bool(summary.get('completedAt')) and isinstance(level, dict) and bool(level.get('completedAt')) and
        level.get('wrongCount') == 0 and level.get('locked') is False and not level.get('cooldownUntil') and
        level.get('xp') == 50 and level.get('autoNext') is False and re.fullmatch(r'[A-D]', level.get('lastAnswer', '')))
    question = level.get('question'); require(isinstance(question, dict) and question.get('kind') == 'choice')
    options = question.get('options'); require(isinstance(options, list) and len(options) == 4 and
        [row.get('key') for row in options] == ['A', 'B', 'C', 'D'] and
        all(isinstance(row.get('text'), str) and not row.get('videoUrl') for row in options) and
        all(isinstance(row.get('imageUrl'), str) and bool(row['imageUrl']) == (i < 3) for i, row in enumerate(options)))
    def no_auth(item):
        if isinstance(item, dict):
            require(not any(str(key).lower() in ('token', 'password', 'authorization', 'controltoken', 'answerkey') for key in item))
            for child in item.values(): no_auth(child)
        elif isinstance(item, list):
            for child in item: no_auth(child)
    no_auth(value)
    return player, scene, listing, options


def capture(args):
    normal, normal_path, normal_bytes, frame, frame_path, frame_bytes = load()
    boundary, sha = frame.BOUNDARY, frame.sha
    require(args.url == normal.BASE_URL and args.expected_fixture_sha == FIXTURE_SHA and
        all(re.fullmatch(r'[a-f0-9]{64}', v or '') for v in (args.expected_dto_sha, args.expected_images_manifest_sha)))
    own_bytes = Path(__file__).read_bytes(); web = args.web_source.absolute().resolve(); boundary.frozen_check(web)
    snapshot = frame.private_input(args.fixtures_json); snapshot_bytes = snapshot.read_bytes()
    require(sha(snapshot_bytes) == args.expected_dto_sha)
    value = json.loads(snapshot_bytes); player, scene, listing, options = completed_fixtures(value)
    sources = {p: (web / p).read_bytes() for p in dict.fromkeys((*frame.SOURCES, *normal.EXTRA_SOURCES))}
    images_path = frame.private_input(args.images_manifest); images_bytes, assets = frame.image_assets(images_path, FIXTURE_SHA)
    require(sha(images_bytes) == args.expected_images_manifest_sha and len(assets) == 8 and all(row['imageUrl'] in assets for row in options[:3]))
    for asset in assets.values(): asset['replayMime'] = 'image/png' if asset['data'].startswith(b'\x89PNG\r\n\x1a\n') else 'image/jpeg'
    font = boundary.path_in(args.font_file, ROOT / 'entry/src/main/resources', True); font_bytes = font.read_bytes()
    require(font == frame.NATIVE_FONT and sha(font_bytes) == normal.FONT_SHA)
    output = boundary.path_in(args.output_dir, frame.PRIVATE); manifest = boundary.path_in(args.manifest, frame.PUBLIC)
    require(not output.exists() and not manifest.exists()); boundary.fresh_directory(output)
    boundary.private_write(output / 'completed-input-dtos.json', snapshot_bytes)
    report = {'status': 'incomplete', 'plan': PLAN, 'helperSha256': sha(own_bytes), 'normalHelperSha256': NORMAL_SHA,
        'frameHelperSha256': normal.FRAME_SHA, 'boundaryHelperSha256': frame.BOUNDARY_SHA, 'sourceCommit': normal.FROZEN,
        'expectedFixtureSha256': FIXTURE_SHA, 'dtoSha256': sha(snapshot_bytes), 'imagesManifestSha256': sha(images_bytes),
        'sourceSha256': {p: sha(data) for p, data in sources.items()}, 'fontSha256': normal.FONT_SHA,
        'registeredImageSha256': sorted({asset['sha256'] for asset in assets.values()}),
        'registeredMimeReplay': [{'sourceSha256': a['sha256'], 'originalHttpMime': a['mime'], 'replayedDetectedMime': a['replayMime']} for a in assets.values()],
        'realCompletedDto': True, 'syntheticAuthentication': True, 'syntheticCompletion': False,
        'backendRequestsContinued': 0, 'externalRequestsContinued': 0, 'businessAcceptance': False, 'nativeAcceptance': False,
        'correctAnswerOrSelectionPublished': False, 'visualReview': 'pending_root_original_review', 'states': [], 'checks': [],
        'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    raw = {key: [] for key in ('apis', 'blocked', 'imagesReplayed', 'unexpectedApis', 'routeFailures', 'pageErrors', 'consoleErrors')}
    raw['webSocketsBlocked'] = 0
    source_checks, schema_checks, font_checks, failure = [], [], [], None
    try:
        package = frame.PRIVATE / 'python-playwright'
        if package.is_dir(): sys.path.insert(0, str(package))
        from playwright.sync_api import sync_playwright
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True, timeout=30000, args=['--disable-background-networking'])
            try:
                for theme in ('light', 'dark'):
                    sample(browser, theme, normal, frame, args, web, value, player, scene, listing, options, assets,
                           font_bytes, sources, output, report, raw, source_checks, schema_checks, font_checks)
            finally: browser.close()
        boundary.frozen_check(web)
        require(Path(__file__).read_bytes() == own_bytes and normal_path.read_bytes() == normal_bytes and frame_path.read_bytes() == frame_bytes and
            sha((ROOT / 'scripts/capture-web-ui-sample.py').read_bytes()) == frame.BOUNDARY_SHA and
            snapshot.read_bytes() == snapshot_bytes and images_path.read_bytes() == images_bytes and font.read_bytes() == font_bytes and
            all(a['source'].read_bytes() == a['data'] for a in assets.values()) and all((web / p).read_bytes() == data for p, data in sources.items()))
        require(not any(raw[k] for k in ('unexpectedApis', 'routeFailures', 'pageErrors')) and schema_checks == [True] * 6 and
            len(source_checks) == len(sources) * 2 and all(source_checks) and len(font_checks) >= 2 and len(report['states']) == 4 and len(report['checks']) == 2)
        report['status'] = 'captured_web_completed_choice_reference'
    except Exception as error:
        raw['failure'] = {'type': type(error).__name__, 'message': str(error)}
        failure = 'The guarded completed Web reference is incomplete; private originals retained'
    finally:
        path = output / 'browser-private.json'
        report['privateBrowserEvidence'] = {'file': str(path.relative_to(ROOT)), 'sha256': boundary.private_write(path, raw)}
        report['counts'] = {k: len(v) if isinstance(v, list) else v for k, v in raw.items() if k != 'failure'}
        report['counts'].update({'states': len(report['states']), 'checks': len(report['checks']), 'schemaChecks': len(schema_checks),
            'servedSourceChecks': len(source_checks), 'fontRequestsReplayed': len(font_checks)})
        if failure: report['failure'] = failure
        encoded = (json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
        literals = set(assets).union(frame.private_literals(value))
        require(not re.search(rb'https?://', encoded) and not any(item.encode() in encoded if len(item) >= 5 else
            ('"' + item + '"').encode() in encoded for item in literals))
        boundary.path_in(manifest, frame.PUBLIC); manifest.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(manifest, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'wb') as stream: stream.write(encoded)
    print(json.dumps({'status': report['status'], 'states': len(report['states']), 'manifestSha256': sha(encoded)}), flush=True)
    return 1 if failure else 0


def sample(browser, theme, normal, frame, args, web, value, player, scene, listing, options, assets,
           font_bytes, sources, output, report, raw, source_checks, schema_checks, font_checks):
    boundary, sha, bounded = frame.BOUNDARY, frame.sha, frame.bounded
    context = browser.new_context(viewport={'width': 376, 'height': 742}, device_scale_factor=1, has_touch=True, is_mobile=True,
        color_scheme=theme, reduced_motion='reduce', locale='zh-CN', timezone_id='Asia/Shanghai', service_workers='block', accept_downloads=False)
    detail = '/api/questions/v1/assignments/' + scene['id']
    routes = (frame.AUTH, '/api/files/token', '/api/questions/v1/me', '/api/questions/v1/assignments', detail,
              '/api/questions/v1/notifications', '/api/questions/v1/rewards')
    cors = {'Access-Control-Allow-Origin': normal.BASE_URL, 'Access-Control-Allow-Headers': 'Authorization,Content-Type,Accept',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'}
    def intercept(route):
        request, parsed = route.request, urlparse(route.request.url); origin = parsed.scheme + '://' + parsed.netloc
        if request.url in assets and request.method == 'GET' and request.resource_type == 'image':
            require(not request.headers.get('authorization')); asset = assets[request.url]
            raw['imagesReplayed'].append({'theme': theme, 'url': request.url, 'sha256': asset['sha256']})
            route.fulfill(status=200, content_type=asset['replayMime'], body=asset['data'])
        elif parsed.path.startswith('/api/'):
            raw['apis'].append({'theme': theme, 'method': request.method, 'url': request.url})
            if origin == frame.API_ORIGIN and not parsed.query and request.method == 'OPTIONS' and parsed.path in routes:
                route.fulfill(status=204, headers=cors, body=''); return
            response = None
            if origin == frame.API_ORIGIN and not parsed.query:
                if request.method == 'POST' and parsed.path == frame.AUTH:
                    require(request.post_data_json == {'identity': player['account'], 'password': frame.PASSWORD})
                    response = {'token': frame.TOKEN, 'record': {'id': player['id']}}
                elif request.headers.get('authorization') == frame.TOKEN:
                    if request.method == 'GET' and parsed.path == '/api/questions/v1/me': response = player
                    elif request.method == 'GET' and parsed.path == '/api/questions/v1/assignments': response = listing
                    elif request.method == 'GET' and parsed.path == detail: response = scene
                    elif request.method == 'GET' and parsed.path in routes[-2:]: response = {'items': []}
                    elif request.method == 'POST' and parsed.path == '/api/files/token': response = {'token': 'completed-choice-render-file-token'}
            if response is None:
                key = 'blocked' if request.method == 'GET' and parsed.path.startswith('/api/files/game_players/') else 'unexpectedApis'
                raw[key].append({'theme': theme, 'method': request.method, 'url': request.url})
                route.fulfill(status=404, headers=cors, content_type='application/json', body='{"error":{"code":"REPLAY_NOT_CONFIGURED"}}')
            else: route.fulfill(status=200, headers=cors, content_type='application/json', body=json.dumps(response, ensure_ascii=False))
        elif request.method == 'GET' and origin == normal.BASE_URL and parsed.path == frame.FONT_ROUTE and not parsed.query:
            font_checks.append(normal.FONT_SHA); route.fulfill(status=200, content_type='font/ttf', body=font_bytes)
        elif boundary.source_request(request.method, request.url, request.resource_type, normal.BASE_URL, scene['id'], web): route.continue_()
        else:
            raw['blocked'].append({'theme': theme, 'kind': request.resource_type, 'url': request.url}); route.abort()
    def guarded(route):
        try: intercept(route)
        except Exception as error:
            raw['routeFailures'].append({'type': type(error).__name__, 'message': str(error)})
            try: route.abort()
            except Exception: pass
    try:
        context.route('**/*', guarded); require(hasattr(context, 'route_web_socket'))
        def no_socket(_socket): raw['webSocketsBlocked'] += 1
        context.route_web_socket('**/*', no_socket)
        page = context.new_page(); page.set_default_timeout(15000); page.set_default_navigation_timeout(30000)
        page.on('pageerror', lambda error: raw['pageErrors'].append(str(error)))
        page.on('console', lambda msg: raw['consoleErrors'].append(msg.text) if msg.type == 'error' else None)
        page.goto(normal.BASE_URL + '/login?theme=' + theme, wait_until='networkidle')
        for relative, data in sources.items():
            served = bounded(page, 'return (await import(arg+"?raw")).default;', '/' + relative)
            source_checks.append(isinstance(served, str) and sha(served.encode()) == sha(data)); require(source_checks[-1])
        checks = bounded(page, '''const m=await import('/src/api/game.schema.ts');return [m.gamePlayerSchema.safeParse(arg.player).success,
          m.gameAssignmentSchema.safeParse(arg.assignment).success,m.gameAssignmentSummarySchema.array().safeParse(arg.assignments.items).success];''', value)
        schema_checks.extend(checks); require(checks == [True, True, True])
        page.get_by_label('登录账号', exact=True).fill(player['account']); page.get_by_label('密码', exact=True).fill(frame.PASSWORD)
        page.get_by_role('button', name='进入冒险', exact=True).click()
        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
        page.goto(normal.BASE_URL + '/play/' + quote(scene['id'], safe='') + '?theme=' + theme, wait_until='networkidle')
        page.locator('.quest-card .choice-list').wait_for(state='visible')
        require(page.locator('.quest-card').count() == 1 and page.locator('.quest-layout.quest-desktop').count() == 0)
        bgm = page.get_by_role('button', name='关闭背景音乐提示', exact=True)
        if bgm.count(): bgm.click(); bgm.wait_for(state='detached')
        page.add_style_tag(content='@font-face{font-family:StarwardQuestionFrameSerif;src:url("' + normal.BASE_URL + frame.FONT_ROUTE +
            '") format("truetype");font-weight:100 900;font-style:normal;font-display:block}:root{--font-display:StarwardQuestionFrameSerif,serif!important}')
        require(bounded(page, 'return (await document.fonts.load("37.6px StarwardQuestionFrameSerif")).length>0;'))
        cards = page.locator('.quest-card .choice-list > .choice-option'); require(cards.count() == 4)
        for i in range(3):
            image = cards.nth(i).locator('.choice-media-button img'); image.scroll_into_view_if_needed()
            page.wait_for_function('(el)=>el.complete&&el.naturalWidth>0&&el.naturalHeight>0', arg=image.element_handle())
            require(image.evaluate('(el)=>el.currentSrc||el.src') == options[i]['imageUrl'])
        api_count = len(raw['apis']); expected_answer = scene['levels'][0]['lastAnswer']
        selected_index = next(i for i, row in enumerate(options) if row['key'] == expected_answer)  # Private only.
        for position, index in (('completed-answer', selected_index), ('completed-tail', 3)):
            cards.nth(index).scroll_into_view_if_needed()
            bounded(page, 'await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));return true;')
            measured = page.evaluate(normal.MEASURE); rows, cond = measured['rows'], measured['conditions']
            require(cond['width'] == 376 and cond['height'] == 742 and cond['dpr'] == 1 and cond['coarsePointer'] and cond['hasTouch'] and
                cond['theme'] == theme and cond['documentInlineZoom'] == '1' and cond['visualViewportScale'] == 1 and
                cond['scrollWidth'] <= 376 and not cond['mediaPlaying'] and not measured['viewer']['present'])
            require(len(rows) == 4 and all(row['private']['radioEffectiveDisabled'] is True for row in rows) and
                all(row['private']['mediaEffectiveDisabled'] is True for row in rows[:3]) and rows[3]['image'] is None and
                sum(row['checked'] for row in rows) == 1 and sum(row['selected'] for row in rows) == 1 and
                all(row['checked'] == row['selected'] == (row['private']['radioValue'] == expected_answer) for row in rows))
            for i, row in enumerate(rows):
                geo = row['geometry']; require(geo['card']['layoutWidth'] == 314 and geo['card']['borderRadius'] == 0 and geo['label']['layoutHeight'] >= 58)
                if i < 3: require(geo['media']['layoutHeight'] == 130 and geo['image']['objectFit'] == 'cover' and row['image']['complete'])
            stem = theme + '-' + position
            png, rawfile, dom = output / (stem + '.png'), output / (stem + '.json'), output / (stem + '.html')
            png_sha = boundary.private_write(png, page.screenshot(full_page=False, animations='disabled'))
            raw_sha = boundary.private_write(rawfile, measured); dom_sha = boundary.private_write(dom, page.content().encode())
            report['states'].append({'theme': theme, 'position': position, 'conditions': cond, 'radioCount': 4,
                'disabledRadioCount': 4, 'disabledThumbnailCount': 3, 'oneSelectionMatchesAuthoritativeLastAnswer': True,
                'allOptionGeometryMatched': True, 'viewerAbsent': True,
                'screenshot': {'file': str(png.relative_to(ROOT)), 'sha256': png_sha},
                'privateMeasurements': {'file': str(rawfile.relative_to(ROOT)), 'sha256': raw_sha}, 'privateDom': {'file': str(dom.relative_to(ROOT)), 'sha256': dom_sha}})
        require(len(raw['apis']) == api_count)
        report['checks'].append({'theme': theme, 'fourRadiosAndThreeThumbnailsEffectivelyDisabled': True,
            'oneReadonlySelectionMatchesAuthoritativeLastAnswer': True, 'noSelectOpenOrSubmitAttempted': True, 'noAdditionalApiRequest': True})
    finally: context.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest='action')
    sub.add_parser('plan'); run = sub.add_parser('run')
    run.add_argument('--url', default='http://127.0.0.1:5178'); run.add_argument('--web-source', type=Path, default=ROOT.parent / 'questions-web')
    run.add_argument('--font-file', type=Path, default=ROOT / 'entry/src/main/resources/rawfile/fonts/NotoSerifSC.ttf')
    for name in ('fixtures-json', 'images-manifest', 'output-dir', 'manifest'): run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-dto-sha', 'expected-fixture-sha', 'expected-images-manifest-sha'): run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if args.action is None: parser.print_help(); return 0
    if args.action == 'plan': print(json.dumps(PLAN, ensure_ascii=False, indent=2)); return 0
    try: return capture(args)
    except Exception:
        print(json.dumps({'status': 'not_captured_or_report_guarded', 'error': 'Explicit completed DTO/source/image/font/output/browser prerequisites failed; values omitted'})); return 1


if __name__ == '__main__':
    sys.exit(main())

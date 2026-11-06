#!/usr/bin/env python3
"""Frozen Web choice-option render reference; default/help/plan is inert.

Explicit run alone launches an owned headless browser. It replays one real
case1 DTO and registered image bytes; authentication/auxiliary APIs are synthetic.
All backend/external traffic is blocked. No business or Native acceptance is made.
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
FRAME_SHA = '12f9b6563ebb95cc141043e966c009375873de0b8de764df9a0308ecf4ae520f'
FONT_SHA = '050080d9255a86808f2945bffac582b31ef32bc36411ce29563b4961670c66f9'
FROZEN = '4b7d1a0a00051ac630e459b0fd6c074f821d7455'
BASE_URL = 'http://127.0.0.1:5178'
EXTRA_SOURCES = ('src/features/media/MediaViewer.tsx', 'src/features/media/ZoomableImage.tsx',
    'src/features/game/useGamePresentation.ts', 'src/styles/components/media-viewer.css',
    'src/styles/components/media-backdrop.css')
PLAN = {'scope': 'Case1 four choice options: A/B/C image thumbnails, D text only',
    'sourceCommit': FROZEN, 'width': 376, 'height': 742, 'fontScale': 1,
    'hasTouch': True, 'themes': ['light', 'dark'],
    'statesPerTheme': ['unselected-A', 'unselected-C', 'unselected-D', 'selected-A',
                       'selected-B', 'B-selected-A-image-open', 'B-selected-A-image-closed'],
    'completedDisabledCapture': False, 'businessAcceptance': False, 'nativeAcceptance': False,
    'limitations': ['Synthetic login and auxiliary replies; real same-data DTO and original registered image-byte replay',
        'No external download, live Referer policy, answer submission, completion, pinch or Native device operation',
        'Completed/pending/cooldown/locked states are source-reviewed only and not rendered in this narrow sample']}
PLAN_SHA = hashlib.sha256(json.dumps(PLAN, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def require(value):
    if not value:
        raise ValueError('The explicit frozen choice reference boundary did not hold')


def helpers():
    path = ROOT / 'scripts/capture-web-question-frame.py'
    data = path.read_bytes(); require(hashlib.sha256(data).hexdigest() == FRAME_SHA)
    module = types.ModuleType('choice_frame_reference'); module.__file__ = str(path)
    exec(compile(data, str(path), 'exec'), module.__dict__)
    return module, path, data


MEASURE = r"""() => {
  const list=document.querySelector('.quest-card .choice-list'), options=list?Array.from(list.children):[];
  const rect=el=>{if(!el)return {present:false};const b=el.getBoundingClientRect(),s=getComputedStyle(el),
    num=v=>Number.isFinite(parseFloat(v))?parseFloat(v):null;
    return {present:true,x:b.x,y:b.y,width:b.width,height:b.height,layoutWidth:el.offsetWidth,layoutHeight:el.offsetHeight,
      documentY:b.y+scrollY,visible:s.display!=='none'&&s.visibility!=='hidden'&&b.width>0&&b.height>0,
      paddingTop:num(s.paddingTop),paddingRight:num(s.paddingRight),paddingBottom:num(s.paddingBottom),paddingLeft:num(s.paddingLeft),
      fontSize:num(s.fontSize),lineHeight:num(s.lineHeight),borderTopWidth:num(s.borderTopWidth),borderLeftWidth:num(s.borderLeftWidth),
      borderRadius:num(s.borderTopLeftRadius),background:s.backgroundColor,borderColor:s.borderTopColor,
      color:s.color,transform:s.transform,objectFit:s.objectFit,gridTemplateColumns:s.gridTemplateColumns};};
  const rows=options.map((el,i)=>{const radio=el.querySelector('input[type=radio]'),label=el.querySelector('label'),
    key=label?.querySelector('strong'),text=label?.querySelector('span'),button=el.querySelector('.choice-media-button'),image=button?.querySelector('img')||null;
    return {index:i,selected:el.classList.contains('is-selected'),checked:!!radio?.checked,disabled:!!radio?.disabled,
      sameRadio:!window.__starwardChoiceRadios||radio===window.__starwardChoiceRadios[i],
      sameImage:!window.__starwardChoiceImages||image===window.__starwardChoiceImages[i],
      geometry:{card:rect(el),label:rect(label),key:rect(key),text:rect(text),media:rect(button),image:rect(image)},
      image:image?{url:image.currentSrc||image.src,complete:image.complete,naturalWidth:image.naturalWidth,naturalHeight:image.naturalHeight}:null,
      private:{radioId:radio?.id,radioName:radio?.name,radioValue:radio?.value,key:key?.textContent,text:text?.textContent,
        mediaLabel:button?.getAttribute('aria-label'),radioEffectiveDisabled:radio?.matches(':disabled'),
        mediaEffectiveDisabled:button?button.matches(':disabled'):null}};});
  const modal=document.querySelector('.media-viewer-backdrop .media-viewer'),image=modal?.querySelector('.media-viewer-stage--zoom > img');
  return {conditions:{width:innerWidth,height:innerHeight,dpr:devicePixelRatio,coarsePointer:matchMedia('(pointer:coarse)').matches,
      hasTouch:navigator.maxTouchPoints>0,theme:document.documentElement.dataset.theme,scrollWidth:document.documentElement.scrollWidth,
      documentInlineZoom:document.documentElement.style.zoom||'1',visualViewportScale:visualViewport?.scale||1,
      mediaPlaying:Array.from(document.querySelectorAll('video,audio')).some(el=>!el.paused)},
    list:{...rect(list),gap:list?parseFloat(getComputedStyle(list).rowGap):null},rows,
    viewer:{present:!!modal,navigationPresent:!!modal?.querySelector('.media-viewer-navigation'),
      image:image?{url:image.currentSrc||image.src,complete:image.complete,naturalWidth:image.naturalWidth,naturalHeight:image.naturalHeight}:null,
      stage:rect(modal?.querySelector('.media-viewer-stage--zoom')),percentage:modal?.querySelector('.media-viewer-zoom output')?.textContent.trim()},
    private:{bodyText:document.body.innerText}};
}"""


def capture(args):
    frame, helper_path, helper_bytes = helpers(); boundary, sha = frame.BOUNDARY, frame.sha
    require(args.url == BASE_URL and all(re.fullmatch(r'[a-f0-9]{64}', s or '') for s in
        (args.expected_dto_sha, args.expected_fixture_sha, args.expected_images_manifest_sha)))
    own_bytes = Path(__file__).read_bytes(); web = args.web_source.absolute().resolve(); boundary.frozen_check(web)
    sources = {name: (web / name).read_bytes() for name in dict.fromkeys((*frame.SOURCES, *EXTRA_SOURCES))}
    snapshot = frame.private_input(args.fixtures_json); snapshot_bytes = snapshot.read_bytes()
    require(sha(snapshot_bytes) == args.expected_dto_sha)
    value = json.loads(snapshot_bytes); player, scene, listing, _hidden = frame.fixtures(value)
    question = scene['levels'][0]['question']; options = question.get('options', [])
    require(question.get('kind') == 'choice' and isinstance(options, list) and len(options) == 4 and
        [row.get('key') for row in options] == ['A', 'B', 'C', 'D'] and
        all(isinstance(row.get('text'), str) and not row.get('videoUrl') for row in options) and
        all(isinstance(row.get('imageUrl'), str) and bool(row['imageUrl']) == (i < 3) for i, row in enumerate(options)))
    images_path = frame.private_input(args.images_manifest); images_bytes, assets = frame.image_assets(images_path, args.expected_fixture_sha)
    require(sha(images_bytes) == args.expected_images_manifest_sha and len(assets) == 8 and all(row['imageUrl'] in assets for row in options[:3]))
    for asset in assets.values():
        asset['replayMime'] = 'image/png' if asset['data'].startswith(b'\x89PNG\r\n\x1a\n') else 'image/jpeg'
    font = boundary.path_in(args.font_file, ROOT / 'entry/src/main/resources', True); font_bytes = font.read_bytes()
    require(font == frame.NATIVE_FONT and sha(font_bytes) == FONT_SHA)
    output = boundary.path_in(args.output_dir, frame.PRIVATE); manifest = boundary.path_in(args.manifest, frame.PUBLIC)
    require(not output.exists() and not manifest.exists()); boundary.fresh_directory(output)
    boundary.private_write(output / 'input-dtos.json', snapshot_bytes)
    report = {'status': 'incomplete', 'scope': PLAN['scope'], 'plan': PLAN, 'planSha256': PLAN_SHA,
        'sourceCommit': FROZEN, 'helperSha256': sha(own_bytes), 'frameHelperSha256': FRAME_SHA,
        'boundaryHelperSha256': frame.BOUNDARY_SHA, 'expectedFixtureSha256': args.expected_fixture_sha,
        'dtoSha256': sha(snapshot_bytes), 'imagesManifestSha256': sha(images_bytes), 'fontSha256': FONT_SHA,
        'sourceSha256': {name: sha(data) for name, data in sources.items()},
        'registeredImageSha256': sorted({asset['sha256'] for asset in assets.values()}),
        'registeredMimeReplay': [{'sourceSha256': asset['sha256'], 'originalHttpMime': asset['mime'],
            'replayedDetectedMime': asset['replayMime']} for asset in assets.values()],
        'syntheticAuthentication': True, 'businessAcceptance': False, 'nativeAcceptance': False,
        'backendRequestsContinued': 0, 'externalRequestsContinued': 0, 'visualReview': 'pending_root_original_review',
        'states': [], 'checks': [], 'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
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
                    sample(browser, theme, frame, args, web, value, player, scene, listing, options, assets,
                           font_bytes, sources, output, report, raw, source_checks, schema_checks, font_checks)
            finally: browser.close()
        boundary.frozen_check(web)
        require(Path(__file__).read_bytes() == own_bytes and helper_path.read_bytes() == helper_bytes and
            sha((ROOT / 'scripts/capture-web-ui-sample.py').read_bytes()) == frame.BOUNDARY_SHA and
            snapshot.read_bytes() == snapshot_bytes and images_path.read_bytes() == images_bytes and font.read_bytes() == font_bytes and
            all(asset['source'].read_bytes() == asset['data'] for asset in assets.values()) and
            all((web / name).read_bytes() == data for name, data in sources.items()))
        require(not any(raw[key] for key in ('unexpectedApis', 'routeFailures', 'pageErrors')) and
            len(source_checks) == len(sources) * 2 and all(source_checks) and schema_checks == [True] * 6 and
            len(font_checks) >= 2 and len(report['states']) == 14 and len(report['checks']) == 2)
        report['status'] = 'captured_web_choice_reference'
    except Exception as error:
        raw['failure'] = {'type': type(error).__name__, 'message': str(error)}
        failure = 'The guarded Web choice reference is incomplete; private originals retained'
    finally:
        evidence = output / 'browser-private.json'
        report['privateBrowserEvidence'] = {'file': str(evidence.relative_to(ROOT)), 'sha256': boundary.private_write(evidence, raw)}
        report['counts'] = {key: len(val) if isinstance(val, list) else val for key, val in raw.items() if key != 'failure'}
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


def sample(browser, theme, frame, args, web, value, player, scene, listing, options, assets,
           font_bytes, sources, output, report, raw, source_checks, schema_checks, font_checks):
    boundary, sha, bounded = frame.BOUNDARY, frame.sha, frame.bounded
    context = browser.new_context(viewport={'width': 376, 'height': 742}, device_scale_factor=1, has_touch=True, is_mobile=True,
        color_scheme=theme, reduced_motion='reduce', locale='zh-CN', timezone_id='Asia/Shanghai', service_workers='block', accept_downloads=False)
    detail = '/api/questions/v1/assignments/' + scene['id']
    routes = (frame.AUTH, '/api/files/token', '/api/questions/v1/me', '/api/questions/v1/assignments', detail,
              '/api/questions/v1/notifications', '/api/questions/v1/rewards')
    cors = {'Access-Control-Allow-Origin': BASE_URL, 'Access-Control-Allow-Headers': 'Authorization,Content-Type,Accept',
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
                    elif request.method == 'POST' and parsed.path == '/api/files/token': response = {'token': 'choice-render-file-token'}
            if response is None:
                key = 'blocked' if request.method == 'GET' and parsed.path.startswith('/api/files/game_players/') else 'unexpectedApis'
                raw[key].append({'theme': theme, 'method': request.method, 'url': request.url})
                route.fulfill(status=404, headers=cors, content_type='application/json', body='{"error":{"code":"REPLAY_NOT_CONFIGURED"}}')
            else: route.fulfill(status=200, headers=cors, content_type='application/json', body=json.dumps(response, ensure_ascii=False))
        elif request.method == 'GET' and origin == BASE_URL and parsed.path == frame.FONT_ROUTE and not parsed.query:
            font_checks.append(FONT_SHA); route.fulfill(status=200, content_type='font/ttf', body=font_bytes)
        elif boundary.source_request(request.method, request.url, request.resource_type, BASE_URL, scene['id'], web): route.continue_()
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
        page.goto(BASE_URL + '/login?theme=' + theme, wait_until='networkidle')
        for name, data in sources.items():
            served = bounded(page, 'return (await import(arg+"?raw")).default;', '/' + name)
            source_checks.append(isinstance(served, str) and sha(served.encode()) == sha(data)); require(source_checks[-1])
        checks = bounded(page, '''const m=await import('/src/api/game.schema.ts');return [m.gamePlayerSchema.safeParse(arg.player).success,
          m.gameAssignmentSchema.safeParse(arg.assignment).success,m.gameAssignmentSummarySchema.array().safeParse(arg.assignments.items).success];''', value)
        schema_checks.extend(checks); require(checks == [True, True, True])
        page.get_by_label('登录账号', exact=True).fill(player['account']); page.get_by_label('密码', exact=True).fill(frame.PASSWORD)
        page.get_by_role('button', name='进入冒险', exact=True).click()
        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
        page.goto(BASE_URL + '/play/' + quote(scene['id'], safe='') + '?theme=' + theme, wait_until='networkidle')
        page.locator('.quest-card .choice-list').wait_for(state='visible')
        require(page.locator('.quest-card').count() == 1 and page.locator('.quest-layout.quest-desktop').count() == 0)
        bgm = page.get_by_role('button', name='关闭背景音乐提示', exact=True)
        if bgm.count(): bgm.click(); bgm.wait_for(state='detached')
        page.add_style_tag(content='@font-face{font-family:StarwardQuestionFrameSerif;src:url("' + BASE_URL + frame.FONT_ROUTE +
            '") format("truetype");font-weight:100 900;font-style:normal;font-display:block}:root{--font-display:StarwardQuestionFrameSerif,serif!important}')
        require(bounded(page, 'return (await document.fonts.load("37.6px StarwardQuestionFrameSerif")).length>0;'))
        cards = page.locator('.quest-card .choice-list > .choice-option'); require(cards.count() == 4)
        for i in range(3):
            image = cards.nth(i).locator('.choice-media-button img'); image.scroll_into_view_if_needed()
            page.wait_for_function('(el)=>el.complete&&el.naturalWidth>0&&el.naturalHeight>0', arg=image.element_handle())
            require(image.evaluate('(el)=>el.currentSrc||el.src') == options[i]['imageUrl'])
        page.evaluate('''() => {window.__starwardChoiceRadios=Array.from(document.querySelectorAll('.quest-card .choice-list input[type=radio]'));
          window.__starwardChoiceImages=Array.from(document.querySelectorAll('.quest-card .choice-list > .choice-option')).map(el=>el.querySelector('img'));}''')
        api_count = len(raw['apis'])
        def record(position, selected=-1, viewer=False):
            bounded(page, 'await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));return true;')
            measured = page.evaluate(MEASURE); rows, cond = measured['rows'], measured['conditions']
            require(cond['width'] == 376 and cond['height'] == 742 and cond['dpr'] == 1 and cond['coarsePointer'] and cond['hasTouch'] and
                cond['theme'] == theme and cond['documentInlineZoom'] == '1' and cond['visualViewportScale'] == 1 and
                cond['scrollWidth'] <= 376 and not cond['mediaPlaying'])
            require(len(rows) == 4 and measured['list']['gap'] == 10 and all(row['sameRadio'] and row['sameImage'] and not row['disabled'] for row in rows))
            require([row['checked'] for row in rows] == [i == selected for i in range(4)] and [row['selected'] for row in rows] == [i == selected for i in range(4)])
            for i, row in enumerate(rows):
                geo = row['geometry']; require(geo['card']['layoutWidth'] == 314 and geo['card']['borderRadius'] == 0 and geo['label']['layoutHeight'] >= 58)
                require(geo['label']['paddingTop'] == geo['label']['paddingBottom'] == 8 and geo['label']['paddingLeft'] == geo['label']['paddingRight'] == 14)
                require(geo['key']['layoutWidth'] == geo['key']['layoutHeight'] == 28)
                if i < 3:
                    require(geo['media']['layoutHeight'] == 130 and geo['image']['objectFit'] == 'cover' and row['image']['url'] == options[i]['imageUrl'] and row['image']['complete'])
                else: require(not geo['media']['present'] and row['image'] is None)
            require(measured['viewer']['present'] == viewer)
            if viewer:
                vi = measured['viewer']; require(not vi['navigationPresent'] and vi['percentage'] == '100%' and vi['image']['complete'] and vi['image']['url'] == options[0]['imageUrl'])
            stem = theme + '-' + position
            png, rawfile, dom = output / (stem + '.png'), output / (stem + '.json'), output / (stem + '.html')
            png_sha = boundary.private_write(png, page.screenshot(full_page=False, animations='disabled'))
            raw_sha = boundary.private_write(rawfile, measured); dom_sha = boundary.private_write(dom, page.content().encode())
            public_rows = [{key: val for key, val in row.items() if key not in ('private', 'image')} for row in rows]
            for i, row in enumerate(public_rows):
                row['image'] = None if i == 3 else {key: val for key, val in rows[i]['image'].items() if key != 'url'}
                if row['image'] is not None: row['image']['sourceSha256'] = assets[options[i]['imageUrl']]['sha256']
            public_viewer = {key: val for key, val in measured['viewer'].items() if key != 'image'}
            public_viewer['imageSourceSha256'] = assets[options[0]['imageUrl']]['sha256'] if viewer else None
            report['states'].append({'theme': theme, 'position': position, 'selectedIndex': selected, 'conditions': cond,
                'list': measured['list'], 'options': public_rows, 'viewer': public_viewer,
                'screenshot': {'file': str(png.relative_to(ROOT)), 'sha256': png_sha},
                'privateMeasurements': {'file': str(rawfile.relative_to(ROOT)), 'sha256': raw_sha}, 'privateDom': {'file': str(dom.relative_to(ROOT)), 'sha256': dom_sha}})
        for i in (0, 2, 3):
            cards.nth(i).scroll_into_view_if_needed(); record('unselected-' + options[i]['key'])
        cards.nth(0).locator('label').click(); cards.nth(0).scroll_into_view_if_needed(); record('selected-A', 0)
        cards.nth(1).locator('label').click(); cards.nth(0).scroll_into_view_if_needed(); record('selected-B', 1)
        cards.nth(0).locator('.choice-media-button').click()
        page.locator('.media-viewer-stage--zoom > img').wait_for(state='visible')
        page.wait_for_function('url=>{const e=document.querySelector(".media-viewer-stage--zoom > img");return e&&e.complete&&e.naturalWidth>0&&(e.currentSrc||e.src)===url;}', arg=options[0]['imageUrl'])
        record('B-selected-A-image-open', 1, True)
        page.get_by_role('button', name='关闭媒体预览', exact=True).click(); page.locator('.media-viewer').wait_for(state='detached')
        cards.nth(0).scroll_into_view_if_needed(); record('B-selected-A-image-closed', 1)
        require(len(raw['apis']) == api_count)
        report['checks'].append({'theme': theme, 'oneSelectedRadio': True, 'sameRadioAndImageNodesRetained': True,
            'thumbnailOpensOnlyItsOwnImage': True, 'thumbnailPreservesBSelection': True, 'noSelectionOrViewerApiRequest': True})
    finally: context.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest='action')
    sub.add_parser('plan'); run = sub.add_parser('run')
    run.add_argument('--url', default=BASE_URL); run.add_argument('--web-source', type=Path, default=ROOT.parent / 'questions-web')
    run.add_argument('--font-file', type=Path, default=ROOT / 'entry/src/main/resources/rawfile/fonts/NotoSerifSC.ttf')
    for name in ('fixtures-json', 'images-manifest', 'output-dir', 'manifest'): run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-dto-sha', 'expected-fixture-sha', 'expected-images-manifest-sha'): run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if args.action is None: parser.print_help(); return 0
    if args.action == 'plan': print(json.dumps({'planSha256': PLAN_SHA, 'plan': PLAN}, ensure_ascii=False, indent=2)); return 0
    try: return capture(args)
    except Exception:
        print(json.dumps({'status': 'not_captured_or_report_guarded', 'error': 'Explicit source/DTO/image/font/output/browser prerequisites failed; values omitted'})); return 1


if __name__ == '__main__':
    sys.exit(main())

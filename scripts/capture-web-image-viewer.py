#!/usr/bin/env python3
"""Prepare owned frozen-Web image-viewer references; default/help/plan is inert.

Only explicit run reads private case0/case2 DTOs and eight registered images,
then uses a fresh headless browser against Root's existing local Vite. All API
replies are synthetic and image bytes are replayed locally. No backend, service,
device or personal browser is used. Zoom/pan and Native acceptance are excluded.
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
DRAFT = 'WEB_IMAGE_VIEWER_REFERENCE_DRAFT'
VIEWER_SOURCES = {
    'src/features/media/MediaViewer.tsx': 'd37ef115da63e7954f202ae6adfe7881504ca4b7d843dbbcaed364e57a498f4e',
    'src/features/media/ZoomableImage.tsx': '76f0a402abb78ecdc3c8aeef09d72c9033a7088bd1b6510f1c9a1c4f57d20e3a',
    'src/features/game/useGamePresentation.ts': 'e48cef4eca361a40aefa4d326ef033ccc4310ace74a5c9f35ef0d4b0d7e33367',
    'src/components/ui/Dialog.tsx': '3424d6686401869fe002c809d5a9b2c40c2080b127247aaf9815b0329acd63db',
    'src/shared/motion/useExitSnapshot.ts': '73c93d0a4f606b2aca6ecf81f4a058ad08c3a2c1ab38295c39de621b6a1b34ac',
    'src/styles/components/media-backdrop.css': 'e5f56b3d64c86f15f4a070112f5df421a8fe9800dccbcb0a169b26067fc3afc9',
    'src/styles/components/media-viewer.css': '0b693cb0333ebae58cf3cb0da70b07ee13bb2e1ae8ae1365534d40d374c497a3',
    'src/styles/effects/overlay-lighting.css': '78884afbc15fd742b2585dd66652f3ba7f11ad172c1b535f84cb1e129c572e27',
}
LIMITATIONS = [
    'Owned headless Web render replay with synthetic authentication and auxiliary replies; no business acceptance',
    'Registered source bytes only; no external download or live image Referer/server-policy verification',
    'Coarse-pointer emulation is a render condition; no touch pinch/pan/swipe or hidden range manipulation is performed',
    'Zoom/reset geometry is recorded at100percent; zoom and reset-from-zoom behavior are not verified',
    'Close button and Escape are Web interactions; Native systemBack/IME/account cancellation are not verified',
    'Native loading, whole-page parity, choice images, video/BGM playback and failure/cancellation acceptance are excluded',
]
PLAN = {'scope': 'Single body photo case0 and one three-image body gallery case2', 'sourceCommit': FROZEN,
    'frameHelperSha256': FRAME_SHA, 'fontSha256': FONT_SHA, 'viewerSourceSha256': VIEWER_SOURCES,
    'viewport': {'width': 376, 'height': 742, 'deviceScaleFactor': 1, 'hasTouch': True, 'isMobile': True},
    'themes': ['light', 'dark'], 'caseStates': {'0': ['open1of1', 'closedAfterEscape'],
    '2': ['open3of3', 'previous2of3', 'previous1of3', 'closedAfterEscape']},
    'closeSequence': ['existing close button', 'reopen same body image', 'Escape'],
    'bodyGroupsOnly': True, 'registeredAssetCount': 8, 'limitations': LIMITATIONS}
PLAN_SHA = hashlib.sha256(json.dumps(PLAN, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def require(value):
    if not value:
        raise ValueError('The explicit frozen image-viewer reference boundary did not hold')


def helpers():
    path = ROOT / 'scripts/capture-web-question-frame.py'
    data = path.read_bytes()
    require(hashlib.sha256(data).hexdigest() == FRAME_SHA)
    module = types.ModuleType('image_viewer_frame_reference')
    module.__file__ = str(path)
    exec(compile(data, str(path), 'exec'), module.__dict__)
    return module, path, data


def body_group(scene, case_index):
    question = scene['levels'][0]['question']
    require(question.get('kind') == 'text' and isinstance(question.get('content'), list))
    groups = []
    for index, block in enumerate(question['content']):
        require(isinstance(block, dict) and isinstance(block.get('imageUrls', []), list))
        if block.get('videoUrl'):
            continue
        values = [block.get('imageUrl', ''), *block.get('imageUrls', [])]
        require(all(isinstance(value, str) for value in values))
        images = list(dict.fromkeys(value for value in values if value))
        if images:
            groups.append((index, images))
    require(case_index in (0, 2) and len(groups) == 1 and len(groups[0][1]) == (1 if case_index == 0 else 3))
    return groups[0]


MEASURE = r"""() => {
  const modal=document.querySelector('.media-viewer-backdrop .media-viewer'), privateData={},geometry={};
  function rect(el) {
    if(!el)return {present:false}; const b=el.getBoundingClientRect(),s=getComputedStyle(el);
    const number=v=>Number.isFinite(parseFloat(v))?parseFloat(v):null;
    return {present:true,actualId:el.id||null,tag:el.tagName.toLowerCase(),role:el.getAttribute('role'),
      x:b.x,y:b.y,width:b.width,height:b.height,visible:s.display!=='none'&&s.visibility!=='hidden'&&b.width>0&&b.height>0,
      fullyInsideViewport:b.x>=0&&b.y>=0&&b.right<=innerWidth&&b.bottom<=innerHeight,
      fontSize:number(s.fontSize),lineHeight:number(s.lineHeight),gap:number(s.gap),paddingTop:number(s.paddingTop),
      paddingRight:number(s.paddingRight),paddingBottom:number(s.paddingBottom),paddingLeft:number(s.paddingLeft),
      borderRadius:number(s.borderTopLeftRadius),borderTopWidth:number(s.borderTopWidth),
      disabled:('disabled' in el)?el.disabled:null};
  }
  const nav=modal?.querySelector('.media-viewer-navigation'), image=modal?.querySelector('.media-viewer-stage--zoom > img');
  const buttons=nav?Array.from(nav.querySelectorAll('button')):[];
  const selectors={viewer:modal,backdrop:document.querySelector('.media-viewer-backdrop'),
    stage:modal?.querySelector('.media-viewer-stage--zoom'),currentImage:image,close:modal?.querySelector('.media-viewer-close'),
    zoom:modal?.querySelector('.media-viewer-zoom'),percentage:modal?.querySelector('.media-viewer-zoom output'),
    reset:modal?.querySelector('.media-viewer-zoom button'),help:modal?.querySelector('.media-viewer-zoom small'),
    slider:modal?.querySelector('.media-viewer-zoom input[type=range]'),navigation:nav,
    previous:buttons.find(el=>el.textContent.trim()==='上一张'),next:buttons.find(el=>el.textContent.trim()==='下一张'),
    answer:document.querySelector('.quest-card .answer-form .text-answer input')};
  for(const [key,el] of Object.entries(selectors)) {
    geometry[key]=rect(el);
    if(el)privateData[key]={text:el.textContent,attributes:Object.fromEntries(Array.from(el.attributes).map(a=>[a.name,a.value]))};
  }
  const percentage=modal?.querySelector('.media-viewer-zoom output')?.textContent.trim();
  const index=nav?.querySelector('span')?.textContent.match(/^\s*(\d+)\s*\/\s*(\d+)\s*$/);
  const input=selectors.answer;
  return {geometry,viewerOpen:!!modal,percentage:Number.parseInt(percentage||'',10)||null,
    index:index?Number(index[1]):null,count:index?Number(index[2]):null,
    currentImage:image?{url:image.currentSrc||image.src,complete:image.complete,naturalWidth:image.naturalWidth,
      naturalHeight:image.naturalHeight,transform:getComputedStyle(image).transform}:null,
    input:{sameNode:!!input&&input===window.__starwardImageViewerInput,draftRetained:!!input&&input.value===window.__starwardImageViewerDraft},
    conditions:{coarsePointer:matchMedia('(pointer:coarse)').matches,hasTouch:navigator.maxTouchPoints>0,
      width:innerWidth,height:innerHeight,dpr:devicePixelRatio,theme:document.documentElement.dataset.theme,
      documentInlineZoom:document.documentElement.style.zoom||'1',visualViewportScale:visualViewport?.scale||1,
      rootFontSizePx:parseFloat(getComputedStyle(document.documentElement).fontSize),scrollY,scrollWidth:document.documentElement.scrollWidth,
      mediaPlaying:Array.from(document.querySelectorAll('video,audio')).some(el=>!el.paused)},
    private:{elements:privateData,bodyText:document.body.innerText}};
}"""


def capture(args):
    frame, helper_path, helper_bytes = helpers()
    boundary, sha = frame.BOUNDARY, frame.sha
    own_bytes = Path(__file__).read_bytes()
    require(args.url == BASE_URL and all(re.fullmatch(r'[a-f0-9]{64}', value or '') for value in
        (args.expected_fixture_sha, args.expected_images_manifest_sha, args.expected_case0_dto_sha, args.expected_case2_dto_sha)))
    web = args.web_source.absolute().resolve()
    boundary.frozen_check(web)
    sources = {name: (web / name).read_bytes() for name in dict.fromkeys((*frame.SOURCES, *VIEWER_SOURCES))}
    require(all(sha(sources[name]) == expected for name, expected in VIEWER_SOURCES.items()))
    cases = []
    for index in (0, 2):
        path = frame.private_input(getattr(args, 'case' + str(index) + '_fixtures_json'))
        data = path.read_bytes()
        require(sha(data) == getattr(args, 'expected_case' + str(index) + '_dto_sha'))
        value = json.loads(data)
        player, scene, listing, _hidden = frame.fixtures(value)
        block, urls = body_group(scene, index)
        cases.append({'index': index, 'path': path, 'bytes': data, 'value': value, 'player': player,
            'scene': scene, 'listing': listing, 'block': block, 'urls': urls})
    require(cases[0]['player']['id'] != cases[1]['player']['id'] and cases[0]['scene']['id'] != cases[1]['scene']['id'])
    images_path = frame.private_input(args.images_manifest)
    images_bytes, assets = frame.image_assets(images_path, args.expected_fixture_sha)
    require(sha(images_bytes) == args.expected_images_manifest_sha and len(assets) == 8 and
        all(url in assets for case in cases for url in case['urls']))
    font = boundary.path_in(args.font_file, ROOT / 'entry/src/main/resources', True)
    font_bytes = font.read_bytes()
    require(font == frame.NATIVE_FONT and sha(font_bytes) == FONT_SHA)
    output = boundary.path_in(args.output_dir, frame.PRIVATE)
    manifest = boundary.path_in(args.manifest, frame.PUBLIC)
    require(not output.exists() and not manifest.exists())
    boundary.fresh_directory(output)
    for case in cases:
        boundary.private_write(output / ('case' + str(case['index']) + '-input-dtos.json'), case['bytes'])
    report = {'status': 'incomplete', 'planSha256': PLAN_SHA, 'plan': PLAN, 'helperSha256': sha(own_bytes),
        'boundaryHelperSha256': frame.BOUNDARY_SHA, 'sourceCommit': FROZEN, 'fontSha256': FONT_SHA,
        'expectedFixtureSha256': args.expected_fixture_sha, 'imagesManifestSha256': sha(images_bytes),
        'caseDtoSha256': {str(case['index']): sha(case['bytes']) for case in cases},
        'sourceSha256': {name: sha(data) for name, data in sources.items()}, 'registeredImageSha256': sorted({a['sha256'] for a in assets.values()}),
        'syntheticAuthentication': True, 'businessAcceptance': False, 'nativeAcceptance': False, 'visualReview': 'pending_root_original_review',
        'backendRequestsContinued': 0, 'externalRequestsContinued': 0, 'registeredCaptureRefererVerified': True,
        'liveRefererPolicyVerified': False, 'touchZoomVerified': False, 'wholePageParityAccepted': False,
        'controlIdentityMethod': 'Actual DOM ids and existing scoped controls; no injected control ids', 'states': [], 'checks': []}
    raw = {'apis': [], 'blocked': [], 'imagesReplayed': [], 'unknownImages': [], 'unexpectedApis': [], 'routeFailures': [],
        'pageErrors': [], 'consoleErrors': [], 'webSocketsBlocked': 0, 'bgmPrompts': []}
    source_checks, schema_checks, font_checks = [], [], []
    failure = None
    try:
        package = frame.PRIVATE / 'python-playwright'
        if package.is_dir(): sys.path.insert(0, str(package))
        from playwright.sync_api import sync_playwright
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True, timeout=30000, args=['--disable-background-networking'])
            try:
                for case in cases:
                    for theme in ('light', 'dark'):
                        sample_context(browser, case, theme, args, frame, assets, font_bytes, sources, output, report, raw,
                                       source_checks, schema_checks, font_checks)
            finally:
                browser.close()
        boundary.frozen_check(web)
        require(Path(__file__).read_bytes() == own_bytes and helper_path.read_bytes() == helper_bytes and
            sha((ROOT / 'scripts/capture-web-ui-sample.py').read_bytes()) == frame.BOUNDARY_SHA and
            images_path.read_bytes() == images_bytes and font.read_bytes() == font_bytes and
            all(case['path'].read_bytes() == case['bytes'] for case in cases) and
            all(asset['source'].read_bytes() == asset['data'] for asset in assets.values()) and
            all((web / name).read_bytes() == data for name, data in sources.items()))
        require(not any(raw[key] for key in ('pageErrors', 'unexpectedApis', 'unknownImages', 'routeFailures')) and
            len(source_checks) == len(sources) * 4 and all(source_checks) and schema_checks == [True] * 12 and len(font_checks) >= 4 and
            len(report['states']) == 12 and len(report['checks']) == 4)
        report['status'] = 'captured_web_image_viewer_reference'
    except Exception as error:
        raw['failure'] = {'type': type(error).__name__, 'message': str(error)}
        failure = 'The guarded Web viewer reference is incomplete; raw evidence retained privately'
    finally:
        evidence = output / 'browser-private.json'
        report['privateBrowserEvidence'] = {'file': str(evidence.relative_to(ROOT)), 'sha256': boundary.private_write(evidence, raw)}
        report['counts'] = {key: len(value) if isinstance(value, list) else value for key, value in raw.items() if key != 'failure'}
        report['counts'].update({'states': len(report['states']), 'checks': len(report['checks']), 'registeredImages': len(assets),
            'schemaChecks': len(schema_checks), 'servedSourceChecks': len(source_checks), 'fontRequestsReplayed': len(font_checks)})
        if failure: report['failure'] = failure
        encoded = (json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
        literals = set(assets).union(*(frame.private_literals(case['value']) for case in cases))
        require(not re.search(rb'https?://', encoded) and not any(item.encode() in encoded if len(item) >= 5 else
            ('"' + item + '"').encode() in encoded for item in literals))
        boundary.path_in(manifest, frame.PUBLIC)
        manifest.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(manifest, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'wb') as stream: stream.write(encoded)
    print(json.dumps({'status': report['status'], 'planSha256': PLAN_SHA, 'states': len(report['states']),
                      'manifestSha256': sha(encoded)}), flush=True)
    return 1 if failure else 0


def sample_context(browser, case, theme, args, frame, assets, font_bytes, sources, output, report, raw,
                   source_checks, schema_checks, font_checks):
    boundary, sha, bounded = frame.BOUNDARY, frame.sha, frame.bounded
    context = browser.new_context(viewport={'width': 376, 'height': 742}, device_scale_factor=1, has_touch=True, is_mobile=True,
        color_scheme=theme, reduced_motion='reduce', locale='zh-CN', timezone_id='Asia/Shanghai', service_workers='block', accept_downloads=False)
    player, scene = case['player'], case['scene']
    detail = '/api/questions/v1/assignments/' + scene['id']
    routes = (frame.AUTH, '/api/files/token', '/api/questions/v1/me', '/api/questions/v1/assignments', detail,
              '/api/questions/v1/notifications', '/api/questions/v1/rewards')
    tag = {'case': case['index'], 'theme': theme}
    cors = {'Access-Control-Allow-Origin': BASE_URL, 'Access-Control-Allow-Headers': 'Authorization,Content-Type,Accept',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'}
    def intercept(route):
        request, parsed = route.request, urlparse(route.request.url)
        origin = parsed.scheme + '://' + parsed.netloc
        if request.url in assets and request.method == 'GET' and request.resource_type == 'image':
            require(not request.headers.get('authorization'))
            asset = assets[request.url]
            raw['imagesReplayed'].append({**tag, 'url': request.url, 'sha256': asset['sha256'], 'referer': request.headers.get('referer')})
            route.fulfill(status=200, content_type=asset['mime'], body=asset['data'])
        elif parsed.path.startswith('/api/'):
            raw['apis'].append({**tag, 'method': request.method, 'url': request.url})
            if origin == frame.API_ORIGIN and not parsed.query and request.method == 'OPTIONS' and parsed.path in routes:
                route.fulfill(status=204, headers=cors, body=''); return
            response = None
            if origin == frame.API_ORIGIN and not parsed.query:
                if request.method == 'POST' and parsed.path == frame.AUTH:
                    require(request.post_data_json == {'identity': player['account'], 'password': frame.PASSWORD})
                    response = {'token': frame.TOKEN, 'record': {'id': player['id']}}
                elif request.headers.get('authorization') == frame.TOKEN:
                    if request.method == 'GET' and parsed.path == '/api/questions/v1/me': response = player
                    elif request.method == 'GET' and parsed.path == '/api/questions/v1/assignments': response = case['listing']
                    elif request.method == 'GET' and parsed.path == detail: response = scene
                    elif request.method == 'GET' and parsed.path in routes[-2:]: response = {'items': []}
                    elif request.method == 'POST' and parsed.path == '/api/files/token': response = {'token': 'viewer-synthetic-file-token'}
            if response is None:
                key = 'blocked' if request.method == 'GET' and parsed.path.startswith('/api/files/game_players/') else 'unexpectedApis'
                raw[key].append({**tag, 'method': request.method, 'url': request.url})
                route.fulfill(status=404, headers=cors, content_type='application/json', body='{"error":{"code":"REPLAY_NOT_CONFIGURED"}}')
            else: route.fulfill(status=200, headers=cors, content_type='application/json', body=json.dumps(response, ensure_ascii=False))
        elif request.method == 'GET' and origin == BASE_URL and parsed.path == frame.FONT_ROUTE and not parsed.query:
            font_checks.append(FONT_SHA); route.fulfill(status=200, content_type='font/ttf', body=font_bytes)
        elif boundary.source_request(request.method, request.url, request.resource_type, BASE_URL, scene['id'], args.web_source.absolute().resolve()):
            route.continue_()
        else:
            raw['blocked'].append({**tag, 'kind': request.resource_type, 'url': request.url}); route.abort()
    def guarded(route):
        try: intercept(route)
        except Exception as error:
            raw['routeFailures'].append({'type': type(error).__name__, 'message': str(error)})
            try: route.abort()
            except Exception: pass
    try:
        context.route('**/*', guarded)
        require(hasattr(context, 'route_web_socket'))
        def no_socket(_socket): raw['webSocketsBlocked'] += 1
        context.route_web_socket('**/*', no_socket)
        page = context.new_page(); page.set_default_timeout(15000); page.set_default_navigation_timeout(30000)
        page.on('pageerror', lambda error: raw['pageErrors'].append(str(error)))
        page.on('console', lambda message: raw['consoleErrors'].append(message.text) if message.type == 'error' else None)
        page.goto(BASE_URL + '/login?theme=' + theme, wait_until='networkidle')
        for name, data in sources.items():
            served = bounded(page, 'return (await import(arg+"?raw")).default;', '/' + name)
            source_checks.append(isinstance(served, str) and sha(served.encode()) == sha(data)); require(source_checks[-1])
        schema = bounded(page, '''const m=await import('/src/api/game.schema.ts'); return [m.gamePlayerSchema.safeParse(arg.player).success,
            m.gameAssignmentSchema.safeParse(arg.assignment).success,m.gameAssignmentSummarySchema.array().safeParse(arg.assignments.items).success];''', case['value'])
        schema_checks.extend(schema); require(schema == [True, True, True])
        page.get_by_label('登录账号', exact=True).fill(player['account']); page.get_by_label('密码', exact=True).fill(frame.PASSWORD)
        page.get_by_role('button', name='进入冒险', exact=True).click()
        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
        page.goto(BASE_URL + '/play/' + quote(scene['id'], safe='') + '?theme=' + theme, wait_until='networkidle')
        page.locator('.quest-card').wait_for(state='visible')
        require(page.locator('.quest-card').count() == 1 and page.locator('.quest-layout.quest-desktop').count() == 0)
        bgm = page.get_by_role('button', name='关闭背景音乐提示', exact=True)
        dismissed = bgm.count() > 0
        if dismissed: bgm.click(); bgm.wait_for(state='detached')
        raw['bgmPrompts'].append({**tag, 'dismissedUsingExistingClose': dismissed, 'playbackEnabled': False})
        page.add_style_tag(content='@font-face{font-family:StarwardQuestionFrameSerif;src:url("' + BASE_URL + frame.FONT_ROUTE +
            '") format("truetype");font-weight:100 900;font-style:normal;font-display:block}:root{--font-display:StarwardQuestionFrameSerif,serif!important}')
        require(bounded(page, 'return (await document.fonts.load("37.6px StarwardQuestionFrameSerif")).length>0;'))
        answer = page.locator('.quest-card .answer-form .text-answer input')
        require(answer.count() == 1 and answer.is_enabled())
        answer.fill(DRAFT)
        answer.evaluate('(el,value)=>{window.__starwardImageViewerInput=el;window.__starwardImageViewerDraft=value;}', DRAFT)
        buttons = page.locator('.quest-card .quest-content-item').nth(case['block']).locator(':scope > .question-image > button, :scope > .question-gallery > button')
        require(buttons.count() == len(case['urls']))
        for index, url in enumerate(case['urls']):
            image = buttons.nth(index).locator('img')
            require(image.count() == 1)
            actual_url = image.evaluate('(el)=>el.currentSrc||el.src')
            if actual_url not in assets: raw['unknownImages'].append({**tag, 'url': actual_url})
            require(actual_url == url)
            image.scroll_into_view_if_needed()
            page.wait_for_function('(el)=>el.complete&&el.naturalWidth>0&&el.naturalHeight>0', arg=image.element_handle())
        page.wait_for_load_state('networkidle')
        api_count = len(raw['apis'])
        first = len(case['urls']) - 1
        def opened(index):
            buttons.nth(index).click()
            page.locator('.media-viewer-stage--zoom > img').wait_for(state='visible')
            page.wait_for_function('url=>{const el=document.querySelector(".media-viewer-stage--zoom > img");return el&&el.complete&&el.naturalWidth>0&&el.naturalHeight>0&&(el.currentSrc||el.src)===url;}', arg=case['urls'][index])
        def retained():
            page.locator('.media-viewer').wait_for(state='detached')
            result = answer.evaluate('(el)=>({same:el===window.__starwardImageViewerInput,draft:el.value===window.__starwardImageViewerDraft})')
            require(result == {'same': True, 'draft': True})
            return result
        def record(position, index=None):
            page.wait_for_load_state('networkidle')
            bounded(page, 'await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));return true;')
            measured = page.evaluate(MEASURE)
            conditions, geometry = measured['conditions'], measured['geometry']
            require(conditions['coarsePointer'] and conditions['hasTouch'] and conditions['width'] == 376 and conditions['height'] == 742 and
                conditions['dpr'] == 1 and conditions['theme'] == theme and conditions['documentInlineZoom'] == '1' and
                conditions['visualViewportScale'] == 1 and not conditions['mediaPlaying'] and conditions['scrollWidth'] <= 376)
            require(measured['input'] == {'sameNode': True, 'draftRetained': True})
            if index is not None:
                image = measured['currentImage']
                require(measured['viewerOpen'] and image['url'] == case['urls'][index] and image['complete'] and
                    image['naturalWidth'] > 0 and image['naturalHeight'] > 0 and measured['percentage'] == 100 and
                    all(geometry[key]['visible'] for key in ('viewer', 'stage', 'currentImage', 'close', 'percentage', 'reset', 'help')) and
                    not geometry['slider']['visible'])
                require(measured['private']['elements']['reset']['text'].strip() == '复位' and
                    measured['private']['elements']['help']['text'].strip() == '双指缩放 · 放大后拖动')
                require(any(row['case'] == case['index'] and row['theme'] == theme and row['url'] == image['url'] for row in raw['imagesReplayed']))
                if len(case['urls']) == 1: require(not geometry['navigation']['present'] and measured['index'] is None)
                else: require(measured['index'] == index + 1 and measured['count'] == 3 and
                    geometry['previous']['disabled'] == (index == 0) and geometry['next']['disabled'] == (index == 2))
            else: require(not measured['viewerOpen'] and measured['currentImage'] is None)
            stem = 'case' + str(case['index']) + '-' + theme + '-' + position
            png, data, dom = output / (stem + '.png'), output / (stem + '.json'), output / (stem + '.html')
            png_sha = boundary.private_write(png, page.screenshot(full_page=False, animations='disabled'))
            data_sha = boundary.private_write(data, measured); dom_sha = boundary.private_write(dom, page.content().encode())
            image_public = None if index is None else {key: value for key, value in measured['currentImage'].items() if key != 'url'}
            if image_public is not None: image_public['sourceSha256'] = assets[case['urls'][index]]['sha256']
            report['states'].append({**tag, 'position': position, 'geometry': geometry, 'conditions': conditions,
                'currentImage': image_public, 'index': measured['index'], 'count': measured['count'], 'percentage': measured['percentage'],
                'retainedInput': measured['input'], 'screenshot': {'file': str(png.relative_to(ROOT)), 'sha256': png_sha},
                'privateMeasurements': {'file': str(data.relative_to(ROOT)), 'sha256': data_sha}, 'privateDom': {'file': str(dom.relative_to(ROOT)), 'sha256': dom_sha}})
            print(json.dumps({'sourceCaseIndex': case['index'], 'theme': theme, 'capturedStates': len(report['states']), 'planSha256': PLAN_SHA}), flush=True)
        opened(first); record('open1of1' if first == 0 else 'open3of3', first)
        if case['index'] == 2:
            for index in (1, 0):
                page.locator('.media-viewer-navigation').get_by_role('button', name='上一张', exact=True).click()
                page.wait_for_function('url=>{const el=document.querySelector(".media-viewer-stage--zoom > img");return el&&el.complete&&el.naturalWidth>0&&(el.currentSrc||el.src)===url;}', arg=case['urls'][index])
                record('previous' + str(index + 1) + 'of3', index)
        page.get_by_role('button', name='关闭媒体预览', exact=True).click(); retained()
        opened(first); page.keyboard.press('Escape'); retained()
        answer.scroll_into_view_if_needed(); record('closedAfterEscape')
        require(len(raw['apis']) == api_count)
        report['checks'].append({**tag, 'existingBodyGroupClicked': True, 'noViewerApiRequest': True, 'closeButtonDismissed': True,
            'escapeDismissed': True, 'sameInputNodeAndDraftRetained': True, 'nonLoopBoundariesObserved': case['index'] == 2,
            'zoomManipulated': False, 'hiddenRangeManipulated': False})
    finally:
        context.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action'); sub.add_parser('plan', help='Print only the frozen plan/bindings/limitations; no inputs or browser')
    run = sub.add_parser('run', help='Root-reviewed explicit same-byte owned Web replay; no service or real backend operation')
    run.add_argument('--url', default=BASE_URL)
    run.add_argument('--web-source', type=Path, default=ROOT.parent / 'questions-web')
    for name in ('case0-fixtures-json', 'case2-fixtures-json', 'images-manifest', 'font-file', 'output-dir', 'manifest'):
        run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-fixture-sha', 'expected-images-manifest-sha', 'expected-case0-dto-sha', 'expected-case2-dto-sha'):
        run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if not args.action: parser.print_help(); return 0
    if args.action == 'plan': print(json.dumps({'planSha256': PLAN_SHA, 'plan': PLAN}, ensure_ascii=False, indent=2)); return 0
    try: return capture(args)
    except Exception:
        print(json.dumps({'status': 'not_captured_or_report_guarded', 'planSha256': PLAN_SHA,
            'error': 'An explicit source/fixture/image/font/output/browser guard failed; values omitted'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

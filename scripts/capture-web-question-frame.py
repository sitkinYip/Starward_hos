#!/usr/bin/env python3
"""Capture guarded frozen-Web question-frame references; default/help is inert.

Root starts Vite separately. Only run reads the explicit private Native DTO and
registered image bytes, then opens a fresh headless browser. Authentication and
auxiliary API responses are synthetic; no backend or external request is sent.
This is a Web frame/type reference, never Native image or whole-page acceptance.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import types
from urllib.parse import quote, urlparse

ROOT = Path(__file__).resolve().parents[1]
BOUNDARY_SHA = '4f293d01bf98e7e4a355493d8572a1a1e1b24566571a872bab7baf0860b0da8f'
try:
    boundary_source = ROOT / 'scripts/capture-web-ui-sample.py'
    boundary_bytes = boundary_source.read_bytes()
    if hashlib.sha256(boundary_bytes).hexdigest() != BOUNDARY_SHA:
        raise ValueError('boundary_mismatch')
    BOUNDARY = types.ModuleType('question_frame_web_boundary')
    BOUNDARY.__file__ = str(boundary_source)
    # Compile the already-verified bytes; a second loader read could race a change.
    exec(compile(boundary_bytes, str(boundary_source), 'exec'), BOUNDARY.__dict__)
except Exception:
    print(json.dumps({'status': 'not_captured_or_report_guarded',
        'error': 'The frozen local boundary helper is unavailable or changed; values omitted'}), flush=True)
    raise SystemExit(1)
require, sha = BOUNDARY.require, BOUNDARY.sha
PRIVATE, PUBLIC = BOUNDARY.PRIVATE, BOUNDARY.PUBLIC
NATIVE_FONT, FROZEN = BOUNDARY.NATIVE_FONT, BOUNDARY.FROZEN
BASE_URL = 'http://127.0.0.1:5178'
API_ORIGIN = BOUNDARY.API_ORIGIN
AUTH = BOUNDARY.AUTH
FONT_ROUTE = '/__question_frame__/native-serif.ttf'
TOKEN, PASSWORD = 'question-frame-synthetic-render-token', 'QuestionFrameRenderingOnly123'
SOURCES = ('src/index.css', 'src/app/App.tsx', 'src/api/game.schema.ts', 'src/config/ui-copy.ts',
    'src/features/game/GamePlayPage.tsx', 'src/features/game/GamePlayScene.tsx',
    'src/features/quest/QuestCard.tsx', 'src/features/quest/QuestAnswerForm.tsx',
    'src/features/media/QuestContent.tsx', 'src/features/media/ChoiceOptions.tsx',
    'src/features/content/RichContent.tsx', 'src/domain/content/parser.ts',
    'src/styles/foundation/base.css', 'src/styles/foundation/tokens.css',
    'src/styles/layout/shell.css', 'src/styles/features/quest.css',
    'src/styles/features/question-images.css', 'src/styles/effects/quest-lighting.css',
    'src/styles/effects/answer-feedback.css', 'src/styles/components/controls-and-overlays.css')


def private_input(value):
    path = BOUNDARY.path_in(value, PRIVATE, True, True)
    for parent in path.parents:
        if parent != PRIVATE and not parent.is_relative_to(PRIVATE):
            break
        info = parent.stat()
        require(stat.S_ISDIR(info.st_mode) and info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o700)
    return path


def fixtures(value):
    require(isinstance(value, dict) and set(value) == {'player', 'assignments', 'assignment'})
    player, scene, listing = value['player'], value['assignment'], value['assignments']
    require(all(isinstance(item, dict) for item in (player, scene, listing)))
    require(isinstance(player.get('account'), str) and player['account'] != 'starward_preview' and
            player.get('mustChangePassword') is False and
            re.fullmatch(r'[a-z0-9]{15}', player.get('id', '')) and
            re.fullmatch(r'[a-z0-9]{15}', scene.get('id', '')) and scene.get('player') == player['id'] and
            scene.get('status') == 'active' and bool(scene.get('startedAt')) and not scene.get('completedAt') and
            scene.get('currentIndex') == 0 and scene.get('totalLevels') == 1 and scene.get('completedLevels') == 0 and
            isinstance(scene.get('levels'), list) and len(scene['levels']) == 1 and
            isinstance(listing.get('items'), list) and len(listing['items']) == 1 and
            listing['items'][0].get('id') == scene['id'] and listing['items'][0].get('player') == player['id'])
    level = scene['levels'][0]
    require(isinstance(level, dict) and isinstance(level.get('question'), dict) and
            not level.get('completedAt') and not level.get('lastAnswer') and
            level.get('wrongCount') == 0 and level.get('locked') is False)

    def reject_credentials(item):
        if isinstance(item, dict):
            require(not any(str(key).lower() in ('token', 'password', 'authorization', 'controltoken', 'answerkey') for key in item))
            for child in item.values():
                reject_credentials(child)
        elif isinstance(item, list):
            for child in item:
                reject_credentials(child)
    reject_credentials(value)
    override = level.get('presentationOverride', {})
    presentation = scene.get('presentation', {})
    require(isinstance(override, dict) and isinstance(presentation, dict))
    hidden = override['hideTitle'] if 'hideTitle' in override else presentation.get('hideTitle', False)
    require(type(hidden) is bool)
    return player, scene, listing, hidden or not bool(level['question'].get('title'))


def image_assets(path, expected_fixture):
    raw = path.read_bytes()
    value = json.loads(raw)
    require(isinstance(value, dict) and value.get('status') == 'reference_image_bytes_captured' and
            value.get('fixtureSha256') == expected_fixture and value.get('referer') == 'https://sitkin.top/' and
            value.get('nativeLoadVerified') is False and isinstance(value.get('assets'), list) and
            0 < len(value['assets']) <= 100)
    assets = {}
    for row in value['assets']:
        require(isinstance(row, dict) and isinstance(row.get('url'), str) and
                isinstance(row.get('file'), str) and row.get('authorizationSent') is False and
                re.fullmatch(r'[a-f0-9]{64}', row.get('sha256', '')) and
                type(row.get('bytes')) is int and 0 < row['bytes'] <= 20 * 1024 * 1024)
        parsed = urlparse(row['url'])
        require(parsed.scheme == 'https' and parsed.hostname and not parsed.username and not parsed.password and
                not parsed.fragment and row['url'] not in assets and row.get('mime') in ('image/png', 'image/jpeg'))
        source = private_input(Path(row['file']))
        data = source.read_bytes()
        require(len(data) == row['bytes'] and sha(data) == row['sha256'])
        # OSS can declare image/png for JPEG bytes. Preserve both the actual
        # response header and original bytes; validate their detected format
        # separately, as browser/ImageKit decoders do.
        detected = row.get('detectedMime', row['mime'])
        require((detected == 'image/png' and data.startswith(b'\x89PNG\r\n\x1a\n')) or
                (detected == 'image/jpeg' and data.startswith(b'\xff\xd8\xff')))
        assets[row['url']] = {'data': data, 'source': source, 'mime': row['mime'], 'sha256': row['sha256']}
    require(sum(len(row['data']) for row in assets.values()) <= 100 * 1024 * 1024)
    return raw, assets


def bounded(page, body, value=None):
    return page.evaluate('''async arg => {
      let timer; try {
        return await Promise.race([(async()=>{''' + body + '''})(),
          new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('bounded_render_step_timeout')),15000);})]);
      } finally {clearTimeout(timer);}
    }''', value)


MEASURE = r"""() => {
  const card=document.querySelector('.quest-card'), privateResult={},geometry={};
  function rect(el) {const b=el.getBoundingClientRect();return {x:b.x,y:b.y,width:b.width,height:b.height,
    documentY:b.y+scrollY,relativeX:b.x-card.getBoundingClientRect().x,
    relativeY:b.y-card.getBoundingClientRect().y};}
  const selectors={card:'.quest-card',meta:'.quest-card .quest-meta',title:'.quest-card h1',
    content:'.quest-card .quest-content',body:'.quest-card .quest-prompt',form:'.quest-card .answer-form'};
  for(const [key,selector] of Object.entries(selectors)) {
    const el=document.querySelector(selector); if(!el){geometry[key]={present:false};continue;}
    const s=getComputedStyle(el),r=rect(el),number=v=>Number.isFinite(parseFloat(v))?parseFloat(v):null;
    geometry[key]={present:true,...r,fontSize:number(s.fontSize),lineHeight:number(s.lineHeight),
      letterSpacing:number(s.letterSpacing),paddingTop:number(s.paddingTop),paddingRight:number(s.paddingRight),
      paddingBottom:number(s.paddingBottom),paddingLeft:number(s.paddingLeft),marginTop:number(s.marginTop),
      borderTopWidth:number(s.borderTopWidth),borderLeftWidth:number(s.borderLeftWidth),
      borderRadius:number(s.borderTopLeftRadius),outlineWidth:number(s.outlineWidth),outlineOffset:number(s.outlineOffset)};
    privateResult[key]={selector,text:el.textContent,computedStyle:Object.fromEntries(Array.from(s).map(k=>[k,s.getPropertyValue(k)]))};
  }
  geometry.corners=Array.from(card.querySelectorAll('.quest-card-chrome > i')).map(el=>{
    const s=getComputedStyle(el),num=v=>Number.isFinite(parseFloat(v))?parseFloat(v):null;
    return {...rect(el),top:num(s.top),right:num(s.right),bottom:num(s.bottom),left:num(s.left),
      borderTopWidth:num(s.borderTopWidth),borderRightWidth:num(s.borderRightWidth),
      borderBottomWidth:num(s.borderBottomWidth),borderLeftWidth:num(s.borderLeftWidth),opacity:num(s.opacity)};
  });
  geometry.blocks=Array.from(card.querySelectorAll('.quest-content-item')).map(el=>{
    const s=getComputedStyle(el);return {...rect(el),gap:parseFloat(s.rowGap)};
  });
  geometry.bodies=Array.from(card.querySelectorAll('.quest-prompt')).map(el=>{
    const s=getComputedStyle(el);return {...rect(el),fontSize:parseFloat(s.fontSize),lineHeight:parseFloat(s.lineHeight)};
  });
  const images=Array.from(card.querySelectorAll('img')).map(el=>({url:el.currentSrc||el.src,
    complete:el.complete,naturalWidth:el.naturalWidth,naturalHeight:el.naturalHeight,...rect(el)}));
  geometry.images=images.map(({url,...rest})=>rest);
  const meta=card.querySelector('.quest-meta'), title=card.querySelector('h1'),content=card.querySelector('.quest-content');
  if(meta&&content) geometry.metaToContent=content.getBoundingClientRect().top-meta.getBoundingClientRect().bottom;
  if(meta&&title) geometry.metaToTitle=title.getBoundingClientRect().top-meta.getBoundingClientRect().bottom;
  if(title&&content) geometry.titleToContent=content.getBoundingClientRect().top-title.getBoundingClientRect().bottom;
  return {geometry,private:{elements:privateResult,images,bodyText:document.body.innerText},
    viewport:{width:innerWidth,height:innerHeight,dpr:devicePixelRatio,scrollY,
      scrollWidth:document.documentElement.scrollWidth,scrollHeight:document.documentElement.scrollHeight},
    titleCount:card.querySelectorAll('h1').length};
}"""


def private_literals(value):
    found = {TOKEN, PASSWORD}
    def walk(item, key=''):
        if isinstance(item, dict):
            for name, child in item.items():
                walk(child, name)
        elif isinstance(item, list):
            for child in item:
                walk(child, key)
        elif isinstance(item, str) and key in ('id', 'account', 'displayName', 'title', 'text', 'hint',
                'placeholder', 'imageUrl', 'imageUrls', 'videoUrl', 'lastAnswer', 'description') and item:
            found.add(item)
    walk(value)
    return found


def capture(args):
    require(args.url == BASE_URL and re.fullmatch(r'[a-f0-9]{64}', args.expected_fixture_sha or ''))
    boundary_path = ROOT / 'scripts/capture-web-ui-sample.py'
    require(sha(boundary_path.read_bytes()) == BOUNDARY_SHA)
    own_bytes = Path(__file__).read_bytes()
    web = args.web_source.absolute().resolve()
    BOUNDARY.frozen_check(web)
    sources = {name: (web / name).read_bytes() for name in SOURCES}
    snapshot = private_input(args.fixtures_json)
    snapshot_bytes = snapshot.read_bytes()
    value = json.loads(snapshot_bytes)
    player, scene, listing, hidden_title = fixtures(value)
    images_path = private_input(args.images_manifest)
    images_bytes, assets = image_assets(images_path, args.expected_fixture_sha)
    font = BOUNDARY.path_in(args.font_file, ROOT / 'entry/src/main/resources', True)
    require(font == NATIVE_FONT)
    font_bytes = font.read_bytes()
    require(0 < len(font_bytes) < 50 * 1024 * 1024)
    output = BOUNDARY.path_in(args.output_dir, PRIVATE)
    manifest = BOUNDARY.path_in(args.manifest, PUBLIC)
    require(not output.exists() and not manifest.exists())
    BOUNDARY.fresh_directory(output)
    BOUNDARY.private_write(output / 'input-fixtures.json', snapshot_bytes)
    report = {'status': 'incomplete', 'sourceCommit': FROZEN, 'helperSha256': sha(own_bytes),
        'boundaryHelperSha256': BOUNDARY_SHA, 'expectedFixtureSha256': args.expected_fixture_sha,
        'fixtureSha256': sha(snapshot_bytes), 'imagesManifestSha256': sha(images_bytes), 'fontSha256': sha(font_bytes),
        'registeredImageSha256': sorted({asset['sha256'] for asset in assets.values()}),
        'viewport': {'width': 376, 'height': 742, 'deviceScaleFactor': 1},
        'syntheticAuthentication': True, 'nativeImageLoadVerified': False, 'wholePageParityAccepted': False,
        'businessAcceptance': False, 'nativeInstalledFontIndependentlyVerified': False,
        'backendRequestsContinued': 0, 'externalRequestsContinued': 0,
        'sources': [{'path': name, 'sha256': sha(data)} for name, data in sources.items()], 'states': []}
    raw = {'apis': [], 'blocked': [], 'imagesReplayed': [], 'unexpectedApis': [], 'unknownImages': [], 'routeFailures': [],
        'pageErrors': [], 'consoleErrors': [], 'webSocketsBlocked': 0, 'phases': []}
    schema_checks, source_checks, font_checks = [], [], []
    failure = None
    def phase(name):
        item = {'phase': name, 'at': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        raw['phases'].append(item)
        BOUNDARY.private_write(output / ('phase-%02d.json' % len(raw['phases'])), item)
        print(json.dumps({'phase': name, 'capturedStates': len(report['states'])}), flush=True)
    try:
        package = PRIVATE / 'python-playwright'
        if package.is_dir():
            sys.path.insert(0, str(package))
        from playwright.sync_api import sync_playwright
        phase('prepared-inputs')
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True, timeout=30000, args=['--disable-background-networking'])
            try:
                for theme in ('light', 'dark'):
                    phase(theme + '-opening')
                    context = browser.new_context(viewport={'width': 376, 'height': 742}, device_scale_factor=1,
                        color_scheme=theme, reduced_motion='reduce', locale='zh-CN', timezone_id='Asia/Shanghai',
                        service_workers='block')
                    def intercept(route):
                        request, parsed = route.request, urlparse(route.request.url)
                        origin = parsed.scheme + '://' + parsed.netloc
                        if request.url in assets and request.method == 'GET' and request.resource_type == 'image':
                            asset = assets[request.url]
                            raw['imagesReplayed'].append({'theme': theme, 'url': request.url, 'sha256': asset['sha256']})
                            route.fulfill(status=200, content_type=asset['mime'], body=asset['data'])
                        elif parsed.path.startswith('/api/'):
                            raw['apis'].append({'theme': theme, 'method': request.method, 'url': request.url})
                            cors = {'Access-Control-Allow-Origin': BASE_URL,
                                'Access-Control-Allow-Headers': 'Authorization,Content-Type,Accept',
                                'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'}
                            detail_path = '/api/questions/v1/assignments/' + scene['id']
                            routes = (AUTH, '/api/files/token', '/api/questions/v1/me', '/api/questions/v1/assignments',
                                detail_path, '/api/questions/v1/notifications', '/api/questions/v1/rewards')
                            if origin == API_ORIGIN and not parsed.query and request.method == 'OPTIONS' and parsed.path in routes:
                                route.fulfill(status=204, headers=cors, body='')
                                return
                            response = None
                            if origin == API_ORIGIN and not parsed.query:
                                if request.method == 'POST' and parsed.path == AUTH:
                                    require(request.post_data_json == {'identity': player['account'], 'password': PASSWORD})
                                    response = {'token': TOKEN, 'record': {'id': player['id']}}
                                elif request.headers.get('authorization') == TOKEN:
                                    if request.method == 'GET' and parsed.path == '/api/questions/v1/me': response = player
                                    elif request.method == 'GET' and parsed.path == '/api/questions/v1/assignments': response = listing
                                    elif request.method == 'GET' and parsed.path == detail_path: response = scene
                                    elif request.method == 'GET' and parsed.path in ('/api/questions/v1/notifications', '/api/questions/v1/rewards'): response = {'items': []}
                                    elif request.method == 'POST' and parsed.path == '/api/files/token': response = {'token': 'question-frame-synthetic-file-token'}
                            if response is None:
                                record = {'method': request.method, 'url': request.url}
                                if request.method == 'GET' and parsed.path.startswith('/api/files/game_players/'):
                                    raw['blocked'].append({'kind': 'unreplayed-avatar', **record})
                                else: raw['unexpectedApis'].append(record)
                                route.fulfill(status=404, headers=cors, content_type='application/json', body='{"error":{"code":"REPLAY_NOT_CONFIGURED"}}')
                            else:
                                route.fulfill(status=200, headers=cors, content_type='application/json', body=json.dumps(response, ensure_ascii=False))
                        elif request.method == 'GET' and origin == BASE_URL and parsed.path == FONT_ROUTE and not parsed.query:
                            font_checks.append(sha(font_bytes))
                            route.fulfill(status=200, content_type='font/ttf', body=font_bytes)
                        elif BOUNDARY.source_request(request.method, request.url, request.resource_type, BASE_URL, scene['id'], web):
                            route.continue_()
                        else:
                            record = {'kind': request.resource_type, 'url': request.url}
                            raw['blocked'].append(record)
                            route.abort()
                    def guarded_intercept(route):
                        try:
                            intercept(route)
                        except Exception as error:
                            raw['routeFailures'].append({'type': type(error).__name__, 'message': str(error)})
                            try:
                                route.abort()
                            except Exception:
                                pass
                    context.route('**/*', guarded_intercept)
                    require(hasattr(context, 'route_web_socket'))
                    def inert_socket(_socket):
                        raw['webSocketsBlocked'] += 1
                        # An unconnected local mock does not forward messages.
                        # Calling close here deadlocks this synchronous driver.
                    context.route_web_socket('**/*', inert_socket)
                    page = context.new_page()
                    page.set_default_timeout(15000)
                    page.set_default_navigation_timeout(30000)
                    page.on('pageerror', lambda error: raw['pageErrors'].append(str(error)))
                    page.on('console', lambda message: raw['consoleErrors'].append(message.text) if message.type == 'error' else None)
                    try:
                        page.goto(BASE_URL + '/login?theme=' + theme, wait_until='networkidle')
                        for name, data in sources.items():
                            served = bounded(page, 'return (await import(arg+"?raw")).default;', '/' + name)
                            matches = isinstance(served, str) and sha(served.encode()) == sha(data)
                            source_checks.append(matches)
                            require(matches)
                        schema = bounded(page, '''const m=await import('/src/api/game.schema.ts');
                          return [m.gamePlayerSchema.safeParse(arg.player).success,
                            m.gameAssignmentSchema.safeParse(arg.assignment).success,
                            m.gameAssignmentSummarySchema.array().safeParse(arg.assignments.items).success];''', value)
                        schema_checks.extend(schema)
                        require(schema == [True, True, True])
                        phase(theme + '-source-and-schema-verified')
                        page.get_by_label('登录账号', exact=True).fill(player['account'])
                        page.get_by_label('密码', exact=True).fill(PASSWORD)
                        page.get_by_role('button', name='进入冒险', exact=True).click()
                        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
                        page.goto(BASE_URL + '/play/' + quote(scene['id'], safe='') + '?theme=' + theme, wait_until='networkidle')
                        page.locator('.quest-card').wait_for(state='visible')
                        require(page.locator('.quest-layout.quest-desktop').count() == 0 and page.locator('.quest-card').count() == 1)
                        # BGM playback is a later slice. Use its existing close
                        # action so a browser-only permission prompt does not
                        # obscure the frame reference; never enable playback.
                        bgm_close = page.get_by_role('button', name='关闭背景音乐提示', exact=True)
                        dismissed_bgm_prompt = bgm_close.count() > 0
                        if dismissed_bgm_prompt:
                            bgm_close.click()
                            bgm_close.wait_for(state='detached')
                        raw['phases'].append({'phase': theme + '-bgm-prompt',
                            'dismissedUsingExistingClose': dismissed_bgm_prompt, 'playbackEnabled': False})
                        page.add_style_tag(content='@font-face{font-family:StarwardQuestionFrameSerif;src:url("' + BASE_URL + FONT_ROUTE +
                            '") format("truetype");font-weight:100 900;font-style:normal;font-display:block}' +
                            ':root{--font-display:StarwardQuestionFrameSerif,serif!important}')
                        require(bounded(page, 'return (await document.fonts.load("37.6px StarwardQuestionFrameSerif")).length>0;'))
                        bounded(page, 'await document.fonts.ready; return true;')
                        images = page.locator('.quest-card img')
                        require(images.count() > 0)
                        for index in range(images.count()):
                            image = images.nth(index)
                            image_url = image.evaluate('(el)=>el.currentSrc||el.src')
                            if image_url not in assets:
                                raw['unknownImages'].append({'theme': theme, 'url': image_url})
                            require(image_url in assets)
                            image.scroll_into_view_if_needed()
                            page.wait_for_function('(el)=>el.complete&&el.naturalWidth>0&&el.naturalHeight>0', arg=image.element_handle(), timeout=10000)
                        phase(theme + '-registered-images-decoded')

                        def record(position):
                            page.wait_for_load_state('networkidle')
                            require(page.get_by_role('button', name='关闭背景音乐提示', exact=True).count() == 0)
                            bounded(page, 'await document.fonts.ready; await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))); return true;')
                            require(page.evaluate('document.documentElement.dataset.theme') == theme)
                            measured = page.evaluate(MEASURE)
                            require(measured['viewport']['width'] == 376 and measured['viewport']['height'] == 742 and
                                    measured['viewport']['scrollWidth'] <= 376 and len(measured['geometry']['corners']) == 4 and
                                    measured['titleCount'] == (0 if hidden_title else 1))
                            for key in ('card', 'meta', 'content', 'body'):
                                require(measured['geometry'][key]['present'])
                            for image, geometry in zip(measured['private']['images'], measured['geometry']['images']):
                                require(image['complete'] and image['naturalWidth'] > 0 and image['naturalHeight'] > 0 and
                                        image['url'] in assets and any(row['theme'] == theme and row['url'] == image['url'] for row in raw['imagesReplayed']))
                                geometry['sourceSha256'] = assets[image['url']]['sha256']
                            stem = 'question-frame-' + theme + '-' + position
                            png = output / (stem + '.png')
                            png_sha = BOUNDARY.private_write(png, page.screenshot(full_page=False, animations='disabled'))
                            data_path, dom_path = output / (stem + '.json'), output / (stem + '.html')
                            data_sha = BOUNDARY.private_write(data_path, measured)
                            dom_sha = BOUNDARY.private_write(dom_path, page.content().encode())
                            report['states'].append({'theme': theme, 'position': position, 'geometry': measured['geometry'],
                                'viewport': measured['viewport'], 'screenshot': {'file': str(png.relative_to(ROOT)), 'sha256': png_sha},
                                'privateMeasurements': {'file': str(data_path.relative_to(ROOT)), 'sha256': data_sha},
                                'privateDom': {'file': str(dom_path.relative_to(ROOT)), 'sha256': dom_sha}})
                            phase(theme + '-' + position + '-captured')
                            return measured
                        page.evaluate('window.scrollTo(0,0)')
                        top = record('top')
                        require(abs(top['viewport']['scrollY']) < 0.5)
                        if top['geometry']['card']['y'] + top['geometry']['card']['height'] > 742:
                            page.evaluate('''()=>{const c=document.querySelector('.quest-card').getBoundingClientRect();
                              window.scrollTo(0,Math.max(0,scrollY+c.bottom-innerHeight+12));}''')
                            bottom = record('bottom')
                            card = bottom['geometry']['card']
                            require(card['y'] + card['height'] <= 742.5 and card['y'] + card['height'] > 28)
                    finally:
                        context.close()
            finally:
                browser.close()
        BOUNDARY.frozen_check(web)
        require(Path(__file__).read_bytes() == own_bytes and sha(boundary_path.read_bytes()) == BOUNDARY_SHA and
                snapshot.read_bytes() == snapshot_bytes and images_path.read_bytes() == images_bytes and font.read_bytes() == font_bytes and
                all(asset['source'].read_bytes() == asset['data'] for asset in assets.values()))
        require(not raw['pageErrors'] and not raw['unexpectedApis'] and not raw['unknownImages'] and not raw['routeFailures'] and
                len(schema_checks) == 6 and all(schema_checks) and len(source_checks) == len(SOURCES) * 2 and
                all(source_checks) and len(font_checks) >= 2 and
                sum(row['position'] == 'top' for row in report['states']) == 2)
        report['status'] = 'captured_frame_render_reference'
    except Exception as error:
        raw['failure'] = {'type': type(error).__name__, 'message': str(error)}
        failure = 'The guarded same-byte frame/type reference did not complete; private evidence retained'
    finally:
        evidence = output / 'browser-private.json'
        report['privateBrowserEvidence'] = {'file': str(evidence.relative_to(ROOT)), 'sha256': BOUNDARY.private_write(evidence, raw)}
        report['counts'] = {'states': len(report['states']), 'registeredImages': len(assets),
            'imageReplayRequests': len(raw['imagesReplayed']), 'unknownImageRequests': len(raw['unknownImages']),
            'schemaChecksExecuted': len(schema_checks), 'schemaChecksPassed': sum(item is True for item in schema_checks),
            'servedSourceChecksExecuted': len(source_checks), 'servedSourceChecksPassed': sum(source_checks),
            'fontRequestsReplayed': len(font_checks), 'apiRequestsReplayedOrBlocked': len(raw['apis']),
            'unexpectedApis': len(raw['unexpectedApis']), 'blockedAssets': len(raw['blocked']),
            'routeFailures': len(raw['routeFailures']),
            'webSocketsBlocked': raw['webSocketsBlocked'], 'consoleErrorsPrivate': len(raw['consoleErrors']),
            'pageErrors': len(raw['pageErrors'])}
        if failure: report['failure'] = failure
        encoded = (json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
        literals = private_literals(value) | set(assets)
        require(not any(item.encode() in encoded if len(item) >= 5 else ('"' + item + '"').encode() in encoded for item in literals))
        manifest.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(manifest, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(encoded)
    print(json.dumps({'status': report['status'], 'counts': report['counts'], 'manifestSha256': sha(encoded)}), flush=True)
    return 0 if failure is None else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-only same-byte frame/type replay; no service startup or real backend writes')
    run.add_argument('--url', default=BASE_URL)
    run.add_argument('--web-source', type=Path, default=ROOT.parent / 'questions-web')
    run.add_argument('--fixtures-json', type=Path, required=True)
    run.add_argument('--images-manifest', type=Path, required=True)
    run.add_argument('--expected-fixture-sha', required=True)
    run.add_argument('--font-file', type=Path, required=True)
    run.add_argument('--output-dir', type=Path, required=True)
    run.add_argument('--manifest', type=Path, required=True)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return capture(args)
    except Exception:
        print(json.dumps({'status': 'not_captured_or_report_guarded',
            'error': 'A source, fixture, image, font, output or browser guard failed; values omitted'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

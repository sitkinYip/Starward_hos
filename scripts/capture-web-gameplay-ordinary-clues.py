#!/usr/bin/env python3
"""Replay isolated clue DTOs in frozen mobile Web; never send business requests.

Run requires hash-pinned private inputs. Only local frozen Web source is fetched;
registered images, synthetic authentication and read responses are served in-browser.
"""
import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import sys
from types import ModuleType
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
FRAME = ROOT / 'scripts/capture-web-question-frame.py'
FRAME_SHA = '12f9b6563ebb95cc141043e966c009375873de0b8de764df9a0308ecf4ae520f'
FONT_SHA = '050080d9255a86808f2945bffac582b31ef32bc36411ce29563b4961670c66f9'
BASE = 'http://127.0.0.1:5178'
PHASES = ('before', 'started', 'firstCompleted', 'completed')
THEMES = ('light', 'dark')
SOURCES = ('src/index.css', 'src/api/game.schema.ts', 'src/config/ui-copy.ts', 'src/features/game/GamePlayPage.tsx',
           'src/features/game/GamePlayScene.tsx', 'src/features/game/clue-presentation.ts',
           'src/features/quest/QuestCard.tsx', 'src/features/quest/useQuestNavigationPosition.ts', 'src/features/clues/CluePanel.tsx',
           'src/features/clues/ClueTextDialog.tsx', 'src/features/content/RichContent.tsx',
           'src/domain/content/parser.ts', 'src/components/ui/Dialog.tsx',
           'src/features/media/MediaViewer.tsx', 'src/features/media/ZoomableImage.tsx',
           'src/styles/features/clues.css', 'src/styles/foundation/tokens.css', 'src/styles/components/media-viewer.css',
           'src/styles/effects/archive-lighting.css', 'src/styles/effects/overlay-lighting.css')

MEASURE = r"""() => {
  const card = document.querySelector('.quest-card'), panel = card?.querySelector('.clue-panel');
  const dialog = document.querySelector('.clue-dialog'), viewer = document.querySelector('.media-viewer');
  const rect = el => {
    if (!el) return null;
    const b = el.getBoundingClientRect(), s = getComputedStyle(el);
    return {x:b.x,y:b.y,width:b.width,height:b.height,visible:el.checkVisibility(),
      fontSize:s.fontSize,lineHeight:s.lineHeight,padding:s.padding,marginTop:s.marginTop,
      gap:s.gap,radius:s.borderRadius,columns:s.gridTemplateColumns,color:s.color,
      scrollTop:el.scrollTop,clientHeight:el.clientHeight,scrollHeight:el.scrollHeight};
  };
  const selectors = {
    card, answer:card?.querySelector('.answer-form'), panel,
    heading:panel?.querySelector('.clue-panel-heading'), sectionTitle:panel?.querySelector('h2'),
    count:panel?.querySelector('.clue-panel-count'), list:panel?.querySelector('.clue-list'), dialog,
    dialogScroll:dialog?.querySelector('.clue-dialog-scroll'), dialogClose:dialog?.querySelector('.clue-dialog-close'),
    dialogEyebrow:dialog?.querySelector('.eyebrow'), dialogTitle:dialog?.querySelector('.clue-dialog-scroll > h2'),
    dialogRule:dialog?.querySelector('.clue-dialog-rule'), dialogBody:dialog?.querySelector('.clue-dialog-content'),
    viewer, viewerStage:viewer?.querySelector('.media-viewer-stage--zoom'),
    viewerImage:viewer?.querySelector('.media-viewer-stage--zoom > img'),
    viewerNav:viewer?.querySelector('.media-viewer-navigation'), viewerClose:viewer?.querySelector('.media-viewer-close'),
  };
  const rows = [...(panel?.querySelectorAll('.clue-card') ?? [])];
  const picture = selectors.viewerImage;
  return {
    viewport:{width:innerWidth,height:innerHeight,dpr:devicePixelRatio,coarse:matchMedia('(pointer:coarse)').matches,
      theme:document.documentElement.dataset.theme,scrollY,visualScale:visualViewport?.scale||1,
      documentWidth:document.documentElement.scrollWidth},
    geometry:Object.fromEntries(Object.entries(selectors).map(([key,el])=>[key,rect(el)])),
    rows:rows.map(row=>({kind:row.dataset.kind,card:rect(row),lead:rect(row.querySelector('.clue-index')),
      status:rect(row.querySelector('.clue-card-status')), title:rect(row.querySelector('.clue-card-body > strong')),
      preview:rect(row.querySelector('.clue-preview')),arrow:rect(row.querySelector('.clue-card-action'))})),
    private:{question:card?.querySelector('.quest-meta > span')?.textContent,
      count:selectors.count?.querySelector('strong')?.textContent,
      rows:rows.map(row=>({title:row.querySelector('.clue-card-body > strong')?.textContent,
        index:row.querySelector('.clue-index > strong')?.textContent,
        preview:row.querySelector('.clue-preview')?.innerText})),
      dialogTitle:selectors.dialogTitle?.textContent,dialogText:selectors.dialogBody?.innerText,
      marks:[...(selectors.dialogBody?.querySelectorAll('mark')??[])].map(n=>n.textContent),
      viewerPosition:selectors.viewerNav?.querySelector('span')?.textContent,
      picture:picture?{url:picture.currentSrc||picture.src,complete:picture.complete,width:picture.naturalWidth,height:picture.naturalHeight}:null}
  };
}"""


def sha(raw):
    return sha256(raw).hexdigest()


def require(condition, detail='guard'):
    if not condition:
        raise ValueError(detail)


def load_frame():
    raw = FRAME.read_bytes()
    require(sha(raw) == FRAME_SHA)
    frame = ModuleType('ordinary_clue_frozen_frame')
    frame.__file__ = str(FRAME)
    exec(compile(raw, str(FRAME), 'exec'), frame.__dict__)
    return frame


def expected_clues(scene, index):
    level = scene['levels'][index]
    if not level['completedAt']:
        return []
    candidates = []
    for clue in scene['clues']:
        bound, source = clue['sessionLevel'], clue.get('source', 'session')
        combo = (source == 'session' and scene['totalLevels'] > 1 and not bound and
                 clue['trigger'] == 'session_completed' and clue['kind'] == 'text')
        if combo or (source == 'question' and bound != level['id']) or (bound and bound != level['id']):
            continue
        candidates.append(clue)
    return sorted(candidates, key=lambda clue: (clue.get('source', 'session') != 'session',
        clue['position'], clue.get('definitionId') or clue['id'], clue['id']))


def read_fixture(frame, path, digest):
    path = frame.private_input(path)
    raw = path.read_bytes()
    require(sha(raw) == digest, 'fixture hash')
    data = json.loads(raw)
    require(set(data) == set(PHASES), 'fixture phases')
    require(not re.search(r'"(?:token|password|authorization|controltoken|answerkey)"\s*:', raw.decode(), re.I))
    base = data['before']
    player, scene = base['player'], base['assignment']
    require(re.fullmatch(r'hm_[a-f0-9]{12}', player['account']) and player['mustChangePassword'] is False and
        all(re.fullmatch(r'[a-z0-9]{15}', value) for value in (player['id'], scene['id'])), 'isolated player')
    for phase, status, done in zip(PHASES, ('assigned', 'active', 'active', 'completed'), (0, 0, 1, 2)):
        dto = data[phase]
        require(set(dto) == {'player', 'assignment', 'assignments'}, 'fixture DTO keys')
        p, a, listing = dto['player'], dto['assignment'], dto['assignments']['items']
        require((p['id'], p['account'], p['mustChangePassword']) == (player['id'], player['account'], False) and
            (a['id'], a['player'], a['session'], a['status'], a['totalLevels'], a['completedLevels']) ==
            (scene['id'], p['id'], scene['session'], status, 2, done) and
            len(a['levels']) == 2 and [row['id'] for row in a['levels']] == [row['id'] for row in scene['levels']] and
            sum(bool(row['completedAt']) for row in a['levels']) == done and
            all(row['player'] == p['id'] for row in listing) and
            sum(row['id'] == a['id'] and row['status'] == a['status'] for row in listing) == 1 and
            bool(a['startedAt']) == (phase != 'before') and not a.get('transitionEffects'), 'authoritative fixture')
    started, first, final = (data[phase]['assignment'] for phase in PHASES[1:])
    require(not scene['clues'] and started['levels'][0]['question'] and not started['levels'][1]['question'] and
        first['levels'][0]['question'] and first['levels'][1]['question'] and first['levels'][0]['completedAt'] and
        not first['levels'][1]['completedAt'] and all(row['question'] for row in final['levels']), 'readability states')
    first_clues = expected_clues(first, 0)
    rich = next((clue for clue in first_clues if clue['kind'] == 'text' and clue.get('source') == 'question'
                 and '[[' in clue['content']['text'] and '{{' in clue['content']['text']), None)
    gallery = next((clue for clue in first_clues if clue['kind'] == 'image' and len(clue['content']['imageUrls']) > 1), None)
    require(rich and gallery and any(row.get('source') == 'session' and not row['sessionLevel'] for row in first_clues) and
        any(row['kind'] not in ('text', 'image') for row in first_clues) and
        any(row['kind'] == 'text' and row['trigger'] == 'session_completed' and not row['sessionLevel']
            and row.get('source', 'session') == 'session' for row in final['clues']), 'fixture coverage')
    return path, raw, data, rich, gallery


def read_media(frame, path, digest):
    path = frame.private_input(path)
    raw = path.read_bytes()
    require(sha(raw) == digest, 'media manifest hash')
    rows = json.loads(raw)['assets']
    require(isinstance(rows, list) and 1 < len(rows) <= 50, 'media entries')
    assets = {}
    for row in rows:
        source = frame.private_input(Path(row['file']))
        data, target, mime = source.read_bytes(), urlparse(row['url']), row['detectedMime']
        require(target.scheme == 'https' and target.hostname and not target.username and not target.password and
            not target.fragment and row['url'] not in assets and len(data) == row['bytes'] and
            0 < len(data) <= 20 * 1024 * 1024 and sha(data) == row['sha256'] and
            ((mime == 'image/png' and data.startswith(b'\x89PNG\r\n\x1a\n')) or
             (mime == 'image/jpeg' and data.startswith(b'\xff\xd8\xff'))), 'registered image')
        assets[row['url']] = {'data': data, 'source': source, 'mime': mime, 'sha256': row['sha256']}
    require(sum(len(row['data']) for row in assets.values()) <= 80 * 1024 * 1024, 'media total bytes')
    return path, raw, assets


def image_inputs(data):
    images = set()
    for dto in data.values():
        scene = dto['assignment']
        for level in scene['levels']:
            question = level['question']
            if question:
                images.update(url for block in question['content']
                    for url in [block.get('imageUrl'), *block.get('imageUrls', [])] if url)
                images.update(option['imageUrl'] for option in question['options'] if option.get('imageUrl'))
        for clue in scene['clues']:
            if clue['kind'] in ('text', 'image'):
                images.update(url.strip() for url in re.findall(r'\{\{(.*?)\}\}', clue['content']['text'], re.S))
                if clue['kind'] == 'image':
                    images.update(clue['content']['imageUrls'])
    return images


def title_of(clue):
    fallback = {'text': '古老密卷', 'image': '神谕影像', 'video': '时空回溯', 'link': '位面传送',
                'letter': '星海情笺', 'bless': '星辉祝福'}
    return clue['content']['title'] or fallback[clue['kind']]


def render(browser, frame, args, sources, font, assets, failed_url, dto, rich, gallery,
           phase, theme, output, report, raw, font_control=False):
    p, a, listing = dto['player'], dto['assignment'], dto['assignments']
    reads = {'/api/questions/v1/me': p, '/api/questions/v1/assignments': listing,
             '/api/questions/v1/assignments/' + a['id']: a,
             '/api/questions/v1/rewards': {'items': []}, '/api/questions/v1/notifications': {'items': []}}
    allowed = (*reads, frame.AUTH, '/api/files/token')
    cors = {'Access-Control-Allow-Origin': BASE, 'Access-Control-Allow-Headers': 'Authorization,Content-Type,Accept',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'}
    tag = {'phase': phase, 'theme': theme, 'fontMode': 'native_font_byte_control' if font_control else 'frozen_web_css'}

    def reply(route, data):
        route.fulfill(status=200, headers=cors, content_type='application/json', body=json.dumps(data, ensure_ascii=False))

    def dispatch(route):
        request = route.request
        parsed = urlparse(request.url)
        origin = parsed.scheme + '://' + parsed.netloc
        if request.method == 'GET' and request.resource_type == 'image' and request.url in assets:
            require(not request.headers.get('authorization'), 'media auth')
            asset = assets[request.url]
            raw['imagesReplayed'].append({**tag, 'url': request.url, 'sha256': asset['sha256']})
            route.fulfill(content_type=asset['mime'], body=asset['data'])
        elif request.method == 'GET' and request.resource_type == 'image' and request.url == failed_url:
            raw['imagesFailedByDesign'].append(tag)
            route.abort('failed')
        elif parsed.path.startswith('/api/'):
            raw['apiIntercepted'].append({**tag, 'method': request.method, 'url': request.url})
            if origin == frame.API_ORIGIN and not parsed.query and request.method == 'OPTIONS' and parsed.path in allowed:
                route.fulfill(status=204, headers=cors, body='')
            elif origin == frame.API_ORIGIN and not parsed.query and request.method == 'POST' and parsed.path == frame.AUTH:
                require(request.post_data_json == {'identity': p['account'], 'password': frame.PASSWORD}, 'synthetic sign in')
                reply(route, {'token': frame.TOKEN, 'record': {'id': p['id']}})
            elif origin == frame.API_ORIGIN and not parsed.query and request.headers.get('authorization') == frame.TOKEN:
                if request.method == 'GET' and parsed.path in reads:
                    reply(route, reads[parsed.path])
                elif request.method == 'POST' and parsed.path == '/api/files/token':
                    reply(route, {'token': 'clue-render-only-file-token'})
                else:
                    raw['unexpectedApis'].append({**tag, 'method': request.method, 'url': request.url})
                    route.abort()
            else:
                key = ('blocked' if origin == frame.API_ORIGIN and request.method == 'GET' and
                       parsed.path.startswith('/api/files/game_players/') else 'unexpectedApis')
                raw[key].append({**tag, 'method': request.method, 'url': request.url})
                route.abort()
        elif request.method == 'GET' and origin == BASE and parsed.path == frame.FONT_ROUTE and not parsed.query:
            raw['fontsReplayed'] += 1
            route.fulfill(content_type='font/ttf', body=font)
        elif frame.BOUNDARY.source_request(request.method, request.url, request.resource_type, BASE, a['id'], args.web_source):
            route.continue_()
        else:
            raw['blocked'].append({**tag, 'kind': request.resource_type, 'url': request.url})
            route.abort()

    def intercept(route):
        try:
            dispatch(route)
        except Exception as error:
            raw['routeFailures'].append({**tag, 'type': type(error).__name__, 'detail': str(error)})
            route.abort()

    def no_socket(_socket):
        raw['webSocketsBlocked'] += 1

    context = browser.new_context(viewport={'width': args.width, 'height': args.height}, device_scale_factor=1,
        is_mobile=True, has_touch=True, color_scheme=theme, reduced_motion='reduce', locale='zh-CN',
        timezone_id='Asia/Shanghai', service_workers='block', accept_downloads=False)
    try:
        context.route('**/*', intercept)
        context.route_web_socket('**/*', no_socket)
        page = context.new_page()
        page.set_default_timeout(15000)
        page.on('pageerror', lambda error: raw['pageErrors'].append({**tag, 'message': str(error)}))
        page.goto(BASE + '/login?theme=' + theme, wait_until='networkidle')
        for filename, content in sources.items():
            served = frame.bounded(page, 'return (await import(arg+"?raw")).default;', '/' + filename)
            require(isinstance(served, str) and sha(served.encode()) == sha(content), 'served source')
            raw['servedSourceChecks'] += 1
        schema = frame.bounded(page, """const m=await import('/src/api/game.schema.ts'); return [
          m.gamePlayerSchema.safeParse(arg.player).success,m.gameAssignmentSchema.safeParse(arg.assignment).success,
          m.gameAssignmentSummarySchema.array().safeParse(arg.assignments.items).success];""", dto)
        require(schema == [True, True, True], 'frozen schema')
        raw['schemaChecks'] += len(schema)
        page.get_by_label('登录账号', exact=True).fill(p['account'])
        page.get_by_label('密码', exact=True).fill(frame.PASSWORD)
        page.get_by_role('button', name='进入冒险', exact=True).click()
        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
        page.goto(BASE + '/play/' + a['id'] + '?theme=' + theme, wait_until='networkidle')
        card = page.locator('.quest-card')
        panel = card.locator('.clue-panel')
        nav = page.get_by_role('navigation', name='题目导航', exact=True)
        dialog = page.locator('.clue-dialog')
        viewer = page.locator('.media-viewer')
        picture = viewer.locator('.media-viewer-stage--zoom > img')
        card.wait_for()
        require(card.count() == 1 and nav.get_by_role('button').count() == 2 and
                page.locator('.quest-layout.quest-desktop').count() == 0, 'mobile scene')
        for name in ('关闭背景音乐提示', '知道了'):
            prompt = page.get_by_role('button', name=name, exact=True)
            if prompt.count() == 1 and prompt.is_visible():
                prompt.click()
                prompt.wait_for(state='detached')
        if font_control:
            page.add_style_tag(content='@font-face{font-family:StarwardClueSerif;src:url("' + BASE + frame.FONT_ROUTE +
                '") format("truetype");font-weight:100 900;font-style:normal;font-display:block}' +
                ':root{--font-display:StarwardClueSerif,serif!important}')
            require(frame.bounded(page, 'return (await document.fonts.load("24px StarwardClueSerif")).length>0;'), 'font')
        require(dialog.count() == 0 and viewer.count() == 0, 'manual read never opens overlay')
        api_before = len(raw['apiIntercepted'])

        def select(index):
            button = nav.get_by_role('button').nth(index)
            changed = button.get_attribute('aria-current') != 'step'
            if changed:
                button.tap()
            page.wait_for_function("index=>document.querySelector('.quest-card .quest-meta > span')?.textContent===`第 ${index+1} 题`", arg=index)
            if changed:
                page.wait_for_function("()=>document.activeElement===document.querySelector('.quest-card')")

        def settled():
            frame.bounded(page, '''await document.fonts.ready;
              await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
              const selector = '.quest-card,.clue-dialog,.clue-dialog-backdrop,.media-viewer,.media-viewer-backdrop';
              const animations = new Set([...document.querySelectorAll(selector)].flatMap(node=>node.getAnimations({subtree:true})));
              await Promise.allSettled([...animations].filter(a=>Number.isFinite(a.effect?.getComputedTiming().endTime)).map(a=>a.finished));
              await new Promise(r=>requestAnimationFrame(r)); return true;''')

        def measure(index):
            settled()
            found = page.evaluate(MEASURE)
            vp, private = found['viewport'], found['private']
            require((vp['width'], vp['height'], vp['dpr'], vp['visualScale'], vp['coarse'], vp['theme']) ==
                (args.width, args.height, 1, 1, True, theme) and vp['documentWidth'] <= args.width, 'viewport')
            require(private['question'] == f'第 {index+1} 题', 'active question')
            clues = expected_clues(a, index)
            require(bool(found['geometry']['panel']) == bool(clues) and len(found['rows']) == len(clues), 'ordinary panel membership')
            if clues:
                # A modal legitimately makes its background inaccessible while
                # the ordinary archive remains mounted in the DOM.
                require(private['count'] == f'{len(clues):02d}' and panel.locator('h2').text_content() == '通关线索' and
                    panel.locator('.clue-panel-count').get_attribute('aria-label') == f'已解锁 {len(clues)} 件线索', 'section copy')
                for number, (clue, row, private_row) in enumerate(zip(clues, found['rows'], private['rows']), 1):
                    require(row['kind'] == clue['kind'] and private_row['title'] == title_of(clue) and
                            private_row['index'] == f'{number:02d}', 'row order and copy')
                    if clue['kind'] in ('text', 'image'):
                        require(not row['status']['visible'], 'mobile hides ordinary status')
                    if not clue['content']['text']:
                        require(private_row['preview'] == '点击查看已解锁内容', 'empty preview copy')
            return found

        def record(name, index):
            measured = measure(index)
            prefix = output / (f'{phase}-{theme}-{name}' + ('-native-font-control' if font_control else ''))
            details, png, dom = (prefix.with_suffix(ext) for ext in ('.json', '.png', '.html'))
            geometry = measured['geometry']
            image = measured['private']['picture']
            public_image = ({'width': image['width'], 'height': image['height'], 'complete': image['complete'],
                'sourceSha256': assets[image['url']]['sha256'] if image['url'] in assets else None} if image else None)
            files = {}
            for key, path, value in (('screenshot', png, page.screenshot(animations='disabled')),
                ('privateMeasurements', details, measured), ('privateDom', dom, page.content().encode())):
                files[key] = {'file': str(path.relative_to(ROOT)), 'sha256': frame.BOUNDARY.private_write(path, value)}
            report['states'].append({**tag, 'state': name, 'question': index + 1, 'viewport': measured['viewport'],
                'geometry': geometry, 'rows': measured['rows'], 'currentImage': public_image,
                'inlineHighlights': len(measured['private']['marks']), **files})
            return measured

        def panel_anchor():
            settled()
            panel.locator('.clue-panel-heading').evaluate('(node)=>node.scrollIntoView({block:"start",behavior:"instant"})')

        def row_for(clue):
            index = expected_clues(a, 0).index(clue)
            return panel.locator('.clue-card').nth(index)

        def assert_dialog():
            dialog.wait_for()
            require(dialog.locator('.clue-dialog-scroll > h2').text_content() == title_of(rich) and
                    page.get_by_role('dialog', name=title_of(rich), exact=True).count() == 1 and
                    dialog.locator('.eyebrow').text_content() == 'Decoded fragment' and
                    dialog.get_by_role('button', name='关闭线索', exact=True).count() == 1 and
                    dialog.locator('mark').count() > 0, 'text dialog structure')

        def expected_picture(url, broken=False):
            picture.wait_for()
            page.wait_for_function("""({url,broken})=>{const image=document.querySelector('.media-viewer-stage--zoom > img');
              return image&&(image.currentSrc||image.src)===url&&image.complete&&(broken?image.naturalWidth===0:image.naturalWidth>0);}""",
                arg={'url': url, 'broken': broken})

        if font_control:
            select(0)
            panel_anchor()
            record('completed-clue-panel', 0)
            row_for(rich).tap()
            assert_dialog()
            record('rich-text-open', 0)
        elif phase == 'started':
            select(0)
            require(nav.get_by_role('button').nth(1).is_disabled(), 'second question locked')
            card.evaluate('(node)=>node.scrollIntoView({block:"start",behavior:"instant"})')
            record('unanswered-locked-neighbor', 0)
        elif phase == 'firstCompleted':
            select(1)
            card.evaluate('(node)=>node.scrollIntoView({block:"start",behavior:"instant"})')
            record('unanswered-with-global-clue', 1)
            select(0)
            panel_anchor()
            record('completed-clue-panel', 0)
            row_for(rich).tap()
            assert_dialog()
            record('rich-text-open', 0)
            inline = dialog.locator('.clue-dialog-content .rich-media-trigger img').first
            inline.scroll_into_view_if_needed()
            inline_url = inline.evaluate('(img)=>img.currentSrc||img.src')
            require(inline_url in assets, 'registered inline image')
            page.wait_for_function('(img)=>img.complete&&img.naturalWidth>0', arg=inline.element_handle())
            record('rich-text-inline', 0)
            dialog.get_by_role('button', name='放大查看图片', exact=True).first.tap()
            expected_picture(inline_url)
            record('rich-text-image-viewer', 0)
            viewer.get_by_role('button', name='关闭媒体预览', exact=True).tap()
            viewer.wait_for(state='detached')
            assert_dialog()
            dialog.get_by_role('button', name='关闭线索', exact=True).tap()
            dialog.wait_for(state='detached')
            row_for(rich).tap()
            assert_dialog()
            page.keyboard.press('Escape')
            dialog.wait_for(state='detached')

            urls = gallery['content']['imageUrls']
            row_for(gallery).tap()
            expected_picture(urls[0])
            first = record('gallery-first', 0)
            require(re.sub(r'\s', '', first['private']['viewerPosition']) == f'1/{len(urls)}', 'gallery opening position')
            next_button = viewer.get_by_role('button', name='下一张', exact=True)
            next_button.tap()
            expected_picture(urls[1])
            second = record('gallery-second', 0)
            require(re.sub(r'\s', '', second['private']['viewerPosition']) == f'2/{len(urls)}', 'gallery next position')
            viewer.get_by_role('button', name='关闭媒体预览', exact=True).tap()
            viewer.wait_for(state='detached')
            if failed_url:
                broken = next(clue for clue in expected_clues(a, 0) if failed_url in clue['content']['imageUrls'])
                broken_urls = broken['content']['imageUrls']
                row_for(broken).tap()
                expected_picture(broken_urls[0], broken_urls[0] == failed_url)
                for url in broken_urls[1:broken_urls.index(failed_url) + 1]:
                    next_button.tap()
                    expected_picture(url, url == failed_url)
                record('gallery-asset-failed', 0)
                page.keyboard.press('Escape')
                viewer.wait_for(state='detached')
            panel_anchor()
            record('closed-to-same-panel', 0)
        elif phase == 'completed':
            select(1)
            panel_anchor()
            record('last-completed-clue-panel', 1)
        # The frozen app can poll notifications while a dialog is being read.
        # These are local read replays, and never business writes or forwarding.
        during = raw['apiIntercepted'][api_before:]
        require(all(item['method'] in ('GET', 'OPTIONS') and urlparse(item['url']).path in reads
                    for item in during), 'clue interactions are read-only')
        report['checks'].append({**tag, 'noInteractionWriteRequests': True,
            'incidentalReadRequestsReplayed': len(during), 'ordinaryRowsMatchedWebRules': True})
    finally:
        context.close()


def capture(args):
    frame = load_frame()
    boundary = frame.BOUNDARY
    args.web_source = args.web_source.resolve()
    boundary.frozen_check(args.web_source)
    source_bytes = {name: (args.web_source / name).read_bytes() for name in SOURCES}
    script = Path(__file__).read_bytes()
    fixture_path, fixture_bytes, data, rich, gallery = read_fixture(frame, args.fixtures_json, args.fixtures_sha)
    media_path, media_bytes, assets = read_media(frame, args.media_manifest, args.media_sha)
    unregistered = image_inputs(data) - set(assets)
    failed_url = 'https://starward-clue-test.invalid/no-image.png'
    require(unregistered <= {failed_url}, 'unregistered image')
    if failed_url not in unregistered:
        failed_url = None
    font = frame.NATIVE_FONT.read_bytes()
    require(sha(font) == FONT_SHA, 'font hash')
    output = boundary.path_in(args.output_dir, frame.PRIVATE)
    manifest = boundary.path_in(args.manifest, frame.PUBLIC)
    require(not output.exists() and not manifest.exists(), 'fresh output paths')
    boundary.fresh_directory(output)
    boundary.private_write(output / 'input-dtos.json', fixture_bytes)
    report = {'status': 'incomplete', 'sourceCommit': frame.FROZEN, 'captureScriptSha256': sha(script),
        'boundaryHelperSha256': frame.BOUNDARY_SHA, 'fixtureSha256': sha(fixture_bytes),
        'mediaManifestSha256': sha(media_bytes), 'fontSha256': sha(font),
        'sourceSha256': {name: sha(content) for name, content in source_bytes.items()},
        'registeredImageSha256': sorted({item['sha256'] for item in assets.values()}),
        'externalRequestsContinued': 0, 'businessRequestsContinued': 0,
        'syntheticAuthentication': True, 'realBusinessAcceptance': False, 'nativeAcceptance': False,
        'visualReview': 'pending_original_review', 'fontModes': ['frozen_web_css', 'native_font_byte_control'],
        'scope': 'Frozen Web shows all ordinary clue kinds; Native text/image scope is narrower.',
        'states': [], 'checks': []}
    raw = {key: [] for key in ('apiIntercepted', 'blocked', 'unexpectedApis', 'imagesReplayed', 'imagesFailedByDesign',
           'routeFailures', 'pageErrors')}
    raw.update({key: 0 for key in ('fontsReplayed', 'webSocketsBlocked', 'servedSourceChecks', 'schemaChecks')})
    failure = False
    try:
        package = frame.PRIVATE / 'python-playwright'
        if package.is_dir():
            sys.path.insert(0, str(package))
        from playwright.sync_api import sync_playwright
        with sync_playwright() as play:
            browser = play.chromium.launch(headless=True, timeout=30000, args=['--disable-background-networking'])
            try:
                for phase in PHASES[1:]:
                    for theme in THEMES:
                        render(browser, frame, args, source_bytes, font, assets, failed_url, data[phase], rich, gallery,
                               phase, theme, output, report, raw)
                for theme in THEMES:
                    render(browser, frame, args, source_bytes, font, assets, failed_url, data['firstCompleted'], rich, gallery,
                           'firstCompleted', theme, output, report, raw, font_control=True)
            finally:
                browser.close()
        boundary.frozen_check(args.web_source)
        require(Path(__file__).read_bytes() == script and sha(FRAME.read_bytes()) == FRAME_SHA and
                sha((ROOT / 'scripts/capture-web-ui-sample.py').read_bytes()) == frame.BOUNDARY_SHA and
                frame.NATIVE_FONT.read_bytes() == font and fixture_path.read_bytes() == fixture_bytes and
                media_path.read_bytes() == media_bytes and all(item['source'].read_bytes() == item['data'] for item in assets.values()) and
                all((args.web_source / name).read_bytes() == content for name, content in source_bytes.items()), 'input provenance')
        require(not any(raw[key] for key in ('unexpectedApis', 'routeFailures', 'pageErrors')) and
            raw['fontsReplayed'] == 2 and raw['servedSourceChecks'] == 8 * len(SOURCES) and raw['schemaChecks'] == 24 and
            len(report['checks']) == 8 and len(report['states']) == (26 if failed_url else 24) and
            (len(raw['imagesFailedByDesign']) >= 2 if failed_url else not raw['imagesFailedByDesign']), 'final state counts')
        report['status'] = 'captured_web_gameplay_ordinary_clues_reference'
    except Exception as error:
        failure = True
        raw['failure'] = {'type': type(error).__name__, 'detail': str(error)}
        report['failure'] = 'Guarded capture incomplete; detailed evidence retained privately.'
    finally:
        evidence = output / 'browser-private.json'
        report['privateBrowserEvidence'] = {'file': str(evidence.relative_to(ROOT)), 'sha256': boundary.private_write(evidence, raw)}
        report['counts'] = {key: len(value) if isinstance(value, list) else value for key, value in raw.items() if key != 'failure'}
        report['counts'].update({'states': len(report['states']), 'checks': len(report['checks'])})
        encoded = (json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
        literals = {item for dto in data.values() for item in frame.private_literals(dto)} | set(assets)
        require(not re.search(rb'https?://', encoded) and not any(
            item.encode() in encoded if len(item) >= 5 else ('"' + item + '"').encode() in encoded for item in literals),
            'public evidence privacy')
        manifest.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(manifest, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(encoded)
    print(json.dumps({'status': report['status'], 'states': len(report['states']), 'manifestSha256': sha(encoded)}), flush=True)
    return int(failure)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    run = parser.add_subparsers(dest='action').add_parser('run')
    run.add_argument('--web-source', type=Path, default=ROOT.parent / 'questions-web')
    for name in ('fixtures-json', 'media-manifest', 'output-dir', 'manifest'):
        run.add_argument('--' + name, type=Path, required=True)
    for name in ('fixtures-sha', 'media-sha'):
        run.add_argument('--' + name, required=True)
    run.add_argument('--width', type=int, required=True, help='Measured Native logical content viewport width')
    run.add_argument('--height', type=int, required=True, help='Measured Native logical content viewport height excluding system areas')
    args = parser.parse_args()
    if args.action is None:
        parser.print_help()
        return 0
    try:
        require(320 <= args.width <= 620 and 500 <= args.height <= 1200 and
            all(re.fullmatch(r'[a-f0-9]{64}', value) for value in (args.fixtures_sha, args.media_sha)), 'viewport/hash arguments')
        return capture(args)
    except Exception:
        print(json.dumps({'status': 'not_captured_or_report_guarded',
            'error': 'Explicit frozen source, fixture, image, font or output prerequisite failed. Values omitted.'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

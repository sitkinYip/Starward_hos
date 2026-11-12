#!/usr/bin/env python3
"""Capture the frozen mobile Web link dialogs from two real isolated snapshots."""
import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import sys
from types import ModuleType
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
FRAME = ROOT / 'scripts/capture-web-question-frame.py'
FRAME_SHA = '12f9b6563ebb95cc141043e966c009375873de0b8de764df9a0308ecf4ae520f'
WEB_BASE = 'http://127.0.0.1:5178'
GAME = '/api/questions/v1'
SOURCES = ('src/index.css', 'src/api/game.schema.ts', 'src/domain/content/parser.ts',
           'src/features/clues/CluePanel.tsx', 'src/features/clues/ClueTextDialog.tsx',
           'src/features/clues/MultiQuestClueDialog.tsx', 'src/features/content/RichContent.tsx',
           'src/styles/foundation/base.css', 'src/styles/features/clues.css',
           'src/styles/effects/overlay-lighting.css')
MARKUP = re.compile(r'\(\((.*?)\|\|(.*?)\)\)(?!\))', re.S)
DRAFT = '未提交的航海手记'


def digest(raw):
    return sha256(raw).hexdigest()


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def load_frame():
    raw = FRAME.read_bytes()
    require(digest(raw) == FRAME_SHA, 'Frozen frame helper changed')
    frame = ModuleType('clue_link_web_frame')
    frame.__file__ = str(FRAME)
    exec(compile(raw, str(FRAME), 'exec'), frame.__dict__)
    return frame


def phase(frame, path, expected, mode):
    source = frame.private_input(path)
    raw = source.read_bytes()
    require(digest(raw) == expected, 'Snapshot hash differs')
    data = json.loads(raw)['second' if mode == 'ordinary' else 'completed']
    p, a = data['player'], data['assignment']
    require(re.fullmatch(r'hm_[a-f0-9]{12}', p['account']) and not p['mustChangePassword'] and
            a['player'] == p['id'] and a['status'] == ('active' if mode == 'ordinary' else 'completed') and
            a['currentIndex'] == 1 and a['totalLevels'] == 2 and a['completedLevels'] == (1 if mode == 'ordinary' else 2) and
            not a.get('transitionEffects') and any(x['id'] == a['id'] for x in data['assignments']['items']),
            'Snapshot is not the expected isolated actor and phase')
    trigger = 'start' if mode == 'ordinary' else 'session_completed'
    [clue] = [x['content'] for x in a['clues'] if x['trigger'] == trigger and x['kind'] == 'text' and
              x['source'] == 'session' and not x['sessionLevel'] and x['unlockedAt']]
    return source, raw, data, clue


def render(browser, frame, args, sources, data, clue, mode, theme, output, report, private):
    p, a = data['player'], data['assignment']
    route_url = WEB_BASE + '/play/' + a['id'] + '?theme=' + theme
    reads = {GAME + '/me': p, GAME + '/assignments': data['assignments'], GAME + '/assignments/' + a['id']: a,
             GAME + '/notifications': {'items': []}, GAME + '/rewards': {'items': []}}
    allowed_api = {*reads, frame.AUTH, '/api/files/token'}
    cors = {'Access-Control-Allow-Origin': WEB_BASE, 'Access-Control-Allow-Headers': 'Authorization,Content-Type,Accept',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'}
    matched = [(m[1], m[2]) for m in MARKUP.finditer(clue['text'])]
    links = [(label, href) for label, href in matched if urlsplit(href).scheme in ('https', 'http')]
    inert = [label for label, href in matched if urlsplit(href).scheme not in ('https', 'http')]
    require(len(links) == (2 if mode == 'ordinary' else 1) and len(inert) == int(mode == 'ordinary'),
            'Fixture link shape differs')
    target = links[0][1]
    popup_requests = []

    def handle(route):
        req = route.request
        uri = urlsplit(req.url)
        origin = uri.scheme + '://' + uri.netloc
        if req.url == target and req.method == 'GET' and req.resource_type == 'document':
            require('authorization' not in req.headers and 'referer' not in req.headers, 'External request leaked a header')
            popup_requests.append(req.url)
            route.fulfill(content_type='text/html', body='<!doctype html><title>Isolated popup</title>')
        elif uri.path.startswith('/api/'):
            if origin == frame.API_ORIGIN and not uri.query and uri.path in allowed_api:
                if req.method == 'OPTIONS':
                    route.fulfill(status=204, headers=cors, body='')
                    return
                if uri.path == frame.AUTH and req.method == 'POST':
                    require(req.post_data_json == {'identity': p['account'], 'password': frame.PASSWORD}, 'Browser-only login differs')
                    value = {'token': frame.TOKEN, 'record': {'id': p['id']}}
                elif req.headers.get('authorization') == frame.TOKEN and req.method == 'GET' and uri.path in reads:
                    value = reads[uri.path]
                elif req.headers.get('authorization') == frame.TOKEN and req.method == 'POST' and uri.path == '/api/files/token':
                    value = {'token': 'clue-link-replay-only-file-token'}
                else:
                    raise ValueError('Unexpected method or auth in browser replay')
                route.fulfill(status=200, headers=cors, content_type='application/json', body=json.dumps(value))
            else:
                require(origin == frame.API_ORIGIN and req.method == 'GET' and uri.path.startswith('/api/files/game_players/'),
                        'Unexpected API intercepted')
                route.abort()
        elif frame.BOUNDARY.source_request(req.method, req.url, req.resource_type, WEB_BASE, a['id'], args.web_source):
            route.continue_()
        else:
            route.abort()

    errors = []

    def guard(route):
        try:
            handle(route)
        except Exception as error:
            errors.append({'url': route.request.url, 'error': str(error)})
            route.abort()

    context = browser.new_context(viewport={'width': args.width, 'height': args.height}, device_scale_factor=1,
                                  color_scheme=theme, reduced_motion='reduce', is_mobile=True, has_touch=True,
                                  locale='zh-CN', service_workers='block', accept_downloads=False)
    try:
        context.route('**/*', guard)
        context.route_web_socket('**/*', lambda _socket: None)
        page = context.new_page()
        page.on('pageerror', lambda error: errors.append({'error': str(error)}))
        page.set_default_timeout(15000)
        page.goto(WEB_BASE + '/login?theme=' + theme, wait_until='networkidle')
        for name, raw in sources.items():
            served = frame.bounded(page, 'return (await import(arg+"?raw")).default;', '/' + name)
            require(isinstance(served, str) and digest(served.encode()) == digest(raw), 'Served Web source hash differs')
        schema = frame.bounded(page, """const m=await import('/src/api/game.schema.ts');return [
          m.gamePlayerSchema.safeParse(arg.player).success,m.gameAssignmentSchema.safeParse(arg.assignment).success,
          m.gameAssignmentSummarySchema.array().safeParse(arg.assignments.items).success];""", data)
        require(schema == [True, True, True], 'Web schema rejected an input')
        page.get_by_label('登录账号', exact=True).fill(p['account'])
        page.get_by_label('密码', exact=True).fill(frame.PASSWORD)
        page.get_by_role('button', name='进入冒险', exact=True).tap()
        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
        page.goto(route_url, wait_until='networkidle')
        card = page.locator('.quest-card')
        card.wait_for()
        require(card.count() == 1 and page.locator('.quest-layout.quest-desktop').count() == 0, 'Expected a single mobile question')
        for label in ('关闭背景音乐提示', '知道了'):
            prompt = page.get_by_role('button', name=label, exact=True)
            if prompt.count() == 1 and prompt.is_visible():
                prompt.tap()
                prompt.wait_for(state='detached')
        answer = None
        if mode == 'ordinary':
            nav = page.locator('nav.quest-nav button')
            require(nav.count() == 2 and nav.nth(1).get_attribute('aria-current') == 'step', 'Expected current question two')
            answer = card.locator('input')
            require(answer.count() == 1 and answer.is_enabled(), 'In-progress text answer unavailable')
            answer.fill(DRAFT)
            nav.nth(0).tap()
            require(nav.nth(0).get_attribute('aria-current') == 'step', 'Expected completed question one archive')
            card.locator('.clue-card').filter(has_text=clue['title']).locator('.clue-card-body > strong').tap()
            dialog = page.locator('.clue-dialog')
            body = dialog.locator('.clue-dialog-content')
            title = dialog.locator('#clue-dialog-title')
        else:
            page.get_by_role('button', name='查看本场线索', exact=True).tap()
            dialog = page.locator('.multi-clue-dialog')
            body = dialog.locator('.multi-clue-content')
            title = dialog.locator('#multi-clue-title')
        body.wait_for()
        require(title.is_visible() and title.text_content() == clue['title'] and
                body.get_by_role('link').count() == len(links), 'The authorized clue dialog or link count differs')
        for label, href in links:
            link = body.get_by_role('link', name=label, exact=True)
            require(link.get_attribute('href') == href and link.get_attribute('target') == '_blank' and
                    set(link.get_attribute('rel').split()) == {'noopener', 'noreferrer'}, 'Exact Web external anchor differs')
        for label in inert:
            require(body.get_by_text(label, exact=True).count() == 1 and
                    body.get_by_role('link', name=label, exact=True).count() == 0, 'Rejected markup was not kept inert')
        page.evaluate('''async()=>{await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));}''')
        geometry = body.evaluate('''el=>{
          function measure(node) { const r=node.getBoundingClientRect(),s=getComputedStyle(node);
            return {x:r.x,y:r.y,width:r.width,height:r.height,rectangles:[...node.getClientRects()].map(b=>({x:b.x,y:b.y,width:b.width,height:b.height})),
              fontSize:s.fontSize,lineHeight:s.lineHeight,color:s.color,decoration:s.textDecorationLine}; }
          return {viewport:{width:innerWidth,height:innerHeight,dpr:devicePixelRatio,theme:document.documentElement.dataset.theme},
            dialog:measure(el.closest('[role=dialog]')),body:measure(el),links:[...el.querySelectorAll('a')].map(measure)};
        }''')
        require(geometry['viewport'] == {'width': args.width, 'height': args.height, 'dpr': 1, 'theme': theme},
                'Web viewport or theme differs')
        files = {}
        for key, ext, value in (('screenshot', '.png', page.screenshot(animations='disabled')),
                                ('privateDom', '.html', page.content().encode())):
            dest = output / (mode + '-' + theme + ext)
            files[key] = {'path': str(dest.relative_to(ROOT)), 'sha256': frame.BOUNDARY.private_write(dest, value)}
        require(not popup_requests, 'External target was requested before tapping the link')
        with context.expect_page() as info:
            body.get_by_role('link', name=links[0][0], exact=True).tap()
        popup = info.value
        popup.wait_for_load_state('domcontentloaded')
        require(popup.url == target and popup_requests and all(url == target for url in popup_requests) and
                set(context.pages) == {page, popup} and popup.evaluate('window.opener === null'),
                'Web link did not open an isolated tab')
        popup.close()
        require(page.url == route_url and body.is_visible() and not errors,
                'Original dialog was not retained after closing the external tab')
        if answer is not None:
            require(nav.nth(0).get_attribute('aria-current') == 'step', 'Archive question changed after return')
            dialog.locator('.clue-dialog-close').tap()
            dialog.wait_for(state='detached')
            nav.nth(1).tap()
            require(nav.nth(1).get_attribute('aria-current') == 'step' and answer.input_value() == DRAFT,
                    'Question two draft was not retained')
        report['states'].append({'case': mode, 'theme': theme, 'geometry': geometry, **files,
            'openedExternalTabWithNoOpenerOrReferrer': True, 'dialogRetained': True,
            'draftRetained': True if answer is not None else None, 'nonClickableLabels': len(inert),
            'popupRequestsIntercepted': len(popup_requests)})
    finally:
        private.append({'case': mode, 'theme': theme, 'popupRequestsIntercepted': popup_requests, 'errors': errors})
        context.close()


def capture(args):
    frame = load_frame()
    boundary = frame.BOUNDARY
    args.web_source = args.web_source.resolve()
    boundary.frozen_check(args.web_source)
    renderer = Path(__file__).read_bytes()
    sources = {name: (args.web_source / name).read_bytes() for name in SOURCES}
    entries = [(mode, phase(frame, path, expected, mode)) for mode, path, expected in
               (('ordinary', args.ordinary, args.ordinary_sha), ('combination', args.combination, args.combination_sha))]
    require(entries[0][1][2]['assignment']['session'] == entries[1][1][2]['assignment']['session'],
            'Reference snapshots must use the same published session')
    output = boundary.path_in(args.output_dir, frame.PRIVATE)
    manifest = boundary.path_in(args.manifest, frame.PUBLIC / 'ui-gameplay-links-20261112')
    require(not manifest.exists() and 320 <= args.width <= 620 and 600 <= args.height <= 1000, 'Invalid output or viewport')
    boundary.fresh_directory(output)
    for mode, (_, raw, _, _) in entries:
        boundary.private_write(output / (mode + '-input.json'), raw)
    report = {'status': 'incomplete', 'sourceCommit': frame.FROZEN, 'rendererSha256': digest(renderer),
        'inputSha256': {mode: digest(raw) for mode, (_, raw, _, _) in entries},
        'sourceSha256': {name: digest(raw) for name, raw in sources.items()}, 'inputOrigin': 'exact_isolated_native_actors',
        'syntheticAuthentication': True, 'businessRequestsForwarded': 0, 'externalRequestsForwarded': 0,
        'visualReview': 'pending_original_review', 'states': []}
    private = []
    try:
        sys.path.insert(0, str(frame.PRIVATE / 'python-playwright'))
        from playwright.sync_api import sync_playwright
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True, timeout=30000, args=['--disable-background-networking'])
            try:
                for mode, (_, _, data, clue) in entries:
                    for theme in ('light', 'dark'):
                        render(browser, frame, args, sources, data, clue, mode, theme, output, report, private)
            finally:
                browser.close()
        boundary.frozen_check(args.web_source)
        require(Path(__file__).read_bytes() == renderer and digest(FRAME.read_bytes()) == FRAME_SHA and
                all(path.read_bytes() == raw for _, (path, raw, _, _) in entries) and
                all((args.web_source / name).read_bytes() == raw for name, raw in sources.items()) and len(report['states']) == 4,
                'Capture input changed or evidence is incomplete')
        report['status'] = 'captured_web_clue_links_reference'
    except Exception as error:
        private.append({'failure': str(error)})
    dest = output / 'browser-private.json'
    report['privateBrowserEvidence'] = {'path': str(dest.relative_to(ROOT)), 'sha256': boundary.private_write(dest, private)}
    encoded = (json.dumps(report, indent=2, allow_nan=False) + '\n').encode()
    require(not re.search(rb'https?://', encoded), 'Public manifest contains a URL')
    fd = os.open(manifest, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(encoded)
    print(json.dumps({'status': report['status'], 'states': len(report['states']), 'manifestSha256': digest(encoded)}))
    return int(report['status'] == 'incomplete')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('ordinary', 'combination', 'output-dir', 'manifest'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--ordinary-sha', required=True)
    parser.add_argument('--combination-sha', required=True)
    parser.add_argument('--web-source', type=Path, default=ROOT.parent / 'questions-web')
    parser.add_argument('--width', type=int, required=True)
    parser.add_argument('--height', type=int, required=True)
    return capture(parser.parse_args())


if __name__ == '__main__':
    sys.exit(main())

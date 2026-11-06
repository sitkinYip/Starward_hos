#!/usr/bin/env python3
"""Capture frozen mobile Web question navigation using exact private snapshots.

The only forwarded requests are frozen local Web sources. Authentication and
read responses are replayed, and every business write is blocked.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import sys
from hashlib import sha256
from types import ModuleType
from urllib.parse import quote, urlparse


ROOT = Path(__file__).resolve().parents[1]
FRAME_PATH = ROOT / 'scripts/capture-web-question-frame.py'
FRAME_SHA = '12f9b6563ebb95cc141043e966c009375873de0b8de764df9a0308ecf4ae520f'
FONT_SHA = '050080d9255a86808f2945bffac582b31ef32bc36411ce29563b4961670c66f9'
CONTENT_SHA = '1ad7a59cc1f13e6dd7ec5550c8f5ab4a5906b90f9a9b56ac948143a4995e8745'
THEMES = ('light', 'dark')
BASE_URL = 'http://127.0.0.1:5178'
WIDTH, HEIGHT = 376, 742

MEASURE = r"""() => {
  const nav = document.querySelector('.quest-nav');
  const card = document.querySelector('.quest-card');
  const box = el => {
    const {x,y,width,height} = el.getBoundingClientRect();
    return {x,y,width,height};
  };
  const navStyle = getComputedStyle(nav);
  return {
    width: innerWidth, height: innerHeight, dpr: devicePixelRatio,
    coarse: matchMedia('(pointer:coarse)').matches,
    theme: document.documentElement.dataset.theme,
    navigation: {...box(nav), clientWidth: nav.clientWidth, scrollWidth: nav.scrollWidth,
      scrollLeft:nav.scrollLeft, gap:navStyle.gap, bottomPadding:navStyle.paddingBottom,
      snapType:navStyle.scrollSnapType, scrollbarWidth:navStyle.scrollbarWidth},
    buttons: [...nav.querySelectorAll('button')].map(b => {
      const style = getComputedStyle(b);
      const number = getComputedStyle(b.querySelector('span'));
      const label = getComputedStyle(b.querySelector('small'));
      const centered = b.offsetLeft - (nav.clientWidth - b.offsetWidth) / 2;
      return {...box(b), current:b.getAttribute('aria-current'), disabled:b.disabled,
        align:style.textAlign, gap:style.gap, padding:style.padding, radius:style.borderRadius,
        background:style.backgroundColor, color:style.color, border:style.border, opacity:style.opacity,
        translate:style.transform, numberSize:number.fontSize, numberLineHeight:number.lineHeight,
        labelSize:label.fontSize, snapAlign:style.scrollSnapAlign,
        expectedCenteredScrollLeft:Math.max(0, Math.min(nav.scrollWidth-nav.clientWidth, centered))};
    }),
    card: {...box(card), focused:document.activeElement === card},
    scrollY, documentHeight:document.documentElement.scrollHeight,
    privateLabels: [...nav.querySelectorAll('button')].map(b => ({
      number:b.querySelector('span').textContent, label:b.querySelector('small').textContent})),
    privateQuestionNumber: card.querySelector('.quest-meta span').textContent,
  };
}"""


def sha(data):
    return sha256(data).hexdigest()


def require(condition):
    if not condition:
        raise ValueError('The reviewed navigation reference boundary did not hold')


def load_frame():
    raw = FRAME_PATH.read_bytes()
    require(sha(raw) == FRAME_SHA)
    module = ModuleType('gameplay_navigation_frame')
    module.__file__ = str(FRAME_PATH)
    exec(compile(raw, str(FRAME_PATH), 'exec'), module.__dict__)
    return module


def check_snapshot(dto):
    require(isinstance(dto, dict) and set(dto) == {'player', 'assignments', 'assignment'})
    player, listing, scene = (dto[key] for key in ('player', 'assignments', 'assignment'))
    require(re.fullmatch(r'hm_[a-f0-9]{12}', player['account']) and player['mustChangePassword'] is False and
            re.fullmatch(r'[a-z0-9]{15}', player['id']) and re.fullmatch(r'[a-z0-9]{15}', scene['id']) and
            scene['player'] == player['id'] and scene['status'] in ('active', 'completed') and
            bool(scene['startedAt']) and all(row['player'] == player['id'] for row in listing['items']) and
            sum(row['id'] == scene['id'] and row['status'] == scene['status'] for row in listing['items']) == 1)
    levels, selected = scene['levels'], scene['currentIndex']
    require(2 <= len(levels) == scene['totalLevels'] <= 50 and type(selected) is int and 0 <= selected < len(levels) and
            levels[selected]['question'] is not None and
            sum(bool(level['completedAt']) for level in levels) == scene['completedLevels'] and
            not re.search(r'"(?:token|password|authorization|controltoken|answerkey)"\s*:', json.dumps(dto), re.I))
    wanted = set()
    for level in levels:
        question = level['question']
        if question is None:
            continue
        wanted.update(value for block in question['content']
                      for value in [block.get('imageUrl'), *block.get('imageUrls', [])] if value)
        wanted.update(option['imageUrl'] for option in question['options'] if option.get('imageUrl'))
    return wanted


def render(browser, frame, web, sources, dto, assets, font, theme, ordinal, output, report, raw):
    boundary = frame.BOUNDARY
    player, listing, scene = (dto[key] for key in ('player', 'assignments', 'assignment'))
    detail = '/api/questions/v1/assignments/' + scene['id']
    reads = {'/api/questions/v1/me': player, '/api/questions/v1/assignments': listing, detail: scene,
             '/api/questions/v1/rewards': {'items': []}, '/api/questions/v1/notifications': {'items': []}}
    cors = {'Access-Control-Allow-Origin': BASE_URL,
            'Access-Control-Allow-Headers': 'Authorization,Content-Type,Accept',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'}

    def reply(route, value):
        route.fulfill(status=200, headers=cors, content_type='application/json',
                      body=json.dumps(value, ensure_ascii=False))

    def route_request(route):
        req = route.request
        parsed = urlparse(req.url)
        origin = parsed.scheme + '://' + parsed.netloc
        if req.url in assets and req.method == 'GET' and req.resource_type == 'image':
            require(not req.headers.get('authorization'))
            asset = assets[req.url]
            raw['imagesReplayed'].append({'url': req.url, 'sha256': asset['sha256']})
            mime = 'image/png' if asset['data'].startswith(b'\x89PNG\r\n\x1a\n') else 'image/jpeg'
            route.fulfill(content_type=mime, body=asset['data'])
        elif parsed.path.startswith('/api/'):
            raw['apis'].append({'url': req.url, 'method': req.method})
            allowed = (*reads, frame.AUTH, '/api/files/token')
            if origin != frame.API_ORIGIN or parsed.query or parsed.path not in allowed:
                if origin == frame.API_ORIGIN and req.method == 'GET' and parsed.path.startswith('/api/files/game_players/'):
                    raw['blocked'].append({'url': req.url, 'type': 'unreplayed-avatar'})
                else:
                    raw['unexpectedApis'].append({'url': req.url, 'method': req.method})
                route.abort()
            elif req.method == 'OPTIONS':
                route.fulfill(status=204, headers=cors, body='')
            elif parsed.path == frame.AUTH and req.method == 'POST':
                require(req.post_data_json == {'identity': player['account'], 'password': frame.PASSWORD})
                reply(route, {'token': frame.TOKEN, 'record': {'id': player['id']}})
            else:
                require(req.headers.get('authorization') == frame.TOKEN)
                if req.method == 'GET' and parsed.path in reads:
                    reply(route, reads[parsed.path])
                elif req.method == 'POST' and parsed.path == '/api/files/token':
                    reply(route, {'token': 'question-navigation-render-only-file-token'})
                else:
                    require(False)
        elif req.method == 'GET' and origin == BASE_URL and parsed.path == frame.FONT_ROUTE and not parsed.query:
            raw['fontsReplayed'] += 1
            route.fulfill(content_type='font/ttf', body=font)
        elif boundary.source_request(req.method, req.url, req.resource_type, BASE_URL, scene['id'], web):
            route.continue_()
        else:
            raw['blocked'].append({'url': req.url, 'type': req.resource_type})
            route.abort()

    def guarded(route):
        try:
            route_request(route)
        except Exception as error:
            raw['routeFailures'].append({'type': type(error).__name__, 'message': str(error)})
            route.abort()

    context = browser.new_context(viewport={'width': WIDTH, 'height': HEIGHT}, device_scale_factor=1,
        is_mobile=True, has_touch=True, color_scheme=theme, reduced_motion='reduce', locale='zh-CN',
        timezone_id='Asia/Shanghai', service_workers='block', accept_downloads=False)
    try:
        context.route('**/*', guarded)
        context.route_web_socket('**/*', lambda _socket: None)
        page = context.new_page()
        page.set_default_timeout(15000)
        page.on('pageerror', lambda error: raw['pageErrors'].append(str(error)))
        page.goto(BASE_URL + '/login?theme=' + theme, wait_until='networkidle')
        for name, content in sources.items():
            served = frame.bounded(page, 'return (await import(arg+"?raw")).default;', '/' + name)
            require(isinstance(served, str) and sha(served.encode()) == sha(content))
            raw['servedSourceChecks'] += 1
        checked = frame.bounded(page, """const m=await import('/src/api/game.schema.ts');
          return [m.gamePlayerSchema.safeParse(arg.player).success,m.gameAssignmentSchema.safeParse(arg.assignment).success,
                  m.gameAssignmentSummarySchema.array().safeParse(arg.assignments.items).success];""", dto)
        require(checked == [True, True, True])
        raw['schemaChecks'] += len(checked)
        page.get_by_label('登录账号', exact=True).fill(player['account'])
        page.get_by_label('密码', exact=True).fill(frame.PASSWORD)
        page.get_by_role('button', name='进入冒险', exact=True).click()
        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
        page.goto(BASE_URL + '/play/' + quote(scene['id'], safe='') + '?theme=' + theme, wait_until='networkidle')
        nav = page.get_by_role('navigation', name='题目导航', exact=True)
        card = page.locator('.quest-card')
        nav.wait_for()
        card.wait_for()
        require(page.locator('.quest-layout.quest-desktop').count() == 0 and card.count() == 1)
        for name in ('关闭背景音乐提示', '知道了'):
            prompt = page.get_by_role('button', name=name, exact=True)
            if prompt.count() == 1 and prompt.is_visible():
                prompt.click()
                prompt.wait_for(state='detached')
        page.add_style_tag(content='@font-face{font-family:StarwardNavigationSerif;src:url("' + BASE_URL + frame.FONT_ROUTE +
            '") format("truetype");font-weight:100 900;font-style:normal;font-display:block}' +
            ':root{--font-display:StarwardNavigationSerif,serif!important}')
        require(frame.bounded(page, 'return (await document.fonts.load("24px StarwardNavigationSerif")).length>0;'))
        buttons, levels = nav.get_by_role('button'), scene['levels']
        require(buttons.count() == len(levels))

        def inspect(index):
            observed = page.evaluate(MEASURE)
            require((observed['width'], observed['height'], observed['dpr'], observed['coarse'], observed['theme']) ==
                    (WIDTH, HEIGHT, 1, True, theme))
            require(observed['privateQuestionNumber'] == f'第 {index+1} 题')
            require(len(observed['buttons']) == len(levels))
            for position, (button, label, level) in enumerate(zip(observed['buttons'], observed['privateLabels'], levels)):
                require(button['current'] == ('step' if position == index else None) and
                        button['disabled'] == (level['question'] is None) and
                        label['number'] == f'{position+1:02d}' and
                        label['label'] == ('已完成' if level['completedAt'] else f'第 {position+1} 题'))
            return observed

        def shot(name, index, landing=None):
            nav.evaluate("node=>node.scrollIntoView({block:'nearest',inline:'nearest',behavior:'instant'})")
            frame.bounded(page, """await document.fonts.ready;
              const animations=[...document.querySelectorAll('.quest-nav,.quest-card')]
                .flatMap(node=>node.getAnimations({subtree:true}));
              await Promise.allSettled(animations.filter(a=>Number.isFinite(a.effect?.getComputedTiming().endTime))
                .map(a=>a.finished));""")
            observed = inspect(index)
            png = output / f'case-{ordinal}-{theme}-{name}.png'
            details = output / f'case-{ordinal}-{theme}-{name}.json'
            report['states'].append({'snapshotOrdinal': ordinal, 'theme': theme, 'position': name,
                'navigation': observed['navigation'], 'buttons': observed['buttons'], 'card': observed['card'],
                'landingBeforeRevealingNavigation': landing,
                'screenshot': {'file': str(png.relative_to(ROOT)),
                    'sha256': boundary.private_write(png, page.screenshot(animations='disabled'))},
                'privateMeasurements': {'file': str(details.relative_to(ROOT)),
                    'sha256': boundary.private_write(details, observed)}})

        current = scene['currentIndex']
        shot('initial', current)
        locked = next((position for position, level in enumerate(levels) if level['question'] is None), None)
        if locked is not None:
            target = buttons.nth(locked)
            target.scroll_into_view_if_needed()
            box = target.bounding_box()
            require(box and target.is_disabled())
            nav_box = nav.bounding_box()
            require(nav_box)
            left, right = max(nav_box['x'], box['x'], 0), min(nav_box['x']+nav_box['width'], box['x']+box['width'], WIDTH)
            top, bottom = max(nav_box['y'], box['y'], 0), min(nav_box['y']+nav_box['height'], box['y']+box['height'], HEIGHT)
            require(right > left and bottom > top)
            page.touchscreen.tap((left+right)/2, (top+bottom)/2)
            inspect(current)
            shot('future-touch', current)
        other = min((position for position, level in enumerate(levels) if position != current and level['question']),
                    key=lambda position: abs(position - current), default=None)

        def switch(position):
            buttons.nth(position).tap()
            page.wait_for_function("""index => {
              const card=document.querySelector('.quest-card');
              return card && document.activeElement===card &&
                document.querySelectorAll('.quest-nav button')[index]?.getAttribute('aria-current')==='step';
            }""", arg=position)
            result = inspect(position)
            actual = result['navigation']['scrollLeft']
            expected = result['buttons'][position]['expectedCenteredScrollLeft']
            require(abs(actual - expected) <= 2)
            return {'card': result['card'], 'scrollY': result['scrollY'], 'documentHeight': result['documentHeight'],
                    'railScrollLeft': actual, 'expectedCenteredScrollLeft': expected}

        if other is not None:
            shot('other-readable', other, switch(other))
            shot('current-restored', current, switch(current))
        report['checks'].append({'snapshotOrdinal': ordinal, 'theme': theme,
            'futureTouchKeptCurrent': locked is not None, 'switchAndReturnFocusedCard': other is not None,
            'navCenteredOnSwitch': other is not None})
    finally:
        context.close()


def capture(args):
    frame = load_frame()
    boundary = frame.BOUNDARY
    web = args.web_source.resolve()
    boundary.frozen_check(web)
    require(1 <= len(args.snapshot) == len(args.snapshot_sha) <= 4)
    sources = {name: (web / name).read_bytes() for name in (*frame.SOURCES, 'src/features/quest/useQuestNavigationPosition.ts')}
    inputs, wanted = [], set()
    for file, expected in zip(args.snapshot, args.snapshot_sha):
        path = frame.private_input(file)
        data = path.read_bytes()
        require(re.fullmatch(r'[a-f0-9]{64}', expected) and sha(data) == expected)
        dto = json.loads(data)
        wanted.update(check_snapshot(dto))
        inputs.append((path, data, dto))
    require(bool(args.images_manifest) == bool(args.images_sha))
    assets, image_path, image_bytes = {}, None, None
    if args.images_manifest:
        image_path = frame.private_input(args.images_manifest)
        image_bytes, registered = frame.image_assets(image_path, args.images_fixture_sha)
        require(sha(image_bytes) == args.images_sha and wanted <= set(registered))
        assets = {url: registered[url] for url in wanted}
    require(set(assets) == wanted)
    font_path = boundary.path_in(frame.NATIVE_FONT, ROOT / 'entry/src/main/resources', True)
    font = font_path.read_bytes()
    require(sha(font) == FONT_SHA)
    output, manifest = boundary.path_in(args.output_dir, frame.PRIVATE), boundary.path_in(args.manifest, frame.PUBLIC)
    require(not output.exists() and not manifest.exists())
    boundary.fresh_directory(output)
    script = Path(__file__).read_bytes()
    report = {'status': 'incomplete', 'sourceCommit': frame.FROZEN, 'helperSha256': sha(script),
        'frameHelperSha256': FRAME_SHA, 'boundaryHelperSha256': frame.BOUNDARY_SHA, 'fontSha256': FONT_SHA,
        'snapshotSha256': [sha(data) for _, data, _ in inputs], 'imagesManifestSha256': args.images_sha,
        'sources': {name: sha(data) for name, data in sources.items()},
        'scope': 'Mobile question navigation, no business or Native header acceptance',
        'backendRequestsContinued': 0, 'externalRequestsContinued': 0, 'states': [], 'checks': [],
        'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    raw = {key: [] for key in ('apis', 'blocked', 'imagesReplayed', 'unexpectedApis', 'routeFailures', 'pageErrors')}
    raw.update({'schemaChecks': 0, 'servedSourceChecks': 0, 'fontsReplayed': 0})
    try:
        package = frame.PRIVATE / 'python-playwright'
        if package.is_dir():
            sys.path.insert(0, str(package))
        from playwright.sync_api import sync_playwright
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True, timeout=30000, args=['--disable-background-networking'])
            try:
                for ordinal, (_, _, dto) in enumerate(inputs, start=1):
                    for theme in THEMES:
                        render(browser, frame, web, sources, dto, assets, font, theme, ordinal, output, report, raw)
            finally:
                browser.close()
        boundary.frozen_check(web)
        require(Path(__file__).read_bytes() == script and sha(FRAME_PATH.read_bytes()) == FRAME_SHA and
                all(path.read_bytes() == data for path, data, _ in inputs) and
                all((web / name).read_bytes() == data for name, data in sources.items()) and font_path.read_bytes() == font and
                (image_path is None or image_path.read_bytes() == image_bytes) and
                all(asset['source'].read_bytes() == asset['data'] for asset in assets.values()))
        require(not any(raw[key] for key in ('unexpectedApis', 'routeFailures', 'pageErrors')) and
                len(report['checks']) == len(inputs) * len(THEMES) and raw['schemaChecks'] == len(report['checks']) * 3 and
                raw['servedSourceChecks'] == len(report['checks']) * len(sources))
        report['status'] = 'captured_web_gameplay_navigation_reference'
    except Exception as error:
        raw['failure'] = {'type': type(error).__name__, 'message': str(error)}
        report['failure'] = 'Guarded browser reference incomplete. Private evidence retained.'
    details = output / 'browser-private.json'
    report['privateBrowserEvidence'] = {'file': str(details.relative_to(ROOT)),
        'sha256': boundary.private_write(details, raw)}
    report['counts'] = {key: len(value) if isinstance(value, list) else value for key, value in raw.items() if key != 'failure'}
    encoded = (json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
    private_literals = set(assets)
    for _, _, dto in inputs:
        private_literals.update(frame.private_literals(dto))
    require(not re.search(rb'https?://', encoded) and not any(
        item.encode() in encoded if len(item) >= 5 else json.dumps(item, ensure_ascii=False).encode() in encoded
        for item in private_literals))
    manifest.parent.mkdir(parents=True, exist_ok=True)
    with os.fdopen(os.open(manifest, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644), 'wb') as stream:
        stream.write(encoded)
    print(json.dumps({'status': report['status'], 'states': len(report['states']), 'manifestSha256': sha(encoded)}), flush=True)
    return int(report['status'] == 'incomplete')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest='action')
    run = actions.add_parser('run')
    run.add_argument('--web-source', type=Path, default=ROOT.parent / 'questions-web')
    run.add_argument('--snapshot', type=Path, action='append', required=True)
    run.add_argument('--snapshot-sha', action='append', required=True)
    run.add_argument('--images-manifest', type=Path)
    run.add_argument('--images-sha')
    run.add_argument('--images-fixture-sha', default=CONTENT_SHA)
    run.add_argument('--output-dir', type=Path, required=True)
    run.add_argument('--manifest', type=Path, required=True)
    args = parser.parse_args()
    if args.action is None:
        parser.print_help()
        return 0
    try:
        return capture(args)
    except Exception:
        print(json.dumps({'status': 'not_captured_or_report_guarded',
            'error': 'Explicit frozen source, snapshot, image, font or output prerequisite failed. Values omitted.'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

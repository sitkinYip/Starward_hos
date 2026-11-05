#!/usr/bin/env python3
"""Capture four narrow frozen-Web render references in isolated headless Chromium.

Default help is inert. Root starts the frozen local Vite server separately. Real
preview DTOs are replay inputs; authentication/auxiliary replies are synthetic
render drivers. No real backend, profile/password/crop or gameplay write is used.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
from urllib.parse import quote, unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'artifacts/private'
PUBLIC = ROOT / 'artifacts/validation'
NATIVE_FONT = ROOT / 'entry/src/main/resources/rawfile/fonts/NotoSerifSC.ttf'
FROZEN = '4b7d1a0a00051ac630e459b0fd6c074f821d7455'
AUTH = '/api/collections/game_players/auth-with-password'
API_ORIGIN = 'http://127.0.0.1:18790'
FONT_ROUTE = '/__ui_sample__/native-serif.ttf'
DRIVER_TOKEN = 'ui-sample-synthetic-render-token'
DRIVER_PASSWORD = 'UiSampleRenderingOnly123'
SOURCES = ('src/app/App.tsx', 'src/api/game.schema.ts', 'src/config/ui-copy.ts',
    'src/features/game/GameSidebar.tsx', 'src/features/game/components/GameSidebarIdentity.tsx',
    'src/features/game/components/GameHeaderView.tsx', 'src/features/game/components/AssignmentBrief.tsx',
    'src/components/ui/Sheet.tsx', 'src/styles/features/game-sidebar.css',
    'src/styles/features/quest.css', 'src/styles/effects/quest-lighting.css')
SELECTORS = {
    'sidebar-home': {'sidebar': '.game-sidebar', 'header': '.game-sidebar .ui-sheet__header',
        'stamp': '.game-sidebar-identity__stamp', 'close': '.game-sidebar .ui-sheet__close',
        'identity': '.game-sidebar-identity', 'identityPlayer': '.game-sidebar-identity__player',
        'identityName': '.game-sidebar-identity__player h3', 'identityRank': '.game-sidebar-identity__player p',
        'navigation': '.game-sidebar__nav', 'footer': '.game-sidebar__footer',
        'settings': '.game-sidebar__settings', 'logout': '.game-sidebar__logout'},
    'session-header': {'header': '.session-header', 'identity': '.traveler-identity',
        'eyebrow': '.traveler-identity .eyebrow', 'name': '.traveler-name', 'rank': '.traveler-rank',
        'progress': '.session-progress', 'menuTrigger': '.session-header .game-menu-trigger',
        'brief': '.assignment-brief'},
}


class CaptureFailure(Exception):
    pass


def require(value):
    if not value:
        raise CaptureFailure('The explicit local rendering/reference boundary did not hold')


def sha(value):
    return hashlib.sha256(value).hexdigest()


def local_origin(value):
    parsed = urlparse(value)
    require(parsed.scheme == 'http' and parsed.hostname == '127.0.0.1' and parsed.port is not None and
            1024 <= parsed.port <= 65535 and not parsed.username and not parsed.password and
            not parsed.path and not parsed.query and not parsed.fragment and
            value == 'http://127.0.0.1:' + str(parsed.port))
    return value


def path_in(value, base, existing=False, private=False):
    path = (ROOT / value).absolute() if not value.is_absolute() else value.absolute()
    require(path == path.resolve() and path.is_relative_to(base) and path != base)
    for item in (path, *path.parents):
        require(not item.is_symlink())
        if item == ROOT:
            break
    if existing:
        info = path.stat()
        require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid())
        if private:
            require(stat.S_IMODE(info.st_mode) == 0o600)
    return path


def fresh_directory(path):
    for item in reversed((path, *path.parents)):
        if item == ROOT or ROOT not in item.parents:
            continue
        if item.exists():
            require(item != path and item.is_dir() and item.stat().st_uid == os.getuid() and not item.is_symlink())
            if item == PRIVATE or item.is_relative_to(PRIVATE):
                require(stat.S_IMODE(item.stat().st_mode) == 0o700)
        else:
            item.mkdir(mode=0o700)
            item.chmod(0o700)


def private_write(path, value):
    encoded = value if isinstance(value, bytes) else (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'wb') as stream:
        os.fchmod(stream.fileno(), 0o600)
        stream.write(encoded)
    return sha(encoded)


def frozen_check(web):
    def git(*args):
        return subprocess.check_output(['git', *args], cwd=web, text=True, stderr=subprocess.DEVNULL).strip()
    require(git('rev-parse', 'HEAD') == FROZEN and not git('status', '--porcelain'))


def fixtures(value):
    require(isinstance(value, dict) and isinstance(value.get('player'), dict) and
            isinstance(value.get('assignment'), dict) and isinstance(value.get('assignments'), dict) and
            isinstance(value['assignments'].get('items'), list))
    player, scene = value['player'], value['assignment']
    require(player.get('account') == 'starward_preview' and player.get('mustChangePassword') is False and
            re.fullmatch(r'[a-z0-9]{15}', player.get('id', '')) and
            re.fullmatch(r'[a-z0-9]{15}', scene.get('id', '')) and scene.get('player') == player['id'] and
            scene.get('status') == 'assigned' and not scene.get('startedAt') and
            isinstance(scene.get('levels'), list) and scene['levels'] and
            all(row.get('question') is None for row in scene['levels']) and
            any(row.get('id') == scene['id'] for row in value['assignments']['items']) and
            all(row.get('player') == player['id'] for row in value['assignments']['items']))
    def no_auth_fields(item):
        if isinstance(item, dict):
            require(not any(str(key).lower() in ('token', 'password', 'authorization', 'controltoken') for key in item))
            for child in item.values():
                no_auth_fields(child)
        elif isinstance(item, list):
            for child in item:
                no_auth_fields(child)
    no_auth_fields(value)
    return player, scene, value['assignments']


def source_request(method, url, resource, base, assignment_id, web):
    parsed = urlparse(url)
    if method != 'GET' or parsed.scheme + '://' + parsed.netloc != base:
        return False
    if resource == 'document':
        return parsed.path in ('/', '/login', '/play/' + assignment_id) and \
            parsed.query in ('', 'theme=light', 'theme=dark')
    if resource in ('script', 'stylesheet'):
        if parsed.path.startswith('/@fs/'):
            # start-web-baseline.mjs intentionally puts optimized modules here,
            # outside the Web checkout. No arbitrary local-file route is opened.
            target = Path('/' + unquote(parsed.path[len('/@fs/'):])).resolve()
            roots = (web / 'node_modules', PRIVATE / 'web-baseline-vite-cache')
            return target.suffix in ('.js', '.mjs', '.css') and any(target.is_relative_to(root) for root in roots)
        return parsed.path.startswith(('/src/', '/node_modules/', '/@vite/', '/@react-refresh', '/@id/'))
    return False


MEASURE = r"""selectors => {
  const privateResult={}, publicResult={};
  for(const [key,selector] of Object.entries(selectors)) {
    const el=document.querySelector(selector); if(!el) {publicResult[key]={present:false};continue;}
    const b=el.getBoundingClientRect(),s=getComputedStyle(el);
    const geo={present:true,x:b.x,y:b.y,width:b.width,height:b.height,
      visible:s.display!=='none'&&s.visibility!=='hidden'&&b.width>0&&b.height>0,
      fullyInsideViewport:b.x>=0&&b.y>=0&&b.right<=innerWidth&&b.bottom<=innerHeight,
      clientHeight:el.clientHeight,scrollHeight:el.scrollHeight,
      paddingTop:parseFloat(s.paddingTop)||0,paddingBottom:parseFloat(s.paddingBottom)||0,
      borderBottomWidth:parseFloat(s.borderBottomWidth)||0};
    publicResult[key]=geo;
    privateResult[key]={...geo,selector,text:el.textContent?.trim(),fontFamily:s.fontFamily,
      fontSize:s.fontSize,lineHeight:s.lineHeight,background:s.background,border:s.border};
  }
  if(publicResult.rank?.present&&publicResult.header?.present) {
    publicResult.rankToHeaderBottom={distance:publicResult.header.y+publicResult.header.height-publicResult.rank.y-publicResult.rank.height};
  }
  if(publicResult.brief?.present&&publicResult.header?.present) {
    publicResult.headerToBrief={distance:publicResult.brief.y-publicResult.header.y-publicResult.header.height};
  }
  const header=document.querySelector(selectors.header);
  if(header) for(const pseudo of ['::before','::after']) {
    const s=getComputedStyle(header,pseudo);
    publicResult[pseudo]={present:s.content!=='none'&&s.content!=='normal',
      width:parseFloat(s.width)||0,height:parseFloat(s.height)||0,
      bottom:parseFloat(s.bottom)||0,borderBottomWidth:parseFloat(s.borderBottomWidth)||0};
  }
  const documentGeometry={width:innerWidth,height:innerHeight,dpr:devicePixelRatio,
    clientWidth:document.documentElement.clientWidth,scrollWidth:document.documentElement.scrollWidth,
    scrollY,mainScrollTop:document.querySelector('.game-shell')?.scrollTop||0};
  return {private:privateResult,geometry:publicResult,document:documentGeometry};
}"""


def capture(args):
    base = local_origin(args.url)
    require(args.width == 376 and args.height == 742)
    web = args.web_source.absolute().resolve()
    frozen_check(web)
    source_bytes = {name: (web / name).read_bytes() for name in SOURCES}
    snapshot = path_in(args.fixtures_json, PRIVATE, True, True)
    snapshot_bytes = snapshot.read_bytes()
    value = json.loads(snapshot_bytes)
    player, scene, listing = fixtures(value)
    font = path_in(args.font_file, ROOT / 'entry/src/main/resources', True)
    require(font == NATIVE_FONT and not font.is_symlink())
    font_bytes = font.read_bytes()
    require(0 < len(font_bytes) < 50 * 1024 * 1024)
    output = path_in(args.output_dir, PRIVATE)
    manifest_path = path_in(args.manifest, PUBLIC)
    require(not manifest_path.exists() and not manifest_path.is_symlink())
    fresh_directory(output)
    private_write(output / 'input-fixtures.json', snapshot_bytes)
    report = {'status': 'incomplete', 'scope': 'Four local replay render references only; no real authentication, business or native acceptance',
        'sourceCommit': FROZEN, 'viewport': {'width': args.width, 'height': args.height, 'deviceScaleFactor': 1,
            'nativeSafeAreaApplied': False}, 'fontSha256': sha(font_bytes), 'fixtureSha256': sha(snapshot_bytes),
        'nativeFontSourceSameBytes': True, 'installedNativeFontIndependentlyVerified': False,
        'browserBackendRequestsContinued': 0, 'externalPageRequestsContinued': 0,
        'syntheticAuthentication': True, 'auxiliaryRepliesAreSynthetic': True, 'assetsReplayedExceptFont': False,
        'sources': [{'path': name, 'sha256': sha(data)} for name, data in source_bytes.items()],
        'states': [], 'counts': {}}
    raw = {'apis': [], 'blocked': [], 'consoleErrors': [], 'pageErrors': [], 'webSocketsBlocked': 0}
    schema_checks, source_checks = [], []
    unexpected = []
    package = PRIVATE / 'python-playwright'
    if package.is_dir():
        sys.path.insert(0, str(package))
    from playwright.sync_api import sync_playwright
    failure = None
    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True, args=['--disable-background-networking'])
            try:
                for theme in ('light', 'dark'):
                    context = browser.new_context(viewport={'width': args.width, 'height': args.height},
                        device_scale_factor=1, color_scheme=theme, reduced_motion='reduce', locale='zh-CN',
                        timezone_id='Asia/Shanghai', service_workers='block')
                    def intercept(route):
                        request = route.request
                        parsed = urlparse(request.url)
                        target_origin = parsed.scheme + '://' + parsed.netloc
                        if parsed.path.startswith('/api/'):
                            raw['apis'].append({'theme': theme, 'method': request.method, 'path': parsed.path})
                            cors = {'Access-Control-Allow-Origin': base,
                                    'Access-Control-Allow-Headers': 'Authorization,Content-Type,Accept',
                                    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'}
                            read_routes = ('/api/questions/v1/me', '/api/questions/v1/assignments',
                                '/api/questions/v1/assignments/' + scene['id'],
                                '/api/questions/v1/notifications', '/api/questions/v1/rewards')
                            if request.method == 'OPTIONS' and target_origin == API_ORIGIN and parsed.path in (*read_routes, AUTH, '/api/files/token'):
                                route.fulfill(status=204, headers=cors, body='')
                                return
                            response = None
                            if target_origin == API_ORIGIN:
                                if request.method == 'POST' and parsed.path == AUTH:
                                    body = request.post_data_json
                                    require(body == {'identity': player['account'], 'password': DRIVER_PASSWORD})
                                    response = {'token': DRIVER_TOKEN, 'record': {'id': player['id']}}
                                elif request.headers.get('authorization') != DRIVER_TOKEN:
                                    response = None
                                elif request.method == 'GET' and parsed.path == '/api/questions/v1/me':
                                    response = player
                                elif request.method == 'GET' and parsed.path == '/api/questions/v1/assignments':
                                    response = listing
                                elif request.method == 'GET' and parsed.path == '/api/questions/v1/assignments/' + scene['id']:
                                    response = scene
                                elif request.method == 'GET' and parsed.path in ('/api/questions/v1/notifications', '/api/questions/v1/rewards'):
                                    response = {'items': []}
                                elif request.method == 'POST' and parsed.path == '/api/files/token':
                                    response = {'token': 'ui-sample-synthetic-file-token'}
                            if response is None:
                                if request.method == 'GET' and parsed.path.startswith('/api/files/game_players/'):
                                    raw['blocked'].append({'kind': 'unreplayed-avatar', 'url': request.url})
                                else:
                                    unexpected.append({'method': request.method, 'url': request.url})
                                route.fulfill(status=404, headers=cors, content_type='application/json', body='{"error":{"code":"REPLAY_NOT_CONFIGURED"}}')
                            else:
                                route.fulfill(status=200, headers=cors, content_type='application/json', body=json.dumps(response, ensure_ascii=False))
                        elif target_origin == base and parsed.path == FONT_ROUTE and request.method == 'GET':
                            route.fulfill(status=200, content_type='font/ttf', body=font_bytes)
                        elif source_request(request.method, request.url, request.resource_type, base, scene['id'], web):
                            route.continue_()
                        else:
                            raw['blocked'].append({'kind': request.resource_type, 'url': request.url})
                            route.abort()
                    context.route('**/*', intercept)
                    require(hasattr(context, 'route_web_socket'))
                    def block_socket(socket):
                        raw['webSocketsBlocked'] += 1
                        # Routed sockets never contact a server unless
                        # connect_to_server() is explicitly called. Closing
                        # inside this sync handler stalls this installed
                        # Playwright driver during Vite's opening handshake.
                        # Leave an inert local mock; no message is forwarded.
                        return
                    context.route_web_socket('**/*', block_socket)
                    page = context.new_page()
                    page.on('pageerror', lambda error: raw['pageErrors'].append(str(error)))
                    page.on('console', lambda message: raw['consoleErrors'].append(message.text) if message.type == 'error' else None)
                    try:
                        page.goto(base + '/login?theme=' + theme, wait_until='networkidle')
                        for name, data in source_bytes.items():
                            served = page.evaluate('(p)=>import(p+"?raw").then(m=>m.default)', '/' + name)
                            matches = isinstance(served, str) and sha(served.encode()) == sha(data)
                            source_checks.append(matches)
                            require(matches)
                        schema = page.evaluate('''async fixture=>{
                          const m=await import('/src/api/game.schema.ts');
                          return [m.gamePlayerSchema.safeParse(fixture.player).success,
                            m.gameAssignmentSchema.safeParse(fixture.assignment).success,
                            m.gameAssignmentSummarySchema.array().safeParse(fixture.assignments.items).success];
                        }''', value)
                        schema_checks.extend(schema)
                        require(schema == [True, True, True])
                        page.get_by_label('登录账号', exact=True).fill(player['account'])
                        page.get_by_label('密码', exact=True).fill(DRIVER_PASSWORD)
                        page.get_by_role('button', name='进入冒险', exact=True).click()
                        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
                        require(page.locator('.game-world').get_attribute('data-desktop') is None)

                        def install_font():
                            page.add_style_tag(content='@font-face{font-family:StarwardUiSampleSerif;src:url("' + base + FONT_ROUTE +
                                '") format("truetype");font-weight:100 900;font-style:normal;font-display:block}' +
                                ':root{--font-display:StarwardUiSampleSerif,serif!important}')
                            require(page.evaluate('document.fonts.load("24px StarwardUiSampleSerif").then(v=>v.length>0)'))
                            page.evaluate('document.fonts.ready')

                        def record(state):
                            page.wait_for_load_state('networkidle')
                            page.evaluate('document.fonts.ready')
                            require(page.evaluate('document.documentElement.dataset.theme') == theme)
                            measurements = page.evaluate(MEASURE, SELECTORS[state])
                            require(measurements['document']['width'] == args.width and
                                    measurements['document']['height'] == args.height)
                            for key in ('header', 'identity'):
                                require(measurements['geometry'][key].get('visible'))
                            name = state + '-' + theme
                            png_path, json_path, dom_path = [output / (name + suffix) for suffix in ('.png', '.json', '.html')]
                            png_sha = private_write(png_path, page.screenshot(full_page=False, animations='disabled'))
                            private_sha = private_write(json_path, measurements)
                            dom_sha = private_write(dom_path, page.content().encode())
                            report['states'].append({'state': state, 'theme': theme,
                                'screenshot': {'file': str(png_path.relative_to(ROOT)), 'sha256': png_sha},
                                'privateMeasurements': {'file': str(json_path.relative_to(ROOT)), 'sha256': private_sha},
                                'privateDom': {'file': str(dom_path.relative_to(ROOT)), 'sha256': dom_sha},
                                'geometry': measurements['geometry'], 'viewport': measurements['document']})
                        install_font()
                        page.locator('.game-menu-trigger').click()
                        for selector in ('.game-sidebar', '.game-sidebar .ui-sheet__close', '.game-sidebar-identity', '.game-sidebar__logout'):
                            page.locator(selector).wait_for(state='visible')
                        record('sidebar-home')
                        page.locator('.game-sidebar .ui-sheet__close').click()
                        page.locator('.game-sidebar').wait_for(state='detached')
                        page.goto(base + '/play/' + quote(scene['id'], safe='') + '?theme=' + theme, wait_until='networkidle')
                        page.locator('.session-header').wait_for(state='visible')
                        page.locator('.assignment-brief').wait_for(state='visible')
                        install_font()
                        record('session-header')
                    finally:
                        context.close()
            finally:
                browser.close()
        frozen_check(web)
        require(snapshot.read_bytes() == snapshot_bytes and font.read_bytes() == font_bytes and not raw['pageErrors'] and
                not unexpected and len(report['states']) == 4)
        report['status'] = 'captured_render_reference'
    except Exception as error:
        raw['failure'] = {'type': type(error).__name__, 'message': str(error)}
        failure = 'The four guarded local render references did not complete; detailed values remain private'
    finally:
        raw['unexpectedApis'] = unexpected
        raw_path = output / 'browser-private.json'
        raw_sha = private_write(raw_path, raw)
        report['privateBrowserEvidence'] = {'file': str(raw_path.relative_to(ROOT)), 'sha256': raw_sha}
        report['counts'] = {'states': len(report['states']), 'schemaChecksExecuted': len(schema_checks),
            'schemaChecksPassed': sum(item is True for item in schema_checks),
            'servedSourceChecksExecuted': len(source_checks), 'servedSourceChecksPassed': sum(source_checks),
            'apiRequestsReplayedOrBlocked': len(raw['apis']), 'unexpectedApis': len(unexpected),
            'assetsAndExternalRequestsBlocked': len(raw['blocked']), 'webSocketsBlocked': raw['webSocketsBlocked'],
            'consoleErrorsPrivate': len(raw['consoleErrors']), 'pageErrors': len(raw['pageErrors'])}
        if failure:
            report['failure'] = failure
        public_encoded = (json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
        ids = set()
        def record_ids(item):
            if isinstance(item, dict):
                if isinstance(item.get('id'), str):
                    ids.add(item['id'])
                for child in item.values():
                    record_ids(child)
            elif isinstance(item, list):
                for child in item:
                    record_ids(child)
        record_ids(value)
        literals = (player['account'], player.get('displayName', ''), DRIVER_TOKEN, *ids)
        require(not any(value and (value.encode() in public_encoded if len(value) >= 5 else
                    ('"' + value + '"').encode() in public_encoded) for value in literals))
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        descriptor = os.open(manifest_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(descriptor, 'wb') as stream:
            stream.write(public_encoded)
    print(json.dumps({'status': report['status'], 'counts': report['counts'],
        'manifestSha256': sha(public_encoded), 'manifest': str(manifest_path.relative_to(ROOT))}), flush=True)
    return 0 if failure is None else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-only four guarded local headless render-reference states')
    run.add_argument('--url', default='http://127.0.0.1:5178')
    run.add_argument('--web-source', type=Path, default=Path(os.environ.get('STARWARD_WEB_SOURCE', ROOT.parent / 'questions-web')))
    run.add_argument('--fixtures-json', type=Path, required=True)
    run.add_argument('--width', type=int, default=376)
    run.add_argument('--height', type=int, default=742)
    run.add_argument('--font-file', type=Path, required=True)
    run.add_argument('--output-dir', type=Path, required=True)
    run.add_argument('--manifest', type=Path, default=PUBLIC / 'ui-sample-20261104/web-ui-sample.json')
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return capture(args)
    except Exception:
        print(json.dumps({'status': 'not_captured_or_report_guarded',
            'error': 'A local source, private fixture, font, output or headless-render guard failed; values omitted'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

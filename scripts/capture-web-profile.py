#!/usr/bin/env python3
"""Capture six private mobile Web references, optionally adding two avatar-crop states.

This reads the frozen sibling checkout without modifying it. Run its existing
start-web-baseline.mjs separately. All browser API requests are fulfilled here;
login/password/file tokens are synthetic rendering drivers, never live sessions.
--crop-source selects a public project QA PNG through the real profile file input;
the crop dialog is captured and cancelled, with no crop confirmation/profile write.
"""
import argparse
import copy
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import quote, urlparse

ROOT = Path(__file__).resolve().parents[1]
FROZEN = '4b7d1a0a00051ac630e459b0fd6c074f821d7455'
WEB = Path(os.environ.get('STARWARD_WEB_SOURCE', ROOT.parent / 'questions-web')).resolve()
PACKAGES = ROOT / 'artifacts/private/python-playwright'
if PACKAGES.exists():
    sys.path.insert(0, str(PACKAGES))
PRIVATE_ROOT = ROOT / 'artifacts/private'
PUBLIC = ROOT / 'artifacts/validation/profile/web-profile-visual.json'
DEFAULT_OUTPUT = PRIVATE_ROOT / 'web-profile-visual'
AUTH = '/api/collections/game_players/auth-with-password'
PASSWORD = '/api/questions/v1/me/change-password'
TOKEN = '/api/files/token'
PROFILE = '/api/questions/v1/me/profile'
SOURCES = ['src/api/game.schema.ts', 'src/config/ui-copy.ts',
           'src/features/game/pages/GameProfilePage.tsx', 'src/features/game/GameSidebar.tsx']
CROP_SOURCES = ['src/features/game/components/ProfileEditor.tsx',
                'src/features/game/components/AvatarCropDialog.tsx',
                'src/features/game/components/avatar-crop.css',
                'src/components/ui/Dialog.tsx', 'src/features/game/avatar-image.ts',
                'src/styles/components/controls-and-overlays.css', 'src/styles/foundation/tokens.css']
CROP_SELECTORS = {
    'cropOverlay': '.avatar-crop-overlay', 'cropDialog': '.avatar-crop-dialog',
    'cropTitle': '.avatar-crop-dialog > h2:not(.sr-only)', 'cropStage': '.avatar-crop-stage',
    'cropImage': '.avatar-crop-stage img', 'cropZoom': '.avatar-crop-zoom input[type="range"]',
    'cropActions': '.avatar-crop-actions', 'cropCancel': '.avatar-crop-actions .ui-button--secondary',
    'cropConfirm': '.avatar-crop-actions .ui-button--primary',
}
SELECTORS = {
    'topbar': '.game-topbar', 'brand': '.game-brand', 'main': '.game-shell',
    'heading': '.game-page-heading', 'title': '.game-page-heading h1',
    'passport': '.game-profile-grid > .player-passport', 'passportIdentity': '.player-passport__identity',
    'xp': '.game-profile-grid .game-xp', 'tabs': '.game-profile-tabs [role="tablist"]',
    'identity': '.game-profile-tabs [role="tab"][data-state="active"]',
    'editor': '.profile-editor', 'avatar': '.profile-editor__avatar',
    'name': '.profile-editor input:not([type="file"])', 'account': '.profile-editor__account',
    'profileSave': '.profile-editor .game-cta', 'security': '.game-password-section',
    'securityTitle': '.game-password-section h2', 'securitySave': '.game-password-section .game-cta',
    'menuTrigger': '.game-menu-trigger', 'menu': '.game-sidebar',
    'menuIdentity': '.game-sidebar-identity', 'menuNavigation': '.game-sidebar__nav',
    'menuSettings': '.game-sidebar__settings', 'menuLogout': '.game-sidebar__logout',
    'bottomNavigation': '.game-navigation',
}


def sha_bytes(value):
    return hashlib.sha256(value).hexdigest()


def private_write(path, value, binary=False):
    if path.is_symlink():
        raise RuntimeError('Private output symlinks are not allowed')
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb' if binary else 'w') as out:
        out.write(value)
    path.chmod(0o600)


def frozen_check():
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=WEB, text=True).strip()
    dirty = subprocess.check_output(['git', 'status', '--porcelain'], cwd=WEB, text=True).strip()
    if head != FROZEN or dirty:
        raise RuntimeError('A clean frozen Web checkout is required')


def private_path(value, description):
    path = value.resolve()
    if value.is_symlink() or not path.is_relative_to(PRIVATE_ROOT.resolve()):
        raise RuntimeError(description + ' must remain inside this project private artifacts')
    return path


def crop_source(value):
    """Only an explicitly supplied public QA PNG can become the crop source."""
    source = value.absolute()
    resolved = source.resolve()
    public_root = ROOT / 'artifacts/validation'
    if not resolved.is_relative_to(public_root.resolve()) or resolved.suffix.lower() != '.png':
        raise RuntimeError('Crop source must be a public QA PNG inside this project artifacts/validation')
    for item in (source, *source.parents):
        if item.is_symlink():
            raise RuntimeError('Crop source paths cannot contain symlinks')
        if item == ROOT:
            break
    if not resolved.is_file() or not 8 <= resolved.stat().st_size <= 50 * 1024 * 1024:
        raise RuntimeError('Crop source must be a bounded regular PNG file')
    data = resolved.read_bytes()
    if len(data) > 50 * 1024 * 1024 or not data.startswith(b'\x89PNG\r\n\x1a\n'):
        raise RuntimeError('Crop source does not have a PNG signature')
    return resolved, data


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', default='http://127.0.0.1:5178')
    parser.add_argument('--width', type=int, default=391)
    parser.add_argument('--height', type=int, default=844)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument('--fixtures-json', type=Path, required=True)
    parser.add_argument('--avatar-file', type=Path)
    parser.add_argument('--font-file', type=Path)
    parser.add_argument('--crop-source', type=Path,
                        help='Public QA PNG in this project artifacts/validation; capture and cancel the real crop dialog in each theme')
    return parser.parse_args()


def main():
    args = parse_args()
    parsed_origin = urlparse(args.url)
    if (parsed_origin.scheme != 'http' or parsed_origin.hostname != '127.0.0.1' or
            not parsed_origin.port or parsed_origin.username or parsed_origin.password or
            parsed_origin.path not in ('', '/') or parsed_origin.query or parsed_origin.fragment):
        raise RuntimeError('Only the separately started local frozen-Web origin is supported')
    origin = args.url.rstrip('/')
    if args.width < 320 or args.width > 600 or args.height < 500:
        raise RuntimeError('This profile reference is restricted to a mobile viewport')
    frozen_check()
    snapshot_path = private_path(args.fixtures_json, 'Player snapshot')
    output_base = private_path(args.output, 'Capture output')
    capture_stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output = output_base / ('capture-' + capture_stamp)
    snapshot_raw = snapshot_path.read_bytes()
    snapshot = json.loads(snapshot_raw)
    if (not isinstance(snapshot, dict) or not isinstance(snapshot.get('player'), dict) or
            not isinstance(snapshot.get('assignment'), dict) or
            not isinstance(snapshot.get('assignments'), dict) or
            not isinstance(snapshot['assignments'].get('items'), list)):
        raise RuntimeError('Fixture requires actual player, assignment and assignments:{items:[]} snapshot objects')
    player, assignment, assignments = snapshot['player'], snapshot['assignment'], snapshot['assignments']
    if not isinstance(player.get('account'), str) or not player['account']:
        raise RuntimeError('The read-only player account is missing')
    if not isinstance(assignment.get('id'), str) or not assignment['id']:
        raise RuntimeError('The read-only assignment identity is missing')
    avatar_bytes, avatar_mime = None, None
    if player.get('avatar'):
        if not args.avatar_file:
            raise RuntimeError('A nonempty snapshot avatar requires --avatar-file with private readback bytes')
        avatar_path = private_path(args.avatar_file, 'Protected-avatar readback')
        avatar_bytes = avatar_path.read_bytes()
        if avatar_bytes[:3] == b'\xff\xd8\xff':
            avatar_mime = 'image/jpeg'
        elif avatar_bytes[:8] == b'\x89PNG\r\n\x1a\n':
            avatar_mime = 'image/png'
        elif avatar_bytes[:4] == b'RIFF' and avatar_bytes[8:12] == b'WEBP':
            avatar_mime = 'image/webp'
        if not avatar_mime or len(avatar_bytes) > 2*1024*1024:
            raise RuntimeError('The private avatar fixture is not a supported bounded image')
    crop_path, crop_bytes = crop_source(args.crop_source) if args.crop_source else (None, None)
    crop_sha = sha_bytes(crop_bytes) if crop_bytes is not None else None
    capture_states = ('profile-identity', 'profile-security', 'profile-menu') + (('profile-avatar-crop',) if crop_path else ())
    font_path = args.font_file.resolve() if args.font_file else None
    font_bytes = font_path.read_bytes() if font_path else None
    output.mkdir(parents=True, exist_ok=False, mode=0o700)
    output.chmod(0o700)
    snapshot_sha = sha_bytes(snapshot_raw)
    archive = PRIVATE_ROOT / 'web-profile-inputs' / (snapshot_sha + '.json')
    if archive.exists() and archive.read_bytes() != snapshot_raw:
        raise RuntimeError('SHA-addressed snapshot archive changed')
    if not archive.exists():
        private_write(archive, snapshot_raw, True)
    PUBLIC.parent.mkdir(parents=True, exist_ok=True)
    if PUBLIC.exists():
        attempts = PUBLIC.parent / 'attempts'
        attempts.mkdir(exist_ok=True)
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        shutil.copyfile(PUBLIC, attempts / ('web-profile-' + stamp + '.json'))
    # Each run owns a unique private directory. Earlier Task1 and first-slice
    # screenshots retain their bytes and remain bound to their original SHA.
    for state in capture_states:
        for theme in ('dark', 'light'):
            for ext in ('.png', '.json', '.html'):
                target = output / (state + '-' + theme + ext)
                if target.is_symlink():
                    raise RuntimeError('Refusing a symlink in private capture output')
                target.unlink(missing_ok=True)
    metadata = {
        'status': 'running', 'scope': 'Task1 mobile Web layout/copy reference only',
        'sourceCommit': FROZEN, 'sourceCheckoutCleanBefore': True,
        'viewport': {'width': args.width, 'height': args.height, 'deviceScaleFactor': 1,
                     'nativeWidthReferenceVp': 391.111111, 'rounding': 'Browser width rounds the measured native width to391 CSSpx',
                     'nativeSafeAreaApplied': False, 'note': 'Native status/gesture avoid areas remain separate runtime evidence; browser does not emulate them'},
        'snapshot': {'sha256': snapshot_sha, 'archiveFile': str(archive.relative_to(ROOT)),
                     'assignmentCount': len(assignments['items'])},
        'browserUsesRealBackend': False, 'apiInterception': 'All /api/* fulfilled in Playwright, including unknown routes; no API request continued',
        'renderDrivers': 'Login, optional mandatory-password reply and file tokens are synthetic rendering drivers; no browser backend write',
        'auxiliaryAPIs': 'Notification/reward replies, if requested, are fixed empty fixtures outside Task1',
        'fontControl': {'enabled': bool(font_path), 'sha256': sha_bytes(font_bytes) if font_bytes else None,
                        'method': 'Same optional controlled serif override as first-slice capture; Web source unchanged'},
        'avatarReplay': {'provided': avatar_bytes is not None,
                         'sha256': sha_bytes(avatar_bytes) if avatar_bytes is not None else None,
                         'source': 'Caller-provided private readback bytes; browser serves only the replay fixture'},
        'servedFrozenSourceChecks': [], 'schemaChecks': [], 'states': [],
        'consoleErrorCount': 0, 'pageErrorCount': 0, 'unexpectedApiCount': 0,
        'externalRequestsAllowed': 0, 'blockedExternalRequestCount': 0,
    }
    raw = {'apiRequests': [], 'consoleErrors': [], 'pageErrors': [], 'blockedExternalRequests': [],
           'unexpectedApis': [], 'stateMeasurements': [], 'uiCopy': None}
    if crop_path:
        private_write(output / 'crop-source.png', crop_bytes, True)
        metadata['cropReference'] = {'source': str(crop_path.relative_to(ROOT)), 'sourceSha256': crop_sha,
            'sourceBytes': len(crop_bytes), 'sourceMimeType': 'image/png',
            'privateSourceArchive': str((output / 'crop-source.png').relative_to(ROOT)),
            'selection': 'Real profile input[type=file].set_input_files with the SHA-bound original PNG bytes',
            'captureStatus': 'pending', 'visualAcceptance': 'not_evaluated',
            'cropConfirmationClicked': False, 'profileWriteRequestCount': 0, 'dialogCancelledThemes': []}
        raw['cropBrowserEvents'] = []
    public_failure = None
    browser = None
    try:
        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True,
                executable_path='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
            metadata['browser'] = {'name': 'Google Chrome headless', 'version': browser.version}
            try:
                for theme in ('dark', 'light'):
                    context = browser.new_context(viewport={'width': args.width, 'height': args.height},
                        device_scale_factor=1, color_scheme=theme, reduced_motion='reduce',
                        locale='zh-CN', timezone_id='Asia/Shanghai', service_workers='block')
                    state = {'player': copy.deepcopy(player), 'derived': False, 'cropActive': False}
                    expected_file = '/api/files/game_players/' + quote(player['id'], safe='') + '/' + quote(player.get('avatar', ''), safe='')
                    def intercept(route):
                        request = route.request
                        parsed = urlparse(request.url)
                        path = parsed.path
                        if font_bytes is not None and path == '/__profile__/controlled-serif.ttf' and parsed.netloc == parsed_origin.netloc:
                            route.fulfill(status=200, content_type='font/ttf', body=font_bytes)
                            return
                        if path.startswith('/api/'):
                            item = {'method': request.method, 'path': path, 'theme': theme}
                            raw['apiRequests'].append(item)
                            body, source = None, ''
                            if path == AUTH and request.method == 'POST':
                                body = {'token': 'visual-profile-fixture-token', 'record': {'id': state['player']['id']}}
                                source = 'synthetic_login_render_driver'
                            elif path == '/api/questions/v1/me' and request.method == 'GET':
                                body = state['player']
                                source = 'derived_player_after_synthetic_password' if state['derived'] else 'actual_readonly_player_snapshot'
                            elif path == PASSWORD and request.method == 'POST' and player.get('mustChangePassword'):
                                state['player']['mustChangePassword'] = False
                                state['derived'] = True
                                body = {'token': 'visual-profile-rotated-token', 'player': state['player']}
                                source = 'synthetic_password_render_driver'
                            elif path == '/api/questions/v1/assignments' and request.method == 'GET':
                                body, source = assignments, 'actual_readonly_assignments_snapshot'
                            elif path == '/api/questions/v1/assignments/' + quote(assignment['id'], safe='') and request.method == 'GET':
                                body, source = assignment, 'actual_readonly_assignment_snapshot'
                            elif path in ('/api/questions/v1/notifications', '/api/questions/v1/rewards') and request.method == 'GET':
                                body, source = {'items': []}, 'fixed_empty_auxiliary_outside_scope'
                            elif path == TOKEN and request.method == 'POST' and avatar_bytes is not None:
                                body, source = {'token': 'visual-profile-file-token'}, 'synthetic_file_token_render_driver'
                            elif path == expected_file and request.method == 'GET' and avatar_bytes is not None:
                                item['path'] = '/api/files/game_players/[owner]/[avatar]'
                                item['responseSource'] = 'private_avatar_byte_replay'
                                route.fulfill(status=200, content_type=avatar_mime, body=avatar_bytes)
                                return
                            else:
                                raw['unexpectedApis'].append({'method': request.method, 'path': path})
                                item['responseSource'] = 'unconfigured_api_404'
                                route.fulfill(status=404, content_type='application/json',
                                    body=json.dumps({'error': {'code': 'NOT_FOUND', 'message': '未配置此视觉夹具路径'}}))
                                return
                            item['responseSource'] = source
                            route.fulfill(status=200, content_type='application/json', body=json.dumps(body, ensure_ascii=False))
                        elif parsed.scheme in ('http', 'https') and parsed.netloc == parsed_origin.netloc:
                            route.continue_()
                        else:
                            raw['blockedExternalRequests'].append(request.url)
                            route.abort()
                    context.route('**/*', intercept)
                    page = context.new_page()
                    def record_page_error(error):
                        raw['pageErrors'].append(str(error))
                        if state['cropActive']:
                            raw['cropBrowserEvents'].append({'theme': theme, 'kind': 'pageerror', 'text': str(error)})
                    def record_console(message):
                        if message.type == 'error':
                            raw['consoleErrors'].append(message.text)
                        if state['cropActive']:
                            raw['cropBrowserEvents'].append({'theme': theme, 'kind': 'console',
                                                            'type': message.type, 'text': message.text})
                    page.on('pageerror', record_page_error)
                    page.on('console', record_console)
                    try:
                        page.goto(origin + '/login?theme=' + theme)
                        page.get_by_role('button', name='进入冒险', exact=True).wait_for()
                        # Vite serves actual modules from the frozen source. Check
                        # the critical raw source bytes too, rather than assuming
                        # an unrelated server on this port belongs to this checkout.
                        for source in SOURCES + (CROP_SOURCES if crop_path else []):
                            served = page.evaluate('(path) => import(path + "?raw").then(m => m.default)', '/' + source)
                            expected = (WEB / source).read_bytes()
                            matched = isinstance(served, str) and sha_bytes(served.encode()) == sha_bytes(expected)
                            metadata['servedFrozenSourceChecks'].append({'theme': theme, 'source': source,
                                'sha256': sha_bytes(expected), 'matches': matched})
                            if not matched:
                                raise RuntimeError('The served Web module differs from the frozen source')
                        schema_results = page.evaluate('''async (snapshot) => {
                          const m = await import('/src/api/game.schema.ts');
                          return [['player',m.gamePlayerSchema,snapshot.player],
                            ['assignment',m.gameAssignmentSchema,snapshot.assignment],
                            ['assignments',m.gameAssignmentSummarySchema.array(),snapshot.assignments.items]].map(([name,schema,value]) => {
                              const r = schema.safeParse(value); return {name, success:r.success,
                                issueCount:r.success?0:r.error.issues.length,
                                issueCodes:r.success?[]:[...new Set(r.error.issues.map(x=>x.code))]};
                            });
                        }''', snapshot)
                        metadata['schemaChecks'].extend(dict(item, theme=theme) for item in schema_results)
                        if not all(item.get('success') for item in schema_results):
                            raise RuntimeError('Frozen Web schemas rejected the supplied read-only snapshot')
                        ui_copy = page.evaluate('''async () => {
                          const {uiCopy:c} = await import('/src/config/ui-copy.ts');
                          return {title:c.gameProfilePage.title, identity:c.gameProfilePage.identity,
                            security:c.gameProfilePage.security, settings:c.gameProfilePage.settingsLabel,
                            nickname:c.profileEditor.displayName, profileSave:c.profileEditor.save,
                            menu:c.gameSidebar.menu, openMenu:c.gameSidebar.openMenu,
                            navigation:c.gameSidebar.navigation, logout:c.gameSidebar.logout,
                            passwordTitle:c.passwordEditor.title,
                            destinations:[c.gameNavigation.dashboardDescription,c.gameNavigation.rewardsDescription,
                              c.gameNavigation.notificationsDescription,c.gameNavigation.profileDescription]};
                        }''')
                        raw['uiCopy'] = ui_copy
                        if crop_path:
                            ui_copy['crop'] = page.evaluate('''async () => {
                              const {uiCopy:c} = await import('/src/config/ui-copy.ts');
                              return {title:c.avatarCrop.title,cancel:c.avatarCrop.cancel,
                                confirm:c.avatarCrop.confirm,zoom:c.avatarCrop.zoom};
                            }''')
                        page.get_by_label('登录账号', exact=True).fill(state['player']['account'])
                        page.get_by_label('密码', exact=True).fill('VisualFixture123')
                        page.get_by_role('button', name='进入冒险', exact=True).click()
                        if state['player'].get('mustChangePassword'):
                            page.get_by_role('heading', name='首次登录，请先修改密码', exact=True).wait_for()
                            page.get_by_label('当前密码', exact=True).fill('VisualFixture123')
                            page.get_by_label('新密码', exact=True).fill('NewVisualFixture123')
                            page.get_by_label('确认新密码', exact=True).fill('NewVisualFixture123')
                            page.get_by_role('button', name='保存新密码', exact=True).click()
                        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
                        page.goto(origin + '/profile?theme=' + theme)
                        page.get_by_role('heading', name=ui_copy['title'], exact=True).wait_for()
                        if page.locator('.game-world').get_attribute('data-desktop') is not None:
                            raise RuntimeError('The supplied viewport did not render the mobile profile')
                        if font_bytes is not None:
                            page.add_style_tag(content='@font-face { font-family: StarwardControlledSerif; src: url("' +
                                origin + '/__profile__/controlled-serif.ttf") format("truetype"); font-weight: 100 900; font-style: normal; font-display: block; } :root { --font-display: StarwardControlledSerif, serif !important; }')
                            page.evaluate('document.fonts.load("34px StarwardControlledSerif")')
                        def capture(name, required, additional_selectors=None):
                            page.wait_for_load_state('networkidle')
                            page.evaluate('document.fonts.ready')
                            page.evaluate('''() => { window.scrollTo({top:0,behavior:'instant'});
                              document.querySelector('.game-shell')?.scrollTo({top:0,behavior:'instant'}); }''')
                            for selector in required:
                                page.locator(selector).wait_for(state='visible')
                            if page.evaluate('document.documentElement.dataset.theme') != theme:
                                raise RuntimeError('The captured Web theme did not match the requested theme')
                            filename = name + '-' + theme
                            screenshot = output / (filename + '.png')
                            page.screenshot(path=str(screenshot), full_page=False, animations='disabled')
                            screenshot.chmod(0o600)
                            measurements = page.evaluate('''selectors => {
                              const result={};for(const [name,selector] of Object.entries(selectors)) {
                                const el=document.querySelector(selector);if(!el)continue;
                                const s=getComputedStyle(el),b=el.getBoundingClientRect();
                                result[name]={selector,text:el.matches('input')?'[input omitted]':el.textContent.trim(),
                                  x:b.x,y:b.y,width:b.width,height:b.height,
                                  visible:s.display!=='none'&&s.visibility!=='hidden'&&b.width>0&&b.height>0,
                                  fontSize:s.fontSize,fontFamily:s.fontFamily,fontWeight:s.fontWeight,lineHeight:s.lineHeight,
                                  color:s.color,background:s.backgroundColor,padding:s.padding,margin:s.margin,
                                  border:s.border,borderRadius:s.borderRadius,display:s.display,gap:s.gap};
                              } result.document={scrollWidth:document.documentElement.scrollWidth,
                                clientWidth:document.documentElement.clientWidth,scrollHeight:document.documentElement.scrollHeight,
                                innerWidth,innerHeight,visualViewportWidth:visualViewport?.width,
                                visualViewportHeight:visualViewport?.height,theme:document.documentElement.dataset.theme,
                                dpr:devicePixelRatio,windowScrollY:scrollY,mainScrollTop:document.querySelector('.game-shell')?.scrollTop};
                              return result;
                            }''', dict(SELECTORS, **(additional_selectors or {})))
                            if name == 'profile-avatar-crop':
                                measurements['cropZoom']['accentColor'] = page.locator(CROP_SELECTORS['cropZoom']).evaluate(
                                    '(el) => getComputedStyle(el).accentColor')
                                measurements['cropImage']['intrinsic'] = page.locator(CROP_SELECTORS['cropImage']).evaluate(
                                    '(el) => ({complete:el.complete,width:el.naturalWidth,height:el.naturalHeight})')
                            item = {'state': name, 'theme': theme, 'route': '/profile',
                                'screenshot': str(screenshot.relative_to(ROOT)), 'screenshotSha256': sha_bytes(screenshot.read_bytes()),
                                'measurements': measurements}
                            raw['stateMeasurements'].append(item)
                            private_write(output / (filename + '.json'), json.dumps(item, ensure_ascii=False, indent=2) + '\n')
                            private_write(output / (filename + '.html'), page.content())
                            metadata['states'].append({k: item[k] for k in ('state','theme','route','screenshot','screenshotSha256')})
                            metadata['states'][-1]['documentFitsWidth'] = measurements['document']['scrollWidth'] <= args.width
                            if name == 'profile-avatar-crop':
                                for key, extension in (('privateGeometry', '.json'), ('privateDom', '.html')):
                                    evidence = output / (filename + extension)
                                    metadata['states'][-1][key] = {'file': str(evidence.relative_to(ROOT)),
                                                                 'sha256': sha_bytes(evidence.read_bytes())}
                        page.get_by_role('tab', name=ui_copy['identity'], exact=True).click()
                        if page.get_by_label(ui_copy['nickname'], exact=True).input_value() != state['player']['displayName']:
                            raise RuntimeError('The profile nickname did not match the supplied player snapshot')
                        if page.locator('.profile-editor__account strong').inner_text() != state['player']['account']:
                            raise RuntimeError('The read-only account did not match the supplied player snapshot')
                        if page.locator('.profile-editor input:not([type="file"])').get_attribute('maxlength') != '40':
                            raise RuntimeError('The frozen Web nickname limit differs from the expected profile contract')
                        capture('profile-identity', ['.game-profile-grid', '.profile-editor'])
                        if crop_path:
                            state['cropActive'] = True
                            page.locator('.profile-editor input[type="file"]').set_input_files({
                                'name': crop_path.name, 'mimeType': 'image/png', 'buffer': crop_bytes})
                            dialog = page.locator(CROP_SELECTORS['cropDialog'])
                            dialog.wait_for(state='visible')
                            # AppDialog also owns an accessible sr-only heading;
                            # measure the visible title without a duplicate role match.
                            title = page.locator(CROP_SELECTORS['cropTitle'])
                            title.wait_for(state='visible')
                            if title.inner_text() != ui_copy['crop']['title']:
                                raise RuntimeError('The real crop dialog title did not match the frozen copy')
                            page.wait_for_function('''() => {
                              const image=document.querySelector('.avatar-crop-stage img');
                              const confirm=document.querySelector('.avatar-crop-actions .ui-button--primary');
                              return image?.complete && image.naturalWidth>0 && image.naturalHeight>0 && confirm && !confirm.disabled;
                            }''')
                            capture('profile-avatar-crop', [CROP_SELECTORS[key] for key in
                                ('cropDialog', 'cropStage', 'cropImage', 'cropZoom', 'cropConfirm', 'cropCancel')], CROP_SELECTORS)
                            dialog.get_by_role('button', name=ui_copy['crop']['cancel'], exact=True).click()
                            dialog.wait_for(state='detached')
                            state['cropActive'] = False
                            if (page.get_by_label(ui_copy['nickname'], exact=True).input_value() != state['player']['displayName'] or
                                    page.locator('.profile-editor__filename').count() or
                                    page.locator('.profile-editor input[type="file"]').input_value()):
                                raise RuntimeError('Cancelling the captured crop dialog changed the profile draft')
                            metadata['cropReference']['dialogCancelledThemes'].append(theme)
                            if any(item['path'] == PROFILE and item['method'] in ('POST', 'PATCH', 'PUT', 'DELETE')
                                   for item in raw['apiRequests']):
                                raise RuntimeError('The crop reference unexpectedly attempted a profile write')
                        page.get_by_role('tab', name=ui_copy['security'], exact=True).click()
                        page.get_by_role('heading', name=ui_copy['passwordTitle'], exact=True).wait_for()
                        if page.locator('.game-password-section input').count() != 3:
                            raise RuntimeError('The ordinary password form did not expose exactly three fields')
                        capture('profile-security', ['.game-password-section'])
                        page.get_by_role('tab', name=ui_copy['identity'], exact=True).click()
                        page.evaluate('''() => {window.scrollTo({top:0,behavior:'instant'});
                          document.querySelector('.game-shell')?.scrollTo({top:0,behavior:'instant'});}''')
                        page.locator('.game-menu-trigger').click()
                        page.locator('.game-sidebar').wait_for(state='visible')
                        if page.locator('.game-sidebar__nav a').count() != 4:
                            raise RuntimeError('The frozen phone menu did not expose the four formal destinations')
                        capture('profile-menu', ['.game-sidebar', '.game-sidebar__nav', '.game-sidebar__logout'])
                    finally:
                        context.close()
            finally:
                browser.close()
        frozen_check()
        metadata['sourceCheckoutCleanAfter'] = True
        if len(metadata['states']) != len(capture_states) * 2 or not all(item['documentFitsWidth'] for item in metadata['states']):
            raise RuntimeError('The requested profile references were incomplete or overflowed the viewport')
        if crop_path:
            writes = sum(item['path'] == PROFILE and item['method'] in ('POST', 'PATCH', 'PUT', 'DELETE')
                         for item in raw['apiRequests'])
            metadata['cropReference']['profileWriteRequestCount'] = writes
            if (sha_bytes(crop_path.read_bytes()) != crop_sha or writes or
                    metadata['cropReference']['dialogCancelledThemes'] != ['dark', 'light']):
                raise RuntimeError('Crop source bytes, cancellation or no-write capture checks did not hold')
            metadata['cropReference']['sourceSha256RecheckedAfter'] = True
            metadata['cropReference']['captureStatus'] = 'captured'
        if raw['pageErrors'] or raw['consoleErrors'] or raw['unexpectedApis']:
            raise RuntimeError('The intercepted profile capture recorded a browser or unexpected-API error')
        metadata['status'] = 'passed'
    except Exception as error:
        raw['captureException'] = {'type': type(error).__name__, 'message': str(error)}
        # Raw errors may contain protected URLs or accounts. Keep only a fixed
        # safe message public; detailed browser events stay in private output.
        public_failure = 'Profile reference capture did not finish all frozen-source, schema, state and browser checks'
        metadata['status'] = 'incomplete'
    finally:
        counts = {}
        for item in raw['apiRequests']:
            key = item.get('responseSource', 'unclassified')
            counts[key] = counts.get(key, 0) + 1
        metadata['responseSourceCounts'] = counts
        metadata['consoleErrorCount'] = len(raw['consoleErrors'])
        metadata['pageErrorCount'] = len(raw['pageErrors'])
        metadata['unexpectedApiCount'] = len(raw['unexpectedApis'])
        metadata['blockedExternalRequestCount'] = len(raw['blockedExternalRequests'])
        if crop_path:
            metadata['cropReference']['profileWriteRequestCount'] = sum(
                item['path'] == PROFILE and item['method'] in ('POST', 'PATCH', 'PUT', 'DELETE')
                for item in raw['apiRequests'])
        if public_failure:
            metadata['error'] = public_failure
        private_write(output / 'browser-raw.json', json.dumps(raw, ensure_ascii=False, indent=2) + '\n')
        metadata['privateRawEvidence'] = {'file': str((output / 'browser-raw.json').relative_to(ROOT)),
                                         'sha256': sha_bytes((output / 'browser-raw.json').read_bytes())}
        PUBLIC.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'status': metadata['status'], 'states': len(metadata['states']),
                      'schemaChecks': len(metadata['schemaChecks']),
                      'consoleErrors': metadata['consoleErrorCount'], 'pageErrors': metadata['pageErrorCount'],
                      'browserUsesRealBackend': False, 'report': str(PUBLIC.relative_to(ROOT))}))
    return 0 if metadata['status'] == 'passed' else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception:
        print(json.dumps({'status': 'incomplete', 'error': 'Private fixture or frozen-Web setup check failed; no live backend requests were sent'}))
        raise SystemExit(1)

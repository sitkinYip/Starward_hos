#!/usr/bin/env python3
"""Capture frozen Web source with fully intercepted, shared response fixtures."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import subprocess
from urllib.parse import quote, urlparse

ROOT = Path(__file__).resolve().parents[1]
PRIVATE_PACKAGES = ROOT / 'artifacts/private/python-playwright'
if PRIVATE_PACKAGES.exists():
    sys.path.insert(0, str(PRIVATE_PACKAGES))
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--url', default='http://127.0.0.1:5178')
parser.add_argument('--width', type=int, default=390)
parser.add_argument('--height', type=int, default=844)
parser.add_argument('--output', default='artifacts/web-baseline')
parser.add_argument('--font-file', type=Path)
parser.add_argument('--fixtures-json', type=Path, help='Read-only isolated PB snapshots: {player, assignment, assignments?:{items:[...]}}')
CAPTURE_STATES = ['login', 'forced-password', 'home', 'detail', 'history', 'logout']
parser.add_argument('--states', nargs='+', choices=CAPTURE_STATES + ['error'], default=CAPTURE_STATES,
                    help='Capture only these states, while navigating their required prerequisites; default: all six states')
args = parser.parse_args()
requested_states = list(dict.fromkeys(args.states))
normal_states = [state for state in requested_states if state != 'error']
WEB_SOURCE = Path(os.environ.get('STARWARD_WEB_SOURCE', ROOT.parent / 'questions-web')).resolve()
if subprocess.check_output(['git','rev-parse','HEAD'],cwd=WEB_SOURCE,text=True).strip() != '4b7d1a0a00051ac630e459b0fd6c074f821d7455':
    raise SystemExit('Frozen Web source commit changed')
if subprocess.check_output(['git','status','--porcelain'],cwd=WEB_SOURCE,text=True).strip():
    raise SystemExit('Web source is dirty; refuse to label it frozen')
OUTPUT = ROOT / args.output
FONT = args.font_file.resolve() if args.font_file else None
FONT_DATA = FONT.read_bytes() if FONT else None
snapshot_bytes = args.fixtures_json.read_bytes() if args.fixtures_json else None
error_fixture = None
if args.fixtures_json:
    snapshot = json.loads(snapshot_bytes)
    if not isinstance(snapshot, dict):
        raise SystemExit('--fixtures-json requires an object')
    player_fixture = snapshot.get('player')
    assignment_fixture = snapshot.get('assignment')
    assignments_fixture = snapshot.get('assignments', {'items':[assignment_fixture]})
    error_fixture = snapshot.get('error')
    if not isinstance(player_fixture, dict) or not isinstance(assignment_fixture, dict):
        raise SystemExit('--fixtures-json requires player and assignment objects')
    if not isinstance(assignments_fixture, dict) or not isinstance(assignments_fixture.get('items'), list):
        raise SystemExit('--fixtures-json assignments must be an object with an items array')
    if any(not isinstance(item, dict) for item in assignments_fixture['items']):
        raise SystemExit('--fixtures-json assignment list contains a non-object item')
    data_description = 'player/list/detail use actual isolated PocketBase response snapshots; auth/password are synthetic render drivers and auxiliary notifications/rewards are fixed empty responses if requested; all browser API calls are intercepted'
else:
    source = (ROOT / 'entry/src/test/fixtures/WebFixture.ets').read_text()
    fixtures = {}
    for name, literal in re.findall(r'export const (WEB_\w+): string = (".*?");', source):
        fixtures[name] = json.loads(json.loads(literal))
    player_fixture = fixtures['WEB_PLAYER_JSON']
    assignment_fixture = fixtures['WEB_ASSIGNMENT_JSON']
    assignments_fixture = fixtures.get('WEB_ASSIGNMENTS_JSON', {'items':[assignment_fixture]})
    data_description = 'same frozen e2e fixture as native Contract tests; no live backend requests'
if not isinstance(player_fixture.get('account'), str) or not player_fixture.get('account'):
    raise SystemExit('Snapshot player account is missing')
if not isinstance(assignment_fixture.get('id'), str) or not assignment_fixture.get('id'):
    raise SystemExit('Snapshot assignment id is missing')
if assignment_fixture.get('status') != 'assigned':
    raise SystemExit('This first-slice capture requires an assigned, not-yet-started assignment')
AUTH_PATH = '/api/collections/game_players/auth-with-password'
PASSWORD_PATH = '/api/questions/v1/me/change-password'
if 'error' in requested_states:
    if not isinstance(error_fixture, dict):
        raise SystemExit('--states error requires fixtures-json error:{requestPath,status,body,pagePath?}')
    error_path = error_fixture.get('requestPath')
    if not isinstance(error_path, str) or not error_path.startswith('/api/') or '?' in error_path or '#' in error_path:
        raise SystemExit('Error requestPath must be an API pathname without query or fragment')
    error_status = error_fixture.get('status')
    if isinstance(error_status, bool) or not isinstance(error_status, int) or not 400 <= error_status <= 599:
        raise SystemExit('Error status must be an HTTP error status from 400 through 599')
    if not isinstance(error_fixture.get('body'), dict):
        raise SystemExit('Error body must contain the explicit error-response object')
    error_method = error_fixture.get('method', 'POST' if error_path in (AUTH_PATH, PASSWORD_PATH) else 'GET')
    if error_method not in ('GET','POST'):
        raise SystemExit('Error method must be GET or POST')
    error_page = error_fixture.get('pagePath', '/play/' + quote(assignment_fixture['id'],safe='') if error_path.startswith('/api/questions/v1/assignments/') else '/')
    if not isinstance(error_page,str) or (error_page != '/' and error_page != '/login' and not re.fullmatch(r'/play/[A-Za-z0-9_-]+',error_page)):
        raise SystemExit('Error pagePath must be a first-slice local route')
    if error_path == PASSWORD_PATH and not player_fixture.get('mustChangePassword'):
        raise SystemExit('A password-error capture requires a real snapshot with mustChangePassword=true')

snapshot_archive = None
if snapshot_bytes is not None:
    snapshot_hash = hashlib.sha256(snapshot_bytes).hexdigest()
    snapshot_archive = ROOT / 'artifacts/private/web-visual-inputs' / (snapshot_hash + '.json')
    snapshot_archive.parent.mkdir(parents=True, exist_ok=True)
    if snapshot_archive.is_symlink():
        raise SystemExit('Refusing a symlink in the private snapshot archive')
    if snapshot_archive.exists():
        if snapshot_archive.read_bytes() != snapshot_bytes:
            raise SystemExit('Snapshot archive content does not match its SHA-256 name')
    else:
        archive_fd = os.open(snapshot_archive, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(archive_fd,'wb') as archive:
            archive.write(snapshot_bytes)
OUTPUT.mkdir(parents=True, exist_ok=True)
# Remove only this tool's generated state files, never unrelated images or
# provenance authored by another tool. This prevents an old skipped state from
# appearing to belong to the next input snapshot.
for generated_state in CAPTURE_STATES + ['error']:
    for generated_theme in ('dark','light'):
        for suffix in ('.png','.json'):
            previous = OUTPUT / (generated_state + '-' + generated_theme + suffix)
            if previous.is_symlink():
                raise SystemExit('Refusing a symlink in capture output')
            if previous.exists():
                previous.unlink()
old_summary = OUTPUT / 'capture-summary.json'
if old_summary.is_symlink():
    raise SystemExit('Refusing a symlink in capture summary output')
if old_summary.exists():
    old_summary.unlink()

selectors = {
    'authHeader': '.game-auth__header', 'brand': '.game-brand',
    'brandWordmark': '.game-brand__wordmark', 'themePicker': '.game-theme-picker',
    'authStory': '.game-auth__story', 'authEyebrow': '.game-auth__story .eyebrow',
    'authStoryTitle': '.game-auth__story h1', 'authStoryDescription': '.game-auth__story-copy > p:not(.eyebrow)',
    'authAtlas': '.game-auth__story > .celestial-atlas',
    'authAtlasStar': '.game-auth__story .celestial-atlas__star',
    'authEntry': '.game-auth__entry', 'loginTitle': '.game-auth__entry > h2',
    'loginAccount': 'input[autocomplete="username"]', 'loginPassword': 'input[autocomplete="current-password"]',
    'authSubmit': '.game-auth .game-cta', 'authHelp': '.game-auth__help', 'authFooter': '.game-auth__footer',
    'passwordSection': '.game-password-section', 'passwordTitle': '.game-password-section h2',
    'passwordDescription': '.game-password-section > .game-muted',
    'passwordCurrent': '.game-password-section .game-form > .ui-field:nth-child(1) input',
    'passwordNew': '.game-password-section .game-form > .ui-field:nth-child(2) input',
    'passwordConfirm': '.game-password-section .game-form > .ui-field:nth-child(3) input',
    'topbar': '.game-topbar', 'shell': '.game-shell', 'heading': '.game-page-heading',
    'headingEyebrow': '.game-page-heading .eyebrow', 'headingTitle': '.game-page-heading h1',
    'headingDescription': '.game-page-heading__description', 'navigation': '.game-navigation',
    'tabs': '.game-tabs__list', 'chapterCard': '.chapter-card', 'chapterNumber': '.chapter-card__number',
    'chapterBody': '.chapter-card__body', 'chapterTitle': '.chapter-card h2',
    'chapterDescription': '.chapter-card__description', 'chapterMeta': '.chapter-card__meta',
    'chapterFooter': '.chapter-card__footer', 'chapterProgress': '.chapter-card__progress',
    'chapterAction': '.chapter-card__footer .game-action-link', 'passport': '.game-lobby__passport',
    'syncNote': '.game-sync-note', 'emptyState': '.game-empty',
    'brief': '.assignment-brief', 'briefBody': '.assignment-brief__body',
    'briefEyebrow': '.assignment-brief .eyebrow', 'briefTitle': '.assignment-brief h1',
    'briefDescription': '.assignment-brief__description', 'briefFacts': '.assignment-brief__facts',
    'briefActions': '.assignment-brief__actions', 'briefSubmit': '.assignment-brief .game-cta',
    'briefSaveHint': '.assignment-brief__body > .game-muted:last-child',
    'sessionHeader': '.session-header', 'travelerIdentity': '.traveler-identity',
    'travelerName': '.traveler-name', 'travelerRank': '.traveler-rank',
    'sessionEyebrow': '.session-header .eyebrow', 'sessionProgress': '.session-progress',
    'progressNumber': '.session-progress strong', 'menuTrigger': '.game-menu-trigger',
    'briefFactLabel': '.assignment-brief__facts dt', 'briefFactValue': '.assignment-brief__facts dd',
    'fieldLabel': '.ui-field__label', 'workspace': '.workspace-tabs',
    'activePanel': '.workspace-tabs > [role="tabpanel"][data-state="active"]',
    'currentTab': '.game-tabs__list [role="tab"]:nth-child(1)',
    'historyTab': '.game-tabs__list [role="tab"]:nth-child(2)',
    'chapterList': '.chapter-list', 'emptyIcon': '.game-empty > svg',
    'emptyTitle': '.game-empty h2', 'emptyDescription': '.game-empty p',
    'failureNotice': '.game-notice[role="alert"]', 'failureText': '.game-notice__body > p',
    'failureActions': '.game-notice__actions'
}
metadata = {'viewport': {'width': args.width, 'height': args.height}, 'deviceScaleFactor': 1,
            'sourceCommit': '4b7d1a0a00051ac630e459b0fd6c074f821d7455',
            'data': data_description,
            'snapshotInput': {'file':str(args.fixtures_json.relative_to(ROOT)) if args.fixtures_json and args.fixtures_json.is_absolute() and args.fixtures_json.is_relative_to(ROOT) else (str(args.fixtures_json) if args.fixtures_json else None), 'sha256':hashlib.sha256(snapshot_bytes).hexdigest() if snapshot_bytes else None, 'archiveFile':str(snapshot_archive.relative_to(ROOT)) if snapshot_archive else None, 'assignmentCount':len(assignments_fixture['items'])},
            'browserUsesRealBackend':False, 'requestedStates':requested_states, 'skippedStates':[],
            'errorReplay': {'requestPath':error_path,'method':error_method,'status':error_status,'pagePath':error_page,'kind':'explicit error-response replay / synthetic fault UI; no real failing browser request'} if 'error' in requested_states else None,
            'stateDerivation':'If the supplied player requires a password change, the local render harness changes that flag after its synthetic change-password reply; no backend write is sent.',
            'fontControl': {'enabled':bool(FONT), 'file':str(FONT.relative_to(ROOT)) if FONT and FONT.is_relative_to(ROOT) else (FONT.name if FONT else None), 'sha256':hashlib.sha256(FONT_DATA).hexdigest() if FONT_DATA else None, 'method':'Playwright @font-face override of --font-display; source files unchanged' if FONT else 'original system-font CSS stack'},
            'states': [], 'apiRequests': [], 'blockedExternalDomains': [], 'pageErrors': []}

def capture(page, state, theme):
    if FONT:
        page.add_style_tag(content='@font-face { font-family: StarwardControlledSerif; src: url("' + args.url + '/__baseline__/controlled-serif.ttf") format("truetype"); font-weight: 100 900; font-style: normal; font-display: block; } :root { --font-display: StarwardControlledSerif, serif !important; }')
        page.evaluate('document.fonts.load("34px StarwardControlledSerif")')
    page.wait_for_load_state('networkidle')
    page.evaluate('document.fonts.ready')
    page.screenshot(path=str(OUTPUT / f'{state}-{theme}.png'), full_page=False, animations='disabled')
    measurements = page.evaluate('''(selectors) => {
      const result = {};
      for (const [name, selector] of Object.entries(selectors)) {
        const el = document.querySelector(selector);
        if (!el) continue;
        const s = getComputedStyle(el), b = el.getBoundingClientRect();
        result[name] = {selector, text: el.matches('input') ? '[input omitted]' : el.textContent.trim(),
          x:b.x,y:b.y,width:b.width,height:b.height,visible:s.display!=='none'&&s.visibility!=='hidden'&&b.width>0&&b.height>0,
          fontSize:s.fontSize,fontFamily:s.fontFamily,fontWeight:s.fontWeight,lineHeight:s.lineHeight,
          letterSpacing:s.letterSpacing,color:s.color,background:s.backgroundColor,padding:s.padding,margin:s.margin,
          border:s.border,borderRadius:s.borderRadius,display:s.display,gap:s.gap};
      }
      result.document = {scrollWidth:document.documentElement.scrollWidth,clientWidth:document.documentElement.clientWidth,
        height:document.documentElement.scrollHeight,theme:document.documentElement.dataset.theme,
        fontScale:window.devicePixelRatio};
      return result;
    }''', selectors)
    item = {'state': state, 'theme': theme, 'urlPath': urlparse(page.url).path, 'screenshot': f'{state}-{theme}.png',
            'screenshotSha256':hashlib.sha256((OUTPUT / f'{state}-{theme}.png').read_bytes()).hexdigest(), 'measurements': measurements}
    metadata['states'].append(item)
    (OUTPUT / f'{state}-{theme}.json').write_text(json.dumps(item, ensure_ascii=False, indent=2) + '\n')

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, executable_path='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
    metadata['browser'] = {'name':'Google Chrome headless','version':browser.version,'pythonPlaywright':'1.64.1'}
    try:
      for theme in ['dark', 'light']:
        context = browser.new_context(viewport={'width':args.width,'height':args.height}, device_scale_factor=1,
                                      color_scheme=theme, reduced_motion='reduce', locale='zh-CN', timezone_id='Asia/Shanghai')
        page = context.new_page()
        state = {'player':copy.deepcopy(player_fixture), 'playerDerived':False, 'assignment':copy.deepcopy(assignment_fixture),
                 'assignments':copy.deepcopy(assignments_fixture)}
        page.on('pageerror', lambda error: metadata['pageErrors'].append(str(error)))
        def intercept(route):
          request = route.request
          parsed = urlparse(request.url)
          path = parsed.path
          if FONT_DATA and path == '/__baseline__/controlled-serif.ttf':
            route.fulfill(status=200,content_type='font/ttf',body=FONT_DATA)
          elif path.startswith('/api/'):
            trace = {'method':request.method,'path':path}
            metadata['apiRequests'].append(trace)
            if state.get('errorEnabled') and path == error_path and request.method == error_method:
              trace['responseSource'] = 'explicit_synthetic_fault_fixture'
              state['faultRequests'] = state.get('faultRequests',0) + 1
              route.fulfill(status=error_status,content_type='application/json',body=json.dumps(error_fixture['body'],ensure_ascii=False))
              return
            if path == AUTH_PATH:
              trace['responseSource'] = 'synthetic_auth_render_driver'
              body = {'token':'visual-fixture-token','record':{'id':state['player']['id']}}
            elif path == '/api/questions/v1/me':
              trace['responseSource'] = 'derived_player_after_synthetic_password' if state['playerDerived'] else ('actual_snapshot_player' if args.fixtures_json else 'frozen_e2e_player')
              body = state['player']
            elif path == PASSWORD_PATH:
              trace['responseSource'] = 'synthetic_password_render_driver'
              state['player']['mustChangePassword'] = False
              state['playerDerived'] = True
              body = {'token':'visual-fixture-rotated-token','player':state['player']}
            elif path == '/api/questions/v1/assignments':
              trace['responseSource'] = 'actual_snapshot_assignments' if args.fixtures_json else 'frozen_e2e_assignments'
              body = state['assignments']
            elif path == '/api/questions/v1/assignments/' + quote(state['assignment']['id'],safe=''):
              trace['responseSource'] = 'actual_snapshot_assignment' if args.fixtures_json else 'frozen_e2e_assignment'
              body = state['assignment']
            elif path in ('/api/questions/v1/notifications','/api/questions/v1/rewards'):
              trace['responseSource'] = 'fixed_empty_auxiliary_outside_slice'
              body = {'items':[]}
            else:
              trace['responseSource'] = 'synthetic_unconfigured_route_404'
              route.fulfill(status=404, content_type='application/json', body=json.dumps({'error':{'code':'NOT_FOUND','message':'未配置此视觉夹具路径'}}))
              return
            route.fulfill(status=200, content_type='application/json', body=json.dumps(body, ensure_ascii=False))
          elif parsed.netloc == urlparse(args.url).netloc:
            route.continue_()
          elif parsed.netloc == 'assets.example':
            route.fulfill(status=200,content_type='image/svg+xml',body='<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40"><rect width="40" height="40" fill="#d4bc7d"/></svg>')
          else:
            metadata['blockedExternalDomains'].append(parsed.netloc)
            route.abort()
        page.route('**/*', intercept)
        def submit_login():
            page.get_by_label('登录账号',exact=True).fill(state['player']['account'])
            page.get_by_label('密码',exact=True).fill('VisualFixture123')
            page.get_by_role('button',name='进入冒险',exact=True).click()
        def submit_password():
            page.get_by_label('当前密码',exact=True).fill('VisualFixture123')
            page.get_by_label('新密码',exact=True).fill('NewVisualFixture123')
            page.get_by_label('确认新密码',exact=True).fill('NewVisualFixture123')
            page.get_by_role('button',name='保存新密码',exact=True).click()
        def finish_context():
            if 'error' in requested_states:
                state['player'] = copy.deepcopy(player_fixture)
                state['playerDerived'] = False
                page.evaluate("localStorage.removeItem('starward:v2:auth')")
                state['errorEnabled'] = error_path == AUTH_PATH
                state['faultRequests'] = 0
                page.goto(args.url + '/login?theme=' + theme)
                page.get_by_role('button',name='进入冒险',exact=True).wait_for()
                submit_login()
                if error_path != AUTH_PATH:
                    if state['player'].get('mustChangePassword'):
                        page.get_by_role('heading',name='首次登录，请先修改密码',exact=True).wait_for()
                        state['errorEnabled'] = error_path == PASSWORD_PATH
                        submit_password()
                    if error_path != PASSWORD_PATH:
                        page.get_by_role('heading',name='下一段故事，等你落笔。',exact=True).wait_for()
                        state['errorEnabled'] = True
                        page.goto(args.url + error_page + '?theme=' + theme)
                page.locator('.game-notice[role="alert"]').wait_for()
                if not state['faultRequests']:
                    raise AssertionError('Error capture did not replay the explicitly supplied failing request')
                capture(page,'error',theme)
                metadata.setdefault('errorFaultRequests',{})[theme] = state['faultRequests']
            context.close()
        page.goto(args.url + '/login?theme=' + theme)
        page.wait_for_load_state('networkidle')
        # Inspect first, then use the established accessible fields and buttons.
        if not page.get_by_role('button', name='进入冒险', exact=True).is_visible():
            raise AssertionError('Frozen source did not render login')
        if not normal_states:
            finish_context()
            continue
        if 'login' in normal_states:
            capture(page,'login',theme)
        if set(normal_states) == {'login'}:
            finish_context()
            continue
        submit_login()
        if state['player'].get('mustChangePassword'):
            page.get_by_role('heading',name='首次登录，请先修改密码',exact=True).wait_for()
            if 'forced-password' in normal_states:
                capture(page,'forced-password',theme)
            if set(normal_states).issubset({'login','forced-password'}):
                finish_context()
                continue
            submit_password()
        elif 'forced-password' in normal_states:
            metadata['skippedStates'].append({'state':'forced-password','theme':theme,'reason':'The read-only player snapshot does not require a password change; the capture does not alter it to manufacture this state.'})
        if set(normal_states).issubset({'login','forced-password'}):
            finish_context()
            continue
        page.get_by_role('heading',name='下一段故事，等你落笔。',exact=True).wait_for()
        if 'home' in normal_states:
            page.locator('.chapter-card:visible, .game-empty:visible').first.wait_for()
            capture(page,'home',theme)
        if 'detail' in normal_states:
            detail_path = '/play/' + quote(state['assignment']['id'],safe='')
            page.goto(args.url + detail_path + '?theme=' + theme)
            page.get_by_role('button',name='开始本场冒险',exact=True).wait_for()
            capture(page,'detail',theme)
        if 'history' in normal_states:
            page.goto(args.url + '/?theme=' + theme)
            page.get_by_role('tab',name=re.compile('旅途回响')).click()
            if any(item.get('status') in ('completed','cancelled') for item in state['assignments']['items']):
                page.locator('.game-tabs__content[data-state="active"] .chapter-card').first.wait_for()
            else:
                page.get_by_role('heading',name='故事的第一页，还空着。',exact=True).wait_for()
            capture(page,'history',theme)
        if 'logout' in normal_states:
            page.evaluate("localStorage.removeItem('starward:v2:auth')")
            page.goto(args.url + '/login?theme=' + theme)
            capture(page,'logout',theme)
        finish_context()
    finally:
      browser.close()
metadata['blockedExternalDomains'] = sorted(set(metadata['blockedExternalDomains']))
metadata['responseSourceCounts'] = {}
for request in metadata['apiRequests']:
    source = request.get('responseSource','unclassified')
    metadata['responseSourceCounts'][source] = metadata['responseSourceCounts'].get(source,0) + 1
(OUTPUT / 'capture-summary.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
if metadata['pageErrors']:
    raise SystemExit('Web capture reported page errors; inspect capture-summary.json')
print(json.dumps({'states':len(metadata['states']),'pageErrors':len(metadata['pageErrors']),'externalRequestsAllowed':0,'output':str(OUTPUT)}))

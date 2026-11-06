#!/usr/bin/env python3
"""Replay actual active/completed text-question DTOs in the frozen Web app.

Default help and plan are inert. Run uses an existing frozen local Web service,
an isolated Chromium context, and explicitly registered question image bytes.
The draft is local to the browser. No start, answer, backend, or device action
is performed. Focus is a browser reference, with no native keyboard simulation.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import sys
from types import ModuleType
from urllib.parse import quote, urlparse
from hashlib import sha256


ROOT = Path(__file__).resolve().parents[1]
FRAME_PATH = ROOT / 'scripts/capture-web-question-frame.py'
FRAME_SHA = '12f9b6563ebb95cc141043e966c009375873de0b8de764df9a0308ecf4ae520f'
CONTENT_SHA = '1ad7a59cc1f13e6dd7ec5550c8f5ab4a5906b90f9a9b56ac948143a4995e8745'
FONT_SHA = '050080d9255a86808f2945bffac582b31ef32bc36411ce29563b4961670c66f9'
BASE_URL = 'http://127.0.0.1:5178'
WIDTH, HEIGHT = 376, 742
THEMES = ('light', 'dark')
STATES = ('idle', 'focused-draft', 'blurred-draft', 'completed-disabled')
SOURCES = ('src/components/ui/FormControls.tsx', 'src/components/ui/Button.tsx',
           'src/styles/foundation/tokens.css', 'src/styles/foundation/base.css')
PLAN = {'scope': 'Same text answer input and nearby controls, active and real completed history',
        'width': WIDTH, 'height': HEIGHT, 'deviceScaleFactor': 1, 'themes': THEMES,
        'statesPerTheme': STATES, 'keyboardSimulated': False, 'businessAcceptance': False,
        'nativeAcceptance': False, 'syntheticAuthentication': True, 'syntheticCompletion': False}

MEASURE = r"""() => {
  const card=document.querySelector('.quest-card'), form=card.querySelector('.answer-form');
  const label=form.querySelector('.text-answer'), field=label.querySelector('.ui-input--line');
  const caption=form.querySelector('.text-answer .sr-only');
  const actions=form.querySelector('.answer-actions'), submit=actions.querySelector('button[type=submit]');
  const style=el=>{
    if(!el)return null;
    const {x,y,width,height,bottom}=el.getBoundingClientRect(), s=getComputedStyle(el);
    return {x,y,width,height,bottom,layoutWidth:el.offsetWidth,layoutHeight:el.offsetHeight,
      fontSize:s.fontSize,lineHeight:s.lineHeight,color:s.color,background:s.backgroundColor,
      minHeight:s.minHeight,padding:s.padding,borderTop:s.borderTopWidth,
      borderLeft:s.borderLeftWidth,borderRight:s.borderRightWidth,borderBottom:s.borderBottomWidth,
      borderBottomColor:s.borderBottomColor,radius:s.borderBottomLeftRadius,opacity:s.opacity,
      marginTop:s.marginTop,boxShadow:s.boxShadow,transform:s.transform,position:s.position,
      outlineWidth:s.outlineWidth,outlineColor:s.outlineColor,outlineOffset:s.outlineOffset};
  };
  const content=card.querySelector('.quest-content'), root=getComputedStyle(document.documentElement);
  const placeholder=getComputedStyle(field,'::placeholder');
  return {conditions:{width:innerWidth,height:innerHeight,dpr:devicePixelRatio,
      theme:document.documentElement.dataset.theme,scrollWidth:document.documentElement.scrollWidth,
      scale:visualViewport?.scale||1,coarsePointer:matchMedia('(pointer:coarse)').matches},
    geometry:{form:style(form),field:style(field),actions:style(actions),submit:style(submit),
      label:style(label),caption:style(caption),formToContent:form.getBoundingClientRect().top-content.getBoundingClientRect().bottom,
      fieldToActions:actions.getBoundingClientRect().top-field.getBoundingClientRect().bottom,
      placeholder:{color:placeholder.color,opacity:placeholder.opacity,fontSize:placeholder.fontSize,lineHeight:placeholder.lineHeight}},
    field:{disabled:field.matches(':disabled'),focused:field===document.activeElement,focusVisible:field.matches(':focus-visible'),
      sameInstance:field===window.__starwardTextAnswerField,autoComplete:field.autocomplete},
    submit:{present:!!submit,disabled:submit?.matches(':disabled')??null},
    themeColors:{border:root.getPropertyValue('--color-accent-border').trim(),
      accent:root.getPropertyValue('--color-accent').trim()},
    private:{answer:field.value,placeholder:field.placeholder,label:caption?.textContent,
      bodyText:document.body.innerText}};
}"""


def require(condition):
    if not condition:
        raise ValueError('The explicit frozen text reference boundary did not hold')


def load_frame():
    data = FRAME_PATH.read_bytes()
    require(sha256(data).hexdigest() == FRAME_SHA)
    frame = ModuleType('text_answer_frame')
    frame.__file__ = str(FRAME_PATH)
    exec(compile(data, str(FRAME_PATH), 'exec'), frame.__dict__)
    return frame, data


def assert_pair(frame, active, completed):
    player, scene, _, _ = frame.fixtures(active)
    require(isinstance(completed, dict) and set(completed) == {'player', 'assignments', 'assignment'})
    history_player, history, history_list = (completed[key] for key in ('player', 'assignment', 'assignments'))
    require(re.fullmatch(r'hm_[a-f0-9]{12}', player['account']) and
            history_player['account'] == player['account'] and history_player['id'] == player['id'] and
            history_player['mustChangePassword'] is False and history['id'] == scene['id'] and
            history['player'] == scene['player'] and history['session'] == scene['session'] and
            history['startedAt'] == scene['startedAt'] and history['status'] == 'completed' and
            bool(history['completedAt']) and history['currentIndex'] == 0 and
            history['completedLevels'] == history['totalLevels'] == 1 and len(history['levels']) == 1)
    require(len(history_list['items']) == 1 and history_list['items'][0]['id'] == history['id'] and
            history_list['items'][0]['player'] == player['id'] and history_list['items'][0]['status'] == 'completed')
    level, history_level = scene['levels'][0], history['levels'][0]
    question = level['question']
    require(question['kind'] == 'text' and level['id'] == history_level['id'] and
            question == history_level['question'] and bool(history_level['completedAt']) and
            isinstance(history_level['lastAnswer'], str) and bool(history_level['lastAnswer'].strip()) and
            history_level['wrongCount'] == 0 and history_level['locked'] is False)
    require(history_player['totalXp'] - player['totalXp'] == history_level['xp'] and history_level['xp'] >= 0)
    def reject_secrets(value):
        if isinstance(value, dict):
            require(not set(map(str.lower, value)).intersection({'token', 'password', 'authorization', 'controltoken', 'answerkey'}))
            for item in value.values(): reject_secrets(item)
        elif isinstance(value, list):
            for item in value: reject_secrets(item)
    reject_secrets(completed)
    return {url for block in question['content'] for url in
            ([block['imageUrl']] if block.get('imageUrl') else []) + block.get('imageUrls', [])}


def sample(browser, frame, args, web, theme, fixtures, completed, draft, assets, font_bytes, sources, output, report, raw):
    boundary, bounded = frame.BOUNDARY, frame.bounded
    player, scene, listing = (fixtures[key] for key in ('player', 'assignment', 'assignments'))
    detail = '/api/questions/v1/assignments/' + scene['id']
    me, assignments = '/api/questions/v1/me', '/api/questions/v1/assignments'
    auxiliary = ('/api/questions/v1/notifications', '/api/questions/v1/rewards')
    file_token = '/api/files/token'
    endpoints = (frame.AUTH, file_token, me, assignments, detail, *auxiliary)
    cors = {'Access-Control-Allow-Origin': args.url, 'Access-Control-Allow-Headers': 'Authorization,Content-Type,Accept',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'}

    def route_request(route):
        request = route.request
        parsed = urlparse(request.url)
        origin = parsed.scheme + '://' + parsed.netloc
        if request.url in assets and request.method == 'GET' and request.resource_type == 'image':
            require(not request.headers.get('authorization'))
            asset = assets[request.url]
            mime = 'image/png' if asset['data'].startswith(b'\x89PNG\r\n\x1a\n') else 'image/jpeg'
            raw['imagesReplayed'].append({'url': request.url, 'sha256': asset['sha256']})
            route.fulfill(status=200, content_type=mime, body=asset['data'])
        elif parsed.path.startswith('/api/'):
            entry = {'url': request.url, 'method': request.method}
            raw['apis'].append(entry)
            response = None
            if origin == frame.API_ORIGIN and not parsed.query and parsed.path in endpoints:
                if request.method == 'OPTIONS':
                    route.fulfill(status=204, headers=cors, body='')
                    return
                if request.method == 'POST' and parsed.path == frame.AUTH:
                    require(request.post_data_json == {'identity': player['account'], 'password': frame.PASSWORD})
                    response = {'token': frame.TOKEN, 'record': {'id': player['id']}}
                elif request.headers.get('authorization') == frame.TOKEN:
                    if request.method == 'GET':
                        response = {me: player, assignments: listing, detail: scene,
                                    **{path: {'items': []} for path in auxiliary}}.get(parsed.path)
                    elif request.method == 'POST' and parsed.path == file_token:
                        response = {'token': 'text-answer-render-only-file-token'}
            if response is None:
                known_avatar = request.method == 'GET' and origin == frame.API_ORIGIN and parsed.path.startswith('/api/files/game_players/')
                raw['blocked' if known_avatar else 'unexpectedApis'].append(entry)
                route.fulfill(status=404, headers=cors, content_type='application/json', body='{"error":{"code":"REPLAY_NOT_CONFIGURED"}}')
            else:
                route.fulfill(status=200, headers=cors, content_type='application/json', body=json.dumps(response, ensure_ascii=False))
        elif request.method == 'GET' and origin == args.url and parsed.path == frame.FONT_ROUTE and not parsed.query:
            raw['fontRequestsReplayed'] += 1
            route.fulfill(status=200, content_type='font/ttf', body=font_bytes)
        elif boundary.source_request(request.method, request.url, request.resource_type, args.url, scene['id'], web):
            route.continue_()
        else:
            raw['blocked'].append({'url': request.url, 'kind': request.resource_type})
            route.abort()

    def guarded_route(route):
        try:
            route_request(route)
        except Exception as error:
            raw['routeFailures'].append({'type': type(error).__name__, 'message': str(error)})
            try: route.abort()
            except Exception: pass

    context = browser.new_context(viewport={'width': WIDTH, 'height': HEIGHT}, device_scale_factor=1,
        has_touch=True, is_mobile=True, color_scheme=theme, reduced_motion='reduce', locale='zh-CN',
        timezone_id='Asia/Shanghai', service_workers='block', accept_downloads=False)
    try:
        context.route('**/*', guarded_route)
        def inert_socket(_socket):
            raw['webSocketsBlocked'] += 1
        context.route_web_socket('**/*', inert_socket)
        page = context.new_page()
        page.set_default_timeout(15000)
        page.set_default_navigation_timeout(30000)
        page.on('pageerror', lambda error: raw['pageErrors'].append(str(error)))
        page.on('console', lambda msg: raw['consoleErrors'].append(msg.text) if msg.type == 'error' else None)
        page.goto(args.url + '/login?theme=' + theme, wait_until='networkidle')
        if not completed:
            for relative, original in sources.items():
                served = bounded(page, 'return (await import(arg+"?raw")).default;', '/' + relative)
                require(isinstance(served, str) and frame.sha(served.encode()) == frame.sha(original))
                raw['servedSourceChecks'] += 1
        checks = bounded(page, """const m=await import('/src/api/game.schema.ts');
          return [m.gamePlayerSchema.safeParse(arg.player).success,m.gameAssignmentSchema.safeParse(arg.assignment).success,
          m.gameAssignmentSummarySchema.array().safeParse(arg.assignments.items).success];""", fixtures)
        require(checks == [True, True, True])
        raw['schemaChecks'] += len(checks)
        page.get_by_label('登录账号', exact=True).fill(player['account'])
        page.get_by_label('密码', exact=True).fill(frame.PASSWORD)
        page.get_by_role('button', name='进入冒险', exact=True).click()
        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
        page.goto(args.url + '/play/' + quote(scene['id'], safe='') + '?theme=' + theme, wait_until='networkidle')
        field = page.get_by_role('textbox', name='答案', exact=True)
        field.wait_for(state='visible')
        require(page.locator('.quest-card').count() == 1 and page.locator('.quest-layout.quest-desktop').count() == 0)
        bgm = page.get_by_role('button', name='关闭背景音乐提示', exact=True)
        if bgm.count():
            bgm.click()
            bgm.wait_for(state='detached')
        page.add_style_tag(content='@font-face{font-family:StarwardQuestionFrameSerif;src:url("' + args.url + frame.FONT_ROUTE +
            '") format("truetype");font-weight:100 900;font-style:normal;font-display:block}:root{--font-display:StarwardQuestionFrameSerif,serif!important}')
        require(bounded(page, 'return (await document.fonts.load("37.6px StarwardQuestionFrameSerif")).length>0;'))
        images = page.locator('.quest-card .quest-content img')
        rendered_images = set()
        for i in range(images.count()):
            image = images.nth(i)
            image.scroll_into_view_if_needed()
            page.wait_for_function('(el)=>el.complete&&el.naturalWidth>0&&el.naturalHeight>0', arg=image.element_handle())
            rendered_images.add(image.evaluate('(el)=>el.currentSrc||el.src'))
        require(rendered_images == set(assets))
        field.evaluate("el=>{window.__starwardTextAnswerField=el;el.scrollIntoView({block:'center',inline:'nearest'});}")
        api_count = len(raw['apis'])
        placeholder = scene['levels'][0]['question'].get('placeholder') or '输入你的答案'

        def record(position, value, focus):
            bounded(page, 'await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));return true;')
            measured = page.evaluate(MEASURE)
            cond, geometry, field_state, submit = (measured[k] for k in ('conditions', 'geometry', 'field', 'submit'))
            line, caption = geometry['field'], geometry['caption']
            require(cond == {'width': WIDTH, 'height': HEIGHT, 'dpr': 1, 'theme': theme, 'scrollWidth': WIDTH,
                             'scale': 1, 'coarsePointer': True})
            require(measured['private']['answer'] == value and measured['private']['placeholder'] == placeholder and
                    measured['private']['label'] == '答案' and field_state == {'disabled': completed, 'focused': focus,
                    'focusVisible': focus, 'sameInstance': True, 'autoComplete': 'off'} and submit['present'] == (not completed))
            require(line['layoutWidth'] == geometry['form']['layoutWidth'] == 314 and line['layoutHeight'] == 58 and
                    line['fontSize'] == '18px' and line['lineHeight'] == 'normal' and
                    line['padding'] == '0px 2px' and line['borderBottom'] == '1px' and
                    line['borderTop'] == line['borderRight'] == line['borderLeft'] == line['radius'] == '0px' and
                    line['background'] == 'rgba(0, 0, 0, 0)' and line['opacity'] == ('0.5' if completed else '1') and
                    geometry['form']['marginTop'] == '24px' and geometry['actions']['marginTop'] == '18px' and
                    caption['width'] == caption['height'] == 1 and 0 <= line['y'] < line['bottom'] <= HEIGHT)
            border = measured['themeColors']['accent' if focus else 'border']
            rgb = ', '.join(str(int(border[i:i + 2], 16)) for i in (1, 3, 5))
            require(line['borderBottomColor'] == f'rgb({rgb})' and
                    line['transform'] == ('matrix(1, 0, 0, 1, 0, -1)' if focus else 'none'))
            if not completed:
                require(submit['disabled'] is False and geometry['submit']['bottom'] <= HEIGHT and
                        geometry['formToContent'] == 24 and geometry['fieldToActions'] == (19 if focus else 18))
            stem = theme + '-' + position
            png, measurement = output / (stem + '.png'), output / (stem + '.json')
            png_hash = boundary.private_write(png, page.screenshot(full_page=False, animations='disabled'))
            measurement_hash = boundary.private_write(measurement, measured)
            report['states'].append({'theme': theme, 'position': position, 'conditions': cond, 'geometry': geometry,
                'field': field_state, 'submit': submit, 'valueMatchesExpected': True, 'placeholderMatchesDto': True,
                'screenshot': {'file': str(png.relative_to(ROOT)), 'sha256': png_hash},
                'privateMeasurements': {'file': str(measurement.relative_to(ROOT)), 'sha256': measurement_hash}})

        if completed:
            record('completed-disabled', scene['levels'][0]['lastAnswer'], False)
        else:
            record('idle', '', False)
            field.tap()
            field.fill(draft)
            record('focused-draft', draft, True)
            field.blur()
            record('blurred-draft', draft, False)
        require(len(raw['apis']) == api_count)
    finally:
        context.close()


def capture(args):
    frame, frame_bytes = load_frame()
    boundary, sha = frame.BOUNDARY, frame.sha
    require(boundary.local_origin(args.url) == BASE_URL)
    own_bytes = Path(__file__).read_bytes()
    web = args.web_source.resolve()
    boundary.frozen_check(web)
    sources = {name: (web / name).read_bytes() for name in dict.fromkeys((*frame.SOURCES, *SOURCES))}
    inputs = {}
    for name in ('active', 'completed', 'draft'):
        path = frame.private_input(getattr(args, name + '_json'))
        data = path.read_bytes()
        require(re.fullmatch(r'[a-f0-9]{64}', getattr(args, name + '_sha')) and sha(data) == getattr(args, name + '_sha'))
        inputs[name] = (path, data, json.loads(data))
    active, completed, probe = (inputs[name][2] for name in ('active', 'completed', 'draft'))
    wanted_images = assert_pair(frame, active, completed)
    require(isinstance(probe, dict) and set(probe) == {'draft'} and
            probe['draft'] == '填空草稿验收 123' and probe['draft'] != completed['assignment']['levels'][0]['lastAnswer'])
    image_path = frame.private_input(args.images_manifest)
    image_bytes, registered = frame.image_assets(image_path, CONTENT_SHA)
    require(sha(image_bytes) == args.images_sha and wanted_images and wanted_images.issubset(registered))
    assets = {url: registered[url] for url in wanted_images}
    font = boundary.path_in(frame.NATIVE_FONT, ROOT / 'entry/src/main/resources', True)
    font_bytes = font.read_bytes()
    require(sha(font_bytes) == FONT_SHA)
    output = boundary.path_in(args.output_dir, frame.PRIVATE)
    manifest = boundary.path_in(args.manifest, frame.PUBLIC)
    require(not output.exists() and not manifest.exists())
    boundary.fresh_directory(output)
    report = {'status': 'incomplete', 'plan': PLAN, 'sourceCommit': frame.FROZEN, 'helperSha256': sha(own_bytes),
        'frameHelperSha256': FRAME_SHA, 'boundaryHelperSha256': frame.BOUNDARY_SHA,
        'sourceSha256': {name: sha(data) for name, data in sources.items()}, 'referenceContentSha256': CONTENT_SHA,
        'imagesManifestSha256': args.images_sha, 'fontSha256': FONT_SHA,
        'registeredImageSha256': sorted(asset['sha256'] for asset in assets.values()),
        'realDtoSha256': {name: sha(inputs[name][1]) for name in ('active', 'completed')},
        'backendRequestsContinued': 0, 'externalRequestsContinued': 0, 'answerSubmissionAttempted': False,
        'realCompletedDtoInput': True, 'answerOrPrivateDraftPublished': False,
        'visualReview': 'pending_root_original_review', 'states': [],
        'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    raw = {key: [] for key in ('apis', 'blocked', 'imagesReplayed', 'unexpectedApis', 'routeFailures', 'pageErrors', 'consoleErrors')}
    raw.update({key: 0 for key in ('fontRequestsReplayed', 'webSocketsBlocked', 'schemaChecks', 'servedSourceChecks')})
    failure = False
    try:
        package = frame.PRIVATE / 'python-playwright'
        if package.is_dir():
            sys.path.insert(0, str(package))
        from playwright.sync_api import sync_playwright
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True, timeout=30000, args=['--disable-background-networking'])
            try:
                for theme in THEMES:
                    sample(browser, frame, args, web, theme, active, False, probe['draft'], assets, font_bytes, sources, output, report, raw)
                    sample(browser, frame, args, web, theme, completed, True, probe['draft'], assets, font_bytes, sources, output, report, raw)
            finally:
                browser.close()
        boundary.frozen_check(web)
        require(Path(__file__).read_bytes() == own_bytes and FRAME_PATH.read_bytes() == frame_bytes and
                sha((ROOT / 'scripts/capture-web-ui-sample.py').read_bytes()) == frame.BOUNDARY_SHA and
                all(path.read_bytes() == data for path, data, _ in inputs.values()) and font.read_bytes() == font_bytes and
                image_path.read_bytes() == image_bytes and all(asset['source'].read_bytes() == asset['data'] for asset in assets.values()) and
                all((web / name).read_bytes() == data for name, data in sources.items()))
        require(not any(raw[key] for key in ('unexpectedApis', 'routeFailures', 'pageErrors')) and
                raw['schemaChecks'] == 12 and raw['servedSourceChecks'] == len(sources) * 2 and
                raw['fontRequestsReplayed'] >= 4 and len(report['states']) == len(THEMES) * len(STATES))
        report['status'] = 'captured_web_text_answer_reference'
    except Exception as error:
        raw['failure'] = {'type': type(error).__name__, 'message': str(error)}
        report['failure'] = 'Guarded text reference incomplete. Private evidence retained.'
        failure = True
    finally:
        report['realCompletedDtoReplayed'] = sum(state['position'] == 'completed-disabled' for state in report['states']) == len(THEMES)
        raw_path = output / 'browser-private.json'
        report['privateBrowserEvidence'] = {'file': str(raw_path.relative_to(ROOT)), 'sha256': boundary.private_write(raw_path, raw)}
        report['counts'] = {k: len(v) if isinstance(v, list) else v for k, v in raw.items() if k != 'failure'}
        encoded = (json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
        private_literals = frame.private_literals(active) | frame.private_literals(completed) | set(assets) | {probe['draft']}
        require(not re.search(rb'https?://', encoded) and not any(
            item.encode() in encoded if len(item) >= 5 else json.dumps(item, ensure_ascii=False).encode() in encoded
            for item in private_literals))
        boundary.path_in(manifest, frame.PUBLIC)
        manifest.parent.mkdir(parents=True, exist_ok=True)
        with os.fdopen(os.open(manifest, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644), 'wb') as stream:
            stream.write(encoded)
    print(json.dumps({'status': report['status'], 'states': len(report['states']), 'manifestSha256': sha(encoded)}), flush=True)
    return 1 if failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action')
    sub.add_parser('plan')
    run = sub.add_parser('run')
    run.add_argument('--url', default=BASE_URL)
    run.add_argument('--web-source', type=Path, default=ROOT.parent / 'questions-web')
    for name in ('active', 'completed', 'draft'):
        run.add_argument('--' + name + '-json', required=True, type=Path)
        run.add_argument('--' + name + '-sha', required=True)
    for name in ('images-manifest', 'output-dir', 'manifest'):
        run.add_argument('--' + name, required=True, type=Path)
    run.add_argument('--images-sha', required=True)
    args = parser.parse_args()
    if args.action is None:
        parser.print_help()
        return 0
    if args.action == 'plan':
        print(json.dumps(PLAN, ensure_ascii=False, indent=2))
        return 0
    try:
        return capture(args)
    except Exception:
        print(json.dumps({'status': 'not_captured_or_report_guarded',
            'error': 'Explicit frozen source, real DTO pair, image, font, draft or output prerequisite failed. Values omitted.'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

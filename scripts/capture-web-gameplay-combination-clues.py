#!/usr/bin/env python3
"""Replay real, private isolated combination-clue DTOs in the frozen mobile Web app."""
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
BASE = 'http://127.0.0.1:5178'
GAME = '/api/questions/v1'
SOURCES = ('src/index.css', 'src/api/game.client.ts', 'src/api/game.schema.ts', 'src/config/ui-copy.ts',
           'src/components/ui/Dialog.tsx', 'src/features/game/GamePlayPage.tsx', 'src/features/game/GamePlayScene.tsx',
           'src/features/game/clue-presentation.ts', 'src/features/game/session-presentation.ts',
           'src/features/game/useGamePresentation.ts', 'src/features/clues/MultiClueLauncher.tsx',
           'src/features/clues/MultiQuestClueDialog.tsx', 'src/features/completion/CompletionFeedbackDialog.tsx',
           'src/features/content/RichContent.tsx', 'src/shared/gestures/useDraggableFloatingControl.ts',
           'src/styles/components/multi-clue-launcher.css', 'src/styles/features/clues.css',
           'src/styles/effects/overlay-lighting.css')

MEASURE = r"""() => {
  const dialog=document.querySelector('.multi-clue-dialog');
  const launcher=document.querySelector('.multi-clue-launcher');
  const nodes={launcher,signal:launcher?.querySelector('.multi-clue-launcher__signal'),
    launcherCopy:launcher?.querySelector('.multi-clue-launcher__copy'),
    launcherTitle:launcher?.querySelector('strong'),completion:document.querySelector('.completion-dialog'),
    dialog,scroll:dialog?.querySelector('.multi-clue-dialog-scroll'),
    eyebrow:dialog?.querySelector('.multi-clue-dialog-scroll > .eyebrow'),
    title:dialog?.querySelector('.multi-clue-dialog-scroll > h2'),
    body:dialog?.querySelector('.multi-clue-content'), footer:dialog?.querySelector('footer'),
    description:dialog?.querySelector('footer p'), action:dialog?.querySelector('footer button')};
  function inspect(el) {
    if(!el) return null;
    const b=el.getBoundingClientRect(), s=getComputedStyle(el);
    return {x:b.x,y:b.y,width:b.width,height:b.height,visible:el.checkVisibility(),fontSize:s.fontSize,
      lineHeight:s.lineHeight,padding:s.padding,gap:s.gap,color:s.color,background:s.backgroundColor,
      radius:s.borderRadius,overflow:s.overflowY,clientHeight:el.clientHeight,scrollHeight:el.scrollHeight};
  }
  const {innerWidth:width,innerHeight:height,devicePixelRatio:dpr}=window;
  return {viewport:{width,height,dpr,coarse:matchMedia('(pointer:coarse)').matches,
    theme:document.documentElement.dataset.theme,visualScale:visualViewport?.scale||1,scrollY},
    geometry:Object.fromEntries(Object.entries(nodes).map(([key,el])=>[key,inspect(el)])),
    launcherSide:launcher?.dataset.horizontal??null, highlights:nodes.body?.querySelectorAll('mark').length??0,
    privateText:Object.fromEntries(Object.entries(nodes).filter(([,el])=>el).map(([key,el])=>[key,el.innerText]))};
}"""


def sha(raw):
    return sha256(raw).hexdigest()


def require(condition, reason='scope guard'):
    if not condition:
        raise ValueError(reason)


def load_frame():
    raw = FRAME.read_bytes()
    require(sha(raw) == FRAME_SHA, 'frame helper changed')
    frame = ModuleType('combination_clue_web_frame')
    frame.__file__ = str(FRAME)
    exec(compile(raw, str(FRAME), 'exec'), frame.__dict__)
    return frame


def combinations(scene):
    return sorted((clue for clue in scene['clues'] if clue.get('source', 'session') == 'session' and
                   scene['totalLevels'] > 1 and clue['trigger'] == 'session_completed' and
                   not clue['sessionLevel'] and clue['kind'] == 'text'),
                  key=lambda clue: (clue['position'], clue.get('definitionId') or clue['id'], clue['id']))


def read(frame, path, expected):
    path = frame.private_input(path)
    raw = path.read_bytes()
    require(sha(raw) == expected, 'input hash')
    require(not re.search(rb'"(?:token|password|authorization|controltoken|answerkey)"\s*:', raw, re.I), 'private credential field')
    return path, raw, json.loads(raw)


def snapshot(value):
    require(set(value) == {'player', 'assignments', 'assignment'}, 'snapshot shape')
    player, scene = value['player'], value['assignment']
    listing = value['assignments']['items']
    require(re.fullmatch(r'hm_[a-f0-9]{12}', player['account']) and player['mustChangePassword'] is False and
        all(re.fullmatch(r'[a-z0-9]{15}', item) for item in (player['id'], scene['id'], scene['session'])) and
        scene['player'] == player['id'] and scene['totalLevels'] == len(scene['levels']) == 2 and
        scene['completedLevels'] == sum(bool(level['completedAt']) for level in scene['levels']) and
        all(row['player'] == player['id'] for row in listing) and
        sum(row['id'] == scene['id'] and row['status'] == scene['status'] for row in listing) == 1,
        'isolated player, assignment and listing consistency')
    return player, scene


def validate(phase_data, answer_request, answer_response, negative):
    require(set(phase_data) == {'before', 'started', 'firstCompleted', 'completed'}, 'fixture phases')
    player, final = snapshot(phase_data['completed'])
    for phase, status, done in (('before', 'assigned', 0), ('started', 'active', 0),
                                ('firstCompleted', 'active', 1), ('completed', 'completed', 2)):
        p, a = snapshot(phase_data[phase])
        require((p['id'], a['id'], a['session'], a['status'], a['completedLevels']) ==
                (player['id'], final['id'], final['session'], status, done) and
                [level['id'] for level in a['levels']] == [level['id'] for level in final['levels']] and
                bool(a['startedAt']) == (phase != 'before') and not a.get('transitionEffects'), 'exact phase facts')
        if phase != 'completed':
            require(not combinations(a), 'premature combination in DTO')
    first = phase_data['firstCompleted']['assignment']
    require(first['currentIndex'] == 1 and first['levels'][1]['question']['kind'] == 'text' and
        not first['levels'][1]['completedAt'], 'reviewed editable last question')
    clues = combinations(final)
    require(len(clues) == 2 and clues[0]['content']['title'] and clues[0]['content']['buttonText'] and
        not clues[1]['content']['title'] and not clues[1]['content']['buttonText'] and
        all('[[' in clue['content']['text'] and '\n' in clue['content']['text'] and
            not any(token in clue['content']['text'] for token in ('{{', '<<', '((')) for clue in clues), 'text scope')
    if answer_response is not None:
        require(set(answer_request) == {'sessionLevelId', 'answer', 'requestId'} and
            answer_request['sessionLevelId'] == first['levels'][1]['id'] and
            isinstance(answer_request['answer'], str) and bool(answer_request['answer'].strip()) and
            isinstance(answer_request['requestId'], str) and bool(answer_request['requestId']), 'real answer request')
        settled = answer_response['assignment']
        require(answer_response['result'] == 'correct' and settled['status'] == 'completed' and
            (settled['id'], settled['player'], settled['session'], settled['completedLevels']) ==
            (final['id'], player['id'], final['session'], 2) and settled['levels'] == final['levels'] and
            combinations(settled) == clues and answer_response['player']['id'] == player['id'] and
            {clue['id'] for clue in clues} <= {effect['clueId'] for effect in answer_response['effects']
                                             if effect['type'] == 'clue'}, 'real final answer settlement')
    if negative is not None:
        _, without = snapshot(negative)
        require(without['status'] == 'completed' and without['id'] != final['id'] and not combinations(without),
                'completed without combination negative scope')
    return clues


def touch_drag(page, launcher):
    box = launcher.bounding_box()
    require(box is not None and box['x'] > 100, 'right launcher before drag')
    x, y = box['x'] + box['width'] / 2, box['y'] + box['height'] / 2
    cdp = page.context.new_cdp_session(page)
    try:
        cdp.send('Input.dispatchTouchEvent', {'type': 'touchStart', 'touchPoints': [{'x': x, 'y': y}]})
        for step in range(1, 13):
            cdp.send('Input.dispatchTouchEvent', {'type': 'touchMove',
                'touchPoints': [{'x': x - step * (x - 53) / 12, 'y': y - step * 4}]})
        cdp.send('Input.dispatchTouchEvent', {'type': 'touchEnd', 'touchPoints': []})
    finally:
        cdp.detach()
    page.wait_for_function("()=>document.querySelector('.multi-clue-launcher')?.dataset.horizontal==='left'")


def render(browser, frame, args, web, sources, output, report, events, theme, initial, completed=None,
           answer_request=None, answer_response=None, expected=None):
    p, a = snapshot(initial)
    detail = f'{GAME}/assignments/{a["id"]}'
    answer_route = detail + '/answers'
    tag = {'theme': theme, 'case': 'combination' if expected else 'no_combination'}
    cors = {'Access-Control-Allow-Origin': BASE, 'Access-Control-Allow-Headers': 'Authorization,Content-Type,Accept',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'}
    active = initial
    local_answers = 0

    def response(route, value):
        route.fulfill(status=200, headers=cors, content_type='application/json', body=json.dumps(value, ensure_ascii=False))

    def route_request(route):
        nonlocal active, local_answers
        req = route.request
        parsed = urlparse(req.url)
        origin = parsed.scheme + '://' + parsed.netloc
        reads = {f'{GAME}/me': active['player'], f'{GAME}/assignments': active['assignments'],
                 detail: active['assignment'], f'{GAME}/rewards': {'items': []}, f'{GAME}/notifications': {'items': []}}
        allowed = {*reads, frame.AUTH, '/api/files/token'}
        if answer_response is not None:
            allowed.add(answer_route)
        if parsed.path.startswith('/api/'):
            events['apiIntercepted'].append({**tag, 'method': req.method, 'url': req.url})
            if origin == frame.API_ORIGIN and not parsed.query and parsed.path in allowed:
                if req.method == 'OPTIONS':
                    route.fulfill(status=204, headers=cors, body='')
                    return
                if req.method == 'POST' and parsed.path == frame.AUTH:
                    require(req.post_data_json == {'identity': p['account'], 'password': frame.PASSWORD}, 'browser-local sign in')
                    response(route, {'token': frame.TOKEN, 'record': {'id': p['id']}})
                    return
                if req.headers.get('authorization') == frame.TOKEN:
                    if req.method == 'GET' and parsed.path in reads:
                        response(route, reads[parsed.path])
                        return
                    if req.method == 'POST' and parsed.path == '/api/files/token':
                        response(route, {'token': 'combination-replay-only-file-token'})
                        return
                    if req.method == 'POST' and parsed.path == answer_route and answer_response is not None:
                        incoming = req.post_data_json
                        require(local_answers == 0 and set(incoming) == set(answer_request) and
                            all(incoming[key] == answer_request[key] for key in ('sessionLevelId', 'answer')) and
                            isinstance(incoming['requestId'], str) and incoming['requestId'], 'final answer replay boundary')
                        local_answers += 1
                        active = completed
                        response(route, answer_response)
                        return
            if origin != frame.API_ORIGIN or req.method != 'GET' or not parsed.path.startswith('/api/files/game_players/'):
                events['unexpectedApis'].append({**tag, 'method': req.method, 'url': req.url})
            route.abort()
        elif frame.BOUNDARY.source_request(req.method, req.url, req.resource_type, BASE, a['id'], web):
            route.continue_()
        else:
            events['blocked'].append({**tag, 'kind': req.resource_type, 'url': req.url})
            route.abort()

    def guarded(route):
        try:
            route_request(route)
        except Exception as error:
            events['routeFailures'].append({**tag, 'type': type(error).__name__, 'detail': str(error)})
            route.abort()

    def no_socket(_socket):
        events['webSocketsBlocked'] += 1

    context = browser.new_context(viewport={'width': args.width, 'height': args.height}, device_scale_factor=1,
        is_mobile=True, has_touch=True, color_scheme=theme, reduced_motion='reduce', locale='zh-CN',
        timezone_id='Asia/Shanghai', service_workers='block', accept_downloads=False)
    try:
        context.route('**/*', guarded)
        context.route_web_socket('**/*', no_socket)
        page = context.new_page()
        page.set_default_timeout(15000)
        page.on('pageerror', lambda error: events['pageErrors'].append({**tag, 'detail': str(error)}))
        page.goto(f'{BASE}/login?theme={theme}', wait_until='networkidle')
        for name, expected_bytes in sources.items():
            served = frame.bounded(page, 'return (await import(arg+"?raw")).default;', '/' + name)
            require(isinstance(served, str) and sha(served.encode()) == sha(expected_bytes), 'served frozen source')
            events['servedSourceChecks'] += 1
        to_validate = {'initial': initial, 'completed': completed, 'answer': answer_response}
        schema_checks = frame.bounded(page, """const m=await import('/src/api/game.schema.ts');
          const check=x=>[m.gamePlayerSchema.safeParse(x.player).success,m.gameAssignmentSchema.safeParse(x.assignment).success,
            m.gameAssignmentSummarySchema.array().safeParse(x.assignments.items).success];
          return [...check(arg.initial),...(arg.completed?check(arg.completed):[]),
            ...(arg.answer?[m.gameAnswerSchema.safeParse(arg.answer).success]:[])];""", to_validate)
        require(schema_checks and all(schema_checks), 'frozen schema validation')
        events['schemaChecks'] += len(schema_checks)
        page.get_by_label('登录账号', exact=True).fill(p['account'])
        page.get_by_label('密码', exact=True).fill(frame.PASSWORD)
        page.get_by_role('button', name='进入冒险', exact=True).tap()
        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
        route_url = f'{BASE}/play/{a["id"]}?theme={theme}'
        page.goto(route_url, wait_until='networkidle')
        card = page.locator('.quest-card')
        completion = page.locator('.completion-dialog')
        dialog = page.locator('.multi-clue-dialog')
        launcher = page.locator('.multi-clue-launcher')
        card.wait_for()
        require(page.locator('.quest-layout.quest-desktop').count() == 0 and card.count() == 1, 'mobile question route')
        prompt = page.get_by_role('button', name='知道了', exact=True)
        if prompt.count() == 1 and prompt.is_visible():
            prompt.tap()
            prompt.wait_for(state='detached')

        def settled():
            frame.bounded(page, '''await document.fonts.ready;
              await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
              const selectors='.quest-card,.multi-clue-dialog,.completion-dialog,.multi-clue-launcher,.rank-up-dialog';
              const animations=new Set([...document.querySelectorAll(selectors)].flatMap(node=>node.getAnimations({subtree:true})));
              await Promise.allSettled([...animations].filter(a=>Number.isFinite(a.effect?.getComputedTiming().endTime)).map(a=>a.finished));
              await new Promise(r=>requestAnimationFrame(r)); return true;''')

        def shot(name):
            settled()
            found = page.evaluate(MEASURE)
            vp = found['viewport']
            require((vp['width'], vp['height'], vp['dpr'], vp['coarse'], vp['theme'], vp['visualScale']) ==
                    (args.width, args.height, 1, True, theme, 1), 'mobile viewport')
            files = {}
            for key, ext, value in (('screenshot', '.png', page.screenshot(animations='disabled')),
                ('privateMeasurements', '.json', found), ('privateDom', '.html', page.content().encode())):
                path = output / f'{tag["case"]}-{theme}-{name}{ext}'
                files[key] = {'file': str(path.relative_to(ROOT)), 'sha256': frame.BOUNDARY.private_write(path, value)}
            report['states'].append({**tag, 'state': name, 'viewport': vp, 'geometry': found['geometry'],
                'launcherSide': found['launcherSide'], 'highlights': found['highlights'], **files})

        def show(clue):
            title = clue['content']['title'] or '隐藏的本场线索'
            description = clue['content'].get('description') or '该本场线索会保留在当前会话中。'
            action = clue['content']['buttonText'] or '我知道了'
            dialog.wait_for()
            dialog.locator('.multi-clue-dialog-scroll > h2').filter(has_text=title).wait_for()
            require(dialog.locator('.multi-clue-dialog-scroll > h2').text_content() == title and
                page.get_by_role('dialog', name=title, exact=True).count() == 1 and
                dialog.locator('.multi-clue-dialog-scroll > .eyebrow').text_content() == 'Combined revelation' and
                dialog.locator('footer p').text_content() == description and dialog.locator('mark').count() >= 1 and
                dialog.locator('.multi-clue-content br').count() >= 1 and not launcher.count(), 'real combination dialog')
            return dialog.get_by_role('button', name=action, exact=True)

        if not expected:
            require(a['status'] == 'completed' and not any(locator.count() for locator in (dialog, completion, launcher)),
                    'completed case without a combination has no launcher')
            shot('completed-without-combination')
        else:
            if answer_response is not None:
                require(not any(locator.count() for locator in (dialog, completion, launcher)), 'absence before completion')
                shot('before-completion')
                answer = card.locator('input')
                require(answer.count() == 1 and answer.is_enabled(), 'editable final question')
                answer.fill(answer_request['answer'])
                card.get_by_role('button', name='提交答案', exact=True).tap()
                completion.wait_for()
                require(completion.locator('#completion-title').text_content() == '组合谜题全部破解' and
                    not dialog.count() and not launcher.count(), 'completion precedes combinations')
                shot('completion-acknowledgement')
                completion.get_by_role('button', name='查看组合结果', exact=True).tap()
                completion.wait_for(state='detached')
                acknowledge = show(expected[0])
                shot('first-combination-auto')
                page.touchscreen.tap(8, 8)
                require(dialog.is_visible(), 'outside touch retains the modal')
                acknowledge.tap()
                acknowledge = show(expected[-1])
                shot('last-combination-auto')
                acknowledge.tap()
                dialog.wait_for(state='detached')
                rank = page.locator('.rank-up-dialog')
                if answer_response['player']['level']['order'] > p['level']['order']:
                    rank.get_by_role('button', name='继续冒险', exact=True).tap()
                    rank.wait_for(state='detached')
                launcher.wait_for()
                shot('launcher-after-queue')
                page.reload(wait_until='networkidle')
            launcher.wait_for()
            require(not dialog.count() and not completion.count() and launcher.get_attribute('aria-label') == '查看本场线索',
                    'completed GET requires a manual open')
            shot('launcher-reentry')
            launcher.tap()
            show(expected[-1])
            shot('last-combination-reopened')
            page.keyboard.press('Escape')
            dialog.wait_for(state='detached')
            launcher.wait_for()
            touch_drag(page, launcher)
            require(not dialog.count(), 'drag does not open a clue')
            shot('launcher-drag-left')
            page.reload(wait_until='networkidle')
            launcher.wait_for()
            require(launcher.get_attribute('data-horizontal') == 'left' and not dialog.count(), 'drag position persists on GET')
            shot('launcher-left-reentry')
        require(local_answers == int(answer_response is not None), 'exactly one local answer in transition scenario')
        report['checks'].append({**tag, 'localFinalAnswersReplayed': local_answers})
    finally:
        context.close()


def capture(args):
    frame = load_frame()
    boundary = frame.BOUNDARY
    web = args.web_source.resolve()
    boundary.frozen_check(web)
    sources = {name: (web / name).read_bytes() for name in SOURCES}
    renderer = Path(__file__).read_bytes()
    inputs = {'phase-dtos': read(frame, args.dtos, args.dtos_sha)}
    for name, path, digest in (('answer-request', args.answer_request, args.answer_request_sha),
                               ('answer-response', args.answer_response, args.answer_response_sha),
                               ('negative-dto', args.negative_dto, args.negative_dto_sha)):
        require((path is None) == (digest is None), 'paired input and hash')
        if path is not None:
            inputs[name] = read(frame, path, digest)
    require(('answer-request' in inputs) == ('answer-response' in inputs), 'paired answer request and response')
    data = inputs['phase-dtos'][2]
    request = inputs.get('answer-request', (None, None, None))[2]
    answer = inputs.get('answer-response', (None, None, None))[2]
    negative = inputs.get('negative-dto', (None, None, None))[2]
    expected = validate(data, request, answer, negative)
    output = boundary.path_in(args.output_dir, frame.PRIVATE)
    manifest = boundary.path_in(args.manifest, frame.PUBLIC / 'ui-gameplay-combination-clues-20261112')
    require(not output.exists() and not manifest.exists(), 'fresh output paths')
    boundary.fresh_directory(output)
    for label, (_, raw, _) in inputs.items():
        boundary.private_write(output / f'input-{label}.json', raw)
    report = {'status': 'incomplete', 'sourceCommit': frame.FROZEN, 'rendererSha256': sha(renderer),
        'frameHelperSha256': FRAME_SHA, 'boundaryHelperSha256': frame.BOUNDARY_SHA,
        'inputOrigin': args.input_origin, 'inputSha256': {key: sha(raw) for key, (_, raw, _) in inputs.items()},
        'sourceSha256': {name: sha(raw) for name, raw in sources.items()}, 'frozenCssOriginals': True,
        'syntheticAuthentication': True, 'businessRequestsForwarded': 0, 'externalRequestsForwarded': 0,
        'realBusinessAcceptance': False, 'nativeAcceptance': False, 'visualReview': 'pending_original_review',
        'states': [], 'checks': []}
    events = {key: [] for key in ('apiIntercepted', 'blocked', 'unexpectedApis', 'routeFailures', 'pageErrors')}
    events.update({key: 0 for key in ('webSocketsBlocked', 'servedSourceChecks', 'schemaChecks')})
    failure = False
    try:
        package = frame.PRIVATE / 'python-playwright'
        if package.is_dir():
            sys.path.insert(0, str(package))
        from playwright.sync_api import sync_playwright
        with sync_playwright() as play:
            browser = play.chromium.launch(headless=True, timeout=30000, args=['--disable-background-networking'])
            try:
                for theme in ('light', 'dark'):
                    if answer is not None:
                        render(browser, frame, args, web, sources, output, report, events, theme, data['firstCompleted'],
                               completed=data['completed'], answer_request=request, answer_response=answer, expected=expected)
                    else:
                        render(browser, frame, args, web, sources, output, report, events, theme, data['completed'], expected=expected)
                    if negative is not None:
                        render(browser, frame, args, web, sources, output, report, events, theme, negative)
            finally:
                browser.close()
        boundary.frozen_check(web)
        require(Path(__file__).read_bytes() == renderer and sha(FRAME.read_bytes()) == FRAME_SHA and
            sha((ROOT / 'scripts/capture-web-ui-sample.py').read_bytes()) == frame.BOUNDARY_SHA and
            all(path.read_bytes() == raw for path, raw, _ in inputs.values()) and
            all((web / name).read_bytes() == raw for name, raw in sources.items()), 'input provenance')
        runs = 4 if negative is not None else 2
        expected_states = (18 if answer is not None else 8) + (2 if negative is not None else 0)
        expected_schemas = (14 if answer is not None else 6) + (6 if negative is not None else 0)
        require(not any(events[key] for key in ('unexpectedApis', 'routeFailures', 'pageErrors')) and
            events['servedSourceChecks'] == len(sources) * runs and events['schemaChecks'] == expected_schemas and
            len(report['checks']) == runs and len(report['states']) == expected_states, 'complete state evidence')
        report['status'] = 'captured_web_gameplay_combination_clues_reference'
    except Exception as error:
        failure = True
        events['failure'] = {'type': type(error).__name__, 'detail': str(error)}
        report['failure'] = 'Guarded capture incomplete; raw diagnostics retained privately.'
    finally:
        raw_path = output / 'browser-private.json'
        report['privateBrowserEvidence'] = {'file': str(raw_path.relative_to(ROOT)),
            'sha256': boundary.private_write(raw_path, events)}
        report['counts'] = {key: len(value) if isinstance(value, list) else value
            for key, value in events.items() if key != 'failure'}
        encoded = (json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
        literals = {item for dto in data.values() for item in frame.private_literals(dto)}
        if negative is not None:
            literals.update(frame.private_literals(negative))
        if request is not None:
            literals.update((request['answer'], request['requestId'], request['sessionLevelId']))
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
    for name in ('dtos', 'output-dir', 'manifest'):
        run.add_argument('--' + name, type=Path, required=True)
    for name in ('answer-request', 'answer-response', 'negative-dto'):
        run.add_argument('--' + name, type=Path)
        run.add_argument('--' + name + '-sha')
    run.add_argument('--dtos-sha', required=True)
    run.add_argument('--input-origin', choices=('isolated_reference_actor', 'isolated_native_actor'), required=True)
    run.add_argument('--width', type=int, required=True)
    run.add_argument('--height', type=int, required=True)
    args = parser.parse_args()
    if args.action is None:
        parser.print_help()
        return 0
    try:
        require(320 <= args.width <= 620 and 500 <= args.height <= 1200 and
            all(value is None or re.fullmatch(r'[a-f0-9]{64}', value) for value in
                (args.dtos_sha, args.answer_request_sha, args.answer_response_sha, args.negative_dto_sha)), 'viewport/hash arguments')
        return capture(args)
    except Exception:
        print(json.dumps({'status': 'not_captured_or_report_guarded',
            'error': 'Explicit frozen source, private input, or output prerequisite failed. Values omitted.'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

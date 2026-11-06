#!/usr/bin/env python3
"""Render the frozen Web feedback states with three reviewed Native snapshots.

Help is inert. Run permits local frozen source and explicitly registered image
bytes only. All player API responses, transport drops and answer transitions
are browser-local replay. No real login, start or answer is performed.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys
from types import ModuleType
from urllib.parse import quote, urlparse


ROOT = Path(__file__).resolve().parents[1]
FRAME = ROOT / 'scripts/capture-web-question-frame.py'
FRAME_SHA = '12f9b6563ebb95cc141043e966c009375873de0b8de764df9a0308ecf4ae520f'
CONTENT_SHA = '1ad7a59cc1f13e6dd7ec5550c8f5ab4a5906b90f9a9b56ac948143a4995e8745'
FONT_SHA = '050080d9255a86808f2945bffac582b31ef32bc36411ce29563b4961670c66f9'
THEMES = ('light', 'dark')
NAMES = ('active', 'incorrect', 'completed')
SOURCES = ('src/api/game.client.ts', 'src/api/retry.ts',
           'src/features/game/components/GameRequestFeedback.tsx',
           'src/features/quest/AnswerFeedback.tsx', 'src/styles/features/game-request-feedback.css')
MEASURE = r"""() => {
  const selectors = {
    hint: '.quest-card .quest-hint', hintSummary: '.quest-card .quest-hint summary',
    hintBody: '.quest-card .quest-hint > div', form: '.quest-card .answer-form',
    field: '.quest-card .answer-form input', actions: '.quest-card .answer-actions',
    submit: '.quest-card button[type=submit]', penalty: '.quest-card .penalty-state',
    feedback: '.quest-card .feedback', feedbackEmblem: '.quest-card .feedback__emblem',
    feedbackContent: '.quest-card .feedback__content',
    feedbackTitle: '.quest-card .feedback__content strong',
    feedbackBody: '.quest-card .feedback__content > span', lifeline: '.quest-card .feedback__lifeline',
    overlay: '.game-retry-overlay', dialog: '.game-retry-dialog',
    signal: '.game-retry-signal', detail: '.game-retry-detail',
    retryActions: '.game-retry-actions', retry: '.game-retry-actions button:nth-child(1)',
    stay: '.game-retry-actions button:nth-child(2)',
  };
  const nodes = {};
  const privateText = {};
  for (const [key, selector] of Object.entries(selectors)) {
    const el = document.querySelector(selector);
    if (!el) continue;
    const {x,y,width,height} = el.getBoundingClientRect();
    const s = getComputedStyle(el);
    nodes[key] = {x,y,width,height,visible:el.checkVisibility(), fontSize:s.fontSize,
      lineHeight:s.lineHeight,padding:s.padding,marginTop:s.marginTop,border:s.border,
      borderRadius:s.borderRadius,color:s.color,background:s.backgroundColor,opacity:s.opacity,
      disabled:el.matches(':disabled'),open:el.hasAttribute('open'),tone:el.dataset.tone??null};
    privateText[key] = el.textContent;
  }
  return {nodes, privateText, fieldValue:document.querySelector(selectors.field)?.value ?? null,
    width:innerWidth,height:innerHeight,dpr:devicePixelRatio,
    theme:document.documentElement.dataset.theme,coarse:matchMedia('(pointer:coarse)').matches};
}"""


def sha(value):
    return hashlib.sha256(value).hexdigest()


def require(value):
    if not value:
        raise ValueError('The explicit frozen feedback reference boundary did not hold')


def load_frame():
    data = FRAME.read_bytes()
    require(sha(data) == FRAME_SHA)
    module = ModuleType('gameplay_feedback_web_frame')
    module.__file__ = str(FRAME)
    exec(compile(data, str(FRAME), 'exec'), module.__dict__)
    return module


def matching_snapshots(frame, snapshots):
    player, scene, _, _ = frame.fixtures(snapshots['active'])
    base = scene['levels'][0]
    question = base['question']
    require(re.fullmatch(r'hm_[a-f0-9]{12}', player['account']) and question['kind'] == 'text' and
            any(block.get('hint') for block in question['content']))
    for name in NAMES:
        dto = snapshots[name]
        require(set(dto) == {'player', 'assignment', 'assignments'})
        p, a, listing = (dto[key] for key in ('player', 'assignment', 'assignments'))
        require(p['id'] == player['id'] and p['account'] == player['account'] and
                p['mustChangePassword'] is False and p['level']['order'] == player['level']['order'] and
                a['id'] == scene['id'] and a['player'] == player['id'] and a['session'] == scene['session'] and
                a['startedAt'] == scene['startedAt'] and a['presentation'] == scene['presentation'] and
                a['totalLevels'] == 1 and len(a['levels']) == len(listing['items']) == 1 and
                listing['items'][0]['id'] == a['id'] and listing['items'][0]['player'] == player['id'] and
                listing['items'][0]['status'] == a['status'])
        level = a['levels'][0]
        require(level['question'] == question and level['id'] == base['id'] and level['locked'] is False)
        require(not re.search(r'"(?:token|password|authorization|controltoken|answerkey)"\s*:',
                              json.dumps(dto), re.IGNORECASE))
        if name == 'incorrect':
            require(a['status'] == 'active' and a['completedLevels'] == 0 and not level['completedAt'] and
                    level['wrongCount'] == base['wrongCount'] and not level['cooldownUntil'] and
                    p['totalXp'] == player['totalXp'] and level['lastAnswer'].strip())
        elif name == 'completed':
            require(a['status'] == 'completed' and a['completedLevels'] == 1 and level['completedAt'] and
                    a['presentation'].get('completionStyle') != 'finale' and level['lastAnswer'].strip() and
                    p['totalXp'] - player['totalXp'] == level['xp'] and level['xp'] > 0)
    wrong = snapshots['incorrect']['assignment']['levels'][0]['lastAnswer']
    correct = snapshots['completed']['assignment']['levels'][0]['lastAnswer']
    require(wrong != correct)
    wanted = {url for block in question['content']
              for url in ([block['imageUrl']] if block.get('imageUrl') else []) + block.get('imageUrls', [])}
    return wrong, correct, wanted


def render(browser, frame, args, web, sources, snapshots, responses, inputs, assets, font, theme, out, report, private):
    boundary = frame.BOUNDARY
    wrong, correct = inputs
    original = '  ' + correct + '  '  # Same edge-whitespace probe as Native.
    active = snapshots['active']
    actor = active['player']
    assignment = active['assignment']
    level = assignment['levels'][0]['id']
    detail = '/api/questions/v1/assignments/' + assignment['id']
    answer = detail + '/answers'
    replies = ('/api/questions/v1/me', '/api/questions/v1/assignments', detail,
               '/api/questions/v1/rewards', '/api/questions/v1/notifications')
    cors = {'Access-Control-Allow-Origin': args.url, 'Access-Control-Allow-Headers': 'Authorization,Content-Type,Accept',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'}
    mode, current, held, bodies = 'idle', active, [], []

    def respond(route, value, status=200):
        route.fulfill(status=status, headers=cors, content_type='application/json',
                      body=json.dumps(value, ensure_ascii=False))

    def route_request(route):
        nonlocal current
        req = route.request
        parsed = urlparse(req.url)
        origin = parsed.scheme + '://' + parsed.netloc
        if req.url in assets and req.method == 'GET' and req.resource_type == 'image':
            require(not req.headers.get('authorization'))
            asset = assets[req.url]['data']
            route.fulfill(content_type='image/png' if asset.startswith(b'\x89PNG\r\n\x1a\n') else 'image/jpeg',
                          body=asset)
        elif parsed.path.startswith('/api/'):
            if origin != frame.API_ORIGIN or parsed.query or parsed.path not in (*replies, frame.AUTH, answer):
                private['unexpectedApis'].append({'url': req.url, 'method': req.method})
                route.abort()
            elif req.method == 'OPTIONS':
                route.fulfill(status=204, headers=cors, body='')
            elif parsed.path == frame.AUTH and req.method == 'POST':
                require(req.post_data_json == {'identity': actor['account'], 'password': frame.PASSWORD})
                respond(route, {'token': frame.TOKEN, 'record': {'id': actor['id']}})
            else:
                require(req.headers.get('authorization') == frame.TOKEN)
                if req.method == 'GET' and parsed.path in replies:
                    values = (*[current[key] for key in ('player', 'assignments', 'assignment')], {'items': []}, {'items': []})
                    respond(route, dict(zip(replies, values))[parsed.path])
                elif req.method == 'POST' and parsed.path == answer:
                    body = req.post_data_json
                    require(mode in ('wrong', 'hold', 'drop') and set(body) == {'sessionLevelId', 'answer', 'requestId'} and
                            body['sessionLevelId'] == level and body['answer'] == (wrong if mode == 'wrong' else original) and
                            isinstance(body['requestId'], str) and bool(body['requestId']))
                    bodies.append(body)
                    if mode == 'wrong':
                        current = snapshots['incorrect']
                        respond(route, responses['incorrect'])
                    elif mode == 'hold':
                        held.append(route)
                    else:
                        route.abort('failed')
                else:
                    raise ValueError('unexpected api method')
        elif req.method == 'GET' and origin == args.url and parsed.path == frame.FONT_ROUTE and not parsed.query:
            route.fulfill(content_type='font/ttf', body=font)
        elif boundary.source_request(req.method, req.url, req.resource_type, args.url, assignment['id'], web):
            route.continue_()
        else:
            private['blocked'].append({'url': req.url, 'type': req.resource_type})
            route.abort()

    def guarded(route):
        try:
            route_request(route)
        except Exception as error:
            private['routeFailures'].append({'type': type(error).__name__, 'message': str(error)})
            route.abort()

    context = browser.new_context(viewport={'width': 376, 'height': 742}, device_scale_factor=1,
        has_touch=True, is_mobile=True, color_scheme=theme, reduced_motion='reduce', locale='zh-CN',
        timezone_id='Asia/Shanghai', service_workers='block', accept_downloads=False)
    try:
        context.route('**/*', guarded)
        context.route_web_socket('**/*', lambda _socket: None)
        page = context.new_page()
        page.set_default_timeout(15000)
        page.on('pageerror', lambda error: private['pageErrors'].append(str(error)))
        page.goto(args.url + '/login?theme=' + theme, wait_until='networkidle')
        for relative, content in sources.items():
            served = frame.bounded(page, 'return (await import(arg+"?raw")).default;', '/' + relative)
            require(isinstance(served, str) and sha(served.encode()) == sha(content))
        checked = frame.bounded(page, """const m=await import('/src/api/game.schema.ts');
          return arg.snapshots.every(d=>m.gamePlayerSchema.safeParse(d.player).success &&
            m.gameAssignmentSchema.safeParse(d.assignment).success &&
            m.gameAssignmentSummarySchema.array().safeParse(d.assignments.items).success) &&
            arg.responses.every(d=>m.gameAnswerSchema.safeParse(d).success);""",
            {'snapshots': list(snapshots.values()), 'responses': list(responses.values())})
        require(checked is True)
        page.get_by_label('登录账号', exact=True).fill(actor['account'])
        page.get_by_label('密码', exact=True).fill(frame.PASSWORD)
        page.get_by_role('button', name='进入冒险', exact=True).click()
        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
        page.goto(args.url + '/play/' + quote(assignment['id'], safe='') + '?theme=' + theme, wait_until='networkidle')
        page.get_by_role('textbox', name='答案', exact=True).wait_for()
        # The dialog's modal accessibility fence intentionally hides the
        # background from role lookups, but its live field is still inspectable.
        field = page.locator('.quest-card .answer-form input.ui-input--line')
        require(page.locator('.quest-card').count() == 1 and page.locator('.quest-layout.quest-desktop').count() == 0)
        bgm = page.get_by_role('button', name='关闭背景音乐提示', exact=True)
        if bgm.count():
            bgm.click()
            bgm.wait_for(state='detached')
        page.add_style_tag(content='@font-face{font-family:StarwardFeedbackSerif;src:url("' + args.url + frame.FONT_ROUTE +
            '") format("truetype");font-weight:100 900;font-style:normal;font-display:block}:root{--font-display:StarwardFeedbackSerif,serif!important}')
        require(frame.bounded(page, 'return (await document.fonts.load("24px StarwardFeedbackSerif")).length>0;'))
        images = page.locator('.quest-card .quest-content img')
        loaded = set()
        for i in range(images.count()):
            image = images.nth(i)
            image.scroll_into_view_if_needed()
            page.wait_for_function('(el)=>el.complete&&el.naturalWidth>0', arg=image.element_handle())
            loaded.add(image.evaluate('(el)=>el.currentSrc||el.src'))
        require(loaded == set(assets))

        def shot(name, anchor):
            anchor.wait_for()
            anchor.evaluate("el=>el.scrollIntoView({block:'center',inline:'nearest',behavior:'instant'})")
            frame.bounded(page, 'await document.fonts.ready;await new Promise(r=>requestAnimationFrame(r));')
            observed = page.evaluate(MEASURE)
            require((observed['width'], observed['height'], observed['dpr'], observed['theme'], observed['coarse']) ==
                    (376, 742, 1, theme, True))
            png = out / f'{theme}-{name}.png'
            raw = out / f'{theme}-{name}.json'
            png_sha = boundary.private_write(png, page.screenshot(animations='disabled'))
            raw_sha = boundary.private_write(raw, observed)
            report['states'].append({'theme': theme, 'state': name, 'geometry': observed['nodes'],
                'screenshot': {'file': str(png.relative_to(ROOT)), 'sha256': png_sha},
                'privateMeasurements': {'file': str(raw.relative_to(ROOT)), 'sha256': raw_sha}})

        def wait_for_held():
            for _ in range(80):
                if len(held) == 1:
                    return
                page.wait_for_timeout(25)
            require(False)

        hint = page.locator('.quest-card .quest-hint').first
        summary = hint.locator('summary')
        field.fill(wrong)
        field.blur()
        require(summary.inner_text() == '查看提示' and hint.get_attribute('open') is None)
        shot('hint-closed', hint)
        summary.tap()
        require(hint.get_attribute('open') is not None and summary.inner_text() == '查看提示')
        shot('hint-open', hint)
        summary.tap()
        require(hint.get_attribute('open') is None and field.input_value() == wrong and not bodies)

        submit = page.get_by_role('button', name='提交答案', exact=True)
        feedback = page.locator('.quest-card .feedback')
        field.fill('')
        field.blur()
        submit.tap()
        feedback.get_by_text('请先输入或选择答案。', exact=True).wait_for()
        require(feedback.get_by_text('验证未通过', exact=True).count() == 1 and not bodies)
        shot('empty', feedback)
        field.fill(wrong)
        mode = 'wrong'
        submit.tap()
        feedback.get_by_text('答案不正确，可以继续尝试。', exact=True).wait_for()
        require(len(bodies) == 1 and field.input_value() == wrong)
        shot('wrong', feedback)
        field.fill(original)
        mode = 'hold'
        submit.tap()
        wait_for_held()
        require(submit.is_disabled() and field.is_disabled() and len(held) == 1)
        shot('pending', submit)
        mode = 'drop'
        held.pop().abort('failed')
        dialog = page.locator('.game-retry-dialog')
        retry = dialog.get_by_role('button', name='重新连接', exact=True)
        stay = dialog.get_by_role('button', name='留在当前页面', exact=True)
        retry.wait_for()
        require(len(bodies) == 5 and all(body == bodies[1] for body in bodies[1:]) and
                bodies[1]['requestId'] != bodies[0]['requestId'] and field.input_value() == original)
        shot('reconnect', dialog)
        mode = 'hold'
        retry.tap()
        wait_for_held()
        pending = dialog.get_by_role('button', name='正在重新连接…', exact=True)
        require(pending.is_disabled() and stay.is_disabled() and len(held) == 1 and bodies[-1] == bodies[1])
        page.keyboard.press('Escape')
        require(dialog.is_visible())
        shot('reconnecting', dialog)
        current = snapshots['completed']
        respond(held.pop(), responses['correct'])
        feedback.get_by_text('全部题目已经完成。', exact=True).wait_for()
        require(dialog.is_hidden() and field.is_disabled() and field.input_value().strip() == correct and len(bodies) == 6)
        shot('correct', feedback)
        report['checks'].append({'theme': theme, 'hintPreservesSameProbeDraft': True, 'emptyHasNoAnswerRequest': True,
            'fourSimulatedSameBodyTransportAttempts': True, 'explicitRetryPreservesSameBody': True,
            'retryPendingEscapeBlocked': True, 'normalAnswerResultRendered': True})
    finally:
        context.close()


def capture(args):
    frame = load_frame()
    boundary = frame.BOUNDARY
    require(boundary.local_origin(args.url) == frame.BASE_URL)
    web = args.web_source.resolve()
    boundary.frozen_check(web)
    sources = {name: (web / name).read_bytes() for name in dict.fromkeys((*frame.SOURCES, *SOURCES))}
    files = {name: frame.private_input(getattr(args, name + '_json')) for name in NAMES}
    originals = {name: path.read_bytes() for name, path in files.items()}
    require(all(sha(raw) == getattr(args, name + '_sha') for name, raw in originals.items()))
    snapshots = {name: json.loads(raw) for name, raw in originals.items()}
    wrong, correct, wanted = matching_snapshots(frame, snapshots)
    responses = {}
    for result in ('incorrect', 'correct'):
        dto = snapshots['completed' if result == 'correct' else result]
        responses[result] = {'result': result, 'assignment': dto['assignment'], 'player': dto['player'],
            'xpDelta': dto['player']['totalXp'] - snapshots['active']['player']['totalXp'],
            'rewardIds': [], 'effects': []}
    image_path = frame.private_input(args.images_manifest)
    image_bytes, all_assets = frame.image_assets(image_path, CONTENT_SHA)
    require(sha(image_bytes) == args.images_sha and wanted <= set(all_assets))
    assets = {url: all_assets[url] for url in wanted}
    font = frame.NATIVE_FONT.read_bytes()
    require(sha(font) == FONT_SHA)
    out = boundary.path_in(args.output_dir, frame.PRIVATE)
    report_path = boundary.path_in(args.manifest, frame.PUBLIC)
    require(not out.exists() and not report_path.exists())
    boundary.fresh_directory(out)
    own = Path(__file__).read_bytes()
    report = {'status': 'incomplete', 'sourceCommit': frame.FROZEN, 'helperSha256': sha(own),
        'frameHelperSha256': FRAME_SHA, 'sourceSha256': {name: sha(raw) for name, raw in sources.items()},
        'actualDtoSha256': {name: sha(raw) for name, raw in originals.items()}, 'imagesManifestSha256': args.images_sha,
        'fontSha256': FONT_SHA, 'backendRequestsContinued': 0, 'externalRequestsContinued': 0,
        'scope': 'Mobile feedback rendering using Native snapshots. Authentication, request timing and responses are local replay.',
        'nativeAcceptance': False, 'businessAcceptance': False, 'sameDataVisualReview': 'pending',
        'states': [], 'checks': [], 'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    private = {key: [] for key in ('unexpectedApis', 'blocked', 'routeFailures', 'pageErrors')}
    try:
        package = frame.PRIVATE / 'python-playwright'
        if package.is_dir():
            sys.path.insert(0, str(package))
        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True, args=['--disable-background-networking'])
            try:
                for theme in THEMES:
                    render(browser, frame, args, web, sources, snapshots, responses,
                           (wrong, correct), assets, font, theme, out, report, private)
            finally:
                browser.close()
        boundary.frozen_check(web)
        require(len(report['states']) == 16 and len(report['checks']) == 2 and
                not any(private[k] for k in ('unexpectedApis', 'routeFailures', 'pageErrors')) and
                sha(FRAME.read_bytes()) == FRAME_SHA and Path(__file__).read_bytes() == own and
                image_path.read_bytes() == image_bytes and frame.NATIVE_FONT.read_bytes() == font and
                all(files[key].read_bytes() == data for key, data in originals.items()) and
                all((web / name).read_bytes() == data for name, data in sources.items()) and
                all(asset['source'].read_bytes() == asset['data'] for asset in assets.values()))
        report['status'] = 'captured_web_gameplay_feedback_reference'
    except Exception as error:
        private['failure'] = {'type': type(error).__name__, 'message': str(error)}
    raw = out / 'private-browser-evidence.json'
    report['privateBrowserEvidence'] = {'file': str(raw.relative_to(ROOT)), 'sha256': boundary.private_write(raw, private)}
    report['counts'] = {key: len(value) for key, value in private.items() if isinstance(value, list)}
    encoded = (json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
    literals = set().union(*(frame.private_literals(dto) for dto in snapshots.values()), wanted)
    require(not re.search(rb'https?://', encoded) and not any(
        item.encode() in encoded if len(item) >= 5 else json.dumps(item, ensure_ascii=False).encode() in encoded
        for item in literals))
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with os.fdopen(os.open(report_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644), 'wb') as stream:
        stream.write(encoded)
    print(json.dumps({'status': report['status'], 'states': len(report['states']), 'manifestSha256': sha(encoded)}), flush=True)
    return int(report['status'] == 'incomplete')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    run = parser.add_subparsers(dest='action').add_parser('run')
    for name in NAMES:
        run.add_argument('--' + name + '-json', type=Path, required=True)
        run.add_argument('--' + name + '-sha', required=True)
    for name in ('images-manifest', 'output-dir', 'manifest'):
        run.add_argument('--' + name, type=Path, required=True)
    run.add_argument('--images-sha', required=True)
    run.add_argument('--url', default='http://127.0.0.1:5178')
    run.add_argument('--web-source', type=Path, default=Path('/Users/sitkin/my_code/questions-web'))
    args = parser.parse_args()
    if args.action is None:
        parser.print_help()
        return 0
    try:
        return capture(args)
    except Exception:
        print(json.dumps({'status': 'not_captured_or_report_guarded',
                          'error': 'Exact source, DTO, output or privacy boundary failed. Values omitted.'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

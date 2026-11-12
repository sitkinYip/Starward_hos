#!/usr/bin/env python3
"""Replay ordinary clue videos against the frozen mobile Web UI.

The caller supplies an isolated player snapshot and the exact MP4 used by the
isolated backend. A standalone browser intercepts all media and API requests.
Only frozen Web source is fetched from the existing loopback Vite server.
"""

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
GAME = '/api/questions/v1'
MEDIA_PATHS = ('/__starward_test_media/ordinary.mp4', '/__starward_test_media/retry.mp4')
SOURCES = (
    'src/index.css', 'src/api/game.schema.ts', 'src/config/ui-copy.ts', 'src/components/ui/Dialog.tsx',
    'src/features/clues/CluePanel.tsx', 'src/features/game/GamePlayPage.tsx',
    'src/features/game/GamePlayScene.tsx', 'src/features/game/clue-presentation.ts',
    'src/features/game/useGamePresentation.ts', 'src/features/media/MediaViewer.tsx',
    'src/features/media/NativeVideo.tsx', 'src/styles/features/clues.css',
    'src/styles/components/media-backdrop.css', 'src/styles/components/media-viewer.css',
    'src/styles/effects/overlay-lighting.css',
)

GEOMETRY = r"""() => {
  const measure = (node) => {
    if (!node) return null;
    const {x,y,width,height}=node.getBoundingClientRect(), style=getComputedStyle(node);
    return {x,y,width,height,visible:node.checkVisibility(),color:style.color,
      background:style.backgroundColor,padding:style.padding,borderRadius:style.borderRadius};
  };
  const selectors={panel:'.clue-panel',viewer:'.media-viewer',backdrop:'.media-viewer-backdrop',
    stage:'.media-viewer-stage--video',video:'.media-viewer-stage--video > video',close:'.media-viewer-close'};
  const cards=[...document.querySelectorAll('.clue-card[data-kind="video"]')].map(card => ({
    card:measure(card),lead:measure(card.querySelector('.clue-index')),
    status:measure(card.querySelector('.clue-card-status')),title:measure(card.querySelector('.clue-card-body > strong')),
    preview:measure(card.querySelector('.clue-preview')),action:measure(card.querySelector('.clue-card-action')),
  }));
  return {viewport:{width:innerWidth,height:innerHeight,dpr:devicePixelRatio,theme:document.documentElement.dataset.theme},
    cards,...Object.fromEntries(Object.entries(selectors).map(([key,selector])=>[key,measure(document.querySelector(selector))]))};
}"""


def digest(raw):
    return sha256(raw).hexdigest()


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def load_frame():
    raw = FRAME.read_bytes()
    require(digest(raw) == FRAME_SHA, 'Frozen frame helper changed')
    frame = ModuleType('clue_video_web_frame')
    frame.__file__ = str(FRAME)
    exec(compile(raw, str(FRAME), 'exec'), frame.__dict__)
    return frame


def inputs(frame, args):
    snapshot_path, media_path = [frame.private_input(path) for path in (args.snapshot, args.media_file)]
    snapshot, media = snapshot_path.read_bytes(), media_path.read_bytes()
    require(digest(snapshot) == args.snapshot_sha and digest(media) == args.media_sha and
            32 <= len(media) <= 16 * 1024 * 1024 and media[4:8] == b'ftyp', 'Hash or MP4 differs')
    require(not re.search(rb'"(?:token|password|authorization|controltoken|answerkey)"\s*:', snapshot, re.I),
            'Fixture contains credential fields')
    data = json.loads(snapshot)
    if args.phase:
        data = data[args.phase]
    require(set(data) == {'player', 'assignment', 'assignments'}, 'Replay expects a single actor DTO')
    player, assignment = data['player'], data['assignment']
    require(re.fullmatch(r'hm_[a-f0-9]{12}', player['account']) and player['mustChangePassword'] is False and
            all(re.fullmatch(r'[a-z0-9]{15}', value) for value in (player['id'], assignment['id'])) and
            assignment['player'] == player['id'] and assignment['status'] in ('active', 'completed') and
            bool(assignment['levels'][0]['completedAt']) and assignment['completedLevels'] >= 1 and
            any(row['id'] == assignment['id'] and row['player'] == player['id']
                for row in data['assignments']['items']), 'Fixture is not an isolated completed-question replay')
    clues = sorted((clue for clue in assignment['clues'] if clue['kind'] == 'video'),
                   key=lambda clue: (clue['position'], clue['definitionId'] or clue['id'], clue['id']))
    require(len(clues) == 2 and all(clue['source'] == 'session' and clue['trigger'] == 'start' and
            not clue['sessionLevel'] and clue['unlockedAt'] for clue in clues), 'Expected two authorized ordinary videos')
    urls = [urlsplit(clue['content']['url']) for clue in clues]
    require(tuple(url.path for url in urls) == MEDIA_PATHS and urls[0].netloc == urls[1].netloc and
            all(url.scheme == 'https' and url.hostname and not any((url.username, url.password, url.query, url.fragment))
                for url in urls), 'Unexpected isolated media paths')
    return snapshot_path, snapshot, media_path, media, data, clues


def serve_media(route, raw, range_value):
    headers = {'Accept-Ranges': 'bytes', 'Cache-Control': 'no-store'}
    size = len(raw)
    if not range_value:
        route.fulfill(status=200, headers={**headers, 'Content-Length': str(size)}, content_type='video/mp4', body=raw)
        return 200
    match = re.fullmatch(r'bytes=(\d{0,12})-(\d{0,12})', range_value)
    require(match and any(match.groups()), 'Unexpected media range syntax')
    first, last = match.groups()
    start = int(first) if first else max(0, size - int(last))
    end = min(size - 1, int(last)) if first and last else size - 1
    if start > end:
        route.fulfill(status=416, headers={**headers, 'Content-Range': f'bytes */{size}'}, body='')
        return 416
    chunk = raw[start:end + 1]
    route.fulfill(status=206, headers={**headers, 'Content-Length': str(len(chunk)),
                                      'Content-Range': f'bytes {start}-{end}/{size}'},
                  content_type='video/mp4', body=chunk)
    return 206


def render(browser, frame, args, sources, data, clues, media, theme, output, report, private):
    player, assignment = data['player'], data['assignment']
    base = args.url
    path = GAME + '/assignments/' + assignment['id']
    route_url = base + '/play/' + assignment['id'] + '?theme=' + theme
    reads = {GAME + '/me': player, GAME + '/assignments': data['assignments'], path: assignment,
             GAME + '/notifications': {'items': []}, GAME + '/rewards': {'items': []}}
    allowed_api = {*reads, frame.AUTH, '/api/files/token'}
    cors = {'Access-Control-Allow-Origin': base, 'Access-Control-Allow-Headers': 'Authorization,Content-Type,Accept',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'}
    media_urls = {clue['content']['url']: index for index, clue in enumerate(clues)}
    evidence = {'theme': theme, 'media': [], 'errors': [], 'blocked': []}
    private.append(evidence)

    def handle(route):
        req = route.request
        uri = urlsplit(req.url)
        origin = uri.scheme + '://' + uri.netloc
        if req.url in media_urls:
            headers = req.all_headers()
            require(req.method == 'GET' and req.resource_type == 'media' and not req.is_navigation_request() and
                    'authorization' not in headers and 'cookie' not in headers and headers.get('referer') == base + '/',
                    'Media request was not an isolated browser subresource')
            status = serve_media(route, media, headers.get('range'))
            evidence['media'].append({'cardIndex': media_urls[req.url], 'range': headers.get('range'), 'status': status})
        elif uri.path.startswith('/api/') and origin == frame.API_ORIGIN:
            if uri.path not in allowed_api:
                require(req.method == 'GET' and uri.path.startswith('/api/files/game_players/'), 'Unexpected API blocked')
                route.abort()
                return
            require(not uri.query, 'Unexpected API query blocked')
            if req.method == 'OPTIONS':
                route.fulfill(status=204, headers=cors, body='')
                return
            if uri.path == frame.AUTH and req.method == 'POST':
                require(req.post_data_json == {'identity': player['account'], 'password': frame.PASSWORD}, 'Synthetic login differs')
                value = {'token': frame.TOKEN, 'record': {'id': player['id']}}
            elif req.headers.get('authorization') == frame.TOKEN and req.method == 'GET' and uri.path in reads:
                value = reads[uri.path]
            elif req.headers.get('authorization') == frame.TOKEN and req.method == 'POST' and uri.path == '/api/files/token':
                value = {'token': 'clue-video-replay-only-file-token'}
            else:
                raise ValueError('Unexpected method or authorization blocked')
            route.fulfill(status=200, headers=cors, content_type='application/json', body=json.dumps(value))
        elif frame.BOUNDARY.source_request(req.method, req.url, req.resource_type, base, assignment['id'], args.web_source):
            route.continue_()
        else:
            evidence['blocked'].append({'kind': req.resource_type, 'url': req.url})
            route.abort()

    def guard(route):
        try:
            handle(route)
        except Exception as error:
            evidence['errors'].append(str(error))
            route.abort()

    context = browser.new_context(viewport={'width': args.width, 'height': args.height}, device_scale_factor=1,
                                  color_scheme=theme, reduced_motion='reduce', is_mobile=True, has_touch=True,
                                  locale='zh-CN', service_workers='block', accept_downloads=False)
    try:
        context.route('**/*', guard)
        context.route_web_socket('**/*', lambda _socket: None)
        page = context.new_page()
        page.on('pageerror', lambda error: evidence['errors'].append(str(error)))
        page.set_default_timeout(15000)
        page.goto(base + '/login?theme=' + theme, wait_until='networkidle')
        for name, raw in sources.items():
            served = frame.bounded(page, 'return (await import(arg+"?raw")).default;', '/' + name)
            require(isinstance(served, str) and digest(served.encode()) == digest(raw), 'Served frozen Web source differs')
        schema = frame.bounded(page, """const m=await import('/src/api/game.schema.ts');return [
          m.gamePlayerSchema.safeParse(arg.player).success,m.gameAssignmentSchema.safeParse(arg.assignment).success,
          m.gameAssignmentSummarySchema.array().safeParse(arg.assignments.items).success];""", data)
        require(schema == [True, True, True], 'Frozen Web schema rejected the fixture')
        page.get_by_label('登录账号', exact=True).fill(player['account'])
        page.get_by_label('密码', exact=True).fill(frame.PASSWORD)
        page.get_by_role('button', name='进入冒险', exact=True).tap()
        page.get_by_role('heading', name='下一段故事，等你落笔。', exact=True).wait_for()
        page.goto(route_url, wait_until='networkidle')
        card = page.locator('.quest-card')
        card.wait_for()
        require(card.count() == 1 and page.locator('.quest-layout.quest-desktop').count() == 0, 'Expected a mobile question')
        for label in ('关闭背景音乐提示', '知道了'):
            prompt = page.get_by_role('button', name=label, exact=True)
            if prompt.count() == 1 and prompt.is_visible():
                prompt.tap()
                prompt.wait_for(state='detached')
        nav = page.locator('nav.quest-nav button')
        if nav.count() > 1 and nav.first.get_attribute('aria-current') != 'step':
            nav.first.tap()
        cards = card.locator('.clue-card[data-kind="video"]')
        cards.first.wait_for()
        require(cards.count() == len(clues), 'Video cards missing from completed question')
        for index, clue in enumerate(clues):
            row = cards.nth(index)
            require(row.locator('.clue-card-body > strong').text_content() == (clue['content']['title'] or '时空回溯') and
                    row.locator('.clue-card-status').text_content() == 'Archive verified' and
                    not row.locator('.clue-card-status').is_visible(), 'Mobile video card title or status differs')
            if not clue['content']['text']:
                require(row.locator('.clue-preview').text_content() == '点击查看已解锁内容', 'Empty preview differs')
        require(not evidence['media'], 'Browser requested an archive video before activation')
        cards.first.scroll_into_view_if_needed()
        page.evaluate('document.fonts.ready')
        viewer = page.get_by_role('dialog', name='视频播放器', exact=True)
        video = viewer.locator('video')

        def capture(state, playback=None):
            geometry = page.evaluate(GEOMETRY)
            require(geometry['viewport'] == {'width': args.width, 'height': args.height, 'dpr': 1, 'theme': theme},
                    'Web viewport or theme differs')
            filename = f'{theme}-{state}'
            files = {}
            for key, ext, value in (('screenshot', '.png', page.screenshot(animations='disabled')),
                                    ('privateDom', '.html', page.content().encode())):
                dest = output / (filename + ext)
                files[key] = {'path': str(dest.relative_to(ROOT)), 'sha256': frame.BOUNDARY.private_write(dest, value)}
            report['states'].append({'theme': theme, 'state': state, 'geometry': geometry, 'playback': playback, **files})

        def playing_at(seconds):
            page.wait_for_function("""seconds=>{const v=document.querySelector('.media-viewer-stage--video > video');
              return !!v && v.readyState>=2 && !v.paused && v.currentTime>=seconds && v.videoWidth>0;}""", arg=seconds)
            return video.evaluate("""v=>({width:v.videoWidth,height:v.videoHeight,duration:v.duration,
              time:v.currentTime,autoPlay:v.autoplay,inline:v.playsInline,controls:v.controls})""")

        def open_video(index):
            cards.nth(index).tap()
            viewer.wait_for()
            playback = playing_at(0.5)
            require(video.get_attribute('src') == clues[index]['content']['url'] and all(playback[key]
                    for key in ('autoPlay', 'inline', 'controls')) and viewer.locator('.media-viewer-navigation').count() == 0 and
                    len(context.pages) == 1 and page.url == route_url, 'Viewer source, playback policy or overlay differs')
            require(any(row['cardIndex'] == index and row['status'] in (200, 206) for row in evidence['media']),
                    'No registered MP4 was consumed for this video')
            return playback

        capture('archive')
        capture('playing', open_video(0))
        capture('playing-later', playing_at(7.5))
        viewer.get_by_role('button', name='关闭媒体预览', exact=True).tap()
        viewer.wait_for(state='detached')
        require(cards.first.is_visible(), 'Close button did not return to the original archive')
        open_video(1)
        video.evaluate("""v=>{
          v.addEventListener('ended', () => { window.__ordinaryClueEnded = v.ended && !v.error; }, {once:true});
          v.currentTime=Math.max(0,v.duration-0.8);
        }""")
        page.wait_for_function('window.__ordinaryClueEnded === true')
        viewer.wait_for(state='detached')
        require(cards.nth(1).is_visible() and page.url == route_url and not evidence['errors'],
                'Natural ended event did not close the viewer cleanly')
        report['checks'].append({'theme': theme, 'authorizedOrdinaryVideoCards': len(clues), 'requestBeforeTap': False,
                                 'closeButtonReturnedToArchive': True, 'seekThenNaturalEndedReturnedToArchive': True,
                                 'registeredMediaResponses': len(evidence['media']), 'frozenSourceChecks': len(sources),
                                 'schemaChecks': len(schema)})
    finally:
        context.close()


def capture(args):
    frame = load_frame()
    boundary = frame.BOUNDARY
    args.url = boundary.local_origin(args.url)
    args.web_source = args.web_source.resolve()
    boundary.frozen_check(args.web_source)
    source_bytes = {name: (args.web_source / name).read_bytes() for name in SOURCES}
    renderer = Path(__file__).read_bytes()
    snapshot_path, snapshot, media_path, media, data, clues = inputs(frame, args)
    output = boundary.path_in(args.output_dir, frame.PRIVATE)
    manifest = boundary.path_in(args.manifest, frame.PUBLIC)
    require(not manifest.exists() and 320 <= args.width <= 620 and 600 <= args.height <= 1000, 'Output or viewport differs')
    boundary.fresh_directory(output)
    report = {'status': 'incomplete', 'sourceCommit': frame.FROZEN, 'rendererSha256': digest(renderer),
              'inputSha256': digest(snapshot), 'mediaSha256': digest(media), 'mediaBytes': len(media),
              'sourceSha256': {name: digest(raw) for name, raw in source_bytes.items()}, 'syntheticAuthentication': True,
              'businessRequestsForwarded': 0, 'externalRequestsForwarded': 0, 'nativeAcceptance': False,
              'visualReview': 'pending_original_review', 'states': [], 'checks': []}
    private = []
    try:
        sys.path.insert(0, str(frame.PRIVATE / 'python-playwright'))
        from playwright.sync_api import sync_playwright
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(channel='chrome', headless=True, timeout=30000,
                                                 args=['--disable-background-networking'])
            try:
                for theme in ('light', 'dark'):
                    render(browser, frame, args, source_bytes, data, clues, media, theme, output, report, private)
            finally:
                browser.close()
        boundary.frozen_check(args.web_source)
        require(Path(__file__).read_bytes() == renderer and digest(FRAME.read_bytes()) == FRAME_SHA and
                snapshot_path.read_bytes() == snapshot and media_path.read_bytes() == media and
                all((args.web_source / name).read_bytes() == raw for name, raw in source_bytes.items()) and
                len(report['states']) == 6 and len(report['checks']) == 2, 'Source changed or capture incomplete')
        report['status'] = 'captured_web_clue_video_reference'
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
    parser.add_argument('--url', default='http://127.0.0.1:5178')
    parser.add_argument('--web-source', type=Path, default=ROOT.parent / 'questions-web')
    for name in ('snapshot', 'media-file', 'output-dir', 'manifest'):
        parser.add_argument('--' + name, type=Path, required=True)
    for name in ('snapshot-sha', 'media-sha'):
        parser.add_argument('--' + name, required=True)
    parser.add_argument('--phase', help='Optional key containing the actor DTO in a phase snapshot')
    parser.add_argument('--width', type=int, required=True)
    parser.add_argument('--height', type=int, required=True)
    try:
        return capture(parser.parse_args())
    except Exception:
        print(json.dumps({'status': 'not_captured_or_report_guarded',
                          'error': 'Frozen source, fixture, MP4, or output guard failed; values omitted'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())

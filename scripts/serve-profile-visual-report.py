#!/usr/bin/env python3
"""Prepare, then privately serve actual Task1 profile visual inputs on127.0.0.1:5180.

Preparation never starts a server/browser/device or edits a source report:
  python3 scripts/serve-profile-visual-report.py --prepare --pairing-receipt <private.json>
Then root explicitly starts the frozen prepared allowlist:
  python3 scripts/serve-profile-visual-report.py --manifest <prepared manifest.json>

Requires NEW complete Web8 states (including crop) and native12 states, with
optional native menu-destinations images. Old Web6 references are rejected.
Private pairing receipt schema:
 {"webReportSha256":"...","nativeReportSha256":"...","nativeHapSha256":"...",
  "nativeRuntimeSha256":"...","webSourceCommit":"...","snapshotSha256":"...",
  "sameDedicatedPlayerAndProfileSnapshot":true,"pairMappingReviewed":true,
  "pairs":[{"group":"identity","theme":"dark","web":"profile-identity",
             "native":["profile-identity-top","profile-identity-bottom"]}, ...],
  "nativeCropReportSha256":"<optional actual native-avatar-crop-visual.json SHA>",
  "nativeCrops":[{"theme":"dark","position":"top","file":"artifacts/private/...png","sha256":"...",
     "hapSha256":"...","runtimeSha256":"...","sourceSha256":"<Web QA crop source SHA>",
     "actualThemeVerified":true}, <dark controls, light top, light controls>]}
Pairs must cover identity/security/menu/crop x dark/light, exactly. Menu includes
profile-menu-destinations between top/bottom only when actually captured. Crop
maps to ["profile-avatar-crop-top","profile-avatar-crop-controls"] if all FOUR
nativeCrops exist, otherwise [] and the page says not captured. They must also
match the actual complete native crop report. Theme verification comes from
root's private receipt; the crop report's pending visual review is unchanged.
--root-review is optional; its HAP and source report SHAs must match if supplied.
Capture status never becomes a visual acceptance verdict in this viewer.
"""
import argparse
import base64
import datetime
import hashlib
import html
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import re
import stat
import struct
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'artifacts/private'
DESTINATION = PRIVATE / 'profile-comparison'
PROFILE = ROOT / 'artifacts/validation/profile'
PORT = 5180
THEMES = ('dark', 'light')
GROUPS = ('identity', 'security', 'menu', 'crop')
WEB_STATES = {'identity': 'profile-identity', 'security': 'profile-security',
              'menu': 'profile-menu', 'crop': 'profile-avatar-crop'}
LABELS = {'identity': '我的名片', 'security': '账号安全', 'menu': '冒险者菜单', 'crop': '头像裁剪'}
SHA = re.compile(r'[a-f0-9]{64}\Z')
ASSET = re.compile(r'/assets/(?:web|native)-[a-z0-9-]+\.(?:png)\Z')
STYLE = """
:root{color-scheme:dark;font:15px/1.6 system-ui,sans-serif;color:#e6e8ed;background:#111317}
*{box-sizing:border-box}body{margin:0}main{max-width:1760px;margin:auto;padding:32px 24px 72px}
h1{font-size:28px;line-height:1.3;margin:0 0 12px}h2{font-size:21px;margin:0 0 10px}
p{margin:8px 0}a{color:#a9c9ff}nav{display:flex;gap:8px 20px;flex-wrap:wrap;margin:24px 0}
code{overflow-wrap:anywhere;font:12px/1.6 ui-monospace,monospace}dl{display:grid;grid-template-columns:110px 1fr;gap:4px 14px}
dt{color:#a5abb7}dd{margin:0;min-width:0}.notice{border:1px solid #454b58;padding:16px 20px;background:#191d24}
section{margin-top:44px;scroll-margin-top:20px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:20px;align-items:start}
figure{margin:0;min-width:0}figcaption{padding:8px 0;color:#b6bdca}figure img{display:block;width:100%;max-width:391.111px;height:auto;margin:auto}
.missing{min-height:220px;border:1px dashed #606878;padding:24px;color:#b6bdca}.muted{color:#a5abb7}.tag{font-size:13px;color:#b8c9e7}
@media(max-width:600px){main{padding:24px 14px}dl{display:block}dt{margin-top:10px}.grid{grid-template-columns:1fr}}
"""
CSP = ("default-src 'none'; img-src 'self'; style-src 'sha256-" +
       base64.b64encode(hashlib.sha256(STYLE.encode()).digest()).decode() +
       "'; script-src 'none'; connect-src 'none'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'")


class Invalid(RuntimeError):
    pass


def digest(value):
    return hashlib.sha256(value).hexdigest()


def metrics(value, keys):
    return {key: value.get(key) if isinstance(value.get(key), (int, float)) and
            not isinstance(value.get(key), bool) and math.isfinite(value[key]) else None for key in keys}


def regular_bytes(value, root=PRIVATE, private=True, maximum=30 * 1024 * 1024):
    """openat/O_NOFOLLOW on every component; no symlink-swap directory escape."""
    path = Path(value).absolute()
    try:
        parts = path.relative_to(root.absolute()).parts
    except ValueError:
        raise Invalid('An input is outside its permitted project directory') from None
    if not parts or any(part in ('', '.', '..') for part in parts):
        raise Invalid('Ambiguous input path')
    if not path.resolve(strict=True).is_relative_to(root.resolve(strict=True)):
        raise Invalid('An input resolved outside its permitted directory')
    directory = descriptor = None
    try:
        directory = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        for part in parts[:-1]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory)
            os.close(directory)
            directory = child
        descriptor = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
        info = os.fstat(descriptor)
        if (not stat.S_ISREG(info.st_mode) or not 0 < info.st_size <= maximum or
                private and (info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077)):
            raise Invalid('A private input is not a bounded owned mode0600 regular file')
        with os.fdopen(descriptor, 'rb', closefd=False) as source:
            value = source.read(maximum + 1)
        if len(value) != info.st_size:
            raise Invalid('Input changed while being read')
        return value
    finally:
        if descriptor is not None:
            os.close(descriptor)
        if directory is not None:
            os.close(directory)


def object_file(path, private=False):
    raw = regular_bytes(path, PRIVATE if private else PROFILE, private, 4 * 1024 * 1024)
    value = json.loads(raw)
    if not isinstance(value, dict):
        raise Invalid('Expected an evidence JSON object')
    return value, digest(raw)


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()


def write_private(path, value):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'wb') as output:
        output.write(value)


def png(value, expected):
    if (not SHA.fullmatch(expected or '') or digest(value) != expected or len(value) < 33 or
            value[:8] != b'\x89PNG\r\n\x1a\n' or value[12:16] != b'IHDR'):
        raise Invalid('A source PNG does not match its actual capture SHA/header')
    width, height = struct.unpack('>II', value[16:24])
    if not 100 <= width <= 10000 or not 100 <= height <= 20000:
        raise Invalid('Source PNG dimensions are outside the screenshot scope')
    return [width, height]


def state_map(report, allowed):
    rows = report.get('states')
    if not isinstance(rows, list):
        raise Invalid('Actual screenshot state records are missing')
    output = {}
    for row in rows:
        key = (row.get('state'), row.get('theme'))
        if key in output or key[0] not in allowed or key[1] not in THEMES:
            raise Invalid('Actual state list contains an unknown or duplicate capture')
        output[key] = row
    return output


def build(args):
    web, web_sha = object_file(args.web_report)
    native, native_sha = object_file(args.native_report)
    receipt, receipt_sha = object_file(args.pairing_receipt, True)
    if (web.get('status') != 'passed' or web.get('browserUsesRealBackend') is not False or
            web.get('sourceCheckoutCleanBefore') is not True or web.get('sourceCheckoutCleanAfter') is not True or
            not re.fullmatch(r'[a-f0-9]{40}', web.get('sourceCommit', '')) or
            any(web.get(key) != 0 for key in ('consoleErrorCount', 'pageErrorCount', 'unexpectedApiCount')) or
            not web.get('schemaChecks') or any(row.get('success') is not True for row in web['schemaChecks']) or
            not web.get('servedFrozenSourceChecks') or any(row.get('matches') is not True for row in web['servedFrozenSourceChecks'])):
        raise Invalid('Complete actual frozen-source/schema/intercepted Web capture evidence is required')
    crop = web.get('cropReference', {})
    if (crop.get('captureStatus') != 'captured' or crop.get('sourceSha256RecheckedAfter') is not True or
            crop.get('cropConfirmationClicked') is not False or crop.get('profileWriteRequestCount') != 0 or
            crop.get('dialogCancelledThemes') != ['dark', 'light'] or not SHA.fullmatch(crop.get('sourceSha256', ''))):
        raise Invalid('A new actual Web crop capture is required; historical six-state Web input is not used')
    web_states = state_map(web, set(WEB_STATES.values()))
    if set(web_states) != {(value, theme) for value in WEB_STATES.values() for theme in THEMES}:
        raise Invalid('Exactly the eight requested Web states must be present')
    base_states = {f'profile-{group}-{position}' for group in ('identity', 'security', 'menu') for position in ('top', 'bottom')}
    native_states = state_map(native, base_states | {'profile-menu-destinations'})
    if not {(value, theme) for value in base_states for theme in THEMES}.issubset(native_states):
        raise Invalid('The twelve actual native top/bottom captures are incomplete')
    web_directories = {str(Path(row.get('screenshot', '')).parent) for row in web_states.values()}
    native_directories = {str(Path(row.get('screenshot', '')).parent) for row in native_states.values()}
    if (len(web_directories) != 1 or len(native_directories) != 1 or
            native_directories != {native.get('privateOriginals')} or
            web_directories != {str(Path(web.get('privateRawEvidence', {}).get('file', '')).parent)}):
        raise Invalid('A capture report mixes screenshot batches or does not bind its private original directory')
    hap = native.get('hap', {}).get('packagedSha256', '')
    runtime_ref, core_ref = native.get('runtime', {}), native.get('corePrerequisite', {})
    runtime, runtime_sha = object_file(ROOT / runtime_ref.get('file', ''))
    core, core_sha = object_file(ROOT / core_ref.get('file', ''))
    if (native.get('status') != 'passed' or not SHA.fullmatch(hap) or
            native.get('webComparisonPerformed') is not False or native.get('businessWritesObserved') != 0 or
            not native.get('cleanup') or not all(value is True for value in native['cleanup'].values()) or
            runtime_sha != runtime_ref.get('sha256') or core_sha != core_ref.get('sha256') or
            runtime.get('status') != 'passed' or runtime.get('installedHapSha256') != hap or
            core.get('status') != 'passed' or core.get('hap', {}).get('packagedSha256') != hap or
            core.get('runtime', {}).get('sha256') != runtime_sha):
        raise Invalid('Native capture/core/runtime must form one clean actual HAP chain')
    snapshot = web.get('snapshot', {})
    if digest(regular_bytes(ROOT / snapshot.get('archiveFile', ''))) != snapshot.get('sha256'):
        raise Invalid('The actual private Web player snapshot archive changed')
    expected = {'webReportSha256': web_sha, 'nativeReportSha256': native_sha, 'nativeHapSha256': hap,
        'nativeRuntimeSha256': runtime_sha, 'webSourceCommit': web['sourceCommit'], 'snapshotSha256': snapshot['sha256']}
    if (any(receipt.get(key) != value for key, value in expected.items()) or
            receipt.get('sameDedicatedPlayerAndProfileSnapshot') is not True or receipt.get('pairMappingReviewed') is not True):
        raise Invalid('Root must explicitly bind the new HAP/snapshot/report SHAs and review the actual pair mapping')
    native_crops = receipt.get('nativeCrops', [])
    if not isinstance(native_crops, list) or len(native_crops) not in (0, 4):
        raise Invalid('Supply both actual native crop themes top/controls, or mark them not captured')
    crop_states = {}
    crop_report_sha = None
    if native_crops:
        crop_report, crop_report_sha = object_file(args.native_crop_report)
        if (receipt.get('nativeCropReportSha256') != crop_report_sha or crop_report.get('status') != 'complete' or
                crop_report.get('hap', {}).get('packagedSha256') != hap or
                crop_report.get('runtime', {}).get('sha256') != runtime_sha or
                crop_report.get('prerequisiteSha256', {}).get('core') != core_sha or
                crop_report.get('fixture', {}).get('sha256') != crop['sourceSha256']):
            raise Invalid('Optional native crop source report does not bind this actual HAP/runtime/core/QA source')
    for row in native_crops:
        theme, position = row.get('theme'), row.get('position')
        if (theme not in THEMES or position not in ('top', 'controls') or (theme, position) in crop_states or row.get('hapSha256') != hap or
                row.get('runtimeSha256') != runtime_sha or row.get('sourceSha256') != crop['sourceSha256'] or
                row.get('actualThemeVerified') is not True):
            raise Invalid('Actual native crop/theme/source evidence does not match the same HAP and QA source')
        actual_theme = crop_report.get('themes', {}).get(theme, {})
        shots = actual_theme.get('privateScreenshots', [])
        if (actual_theme.get('status') != 'captured' or not actual_theme.get('cleanup') or
                not all(value is True for value in actual_theme['cleanup'].values()) or
                actual_theme.get('businessWriteDelta') != {'profilePatch': 0, 'passwordPost': 0} or
                len([shot for shot in shots if shot.get('file') == row.get('file') and shot.get('sha256') == row.get('sha256') and
                     Path(shot['file']).name == 'crop-' + theme + '-' + position + '.png']) != 1):
            raise Invalid('A crop image is not one original top/controls PNG from the completed actual theme session')
        crop_states[(theme, position)] = row
    pairs = []
    for group in GROUPS:
        for theme in THEMES:
            states = [] if group == 'crop' else [f'profile-{group}-top', f'profile-{group}-bottom']
            if group == 'menu' and ('profile-menu-destinations', theme) in native_states:
                states.insert(1, 'profile-menu-destinations')
            if group == 'crop' and crop_states:
                states = ['profile-avatar-crop-top', 'profile-avatar-crop-controls']
            pairs.append({'group': group, 'theme': theme, 'web': WEB_STATES[group], 'native': states})
    reviewed_pairs = receipt.get('pairs')
    if (not isinstance(reviewed_pairs, list) or len(reviewed_pairs) != len(pairs) or
            sorted(json.dumps(row, sort_keys=True) for row in reviewed_pairs) !=
            sorted(json.dumps(row, sort_keys=True) for row in pairs)):
        raise Invalid('The reviewed pair mapping differs from the actual complete capture set/order')
    review = {'status': 'not_supplied', 'visualAcceptanceClaimedByViewer': False}
    if args.root_review:
        value, review_sha = object_file(args.root_review)
        sources = value.get('sources', {})
        if (value.get('status') != 'reviewed' or value.get('hap', {}).get('packagedSha256') != hap or
                sources.get('native', {}).get('sha256') != native_sha or sources.get('web', {}).get('sha256') != web_sha):
            raise Invalid('An explicitly supplied root review is stale or refers to different capture sources')
        review = {'status': 'matching_root_review_supplied', 'sha256': review_sha, 'visualAcceptanceClaimedByViewer': False}
    metadata = {'status': 'prepared_for_local_review', 'visualAcceptance': 'not_evaluated_by_viewer',
        'sources': expected, 'pairingReceiptSha256': receipt_sha, 'webStateCount': len(web_states),
        'nativeStateCount': len(native_states), 'nativeCropCount': len(crop_states), 'nativeCropReportSha256': crop_report_sha, 'pairs': pairs,
        'webMode': 'Frozen Web source; intercepted private snapshot replay; synthetic login/token drivers; no real browser backend',
        'nativeMode': 'Actual ArkUI screenshots; dedicated real HTTPS backend; capture success is separate from visual review',
        'approvedPlatformDifferences': ['Official ArkUI immersive light/material, native controls, feedback and motion are approved platform differences'],
        'rootReview': review, 'window': metrics(native.get('window', {}),
            ('widthPx', 'heightPx', 'density', 'fontScale', 'topInsetPx', 'bottomInsetPx')),
        'webViewport': metrics(web.get('viewport', {}), ('width', 'height', 'deviceScaleFactor')),
        'originalScreenshotsUnedited': True, 'browserOrDeviceStartedDuringPreparation': False}
    images = {}
    for (state, theme), row in web_states.items():
        if row.get('documentFitsWidth') is not True:
            raise Invalid('A supplied Web capture did not fit its actual viewport')
        add_image(images, 'web-' + state + '-' + theme, row,
                  [web['viewport']['width'], web['viewport']['height']])
    for (state, theme), row in native_states.items():
        if row.get('actualThemeVerified') is not True:
            raise Invalid('A supplied native capture lacks actual theme evidence')
        add_image(images, 'native-' + state + '-' + theme, row, row.get('pixels'))
    for (theme, position), row in crop_states.items():
        add_image(images, 'native-profile-avatar-crop-' + position + '-' + theme,
                  {'screenshot': row.get('file'), 'screenshotSha256': row.get('sha256')},
                  [runtime['window']['widthPx'], runtime['window']['heightPx']])
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    if (PRIVATE.is_symlink() or DESTINATION.is_symlink() or
            DESTINATION.exists() and (not DESTINATION.is_dir() or DESTINATION.resolve().parent != PRIVATE.resolve())):
        raise Invalid('Private comparison output directory cannot be a symlink or escape the private root')
    DESTINATION.mkdir(exist_ok=True, mode=0o700)
    if DESTINATION.stat().st_uid != os.getuid():
        raise Invalid('Private comparison output must be owned by this user')
    DESTINATION.chmod(0o700)
    directory = DESTINATION / ('review-' + stamp)
    directory.mkdir(parents=True, exist_ok=False, mode=0o700)
    directory.chmod(0o700)
    (directory / 'assets').mkdir(mode=0o700)
    files = []
    for route, record in images.items():
        relative = route[1:]
        write_private(directory / relative, record['bytes'])
        files.append({'route': route, 'file': relative, 'sha256': digest(record['bytes']),
                      'bytes': len(record['bytes']), 'mime': 'image/png', 'pixels': record['pixels']})
    for route, data, mime in (('/index.html', render(metadata).encode(), 'text/html; charset=utf-8'),
                              ('/metadata.json', json_bytes(metadata), 'application/json; charset=utf-8')):
        write_private(directory / route[1:], data)
        files.append({'route': route, 'file': route[1:], 'sha256': digest(data), 'bytes': len(data), 'mime': mime})
    manifest = {'formatVersion': 1, 'status': 'prepared_for_local_review', 'driverSha256': digest(Path(__file__).read_bytes()),
        'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'files': files, 'metadata': metadata}
    path = directory / 'manifest.json'
    write_private(path, json_bytes(manifest))
    print(json.dumps({'status': 'prepared_for_local_review', 'manifest': str(path.relative_to(ROOT)),
        'manifestSha256': digest(json_bytes(manifest)), 'pngCount': len(images), 'serverStarted': False,
        'visualAcceptance': 'not_evaluated_by_viewer'}, ensure_ascii=False))


def add_image(images, name, row, dimensions=None):
    route = '/assets/' + name + '.png'
    if not ASSET.fullmatch(route) or route in images or not isinstance(row.get('screenshot'), str):
        raise Invalid('Image identity is missing, duplicated or outside the fixed route allowlist')
    value = regular_bytes(ROOT / row['screenshot'])
    actual = png(value, row.get('screenshotSha256'))
    if dimensions is not None and actual != dimensions:
        raise Invalid('Native screenshot dimensions differ from its actual runtime/capture record')
    images[route] = {'bytes': value, 'pixels': actual}


def render(metadata):
    escape = lambda value: html.escape(str(value), quote=True)
    links, sections = [], []
    for pair in metadata['pairs']:
        group, theme = pair['group'], pair['theme']
        identifier = group + '-' + theme
        title = LABELS[group] + ' · ' + ('深色' if theme == 'dark' else '浅色')
        links.append('<a href="#' + identifier + '">' + title + '</a>')
        figures = []
        for kind, state in [('web', pair['web']), *[('native', state) for state in pair['native']]]:
            route = '/assets/' + kind + '-' + state + '-' + theme + '.png'
            label = 'Web · 完整截图' if kind == 'web' else 'Native · ' + ('顶部' if state.endswith('-top') else '底部' if state.endswith('-bottom') else '入口补充' if state.endswith('-destinations') else '裁剪操作区完整截图')
            figures.append('<figure><figcaption>' + label + '</figcaption><a target="_blank" rel="noopener noreferrer" href="' + route + '"><img loading="lazy" src="' + route + '" alt="' + escape(title + ' ' + label) + '"></a></figure>')
        if not pair['native']:
            figures.append('<div class="missing">原生裁剪此主题尚未采集。不会替用历史截图。</div>')
        sections.append('<section id="' + identifier + '"><h2>' + title + '</h2><div class="grid">' + ''.join(figures) + '</div></section>')
    source = metadata['sources']
    fields = [('Native HAP', source['nativeHapSha256']), ('Native runtime', source['nativeRuntimeSha256']),
              ('Web 原仓库 HEAD', source['webSourceCommit']), ('快照 SHA', source['snapshotSha256']),
              ('Web 报告 SHA', source['webReportSha256']), ('Native 报告 SHA', source['nativeReportSha256']),
              ('配对回执 SHA', metadata['pairingReceiptSha256'])]
    details = ''.join('<dt>' + key + '</dt><dd><code>' + escape(value) + '</code></dd>' for key, value in fields)
    viewport, window = metadata['webViewport'], metadata['window']
    geometry = ('Web ' + str(viewport['width']) + ' × ' + str(viewport['height']) + ' CSS px；Native ' +
        str(window['widthPx']) + ' × ' + str(window['heightPx']) + ' px，density ' + str(window['density']) +
        '，fontScale ' + str(window['fontScale']) + '，上下避让 ' + str(window['topInsetPx']) + ' / ' + str(window['bottomInsetPx']) + ' px。')
    review = '已提供同来源 SHA 的 root-review；具体结论另查原审阅记录。' if metadata['rootReview']['status'] == 'matching_root_review_supplied' else '尚未提供与本次来源绑定的 root-review；此页用于审阅，不给出视觉通过结论。'
    return ('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>Task1 · 资料视觉对照</title><style>' + STYLE + '</style><main><h1>Task1 · 资料视觉对照</h1>'
        '<p class="tag">仅本机 5180 · 原始完整截图 · 点击图片查看原尺寸</p><div class="notice">'
        '<p>Web 使用冻结源码、私有真实快照回放与合成登录/API 驱动；浏览器未联调真实后端。</p>'
        '<p>Native 为实际 ArkUI 真机截图与专用 HTTPS 环境。采集成功不等于视觉验收通过。</p>'
        '<p>已批准的平台差异包括官方沉浸光感、原生材质、通用控件、反馈与动效；具体布局、文案与逐状态视觉结论以 root-review 为准。</p>'
        '<p>快照对应关系与裁剪主题由 root 的私有配对回执复核绑定。</p><p>' + review + '</p></div><dl>' + details + '</dl><p class="muted">' + escape(geometry) + '</p><p class="muted">图片保持原字节与完整边界，不遮挡、不裁剪、不编辑。原生状态栏与手势避让按实际运行时单独记录。</p><nav>' + ''.join(links) + '</nav>' + ''.join(sections) + '</main></html>')


def prepared_files(path):
    raw = regular_bytes(path, DESTINATION, True, 4 * 1024 * 1024)
    manifest = json.loads(raw)
    directory = path.absolute().parent
    if (manifest.get('formatVersion') != 1 or manifest.get('status') != 'prepared_for_local_review' or
            manifest.get('driverSha256') != digest(Path(__file__).read_bytes()) or not isinstance(manifest.get('files'), list)):
        raise Invalid('Prepared manifest/driver provenance is not current')
    output = {}
    for record in manifest['files']:
        route, relative = record.get('route'), record.get('file')
        if (route not in ('/index.html', '/metadata.json') and not ASSET.fullmatch(route or '') or
                relative != route[1:] or route in output):
            raise Invalid('Prepared manifest contains an unapproved route or path')
        value = regular_bytes(directory / relative, DESTINATION)
        expected_mime = 'image/png' if route.startswith('/assets/') else 'text/html; charset=utf-8' if route == '/index.html' else 'application/json; charset=utf-8'
        if digest(value) != record.get('sha256') or len(value) != record.get('bytes') or record.get('mime') != expected_mime:
            raise Invalid('A prepared asset changed before server startup')
        if route.startswith('/assets/'):
            png(value, record['sha256'])
        output[route] = (value, expected_mime)
    required = {'/index.html', '/metadata.json'} | {
        '/assets/web-' + value + '-' + theme + '.png' for value in WEB_STATES.values() for theme in THEMES} | {
        '/assets/native-profile-' + group + '-' + position + '-' + theme + '.png'
        for group in ('identity', 'security', 'menu') for position in ('top', 'bottom') for theme in THEMES}
    optional = {'/assets/native-profile-' + state + '-' + theme + '.png'
                for state in ('menu-destinations', 'avatar-crop-top', 'avatar-crop-controls') for theme in THEMES}
    crop_routes = {'/assets/native-profile-avatar-crop-' + position + '-' + theme + '.png'
                   for position in ('top', 'controls') for theme in THEMES}
    if (not required.issubset(output) or not set(output).issubset(required | optional) or
            set(output) & crop_routes not in (set(), crop_routes)):
        raise Invalid('The prepared complete comparison allowlist is missing')
    if json.loads(output['/metadata.json'][0]) != manifest.get('metadata'):
        raise Invalid('Prepared safe metadata and its manifest differ')
    # Retain verified immutable bytes, not file descriptors or directory access.
    return output, digest(raw)


def requested_route(raw):
    try:
        parsed = urlsplit(raw)
        if parsed.scheme or parsed.netloc or '?' in raw or '#' in raw:
            return None
        path = unquote(parsed.path, encoding='utf-8', errors='strict')
    except (ValueError, UnicodeError):
        return None
    if (not path.startswith('/') or '%' in path or '\\' in path or
            any(ord(char) < 32 or ord(char) == 127 for char in path)):
        return None
    if path == '/':
        return '/index.html'
    if any(part in ('', '.', '..') for part in path[1:].split('/')):
        return None
    return path


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, files, port=PORT):
        self.files = files
        super().__init__(('127.0.0.1', port), Handler)


class Handler(BaseHTTPRequestHandler):
    server_version, sys_version = 'StarwardProfileComparison', ''

    def log_message(self, *args):
        pass

    def log_error(self, *args):
        pass

    def send_error(self, *args, **kwargs):
        self.missing()

    def reply(self, code, value, mime):
        self.send_response(code)
        for name, item in {'Content-Type': mime, 'Content-Length': str(len(value)), 'Cache-Control': 'no-store',
            'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'no-referrer',
            'Cross-Origin-Resource-Policy': 'same-origin', 'Cross-Origin-Opener-Policy': 'same-origin',
            'Content-Security-Policy': CSP}.items():
            self.send_header(name, item)
        self.end_headers()
        if self.command != 'HEAD':
            try:
                self.wfile.write(value)
            except (BrokenPipeError, ConnectionResetError):
                pass

    def missing(self):
        self.reply(404, b'Not found\n', 'text/plain; charset=utf-8')

    def serve(self):
        port = self.server.server_address[1]
        hosts = self.headers.get_all('Host', [])
        if len(hosts) != 1 or hosts[0] not in (f'127.0.0.1:{port}', f'localhost:{port}'):
            return self.missing()
        record = self.server.files.get(requested_route(self.path))
        if record is None:
            return self.missing()
        self.reply(200, *record)

    do_GET = do_HEAD = serve
    do_POST = do_PUT = do_PATCH = do_DELETE = do_OPTIONS = do_TRACE = do_CONNECT = missing


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--prepare', action='store_true', help='Validate actual inputs and copy original QA PNG bytes; do not start a server')
    parser.add_argument('--pairing-receipt', type=Path)
    parser.add_argument('--web-report', type=Path, default=PROFILE / 'web-profile-visual.json')
    parser.add_argument('--native-report', type=Path, default=PROFILE / 'native-profile-visual.json')
    parser.add_argument('--native-crop-report', type=Path, default=PROFILE / 'native-avatar-crop-visual.json',
                        help='Only read when the reviewed receipt provides all four original crop top/controls PNGs')
    parser.add_argument('--root-review', type=Path)
    parser.add_argument('--manifest', type=Path, help='Previously prepared private manifest; serves only its frozen allowlist')
    args = parser.parse_args()
    if args.prepare and (not args.pairing_receipt or args.manifest):
        parser.error('--prepare requires --pairing-receipt and cannot be combined with --manifest')
    if not args.prepare and not args.manifest:
        parser.error('Provide --prepare or the previously prepared --manifest')
    try:
        if args.prepare:
            build(args)
            return 0
        files, manifest_sha = prepared_files(args.manifest)
        server = Server(files)
        print(json.dumps({'status': 'serving_local_review_inputs', 'url': f'http://127.0.0.1:{PORT}/index.html',
            'manifestSha256': manifest_sha, 'bind': '127.0.0.1', 'visualAcceptance': 'not_evaluated_by_viewer'}, ensure_ascii=False), flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            server.server_close()
        return 0
    except Exception:
        print(json.dumps({'status': 'not_prepared_or_started',
            'error': 'Actual complete source/provenance/pairing/allowlist checks failed; no fallback or historical mixing',
            'visualAcceptance': 'not_evaluated_by_viewer'}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

#!/usr/bin/env python3
"""Measure final auth controls against frozen Web DOM without editing images."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.parse_args()


def digest(path):
    if path.is_symlink() or not path.is_file():
        raise SystemExit('Measurement source must be an ordinary file')
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path):
    return str(path.relative_to(ROOT))


def read(path):
    digest(path)
    return json.loads(path.read_text())


native = ROOT / 'artifacts/native-system-visual'
capture_path = native / 'auth-capture-summary.json'
capture = read(capture_path)
hap_path = ROOT / 'artifacts/validation/native-system-visual-hap.json'
hap = read(hap_path)
window = capture.get('window', {})
runtime_path = ROOT / 'artifacts/validation/native-system-runtime.json'
runtime = read(runtime_path)
expected = {(state, theme) for state in ('login', 'forced-password') for theme in ('light', 'dark')}
states = capture.get('states', [])
if (capture.get('status') != 'captured' or capture.get('count') != 4 or len(states) != 4
        or {(s.get('state'), s.get('theme')) for s in states} != expected
        or capture.get('visualCriteria') != 'arkui-system-v1'
        or capture.get('immersionVersion') != 'edge-to-edge-v1'
        or capture.get('hap', {}).get('sha256') != hap.get('sha256')
        or capture['hap'].get('source') != relative(hap_path)
        or capture['hap'].get('sourceSha256') != digest(hap_path)
        or capture['hap'].get('immersionVersion') != 'edge-to-edge-v1'
        or hap.get('immersionVersion') != 'edge-to-edge-v1'):
    raise SystemExit('A complete final-HAP-bound auth capture is required')
index = window.get('sourceRecord')
if (window.get('source') != relative(runtime_path)
        or window.get('sourceSha256') != digest(runtime_path)
        or not isinstance(index, int) or isinstance(index, bool)
        or not 0 <= index < len(runtime.get('records', []))
        or any(runtime['records'][index].get(key) != window.get(key)
               for key in ('widthPx', 'heightPx', 'density', 'topInsetPx', 'bottomInsetPx'))):
    raise SystemExit('The measured runtime window source is not current')
for item in states:
    if (item.get('themeVerified') is not True or item.get('visibleInputsEmpty') is not True
            or item.get('screenshot') != item['state'] + '-' + item['theme'] + '.png'
            or item.get('uiTree') != 'ui-' + item['state'] + '-' + item['theme'] + '.json'
            or item.get('screenshotSha256') != digest(native / item['screenshot'])):
        raise SystemExit('Blank auth image capture provenance does not match')
    digest(native / item['uiTree'])

login_web = ROOT / 'artifacts/web-isolated-content'
forced_web = ROOT / 'artifacts/web-isolated-forced'
for directory, state in ((login_web, 'login'), (forced_web, 'forced-password')):
    summary = read(directory / 'capture-summary.json')
    if (summary.get('sourceCommit') != '4b7d1a0a00051ac630e459b0fd6c074f821d7455'
            or summary.get('viewport') != {'width': 391, 'height': 777}
            or summary.get('pageErrors') or summary.get('browserUsesRealBackend') is not False):
        raise SystemExit('The frozen Web replay metadata does not match')
    source = summary['snapshotInput']
    if (digest(ROOT / source['file']) != source.get('sha256')
            or digest(ROOT / 'artifacts/private/web-visual-inputs' / (source['sha256'] + '.json')) != source['sha256']):
        raise SystemExit('The Web input is no longer the capture-time snapshot')
    for theme in ('light', 'dark'):
        item = next((s for s in summary['states'] if s.get('state') == state and s.get('theme') == theme), {})
        if item.get('screenshotSha256') != digest(directory / (state + '-' + theme + '.png')):
            raise SystemExit('The Web auth PNG capture hash does not match')

login_output = ROOT / 'artifacts/validation/edge-login-layout.json'
subprocess.run([sys.executable, str(ROOT / 'scripts/measure-native-login.py'),
                '--native', relative(native), '--web', relative(login_web),
                '--output', relative(login_output), '--window-report', relative(capture_path)],
               cwd=ROOT, check=True, capture_output=True, text=True)
login = read(login_output)
login.update({'measuredAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'immersionVersion': capture['immersionVersion'], 'hap': capture['hap'],
              'webCaptureReport': relative(login_web / 'capture-summary.json'),
              'webCaptureReportSha256': digest(login_web / 'capture-summary.json'),
              'uiTreeHashScope': 'Current original UiTest bytes at measurement time; auth capture does not record capture-time UiTest hashes.'})
login_output.write_text(json.dumps(login, ensure_ascii=False, indent=2) + '\n')


def frames(tree):
    result = {}

    def walk(value):
        if isinstance(value, list):
            for item in value:
                walk(item)
        elif isinstance(value, dict):
            if value.get('id') in ('old-password', 'new-password', 'confirm-password', 'primary-action'):
                result[value['id']] = value['bounds']
            for item in value.get('children', []):
                walk(item)

    walk(tree)
    return result


forced = {'visualCriteria': capture['visualCriteria'], 'immersionVersion': capture['immersionVersion'],
          'measuredAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'hap': capture['hap'], 'window': window,
          'nativeCaptureReport': relative(capture_path), 'nativeCaptureReportSha256': digest(capture_path),
          'webCaptureReport': relative(forced_web / 'capture-summary.json'),
          'webCaptureReportSha256': digest(forced_web / 'capture-summary.json'),
          'geometryMeaning': 'Actual UiTest component frames vs same-font frozen Web DOM rectangles after removing measured top inset; not painted-edge or typography equality.',
          'uiTreeHashScope': 'Current original UiTest bytes at measurement time; auth capture does not record capture-time UiTest hashes.',
          'provenance': {}, 'rows': [],
          'limitations': ['Original physical PNG files remain unchanged. Content coordinates support layout comparison; inspect the full image for immersive system areas.',
                         'This measurement does not establish spoken-reader, dynamic theme, animation, IME or larger-font acceptance.']}
for theme in ('light', 'dark'):
    ui_path = native / ('ui-forced-password-' + theme + '.json')
    png_path = native / ('forced-password-' + theme + '.png')
    web_path = forced_web / ('forced-password-' + theme + '.json')
    bounds = frames(read(ui_path))
    measurements = read(web_path)['measurements']
    forced['provenance'][theme] = {relative(p): digest(p) for p in (ui_path, png_path, web_path)}
    for control, name in (('old-password', 'passwordCurrent'), ('new-password', 'passwordNew'),
                          ('confirm-password', 'passwordConfirm'), ('primary-action', 'authSubmit')):
        b = bounds[control]
        native_rect = [b[0] / window['density'], (b[1] - window['topInsetPx']) / window['density'],
                       (b[2] - b[0]) / window['density'], (b[3] - b[1]) / window['density']]
        web_rect = [measurements[name][key] for key in ('x', 'y', 'width', 'height')]
        forced['rows'].append({'theme': theme, 'control': control, 'nativeBoundsPx': b,
                               'nativeContentVp': native_rect, 'webCssPx': web_rect,
                               'nativeMinusWeb': [a - b for a, b in zip(native_rect, web_rect)]})
forced['maxAbsVerticalDifferenceVp'] = max(abs(row['nativeMinusWeb'][1]) for row in forced['rows'])
forced_output = ROOT / 'artifacts/validation/edge-forced-layout.json'
forced_output.write_text(json.dumps(forced, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'hapSha256': hap['sha256'], 'login': relative(login_output), 'forced': relative(forced_output),
                  'loginMaxAbsVerticalDifferenceVp': max(abs(r['nativeMinusWeb'][1]) for t in login['themes'] for r in t['rectangles']),
                  'forcedMaxAbsVerticalDifferenceVp': forced['maxAbsVerticalDifferenceVp']}))

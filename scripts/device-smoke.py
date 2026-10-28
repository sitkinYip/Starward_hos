#!/usr/bin/env python3
"""Official CLI/UiTest smoke for the explicitly labelled, in-memory demo only."""
import json
import hashlib
from pathlib import Path
import statistics
import struct
import time
import zlib

from native_device_ui import DeviceUI, SafeFailure

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/validation'
SHOTS = ROOT / 'artifacts/screenshots'
ui = DeviceUI(OUT, SHOTS)
checks = []
screenshots = []
theme_samples = []


def check(condition, label):
    if not condition:
        raise SafeFailure(label)
    checks.append(label)


def shot(name):
    target = ui.screenshot(name)
    screenshots.append(target.name)
    return target


def png_pixels(path):
    """Read official screenshot RGB/RGBA PNGs without an external image package."""
    try:
        from PIL import Image
    except ImportError:
        Image = None
    if Image is not None:
        with Image.open(path) as image:
            image = image.convert('RGB')
            width, height = image.size
            raw = image.tobytes()
            stride = width * 3
            return width, height, 3, [memoryview(raw)[y * stride:(y + 1) * stride] for y in range(height)]
    data = Path(path).read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise SafeFailure('Theme screenshot is not a PNG')
    offset, compressed = 8, bytearray()
    width = height = channels = 0
    while offset < len(data):
        length = struct.unpack_from('>I', data, offset)[0]
        kind = data[offset + 4:offset + 8]
        chunk = data[offset + 8:offset + 8 + length]
        offset += 12 + length
        if kind == b'IHDR':
            width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', chunk)
            if depth != 8 or color not in (2, 6) or compression or filtering or interlace:
                raise SafeFailure('Theme screenshot PNG format is unsupported')
            channels = 3 if color == 2 else 4
        elif kind == b'IDAT':
            compressed.extend(chunk)
        elif kind == b'IEND':
            break
    if not width or not height or not channels:
        raise SafeFailure('Theme screenshot PNG has no image header')
    decoded = zlib.decompress(compressed)
    stride = width * channels
    if len(decoded) != (stride + 1) * height:
        raise SafeFailure('Theme screenshot PNG has an unexpected image length')
    rows, previous = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        filtering = decoded[start]
        row = bytearray(decoded[start + 1:start + 1 + stride])
        if filtering not in range(5):
            raise SafeFailure('Theme screenshot PNG filter is unsupported')
        for x in range(stride):
            left = row[x - channels] if x >= channels else 0
            above = previous[x]
            upper_left = previous[x - channels] if x >= channels else 0
            if filtering == 1:
                predictor = left
            elif filtering == 2:
                predictor = above
            elif filtering == 3:
                predictor = (left + above) // 2
            elif filtering == 4:
                estimate = left + above - upper_left
                distances = (abs(estimate - left), abs(estimate - above), abs(estimate - upper_left))
                predictor = (left, above, upper_left)[distances.index(min(distances))]
            else:
                predictor = 0
            row[x] = (row[x] + predictor) & 255
        rows.append(row)
        previous = row
    return width, height, channels, rows


def verify_theme(name, expected):
    button_id = 'theme-' + name
    control = ui.seek(button_id)
    if control.get('type') != 'Button' or not control.get('clickable'):
        raise SafeFailure('Expected named theme control is not an actionable button')
    ui.tap(button_id)
    ui.wait(lambda state: state.find('account') is not None, 'theme keeps the login form available')
    time.sleep(.35)
    ui.seek('account')
    ui.capture(name)
    if not ui.find('environment-badge') or ui.find('environment-badge').get('text') != '演示环境':
        raise SafeFailure('Theme assertion requires the explicitly labelled mock environment')
    left, top, right, bottom = ui.find('account')['bounds']
    if left < 8 or bottom <= top or right <= left:
        raise SafeFailure('Theme canvas sample cannot be located outside the input')
    # Sample the blank canvas gutter beside the known input, away from text and the atlas.
    x, y = left // 2, (top + bottom) // 2
    target = shot('login-' + name)
    width, height, channels, rows = png_pixels(target)
    if x < 2 or y < 2 or x + 2 >= width or y + 2 >= height:
        raise SafeFailure('Theme sample is outside the screenshot')
    observed = [int(statistics.median(rows[py][px * channels + channel]
                                    for py in range(y - 2, y + 3)
                                    for px in range(x - 2, x + 3)))
                for channel in range(3)]
    theme_samples.append({'theme': name, 'control': button_id, 'canvasRGB': observed,
                          'expectedRGB': list(expected), 'sample': [x, y]})
    check(all(abs(actual - wanted) <= 4 for actual, wanted in zip(observed, expected)),
          'App renders the ' + name + ' canvas after explicit theme selection')


def login():
    ui.fill('account', 'alice')
    ui.fill('password', 'Starward1234')
    ui.tap('primary-action')


try:
    ui.launch(cold=True)
    ui.wait(lambda state: state.find('environment-badge') is not None, 'initial login environment', save='login')
    check(ui.find('environment-badge').get('text') == '演示环境' and ui.find('account') is not None,
          'App identifies the isolated demo environment before any credential entry')
    ui.back()
    # Root Back may close the Ability. Relaunch keeps the in-memory demo mode explicit.
    ui.launch()
    ui.wait(lambda state: state.find('account') is not None, 'login after root Back', save='root-return')
    check(not ui.has_text('下一段故事，等你落笔。'),
          'System Back cannot reveal protected home before authentication')
    login()
    ui.wait(lambda state: state.find('old-password') is not None, 'mandatory password change', save='forced-password')
    check(ui.has_text('首次登录，请先修改密码'), 'Successful demo login reaches mandatory password change')
    shot('forced-password')
    ui.fill('old-password', 'Starward1234')
    ui.fill('new-password', 'NewStarward1234')
    ui.fill('confirm-password', 'NewStarward1234')
    ui.tap('primary-action')
    ui.wait(lambda state: state.find('account-menu') is not None, 'native home', save='home')
    check(ui.has_text('下一段故事，等你落笔。'), 'Password change unlocks the native home')
    ui.tap('account-menu')
    ui.wait(lambda state: state.find('logout') is not None, 'authenticated native passport Sheet')
    check(ui.has_text('远航者'), 'Passport renders the authenticated player')
    ui.back()
    ui.wait(lambda state: state.find('logout') is None, 'native Sheet Back dismissal')
    ui.seek('assignment-assignment1')
    check(ui.has_text('星辰探险'), 'Home renders the assigned chapter')
    shot('home')
    ui.tap('assignment-assignment1')
    ui.wait(lambda state: state.find('start-assignment') is not None, 'read-only assignment detail', save='detail')
    check(ui.has_text('星辰探险') and ui.has_text('2 道等待解开'),
          'Native destination renders read-only assignment projection')
    # UiTest includes visible nodes only; seek the disabled CTA before checking the scope note.
    ui.seek('start-assignment')
    ui.capture()
    check(ui.has_text('此切片仅查看场次，暂不支持开始冒险。') and not ui.find('start-assignment').get('clickable'),
          'Read-only scope is visible and the start command is disabled')
    shot('detail')
    ui.back()
    ui.wait(lambda state: state.find('current-tab') is not None, 'home after detail Back', save='detail-back')
    check(ui.has_text('下一段故事，等你落笔。'), 'System Back from detail returns to home')
    ui.tap('history-tab')
    ui.wait(lambda state: state.has_text('故事的第一页，还空着。'), 'history empty state', save='history')
    check(ui.has_text('完成一场冒险，就会在这里留下你的足迹。'), 'History shows its distinct empty state')
    shot('history')
    ui.tap('current-tab')
    ui.tap('account-menu')
    ui.wait(lambda state: state.find('logout') is not None, 'logout in account menu')
    ui.tap('logout')
    ui.wait(lambda state: state.find('account') is not None, 'login after logout', save='logout')
    check(ui.has_text('以你的名字，开启冒险。') and not ui.has_text('远航者'),
          'Logout removes protected content and returns to login')
    verify_theme('dark', (16, 17, 15))
    verify_theme('light', (255, 255, 255))
    if len(checks) != 13:
        raise SafeFailure('The smoke report did not contain all 13 required checks')
    result = {'status': 'passed', 'visualCriteria': 'arkui-system-v1', 'immersionVersion': 'edge-to-edge-v1',
              'installedHapSha256': hashlib.sha256((ROOT/'entry/build/default/outputs/default/entry-default-signed.hap').read_bytes()).hexdigest(), 'checks': checks, 'count': len(checks),
              'environment': 'in-memory mock on API26 physical device',
              'screenshots': screenshots, 'themeSamples': theme_samples,
              'notes': 'CLI UiTest operations; not a Hypium instrument-test report or production/network acceptance.'}
except Exception as error:
    # Do not expose command output, input values, or arbitrary exception details.
    message = str(error) if isinstance(error, SafeFailure) else 'Smoke helper failed before acceptance completed'
    result = {'status': 'failed', 'checks': checks, 'count': len(checks), 'error': message,
              'themeSamples': theme_samples}
    (OUT / 'device-smoke.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(1)
(OUT / 'device-smoke.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(result, ensure_ascii=False))

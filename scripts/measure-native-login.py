#!/usr/bin/env python3
"""Read native PNG pixels and UiTest frames; preserve a login comparison record."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--native', type=Path, default=ROOT / 'artifacts/native-https-visual')
parser.add_argument('--web', type=Path, default=ROOT / 'artifacts/web-content-login-reference')
parser.add_argument('--output', type=Path, default=ROOT / 'artifacts/validation/login-visual-comparison.json')
parser.add_argument('--window-report', type=Path, help='Capture report containing this run\'s measured window; required for the official ArkUI visual set')
args = parser.parse_args()
for name in ('native', 'web', 'output'):
    value = getattr(args, name)
    setattr(args, name, (value if value.is_absolute() else ROOT / value).resolve())


def read_png(path):
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Expected an original PNG screenshot')
    offset, compressed = 8, bytearray()
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        tag = data[offset + 4:offset + 8]
        chunk = data[offset + 8:offset + 8 + length]
        offset += length + 12
        if tag == b'IHDR':
            width, height, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', chunk)
        elif tag == b'IDAT':
            compressed.extend(chunk)
    if depth != 8 or color not in (2, 6) or interlace != 0:
        raise ValueError('Expected non-interlaced 8-bit RGB/RGBA screenshot')
    channels = 3 if color == 2 else 4
    stride = width * channels
    raw = zlib.decompress(compressed)
    rows, previous, offset = [], bytearray(stride), 0
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        row = bytearray(raw[offset:offset + stride])
        offset += stride
        for x in range(stride):
            a = row[x - channels] if x >= channels else 0
            b = previous[x]
            c = previous[x - channels] if x >= channels else 0
            if filter_type == 0:
                prediction = 0
            elif filter_type == 1:
                prediction = a
            elif filter_type == 2:
                prediction = b
            elif filter_type == 3:
                prediction = (a + b) // 2
            elif filter_type == 4:
                value = a + b - c
                pa, pb, pc = abs(value - a), abs(value - b), abs(value - c)
                prediction = a if pa <= pb and pa <= pc else b if pb <= pc else c
            else:
                raise ValueError('Unsupported PNG filter')
            row[x] = (row[x] + prediction) % 256
        rows.append(row)
        previous = row
    return width, height, channels, rows


def star_pixels(path, theme, density, top):
    width, height, channels, rows = read_png(path)
    # The expected complete star path has no text in this ROI. Color thresholds
    # isolate its .22-opacity fill from the fainter circles/axes; pixels are read,
    # never rewritten. This method is specific to the frozen login color tokens.
    roi = [int(250 * density), int(130 * density + top), int(370 * density), int(240 * density + top)]
    points = []
    for y in range(roi[1], roi[3]):
        for x in range(roi[0], roi[2]):
            red, green, blue = rows[y][x * channels:x * channels + 3]
            selected = (190 < red < 225 and green - red >= 8 and green - blue >= 1) if theme == 'light' else (47 <= red <= 60 and 44 <= green <= 58 and red - green >= 3 and green - blue >= 9)
            if selected:
                points.append((x, y))
    if not points:
        raise ValueError('Expected complete Atlas star was not found in the comparison ROI')
    left, right = min(x for x, _ in points), max(x for x, _ in points) + 1
    y_top, bottom = min(y for _, y in points), max(y for _, y in points) + 1
    if left <= roi[0] or right >= roi[2] or y_top <= roi[1] or bottom >= roi[3]:
        raise ValueError('Star mask touches ROI boundary; do not treat a clipped path as verified')
    return {'imagePx':[width,height], 'roiPx':roi, 'selectedPixels':len(points), 'pathRasterBoundsPx':[left,y_top,right,bottom],
            'pathCenterVp':[(left + right) / 2 / density, ((y_top + bottom) / 2 - top) / density],
            'pathSizeVp':[(right - left) / density, (bottom - y_top) / density],
            'method':'Read-only PNG decode; threshold .22-opacity star fill in a text-free ROI, excluding fainter rings/axes; <=1px antialias edge uncertainty'}


def find_frames(tree):
    found = {}
    def visit(value):
        if isinstance(value, list):
            for item in value:
                visit(item)
        elif isinstance(value, dict):
            key = value.get('id')
            if key in ('account', 'password', 'primary-action'):
                found[key] = value['bounds']
            if value.get('text') == '以你的名字，开启冒险。':
                found['title'] = value['bounds']
            for item in value.get('children', []):
                visit(item)
    visit(tree)
    return found


window_report = args.window_report
if window_report is not None:
    window_report = (window_report if window_report.is_absolute() else ROOT / window_report).resolve()
elif args.native.name == 'native-system-visual':
    window_report = args.native / 'auth-capture-summary.json'
else:
    window_report = ROOT / 'artifacts/validation/native-tls-and-metrics.json'
record = json.loads(window_report.read_text())
window = record['window']
if args.native.name == 'native-system-visual' and (record.get('visualCriteria') != 'arkui-system-v1' or record.get('status') != 'captured'):
    raise SystemExit('Current official ArkUI login measurement requires its completed capture report')
if 'source' in window:
    source = ROOT / window['source']
    if window['source'] != 'artifacts/validation/native-system-runtime.json' or source.is_symlink() or hashlib.sha256(source.read_bytes()).hexdigest() != window.get('sourceSha256'):
        raise SystemExit('Measured window source hash is not current')
    source_record = json.loads(source.read_text())['records'][window['sourceRecord']]
    if any(source_record.get(key) != window[key] for key in ('widthPx','heightPx','density','topInsetPx','bottomInsetPx')):
        raise SystemExit('Measured window source record differs')
density, top = window['density'], window['topInsetPx']
result = {'window':window, 'webGroup':str(args.web.relative_to(ROOT)), 'nativeGroup':str(args.native.relative_to(ROOT)),
          'windowReport':str(window_report.relative_to(ROOT)), 'windowReportSha256':hashlib.sha256(window_report.read_bytes()).hexdigest(),
          'visualCriteria':record.get('visualCriteria','legacy-web-alignment'),
          'webDataScope':'Login layout only; no form submission or player/assignment DTO consumption. Browser API request list is empty.',
          'geometryMeaning':'UiTest component frames vs DOM rectangles; painted edges may differ.', 'themes':[]}
for theme in ('light', 'dark'):
    image_file = args.native / f'login-{theme}.png'
    ui_file = args.native / f'ui-login-{theme}.json'
    frames = find_frames(json.loads(ui_file.read_text()))
    web = json.loads((args.web / f'login-{theme}.json').read_text())['measurements']
    rectangles = []
    for name, web_name in [('title','loginTitle'),('account','loginAccount'),('password','loginPassword'),('primary-action','authSubmit')]:
        b = frames[name]
        native = [b[0]/density,(b[1]-top)/density,(b[2]-b[0])/density,(b[3]-b[1])/density]
        web_rect = [web[web_name][key] for key in ('x','y','width','height')]
        rectangles.append({'element':name,'nativeBoundsPx':b,'nativeContentVp':native,'webCssPx':web_rect,'nativeMinusWeb':[a-b for a,b in zip(native,web_rect)]})
    star = star_pixels(image_file,theme,density,top)
    web_star = web['authAtlasStar']
    star['webPathCenterCssPx'] = [web_star['x']+web_star['width']/2,web_star['y']+web_star['height']/2]
    star['centerDifferenceVp'] = [a-b for a,b in zip(star['pathCenterVp'],star['webPathCenterCssPx'])]
    result['themes'].append({'theme':theme,'rectangles':rectangles,'atlasPaint':star,
                            'provenance':{p.name:{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'mtime':datetime.datetime.fromtimestamp(p.stat().st_mtime).isoformat()} for p in (image_file,ui_file)}})
args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'output':str(args.output),'atlas':[{k:v for k,v in t['atlasPaint'].items() if k in ('pathRasterBoundsPx','pathCenterVp','pathSizeVp','centerDifferenceVp')} for t in result['themes']]},ensure_ascii=False,indent=2))

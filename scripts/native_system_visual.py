"""UI-only adapters and strict canvas sampling for the official ArkUI visual set.

Importing this module never invokes the device or local test control.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re
import statistics
import struct
import time
import zlib

from native_device_ui import ROOT, DeviceUI, SafeFailure

try:
    from PIL import Image
except ImportError:
    Image = None

CRITERIA = 'arkui-system-v1'
COLORS = {'dark': (16, 17, 15), 'light': (255, 255, 255)}
INPUT_TYPES = ('TextInput', 'TextArea', 'SearchField')


def capture_options(allow_resume=False):
    """CLI choices only; importing the helper still never touches a device."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'artifacts/native-system-visual')
    parser.add_argument('--window-version', default='edge-to-edge-v1', help='Expected immersionVersion from the installed HAP manifest')
    if allow_resume:
        parser.add_argument('--resume-checkpoint', '--resume-dark-checkpoint', dest='resume_dark_checkpoint', type=Path, help='Preserve a verified legal prefix of an archived incomplete attempt')
    args = parser.parse_args()
    output = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output = output.resolve()
    try:
        output.relative_to((ROOT / 'artifacts').resolve())
    except ValueError:
        parser.error('Visual output must remain inside this project artifacts directory')
    if args.window_version and not re.fullmatch(r'[A-Za-z0-9._-]{1,80}', args.window_version):
        parser.error('Window version must be a short literal identifier')
    args.output_dir = output
    return args


def runtime_hap(expected_window_version='edge-to-edge-v1'):
    """Bind the capture to bytes of the latest explicitly recorded signed build.

    This verifies the local packaged HAP and its manifest, not installation on
    the device. The root's separate official install log remains required.
    """
    source = ROOT / 'artifacts/validation/native-system-visual-hap.json'
    hap_path = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
    try:
        if not source.is_file() or source.is_symlink() or not hap_path.is_file() or hap_path.is_symlink():
            raise SafeFailure('The explicit capture HAP manifest and signed build are required')
        raw = source.read_bytes()
        value = json.loads(raw)
        digest = hashlib.sha256(hap_path.read_bytes()).hexdigest()
        if value.get('visualCriteria') != CRITERIA or value.get('sha256') != digest:
            raise SafeFailure('The recorded capture HAP does not match the current signed build bytes')
        version = value.get('immersionVersion')
        if not isinstance(version, str) or not re.fullmatch(r'[A-Za-z0-9._-]{1,80}', version):
            raise SafeFailure('The capture HAP window version is invalid')
        if expected_window_version is not None and version != expected_window_version:
            raise SafeFailure('The recorded capture HAP is not the requested window version')
        return {'sha256': digest, 'visualCriteria': CRITERIA, 'immersionVersion': version,
                'source': str(source.relative_to(ROOT)),
                'sourceSha256': hashlib.sha256(raw).hexdigest(),
                'verification': 'Packaged HAP bytes match the explicit manifest; device installation requires its separate log'}
    except SafeFailure:
        raise
    except (OSError, ValueError, TypeError, AttributeError):
        raise SafeFailure('The capture HAP manifest could not be verified') from None


def runtime_window():
    """Return the latest measured density record, with immutable source evidence."""
    source = ROOT / 'artifacts/validation/native-system-runtime.json'
    try:
        if not source.is_file() or source.is_symlink():
            return None
        raw = source.read_bytes()
        records = json.loads(raw).get('records', [])
        required = ('widthPx', 'heightPx', 'density', 'topInsetPx', 'bottomInsetPx')
        for index in range(len(records) - 1, -1, -1):
            record = records[index]
            if not isinstance(record, dict) or 'density' not in record:
                continue
            if not all(isinstance(record.get(key), (int, float)) and not isinstance(record[key], bool)
                       and math.isfinite(record[key]) for key in required):
                return None
            if (min(record['widthPx'], record['density']) <= 0 or
                    min(record['topInsetPx'], record['bottomInsetPx']) < 0 or
                    record['heightPx'] <= record['topInsetPx'] + record['bottomInsetPx']):
                return None
            result = {key: record[key] for key in required}
            for key in ('fontScale', 'widthVp', 'contentHeightVp'):
                if (isinstance(record.get(key), (int, float)) and not isinstance(record[key], bool)
                        and math.isfinite(record[key]) and record[key] > 0):
                    result[key] = record[key]
            return {**result, 'source': str(source.relative_to(ROOT)), 'sourceRecord': index,
                    'sourceSha256': hashlib.sha256(raw).hexdigest()}
    except (OSError, ValueError, TypeError, AttributeError):
        return None
    return None


def png_pixels(path, through_row=None):
    """Use Pillow when available, otherwise decode only through the required row.

    The fallback retains the existing strict RGB/RGBA PNG decoder. It need not
    reconstruct every keyboard row just to sample the App's canvas above IME.
    """
    data = Path(path).read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise SafeFailure('Theme screenshot is not a PNG')
    offset, compressed = 8, bytearray()
    width = height = channels = 0
    while offset < len(data):
        if offset + 12 > len(data):
            raise SafeFailure('Theme screenshot PNG is truncated')
        length = struct.unpack_from('>I', data, offset)[0]
        kind = data[offset + 4:offset + 8]
        chunk = data[offset + 8:offset + 8 + length]
        if len(chunk) != length:
            raise SafeFailure('Theme screenshot PNG is truncated')
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
    limit = height if through_row is None else min(height, through_row + 1)
    if not isinstance(limit, int) or limit <= 0:
        raise SafeFailure('Theme screenshot sample row is invalid')
    if Image is not None:
        with Image.open(path) as picture:
            if picture.format != 'PNG' or picture.size != (width, height):
                raise SafeFailure('Theme screenshot decoder dimensions differ')
            picture = picture.convert('RGB' if channels == 3 else 'RGBA')
            raw = picture.crop((0, 0, width, limit)).tobytes()
        stride = width * channels
        return width, height, channels, [raw[y * stride:(y + 1) * stride] for y in range(limit)]
    try:
        decoded = zlib.decompress(compressed)
    except zlib.error:
        raise SafeFailure('Theme screenshot PNG compression is invalid') from None
    stride = width * channels
    if len(decoded) != (stride + 1) * height:
        raise SafeFailure('Theme screenshot PNG has an unexpected image length')
    rows, previous = [], bytearray(stride)
    for y in range(limit):
        start = y * (stride + 1)
        filtering = decoded[start]
        row = bytearray(decoded[start + 1:start + 1 + stride])
        if filtering not in range(5):
            raise SafeFailure('Theme screenshot PNG filter is unsupported')
        if filtering:
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
                else:
                    estimate = left + above - upper_left
                    distances = (abs(estimate - left), abs(estimate - above), abs(estimate - upper_left))
                    predictor = (left, above, upper_left)[distances.index(min(distances))]
                row[x] = (row[x] + predictor) & 255
        rows.append(row)
        previous = row
    return width, height, channels, rows


class SystemVisualUI(DeviceUI):
    """Keep adapters local to these captures; do not change the shared driver."""
    def __init__(self, output, shots, window_version='edge-to-edge-v1'):
        self.hap = runtime_hap(window_version)
        self.window = runtime_window()
        if self.window is None:
            raise SafeFailure('Current measured window and density evidence is required for visual capture')
        self.density = self.window['density']
        super().__init__(output, shots)

    def viewport(self, node_id=None):
        """Interaction region excludes the real floating bar's touch surface.

        body_viewport deliberately remains the full physical painting region
        for visual evidence; only control seeking and scrolling are narrowed.
        """
        view = super().viewport(node_id)
        path = self.path_to(node_id) if node_id else None
        scrolls = [node for node in (path or self.flat) if node.get('type') == 'Scroll' and node.get('bounds')]
        scroll = scrolls[-1] if path and scrolls else max(scrolls, key=lambda node:
            max(0, node['bounds'][2] - node['bounds'][0]) * max(0, node['bounds'][3] - node['bounds'][1]), default=None)
        if scroll and scroll.get('id') in ('current-scroll', 'history-scroll'):
            bar_path = self.path_to('nav-home')
            bar = next((node for node in reversed(bar_path or []) if node.get('type') == 'TabBar' and node.get('bounds')), None)
            if bar and view[1] < bar['bounds'][1] < view[3]:
                view[3] = bar['bounds'][1]
        return view

    def minimum_height(self, node_id, node):
        if node_id in ('current-tab', 'history-tab'):
            # SubTabBarStyle.id can identify the label instead of its 53vp bar.
            return (15 if node.get('type') == 'Text' else 53) * self.density * .9
        if node_id == 'expired-return-home':
            return 46 * self.density * .9
        # Shared driver's baseline was measured at 3.375; adapt its vp gates
        # using this run's actual density without changing that shared file.
        return super().minimum_height(node_id, node) * self.density / 3.375

    def theme_choice(self, theme, authenticated=True):
        if authenticated:
            self.tap('account-menu')
            self.wait(lambda u: u.find('theme-picker') is not None and u.find('logout') is not None,
                      'native account sheet is open')
        self.tap('theme-' + theme)
        time.sleep(.4)
        # Applying application color mode can rebuild the native title/sheet
        # subtree. Wait for the same control instead of assuming a fixed
        # 400ms rebuild time; no second tap or business operation is sent.
        self.wait(lambda u: u.find('theme-' + theme) is not None,
                  'native theme control after color-mode reconfiguration')
        selected = self.find('theme-' + theme)
        # This CLI may omit selected state; do not invent its presence. Actual
        # screenshot canvas remains the required independent theme evidence.
        for key in ('accessibilitySelected', 'selected'):
            if key in selected and selected[key] not in (True, 'true'):
                raise SafeFailure('Native theme control did not report selection')
        if authenticated:
            self.back()  # Native sheet dismissal; no removed custom close button.
            self.wait(lambda u: u.find('theme-picker') is None and u.find('account-menu') is not None,
                      'native account sheet is dismissed by system Back')

    def body_scroll(self):
        app = self.app_rect()
        candidates = [node for node in self.flat if node.get('type') == 'Scroll' and node.get('bounds')
                      and node['bounds'][2] > app[0] and node['bounds'][0] < app[2]
                      and node['bounds'][3] > app[1] and node['bounds'][1] < app[3]]
        if not candidates:
            raise SafeFailure('The current App content Scroll is unavailable')
        return max(candidates, key=lambda node: (min(app[2], node['bounds'][2]) - max(app[0], node['bounds'][0])) *
                   (min(app[3], node['bounds'][3]) - max(app[1], node['bounds'][1])))

    def body_viewport(self):
        app, scroll = self.app_rect(), self.body_scroll()['bounds']
        return [max(app[0], scroll[0]), max(app[1], scroll[1]), min(app[2], scroll[2]), min(app[3], scroll[3])]

    def scroll_body_top(self):
        """Restore the actual body, not the fixed native Navigation title."""
        previous = None
        for attempt in range(13):
            self.capture()
            scroll = self.body_scroll()
            view = self.body_viewport()
            # Auth's first line is 32vp below its Scroll. This also proves the
            # original top after the header moved outside the scrolling body.
            first = next((node for node in self.flat if node.get('text') == '一场属于你的解谜之旅'), None)
            if first and abs(first['bounds'][1] - view[1] - 32 * self.density) <= 4:
                return
            # Lists/details have an explicit top content gap. Prefer it over
            # an extra pull at the edge that would itself trigger Refresh.
            body = next((child for child in scroll.get('children', []) if child.get('bounds')), None)
            children = [child for child in (body or {}).get('children', []) if child.get('bounds') and
                        child['bounds'][3] - child['bounds'][1] > 2]
            if children and 14 * self.density <= children[0]['bounds'][1] - view[1] <= 25 * self.density:
                return
            fingerprint = self.visible_fingerprint()
            if fingerprint == previous:
                return
            previous = fingerprint
            if attempt < 12:
                self.swipe('up')
        raise SafeFailure('App content did not reach a stable top boundary')

    def pull_refresh(self, control, path):
        """One native pull, correlated with a new, real successful list GET."""
        self.hide_keyboard()
        self.scroll_body_top()
        # An edge-reaching positioning gesture may itself activate Refresh.
        # Let such positioning reads finish before measuring the deliberate pull.
        stable, last = 0, None
        deadline = time.monotonic() + 25
        while time.monotonic() < deadline:
            rows = [row for row in control.requests() if row.get('method') == 'GET' and row.get('path') == path]
            signature = (len(rows), tuple(row.get('status') for row in rows))
            stable = stable + 1 if signature == last and all(row.get('status') for row in rows) else 0
            if stable >= 3:
                break
            last = signature
            time.sleep(.2)
        else:
            raise SafeFailure('Previous isolated list reads did not settle before native Refresh')
        before = len(rows)
        self.capture()
        if self.find('current-scroll') is None or self.find('theme-picker') is not None:
            raise SafeFailure('Native Refresh requires the visible current-journey content')
        left, top, right, bottom = self.body_viewport()
        if right - left < 120 or bottom - top < 160 * self.density:
            raise SafeFailure('Native Refresh viewport is too small for a safe pull')
        x = round(left + (right - left) * .56)
        y1 = round(top + min(40 * self.density, (bottom - top) * .15))
        y2 = round(top + min(200 * self.density, (bottom - top) * .78))
        self.run('devecocli', 'ui', 'swipe', x, y1, x, y2, '--speed', 900)
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            current = [row for row in control.requests() if row.get('method') == 'GET' and row.get('path') == path]
            if len(current) > before and current[before].get('status'):
                row = current[before]
                if row['status'] != 200 or row.get('fault') is not False:
                    raise SafeFailure('The new native Refresh GET was not a real successful response')
                return {'trigger': 'official Refresh pull gesture', 'method': 'GET', 'path': path,
                        'ordinal': before + 1, 'status': 200, 'fault': False,
                        'viewport': [left, top, right, bottom], 'gesture': [x, y1, x, y2]}
            time.sleep(.15)
        raise SafeFailure('The native Refresh pull did not produce a new completed list GET')

    def empty_visible_inputs(self):
        return all(not node.get('text', '') for node in self.flat if node.get('type') in INPUT_TYPES)

    def canvas_sample(self, anchor):
        """Select geometry before reading pixels; never search for a passing color."""
        app = self.app_rect()
        view = self.body_viewport()
        # For auth and IME, sample the declared canvas gap between a field's
        # label and border. The gutter near IME can belong to a different surface.
        fields = [node for node in self.flat if node.get('type') == 'TextInput' and node.get('id') and node.get('bounds')]
        fields.sort(key=lambda node: (node.get('id') != anchor, node['bounds'][1]))
        for field in fields:
            left, top, right, bottom = field['bounds']
            if bottom - top < 52 * self.density * .9 or top < view[1] + 24 or bottom > view[3] - 8:
                continue
            path = self.path_to(field['id'])
            for parent in reversed((path or [])[:-1]):
                labels = [child for child in parent.get('children', []) if child.get('type') == 'Text' and
                          child.get('bounds') and child['bounds'][3] <= top]
                if not labels:
                    continue
                label = max(labels, key=lambda child: child['bounds'][3])
                gap = top - label['bounds'][3]
                if 12 <= gap <= 20 * self.density:
                    point = [round(left + 8 * self.density), round((top + label['bounds'][3]) / 2)]
                    return point, {'kind': 'form label-to-input canvas gap', 'field': field['id'],
                                   'bounds': [left, label['bounds'][3], right, top], 'appBounds': app, 'scrollBounds': view}
                break
        if fields:
            raise SafeFailure('A complete blank form canvas gap is not visible above the keyboard')
        # Outside the padded journey Scroll, the page's canvas is explicit and
        # independent of the official floating/immersive title material.
        if view[0] - app[0] >= 20:
            point = [round((app[0] + view[0]) / 2), round(view[1] + min(32 * self.density, (view[3] - view[1]) / 4))]
            return point, {'kind': 'page canvas outside padded journey Scroll',
                           'bounds': [app[0], view[1], view[0], view[3]], 'appBounds': app, 'scrollBounds': view}
        # Detail body children are inset by 12vp. The 16vp top gap is affected
        # by the official material title's shadow, so it is not a pure canvas
        # reference. Choose geometry in the actual side padding, 160vp below
        # the Scroll top, before inspecting any pixel colors.
        scroll = self.body_scroll()
        body = next((child for child in scroll.get('children', []) if child.get('bounds')), None)
        boxes = [child['bounds'] for child in (body or {}).get('children', [])
                 if child.get('bounds') and child['bounds'][0] - view[0] >= 12 and
                 view[2] - child['bounds'][2] >= 12 and
                 child['bounds'][2] - child['bounds'][0] >= (view[2] - view[0]) * .6]
        if not boxes:
            raise SafeFailure('The actual inset detail body has no declared side-canvas region')
        left = min(bounds[0] for bounds in boxes)
        point = [round((view[0] + left) / 2),
                 round(view[1] + min(160 * self.density, (view[3] - view[1]) / 2))]
        return point, {'kind': 'detail page canvas outside actual 12vp body inset, away from title shadow',
                       'bounds': [view[0], view[1], left, view[3]],
                       'geometryRule': 'horizontal midpoint of actual left body padding; 160vp below Scroll top, capped at its midpoint',
                       'insetBodyBounds': boxes[0], 'appBounds': app, 'scrollBounds': view}



def canvas_evidence(ui, target, theme, anchor):
    point, region = ui.canvas_sample(anchor)
    x, y = point
    width, height, channels, rows = png_pixels(target, through_row=y + 2)
    app = region['appBounds']
    bounds = region['bounds']
    if (app[0] < 0 or app[1] < 0 or app[2] > width or app[3] > height or
            x - 2 < max(0, app[0], bounds[0]) or x + 2 >= min(width, app[2], bounds[2]) or
            y - 2 < max(0, app[1], bounds[1]) or y + 2 >= min(height, app[3], bounds[3])):
        raise SafeFailure('The canvas sample is outside the current App or declared blank region')
    values = [[rows[py][px * channels + channel] for py in range(y - 2, y + 3)
               for px in range(x - 2, x + 3)] for channel in range(3)]
    observed = [int(statistics.median(value)) for value in values]
    expected = COLORS[theme]
    # Keep the original ±4 tolerance and require the whole 5×5 patch to be
    # flat; a median cannot hide text, an Atlas line, a material or IME edge.
    flat = all(max(value) - min(value) <= 4 for value in values)
    matched = flat and all(abs(actual - wanted) <= 4 for actual, wanted in zip(observed, expected))
    return {'canvasRGB': observed, 'expectedRGB': list(expected), 'sample': point,
            'sampleRegion': region, 'sampleFlat': flat, 'themeVerified': matched,
            'pixels': [width, height], 'pngDecoder': 'Pillow' if Image else 'strict PNG row fallback',
            'screenshotSha256': hashlib.sha256(Path(target).read_bytes()).hexdigest()}

"""Official DevEco CLI helpers. UI input values never enter public evidence or errors."""
import json
from pathlib import Path
import shlex
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


class SafeFailure(RuntimeError):
    pass


def flatten(value):
    out = []
    if isinstance(value, list):
        for child in value:
            out.extend(flatten(child))
    elif isinstance(value, dict):
        out.append(value)
        for child in value.get('children', []):
            out.extend(flatten(child))
    return out


def sanitise(value, in_input=False):
    if isinstance(value, list):
        return [sanitise(item, in_input) for item in value]
    if not isinstance(value, dict):
        return value
    in_input = in_input or value.get('type') in ('TextInput', 'TextArea', 'SearchField')
    out = {}
    for key, item in value.items():
        if in_input and key.lower() in ('text', 'value', 'accessibilityvalue', 'accessibilitytext', 'content', 'password'):
            out[key] = '[input omitted]'
        else:
            out[key] = sanitise(item, in_input)
    return out


class IsolationControl:
    def __init__(self):
        self.state_path = ROOT / 'artifacts/private/https-isolation/state.json'
        self.state = json.loads(self.state_path.read_text())
        if self.state.get('mode') != 'real isolated PocketBase':
            raise SafeFailure('Only this disposable backend is supported')
        if not self.state.get('controlBase', '').startswith('http://127.0.0.1:'):
            raise SafeFailure('Test control must remain on loopback')
        if self.state.get('tls', {}).get('base') != 'https://127.0.0.1:18443':
            raise SafeFailure('Strict USB TLS test origin is not configured')
        self.ledger = []

    def call(self, route, body=None):
        req = urllib.request.Request(self.state['controlBase'] + route, data=json.dumps(body or {}).encode(), method='POST', headers={'Authorization': self.state['controlToken'], 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(req, timeout=25) as response:
                return json.load(response)
        except Exception:
            raise SafeFailure('Local isolated control operation failed: ' + route) from None

    def requests(self):
        return self.call('/requests')['requests']

    def count(self, path, method=None):
        return sum(row.get('path') == path and (not method or row.get('method') == method) for row in self.requests())

    def checkpoint(self, label):
        allowed = ('method', 'path', 'status', 'fault', 'responseDropped', 'bearer', 'authenticated')
        rows = [{key: row[key] for key in allowed if key in row} for row in self.requests()]
        self.ledger.append({'phase': label, 'requests': rows})
        return rows

    def reset(self):
        self.call('/reset')


class DeviceUI:
    def __init__(self, output, shots):
        self.output = Path(output)
        self.shots = Path(shots)
        self.output.mkdir(parents=True, exist_ok=True)
        self.shots.mkdir(parents=True, exist_ok=True)
        self.tree = None
        self.flat = []
        self.width = 0
        self.height = 0

    def run(self, *args, timeout=45):
        prefix = ' '.join(str(arg) for arg in args[:2] if not any(c.isspace() for c in str(arg)))
        if len(args) > 2 and not any(c.isspace() for c in str(args[2])):
            prefix += ' ' + str(args[2])
        try:
            result = subprocess.run([str(arg) for arg in args], cwd=ROOT, capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired:
            raise SafeFailure('Official command timed out: ' + prefix) from None
        if result.returncode or result.stdout.lstrip().startswith(('Error:', '[Fail]')):
            raise SafeFailure('Official command failed: ' + prefix)
        return result.stdout

    def launch(self, uri=None, cold=False):
        if cold:
            self.run('hdc', 'shell', 'aa', 'force-stop', 'com.sitkin.starward')
        args = ['hdc', 'shell', 'aa', 'start', '-b', 'com.sitkin.starward', '-a', 'EntryAbility']
        if uri:
            args += ['-U', uri]
        if 'start ability successfully' not in self.run(*args).lower():
            raise SafeFailure('The test Ability did not acknowledge launch')

    def capture(self, name=None):
        raw = self.run('devecocli', 'ui', 'layout', '--format', 'json', '--mode', 'full')
        try:
            self.tree = json.loads(raw)
        except Exception:
            raise SafeFailure('Official UI dump was not valid JSON') from None
        self.flat = flatten(self.tree)
        known = {'environment-badge', 'account', 'password', 'old-password', 'new-password', 'confirm-password',
                 'primary-action', 'account-menu', 'start-assignment', 'return-home',
                 'forced-logout', 'logout', 'error-return-home', 'profile-scroll', 'profile-name',
                 'security-old-password', 'security-new-password', 'security-confirm-password'}
        if not any(node.get('id') in known or node.get('text') == 'QUEST SESSION' for node in self.flat):
            raise SafeFailure('Expected test App is not foreground; other apps were not touched')
        roots = self.tree if isinstance(self.tree, list) else [self.tree]
        bounds = next((node.get('bounds') for node in roots if node.get('bounds') and len(node['bounds']) == 4), None)
        if bounds:
            self.width, self.height = bounds[2] - bounds[0], bounds[3] - bounds[1]
        if not self.width or not self.height:
            raise SafeFailure('Device bounds are unavailable')
        if name:
            (self.output / ('ui-' + name + '.json')).write_text(json.dumps(sanitise(self.tree), ensure_ascii=False, indent=2) + '\n')
        return self.flat

    def find(self, node_id):
        return next((node for node in self.flat if node.get('id') == node_id), None)

    def texts(self):
        return [node.get('text', '') for node in self.flat if node.get('text')]

    def has_text(self, text, contains=False):
        return any(text in value if contains else text == value for value in self.texts())

    def app_rect(self):
        node = next((node for node in self.flat if node.get('type') == 'root' and node.get('bounds')), None)
        if node is None:
            raise SafeFailure('Current App root bounds are unavailable')
        return node['bounds']

    def path_to(self, node_id):
        def visit(value, parents):
            if isinstance(value, list):
                for child in value:
                    result = visit(child, parents)
                    if result is not None:
                        return result
            elif isinstance(value, dict):
                if value.get('id') == node_id:
                    return parents + [value]
                for child in value.get('children', []):
                    result = visit(child, parents + [value])
                    if result is not None:
                        return result
            return None
        return visit(self.tree, [])

    def viewport(self, node_id=None):
        app = self.app_rect()
        path = self.path_to(node_id) if node_id else None
        scrolls = [node for node in (path or self.flat) if node.get('type') == 'Scroll' and node.get('bounds')]
        if path is not None:
            scroll = scrolls[-1]['bounds'] if scrolls else app
        elif scrolls:
            scroll = max(scrolls, key=lambda node: max(0, node['bounds'][2] - node['bounds'][0]) *
                         max(0, node['bounds'][3] - node['bounds'][1]))['bounds']
        else:
            scroll = app
        return [max(app[0], scroll[0]), max(app[1], scroll[1]), min(app[2], scroll[2]), min(app[3], scroll[3])]

    def swipe(self, direction):
        self.capture()
        left, top, right, bottom = self.viewport()
        if right - left < 80 or bottom - top < 150:
            raise SafeFailure('App scroll viewport is too small for a safe gesture')
        x = int(left + (right - left) * .58)
        low = int(top + (bottom - top) * .76)
        high = int(top + (bottom - top) * .30)
        start, end = (low, high) if direction == 'down' else (high, low)
        self.run('devecocli', 'ui', 'swipe', x, start, x, end)

    def visible_fingerprint(self):
        return tuple(sorted((node['id'], tuple(node['bounds'])) for node in self.flat
                            if node.get('id') and node.get('bounds')))

    def minimum_height(self, node_id, node):
        # Heights are the actual API26 ArkUI vp/fp declarations, converted using
        # the measured device density. Unknown controls still reject tiny clips.
        heights = {'primary-action': 52, 'start-assignment': 52, 'account-menu': 44,
                   'account-close': 44, 'forced-logout': 44, 'logout': 44,
                   'request-retry': 40, 'error-return-home': 40, 'return-home': 44,
                   'current-tab': 52, 'history-tab': 52, 'login-help': 45.6,
                   'refresh-assignments': 48}
        if node.get('type') == 'TextInput':
            expected = 52
        elif node_id.startswith('assignment-state-'):
            expected = 19
        elif node_id.startswith('assignment-'):
            expected = 46
        elif node_id.startswith('theme-'):
            expected = 40
        elif node_id.startswith('nav-'):
            expected = 44  # Native BottomTabBarStyle owns its actual bar geometry.
        else:
            expected = heights.get(node_id, 28 if node.get('type') == 'Button' else 8)
        return expected * 3.375 * .9

    def seek(self, node_id, max_swipes=12):
        for direction in ('down', 'up'):
            previous = None
            for attempt in range(max_swipes + 1):
                self.capture()
                node = self.find(node_id)
                if node and node.get('bounds'):
                    left, top, right, bottom = node['bounds']
                    view = self.viewport(node_id)
                    minimum = self.minimum_height(node_id, node)
                    if (right > left and bottom - top >= minimum and left >= view[0] + 4 and
                            right <= view[2] - 4 and top >= view[1] + 8 and bottom <= view[3] - 8):
                        return node
                fingerprint = self.visible_fingerprint()
                if fingerprint == previous:
                    break  # The bounded App Scroll reached an edge; reverse now.
                previous = fingerprint
                if attempt < max_swipes:
                    self.swipe(direction)
        raise SafeFailure('Expected test control is not reachable: ' + node_id)

    def tap(self, node_id):
        self.seek(node_id)
        self.run('devecocli', 'ui', 'click', '--id', node_id)

    def tap_text(self, text):
        for direction in ('down', 'up'):
            for attempt in range(6):
                self.capture()
                found = next((n for n in self.flat if n.get('type') == 'Button' and n.get('text') == text and n.get('bounds')), None)
                if found:
                    left, top, right, bottom = found['bounds']
                    self.run('devecocli', 'ui', 'click', (left + right) // 2, (top + bottom) // 2)
                    return
                if attempt < 5:
                    self.swipe(direction)
        raise SafeFailure('Expected labelled App button is not reachable')

    def keyboard_visible(self):
        try:
            windows = json.loads(self.run('devecocli', 'ui', 'window', 'list', '--all', '--format', 'json'))
            candidates = windows if isinstance(windows, list) else windows.get('windows', [])
            return any(any(part in str(window.get('name', '')).lower() for part in ('inputmethod', 'input_method', 'keyboard', 'hmosime')) for window in candidates)
        except Exception:
            return False

    def hide_keyboard(self):
        if self.keyboard_visible():
            self.back()
            deadline = time.monotonic() + 8
            while self.keyboard_visible():
                if time.monotonic() >= deadline:
                    raise SafeFailure('The native keyboard did not finish dismissing')
                time.sleep(.1)

    def fill(self, node_id, value):
        self.hide_keyboard()
        self.seek(node_id)
        self.run('devecocli', 'ui', 'click', '--id', node_id)
        # Official UiTest text appends. Select all + delete before replacement.
        # API26 KeyCode: CTRL_LEFT=2072, A=2017, DEL=2055.
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017')
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', '2055')
        self.capture()
        cleared = self.find(node_id)
        if cleared is None or cleared.get('text', ''):
            raise SafeFailure('Official input clearing could not be verified: ' + node_id)
        # A single safely quoted remote command also preserves edge spaces;
        # this CLI build otherwise splits the decoded text argument.
        if value:
            self.run('hdc', 'shell', 'uitest uiInput text ' + shlex.quote(value))
        self.hide_keyboard()
        self.capture()
        node = self.find(node_id)
        observed = node.get('text', '') if node else ''
        masked = bool(observed) and all(char in '*•●·' for char in observed)
        if node is None or not (observed == value or (masked and len(observed) == len(value))):
            raise SafeFailure('Official input replacement could not be verified: ' + node_id)

    def back(self):
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', 'Back')

    def edge_back(self):
        self.hide_keyboard()
        self.capture()
        # A real OS edge swipe, deliberately distinct from keyEvent Back.
        y = int(self.height * .5)
        self.run('devecocli', 'ui', 'swipe', 2, y, int(self.width * .35), y, '--speed', 900)

    def foreground_cycle(self):
        self.hide_keyboard()
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', 'Home')
        self.launch()

    def wait(self, predicate, label, timeout=25, save=None):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            self.capture()
            if predicate(self):
                if save:
                    self.capture(save)
                return self.flat
            time.sleep(.2)
        self.capture('failure-last-view')
        raise SafeFailure('UI expectation timed out: ' + label)

    def screenshot(self, name):
        self.capture()
        target = self.shots / (name + '.png')
        target.unlink(missing_ok=True)
        self.run('devecocli', 'ui', 'screenshot', '--path', target)
        return target

    def input_empty(self, node_id):
        self.seek(node_id)
        node = self.find(node_id)
        return node is not None and not node.get('text', '')

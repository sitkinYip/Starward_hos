#!/usr/bin/env python3
"""Root-only question frame/type sample for one explicit isolated real-content case.

Default/help is inert. Only run performs Host login/me/list/detail, read-only
runner diagnostics and native login/start/GET/navigation/theme/hint/logout.
No answer, profile, password, reset, fault or service operation is implemented.
Original trees, screenshots and the same-data Web DTO stay private. A passed
report means these narrow checks completed, never that visual parity passed.
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shlex
import ssl
import stat
import subprocess
import sys
import urllib.request
from urllib.parse import urlparse
import zipfile

from native_device_ui import ROOT, DeviceUI, SafeFailure


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


# Import only inert definitions. Never construct EntryMain or AnswerDevice:
# their four-timing-case/fault/answer execution policies remain unchanged.
ENTRY = module('question_frame_entry', 'device-gameplay-entry.py')
ANSWER = module('question_frame_answer', 'device-gameplay-answer.py')
PIXELS = module('question_frame_pixels', 'native_system_visual.py')
UI = ENTRY.UI
VALIDATION = ROOT / 'artifacts/validation'
PRIVATE = ROOT / 'artifacts/private'
AUTH, BASE = ENTRY.AUTH, ENTRY.BASE
require, sha = ENTRY.require, ENTRY.sha


def fresh(value, base, directory=False):
    path = (ROOT / value).absolute() if not value.is_absolute() else value.absolute()
    require(path == path.resolve() and path.is_relative_to(base) and path != base and
            not path.exists() and not path.is_symlink(), 'Choose a fresh canonical sample output')
    require(directory or path.suffix == '.json', 'The public report must be JSON')
    for parent in (path.parent, *path.parent.parents):
        require(not parent.is_symlink(), 'Sample output ancestors cannot be symlinks')
        if parent == ROOT:
            break
    return path


def private_directory(path):
    require(not path.exists() and not path.is_symlink(), 'The private run directory already exists')
    for parent in reversed((path, *path.parents)):
        if parent == ROOT or ROOT not in parent.parents:
            continue
        if not parent.exists():
            parent.mkdir(mode=0o700 if parent == PRIVATE or PRIVATE in parent.parents else 0o755)
        info = parent.stat()
        require(not parent.is_symlink() and stat.S_ISDIR(info.st_mode) and info.st_uid == os.getuid(),
                'Sample output directories must be owned and direct')
        if parent == PRIVATE or PRIVATE in parent.parents:
            require(stat.S_IMODE(info.st_mode) == 0o700, 'Private ancestors must be mode700')


def write_private(path, value, credentials):
    def no_auth_fields(item):
        if isinstance(item, dict):
            require(not any(str(key).lower() in ('token', 'password', 'authorization', 'controltoken') for key in item),
                    'Authentication fields cannot enter private reference data')
            for child in item.values():
                no_auth_fields(child)
        elif isinstance(item, list):
            for child in item:
                no_auth_fields(child)
    no_auth_fields(value)
    data = (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n').encode()
    require(not any(secret and secret.encode() in data for secret in credentials),
            'Authentication literals cannot enter private reference data')
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        os.fchmod(stream.fileno(), 0o600)
        stream.write(data)
    return {'file': str(path.relative_to(ROOT)), 'sha256': sha(path)}


def command(*args):
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, capture_output=True,
                            text=True, timeout=20)
    require(result.returncode == 0, 'A read-only runner ownership command failed')
    return result.stdout


def owner(pid, script, operations, ports):
    require(type(pid) is int and pid > 0, 'A runner PID is invalid')
    require(command('ps', '-p', pid, '-o', 'uid=').strip() == str(os.getuid()),
            'A runner belongs to another user')
    argv = shlex.split(command('ps', '-p', pid, '-o', 'args=').strip())
    require(len(argv) == 3 and Path(argv[0]).name == 'node' and
            (ROOT / argv[1]).resolve() == script.resolve() and argv[2] in operations,
            'A runner command does not identify the exact reviewed script')
    cwd = [line[1:] for line in command('/usr/sbin/lsof', '-a', '-p', pid, '-d', 'cwd', '-Fn').splitlines()
           if line.startswith('n')]
    require(cwd == [str(ROOT)], 'A runner working directory changed')
    for port in ports:
        listening = command('/usr/sbin/lsof', '-nP', '-iTCP:' + str(port), '-sTCP:LISTEN', '-Fp')
        require({int(line[1:]) for line in listening.splitlines() if re.fullmatch(r'p[1-9][0-9]*', line)} == {pid},
                'An origin no longer has its exact sole runner listener')
    return command('ps', '-p', pid, '-o', 'lstart=').strip()


class FrameUI(ANSWER.GameplayUI):
    def __init__(self, state, density, directory):
        # ProfileUI's constructor creates its historical output directories.
        # Use its reviewed methods with only this fresh private directory.
        DeviceUI.__init__(self, directory, directory)
        self.density = density
        self.secrets = [state[key] for key in ('account', 'initialPassword', 'controlToken')]
        self.secret_literals = self.secrets[1:]
        self.private_screenshots, self.private_trees, self.ime_evidence, self.raw_evidence = [], [], [], []
        self.remote_cleanup_ok, self.side_panel = True, True
        self.available_bottom, self.no_keyboard_baseline = None, None
        self.main_bar_hidden_observed = False

    def minimum_height(self, node_id, node):
        if node_id.startswith('question-hint-') and not node_id.startswith('question-hint-content-'):
            return 44 * self.density - 2
        return super().minimum_height(node_id, node)

    def scroll_top(self):
        previous = None
        for _ in range(16):
            self.capture()
            fingerprint = self.visible_fingerprint()
            if fingerprint == previous:
                return
            previous = fingerprint
            self.swipe('up')
        raise SafeFailure('The own page top was not reached within the bounded scroll')

    def reveal_text(self, node_id):
        # A long paragraph cannot fit the control-oriented seek() contract.
        # Bring its beginning into the actual Scroll and retain full raw bounds.
        for _ in range(24):
            self.capture()
            node = self.find(node_id)
            if node and node.get('bounds'):
                box, view = UI.rect(node['bounds']), self.viewport(node_id)
                visible = min(box[3], view[3]) - max(box[1], view[1])
                if view[1] + 4 <= box[1] <= view[3] - 8 and visible >= min(40 * self.density, box[3] - box[1]):
                    return
                desired = box[1] - (view[1] + 24 * self.density)
                distance = min(abs(desired), (view[3] - view[1]) * .5)
                require(view[2] - view[0] > 80 and view[3] - view[1] > 150, 'The own text viewport is too small')
                x, center = round((view[0] + view[2]) / 2), round((view[1] + view[3]) / 2)
                half = max(8, round(distance / 2))
                start, end = (center + half, center - half) if desired > 0 else (center - half, center + half)
                self.run('devecocli', 'ui', 'swipe', x, start, x, end)
            else:
                self.swipe('down')
        raise SafeFailure('The own long text beginning was not reachable within bounded scrolling')


def own(raw, node_id):
    values = [row for row in raw if row.get('id') == node_id and UI.positive(UI.rect(row.get('bounds')))]
    require(len(values) == 1, 'A unique measured own frame node is required')
    return values[0]


def measured_text(row, density, expected_line_height):
    box = UI.rect(row.get('bounds'))
    fonts = {key: row[key] for key in ('fontSize', 'textSize', 'font-size', 'lineHeight', 'textLineCount')
             if key in row and isinstance(row[key], (int, float, str)) and
             re.fullmatch(r'[0-9.]+(?:px|vp|fp)?', str(row[key]))}
    return {'boundsPx': box, 'widthVp': (box[2] - box[0]) / density,
        'heightVp': (box[3] - box[1]) / density, 'textLength': len(row.get('text', '')),
        'platformTypographyFields': fonts, 'fontFieldsExposed': bool(fonts),
        'lineBoxReferenceVp': expected_line_height,
        'lineBoxRatio': (box[3] - box[1]) / density / expected_line_height,
        'lineWrapReview': 'pending_root_original_review; ratio is not an authoritative line count'}


class OriginalPng:
    def __init__(self, path):
        self.width, self.height, self.channels, self.rows = PIXELS.png_pixels(path)

    def getpixel(self, point):
        x, y = point
        start = x * self.channels
        return self.rows[y][start:start + 3]


def pixel_corner(image, card, density, side):
    """Measure painted perpendicular line runs, never substitute target28/12."""
    left, top, right, bottom = [round(v) for v in card]
    sx, sy = (-1 if side.endswith('right') else 1), (-1 if side.startswith('bottom') else 1)
    origin_x, origin_y = (right - 1 if sx < 0 else left), (bottom - 1 if sy < 0 else top)
    extent = round(48 * density)
    require(0 <= origin_x < image.width and 0 <= origin_y < image.height and
            0 <= origin_x + sx * extent < image.width and 0 <= origin_y + sy * extent < image.height,
            'A painted frame corner is not fully inside the original screenshot')
    surface = image.getpixel((origin_x + sx * round(3 * density), origin_y + sy * round(3 * density)))
    def foreground(x, y):
        value = image.getpixel((origin_x + sx * x, origin_y + sy * y))
        return max(abs(value[k] - surface[k]) for k in range(3)) >= 30
    candidates = []
    for y in range(round(3 * density), round(24 * density)):
        for x in range(round(3 * density), round(24 * density)):
            if not foreground(x, y):
                continue
            horizontal = 0
            while x + horizontal < extent and foreground(x + horizontal, y):
                horizontal += 1
            vertical = 0
            while y + vertical < extent and foreground(x, y + vertical):
                vertical += 1
            if min(horizontal, vertical) >= 10 * density:
                candidates.append((x + y, x, y, horizontal, vertical))
    require(candidates, 'The painted corner could not be independently measured')
    _, x, y, horizontal, vertical = min(candidates)
    return {'method': 'original_png_perpendicular_painted_runs',
        'horizontalOffsetVp': x / density, 'verticalOffsetVp': y / density,
        'horizontalLengthVp': horizontal / density, 'verticalLengthVp': vertical / density}


def pixel_inner(image, card, density, bottom=False, vertical=False):
    left, top, right, foot = [round(v) for v in card]
    edge, direction = ((right - 1, -1) if bottom else (left, 1)) if vertical else ((foot - 1, -1) if bottom else (top, 1))
    start, end = ((max(0, top + round(48 * density)), min(image.height, foot - round(48 * density)))
                  if vertical else (left + round(48 * density), right - round(48 * density)))
    axis_limit = image.width if vertical else image.height
    require(end - start >= 40 * density and 0 <= edge < axis_limit and
            0 <= edge + direction * round(14 * density) < axis_limit,
            'The inner line is not fully visible in the original screenshot')
    def pixel(span, offset):
        point = (edge + direction * offset, span) if vertical else (span, edge + direction * offset)
        return image.getpixel(point)
    base = pixel((start + end) // 2, round(3 * density))
    found = []
    for offset in range(round(2 * density), round(14 * density)):
        colors = [pixel(span, offset) for span in range(start, end)]
        mid = tuple(sorted(value[k] for value in colors)[len(colors) // 2] for k in range(3))
        contrast = max(abs(mid[k] - base[k]) for k in range(3))
        flat = sum(max(abs(value[k] - mid[k]) for k in range(3)) <= 1 for value in colors) / len(colors)
        if 2 <= contrast < 30 and flat >= .98:
            found.append(offset)
    require(found, 'The painted inner horizontal line could not be independently measured')
    return {'method': 'original_png_flat_inset_line', 'edgeOffsetVp': min(found) / density}


class FrameSample:
    def __init__(self, args):
        self.args = args
        require(re.fullmatch(r'[a-f0-9]{64}', args.expected_hap or '') and
                re.fullmatch(r'[a-f0-9]{64}', args.expected_fixture_sha or ''), 'Explicit package and fixture SHA256 are required')
        self.report, self.directory = fresh(args.output, VALIDATION), fresh(args.private_dir, PRIVATE, True)
        self.state = ENTRY.read_state()
        self.reference = ENTRY.guarded(args.case_ref, PRIVATE, True)
        reference = json.loads(self.reference.read_text())
        self.case_id = reference.get('caseId')
        require(re.fullmatch(r'[a-f0-9]{16}', self.case_id or ''), 'An explicit synthetic case reference is required')
        self.case = self.state['gameplay']['cases'].get(self.case_id)
        require(isinstance(self.case, dict) and self.case.get('caseId') == self.case_id and
                self.case.get('fixture') == 'ui-real-content' and self.case.get('setupStatus') == 'ready' and
                self.case.get('ordinaryLoginPrepared') is True and
                re.fullmatch(r'hm_[a-f0-9]{12}', self.case.get('account', '')) and
                re.fullmatch(r'[a-z0-9]{15}', self.case.get('playerId', '')) and
                isinstance(self.case.get('newPassword'), str) and len(self.case['newPassword']) >= 24 and
                isinstance(self.case.get('label'), str) and bool(self.case['label']) and
                self.case.get('fixtureLevelKinds') in (['text'], ['choice']) and
                set(self.case.get('assignments', {})) == {'ready'}, 'The explicit ordinary real-content case is not ready')
        source = self.case.get('sourceContent', {})
        require(set(source) == {'fixtureSha256', 'sourceCaseIndex', 'effectiveHideTitle'} and
                source['fixtureSha256'] == args.expected_fixture_sha and type(source['sourceCaseIndex']) is int and
                0 <= source['sourceCaseIndex'] <= 2 and type(source['effectiveHideTitle']) is bool,
                'The case does not bind the exact reviewed content fixture')
        self.import_id = self.case.get('uiContentImportId')
        registry = self.state.get('uiContent', {})
        imported = registry.get('imports', {}).get(self.import_id) if isinstance(registry.get('imports'), dict) else None
        require(registry.get('schema') == 1 and isinstance(imported, dict) and imported.get('status') == 'ready' and
                imported.get('fixture') == 'ui-real-content' and imported.get('fixtureSha256') == args.expected_fixture_sha and
                imported.get('verifiedRecordCount') == 19 and imported.get('verifiedBy') == 'official-admin-and-player-readbacks' and
                isinstance(imported.get('caseIds'), list) and len(imported['caseIds']) == 3 and
                imported['caseIds'][source['sourceCaseIndex']] == self.case_id,
                'The case has no complete matching independently read-back content import')
        self.import_identity = json.dumps(imported, sort_keys=True)
        require(set(reference) == {'caseId'}, 'The fresh case reference must contain only its explicit synthetic ID')
        self.assignment_id = self.case['assignmentId']
        ready = self.case['assignments']['ready']
        require(set(ready) == {'assignmentId', 'sessionId'} and ready['assignmentId'] == self.assignment_id and
                all(re.fullmatch(r'[a-z0-9]{15}', ready[key] or '') for key in ready) and
                self.assignment_id != self.state['assignmentId'] and self.case['playerId'] != self.state['playerId'],
                'The explicit single assignment is not separate from the original environment player')
        self.detail, self.start = BASE + '/' + self.assignment_id, BASE + '/' + self.assignment_id + '/start'
        self.environment = ENTRY.EntryMain.identity(self.state)
        self.case_identity = json.dumps(self.case, sort_keys=True)
        tls = self.state.get('tls', {})
        self.host, self.control_base = ENTRY.loopback(tls.get('hostBase'), 'https'), ENTRY.loopback(self.state.get('controlBase'), 'http')
        proxy = ENTRY.loopback(self.state.get('proxyBase'), 'http')
        ENTRY.loopback(self.state.get('backendBase'), 'http')
        require(tls.get('base') == 'https://127.0.0.1:18443' and tls.get('hostPort') == urlparse(self.host).port and
                re.fullmatch(r'sha256:[a-f0-9]{64}', self.state.get('imageId', '')), 'The exact isolated TLS/image identity is absent')
        self.ca = ENTRY.guarded(ENTRY.ISOLATION / 'tls/ca.pem', ENTRY.ISOLATION)
        require(tls.get('caPath') == str(self.ca) and tls.get('caSha256') == sha(self.ca), 'The independent isolated CA receipt changed')
        source_directory = Path(self.state.get('sourceDirectory', ''))
        require(source_directory.is_absolute() and source_directory == source_directory.resolve() and source_directory.is_relative_to(ENTRY.ISOLATION) and
                source_directory.name.startswith('questions-pb-test-') and source_directory.is_dir(),
                'The source database directory is outside the owned disposable namespace')
        for parent in (source_directory, *source_directory.parents):
            require(not parent.is_symlink() and parent.stat().st_uid == os.getuid(), 'The source directory ownership changed')
            if parent == ENTRY.ISOLATION:
                break
        runtime_path = ENTRY.guarded(args.runtime, VALIDATION)
        runtime = json.loads(runtime_path.read_text())
        self.hap_sha = sha(ENTRY.HAP)
        window = runtime.get('window', {})
        density = window.get('density')
        require(runtime.get('status') == 'passed' and runtime.get('installedHapSha256') == self.hap_sha == args.expected_hap and
                set(runtime.get('checks', {})) == ENTRY.CHECKS and all(value is True for value in runtime['checks'].values()) and
                window.get('fontScale') == 1 and type(density) in (int, float) and math.isfinite(density) and density > 0 and
                type(window.get('widthPx')) in (int, float) and abs(window['widthPx'] / density - 376) <= 1 / density,
                'A matching actual five-check376vp/font1 runtime is required')
        config = json.loads(ENTRY.CONFIG.read_text())
        require(config == {'isolated': True, 'endpoint': tls['base'], 'timeoutMs': 15000, 'probeTls': True, 'fontScale': 1} and
                sha(ENTRY.CONFIG.parent / 'integration-ca.pem') == sha(self.ca), 'The local integration config or CA changed')
        with zipfile.ZipFile(ENTRY.HAP) as archive:
            configs = [name for name in archive.namelist() if name.endswith('/rawfile/integration.json')]
            authorities = [name for name in archive.namelist() if name.endswith('/rawfile/integration-ca.pem')]
            require(len(configs) == len(authorities) == 1 and archive.read(configs[0]) == ENTRY.CONFIG.read_bytes() and
                    hashlib.sha256(archive.read(authorities[0])).hexdigest() == sha(self.ca), 'The HAP lacks the exact config and CA')
        self.ports = [urlparse(proxy).port, urlparse(self.control_base).port]
        self.births = self.ownership()
        self.bound = {'driver': Path(__file__), 'caseReference': self.reference, 'runtime': runtime_path, 'hap': ENTRY.HAP,
            'config': ENTRY.CONFIG, 'ca': self.ca, 'runner': ROOT / 'scripts/isolated-backend.mjs',
            'uiContentSetup': ROOT / 'scripts/ui-content-case.mjs',
            'tlsRunner': ROOT / 'scripts/isolated-tls.mjs', 'entryGuard': ROOT / 'scripts/device-gameplay-entry.py',
            'answerUI': ROOT / 'scripts/device-gameplay-answer.py', 'refinementUI': ROOT / 'scripts/device-native-ui-refinements.py',
            'pngDecoder': ROOT / 'scripts/native_system_visual.py',
            'nativeUI': ROOT / 'scripts/native_device_ui.py', 'gameplayPage': ROOT / 'entry/src/main/ets/features/GameplayPage.ets',
            'questionFrame': ROOT / 'entry/src/main/ets/ui/StarwardQuestionFrame.ets'}
        self.binding = {name: sha(path) for name, path in self.bound.items()}
        context = ssl.create_default_context(cafile=str(self.ca))
        require(context.check_hostname and context.verify_mode == ssl.CERT_REQUIRED, 'Strict Host TLS is required')
        self.host_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), ENTRY.NoRedirect(), urllib.request.HTTPSHandler(context=context))
        self.control_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), ENTRY.NoRedirect())
        private_directory(self.directory)
        self.ui = FrameUI({'account': self.case['account'], 'initialPassword': self.case['newPassword'],
                           'controlToken': self.state['controlToken']}, density, self.directory)
        self.token, self.dto, self.checks, self.states = '', None, [], []
        self.stage, self.failure, self.device_started = 'prerequisites', None, False
        self.cleanup = {'loggedOut': False, 'loginInputsEmpty': False, 'privateGameplayAbsent': False,
                        'remoteRawFilesRemoved': True, 'zeroForbiddenWrites': False}

    def ownership(self):
        return [owner(self.state['pid'], ROOT / 'scripts/isolated-backend.mjs', {'start'}, self.ports),
                owner(self.state['tls']['pid'], ROOT / 'scripts/isolated-tls.mjs', {'start', 'resume'}, [urlparse(self.host).port])]

    def immutable(self):
        current = ENTRY.read_state()
        require(ENTRY.EntryMain.identity(current) == self.environment and
                json.dumps(current['gameplay']['cases'].get(self.case_id), sort_keys=True) == self.case_identity and
                json.dumps(current.get('uiContent', {}).get('imports', {}).get(self.import_id), sort_keys=True) == self.import_identity and
                all(sha(path) == self.binding[name] for name, path in self.bound.items()) and self.ownership() == self.births,
                'The exact source, runtime, case or runner ownership changed')

    def request(self, control, route, body=None):
        if control:
            require(route in ('/requests', '/case-progress'), 'No mutating control operation is permitted')
            token, base, opener = self.state['controlToken'], self.control_base, self.control_opener
        else:
            require((route == AUTH and isinstance(body, dict) and set(body) == {'identity', 'password'} and
                     body == {'identity': self.case['account'], 'password': self.case['newPassword']}) or
                    (body is None and route in ('/api/questions/v1/me', BASE, self.detail)), 'Host traffic escaped the exact auth/read allowlist')
            token, base, opener = self.token, self.host, self.host_opener
        request = urllib.request.Request(base + route, data=None if body is None else json.dumps(body).encode(),
            method='GET' if body is None else 'POST', headers={'Accept': 'application/json',
                **({'Authorization': token} if token else {}), **({'Content-Type': 'application/json'} if body is not None else {})})
        try:
            with opener.open(request, timeout=25) as response:
                require(response.status == 200, 'An owned read/auth request did not return200')
                value = json.load(response)
                require(isinstance(value, dict), 'An owned response is not an object')
                return value
        except Exception:
            raise SafeFailure('An exact owned HTTPS/control read failed; values omitted') from None

    def ledger(self):
        rows = self.request(True, '/requests', {}).get('requests')
        require(isinstance(rows, list) and len(rows) < 950 and all(isinstance(row, dict) for row in rows), 'The bounded request ledger is unavailable')
        return rows

    def facts(self):
        value = self.request(True, '/case-progress', {'caseId': self.case_id, 'kind': 'ready'})
        require(value.get('caseId') == self.case_id and value.get('assignmentKind') == 'ready' and
                value.get('readOnlyDiagnostic') is True and value.get('rawAnswersOrCredentialsReturned') is False,
                'The read-only diagnostic does not identify the explicit case')
        require(all(type(value.get(key)) is int and value[key] == 0 for key in ('answerSubmissionCount', 'answerReceiptCount', 'xpLedgerCount', 'xpDeltaSum',
                    'wrongCountTotal', 'lockedProgressRows', 'completedProgressRows')), 'The frame case has answer or settlement facts')
        return value

    def check(self, condition, label):
        require(condition, label)
        self.checks.append(label)
        print(json.dumps({'checksPassed': len(self.checks), 'passed': label}), flush=True)

    def snapshot(self):
        player, listing, detail = [self.request(False, route) for route in ('/api/questions/v1/me', BASE, self.detail)]
        require(player.get('id') == self.case['playerId'] and player.get('account') == self.case['account'] and
                player.get('mustChangePassword') is False and detail.get('id') == self.assignment_id and
                detail.get('player') == self.case['playerId'] and isinstance(listing.get('items'), list) and
                len(listing['items']) == 1 and listing['items'][0].get('id') == self.assignment_id,
                'The strict Host DTOs do not identify the exact same ordinary account/assignment')
        return {'player': player, 'assignments': listing, 'assignment': detail}

    def question(self):
        detail = self.dto['assignment']
        levels = detail.get('levels', [])
        require(len(levels) == 1 and isinstance(levels[0].get('question'), dict) and detail.get('status') == 'active',
                'The real-content capture requires one active own question')
        require(levels[0]['question'].get('kind') == self.case['fixtureLevelKinds'][0], 'The active question kind differs from the case')
        override = levels[0].get('presentationOverride', {})
        hidden = override.get('hideTitle', detail.get('presentation', {}).get('hideTitle', False))
        require(type(hidden) is bool and hidden == self.case['sourceContent']['effectiveHideTitle'], 'The effective title override differs from the source case')
        return levels[0]['question'], hidden

    def theme(self, name):
        self.ui.tap('account-menu')
        self.ui.wait(lambda ui: ui.find('account-side-panel') is not None, 'own theme panel')
        self.ui.tap('theme-' + name)
        self.ui.capture()
        require(self.ui.find('theme-error-message') is None, 'A native theme request failed')
        if self.ui.find('account-side-panel') is not None:
            self.ui.back()
        self.ui.wait(lambda ui: ui.find('account-side-panel') is None and ui.find('account-menu') is not None, 'theme panel dismissed')

    def sample(self, theme):
        question, hidden = self.question()
        self.ui.scroll_top()
        self.ui.seek('question-number')
        raw, record = self.ui.raw_app('frame-top-' + theme)
        self.ui.private_shot('frame-top-' + theme)
        card, inner = UI.rect(own(raw, 'gameplay-question-card')['bounds']), UI.rect(own(raw, 'question-content')['bounds'])
        density, tolerance = self.ui.density, 2 / self.ui.density
        require(abs(self.ui.width / density - 376) <= tolerance and abs((card[2] - card[0]) / density - 352) <= tolerance and
                abs((inner[2] - inner[0]) / density - 314) <= tolerance, 'Actual viewport/card/inner widths are376/352/314vp')
        title_rows = [row for row in raw if row.get('id') == 'question-title']
        shown = not hidden and bool(question.get('title'))
        require(bool(title_rows) == shown and (not shown or len(title_rows) == 1 and title_rows[0].get('text') == question['title']),
                'Actual visible/absent question title matches the effective server presentation')
        typography = {'number': measured_text(own(raw, 'question-number'), density, 14.4),
            'kind': measured_text(own(raw, 'question-kind'), density, 14.4),
            'titleShown': shown, 'title': measured_text(title_rows[0], density, 37.6 * .98) if shown else None,
            'referenceFontSizesFp': {'meta': 12, 'titleAt376': 37.6, 'body': 16}, 'body': []}
        shot = ROOT / self.ui.private_screenshots[-1]['file']
        image = OriginalPng(shot)
        corners = {side: pixel_corner(image, card, density, side) for side in ('top-left', 'top-right')}
        inset_top = pixel_inner(image, card, density)
        inset_left, inset_right = pixel_inner(image, card, density, vertical=True), pixel_inner(image, card, density, True, True)
        for index, block in enumerate(question.get('content', [])):
            if block.get('text'):
                self.ui.reveal_text('question-content-text-' + str(index))
                lines, evidence = self.ui.raw_app('body-' + str(index) + '-' + theme)
                text = own(lines, 'question-content-text-' + str(index))
                require(text.get('text') == block['text'], 'Native body text equals the same Host content block')
                typography['body'].append(measured_text(text, density, 27.52))
                self.ui.private_shot('body-' + str(index) + '-' + theme)
            if block.get('hint'):
                button, content = 'question-hint-' + str(index), 'question-hint-content-' + str(index)
                self.ui.tap(button)
                self.ui.wait(lambda ui: ui.find(content) is not None and ui.find(content).get('text') == block['hint'], 'hint expanded')
                self.ui.private_shot('hint-' + str(index) + '-' + theme)
                self.ui.tap(button)
                self.ui.wait(lambda ui: ui.find(content) is None, 'hint collapsed')
                self.check(True, 'The real hint expands and closes without submitting')
        self.ui.seek('gameplay-leave')
        foot, foot_record = self.ui.raw_app('frame-bottom-' + theme)
        self.ui.private_shot('frame-bottom-' + theme)
        bottom_card = UI.rect(own(foot, 'gameplay-question-card')['bounds'])
        image = OriginalPng(ROOT / self.ui.private_screenshots[-1]['file'])
        corners.update({side: pixel_corner(image, bottom_card, density, side) for side in ('bottom-left', 'bottom-right')})
        inset_bottom = pixel_inner(image, bottom_card, density, True)
        require(all(abs(value[field] - target) <= tolerance for value in corners.values()
                    for field, target in (('horizontalOffsetVp', 13), ('verticalOffsetVp', 13),
                                           ('horizontalLengthVp', 28), ('verticalLengthVp', 28))) and
                abs(inset_top['edgeOffsetVp'] - 6) <= tolerance and abs(inset_bottom['edgeOffsetVp'] - 6) <= tolerance,
                'Original painted corners measure28vp at13vp from the outer border, matching Web CSS12px inside its1px border')
        require(all(abs(value['edgeOffsetVp'] - 6) <= tolerance for value in (inset_left, inset_right)),
                'Original painted inner boundaries match the1px Web outline at offset-7px')
        self.states.append({'themeRequested': theme, 'themePixelReview': 'pending_root_original_review',
            'viewportVp': self.ui.width / density, 'cardBoundsPx': card, 'innerBoundsPx': inner,
            'cardWidthVp': (card[2] - card[0]) / density, 'innerWidthVp': (inner[2] - inner[0]) / density,
            'corners': corners, 'innerTop': inset_top, 'innerBottom': inset_bottom,
            'innerLeft': inset_left, 'innerRight': inset_right, 'typography': typography,
            'hintCountExercised': sum(bool(block.get('hint')) for block in question.get('content', [])),
            'topRawSha256': record['sha256'], 'bottomRawSha256': foot_record['sha256']})
        self.check(True, 'The requested theme frame geometry and same-data typography evidence are captured')

    def verify_ledger(self):
        rows = self.ledger()
        require(rows[:len(self.baseline)] == self.baseline, 'The request ledger was reset, truncated or changed')
        added = rows[len(self.baseline):]
        allowed_get = {'/api/health', '/api/questions/v1/me', BASE, self.detail}
        require(all((row.get('method') == 'GET' and row.get('path') in allowed_get) or
                    (row.get('method') == 'POST' and row.get('path') in (AUTH, self.start)) for row in added),
                'A forbidden business request occurred during this narrow sample')
        require(all(row.get('fault') is False and not row.get('responseDropped') and
                    not row.get('responseAwaitingDelay') for row in added), 'The sample was affected by an unexpected fault or pending response')
        starts = [row for row in added if row.get('method') == 'POST' and row.get('path') == self.start]
        require(len(starts) == self.expected_starts and all(row.get('status') == 200 and row.get('authenticated') is True and
                row.get('bearer') is False and row.get('actorVerifiedByBackendResponse') is True and
                row.get('actorSha256') == hashlib.sha256((self.state['controlToken'] + ':actor:' + self.case['playerId']).encode()).hexdigest()
                for row in starts), 'Only the exact optional single native entry command is allowed')
        self.final_facts = self.facts()
        self.final_ledger = {'baseline': self.baseline, 'added': added}
        self.cleanup['zeroForbiddenWrites'] = True

    def main(self):
        self.stage = 'host-auth-and-own-dtos'
        auth = self.request(False, AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
        require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str) and auth['token'],
                'Host authentication did not identify the exact case')
        self.token = auth['token']
        before = self.snapshot()
        require(before['assignment'].get('status') in ('assigned', 'active'), 'The sample case is neither fresh nor active')
        facts = self.facts()
        self.expected_starts = 1 if before['assignment']['status'] == 'assigned' else 0
        require(facts.get('startReceiptCount') == (0 if self.expected_starts else 1), 'The case entry receipt baseline is inconsistent')
        levels = before['assignment'].get('levels')
        require(isinstance(levels, list) and len(levels) == 1 and
                (not before['assignment'].get('startedAt') and levels[0].get('question') is None and facts.get('progressRows') == 0
                 if self.expected_starts else bool(before['assignment'].get('startedAt')) and
                    isinstance(levels[0].get('question'), dict) and facts.get('progressRows') == 1),
                'The case start state and protected-question boundary are inconsistent')
        self.baseline = self.ledger()
        self.immutable()
        self.stage = 'native-entry-and-frame'
        self.ui.launch(cold=True)
        self.device_started = True
        self.ui.wait(lambda ui: ui.find('account') is not None, 'cold isolated empty login')
        require(self.ui.input_empty('account') and self.ui.input_empty('password') and self.ui.has_text('隔离测试环境'), 'The own isolated native login is not empty')
        self.ui.fill('account', self.case['account'])
        self.ui.fill('password', self.case['newPassword'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('old-password') is None, 'ordinary direct login')
        self.ui.tap('assignment-' + self.assignment_id)
        if self.expected_starts:
            self.ui.wait(lambda ui: ui.find('start-assignment') is not None, 'explicit assigned detail')
            self.ui.tap('start-assignment')
        self.ui.wait(lambda ui: ui.find('gameplay-page') is not None and ui.find('gameplay-loading') is None and
                     ui.find('gameplay-question-card') is not None, 'active question frame', timeout=40)
        self.dto = self.snapshot()
        self.question()
        self.fixture = write_private(self.directory / 'web-dtos.json', self.dto,
            (self.case['newPassword'], self.state['controlToken'], self.token))
        for theme in ('light', 'dark'):
            self.theme(theme)
            self.sample(theme)
            self.verify_ledger()
            self.immutable()
        self.stage = 'return-and-get-resume'
        self.ui.back()
        self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('gameplay-page') is None, 'Back without answer')
        self.ui.tap('assignment-' + self.assignment_id)
        self.ui.wait(lambda ui: ui.find('gameplay-question-card') is not None and ui.find('start-assignment') is None, 'GET-only resume')
        self.verify_ledger()
        self.check(True, 'Back and same active re-entry use GET without another start or any answer')

    def logout(self):
        self.ui.capture()
        if self.ui.find('account-side-panel') is not None:
            self.ui.back()
            self.ui.wait(lambda ui: ui.find('account-side-panel') is None, 'close own panel before cleanup')
        if self.ui.find('gameplay-page') is not None:
            self.ui.back()
            self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'home before sample logout')
        if self.ui.find('account-menu') is not None and self.ui.find('account') is None:
            self.ui.tap('account-menu')
            self.ui.tap('logout')
        self.ui.wait(lambda ui: ui.find('account') is not None, 'sample logout')
        self.cleanup['loggedOut'] = True
        self.cleanup['loginInputsEmpty'] = self.ui.input_empty('account') and self.ui.input_empty('password')
        self.cleanup['privateGameplayAbsent'] = all(self.ui.find(key) is None for key in ('gameplay-page', 'gameplay-question-card', 'question-title'))
        require(all(self.cleanup[key] for key in ('loggedOut', 'loginInputsEmpty', 'privateGameplayAbsent')), 'Logout did not clear private page and inputs')

    def execute(self):
        try:
            self.main()
        except Exception as error:
            reason = str(error)
            for secret in (self.case['newPassword'], self.state['controlToken'], self.token):
                if secret:
                    reason = reason.replace(secret, '[credential omitted]')
            write_private(self.directory / 'failure-diagnostic.json',
                {'stage': self.stage, 'exceptionType': type(error).__name__, 'reason': reason},
                (self.case['newPassword'], self.state['controlToken'], self.token))
            self.failure = 'The narrow frame/type sample stopped; raw diagnostics are private and no parity pass is claimed'
        finally:
            try:
                self.immutable()
                if self.device_started:
                    self.logout()
                    self.verify_ledger()
            except Exception:
                self.failure = self.failure or 'Exact sample cleanup or ownership could not be confirmed'
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not all(self.cleanup.values()):
                self.failure = self.failure or 'The narrow cleanup/zero-write observations are incomplete'
        ledger_evidence = None
        if hasattr(self, 'final_ledger'):
            ledger_evidence = write_private(self.directory / 'request-ledger.json', self.final_ledger,
                (self.case['newPassword'], self.state['controlToken'], self.token))
        if self.failure is None:
            self.stage = 'frame-sample-complete'
        report = {'status': 'incomplete' if self.failure else 'passed', 'stage': self.stage,
            'scope': 'Question card frame and typography evidence only', 'visualReview': 'pending_root_original_review',
            'businessAcceptanceClaimed': False, 'imageInputChoiceProgressRefreshHeaderHideParityClaimed': False,
            'hapSha256': self.hap_sha, 'expectedFixtureSha256': self.args.expected_fixture_sha,
            'sourceCaseIndex': self.case['sourceContent']['sourceCaseIndex'], 'bindingSha256': self.binding,
            'checksPassed': len(self.checks), 'checks': self.checks, 'states': self.states, 'cleanup': self.cleanup,
            'privateScreenshots': self.ui.private_screenshots, 'privateRawEvidence': self.ui.raw_evidence,
            'sameDataWebFixture': getattr(self, 'fixture', None), 'fixedPreviewTouched': False,
            'privateReadOnlyLedger': ledger_evidence,
            'writeScope': 'Host auth/read and optional single native start only; no answer/profile/password/reset/fault/service operation',
            'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
        if self.failure:
            report['failure'] = self.failure
        encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        secrets = [self.case_id, self.case['account'], self.case['newPassword'], self.case['playerId'], self.assignment_id,
                   self.case['assignments']['ready']['sessionId'], self.state['controlToken'], self.token]
        require(not any(secret and secret in encoded for secret in secrets) and not re.search(r'https?://', encoded),
                'A private literal would enter the public report')
        fresh(self.report, VALIDATION)
        self.report.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream:
            stream.write(encoded)
        print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks),
                          'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 1 if self.failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-reviewed explicit isolated native frame sample')
    for name in ('runtime', 'case-ref', 'output', 'private-dir'):
        run.add_argument('--' + name, type=Path, required=True)
    run.add_argument('--expected-hap', required=True)
    run.add_argument('--expected-fixture-sha', required=True)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        return FrameSample(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
            'error': 'Exact case/fixture/runtime/owner/output guards did not complete; values omitted'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

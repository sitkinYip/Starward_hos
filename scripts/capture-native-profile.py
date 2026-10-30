#!/usr/bin/env python3
"""Capture private Task1 ArkUI profile/menu references on the owned HTTPS phone.

Requires a passed same-HAP core run and its actual runtime report. Uses a matching
passed S2 password key when available. Never edits a profile/password or claims
Web equivalence; the output is evidence for a separate visual comparison.
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
import shutil
import statistics
import subprocess
import time

from native_device_ui import ROOT, IsolationControl, SafeFailure
from native_system_visual import png_pixels, COLORS

SPEC = importlib.util.spec_from_file_location('profile_core_visual', Path(__file__).with_name('device-profile-acceptance.py'))
CORE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CORE)
OUT = ROOT / 'artifacts/validation/profile'
REPORT = OUT / 'native-profile-visual.json'
HAP = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
PRIVATE = ROOT / 'artifacts/private/native-profile-visual'
MENU_IDS = ('menu-home', 'menu-rewards', 'menu-notifications', 'menu-profile')
PASSWORD_IDS = ('security-old-password', 'security-new-password', 'security-confirm-password')
GEOMETRY_IDS = ('account-menu', 'profile-passport', 'profile-identity-tab', 'profile-security-tab',
                'profile-avatar-pick', 'profile-name', 'profile-account', 'profile-save',
                *PASSWORD_IDS, 'security-save', *MENU_IDS, 'theme-picker',
                'theme-dark', 'theme-light', 'logout', 'nav-home', 'nav-profile')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def private_json(path, value):
    if path.is_symlink():
        raise SafeFailure('Private visual output cannot be a symlink')
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as output:
        json.dump(value, output, ensure_ascii=False, indent=2)
        output.write('\n')
    path.chmod(0o600)


class ProfileVisualUI(CORE.ProfileUI):
    def __init__(self, state, density, directory):
        super().__init__(state, density)
        self.output = directory
        self.shots = directory

    def minimum_height(self, node_id, node):
        if node_id in MENU_IDS:
            return 52 * self.density - 2
        return super().minimum_height(node_id, node)

    def scroll_node(self, scope):
        if scope == 'profile':
            node = self.find('profile-scroll')
            if node and node.get('type') == 'Scroll' and node.get('bounds'):
                return node
        elif scope == 'menu':
            for node_id in (*MENU_IDS, 'logout', 'theme-picker'):
                path = self.path_to(node_id)
                scroll = next((n for n in reversed(path or []) if n.get('type') == 'Scroll' and n.get('bounds')), None)
                if scroll:
                    return scroll
        raise SafeFailure('The intended native profile/menu Scroll is not visible')

    def scoped_view(self, scope):
        bounds = self.scroll_node(scope)['bounds']
        app = self.app_rect()
        view = [max(bounds[0], app[0]), max(bounds[1], app[1]), min(bounds[2], app[2]), min(bounds[3], app[3])]
        if scope == 'profile':
            path = self.path_to('nav-home')
            bar = next((n for n in reversed(path or []) if n.get('type') == 'TabBar' and n.get('bounds')), None)
            if bar and view[1] < bar['bounds'][1] < view[3]:
                view[3] = bar['bounds'][1]
        return view

    def scroll_top(self, scope):
        previous = None
        stable = 0
        for attempt in range(18):
            self.capture()
            node = self.scroll_node(scope)
            def geometry(value):
                result = []
                def visit(item):
                    if isinstance(item, dict):
                        if item.get('bounds'):
                            result.append((item.get('id', ''), item.get('type', ''), tuple(item['bounds'])))
                        for child in item.get('children', []):
                            visit(child)
                visit(value)
                return tuple(result)
            current = geometry(node)
            stable = stable + 1 if current == previous else 0
            if stable >= 2:
                return {'stableObservations': stable + 1, 'positioningSwipes': attempt,
                        'scrollBoundsPx': node['bounds'], 'interactionViewportPx': self.scoped_view(scope)}
            previous = current
            left, top, right, bottom = self.scoped_view(scope)
            if right-left < 80 or bottom-top < 150:
                raise SafeFailure('Native profile/menu viewport is too small for safe positioning')
            x = int(left + (right-left)*.57)
            self.run('devecocli', 'ui', 'swipe', x, int(top+(bottom-top)*.30),
                     x, int(top+(bottom-top)*.76))
        raise SafeFailure('Native profile/menu Scroll did not reach a stable top')


class Capture:
    def __init__(self, args):
        self.args = args
        self.control = IsolationControl()
        self.state = self.control.state
        if not self.state.get('account', '').startswith('hm_'):
            raise SafeFailure('Only the dedicated disposable test player is supported')
        config = json.loads((ROOT / 'entry/src/main/resources/rawfile/integration.json').read_text())
        if config.get('isolated') is not True or config.get('endpoint') != self.state['tls']['base']:
            raise SafeFailure('The current packaged configuration must identify this isolated HTTPS origin')
        self.runtime_path = args.runtime_report.resolve()
        self.core_path = args.core_report.resolve()
        for path in (self.runtime_path, self.core_path):
            if not path.is_relative_to(OUT.resolve()) or path.is_symlink():
                raise SafeFailure('Native profile prerequisites must remain in profile validation')
        self.hap = sha(HAP)
        self.runtime_sha, self.core_sha = sha(self.runtime_path), sha(self.core_path)
        runtime, core = json.loads(self.runtime_path.read_text()), json.loads(self.core_path.read_text())
        window = runtime.get('window', {})
        if (runtime.get('status') != 'passed' or runtime.get('installedHapSha256') != self.hap or
                not all(isinstance(window.get(key), (int, float)) and not isinstance(window[key], bool) and
                            math.isfinite(window[key]) and window[key] > 0 for key in ('density','widthPx','heightPx'))):
            raise SafeFailure('Actual profile runtime must bind the current signed HAP and measured window')
        if (core.get('status') != 'passed' or core.get('hap', {}).get('packagedSha256') != self.hap or
                core.get('runtime', {}).get('sha256') != self.runtime_sha or
                not all(core.get('cleanup', {}).get(k) is True for k in ('loggedOut','faultNeutralised'))):
            raise SafeFailure('Native profile visuals require a cleaned-up passed core run on the same HAP/runtime')
        self.password_key = core.get('finalPasswordKey')
        self.password_source = {'kind': 'matching passed core', 'sha256': self.core_sha}
        self.s2_path = OUT / 'device-profile-password-uncertain.json'
        self.s2_sha = None
        if self.s2_path.exists():
            s2 = json.loads(self.s2_path.read_text())
            same_build = s2.get('hap', {}).get('packagedSha256') == self.hap and s2.get('runtime', {}).get('sha256') == self.runtime_sha
            if same_build:
                if (s2.get('status') != 'passed' or s2.get('corePrerequisite', {}).get('sha256') != self.core_sha or
                        not all(s2.get('cleanup', {}).get(k) is True for k in ('loggedOut','faultNeutralised'))):
                    raise SafeFailure('Matching S2 is incomplete or stale; resolve the password before visual capture')
                self.password_key = s2.get('finalPasswordKey')
                self.s2_sha = sha(self.s2_path)
                self.password_source = {'kind': 'matching passed S2', 'sha256': self.s2_sha}
        if self.password_key not in ('initialPassword','newPassword'):
            raise SafeFailure('A verified current password key is required')
        self.avatar_prerequisite = {'present': False, 'basicUploadPhaseCompleted': False}
        avatar_path = OUT / 'device-profile-avatar.json'
        if avatar_path.exists():
            avatar = json.loads(avatar_path.read_text())
            matches = avatar.get('hap', {}).get('packagedSha256') == self.hap and avatar.get('runtime', {}).get('sha256') == self.runtime_sha
            self.avatar_prerequisite = {'present': True, 'matchesCurrentBuild': matches,
                'sourceSha256': sha(avatar_path), 'status': avatar.get('status'),
                'basicUploadPhaseCompleted': matches and 'avatar-saved' in avatar.get('phases', [])}
        self.window = {key: window.get(key) for key in ('widthPx','heightPx','density','fontScale','topInsetPx','bottomInsetPx',
                      'leftInsetPx','rightInsetPx','immersiveLayout','statusBarColor','navigationBarColor')}
        self.directory = PRIVATE / ('capture-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
        self.directory.mkdir(parents=True, mode=0o700, exist_ok=False)
        self.directory.chmod(0o700)
        self.ui = ProfileVisualUI(self.state, window['density'], self.directory)
        self.records, self.theme_records = [], []
        self.started_at = now()
        self.cleanup = {'loggedOut': False, 'loginInputsEmpty': False, 'hilogStopped': False}
        self.initial_write_count = self.write_count()
        self.device_started = False
        self.raw_log = self.directory / 'metrics-hilog.log'
        self.log_process = None
        self.log_sink = None
        self.theme = None
        if REPORT.exists():
            attempts = OUT / 'attempts'
            attempts.mkdir(exist_ok=True)
            shutil.copyfile(REPORT, attempts / ('native-profile-' + self.directory.name + '.json'))
        self.report('running')

    def write_count(self):
        return sum(r.get('method') in ('POST','PATCH') and r.get('path') in
                   ('/api/questions/v1/me/profile','/api/questions/v1/me/change-password')
                   for r in self.control.requests())

    def immutable(self):
        if (sha(HAP) != self.hap or sha(self.runtime_path) != self.runtime_sha or sha(self.core_path) != self.core_sha or
                self.s2_sha is not None and sha(self.s2_path) != self.s2_sha):
            raise SafeFailure('A prerequisite HAP/runtime/acceptance report changed during visual capture')

    def report(self, status, error=None):
        value = {'status': status, 'scope': 'Task1 actual ArkUI profile/menu screenshots and safe geometry',
            'startedAt': self.started_at, 'updatedAt': now(), 'count': len(self.records), 'states': self.records,
            'environment': 'Dedicated isolated HTTPS player; screenshots and raw UI remain private',
            'hap': {'packagedSha256': self.hap, 'installationEvidence': 'Separate official scripts/hm.sh run log is required'},
            'runtime': {'file': str(self.runtime_path.relative_to(ROOT)), 'sha256': self.runtime_sha},
            'corePrerequisite': {'file': str(self.core_path.relative_to(ROOT)), 'sha256': self.core_sha},
            'passwordSource': self.password_source, 'avatarPrerequisite': self.avatar_prerequisite,
            'window': self.window, 'actualThemeRecords': self.theme_records, 'cleanup': self.cleanup,
            'privateOriginals': str(self.directory.relative_to(ROOT)),
            'businessWritesObserved': self.write_count()-self.initial_write_count,
            'webComparisonPerformed': False,
            'acceptanceCredit': 'Actual phone captures, theme and geometry only; Web consistency requires separate visual review',
            'notExecuted': ['Cross-device/foldable/hover/window tests are deferred',
                            'Screenshots alone do not prove avatar pixels, pending writes or all business error states']}
        if self.raw_log.exists() and self.cleanup['hilogStopped']:
            value['privateMetricsLog'] = {'file': str(self.raw_log.relative_to(ROOT)), 'sha256': sha(self.raw_log)}
        if error:
            value['error'] = self.ui.redact(error)
        REPORT.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

    def start_log(self):
        self.log_sink = self.raw_log.open('w')
        self.raw_log.chmod(0o600)
        self.log_process = subprocess.Popen(['hdc','shell','hilog','-T','StarwardMetrics'],
            stdout=self.log_sink, stderr=subprocess.STDOUT)

    def metrics_since(self, offset):
        try:
            raw = self.raw_log.read_bytes()[offset:].decode('utf-8', errors='replace')
        except OSError:
            return []
        result = []
        for line in raw.splitlines():
            match = re.search(r'(\{.*\})', line)
            if match:
                try:
                    item = json.loads(match.group(1))
                except ValueError:
                    continue
                if isinstance(item, dict) and 'density' in item and 'appColorMode' in item:
                    result.append(item)
        return result

    def choose_theme(self, theme):
        # Switching via the opposite explicit mode guarantees a fresh native
        # configuration observation even if the system already has this theme.
        opposite = 'light' if theme == 'dark' else 'dark'
        self.ui.tap('theme-'+opposite)
        self.ui.wait(lambda u: u.find('theme-'+opposite) is not None, 'opposite native theme control')
        offset = self.raw_log.stat().st_size
        self.ui.tap('theme-'+theme)
        self.ui.wait(lambda u: u.find('theme-'+theme) is not None, 'requested native theme control')
        expected = 0 if theme == 'dark' else 1
        deadline = time.monotonic()+8
        selected = None
        while time.monotonic() < deadline:
            rows = self.metrics_since(offset)
            if rows and rows[-1].get('appColorMode') == expected:
                selected = rows[-1]
                break
            time.sleep(.15)
        if not selected:
            raise SafeFailure('No fresh actual native color-mode record matched the requested theme')
        for key in ('widthPx','heightPx','density','fontScale'):
            expected_value = self.window.get(key)
            if expected_value is not None and (not isinstance(selected.get(key), (int,float)) or abs(selected[key]-expected_value) > .01):
                raise SafeFailure('Native theme reconfiguration changed the measured capture window or font')
        if selected.get('statusBarContentColor') != ('#FFFFFFFF' if theme == 'dark' else '#FF000000'):
            raise SafeFailure('Actual system-bar content did not match the native theme')
        self.theme = theme
        self.theme_records.append({'requestedTheme': theme, 'logStartByteOffset': offset,
            'record': {key: selected.get(key) for key in ('appColorMode','widthPx','heightPx','density','fontScale',
                'statusBarContentColor','navigationBarContentColor','statusBarColor','navigationBarColor','immersiveLayout')},
            'verification': 'Fresh official StarwardMetrics record after native theme selection; raw log kept private'})

    def login(self):
        self.ui.wait(lambda u: u.find('account') is not None, 'blank native visual login')
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('Native visual capture requires empty login fields')
        before = len(self.owner_files())
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state[self.password_key])
        self.ui.tap('primary-action')
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'native visual authenticated home')
        if self.avatar_prerequisite.get('basicUploadPhaseCompleted'):
            deadline = time.monotonic()+25
            while time.monotonic() < deadline:
                rows = self.owner_files()[before:]
                if any(r.get('status') == 200 and not r.get('fault') for r in rows):
                    break
                time.sleep(.2)
            else:
                raise SafeFailure('Uploaded avatar did not finish a new real native protected-file GET before visual capture')

    def owner_files(self):
        prefix = '/api/files/game_players/'+self.state['playerId']+'/'
        return [r for r in self.control.requests() if r.get('method') == 'GET' and str(r.get('path','')).startswith(prefix)]

    def profile(self):
        self.ui.tap('nav-profile')
        self.ui.wait(lambda u: u.find('profile-scroll') is not None, 'native profile Scroll destination')

    def logout(self):
        self.ui.hide_keyboard()
        self.ui.capture()
        if self.ui.find('account') is None:
            menu_open = any(self.ui.find(node_id) is not None for node_id in MENU_IDS) or self.ui.find('logout') is not None or self.ui.has_text('冒险者菜单')
            if not menu_open:
                self.ui.tap('account-menu')
            self.ui.seek('logout')
            self.ui.tap('logout')
            self.ui.wait(lambda u: u.find('account') is not None, 'native visual explicit logout')
        self.cleanup['loggedOut'] = True
        self.cleanup['loginInputsEmpty'] = self.ui.input_empty('account') and self.ui.input_empty('password')
        if not self.cleanup['loginInputsEmpty']:
            raise SafeFailure('Native visual logout did not clear login fields')

    def control_geometry(self, scope):
        view = self.ui.scoped_view(scope)
        result = []
        for node_id in GEOMETRY_IDS:
            node = self.ui.find(node_id)
            if not node or not node.get('bounds'):
                continue
            bounds = node['bounds']
            inside = bounds[0] >= view[0] and bounds[1] >= view[1] and bounds[2] <= view[2] and bounds[3] <= view[3]
            result.append({'id': node_id, 'type': node.get('type'), 'boundsPx': bounds,
                'boundsVp': [round(x/self.ui.density,3) for x in bounds],
                'insideContentInteractionViewport': inside,
                'visibleHeightVp': round((bounds[3]-bounds[1])/self.ui.density,3)})
        return {'appRootBoundsPx': self.ui.app_rect(), 'contentInteractionViewportPx': view,
                'controls': result, 'keyboardVisible': self.ui.keyboard_visible()}

    def canvas(self, target):
        # A fixed rule from the actual20vp profile side padding, chosen before
        # inspecting colours. Sheet material is intentionally not forced flat.
        view = self.ui.scroll_node('profile')['bounds']
        point = [round(view[0]+8*self.ui.density), round(view[1]+min(160*self.ui.density,(view[3]-view[1])*.5))]
        x,y = point
        width,height,channels,rows = png_pixels(target, through_row=y+2)
        if not (2 <= x < width-2 and 2 <= y < height-2):
            raise SafeFailure('Profile canvas sample falls outside the captured physical screen')
        values = [[rows[py][px*channels+c] for py in range(y-2,y+3) for px in range(x-2,x+3)] for c in range(3)]
        observed = [int(statistics.median(v)) for v in values]
        flat = all(max(v)-min(v)<=4 for v in values)
        matches = flat and all(abs(a-b)<=4 for a,b in zip(observed,COLORS[self.theme]))
        return {'pointPx':point,'observedRGB':observed,'expectedRGB':list(COLORS[self.theme]),
                'flat5x5':flat,'themeVerified':matches,
                'rule':'8vp into actual20vp side padding;160vp below profile Scroll top, capped at half its height'}

    def take(self, state, scope, anchor=None, top=None):
        self.immutable()
        self.ui.hide_keyboard()
        self.ui.capture()
        if self.ui.keyboard_visible():
            raise SafeFailure('Native visual capture requires the keyboard to be closed')
        for node in self.ui.flat:
            if node.get('id') in PASSWORD_IDS and node.get('text'):
                raise SafeFailure('Nonempty native password fields prevented visual capture')
        if anchor:
            self.ui.seek(anchor)
            node = self.ui.find(anchor)
            required = (52 if anchor in ('profile-save','security-save') else 44)*self.ui.density-2
            if not node or node['bounds'][3]-node['bounds'][1] < required:
                raise SafeFailure('A primary native action is partially clipped at capture time')
        name = state+'-'+self.theme
        self.ui.capture(name)
        tree = self.directory/('ui-'+name+'.json')
        tree.chmod(0o600)
        geometry = self.control_geometry(scope)
        target = self.ui.screenshot(name)
        target.chmod(0o600)
        width,height,_,_ = png_pixels(target, through_row=0)
        if abs(width-self.window['widthPx'])>1 or abs(height-self.window['heightPx'])>1:
            raise SafeFailure('Native screenshot dimensions differ from the bound physical window')
        paint = self.canvas(target) if scope == 'profile' else None
        if paint and not paint['themeVerified']:
            raise SafeFailure('The actual profile screenshot canvas did not show the requested native theme')
        item = {'state':state,'theme':self.theme,'screenshot':str(target.relative_to(ROOT)),
            'screenshotSha256':sha(target),'uiTree':str(tree.relative_to(ROOT)),'uiTreeSha256':sha(tree),
            'pixels':[width,height],'actualThemeVerified':True,'actualThemeRecordIndex':len(self.theme_records)-1,
            'canvas':paint,'safeGeometry':geometry,'topBoundary':top,
            'businessAcceptance':False,'webConsistencyClaimed':False}
        self.records.append(item)
        self.report('running')
        return item

    def capture_theme(self, theme):
        self.choose_theme(theme)
        self.login()
        self.profile()
        self.ui.tap('profile-identity-tab')
        top = self.ui.scroll_top('profile')
        self.take('profile-identity-top','profile',top=top)
        self.ui.seek('profile-save')
        self.take('profile-identity-bottom','profile',anchor='profile-save')
        self.ui.tap('profile-security-tab')
        for field in PASSWORD_IDS:
            self.ui.seek(field)
            if self.ui.find(field).get('text'):
                raise SafeFailure('The native security tab did not start with empty passwords')
        top = self.ui.scroll_top('profile')
        self.take('profile-security-top','profile',top=top)
        self.ui.seek('security-save')
        self.take('profile-security-bottom','profile',anchor='security-save')
        self.ui.tap('account-menu')
        self.ui.seek('menu-home')
        top = self.ui.scroll_top('menu')
        first = self.take('profile-menu-top','menu',top=top)
        seen = {n['id'] for n in first['safeGeometry']['controls'] if n['insideContentInteractionViewport']}
        if not set(MENU_IDS).issubset(seen):
            self.ui.seek('menu-profile')
            self.take('profile-menu-destinations','menu')
        self.ui.seek('logout')
        self.take('profile-menu-bottom','menu',anchor='logout')
        self.logout()

    def run(self):
        failure = None
        try:
            self.start_log()
            # Do not manufacture the blank-login precondition by wiping an
            # unfinished avatar/profile session. Verify it before cold launch.
            self.ui.launch()
            self.ui.wait(lambda u: u.find('account') is not None, 'pre-existing blank login before native visuals')
            if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
                raise SafeFailure('Native visuals require the previous task to finish at blank login')
            self.device_started = True
            self.ui.launch(cold=True)
            self.ui.wait(lambda u: u.find('account') is not None, 'empty isolated login for native profile visuals')
            if not self.ui.has_text('隔离测试环境') or self.ui.has_text('演示环境'):
                raise SafeFailure('The phone did not identify the dedicated HTTPS environment')
            for theme in ('dark','light'):
                self.cleanup['loggedOut'] = False
                self.cleanup['loginInputsEmpty'] = False
                self.capture_theme(theme)
            self.ui.back()
            self.ui.launch()
            self.ui.wait(lambda u: u.find('account') is not None, 'visual logout Back and Ability boundary')
            if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
                raise SafeFailure('Back/relaunch restored login inputs after visual logout')
            self.immutable()
            if self.write_count() != self.initial_write_count:
                raise SafeFailure('Visual capture unexpectedly submitted a profile or password write')
            for theme in ('dark','light'):
                states = {r['state'] for r in self.records if r['theme']==theme}
                if not {'profile-identity-top','profile-identity-bottom','profile-security-top',
                        'profile-security-bottom','profile-menu-top','profile-menu-bottom'}.issubset(states):
                    raise SafeFailure('A requested native profile visual state is missing')
        except Exception as error:
            private_json(self.directory/'capture-error.json', {'type':type(error).__name__,'message':str(error)})
            failure = str(error) if isinstance(error,SafeFailure) else 'Native profile capture stopped before all states completed'
        finally:
            if self.device_started and not self.cleanup['loggedOut']:
                try:
                    self.logout()
                except Exception:
                    failure = failure or 'Native visual explicit logout cleanup did not complete'
            if self.log_process:
                self.log_process.terminate()
                try:
                    self.log_process.wait(timeout=5)
                    self.cleanup['hilogStopped'] = True
                except subprocess.TimeoutExpired:
                    self.log_process.kill()
                    self.log_process.wait(timeout=5)
                    self.cleanup['hilogStopped'] = True
            if self.log_sink:
                self.log_sink.close()
            if not all(self.cleanup.values()):
                failure = failure or 'Native profile visual cleanup was incomplete'
            self.report('incomplete' if failure else 'passed', failure)
        print(json.dumps({'status':'incomplete' if failure else 'passed','count':len(self.records),
            'themes':len(self.theme_records),'webComparisonPerformed':False,
            'report':str(REPORT.relative_to(ROOT))},ensure_ascii=False))
        return 1 if failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-report',type=Path,default=OUT/'runtime.json')
    parser.add_argument('--core-report',type=Path,default=OUT/'device-profile-acceptance.json')
    args = parser.parse_args()
    try:
        return Capture(args).run()
    except Exception as error:
        text = str(error) if isinstance(error,SafeFailure) else 'Native profile setup stopped before capture began'
        print(json.dumps({'status':'incomplete','error':text},ensure_ascii=False))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

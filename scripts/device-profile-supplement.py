#!/usr/bin/env python3
"""Supplement Task1 phone acceptance after the core and S2 runs have passed.

This script owns no service and never resets the player or submits profile or
password writes. The operator must exclusively own the phone and the dedicated
control endpoint. All screenshots and UI trees stay private. It verifies only
the states actually observed; a missing accessibility selection field is
reported as unobservable, not counted as a successful selection assertion.
"""
import argparse
import datetime
import importlib.util
import json
import math
from pathlib import Path
import shlex
import shutil
import time

from isolated_snapshot import ReadonlySnapshot
from native_device_ui import ROOT, IsolationControl, SafeFailure, flatten, sanitise

SPEC = importlib.util.spec_from_file_location(
    'profile_supplement_core', Path(__file__).with_name('device-profile-acceptance.py'))
CORE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CORE)
PROFILE_OUT = CORE.OUT
OUT = PROFILE_OUT / 'supplement'
REPORT = OUT / 'device-profile-supplement.json'
LIST = '/api/questions/v1/assignments'
PROFILE = CORE.PROFILE
CHANGE = CORE.CHANGE
MAX_LENGTH_PROBE = '0123456789012345678901234567890123456789X'
SECURITY_PROBES = ('Supplement-Old-Probe', 'Supplement-New-Probe', 'Supplement-New-Probe')


class SupplementUI(CORE.ProfileUI):
    def __init__(self, state, density, stamp):
        super().__init__(state, density)
        self.output = OUT
        self.shots = ROOT / 'artifacts/private/profile-device/supplement' / stamp
        self.shots.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.shots.chmod(0o700)
        self.private_trees = []

    def capture(self, name=None):
        # The parent capture without a name does not write a public UI tree.
        result = super().capture()
        if name:
            target = self.shots / ('ui-' + name + '.json')
            target.write_text(json.dumps(self.redact(sanitise(self.tree)), ensure_ascii=False, indent=2) + '\n')
            target.chmod(0o600)
            self.private_trees.append({'file': str(target.relative_to(ROOT)), 'sha256': CORE.sha(target),
                                       'scope': 'Private sanitised original UI tree'})
        return result

    def menu_scope(self):
        for node_id in ('menu-home', 'menu-profile', 'menu-rewards', 'menu-notifications', 'logout'):
            path = self.path_to(node_id)
            if path:
                scroll = next((node for node in reversed(path)
                               if node.get('type') == 'Scroll' and node.get('bounds')), None)
                if scroll:
                    return scroll
        return None

    def swipe(self, direction):
        self.capture()
        menu = self.menu_scope()
        rect = menu['bounds'] if menu else self.viewport()
        app = self.app_rect()
        left, top, right, bottom = (max(rect[0], app[0]), max(rect[1], app[1]),
                                    min(rect[2], app[2]), min(rect[3], app[3]))
        if right - left < 80 or bottom - top < 150:
            raise SafeFailure('Supplement scroll viewport is too small for a safe gesture')
        x = int(left + (right - left) * .58)
        low, high = int(top + (bottom - top) * .76), int(top + (bottom - top) * .30)
        start, end = (low, high) if direction == 'down' else (high, low)
        self.run('devecocli', 'ui', 'swipe', x, start, x, end)

    def seek_text(self, text, scope_id=None, menu=False, max_swipes=12):
        for direction in ('down', 'up'):
            previous = None
            for attempt in range(max_swipes + 1):
                self.capture()
                scope = self.menu_scope() if menu else self.find(scope_id) if scope_id else self.tree
                nodes = flatten(scope) if scope is not None else []
                if menu and scope:
                    app = self.app_rect()
                    bounds = scope['bounds']
                    view = [max(app[0], bounds[0]), max(app[1], bounds[1]),
                            min(app[2], bounds[2]), min(app[3], bounds[3])]
                else:
                    view = self.viewport(scope_id)
                for node in nodes:
                    bounds = node.get('bounds')
                    if (node.get('type') == 'Text' and node.get('text') == text and bounds and
                            bounds[2] > bounds[0] and bounds[3] > bounds[1] and
                            bounds[1] >= view[1] + 2 and bounds[3] <= view[3] - 2):
                        return node
                fingerprint = self.visible_fingerprint()
                if previous == fingerprint:
                    break
                previous = fingerprint
                if attempt < max_swipes:
                    self.swipe(direction)
        # Text can contain account-specific server content, so never echo it.
        raise SafeFailure('Expected authoritative supplement text is not reachable in its intended container')

    def type_length_probe(self):
        self.hide_keyboard()
        self.seek('profile-name')
        self.run('devecocli', 'ui', 'click', '--id', 'profile-name')
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017')
        self.run('hdc', 'shell', 'uitest', 'uiInput', 'keyEvent', '2055')
        self.capture()
        field = self.find('profile-name')
        if field is None or field.get('text', ''):
            raise SafeFailure('Supplement could not verify an empty nickname input before its length probe')
        # DeviceUI.fill expects its entire argument to survive. Here the real
        # TextInput must truncate41 ASCII characters to40 instead.
        self.run('hdc', 'shell', 'uitest uiInput text ' + shlex.quote(MAX_LENGTH_PROBE))
        self.back()
        self.capture()
        field = self.find('profile-name')
        if field is None or field.get('text') != MAX_LENGTH_PROBE[:40]:
            raise SafeFailure('Native nickname TextInput did not truncate the actual41-character input to its first40 characters')


class SupplementAcceptance:
    def __init__(self, runtime_path, core_path, s2_path):
        self.control = IsolationControl()
        self.state = self.control.state
        self.paths = {'runtime': runtime_path.resolve(), 'core': core_path.resolve(), 's2': s2_path.resolve()}
        if any(not path.is_relative_to(PROFILE_OUT.resolve()) for path in self.paths.values()):
            raise SafeFailure('Supplement prerequisite reports must remain in the profile validation directory')
        self.hashes = {name: CORE.sha(path) for name, path in self.paths.items()}
        reports = {name: json.loads(path.read_text()) for name, path in self.paths.items()}
        self.hap_path = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
        self.hap_sha = CORE.sha(self.hap_path)
        runtime, core, s2 = reports['runtime'], reports['core'], reports['s2']
        config = json.loads((ROOT / 'entry/src/main/resources/rawfile/integration.json').read_text())
        if (config.get('isolated') is not True or config.get('endpoint') != self.state['tls']['base'] or
                not self.state.get('account', '').startswith('hm_')):
            raise SafeFailure('Supplement requires the packaged dedicated strict-HTTPS environment')
        density = runtime.get('window', {}).get('density')
        if (runtime.get('status') != 'passed' or runtime.get('installedHapSha256') != self.hap_sha or
                not runtime.get('checks') or not all(runtime['checks'].values()) or
                not isinstance(density, (int, float)) or not math.isfinite(density) or density <= 0):
            raise SafeFailure('Supplement runtime must be passed and match the packaged HAP')
        for name, report in (('core', core), ('s2', s2)):
            if (report.get('status') != 'passed' or not isinstance(report.get('count'), int) or
                    report['count'] <= 0 or report['count'] != len(report.get('checks', [])) or
                    report.get('hap', {}).get('packagedSha256') != self.hap_sha or
                    report.get('runtime', {}).get('sha256') != self.hashes['runtime'] or
                    report.get('cleanup', {}).get('loggedOut') is not True or
                    report.get('cleanup', {}).get('faultNeutralised') is not True):
                raise SafeFailure('Supplement requires non-empty passed core and S2 runs with complete cleanup on the same HAP/runtime')
        self.password_key = s2.get('finalPasswordKey')
        if (core.get('finalPasswordKey') != 'initialPassword' or self.password_key not in ('initialPassword', 'newPassword') or
                s2.get('corePrerequisite', {}).get('sha256') != self.hashes['core']):
            raise SafeFailure('Supplement requires the completed core-to-S2 chain with an authoritative password key')
        self.started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        self.stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        self.ui = SupplementUI(self.state, density, self.stamp)
        self.checks = []
        self.observations = []
        self.not_executed = [
            'Live non-empty extraDisplay fixture values are outside this supplement and need separate actual evidence',
            'Manual visual judgement of the private light/dark screenshots is separate from these structural checks',
            'Avatar/Picker/crop and deferred foldable/hover/split-window scopes are outside this run']
        self.cleanup = {'loggedOut': False, 'themeRestoredToSystem': True, 'noProfileOrPasswordWrites': False}
        self.device_started = False
        self.ready = False
        self.theme_touched = False
        self.expected_player = None
        self.snapshot = ReadonlySnapshot(self.state)
        self.start_ledger = len(self.control.requests())
        self.before_profile = self.count(PROFILE, 'PATCH')
        self.before_change = self.count(CHANGE, 'POST')
        OUT.mkdir(parents=True, exist_ok=True)
        if REPORT.exists():
            attempts = OUT / 'attempts'
            attempts.mkdir(exist_ok=True)
            shutil.copyfile(REPORT, attempts / ('supplement-' + self.stamp + '.json'))
        self.report('running')

    def report(self, status, error=None):
        result = {
            'status': status, 'scope': 'Task1 phone identity, length limit, unsaved drafts, category, Refresh and theme supplement',
            'environment': 'real isolated PocketBase over strict USB HTTPS', 'deviceApi': 26,
            'startedAt': self.started_at, 'updatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'count': len(self.checks), 'checks': self.checks, 'observations': self.observations,
            'hap': {'packagedSha256': self.hap_sha, 'installationEvidence': 'Separate official scripts/hm.sh run log is required'},
            'prerequisites': {name: {'file': str(path.relative_to(ROOT)), 'sha256': self.hashes[name]}
                              for name, path in self.paths.items()},
            'requestLedger': self.control.ledger, 'privateScreenshots': self.ui.private_screenshots,
            'privateUiTrees': self.ui.private_trees, 'cleanup': self.cleanup, 'finalPasswordKey': self.password_key,
            'notExecuted': self.not_executed,
            'limitations': ['CLI/UiTest checks are not Hypium instrument tests',
                            'Only this dedicated player is authenticated; no reset or profile/password write is submitted',
                            'Missing native accessibility selection properties are not inferred from colours',
                            'No production, start, answer, reward or notification-read write']}
        if error:
            result['error'] = self.ui.redact(error)
        REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')

    def check(self, value, label, case):
        if not value:
            raise SafeFailure('Supplement expectation did not hold: ' + label)
        self.checks.append({'case': case, 'label': label})
        self.report('running')
        print(json.dumps({'count': len(self.checks), 'passed': label}, ensure_ascii=False), flush=True)

    def count(self, path, method):
        return sum(row.get('path') == path and row.get('method') == method for row in self.control.requests())

    def no_writes(self):
        return self.count(PROFILE, 'PATCH') == self.before_profile and self.count(CHANGE, 'POST') == self.before_change

    def checkpoint(self, phase):
        allowed = ('method', 'path', 'status', 'fault', 'responseDropped', 'authenticated', 'bearer',
                   'bodyKind', 'avatarPartPresent', 'requestBytes', 'fileTokenProvided')
        rows = []
        for row in self.control.requests()[self.start_ledger:]:
            item = {key: row[key] for key in allowed if key in row}
            path = str(item.get('path', '')).split('?', 1)[0]
            item['path'] = '/api/files/game_players/[owner]/[avatar]' if path.startswith('/api/files/game_players/') else path
            rows.append(item)
        self.control.ledger.append({'phase': phase, 'requests': rows})
        self.report('running')

    def prepare(self):
        self.snapshot.login(self.state[self.password_key])
        self.expected_player = self.snapshot.request(CORE.ME)
        if (self.expected_player.get('id') != self.state['playerId'] or
                self.expected_player.get('account') != self.state['account'] or
                self.expected_player.get('mustChangePassword') is not False):
            raise SafeFailure('Supplement authoritative player does not match the completed dedicated S2 account')
        assignments = self.snapshot.request(LIST)
        if not isinstance(assignments.get('items'), list):
            raise SafeFailure('Supplement requires an authoritative assignment-list DTO')
        if any(item.get('status') in ('completed', 'cancelled') for item in assignments['items']):
            raise SafeFailure('Supplement requires the dedicated history-empty dataset; no scenario is silently changed')
        self.ready = True
        self.ui.launch()
        self.device_started = True
        self.ui.wait(lambda ui: ui.find('account') is not None, 'supplement prerequisite logged-out phone')
        self.check(self.ui.input_empty('account') and self.ui.input_empty('password') and
                   self.ui.has_text('隔离测试环境') and not self.ui.has_text('演示环境'),
                   'The same dedicated HTTPS phone starts at empty login after the passed S2 run', 'R1')
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state[self.password_key])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'supplement authenticated home')
        self.check(self.ui.find('old-password') is None, 'The authoritative new password reaches home without another forced change', 'R1')

    def profile(self, identity=True):
        self.ui.tap('nav-profile')
        self.ui.wait(lambda ui: ui.find('profile-scroll') is not None, 'supplement profile container')
        if identity:
            self.ui.tap('profile-identity-tab')
            self.ui.seek('profile-name')

    def open_menu(self):
        self.ui.tap('account-menu')
        self.ui.wait(lambda ui: ui.menu_scope() is not None, 'supplement account Sheet')

    def close_menu(self):
        self.ui.back()
        self.ui.wait(lambda ui: ui.menu_scope() is None, 'supplement Sheet dismissal')

    def identity_facts(self, menu=False):
        player = self.expected_player
        rank, next_rank = player['level'], player['nextLevel']
        remaining = 0 if next_rank is None else max(0, next_rank['minTotalXp'] - player['totalXp'])
        expected = ['冒险者护照', player['displayName'], f"{rank['name']} · Lv.{rank['order']}", f"{player['totalXp']} EXP"]
        if menu:
            expected.append('已满级' if next_rank is None else f'距下一级 {remaining} EXP')
        else:
            expected.append(f"RANK {rank['order']:02d}")
            expected.append('已抵达当前最高等级，故事仍在继续。' if next_rank is None else
                            f"再收集 {remaining} 经验，成为「{next_rank['name']}」")
        for value in expected:
            self.ui.seek_text(value, scope_id=None if menu else 'profile-passport', menu=menu)
        self.check(True, 'The account Sheet shows authoritative nickname, level, EXP and remaining/max-level text' if menu else
                   'The profile passport shows authoritative nickname, level, EXP, rank code and next-level text', 'N2')

    @staticmethod
    def selected_value(node):
        for key in ('selected', 'accessibilitySelected', 'isSelected'):
            value = node.get(key)
            if isinstance(value, bool):
                return key, value
            if isinstance(value, str) and value.lower() in ('true', 'false'):
                return key, value.lower() == 'true'
        return None, None

    def selection(self, selected_id, other_id):
        observed = {}
        for node_id in (selected_id, other_id):
            node = self.ui.seek(node_id)
            key, value = self.selected_value(node)
            observed[node_id] = {'field': key, 'value': value}
        if any(value['field'] is None for value in observed.values()):
            self.observations.append({'case': 'N1', 'check': 'Account menu accessibility selection',
                                      'status': 'not_observable', 'observed': observed,
                                      'reason': 'Official visible-node dump did not expose a boolean selection value for both controls'})
            missing = 'Account menu accessibility selection is not fully observable in this CLI dump'
            if missing not in self.not_executed:
                self.not_executed.append(missing)
            self.report('running')
            return
        self.check(observed[selected_id]['value'] is True and observed[other_id]['value'] is False,
                   'The actual menu nodes expose the current destination as selected and the other as unselected', 'N1')
        self.observations.append({'case': 'N1', 'check': 'Account menu accessibility selection',
                                  'status': 'verified', 'observed': observed})

    def identity_and_menu(self):
        self.profile()
        self.identity_facts()
        self.ui.capture('supplement-profile-facts')
        self.ui.private_shot('profile-facts')
        self.open_menu()
        self.identity_facts(menu=True)
        self.selection('menu-profile', 'menu-home')
        self.ui.capture('supplement-menu-profile')
        self.ui.private_shot('menu-profile')
        self.close_menu()
        self.ui.tap('nav-home')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'supplement home menu state')
        self.open_menu()
        self.selection('menu-home', 'menu-profile')
        self.close_menu()
        self.checkpoint('authoritative-identity-and-menu')

    def length_and_draft(self):
        self.profile()
        before = self.count(PROFILE, 'PATCH')
        self.ui.type_length_probe()
        self.check(self.count(PROFILE, 'PATCH') == before,
                   'Actual input of41 ASCII characters leaves exactly the first40 in the native nickname field without a PATCH', 'P1')
        self.ui.tap('nav-home')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'home after an unsaved nickname draft')
        current = self.snapshot.request(CORE.ME)
        self.check(current.get('displayName') == self.expected_player['displayName'] and self.no_writes(),
                   'Leaving the profile with an unsaved nickname makes no write and does not change the authoritative nickname', 'P1')
        self.profile()
        field = self.ui.seek('profile-name')
        self.observations.append({'case': 'P1', 'check': 'Unsaved draft after returning to the profile',
                                  'retainedOnlyInMemory': field.get('text') == MAX_LENGTH_PROBE[:40],
                                  'authoritativeNameUnchanged': True,
                                  'scope': 'No assertion that route changes must retain or discard the unsaved text'})
        self.ui.fill('profile-name', self.expected_player['displayName'])
        self.check(self.no_writes(), 'The temporary length-test draft is restored by editing only, without saving it', 'P1')
        self.checkpoint('nickname-length-and-unsaved-route')

    def enter_probes(self):
        self.ui.tap('profile-security-tab')
        self.ui.seek('security-old-password')
        for node_id, value in zip(('security-old-password', 'security-new-password', 'security-confirm-password'), SECURITY_PROBES):
            self.ui.fill(node_id, value)

    def empty_security(self):
        return all(self.ui.input_empty(node_id) for node_id in
                   ('security-old-password', 'security-new-password', 'security-confirm-password'))

    def security_clearance(self):
        self.enter_probes()
        self.ui.tap('profile-identity-tab')
        self.ui.seek('profile-name')
        self.ui.tap('profile-security-tab')
        self.ui.seek('security-old-password')
        self.check(self.empty_security() and self.no_writes(),
                   'Leaving the security section clears all three native password fields without a password POST', 'S1')
        self.enter_probes()
        self.ui.tap('nav-home')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'home after leaving profile security')
        self.profile(identity=False)
        self.ui.tap('profile-security-tab')
        self.ui.seek('security-old-password')
        self.check(self.empty_security() and self.no_writes(),
                   'Leaving the profile destination also clears all three native password fields without a write', 'S1')
        self.ui.tap('profile-identity-tab')
        self.ui.seek('profile-name')
        self.checkpoint('password-fields-on-section-and-route-exit')

    def wait_list_request(self, before):
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            rows = [row for row in self.control.requests() if row.get('path') == LIST and row.get('method') == 'GET']
            if len(rows) > before and rows[before].get('status'):
                row = rows[before]
                if row.get('status') != 200 or row.get('fault') is not False:
                    raise SafeFailure('Supplement Refresh did not finish as a new non-injected HTTPS200 list response')
                return
            time.sleep(.15)
        raise SafeFailure('Supplement Refresh did not produce a completed new HTTPS list request')

    def categories_and_refresh(self):
        self.ui.tap('nav-home')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'home for category and Refresh checks')
        self.ui.tap('history-tab')
        self.ui.wait(lambda ui: ui.has_text('故事的第一页，还空着。'), 'the separate history empty state')
        self.check(self.ui.has_text('完成一场冒险，就会在这里留下你的足迹。'),
                   'The native history category retains both distinct empty-state sentences', 'R1')
        self.ui.capture('supplement-history-empty')
        self.ui.private_shot('history-empty')
        self.ui.tap('current-tab')
        self.ui.wait(lambda ui: ui.find('current-scroll') is not None, 'return to current assignments')
        self.ui.seek('assignment-' + self.state['assignmentId'])
        self.check(True, 'Switching back from history reaches the existing current assignment action', 'R1')
        # Return the owned list to its beginning before measuring this single
        # pull. Do not retry the measured gesture or silently inject a GET.
        for _ in range(9):
            self.ui.capture()
            scroll = self.ui.find('current-scroll')
            first = self.ui.find('assignment-state-' + self.state['assignmentId'])
            if scroll and first and first.get('bounds') and first['bounds'][1] > scroll['bounds'][1] + 20:
                break
            self.ui.swipe('up')
        else:
            raise SafeFailure('Supplement current list did not reach its beginning before Refresh')
        self.ui.capture()
        scroll = self.ui.find('current-scroll')
        if scroll is None or not scroll.get('bounds'):
            raise SafeFailure('Supplement current Scroll is unavailable for the measured Refresh gesture')
        rect = scroll['bounds']
        view = self.ui.viewport('current-scroll')
        top, bottom = max(rect[1], view[1]), min(rect[3], view[3])
        if bottom - top < 180:
            raise SafeFailure('Supplement current Scroll is too short for the Refresh gesture')
        x = (rect[0] + rect[2]) // 2
        before = self.count(LIST, 'GET')
        self.ui.run('devecocli', 'ui', 'swipe', x, int(top + (bottom - top) * .14),
                    x, int(top + (bottom - top) * .72), '--speed', 1000)
        self.wait_list_request(before)
        self.ui.wait(lambda ui: ui.find('current-scroll') is not None and ui.find('request-retry') is None,
                     'successful official Refresh leaves the list usable')
        self.check(self.count(LIST, 'GET') == before + 1,
                   'One actual official Refresh pull makes exactly one new non-injected HTTPS200 assignment GET', 'R1')
        self.check(self.no_writes(), 'Category changes and Refresh do not submit profile or password writes', 'R1')
        self.checkpoint('history-current-and-official-refresh')

    def themes(self):
        self.profile()
        for theme in ('dark', 'light'):
            self.open_menu()
            self.theme_touched = True
            self.cleanup['themeRestoredToSystem'] = False
            self.ui.tap('theme-' + theme)
            self.ui.wait(lambda ui: ui.find('theme-' + theme) is not None,
                         'theme action remains in its account Sheet')
            if self.ui.find('theme-error-message') is not None:
                raise SafeFailure('Supplement theme switching exposed an application error')
            selected = self.ui.seek('theme-' + theme)
            key, value = self.selected_value(selected)
            if key is not None:
                self.check(value is True, 'The actual theme action exposes its newly selected state: ' + theme, 'R1')
            else:
                self.observations.append({'case': 'R1', 'check': 'Theme accessibility selection: ' + theme,
                                          'status': 'not_observable', 'scope': 'Theme click, no error and profile structure are still checked'})
            self.close_menu()
            self.ui.seek('profile-name')
            self.check(self.ui.find('profile-name').get('text') == self.expected_player['displayName'],
                       'The nickname editor retains its current value after the native theme action: ' + theme, 'R1')
            self.identity_facts()
            self.ui.capture('supplement-profile-' + theme + '-passport')
            self.ui.private_shot('profile-' + theme + '-passport')
            self.ui.seek('profile-save')
            self.check(True, 'The profile save action remains fully reachable after the native theme action: ' + theme, 'R1')
            self.ui.capture('supplement-profile-' + theme)
            self.ui.private_shot('profile-' + theme)
        self.restore_theme()
        self.check(self.no_writes(), 'Light and dark theme actions preserve the profile without business writes', 'R1')
        self.checkpoint('light-dark-profile-structure')

    def restore_theme(self):
        self.ui.hide_keyboard()
        self.ui.capture()
        if self.ui.menu_scope() is None:
            self.open_menu()
        self.ui.tap('theme-system')
        self.ui.capture()
        if self.ui.find('theme-error-message') is not None:
            raise SafeFailure('Supplement could not restore the App theme to follow the system')
        self.close_menu()
        self.cleanup['themeRestoredToSystem'] = True

    def logout(self):
        self.ui.hide_keyboard()
        self.ui.capture()
        if self.ui.find('account') is None:
            if self.ui.menu_scope() is None:
                if self.ui.find('account-menu') is None:
                    raise SafeFailure('Supplement could not find a safe explicit account logout action')
                self.open_menu()
            self.ui.tap('logout')
        self.ui.wait(lambda ui: ui.find('account') is not None, 'supplement empty login after logout')
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('Supplement logout did not clear both login inputs')
        self.ui.back()
        self.ui.launch()
        self.ui.wait(lambda ui: ui.find('account') is not None, 'supplement logout Back and Ability gate')
        self.cleanup['loggedOut'] = (self.ui.input_empty('account') and self.ui.input_empty('password') and
                                     self.ui.find('profile-passport') is None and self.ui.find('security-old-password') is None)
        if not self.cleanup['loggedOut']:
            raise SafeFailure('Supplement logout gate exposed old profile or security content')

    def run(self):
        failure = None
        try:
            self.prepare()
            self.identity_and_menu()
            self.length_and_draft()
            self.security_clearance()
            self.categories_and_refresh()
            self.themes()
            current = self.snapshot.request(CORE.ME)
            self.check(current.get('displayName') == self.expected_player['displayName'] and
                       current.get('mustChangePassword') is False and self.no_writes(),
                       'A fresh authoritative me read confirms that the supplement changed neither nickname nor password state', 'P1')
            self.logout()
            self.check(self.cleanup['loggedOut'], 'Final logout, Back and Ability relaunch remain at empty login with no profile content', 'R1')
        except Exception as error:
            failure = str(error) if isinstance(error, SafeFailure) else 'Supplement helper stopped before acceptance completed'
        finally:
            if self.device_started and self.ready:
                if self.theme_touched and not self.cleanup['themeRestoredToSystem']:
                    try:
                        self.restore_theme()
                    except Exception:
                        failure = failure or 'Supplement App theme cleanup did not complete'
                if not self.cleanup['loggedOut']:
                    try:
                        self.logout()
                    except Exception:
                        failure = failure or 'Supplement explicit logout cleanup did not complete'
            try:
                self.cleanup['noProfileOrPasswordWrites'] = self.no_writes()
                if not self.cleanup['noProfileOrPasswordWrites']:
                    failure = failure or 'Supplement unexpectedly observed a profile or password write'
                if CORE.sha(self.hap_path) != self.hap_sha or any(
                        CORE.sha(path) != self.hashes[name] for name, path in self.paths.items()):
                    failure = failure or 'Supplement prerequisite evidence changed during the phone run'
                self.checkpoint('final-cleanup')
            except Exception:
                failure = failure or 'Supplement final evidence could not be collected'
            if not failure and (not {'N2', 'P1', 'S1', 'R1'}.issubset({item['case'] for item in self.checks}) or
                                len(self.checks) < 15 or not all(self.cleanup.values())):
                failure = 'Supplement executed coverage or cleanup was incomplete'
            self.report('incomplete' if failure else 'passed', failure)
        print(json.dumps({'status': 'incomplete' if failure else 'passed', 'count': len(self.checks),
                          'scope': 'Task1 structural and interaction supplement; unobservable checks remain explicit',
                          'report': str(REPORT.relative_to(ROOT)), 'cleanup': self.cleanup,
                          'finalPasswordKey': self.password_key}, ensure_ascii=False))
        return 1 if failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-report', type=Path, default=PROFILE_OUT / 'runtime.json')
    parser.add_argument('--core-report', type=Path, default=PROFILE_OUT / 'device-profile-acceptance.json')
    parser.add_argument('--s2-report', type=Path, default=PROFILE_OUT / 'device-profile-password-uncertain.json')
    args = parser.parse_args()
    try:
        return SupplementAcceptance(args.runtime_report, args.core_report, args.s2_report).run()
    except Exception as error:
        text = str(error) if isinstance(error, SafeFailure) else 'Supplement setup stopped before acceptance completed'
        print(json.dumps({'status': 'incomplete', 'scope': 'supplement setup', 'error': text}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

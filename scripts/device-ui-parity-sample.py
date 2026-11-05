#!/usr/bin/env python3
"""Root-only native sidebar/Rank sample; default help has no private/device IO.

Only fixed-preview authentication, me/list and the explicit assigned scene GET
are allowed. The final authenticated home is retained. This captures native
evidence and a private same-data Web fixture; it never claims Web fidelity.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import ssl
import stat
import sys
import urllib.request

from native_device_ui import ROOT, SafeFailure

SPEC = importlib.util.spec_from_file_location('ui_sample_preview_binding', ROOT / 'scripts/device-preview-smoke.py')
PREVIEW = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREVIEW)
UI = PREVIEW.NATIVE_UI
VALIDATION = ROOT / 'artifacts/validation'
PRIVATE = ROOT / 'artifacts/private'
CHECKS = ('actualWindowReported', 'actualImmersiveWindow', 'transparentSystemBars',
          'requestedFontScaleReported', 'threeIndependentTlsCases')


def fresh_path(value, base, directory=False):
    path = (ROOT / value).absolute() if not value.is_absolute() else value.absolute()
    PREVIEW.require(path == path.resolve() and path.is_relative_to(base) and path != base and
                    not path.exists() and not path.is_symlink(), 'Choose a fresh direct sample output path')
    if not directory:
        PREVIEW.require(path.suffix == '.json', 'The public sample report must be JSON')
    for item in (path.parent, *path.parent.parents):
        PREVIEW.require(not item.is_symlink(), 'Sample output ancestors cannot be symlinks')
        if item == ROOT:
            break
    return path


def make_private(path):
    for item in reversed((path, *path.parents)):
        if item == ROOT or ROOT not in item.parents:
            continue
        if item.exists():
            info = item.stat()
            PREVIEW.require(item != path and stat.S_ISDIR(info.st_mode) and info.st_uid == os.getuid(),
                            'A sample output ancestor is not an owned directory')
            if item == PRIVATE or item.is_relative_to(PRIVATE):
                PREVIEW.require(stat.S_IMODE(info.st_mode) == 0o700,
                                'Private sample ancestors must be owned mode700')
        else:
            item.mkdir(mode=0o700)


def private_json(path, value, secrets):
    encoded = json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
    PREVIEW.require(not any(secret and secret in encoded for secret in secrets),
                    'Authentication literals cannot enter private reference data')
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as stream:
        os.fchmod(stream.fileno(), 0o600)
        stream.write(encoded)
    return PREVIEW.sha(path)


def intersect(*boxes):
    return [max(box[0] for box in boxes), max(box[1] for box in boxes),
            min(box[2] for box in boxes), min(box[3] for box in boxes)]


class Sample(PREVIEW.Smoke):
    def __init__(self, args):
        self.report = fresh_path(args.output, VALIDATION)
        private = fresh_path(args.private_dir, PRIVATE, True)
        runtime = PREVIEW.guarded(args.runtime_report, VALIDATION)
        PREVIEW.require(PREVIEW.sha(PREVIEW.HAP) == args.expected_hap,
                        'The sample package is not the explicit expected HAP')
        make_private(private)
        PREVIEW.REPORT, PREVIEW.PRIVATE, PREVIEW.RUNTIME_CHECKS = self.report, private, CHECKS
        # The original constructor couples its runtime and Host-readiness paths
        # to OUT. Relax only this exact explicit runtime input to validation/;
        # the independent Host-readiness report keeps its original profile path.
        original_guard = PREVIEW.guarded

        def runtime_guard(value, directory, private=False):
            actual = (ROOT / value).absolute() if not Path(value).is_absolute() else Path(value).absolute()
            return original_guard(value, VALIDATION if actual == runtime and directory == PREVIEW.OUT else directory, private)

        PREVIEW.guarded = runtime_guard
        try:
            super().__init__(args)
        finally:
            PREVIEW.guarded = original_guard
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), PREVIEW.NoRedirect(),
                                                  urllib.request.HTTPSHandler(context=self.context))
        PREVIEW.require(self.context.check_hostname and self.context.verify_mode == ssl.CERT_REQUIRED,
                        'Strict native-reference Host TLS is required')
        entry = self.manifest.get('assignments', {}).get('waiting')
        PREVIEW.require(isinstance(entry, dict) and re.fullmatch(r'[a-z0-9]{15}', entry.get('assignmentId', '')),
                        'The fixed preview has no exact waiting assignment reference')
        self.assignment_id = entry['assignmentId']
        self.assignment_route = '/api/questions/v1/assignments/' + self.assignment_id
        for name, source in {
            'sampleDriver': Path(__file__), 'previewRun': PREVIEW.BASE / 'run.json',
            'previewLogin': PREVIEW.BASE / 'login.json',
            'sidePanel': ROOT / 'entry/src/main/ets/ui/StarwardSidePanel.ets',
            'passport': ROOT / 'entry/src/main/ets/ui/StarwardPassport.ets',
            'index': ROOT / 'entry/src/main/ets/pages/Index.ets',
            'titleMaterial': ROOT / 'entry/src/main/ets/ui/StarwardMaterial.ets',
            'lightColors': ROOT / 'entry/src/main/resources/base/element/color.json',
            'darkColors': ROOT / 'entry/src/main/resources/dark/element/color.json'
        }.items():
            self.bound[name], self.binding[name] = source, PREVIEW.sha(source)
        self.token = ''
        self.fixture_path = PREVIEW.guarded(args.fixtures_json, PRIVATE, True) if args.fixtures_json else None
        if self.fixture_path is not None:
            self.bound['referenceFixture'] = self.fixture_path
            self.binding['referenceFixture'] = PREVIEW.sha(self.fixture_path)
        self.states = []
        self.theme_actions = []
        self.fixture = None
        self.cleanup = {'authenticatedHomeRetained': False, 'panelClosed': False,
                        'remoteRawFilesRemoved': True}
        self.stage = 'fixed-preview-prerequisites'

    def request(self, route, body=None, token=''):
        if route != getattr(self, 'assignment_route', None):
            return super().request(route, body, token)
        PREVIEW.require(body is None and bool(token), 'The assigned-scene reference is GET-only')
        request = urllib.request.Request(self.run['hostBase'] + route, method='GET',
            headers={'Accept': 'application/json', 'Authorization': token})
        try:
            with self.opener.open(request, timeout=25) as response:
                PREVIEW.require(response.status == 200, 'The exact assigned-scene read did not return200')
                value = json.load(response)
                PREVIEW.require(isinstance(value, dict), 'The assigned-scene read is not a JSON object')
                return value
        except Exception:
            raise SafeFailure('Strict assigned-scene HTTPS read failed; values omitted') from None

    def login_native(self):
        self.ui.fill('account', self.login['account'])
        self.ui.fill('password', self.login['password'])
        self.ui.tap('primary-action')
        self.ui.wait(lambda ui: ui.find('current-tab') is not None, 'fixed-preview sample enters home directly')
        self.check(self.ui.find('old-password') is None and self.ui.find('forced-logout') is None,
                   'The fixed-preview sample reaches authenticated home without first-password setup')
        self.ui.seek('assignment-' + self.assignment_id)

    def own_row(self, raw, node_id):
        values = [row for row in raw if row.get('id') == node_id and UI.exposed(row)]
        PREVIEW.require(len(values) == 1, 'A unique exposed own sample node is required')
        return values[0]

    def center_touch(self, row):
        box = UI.rect(row.get('bounds'))
        PREVIEW.require(UI.positive(box) and UI.inside(box, self.ui.app_rect()),
                        'The measured own sample action is outside its App')
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click',
                    round((box[0] + box[2]) / 2), round((box[1] + box[3]) / 2))

    def panel_closed(self):
        self.ui.wait(lambda ui: ui.find('account-side-panel') is None and ui.find('account-menu') is not None,
                     'native panel dismissal returns its same own page')

    def open_panel(self):
        self.ui.tap('account-menu')
        self.ui.wait(lambda ui: ui.find('account-side-panel') is not None and ui.find('account-panel-title') is not None,
                     'native account panel opens from its real avatar')

    def theme(self, name):
        self.open_panel()
        self.ui.tap('theme-' + name)
        self.ui.wait(lambda ui: ui.find('theme-' + name) is not None or ui.find('account-side-panel') is None,
                     'native theme action or its configuration dismissal')
        PREVIEW.require(self.ui.find('theme-error-message') is None, 'The native theme action returned an error')
        selected = self.ui.find('theme-' + name)
        flags = {key: selected[key] for key in ('selected', 'accessibilitySelected')
                 if selected is not None and key in selected}
        PREVIEW.require(all(value in (True, 'true') for value in flags.values()),
                        'A reported selected-theme flag is false')
        self.theme_actions.append({'requested': name, 'selectedFlagsObservable': bool(flags),
                                   'selectedFlags': flags, 'actualPixels': 'pending_root_original_review'})
        if self.ui.find('account-side-panel') is not None:
            self.ui.back()
        self.panel_closed()

    def panel_sample(self, name, theme, close_with_back=False):
        self.open_panel()
        # No seek/scroll takes place inside this fresh panel before measuring
        # whether logout is initially fully visible.
        raw, evidence = self.ui.raw_app(name + '-' + theme)
        self.ui.private_shot(name + '-' + theme)
        panel = self.own_row(raw, 'account-side-panel')
        header = self.own_row(raw, 'account-panel-header')
        label = self.own_row(raw, 'account-panel-title')
        mark = self.own_row(raw, 'account-panel-mark')
        close = self.own_row(raw, 'account-close')
        logout = self.own_row(raw, 'logout')
        body = self.own_row(raw, 'account-menu-scroll')
        boxes = {key: UI.rect(row.get('bounds')) for key, row in
                 (('panel', panel), ('header', header), ('label', label), ('mark', mark), ('close', close), ('logout', logout))}
        available = intersect(self.ui.app_rect(), boxes['panel'], UI.rect(body.get('bounds')))
        density = self.ui.density
        geometry = {'boundsPx': boxes, 'bodyAvailablePx': available,
            'headerHeightVp': (boxes['header'][3] - boxes['header'][1]) / density,
            'closeWidthVp': (boxes['close'][2] - boxes['close'][0]) / density,
            'closeHeightVp': (boxes['close'][3] - boxes['close'][1]) / density,
            'logoutInitiallyFullyVisible': UI.positive(available) and UI.inside(boxes['logout'], available)}
        self.states.append({'state': name, 'theme': theme, 'geometry': geometry,
                            'rawEvidenceSha256': evidence['sha256']})
        self.check(label.get('text') == '冒险者护照' and not any(row.get('type') == 'Text' and
                   row.get('text') == '冒险者菜单' and UI.exposed(row) for row in raw) and
                   boxes['mark'][2] <= boxes['label'][0] and boxes['label'][2] <= boxes['close'][0],
                   'One leading-star passport heading and trailing close replace the duplicate visible menu title')
        self.check(abs(geometry['headerHeightVp'] - 44) <= .6 and
                   abs(geometry['closeWidthVp'] - 44) <= .6 and abs(geometry['closeHeightVp'] - 44) <= .6 and
                   UI.inside(boxes['close'], intersect(self.ui.app_rect(), boxes['panel'])),
                   'The measured small header and complete native close target are44vp inside the actual panel')
        self.check(geometry['logoutInitiallyFullyVisible'] and
                   (boxes['logout'][3] - boxes['logout'][1]) / density >= 43.4,
                   'Normal-font logout is fully visible before any panel scroll and retains its44vp target')
        if close_with_back:
            self.ui.back()
        else:
            self.center_touch(close)
        self.panel_closed()
        self.check(True, 'The measured close action or official Back dismisses only its own native account panel')

    def rank_sample(self, theme, player):
        self.ui.seek('start-assignment')
        self.ui.capture()
        expected = 'RANK ' + str(player['level']['order']) + ' · ' + player['level']['name']
        chains = []

        def visit(value, ancestors):
            if isinstance(value, list):
                for child in value:
                    visit(child, ancestors)
            elif isinstance(value, dict):
                path = ancestors + [value]
                if value.get('text') == expected and value.get('bounds'):
                    chains.append(path)
                for child in value.get('children', []):
                    visit(child, path)

        visit(self.ui.tree, [])
        PREVIEW.require(len(chains) == 1, 'A unique current-player Rank text is required')
        path = chains[0]
        rank = UI.rect(path[-1]['bounds'])
        bars = [node for node in path if node.get('type') in ('TitleBar', 'NavDestinationTitleBar') and node.get('bounds')]
        self.ui.private_shot('session-header-' + theme)
        raw, evidence = self.ui.raw_app('session-header-' + theme)
        geometry = {'rankBoundsPx': rank, 'actualTitleBarObserved': bool(bars),
                    'measurementMeaning': 'Rank text bottom to the measured native title-bar lower boundary; divider pixels require Root original review'}
        if bars:
            box = UI.rect(bars[-1]['bounds'])
            PREVIEW.require(UI.positive(box) and UI.inside(rank, box), 'The Rank text is outside its actual title bar')
            geometry['titleBarBoundsPx'] = box
            geometry['rankToTitleBarBottomVp'] = (box[3] - rank[3]) / self.ui.density
        self.states.append({'state': 'session-header', 'theme': theme, 'geometry': geometry,
                            'rawEvidenceSha256': evidence['sha256']})
        self.check(bool(bars) and geometry.get('rankToTitleBarBottomVp', -1) >= 10 - 1 / self.ui.density - .01,
                   'The current-player Rank text has10vp measured clearance within one physical pixel of rounding')
        self.check(not any(row.get('id') == 'gameplay-page' for row in raw) and self.ui.find('start-assignment') is not None,
                   'The assigned scene remains a GET-only detail without entering gameplay')

    def main(self):
        auth = self.request('/api/collections/game_players/auth-with-password',
                            {'identity': self.login['account'], 'password': self.login['password']})
        PREVIEW.require(isinstance(auth.get('token'), str) and bool(auth['token']), 'The fixed-preview Host token is absent')
        self.token = auth['token']
        player = self.request('/api/questions/v1/me', token=self.token)
        listing = self.request('/api/questions/v1/assignments', token=self.token)
        assignment = self.request(self.assignment_route, token=self.token)
        expected = {item['assignmentId'] for item in self.manifest['assignments'].values()}
        self.check(player.get('id') == auth.get('record', {}).get('id') == self.manifest['playerId'] and
                   player.get('account') == PREVIEW.ACCOUNT and player.get('mustChangePassword') is False and
                   isinstance(listing.get('items'), list) and {item.get('id') for item in listing['items']} == expected and
                   all(item.get('player') == player['id'] for item in listing['items']),
                   'Strict Host reads confirm the ordinary fixed-preview identity and its exact assignment list')
        self.check(assignment.get('id') == self.assignment_id and assignment.get('player') == player['id'] and
                   assignment.get('status') == 'assigned' and not assignment.get('startedAt') and
                   isinstance(assignment.get('levels'), list) and bool(assignment['levels']) and
                   all(item.get('question') is None for item in assignment['levels']),
                   'The existing waiting scene is still assigned and keeps every unentered question hidden')
        payload = {'player': player, 'assignments': listing, 'assignment': assignment}

        def without_server_time(value):
            if isinstance(value, dict):
                return {key: without_server_time(item) for key, item in value.items() if key != 'serverTime'}
            if isinstance(value, list):
                return [without_server_time(item) for item in value]
            return value

        normalized = json.dumps(without_server_time(payload), ensure_ascii=False, sort_keys=True, separators=(',', ':'))
        if self.fixture_path is not None:
            reference = json.loads(self.fixture_path.read_text())
            compared = {key: reference.get(key) for key in ('player', 'assignments', 'assignment')}
            self.check(without_server_time(compared) == without_server_time(payload),
                       'Fresh strict Host DTOs exactly match the private Web reference except serverTime')
            fixture_path, fixture_sha = self.fixture_path, PREVIEW.sha(self.fixture_path)
        else:
            fixture_path = self.directory / 'fixtures.json'
            fixture_sha = private_json(fixture_path, payload,
                (self.login['password'], self.token, self.run['controlToken']))
        self.fixture = {'file': str(fixture_path.relative_to(ROOT)), 'sha256': fixture_sha,
                        'normalizedDtoSha256': hashlib.sha256(normalized.encode()).hexdigest(),
                        'comparisonIgnoresOnlyServerTime': True}
        self.device_started = True
        self.ui.launch(cold=True)
        self.ui.wait(lambda ui: ui.find('account') is not None, 'cold fixed-preview sample login')
        self.check(self.ui.input_empty('account') and self.ui.input_empty('password') and self.ui.has_text('隔离测试环境'),
                   'The sample starts at an empty real isolated native login')
        self.login_native()
        self.check(abs(self.ui.width / self.ui.density - 376) <= .6,
                   'The actual native viewport is376vp at normal font scale')
        for theme in ('light', 'dark'):
            self.stage = 'sample-' + theme
            self.theme(theme)
            self.panel_sample('sidebar-home', theme)
            self.ui.tap('assignment-' + self.assignment_id)
            self.ui.wait(lambda ui: ui.find('start-assignment') is not None and ui.has_text('QUEST SESSION'),
                         'existing assigned session header')
            self.rank_sample(theme, player)
            self.panel_sample('sidebar-session', theme, close_with_back=True)
            self.check(self.ui.find('start-assignment') is not None and self.ui.has_text('QUEST SESSION'),
                       'Back from the session panel retains the same read-only detail')
            self.ui.back()
            self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('start-assignment') is None,
                         'return from assigned detail to authenticated home')
        self.immutable()
        self.cleanup['panelClosed'] = self.ui.find('account-side-panel') is None
        self.cleanup['authenticatedHomeRetained'] = self.ui.find('current-tab') is not None and self.ui.find('account') is None
        self.check(self.cleanup['panelClosed'] and self.cleanup['authenticatedHomeRetained'],
                   'The reviewed fixed-preview session is left on authenticated home with its panel closed')
        self.stage = 'sample-complete-visual-review-pending'

    def execute(self):
        failure = None
        try:
            self.main()
        except Exception as error:
            failure = str(error) if isinstance(error, SafeFailure) else 'Native sample stopped; raw values omitted'
            for secret in self.secrets():
                if secret:
                    failure = failure.replace(secret, '[private value omitted]')
        finally:
            self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
            if not self.cleanup['remoteRawFilesRemoved']:
                failure = failure or 'An exact own remote raw-file cleanup was not confirmed'
            try:
                self.immutable()
            except Exception:
                failure = failure or 'The exact sample package, source or preview ownership binding changed'
        result = {'status': 'captured_native_sample' if failure is None else 'incomplete', 'stage': self.stage,
            'scope': 'Native first UI sample only; no Web fidelity or unchanged business-flow regression claim',
            'hapSha256': self.hap_sha, 'bindingSha256': self.binding, 'checksPassed': len(self.checks), 'checks': self.checks,
            'pickedAssignedState': 'waiting', 'privateFixture': self.fixture, 'states': self.states,
            'themeActions': self.theme_actions, 'privateScreenshots': self.ui.private_screenshots,
            'privateRawEvidence': self.ui.raw_evidence, 'cleanup': self.cleanup,
            'visualReview': 'pending_root_same_data_original_review', 'businessWriteLedgerObserved': False,
            'writeScope': 'Host authentication/me/list/exact assigned GET; native authentication, local theme selection and menu/navigation only. No start/answer/profile/password/reset/fault/service command.',
            'appCredentialsPersisted': False, 'privateCredentialsOrRecordIdsPersisted': False}
        if failure:
            result['failure'] = failure
            result['cleanupMeaning'] = 'Only completed observations are recorded; Root must inspect the actual foreground before further action'
        encoded = json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        PREVIEW.require(not any(secret and secret in encoded for secret in self.secrets()),
                        'A private literal would enter the public sample report')
        fresh_path(self.report, VALIDATION)
        self.report.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(fd, 'w') as stream:
            stream.write(encoded)
        print(json.dumps({'status': result['status'], 'checksPassed': len(self.checks),
                          'report': str(self.report.relative_to(ROOT))}), flush=True)
        return 0 if failure is None else 1

    def secrets(self):
        values = [self.login['account'], self.login['password'], self.token, self.run['controlToken'],
                  self.manifest['playerId'], self.manifest['owner'], self.assignment_id]
        for item in self.manifest['assignments'].values():
            values += [item.get('assignmentId', ''), item.get('sessionId', '')]
        return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action')
    run = sub.add_parser('run', help='Root-only sample on the explicit current preview HAP/runtime')
    run.add_argument('--expected-hap', required=True)
    run.add_argument('--runtime-report', type=Path, required=True)
    run.add_argument('--output', type=Path, required=True)
    run.add_argument('--private-dir', type=Path, required=True)
    run.add_argument('--fixtures-json', type=Path, help='Existing private same-data Web fixture to verify with fresh Host GETs')
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    try:
        PREVIEW.require(re.fullmatch(r'[a-f0-9]{64}', args.expected_hap), 'An explicit expected HAP SHA256 is required')
        args.runtime_report = (ROOT / args.runtime_report).absolute() if not args.runtime_report.is_absolute() else args.runtime_report.absolute()
        return Sample(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded',
                          'error': 'The current preview HAP/runtime, ownership or fresh output guard did not complete; private values omitted'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())

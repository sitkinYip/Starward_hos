#!/usr/bin/env python3
"""Verify the current fixed preview assignment snapshot on the installed Aurora HAP."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
from types import SimpleNamespace

from native_device_ui import DeviceUI, ROOT, flatten


JOURNEY_SECTIONS = {'current': '待赴', 'history': '回响'}


def login_first_view(ui, window, require):
    """Inspect one untouched layout dump. tap/fill/seek can scroll clipped controls into view."""
    scroll = ui.find('auth-scroll')
    require(scroll is not None and scroll.get('bounds'), 'The login scroll viewport is missing')
    left, top, right, bottom = scroll['bounds']
    app_left, app_top, app_right, app_bottom = ui.app_rect()
    left, right = max(left, app_left), min(right, app_right)
    top = max(top, app_top + window['topInsetPx'])
    bottom = min(bottom, app_bottom - window['bottomInsetPx'])
    controls = {'auth-entry': 0, 'auth-form-card': 0, 'account': 52, 'password': 52, 'primary-action': 52, 'login-help': 44,
                'auth-environment-note': 0}
    result = {'safeViewportPx': [left, top, right, bottom], 'controlsPx': {}}
    for key, minimum_height in controls.items():
        node = ui.find(key)
        require(node is not None and node.get('bounds'), key + ' is absent from the untouched login view')
        x0, y0, x1, y1 = node['bounds']
        require(left <= x0 < x1 <= right and top <= y0 < y1 <= bottom and
                y1 - y0 >= minimum_height * window['density'] - 1,
                key + ' is clipped in the untouched login view')
        result['controlsPx'][key] = [x0, y0, x1, y1]
    gap = result['controlsPx']['auth-environment-note'][1] - result['controlsPx']['auth-form-card'][3]
    require(gap >= 12 * window['density'] - 1, 'The environment note needs a 12vp gap below the login card')
    result['environmentGapPx'] = gap
    bottom_gap = bottom - result['controlsPx']['auth-entry'][3]
    require(abs(bottom_gap - 16 * window['density']) <= 2,
            'The entry should be anchored 16vp above the lower safe-area boundary')
    result['bottomGapPx'] = bottom_gap
    return result


def select_journey_section(ui, section, require):
    ui.capture()
    segment = ui.find('journey-segment')
    require(segment is not None and segment.get('bounds'), 'The native journey segmentation is missing')
    label = JOURNEY_SECTIONS[section]
    candidates = [node['bounds'] for node in flatten(segment)
                  if node.get('bounds') and node.get('text') == label]
    require(candidates, 'The selected section label must be inside the native capsule')
    bounds = segment['bounds']
    x0, y0, x1, y1 = max(candidates, key=lambda box: (box[2] - box[0]) * (box[3] - box[1]))
    require(bounds[0] <= x0 < x1 <= bounds[2] and bounds[1] <= y0 < y1 <= bounds[3],
            'The native segment must have a visible target inside its bounds')
    ui.run('devecocli', 'ui', 'click', (x0 + x1) // 2, (y0 + y1) // 2)
    ui.wait(lambda view: view.find(section + '-scroll') is not None, 'native journey section changed')


def find_journey_items(ui, section, minimum_by_id, require):
    remaining = minimum_by_id.copy()
    found = {}
    for direction in ('down', 'up'):
        for _ in range(5):
            ui.capture()
            scroll = ui.find(section + '-scroll')
            bar = ui.find('starward-native-tabbar')
            require(scroll is not None and bar is not None, 'The active native journey section is missing')
            left, top, right, bottom = scroll['bounds']
            bottom = min(bottom, bar['bounds'][1])
            for node_id, minimum in list(remaining.items()):
                item = ui.find(node_id)
                if item is None:
                    continue
                x0, y0, x1, y1 = item['bounds']
                if left <= x0 < x1 <= right and top <= y0 < y1 <= bottom and y1 - y0 >= minimum:
                    found[node_id] = item
                    del remaining[node_id]
            if not remaining:
                return found
            ui.swipe(direction)
    require(False, 'Some scene cards or the sync note did not become reachable above navigation')


def seek_journey_item(ui, section, node_id, minimum_px, require):
    return find_journey_items(ui, section, {node_id: minimum_px}, require)[node_id]


def scan_journey_section(ui, section, identifiers, density, require):
    note = 'assignment-sync-note-text'
    minimum_by_id = {f'assignment-{identifier}': 44 * density - 1 for identifier in identifiers}
    minimum_by_id[note] = 16 * density - 1
    found = find_journey_items(ui, section, minimum_by_id, require)
    require(all(node_id == note or item.get('type') == 'Button' for node_id, item in found.items()),
            'Each scene card should have one primary native button')
    return len(identifiers)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-report', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    output = args.output.absolute()
    validation = ROOT / 'artifacts/validation/aurora-glass-v2-20261125'
    if (output.suffix != '.json' or not output.resolve().is_relative_to(validation) or output.exists() or
            any(path.is_symlink() for path in (output, *output.parents))):
        parser.error('Choose a fresh Aurora validation JSON path')

    spec = importlib.util.spec_from_file_location('aurora_preview_guard', ROOT / 'scripts/device-preview-smoke.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.REPORT = output
    module.PRIVATE = ROOT / 'artifacts/private/aurora-glass-v2-20261125/preview-captures'
    runtime_file = module.guarded(args.runtime_report, module.OUT)
    if 'actualLightAndDarkBarContent' not in json.loads(runtime_file.read_text()).get('checks', {}):
        module.RUNTIME_CHECKS = tuple(check for check in module.RUNTIME_CHECKS if check != 'actualLightAndDarkBarContent')
    report = {'status': 'incomplete', 'checks': [], 'stage': 'preview-package-and-runtime'}
    try:
        smoke = module.Smoke(SimpleNamespace(runtime_report=args.runtime_report.absolute(), leave_logged_in=True))
        report['installedHapSha256'] = smoke.hap_sha
        report['sourceBindings'] = {**smoke.binding, 'auroraSmoke': module.sha(__file__)}
        report['stage'] = 'current-isolated-https-snapshot'
        auth = smoke.request('/api/collections/game_players/auth-with-password',
                             {'identity': smoke.login['account'], 'password': smoke.login['password']})
        player = smoke.request('/api/questions/v1/me', token=auth['token'])
        items = smoke.request('/api/questions/v1/assignments', token=auth['token'])['items']
        module.require(player['id'] == smoke.manifest['playerId'] == auth['record']['id'] and
                       player['account'] == module.ACCOUNT and player['mustChangePassword'] is False,
                       'The current HTTPS identity must be the fixed preview player')
        report['checks'].append('Current HTTPS auth and me identify the fixed preview player')
        sections = {section: [] for section in JOURNEY_SECTIONS}
        for item in items:
            identifier = item['id']
            status = item['status']
            module.require(re.fullmatch(r'[a-z0-9]{15}', identifier) and
                           status in ('assigned', 'active', 'completed', 'cancelled'),
                           'The HTTPS assignment must match the UI contract')
            sections['current' if status in ('assigned', 'active') else 'history'].append(identifier)
        current = {item['id'] for item in items}
        seeded = {item['assignmentId'] for item in smoke.manifest['assignments'].values()}
        module.require(seeded.issubset(current) and len(current) == len(items), 'The current snapshot lost a seeded record')
        report['snapshotCounts'] = {'seeded': len(seeded), 'current': len(current),
                                    'ongoing': len(sections['current']), 'history': len(sections['history'])}
        del auth, player

        report['stage'] = 'device-direct-login'
        ui = DeviceUI(smoke.directory, smoke.directory)
        ui.launch(cold=True)
        ui.wait(lambda view: view.find('account') or view.find('lobby-identity'), 'fixed preview entry')
        if ui.find('account') is None:
            ui.tap('nav-profile')
            ui.wait(lambda view: view.find('passport-edit-profile') or view.find('profile-account'),
                    'fixed preview Passport opens')
            in_edit_sheet = ui.find('passport-edit-profile') is not None
            if in_edit_sheet:
                ui.tap('passport-edit-profile')
            module.require(ui.seek('profile-account').get('text') == module.ACCOUNT,
                           'The restored native account must be the isolated fixed preview player')
            if in_edit_sheet:
                ui.back()
                ui.wait(lambda view: view.find('profile-account') is None, 'profile edit Sheet closed')
            ui.tap('logout')
            ui.wait(lambda view: view.find('account') is not None, 'fixed preview login after explicit logout')
        report['untouchedLogin'] = login_first_view(ui, smoke.runtime['window'], module.require)
        report['checks'].append('Complete login card and controls fit the first screen with no scrolling')
        module.require(ui.input_empty('account') and ui.input_empty('password') and ui.has_text('隔离测试环境'),
                       'Device login must show the isolated environment and empty inputs')
        ui.fill('account', smoke.login['account'])
        ui.fill('password', smoke.login['password'])
        ui.tap('primary-action')
        ui.wait(lambda view: view.find('journey-segment') is not None, 'fixed preview home')
        module.require(ui.find('forced-logout') is None and ui.find('old-password') is None,
                       'Direct login must reach home without a password change')
        report['checks'].append('Cold isolated device login reached home directly')

        report['stage'] = 'device-current-assignment-snapshot'
        report['verifiedRows'] = 0
        density = smoke.runtime['window']['density']
        for section, identifiers in sections.items():
            report['stage'] = 'device-segment-' + section
            select_journey_section(ui, section, module.require)
            report['stage'] = 'device-assignment-cards-and-sync-' + section
            report['verifiedRows'] += scan_journey_section(ui, section, identifiers, density, module.require)
        select_journey_section(ui, 'current', module.require)
        smoke.immutable()
        report['checks'].append('Every current HTTPS assignment was reachable in its device tab')
        report['checks'].append('The scrollable final sync note was visible above navigation in both sections')
        report['status'] = 'passed'
        report['stage'] = 'complete'
    except Exception:
        report['failure'] = 'Preview verification stopped at the recorded stage. Private values omitted.'
    module.save(output, report)
    print(json.dumps({'status': report['status'], 'stage': report['stage'], 'checks': len(report['checks']),
                      'verifiedRows': report.get('verifiedRows', 0), 'output': str(output.relative_to(ROOT))}))
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())

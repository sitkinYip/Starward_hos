#!/usr/bin/env python3
"""Staged real-phone avatar acceptance; never imports, selects, or uploads media on the host.

Run with the bundled Python containing Pillow. Root first imports and SHA-verifies
only the non-private QA fixture through official hdc/mediatool. The private receipt
must contain fixtureSha256, readbackSha256, and mediaUri. The root operator selects
that exact fixture in the system Picker between these commands:
  begin -> [select fixture] -> cancel-crop -> [select fixture] -> reselect
  -> [cancel system Picker] -> pending-begin -> [select exact PNG again] -> pending-cancel
  -> confirm -> recovery -> decode-corrupt -> late-logout -> visual
`begin` opens the real Picker. `reselect` opens it again. Other steps operate only
this App's recognised ArkUI controls. No host profile write exists in this helper.
"""
import argparse
import datetime
import hashlib
import importlib.util
import io
import json
import math
import os
from pathlib import Path
import re
import ssl
import signal
import stat
import shutil
import time
import urllib.parse
import urllib.request

from native_device_ui import ROOT, IsolationControl, SafeFailure, flatten, sanitise
from isolated_snapshot import ReadonlySnapshot

_spec = importlib.util.spec_from_file_location('profile_core', ROOT / 'scripts/device-profile-acceptance.py')
_core = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_core)
ProfileUI = _core.ProfileUI
OUT = ROOT / 'artifacts/validation/profile'
REPORT = OUT / 'device-profile-avatar.json'
PRIVATE = ROOT / 'artifacts/private/profile-device'
SESSION = PRIVATE / 'avatar-session.json'
HAP = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
PROFILE = '/api/questions/v1/me/profile'
TOKEN = '/api/files/token'
PALETTE = [(210, 62, 69), (36, 112, 198), (224, 166, 43), (118, 76, 177)]


def sha(value):
    return hashlib.sha256(Path(value).read_bytes()).hexdigest()


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def private_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as out:
        json.dump(value, out, ensure_ascii=False, indent=2)
        out.write('\n')
    path.chmod(0o600)


class AvatarUI(ProfileUI):
    def capture(self, name=None):
        # Crop is an App Sheet. The system Picker deliberately fails this guard.
        raw = self.run('devecocli', 'ui', 'layout', '--format', 'json', '--mode', 'full')
        try:
            self.tree = json.loads(raw)
        except ValueError:
            raise SafeFailure('Official avatar UI dump was not JSON') from None
        self.flat = flatten(self.tree)
        ids = {n.get('id') for n in self.flat}
        app = bool(ids.intersection({'account', 'account-menu', 'environment-badge', 'profile-name'}))
        crop = bool(ids.intersection({'avatar-crop-preview', 'avatar-crop-loading', 'avatar-crop-error'}))
        if not (app or crop):
            raise SafeFailure('The owned App/crop Sheet is not foreground; system Picker was not touched')
        roots = self.tree if isinstance(self.tree, list) else [self.tree]
        bounds = next((n.get('bounds') for n in roots if n.get('bounds')), None)
        if not bounds or len(bounds) != 4:
            raise SafeFailure('Avatar App bounds are unavailable')
        self.width, self.height = bounds[2] - bounds[0], bounds[3] - bounds[1]
        if name:
            (self.output / ('ui-' + name + '.json')).write_text(json.dumps(
                self.redact(sanitise(self.tree)), ensure_ascii=False, indent=2) + '\n')
        return self.flat

    def minimum_height(self, node_id, node):
        if node_id == 'avatar-crop-preview' and node.get('bounds'):
            # Official dumps clip off-screen bounds. A Stack otherwise inherits
            # the generic8vp minimum and could pass seek while mostly clipped.
            return max(1, node['bounds'][2] - node['bounds'][0] - 3)
        if node_id == 'avatar-crop-confirm':
            return 52 * self.density * .9
        if node_id in ('avatar-crop-reselect', 'avatar-crop-cancel', 'avatar-retry'):
            return 44 * self.density * .9
        return super().minimum_height(node_id, node)

    def slider(self, node_id, fraction):
        node = self.seek(node_id)
        l, t, r, b = node['bounds']
        # Official Slider owns thumb/track hit-testing; use its interior, not an
        # invented synthetic crop state. Resulting image is checked separately.
        inset = min((r-l) * .08, 16 * self.density)
        x = int(l + inset + (r-l-2*inset) * fraction)
        self.run('devecocli', 'ui', 'click', x, int((t+b)/2))
        self.capture()

    def swipe(self, direction):
        self.capture()
        left, top, right, bottom = self.viewport()
        if right - left < 80 or bottom - top < 150:
            raise SafeFailure('Crop scroll viewport is too small for a safe gesture')
        # The preview has a real PanGesture. Scroll in its24vp outer gutter,
        # so finding another control does not inadvertently alter the crop.
        x = int(left + min(12 * self.density, (right-left) * .06))
        low, high = int(top+(bottom-top)*.76), int(top+(bottom-top)*.30)
        start, end = (low, high) if direction == 'down' else (high, low)
        self.run('devecocli', 'ui', 'swipe', x, start, x, end)


class AvatarAcceptance:
    def __init__(self, args):
        self.args = args
        self.control = IsolationControl()
        self.state = self.control.state
        self.runtime_path = args.runtime_report.resolve()
        if not self.runtime_path.is_relative_to(OUT.resolve()):
            raise SafeFailure('Avatar runtime report must remain in profile validation')
        runtime = json.loads(self.runtime_path.read_text())
        self.hap = sha(HAP)
        self.runtime_sha = sha(self.runtime_path)
        self.core_path = OUT / 'device-profile-acceptance.json'
        self.core_sha = sha(self.core_path)
        density = runtime.get('window', {}).get('density')
        if (runtime.get('status') != 'passed' or runtime.get('installedHapSha256') != self.hap or
                not isinstance(density, (int, float)) or not math.isfinite(density) or density <= 0):
            raise SafeFailure('Avatar runtime must bind the actual current HAP and density')
        core = json.loads((OUT / 'device-profile-acceptance.json').read_text())
        if (core.get('status') != 'passed' or core.get('hap', {}).get('packagedSha256') != self.hap or
                core.get('runtime', {}).get('sha256') != self.runtime_sha or
                core.get('cleanup', {}).get('loggedOut') is not True or
                core.get('cleanup', {}).get('faultNeutralised') is not True):
            raise SafeFailure('Complete matching core phone acceptance before avatar acceptance')
        security_path = OUT / 'device-profile-password-uncertain.json'
        key = core.get('finalPasswordKey')
        self.security_sha = None
        if security_path.exists():
            security = json.loads(security_path.read_text())
            if (security.get('status') != 'passed' or
                    security.get('hap', {}).get('packagedSha256') != self.hap or
                    security.get('runtime', {}).get('sha256') != self.runtime_sha or
                    security.get('corePrerequisite', {}).get('sha256') != self.core_sha or
                    not all(security.get('cleanup', {}).get(k) is True for k in ('loggedOut', 'faultNeutralised'))):
                raise SafeFailure('Resolve incomplete uncertain-password acceptance before avatar work')
            key = security.get('finalPasswordKey')
            self.security_sha = sha(security_path)
        if key not in ('initialPassword', 'newPassword'):
            raise SafeFailure('A verified current dedicated-password key is required')
        self.password_key = key
        self.ui = AvatarUI(self.state, density)
        self.owner = hashlib.sha256((self.state['account'] + self.state['playerId'] + self.state['controlBase']).encode()).hexdigest()
        self.session = {'ownerSha256': self.owner, 'hapSha256': self.hap, 'checks': [], 'phases': [],
                        'privateScreenshots': [], 'startedAt': now(), 'passwordKey': key,
                        'runtimeSha256': self.runtime_sha, 'coreSha256': self.core_sha,
                        'securitySha256': self.security_sha,
                        'requestLedger': [], 'hostReads': []}
        if args.action == 'begin' and SESSION.exists():
            if not args.new_attempt:
                raise SafeFailure('An avatar session already exists; use --new-attempt only for an intentional fresh attempt')
            stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
            archive = PRIVATE / ('avatar-session-' + stamp + '.json')
            shutil.copyfile(SESSION, archive)
            archive.chmod(0o600)
            if REPORT.exists():
                attempts = OUT / 'attempts'
                attempts.mkdir(exist_ok=True)
                shutil.copyfile(REPORT, attempts / ('avatar-' + stamp + '.json'))
        if args.action != 'begin':
            self.session = json.loads(SESSION.read_text())
            if (self.session.get('ownerSha256') != self.owner or self.session.get('hapSha256') != self.hap or
                    self.session.get('runtimeSha256') != self.runtime_sha or
                    self.session.get('coreSha256') != self.core_sha or
                    self.session.get('securitySha256') != self.security_sha):
                raise SafeFailure('Avatar session belongs to a different environment or HAP')
        self.ui.private_screenshots = self.session['privateScreenshots']
        required = {'cancel-crop': 'picker-open', 'reselect': 'crop-cancelled',
                    'pending-begin': 'reselect-open', 'pending-cancel': 'pending-repick-open',
                    'confirm': 'reselect-open', 'recovery': 'avatar-saved',
                    'decode-corrupt': 'recovery-and-logout', 'late-logout': 'recovery-and-logout',
                    'visual': 'decode-corrupt-restored'}
        if args.action in required and required[args.action] not in self.session['phases']:
            raise SafeFailure('The preceding avatar stage is not complete')
        if args.action == 'visual' and 'pending-repick-cancelled' not in self.session['phases']:
            raise SafeFailure('Visual completion requires pending-avatar retention and decode recovery')

    def save(self, phase=None, error=None):
        if (sha(HAP) != self.hap or sha(self.runtime_path) != self.runtime_sha or
                sha(self.core_path) != self.core_sha):
            raise SafeFailure('HAP changed during staged avatar acceptance')
        if phase and phase not in self.session['phases']:
            self.session['phases'].append(phase)
        self.session['updatedAt'] = now()
        private_json(SESSION, self.session)
        phases = self.session['phases']
        complete = all(p in phases for p in ('picker-open', 'crop-cancelled', 'reselect-open', 'pending-repick-cancelled', 'avatar-saved', 'recovery-and-logout', 'decode-corrupt-restored', 'visual-reviewed'))
        report = {'status': 'incomplete' if error else 'passed' if complete else 'awaiting_next_stage',
                  'scope': 'Task1 system Picker, crop, multipart, protected-avatar recovery and ordinary logout; delayed-response logout is an independent scope',
                  'environment': 'dedicated real PocketBase over strict USB HTTPS',
                  'startedAt': self.session['startedAt'], 'updatedAt': now(),
                  'hap': {'packagedSha256': self.hap},
                  'runtime': {'file': str(self.runtime_path.relative_to(ROOT)), 'sha256': self.runtime_sha},
                  'corePrerequisite': {'file': str(self.core_path.relative_to(ROOT)), 'sha256': self.core_sha},
                  'securityPrerequisiteSha256': self.security_sha,
                  'phases': phases, 'count': len(self.session['checks']), 'checks': self.session['checks'],
                  'requestLedger': self.session['requestLedger'], 'hostReads': self.session['hostReads'],
                  'privateScreenshots': self.ui.private_screenshots,
                  'fixture': {'sha256': self.session.get('fixtureSha256'), 'nonPrivateGeneratedImage': True,
                              'selection': 'Actual system Picker selection between staged commands; no host upload'},
                  'notExecuted': ['Invalid/over50MiB source selection needs a separate actual Picker check',
                                  'EXIF orientation cases are not covered by the orientation-free PNG fixture',
                                  'Actual switching to another account with an in-flight avatar is not exercised; old-generation unit tests are separate',
                                  'Foldable/hover/split-window testing is deferred by user instruction'] +
                                 ([] if 'decode-corrupt-restored' in phases else
                                  ['The real own-storage HTTP200 corrupt-image/native decode-retry phase has not completed']) +
                                 ([] if 'late-file-logout' in phases and self.session.get('lateFileLogout', {}).get('status') == 'passed' else
                                  ['The independent delayed-avatar logout phase is still pending or failed; basic403/503 and decode recovery retain their separate results']) +
                                 ([] if 'pending-repick-cancelled' in phases else
                                  ['Cancelling a second crop while an earlier confirmed avatar remains pending has not been verified']),
                  'finalPasswordKey': self.password_key,
                  'observations': self.session.get('observations', []),
                  'outputImage': self.session.get('outputImage'),
                  'imageComparison': self.session.get('imageComparison'),
                  'lateFileLogout': self.session.get('lateFileLogout', {'status': 'pending', 'executed': False}),
                  'phaseStatuses': {
                      'pendingRepickCancellation': 'passed' if 'pending-repick-cancelled' in phases else 'pending',
                      'basicFileRecovery': 'passed' if 'recovery-and-logout' in phases else 'pending',
                      'decodeCorruptRecovery': 'passed' if 'decode-corrupt-restored' in phases else 'pending',
                      'lateFileLogout': self.session.get('lateFileLogout', {}).get('status', 'pending')},
                  'injectedStorageFault': self.session.get('decodeStorageFault', {
                      'executed': False, 'stage': 'not_executed',
                      'description': 'Real corrupt-file HTTP200 and native ImageKit recovery must be run separately'}),
                  'visualEvidence': self.session.get('visualEvidence')}
        if error:
            report['error'] = self.ui.redact(error)
        REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')

    def check(self, condition, label, case, injected=False):
        if not condition:
            raise SafeFailure('Avatar expectation did not hold: ' + label)
        self.session['checks'].append({'case': case, 'label': label, 'injectedResilience': injected})
        self.save()
        print(json.dumps({'count': len(self.session['checks']), 'passed': label}, ensure_ascii=False), flush=True)

    def rows(self, path, method):
        return [r for r in self.control.requests() if r.get('path') == path and r.get('method') == method]

    def await_rows(self, path, method, before, statuses):
        deadline = time.monotonic() + 35
        while time.monotonic() < deadline:
            rows = self.rows(path, method)[before:]
            if len(rows) >= len(statuses) and all(r.get('status') for r in rows[:len(statuses)]):
                if [r['status'] for r in rows[:len(statuses)]] != statuses:
                    raise SafeFailure('New avatar request statuses differed from the expected sequence')
                return rows
            time.sleep(.2)
        raise SafeFailure('New avatar request did not complete')

    def checkpoint(self, phase):
        allowed = ('method', 'path', 'status', 'fault', 'responseDropped', 'authenticated', 'bearer',
                   'bodyKind', 'avatarPartPresent', 'requestBytes', 'fileTokenProvided')
        rows = []
        for row in self.control.requests():
            item = {k: row[k] for k in allowed if k in row}
            if str(item.get('path', '')).startswith('/api/files/game_players/'):
                item['path'] = '/api/files/game_players/[owner]/[avatar]'
            rows.append(item)
        self.session['requestLedger'].append({'phase': phase, 'requests': rows})

    def login(self):
        self.ui.wait(lambda u: u.find('account') is not None, 'blank avatar login')
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state[self.password_key])
        self.ui.tap('primary-action')
        self.ui.wait(lambda u: u.find('current-tab') is not None, 'authenticated avatar home')

    def profile(self):
        self.ui.tap('nav-profile')
        self.ui.seek('profile-avatar-pick')

    def logout(self):
        self.ui.hide_keyboard()
        self.ui.tap('account-menu')
        self.ui.seek('logout')
        self.ui.tap('logout')
        self.ui.wait(lambda u: u.find('account') is not None, 'avatar logout gate')
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('Avatar logout did not clear login fields')

    def picker(self):
        # No capture after the click: it has deliberately opened a different,
        # official system surface. Root must select only the imported test image.
        self.ui.tap('profile-avatar-pick')

    def crop(self):
        self.ui.wait(lambda u: u.find('avatar-crop-preview') is not None, 'prepared native crop preview')
        node = self.ui.seek('avatar-crop-preview')
        self.check(node['bounds'][2] - node['bounds'][0] > 100 and
                   abs((node['bounds'][2] - node['bounds'][0]) - (node['bounds'][3] - node['bounds'][1])) <= 3,
                   'The actual native crop preview exposes a square viewport', 'A2')

    def begin(self):
        if not self.args.receipt:
            raise SafeFailure('A private exact-fixture import/readback receipt is required')
        receipt_path = self.args.receipt.resolve()
        if not receipt_path.is_relative_to((ROOT / 'artifacts/private').resolve()):
            raise SafeFailure('Fixture import receipt must remain private')
        receipt = json.loads(receipt_path.read_text())
        fixture = OUT / 'avatar-fixture.png'
        digest = sha(fixture)
        if (receipt.get('fixtureSha256') != digest or receipt.get('readbackSha256') != digest or
                not isinstance(receipt.get('mediaUri'), str) or not receipt['mediaUri']):
            raise SafeFailure('The imported fixture must have an exact matching SHA-verified readback')
        self.session['fixtureSha256'] = digest
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state[self.password_key])
        player = snapshot.request('/api/questions/v1/me')
        self.session['originalName'] = player['displayName']
        self.session['originalAvatar'] = player['avatar']
        self.session['beforePatch'] = len(self.rows(PROFILE, 'PATCH'))
        self.ui.launch(cold=True)
        self.login()
        self.profile()
        self.ui.capture('avatar-before-picker')
        self.session['originalDraft'] = self.ui.find('profile-name').get('text') if self.ui.find('profile-name') else player['displayName']
        self.check(not self.ui.find('profile-avatar-pending'), 'Before selecting, no avatar draft is pending', 'A1')
        self.picker()
        self.save('picker-open')
        print('System Picker opened. Select only the SHA-verified imported QA fixture, then run cancel-crop.', flush=True)

    def cancel_crop(self):
        self.crop()
        self.ui.private_shot('avatar-crop-default-before-cancel')
        self.ui.slider('avatar-crop-zoom', .5)
        self.ui.slider('avatar-crop-horizontal', 0)
        self.ui.slider('avatar-crop-vertical', 0)
        self.ui.seek('avatar-crop-preview')
        self.ui.private_shot('avatar-crop-adjusted-before-cancel')
        self.session.setdefault('observations', []).append(
            'Official zoom/horizontal/vertical Slider click commands executed in cancelled draft; exact values were not exposed or asserted. Private before/after images require visual review.')
        self.ui.tap('avatar-crop-cancel')
        self.ui.wait(lambda u: u.find('avatar-crop-preview') is None, 'native crop cancellation')
        self.ui.seek('profile-name')
        self.check(self.ui.find('profile-name').get('text') == self.session['originalDraft'] and
                   self.ui.find('profile-avatar-pending') is None and
                   len(self.rows(PROFILE, 'PATCH')) == self.session['beforePatch'],
                   'Cancelling a prepared/adjusted crop preserves the nickname draft and sends no PATCH', 'A2')
        self.checkpoint('cancelled-native-crop')
        self.picker()
        self.save('crop-cancelled')
        print('System Picker reopened. Select the exact QA fixture again, then run reselect.', flush=True)

    def reselect(self):
        self.crop()
        self.ui.tap('avatar-crop-reselect')
        self.save('reselect-open')
        print('System Picker opened by native reselect. Cancel it through its official Back/Cancel, then run confirm.', flush=True)

    def pending_begin(self):
        # Root has cancelled the system reselect Picker and returned to the
        # existing crop. Confirming it creates a draft, never a profile write.
        self.crop()
        self.ui.private_shot('avatar-crop-after-cancelled-reselect')
        self.check(len(self.rows(PROFILE, 'PATCH')) == self.session['beforePatch'],
                   'Cancelling system reselect keeps the earlier crop usable without any new profile PATCH', 'A1')
        self.ui.tap('avatar-crop-confirm')
        self.ui.wait(lambda u: u.find('avatar-crop-preview') is None, 'first confirmed crop becomes an avatar draft')
        self.ui.seek('profile-avatar-pending')
        pending_visible = self.ui.find('profile-avatar-pending') is not None
        self.ui.seek('profile-name')
        self.check(pending_visible and self.ui.find('profile-name').get('text') == self.session['originalDraft'] and
                   len(self.rows(PROFILE, 'PATCH')) == self.session['beforePatch'],
                   'The first crop confirmation creates a pending avatar, retains the nickname and sends no PATCH', 'A2')
        self.ui.seek('profile-avatar-pending')
        self.ui.private_shot('avatar-pending-before-repick')
        self.session.setdefault('observations', []).append(
            'The repeated selection uses the same exact imported PNG. Pending-retention checks assert visible pending state, unchanged nickname and no new write; they do not establish identity of in-memory avatar bytes.')
        self.checkpoint('confirmed-avatar-pending-before-repick')
        self.picker()
        self.save('pending-repick-open')
        print('System Picker reopened while an avatar is already pending. Select the exact PNG fixture again, then run pending-cancel.', flush=True)

    def pending_cancel(self):
        # Cancelling the new crop must preserve the already-confirmed draft.
        self.crop()
        self.ui.tap('avatar-crop-cancel')
        self.ui.wait(lambda u: u.find('avatar-crop-preview') is None, 'second crop cancellation')
        self.ui.seek('profile-avatar-pending')
        pending_visible = self.ui.find('profile-avatar-pending') is not None
        self.ui.seek('profile-name')
        self.check(pending_visible and self.ui.find('profile-name').get('text') == self.session['originalDraft'] and
                   len(self.rows(PROFILE, 'PATCH')) == self.session['beforePatch'],
                   'Cancelling a second native crop keeps the earlier pending avatar and nickname without a profile PATCH', 'A2')
        self.ui.seek('profile-avatar-pending')
        self.ui.private_shot('avatar-pending-after-repick-cancel')
        self.checkpoint('earlier-avatar-pending-after-repick-cancel')
        self.save('pending-repick-cancelled')

    def host_avatar(self):
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state[self.password_key])
        player = snapshot.request('/api/questions/v1/me')
        filename = player.get('avatar', '')
        if not filename or player.get('id') != self.state['playerId']:
            raise SafeFailure('The real player did not retain an owned avatar')
        self.session['avatarName'] = filename
        path = '/api/files/game_players/' + urllib.parse.quote(self.state['playerId'], safe='') + '/' + urllib.parse.quote(filename, safe='')
        self.session['avatarPath'] = path
        ctx = ssl.create_default_context(cafile=self.state['tls']['caPath'])
        req = urllib.request.Request(self.state['tls']['hostBase'] + TOKEN, data=b'{}', method='POST',
                                     headers={'Authorization': snapshot.token, 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=25) as response:
                file_token = json.load(response)['token']
            req = urllib.request.Request(self.state['tls']['hostBase'] + path + '?token=' + urllib.parse.quote(file_token, safe=''))
            with urllib.request.urlopen(req, context=ctx, timeout=25) as response:
                content_type = response.headers.get_content_type()
                image_bytes = response.read(2 * 1024 * 1024 + 1)
        except Exception:
            raise SafeFailure('Strict HTTPS protected-avatar readback failed; addresses omitted') from None
        self.session['hostReads'].append({'purpose': 'readback-only after native upload', 'fileTokenStatus': 200,
                                           'fileStatus': 200, 'contentType': content_type, 'bytes': len(image_bytes)})
        target = PRIVATE / 'uploaded-avatar.jpg'
        target.write_bytes(image_bytes)
        target.chmod(0o600)
        try:
            from PIL import Image, ImageChops, ImageStat
        except ImportError:
            raise SafeFailure('Run this helper with the bundled Pillow-enabled Python') from None
        with Image.open(io.BytesIO(image_bytes)) as image:
            pixels = image.convert('RGB')
            width, height = image.size
            self.check(content_type == 'image/jpeg' and image.format == 'JPEG' and
                       width == height == 512 and len(image_bytes) <= 200 * 1024,
                       'Real uploaded bytes are a512px square JPEG within200KiB', 'A3')
            self.check(not dict(image.getexif()), 'Re-encoded avatar contains no source EXIF fields', 'A2')
            for expected, point in zip(PALETTE, ((.17, .17), (.83, .17), (.17, .83), (.83, .83))):
                actual = pixels.getpixel((int(width*point[0]), int(height*point[1])))
                if max(abs(actual[i]-expected[i]) for i in range(3)) > 36:
                    raise SafeFailure('Real uploaded crop did not match the selected four-quadrant fixture')
            self.check(True, 'Four authoritative output colour patches match the actual selected fixture', 'A3')
            # Four quadrant samples alone cannot distinguish a correct crop
            # from stretching the entire1024x640 source into a square. Compare
            # the entire output to the independently constructed center crop,
            # and require the incorrect whole-image stretch to be much worse.
            fixture_path = OUT / 'avatar-fixture.png'
            if sha(fixture_path) != self.session['fixtureSha256']:
                raise SafeFailure('Source fixture changed before crop-geometry comparison')
            with Image.open(fixture_path) as original:
                original = original.convert('RGB')
                if original.size != (1024, 640):
                    raise SafeFailure('Crop comparison requires the original1024x640 QA fixture')
                expected = original.crop((192, 0, 832, 640)).resize((512, 512), Image.Resampling.LANCZOS)
                wrong_stretch = original.resize((512, 512), Image.Resampling.LANCZOS)
            def mean_absolute_error(reference):
                return sum(ImageStat.Stat(ImageChops.difference(pixels, reference)).mean) / 3
            crop_mae = mean_absolute_error(expected)
            stretch_mae = mean_absolute_error(wrong_stretch)
            self.session['imageComparison'] = {
                'method': 'Full512x512 RGB mean absolute channel error in0..255 units',
                'sourceFixtureSha256': self.session['fixtureSha256'],
                'expected': {'sourceCrop': [192, 0, 832, 640], 'resize': [512, 512], 'resampling': 'Pillow LANCZOS'},
                'wrongHypothesis': 'Entire1024x640 fixture stretched directly to512x512',
                'centerCropMae': round(crop_mae, 6), 'wholeImageStretchMae': round(stretch_mae, 6),
                'thresholds': {'maxCenterCropMae': 8, 'minWrongMinusCorrectMae': 5, 'minWrongToCorrectRatio': 1.6},
                'tolerance': 'Allows native scaling and two JPEG encodes; distinguishes wrong crop geometry. Threshold fixed before phone execution.'}
            self.check(crop_mae <= 8 and stretch_mae >= crop_mae + 5 and stretch_mae >= crop_mae * 1.6,
                       'The entire real JPEG matches the independent centered crop and is substantially closer than an incorrect whole-image stretch', 'A2')
        self.session['outputImage'] = {'sha256': hashlib.sha256(image_bytes).hexdigest(), 'width': width,
                                       'height': height, 'bytes': len(image_bytes), 'format': 'JPEG'}

    def confirm(self):
        if 'pending-repick-cancelled' in self.session['phases']:
            # The new retention path has already confirmed the earlier crop,
            # selected another source and cancelled its crop. Save that draft.
            self.ui.seek('profile-avatar-pending')
            pending_visible = self.ui.find('profile-avatar-pending') is not None
            self.ui.seek('profile-name')
            self.check(pending_visible and self.ui.find('profile-name').get('text') == self.session['originalDraft'] and
                       len(self.rows(PROFILE, 'PATCH')) == self.session['beforePatch'],
                       'The retained pending avatar remains unsaved with the original nickname before explicit save', 'A2')
            self.ui.seek('profile-avatar-pending')
        else:
            # Legacy path remains usable for an independently partial run, but
            # overall passed still requires the explicit pending-retention phase.
            self.crop()
            self.ui.private_shot('avatar-crop-after-cancelled-reselect')
            self.check(len(self.rows(PROFILE, 'PATCH')) == self.session['beforePatch'],
                       'Cancelling system reselect keeps the previous crop usable and sends no profile write', 'A1')
            self.ui.tap('avatar-crop-confirm')
            self.ui.wait(lambda u: u.find('avatar-crop-preview') is None, 'confirmed crop closes its native Sheet')
            self.ui.seek('profile-avatar-pending')
            self.check(self.ui.find('profile-avatar-pending') is not None and
                       len(self.rows(PROFILE, 'PATCH')) == self.session['beforePatch'],
                       'Crop confirmation creates only an unsaved local avatar draft', 'A2')
        self.ui.private_shot('avatar-pending')
        before = len(self.rows(PROFILE, 'PATCH'))
        self.control.call('/fault', {'path': PROFILE, 'method': 'PATCH', 'status': 503})
        self.ui.tap('profile-save')
        self.await_rows(PROFILE, 'PATCH', before, [503])
        self.ui.wait(lambda u: u.find('profile-error') is not None, 'avatar multipart failure')
        self.ui.seek('profile-avatar-pending')
        self.check(self.ui.find('profile-avatar-pending') is not None,
                   'Injected multipart503 preserves the selected avatar for an explicit retry', 'A3', True)
        before_token = len(self.rows(TOKEN, 'POST'))
        before_file = len([r for r in self.control.requests() if str(r.get('path', '')).startswith('/api/files/game_players/')])
        self.ui.tap('profile-save')
        rows = self.await_rows(PROFILE, 'PATCH', before + 1, [200])
        row = rows[0]
        self.ui.wait(lambda u: u.find('profile-saved') is not None, 'avatar profile saved')
        self.check(row.get('bodyKind') == 'multipart' and row.get('avatarPartPresent') is True and
                   row.get('authenticated') and row.get('bearer') is False,
                   'The native retry sends a real authenticated multipart PATCH containing an avatar part', 'A3')
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            files = [r for r in self.control.requests() if str(r.get('path', '')).startswith('/api/files/game_players/')][before_file:]
            if any(r.get('status') == 200 and r.get('fileTokenProvided') for r in files):
                break
            time.sleep(.2)
        else:
            raise SafeFailure('The native avatar did not complete a new protected-file GET200')
        self.check(len(self.rows(TOKEN, 'POST')) > before_token,
                   'After saving, native code requests a new file token and fetches the protected avatar200', 'A3')
        self.ui.seek('profile-avatar-pick')
        self.ui.private_shot('avatar-profile-saved')
        self.ui.tap('account-menu')
        self.ui.wait(lambda u: u.find('menu-profile') is not None, 'avatar in account menu')
        self.ui.private_shot('avatar-menu-saved')
        self.ui.back()
        self.host_avatar()
        self.checkpoint('real-native-avatar-upload')
        self.save('avatar-saved')
        print('Native upload and byte readback completed. Inspect private profile/menu images for rendered fixture, then run recovery.', flush=True)

    def recovery(self):
        # A failed late-response race may already have logged out. A retry of
        # this read-only recovery phase may start from either owned App state.
        self.ui.capture()
        if self.ui.find('account') is not None:
            self.login()
            self.profile()
        path = self.session.get('avatarPath')
        if not isinstance(path, str) or not path.startswith('/api/files/game_players/' + self.state['playerId'] + '/'):
            raise SafeFailure('A native-uploaded avatar is required before recovery')
        self.logout()
        before_token, before_file = len(self.rows(TOKEN, 'POST')), len(self.rows(path, 'GET'))
        self.control.call('/fault', {'path': path, 'method': 'GET', 'status': 403})
        self.login()
        rows = self.await_rows(path, 'GET', before_file, [403, 200])
        self.profile()
        self.check(len(rows) == 2 and len(self.rows(TOKEN, 'POST')) == before_token + 2 and
                   rows[0].get('fault') and not rows[1].get('fault'),
                   'One injected file403 causes exactly one fresh file token and successful protected-file retry', 'A4', True)
        self.check(self.ui.find('account') is None and self.ui.find('avatar-error') is None,
                   'Protected-file403 does not expire the main account and the recovered profile remains usable', 'A4', True)
        self.ui.private_shot('avatar-token-recovered')
        self.logout()
        before_file = len(self.rows(path, 'GET'))
        self.control.call('/fault', {'path': path, 'method': 'GET', 'status': 503})
        self.login()
        self.await_rows(path, 'GET', before_file, [503])
        self.profile()
        self.ui.seek('avatar-error')
        self.check(self.ui.find('avatar-error') is not None and self.ui.find('account') is None,
                   'Injected file503 exposes a persistent image error while preserving account access', 'A4', True)
        self.ui.tap('avatar-retry')
        self.await_rows(path, 'GET', before_file + 1, [200])
        self.ui.wait(lambda u: u.find('avatar-error') is None, 'explicit avatar retry recovery')
        self.check(True, 'Explicit native avatar retry performs a new real GET200 and clears the image error', 'A4')
        self.ui.private_shot('avatar-file-retry-recovered')
        self.logout()
        self.ui.back()
        self.ui.launch()
        self.ui.wait(lambda u: u.find('account') is not None, 'avatar logout route boundary')
        self.check(self.ui.input_empty('account') and self.ui.input_empty('password') and
                   self.ui.find('profile-avatar-pending') is None and self.ui.find('profile-name') is None,
                   'Logout and Back/Ability relaunch expose no former profile draft or private image view', 'A4')
        self.checkpoint('file-recovery-and-final-logout')
        self.save('recovery-and-logout')

    def late_logout(self):
        # Independent from basic403/503 and ImageKit recovery so a narrow
        # timing window cannot prevent the other scopes from being executed.
        self.ui.capture()
        if self.ui.find('account') is None:
            self.logout()
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('Late-avatar acceptance requires explicit empty login')
        path = self.session.get('avatarPath')
        if not isinstance(path, str) or not path.startswith('/api/files/game_players/' + self.state['playerId'] + '/'):
            raise SafeFailure('The independent late-avatar test requires this own native-uploaded file')
        self.session['lateFileLogout'] = {'status': 'running', 'executed': False}
        self.save()
        try:
            self.late_file_logout(path)
        except Exception as error:
            late = self.session.setdefault('lateFileLogout', {})
            late['status'] = 'failed'
            late['error'] = self.ui.redact(str(error) if isinstance(error, SafeFailure) else
                                          'Independent late-avatar phase stopped before completion')
            raise

    def late_file_logout(self, path):
        config = json.loads((ROOT / 'entry/src/main/resources/rawfile/integration.json').read_text())
        if config.get('isolated') is not True or config.get('endpoint') != self.state['tls']['base']:
            raise SafeFailure('Delayed-avatar testing requires this packaged dedicated HTTPS environment')
        if config.get('timeoutMs', 0) <= 1500:
            raise SafeFailure('The1500ms avatar delay must remain below the App request timeout')
        # Calibrate real native controls without a race, while the same HAP,
        # player, font/window and menu layout are active. Record only geometric
        # official UiTest swipe arguments, never input values or account text.
        self.login()
        menu = self.ui.seek('account-menu')['bounds']
        menu_point = [int((menu[0]+menu[2])/2), int((menu[1]+menu[3])/2)]
        self.ui.tap('account-menu')
        swipes = []
        original_run = self.ui.run
        def record_run(*args, **kwargs):
            if len(args) >= 7 and tuple(args[:3]) == ('devecocli', 'ui', 'swipe'):
                if len(args) != 7 or not all(isinstance(v, int) for v in args[3:]):
                    raise SafeFailure('Unexpected arguments in the native logout calibration')
                swipes.append(list(args[3:]))
            return original_run(*args, **kwargs)
        self.ui.run = record_run
        try:
            logout = self.ui.seek('logout')['bounds']
        finally:
            self.ui.run = original_run
        logout_point = [int((logout[0]+logout[2])/2), int((logout[1]+logout[3])/2)]
        self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', *logout_point)
        self.ui.wait(lambda u: u.find('account') is not None, 'calibrated avatar logout')
        self.ui.fill('account', self.state['account'])
        self.ui.fill('password', self.state[self.password_key])
        login_bounds = self.ui.seek('primary-action')['bounds']
        login_point = [int((login_bounds[0]+login_bounds[2])/2), int((login_bounds[1]+login_bounds[3])/2)]
        before_file = len(self.rows(path, 'GET'))
        self.session['lateFileLogout'] = {'status': 'running', 'executed': True,
            'delayMs': 1500, 'appTimeoutMs': config['timeoutMs'],
            'source': 'Same-HAP native controls calibrated immediately before official HDC UiTest replay',
            'calibratedMenuSwipes': len(swipes), 'pendingBeforeLogout': False,
            'emptyLoginObservedBeforeResponse': False, 'responseCompleted200': False,
            'emptyAfterResponseAndBack': False, 'faultNeutralised': False}
        self.control.call('/fault', {'path': path, 'method': 'GET', 'delayMs': 1500})
        try:
            self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', *login_point)
            deadline = time.monotonic() + 3
            pending = None
            while time.monotonic() < deadline:
                rows = self.rows(path, 'GET')[before_file:]
                if rows:
                    pending = rows[0]
                    break
                time.sleep(.01)
            if not pending or pending.get('status') != 0 or not pending.get('fault'):
                raise SafeFailure('The real delayed avatar request was not observed in flight')
            started = time.monotonic()
            self.session['lateFileLogout']['pendingBeforeLogout'] = True
            # The login transition has started this very App's avatar request.
            # Use the previously measured native menu/Scroll/logout geometry;
            # no synthetic VM route or host logout endpoint exists here.
            self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', *menu_point)
            for swipe in swipes:
                self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'swipe', *swipe)
            self.ui.run('hdc', 'shell', 'uitest', 'uiInput', 'click', *logout_point)
            self.ui.capture()
            empty_before = self.ui.find('account') is not None
            row_after = self.rows(path, 'GET')[before_file:][0]
            self.session['lateFileLogout']['logoutObservationElapsedMs'] = round((time.monotonic()-started)*1000, 3)
            self.session['lateFileLogout']['emptyLoginObservedBeforeResponse'] = bool(empty_before and row_after.get('status') == 0)
            self.check(empty_before and row_after.get('status') == 0,
                       'The native UI reaches empty login while the injected1500ms avatar response is still pending', 'A4', True)
            rows = self.await_rows(path, 'GET', before_file, [200])
            self.session['lateFileLogout']['responseCompleted200'] = rows[0].get('status') == 200
            self.ui.capture()
            if self.ui.find('account') is None:
                raise SafeFailure('Late avatar response restored an authenticated App view')
            self.ui.back()
            self.ui.launch()
            self.ui.wait(lambda u: u.find('account') is not None, 'late-avatar Back and Ability boundary')
            empty = self.ui.input_empty('account') and self.ui.input_empty('password')
            self.session['lateFileLogout']['emptyAfterResponseAndBack'] = empty
            self.check(empty and self.ui.find('profile-name') is None and self.ui.find('profile-avatar-pending') is None,
                       'A real avatar GET200 completed after logout and cannot restore the image, draft, route or login through Back/relaunch', 'A4', True)
            self.ui.private_shot('avatar-after-late-file-logout')
            self.checkpoint('late-protected-file-response-after-native-logout')
        finally:
            self.control.call('/fault', {'path': '/__never_forward_avatar_fault__', 'method': 'GET', 'status': 503})
            self.session['lateFileLogout']['faultNeutralised'] = True
        self.session['lateFileLogout']['status'] = 'passed'
        self.save('late-file-logout')

    def storage_fixture(self):
        """Resolve only this runner's exact, already-uploaded QA avatar inode."""
        isolation = ROOT / 'artifacts/private/https-isolation'
        source_value = self.state.get('sourceDirectory')
        if not isinstance(source_value, str):
            raise SafeFailure('Disposable backend source directory is not recorded')
        source = Path(source_value)
        if (not source.is_absolute() or source.is_symlink() or source.parent.resolve() != isolation.resolve() or
                not re.fullmatch(r'questions-pb-test-[A-Za-z0-9_-]{1,100}', source.name) or
                source.resolve() != source or not source.is_dir()):
            raise SafeFailure('Storage fault is restricted to this own disposable backend directory')
        player = self.state.get('playerId', '')
        filename = self.session.get('avatarName', '')
        digest = self.session.get('outputImage', {}).get('sha256', '')
        if (not re.fullmatch(r'[a-z0-9]{15}', player) or
                not isinstance(filename, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,200}', filename) or
                filename in ('.', '..') or not re.fullmatch(r'[a-f0-9]{64}', digest)):
            raise SafeFailure('Exact owned player, avatar and successful native-upload SHA are required')
        storage = source / 'pb_data/storage'
        for directory in (source / 'pb_data', storage):
            if directory.is_symlink() or not directory.is_dir():
                raise SafeFailure('Disposable storage directories must be regular directories without symlinks')
        candidates = list(storage.glob('*/' + player + '/' + filename))
        if len(candidates) != 1:
            raise SafeFailure('The exact owned fixture must match one and only one storage file')
        target = candidates[0]
        if not target.resolve().is_relative_to(storage.resolve()):
            raise SafeFailure('Owned avatar resolved outside disposable storage')
        for item in (target.parent.parent, target.parent, target):
            if item.is_symlink():
                raise SafeFailure('Storage fault refuses symlinked collection/player/file paths')
        if not target.parent.parent.is_dir() or not target.parent.is_dir():
            raise SafeFailure('Owned avatar collection/player directories are invalid')
        info = target.lstat()
        if not stat.S_ISREG(info.st_mode):
            raise SafeFailure('Only the exact regular uploaded fixture may be changed')
        return target, digest

    def storage_readback(self, expected_bytes):
        """Read-only HTTPS proof of actual PB status, MIME and body; never upload."""
        snapshot = ReadonlySnapshot(self.state)
        snapshot.login(self.state[self.password_key])
        player = snapshot.request('/api/questions/v1/me')
        if player.get('id') != self.state['playerId'] or player.get('avatar') != self.session['avatarName']:
            raise SafeFailure('Storage fault player/avatar no longer matches this native upload')
        ctx = ssl.create_default_context(cafile=self.state['tls']['caPath'])
        request = urllib.request.Request(self.state['tls']['hostBase'] + TOKEN, data=b'{}', method='POST',
            headers={'Authorization': snapshot.token, 'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(request, context=ctx, timeout=25) as response:
                file_token = json.load(response)['token']
            request = urllib.request.Request(self.state['tls']['hostBase'] + self.session['avatarPath'] +
                                            '?token=' + urllib.parse.quote(file_token, safe=''))
            with urllib.request.urlopen(request, context=ctx, timeout=25) as response:
                body = response.read(2 * 1024 * 1024 + 1)
                status, content_type = response.status, response.headers.get_content_type()
        except Exception:
            raise SafeFailure('Real protected-fixture HTTPS readback failed; URL and token omitted') from None
        if status != 200 or content_type != 'image/jpeg' or body != expected_bytes:
            raise SafeFailure('PB did not serve the precise injected/restored JPEG fixture as real HTTP200 image/jpeg')
        return {'source': 'Host read-only strict HTTPS probe, separate from subsequent native request',
                'status': status, 'contentType': content_type, 'bytes': len(body),
                'sha256': hashlib.sha256(body).hexdigest()}

    def decode_corrupt(self):
        """Corrupt only a SHA-verified own fixture, and restore even on failure."""
        self.ui.capture()
        if self.ui.find('account') is None:
            self.logout()
        if not self.ui.input_empty('account') or not self.ui.input_empty('password'):
            raise SafeFailure('Corrupt-image acceptance requires explicit empty login before mutation')
        target, expected_sha = self.storage_fixture()
        descriptor = None
        original = None
        original_mode = None
        mutated = False
        previous_handlers = {}
        fault = {'executed': False, 'injectedStorageFault': True,
                 'scope': 'Exact SHA-verified avatar from this phone native multipart in the disposable backend only',
                 'productionFault': False, 'stage': 'preparing', 'originalSha256': expected_sha,
                 'injectedHex': 'ffd8ff00', 'injectedBytes': 4, 'restored': False,
                 'cleanupLoggedOut': False, 'automaticNativeRereadObserved': None}
        self.session['decodeStorageFault'] = fault
        before_writes = len(self.rows(PROFILE, 'PATCH'))
        before_password_writes = len(self.rows('/api/questions/v1/me/change-password', 'POST'))
        def overwrite(data):
            os.lseek(descriptor, 0, os.SEEK_SET)
            os.ftruncate(descriptor, 0)
            pending = memoryview(data)
            while pending:
                count = os.write(descriptor, pending)
                if count <= 0:
                    raise SafeFailure('Owned fixture write did not complete')
                pending = pending[count:]
            os.fsync(descriptor)
        def verify_inode():
            current = target.lstat()
            opened = os.fstat(descriptor)
            if (not stat.S_ISREG(current.st_mode) or
                    (current.st_dev, current.st_ino) != (opened.st_dev, opened.st_ino)):
                raise SafeFailure('Owned fixture path changed during the isolated fault')
        def interrupted(signum, frame):
            raise SafeFailure('Corrupt-fixture acceptance interrupted; original bytes will be restored')
        try:
            descriptor = os.open(target, os.O_RDWR | os.O_NOFOLLOW)
            opened = os.fstat(descriptor)
            if not stat.S_ISREG(opened.st_mode):
                raise SafeFailure('The opened owned fixture is not a regular file')
            original_mode = stat.S_IMODE(opened.st_mode)
            with os.fdopen(os.dup(descriptor), 'rb') as stream:
                original = stream.read(2 * 1024 * 1024 + 1)
            if (hashlib.sha256(original).hexdigest() != expected_sha or
                    len(original) != self.session['outputImage'].get('bytes') or
                    len(original) > 200 * 1024):
                raise SafeFailure('Storage bytes do not match this session native-uploaded QA JPEG')
            verify_inode()
            backup = PRIVATE / ('avatar-storage-backup-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '.jpg')
            backup_fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            with os.fdopen(backup_fd, 'wb') as stream:
                stream.write(original)
                stream.flush()
                os.fsync(stream.fileno())
            backup.chmod(0o600)
            if sha(backup) != expected_sha:
                raise SafeFailure('Private fixture backup did not match the native upload SHA')
            fault['backup'] = {'file': str(backup.relative_to(ROOT)), 'sha256': expected_sha, 'mode': '0600'}
            for signum in (signal.SIGINT, signal.SIGTERM):
                previous_handlers[signum] = signal.getsignal(signum)
                signal.signal(signum, interrupted)
            mutated = True
            os.fchmod(descriptor, 0o600)
            corrupt = bytes.fromhex('ffd8ff00')
            overwrite(corrupt)
            verify_inode()
            with os.fdopen(os.dup(descriptor), 'rb') as stream:
                stream.seek(0)
                if stream.read() != corrupt:
                    raise SafeFailure('Owned fixture corruption did not retain the exact four test bytes')
            fault.update({'executed': True, 'stage': 'corrupt_real_file'})
            self.save()
            # A Host read proves the real response MIME/body while the file is
            # held corrupt. Native traffic is counted only after this probe.
            fault['corruptReadback'] = self.storage_readback(corrupt)
            before_file = len(self.rows(self.session['avatarPath'], 'GET'))
            self.login()
            rows = self.await_rows(self.session['avatarPath'], 'GET', before_file, [200])
            self.profile()
            self.ui.seek('avatar-error')
            self.ui.seek('avatar-retry')
            self.check(len(rows) == 1 and not rows[0].get('fault') and
                       rows[0].get('fileTokenProvided') is True and self.ui.find('avatar-retry') is not None,
                       'Real HTTP200 image/jpeg with valid JPEG magic but corrupt image bytes exposes a native image error and retry action',
                       'A4', True)
            self.ui.private_shot('avatar-decode-corrupt-error')
            # Verify persistence through a real foreground/me refresh; an error
            # must not start another file read merely by reopening the profile.
            before_me = len(self.rows('/api/questions/v1/me', 'GET'))
            self.ui.foreground_cycle()
            self.await_rows('/api/questions/v1/me', 'GET', before_me, [200])
            self.profile()
            self.ui.seek('avatar-error')
            native_files = self.rows(self.session['avatarPath'], 'GET')[before_file:]
            fault['automaticNativeRereadObserved'] = len(native_files) != 1
            self.check(self.ui.find('avatar-error') is not None and len(native_files) == 1,
                       'The actual native decode error persists across foreground/me sync without automatic file rereads',
                       'A4', True)
        finally:
            if descriptor is not None:
                try:
                    if mutated and original is not None:
                        # SIGINT/SIGTERM cannot interrupt this brief restoration.
                        # SIGKILL/power loss cannot run Python finally; the exact
                        # SHA-bound private backup remains for explicit recovery.
                        for signum in previous_handlers:
                            signal.signal(signum, signal.SIG_IGN)
                        overwrite(original)
                        os.fchmod(descriptor, original_mode)
                        os.fsync(descriptor)
                        verify_inode()
                        with os.fdopen(os.dup(descriptor), 'rb') as stream:
                            stream.seek(0)
                            restored_sha = hashlib.sha256(stream.read()).hexdigest()
                        if restored_sha != expected_sha or sha(target) != expected_sha:
                            raise SafeFailure('Owned fixture restoration SHA did not match the original')
                        fault.update({'restored': True, 'restoredSha256': restored_sha,
                                      'stage': 'original_bytes_restored'})
                finally:
                    os.close(descriptor)
                    for signum, handler in previous_handlers.items():
                        signal.signal(signum, handler)
            # Persist cleanup facts even when a UI/readback assertion fails.
            self.save()
        if not fault['restored']:
            raise SafeFailure('Corrupt-fixture acceptance did not restore original bytes')
        fault['restoredReadback'] = self.storage_readback(original)
        before_retry = len(self.rows(self.session['avatarPath'], 'GET'))
        self.ui.tap('avatar-retry')
        rows = self.await_rows(self.session['avatarPath'], 'GET', before_retry, [200])
        self.ui.wait(lambda u: u.find('avatar-error') is None, 'explicit native decode retry after restoring the real JPEG')
        self.ui.seek('profile-avatar-pick')
        self.ui.private_shot('avatar-decode-corrupt-recovered')
        self.ui.capture()
        self.check(not rows[0].get('fault') and self.ui.find('avatar-error') is None,
                   'After exact fixture restoration, explicit native retry performs a new real GET200 and clears the image error',
                   'A4', True)
        self.logout()
        self.ui.back()
        self.ui.launch()
        self.ui.wait(lambda u: u.find('account') is not None, 'corrupt-avatar final logout boundary')
        empty = self.ui.input_empty('account') and self.ui.input_empty('password')
        fault['cleanupLoggedOut'] = empty
        self.check(empty and len(self.rows(PROFILE, 'PATCH')) == before_writes and
                   len(self.rows('/api/questions/v1/me/change-password', 'POST')) == before_password_writes,
                   'Corrupt-image recovery leaves empty login after Back/relaunch and submits no profile/password write',
                   'A4', True)
        self.checkpoint('injected-owned-storage-corrupt-image-restored-and-retried')
        self.save('decode-corrupt-restored')

    def visual(self):
        # The root reviews only these private originals with an image-view tool.
        # This receipt is evidence of that review, never inferred from GET200.
        if not self.args.visual_receipt:
            raise SafeFailure('A private visual-inspection receipt is required')
        path = self.args.visual_receipt.resolve()
        if not path.is_relative_to((ROOT / 'artifacts/private').resolve()):
            raise SafeFailure('The visual receipt must remain private')
        receipt = json.loads(path.read_text())
        required = ['avatar-profile-saved.png', 'avatar-menu-saved.png',
                    'avatar-crop-default-before-cancel.png', 'avatar-crop-adjusted-before-cancel.png',
                    'avatar-crop-after-cancelled-reselect.png']
        if 'pending-repick-cancelled' in self.session['phases']:
            required.extend(['avatar-pending-before-repick.png', 'avatar-pending-after-repick-cancel.png'])
        files = receipt.get('screenshots', {})
        for filename in required:
            image = PRIVATE / filename
            recorded = next((r for r in self.ui.private_screenshots if Path(r['file']).name == filename), None)
            if not recorded or not image.exists() or files.get(filename) != sha(image) or recorded['sha256'] != sha(image):
                raise SafeFailure('Visual receipt must bind all original private screenshot bytes')
        self.check(receipt.get('renderedFixtureInProfileAndMenu') is True,
                   'Root visual inspection confirms the actual fixture renders in both profile and account menu; screenshot SHA bound', 'A3')
        self.check(receipt.get('adjustedPreviewChangedBySliders') is True and
                   receipt.get('cancelledReselectPreservedCrop') is True,
                   'Root visual inspection confirms visible crop adjustment and preserved crop after system reselect cancellation', 'A2')
        self.session['visualEvidence'] = {'receiptSha256': sha(path),
                                         'source': 'Root inspection of SHA-bound private originals'}
        self.save('visual-reviewed')

    def run(self):
        try:
            getattr(self, self.args.action.replace('-', '_'))()
            return 0
        except Exception as error:
            message = str(error) if isinstance(error, SafeFailure) else 'Avatar helper stopped before this stage completed'
            self.save(error=message)
            print(json.dumps({'status': 'incomplete', 'error': self.ui.redact(message)}, ensure_ascii=False))
            return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('action', choices=['begin', 'cancel-crop', 'reselect', 'pending-begin', 'pending-cancel', 'confirm', 'recovery', 'decode-corrupt', 'late-logout', 'visual'])
    parser.add_argument('--runtime-report', type=Path, default=OUT / 'runtime.json')
    parser.add_argument('--receipt', type=Path)
    parser.add_argument('--visual-receipt', type=Path)
    parser.add_argument('--new-attempt', action='store_true')
    args = parser.parse_args()
    try:
        return AvatarAcceptance(args).run()
    except Exception as error:
        text = str(error) if isinstance(error, SafeFailure) else 'Avatar setup stopped before acceptance completed'
        print(json.dumps({'status': 'incomplete', 'error': text}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

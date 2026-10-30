#!/usr/bin/env python3
"""Seed one real profile extension through the disposable backend's formal APIs.

Creates fresh temporary superuser/admin identities; never recovers existing
credentials. All credentials stay in process memory. The exact new record IDs
are saved privately. Final cleanup may destroy the entire owned disposable DB;
this helper does not delete or modify existing administrators, players or schema.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import secrets
import ssl
import subprocess
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'artifacts/private/https-isolation'
OUT = ROOT / 'artifacts/validation/profile'
REPORT = OUT / 'profile-extra-seed.json'
PREFIX = '/api/questions/v1'
LABEL = '原生资料验收标记'
TEXT = '专用隔离玩家 · 扩展资料已回源'
REASON = '隔离原生资料扩展验收'
MANAGEMENT_ROUTES = {
    '/api/collections/_superusers/auth-with-password': {'POST'},
    '/api/collections/game_admins/records': {'POST'},
    '/api/collections/game_admins/auth-with-password': {'POST'},
    PREFIX + '/admin/me': {'GET'},
    PREFIX + '/admin/extra-definitions': {'GET', 'POST'},
    PREFIX + '/admin/extra-configs/preview': {'POST'},
    PREFIX + '/admin/extra-configs/dispatch': {'POST'},
    PREFIX + '/admin/extra-configs/inspect': {'POST'},
}
PLAYER_ROUTES = {'/api/collections/game_players/auth-with-password': {'POST'}, PREFIX + '/me': {'GET'}}


class SafeStop(RuntimeError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def require(value, message):
    if not value:
        raise SafeStop(message)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def record_id(value):
    return isinstance(value, str) and re.fullmatch(r'[a-z0-9]{15}', value) is not None


def read_json(path):
    value = json.loads(path.read_text())
    require(isinstance(value, dict), 'An evidence file is not an object')
    return value


def evidence_path(relative):
    require(isinstance(relative, str), 'A prerequisite evidence path is missing')
    path = (ROOT / relative).resolve()
    require(path.is_relative_to(OUT.resolve()) and path.is_file(), 'Prerequisite evidence must remain in the profile validation directory')
    return path


def command(args, input_text=None):
    try:
        result = subprocess.run(args, cwd=ROOT, input=input_text, capture_output=True, text=True, timeout=30)
    except Exception:
        raise SafeStop('An owned Docker operation could not complete') from None
    require(result.returncode == 0, 'An owned Docker operation failed')
    # Command stdout/stderr can contain the fresh temporary email; never print,
    # persist or include these buffers in an exception or a report.
    return result.stdout


class Seed:
    def __init__(self, password_report):
        require(not REPORT.exists(), 'A prior seed report already exists; review its private receipt before a new experiment')
        self.state = read_json(PRIVATE / 'state.json')
        require(self.state.get('mode') == 'real isolated PocketBase' and self.state.get('version') == '0.40.1',
                'Only the owned disposable PocketBase version is supported')
        self.backend = self.state.get('backendBase', '')
        match = re.fullmatch(r'http://127\.0\.0\.1:([0-9]+)', self.backend)
        require(match is not None and 0 < int(match[1]) < 65536, 'Management origin must be the owned loopback backend')
        self.backend_port = match[1]
        require(record_id(self.state.get('playerId')), 'The dedicated target player ID is invalid')
        image = self.state.get('imageId', '')
        require(re.fullmatch(r'sha256:[a-f0-9]{64}', image) is not None, 'The disposable image fingerprint is missing')
        self.source = Path(self.state.get('sourceDirectory', '')).resolve()
        require(self.source.parent == PRIVATE.resolve() and
                re.fullmatch(r'questions-pb-test-[A-Za-z0-9_-]+', self.source.name) is not None and self.source.is_dir(),
                'The backend data mount must be this task own disposable source directory')
        self.password_report_path = password_report.resolve()
        require(self.password_report_path.is_relative_to(OUT.resolve()), 'The password evidence must remain in the profile validation directory')
        self.password_report = read_json(self.password_report_path)
        self.password_report_sha = sha(self.password_report_path)
        password = self.password_report
        require(password.get('status') == 'passed' and
                password.get('cleanup', {}).get('faultNeutralised') is True and
                password.get('cleanup', {}).get('loggedOut') is True and
                password.get('finalPasswordKey') in ('initialPassword', 'newPassword'),
                'A passed password experiment with completed cleanup is required')
        self.password_key = password['finalPasswordKey']
        require(isinstance(self.state.get(self.password_key), str) and self.state[self.password_key], 'The verified dedicated player password is unavailable')
        self.hap_path = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
        self.hap_sha = sha(self.hap_path)
        self.runtime_path = evidence_path(password.get('runtime', {}).get('file'))
        self.core_path = evidence_path(password.get('corePrerequisite', {}).get('file'))
        self.runtime_sha, self.core_sha = sha(self.runtime_path), sha(self.core_path)
        runtime, core = read_json(self.runtime_path), read_json(self.core_path)
        require(password.get('hap', {}).get('packagedSha256') == self.hap_sha and
                password.get('runtime', {}).get('sha256') == self.runtime_sha and
                password.get('corePrerequisite', {}).get('sha256') == self.core_sha and
                runtime.get('status') == 'passed' and runtime.get('installedHapSha256') == self.hap_sha and
                core.get('status') == 'passed' and core.get('hap', {}).get('packagedSha256') == self.hap_sha and
                core.get('runtime', {}).get('sha256') == self.runtime_sha,
                'The password, core and actual runtime evidence must match the same current HAP')
        config = read_json(ROOT / 'entry/src/main/resources/rawfile/integration.json')
        self.player_origin = self.state.get('tls', {}).get('hostBase', '')
        require(config.get('isolated') is True and config.get('endpoint') == self.state.get('tls', {}).get('base') and
                config.get('endpoint') == 'https://127.0.0.1:18443' and
                re.fullmatch(r'https://127\.0\.0\.1:[0-9]+', self.player_origin) is not None,
                'The existing strict player HTTPS origin must match the packaged isolated configuration')
        ca = Path(self.state.get('tls', {}).get('caPath', '')).resolve()
        require(ca.is_relative_to(PRIVATE.resolve()) and ca.is_file(), 'Only this task private TLS CA is supported')
        self.tls = ssl.create_default_context(cafile=str(ca))
        self.started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        self.receipt_path = PRIVATE / ('profile-extra-seed-receipt-' + stamp + '-' + secrets.token_hex(4) + '.json')
        self.source_sha = sha(Path(__file__))
        self.requests, self.checks = [], []
        self.recipient_verified = False
        self.definition_key = 'hm_profile_qa_' + secrets.token_hex(6)
        self.owner_hash = hashlib.sha256((str(self.source) + image + self.backend).encode()).hexdigest()
        self.receipt = {'status': 'prepared', 'ownedBackendFingerprint': self.owner_hash,
                        'targetPlayerId': self.state['playerId'], 'definitionKey': self.definition_key,
                        'fixtureLabel': LABEL, 'fixtureText': TEXT,
                        'superuserCreated': False, 'superuserId': None, 'adminId': None,
                        'definitionId': None, 'configId': None,
                        'cleanupStrategy': 'Destroy only the complete owned disposable backend; no credential is persisted'}

    def save_receipt(self):
        self.receipt_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        descriptor = os.open(self.receipt_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(descriptor, 'w') as output:
            json.dump(self.receipt, output, ensure_ascii=False, indent=2)
            output.write('\n')
        self.receipt_path.chmod(0o600)

    def report(self, status, error=None):
        OUT.mkdir(parents=True, exist_ok=True)
        result = {'status': status, 'scope': 'Formal management configuration and strict HTTPS player read; phone rendering is separate',
                  'environment': 'non-production owned disposable PocketBase', 'intendedRecipientCount': 1,
                  'verifiedRecipientCount': 1 if self.recipient_verified else None,
                  'startedAt': self.started_at, 'updatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  'driver': {'file': 'scripts/seed-isolated-profile-extra.py', 'sha256': self.source_sha},
                  'hapSha256': self.hap_sha,
                  'prerequisites': {'passwordReport': str(self.password_report_path.relative_to(ROOT)),
                                    'passwordReportSha256': self.password_report_sha,
                                    'runtimeSha256': self.runtime_sha, 'coreSha256': self.core_sha},
                  'fixture': {'label': LABEL, 'text': TEXT}, 'checks': self.checks, 'requests': self.requests,
                  'privateReceipt': {'file': str(self.receipt_path.relative_to(ROOT)), 'sha256': sha(self.receipt_path)}}
        if error:
            result['error'] = error
        REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')

    def check(self, condition, label):
        require(condition, label)
        self.checks.append(label)

    def api(self, path, method='GET', body=None, token=None, player=False):
        routes = PLAYER_ROUTES if player else MANAGEMENT_ROUTES
        require(path in routes and method in routes[path], 'Only the fixed formal seed and player-read routes are allowed')
        origin = self.player_origin if player else self.backend
        headers = {'Accept': 'application/json'}
        if token:
            headers['Authorization'] = token
        if body is not None:
            headers['Content-Type'] = 'application/json'
        request = urllib.request.Request(origin + path, method=method, headers=headers,
                                         data=json.dumps(body).encode() if body is not None else None)
        handlers = [urllib.request.ProxyHandler({}), NoRedirect()]
        if player:
            handlers.append(urllib.request.HTTPSHandler(context=self.tls))
        row = {'method': method, 'path': path, 'status': 0,
               'channel': 'player strict HTTPS' if player else 'management loopback'}
        self.requests.append(row)
        try:
            with urllib.request.build_opener(*handlers).open(request, timeout=20) as response:
                row['status'] = response.status
                require(response.status == 200, 'A formal API returned an unexpected status')
                data = response.read(1000001)
                require(len(data) <= 1000000, 'A formal API response exceeded its allowed size')
                value = json.loads(data)
                require(isinstance(value, dict), 'A formal API response was not an object')
                return value
        except urllib.error.HTTPError as error:
            row['status'] = error.code
            raise SafeStop('A formal API rejected this isolated experiment') from None
        except SafeStop:
            raise
        except Exception:
            raise SafeStop('A formal API could not complete; no command was automatically retried') from None

    def owned_container(self):
        ids = command(['docker', 'ps', '--filter', 'status=running', '--filter', 'ancestor=' + self.state['imageId'],
                       '--format', '{{.ID}}']).splitlines()
        matches = []
        # Deliberately request only ownership/network fields. Never inspect Env,
        # existing tokens, process environments or unrelated command arguments.
        template = '{"running":{{json .State.Running}},"image":{{json .Image}},"mounts":{{json .Mounts}},"ports":{{json .NetworkSettings.Ports}}}'
        for container in ids:
            require(re.fullmatch(r'[a-f0-9]{12,64}', container) is not None, 'Docker returned an invalid container reference')
            data = json.loads(command(['docker', 'inspect', '--format', template, container]))
            mounts = [m for m in data.get('mounts', []) if m.get('Type') == 'bind' and m.get('RW') is True and
                      isinstance(m.get('Source'), str) and Path(m['Source']).resolve() == self.source]
            published = [(key, entry) for key, entries in (data.get('ports') or {}).items() for entry in entries or []]
            if (data.get('running') is True and data.get('image') == self.state['imageId'] and len(mounts) == 1 and
                    len(published) == 1 and published[0][0] == '8090/tcp' and
                    published[0][1].get('HostIp') == '127.0.0.1' and published[0][1].get('HostPort') == self.backend_port):
                matches.append((container, mounts[0]['Destination']))
        require(len(matches) == 1, 'Exactly one running container must match this task data, image and loopback port')
        container, destination = matches[0]
        # Only after ownership is established inspect its public runtime flags.
        runtime = json.loads(command(['docker', 'inspect', '--format', '{"binary":{{json .Path}},"args":{{json .Args}}}', container]))
        args = runtime.get('args')
        require(runtime.get('binary') == '/pb/pocketbase' and isinstance(args, list) and args and args[0] == 'serve',
                'The owned container must run the expected PocketBase binary')
        flags = {}
        for value in args[1:]:
            require(isinstance(value, str) and value.startswith('--') and '=' in value, 'Unexpected owned runtime flags')
            key, item = value.split('=', 1)
            require(key not in flags, 'Duplicate owned runtime flags are not supported')
            flags[key] = item
        require(set(flags) == {'--http', '--dir', '--migrationsDir', '--hooksDir', '--automigrate'} and
                flags['--http'] == '0.0.0.0:8090' and flags['--automigrate'] == 'false',
                'The owned runtime flags differ from the frozen test harness')
        mount = PurePosixPath(destination)
        require(mount.is_absolute() and '..' not in mount.parts and
                PurePosixPath(flags['--dir']).parent == mount and
                PurePosixPath(flags['--dir']).name in ('pb_data', 'restored_pb_data') and
                flags['--hooksDir'] == str(mount / 'pb_hooks') and flags['--migrationsDir'] == str(mount / 'pb_migrations'),
                'PocketBase directories must be the exact owned test-data mount')
        cli_flags = [key + '=' + flags[key] for key in ('--dir', '--hooksDir', '--migrationsDir', '--automigrate')]
        version = command(['docker', 'exec', container, runtime['binary'], '--version'])
        require(re.search(r'\b0\.40\.1\b', version) is not None, 'The owned PocketBase binary has an unexpected version')
        self.check(True, 'One exact owned running container and its loopback-only frozen runtime were verified')
        return container, runtime['binary'], cli_flags

    def auth(self, collection, identity, password, expected_id=None, player=False):
        result = self.api('/api/collections/' + collection + '/auth-with-password', 'POST',
                          {'identity': identity, 'password': password}, player=player)
        record = result.get('record')
        require(isinstance(result.get('token'), str) and result['token'] and isinstance(record, dict) and
                record_id(record.get('id')) and record.get('collectionName') == collection and
                (expected_id is None or record['id'] == expected_id), 'Authentication returned an incompatible identity')
        return result['token'], record

    def execute(self):
        container, binary, cli_flags = self.owned_container()
        player_token, _ = self.auth('game_players', self.state['account'], self.state[self.password_key], self.state['playerId'], player=True)
        before = self.api(PREFIX + '/me', token=player_token, player=True)
        self.check(before.get('id') == self.state['playerId'] and before.get('mustChangePassword') is False,
                   'The final verified player password authenticates through strict HTTPS without a forced-change gate')

        super_email = 'hmqa_' + secrets.token_hex(12) + '@example.test'
        super_password = 'Qa-' + secrets.token_urlsafe(32)
        # Keep fresh credentials out of Docker ExecConfig.Cmd and exec-event
        # metadata. Only this fixed wrapper and verified runtime flags appear
        # there; credentials are two stdin lines consumed in process memory.
        bootstrap = ('IFS= read -r qa_email || exit 64\n'
                     'IFS= read -r qa_password || exit 64\n'
                     'qa_binary=$1\nshift\n'
                     'exec "$qa_binary" superuser create "$qa_email" "$qa_password" "$@"')
        command(['docker', 'exec', '-i', container, '/bin/sh', '-c', bootstrap,
                 'starward-extra-bootstrap', binary, *cli_flags], input_text=super_email + '\n' + super_password + '\n')
        self.receipt['superuserCreated'] = True
        self.save_receipt()
        super_token, super_record = self.auth('_superusers', super_email, super_password)
        require(super_record.get('email') == super_email, 'The new temporary superuser identity did not match')
        self.receipt['superuserId'] = super_record['id']
        self.save_receipt()
        admin_account = 'hmqa_' + secrets.token_hex(6)
        admin_password = 'Qa-' + secrets.token_urlsafe(32)
        admin = self.api('/api/collections/game_admins/records', 'POST',
                         {'account': admin_account, 'displayName': '原生扩展资料专用管理员', 'status': 'active',
                          'password': admin_password, 'passwordConfirm': admin_password}, token=super_token)
        require(record_id(admin.get('id')) and admin.get('collectionName') == 'game_admins' and
                admin.get('account') == admin_account and admin.get('status') == 'active',
                'The new dedicated administrator response was incompatible')
        self.receipt['adminId'] = admin['id']
        self.save_receipt()
        admin_token, _ = self.auth('game_admins', admin_account, admin_password, admin['id'])
        who = self.api(PREFIX + '/admin/me', token=admin_token)
        self.check(who.get('id') == admin['id'] and who.get('account') == admin_account,
                   'A fresh active game administrator authenticates through the formal management API')
        definitions = self.api(PREFIX + '/admin/extra-definitions', token=admin_token)
        require(isinstance(definitions.get('items'), list) and
                all(isinstance(item, dict) and isinstance(item.get('key'), str) for item in definitions['items']) and
                all(item['key'] != self.definition_key for item in definitions['items']), 'The new QA definition key must not overwrite any existing definition')
        schema = {'scopes': ['global'], 'contexts': ['profile'], 'visibility': 'player', 'renderer': 'text',
                  'fields': {'type': 'object', 'properties': {'text': {'type': 'string', 'required': True, 'maxLength': 200}}}}
        definition = self.api(PREFIX + '/admin/extra-definitions', 'POST',
                              {'requestId': str(uuid.uuid4()), 'key': self.definition_key, 'label': LABEL, 'status': 'active',
                               'expectedRevision': 0, 'reason': REASON, 'schema': schema}, token=admin_token)
        self.check(record_id(definition.get('id')) and definition.get('key') == self.definition_key and
                   definition.get('label') == LABEL and definition.get('status') == 'active' and
                   type(definition.get('revision')) is int and definition['revision'] == 1 and definition.get('schema') == schema,
                   'The formal definition API confirms the exact player-visible profile text schema')
        self.receipt.update({'definitionId': definition['id'], 'definitionRevision': definition['revision'], 'definitionSchema': schema})
        self.save_receipt()
        body = {'definitionId': definition['id'], 'scopeType': 'global', 'audience': 'selected',
                'playerIds': [self.state['playerId']], 'action': 'value', 'extra': {'text': TEXT}, 'reason': REASON}
        preview = self.api(PREFIX + '/admin/extra-configs/preview', 'POST', body, token=admin_token)
        items = preview.get('items')
        self.check(isinstance(preview.get('version'), str) and re.fullmatch(r'[a-f0-9]{64}', preview['version']) is not None and
                   preview.get('recipientIds') == [self.state['playerId']] and preview.get('skippedIds') == [] and
                   preview.get('normalizedExtra') == {'text': TEXT} and isinstance(items, list) and len(items) == 1 and
                   isinstance(items[0], dict) and items[0].get('playerId') == self.state['playerId'] and items[0].get('before') is None,
                   'The authoritative preview targets exactly the one dedicated player with no prior binding')
        request_id = str(uuid.uuid4())
        result = self.api(PREFIX + '/admin/extra-configs/dispatch', 'POST',
                          {**body, 'requestId': request_id, 'expectedVersion': preview['version']}, token=admin_token)
        rows = result.get('results')
        self.check(result.get('requestId') == request_id and result.get('recipientIds') == [self.state['playerId']] and
                   result.get('skippedIds') == [] and isinstance(rows, list) and len(rows) == 1 and
                   isinstance(rows[0], dict) and record_id(rows[0].get('id')) and rows[0].get('playerId') == self.state['playerId'] and
                   rows[0].get('status') == 'active' and type(rows[0].get('revision')) is int and rows[0]['revision'] == 1,
                   'One formal dispatch confirms exactly one new active binding using the preview version')
        self.recipient_verified = True
        self.receipt.update({'configId': rows[0]['id'], 'configRevision': rows[0]['revision'], 'dispatchRequestId': request_id})
        self.save_receipt()
        expected = {'key': self.definition_key, 'label': LABEL, 'text': TEXT}
        inspected = self.api(PREFIX + '/admin/extra-configs/inspect', 'POST',
                             {'playerId': self.state['playerId'], 'context': 'profile'}, token=admin_token)
        self.check(isinstance(inspected.get('extraDisplay'), list) and expected in inspected['extraDisplay'],
                   'The formal management resolver confirms the exact profile display tuple')
        player_token, _ = self.auth('game_players', self.state['account'], self.state[self.password_key], self.state['playerId'], player=True)
        after = self.api(PREFIX + '/me', token=player_token, player=True)
        self.check(isinstance(after.get('extraDisplay'), list) and expected in after['extraDisplay'] and
                   isinstance(after.get('extra'), dict) and after['extra'].get(self.definition_key) == {'text': TEXT},
                   'A fresh real player strict-HTTPS me response contains the exact server-resolved nonempty extension')
        facts = ('id', 'account', 'displayName', 'avatar', 'mustChangePassword', 'totalXp', 'level', 'nextLevel')
        self.check(all(before.get(field) == after.get(field) for field in facts),
                   'Adding the extension changes no player identity, password gate, avatar, rank or experience facts')

    def run(self):
        failure = None
        self.save_receipt()
        self.report('running')
        try:
            self.execute()
            require(sha(self.hap_path) == self.hap_sha and sha(self.password_report_path) == self.password_report_sha and
                    sha(self.runtime_path) == self.runtime_sha and sha(self.core_path) == self.core_sha and
                    sha(Path(__file__)) == self.source_sha, 'Prerequisite evidence changed during this isolated experiment')
        except Exception as error:
            failure = str(error) if isinstance(error, SafeStop) else 'The isolated extra seed stopped before verification completed'
        self.receipt['status'] = 'incomplete' if failure else 'seeded_and_verified'
        self.save_receipt()
        self.report('incomplete' if failure else 'passed', failure)
        print(json.dumps({'status': 'incomplete' if failure else 'passed', 'scope': 'formal extra seed and host HTTPS read only',
                          'report': str(REPORT.relative_to(ROOT)), 'verifiedRecipientCount': 1 if self.recipient_verified else None,
                          'checks': len(self.checks)}, ensure_ascii=False))
        return 1 if failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--password-report', type=Path, default=OUT / 'device-profile-password-uncertain.json')
    args = parser.parse_args()
    try:
        return Seed(args.password_report).run()
    except Exception as error:
        message = str(error) if isinstance(error, SafeStop) else 'The isolated extra seed setup could not be verified'
        print(json.dumps({'status': 'incomplete', 'scope': 'extra seed setup', 'error': message}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

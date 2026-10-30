#!/usr/bin/env python3
"""Gracefully restart only the verified own temporary TLS runner with its response gate.

PRECONDITIONS: root has installed the isolated15000ms/font1 HAP variant, captured
its actual six-check runtime, completed its base phone scopes, and left empty
native login. This helper does not inspect or manipulate native UI. It verifies
the frozen base/archive/source/ABC/CA relationship before touching TLS.

The existing runner's official stop intentionally deletes its ephemeral CA/key
directory and raw CA. This helper first preserves those exact own bytes in a
private backup, waits for complete graceful cleanup, restores only those bytes
and the old TLS metadata into otherwise unchanged backend state, then invokes
the existing resume script with the explicit gate environment. It never creates
a CA, resets PocketBase, kills an unrelated process or removes another mapping.

Failure retains the private backup for root recovery. No automatic rollback,
SIGKILL, device identifier output, gate arm, or late-response/UI pass exists.
Do not run two transition helpers concurrently. Root deletes the exact reported
private backup only after the overall isolated-environment cleanup is complete.
"""
import argparse
import copy
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import signal
import stat
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import uuid
import zipfile

from hap_timeout_variant import VariantMismatch, validate_timeout_entries

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'artifacts/private/https-isolation'
STATE = PRIVATE / 'state.json'
TLS = PRIVATE / 'tls'
RAW_CA = ROOT / 'entry/src/main/resources/rawfile/integration-ca.pem'
CONFIG = RAW_CA.with_name('integration.json')
HAP = ROOT / 'entry/build/default/outputs/default/entry-default-signed.hap'
SCRIPT = ROOT / 'scripts/isolated-tls.mjs'
GATE_MODULE = ROOT / 'scripts/isolated-response-gate.mjs'
PROVENANCE_HELPER = ROOT / 'scripts/hap_timeout_variant.py'
BACKEND_SCRIPT = ROOT / 'scripts/isolated-backend.mjs'
OUT = ROOT / 'artifacts/validation/profile'
REPORT = OUT / 'isolated-tls-gate-transition.json'
LOCK = PRIVATE / 'tls-gate-transition.lock'
NODE = Path('/Applications/DevEco-Studio.app/Contents/tools/node/bin/node')
HDC = Path('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc')
PS, LSOF = '/bin/ps', '/usr/sbin/lsof'
DEVICE_PORT = 18443
CONFIG_ENTRY = 'resources/rawfile/integration.json'
CA_ENTRY = 'resources/rawfile/integration-ca.pem'
REASON = 'controlled graceful stop/resume for explicit response-gate activation'
TLS_FILES = {'ca.key', 'ca.pem', 'server.key', 'server.csr', 'server.pem', 'server.ext', 'ca.srl'}
REQUIRED_TLS_FILES = TLS_FILES - {'ca.srl'}
RUNTIME_CHECKS = {'actualWindowReported', 'actualImmersiveWindow', 'transparentSystemBars',
                  'requestedFontScaleReported', 'threeIndependentTlsCases', 'actualLightAndDarkBarContent'}


class SafeFailure(Exception):
    pass


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sha(filename):
    return digest(Path(filename).read_bytes())


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def no_links(filename, boundary=ROOT):
    original = Path(filename).absolute()
    if not original.resolve().is_relative_to(boundary.resolve()):
        raise SafeFailure('An input resolved outside its permitted project directory')
    for item in (original, *original.parents):
        if item.is_symlink():
            raise SafeFailure('Symlinks are not permitted in transition source or evidence paths')
        if item == boundary.absolute():
            break
    return original


def regular(value, boundary=ROOT, private=False):
    filename = no_links(value, boundary)
    info = filename.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
        raise SafeFailure('Transition inputs must be regular files owned by this user')
    if private and stat.S_IMODE(info.st_mode) & 0o077:
        raise SafeFailure('Private transition input permissions must exclude group and others')
    return filename


def read_json(filename):
    value = json.loads(Path(filename).read_text())
    if not isinstance(value, dict):
        raise SafeFailure('A transition JSON input is not an object')
    return value


def write_new(filename, data, mode=0o600):
    no_links(filename)
    descriptor = os.open(filename, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode)
    with os.fdopen(descriptor, 'wb') as output:
        output.write(data)
        output.flush()
        os.fsync(output.fileno())
    filename.chmod(mode)


def loopback_port(value, scheme):
    parsed = urllib.parse.urlsplit(value)
    if (parsed.scheme != scheme or parsed.hostname != '127.0.0.1' or not parsed.port or
            not 1024 <= parsed.port <= 65535 or parsed.username or parsed.password or
            parsed.path not in ('', '/') or parsed.query or parsed.fragment):
        raise SafeFailure('The dedicated environment endpoint is not an exact loopback origin')
    return parsed.port


def command(arguments, allow_missing=False, timeout=15, payload=None):
    try:
        child = subprocess.Popen([str(value) for value in arguments], cwd=ROOT,
            stdin=subprocess.PIPE if payload is not None else subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            env={**os.environ, 'LC_ALL': 'C', 'STARWARD_VALIDATION_DIR': 'artifacts/validation/profile',
                 'PATH': str(NODE.parent) + ':' + str(HDC.parent) + ':/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin'})
        try:
            stdout, stderr = child.communicate(input=payload, timeout=timeout)
        except subprocess.TimeoutExpired:
            if child.poll() is None:
                child.terminate()  # Only this created one-shot child, never SIGKILL.
            try:
                child.communicate(timeout=3)
            except subprocess.TimeoutExpired:
                raise SafeFailure('An own inspection/launcher child did not exit after SIGTERM; no force-kill was attempted') from None
            raise SafeFailure('A bounded ownership or official-runner command timed out; no force-kill was attempted') from None
    except SafeFailure:
        raise
    except Exception:
        raise SafeFailure('A bounded ownership or official-runner command did not complete') from None
    if child.returncode and not (allow_missing and child.returncode == 1 and not stdout.strip() and not stderr.strip()):
        raise SafeFailure('An ownership or official-runner command rejected the operation; raw output omitted')
    return stdout


def process_record(pid):
    if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 1:
        raise SafeFailure('The recorded runner PID is invalid')
    output = command([PS, '-p', pid, '-o', 'uid=', '-o', 'stat=', '-o', 'lstart=', '-o', 'command='], True)
    if not output.strip():
        return None
    fields = output.strip().split(None, 7)
    if len(fields) != 8 or not fields[0].isdigit():
        raise SafeFailure('Process ownership output could not be interpreted exactly')
    return {'uid': int(fields[0]), 'status': fields[1], 'birth': ' '.join(fields[2:7]), 'argv': fields[7]}


def owner_process(pid, script, operations, birth=None):
    record = process_record(pid)
    if not record or record['uid'] != os.getuid() or record['status'].startswith('Z'):
        raise SafeFailure('The expected own runner is not live under this user')
    try:
        argv = shlex.split(record['argv'])
    except ValueError:
        raise SafeFailure('The runner argv is ambiguous') from None
    if (len(argv) != 3 or Path(argv[0]).name != 'node' or
            (ROOT / argv[1]).absolute() != script or argv[2] not in operations or
            birth is not None and record['birth'] != birth):
        raise SafeFailure('The live PID is not the exact expected Node script invocation')
    cwd = command([LSOF, '-a', '-p', pid, '-d', 'cwd', '-Fn'])
    if [line[1:] for line in cwd.splitlines() if line.startswith('n')] != [str(ROOT)]:
        raise SafeFailure('The runner working directory does not match this project')
    return record


def listeners(port):
    output = command([LSOF, '-nP', '-iTCP:' + str(port), '-sTCP:LISTEN', '-Fpn'], True)
    result, pid = [], None
    for line in output.splitlines():
        if line.startswith('p') and line[1:].isdigit():
            pid = int(line[1:])
        elif line.startswith('n'):
            if pid is None:
                raise SafeFailure('Listener ownership output was ambiguous')
            result.append((pid, line[1:]))
    return result


def own_listener(pid, port):
    if set(listeners(port)) != {(pid, '127.0.0.1:' + str(port))}:
        raise SafeFailure('A loopback listener is not exclusively owned by the recorded runner')


def forwards(device, host_port, required):
    # Device identifiers and unrelated mapping text remain in memory only.
    targets = command([HDC, 'list', 'targets'])
    values = [line.strip() for line in targets.splitlines() if line.strip() and line.strip() != '[Empty]']
    if len(values) != 1 or any(char.isspace() for char in values[0]) or values[0].startswith('['):
        raise SafeFailure('Exactly one unambiguous connected device is required')
    if device is not None and values[0] != device:
        raise SafeFailure('The sole connected device changed during the controlled transition')
    device = values[0]
    rows = [line.strip() for line in command([HDC, 'fport', 'ls']).splitlines() if line.strip()]
    if rows == ['[Empty]']:
        rows = []
    matches = [line for line in rows if 'tcp:' + str(DEVICE_PORT) in line.split()]
    expected = [device, 'tcp:' + str(DEVICE_PORT), 'tcp:' + str(host_port), '[Reverse]']
    if (required and (len(matches) != 1 or matches[0].split() != expected)) or (not required and matches):
        raise SafeFailure('The dedicated reverse mapping is missing, foreign or ambiguous')
    return device, sorted(line for line in rows if line not in matches)


def hap_entries(filename):
    with zipfile.ZipFile(filename) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or any(value.file_size > 30 * 1024 * 1024 for value in archive.infolist()):
            raise SafeFailure('The signed HAP entry structure is invalid')
        return {name: archive.read(name) for name in names if not name.endswith('/')}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Transition:
    def __init__(self, args):
        self.args, self.started = args, now()
        self.stage, self.backup, self.log_path = 'preflight', None, None
        self.checks, self.frozen = {}, {}
        self.old_stopped, self.new_started, self.child = False, False, None
        self.lock_identity = None

    def report(self, status, error=None):
        value = {'status': status, 'scope': 'Controlled own temporary TLS restart and response-gate readiness only',
            'startedAt': self.started, 'updatedAt': now(), 'stage': self.stage, 'checks': self.checks,
            'lateResponseOrNativeUiAccepted': False, 'nativeUiInspected': False,
            'backendReset': False, 'databaseOrPlayerWrite': False, 'newCaCreated': False,
            'gateArmedByHelper': False, 'oldOwnRunnerStopped': self.old_stopped,
            'newOwnRunnerStarted': self.new_started,
            'privateBackup': str(self.backup.relative_to(ROOT)) if self.backup else None,
            'backupCleanup': 'Root removes only this exact private backup after final environment cleanup',
            'failureRecovery': 'Retain original materials and private manifest; inspect the recorded stage before any manual recovery'}
        if hasattr(self, 'provenance'):
            value['provenance'] = self.provenance
        if error:
            value['error'] = error
        OUT.mkdir(parents=True, exist_ok=True)
        no_links(REPORT)
        temporary = OUT / ('.tls-gate-report-' + uuid.uuid4().hex + '.json')
        write_new(temporary, json.dumps(value, ensure_ascii=False, indent=2).encode() + b'\n', 0o644)
        os.replace(temporary, REPORT)
        print(json.dumps({'status': status, 'stage': self.stage,
            'report': str(REPORT.relative_to(ROOT)), 'lateResponseOrNativeUiAccepted': False}, ensure_ascii=False), flush=True)

    def state(self):
        regular(STATE, PRIVATE, True)
        # The existing Node persist() uses writeFile; a very short truncate/write
        # interval is not evidence of another backend epoch. No mutation follows
        # until one complete object is observed and its identity is rechecked.
        for attempt in range(5):
            try:
                return read_json(STATE)
            except json.JSONDecodeError:
                if attempt == 4:
                    raise SafeFailure('Backend state did not settle to a complete JSON object') from None
                time.sleep(.02)

    @staticmethod
    def without_tls(value):
        return {key: item for key, item in value.items() if key != 'tls'}

    def backend(self, state):
        if self.without_tls(state) != self.other_state:
            raise SafeFailure('Non-TLS backend/account/control state changed; no overwrite is permitted')
        owner_process(state['pid'], BACKEND_SCRIPT, {'start'}, self.backend_birth)
        own_listener(state['pid'], self.proxy_port)
        own_listener(state['pid'], self.control_port)

    def stable_files(self, include_materials=True):
        for filename, value in self.frozen.items():
            if not include_materials and (filename.parent == TLS or filename == RAW_CA):
                continue
            regular(filename, ROOT)
            if sha(filename) != value:
                raise SafeFailure('A frozen HAP, source, certificate, helper or evidence file changed')
        actual = {str(item.relative_to(ROOT)) for item in (ROOT / 'entry/src/main/ets').rglob('*')
                  if item.is_file() and item.suffix in ('.ets', '.ts')}
        if actual != set(self.source_files):
            raise SafeFailure('The frozen ArkTS source-file set changed')

    def certificates(self):
        # Read certificates/keys inside fixed Studio Node. Only public digests are
        # returned; raw tool diagnostics and private-key bytes are never printed.
        program = '''const fs=require('node:fs'),c=require('node:crypto');
const p=JSON.parse(fs.readFileSync(0,'utf8'));try {
 const ca=new c.X509Certificate(fs.readFileSync(p.ca)),cert=new c.X509Certificate(fs.readFileSync(p.cert));
 const key=c.createPublicKey(fs.readFileSync(p.key)),caKey=c.createPublicKey(fs.readFileSync(p.caKey));
 const der=x=>x.export({type:'spki',format:'der'}),now=Date.now();
 if(cert.subjectAltName!=='IP Address:127.0.0.1'||!cert.verify(ca.publicKey)||!ca.ca||!ca.verify(ca.publicKey)||
 !der(cert.publicKey).equals(der(key))||!der(ca.publicKey).equals(der(caKey))||
 [ca,cert].some(x=>Date.parse(x.validFrom)>now||Date.parse(x.validTo)<=now+300000))throw Error();
 console.log(JSON.stringify({caSha256:c.createHash('sha256').update(fs.readFileSync(p.ca)).digest('hex'),fingerprint:cert.fingerprint256}));
}catch{process.exit(2);}'''
        result = json.loads(command([NODE, '-e', program], payload=json.dumps({
            'ca': str(TLS / 'ca.pem'), 'cert': str(TLS / 'server.pem'),
            'key': str(TLS / 'server.key'), 'caKey': str(TLS / 'ca.key')})))
        if result != {'caSha256': self.old_tls['caSha256'], 'fingerprint': self.old_tls['fingerprint']}:
            raise SafeFailure('The CA/SAN/public-key identity does not match recorded own TLS metadata')

    def provenance_check(self):
        manifest_path = regular(self.args.base_hap_manifest, OUT)
        runtime_path = regular(self.args.runtime_report, OUT)
        base, runtime = read_json(manifest_path), read_json(runtime_path)
        base_sha = base.get('hapSha256', '')
        if not re.fullmatch(r'[a-f0-9]{64}', base_sha):
            raise SafeFailure('The explicit base-HAP manifest has no valid SHA')
        archive = regular(ROOT / base['privateArchive'], ROOT / 'artifacts/private', True)
        regular(HAP, ROOT)
        current_sha = sha(HAP)
        if sha(archive) != base_sha or current_sha == base_sha:
            raise SafeFailure('A distinct timeout variant and its exact private base archive are required')
        checks = runtime.get('checks')
        if (runtime.get('status') != 'passed' or runtime.get('installedHapSha256') != current_sha or
                not isinstance(checks, dict) or set(checks) != RUNTIME_CHECKS or any(value is not True for value in checks.values()) or
                runtime.get('window', {}).get('fontScale') != 1 or any(runtime.get('tls', {}).get(key) is not True
                    for key in ('customCaAccepted', 'untrustedCaRejected', 'wrongHostnameRejected'))):
            raise SafeFailure('The current installed variant requires its actual six-check font1 strict-TLS runtime')
        entries, variant = hap_entries(archive), hap_entries(HAP)
        try:
            entry_comparison = validate_timeout_entries(entries, variant)
        except VariantMismatch as error:
            raise SafeFailure(str(error)) from None
        original, changed = json.loads(entries[CONFIG_ENTRY]), json.loads(variant[CONFIG_ENTRY])
        desired = {**original, 'timeoutMs': 15000}
        if (original != base.get('configuration') or original.get('timeoutMs') != 2000 or changed != desired or
                changed.get('isolated') is not True or changed.get('fontScale') != 1 or
                changed.get('endpoint') != self.old_tls['base'] or regular(CONFIG).read_bytes() != variant[CONFIG_ENTRY] or
                not entries.get(CA_ENTRY) or entries[CA_ENTRY] != regular(RAW_CA).read_bytes() or
                digest(entries[CA_ENTRY]) != self.old_tls['caSha256']):
            raise SafeFailure('Base/variant/local config and original CA must bind only the isolated15000ms/font1 change')
        abc = {name: digest(value) for name, value in entries.items() if name.endswith('.abc')}
        recorded = base.get('arktsBytecode', [])
        if not abc or len(recorded) != len(abc) or abc != {row.get('file'): row.get('sha256') for row in recorded}:
            raise SafeFailure('The archived base ABC bytes do not match their manifest')
        rows, expected = base.get('sourceFiles', []), {}
        if not isinstance(rows, list) or not rows:
            raise SafeFailure('The frozen ArkTS source manifest is missing')
        for row in rows:
            name, value = row.get('file', ''), row.get('sha256', '')
            if (not re.fullmatch(r'entry/src/main/ets/[A-Za-z0-9_./-]+\.(ets|ts)', name) or '..' in Path(name).parts or
                    name in expected or not re.fullmatch(r'[a-f0-9]{64}', value)):
                raise SafeFailure('A frozen ArkTS source manifest entry is invalid')
            source = regular(ROOT / name, ROOT / 'entry/src/main/ets')
            if sha(source) != value:
                raise SafeFailure('The current ArkTS source differs from the frozen base')
            expected[name] = value
            self.frozen[source] = value
        self.source_files = expected
        for filename in (HAP, archive, manifest_path, runtime_path, CONFIG, RAW_CA, SCRIPT, GATE_MODULE,
                         PROVENANCE_HELPER, Path(__file__).resolve()):
            regular(filename, ROOT)
            self.frozen[filename] = sha(filename)
        self.provenance = {'basePackagedSha256': base_sha, 'variantPackagedSha256': current_sha,
            'runtime': {'file': str(runtime_path.relative_to(ROOT)), 'sha256': sha(runtime_path)},
            'baseManifest': {'file': str(manifest_path.relative_to(ROOT)), 'sha256': sha(manifest_path)},
            'onlyTimeoutConfigurationChanged': True, 'baseTimeoutMs': 2000, 'variantTimeoutMs': 15000,
            'abcBytesIdentical': True, 'sourceFileCount': len(expected), 'caSha256': self.old_tls['caSha256'],
            'packagedEntryComparison': entry_comparison,
            'provenanceHelperSha256': sha(PROVENANCE_HELPER)}
        self.checks['frozenVariantRuntimeAndSources'] = True

    def preflight(self):
        if sys.platform != 'darwin' or not NODE.is_file() or not HDC.is_file():
            raise SafeFailure('This controlled transition requires the fixed local Studio Node/HDC toolchain on macOS')
        initial = self.state()
        self.other_state = copy.deepcopy(self.without_tls(initial))
        self.old_tls = copy.deepcopy(initial.get('tls', {}))
        if (initial.get('mode') != 'real isolated PocketBase' or not re.fullmatch(r'hm_[a-f0-9]+', initial.get('account', '')) or
                not re.fullmatch(r'[a-z0-9]{15}', initial.get('playerId', '')) or self.old_tls.get('responseGate') or
                self.old_tls.get('base') != 'https://127.0.0.1:' + str(DEVICE_PORT) or
                self.old_tls.get('devicePort') != DEVICE_PORT or self.old_tls.get('caPath') != str(TLS / 'ca.pem') or
                self.old_tls.get('rawCaPath') != str(RAW_CA)):
            raise SafeFailure('Only the original own non-gate disposable TLS runner at the exact project paths can be transitioned')
        self.host_port = loopback_port(self.old_tls.get('hostBase', ''), 'https')
        if self.old_tls.get('hostPort') != self.host_port:
            raise SafeFailure('TLS host endpoint and recorded port differ')
        self.proxy_port = loopback_port(initial.get('proxyBase', ''), 'http')
        self.control_port = loopback_port(initial.get('controlBase', ''), 'http')
        if len({self.host_port, self.proxy_port, self.control_port}) != 3:
            raise SafeFailure('TLS and dedicated backend/control listener ports must be distinct')
        self.backend_birth = owner_process(initial['pid'], BACKEND_SCRIPT, {'start'})['birth']
        self.backend(initial)
        self.old_birth = owner_process(self.old_tls.get('pid'), SCRIPT, {'start', 'resume'})['birth']
        own_listener(self.old_tls['pid'], self.host_port)
        self.device, self.other_forwards = forwards(None, self.host_port, True)
        info = no_links(TLS, PRIVATE).stat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
            raise SafeFailure('The temporary TLS directory is not private and owned')
        names = {item.name for item in TLS.iterdir()}
        if not REQUIRED_TLS_FILES.issubset(names) or not names.issubset(TLS_FILES):
            raise SafeFailure('The TLS directory contains missing or unexpected materials; no file will be removed by this helper')
        self.materials = {}
        for name in sorted(names):
            source = regular(TLS / name, TLS, name.endswith('.key'))
            mode = stat.S_IMODE(source.stat().st_mode)
            if mode & 0o133:
                raise SafeFailure('TLS materials must not be executable or writable by group/others')
            self.materials[name] = {'data': source.read_bytes(), 'mode': mode}
            self.frozen[source] = digest(self.materials[name]['data'])
        regular(RAW_CA)
        if RAW_CA.read_bytes() != self.materials['ca.pem']['data']:
            raise SafeFailure('The packaged public CA differs from the own TLS CA')
        self.raw_mode = stat.S_IMODE(RAW_CA.stat().st_mode)
        if self.raw_mode & 0o133:
            raise SafeFailure('The public CA resource must not be executable or writable by group/others')
        self.certificates()
        self.provenance_check()
        self.stable_files()
        self.checks.update({'ownTlsAndBackendProcesses': True, 'ownLoopbackListeners': True,
            'soleDeviceAndExactOwnReverseMapping': True, 'caSanKeysAndPackagedAuthority': True})

    def backup_materials(self):
        self.stage = 'backing_up_original_tls'
        self.backup = PRIVATE / ('gate-transition-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
        no_links(self.backup, PRIVATE).mkdir(mode=0o700)
        rows = []
        for name, item in self.materials.items():
            target = self.backup / name
            write_new(target, item['data'])
            if sha(target) != digest(item['data']):
                raise SafeFailure('A private TLS backup did not preserve its original bytes')
            rows.append({'name': name, 'bytes': len(item['data']), 'sha256': sha(target), 'originalMode': item['mode']})
        write_new(self.backup / 'raw-ca.pem', self.materials['ca.pem']['data'])
        self.backup_manifest = {'scope': 'Exact own temporary TLS materials only; not a database or credential backup',
            'createdAt': now(), 'oldTls': self.old_tls, 'backendIdentitySha256': digest(canonical(self.other_state)),
            'rawCa': {'sha256': sha(self.backup / 'raw-ca.pem'), 'originalMode': self.raw_mode}, 'files': rows,
            'helperSha256': sha(Path(__file__).resolve()), 'tlsScriptSha256': sha(SCRIPT)}
        write_new(self.backup / 'manifest.json', canonical(self.backup_manifest) + b'\n')
        self.checks['privateOriginalMaterialBackupVerified'] = True
        self.report('running')

    def stop_original(self):
        self.stage = 'stopping_verified_own_tls'
        self.stable_files()
        latest = self.state()
        self.backend(latest)
        if latest.get('tls') != self.old_tls:
            raise SafeFailure('Own TLS metadata changed before the official graceful stop')
        owner_process(self.old_tls['pid'], SCRIPT, {'start', 'resume'}, self.old_birth)
        own_listener(self.old_tls['pid'], self.host_port)
        device, other = forwards(self.device, self.host_port, True)
        if other != self.other_forwards:
            raise SafeFailure('Another reverse mapping changed; no runner was stopped')
        if self.state() != latest:
            raise SafeFailure('Runner state changed immediately before the official stop; no signal was requested')
        command([NODE, SCRIPT, 'stop'])
        deadline = time.monotonic() + 25
        while time.monotonic() < deadline:
            record = process_record(self.old_tls['pid'])
            if record and record['birth'] != self.old_birth:
                raise SafeFailure('The former TLS PID was reused; no further transition action is safe')
            # Existing MJS resume checks process.kill(oldPid, 0). A zombie still
            # satisfies that check, so wait for actual PID removal/reaping.
            exited = record is None
            latest = self.state()
            self.backend(latest)
            if exited and not listeners(self.host_port) and 'tls' not in latest and not TLS.exists() and not RAW_CA.exists():
                _, other = forwards(self.device, self.host_port, False)
                if other != self.other_forwards:
                    raise SafeFailure('Unrelated device mappings changed during own TLS shutdown')
                self.old_stopped = True
                self.checks['gracefulStopPidPortStateAndMaterialsCleared'] = True
                return
            time.sleep(.15)
        raise SafeFailure('The verified own TLS runner did not complete all graceful-stop cleanup; backup retained')

    def restore_original(self):
        self.stage = 'restoring_exact_original_materials'
        self.stable_files(False)
        state_raw = regular(STATE, PRIVATE, True).read_bytes()
        latest = json.loads(state_raw)
        self.backend(latest)
        if 'tls' in latest or TLS.exists() or RAW_CA.exists() or listeners(self.host_port):
            raise SafeFailure('The restoration destination is no longer exclusively empty')
        no_links(TLS, PRIVATE).mkdir(mode=0o700)
        for row in self.backup_manifest['files']:
            source = regular(self.backup / row['name'], self.backup, True)
            data = source.read_bytes()
            if digest(data) != row['sha256']:
                raise SafeFailure('A preserved TLS backup changed before restoration')
            write_new(TLS / row['name'], data, 0o600 if row['name'].endswith('.key') else row['originalMode'])
        source = regular(self.backup / 'raw-ca.pem', self.backup, True)
        if sha(source) != self.backup_manifest['rawCa']['sha256']:
            raise SafeFailure('The preserved raw authority changed before restoration')
        write_new(RAW_CA, source.read_bytes(), self.raw_mode)
        self.stable_files()
        self.certificates()
        state_raw = regular(STATE, PRIVATE, True).read_bytes()
        latest = json.loads(state_raw)
        self.backend(latest)
        if 'tls' in latest:
            raise SafeFailure('TLS state reappeared before restoration; no state was overwritten')
        original_state_sha = digest(state_raw)
        latest['tls'] = copy.deepcopy(self.old_tls)
        temporary = PRIVATE / ('.tls-restore-' + uuid.uuid4().hex + '.json')
        write_new(temporary, canonical(latest) + b'\n')
        if sha(STATE) != original_state_sha:
            raise SafeFailure('Backend state changed during metadata restoration; temporary recovery file retained')
        os.replace(temporary, STATE)
        self.backend(self.state())
        self.checks['originalBytesAndOnlyTlsMetadataRestored'] = True

    def gate_ready(self, latest):
        tls = latest.get('tls', {})
        for key in ('base', 'hostBase', 'hostPort', 'devicePort', 'caPath', 'rawCaPath', 'caSha256', 'fingerprint'):
            if tls.get(key) != self.old_tls.get(key):
                raise SafeFailure('The resumed TLS runner changed its original identity or endpoint')
        owner_process(self.child.pid, SCRIPT, {'resume'})
        own_listener(self.child.pid, self.host_port)
        _, other = forwards(self.device, self.host_port, True)
        if other != self.other_forwards:
            raise SafeFailure('Unrelated mappings changed during TLS resume')
        receipt = regular(tls.get('responseGate', {}).get('receiptPath', ''), TLS, True)
        if not re.fullmatch(r'response-gate-' + str(self.child.pid) + r'-[a-f0-9]{32}\.json', receipt.name):
            raise SafeFailure('The gate receipt filename does not belong to the new own TLS runner')
        value = read_json(receipt)
        owner = digest((latest['account'] + latest['playerId'] + latest['controlBase']).encode())
        manifest = value.get('manifest', {})
        if (value.get('pid') != self.child.pid or value.get('ownerSha256') != owner or
                not re.fullmatch(r'[a-f0-9]{32}', value.get('instanceId', '')) or
                not isinstance(value.get('controlToken'), str) or len(value['controlToken']) < 32 or
                any(manifest.get(key) != item for key, item in {'version': 1, 'enabled': True, 'maxBytes': 2 * 1024 * 1024,
                    'maxTtlMs': 14000, 'singleUsePerArm': True, 'bufferedInMemoryOnly': True,
                    'verifiesOriginalBodySha256': True}.items())):
            raise SafeFailure('The private gate receipt does not bind this exact new own runner/account')
        port = loopback_port(value.get('controlBase', ''), 'http')
        own_listener(self.child.pid, port)
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        request = urllib.request.Request(value['controlBase'].rstrip('/') + '/status', data=b'{}', method='POST',
            headers={'Authorization': value['controlToken'], 'Content-Type': 'application/json'})
        try:
            with opener.open(request, timeout=3) as response:
                raw = response.read(65537)
                result = json.loads(raw) if response.status == 200 and len(raw) <= 65536 else None
        except Exception:
            raise SafeFailure('The new private gate did not acknowledge authenticated read-only readiness') from None
        if not isinstance(result, dict) or result.get('manifest') != manifest or result.get('current') is not None or result.get('history') != []:
            raise SafeFailure('The new response gate is not fresh and unarmed')
        evidence = read_json(regular(OUT / 'isolated-tls-resume.json', OUT))
        if (evidence.get('status') != 'passed' or evidence.get('checks') != 3 or evidence.get('operation') != 'resume' or
                evidence.get('causeOfPriorTermination') != REASON or evidence.get('responseGate') != manifest or
                evidence.get('caSha256') != self.old_tls['caSha256'] or evidence.get('certificateReused') is not True or
                evidence.get('tlsVerificationDisabled') is not False or evidence.get('backendReset') is not False):
            raise SafeFailure('The existing TLS runner has not recorded its actual three strict-TLS resume checks')

    def start_gate(self):
        self.stage = 'starting_official_resume_with_gate'
        self.stable_files()
        self.backend(self.state())
        self.log_path = self.backup / 'official-resume.log'
        descriptor = os.open(self.log_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        environment = {**os.environ, 'STARWARD_RESPONSE_GATE': '1', 'STARWARD_TLS_RESUME_REASON': 'controlled_gate_activation',
            'STARWARD_VALIDATION_DIR': 'artifacts/validation/profile', 'LC_ALL': 'C',
            'PATH': str(NODE.parent) + ':' + str(HDC.parent) + ':/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin'}
        try:
            self.child = subprocess.Popen([str(NODE), str(SCRIPT), 'resume'], cwd=ROOT, env=environment,
                stdin=subprocess.DEVNULL, stdout=descriptor, stderr=subprocess.STDOUT, start_new_session=True)
        finally:
            os.close(descriptor)
        self.new_started = True
        deadline = time.monotonic() + 35
        while time.monotonic() < deadline:
            if self.child.poll() is not None:
                raise SafeFailure('The new own TLS resume process exited before verified readiness; backup/log retained')
            latest = self.state()
            self.backend(latest)
            pid = latest.get('tls', {}).get('pid')
            if pid not in (self.old_tls['pid'], self.child.pid):
                raise SafeFailure('An unexpected runner changed TLS state during resume; no process will be killed')
            if pid == self.child.pid and latest['tls'].get('responseGate'):
                # State is persisted immediately before the MJS evidence file.
                # Wait for that exact file rather than treating state alone as ready.
                evidence_path = OUT / 'isolated-tls-resume.json'
                if evidence_path.exists():
                    evidence = read_json(regular(evidence_path, OUT))
                    if evidence.get('causeOfPriorTermination') == REASON and evidence.get('responseGate'):
                        self.gate_ready(latest)
                        self.stable_files()
                        self.certificates()
                        self.backend(self.state())
                        self.checks.update({'sameTlsIdentityAndReverseMappingResumed': True,
                            'officialThreeTlsChecksPassed': True, 'authenticatedFreshUnarmedGateReady': True,
                            'nonTlsBackendStatePreserved': True})
                        return
            time.sleep(.15)
        raise SafeFailure('The resumed own TLS/gate did not reach complete verified readiness; no force-kill or CA rebuild was attempted')

    def run(self):
        failure = 'Controlled TLS transition did not complete'
        handlers = {}
        def interrupted(signum, frame):
            raise SafeFailure('Controlled TLS transition interrupted; preserved backup requires stage-aware recovery')
        try:
            for number in (signal.SIGINT, signal.SIGTERM):
                handlers[number] = signal.getsignal(number)
                signal.signal(number, interrupted)
            self.preflight()
            descriptor = os.open(no_links(LOCK), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            with os.fdopen(descriptor, 'w') as lock:
                json.dump({'pid': os.getpid(), 'startedAt': self.started}, lock)
            info = LOCK.stat()
            self.lock_identity = (info.st_dev, info.st_ino)
            self.backup_materials()
            self.stop_original()
            self.report('running')
            self.restore_original()
            self.start_gate()
            self.stage = 'gate_ready_without_arming'
            failure = None
        except Exception as error:
            failure = str(error) if isinstance(error, SafeFailure) else 'Controlled TLS transition stopped; raw diagnostics and private values omitted'
        finally:
            for number in handlers:
                signal.signal(number, signal.SIG_IGN)
            if self.lock_identity:
                try:
                    info = LOCK.lstat()
                    if stat.S_ISREG(info.st_mode) and (info.st_dev, info.st_ino) == self.lock_identity:
                        LOCK.unlink()
                except OSError:
                    pass
            try:
                self.report('incomplete' if failure else 'passed', failure)
            finally:
                for number, handler in handlers.items():
                    signal.signal(number, handler)
        return 1 if failure else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--runtime-report', type=Path, required=True, help='Actual installed15000ms/font1 HAP six-check runtime')
    parser.add_argument('--base-hap-manifest', type=Path, required=True, help='Explicit same-code2000ms base archive/source/ABC/config manifest')
    args = parser.parse_args()
    return Transition(args).run()


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception:
        print(json.dumps({'status': 'incomplete', 'error': 'Controlled TLS helper setup/report failed; private values omitted',
                          'lateResponseOrNativeUiAccepted': False}))
        raise SystemExit(1)

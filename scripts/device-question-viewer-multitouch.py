#!/usr/bin/env python3
"""Preparatory, owned Hypium multi-pointer supplement; default/help/plan are inert.

Run only with Root's review, the installed Testing Python3.12, a private current
directory/config/report/tmp and private stdout/stderr. Requires a fresh successful
same-HAP case2 normal-viewer report. No SDK is imported until all ownership guards
pass. Only official inject_multi_finger_gesture injects SDK UI actions. Cache
cleanup belongs to Root AFTER this Python process exits, using the exit inventory.
This is not complete viewer, cancellation, or remaining-finger acceptance.
"""
import argparse
import atexit
import datetime
import hashlib
import importlib.util
import ipaddress
import json
import os
from pathlib import Path
import pwd
import re
import shlex
import shutil
import socket
import stat
import subprocess
import sys
import time
import urllib.request

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / 'artifacts/private'
OUT = ROOT / 'artifacts/validation/ui-image-viewer-20261105'
PYTHON = Path('/Applications/DevEco_Testing_for_App.app/Contents/Python/bin/python3')
SDK = PYTHON.parent.parent / 'lib/python3.12/site-packages'
HDC = Path('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc')
PARENT = ROOT / 'scripts/device-question-image-viewer.py'
PARENT_SHA = 'a1d5d608f76647760246139ffd4ab95cbb1a386eb9ac60880f57f460531388fd'
SDK_SOURCES = {
    'hypium/__init__.py': '80f1302f89f8fa324982cbb139bcbb8af6b681fef8cc1eefe3c4386a3e6c9f66',
    'hypium/version.py': '83d1efe63d590e653f8a5001cb7d2aa99d98ee6ccfc51e630dbb5d7c8e70ab24',
    'hypium/action/device/uidriver.py': 'c00e13c080b7a60dbf9ffdaa0249af52463cd194fefee53de90ba8a2218c851a',
    'hypium/uidriver/device_connector.py': 'ca625e907ac92013d04c81b7cf99cfcc1db1c318d54574cb54c97f75aead49b0',
    'hypium/uidriver/ohos/uidriver.py': 'b46925156470e43661bc7c5e030de558923ba0174c811032f2147d801971a1af',
    'hypium/uidriver/arkuidriver.py': 'dfb0d4f142c97debfa22fc544131dfc0870987b38452275e62ede54d3c3a13a4',
    'hypium/uidriver/gesture.py': '187585f39a24f3ae4e94f1d5a177db1872c700a513524b06196960726467befe',
    'hypium/uidriver/pointer_matrix.py': 'f493fac33bc982a63478885265bf28357af4377358b2570e3637655c7327e805',
    'hypium/dfx/init_status_manager.py': '19abb010d452e38307c086643c0e2ecb38d003154e46504995950be175672f05',
    'hypium/dfx/tracker.py': 'ee33b7d1b19c4b9f75f88873ff46fc8ffb4f35a6adb0f5b309a5408dd36c4cf1',
    'hypium/model/basic_data_type.py': '235915582100bbc2007b175c95c61bcdbc02e096862f3eb3112a49c669278eb3',
    'hypium/utils/utils.py': 'f08a32783d1acdcbbaddd818350aa385cb4878892e3a714e7829b166a9affd87',
    'xdevice/__init__.py': '04a31dedcb21b9ad33eedc52ee822a48d580c8202383f4b117f79cdc298ff37c',
    'xdevice/_core/variables.py': '30331c69a6955ab1dc45f9f02dfdf33a67709ca2ccb2e6a1ceaeff078851753e',
    'xdevice/_core/utils.py': '277dc2f35a349ea3862df8f577ba2f002369a2dbb43a9e69f2fee8ec2f989bf3',
    'xdevice/_core/config/config_manager.py': '3291803327aeee020d1e61f3992a67cb8fbd8b12c4ab499112d592a2c6c18ce2',
    'xdevice/_core/analysis/tracker.py': 'e23fc2029016981eecb87bdbd04ceabd7702e2bc1e6ed78ba347837784a0b3db',
    'xdevice/_core/analysis/db.py': '6417ab826ae533ab2529efe15f126458685b2e6a4fd04603f7362846e63c6e5e',
    'xdevice/_core/environment/env_pool.py': '999956b832502e589ea2fa5fdbf1baebcb08e27521c3e8333c55f116d73c0885',
    'ohos/proxy/ui_proxy.py': '1c76631c25c70f082083c2baef336ad3bf2b327e154754f01a4fe0ee9201daf7',
    'ohos/proxy/proxy_base.py': '62185539994ffcdb1757b80a45a79fe31fd1fe22670cccd91e691f42ab7b968e',
    'ohos/environment/device.py': '4ca3d74d3dab0d36b9179bf712aa17da4dfd895e473193b457f39cb5950091ef',
    'ohos/environment/dmlib.py': '08b1fb47f522a75d9a2a1f6b2a4e91b970fa9e055d9ec360444333ee883c408d',
    'devicetest/utils/util.py': '303910ceb57801e91c10cd019a37b000aba21e27505fa5d0e4db44c9e4c369d5',
    'devicetest/core/test_case.py': '620d7ed1eee0de86e65e91cafb8c72d0f494a29b2fca5019a2d76fe21e9a51e2',
}
AGENTS = {
    'uitest_agent_v1.1.10.so': '1c9286456fb003ee15d86fef04e8c93f004027349e6dd2ef972c792e0a6d4bf8',
    'uitest_agent_v1.1.3.so': '6a76d6047b367b0e00be627daf212d3baa5b20566131cbe298abe7cdf6639b53',
    'uitest_agent_v1.1.5.so': 'fc2322feb8145ddda244f2b97046f448d040d886e6f81e546842ee45fa028781',
    'uitest_agent_v1.1.9.x86_64_so': '24a14a7841ec376dad4e1fa741de8f9f218c652a7e6d0100077798006367b274',
    'uitest_agent_v1.2.2.so': 'e1b8e75fad983aa29640784ee4b457fe7ac1c916a15f72c8b899d5a7716da651',
}
CONFIG = ('<user_config><uploadtrack>FALSE</uploadtrack><analysis><upload><enable>false</enable>'
          '</upload></analysis><taskargs><kill_uitest>false</kill_uitest></taskargs></user_config>\n')
REMOTE_FILES = {'agent.so', 'screen.png', 'screen.jpeg'}
PREFIXES = ('app', 'commons-', 'agent', 'libagent_antry')
OFFLINE_RESOLVER_REASON = 'Resolver access is disabled by the owned offline SDK harness'
SAFE_FAILURE_REASONS = frozenset({'An SDK import/operation encountered a process audit rejection'})


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(',', ':'), allow_nan=False)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def failure_reason(error):
    trace = error.__traceback__
    while trace is not None and trace.tb_next is not None:
        trace = trace.tb_next
    if type(error) is RuntimeError and len(error.args) == 1 and type(error.args[0]) is str and \
            error.args[0] in SAFE_FAILURE_REASONS and trace is not None and \
            trace.tb_frame.f_code.co_filename == __file__ and trace.tb_frame.f_code.co_name == 'require':
        return error.args[0]
    return 'Owned setup, actual gesture evidence, or cleanup guard failed; raw exception omitted'


def plan():
    return {'scope': 'Official case2 Pinch/zoomed Pan/reset supplement only', 'python': str(PYTHON),
            'hypiumVersion': '6.1.0.210', 'hdc': str(HDC), 'normalHelperSha256': PARENT_SHA,
            'sdkSourceSha256': SDK_SOURCES, 'agentSourceSha256': AGENTS,
            'configSha256': hashlib.sha256(CONFIG.encode()).hexdigest(),
            'beforeConnect': ['Fresh successful same-HAP/case2 normal report and unchanged source bindings',
                'Private cwd/report/tmp/stdout/stderr; absent home .xdevice AND .hypium; no HOME changes',
                'Single explicit device; existing fixed-Studio HDC server; own TLS reverse only',
                'Empty own login; no daemon/wukong or preexisting SDK cleanup-prefix/screen files',
                'Deny nonloopback DNS/socket connect before lazy SDK import; verify public false config'],
            'connect': 'Remove exact owned reverse, connect, bind exact new forward/PID birth/agent bytes, restore own reverse; no UI actions during connect',
            'gestures': ['Measured-stage two-finger positive Pinch', 'Zoomed one-finger Pan through the same official injector',
                         'Actual reset Button', 'Pinch upper400% and lower100% clamps'],
            'proof': 'Serial real injections, then original PNG/raw actual pose/index; None return is not a pass',
            'cleanup': 'Empty logout first; close(kill_uitest=false), existing EnvPool shutdown, exact owned remote cleanup; Root cache cleanup AFTER process exit',
            'pending': ['Cancellation and remaining-finger isolation', 'Root original-image review', 'Outer post-process cache cleanup'],
            'noActualSdkImportOrDeviceOperation': True}


def private_path(path, directory=False):
    path = Path(path).absolute()
    require(path == path.resolve() and path.is_relative_to(PRIVATE) and path != PRIVATE, 'A canonical task-private path is required')
    for item in (path, *path.parents):
        if item == ROOT:
            break
        info = item.lstat()
        require(not stat.S_ISLNK(info.st_mode) and info.st_uid == os.getuid(), 'A private path has foreign ownership or a symlink')
        if item == PRIVATE or PRIVATE in item.parents:
            mode = 0o700 if item != path or directory else 0o600
            require(stat.S_IMODE(info.st_mode) == mode, 'Task-private directories/files must be700/600')
    require(path.is_dir() if directory else path.is_file(), 'A private path has the wrong type')
    return path


def identity(info):
    return {'device': info.st_dev, 'inode': info.st_ino, 'uid': info.st_uid,
            'birthNs': round(getattr(info, 'st_birthtime', 0) * 1e9), 'mode': stat.S_IMODE(info.st_mode)}


def write_json(path, value):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as stream:
        os.fchmod(stream.fileno(), 0o600)
        stream.write(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + '\n')
    return {'file': str(Path(path).relative_to(ROOT)), 'sha256': sha(path)}


def forwards(text, serial):
    if text.strip() == '[Empty]':
        return []
    result = []
    for line in text.splitlines():
        words = line.split()
        if not words:
            continue
        require(len(words) in (3, 4), 'Unknown HDC forward row shape')
        if len(words) == 4:
            require(words.pop(0) == serial, 'A forward belongs to another device')
        source, target, direction = words
        require(re.fullmatch(r'tcp:[1-9][0-9]{0,4}', source) and 1 <= int(source[4:]) <= 65535 and
                (re.fullmatch(r'tcp:[1-9][0-9]{0,4}', target) and 1 <= int(target[4:]) <= 65535 or target == 'localabstract:uitest_socket') and
                direction in ('[Reverse]', '[Forward]'), 'Unknown HDC forward endpoints/direction')
        row = (source, target, direction)
        require(row not in result, 'Duplicate HDC forward')
        result.append(row)
    return sorted(result)


def daemon_pids(text):
    result = []
    for line in text.splitlines():
        if re.search(r'\b(?:uitest|singleness|wukong)\b', line, re.I):
            values = line.split()
            require(len(values) >= 3 and values[1].isdigit() and 'grep' not in values, 'Unexpected UITest/Wukong process row')
            result.append(int(values[1]))
    require(len(result) == len(set(result)), 'Repeated daemon process')
    return result


class ProcessAudit:
    """No SDK patch. Only loopback Python connections; record task-local writes.

    This does not intercept HDC's native transport. Its executable, explicit
    serial/server and exact device deltas are separately bound and checked.
    """
    def __init__(self, roots, report, port):
        self.roots, self.report, self.port = tuple(roots), report, port
        self.writes, self.denied, self.own_reverse_removal = set(), [], False
        # Local metadata only, captured before hook installation/SDK import.
        # The hostname itself never enters public diagnostics or the inventory.
        self.local_hostname = socket.gethostname()
        self.blocked_resolver_lookups = []

    def deny(self, event):
        self.denied.append(event)
        raise RuntimeError('A process audit guard rejected an operation; raw target omitted')

    def write_target(self, value, event):
        if isinstance(value, int):
            return
        path = Path(os.fsdecode(value)).absolute()
        if path != path.resolve() or not (path == self.report or any(path == root or root in path.parents for root in self.roots)):
            self.deny(event)
        self.writes.add(str(path))

    def block_resolver(self, event, args):
        target = args[0] if args else None
        if event == 'socket.getnameinfo' and isinstance(target, tuple) and target:
            target = target[0]
        try:
            loopback = ipaddress.ip_address(target).is_loopback
        except (ValueError, TypeError):
            loopback = False
        frames, frame = [], sys._getframe(2)
        while frame is not None and len(frames) < 20:
            code, filename = frame.f_code, Path(frame.f_code.co_filename)
            trusted = filename.is_absolute() and (PYTHON.parent.parent / 'lib/python3.12' in filename.parents or filename.parent == ROOT / 'scripts')
            def safe(value, pattern):
                return value if trusted and type(value) is str and re.fullmatch(pattern, value) else '<opaque>'
            frames.append({'fileBasename': safe(filename.name, r'[A-Za-z0-9_.-]{1,80}'),
                'module': safe(frame.f_globals.get('__name__'), r'[A-Za-z_][A-Za-z0-9_.]{0,95}'),
                'co_name': safe(code.co_name, r'(?:[A-Za-z_][A-Za-z0-9_]{0,79}|<module>|<lambda>|<listcomp>|<genexpr>)'),
                'firstLine': code.co_firstlineno, 'currentLine': frame.f_lineno})
            frame = frame.f_back
        self.blocked_resolver_lookups.append({'event': event, 'targetIsLoopback': bool(loopback),
            'targetMatchesCapturedHostname': type(target) is str and target == self.local_hostname,
            'frames': frames, 'framesTruncated': frame is not None, 'blockedBeforeResolver': True})
        # Audit hooks run before the resolver. No fake IP or SDK patch: callers
        # may use their own existing OSError fallback, and every attempt is kept.
        raise OSError(OFFLINE_RESOLVER_REASON)

    def __call__(self, event, args):
        if event in ('socket.getaddrinfo', 'socket.gethostbyname'):
            try:
                require(ipaddress.ip_address(args[0]).is_loopback, 'Nonloopback DNS is forbidden')
            except (ValueError, TypeError, RuntimeError):
                self.block_resolver(event, args)
        elif event in ('socket.gethostbyaddr', 'socket.getnameinfo'):
            self.block_resolver(event, args)
        elif event in ('socket.connect', 'socket.sendto', 'socket.sendmsg'):
            address = args[1] if event == 'socket.connect' else args[-1]
            try:
                require(isinstance(address, tuple) and len(address) in (2, 4) and
                        ipaddress.ip_address(address[0]).is_loopback, 'Nonloopback connection is forbidden')
            except (ValueError, TypeError, RuntimeError):
                self.deny(event)
        elif event == 'open':
            mode, flags = args[1], args[2]
            if mode is not None and any(char in mode for char in 'wax+') or flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC):
                self.write_target(args[0], event)
        elif event in ('os.mkdir', 'sqlite3.connect'):
            self.write_target(args[0], event)
        elif event == 'subprocess.Popen':
            # Defense for subprocess-form HDC commands only. The SDK also uses
            # HDC's native protocol: pre/post exact receipts remain necessary,
            # and any automatic reconnect/delta makes this run incomplete.
            command = args[1]
            command = command if isinstance(command, str) else shlex.join(str(value) for value in command)
            if re.search(r'\bfport\s+rm\s+tcp:18443\b', command) and not self.own_reverse_removal:
                self.deny('subprocess.owned_reverse_removal')


class OwnedSdk:
    def __init__(self, sample, args):
        self.sample, self.args = sample, args
        self.driver, self.xdevice, self.hypium, self.forward, self.daemon, self.pool = None, None, None, None, None, None
        self.remote_files, self.cache_roots, self.notes = {}, {}, {}
        self.reverse_removed, self.import_attempted = False, False
        self.cleanup = {'sdkClosed': False, 'existingPoolShutdown': False, 'ownedDaemonRemoved': False,
                        'ownedAgentFilesRemoved': False, 'ownedSdkForwardRemoved': False, 'ownTlsReversePreserved': False,
                        'foreignRemoteNamesPreserved': False, 'existingHdcServerPreserved': False}
        self.serial = json.loads(private_path(args.device_ref).read_text())
        require(set(self.serial) == {'deviceSerial'} and isinstance(self.serial['deviceSerial'], str) and
                re.fullmatch(r'[A-Za-z0-9]{8,80}', self.serial['deviceSerial']), 'Explicit private device reference required')
        self.serial = self.serial['deviceSerial']
        self.work, self.report_dir, self.tmp = [private_path(value, True) for value in (args.sdk_work_dir, args.sdk_report_dir, args.sdk_temp_dir)]
        require(Path.cwd() == self.work and self.report_dir != self.tmp and self.work in self.report_dir.parents and
                self.work in self.tmp.parents and not self.report_dir.is_relative_to(self.tmp) and not self.tmp.is_relative_to(self.report_dir) and
                not any(self.report_dir.iterdir()) and not any(self.tmp.iterdir()) and not (self.work / 'config').exists(),
                'Use fresh empty private SDK report/tmp and an absent cwd/config')
        require(Path(os.environ.get('TMPDIR', '')).absolute() == self.tmp and
                Path(shutil.which('hdc') or '') == HDC and sha(HDC) == args.expected_hdc_sha and
                os.environ.get('OHOS_HDC_SERVER_PORT', '8710') == '8710' and not os.environ.get('HDC_SERVER_PORT') and
                not os.environ.get('PYTHONPATH') and not os.environ.get('PYTHONSTARTUP'), 'Fixed per-process HDC/TMPDIR/import environment required')
        require(Path(sys.executable).resolve() == PYTHON.resolve() and sys.version_info[:2] == (3, 12), 'Use installed Testing Python3.12 for the entire process')
        for fd in (1, 2):
            info = os.fstat(fd)
            require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o600,
                    'SDK stdout AND stderr must be caller-owned private600 regular files')
        previous = os.umask(0o077)
        require(previous == 0o077, 'Caller must set umask077 before starting this process')
        for relative, expected in SDK_SOURCES.items():
            require(sha(SDK / relative) == expected, 'Installed SDK source differs from the reviewed version')
        for name, expected in AGENTS.items():
            require(sha(SDK / 'devicetest/res/prototype/native' / name) == expected, 'Installed agent source bytes changed')
        self.home = Path.home()
        require(self.home == self.home.resolve() == Path(pwd.getpwuid(os.getuid()).pw_dir).resolve() and
                self.home.stat().st_uid == os.getuid(), 'Use the actual account home; never replace HOME for SDK isolation')
        self.cache_paths = [self.home / name for name in ('.xdevice', '.hypium')]
        require(all(not value.exists() and not value.is_symlink() for value in self.cache_paths),
                'SDK home caches must both be absent; existing unowned data is never read, changed or removed')
        self.tls_reverse = ('tcp:18443', 'tcp:' + str(sample.state['tls']['hostPort']), '[Reverse]')
        self.audit = ProcessAudit([self.work, sample.directory, *self.cache_paths], sample.report, sample.state['tls']['hostPort'])
        self.exit_inventory = sample.directory / 'sdk-cache-exit-inventory.json'

    def hdc(self, *args):
        result = subprocess.run([str(HDC), '-t', self.serial, *map(str, args)], capture_output=True, text=True, timeout=25)
        require(result.returncode == 0 and not re.search(r'(?im)^\s*\[?fail\]?|^error:', result.stdout),
                'An exact owned HDC operation failed; raw output retained only privately')
        return result.stdout

    def ls(self):
        names = self.hdc('shell', 'ls', '-1a', '/data/local/tmp').splitlines()
        names = {value.strip() for value in names if value.strip() not in ('.', '..', '')}
        require(all(re.fullmatch(r'[A-Za-z0-9._-]+', value) for value in names), 'An unknown remote filename prevents safe ownership accounting')
        return names

    def ports(self):
        return forwards(self.hdc('fport', 'ls'), self.serial)

    def processes(self):
        return daemon_pids(self.hdc('shell', 'ps', '-ef'))

    def hdc_server(self):
        def cmd(*args):
            result = subprocess.run(list(map(str, args)), capture_output=True, text=True, timeout=10)
            require(result.returncode == 0, 'Existing HDC listener ownership cannot be proved')
            return result.stdout
        rows = cmd('/usr/sbin/lsof', '-nP', '-iTCP:8710', '-sTCP:LISTEN', '-Fp').splitlines()
        pids = {int(row[1:]) for row in rows if re.fullmatch(r'p[1-9][0-9]*', row)}
        require(len(pids) == 1, 'Exactly one preexisting local HDC listener is required')
        pid = pids.pop()
        binaries = [Path(row[1:]) for row in cmd('/usr/sbin/lsof', '-a', '-p', pid, '-d', 'txt', '-Fn').splitlines() if row.startswith('n')]
        require(cmd('ps', '-p', pid, '-o', 'uid=').strip() == str(os.getuid()) and any(path.resolve() == HDC.resolve() for path in binaries),
                'The HDC listener is not the owned fixed-Studio executable')
        return {'pid': pid, 'birth': cmd('ps', '-p', pid, '-o', 'lstart=').strip(), 'sha256': sha(HDC)}

    def daemon_receipt(self, pid):
        proc = '/proc/' + str(pid)
        raw = self.hdc('shell', 'cat', proc + '/stat').strip()
        fields = raw[raw.rfind(')') + 2:].split()
        command = self.hdc('shell', 'cat', proc + '/cmdline').replace('\x00', ' ').strip()
        executable = self.hdc('shell', 'readlink', proc + '/exe').strip()
        require(len(fields) >= 20 and fields[19].isdigit() and executable == '/system/bin/uitest' and
                re.fullmatch(r'(?:/system/bin/)?uitest\s+start-daemon\s+singleness', command),
                'The new daemon PID/executable/start birth is not exact')
        return {'pid': pid, 'startTicks': fields[19], 'executable': executable,
                'binarySha256': self.remote_hash(executable)}

    def remote_hash(self, path):
        value = self.hdc('shell', 'sha256sum', path).split()
        require(len(value) == 2 and re.fullmatch(r'[a-f0-9]{64}', value[0]) and value[1] == path, 'An exact remote file SHA256 is unavailable')
        return value[0]

    def file_receipt(self, name):
        require(name in REMOTE_FILES, 'Only explicit SDK-created files can have an owned receipt')
        path = '/data/local/tmp/' + name
        value = self.hdc('shell', 'stat', '-c', '%f:%i:%s:%Y:%Z:%u', path).strip().split(':')
        require(len(value) == 6 and all(re.fullmatch(r'[0-9a-fA-F]+', item) for item in value) and
                stat.S_ISREG(int(value[0], 16)) and int(value[5]) in (0, 2000), 'The new SDK file is not a direct regular shell-owned file')
        result = {'stat': value, 'sha256': self.remote_hash(path)}
        if name == 'agent.so':
            require(result['sha256'] in AGENTS.values(), 'The new remote agent bytes are not a reviewed installed agent')
            result['source'] = next(key for key, expected in AGENTS.items() if expected == result['sha256'])
        return result

    def private_receipt(self, suffix, value):
        return write_json(self.sample.directory / ('sdk-' + suffix + '.json'), value)

    def preflight(self):
        self.server = self.hdc_server()
        result = subprocess.run([str(HDC), 'list', 'targets'], capture_output=True, text=True, timeout=15)
        require(result.returncode == 0 and result.stdout.split() == [self.serial], 'Exactly the explicit sole authorized phone is required')
        require(self.ports() == [self.tls_reverse] and self.processes() == [], 'Only the owned TLS reverse and zero UITest/Wukong processes are allowed')
        self.remote_baseline = self.ls()
        require(not any(name.startswith(PREFIXES) or name in REMOTE_FILES for name in self.remote_baseline),
                'A preexisting agent cleanup-prefix/screen file forbids SDK initialization')
        self.sample.ui.capture()
        require(self.sample.ui.find('account') is not None and self.sample.ui.find('gameplay-page') is None and
                self.sample.ui.input_empty('account') and self.sample.ui.input_empty('password') and self.sample.ui.has_text('隔离测试环境'),
                'Normal viewer phase must have left the actual own empty isolated login')
        self.notes['baseline'] = self.private_receipt('baseline', {'deviceSerial': self.serial, 'forwards': self.ports(), 'server': self.server,
            'remoteNames': sorted(self.remote_baseline), 'homeCachePathsAbsent': list(map(str, self.cache_paths)),
            'sdkSourceSha256': SDK_SOURCES, 'agentSourceSha256': AGENTS})
        config_dir = self.work / 'config'
        config_dir.mkdir(mode=0o700)
        fd = os.open(config_dir / 'user_config.xml', os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, 'w') as stream:
            stream.write(CONFIG)
        sys.addaudithook(self.audit)
        # First absence was checked without reading either cache. We create the
        # roots ourselves and hold nofollow FDs, so the outer cleanup has a birth.
        for path in self.cache_paths:
            path.mkdir(mode=0o700)
            fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
            self.cache_roots[str(path)] = (fd, identity(os.fstat(fd)))
        atexit.register(self.write_exit_inventory)  # before SDK's later atexit hooks
        self.notes['cacheOwnership'] = self.private_receipt('cache-roots', {path: receipt for path, (_, receipt) in self.cache_roots.items()})

    def effective_config(self):
        config = self.xdevice.Variables.config
        require(Path(config.file_path) == self.work / 'config/user_config.xml' and
                str(config.uploadtrack.get('uploadtrack')).lower() == 'false' and
                str(config.analysis.get('upload', {}).get('enable')).lower() == 'false' and
                str(config.taskargs.get('kill_uitest')).lower() == 'false', 'Official public SDK config did not disable upload/analysis/daemon kill')
        require(sha(config.file_path) == hashlib.sha256(CONFIG.encode()).hexdigest(), 'The private official SDK config changed')
        require(not self.audit.denied, 'An SDK import/operation encountered a process audit rejection')
        self.notes['publicConfigVerified'] = {'uploadtrack': False, 'analysisUploadEnable': False, 'killUitest': False}

    def restore_tls(self):
        rows = self.ports()
        if self.tls_reverse not in rows:
            require(not any(row[0] == 'tcp:18443' for row in rows), 'An unknown mapping now occupies the owned TLS device port')
            self.hdc('rport', *self.tls_reverse[:2])
        require(self.tls_reverse in self.ports(), 'The exact own TLS reverse could not be restored')
        self.reverse_removed = False

    def connect(self):
        self.audit.own_reverse_removal = True
        try:
            self.hdc('fport', 'rm', *self.tls_reverse[:2])
        finally:
            self.audit.own_reverse_removal = False
        self.reverse_removed = True
        require(self.ports() == [] and self.processes() == [] and self.ls() == self.remote_baseline,
                'The SDK connect baseline changed after removing only our TLS mapping')
        self.import_attempted = True
        require(not any(name.split('.')[0] in ('hypium', 'xdevice', 'ohos', 'devicetest') for name in sys.modules),
                'This must be a fresh SDK Python process without a preexisting pool')
        import hypium
        import xdevice
        self.hypium, self.xdevice = hypium, xdevice
        require(Path(hypium.__file__) == SDK / 'hypium/__init__.py' and Path(xdevice.__file__) == SDK / 'xdevice/__init__.py' and
                hypium.__version__ == xdevice.__version__ == '6.1.0.210', 'A foreign SDK/version was imported')
        self.effective_config()  # before UiDriver.connect; no private Tracker setter
        require(xdevice.EnvPool.instance is None, 'No pool may predate this owned connect')
        try:
            self.driver = hypium.UiDriver.connect(device_sn=self.serial, report_path=str(self.report_dir), log_level='info', connector_server=('127.0.0.1', 8710))
        finally:
            self.pool = xdevice.EnvPool.instance  # a newly created pool, even on partial failure
        require(self.pool is not None, 'The owned SDK connection did not expose its existing pool')
        self.effective_config()
        rows, pids = self.ports(), self.processes()
        require(len(rows) == 1 and rows[0][2] == '[Forward]' and rows[0][1] in ('localabstract:uitest_socket', 'tcp:8012') and
                9901 <= int(rows[0][0][4:]) <= 9999 and len(pids) == 1, 'The exact new SDK forward/unique daemon delta is unavailable')
        self.forward, self.daemon = rows[0], self.daemon_receipt(pids[0])
        created = self.ls() - self.remote_baseline
        require('agent.so' in created and created <= REMOTE_FILES and self.remote_baseline <= self.ls(), 'Unknown remote SDK side effects prevent ownership binding')
        self.remote_files = {name: self.file_receipt(name) for name in sorted(created)}
        self.notes['connectedOwnership'] = self.private_receipt('connected', {'forward': self.forward, 'daemon': self.daemon,
            'remoteFiles': self.remote_files, 'server': self.hdc_server()})
        self.restore_tls()
        self.verify()

    def verify(self):
        require(self.forward is not None and self.daemon is not None and self.ports() == sorted([self.tls_reverse, self.forward]) and
                self.processes() == [self.daemon['pid']] and self.daemon_receipt(self.daemon['pid']) == self.daemon and
                self.ls() == self.remote_baseline | set(self.remote_files) and self.hdc_server() == self.server and
                all(self.file_receipt(name) == receipt for name, receipt in self.remote_files.items()),
                'The bound SDK daemon/agent/forward/server changed; do not reconnect or broadly clean')
        require(not self.audit.denied, 'A process audit rejection makes this run incomplete')
        self.effective_config()

    def inject(self, box, paths):
        self.verify()
        left, top, right, bottom = box
        require(right > left and bottom > top and len(paths) in (1, 2), 'A measured real stage and one/two actual pointers are required')
        area = self.hypium.Rect(left=left, right=right, top=top, bottom=bottom)
        gestures = []
        for start, end in paths:
            require(all(.04 <= value <= .96 for point in (start, end) for value in point), 'A real injection endpoint escapes the measured stage interior')
            gestures.append(self.hypium.Gesture(area=area, sampling_time=50).start(start).move_to(end, interval=.8))
        before = time.monotonic()
        value = self.driver.inject_multi_finger_gesture(gestures, speed=600)
        require(value is None, 'The reviewed official injector return contract changed')
        self.verify()
        return {'pointerCount': len(paths), 'stageBoundsPx': box, 'relativePaths': paths,
                'moveIntervalSeconds': .8, 'completedWithoutException': True, 'publicReturn': None,
                'callAndGuardDurationMs': round((time.monotonic() - before) * 1000)}

    def incomplete_observations(self):
        # Read-only partial-setup evidence never grants cleanup ownership.
        value = {'cleanupAuthorizedByThisObservation': False}
        for name, operation in (('forwards', self.ports), ('daemonPids', self.processes), ('remoteNames', lambda: sorted(self.ls()))):
            try:
                value[name] = operation()
            except Exception:
                value[name + 'Unavailable'] = True
        try:
            self.notes['incompleteObservation'] = self.private_receipt('incomplete-observation', value)
        except Exception:
            pass

    def close_after_empty_logout(self):
        require(all(self.sample.cleanup[key] for key in ('loggedOut', 'loginInputsEmpty', 'privateGameplayAbsent')),
                'SDK/remote cleanup requires actual empty own logout first')
        # Nothing resembling rm-prefix/killall/rm of an unbound PID is used here.
        if self.driver is not None:
            self.verify()
            self.driver.close()
            self.cleanup['sdkClosed'] = True
        else:
            self.cleanup['sdkClosed'] = not self.import_attempted
        if self.pool is not None:
            require(self.xdevice.EnvPool.instance is self.pool, 'The SDK pool was replaced; no unknown pool is shut down')
            self.pool.shutdown()
        self.cleanup['existingPoolShutdown'] = self.pool is not None or not self.import_attempted
        self.restore_tls()
        rows = self.ports()
        require(all(row == self.tls_reverse or row == self.forward for row in rows), 'An unknown forward must be left to Root')
        if self.forward is not None and self.forward in rows:
            self.hdc('fport', 'rm', *self.forward[:2])
        require(self.ports() == [self.tls_reverse], 'Owned SDK forward cleanup did not preserve only our original TLS reverse')
        self.cleanup['ownedSdkForwardRemoved'] = True
        if self.daemon is not None:
            require(self.processes() == [self.daemon['pid']] and self.daemon_receipt(self.daemon['pid']) == self.daemon,
                    'The PID/source/birth changed; no daemon is killed')
            self.hdc('shell', 'kill', '-9', self.daemon['pid'])
            for _ in range(10):
                remaining = self.processes()
                require(remaining in ([], [self.daemon['pid']]), 'An unknown UITest process is left for Root')
                if not remaining:
                    break
                time.sleep(.2)
        require(self.processes() == [], 'An unknown or surviving UITest process is left for Root')
        self.cleanup['ownedDaemonRemoved'] = True
        require(self.ls() == self.remote_baseline | set(self.remote_files), 'Remote files changed; no unknown file is removed')
        for name, receipt in self.remote_files.items():
            require(self.file_receipt(name) == receipt, 'A task-owned file hash/inode/birth changed; it is not removed')
            self.hdc('shell', 'rm', '/data/local/tmp/' + name)
        self.cleanup['ownedAgentFilesRemoved'] = self.ls() == self.remote_baseline
        self.cleanup['foreignRemoteNamesPreserved'] = self.ls() == self.remote_baseline
        self.cleanup['ownTlsReversePreserved'] = self.ports() == [self.tls_reverse]
        self.cleanup['existingHdcServerPreserved'] = self.hdc_server() == self.server
        self.notes['remoteCleanup'] = self.private_receipt('remote-cleanup', {'cleanup': self.cleanup, 'forwards': self.ports(), 'remoteNames': sorted(self.ls())})

    def write_exit_inventory(self):
        """No deletion in-process: outer owner waits for exit before exact cleanup.

        Registered BEFORE SDK import: later SDK atexit handlers execute first.
        Root still verifies the final paths/inodes/hashes after process exit.
        """
        try:
            roots = []
            for path, (fd, receipt) in self.cache_roots.items():
                require(identity(os.fstat(fd)) == receipt and identity(os.lstat(path)) == receipt, 'An SDK cache root identity changed')
                files = []
                def walk(directory_fd, prefix=''):
                    for name in sorted(os.listdir(directory_fd)):
                        require(name not in ('.', '..') and '/' not in name, 'Invalid cache entry')
                        info = os.stat(name, dir_fd=directory_fd, follow_symlinks=False)
                        relative = prefix + name
                        require(info.st_uid == os.getuid() and not stat.S_ISLNK(info.st_mode), 'A cache child is foreign or linked')
                        target = str(Path(path) / relative)
                        tracked = target in self.audit.writes or any(target == base + suffix for base in self.audit.writes for suffix in ('-journal', '-wal', '-shm'))
                        require(tracked, 'An untracked cache child must be left for Root')
                        row = {'relativePath': relative, **identity(info)}
                        if stat.S_ISDIR(info.st_mode):
                            require(row['mode'] == 0o700, 'A cache directory is not private700')
                            child = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory_fd)
                            try:
                                require(identity(os.fstat(child)) == identity(info), 'A cache directory was replaced')
                                files.append({**row, 'kind': 'directory'})
                                walk(child, relative + '/')
                            finally:
                                os.close(child)
                        else:
                            # Fixed SDK EnvPool.update_cache creates this exact
                            # file with mode0755; caller umask077 yields0700.
                            # Only the newly owned root-level .xdevice/cache.dat
                            # has this exception; row.mode records its real mode.
                            allowed_modes = (0o600, 0o700) if Path(path) == self.home / '.xdevice' and relative == 'cache.dat' else (0o600,)
                            require(stat.S_ISREG(info.st_mode) and row['mode'] in allowed_modes and info.st_nlink == 1, 'A cache file violates its exact private mode policy')
                            child = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=directory_fd)
                            try:
                                require(identity(os.fstat(child)) == identity(info), 'A cache file was replaced')
                                digest = hashlib.sha256()
                                while True:
                                    data = os.read(child, 1024 * 1024)
                                    if not data:
                                        break
                                    digest.update(data)
                                after = os.fstat(child)
                                require(info.st_size == after.st_size and info.st_mtime_ns == after.st_mtime_ns, 'A cache file changed during inventory')
                                files.append({**row, 'kind': 'file', 'bytes': info.st_size, 'modifiedNs': info.st_mtime_ns, 'sha256': digest.hexdigest()})
                            finally:
                                os.close(child)
                walk(fd)
                roots.append({'path': path, 'root': receipt, 'entries': files})
            write_json(self.exit_inventory, {'status': 'owned_cache_inventory_for_outer_post_process_verification',
                'postProcessCacheCleanupPending': True, 'roots': roots, 'writeAuditPaths': sorted(self.audit.writes),
                'homeCacheBaselineAbsent': True, 'childPid': os.getpid(), 'helperSha256': sha(__file__),
                'normalPrerequisiteSha256': self.sample.binding['normalViewerPrerequisite'], 'sdkSourceSha256': SDK_SOURCES,
                'auditDeniedEvents': self.audit.denied, 'blockedResolverLookups': self.audit.blocked_resolver_lookups,
                'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()})
        except Exception:
            # No broad fallback cleanup and no raw exception/SDK target on stdout.
            try:
                write_json(self.sample.directory / 'sdk-cache-inventory-incomplete.json', {'status': 'incomplete',
                    'reason': 'Cache ownership/hash inventory failed; do not remove anything without Root review'})
            except Exception:
                pass


def sample_type(parent):
    FRAME, UI = parent.FRAME, parent.UI

    class MultiTouch(parent.Viewer):
        def __init__(self, args):
            super().__init__(args)
            require(self.index == 2, 'Only explicit already-active ordinary real-content case2 is supported')
            require(self.report.parent == OUT and OUT.is_dir(), 'Use a fresh JSON directly in the existing viewer validation directory')
            reference = FRAME.ENTRY.guarded(args.normal_reference, OUT)
            require(sha(reference) == args.expected_normal_reference_sha, 'The normal viewer prerequisite report changed')
            normal = json.loads(reference.read_text())
            created = datetime.datetime.fromisoformat(normal.get('createdAt', ''))
            age = (datetime.datetime.now(datetime.timezone.utc) - created).total_seconds()
            require(0 <= age <= 3600 and normal.get('status') == 'captured_native_viewer_narrow' and normal.get('sourceCaseIndex') == 2 and
                    normal.get('hapSha256') == self.hap_sha and normal.get('failure') is None and normal.get('checksPassed', 0) > 0 and
                    normal.get('cleanup') and all(value is True for value in normal['cleanup'].values()) and
                    normal.get('bindingSha256') == self.binding, 'A fresh successful same-HAP/case2/source/CA/runtime normal capture is required')
            require(re.fullmatch(r'[a-f0-9]{64}', args.expected_hdc_sha or ''), 'Explicit fixed-Studio HDC SHA256 required')
            self.bound['normalViewerPrerequisite'], self.binding['normalViewerPrerequisite'] = reference, sha(reference)
            self.bound['multiTouchHelper'], self.binding['multiTouchHelper'] = Path(__file__), sha(__file__)
            self.sdk = OwnedSdk(self, args)
            self.gestures = []

        def empty_login(self):
            self.ui.capture()
            require(self.ui.find('account') is not None and self.ui.input_empty('account') and self.ui.input_empty('password') and
                    self.ui.find('gameplay-page') is None and self.ui.has_text('隔离测试环境'), 'The own isolated login must be actually empty')

        def observe_pose(self, label):
            self.sdk.verify()
            raw, evidence = self.ui.raw_app(label)
            require(all(any(row.get('id') == node_id for row in raw) for node_id in parent.IDS) and
                    not any(row.get('id') in ('image-viewer-loading', 'image-viewer-error', 'image-viewer-retry') for row in raw), 'Actual viewer ready pixels are required')
            stage = FRAME.own(raw, 'image-viewer-stage')
            actual = parent.pose(stage)
            require(100 <= actual['percent'] <= 400 and FRAME.own(raw, 'image-viewer-percent').get('text') == str(actual['percent']) + '%' and
                    FRAME.own(raw, 'image-viewer-index').get('text') == '2 / 3', 'A real gesture escaped the middle image or legal scale')
            box = UI.rect(stage['bounds'])
            for axis, extent in (('xVp', box[2] - box[0]), ('yVp', box[3] - box[1])):
                # Accessibility rounds the scale to whole percent and offsets
                # to0.1vp. Account only for that exposed rounding, not motion.
                limit = extent / self.ui.density * ((actual['percent'] + .5) / 100 - 1) / 2
                require(abs(actual[axis]) <= limit + .2, 'The actual zoomed Pan escapes the measured stage clamp')
            record = {'position': label, 'themeRequested': 'light', 'imageIndex': 2, 'imageCount': 3,
                'pose': actual, 'rawSha256': evidence['sha256'], 'stageBoundsPx': box,
                'pixelsBoundsPx': UI.rect(FRAME.own(raw, 'image-viewer-pixels')['bounds']),
                'sourceSha256': self.specs()[1]['sourceSha256'], **self.screenshot(label, 'light', raw)}
            self.states.append(record)
            self.sdk.verify()
            return actual, box

        def injected(self, label, paths, assertion):
            before_reads = len(self.ledger())
            self.ui.capture()
            box = UI.rect(self.ui.find('image-viewer-stage')['bounds'])
            injection = self.sdk.inject(box, paths)
            actual, _ = self.observe_pose(label)
            require(assertion(actual), 'The actual native pose did not satisfy ' + label)
            require(len(self.ledger()) == before_reads, 'A viewer gesture caused an unexpected business request')
            self.gestures.append({'gesture': label, **injection, 'observedPose': actual, 'sameMiddleIndex': True, 'zeroBusinessTraffic': True})
            self.check(True, label + ' has actual raw pose/original PNG evidence, unchanged image and zero business traffic')
            return actual

        def main(self):
            self.stage = 'host-auth-read-and-owned-sdk-preflight'
            self.baseline, self.expected_starts = self.ledger(), 0
            with self.host_opener.open(urllib.request.Request(self.host + '/api/health', headers={'Accept': 'application/json'}), timeout=15) as response:
                require(response.status == 200, 'The existing strictly verified own Host TLS health is unavailable')
            auth = self.request(False, FRAME.AUTH, {'identity': self.case['account'], 'password': self.case['newPassword']})
            require(auth.get('record', {}).get('id') == self.case['playerId'] and isinstance(auth.get('token'), str) and auth['token'], 'Own Host authentication failed')
            self.token, self.dto = auth['token'], None
            self.dto = self.snapshot()
            self.facts(); self.question(); self.immutable()
            self.sdk.preflight()
            self.stage = 'official-sdk-connect-no-ui-actions'
            try:
                self.sdk.connect()
            finally:
                self.sdk.restore_tls()
            self.empty_login()
            self.stage = 'ordinary-native-login-get-only-active-case2'
            self.device_started = True
            self.ui.fill('account', self.case['account']); self.ui.fill('password', self.case['newPassword'])
            self.ui.tap('primary-action')
            self.ui.wait(lambda ui: ui.find('current-tab') is not None and ui.find('old-password') is None, 'own ordinary direct login')
            before = len([row for row in self.ledger() if row.get('method') == 'GET' and row.get('path') == self.detail])
            self.ui.tap('assignment-' + self.assignment_id)
            self.ui.wait(lambda ui: ui.find('gameplay-question-card') is not None and ui.find('gameplay-loading') is None, 'existing active own image question', timeout=40)
            reads = [row for row in self.ledger() if row.get('method') == 'GET' and row.get('path') == self.detail][before:]
            require(len(reads) == 2 and all(row.get('status') == 200 for row in reads), 'Established active entry requires exactly its two GET200 responses')
            self.dto = self.snapshot()
            self.fixture = FRAME.write_private(self.directory / 'web-dtos.json', self.dto, (self.case['newPassword'], self.state['controlToken'], self.token))
            self.theme('light'); self.ready_images(self.specs())
            self.ui.fill('gameplay-answer-input', parent.DRAFT); self.draft('multitouch-initial', initial=True)
            before = len(self.ledger())
            self.open_image(1)
            initial, _ = self.observe_pose('multitouch-baseline')
            require(initial == {'percent': 100, 'xVp': 0.0, 'yVp': 0.0}, 'The opened image is not initially untransformed')
            self.stage = 'serial-real-multi-pointer-injection'
            zoom = self.injected('positive-pinch', [((.38, .5), (.26, .5)), ((.62, .5), (.74, .5))],
                                 lambda actual: 170 <= actual['percent'] <= 230)
            self.injected('zoomed-pan', [((.45, .45), (.58, .52))],
                          lambda actual: abs(actual['percent'] - zoom['percent']) <= 1 and abs(actual['xVp']) > 8 and abs(actual['yVp']) > 4)
            self.ui.run('devecocli', 'ui', 'click', '--id', 'image-viewer-reset')
            reset, _ = self.observe_pose('actual-reset-button')
            require(reset == {'percent': 100, 'xVp': 0.0, 'yVp': 0.0}, 'Actual Reset did not restore the baseline pose')
            self.check(True, 'The actual reset Button restores100%/zero offsets after real zoomed Pan')
            self.injected('maximum-pinch-cap', [((.45, .5), (.15, .5)), ((.55, .5), (.85, .5))], lambda actual: actual['percent'] == 400)
            self.injected('minimum-pinch-cap', [((.15, .5), (.48, .5)), ((.85, .5), (.52, .5))],
                          lambda actual: actual == {'percent': 100, 'xVp': 0.0, 'yVp': 0.0})
            self.close_image('x', 'light')
            require(len(self.ledger()) == before, 'Viewer open/real gestures/reset/close unexpectedly called a business API')
            self.verify_ledger(); self.immutable()
            self.check(True, 'Real multi-pointer sample closes with the same native input instance/DRAFT, zero start/answer/XP')

        def execute(self):
            try:
                self.main()
            except Exception as error:
                # SDK errors may contain serial/addresses. Keep only the local
                # stage/type; private command receipts support Root diagnosis.
                FRAME.write_private(self.directory / 'failure-diagnostic.json', {'stage': self.stage, 'exceptionType': type(error).__name__,
                    'reason': failure_reason(error)}, ())
                self.failure = 'The narrow multi-pointer supplement is incomplete'
                if hasattr(self.sdk, 'server'):
                    self.sdk.incomplete_observations()
            finally:
                try:
                    if hasattr(self.sdk, 'server'):
                        self.sdk.restore_tls()
                    self.immutable()
                    if self.device_started:
                        self.ui.capture()
                        if self.ui.find('image-viewer') is not None:
                            self.ui.run('devecocli', 'ui', 'click', '--id', 'image-viewer-close')
                            self.ui.wait(lambda ui: ui.find('image-viewer') is None, 'dismiss own viewer before logout')
                        self.logout()
                    else:
                        self.empty_login()
                        self.cleanup.update(loggedOut=True, loginInputsEmpty=True, privateGameplayAbsent=True)
                    self.verify_ledger()
                    if hasattr(self.sdk, 'server'):
                        self.sdk.close_after_empty_logout()
                except Exception:
                    self.failure = self.failure or 'Owned empty logout/SDK remote cleanup/source observations could not be confirmed'
                    self.sdk.incomplete_observations()
                self.cleanup['remoteRawFilesRemoved'] = self.ui.remote_cleanup_ok
                if not all(self.cleanup.values()) or not all(self.sdk.cleanup.values()) or self.sdk.audit.denied:
                    self.failure = self.failure or 'The narrow multi-pointer cleanup/traffic guard is incomplete'
            ledger = FRAME.write_private(self.directory / 'request-ledger.json', self.final_ledger,
                (self.case['newPassword'], self.state['controlToken'], self.token)) if hasattr(self, 'final_ledger') else None
            report = {'status': 'incomplete' if self.failure else 'captured_pending_outer_cache_cleanup',
                'scope': 'Official real case2 Pinch/zoomed Pan/Reset/clamp supplement only', 'viewerAcceptanceComplete': False,
                'sourceCaseIndex': 2, 'hapSha256': self.hap_sha, 'bindingSha256': self.binding,
                'sdkSourceSha256': SDK_SOURCES, 'sdkVersion': '6.1.0.210', 'sdkNotes': self.sdk.notes,
                'checksPassed': len(self.checks), 'checks': self.checks, 'gestures': self.gestures, 'states': self.states,
                'cleanup': self.cleanup, 'sdkRemoteCleanup': self.sdk.cleanup, 'postProcessCacheCleanupPending': True,
                'privateExitCacheInventory': str(self.sdk.exit_inventory.relative_to(ROOT)),
                'outerCleanupRule': 'Wait for Python exit; verify fresh exit inventory roots/inodes/hashes/source and absence baseline before precise removal',
                'auditDeniedEvents': self.sdk.audit.denied, 'blockedResolverLookups': self.sdk.audit.blocked_resolver_lookups,
                'resolverPolicy': 'Offline resolver calls blocked with OSError; attempts are diagnostic and do not establish acceptance',
                'privateScreenshots': self.ui.private_screenshots,
                'privateRawEvidence': self.ui.raw_evidence, 'privateReadOnlyLedger': ledger,
                'realMultiPointerInjected': bool(self.gestures), 'publicInjectionReturnMeaning': 'Reviewed SDK returnsNone; raw pose/PNG is the evidence',
                'otherTestCountsInherited': False, 'fixedPreviewTouched': False, 'failure': self.failure,
                'pendingAcceptance': ['Root post-process exact cache cleanup closure', 'Remaining-finger and cancellation isolation', 'Root full-original visual review'],
                'writeScope': 'Host auth/read; zero start/answer/profile/password/fault/reset; owned SDK initialization/cleanup only',
                'createdAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
            encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
            private = [self.sdk.serial, self.case_id, self.case['account'], self.case['newPassword'], self.case['playerId'], self.assignment_id,
                       self.case['assignments']['ready']['sessionId'], self.state['controlToken'], self.token, *self.assets]
            require(not re.search(r'https?://', encoded) and not any(value and value in encoded for value in private), 'A private literal would enter the public supplement report')
            FRAME.fresh(self.report, OUT)
            require(self.report.parent == OUT and OUT.is_dir(), 'The existing public report directory changed')
            fd = os.open(self.report, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
            with os.fdopen(fd, 'w') as stream:
                stream.write(encoded)
            print(json.dumps({'status': report['status'], 'checksPassed': len(self.checks), 'report': str(self.report.relative_to(ROOT))}), flush=True)
            return 1 if self.failure else 0

    return MultiTouch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action')
    sub.add_parser('plan', help='Inert preparation manifest; no SDK/private/device read')
    run = sub.add_parser('run', help='Only after Root reviews this new helper and the same-HAP normal capture')
    for name in ('runtime', 'case-ref', 'output', 'private-dir', 'images-manifest', 'web-reference', 'normal-reference',
                 'device-ref', 'sdk-work-dir', 'sdk-report-dir', 'sdk-temp-dir'):
        run.add_argument('--' + name, type=Path, required=True)
    for name in ('expected-hap', 'expected-fixture-sha', 'expected-images-manifest-sha', 'expected-web-reference-sha',
                 'expected-viewer-sha', 'expected-gameplay-page-sha', 'expected-window-sha', 'expected-surfaces-sha',
                 'expected-normal-reference-sha', 'expected-hdc-sha'):
        run.add_argument('--' + name, required=True)
    args = parser.parse_args()
    if not args.action:
        parser.print_help()
        return 0
    if args.action == 'plan':
        value = plan()
        print(json.dumps({'plan': value, 'planSha256': hashlib.sha256(canonical(value).encode()).hexdigest()}, ensure_ascii=False, indent=2))
        return 0
    try:
        require(sha(PARENT) == PARENT_SHA, 'The frozen normal-viewer helper changed')
        spec = importlib.util.spec_from_file_location('owned_normal_viewer', PARENT)
        parent = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(parent)
        return sample_type(parent)(args).execute()
    except Exception:
        print(json.dumps({'status': 'not_started_or_report_guarded', 'error': 'Explicit owned SDK/case/source/runtime/prerequisite/private guards failed; raw values omitted'}), flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())

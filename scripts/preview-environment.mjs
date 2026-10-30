#!/usr/bin/env node
/** Persistent, player-only PB preview. Never shares the disposable acceptance DB or controls. */
import http from 'node:http';
import https from 'node:https';
import { spawn, spawnSync } from 'node:child_process';
import { createHash, randomBytes, randomUUID, X509Certificate, createPublicKey } from 'node:crypto';
import { mkdir, readFile, writeFile, chmod, cp, readdir, lstat, rm, open, rename } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(import.meta.url);
const root = path.resolve(path.dirname(script), '..');
const home = path.join(root, 'artifacts/private/profile-preview');
const snapshot = path.join(home, 'source');
const data = path.join(home, 'pb_data');
const tls = path.join(home, 'tls');
const manifestFile = path.join(home, 'manifest.json');
const loginFile = path.join(home, 'login.json');
const runFile = path.join(home, 'run.json');
const lockFile = path.join(home, 'runner.lock');
const reportFile = path.join(root, 'artifacts/validation/profile/preview-environment.json');
const backend = path.resolve(process.env.STARWARD_BACKEND_SOURCE || path.join(root, '../sitkin-pb-backend-management/backend'));
const image = 'starward-hm-isolation:pb-0.40.1-arm64';
const version = '0.40.1';
const account = 'starward_preview';
const devicePort = 18443;
const endpoint = 'https://127.0.0.1:' + devicePort;
const openssl = '/opt/homebrew/bin/openssl';
const operation = process.argv[2] || 'help';
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const secret = () => 'Preview-' + randomBytes(15).toString('base64url');
class PreviewFailure extends Error {}
const fail = message => { throw new PreviewFailure(message); };
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const caFile = path.join(tls, 'ca.pem');
const caKey = path.join(tls, 'ca.key');
const serverKey = path.join(tls, 'server.key');
const serverCert = path.join(tls, 'server.pem');
process.umask(0o077);
process.chdir(root);
let heldLock = null;

function exec(program, args, input) {
  const result = spawnSync(program, args, { encoding: 'utf8', stdio: 'pipe', input, timeout: 120000 });
  if (result.status !== 0) fail(path.basename(program) + ' command failed; private command output omitted');
  return result.stdout;
}
async function exists(file) { try { await lstat(file); return true; } catch (e) { if (e.code === 'ENOENT') return false; throw e; } }
async function regular(file) {
  const relative = path.relative(home, file);
  if (relative.startsWith('..') || path.isAbsolute(relative)) fail('Private path escaped its preview directory');
  for (let cursor = home; ; ) {
    if (await exists(cursor) && (await lstat(cursor)).isSymbolicLink()) fail('Preview paths cannot be symlinks');
    if (cursor === file) break;
    const remaining = path.relative(cursor, file).split(path.sep);
    cursor = path.join(cursor, remaining[0]);
  }
  const item = await lstat(file);
  if (!item.isFile() || (item.mode & 0o077)) fail('Private preview file must be regular and mode600');
}
async function json(file) { await regular(file); return JSON.parse(await readFile(file, 'utf8')); }
async function save(file, value) {
  await mkdir(path.dirname(file), { recursive: true, mode: 0o700 });
  if (await exists(file)) await regular(file);
  const temporary = path.join(path.dirname(file), '.' + path.basename(file) + '-' + randomUUID() + '.tmp');
  await writeFile(temporary, JSON.stringify(value, null, 2) + '\n', { mode: 0o600, flag: 'wx' });
  await rename(temporary, file);
  await chmod(file, 0o600);
}
async function acquireLock(value) {
  if (await exists(lockFile)) {
    const previous = await json(lockFile);
    if (previous.owner !== value.owner || previous.script !== script || !Number.isInteger(previous.pid)) fail('Preview startup lock has unknown ownership');
    try { process.kill(previous.pid, 0); fail('Another exact preview runner is active or starting; no process or container replaced'); }
    catch (error) {
      if (error.code !== 'ESRCH') throw error;
      fail('An interrupted preview startup left runner.lock; exact owner/process/container review is required before removing that one stale file');
    }
  }
  const candidate = { owner: value.owner, script, pid: process.pid, nonce: randomUUID() };
  try { await writeFile(lockFile, JSON.stringify(candidate) + '\n', { mode: 0o600, flag: 'wx' }); }
  catch { fail('Preview startup lock is already owned by another invocation'); }
  heldLock = candidate;
}
async function releaseLock() {
  if (!heldLock) return;
  const current = await json(lockFile);
  if (current.owner !== heldLock.owner || current.pid !== process.pid || current.nonce !== heldLock.nonce) fail('Preview startup lock changed; no foreign lock removed');
  await rm(lockFile); heldLock = null;
}
async function hashes(directory, prefix = '') {
  const result = {};
  for (const entry of (await readdir(directory, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) {
    const name = prefix + entry.name;
    if (entry.isSymbolicLink()) fail('Frozen preview inputs cannot contain symlinks');
    if (entry.isDirectory()) Object.assign(result, await hashes(path.join(directory, entry.name), name + '/'));
    else if (entry.isFile()) result[name] = digest(await readFile(path.join(directory, entry.name)));
    else fail('Frozen preview inputs must contain regular files only');
  }
  return result;
}
async function manifest() {
  const value = await json(manifestFile);
  if (value.schema !== 1 || value.mode !== 'persistent isolated player preview' || value.account !== account ||
      !/^[a-f0-9-]{36}$/.test(value.owner) || value.image !== image || value.version !== version ||
      value.container !== 'starward-hm-preview-' + value.owner || !/^sha256:[a-f0-9]{64}$/.test(value.imageId) ||
      typeof value.initialized !== 'boolean') {
    fail('Preview ownership manifest is invalid');
  }
  if (JSON.stringify(await hashes(snapshot)) !== JSON.stringify(value.sourceHashes)) fail('Frozen preview source changed; refusing automatic migration');
  if (exec('docker', ['image', 'inspect', '--format', '{{.Id}}', image]).trim() !== value.imageId) fail('Preview PB image changed');
  await regular(caFile); await regular(caKey);
  if (digest(await readFile(caFile)) !== value.caSha256) fail('Preview CA changed; explicit reconfiguration and install are required');
  const authority = new X509Certificate(await readFile(caFile));
  if (!authority.publicKey.export({ type: 'spki', format: 'der' }).equals(
    createPublicKey(await readFile(caKey)).export({ type: 'spki', format: 'der' }))) fail('Preview CA private key does not match its frozen public identity');
  return value;
}
function mounts() {
  return ['--mount', 'type=bind,source=' + data + ',target=/preview/pb_data',
    '--mount', 'type=bind,source=' + path.join(snapshot, 'pb_hooks') + ',target=/preview/pb_hooks,readonly',
    '--mount', 'type=bind,source=' + path.join(snapshot, 'pb_migrations') + ',target=/preview/pb_migrations,readonly'];
}
const runtime = ['--dir=/preview/pb_data', '--hooksDir=/preview/pb_hooks', '--migrationsDir=/preview/pb_migrations', '--automigrate=false'];
function containerInfo(value, allowAbsent = false) {
  const result = spawnSync('docker', ['container', 'inspect', value.container], { encoding: 'utf8', stdio: 'pipe' });
  if (result.status !== 0) { if (allowAbsent) return null; fail('Owned preview container is missing'); }
  const rows = JSON.parse(result.stdout);
  const item = rows[0];
  const expected = [[data, '/preview/pb_data', true], [path.join(snapshot, 'pb_hooks'), '/preview/pb_hooks', false],
    [path.join(snapshot, 'pb_migrations'), '/preview/pb_migrations', false]];
  if (rows.length !== 1 || item.Image !== value.imageId || item.Config.Labels?.['com.sitkin.starward.preview'] !== value.owner ||
      item.Mounts.length !== expected.length || expected.some(([source, target, rw]) =>
        !item.Mounts.some(m => m.Type === 'bind' && m.Source === source && m.Destination === target && m.RW === rw))) {
    fail('A container with this name does not match the exact preview owner/image/mounts');
  }
  for (const bindings of Object.values(item.HostConfig.PortBindings || {})) {
    if (!Array.isArray(bindings) || bindings.some(binding => binding.HostIp !== '127.0.0.1')) fail('Preview PB must only bind loopback');
  }
  return item;
}
function shellLiteral(value) { return "'" + String(value).replaceAll("'", "'\\''") + "'"; }
function bootstrapSuperuser(value, identity, password, running) {
  const line = ['/pb/pocketbase', 'superuser', 'upsert', identity, password, ...runtime].map(shellLiteral).join(' ') + '\n';
  // Secrets travel on stdin, not Docker argv/ExecConfig or persistent files.
  if (running) { containerInfo(value); exec('docker', ['exec', '-i', value.container, '/bin/sh', '-s'], line); }
  else exec('docker', ['run', '--rm', '--network=none', ...mounts(), '--entrypoint', '/bin/sh', value.imageId, '-s'], line);
}
async function api(base, route, { token, body, method = body === undefined ? 'GET' : 'POST' } = {}) {
  const response = await fetch(base + route, { method, headers: { Accept: 'application/json',
    ...(token ? { Authorization: token } : {}), ...(body === undefined ? {} : { 'Content-Type': 'application/json' }) },
  ...(body === undefined ? {} : { body: JSON.stringify(body) }), signal: AbortSignal.timeout(20000), redirect: 'manual' });
  const parsed = response.status === 204 ? null : await response.json();
  if (response.status !== 200 && response.status !== 204) fail('Preview API rejected ' + method + ' ' + route.replace(/[a-z0-9]{15}/g, '<owned-record>') + ' HTTP' + response.status);
  return parsed;
}
async function playerLogin(base, password) {
  const authenticated = await api(base, '/api/collections/game_players/auth-with-password', { body: { identity: account, password } });
  const player = await api(base, '/api/questions/v1/me', { token: authenticated.token });
  return { token: authenticated.token, player };
}
async function loginStatus(base, value) {
  try {
    const credential = await json(loginFile);
    const { player } = await playerLogin(base, credential.password);
    if (credential.account !== account || player.id !== value.playerId || player.mustChangePassword !== false) fail('Saved login does not identify the ordinary preview player');
    return 'verified_direct_login';
  } catch { return 'saved_login_rejected_or_unavailable_use_own_changed_password_or_explicit_reset_login'; }
}
async function withAdmin(value, base, callback, bootstrap) {
  const email = bootstrap?.email || 'preview-' + randomBytes(12).toString('hex') + '@example.test';
  const password = bootstrap?.password || secret();
  if (!bootstrap) bootstrapSuperuser(value, email, password, true);
  const auth = await api(base, '/api/collections/_superusers/auth-with-password', { body: { identity: email, password } });
  const adminAccount = 'preview_' + randomBytes(8).toString('hex');
  const adminPassword = secret();
  let adminId;
  try {
    const created = await api(base, '/api/collections/game_admins/records', { token: auth.token,
      body: { account: adminAccount, displayName: '隔离预览初始化', status: 'active', password: adminPassword, passwordConfirm: adminPassword } });
    adminId = created.id;
    const admin = await api(base, '/api/collections/game_admins/auth-with-password', { body: { identity: adminAccount, password: adminPassword } });
    return await callback(admin.token);
  } finally {
    // Audit rows/assignments retain required actor relations. Disable this exact
    // temporary admin and revoke its password, instead of deleting audit facts.
    if (adminId) {
      const discarded = secret();
      await api(base, '/api/collections/game_admins/records/' + adminId, { token: auth.token, method: 'PATCH',
        body: { status: 'disabled', password: discarded, passwordConfirm: discarded } });
    }
    await api(base, '/api/collections/_superusers/records/' + auth.record.id, { token: auth.token, method: 'DELETE' });
  }
}
async function seed(value, base, bootstrap) {
  const credential = await json(loginFile);
  await withAdmin(value, base, async token => {
    const admin = (route, body = {}) => api(base, '/api/questions/v1/admin/' + route, { token, body: { requestId: randomUUID(), ...body } });
    const initialPassword = secret();
    const player = await admin('players', { account, displayName: '远航审阅者', password: initialPassword });
    value.playerId = player.id;
    const catalog = await api(base, '/api/questions/v1/admin/catalog', { token });
    const ranks = catalog.ranks || catalog.levels;
    if (!Array.isArray(ranks) || ranks.length < 2) fail('Real preview rank catalog is missing');
    const question = await admin('questions', { title: '预览星辰之门', kind: 'text',
      content: [{ text: '这是专用隔离预览场次，展示已迁移的原生业务。' }], options: [], acceptedAnswers: ['星辰大海'], placeholder: '输入你的答案' });
    await admin('questions/' + question.id + '/publish');
    value.assignments = {};
    const now = Date.now();
    for (const [kind, title, minLevel, timing] of [
      ['ready', '星辰探险', '', {}],
      ['waiting', '静候启程', '', { startsAt: new Date(now + 14 * 86400000).toISOString(), endsAt: new Date(now + 30 * 86400000).toISOString() }],
      ['expired', '已过开放时间', '', { endsAt: new Date(now - 86400000).toISOString() }],
      ['locked', '等级暂不符合', ranks[1].id, {}]
    ]) {
      const session = await admin('sessions', { title, description: '解开谜题，发现惊喜。', minLevel,
        levels: [{ question: question.id, xp: 50 }], clues: [], rewardRules: [], presentation: { bgmMode: 'silent', completionStyle: 'normal' } });
      await admin('sessions/' + session.id + '/publish');
      const assigned = await admin('assignments', { sessionId: session.id, target: 'selected', playerIds: [player.id],
        order: kind === 'ready' ? 0 : 10, ...timing });
      const result = assigned.results?.find(row => row.playerId === player.id);
      if (!result?.assignmentId) fail('Preview assignment did not identify the sole preview player');
      value.assignments[kind] = { assignmentId: result.assignmentId, sessionId: session.id };
    }
    // The genuine first-password flow happens once in setup. The reviewer never sees that gate.
    const first = await playerLogin(base, initialPassword);
    const changed = await api(base, '/api/questions/v1/me/change-password', { token: first.token,
      body: { oldPassword: initialPassword, password: credential.password, passwordConfirm: credential.password } });
    if (changed.player?.id !== player.id || changed.player.mustChangePassword !== false) fail('Preview first-password setup was not confirmed');
  }, bootstrap);
  value.initialized = true;
  value.initializationStatus = 'complete';
  value.initializedAt = new Date().toISOString();
  await save(manifestFile, value);
  credential.initializedAt = value.initializedAt;
  credential.note = '专用隔离预览已完成首次初始化，可直接登录。仅用于本人审查；请勿用于故障注入或自动改密验收。自己改密后，工具不会静默改回旧密码。';
  await save(loginFile, credential);
}
async function renewLeaf() {
  const ca = new X509Certificate(await readFile(caFile));
  if (!ca.ca || Date.parse(ca.validFrom) > Date.now() || Date.parse(ca.validTo) <= Date.now() + 2 * 86400000) {
    fail('Preview CA is expired or nearing expiry; explicit CA replacement and app reinstall are required');
  }
  if (await exists(serverCert)) {
    const leaf = new X509Certificate(await readFile(serverCert));
    if (Date.parse(leaf.validTo) > Date.now() + 2 * 86400000) {
      exec(openssl, ['verify', '-CAfile', caFile, '-verify_ip', '127.0.0.1', serverCert]);
      return;
    }
  }
  exec(openssl, ['genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256', '-out', serverKey]);
  const csr = path.join(tls, 'server.csr'), extension = path.join(tls, 'server.ext');
  exec(openssl, ['req', '-new', '-key', serverKey, '-out', csr, '-subj', '/CN=127.0.0.1']);
  await writeFile(extension, 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\nsubjectAltName=IP:127.0.0.1\n', { mode: 0o600 });
  exec(openssl, ['x509', '-req', '-in', csr, '-CA', caFile, '-CAkey', caKey, '-CAcreateserial', '-days', '14', '-sha256', '-extfile', extension, '-out', serverCert]);
  await chmod(serverKey, 0o600); await chmod(serverCert, 0o600);
  await rm(csr); await rm(extension);
}
async function prepare() {
  if (await exists(manifestFile)) { await manifest(); console.log(JSON.stringify({ prepared: true, reused: true, credentialsPrinted: false })); return; }
  if (await exists(home)) {
    const directory = await lstat(home);
    if (!directory.isDirectory() || directory.isSymbolicLink() || (directory.mode & 0o077)) fail('Preview directory must be a real private mode700 directory');
    const entries = await readdir(home);
    if (entries.some(name => name !== 'runner.log')) fail('Unowned or incomplete preview directory exists; no files replaced');
  }
  // Explicit cwd is needed here; other commands never run in the sibling checkout.
  const git = args => {
    const result = spawnSync('git', ['-C', path.dirname(backend), ...args], { encoding: 'utf8', stdio: 'pipe' });
    if (result.status !== 0) fail('Frozen backend Git inspection failed');
    return result.stdout.trim();
  };
  if (git(['status', '--porcelain'])) fail('Preview requires the unchanged frozen backend checkout');
  await mkdir(home, { recursive: true, mode: 0o700 }); await chmod(home, 0o700);
  await mkdir(snapshot, { mode: 0o700 }); await mkdir(data, { mode: 0o700 }); await mkdir(tls, { mode: 0o700 });
  await cp(path.join(backend, 'pb_hooks'), path.join(snapshot, 'pb_hooks'), { recursive: true, errorOnExist: true, force: false });
  await cp(path.join(backend, 'pb_migrations'), path.join(snapshot, 'pb_migrations'), { recursive: true, errorOnExist: true, force: false });
  const imageId = exec('docker', ['image', 'inspect', '--format', '{{.Id}}', image]).trim();
  if (!/^sha256:[a-f0-9]{64}$/.test(imageId)) fail('The verified own PB image must already be prepared');
  if (!exec('docker', ['run', '--rm', '--network=none', imageId, '--version']).includes(' ' + version)) fail('Unexpected preview PB runtime');
  exec(openssl, ['genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256', '-out', caKey]);
  exec(openssl, ['req', '-new', '-x509', '-sha256', '-days', '365', '-key', caKey, '-out', caFile,
    '-subj', '/CN=Starward dedicated local preview CA', '-addext', 'basicConstraints=critical,CA:TRUE,pathlen:0', '-addext', 'keyUsage=critical,keyCertSign,cRLSign']);
  await chmod(caKey, 0o600); await chmod(caFile, 0o600);
  const owner = randomUUID();
  const value = { schema: 1, owner, mode: 'persistent isolated player preview', account,
    container: 'starward-hm-preview-' + owner, image, imageId, version, backendSourceCommit: git(['rev-parse', 'HEAD']),
    sourceHashes: await hashes(snapshot), caSha256: digest(await readFile(caFile)), initialized: false,
    initializationStatus: 'prepared', preparedAt: new Date().toISOString() };
  await save(loginFile, { environment: '专用隔离预览环境', account, password: secret(), endpoint,
    note: '请先启动预览并确认status为verified_direct_login；初始化完成后可直接登录。仅用于本人审查，请勿用于故障注入或自动改密验收。自己改密后，工具不会静默改回旧密码。' });
  await save(manifestFile, value); await renewLeaf();
  console.log(JSON.stringify({ prepared: true, serviceStarted: false, credentialsPrinted: false,
    privateLoginFile: path.relative(root, loginFile), packageConfigurationChanged: false }));
}
function permitted(method, pathname) {
  return (method === 'GET' && ['/api/health', '/api/questions/v1/me', '/api/questions/v1/notifications', '/api/questions/v1/rewards', '/api/questions/v1/assignments'].includes(pathname)) ||
    (method === 'GET' && /^\/api\/questions\/v1\/assignments\/[a-z0-9]{15}$/.test(pathname)) ||
    (method === 'GET' && /^\/api\/files\/game_players\/[a-z0-9]{15}\/[a-zA-Z0-9._%-]+$/.test(pathname)) ||
    (method === 'POST' && ['/api/collections/game_players/auth-with-password', '/api/questions/v1/me/change-password', '/api/files/token'].includes(pathname)) ||
    (method === 'PATCH' && pathname === '/api/questions/v1/me/profile');
}
function response(res, status, value) {
  if (!res.destroyed && !res.writableEnded) { res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(value)); }
}
async function requestBytes(req, maximum = 2500000) {
  const chunks = []; let size = 0;
  for await (const chunk of req) { size += chunk.length; if (size > maximum) fail('Preview request is too large'); chunks.push(chunk); }
  return Buffer.concat(chunks);
}
function forwards() {
  return exec('hdc', ['fport', 'ls']).split(/\r?\n/).filter(Boolean).map(line => line.trim().split(/\s+/));
}
function soleDevice() {
  const rows = exec('hdc', ['list', 'targets']).trim().split(/\r?\n/).filter(line => line && !line.includes('[Empty]'));
  if (rows.length !== 1 || /\s/.test(rows[0])) fail('Preview requires exactly one connected phone; no device identifier is printed');
  return rows[0];
}
function attach(hostPort) {
  const device = soleDevice();
  const rows = forwards().filter(row => row[1] === 'tcp:' + devicePort);
  if (rows.length && (rows.length !== 1 || rows[0][0] !== device || rows[0][2] !== 'tcp:' + hostPort || rows[0][3] !== '[Reverse]')) {
    fail('Device preview port is occupied; the existing acceptance or other mapping was not changed');
  }
  if (!rows.length) exec('hdc', ['-t', device, 'rport', 'tcp:' + devicePort, 'tcp:' + hostPort]);
  const after = forwards().filter(row => row[0] === device && row[1] === 'tcp:' + devicePort && row[2] === 'tcp:' + hostPort && row[3] === '[Reverse]');
  if (after.length !== 1) fail('Official preview USB reverse forwarding was not confirmed');
}
function detach(hostPort) {
  const rows = forwards().filter(row => row[1] === 'tcp:' + devicePort && row[2] === 'tcp:' + hostPort && row[3] === '[Reverse]');
  if (rows.length > 1) fail('Preview reverse-forward ownership is ambiguous');
  if (rows.length) exec('hdc', ['-t', rows[0][0], 'fport', 'rm', 'tcp:' + devicePort, 'tcp:' + hostPort]);
}
async function control(run, route) {
  const response = await fetch(run.controlBase + route, { method: 'POST', headers: { Authorization: run.controlToken }, signal: AbortSignal.timeout(route === '/reset-login' ? 60000 : 4000) });
  const result = await response.json();
  if (!response.ok) fail('The exact preview control refused the operation');
  if (result.owner !== run.owner) fail('Preview control owner changed');
  return result;
}
async function ownedRun(value) {
  const run = await json(runFile);
  if (run.owner !== value.owner || run.mode !== value.mode || !Number.isInteger(run.pid) ||
      !/^http:\/\/127\.0\.0\.1:[0-9]+$/.test(run.controlBase) || !/^https:\/\/127\.0\.0\.1:[0-9]+$/.test(run.hostBase) ||
      run.hostBase !== 'https://127.0.0.1:' + run.hostPort || typeof run.controlToken !== 'string') fail('Preview runtime receipt is invalid');
  const command = exec('ps', ['-p', String(run.pid), '-o', 'command=']).trim();
  const uid = Number(exec('ps', ['-p', String(run.pid), '-o', 'uid=']).trim());
  const birth = exec('ps', ['-p', String(run.pid), '-o', 'lstart=']).trim();
  const workingDirectory = exec('lsof', ['-a', '-p', String(run.pid), '-d', 'cwd', '-Fn']).trim().split(/\r?\n/).filter(line => line.startsWith('n'));
  if (typeof run.nodeExecutable !== 'string' || command !== run.nodeExecutable + ' ' + script + ' serve' ||
      uid !== process.getuid() || uid !== run.uid || birth !== run.processBirth ||
      workingDirectory.length !== 1 || workingDirectory[0] !== 'n' + root) fail('Recorded preview UID/argv/cwd/process birth no longer identifies this runner');
  for (const port of [run.hostPort, Number(new URL(run.controlBase).port)]) {
    const listener = exec('lsof', ['-nP', '-a', '-p', String(run.pid), '-iTCP:' + port, '-sTCP:LISTEN', '-Fpn']).trim().split(/\r?\n/);
    if (!listener.includes('p' + run.pid) || !listener.includes('n127.0.0.1:' + port)) fail('Preview loopback listener no longer belongs to this exact runner');
  }
  containerInfo(value);
  await control(run, '/status');
  return run;
}
async function strictTls(hostPort) {
  const ca = await readFile(caFile);
  const attempt = options => new Promise(resolve => {
    const req = https.get({ hostname: '127.0.0.1', port: hostPort, path: '/api/health', ...options }, res => { res.resume(); res.on('end', () => resolve({ status: res.statusCode })); });
    req.on('error', error => resolve({ code: error.code })); req.setTimeout(4000, () => req.destroy());
  });
  const [positive, untrusted, wrongName] = await Promise.all([attempt({ ca }), attempt({}), attempt({ ca, servername: 'localhost' })]);
  if (positive.status !== 200 || !['UNABLE_TO_VERIFY_LEAF_SIGNATURE', 'SELF_SIGNED_CERT_IN_CHAIN', 'DEPTH_ZERO_SELF_SIGNED_CERT'].includes(untrusted.code) ||
      wrongName.code !== 'ERR_TLS_CERT_ALTNAME_INVALID') fail('Preview strict TLS positive/negative checks failed');
  return { positive200: true, untrustedRejected: true, untrustedError: untrusted.code,
    wrongHostnameRejected: true, wrongHostnameError: wrongName.code, systemTrustChanged: false };
}
async function serve() {
  let value = await manifest();
  await acquireLock(value);
  if (await exists(runFile)) {
    try { await ownedRun(value); fail('Preview is already running'); } catch (error) {
      const recorded = await json(runFile);
      try { process.kill(recorded.pid, 0); fail('An existing preview PID is active; no process replaced'); }
      catch (cause) { if (cause.code !== 'ESRCH') throw cause; }
      if (containerInfo(value, true)) fail('Recorded preview container remains; explicit owner review is required');
      await rm(runFile);
    }
  }
  if (containerInfo(value, true)) fail('A container remains; explicit owner review is required');
  if (forwards().some(row => row[1] === 'tcp:' + devicePort)) fail('Device18443 is occupied; acceptance environment was not touched');
  soleDevice(); await renewLeaf();
  exec('docker', ['run', '--rm', '--network=none', ...mounts(), value.imageId, 'migrate', 'up', ...runtime]);
  let bootstrap;
  if (!value.initialized) {
    if (value.initializationStatus !== 'prepared') fail('Preview initialization previously stopped; refusing to replay seed writes or reset the fixed account');
    value.initializationStatus = 'initializing';
    await save(manifestFile, value);
    bootstrap = { email: 'preview-' + randomBytes(12).toString('hex') + '@example.test', password: secret() };
    bootstrapSuperuser(value, bootstrap.email, bootstrap.password, false);
  }
  const containerId = exec('docker', ['create', '--rm', '--name', value.container, '--label', 'com.sitkin.starward.preview=' + value.owner,
    '-p', '127.0.0.1::8090', '--cap-drop=ALL', '--security-opt=no-new-privileges', ...mounts(), value.imageId,
    'serve', '--http=0.0.0.0:8090', ...runtime]).trim();
  if (!/^[a-f0-9]{64}$/.test(containerId) || containerInfo(value).Id !== containerId) fail('New preview container identity was not confirmed');
  const child = spawn('docker', ['start', '-a', containerId], { stdio: ['ignore', 'ignore', 'ignore'] });
  let spawnFailed = false;
  child.on('error', () => { spawnFailed = true; });
  let gateway, local, run, stopping = false, forwarded = false, resetBusy = false;
  const stop = async () => {
    if (stopping) return; stopping = true;
    local?.close(); gateway?.close();
    if (forwarded && run) detach(run.hostPort);
    const current = containerInfo(value, true);
    if (current) {
      if (current.Id !== containerId) fail('Preview container identity changed; replacement was not stopped');
      if (current.State.Running) exec('docker', ['stop', '--time=5', containerId]);
      else exec('docker', ['rm', containerId]);
    }
    if (await exists(runFile) && (await json(runFile)).pid === process.pid) await rm(runFile);
    await releaseLock();
    console.log(JSON.stringify({ stopped: true, persistentDatabaseAndCaPreserved: true }));
  };
  process.on('SIGTERM', () => { void stop().then(() => process.exit(0)); });
  process.on('SIGINT', () => { void stop().then(() => process.exit(0)); });
  try {
    let backendBase;
    const deadline = Date.now() + 120000;
    while (Date.now() < deadline) {
      if (spawnFailed || child.exitCode !== null) fail('Preview PB exited before readiness; no private server logs exposed');
      const info = containerInfo(value, true);
      const port = info?.NetworkSettings.Ports?.['8090/tcp']?.[0]?.HostPort;
      if (port) {
        backendBase = 'http://127.0.0.1:' + port;
        try { if ((await fetch(backendBase + '/api/health', { signal: AbortSignal.timeout(1500) })).ok) break; } catch {}
      }
      await delay(150);
    }
    if (!backendBase || !(await fetch(backendBase + '/api/health', { signal: AbortSignal.timeout(1500) })).ok) fail('Preview PB readiness deadline exceeded');
    if (!value.initialized) await seed(value, backendBase, bootstrap);
    value = await manifest();
    const loginValidation = await loginStatus(backendBase, value);
    gateway = https.createServer({ key: await readFile(serverKey), cert: await readFile(serverCert), minVersion: 'TLSv1.2' }, async (req, res) => {
      req.on('error', () => {}); res.on('error', () => {});
      try {
        const url = new URL(req.url, endpoint);
        const origin = req.headers.origin;
        if (origin && !/^http:\/\/(localhost|127\.0\.0\.1)(:[0-9]+)?$/.test(origin)) { response(res, 403, { error: { code: 'ORIGIN_DENIED', message: '隔离预览来源受限' } }); return; }
        if (origin) { res.setHeader('Access-Control-Allow-Origin', origin); res.setHeader('Vary', 'Origin'); res.setHeader('Access-Control-Allow-Headers', 'Authorization,Content-Type,Accept'); res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,OPTIONS'); }
        if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }
        if (!permitted(req.method, url.pathname)) { response(res, 404, { error: { code: 'NOT_FOUND', message: '专用预览仅提供玩家接口' } }); return; }
        const body = await requestBytes(req);
        const upstream = await fetch(backendBase + url.pathname + url.search, { method: req.method, headers: {
          Accept: req.headers.accept || 'application/json', ...(req.headers.authorization ? { Authorization: req.headers.authorization } : {}),
          ...(req.headers['content-type'] ? { 'Content-Type': req.headers['content-type'] } : {}) },
        ...(req.method === 'GET' ? {} : { body }), redirect: 'manual', signal: AbortSignal.timeout(30000) });
        const bytes = Buffer.from(await upstream.arrayBuffer());
        if (bytes.length > 4 * 1024 * 1024) fail('Preview upstream response exceeds its bound');
        res.writeHead(upstream.status, { 'Content-Type': upstream.headers.get('content-type') || 'application/json', 'Cache-Control': 'no-store' }); res.end(bytes);
      } catch { response(res, 502, { error: { code: 'PREVIEW_UNAVAILABLE', message: '隔离预览暂时不可达，请重试。' } }); }
    });
    gateway.on('clientError', (_error, socket) => socket.destroy());
    gateway.on('tlsClientError', () => {});
    await new Promise((resolve, reject) => { gateway.once('error', reject); gateway.listen(0, '127.0.0.1', resolve); });
    const hostPort = gateway.address().port;
    run = { owner: value.owner, mode: value.mode, pid: process.pid, uid: process.getuid(), nodeExecutable: process.execPath,
      processBirth: exec('ps', ['-p', String(process.pid), '-o', 'lstart=']).trim(), backendBase, hostPort, hostBase: 'https://127.0.0.1:' + hostPort,
      controlBase: '', controlToken: secret(), startedAt: new Date().toISOString(), loginValidation };
    const tlsChecks = await strictTls(hostPort);
    local = http.createServer(async (req, res) => {
      if (req.method !== 'POST' || req.headers.authorization !== run.controlToken) { response(res, 403, { error: 'Preview control denied' }); return; }
      try {
        if (req.url === '/status') { response(res, 200, { owner: value.owner, running: true, loginValidation: await loginStatus(backendBase, value) }); return; }
        if (req.url === '/stop') { response(res, 200, { owner: value.owner, stopping: true }); setTimeout(() => { void stop().then(() => process.exit(0)); }, 100); return; }
        if (req.url === '/reset-login') {
          if (resetBusy) { response(res, 409, { error: 'An explicit preview password reset is already in progress' }); return; }
          resetBusy = true;
          try {
          const next = secret(), initial = secret();
          await withAdmin(value, backendBase, async token => {
            await api(backendBase, '/api/questions/v1/admin/players/' + value.playerId + '/actions', { token,
              body: { requestId: randomUUID(), action: 'reset_password', password: initial, reason: '本人显式重置专用隔离预览登录，不属于故障验收' } });
            const authenticated = await playerLogin(backendBase, initial);
            const changed = await api(backendBase, '/api/questions/v1/me/change-password', { token: authenticated.token,
              body: { oldPassword: initial, password: next, passwordConfirm: next } });
            if (changed.player?.id !== value.playerId || changed.player.mustChangePassword !== false) fail('Explicit preview password reset was not confirmed');
            const verified = await playerLogin(backendBase, next);
            if (verified.player.id !== value.playerId || verified.player.mustChangePassword !== false) fail('New preview login was not verified');
            const credential = await json(loginFile); credential.password = next; credential.resetAt = new Date().toISOString(); await save(loginFile, credential);
          });
          response(res, 200, { owner: value.owner, reset: true, directLoginVerified: true, credentialsPrinted: false }); return;
          } finally { resetBusy = false; }
        }
        response(res, 404, { error: 'No test reset, fault injection or general admin control exists' });
      } catch { response(res, 409, { error: 'Explicit preview operation did not fully complete; review status and the private local login file before another command' }); }
    });
    await new Promise((resolve, reject) => { local.once('error', reject); local.listen(0, '127.0.0.1', resolve); });
    run.controlBase = 'http://127.0.0.1:' + local.address().port;
    attach(hostPort); forwarded = true;
    await save(runFile, run);
    const report = { status: loginValidation === 'verified_direct_login' ? 'host_ready_native_pending' : 'host_ready_saved_login_needs_review',
      mode: value.mode, account, credentialStorage: 'Ignored local mode600 login.json; credentials and app sessions never embedded in HAP',
      sourceCommit: value.backendSourceCommit, sourceSnapshotSha256: digest(Buffer.from(JSON.stringify(value.sourceHashes))), version,
      initializedOnce: true, directLoginValidation: loginValidation, transport: endpoint, tlsChecks,
      caSha256: value.caSha256, caDays: 365, leafDays: 14, serverLeafRenewalPreservesCa: true,
      faultOrResetApiExposedToPlayer: false, playerOnlyProxy: true, databasePersistsAcrossStop: true,
      acceptance: 'Host preparation/readiness only; root must separately build/install and verify native login and preview', startedAt: run.startedAt };
    await mkdir(path.dirname(reportFile), { recursive: true }); await writeFile(reportFile, JSON.stringify(report, null, 2) + '\n');
    console.log(JSON.stringify({ ready: true, directLoginValidation: loginValidation, privateLoginFile: path.relative(root, loginFile), report: path.relative(root, reportFile), credentialsPrinted: false }));
    child.once('exit', () => { if (!stopping) { void stop().then(() => process.exit(1)); } });
  } catch (error) { await stop(); throw error; }
}
async function start() {
  const value = await manifest();
  if (await exists(runFile)) {
    try { const run = await ownedRun(value); console.log(JSON.stringify({ running: true, ...(await control(run, '/status')), credentialsPrinted: false })); return; }
    catch { /* serve performs the strict stale-owner/container checks; never kill a PID here. */ }
  }
  const logFile = path.join(home, 'runner.log');
  if (await exists(logFile)) await regular(logFile);
  const log = await open(logFile, 'a', 0o600);
  const child = spawn(process.execPath, [script, 'serve'], { detached: true, stdio: ['ignore', log.fd, log.fd] });
  let spawnFailed = false;
  child.on('error', () => { spawnFailed = true; });
  await log.close(); child.unref();
  const deadline = Date.now() + 180000;
  while (Date.now() < deadline) {
    if (await exists(runFile)) {
      const run = await json(runFile);
      if (run.pid === child.pid) { await ownedRun(value); console.log(JSON.stringify({ ready: true, privateLoginFile: path.relative(root, loginFile), credentialsPrinted: false })); return; }
    }
    if (spawnFailed || !child.pid) fail('Preview runner could not start');
    try { process.kill(child.pid, 0); } catch { fail('Preview runner stopped before readiness; inspect its private safe-event log'); }
    await delay(250);
  }
  fail('Preview startup has not completed; inspect status before another start');
}
async function configure() {
  const value = await manifest(); await ownedRun(value);
  const target = path.join(root, 'entry/src/main/resources/rawfile/integration.json');
  const caTarget = path.join(path.dirname(target), 'integration-ca.pem');
  if (await exists(target)) {
    const previous = JSON.parse(await readFile(target, 'utf8'));
    if (previous.endpoint !== endpoint || !await exists(caTarget) || digest(await readFile(caTarget)) !== value.caSha256) {
      fail('An existing integration config belongs to another environment; root must explicitly finish and remove it first');
    }
  }
  await mkdir(path.dirname(target), { recursive: true });
  await writeFile(caTarget, await readFile(caFile), { mode: 0o600 });
  await writeFile(target, JSON.stringify({ isolated: true, endpoint, timeoutMs: 15000, probeTls: true, fontScale: 1 }) + '\n', { mode: 0o600 });
  console.log(JSON.stringify({ configured: true, requiresOfficialBuildInstallAndNativeVerification: true, credentialsEmbedded: false }));
}

const help = `Usage: preview-environment.mjs prepare|start|status|attach|configure|stop|reset-login

prepare    Freeze unchanged backend hooks/migrations, existing verified PB image and a new independent persistent CA/login.
start      Start or reuse ONLY this persistent preview runner; requires one phone and free official USB18443.
status     Inspect exact owner and validate the saved direct login. A user's changed password is never silently reset.
attach     Reattach this exact live preview after reconnecting the phone; refuses any occupied unrelated mapping.
configure  Explicitly package only its public CA/endpoint; refuses another active build config. Root builds/installs separately.
stop       Stop only the verified preview owner/container/mapping. Persistent database, CA and fixed login remain.
reset-login Explicitly reset ONLY the preview player's password through real admin/player flows and update private login.json.

Private credentials: artifacts/private/profile-preview/login.json (mode600). No password/token is printed.
Acceptance and preview have separate DB/state; this tool has no fault injector or production endpoint.
The app still keeps login sessions only in memory. CA replacement after expiry requires app reinstall.
`;
try {
  if (['help', '--help', '-h'].includes(operation)) console.log(help);
  else if (operation === 'prepare') await prepare();
  else if (operation === 'start') await start();
  else if (operation === 'serve') await serve();
  else if (operation === 'configure') await configure();
  else if (['status', 'attach', 'stop', 'reset-login'].includes(operation)) {
    const value = await manifest(); const run = await ownedRun(value);
    if (operation === 'attach') { attach(run.hostPort); console.log(JSON.stringify({ attached: true, credentialsPrinted: false })); }
    else console.log(JSON.stringify({ ...(await control(run, '/' + operation)), credentialsPrinted: false }));
  } else fail('Unknown preview operation; use --help');
} catch (error) {
  try { await releaseLock(); } catch { /* An unknown lock is deliberately preserved. */ }
  console.error(JSON.stringify({ status: 'stopped_or_not_ready',
    error: error instanceof PreviewFailure ? error.message : 'Preview operation stopped; private details and values omitted', credentialsPrinted: false }));
  process.exitCode = 1;
}

#!/usr/bin/env node
/** Real PocketBase in a disposable Docker database; player-only proxy for TLS tunnelling. */
import { createServer } from 'node:http';
import { spawnSync } from 'node:child_process';
import { cp, mkdir, readFile, writeFile, chmod, rm, lstat, rename } from 'node:fs/promises';
import { createHash, randomBytes, randomUUID, X509Certificate } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { prepareIsolationHarness } from './prepare-isolation-harness.mjs';
import { createUiContentCases } from './ui-content-case.mjs';
import { createUiImageFailureCase } from './ui-image-failure-case.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const privateRoot = path.join(root, 'artifacts/private/https-isolation');
const stateFile = path.join(privateRoot, 'state.json');
const backend = path.resolve(process.env.STARWARD_BACKEND_SOURCE || path.join(root, '../sitkin-pb-backend-management/backend'));
const version = '0.40.1';
const sourceDir = path.join(privateRoot, 'source');
const image = 'starward-hm-isolation:pb-0.40.1-arm64';
const secret = () => 'Hm-' + randomBytes(20).toString('base64url');
const command = process.argv[2] || 'status';
const sha256 = value => createHash('sha256').update(value).digest('hex');
const validationRoot = path.join(root, 'artifacts/validation');
const evidenceDirectory = path.resolve(root, process.env.STARWARD_VALIDATION_DIR || 'artifacts/validation/profile');
if (evidenceDirectory !== validationRoot && !evidenceDirectory.startsWith(validationRoot + path.sep)) {
  throw new Error('Validation output must remain inside this project artifacts/validation');
}

function immutableImage() {
  const rows = JSON.parse(exec('docker', ['image', 'inspect', 'docker.io/library/' + image]));
  if (!Array.isArray(rows) || rows.length !== 1 || !/^sha256:[a-f0-9]{64}$/.test(rows[0].Id) ||
      rows[0].Architecture !== 'arm64' || !rows[0].RepoTags?.includes(image)) {
    throw new Error('The exact isolated PocketBase image/tag/architecture could not be established');
  }
  return rows[0].Id;
}

function exec(program, args, opts = {}) {
  const r = spawnSync(program, args, { encoding: 'utf8', stdio: 'pipe', ...opts });
  if (r.status !== 0) throw new Error(program + ' failed: ' + (r.stderr || r.stdout || r.error?.message || '').slice(-1200));
  return r.stdout;
}
async function save(value) {
  let current;
  try {
    const info = await lstat(stateFile);
    if (!info.isFile() || info.isSymbolicLink() || info.uid !== process.getuid() || (info.mode & 0o777) !== 0o600) {
      throw new Error('The existing disposable state is not an exact owned private file');
    }
    current = JSON.parse(await readFile(stateFile, 'utf8'));
  } catch (error) { if (error.code !== 'ENOENT') throw error; }
  if (current) {
    const identity = ['pid', 'backendBase', 'proxyBase', 'controlBase', 'controlToken', 'account',
      'playerId', 'assignmentId', 'version', 'mode', 'backendSourceCommit', 'imageId', 'sourceDirectory'];
    if (identity.some(key => current[key] !== value[key])) {
      throw new Error('The state now belongs to a different disposable runner; no fields merged');
    }
    // TLS writes its receipt after this backend has started. Merge only that
    // same-runner receipt so later case saves cannot erase it with stale state.
    // Conversely, an intentionally removed disk receipt must not be resurrected.
    if (current.tls !== undefined) {
      const tls = current.tls;
      if (!tls || typeof tls !== 'object' || tls.base !== 'https://127.0.0.1:18443' || tls.devicePort !== 18443 ||
          !Number.isInteger(tls.hostPort) || tls.hostPort < 1024 || tls.hostPort > 65535 ||
          tls.hostBase !== 'https://127.0.0.1:' + tls.hostPort || !Number.isInteger(tls.pid) || tls.pid <= 0 ||
          tls.caPath !== path.join(privateRoot, 'tls/ca.pem') ||
          tls.rawCaPath !== path.join(root, 'entry/src/main/resources/rawfile/integration-ca.pem') ||
          !/^[a-f0-9]{64}$/.test(tls.caSha256 || '')) {
        throw new Error('The same-runner TLS receipt has an invalid local identity');
      }
      const caInfo = await lstat(tls.caPath);
      if (!caInfo.isFile() || caInfo.isSymbolicLink() || caInfo.uid !== process.getuid() ||
          (caInfo.mode & 0o022) || sha256(await readFile(tls.caPath)) !== tls.caSha256) {
        throw new Error('The same-runner TLS public CA does not match its receipt');
      }
      value.tls = tls;
    } else delete value.tls;
  }
  const temporary = path.join(privateRoot, '.state-' + randomUUID() + '.tmp');
  await writeFile(temporary, JSON.stringify(value, null, 2) + '\n', { mode: 0o600, flag: 'wx' });
  await rename(temporary, stateFile);
  await chmod(stateFile, 0o600);
}
async function ownedPrivateFile(filename, exactMode) {
  const resolved = path.resolve(filename);
  if (!resolved.startsWith(privateRoot + path.sep)) throw new Error('Restart input escaped this disposable namespace');
  for (let current = resolved; current !== root; current = path.dirname(current)) {
    const info = await lstat(current);
    if (info.isSymbolicLink() || info.uid !== process.getuid() ||
        (current === resolved ? !info.isFile() || (exactMode === undefined ? !!(info.mode & 0o022) : (info.mode & 0o777) !== exactMode) : !info.isDirectory() || !!(info.mode & 0o022))) {
      throw new Error('Restart input is not an exact owned file in owned directories');
    }
  }
  return readFile(resolved);
}
function listenerPids(port) {
  const result = spawnSync('/usr/sbin/lsof', ['-nP', '-iTCP:' + port, '-sTCP:LISTEN', '-Fp'], { encoding: 'utf8' });
  if (![0, 1].includes(result.status) || result.stderr.trim()) throw new Error('Restart listener ownership could not be established');
  return [...new Set(result.stdout.split(/\r?\n/).filter(line => /^p[1-9][0-9]*$/.test(line)).map(line => Number(line.slice(1))))];
}
function exactLoopbackPort(base) {
  if (typeof base !== 'string' || !/^http:\/\/127\.0\.0\.1:[1-9][0-9]{3,4}$/.test(base)) throw new Error('Restart origin is not exact loopback');
  const port = Number(new URL(base).port);
  if (port < 1024 || port > 65535) throw new Error('Restart port is invalid');
  return port;
}
async function restartReceipt() {
  try { await lstat(stateFile); throw new Error('Disposable state still exists; stop its exact owned runner before starting'); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  if (!process.env.STARWARD_RESTART_STATE) return null;
  const filename = path.resolve(process.env.STARWARD_RESTART_STATE);
  if (filename === stateFile) throw new Error('Restart backup must be a separate private receipt');
  const old = JSON.parse((await ownedPrivateFile(filename, 0o600)).toString('utf8'));
  if (old.mode !== 'real isolated PocketBase' || old.version !== version || !Number.isInteger(old.pid) || old.pid <= 0 ||
      old.backendSourceCommit !== exec('git', ['rev-parse', 'HEAD'], { cwd: path.dirname(backend) }).trim()) {
    throw new Error('Restart backup does not identify this disposable backend');
  }
  try { process.kill(old.pid, 0); throw new Error('Previous backend process is still alive'); }
  catch (error) { if (error.code !== 'ESRCH') throw error; }
  const ports = { proxy: exactLoopbackPort(old.proxyBase), control: exactLoopbackPort(old.controlBase) };
  if (ports.proxy === ports.control || String(ports.proxy) !== process.env.STARWARD_PROXY_PORT ||
      String(ports.control) !== process.env.STARWARD_CONTROL_PORT || listenerPids(ports.proxy).length || listenerPids(ports.control).length) {
    throw new Error('Restart requires the exact two now-unoccupied previous ports');
  }
  const tls = old.tls;
  if (!tls || tls.responseGate !== undefined || tls.base !== 'https://127.0.0.1:18443' || tls.devicePort !== 18443 ||
      !Number.isInteger(tls.hostPort) || tls.hostPort < 1024 || tls.hostPort > 65535 ||
      tls.hostBase !== 'https://127.0.0.1:' + tls.hostPort || !Number.isInteger(tls.pid) || tls.pid <= 0 || tls.pid === old.pid ||
      tls.caPath !== path.join(privateRoot, 'tls/ca.pem') ||
      tls.rawCaPath !== path.join(root, 'entry/src/main/resources/rawfile/integration-ca.pem') ||
      !/^[a-f0-9]{64}$/.test(tls.caSha256 || '')) throw new Error('Restart TLS receipt is invalid or has an old-owner response gate');
  const ca = await ownedPrivateFile(tls.caPath);
  const raw = await readFile(tls.rawCaPath);
  const rawInfo = await lstat(tls.rawCaPath);
  if (!rawInfo.isFile() || rawInfo.isSymbolicLink() || rawInfo.uid !== process.getuid() || (rawInfo.mode & 0o022) ||
      sha256(ca) !== tls.caSha256 || sha256(raw) !== tls.caSha256) throw new Error('Restart CA bytes changed');
  const certificate = new X509Certificate(await ownedPrivateFile(path.join(privateRoot, 'tls/server.pem')));
  const authority = new X509Certificate(ca);
  if (certificate.fingerprint256 !== tls.fingerprint || certificate.checkIP('127.0.0.1') !== '127.0.0.1' ||
      !certificate.verify(authority.publicKey) || Date.parse(certificate.validFrom) > Date.now() ||
      Date.parse(authority.validFrom) > Date.now() || Date.parse(certificate.validTo) <= Date.now() + 300000 ||
      Date.parse(authority.validTo) <= Date.now() + 300000) throw new Error('Restart TLS certificate identity or validity changed');
  process.kill(tls.pid, 0);
  const uid = exec('ps', ['-p', String(tls.pid), '-o', 'uid=']).trim();
  const argv = exec('ps', ['-p', String(tls.pid), '-o', 'args=']).trim().split(/\s+/);
  const cwd = exec('/usr/sbin/lsof', ['-a', '-p', String(tls.pid), '-d', 'cwd', '-Fn']).split(/\r?\n/).filter(line => line.startsWith('n'));
  if (uid !== String(process.getuid()) || argv.length !== 3 || path.basename(argv[0]) !== 'node' ||
      path.resolve(root, argv[1]) !== path.join(root, 'scripts/isolated-tls.mjs') || !['start', 'resume'].includes(argv[2]) ||
      cwd.length !== 1 || cwd[0] !== 'n' + root || JSON.stringify(listenerPids(tls.hostPort)) !== JSON.stringify([tls.pid])) {
    throw new Error('Restart TLS process, cwd or sole listener ownership changed');
  }
  return { tls: structuredClone(tls), ports };
}
async function prepare() {
  await mkdir(privateRoot, { recursive: true, mode: 0o700 });
  await mkdir(path.join(sourceDir, 'deploy/runtime'), { recursive: true });
  await cp(path.join(backend, 'pb_hooks'), path.join(sourceDir, 'pb_hooks'), { recursive: true });
  await cp(path.join(backend, 'pb_migrations'), path.join(sourceDir, 'pb_migrations'), { recursive: true });
  await cp(path.join(backend, 'deploy/Dockerfile'), path.join(sourceDir, 'Dockerfile'));
  const hash = '8e15eb6080de5ae7fcf789ac963d5c3c9328a491d5f7a24eb13c93a2f4bae4f1';
  const archive = path.join(privateRoot, 'pocketbase-linux-arm64.zip');
  let bytes;
  try { bytes = await readFile(archive); } catch {}
  if (!bytes || createHash('sha256').update(bytes).digest('hex') !== hash) {
    const response = await fetch('https://github.com/pocketbase/pocketbase/releases/download/v0.40.1/pocketbase_0.40.1_linux_arm64.zip');
    if (!response.ok) throw new Error('Official runtime download HTTP ' + response.status);
    bytes = Buffer.from(await response.arrayBuffer());
    if (createHash('sha256').update(bytes).digest('hex') !== hash) throw new Error('Official runtime SHA256 mismatch');
    await writeFile(archive, bytes);
  }
  exec('unzip', ['-o', archive, 'pocketbase', '-d', path.join(sourceDir, 'deploy/runtime')]);
  await chmod(path.join(sourceDir, 'deploy/runtime/pocketbase'), 0o755);
  exec('docker', ['build', '--platform', 'linux/arm64', '-t', image, '-f', path.join(sourceDir, 'Dockerfile'), sourceDir]);
  if (!exec('docker', ['run', '--rm', '--network=none', immutableImage(), '--version']).includes(' ' + version)) throw new Error('Runtime version mismatch');
  console.log(JSON.stringify({ prepared: true, version, architecture: 'linux/arm64', source: 'frozen sibling backend; original files unchanged' }));
}
async function control(route, body = {}) {
  const state = JSON.parse(await readFile(stateFile, 'utf8'));
  const response = await fetch(state.controlBase + route, { method: 'POST', headers: { Authorization: state.controlToken, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || 'Local control failed');
  return result;
}
if (command === 'prepare') { await prepare(); process.exit(0); }
if (command === 'stop') { const state = JSON.parse(await readFile(stateFile, 'utf8')); process.kill(state.pid, 'SIGTERM'); console.log('Stopping only the disposable backend runner.'); process.exit(0); }
if (command === 'status') {
  try { const s = JSON.parse(await readFile(stateFile, 'utf8')); console.log(JSON.stringify({ running: !!(await fetch(s.proxyBase + '/api/health')).ok, proxyBase: s.proxyBase, controlBase: s.controlBase, stateFile })); }
  catch { console.log(JSON.stringify({ running: false })); }
  process.exit(0);
}
if (command === 'reset') { console.log(JSON.stringify(await control('/reset'))); process.exit(0); }
if (command === 'requests') { console.log(JSON.stringify(await control('/requests'))); process.exit(0); }
if (command === 'fault') { console.log(JSON.stringify(await control('/fault', JSON.parse(process.argv[3] || '{}')))); process.exit(0); }
if (command === 'player') { console.log(JSON.stringify(await control('/player', JSON.parse(process.argv[3] || '{}')))); process.exit(0); }
if (command === 'scenario') { console.log(JSON.stringify(await control('/scenario', JSON.parse(process.argv[3] || '{}')))); process.exit(0); }
if (command === 'new-case') { console.log(JSON.stringify(await control('/new-case', JSON.parse(process.argv[3] || '{}')))); process.exit(0); }
if (command === 'case-progress') { console.log(JSON.stringify(await control('/case-progress', JSON.parse(process.argv[3] || '{}')))); process.exit(0); }
if (command === 'case-cancel') { console.log(JSON.stringify(await control('/case-cancel', JSON.parse(process.argv[3] || '{}')))); process.exit(0); }
if (command !== 'start') throw new Error('Usage: isolated-backend.mjs prepare|start|status|stop|reset|requests|fault|player|scenario|new-case|case-progress|case-cancel');
await mkdir(privateRoot, { recursive: true, mode: 0o700 });
const preservedRestart = await restartReceipt();
const imageId = immutableImage();
process.env.PB_DOCKER_IMAGE = imageId;
process.env.TMPDIR = privateRoot;
const harness = await prepareIsolationHarness(backend, privateRoot, path.join(evidenceDirectory, 'environment-harness.json'));
const { createTestServer } = await import(harness.moduleUrl);
const server = await createTestServer();
let proxy, localControl, closing = false, fault = null, requests = [], caseCreationBusy = false;
const requestIdentities = new Map();
const state = { pid: process.pid, backendBase: server.base, proxyBase: '', controlBase: '', controlToken: secret(), account: 'hm_' + randomBytes(5).toString('hex'), initialPassword: secret(), newPassword: secret(), playerId: '', assignmentId: '', assignments: {}, version, mode: 'real isolated PocketBase', backendSourceCommit: exec('git', ['rev-parse', 'HEAD'], { cwd: path.dirname(backend) }).trim(), imageId, sourceDirectory: server.directory };
async function api(route, body, token = server.adminToken, method = body ? 'POST' : 'GET') {
  const result = await server.request(route, { token, body, method });
  if (result.status !== 200) throw new Error('Isolated setup ' + route + ' HTTP ' + result.status + ' ' + (result.data.error?.code || 'UNKNOWN'));
  return result.data;
}
async function admin(route, body = {}) { return api('/api/questions/v1/admin/' + route, { requestId: randomUUID(), ...body }); }
async function jsonBody(req) {
  const chunks = []; let size = 0;
  for await (const chunk of req) { size += chunk.length; if (size > 2500000) throw new Error('Request body too large'); chunks.push(chunk); }
  return Buffer.concat(chunks);
}
async function seed() {
  const catalog = await api('/api/questions/v1/admin/catalog');
  const ranks = catalog.ranks || catalog.levels;
  if (!Array.isArray(ranks)) throw new Error('Missing rank catalog');
  await admin('ranks', { levels: ranks.map((r, i) => ({ ...r, name: i === 0 ? '初见' : r.name })), reason: '隔离原生跨端验收资料' });
  const player = await admin('players', { account: state.account, displayName: '远航者', password: state.initialPassword });
  state.playerId = player.id;
  const q = await admin('questions', { title: '星辰之门', kind: 'text', content: [{ text: '这是隔离验收场次。请填写“星辰大海”。' }], options: [], acceptedAnswers: ['星辰大海'], placeholder: '输入你的答案' });
  await admin(`questions/${q.id}/publish`);
  const q2 = await admin('questions', { title: '守门人的选择', kind: 'choice', content: [{ text: '这是隔离验收场次。请选择“北极星”。' }], options: [{ key: 'A', text: '月亮' }, { key: 'B', text: '北极星' }], acceptedAnswers: ['B'] });
  await admin(`questions/${q2.id}/publish`);
  // Private fixture metadata only. Gameplay cases get genuinely new players
  // and assignments; the legacy reset never pretends to erase gameplay facts.
  state.gameplay = { schema: 1, phase: 'entry-snapshot', activeCaseId: '', cases: {}, minLevelId: ranks[1].id,
    answerProtocol: { version: 1, playerPostAnswers: true, ownSessionFixtures: true, readOnlyAnswerDiagnostics: true },
    questions: [{ kind: 'text', id: q.id, answer: '星辰大海' }, { kind: 'choice', id: q2.id, answer: 'B' }] };
  const now = Date.now();
  for (const [kind, title, timing, minLevel] of [
    ['ready', '星辰探险', {}, ''],
    ['waiting', '静候启程', { startsAt: new Date(now + 86400000).toISOString(), endsAt: new Date(now + 172800000).toISOString() }, ''],
    ['expired', '已过开放时间', { endsAt: new Date(now - 86400000).toISOString() }, ''],
    ['locked', '等级暂不符合', {}, ranks[1].id],
  ]) {
    const session = await admin('sessions', { title, description: '解开谜题，发现惊喜。', minLevel, levels: [{ question: q.id, xp: 50 }, { question: q2.id, xp: 50 }], clues: [], rewardRules: [], presentation: { bgmMode: 'silent', completionStyle: 'normal' } });
    await admin(`sessions/${session.id}/publish`);
    const result = await admin('assignments', { sessionId: session.id, target: 'selected', playerIds: [player.id], order: kind === 'ready' ? 0 : 10, ...timing });
    const assignment = result.results.find(r => r.playerId === player.id);
    state.assignments[kind] = { assignmentId: assignment.assignmentId, sessionId: session.id };
  }
  state.assignmentId = state.assignments.ready.assignmentId;
  const secondary = await admin('players', { account: 'hm_' + randomBytes(5).toString('hex'), displayName: '另一位测试玩家', password: secret() });
  state.otherPlayerId = secondary.id;
}
async function newGameplayCase(input) {
  if (caseCreationBusy || Object.keys(state.gameplay.cases).length >= 24) throw new Error('Gameplay case creation is busy or exhausted');
  const label = input.label || 'entry';
  if (!/^[a-z][a-z0-9-]{0,39}$/.test(label)) throw new Error('Gameplay case label must be a short synthetic identifier');
  const fixture = input.fixture || 'manual';
  if (!['manual', 'auto-next', 'choice-cooldown', 'choice-lock', 'single-normal'].includes(fixture)) throw new Error('Unknown owned gameplay fixture');
  const [text, choice] = state.gameplay.questions;
  const levels = fixture === 'choice-cooldown' ? [{ question: choice.id, xp: 50, penaltyPolicy: [{ type: 'cooldown', seconds: 12 }] }] :
    fixture === 'choice-lock' ? [{ question: choice.id, xp: 50, penaltyPolicy: [{ type: 'lock' }] }] :
    fixture === 'single-normal' ? [{ question: text.id, xp: 50, autoNext: false }] :
    [{ question: text.id, xp: 50, autoNext: fixture === 'auto-next' }, { question: choice.id, xp: 50, autoNext: false }];
  caseCreationBusy = true;
  try {
    const caseId = randomBytes(8).toString('hex');
    const value = { caseId, label, fixture, fixtureLevelKinds: levels.map(row => row.question === text.id ? 'text' : 'choice'),
      cooldownSeconds: fixture === 'choice-cooldown' ? 12 : 0, account: 'hm_' + randomBytes(6).toString('hex'), initialPassword: secret(),
      newPassword: secret(), playerId: '', assignments: {}, setupStatus: 'creating', ordinaryLoginPrepared: false };
    // Record interrupted preparation rather than replaying it silently.
    state.gameplay.cases[caseId] = value;
    await save(state);
    const player = await admin('players', { account: value.account, displayName: '入场验收旅行者', password: value.initialPassword });
    value.playerId = player.id;
    await save(state);
    for (const kind of Object.keys(state.assignments)) {
      const timing = kind === 'waiting' ? { startsAt: new Date(Date.now() + 86400000).toISOString(), endsAt: new Date(Date.now() + 172800000).toISOString() } :
        kind === 'expired' ? { endsAt: new Date(Date.now() - 86400000).toISOString() } : {};
      // Every case owns newly published sessions. Existing entry/preview fixtures
      // and past case business facts are never edited to manufacture a scenario.
      const session = await admin('sessions', { title: kind === 'ready' ? '星辰探险' : kind === 'waiting' ? '静候启程' : kind === 'expired' ? '已过开放时间' : '等级暂不符合',
        description: '解开谜题，发现惊喜。', minLevel: kind === 'locked' ? state.gameplay.minLevelId : '', levels,
        clues: [], rewardRules: [], presentation: { bgmMode: 'silent', completionStyle: 'normal' } });
      await admin(`sessions/${session.id}/publish`);
      const assigned = await admin('assignments', { sessionId: session.id, target: 'selected', playerIds: [player.id], order: kind === 'ready' ? 0 : 10, ...timing });
      const row = assigned.results?.find(item => item.playerId === player.id);
      if (!/^[a-z0-9]{15}$/.test(row?.assignmentId || '')) throw new Error('Gameplay case assignment identity missing');
      value.assignments[kind] = { assignmentId: row.assignmentId, sessionId: session.id };
      await save(state);
    }
    const authenticated = await api('/api/collections/game_players/auth-with-password', { identity: value.account, password: value.initialPassword }, '');
    const changed = await api('/api/questions/v1/me/change-password', { oldPassword: value.initialPassword,
      password: value.newPassword, passwordConfirm: value.newPassword }, authenticated.token);
    if (changed.player?.id !== player.id || changed.player.mustChangePassword !== false) throw new Error('Gameplay ordinary login preparation was not confirmed');
    value.ordinaryLoginPrepared = true;
    value.setupStatus = 'ready';
    value.assignmentId = value.assignments.ready.assignmentId;
    state.gameplay.activeCaseId = caseId;
    await save(state);
    return { created: true, caseId, fixture, assignmentKinds: Object.keys(value.assignments),
      ordinaryLoginPrepared: true, credentials: 'Only in this private state file; never printed', resetExistingGameplay: false };
  } finally { caseCreationBusy = false; }
}
async function gameplayProgress(input) {
  const value = state.gameplay.cases[input.caseId || state.gameplay.activeCaseId];
  const kind = input.kind || 'ready';
  if (!value || value.setupStatus !== 'ready' || !Object.hasOwn(value.assignments, kind)) throw new Error('Unknown owned gameplay case');
  const assignmentId = value.assignments[kind].assignmentId;
  const list = async (collection, filter) => {
    const data = await api('/api/collections/' + collection + '/records?perPage=500&filter=' + encodeURIComponent(filter), undefined, server.superToken);
    if (!Array.isArray(data.items) || data.totalItems !== data.items.length) throw new Error('Diagnostic collection is incomplete');
    return data.items;
  };
  const assignment = await api('/api/collections/game_assignments/records/' + assignmentId, undefined, server.superToken);
  if (assignment.player !== value.playerId) throw new Error('Gameplay assignment changed owner');
  const filter = 'assignment="' + assignmentId + '"';
  const [progress, submissions, ledger, receipts, answerReceipts, steps, balances] = await Promise.all([
    list('game_level_progress', filter), list('game_answer_submissions', filter), list('game_xp_ledger', filter),
    list('game_command_receipts', 'actorCollection="game_players" && actorId="' + value.playerId + '" && operation="start:' + assignmentId + '"'),
    list('game_command_receipts', 'actorCollection="game_players" && actorId="' + value.playerId + '" && operation="answer:' + assignmentId + '"'),
    list('game_session_levels', 'session="' + value.assignments[kind].sessionId + '"'),
    list('game_player_stats', 'player="' + value.playerId + '"')
  ]);
  if (!['assigned', 'active', 'completed', 'cancelled'].includes(assignment.status) ||
      typeof assignment.startedAt !== 'string' || typeof assignment.completedAt !== 'string' ||
      progress.some(row => !Number.isSafeInteger(row.wrongCount) || row.wrongCount < 0 || typeof row.locked !== 'boolean' ||
        typeof row.cooldownUntil !== 'string' || (row.cooldownUntil && !Number.isFinite(Date.parse(row.cooldownUntil))) || typeof row.completedAt !== 'string') ||
      ledger.some(row => !Number.isFinite(row.delta)) || [...receipts, ...answerReceipts].some(row => typeof row.requestId !== 'string') ||
      steps.some(row => !Number.isSafeInteger(row.position) || !Number.isFinite(row.xp)) || balances.length !== 1 || !Number.isFinite(balances[0].totalXp) ||
      submissions.some(row => !['correct', 'incorrect', 'manual'].includes(row.result))) {
    throw new Error('Diagnostic business fields are invalid');
  }
  return { caseId: value.caseId, assignmentKind: kind, assignmentStatus: assignment.status,
    startedAtPresent: !!assignment.startedAt, completedAtPresent: !!assignment.completedAt,
    progressRows: progress.length, completedProgressRows: progress.filter(row => !!row.completedAt).length,
    wrongCountTotal: progress.reduce((sum, row) => sum + row.wrongCount, 0),
    lockedProgressRows: progress.filter(row => row.locked).length, answerSubmissionCount: submissions.length,
    xpLedgerCount: ledger.length, xpDeltaSum: ledger.reduce((sum, row) => sum + row.delta, 0),
    startReceiptCount: receipts.length, startRequestIdSha256: receipts.map(row => sha256(row.requestId)),
    answerReceiptCount: answerReceipts.length, answerRequestIdSha256: answerReceipts.map(row => sha256(row.requestId)),
    submissionResults: { correct: submissions.filter(row => row.result === 'correct').length,
      incorrect: submissions.filter(row => row.result === 'incorrect').length, manual: submissions.filter(row => row.result === 'manual').length },
    playerTotalXp: balances[0].totalXp,
    steps: steps.sort((a, b) => a.position - b.position).map(step => {
      const matching = progress.filter(row => row.sessionLevel === step.id);
      if (matching.length > 1) throw new Error('Diagnostic has duplicate step progress');
      const p = matching[0];
      return { position: step.position, sessionLevelIdSha256: sha256(step.id), autoNext: step.autoNext,
        xp: step.xp, progressPresent: !!p, completedAtPresent: !!p?.completedAt,
        wrongCount: p?.wrongCount || 0, locked: p?.locked || false, cooldownUntil: p?.cooldownUntil || '',
        cooldownActive: !!p?.cooldownUntil && Date.parse(p.cooldownUntil) > Date.now(),
        submissionCount: submissions.filter(row => row.sessionLevel === step.id).length,
        xpLedgerCount: ledger.filter(row => row.sessionLevel === step.id).length,
        xpDeltaSum: ledger.filter(row => row.sessionLevel === step.id).reduce((sum, row) => sum + row.delta, 0) };
    }),
    readOnlyDiagnostic: true, rawAnswersOrCredentialsReturned: false };
}
async function cancelGameplayCase(input) {
  if (Object.keys(input).some(key => key !== 'caseId')) throw new Error('Case cancel accepts only its explicit owned case');
  const value = state.gameplay.cases[input.caseId];
  if (!value || value.setupStatus !== 'ready') throw new Error('Case cancel requires a prepared owned case');
  const assignmentId = value.assignments.ready.assignmentId;
  const before = await api('/api/collections/game_assignments/records/' + assignmentId, undefined, server.superToken);
  if (before.player !== value.playerId || before.session !== value.assignments.ready.sessionId || !['assigned', 'active'].includes(before.status)) {
    throw new Error('Only an unfinished own ready assignment can be cancelled');
  }
  await admin(`assignments/${assignmentId}/actions`, { action: 'cancel', reason: '独立答题验收场次撤回边界' });
  const after = await api('/api/collections/game_assignments/records/' + assignmentId, undefined, server.superToken);
  if (after.status !== 'cancelled' || after.player !== value.playerId) throw new Error('Own case cancellation was not confirmed');
  return { cancelled: true, caseId: value.caseId, assignmentKind: 'ready', officialAdminAction: true, pastFactsRewritten: false };
}
async function legacyResetIsSafe() {
  // Once the runner is used for gameplay, fresh cases replace reset entirely.
  // This also preserves earlier case request evidence and shared session facts.
  if (Object.keys(state.gameplay.cases).length > 0) return false;
  const count = async (collection, filter) => {
    const value = await api('/api/collections/' + collection + '/records?perPage=1&filter=' + encodeURIComponent(filter), undefined, server.superToken);
    if (!Number.isSafeInteger(value.totalItems) || value.totalItems < 0) throw new Error('Legacy reset guard could not establish record count');
    return value.totalItems;
  };
  for (const { assignmentId } of Object.values(state.assignments)) {
    const assignment = await api('/api/collections/game_assignments/records/' + assignmentId, undefined, server.superToken);
    if (assignment.player !== state.playerId || typeof assignment.startedAt !== 'string' ||
        typeof assignment.completedAt !== 'string' || assignment.startedAt || assignment.completedAt) return false;
    const assignmentFilter = 'assignment="' + assignmentId + '"';
    const counts = await Promise.all([
      count('game_level_progress', assignmentFilter), count('game_answer_submissions', assignmentFilter),
      count('game_xp_ledger', assignmentFilter),
      count('game_command_receipts', 'actorCollection="game_players" && actorId="' + state.playerId +
        '" && (operation="start:' + assignmentId + '" || operation="answer:' + assignmentId + '")')
    ]);
    if (counts.some(value => value > 0)) return false;
  }
  return true;
}
function ownedClaim(authorization) {
  if (!authorization || /^Bearer /i.test(authorization)) return '';
  try {
    const pieces = authorization.split('.');
    if (pieces.length !== 3) return '';
    const id = JSON.parse(Buffer.from(pieces[1], 'base64url').toString('utf8')).id;
    const owned = [state.playerId, state.otherPlayerId, ...Object.values(state.gameplay.cases).map(value => value.playerId)];
    return /^[a-z0-9]{15}$/.test(id || '') && owned.includes(id) ? id : '';
  } catch { return ''; }
}
function permitted(method, pathname) {
  return (method === 'GET' && (pathname === '/api/health' || pathname === '/api/questions/v1/me' || pathname === '/api/questions/v1/notifications' || pathname === '/api/questions/v1/rewards' || pathname === '/api/questions/v1/assignments' || /^\/api\/questions\/v1\/assignments\/[a-z0-9]{15}$/.test(pathname) || /^\/api\/files\/game_players\/[a-z0-9]{15}\/[a-zA-Z0-9._%-]+$/.test(pathname))) || (method === 'POST' && (['/api/collections/game_players/auth-with-password', '/api/questions/v1/me/change-password', '/api/files/token'].includes(pathname) || /^\/api\/questions\/v1\/assignments\/[a-z0-9]{15}\/(start|answers)$/.test(pathname))) || (method === 'PATCH' && pathname === '/api/questions/v1/me/profile');
}
function reply(res, status, body) {
  if (res.destroyed || res.writableEnded) return;
  try { res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(body)); }
  catch { res.destroy(); }
}
async function listener(req, res) {
  req.on('error', () => {});
  res.on('error', () => {});
  const url = new URL(req.url, 'http://127.0.0.1');
  const origin = req.headers.origin;
  if (origin && /^http:\/\/(localhost|127\.0\.0\.1|local\.sitkin\.top)(:\d+)?$/.test(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin); res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, Accept'); res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
  } else if (origin) { reply(res, 403, { error: { code: 'ORIGIN_DENIED', message: '隔离环境来源受限' } }); return; }
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }
  if (!permitted(req.method, url.pathname)) { reply(res, 404, { error: { code: 'NOT_FOUND', message: '隔离玩家代理不提供此接口' } }); return; }
  const row = { method: req.method, path: url.pathname, authenticated: !!req.headers.authorization, bearer: /^Bearer /i.test(req.headers.authorization || ''), fault: false, status: 0, time: new Date().toISOString() };
  requests.push(row); requests = requests.slice(-1000);
  try {
    const body = await jsonBody(req);
    const actor = ownedClaim(req.headers.authorization);
    if (req.method === 'POST' && /^\/api\/questions\/v1\/assignments\/[a-z0-9]{15}\/(start|answers)$/.test(url.pathname)) {
      // Telemetry only: claims are not authentication and never gate requests.
      // Only a real successful backend response can verify the actor binding.
      row.operation = url.pathname.endsWith('/answers') ? 'answer' : 'start';
      row.actorBinding = actor ? 'owned_claim_not_yet_verified' : 'missing_or_unowned_claim';
      row.actorSha256 = actor ? sha256(state.controlToken + ':actor:' + actor) : null;
      row.requestBodySha256 = sha256(body);
      try {
        const parsed = JSON.parse(body.toString('utf8'));
        if (row.operation === 'answer' && typeof parsed.sessionLevelId === 'string') row.sessionLevelIdSha256 = sha256(parsed.sessionLevelId);
        if (typeof parsed.requestId === 'string' && parsed.requestId.length > 0 && parsed.requestId.length <= 100) {
          row.requestIdSha256 = sha256(parsed.requestId);
          const key = url.pathname + ':' + row.requestIdSha256;
          const identity = JSON.stringify([row.actorSha256, row.requestBodySha256]);
          row.matchesPriorRequestIdentity = requestIdentities.has(key) ? requestIdentities.get(key) === identity : null;
          if (!requestIdentities.has(key)) {
            if (requestIdentities.size >= 4096) requestIdentities.delete(requestIdentities.keys().next().value);
            requestIdentities.set(key, identity);
          }
        }
      } catch { /* Real backend decides malformed command errors. */ }
    }
    // Structural evidence only: never retain multipart boundaries, fields,
    // filenames, image bytes, credentials, file-token values or query strings.
    if (url.pathname === '/api/questions/v1/me/profile' && req.method === 'PATCH') {
      const contentType = req.headers['content-type'] || '';
      row.bodyKind = /^multipart\/form-data(?:;|$)/i.test(contentType) ? 'multipart' : /^application\/json(?:;|$)/i.test(contentType) ? 'json' : 'other';
      row.avatarPartPresent = row.bodyKind === 'multipart' && /(?:^|\r\n)Content-Disposition:[^\r\n]*\bname="avatar"(?:;|\r\n)/i.test(body.toString('latin1'));
      row.requestBytes = body.length;
    }
    if (/^\/api\/files\/game_players\//.test(url.pathname)) row.fileTokenProvided = url.searchParams.has('token');
    let dropAfterForward = false, responseDelayMs = 0;
    if (fault && (!fault.path || url.pathname === fault.path) && (!fault.method || req.method === fault.method)) {
      const selected = fault; fault = null; row.fault = true;
      if (selected.delayMs) await new Promise(resolve => setTimeout(resolve, Math.min(selected.delayMs, 20000)));
      dropAfterForward = selected.dropResponse === true;
      responseDelayMs = Number.isFinite(selected.responseDelayMs) ? Math.max(0, Math.min(selected.responseDelayMs, 20000)) : 0;
      if (selected.drop) { row.status = 0; req.socket.destroy(); return; }
      if (selected.status) { row.status = selected.status; res.writeHead(selected.status, { 'Content-Type': 'application/json' }); res.end(selected.rawBody ?? JSON.stringify(selected.body || { error: { code: 'TEST_FAULT', message: '隔离网络故障注入' } })); return; }
    }
    const headers = { Accept: req.headers.accept || 'application/json', ...(req.headers.authorization ? { Authorization: req.headers.authorization } : {}), ...(req.headers['content-type'] ? { 'Content-Type': req.headers['content-type'] } : {}), ...(origin ? { Origin: origin } : {}) };
    const upstream = await fetch(server.base + url.pathname + url.search, { method: req.method, headers, body: req.method === 'GET' ? undefined : body, redirect: 'manual' });
    const output = Buffer.from(await upstream.arrayBuffer()); row.status = upstream.status;
    row.upstreamFinished = true;
    if (['start', 'answer'].includes(row.operation) && upstream.status === 200 && actor) {
      try {
        const parsed = JSON.parse(output.toString('utf8'));
        row.actorVerifiedByBackendResponse = (row.operation === 'start' ? parsed.player : parsed.assignment?.player) === actor;
        if (row.actorVerifiedByBackendResponse) row.actorBinding = 'owned_backend_confirmed';
      }
      catch { row.actorVerifiedByBackendResponse = false; }
    }
    if (responseDelayMs) {
      row.responseAwaitingDelay = true;
      await new Promise(resolve => setTimeout(resolve, responseDelayMs));
      row.responseAwaitingDelay = false;
    }
    if (dropAfterForward) { row.responseDropped = true; res.destroy(); return; }
    res.writeHead(upstream.status, { 'Content-Type': upstream.headers.get('content-type') || 'application/json', 'Cache-Control': 'no-store' }); res.end(output);
  } catch { row.status = 502; if (!res.headersSent) reply(res, 502, { error: { code: 'UPSTREAM_UNAVAILABLE', message: '隔离后端暂时不可达' } }); }
}
try {
  await seed();
  proxy = createServer(listener);
  await new Promise(resolve => proxy.listen(Number(process.env.STARWARD_PROXY_PORT || 0), '127.0.0.1', resolve));
  state.proxyBase = 'http://127.0.0.1:' + proxy.address().port;
  localControl = createServer(async (req, res) => {
    req.on('error', () => {});
    res.on('error', () => {});
    if (req.headers.authorization !== state.controlToken || req.method !== 'POST') { reply(res, 403, { error: 'Local control authorization required' }); return; }
    try {
      const body = JSON.parse((await jsonBody(req)).toString('utf8') || '{}');
      if (req.url === '/requests') { reply(res, 200, { requests }); return; }
      if (req.url === '/fault') { fault = body; reply(res, 200, { configured: true }); return; }
      if (req.url === '/new-case') { reply(res, 200, await newGameplayCase(body)); return; }
      if (req.url === '/new-ui-content-case') {
        if (caseCreationBusy) throw new Error('Owned case creation is busy');
        caseCreationBusy = true;
        try { reply(res, 200, await createUiContentCases(body, { root, state, save, admin, api, secret, superToken: server.superToken })); }
        finally { caseCreationBusy = false; }
        return;
      }
      if (req.url === '/new-ui-image-failure-case') {
        if (caseCreationBusy) throw new Error('Owned case creation is busy');
        caseCreationBusy = true;
        try { reply(res, 200, await createUiImageFailureCase(body, { root, state, save, admin, api, secret, superToken: server.superToken })); }
        finally { caseCreationBusy = false; }
        return;
      }
      if (req.url === '/case-progress') { reply(res, 200, await gameplayProgress(body)); return; }
      if (req.url === '/case-cancel') { reply(res, 200, await cancelGameplayCase(body)); return; }
      if (req.url === '/reset') {
        if (!await legacyResetIsSafe()) {
          reply(res, 409, { error: 'Gameplay cases or facts exist; create a new case instead of resetting progression' }); return;
        }
        await admin(`players/${state.playerId}/actions`, { action: 'enable', reason: '隔离验收重置账号状态' });
        await admin(`players/${state.playerId}/actions`, { action: 'reset_password', password: state.initialPassword, reason: '隔离验收重置初始密码' });
        for (const entry of Object.values(state.assignments)) await api('/api/collections/game_sessions/records/' + entry.sessionId, { status: 'published' }, server.superToken, 'PATCH');
        await api('/api/collections/game_assignments/records/' + state.assignmentId, { status: 'assigned' }, server.superToken, 'PATCH');
        fault = null; requests = []; reply(res, 200, { reset: true }); return;
      }
      if (req.url === '/player') { await admin(`players/${state.playerId}/actions`, { action: body.disabled ? 'disable' : 'enable', reason: '隔离验收账号状态测试' }); reply(res, 200, { changed: true }); return; }
      if (req.url === '/scenario' && typeof body.singleAssignment === 'boolean') { for (const [kind, entry] of Object.entries(state.assignments)) { await api('/api/collections/game_sessions/records/' + entry.sessionId, { status: !body.singleAssignment || kind === 'ready' ? 'published' : 'archived' }, server.superToken, 'PATCH'); } reply(res, 200, { changed: true, singleAssignment: body.singleAssignment }); return; }
      if (req.url === '/scenario' && typeof body.emptyAssignments === 'boolean') { for (const entry of Object.values(state.assignments)) { await api('/api/collections/game_sessions/records/' + entry.sessionId, { status: body.emptyAssignments ? 'archived' : 'published' }, server.superToken, 'PATCH'); } reply(res, 200, { changed: true, emptyAssignments: body.emptyAssignments }); return; }
      if (req.url === '/scenario') { const allowed = ['assigned', 'active', 'completed', 'cancelled']; if (!allowed.includes(body.status)) throw new Error('Unsupported scenario status'); await api('/api/collections/game_assignments/records/' + state.assignmentId, { status: body.status }, server.superToken, 'PATCH'); reply(res, 200, { changed: true }); return; }
      reply(res, 404, { error: 'Unknown local control operation' });
    } catch { reply(res, 400, { error: 'Isolated local control failed' }); }
  });
  await new Promise(resolve => localControl.listen(Number(process.env.STARWARD_CONTROL_PORT || 0), '127.0.0.1', resolve));
  state.controlBase = 'http://127.0.0.1:' + localControl.address().port;
  if (preservedRestart) {
    if (state.proxyBase !== 'http://127.0.0.1:' + preservedRestart.ports.proxy ||
        state.controlBase !== 'http://127.0.0.1:' + preservedRestart.ports.control) throw new Error('Restart actual ports changed');
    process.kill(preservedRestart.tls.pid, 0);
    state.tls = preservedRestart.tls;
  }
  await save(state);
  console.log(JSON.stringify({ ready: true, proxyBase: state.proxyBase, stateFile, credentials: 'Private file mode600; never printed', adminPublic: false }));
  const stop = async () => { if (closing) return; closing = true; proxy.close(); localControl.close(); await server.stop(); await rm(stateFile, { force: true }); process.exit(0); };
  process.on('SIGINT', stop); process.on('SIGTERM', stop);
} catch (error) { proxy?.close(); localControl?.close(); await server.stop(); throw error; }

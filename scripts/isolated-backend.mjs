#!/usr/bin/env node
/** Real PocketBase in a disposable Docker database; player-only proxy for TLS tunnelling. */
import { createServer } from 'node:http';
import { spawnSync } from 'node:child_process';
import { cp, mkdir, readFile, writeFile, chmod, rm } from 'node:fs/promises';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { prepareIsolationHarness } from './prepare-isolation-harness.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const privateRoot = path.join(root, 'artifacts/private/https-isolation');
const stateFile = path.join(privateRoot, 'state.json');
const backend = path.resolve(process.env.STARWARD_BACKEND_SOURCE || path.join(root, '../sitkin-pb-backend-management/backend'));
const version = '0.40.1';
const sourceDir = path.join(privateRoot, 'source');
const image = 'starward-hm-isolation:pb-0.40.1-arm64';
const secret = () => 'Hm-' + randomBytes(20).toString('base64url');
const command = process.argv[2] || 'status';

function exec(program, args, opts = {}) {
  const r = spawnSync(program, args, { encoding: 'utf8', stdio: 'pipe', ...opts });
  if (r.status !== 0) throw new Error(program + ' failed: ' + (r.stderr || r.stdout || r.error?.message || '').slice(-1200));
  return r.stdout;
}
async function save(value) {
  await writeFile(stateFile, JSON.stringify(value, null, 2) + '\n', { mode: 0o600 });
  await chmod(stateFile, 0o600);
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
  if (!exec('docker', ['run', '--rm', '--network=none', image, '--version']).includes(' ' + version)) throw new Error('Runtime version mismatch');
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
if (command !== 'start') throw new Error('Usage: isolated-backend.mjs prepare|start|status|stop|reset|requests|fault|player|scenario');
await mkdir(privateRoot, { recursive: true, mode: 0o700 });
process.env.PB_DOCKER_IMAGE = image;
process.env.TMPDIR = privateRoot;
const harness = await prepareIsolationHarness(backend, privateRoot);
const { createTestServer } = await import(harness.moduleUrl);
const server = await createTestServer();
let proxy, localControl, closing = false, fault = null, requests = [];
const state = { pid: process.pid, backendBase: server.base, proxyBase: '', controlBase: '', controlToken: secret(), account: 'hm_' + randomBytes(5).toString('hex'), initialPassword: secret(), newPassword: secret(), playerId: '', assignmentId: '', assignments: {}, version, mode: 'real isolated PocketBase', backendSourceCommit: exec('git', ['rev-parse', 'HEAD'], { cwd: path.dirname(backend) }).trim(), imageId: exec('docker', ['image', 'inspect', '--format', '{{.Id}}', image]).trim(), sourceDirectory: server.directory };
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
  const q = await admin('questions', { title: '星辰之门', kind: 'text', content: [{ text: '隔离验收题目，不在本切片答题。' }], options: [], acceptedAnswers: ['星辰大海'], placeholder: '输入你的答案' });
  await admin(`questions/${q.id}/publish`);
  const q2 = await admin('questions', { title: '守门人的选择', kind: 'choice', content: [{ text: '隔离验收题目' }], options: [{ key: 'A', text: '月亮' }, { key: 'B', text: '北极星' }], acceptedAnswers: ['B'] });
  await admin(`questions/${q2.id}/publish`);
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
function permitted(method, pathname) {
  return (method === 'GET' && (pathname === '/api/health' || pathname === '/api/questions/v1/me' || pathname === '/api/questions/v1/notifications' || pathname === '/api/questions/v1/rewards' || pathname === '/api/questions/v1/assignments' || /^\/api\/questions\/v1\/assignments\/[a-z0-9]{15}$/.test(pathname) || /^\/api\/files\/game_players\/[a-z0-9]{15}\/[a-zA-Z0-9._%-]+$/.test(pathname))) || (method === 'POST' && ['/api/collections/game_players/auth-with-password', '/api/questions/v1/me/change-password', '/api/files/token'].includes(pathname)) || (method === 'PATCH' && pathname === '/api/questions/v1/me/profile');
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
    // Structural evidence only: never retain multipart boundaries, fields,
    // filenames, image bytes, credentials, file-token values or query strings.
    if (url.pathname === '/api/questions/v1/me/profile' && req.method === 'PATCH') {
      const contentType = req.headers['content-type'] || '';
      row.bodyKind = /^multipart\/form-data(?:;|$)/i.test(contentType) ? 'multipart' : /^application\/json(?:;|$)/i.test(contentType) ? 'json' : 'other';
      row.avatarPartPresent = row.bodyKind === 'multipart' && /(?:^|\r\n)Content-Disposition:[^\r\n]*\bname="avatar"(?:;|\r\n)/i.test(body.toString('latin1'));
      row.requestBytes = body.length;
    }
    if (/^\/api\/files\/game_players\//.test(url.pathname)) row.fileTokenProvided = url.searchParams.has('token');
    let dropAfterForward = false;
    if (fault && (!fault.path || url.pathname === fault.path) && (!fault.method || req.method === fault.method)) {
      const selected = fault; fault = null; row.fault = true;
      if (selected.delayMs) await new Promise(resolve => setTimeout(resolve, Math.min(selected.delayMs, 20000)));
      dropAfterForward = selected.dropResponse === true;
      if (selected.drop) { row.status = 0; req.socket.destroy(); return; }
      if (selected.status) { row.status = selected.status; res.writeHead(selected.status, { 'Content-Type': 'application/json' }); res.end(selected.rawBody ?? JSON.stringify(selected.body || { error: { code: 'TEST_FAULT', message: '隔离网络故障注入' } })); return; }
    }
    const headers = { Accept: req.headers.accept || 'application/json', ...(req.headers.authorization ? { Authorization: req.headers.authorization } : {}), ...(req.headers['content-type'] ? { 'Content-Type': req.headers['content-type'] } : {}), ...(origin ? { Origin: origin } : {}) };
    const upstream = await fetch(server.base + url.pathname + url.search, { method: req.method, headers, body: req.method === 'GET' ? undefined : body, redirect: 'manual' });
    const output = Buffer.from(await upstream.arrayBuffer()); row.status = upstream.status;
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
      if (req.url === '/reset') { await admin(`players/${state.playerId}/actions`, { action: 'enable', reason: '隔离验收重置账号状态' }); await admin(`players/${state.playerId}/actions`, { action: 'reset_password', password: state.initialPassword, reason: '隔离验收重置初始密码' }); for (const entry of Object.values(state.assignments)) { await api('/api/collections/game_sessions/records/' + entry.sessionId, { status: 'published' }, server.superToken, 'PATCH'); } await api('/api/collections/game_assignments/records/' + state.assignmentId, { status: 'assigned' }, server.superToken, 'PATCH'); fault = null; requests = []; reply(res, 200, { reset: true }); return; }
      if (req.url === '/player') { await admin(`players/${state.playerId}/actions`, { action: body.disabled ? 'disable' : 'enable', reason: '隔离验收账号状态测试' }); reply(res, 200, { changed: true }); return; }
      if (req.url === '/scenario' && typeof body.singleAssignment === 'boolean') { for (const [kind, entry] of Object.entries(state.assignments)) { await api('/api/collections/game_sessions/records/' + entry.sessionId, { status: !body.singleAssignment || kind === 'ready' ? 'published' : 'archived' }, server.superToken, 'PATCH'); } reply(res, 200, { changed: true, singleAssignment: body.singleAssignment }); return; }
      if (req.url === '/scenario' && typeof body.emptyAssignments === 'boolean') { for (const entry of Object.values(state.assignments)) { await api('/api/collections/game_sessions/records/' + entry.sessionId, { status: body.emptyAssignments ? 'archived' : 'published' }, server.superToken, 'PATCH'); } reply(res, 200, { changed: true, emptyAssignments: body.emptyAssignments }); return; }
      if (req.url === '/scenario') { const allowed = ['assigned', 'active', 'completed', 'cancelled']; if (!allowed.includes(body.status)) throw new Error('Unsupported scenario status'); await api('/api/collections/game_assignments/records/' + state.assignmentId, { status: body.status }, server.superToken, 'PATCH'); reply(res, 200, { changed: true }); return; }
      reply(res, 404, { error: 'Unknown local control operation' });
    } catch { reply(res, 400, { error: 'Isolated local control failed' }); }
  });
  await new Promise(resolve => localControl.listen(Number(process.env.STARWARD_CONTROL_PORT || 0), '127.0.0.1', resolve));
  state.controlBase = 'http://127.0.0.1:' + localControl.address().port;
  if (process.env.STARWARD_RESTART_STATE) { const preserved = JSON.parse(await readFile(process.env.STARWARD_RESTART_STATE, 'utf8')); if (preserved.tls?.pid) { process.kill(preserved.tls.pid, 0); state.tls = preserved.tls; } }
  await save(state);
  console.log(JSON.stringify({ ready: true, proxyBase: state.proxyBase, stateFile, credentials: 'Private file mode600; never printed', adminPublic: false }));
  const stop = async () => { if (closing) return; closing = true; proxy.close(); localControl.close(); await server.stop(); await rm(stateFile, { force: true }); process.exit(0); };
  process.on('SIGINT', stop); process.on('SIGTERM', stop);
} catch (error) { proxy?.close(); localControl?.close(); await server.stop(); throw error; }

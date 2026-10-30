/** Opt-in, single-response transport gate for the disposable player's uploaded QA avatar. */
import http from 'node:http';
import { constants } from 'node:fs';
import { open, mkdir, unlink } from 'node:fs/promises';
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import path from 'node:path';
import { performance } from 'node:perf_hooks';

const MAX_BYTES = 2 * 1024 * 1024;
const MAX_TTL_MS = 14000;
const MAX_HISTORY = 16;
const digest = value => createHash('sha256').update(value).digest('hex');
const isLoopback = value => {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' && url.hostname === '127.0.0.1' && url.port &&
      !url.username && !url.password && url.pathname === '/' && !url.search && !url.hash;
  } catch { return false; }
};
const stamp = started => ({ at: new Date().toISOString(), elapsedMs: Math.round((performance.now() - started) * 1000) / 1000 });
const reply = (res, status, body) => {
  if (res.destroyed || res.writableEnded) return;
  res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(body));
};

async function readPrivateJson(filename) {
  const file = await open(filename, constants.O_RDONLY | constants.O_NOFOLLOW);
  try {
    const stat = await file.stat();
    if (!stat.isFile() || (stat.mode & 0o077) || (process.getuid && stat.uid !== process.getuid()) || stat.size > 1024 * 1024) {
      throw new Error('Private avatar receipt permissions or size are invalid');
    }
    return JSON.parse(await file.readFile('utf8'));
  } finally { await file.close(); }
}

async function controlBody(req) {
  const chunks = [];
  let bytes = 0;
  for await (const chunk of req) {
    bytes += chunk.length;
    if (bytes > 4096) throw new Error('CONTROL_BODY_LIMIT');
    chunks.push(chunk);
  }
  const value = JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
  if (!value || Array.isArray(value) || typeof value !== 'object') throw new Error('CONTROL_BODY_INVALID');
  return value;
}

/** No request URL, authentication, file token, image bytes or headers enter the public ledger. */
export async function createIsolatedResponseGate({ state, privateDirectory, avatarSessionPath,
  readSession = () => readPrivateJson(avatarSessionPath) }) {
  if (state.mode !== 'real isolated PocketBase' || !/^[a-z0-9]{15}$/.test(state.playerId || '') ||
      typeof state.account !== 'string' || !state.account || !isLoopback(state.controlBase) || !isLoopback(state.proxyBase)) {
    throw new Error('Response gate requires this dedicated loopback player environment');
  }
  const owner = digest(state.account + state.playerId + state.controlBase);
  let token = randomBytes(32).toString('base64url');
  const instanceId = randomBytes(16).toString('hex');
  const started = performance.now();
  const history = [];
  let current = null;
  let stopped = false;
  let arming = false;
  let receiptPath;
  const manifest = Object.freeze({ version: 1, enabled: true, purpose: 'one real own-avatar response held until explicit release',
    maxBytes: MAX_BYTES, maxTtlMs: MAX_TTL_MS, singleUsePerArm: true, bufferedInMemoryOnly: true,
    verifiesOriginalBodySha256: true, control: 'authenticated loopback POST; private receipt only',
    events: ['requestReceived', 'held', 'released', 'downstreamFinished', 'clientAborted', 'failed'] });

  function snapshot(row) {
    return row ? structuredClone(row.ledger) : null;
  }

  function clearMemory(row) {
    for (const chunk of row.chunks) chunk.fill(0);
    row.chunks = [];
    row.body?.fill(0);
    row.body = null;
    row.headers = null;
    row.path = '';
    row.expectedSha256 = '';
  }

  function fail(row, reason) {
    if (['finished', 'failed'].includes(row.ledger.state)) return;
    row.ledger.state = 'failed';
    row.ledger.failed = { ...stamp(started), reason };
    clearTimeout(row.timer);
    clearMemory(row);
    row.remote?.destroy();
    row.remote = null;
    row.res?.destroy();
    row.res = null;
  }

  async function arm(body) {
    if (stopped || arming || (current && !['finished', 'failed'].includes(current.ledger.state))) {
      return { status: 409, body: { error: 'GATE_BUSY_OR_STOPPED' } };
    }
    if (Object.keys(body).some(key => !['path', 'expectedSha256', 'ttlMs'].includes(key)) || typeof body.path !== 'string' ||
        typeof body.expectedSha256 !== 'string' || !/^[a-f0-9]{64}$/.test(body.expectedSha256) ||
        !Number.isInteger(body.ttlMs ?? MAX_TTL_MS) || (body.ttlMs ?? MAX_TTL_MS) < 100 || (body.ttlMs ?? MAX_TTL_MS) > MAX_TTL_MS) {
      return { status: 400, body: { error: 'INVALID_ARM_PARAMETERS' } };
    }
    arming = true;
    try {
      const session = await readSession();
      const prefix = '/api/files/game_players/' + state.playerId + '/';
      const encodedName = body.path.startsWith(prefix) ? body.path.slice(prefix.length) : '';
      let filename = '';
      try { filename = decodeURIComponent(encodedName); } catch {}
      const validPath = /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,199}$/.test(filename) &&
        encodeURIComponent(filename) === encodedName;
      if (stopped || session.ownerSha256 !== owner || !Array.isArray(session.phases) || !session.phases.includes('avatar-saved') ||
          !validPath) {
        return { status: 400, body: { error: 'OWN_UPLOADED_AVATAR_RECEIPT_MISMATCH' } };
      }
      const ttlMs = body.ttlMs ?? MAX_TTL_MS;
      // The operator obtains this current owned filename/digest from authenticated
      // read-only /me and protected-file reads. The original upload receipt proves
      // the dedicated session; it may precede a later JPEG/WebP replacement.
      const row = { path: body.path, expectedSha256: body.expectedSha256, chunks: [], body: null, headers: null,
        remote: null, res: null, expiresAt: performance.now() + ttlMs, timer: null,
        ledger: { gateId: randomBytes(16).toString('hex'), state: 'armed', armed: stamp(started), ttlMs,
          bodySha256Matched: false, requestReceived: null, held: null, released: null,
          downstreamFinished: null, clientAborted: null, failed: null } };
      row.timer = setTimeout(() => fail(row, 'EXPIRED'), ttlMs);
      current = row;
      history.push(row);
      if (history.length > MAX_HISTORY) history.shift();
      return { status: 200, body: snapshot(row) };
    } catch {
      return { status: 400, body: { error: 'PRIVATE_AVATAR_RECEIPT_UNAVAILABLE' } };
    } finally { arming = false; }
  }

  function release(body) {
    const row = current;
    if (!row || body.gateId !== row.ledger.gateId || Object.keys(body).some(key => key !== 'gateId') ||
        row.ledger.state !== 'held') return { status: 409, body: { error: 'NO_MATCHING_HELD_RESPONSE' } };
    if (performance.now() >= row.expiresAt || row.res.destroyed || row.res.writableEnded) {
      fail(row, 'CLIENT_UNAVAILABLE_OR_EXPIRED');
      return { status: 409, body: snapshot(row) };
    }
    row.ledger.state = 'released';
    row.ledger.released = stamp(started);
    try {
      row.res.writeHead(200, row.headers);
      row.res.end(row.body);
      return { status: 200, body: snapshot(row) };
    } catch {
      fail(row, 'DOWNSTREAM_WRITE_FAILED');
      return { status: 409, body: snapshot(row) };
    }
  }

  const control = http.createServer(async (req, res) => {
    req.on('error', () => {});
    res.on('error', () => {});
    const supplied = Buffer.from(typeof req.headers.authorization === 'string' ? req.headers.authorization : '');
    const expected = Buffer.from(token);
    if (req.method !== 'POST' || supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) {
      req.resume();
      reply(res, 403, { error: 'CONTROL_AUTH_REQUIRED' });
      return;
    }
    try {
      const body = await controlBody(req);
      if (req.url === '/arm') {
        const result = await arm(body);
        reply(res, result.status, result.body);
      } else if (req.url === '/status' && Object.keys(body).length === 0) {
        reply(res, 200, { manifest, current: snapshot(current), history: history.map(snapshot) });
      } else if (req.url === '/release') {
        const result = release(body);
        reply(res, result.status, result.body);
      } else if (req.url === '/cancel' && current && body.gateId === current.ledger.gateId &&
          Object.keys(body).every(key => key === 'gateId')) {
        fail(current, 'OPERATOR_CANCELLED');
        reply(res, 200, snapshot(current));
      } else reply(res, 404, { error: 'UNKNOWN_CONTROL_OPERATION' });
    } catch { reply(res, 400, { error: 'INVALID_CONTROL_REQUEST' }); }
  });
  control.on('connection', socket => socket.on('error', () => {}));
  control.on('clientError', (_error, socket) => socket.destroy());
  await new Promise((resolve, reject) => {
    control.once('error', reject);
    control.listen(0, '127.0.0.1', resolve);
  });
  control.on('error', () => { if (current) fail(current, 'CONTROL_SERVER_FAILED'); });

  async function close() {
    if (stopped) return;
    stopped = true;
    if (current) fail(current, 'GATE_STOPPED');
    control.closeAllConnections();
    await new Promise(resolve => control.close(resolve));
    token = '';
    if (receiptPath) await unlink(receiptPath).catch(() => {});
  }

  try {
    await mkdir(privateDirectory, { recursive: true, mode: 0o700 });
    receiptPath = path.join(privateDirectory, 'response-gate-' + process.pid + '-' + instanceId + '.json');
    const file = await open(receiptPath, constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW, 0o600);
    try {
      await file.writeFile(JSON.stringify({ instanceId, pid: process.pid, createdAt: new Date().toISOString(),
        controlBase: 'http://127.0.0.1:' + control.address().port, controlToken: token, ownerSha256: owner, manifest }, null, 2) + '\n');
    } finally { await file.close(); }
  } catch { await close(); throw new Error('Could not create private response-gate receipt'); }

  function claim(req, res) {
    const row = current;
    if (stopped || !row || row.ledger.state !== 'armed' || req.method !== 'GET') return null;
    let pathname;
    try { pathname = new URL(req.url, 'http://127.0.0.1').pathname; } catch { return null; }
    if (pathname !== row.path) return null;
    if (performance.now() >= row.expiresAt) { fail(row, 'EXPIRED'); res.destroy(); return null; }
    row.ledger.state = 'receiving';
    row.ledger.requestReceived = stamp(started);
    row.res = res;
    res.once('finish', () => {
      if (row.ledger.state !== 'released') { fail(row, 'UNEXPECTED_DOWNSTREAM_FINISH'); return; }
      row.ledger.downstreamFinished = stamp(started);
      row.ledger.state = 'finished';
      clearTimeout(row.timer);
      clearMemory(row);
      row.res = null;
      row.remote = null;
    });
    res.once('close', () => {
      if (!res.writableFinished) {
        row.ledger.clientAborted = stamp(started);
        fail(row, 'CLIENT_CLOSED_BEFORE_FINISH');
      }
    });
    return {
      fail: reason => fail(row, reason),
      async hold(remote) {
        if (row.ledger.state !== 'receiving') { remote.destroy(); return; }
        row.remote = remote;
        try {
          if (remote.statusCode !== 200) { fail(row, 'UPSTREAM_NOT_200'); return; }
          const declared = Number(remote.headers['content-length']);
          if (Number.isFinite(declared) && declared > MAX_BYTES) { fail(row, 'BODY_LIMIT'); return; }
          let bytes = 0;
          for await (const chunk of remote) {
            if (row.ledger.state !== 'receiving') { remote.destroy(); return; }
            bytes += chunk.length;
            if (bytes > MAX_BYTES) { fail(row, 'BODY_LIMIT'); return; }
            row.chunks.push(Buffer.from(chunk));
          }
          if (row.ledger.state !== 'receiving') return;
          row.body = Buffer.concat(row.chunks);
          for (const chunk of row.chunks) chunk.fill(0);
          row.chunks = [];
          if (digest(row.body) !== row.expectedSha256) { fail(row, 'ORIGINAL_BODY_SHA256_MISMATCH'); return; }
          row.headers = { ...remote.headers };
          row.remote = null;
          row.ledger.bodySha256Matched = true;
          row.ledger.state = 'held';
          row.ledger.held = stamp(started);
        } catch { fail(row, 'UPSTREAM_READ_FAILED'); }
      }
    };
  }

  return { claim, close, manifest, receiptPath };
}

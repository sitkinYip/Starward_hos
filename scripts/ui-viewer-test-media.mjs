#!/usr/bin/env node
/** Synthetic-only fixture. Import/default/help/prepare never open a listener. */
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const SELF = fileURLToPath(import.meta.url);
const ROOT = path.resolve(path.dirname(SELF), '..');
const PRIVATE = path.join(ROOT, 'artifacts/private/ui-reference');
const MAX_REQUESTS = 256;
const HOLD_MS = 12000;
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const requireThat = (ok, message = 'Synthetic fixture guard failed') => { if (!ok) throw new Error(message); };
const keysAre = (value, keys) => value && typeof value === 'object' && !Array.isArray(value) &&
  Object.keys(value).sort().join(',') === [...keys].sort().join(',');

function crc32(bytes) {
  let value = 0xffffffff;
  for (const byte of bytes) {
    value ^= byte;
    for (let bit = 0; bit < 8; bit++) value = (value >>> 1) ^ ((value & 1) ? 0xedb88320 : 0);
  }
  return (value ^ 0xffffffff) >>> 0;
}

export function checkerPng() {
  const chunk = (type, bytes) => {
    const name = Buffer.from(type), size = Buffer.alloc(4), checksum = Buffer.alloc(4);
    size.writeUInt32BE(bytes.length); checksum.writeUInt32BE(crc32(Buffer.concat([name, bytes])));
    return Buffer.concat([size, name, bytes, checksum]);
  };
  const header = Buffer.alloc(13); header.writeUInt32BE(64); header.writeUInt32BE(40, 4);
  header[8] = 8; header[9] = 6;
  const rows = Buffer.alloc(40 * (1 + 64 * 4));
  for (let y = 0; y < 40; y++) for (let x = 0; x < 64; x++) {
    const offset = y * 257 + 1 + x * 4, light = (Math.floor(x / 8) + Math.floor(y / 8)) % 2 === 0;
    rows.set(light ? [234, 209, 131, 255] : [35, 94, 82, 255], offset);
  }
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header),
    chunk('IDAT', zlib.deflateSync(rows)), chunk('IEND', Buffer.alloc(0))]);
}

function privatePath(filename, root = PRIVATE) {
  const target = path.resolve(filename), boundary = path.resolve(root);
  requireThat(target.startsWith(boundary + path.sep));
  let current = target;
  while (current !== path.dirname(current)) {
    try { requireThat(!fs.lstatSync(current).isSymbolicLink()); }
    catch (error) { requireThat(error.code === 'ENOENT'); }
    current = path.dirname(current);
  }
  return target;
}

function privateStat(filename, directory) {
  const value = fs.lstatSync(filename);
  requireThat(!value.isSymbolicLink() && value.uid === process.getuid() &&
    (directory ? value.isDirectory() : value.isFile()) && (value.mode & 0o777) === (directory ? 0o700 : 0o600));
  return value;
}

function freshWrite(filename, bytes) {
  const descriptor = fs.openSync(filename, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | fs.constants.O_NOFOLLOW, 0o600);
  try { fs.writeFileSync(descriptor, bytes); } finally { fs.closeSync(descriptor); }
}

export function ownedStateWriter(filename, initial) {
  privateStat(path.dirname(filename), true);
  freshWrite(filename, JSON.stringify(initial, null, 2) + '\n');
  let original = privateStat(filename, false);
  return value => {
    const current = privateStat(filename, false);
    requireThat(current.dev === original.dev && current.ino === original.ino);
    const temporary = filename + '.' + crypto.randomUUID() + '.tmp';
    freshWrite(temporary, JSON.stringify(value, null, 2) + '\n');
    const candidate = privateStat(temporary, false);
    try {
      const beforeRename = privateStat(filename, false);
      requireThat(beforeRename.dev === original.dev && beforeRename.ino === original.ino);
      fs.renameSync(temporary, filename); original = privateStat(filename, false);
    } catch (error) {
      const remaining = privateStat(temporary, false);
      if (remaining.dev === candidate.dev && remaining.ino === candidate.ino) fs.unlinkSync(temporary);
      throw error;
    }
  };
}

export function prepare(directory, mediaPort, controlPort, root = PRIVATE) {
  const target = privatePath(directory, root);
  privateStat(path.dirname(target), true);
  requireThat(Number.isInteger(mediaPort) && Number.isInteger(controlPort) && mediaPort >= 1024 &&
    mediaPort <= 65535 && controlPort >= 1024 && controlPort <= 65535 && mediaPort !== controlPort);
  fs.mkdirSync(target, { mode: 0o700 });
  const png = checkerPng(), nonce = crypto.randomBytes(16).toString('hex');
  const spec = { formatVersion: 1, fixture: 'ui-viewer-test-media', status: 'prepared_offline',
    createdAt: new Date().toISOString(), sourceSha256: sha(fs.readFileSync(SELF)), mediaPort, controlPort, nonce,
    controlKey: crypto.randomBytes(32).toString('hex'),
    paths: { health: '/health', png: `/viewer-${nonce}/small.png`, missing: `/viewer-${nonce}/missing.png` },
    png: { file: path.join(target, 'small.png'), sha256: sha(png), bytes: png.length, width: 64, height: 40, mime: 'image/png' } };
  freshWrite(spec.png.file, png);
  const specFile = path.join(target, 'spec.json'), bytes = Buffer.from(JSON.stringify(spec, null, 2) + '\n');
  freshWrite(specFile, bytes);
  return { specFile, specSha256: sha(bytes), pngSha256: spec.png.sha256 };
}

function approvedSpec(filename, expectedSha256) {
  const specFile = privatePath(filename); privateStat(path.dirname(specFile), true); privateStat(specFile, false);
  const bytes = fs.readFileSync(specFile); requireThat(sha(bytes) === expectedSha256);
  const spec = JSON.parse(bytes);
  requireThat(keysAre(spec, ['formatVersion', 'fixture', 'status', 'createdAt', 'sourceSha256', 'mediaPort', 'controlPort', 'nonce', 'controlKey', 'paths', 'png']) &&
    spec.formatVersion === 1 && spec.fixture === 'ui-viewer-test-media' && spec.status === 'prepared_offline' &&
    spec.sourceSha256 === sha(fs.readFileSync(SELF)) && /^[0-9a-f]{32}$/.test(spec.nonce) && /^[0-9a-f]{64}$/.test(spec.controlKey));
  requireThat(Number.isInteger(spec.mediaPort) && Number.isInteger(spec.controlPort) && spec.mediaPort >= 1024 &&
    spec.mediaPort <= 65535 && spec.controlPort >= 1024 && spec.controlPort <= 65535 && spec.mediaPort !== spec.controlPort);
  requireThat(keysAre(spec.paths, ['health', 'png', 'missing']) && spec.paths.health === '/health' &&
    spec.paths.png === `/viewer-${spec.nonce}/small.png` && spec.paths.missing === `/viewer-${spec.nonce}/missing.png`);
  requireThat(keysAre(spec.png, ['file', 'sha256', 'bytes', 'width', 'height', 'mime']) &&
    spec.png.file === path.join(path.dirname(specFile), 'small.png') && spec.png.width === 64 && spec.png.height === 40 && spec.png.mime === 'image/png');
  privatePath(spec.png.file); privateStat(spec.png.file, false);
  const png = fs.readFileSync(spec.png.file);
  requireThat(png.equals(checkerPng()) && sha(png) === spec.png.sha256 && png.length === spec.png.bytes);
  return { spec, png, specFile, specSha256: sha(bytes) };
}

/** Injectable timers/clock are only for pure offline fake-stream tests. No server is created here. */
export function handlers(spec, png, onChange = () => {}, timers = { setTimeout, clearTimeout }) {
  const requests = [], gates = [], streams = new Set();
  let armed = null, held = null, sequence = 0;
  const changed = () => onChange({ requests, gates });
  const json = (res, status, value) => {
    if (res.destroyed) return;
    try { res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(value)); }
    catch { res.destroy(); }
  };
  const sendPng = item => {
    item.record.responseAttempted = !item.res.destroyed;
    if (!item.res.destroyed) {
      try {
        item.res.writeHead(200, { 'Content-Type': 'image/png', 'Content-Length': png.length, 'Cache-Control': 'no-store' });
        item.record.responseStatus = 200; item.res.end(png);
      }
      catch { item.record.streamError = true; item.res.destroy(); }
    }
    changed();
  };
  const release = (gateId, reason) => {
    requireThat(held !== null && held.gate.id === gateId && !held.gate.released);
    const item = held; held = null; timers.clearTimeout(item.timer);
    item.gate.released = true; item.gate.releaseReason = reason; item.gate.releasedAt = new Date().toISOString();
    sendPng(item); return item.gate;
  };
  const media = (req, res) => {
    res.on('error', () => {}); req.on('error', () => {});
    if (req.method !== 'GET') { json(res, 405, { status: 'method_not_allowed' }); return; }
    if (requests.length >= MAX_REQUESTS) { json(res, 429, { status: 'bounded_fixture_limit' }); return; }
    const kind = req.url === spec.paths.png ? 'png' : req.url === spec.paths.missing ? 'missing' : req.url === '/health' ? 'health' : 'unregistered';
    // Payload SHA is known fixture bytes; stream finish is not a Native decode acknowledgement.
    const record = { id: ++sequence, kind, receivedAt: new Date().toISOString(), requestComplete: req.complete === true,
      requestAborted: false, requestError: false, responseStatus: 0,
      responseAttempted: false, responseFinished: false, downstreamClosed: false, downstreamClosedBeforeRelease: false,
      streamError: false, gateId: '', AuthPresent: typeof req.headers.authorization === 'string' && req.headers.authorization.length > 0,
      CookiePresent: typeof req.headers.cookie === 'string' && req.headers.cookie.length > 0,
      RefererMatchesWeb: req.headers.referer === 'https://sitkin.top/',
      bytesSha256: kind === 'png' ? spec.png.sha256 : '', width: kind === 'png' ? 64 : 0, height: kind === 'png' ? 40 : 0 };
    requests.push(record); streams.add(res);
    req.on('end', () => { record.requestComplete = true; changed(); });
    req.on('aborted', () => { record.requestAborted = true; changed(); });
    req.on('error', () => { record.requestError = true; changed(); });
    res.on('finish', () => { record.responseFinished = true; changed(); });
    res.on('error', () => { record.streamError = true; changed(); });
    res.on('close', () => {
      streams.delete(res); record.downstreamClosed = true;
      if (record.gateId && !gates.find(gate => gate.id === record.gateId)?.released) record.downstreamClosedBeforeRelease = true;
      changed();
    });
    req.resume(); changed();
    if (kind !== 'png') {
      record.responseAttempted = true; record.responseStatus = kind === 'health' ? 200 : 404;
      json(res, record.responseStatus, { status: kind === 'health' ? 'healthy_synthetic_fixture' : 'not_found' }); return;
    }
    if (armed === null) { sendPng({ res, record }); return; }
    const gate = armed; armed = null; record.gateId = gate.id; gate.requestId = record.id;
    gate.heldAt = new Date().toISOString(); gate.holdMs = HOLD_MS;
    const item = { res, record, gate, timer: null }; held = item;
    item.timer = timers.setTimeout(() => { if (held === item) release(gate.id, 'bounded_timeout'); }, HOLD_MS);
    item.timer?.unref?.(); changed();
  };
  const control = (req, res) => {
    res.on('error', () => {}); req.on('error', () => {});
    if (req.headers.authorization !== spec.controlKey) { req.resume(); json(res, 401, { status: 'unauthorized' }); return; }
    if (req.method === 'GET' && req.url === '/requests') { json(res, 200, { requests, gates, armed: armed !== null, held: held !== null }); return; }
    if (req.method !== 'POST' || !['/gateOnce', '/release'].includes(req.url)) { req.resume(); json(res, 404, { status: 'not_found' }); return; }
    let body = '', rejected = false;
    req.on('data', bytes => { body += bytes.toString('utf8'); if (body.length > 256) { rejected = true; json(res, 413, { status: 'too_large' }); req.destroy(); } });
    req.on('end', () => {
      if (rejected) return;
      try {
        const value = JSON.parse(body);
        if (req.url === '/gateOnce') {
          requireThat(keysAre(value, []) && armed === null && held === null && gates.length < 32 &&
            requests.some(row => row.kind === 'png' && row.responseStatus === 200 && row.responseFinished && !row.streamError && !row.gateId));
          armed = { id: crypto.randomUUID(), requestId: null, released: false, releaseReason: '', createdAt: new Date().toISOString() };
          gates.push(armed); changed(); json(res, 200, { status: 'armed', gateId: armed.id });
        } else {
          requireThat(keysAre(value, ['gateId']) && typeof value.gateId === 'string');
          const gate = release(value.gateId, 'explicit_release'); json(res, 200, { status: 'released', gateId: gate.id });
        }
      } catch { json(res, 409, { status: 'gate_precondition_failed' }); }
    });
  };
  const dispose = () => {
    armed = null;
    if (held !== null) { timers.clearTimeout(held.timer); held.gate.released = true; held.gate.releaseReason = 'owned_shutdown'; held = null; }
    for (const stream of streams) stream.destroy();
    changed();
  };
  return { media, control, dispose };
}

async function start(specFile, expectedSha256, stateFile) {
  const approved = approvedSpec(specFile, expectedSha256), filename = privatePath(stateFile);
  requireThat(path.dirname(filename) === path.dirname(approved.specFile) && filename !== approved.specFile && filename !== approved.spec.png.file);
  const state = { formatVersion: 1, fixture: 'ui-viewer-test-media', status: 'starting', pid: process.pid,
    uid: process.getuid(), processBirth: new Date(Date.now() - process.uptime() * 1000).toISOString(), processBirthNonce: crypto.randomUUID(),
    sourceFile: SELF, sourceSha256: sha(fs.readFileSync(SELF)), specFile: approved.specFile, specSha256: approved.specSha256,
    mediaPort: approved.spec.mediaPort, controlPort: approved.spec.controlPort, controlKey: approved.spec.controlKey,
    nonce: approved.spec.nonce, paths: approved.spec.paths, png: approved.spec.png, requests: [], gates: [] };
  const writeState = ownedStateWriter(filename, state), servers = [];
  let closing = false, api;
  const save = update => {
    Object.assign(state, update);
    try {
      writeState(state);
    } catch {
      if (!closing) { closing = true; api?.dispose(); for (const server of servers) { try { server.close(); } catch {} } }
      process.exitCode = 1;
    }
  };
  api = handlers(approved.spec, approved.png, save);
  const shutdown = () => { if (closing) return; closing = true; api.dispose(); for (const server of servers) { try { server.close(); } catch {} } save({ status: 'stopped' }); };
  try {
    for (const handler of [api.media, api.control]) {
      const server = http.createServer(handler); server.on('clientError', (_error, socket) => socket.destroy());
      server.requestTimeout = 15000; server.headersTimeout = 15000; server.keepAliveTimeout = 1000;
      server.maxConnections = 16; server.maxRequestsPerSocket = 32;
      servers.push(server);
      await new Promise((resolve, reject) => { server.once('error', reject); server.listen(servers.length === 1 ? state.mediaPort : state.controlPort, '127.0.0.1', resolve); });
      server.on('error', shutdown);
    }
    save({ status: 'listening' });
    process.once('SIGINT', shutdown); process.once('SIGTERM', shutdown);
    console.log(JSON.stringify({ status: 'listening_synthetic_only', stateFile: path.relative(ROOT, filename), sourceSha256: state.sourceSha256 }));
  } catch { shutdown(); throw new Error('Owned synthetic listeners did not start'); }
}

async function main(args) {
  if (args.length === 0 || args.includes('--help')) { console.log('Usage: ui-viewer-test-media.mjs prepare --output-dir PRIVATE_FRESH --media-port PORT --control-port PORT | start --spec PRIVATE --expected-spec-sha SHA --state PRIVATE_FRESH'); return; }
  const [command, ...rest] = args, options = {};
  requireThat(rest.length % 2 === 0);
  for (let i = 0; i < rest.length; i += 2) { requireThat(rest[i].startsWith('--') && !(rest[i] in options)); options[rest[i]] = rest[i + 1]; }
  if (command === 'prepare') {
    requireThat(keysAre(options, ['--output-dir', '--media-port', '--control-port']));
    const result = prepare(options['--output-dir'], Number(options['--media-port']), Number(options['--control-port']));
    console.log(JSON.stringify({ status: 'prepared_offline_no_listener', specFile: path.relative(ROOT, result.specFile), specSha256: result.specSha256, pngSha256: result.pngSha256 }));
  } else {
    requireThat(command === 'start' && keysAre(options, ['--spec', '--expected-spec-sha', '--state']));
    await start(options['--spec'], options['--expected-spec-sha'], options['--state']);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === SELF) {
  main(process.argv.slice(2)).catch(() => { console.error(JSON.stringify({ status: 'not_started_or_incomplete', valuesOmitted: true })); process.exitCode = 1; });
}

import assert from 'node:assert/strict';
import http from 'node:http';
import { mkdtemp, readFile, stat, rm, access } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { createIsolatedResponseGate } from './isolated-response-gate.mjs';
const hash = b => createHash('sha256').update(b).digest('hex');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const state = { mode: 'real isolated PocketBase', playerId: 'qa0000000000001', account: 'fixture_account', controlBase: 'http://127.0.0.1:10001', proxyBase: 'http://127.0.0.1:10002' };
const owned = '/api/files/game_players/' + state.playerId + '/current_avatar.jpg';
const fixture = Buffer.from([0xff, 0xd8, 0xff, 0x46, 0x49, 0x58, 0x54, 0x55, 0x52, 0x45]);
let payload = fixture;
let upstreamStatus = 200;
let healthy = true;
const session = { ownerSha256: hash(state.account + state.playerId + state.controlBase), phases: ['avatar-saved'],
  avatarName: 'previous_png.png', avatarPath: '/unused/old.png', outputImage: { sha256: '0'.repeat(64) } };
const dir = await mkdtemp(path.join(os.tmpdir(), 'starward-gate-fixture-'));
let gate, upstream, downstream;
const checks = [];
function check(label, condition) { assert.ok(condition, label); checks.push(label); }
async function listen(server) { await new Promise(resolve => server.listen(0, '127.0.0.1', resolve)); return 'http://127.0.0.1:' + server.address().port; }
async function stop(server) { if (server) { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); } }
try {
  gate = await createIsolatedResponseGate({ state, privateDirectory: dir, readSession: async () => {
    if (!healthy) throw Error('deliberately missing fixture'); return session;
  } });
  const receipt = JSON.parse(await readFile(gate.receiptPath, 'utf8'));
  check('private receipt mode600', ((await stat(gate.receiptPath)).mode & 0o777) === 0o600);
  const call = async (route, body = {}, token = receipt.controlToken) => {
    const res = await fetch(receipt.controlBase + route, { method: 'POST', headers: { Authorization: token, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    return { status: res.status, body: await res.json() };
  };
  const status = async () => (await call('/status')).body.current;
  const waitState = async expected => {
    for (let i=0; i<200; i++) { const s=await status(); if (s?.state===expected) return s; await pause(5); }
    throw Error('fixture state deadline: ' + expected);
  };
  upstream = http.createServer((req, res) => { res.writeHead(req.url.startsWith('/api/health') ? 200 : upstreamStatus, { 'Content-Type': 'image/jpeg', 'Cache-Control': 'no-store', 'X-Fixture': 'original' }); res.end(req.url.startsWith('/api/health') ? 'healthy' : payload); });
  const origin = await listen(upstream);
  downstream = http.createServer((req, res) => {
    const ticket = gate.claim(req, res);
    const outgoing = http.request(origin + req.url, { method: req.method }, remote => {
      if (ticket) void ticket.hold(remote);
      else { res.writeHead(remote.statusCode, remote.headers); remote.pipe(res); }
    });
    outgoing.on('error', () => { ticket?.fail('FIXTURE_FORWARD_FAILED'); res.destroy(); });
    res.on('error', () => {});
    req.pipe(outgoing);
  });
  const base = await listen(downstream);
  const request = suffix => {
    let receivedHeaders = false;
    let finished = false;
    let client;
    const result = new Promise(resolve => {
      client = http.get(base + suffix, res => {
        receivedHeaders = true; const chunks=[];
        res.on('data', chunk => chunks.push(chunk));
        res.on('end', () => { finished = true; resolve({ kind:'end', status:res.statusCode, headers:res.headers, data:Buffer.concat(chunks) }); });
        res.on('error', () => resolve({kind:'error'}));
      });
      client.on('error', () => resolve({kind:'error'}));
    });
    return { client, result, get headers() { return receivedHeaders; }, get finished() { return finished; } };
  };
  const arm = async (extra={}) => call('/arm', { path: owned, expectedSha256: hash(fixture), ttlMs: 2000, ...extra });
  check('control rejects missing token', (await call('/status', {}, '')).status===403);
  for (const bad of ['/api/files/game_players/qa0000000000002/alien.jpg', owned+'?token=never-retain', owned+'/nested', owned.replace('current_avatar.jpg','%2E%2E'), owned.replace('current_avatar.jpg','%2561.jpg')]) {
    check('reject malformed or foreign own-path fixture', (await arm({path:bad})).status===400);
  }
  check('reject ttl over14s', (await arm({ttlMs:14001})).status===400);
  check('reject missing expected digest', (await arm({expectedSha256:''})).status===400);
  healthy=false; check('missing private session cannot arm', (await arm()).status===400); healthy=true;
  session.ownerSha256='wrong'; check('foreign private session cannot arm', (await arm()).status===400); session.ownerSha256=hash(state.account+state.playerId+state.controlBase);
  const a = await arm(); check('current file independent from historicalPNG receipt', a.status===200);
  check('second arm rejected while live', (await arm()).status===409);
  const pending = request(owned+'?token=fixture-never-record');
  const held = await waitState('held');
  await pause(25);
  check('headers/body remain withheld', !pending.headers && !pending.finished);
  check('received and held distinct with SHA match', held.requestReceived && held.held && held.bodySha256Matched && !held.released && !held.downstreamFinished);
  const unrelated = await fetch(base+'/api/health'); check('unrelated response unaffected', await unrelated.text()==='healthy');
  const duplicate = await fetch(base+owned); check('one arm captures only one request', Buffer.from(await duplicate.arrayBuffer()).equals(fixture));
  check('wrong gate release rejected', (await call('/release',{gateId:'wrong'})).status===409);
  check('explicit release acknowledged', (await call('/release',{gateId:held.gateId})).status===200);
  const final = await pending.result; const complete = await waitState('finished');
  check('original bytes and header unchanged', final.kind==='end' && final.data.equals(fixture) && final.headers['x-fixture']==='original' && final.status===200);
  check('finish only after release, no abort', complete.released && complete.downstreamFinished && !complete.clientAborted && !complete.failed && complete.downstreamFinished.elapsedMs>=complete.released.elapsedMs);
  check('release cannot replay', (await call('/release',{gateId:held.gateId})).status===409);
  const ledgerText=JSON.stringify((await call('/status')).body);
  check('ledger and manifest omit path/token/body/credentials', !ledgerText.includes(owned) && !ledgerText.includes('fixture-never-record') && !ledgerText.includes(receipt.controlToken) && !ledgerText.includes('fixture_account'));
  await arm(); const aborted=request(owned); await waitState('held'); aborted.client.destroy(); await aborted.result;
  const closed=await waitState('failed'); check('client close records abort without finish', closed.clientAborted && !closed.downstreamFinished && closed.failed);
  await arm({ttlMs:100}); const expired=request(owned); await waitState('held'); await expired.result;
  const timed=await waitState('failed'); check('expiry aborts held response without release or finish', timed.failed.reason==='EXPIRED' && !timed.released && !timed.downstreamFinished && !expired.headers);
  await arm({expectedSha256:'0'.repeat(64)}); const mismatch=request(owned); await mismatch.result;
  const badSha=await waitState('failed'); check('real bytes mismatch fails closed', badSha.failed.reason==='ORIGINAL_BODY_SHA256_MISMATCH' && !mismatch.headers && !badSha.held);
  upstreamStatus=403; await arm(); const forbidden=request(owned); await forbidden.result;
  const badStatus=await waitState('failed'); check('upstream non200 fails closed', badStatus.failed.reason==='UPSTREAM_NOT_200' && !forbidden.headers); upstreamStatus=200;
  payload=Buffer.alloc(2*1024*1024+1); await arm({expectedSha256:hash(payload)}); const huge=request(owned); await huge.result;
  const oversized=await waitState('failed'); check('over2MiB fails closed', oversized.failed.reason==='BODY_LIMIT' && !huge.headers); payload=fixture;
  await arm(); const stopping=request(owned); await waitState('held'); await gate.close(); await stopping.result;
  await assert.rejects(access(gate.receiptPath)); check('stop aborts withheld response and removes receipt', !stopping.headers);
  console.log(JSON.stringify({status:'passed',environment:'host-only synthetic HTTP fixtures; no live state/CA/PB/device',count:checks.length,checks},null,2));
} finally { await gate?.close(); await stop(downstream); await stop(upstream); await rm(dir,{recursive:true,force:true}); }

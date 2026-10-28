#!/usr/bin/env node
/** Protocol probes only against this runner's disposable database. Never production. */
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import https from 'node:https';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const state = JSON.parse(await readFile(path.join(root, 'artifacts/private/https-isolation/state.json'), 'utf8'));
assert.equal(state.mode, 'real isolated PocketBase');
const base = process.env.STARWARD_HTTPS_BASE || state.tls?.hostBase || state.proxyBase;
const target = new URL(base);
if (![state.proxyBase, state.tls?.hostBase, state.tls?.base].includes(base)) throw new Error('Probe URL must match this runner state; no arbitrary remote targets');
if (target.hostname === 'api.sitkin.top' || (target.protocol !== 'https:' && !['127.0.0.1', 'localhost'].includes(target.hostname))) throw new Error('Only isolated HTTPS or local runner is allowed');
const checks = [];
async function request(route, { method = 'GET', body, token, headers = {} } = {}) {
  const selectedHeaders = { Accept: 'application/json', ...(token ? { Authorization: token } : {}), ...(body ? { 'Content-Type': 'application/json' } : {}), ...headers };
  if (target.protocol === 'https:' && state.tls?.caPath) {
    const ca = await readFile(state.tls.caPath);
    return new Promise((resolve, reject) => {
      const req = https.request(base + route, { method, headers: selectedHeaders, ca, rejectUnauthorized: true }, response => {
        const chunks = [];
        response.on('data', chunk => chunks.push(chunk));
        response.on('error', reject);
        response.on('end', () => {
          try {
            resolve({ status: response.statusCode, data: JSON.parse(Buffer.concat(chunks).toString('utf8')), headers: new Headers(response.headers) });
          } catch (error) { reject(error); }
        });
      });
      req.on('error', reject);
      req.setTimeout(20000, () => req.destroy(new Error('Isolated HTTPS probe timed out')));
      req.end(body ? JSON.stringify(body) : undefined);
    });
  }
  const response = await fetch(base + route, { method, headers: selectedHeaders, body: body ? JSON.stringify(body) : undefined });
  const data = await response.json();
  return { status: response.status, data, headers: response.headers };
}

function check(label, actual, expected) { assert.equal(actual, expected, label); checks.push(label); }
async function reset() {
  const response = await fetch(state.controlBase + '/reset', { method: 'POST', headers: { Authorization: state.controlToken, 'Content-Type': 'application/json' }, body: '{}' });
  assert.equal(response.status, 200);
}
let report;
try {
  await reset();
  check('Real PocketBase health', (await request('/api/health')).status, 200);
  for (const route of ['/_/', '/api/collections/_superusers/auth-with-password', '/api/questions/v1/admin/catalog', '/__test/normalize', '/__control/reset']) {
    check('Public proxy blocks ' + route, (await request(route, { method: route.includes('auth-with-password') ? 'POST' : 'GET' })).status, 404);
  }
  check('Anonymous player endpoint rejects access', (await request('/api/questions/v1/me')).status, 401);
  check('Wrong synthetic password fails', (await request('/api/collections/game_players/auth-with-password', { method: 'POST', body: { identity: state.account, password: 'deliberately-wrong-test-password' } })).status, 400);
  const auth = await request('/api/collections/game_players/auth-with-password', { method: 'POST', body: { identity: state.account, password: state.initialPassword } });
  check('Real player authentication', auth.status, 200);
  assert.equal(typeof auth.data.token, 'string');
  const before = await request('/api/questions/v1/me', { token: auth.data.token });
  check('Real player me before change', before.status, 200);
  check('Backend requires first password change', before.data.mustChangePassword, true);
  check('Unchanged password blocks assignments', (await request('/api/questions/v1/assignments', { token: auth.data.token })).status, 403);
  const changed = await request('/api/questions/v1/me/change-password', { method: 'POST', token: auth.data.token, body: { oldPassword: state.initialPassword, password: state.newPassword, passwordConfirm: state.newPassword } });
  check('Real password rotation', changed.status, 200);
  check('Backend removes mandatory gate after change', changed.data.player.mustChangePassword, false);
  check('Old token invalid after password rotation', (await request('/api/questions/v1/me', { token: auth.data.token })).status, 401);
  const list = await request('/api/questions/v1/assignments', { token: changed.data.token });
  check('Authenticated assignments', list.status, 200);
  check('Normal/time/rank test scenarios seeded', list.data.items.length, 4);
  const detail = await request('/api/questions/v1/assignments/' + state.assignmentId, { token: changed.data.token });
  check('Real read-only assignment detail', detail.status, 200);
  check('Detail title is fixture baseline', detail.data.title, '星辰探险');
  check('Unstarted question remains protected', detail.data.levels[0].question, null);
  check('Real serverTime is a valid timestamp', Number.isFinite(Date.parse(detail.data.serverTime)), true);
  check('Proxy prevents start mutation outside first slice', (await request('/api/questions/v1/assignments/' + state.assignmentId + '/start', { method: 'POST', token: changed.data.token, body: {} })).status, 404);
  const file = await request('/api/files/token', { method: 'POST', token: changed.data.token, body: {} });
  check('Real protected file token endpoint', file.status, 200);
  check('File token shape', typeof file.data.token, 'string');
  const cors = await request('/api/health', { headers: { Origin: 'http://localhost:5188' } });
  check('Isolated Web localhost CORS', cors.headers.get('access-control-allow-origin'), 'http://localhost:5188');
  report = { status: 'passed', transport: target.protocol === 'https:' ? state.tls?.caPath ? 'HTTPS with ephemeral test CA and strict certificate/hostname validation' : 'HTTPS with normal TLS validation' : 'local HTTP setup probe; not native HTTPS evidence', backend: 'PocketBase 0.40.1 linux/arm64; real frozen hooks and migrations', count: checks.length, checks, productionRequests: 0, syntheticCredentialsOmitted: true, firstPasswordChangeRestored: true };
} catch (error) {
  report = { status: 'failed', count: checks.length, checks, error: error.message, syntheticCredentialsOmitted: true };
  process.exitCode = 1;
} finally {
  await reset();
}
await mkdir(path.join(root, 'artifacts/validation'), { recursive: true });
const name = target.protocol === 'https:' ? 'real-pb-https-probe.json' : 'real-pb-local-probe.json';
await writeFile(path.join(root, 'artifacts/validation', name), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ status: report.status, count: report.count, report: 'artifacts/validation/' + name, initialStateRestored: true }));

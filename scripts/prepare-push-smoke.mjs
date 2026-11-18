#!/usr/bin/env node
/** Standalone disposable HTTPS Push smoke. Does not build, install or map a device. */
import { createServer as createHttpServer, request as httpRequest } from 'node:http';
import { createServer as createHttpsServer } from 'node:https';
import { execFileSync } from 'node:child_process';
import { chmod, lstat, mkdtemp, readFile, realpath, unlink, writeFile } from 'node:fs/promises';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createTestServer } from '../../sitkin-pb-backend-management/backend/tests/server.mjs';

const nativeRoot = fileURLToPath(new URL('..', import.meta.url));
const privateRoot = path.join(nativeRoot, 'artifacts/private');
const root = '/api/questions/v1';
const recordId = /^[a-z0-9]{15}$/;
const kinds = ['assignment', 'letter', 'announcement'];
const [command, ...args] = process.argv.slice(2);
const certTool = '/usr/bin/openssl';
const imageTag = 'questions-pocketbase:starward-push-crypto-test';
const random = (bytes) => randomBytes(bytes).toString('hex');
const use = message => { throw new Error(message); };
const output = data => console.log(JSON.stringify(data));

function run(program, args) {
  try {
    return execFileSync(program, args, { encoding: 'utf8', stdio: 'pipe', timeout: 25000 }).trim();
  } catch {
    return use(`Could not complete ${path.basename(program)} prerequisite; private output omitted.`);
  }
}

async function checkSecretPath(filename) {
  try {
    const normalized = await realpath(filename);
    const stat = await lstat(filename);
    const checkoutParent = path.dirname(path.resolve(nativeRoot));
    if (filename === normalized && !normalized.startsWith(checkoutParent + path.sep) &&
        stat.isFile() && !stat.isSymbolicLink() && stat.uid === process.getuid() &&
        [0o400, 0o600].includes(stat.mode & 0o777) && !/[\r\n,]/.test(normalized) &&
        stat.size >= 200 && stat.size <= 16384)
      return normalized; // Copying, reading and printing the key are deliberately avoided.
  } catch {}
  use('Use an owned mode0400/0600 AGC JSON file at a real absolute path outside the checkouts.');
}

async function prepareTLS(directory) {
  const files = Object.fromEntries(['ca.key', 'ca.pem', 'ca.cnf', 'server.key', 'server.pem', 'server.csr', 'server.ext']
    .map(name => [name, path.join(directory, name)]));
  await writeFile(files['ca.cnf'], '[req]\ndistinguished_name=dn\nx509_extensions=ca\n[dn]\n[ca]\nbasicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign,cRLSign\n');
  run(certTool, ['ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', files['ca.key']]);
  run(certTool, ['req', '-x509', '-new', '-sha256', '-days', '2', '-key', files['ca.key'],
    '-out', files['ca.pem'], '-config', files['ca.cnf'], '-subj', '/CN=Starward disposable Push smoke CA']);
  run(certTool, ['ecparam', '-name', 'prime256v1', '-genkey', '-noout', '-out', files['server.key']]);
  run(certTool, ['req', '-new', '-key', files['server.key'], '-out', files['server.csr'], '-subj', '/CN=127.0.0.1']);
  await writeFile(files['server.ext'], 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\nsubjectAltName=IP:127.0.0.1\n', { mode: 0o600 });
  run(certTool, ['x509', '-req', '-in', files['server.csr'], '-CA', files['ca.pem'], '-CAkey', files['ca.key'],
    '-set_serial', '0x' + random(16), '-out', files['server.pem'], '-sha256', '-days', '2', '-extfile', files['server.ext']]);
  run(certTool, ['verify', '-CAfile', files['ca.pem'], files['server.pem']]);
  for (const name of ['ca.key', 'server.key']) await chmod(files[name], 0o600);
  const ca = await readFile(files['ca.pem']);
  return { path: files['ca.pem'], sha256: createHash('sha256').update(ca).digest('hex'),
    key: await readFile(files['server.key']), cert: await readFile(files['server.pem']) };
}

function permitted(method, pathname) {
  return (method === 'GET' && ['/api/health', ...['me', 'assignments', 'notifications', 'rewards']
    .map(name => root + '/' + name)].includes(pathname)) ||
    (method === 'GET' && pathname.startsWith(root + '/assignments/') && recordId.test(pathname.slice((root + '/assignments/').length))) ||
    (method === 'POST' && (pathname === '/api/collections/game_players/auth-with-password' ||
      ['me/push/register', 'me/push/unregister', 'push/revoke'].some(name => pathname === root + '/' + name)));
}

function respond(response, statusCode, body) {
  response.writeHead(statusCode, {'Content-Type': 'application/json', 'Cache-Control': 'no-store'});
  response.end(JSON.stringify(body));
}

async function serve() {
  const live = args[0] === '--live-test';
  if (live ? args.length !== 3 || !/^[0-9]{5,32}$/.test(args[1]) : args.length !== 0)
    use('Usage: node scripts/prepare-push-smoke.mjs serve [--live-test PROJECT_ID /absolute/owned/key.json]');
  const sidecar = live ? await checkSecretPath(args[2]) : undefined;
  const info = await lstat(privateRoot);
  if (privateRoot !== await realpath(privateRoot) || !info.isDirectory() || info.uid !== process.getuid() ||
      (info.mode & 0o077)) use('The existing private artifact parent must be owned and private.');
  const imageId = run('docker', ['image', 'ls', '--no-trunc', '--filter', 'reference=' + imageTag, '--format', '{{.ID}}']);
  if (!/^sha256:[0-9a-f]{64}$/.test(imageId)) use('Missing the verified local PocketBase + OpenSSL test image.');
  const image = run('docker', ['inspect', '--type', 'image', '--format', '{{.Id}} {{.Architecture}}', imageId]).split(' ');
  if (image.length !== 2 || !/^sha256:[0-9a-f]{64}$/.test(image[0]) || image[1] !== 'arm64')
    use('Expected the verified local arm64 PocketBase + OpenSSL test image.');
  run('docker', ['run', '--rm', '--network=none', '--entrypoint', 'openssl', image[0], 'version']);
  const runDirectory = await mkdtemp(path.join(privateRoot, 'push-smoke-'));
  await chmod(runDirectory, 0o700);
  const removeSecrets = async () => {
    await Promise.all(['login.json', 'ca.key', 'server.key'].map(async name => {
      try { await unlink(path.join(runDirectory, name)); }
      catch (error) { if (error.code !== 'ENOENT') throw error; }
    }));
  };
  const playerId = random(8).slice(0, 15);
  const env = {
    STARWARD_PUSH_ENABLED: '1', STARWARD_PUSH_TEST_MODE: '1', STARWARD_PUSH_TEST_PLAYER_ID: playerId,
    STARWARD_PUSH_PROJECT_ID: live ? args[1] : '',
  };
  let pb, tls;
  try {
    tls = await prepareTLS(runDirectory);
    process.env.PB_DOCKER_IMAGE = image[0];
    process.env.TMPDIR = runDirectory;
    pb = await createTestServer({ env, pushSmokeSecretFile: sidecar });
  } catch {
    await removeSecrets();
    use('Isolated TLS or PocketBase did not start; private logs omitted.');
  }
  let gateway, control, closing = false, busy = false;
  const close = async () => {
    if (closing) return;
    closing = true;
    gateway?.closeAllConnections();
    gateway?.close();
    control?.close();
    try { await pb.stop(); } finally { await removeSecrets(); }
  };
  const account = 'push_smoke_' + random(4), password = 'T-' + random(18);
  const source = '/api/collections/';
  const api = async (route, body, token = pb.superToken) => {
    const result = await pb.request(route, { method: body ? 'POST' : 'GET', body, token });
    if (result.status !== 200) use('Isolated fixture request failed (HTTP ' + result.status + ').');
    return result.data;
  };
  const admin = (route, body = {}) => api(root + '/admin/' + route, { ...body, requestId: randomUUID() }, pb.adminToken);
  const list = async (name) => (await api(source + name + '/records?perPage=200')).items;
  const triggered = new Set();
  let session;
  try {
    const player = await api(source + 'game_players/records', {
      id: playerId, account, password, passwordConfirm: password, displayName: '推送验收旅人',
      status: 'active', mustChangePassword: false,
    });
    if (player.id !== playerId) use('The generated test player is not the configured test allowlist.');
    await api(source + 'game_player_stats/records', { player: playerId, totalXp: 0 });
    const q = await admin('questions', {
      title: 'Push 隔离样题', kind: 'text', content: [{text: '这道题仅用于验证通知打开场次。'}],
      acceptedAnswers: ['北星'],
    });
    await admin('questions/' + q.id + '/publish');
    session = await admin('sessions', { title: '星港航标 · Push 隔离验收',
      levels: [{question: q.id, xp: 0}] });
    await admin('sessions/' + session.id + '/publish');
    gateway = createHttpsServer({ key: tls.key, cert: tls.cert, minVersion: 'TLSv1.2' }, (req, res) => {
      if (!req.url || !permitted(req.method, req.url)) return respond(res, 404, {});
      const address = new URL(pb.base);
      const headers = Object.fromEntries(['authorization', 'content-type', 'content-length', 'accept']
        .filter(name => req.headers[name]).map(name => [name, req.headers[name]]));
      const upstream = httpRequest({
        hostname: '127.0.0.1', port: address.port, method: req.method, path: req.url, headers,
      }, result => {
        res.writeHead(result.statusCode, {'Content-Type': result.headers['content-type'] || 'application/json', 'Cache-Control': 'no-store'});
        result.on('error', () => res.destroy());
        result.pipe(res);
      });
      upstream.setTimeout(15000, () => upstream.destroy());
      upstream.on('error', () => { if (!res.headersSent) respond(res, 502, {}); else res.destroy(); });
      req.on('aborted', () => upstream.destroy());
      req.on('error', () => upstream.destroy());
      res.on('close', () => { if (!res.writableEnded) upstream.destroy(); });
      req.pipe(upstream);
    });
    await new Promise((resolve, reject) => {
      gateway.once('error', reject);
      gateway.listen(0, '127.0.0.1', resolve);
    });
    control = createHttpServer(async (request, response) => {
      if (request.method !== 'POST') return respond(response, 405, {});
      if (request.url === '/stop') {
        try { await close(); return respond(response, 200, {stopped: true}); }
        catch { process.exitCode = 1; return respond(response, 500, {error: 'Isolated cleanup did not confirm.'}); }
      }
      const kind = request.url.slice('/trigger/'.length);
      try {
        const bindings = await list('game_push_bindings');
        if (request.url === '/status') {
          const deliveries = (await list('game_push_deliveries')).map(item => ({
            kind: item.kind, status: item.status, attempts: item.attempts, providerCode: item.providerCode,
          }));
          const receipts = await list('game_notification_receipts');
          const assignments = await list('game_assignments');
          return respond(response, 200, {liveTest: live, bindings: bindings.length,
            deliveries, readReceipts: receipts.filter(x => x.readAt).length,
            assignments: assignments.map(x => x.status),
            answerSubmissions: (await list('game_answer_submissions')).length});
        }
        if (!request.url.startsWith('/trigger/') || !kinds.includes(kind))
          return respond(response, 404, {error: 'Unknown local smoke operation.'});
        if (busy || bindings.length !== 1 || bindings[0].player !== playerId || triggered.has(kind))
          return respond(response, 409, {error: 'Requires exactly one allowed binding and an unused case.'});
        busy = true;
        triggered.add(kind); // If interrupted, check status instead of replaying an unknown write.
        try {
          if (kind === 'assignment') await admin('assignments', {
            sessionId: session.id, target: 'selected', playerIds: [playerId],
          });
          else await admin('notifications', {
            target: 'selected', playerIds: [playerId],
            title: kind === 'letter' ? '星港来信 · 隔离验收' : '星港公告 · 隔离验收',
            content: '这条消息仅供隔离验收，请从通知中心点击并确认旅途来信。',
          });
        } finally { busy = false; }
        respond(response, 200, {liveTest: live, kind, triggerCommitted: true});
      } catch {
        respond(response, 500, {error: 'Isolated operation did not confirm; inspect status without replaying.'});
      }
    });
    const socket = path.join(runDirectory, 'control.sock');
    await new Promise((resolve, reject) => {
      control.once('error', reject);
      control.listen(socket, resolve);
    });
    await chmod(socket, 0o600);
    const loginFile = path.join(runDirectory, 'login.json');
    await writeFile(loginFile, JSON.stringify({account, password}) + '\n', { flag: 'wx', mode: 0o600 });
    output({ready: true, liveTest: live, hostHttpsPort: gateway.address().port, privateRunDirectory: runDirectory,
      publicCaPath: tls.path, caSha256: tls.sha256, loginFile, credentialsPrinted: false, deviceMappingChanged: false});
    process.once('SIGINT', () => close().catch(() => { process.exitCode = 1; }));
    process.once('SIGTERM', () => close().catch(() => { process.exitCode = 1; }));
  } catch {
    await close();
    use('Push isolated fixture or proxy did not prepare; no live send requested.');
  }
}

async function local() {
  const [directory, kind] = args;
  if (command === 'trigger' ? args.length !== 2 || !kinds.includes(kind) : args.length !== 1)
    use('Usage: node scripts/prepare-push-smoke.mjs status|stop RUN_DIR or trigger RUN_DIR assignment|letter|announcement');
  const runDirectory = path.resolve(directory);
  if (runDirectory !== await realpath(runDirectory) || path.dirname(runDirectory) !== privateRoot ||
      !/^push-smoke-[a-zA-Z0-9]+$/.test(path.basename(runDirectory)))
    use('A disposable Push run directory from this checkout is required.');
  const socket = path.join(runDirectory, 'control.sock');
  const stat = await lstat(socket), parent = await lstat(runDirectory);
  if (!stat.isSocket() || stat.uid !== process.getuid() || (stat.mode & 0o777) !== 0o600 ||
      !parent.isDirectory() || parent.uid !== process.getuid() || (parent.mode & 0o777) !== 0o700)
    use('The Push run socket is not owned by this local user.');
  await new Promise((resolve, reject) => {
    const req = httpRequest({socketPath: socket,
      path: command === 'trigger' ? '/trigger/' + kind : '/' + command, method: 'POST'}, response => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', chunk => { body += chunk; });
      response.on('end', () => {
        if (response.statusCode !== 200) return reject(new Error('Isolated control HTTP ' + response.statusCode));
        output(JSON.parse(body));
        resolve();
      });
    });
    req.setTimeout(command === 'stop' ? 12000 : 5000, () => req.destroy());
    req.on('error', reject);
    req.end();
  });
}

try {
  if (command === 'serve') await serve();
  else if (['status', 'stop', 'trigger'].includes(command)) await local();
  else use('Usage: node scripts/prepare-push-smoke.mjs serve|status|stop|trigger');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}

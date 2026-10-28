#!/usr/bin/env node
/** Strict ephemeral TLS for the disposable player proxy over official USB reverse forwarding. */
import https from 'node:https';
import http from 'node:http';
import { readFile, writeFile, mkdir, chmod, rm, unlink } from 'node:fs/promises';
import { spawn, spawnSync } from 'node:child_process';
import { createHash, createPublicKey, X509Certificate } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const privateRoot = path.join(root, 'artifacts/private/https-isolation');
const statePath = path.join(privateRoot, 'state.json');
const tlsDir = path.join(privateRoot, 'tls');
const rawCa = path.join(root, 'entry/src/main/resources/rawfile/integration-ca.pem');
const operation = process.argv[2] || 'status';
const devicePort = 18443;
const openssl = '/opt/homebrew/bin/openssl';
function exec(program, args) {
  const result = spawnSync(program, args, { encoding: 'utf8', stdio: 'pipe' });
  if (result.status !== 0) throw new Error(program + ' failed (output omitted)');
  return result.stdout;
}
async function state() { return JSON.parse(await readFile(statePath, 'utf8')); }
async function persist(value) { await writeFile(statePath, JSON.stringify(value, null, 2) + '\n', { mode: 0o600 }); await chmod(statePath, 0o600); }
if (operation === 'stop') { const s = await state(); if (!s.tls?.pid) throw new Error('No own TLS runner recorded'); process.kill(s.tls.pid, 'SIGTERM'); console.log('Stopping only this TLS runner and its reverse forward.'); process.exit(0); }
if (operation === 'status') { const s = await state(); console.log(JSON.stringify({ configured: !!s.tls, ...(s.tls ? { base: s.tls.base, hostPort: s.tls.hostPort, fingerprint: s.tls.fingerprint } : {}) })); process.exit(0); }
if (!['start', 'resume'].includes(operation)) throw new Error('Usage: isolated-tls.mjs start|resume|status|stop');
const s = await state();
const reuse = operation === 'resume';
const previousTls = s.tls;
if (s.mode !== 'real isolated PocketBase' || new URL(s.proxyBase).hostname !== '127.0.0.1') throw new Error('Requires this disposable loopback player proxy');
if (s.tls?.pid) {
  try { process.kill(s.tls.pid, 0); throw new Error('Own TLS runner already active; stop it before replacing certificates'); }
  catch (error) { if (error.code !== 'ESRCH') throw error; }
}
const forwards = exec('hdc', ['fport', 'ls']);
if (!reuse && forwards.includes('tcp:' + devicePort)) throw new Error('Device port already forwarded; no existing mapping was changed');
await mkdir(tlsDir, { recursive: true, mode: 0o700 });
const caKey = path.join(tlsDir, 'ca.key');
const ca = path.join(tlsDir, 'ca.pem');
const key = path.join(tlsDir, 'server.key');
const csr = path.join(tlsDir, 'server.csr');
const cert = path.join(tlsDir, 'server.pem');
const ext = path.join(tlsDir, 'server.ext');
if (!reuse) {
exec(openssl, ['genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256', '-out', caKey]);
exec(openssl, ['req', '-new', '-x509', '-sha256', '-days', '2', '-key', caKey, '-out', ca, '-subj', '/CN=Starward temporary integration CA', '-addext', 'basicConstraints=critical,CA:TRUE,pathlen:0', '-addext', 'keyUsage=critical,keyCertSign,cRLSign']);
exec(openssl, ['genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256', '-out', key]);
exec(openssl, ['req', '-new', '-key', key, '-out', csr, '-subj', '/CN=127.0.0.1']);
await writeFile(ext, 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\nsubjectAltName=IP:127.0.0.1\n');
exec(openssl, ['x509', '-req', '-in', csr, '-CA', ca, '-CAkey', caKey, '-CAcreateserial', '-days', '2', '-sha256', '-extfile', ext, '-out', cert]);
await chmod(caKey, 0o600); await chmod(key, 0o600);
}
const caBytes = await readFile(ca);
const caDigest = createHash('sha256').update(caBytes).digest('hex');
const fingerprint = exec(openssl, ['x509', '-in', cert, '-noout', '-fingerprint', '-sha256']).trim().split('=').at(-1);
if (reuse) {
  if (!previousTls || previousTls.base !== 'https://127.0.0.1:' + devicePort ||
      !Number.isInteger(previousTls.hostPort) || previousTls.hostPort < 1024 || previousTls.hostPort > 65535 ||
      previousTls.hostBase !== 'https://127.0.0.1:' + previousTls.hostPort ||
      previousTls.caPath !== ca || previousTls.rawCaPath !== rawCa ||
      previousTls.caSha256 !== caDigest || previousTls.fingerprint !== fingerprint ||
      createHash('sha256').update(await readFile(rawCa)).digest('hex') !== caDigest) {
    throw new Error('Resume refused: saved TLS identity or packaged public CA does not match');
  }
  const certificate = new X509Certificate(await readFile(cert));
  const authority = new X509Certificate(caBytes);
  const now = Date.now();
  if (certificate.subjectAltName !== 'IP Address:127.0.0.1' ||
      Date.parse(certificate.validFrom) > now || Date.parse(authority.validFrom) > now ||
      Date.parse(certificate.validTo) <= now + 300000 || Date.parse(authority.validTo) <= now + 300000 ||
      !certificate.publicKey.export({ type: 'spki', format: 'der' }).equals(
        createPublicKey(await readFile(key)).export({ type: 'spki', format: 'der' }))) {
    throw new Error('Resume refused: certificate validity, SAN or private-key match failed');
  }
  exec(openssl, ['verify', '-CAfile', ca, '-verify_ip', '127.0.0.1', cert]);
} else {
  await mkdir(path.dirname(rawCa), { recursive: true });
  await writeFile(rawCa, caBytes);
}
const proxyOrigin = new URL(s.proxyBase);
const gateway = https.createServer({ key: await readFile(key), cert: await readFile(cert), minVersion: 'TLSv1.2' }, (req, res) => {
  let upstream, remote;
  let aborted = false;
  const abort = () => {
    if (aborted) return;
    aborted = true;
    upstream?.destroy();
    remote?.destroy();
    res.destroy();
  };
  // Consume errors on both incoming and outgoing streams. A client disconnect
  // is local to one request, including while a real write is already committed.
  req.on('error', abort);
  req.on('aborted', abort);
  res.on('error', abort);
  res.on('close', () => { if (!res.writableFinished) abort(); });
  try {
    upstream = http.request({ hostname: '127.0.0.1', port: proxyOrigin.port, path: req.url, method: req.method,
      headers: { ...req.headers, host: proxyOrigin.host } }, response => {
      remote = response;
      remote.on('aborted', abort);
      remote.on('error', abort);
      remote.on('close', () => { if (!remote.complete) abort(); });
      if (aborted || res.destroyed) { remote.destroy(); return; }
      try { res.writeHead(remote.statusCode, remote.headers); remote.pipe(res); }
      catch { abort(); }
    });
    upstream.on('error', abort);
    upstream.setTimeout(30000, abort);
    req.pipe(upstream);
  } catch { abort(); }
});
gateway.on('connection', socket => socket.on('error', () => {}));
gateway.on('clientError', (_error, socket) => { socket.on('error', () => {}); socket.destroy(); });
gateway.on('tlsClientError', (_error, socket) => { socket.on('error', () => {}); socket.destroy(); });
await new Promise((resolve, reject) => {
  gateway.once('error', reject);
  gateway.listen(reuse ? previousTls.hostPort : 0, '127.0.0.1', resolve);
});
gateway.on('error', error => console.error(JSON.stringify({ event: 'gateway-error', code: error.code || 'UNKNOWN' })));
const hostPort = gateway.address().port;
let forwardInstalled = false;
let forwardCreated = false;
let forwardReused = false;
try {
  const matching = forwards.split(/\r?\n/).filter(line => line.includes('tcp:' + devicePort));
  if (reuse && matching.length) {
    if (matching.length !== 1 || !matching[0].includes('tcp:' + hostPort)) throw new Error('Saved reverse forward does not match; no mapping changed');
    forwardReused = true;
  } else {
    const response = exec('hdc', ['rport', 'tcp:' + devicePort, 'tcp:' + hostPort]);
    if (/\[Fail\]|error/i.test(response)) throw new Error('Official reverse forwarding rejected');
    forwardCreated = true;
  }
  forwardInstalled = true;
  const current = exec('hdc', ['fport', 'ls']);
  if (!current.includes('tcp:' + devicePort) || !current.includes('tcp:' + hostPort)) throw new Error('Reverse forwarding was not confirmed');
  forwardInstalled = true;
  const hostBase = 'https://127.0.0.1:' + hostPort;
  const curl = args => new Promise((resolve, reject) => {
    const child = spawn('curl', ['--max-time', '10', '--connect-timeout', '5', ...args], { stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    child.stdout.on('data', chunk => { stdout += chunk; });
    child.on('error', reject);
    child.on('exit', status => resolve({ status, stdout }));
  });
  const [positive, untrusted, wrongHost] = await Promise.all([
    curl(['--silent', '--show-error', '--cacert', ca, '--output', '/dev/null', '--write-out', '%{http_code}', hostBase + '/api/health']),
    curl(['--silent', '--output', '/dev/null', hostBase + '/api/health']),
    curl(['--silent', '--cacert', ca, '--resolve', 'localhost:' + hostPort + ':127.0.0.1', '--output', '/dev/null', 'https://localhost:' + hostPort + '/api/health'])
  ]);
  if (positive.status !== 0 || positive.stdout !== '200' || untrusted.status !== 60 || wrongHost.status !== 60) throw new Error('Strict TLS positive/negative checks did not match');
  const latest = await state();
  latest.tls = { ...(reuse ? previousTls : {}), base: 'https://127.0.0.1:' + devicePort, hostBase, hostPort, devicePort, caPath: ca, rawCaPath: rawCa, caSha256: caDigest, fingerprint, pid: process.pid, reverseForward: 'official hdc rport; this mapping only', expiresInDays: 2,
    ...(reuse ? { resumedAt: new Date().toISOString(), previousPid: previousTls.pid, certificateReused: true, reverseForwardReused: forwardReused } : {}) };
  await persist(latest);
  const evidence = { status: 'passed', checks: 3, operation, positive: 'curl --cacert: HTTP200', withoutCa: 'curl exit60: untrusted chain rejected', wrongHostname: 'curl --cacert for localhost: exit60, SAN mismatch rejected', san: ['IP:127.0.0.1'], tlsVerificationDisabled: false, systemTrustStoreModified: false, nativeTrust: 'API26 caData only in isolated test config', certificateFingerprintSha256: fingerprint, caSha256: caDigest, reverseForwardConfirmed: true, certificateReused: reuse, reverseForwardReused: forwardReused, backendReset: false, causeOfPriorTermination: 'not established; original execution output unavailable' };
  await mkdir(path.join(root, 'artifacts/validation'), { recursive: true });
  const evidenceName = reuse ? 'isolated-tls-resume.json' : 'isolated-tls.json';
  await writeFile(path.join(root, 'artifacts/validation', evidenceName), JSON.stringify(evidence, null, 2) + '\n');
  console.log(JSON.stringify({ ready: true, deviceBase: latest.tls.base, hostPort, caPath: ca, fingerprint, certificateReused: reuse, evidence: 'artifacts/validation/' + evidenceName }));
} catch (error) {
  gateway.close();
  if (forwardCreated) spawnSync('hdc', ['fport', 'rm', 'tcp:' + devicePort, 'tcp:' + hostPort], { stdio: 'pipe' });
  throw error;
}
let stopping = false;
const stop = async () => {
  if (stopping) return; stopping = true;
  gateway.close();
  if (forwardInstalled) spawnSync('hdc', ['fport', 'rm', 'tcp:' + devicePort, 'tcp:' + hostPort], { stdio: 'pipe' });
  try { const latest = await state(); if (latest.tls?.pid === process.pid) { delete latest.tls; await persist(latest); } } catch {}
  try { if (createHash('sha256').update(await readFile(rawCa)).digest('hex') === caDigest) await unlink(rawCa); } catch {}
  await rm(tlsDir, { recursive: true, force: true });
  process.exit(0);
};
process.on('SIGINT', stop); process.on('SIGTERM', stop);

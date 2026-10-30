#!/usr/bin/env node
/** Adapt only startup waiting in the frozen, read-only backend test harness. */
import { readFile, writeFile, mkdir, chmod } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const startupTimeoutMs = 120000;
const healthRequestTimeoutMs = 1500;

function replaceExactlyOnce(source, before, after, name) {
  const occurrences = source.split(before).length - 1;
  if (occurrences !== 1) throw new Error('Isolation harness anchor must occur exactly once: ' + name);
  return source.replace(before, after);
}

export async function prepareIsolationHarness(backendDirectory, privateRootDirectory,
  reportFile = path.join(root, 'artifacts/validation/profile/environment-harness.json')) {
  const backend = path.resolve(backendDirectory);
  const sourceFile = path.join(backend, 'tests/server.mjs');
  const runtimeFile = path.join(backend, 'scripts/runtime.mjs');
  const sourceBytes = await readFile(sourceFile);
  const source = sourceBytes.toString('utf8');
  if (!Buffer.from(source, 'utf8').equals(sourceBytes)) throw new Error('Isolation harness source is not valid UTF-8');
  // Validate the imported module exists without executing it or starting PB.
  await readFile(runtimeFile);
  let adapted = replaceExactlyOnce(source,
    '} from "../scripts/runtime.mjs";',
    '} from ' + JSON.stringify(pathToFileURL(runtimeFile).href) + ';',
    'frozen runtime import');
  adapted = replaceExactlyOnce(adapted,
    '    for (let i = 0; i < 400; i++) {',
    '    const startupDeadline = Date.now() + ' + startupTimeoutMs + ';\n' +
      '    while (Date.now() < startupDeadline) {',
    'startup wait loop');
  adapted = replaceExactlyOnce(adapted,
    '        if ((await fetch(`${base}/api/health`)).ok) {',
    '        if ((await fetch(`${base}/api/health`, { signal: AbortSignal.timeout(' + healthRequestTimeoutMs + ') })).ok) {',
    'startup health request');
  const adapterBytes = Buffer.from(adapted, 'utf8');
  const harnessDirectory = path.join(path.resolve(privateRootDirectory), 'harness');
  await mkdir(harnessDirectory, { recursive: true, mode: 0o700 });
  const frozenSource = path.join(harnessDirectory, 'source-server.mjs');
  const adapterFile = path.join(harnessDirectory, 'server.mjs');
  await writeFile(frozenSource, sourceBytes, { mode: 0o600 });
  await writeFile(adapterFile, adapterBytes, { mode: 0o600 });
  await chmod(frozenSource, 0o600);
  await chmod(adapterFile, 0o600);
  // Re-read both files and the original so a concurrent source change fails
  // before the caller imports the adapter or creates a server.
  const [originalAfter, frozenAfter, adapterAfter] = await Promise.all([
    readFile(sourceFile), readFile(frozenSource), readFile(adapterFile)
  ]);
  if (!originalAfter.equals(sourceBytes) || !frozenAfter.equals(sourceBytes) || !adapterAfter.equals(adapterBytes)) {
    throw new Error('Isolation harness source or prepared bytes changed');
  }
  const evidence = {
    status: 'prepared_not_executed',
    preparedAt: new Date().toISOString(),
    source: 'frozen backend/tests/server.mjs; original file left unchanged',
    sourceSha256: sha256(sourceBytes),
    adapter: 'artifacts/private/https-isolation/harness/server.mjs',
    adapterSha256: sha256(adapterBytes),
    changes: [
      { anchor: 'static ../scripts/runtime.mjs import', occurrences: 1,
        replacement: 'Absolute file URL of the original frozen backend scripts/runtime.mjs' },
      { anchor: '400 iterations with50ms delay', occurrences: 1,
        replacement: 'Explicit Date.now() startup deadline', startupTimeoutMs },
      { anchor: 'startup GET /api/health', occurrences: 1,
        replacement: 'Bounded AbortSignal.timeout for each readiness request', healthRequestTimeoutMs }
    ],
    unchanged: ['business hooks', 'migrations', 'seed logic', 'contracts', 'database lifecycle', '50ms poll delay'],
    originalSourceUnchanged: true,
    serverStartedByPreparation: false,
    acceptanceCredit: 'Preparation and source-integrity evidence only; not startup, HTTPS or UI acceptance'
  };
  await mkdir(path.dirname(reportFile), { recursive: true });
  await writeFile(reportFile, JSON.stringify(evidence, null, 2) + '\n');
  return { moduleUrl: pathToFileURL(adapterFile).href, sourceSha256: evidence.sourceSha256,
    adapterSha256: evidence.adapterSha256, reportFile };
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const prepared = await prepareIsolationHarness(
    process.env.STARWARD_BACKEND_SOURCE || path.join(root, '../sitkin-pb-backend-management/backend'),
    path.join(root, 'artifacts/private/https-isolation'));
  console.log(JSON.stringify({ prepared: true, sourceSha256: prepared.sourceSha256,
    adapterSha256: prepared.adapterSha256, serverStarted: false,
    report: path.relative(root, prepared.reportFile) }));
}

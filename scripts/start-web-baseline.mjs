#!/usr/bin/env node
// Frozen source only. All Vite cache output stays in this project's private artifacts.
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
const root = path.resolve(import.meta.dirname, '..');
const web = path.resolve(process.env.STARWARD_WEB_SOURCE || path.join(root, '../questions-web'));
if (process.argv.includes('--help')) {
  console.log('Usage: node scripts/start-web-baseline.mjs (STARWARD_WEB_SOURCE optional; port 5178)');
  process.exit(0);
}
const frozen = '4b7d1a0a00051ac630e459b0fd6c074f821d7455';
if (execFileSync('git', ['rev-parse', 'HEAD'], { cwd: web, encoding: 'utf8' }).trim() !== frozen) {
  throw new Error('Frozen Web source commit changed. Review the baseline before capture.');
}
if (execFileSync('git', ['status', '--porcelain'], { cwd: web, encoding: 'utf8' }).trim()) {
  throw new Error('Web source is dirty; capture a clean frozen baseline.');
}
process.env.VITE_POCKETBASE_URL = process.env.STARWARD_BASELINE_API_URL || 'http://127.0.0.1:18790';
process.env.VITE_PUBLIC_BASE = '/';
process.env.VITE_ANALYTICS_ENABLED = 'false';
process.chdir(web);
const { createServer } = await import(pathToFileURL(path.join(web, 'node_modules/vite/dist/node/index.js')).href);
const original = (await import(pathToFileURL(path.join(web, 'vite.config.ts')).href)).default;
const config = await original({ command: 'serve', mode: 'development', isSsrBuild: false, isPreview: false });
const server = await createServer({
  ...config,
  configFile: false,
  root: web,
  cacheDir: path.join(root, 'artifacts/private/web-baseline-vite-cache'),
  server: { ...config.server, host: '127.0.0.1', port: Number(process.env.STARWARD_BASELINE_PORT || 5178), strictPort: true },
  logLevel: 'warn'
});
await server.listen();
console.log('Frozen Web baseline server ready; default API requires capture-script interception.');
for (const event of ['SIGINT', 'SIGTERM']) process.on(event, async () => { await server.close(); process.exit(0); });

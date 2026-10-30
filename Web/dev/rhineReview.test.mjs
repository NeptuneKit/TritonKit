import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { mkdtemp, realpath, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { build, createServer } from 'vite';
import { reviewProductionGuard } from '@linhey/rhine-design/review/vite';

const server = await createServer({ configFile: false, server: { middlewareMode: true, hmr: false, ws: false }, optimizeDeps: { noDiscovery: true }, ssr: { noExternal: ['@linhey/rhine-design'] } });
after(() => server.close());
const { default: catalog } = await server.ssrLoadModule('/design/catalog.tsx');
const { parseReviewState } = await server.ssrLoadModule('/node_modules/@linhey/rhine-design/review/state.ts');
const { makeWorkbenchFixture } = await server.ssrLoadModule('/design/fixtures.ts');

test('review declares all four real surfaces, read-only role and recoverable synthetic states', () => {
  assert.deepEqual(catalog.widths, [400, 520, 880, 1280]);
  assert.deepEqual(catalog.scenes.map(scene => scene.id), ['run-atlas', 'device-preview', 'hierarchy-inspector', 'workspace']);
  for (const scene of catalog.scenes) assert.equal(scene.dimensions.find(d => d.id === 'role').options[0].id, 'reader');
  const state = parseReviewState('#scene=run-atlas&d.state=error&theme=arknights&width=400&zoom=2', catalog);
  assert.equal(state.dimensions.state, 'error');
  assert.equal(state.theme, 'arknights');
  assert.equal(state.width, 400);
  assert.equal(state.zoom, 2);
  assert.equal(parseReviewState('#d.state=invalid&width=1', catalog).dimensions.state, 'ready');
});

test('each synthetic fixture owns its data and keeps failures distinct from empty results', () => {
  const ready = makeWorkbenchFixture('ready');
  const empty = makeWorkbenchFixture('empty');
  const failed = makeWorkbenchFixture('failed');
  assert.equal(empty.paths.length, 0);
  assert.equal(failed.run.status, 'failed');
  assert.equal(ready.run.status, 'paused');
  ready.paths.length = 0;
  assert.ok(makeWorkbenchFixture('ready').paths.length > 0);
  assert.ok(makeWorkbenchFixture('long').run.goal.length > 100);
});

test('production guard rejects emitted design fixtures and review modules, allows ordinary entry', async () => {
  const directory = await realpath(await mkdtemp(join(tmpdir(), 'triton-rhine-guard-')));
  try {
    await writeFile(join(directory, 'entry.js'), 'export const product = 1;');
    await writeFile(join(directory, 'fixture.js'), 'export const synthetic = "design-only";');
    const config = {
      configFile: false, root: directory, logLevel: 'silent',
      plugins: [reviewProductionGuard({ forbidden: ['./fixture.js'] })],
      build: { write: false, lib: { entry: join(directory, 'entry.js'), formats: ['es'], fileName: 'product' } },
    };
    await build(config);
    await writeFile(join(directory, 'entry.js'), 'export { synthetic } from "./fixture.js";');
    await assert.rejects(build(config), /Production bundle imports review runtime or forbidden fixtures/);
    await writeFile(join(directory, 'entry.js'), `export { parseReviewState } from ${JSON.stringify(resolve('node_modules/@linhey/rhine-design/review/state.ts'))};`);
    await assert.rejects(build(config), /Production bundle imports review runtime or forbidden fixtures/);
  } finally { await rm(directory, { recursive: true, force: true }); }
});

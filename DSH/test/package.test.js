import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, realpath, stat } from 'node:fs/promises';
import { apply, inject } from '../host.js';

const root = new URL('../', import.meta.url);
test('bundle exports include all runtime, metadata and original icon resources', async () => {
  const manifest = JSON.parse(await readFile(new URL('package.json', root), 'utf8'));
  assert.equal(manifest.name, '@neptunekit/dsh-tritonkit-host');
  assert.equal(manifest.dsh.bundle.patch, './cordis.patch.yml');
  assert.equal(manifest.exports['.'], './host.js');
  assert.equal(manifest.exports['./locale/*.json'], './locale/*.json');
  assert.equal(manifest.exports['./icon'], './icon.svg');
  assert.equal(manifest.engines.dsh, '0.2.2-rc.1');
  assert.equal(manifest.dependencies, undefined);
  assert.equal(manifest.scripts.postinstall, undefined);
  for (const entry of ['host.js', 'commands.js', 'cordis.patch.yml', 'locale/*.json', 'icon.svg', 'README.md']) {
    assert.ok(manifest.files.includes(entry), `Missing packed resource declaration: ${entry}`);
  }
  const canonical = await realpath(root);
  for (const name of ['host.js', 'commands.js', 'cordis.patch.yml', 'README.md', 'icon.svg', 'locale/en.json', 'locale/zh.json']) {
    const path = await realpath(new URL(name, root));
    assert.ok(path.startsWith(`${canonical}/`));
    assert.ok((await stat(path)).isFile());
  }
  const patch = await readFile(new URL('cordis.patch.yml', root), 'utf8');
  assert.ok(patch.includes(`name: '${manifest.name}'`));
  for (const lang of ['en', 'zh']) {
    const { meta } = JSON.parse(await readFile(new URL(`locale/${lang}.json`, root), 'utf8'));
    assert.equal(meta.title, 'TritonKit');
    assert.ok(meta.description.length > 40);
  }
  const svg = await readFile(new URL('icon.svg', root), 'utf8');
  assert.ok(Buffer.byteLength(svg) < 256 * 1024);
  assert.match(svg, /<svg xmlns="http:\/\/www.w3.org\/2000\/svg"/u);
  assert.doesNotMatch(svg, /<script|<foreignObject|href=/iu);
});

test('tool contract size stays bounded without injecting a separate system prompt', () => {
  const tools = [];
  const ctx = { effect: fn => fn(), tools: { register: tool => { tools.push(tool); return () => {}; } } };
  apply(ctx, {});
  assert.deepEqual(inject, ['tools', 'subprocess', 'workingDirectory', 'sandboxPolicy']);
  const schemas = tools.map(({ name, description, parameters }) => ({ name, description, parameters }));
  assert.ok(Buffer.byteLength(JSON.stringify(schemas)) < 16384);
  for (const { parameters } of schemas) {
    for (const [key, property] of Object.entries(parameters.properties)) {
      if (!parameters.required.includes(key)) assert.ok(property.oneOf.some(item => item.type === 'null'));
    }
  }
});

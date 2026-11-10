import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtemp, realpath, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

test('actual npm archive includes exactly the runtime and display resources', async () => {
  const parent = await realpath(tmpdir());
  const directory = await mkdtemp(join(parent, 'tritonkit-dsh-pack-'));
  try {
    const packed = JSON.parse(execFileSync('npm', ['pack', '--json', '--ignore-scripts', '--pack-destination', directory], {
      cwd: fileURLToPath(new URL('../', import.meta.url)), encoding: 'utf8', timeout: 15000, maxBuffer: 1048576,
    }))[0];
    const expected = ['README.md', 'commands.js', 'cordis.patch.yml', 'host.js', 'icon.svg', 'locale/en.json', 'locale/zh.json', 'package.json'].sort();
    assert.deepEqual(packed.files.map(file => file.path).sort(), expected);
    const archive = join(directory, packed.filename);
    const entries = execFileSync('tar', ['-tzf', archive], { encoding: 'utf8', timeout: 5000 }).trim().split('\n');
    assert.deepEqual(entries.filter(name => !name.endsWith('/')).map(name => name.replace(/^package\//u, '')).sort(), expected);
  } finally {
    // Delete only this test-owned, canonical temporary directory.
    assert.equal(dirname(directory), parent);
    assert.ok(basename(directory).startsWith('tritonkit-dsh-pack-'));
    assert.equal(await realpath(directory), directory);
    await rm(directory, { recursive: true });
  }
});

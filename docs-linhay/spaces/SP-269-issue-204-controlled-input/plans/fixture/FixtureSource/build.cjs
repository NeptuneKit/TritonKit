const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
if (!process.env.TRITONKIT_REPO) throw new Error('Set TRITONKIT_REPO to the verified TritonKit checkout before building this external fixture');
const dependencyRoot = path.join(path.resolve(process.env.TRITONKIT_REPO), 'Web/node_modules');
const expected = {react: '19.2.7', 'react-dom': '19.2.7', esbuild: '0.27.7'};
const sha = data => crypto.createHash('sha256').update(data).digest('hex');
for (const [name, version] of Object.entries(expected)) {
  const actual = JSON.parse(fs.readFileSync(path.join(dependencyRoot, name, 'package.json'))).version;
  if (actual !== version) throw new Error(`Local ${name} version ${actual} differs from fixed ${version}`);
}
const esbuild = require(path.join(dependencyRoot, 'esbuild'));
const result = esbuild.buildSync({entryPoints: [path.join(__dirname, 'fixture.jsx')],
  absWorkingDir: root, bundle: true, format: 'iife', platform: 'browser', target: ['safari16'],
  nodePaths: [dependencyRoot], define: {'process.env.NODE_ENV': '"production"'},
  legalComments: 'inline', write: false, metafile: true});
const output = path.join(root, 'Resources/Fixture');
fs.mkdirSync(output, {recursive: true});
const bytes = result.outputFiles[0].contents;
fs.writeFileSync(path.join(output, 'fixture.js'), bytes);
const html = '<!doctype html><html data-load-id="__GENERATION__" data-ready="false"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SP269 Controlled Input</title><style>body{font:16px system-ui;padding:16px}label{display:block;margin-top:12px}textarea,input,[contenteditable]{display:block;box-sizing:border-box;width:100%;min-height:40px;font:18px system-ui;border:1px solid #777;padding:6px}[contenteditable]{min-height:60px}output{display:block;overflow-wrap:anywhere;margin-top:16px;font:12px monospace}button{margin-top:12px;padding:8px}</style></head><body><div id="root"></div><script>__BUNDLED_JS__</script></body></html>';
fs.writeFileSync(path.join(output, 'fixture.html'), html);
const inputs = Object.keys(result.metafile.inputs).sort().map(input => {
  const absolute = path.resolve(root, input);
  const label = absolute.startsWith(dependencyRoot + path.sep)
    ? 'node_modules/' + path.relative(dependencyRoot, absolute) : path.relative(root, absolute);
  return {path: label, sha256: sha(fs.readFileSync(absolute))};
});
fs.writeFileSync(path.join(output, 'BUILD_INFO.json'), JSON.stringify({
  purpose: 'SP269 owned offline acceptance fixture, not product input implementation',
  packages: expected, target: 'safari16', mode: 'production', networkDependencies: false,
  bundleSHA256: sha(bytes), htmlTemplateSHA256: sha(Buffer.from(html)),
  buildScriptSHA256: sha(fs.readFileSync(__filename)), inputs,
}, null, 2) + '\n');
console.log(JSON.stringify({packages: expected, bytes: bytes.length, bundleSHA256: sha(bytes), inputs: inputs.length}));

import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { createServer } from 'vite';

const server = await createServer({
  configFile: false, root: new URL('..', import.meta.url).pathname, appType: 'custom',
  esbuild: { jsx: 'automatic' }, server: { middlewareMode: true, hmr: false, ws: false },
  optimizeDeps: { noDiscovery: true }, ssr: { noExternal: ['@linhey/rhine-design'] },
});
after(() => server.close());
const { StreamPanel, streamImageSource } = await server.ssrLoadModule('/src/components/StreamPanel.tsx');
const { AppContext } = await server.ssrLoadModule('/src/AppContext.tsx');
const { releaseStreamImage, attachStreamImage } = await server.ssrLoadModule('/src/streamVisibility.ts');

test('default image source preserves all three platform endpoints, FPS and reconnect identity', () => {
  for (const [platform, endpoint] of [['ios', 'ios-simulator'], ['android', 'android'], ['harmony', 'harmony']]) {
    assert.equal(streamImageSource({ platform, target: 'synthetic-target', fps: 15, connectTime: 123 }), `/web/${endpoint}/mjpeg?udid=synthetic-target&fps=15&t=123`);
  }
});

test('Rhine stream renders labeled readonly controls without a nested theme or native mutation action', () => {
  const context = { getInspectSession: () => undefined };
  const html = renderToStaticMarkup(createElement(AppContext.Provider, { value: context }, createElement(StreamPanel, { nodeId: 'synthetic-stream' })));
  for (const label of ['设备预览', '调试设备', '预览设置', '刷新设备列表', '叠加层', '等待可用设备']) assert.ok(html.includes(label), label);
  assert.match(html, /<select/);
  assert.match(html, /type="radio"/);
  assert.doesNotMatch(html, /ant-select|ant-radio|rhine-theme|执行手势|\/web\/host-input/);
});

test('candidate preserves visibility/ref restoration and hierarchy hit-test integration', () => {
  const source = readFileSync(new URL('../src/components/StreamPanel.tsx', import.meta.url), 'utf8');
  assert.match(source, /observeStreamVisibility\(viewport/);
  assert.match(source, /!visible && imgRef\.current\) releaseStreamImage/);
  assert.match(source, /connected && Boolean\(selectedUdid\) && previewVisible/);
  assert.match(source, /if \(image\) attachStreamImage\(image, streamUrl\)/);
  assert.match(source, /observeFirstStreamFrame\(image/);
  assert.match(source, /hitTestHierarchyNode\(/);
  assert.match(source, /selectInspectNode\(selectedTargetKey, hit.nodeId \|\| node.id\)/);
  assert.match(source, /loadStreamTargetFps/);
  assert.match(source, /saveStreamTargetFps\(targetFps\)/);
  assert.doesNotMatch(source, /from ["']antd|mockData|design\/|sendGestureInput|fetch\(["']\/web\/host-input/);
});

test('image detach and StrictMode reattach restore the original source', () => {
  const image = { src: '/web/ios-simulator/mjpeg?fps=15', removeAttribute() {}, getAttribute(name) { return name === 'src' ? this.src : null; } };
  const original = image.src;
  releaseStreamImage(image);
  assert.match(image.src, /^data:/);
  attachStreamImage(image, original);
  assert.equal(image.src, original);
});

test('stream folds low-frequency FPS into settings and combines pane actions with refresh in the header', () => {
  const context = { getInspectSession: () => undefined };
  const html = renderToStaticMarkup(createElement(AppContext.Provider, { value: context }, createElement(StreamPanel, { nodeId: 'synthetic-stream', headerActions: createElement('button', null, 'Synthetic pane menu') })));
  const header = html.match(/<header[^>]*>[\s\S]*?<\/header>/)?.[0] ?? '';
  assert.match(header, /Synthetic pane menu/);
  assert.match(header, /刷新设备列表/);
  assert.match(header, /预览设置/);
  assert.doesNotMatch(html, /只读镜像|<option[^>]*>15 FPS/);
});

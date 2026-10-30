import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { createServer } from 'vite';

const server = await createServer({ configFile: false, root: new URL('..', import.meta.url).pathname, appType: 'custom', esbuild: { jsx: 'automatic' }, server: { middlewareMode: true, hmr: false, ws: false }, optimizeDeps: { noDiscovery: true }, ssr: { noExternal: ['@linhey/rhine-design'] } });
after(() => server.close());
const { WorkspaceCanvas, workspaceVisualDirection, dividerKeyboardDelta, createDividerMovement } = await server.ssrLoadModule('/src/components/WorkspaceCanvas.tsx');

const props = { onSplit() {}, onClose() {}, onUnload() {}, onSelectCard() {}, onDividerDrag() {}, isRoot: true, renderCard: (card, id, actions) => createElement('header', { 'data-product-header': true }, `${card}:${id}`, actions) };

test('divider movement reports adjacent deltas, ignores other pointers, and stops after cancellation', () => {
  const movement = createDividerMovement(7, 100, 500);
  const deltas = [movement.move(7, 110), movement.move(7, 120)];
  assert.equal(deltas.reduce((a, b) => a + b), 0.04);
  assert.equal(movement.move(8, 400), 0);
  assert.equal(movement.move(7, 125), 0.01);
  movement.stop();
  assert.equal(movement.move(7, 400), 0);
  assert.equal(createDividerMovement(7, 100, 0).move(7, 120), 0);
});

test('keyboard resize obeys visible orientation and stops at the ten/ninety percent bounds', () => {
  assert.equal(dividerKeyboardDelta('ArrowRight', 'v', 0.5), 0.05);
  assert.equal(dividerKeyboardDelta('ArrowDown', 'h', 0.5), 0.05);
  assert.equal(dividerKeyboardDelta('ArrowDown', 'v', 0.5), null);
  assert.equal(dividerKeyboardDelta('Home', 'v', 0.5), -0.4);
  assert.equal(dividerKeyboardDelta('End', 'h', 0.5), 0.4);
  assert.equal(dividerKeyboardDelta('ArrowRight', 'v', 0.9), 0);
});

test('narrow splits stack without changing their stored direction', () => {
  for (const width of [199, 400, 520]) assert.equal(workspaceVisualDirection('v', width), 'h');
  assert.equal(workspaceVisualDirection('v', 880), 'v');
  assert.equal(workspaceVisualDirection('h', 1280), 'h');
});

test('empty panes provide keyboard buttons for exactly the three readonly cards', () => {
  const html = renderToStaticMarkup(createElement(WorkspaceCanvas, { ...props, node: { kind: 'leaf', id: 'one', card: null } }));
  for (const label of ['设备预览', '界面层级', '运行与路径']) assert.ok(html.includes(label));
  assert.equal((html.match(/data-workspace-card=/g) || []).length, 3);
  assert.doesNotMatch(html, /执行手势|进行手势控制|ant-/);
  assert.doesNotMatch(html, /关闭当前窗格/);
});

test('split panes expose separator range and render every supplied real card', () => {
  const node = { kind: 'split', id: 'split', direction: 'v', ratio: 0.58, first: { kind: 'leaf', id: 'one', card: 'stream' }, second: { kind: 'leaf', id: 'two', card: 'inspector' } };
  const html = renderToStaticMarkup(createElement(WorkspaceCanvas, { ...props, node }));
  assert.match(html, /role="separator"/);
  assert.match(html, /aria-valuenow="58"/);
  assert.match(html, /aria-valuemin="10"/);
  assert.match(html, /aria-valuemax="90"/);
  assert.match(html, /stream:one/);
  assert.match(html, /inspector:two/);
  assert.match(html, /窗格操作/);
});


test('pane actions live in the supplied product header instead of a separate blank toolbar', () => {
  const html = renderToStaticMarkup(createElement(WorkspaceCanvas, { ...props, node: {kind:'leaf',id:'one',card:'stream'} }));
  assert.match(html, /<header[^>]*data-product-header[^>]*>[\s\S]*窗格操作[\s\S]*<\/header>/);
  assert.doesNotMatch(html, /rhine-workspace-toolbar/);
});

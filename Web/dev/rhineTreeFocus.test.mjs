import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { createServer } from 'vite';

const server = await createServer({ configFile: false, root: new URL('..', import.meta.url).pathname, appType: 'custom',
  esbuild: { jsx: 'automatic' }, server: { middlewareMode: true, hmr: false, ws: false },
  optimizeDeps: { noDiscovery: true }, ssr: { noExternal: ['@linhey/rhine-design'] } });
after(() => server.close());
const { InspectorHierarchyTree, visibleInspectorRows, recoverInspectorFocus, inspectorTreeKeyAction, inspectorNullBlurReleasesFocus } = await server.ssrLoadModule('/src/components/InspectorHierarchyTree.tsx');
const leaf = (id, children = []) => ({ id, type: 'View', name: id, frame: {x:0,y:0,width:20,height:20}, visible: true, interactive: true, depth: 0, color:'#ccc', children });
const nodes = [leaf('root', [leaf('branch', [leaf('deep')])]), leaf('last')];
const noop = () => {};
const render = props => renderToStaticMarkup(createElement(InspectorHierarchyTree, { nodes, label: 'Synthetic hierarchy', onSelect: noop, onHover: noop, ...props }));

test('nested treeitem owns child groups instead of only relying on aria-level', () => {
  const html = render({ selectedNodeId: 'deep' });
  assert.equal((html.match(/role="group"/g) ?? []).length, 2);
  assert.match(html, /data-node-id="root"[\s\S]*role="group"[\s\S]*data-node-id="branch"/);
  assert.equal((html.match(/tabindex="0"/g) ?? []).length, 1);
  const leafTag = html.match(/<div[^>]*role="treeitem"[^>]*data-node-id="deep"[^>]*>/)?.[0];
  assert.ok(leafTag); assert.doesNotMatch(leafTag, /aria-expanded=/);
});

test('missing focused descendants recover to nearest visible ancestor, then first item or empty root', () => {
  const previous = visibleInspectorRows(nodes, new Set());
  assert.equal(typeof recoverInspectorFocus, 'function');
  assert.equal(recoverInspectorFocus(previous, visibleInspectorRows(nodes, new Set(['branch'])), 'deep'), 'branch');
  assert.equal(recoverInspectorFocus(previous, visibleInspectorRows([leaf('root'), leaf('last')], new Set()), 'deep'), 'root');
  assert.equal(recoverInspectorFocus(previous, visibleInspectorRows([leaf('new')], new Set()), 'deep'), 'new');
  assert.equal(recoverInspectorFocus(previous, [], 'deep'), null);
});

test('pre-detach null blur retains ownership for removal but explicit blur releases it', () => {
  const previous = visibleInspectorRows(nodes, new Set());
  const next = visibleInspectorRows([leaf('root', [leaf('branch')]), leaf('last')], new Set());
  assert.equal(typeof inspectorNullBlurReleasesFocus, 'function');
  // Chromium fires focusout before React detaches the deleted item: isConnected is still true.
  assert.equal(inspectorNullBlurReleasesFocus(next, 'deep', true), false);
  assert.equal(recoverInspectorFocus(previous, next, 'deep'), 'branch');
  assert.equal(inspectorNullBlurReleasesFocus(previous, 'deep', true), true);
  assert.equal(inspectorNullBlurReleasesFocus(next, 'deep', false), false);
  assert.equal(inspectorNullBlurReleasesFocus([], null, true), true);
});

test('empty tree has one entry point and updates have text beyond color', () => {
  const empty = render({ nodes: [] });
  assert.match(empty, /role="tree"[^>]*tabindex="0"/);
  const updated = render({ updatedNodeIds: new Set(['deep']) });
  assert.match(updated, /已更新/);
});

test('deep nesting keeps its real level while capping visual indentation', () => {
  let deep = leaf('deepest'); for (let i=6;i>=0;i--) deep=leaf(`level-${i}`, [deep]);
  const html=render({nodes:[deep]});
  assert.match(html,/aria-level="8"/); assert.match(html,/第 8 层/);
  assert.doesNotMatch(html,/--rhine-inspector-depth:[4-9]/);
});

test('navigation focus actions remain separate from selection actions', () => {
  const rows=visibleInspectorRows(nodes,new Set());
  assert.deepEqual(inspectorTreeKeyAction(rows,'root','End',new Set()),{focus:'last'});
  assert.deepEqual(inspectorTreeKeyAction(rows,'last','Home',new Set()),{focus:'root'});
  assert.deepEqual(inspectorTreeKeyAction(rows,'deep','Enter',new Set()),{select:'deep'});
});

test('consecutive updates replace only the animated row, preserving treeitem identity', () => {
  const props = { updatedNodeIds: new Set(['deep']), selectedNodeId: 'deep' };
  for (const updateRevision of [1, 2]) {
    const html = render({ ...props, updateRevision });
    assert.match(html, new RegExp(`data-tree-row="deep"[^>]*data-update-revision="${updateRevision}"`));
    assert.equal((html.match(/tabindex="0"/g) ?? []).length, 1);
  }
  // SSR cannot exercise reconciliation; guard the stable item / replaceable animation boundary.
  const tree = readFileSync(new URL('../src/components/InspectorHierarchyTree.tsx', import.meta.url), 'utf8');
  assert.match(tree, /return <div key=\{node\.id\}/);
  assert.match(tree, /<div key=\{updated \? updateRevision : "idle"\}/);
  const panel = readFileSync(new URL('../src/components/InspectorPanel.tsx', import.meta.url), 'utf8');
  assert.match(panel, /setHighlights\(current => \(\{ \.\.\.changed, revision: current\.revision \+ 1 \}\)\)/);
  assert.match(panel, /updateRevision=\{highlights\.revision\}/);
  assert.match(panel, /setHighlights\(current => noHighlights\(current\.revision\)\)/);
});

test('tree touch targets keep 44px space and do not advertise unsupported pause', () => {
  const css = readFileSync(new URL('../src/components/inspectorPanel.css', import.meta.url), 'utf8');
  assert.match(css, /grid-template-columns: 44px minmax\(0, 1fr\)/);
  for (const selector of ['toggle', 'leaf']) {
    const rule = css.match(new RegExp(`\\.rhine-inspector-tree-${selector} \\{([^}]+)\\}`))?.[1] ?? '';
    assert.match(rule, /width: 44px/); assert.match(rule, /min-height: 44px/);
  }
  assert.doesNotMatch(css, /\.rhine-inspector-tree-row\[aria-selected/);
  assert.doesNotMatch(css, /data-rhine-motion="paused"/);
  assert.match(css, /overflow-wrap: anywhere/);
});

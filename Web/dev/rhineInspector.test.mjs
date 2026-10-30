import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { after, test } from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createServer } from "vite";

const server = await createServer({ configFile: false, root: new URL("..", import.meta.url).pathname,
  appType: "custom", esbuild: { jsx: "automatic" }, server: { hmr: false, middlewareMode: true, ws: false },
  optimizeDeps: { noDiscovery: true }, ssr: { noExternal: ["@linhey/rhine-design"] } });
after(() => server.close());
const { InspectorPanel, InspectorPropertyEditor } = await server.ssrLoadModule("/src/components/InspectorPanel.tsx");
const { InspectorHierarchyTree, visibleInspectorRows, inspectorTreeKeyAction } = await server.ssrLoadModule("/src/components/InspectorHierarchyTree.tsx");
const { AppContext } = await server.ssrLoadModule("/src/AppContext.tsx");
const { deriveViewTree } = await server.ssrLoadModule("/src/inspect/hierarchyDerive.ts");
const { buildNodePropertyDraft } = await server.ssrLoadModule("/src/inspect/nodePropertyDraft.ts");
const { makeSyntheticTargets, makeSyntheticHierarchy } = await server.ssrLoadModule('/design/syntheticData.ts');
const { SyntheticContextProvider } = await server.ssrLoadModule('/design/SyntheticContext.tsx');
const node = (id, parentId = null, extra = {}) => ({ id, parentId, name: id, type: "SyntheticView", depth: parentId ? 1 : 0,
  frame: { x: 2, y: 4, width: 120, height: 60 }, visible: true, interactive: true, color: "#cccccc", ...extra });
const nodes = [node("root"), node("child", "root", { view: { accessibilityLabel: "Synthetic text", accessibilityIdentifier: "synthetic-field" } }), node("leaf", "child"), node("last")];
const noop = () => {};
function renderPanel({ platform = "ios", loading = false, error, stale = false, target = true, scene = true, selected = "child", items = nodes, headerActions } = {}) {
  const device = { key: "synthetic-target", target: "synthetic", name: "Synthetic target", platform, inputCapabilities: [] };
  const context = {
    inspectTargets: target ? [device] : [], resolveInspectSlotTarget: () => target ? device : null,
    getInspectSession: () => ({ targetKey: device.key, selectedNodeId: selected, loading, error, stale,
      overlayMode: "view", requestSeq: 1, scene: scene ? { platform, rootId: "root", viewport: { width: 400, height: 880 }, nodes: items } : undefined }),
    refreshInspectSession: async () => null, setInspectOverlayMode: noop, selectInspectNode: noop,
    hoverInspectNode: noop, setFocusedInspectTarget: noop, bindInspectSlot: noop,
  };
  return renderToStaticMarkup(createElement(AppContext.Provider, { value: context }, createElement(InspectorPanel, { nodeId: "synthetic-inspector", headerActions })));
}

test("renders the real session and selected node with accessible view/AX trees", () => {
  const html = renderPanel();
  for (const text of ["界面层级", "目标源", "跟随", "来源说明", "简化", "视图树", "AX 树", "Synthetic text", "synthetic-field", "节点详情", "复制 DTO"]) assert.ok(html.includes(text), text);
  assert.match(html, /role="tree"/); assert.match(html, /role="treeitem"/); assert.match(html, /aria-selected="true"/);
  assert.doesNotMatch(html, /ant-|执行 patch|应用到设备/);
});
test("renders platform-specific tree sources without inventing a second AX source", () => {
  for (const platform of ["android", "harmony"]) {
    const html = renderPanel({ platform }); assert.match(html, /布局树/); assert.doesNotMatch(html, /aria-label="AX 树"/);
  }
  assert.match(renderPanel({ platform: "android", items: nodes.map(item => ({ ...item, source: "android-bridge" })) }), /辅助功能树/);
});
test("keeps last snapshot visible on refresh/failure and labels unavailable states honestly", () => {
  const loading = renderPanel({ loading: true }); assert.match(loading, /aria-busy="true"/); assert.match(loading, /更新中/); assert.match(loading, /Synthetic text/);
  const error = renderPanel({ error: "Synthetic refresh failed" }); assert.match(error, /role="alert"/); assert.match(error, /Synthetic refresh failed/); assert.match(error, /上次读取/); assert.doesNotMatch(error, />就绪</);
  assert.match(renderPanel({ target: false }), /等待连接/); assert.match(renderPanel({ stale: true }), /待更新/);
  assert.match(renderPanel({ items: [], selected: null }), /无数据或未就绪/);
});
test("tree keyboard traversal skips collapsed descendants and respects parent/child boundaries", () => {
  const collapsed = new Set(["child"]); const rows = visibleInspectorRows(deriveViewTree(nodes), collapsed);
  assert.deepEqual(rows.map(row => row.node.id), ["root", "child", "last"]);
  const act = (key, id) => inspectorTreeKeyAction(rows, id, key, collapsed);
  assert.deepEqual(act("ArrowDown", "child"), { focus: "last" }); assert.deepEqual(act("ArrowUp", "root"), { focus: "root" });
  assert.deepEqual(act("Home", "last"), { focus: "root" }); assert.deepEqual(act("End", "root"), { focus: "last" });
  assert.deepEqual(act("ArrowRight", "child"), { expand: "child" }); assert.deepEqual(act("ArrowRight", "root"), { focus: "child" });
  assert.deepEqual(act("ArrowLeft", "root"), { collapse: "root" }); assert.deepEqual(act("ArrowLeft", "child"), { focus: "root" });
  assert.deepEqual(act("Enter", "child"), { select: "child" }); assert.deepEqual(act(" ", "child"), { select: "child" }); assert.equal(act("Tab", "child"), null);
});
test("tree keeps one tab stop and full long text with depth/selection semantics", () => {
  const title = "SyntheticLongAccessibilityDescription".repeat(20);
  const tree = deriveViewTree([node("root"), node("child", "root", { style: { text: title } })]);
  const html = renderToStaticMarkup(createElement(InspectorHierarchyTree, { nodes: tree, label: "Synthetic tree", selectedNodeId: "child", onSelect: noop, onHover: noop }));
  assert.equal((html.match(/tabindex="0"/g) ?? []).length, 1); assert.match(html, /aria-level="2"/); assert.match(html, /aria-expanded="true"/); assert.ok(html.includes(title));
});
test("property draft keeps geometry, appearance, accessibility, and raw DTO panels without write actions", () => {
  const selected = nodes[1];
  const html = renderToStaticMarkup(createElement(InspectorPropertyEditor, { node: selected, draft: buildNodePropertyDraft(selected), onChange: noop }));
  for (const field of ["Geometry", "View", "Layer", "AX", "Raw", "width", "height", "userInteraction", "masksToBounds", "opacity", "accessibilityIdentifier", "accessibilityLabel", "backgroundColor", "foregroundColor", "styleAlpha", "styleCornerRadius"]) assert.ok(html.includes(field), field);
  assert.doesNotMatch(html, /type="submit"|执行|应用到设备/);
});

test('synthetic fixtures contain three anonymous platforms with a stable selectable action', () => {
  assert.deepEqual(makeSyntheticTargets('ready').map(target => target.platform), ['ios', 'android', 'harmony']);
  assert.deepEqual(makeSyntheticTargets('empty'), []);
  for (const platform of ['ios', 'android', 'harmony']) {
    const scene = makeSyntheticHierarchy(platform, 'ready');
    assert.equal(scene.platform, platform);
    assert.ok(scene.nodes.some(node => node.id === 'child-action' && node.interactive));
    assert.deepEqual(makeSyntheticHierarchy(platform, 'empty').nodes, []);
    assert.ok(makeSyntheticHierarchy(platform, 'long').nodes.some(node => (node.view?.accessibilityLabel?.length ?? 0) > 150));
  }
});
test('synthetic context exposes initial selection and explicit loading/error/empty states without a network request', () => {
  const render = state => renderToStaticMarkup(createElement(SyntheticContextProvider, { state, selectedNode: true }, createElement(InspectorPanel, { nodeId: 'synthetic-context-inspector' })));
  assert.match(render('ready'), /节点详情/);
  assert.match(render('loading'), /更新中/);
  assert.match(render('error'), /合成层级读取失败/);
  assert.match(render('empty'), /无数据或未就绪/);
});

test('inspector places refresh and pane actions in one header and keeps source mechanisms on demand', () => {
  const html = renderPanel({ headerActions: createElement('button', null, 'Synthetic pane menu') });
  const header = html.match(/<header[^>]*>[\s\S]*?<\/header>/)?.[0] ?? '';
  assert.match(header, /更新层级/);
  assert.match(header, /Synthetic pane menu/);
  assert.match(html, /来源说明/);
  assert.match(html, /<section class="rhine-inspector"/);
  const source = readFileSync(new URL('../src/components/InspectorPanel.tsx', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /height="min\(760px/);
});

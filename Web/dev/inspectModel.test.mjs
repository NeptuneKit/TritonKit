import assert from "node:assert/strict";
import { after, test } from "node:test";
import { createServer } from "vite";

const viteServer = await createServer({
  appType: "custom",
  server: {
    hmr: false,
    middlewareMode: true,
    ws: false,
  },
});

const { inspectTargetFromDeviceTarget } = await viteServer.ssrLoadModule("/src/inspect/target.ts");
const {
  createInspectSessionState,
  inspectSessionReducer,
  resolveSlotTargetKey,
  sessionRefreshRequest,
  sessionRefreshSucceeded,
} = await viteServer.ssrLoadModule("/src/inspect/sessionStore.ts");
const { deriveAxTree, deriveOverlayNodes, deriveViewTree } = await viteServer.ssrLoadModule("/src/inspect/hierarchyDerive.ts");
const { hitTestHierarchyNode } = await viteServer.ssrLoadModule("/src/inspect/hitTest.ts");

after(async () => {
  await viteServer.close();
});

test("inspect target preserves hierarchy source for iOS simulator and real device", () => {
  const simulator = inspectTargetFromDeviceTarget({
    id: "host:ios:SIM-1",
    name: "iPhone",
    platform: "ios",
    device: "iPhone",
    appName: "App",
    bundleId: "app",
    os: "iOS",
    status: "ready",
    statusLabel: "ready",
    transport: "simctl",
    screenshotTone: "blue",
    screenSize: "390x844",
    fps: 15,
    latencyMs: 0,
    proxyMode: "off",
    proxyLabel: "off",
    hierarchyNodes: 0,
    lastAction: "",
    actionResult: "ok",
    accent: "#fff",
    Icon: function Icon() {},
    scope: "simulator",
    kind: "simulator",
    targetSelector: "SIM-1",
    screenshotSource: "host",
    inputCapabilities: [{ action: "tap", source: "host", supported: true }],
  });
  const real = inspectTargetFromDeviceTarget({
    ...simulatorFixture(),
    id: "ios-real:abc",
    scope: "real",
    kind: "real-device",
    targetSelector: "ios-real:abc",
    screenshotSource: "runtime",
  });

  assert.equal(simulator.hierarchySource, "host");
  assert.equal(real.hierarchySource, "runtime");
  assert.notEqual(simulator.key, real.key);
});

test("session refresh is scoped by target and rejects stale results", () => {
  const target = inspectTargetFromDeviceTarget({ ...simulatorFixture(), targetSelector: "SIM-1" });
  let state = createInspectSessionState([target]);

  const first = sessionRefreshRequest(state, target.key);
  state = first.state;
  const second = sessionRefreshRequest(state, target.key);
  state = second.state;
  state = sessionRefreshSucceeded(state, target.key, first.seq, sceneWithNodes("old"));
  assert.equal(state.sessions[target.key].scene, undefined);

  state = sessionRefreshSucceeded(state, target.key, second.seq, sceneWithNodes("new"));
  assert.equal(state.sessions[target.key].scene.nodes[0].id, "new");
});

test("slot binding can pin one inspector while workbench focus moves", () => {
  const a = inspectTargetFromDeviceTarget({ ...simulatorFixture(), targetSelector: "SIM-A" });
  const b = inspectTargetFromDeviceTarget({ ...simulatorFixture(), targetSelector: "SIM-B" });
  let state = createInspectSessionState([a, b]);
  state = inspectSessionReducer(state, { type: "focusedTargetChanged", targetKey: b.key, sourceSlotId: "stream-b" });
  state = inspectSessionReducer(state, { type: "slotBindingChanged", slotId: "inspector-a", binding: { mode: "pinnedTarget", targetKey: a.key } });

  assert.equal(resolveSlotTargetKey(state, "inspector-a"), a.key);
  assert.equal(resolveSlotTargetKey(state, "inspector-follow"), b.key);
});

test("selected node is scoped per target session", () => {
  const a = inspectTargetFromDeviceTarget({ ...simulatorFixture(), targetSelector: "SIM-A" });
  const b = inspectTargetFromDeviceTarget({ ...simulatorFixture(), targetSelector: "SIM-B" });
  let state = createInspectSessionState([a, b]);
  state = inspectSessionReducer(state, { type: "sessionNodeSelected", targetKey: a.key, nodeId: "a-cell" });
  state = inspectSessionReducer(state, { type: "sessionNodeSelected", targetKey: b.key, nodeId: "b-cell" });

  assert.equal(state.sessions[a.key].selectedNodeId, "a-cell");
  assert.equal(state.sessions[b.key].selectedNodeId, "b-cell");
});

test("view and ax derivation keep cell grouping nodes", () => {
  const nodes = cellSceneNodes();
  const viewTree = deriveViewTree(nodes, { simplify: true });
  const axTree = deriveAxTree(nodes);

  assert.equal(flattenTree(viewTree).some((node) => node.id === "cell"), true);
  assert.equal(flattenTree(axTree).some((node) => node.id === "cell"), true);
  assert.equal(flattenTree(axTree).some((node) => node.id === "label"), true);
});

test("overlay derivation and hit test respect mode and selected ancestor descent", () => {
  const nodes = cellSceneNodes();
  const axNodes = deriveOverlayNodes(nodes, "ax");
  const hit = hitTestHierarchyNode({
    nodes,
    mode: "ax",
    point: { x: 20, y: 20 },
    selectedNodeId: "cell",
  });

  assert.equal(axNodes.some((node) => node.id === "plain-view"), false);
  assert.equal(hit.nodeId, "label");
  assert.equal(hit.reason, "selected-descendant");
});

function simulatorFixture() {
  return {
    id: "host:ios:SIM-1",
    name: "iPhone",
    platform: "ios",
    device: "iPhone",
    appName: "App",
    bundleId: "app",
    os: "iOS",
    status: "ready",
    statusLabel: "ready",
    transport: "simctl",
    screenshotTone: "blue",
    screenSize: "390x844",
    fps: 15,
    latencyMs: 0,
    proxyMode: "off",
    proxyLabel: "off",
    hierarchyNodes: 0,
    lastAction: "",
    actionResult: "ok",
    accent: "#fff",
    Icon: function Icon() {},
    scope: "simulator",
    kind: "simulator",
    targetSelector: "SIM-1",
    screenshotSource: "host",
    inputCapabilities: [{ action: "tap", source: "host", supported: true }],
  };
}

function sceneWithNodes(id) {
  return {
    platform: "ios",
    rootId: id,
    viewport: { width: 100, height: 100 },
    nodes: [{ id, type: "UIWindow", name: id, frame: box(0, 0, 100, 100), depth: 0, visible: true, interactive: false, color: "#fff" }],
  };
}

function cellSceneNodes() {
  return [
    { id: "root", type: "UIWindow", name: "root", frame: box(0, 0, 100, 100), depth: 0, visible: true, interactive: false, color: "#fff" },
    { id: "cell", parentId: "root", type: "UITableViewCell", className: "UITableViewCell", name: "cell", frame: box(10, 10, 80, 30), depth: 1, visible: true, interactive: false, color: "#fff" },
    { id: "label", parentId: "cell", type: "UILabel", name: "label", frame: box(15, 15, 20, 10), depth: 2, visible: true, interactive: false, color: "#fff", view: { accessibilityLabel: "Inbox" } },
    { id: "plain-view", parentId: "cell", type: "UIView", name: "plain", frame: box(40, 15, 20, 10), depth: 2, visible: true, interactive: false, color: "#fff" },
  ];
}

function box(x, y, width, height) {
  return { x, y, width, height };
}

function flattenTree(nodes) {
  return nodes.flatMap((node) => [node, ...flattenTree(node.children ?? [])]);
}

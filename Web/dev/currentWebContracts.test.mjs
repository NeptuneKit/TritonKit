import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { after, test } from "node:test";
import { createServer } from "vite";

const viteServer = await createServer({
  configFile: false,
  appType: "custom",
  server: {
    hmr: false,
    middlewareMode: true,
    ws: false,
  },
  optimizeDeps: {
    noDiscovery: true,
  },
});

const { hierarchyScenes } = await viteServer.ssrLoadModule("/src/data/mockData.ts");
const { SUPPORTED_CARD_TYPES, loadInitialRoot } = await viteServer.ssrLoadModule("/src/layoutModel.ts");

after(async () => {
  await viteServer.close();
});

test("keeps iOS fallback tab bar aligned with the four Overloaded bottom tabs", () => {
  const tabButtons = hierarchyScenes.ios.nodes.filter(
    (node) => node.parentId === "tabbar" && node.type === "UIButton"
  );

  assert.deepEqual(
    tabButtons.map((node) => [node.id, node.name]),
    [
      ["server-tab", "serverTab"],
      ["photos-tab", "photosTab"],
      ["music-tab", "musicTab"],
      ["settings-tab", "settingsTab"],
    ]
  );
});

test("keeps long hierarchy text readable in the active semantic tree", () => {
  const css = readFileSync(new URL("../src/components/inspectorPanel.css", import.meta.url), "utf8");
  const row = css.match(/\.rhine-inspector-tree-row \{[^}]+\}/)?.[0] ?? "";
  assert.match(row, /minmax\(0, 1fr\)/);
  assert.match(row, /overflow-wrap:\s*anywhere/);
  assert.match(row, /min\(calc\(var\(--rhine-inspector-depth\)/);
  assert.doesNotMatch(row, /text-overflow:\s*ellipsis/);
});

test("keeps screenshot viewport nonzero while controls scroll in a short pane", () => {
  const css = readFileSync(new URL("../src/components/streamPanel.css", import.meta.url), "utf8");
  const viewport = css.match(/\.rhine-stream-viewport \{[^}]+\}/)?.[0] ?? "";
  assert.match(viewport, /min-height:\s*240px/);
  assert.match(viewport, /position:\s*relative/);
  assert.match(css, /overflow:\s*auto/);
});

test("keeps the Web workbench scoped to read-only runtime slots", () => {
  assert.deepEqual(SUPPORTED_CARD_TYPES, ["stream", "inspector", "workbench"]);

  const originalLocalStorage = globalThis.localStorage;
  globalThis.localStorage = {
    getItem() {
      return JSON.stringify({
        kind: "split",
        id: "1",
        direction: "v",
        ratio: 0.5,
        first: { kind: "leaf", id: "2", card: "vlm" },
        second: { kind: "leaf", id: "3", card: "workbench" },
      });
    },
    setItem() {},
  };

  try {
    assert.deepEqual(loadInitialRoot(), {
      kind: "split",
      id: "1",
      direction: "v",
      ratio: 0.5,
      first: { kind: "leaf", id: "2", card: null },
      second: { kind: "leaf", id: "3", card: "workbench" },
    });
  } finally {
    globalThis.localStorage = originalLocalStorage;
  }
});

test("opens new layouts with stream and run atlas workbench visible", () => {
  const originalLocalStorage = globalThis.localStorage;
  globalThis.localStorage = undefined;

  try {
    const root = loadInitialRoot();
    assert.equal(root.kind, "split");
    assert.equal(root.direction, "v");
    assert.equal(root.ratio, 0.58);
    assert.equal(root.first.kind, "leaf");
    assert.equal(root.first.card, "stream");
    assert.equal(root.second.kind, "leaf");
    assert.equal(root.second.card, "workbench");
  } finally {
    globalThis.localStorage = originalLocalStorage;
  }
});

test("keeps browser device surfaces free of Web write dispatch", () => {
  const streamCard = readFileSync(new URL("../src/components/StreamPanel.tsx", import.meta.url), "utf8");
  const inspectorCard = readFileSync(new URL("../src/components/InspectorPanel.tsx", import.meta.url), "utf8");
  const bridge = readFileSync(new URL("./ios-bridge/index.mjs", import.meta.url), "utf8");

  assert.doesNotMatch(streamCard, /\/web\/host-input/);
  assert.doesNotMatch(streamCard, /sendGestureInput/);
  assert.doesNotMatch(inspectorCard, /\/web\/node-property/);
  assert.doesNotMatch(inspectorCard, /applyNodePatchDraft/);
  assert.doesNotMatch(bridge, /dispatchHostInput/);
  assert.doesNotMatch(bridge, /handleHostInputRoute/);
  assert.doesNotMatch(bridge, /handleNodePropertyRoute/);
  assert.match(bridge, /web_host_input_readonly/);
  assert.match(bridge, /web_node_property_readonly/);
});

test("keeps the Web-managed Triton server loopback-only", () => {
  const tritonServe = readFileSync(new URL("./ios-bridge/tritonServe.mjs", import.meta.url), "utf8");

  assert.match(tritonServe, /defaultManagedTritonServeHost = "127\.0\.0\.1"/);
  assert.doesNotMatch(tritonServe, /process\.env\.TRITONKIT_WEB_MANAGED_SERVE_HOST/);
});

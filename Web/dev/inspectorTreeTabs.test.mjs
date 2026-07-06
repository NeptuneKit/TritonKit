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

const { getInspectorTreeTabs } = await viteServer.ssrLoadModule("/src/inspectorTreeTabs.ts");

after(async () => {
  await viteServer.close();
});

test("android bridge shows one accessibility tree tab", () => {
  const tabs = getInspectorTreeTabs("android", [{ source: "android-bridge", capabilities: ["visible"] }], true);
  assert.deepEqual(tabs.map((tab) => tab.key), ["source"]);
  assert.equal(tabs[0].label, "辅助功能树");
});

test("android host layout shows one layout tree tab", () => {
  const tabs = getInspectorTreeTabs("android", [{ source: "host-layout", capabilities: ["tap"] }], true);
  assert.deepEqual(tabs.map((tab) => tab.key), ["source"]);
  assert.equal(tabs[0].label, "布局树");
  assert.match(tabs[0].description, /UIAutomator/);
});

test("harmony host layout shows one layout tree tab", () => {
  const tabs = getInspectorTreeTabs("harmony", [{ source: "host-layout", capabilities: ["tap"] }], true);
  assert.deepEqual(tabs.map((tab) => tab.key), ["source"]);
  assert.equal(tabs[0].label, "布局树");
  assert.match(tabs[0].description, /HDC dumpLayout/);
});

test("ios keeps separate view and ax tabs", () => {
  const tabs = getInspectorTreeTabs("ios", [{ source: "runtime-tree", capabilities: ["tap"] }], true);
  assert.deepEqual(tabs.map((tab) => tab.key), ["view", "ax"]);
  assert.equal(tabs[0].label, "视图树");
  assert.equal(tabs[1].label, "AX 树");
});


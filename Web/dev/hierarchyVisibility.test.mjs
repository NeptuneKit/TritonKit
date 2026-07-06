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

const { findDescendantAtPoint, getEffectivelyVisibleNodeIds } = await viteServer.ssrLoadModule("/src/hierarchyVisibility.ts");

after(async () => {
  await viteServer.close();
});

test("hides descendants of hidden hierarchy nodes", () => {
  const visibleIds = getEffectivelyVisibleNodeIds([
    { id: "root", type: "UIWindow", name: "root", frame: box(), depth: 0, visible: true, interactive: false, color: "#fff" },
    { id: "hidden-parent", parentId: "root", type: "UIView", name: "hidden", frame: box(), depth: 1, visible: false, interactive: false, color: "#fff" },
    { id: "visible-child", parentId: "hidden-parent", type: "UITableView", name: "child", frame: box(), depth: 2, visible: true, interactive: true, color: "#fff" },
  ]);

  assert.deepEqual([...visibleIds], ["root"]);
});

test("finds the smallest descendant under a repeated selected-node click", () => {
  const nodes = [
    { id: "root", type: "UIWindow", name: "root", frame: { x: 0, y: 0, width: 100, height: 100 }, depth: 0, visible: true, interactive: false, color: "#fff" },
    { id: "parent", parentId: "root", type: "UIView", name: "parent", frame: { x: 10, y: 10, width: 80, height: 80 }, depth: 1, visible: true, interactive: false, color: "#fff" },
    { id: "child", parentId: "parent", type: "UIButton", name: "child", frame: { x: 20, y: 20, width: 20, height: 20 }, depth: 2, visible: true, interactive: true, color: "#fff" },
  ];

  assert.equal(findDescendantAtPoint(nodes, "parent", 25, 25)?.id, "child");
});

function box() {
  return { x: 0, y: 0, width: 10, height: 10 };
}

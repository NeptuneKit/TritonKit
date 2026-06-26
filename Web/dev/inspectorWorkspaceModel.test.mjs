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

const { cycleHierarchyNodeAtPoint } = await viteServer.ssrLoadModule("/src/components/inspectorWorkspaceModel.ts");

after(async () => {
  await viteServer.close();
});

test("clicking a different branch selects the deepest node at that point", () => {
  const scene = {
    platform: "ios",
    rootId: "root",
    viewport: { width: 100, height: 100 },
    nodes: [
      { id: "root", type: "Root", frame: { x: 0, y: 0, width: 100, height: 100 }, depth: 0, visible: true, interactive: false, color: "#000" },
      { id: "left", parentId: "root", type: "View", frame: { x: 0, y: 0, width: 50, height: 100 }, depth: 1, visible: true, interactive: false, color: "#111" },
      { id: "left-leaf", parentId: "left", type: "Button", frame: { x: 10, y: 10, width: 10, height: 10 }, depth: 2, visible: true, interactive: true, color: "#222" },
      { id: "right", parentId: "root", type: "View", frame: { x: 50, y: 0, width: 50, height: 100 }, depth: 1, visible: true, interactive: false, color: "#333" },
      { id: "right-leaf", parentId: "right", type: "Button", frame: { x: 60, y: 10, width: 10, height: 10 }, depth: 2, visible: true, interactive: true, color: "#444" },
    ],
  };

  assert.equal(cycleHierarchyNodeAtPoint(scene, 65, 15, "left-leaf")?.id, "right-leaf");
});

test("clicking inside a selected ancestor selects the deepest hit descendant", () => {
  const scene = {
    platform: "ios",
    rootId: "root",
    viewport: { width: 100, height: 100 },
    nodes: [
      { id: "root", type: "Root", frame: { x: 0, y: 0, width: 100, height: 100 }, depth: 0, visible: true, interactive: false, color: "#000" },
      { id: "container", parentId: "root", type: "View", frame: { x: 0, y: 0, width: 100, height: 100 }, depth: 1, visible: true, interactive: false, color: "#111" },
      { id: "row", parentId: "container", type: "View", frame: { x: 10, y: 10, width: 80, height: 30 }, depth: 2, visible: true, interactive: false, color: "#222" },
      { id: "button", parentId: "row", type: "Button", frame: { x: 20, y: 15, width: 20, height: 10 }, depth: 3, visible: true, interactive: true, color: "#333" },
    ],
  };

  assert.equal(cycleHierarchyNodeAtPoint(scene, 25, 20, "container")?.id, "button");
});

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

const {
  changedHierarchyTreeNodeIds,
  snapshotHierarchyTree,
} = await viteServer.ssrLoadModule("/src/inspect/treeUpdateHighlight.ts");

after(async () => {
  await viteServer.close();
});

test("tree update highlight does not flash the first snapshot", () => {
  const first = snapshotHierarchyTree([node("root", { children: [node("label")] })]);

  assert.deepEqual([...changedHierarchyTreeNodeIds(new Map(), first)], []);
});

test("tree update highlight marks changed and newly inserted nodes", () => {
  const previous = snapshotHierarchyTree([node("root", { children: [node("label", { text: "Old" })] })]);
  const next = snapshotHierarchyTree([
    node("root", { children: [node("label", { text: "New" }), node("button", { text: "Tap" })] }),
  ]);

  assert.deepEqual([...changedHierarchyTreeNodeIds(previous, next)].sort(), ["button", "label", "root"]);
});

test("tree update highlight ignores unchanged snapshots", () => {
  const previous = snapshotHierarchyTree([node("root", { children: [node("label", { text: "Same" })] })]);
  const next = snapshotHierarchyTree([node("root", { children: [node("label", { text: "Same" })] })]);

  assert.deepEqual([...changedHierarchyTreeNodeIds(previous, next)], []);
});

function node(id, options = {}) {
  return {
    id,
    parentId: options.parentId,
    type: options.type ?? "UIView",
    className: options.className ?? "UIView",
    name: options.name ?? id,
    frame: options.frame ?? { x: 0, y: 0, width: 100, height: 20 },
    depth: options.depth ?? 0,
    visible: true,
    interactive: options.interactive ?? false,
    color: "#fff",
    style: options.text ? { text: options.text } : undefined,
    view: options.label ? { accessibilityLabel: options.label } : undefined,
    children: options.children ?? [],
  };
}

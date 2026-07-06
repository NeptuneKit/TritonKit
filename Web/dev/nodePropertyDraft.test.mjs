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
    buildNodePropertyDraft,
    buildNodePropertyPatchPayload,
    diffNodePropertyDraft,
    hasNodePropertyChanges,
  } = await viteServer.ssrLoadModule("/src/inspect/nodePropertyDraft.ts");

after(async () => {
  await viteServer.close();
});

test("node property draft mirrors editable geometry view layer and AX fields", () => {
  const draft = buildNodePropertyDraft(nodeFixture());

  assert.deepEqual(draft.frame, { x: 10, y: 20, width: 120, height: 44 });
  assert.deepEqual(draft.view, {
    isHidden: false,
    alpha: 0.75,
    isUserInteractionEnabled: true,
    accessibilityIdentifier: "primary",
    accessibilityLabel: "Continue",
  });
  assert.deepEqual(draft.layer, {
    isHidden: false,
    masksToBounds: true,
    opacity: 0.8,
    cornerRadius: 12,
    zPosition: 2,
  });
  assert.equal(draft.style.text, "继续");
});

test("node property patch payload exports only changed draft fields", () => {
  const node = nodeFixture();
  const base = buildNodePropertyDraft(node);
  const draft = {
    ...base,
    frame: { ...base.frame, x: 18 },
    view: { ...base.view, accessibilityLabel: "Start" },
    layer: { ...base.layer, opacity: 0.5 },
  };

  assert.deepEqual(diffNodePropertyDraft(base, draft), {
    frame: { x: 18 },
    view: { accessibilityLabel: "Start" },
    layer: { opacity: 0.5 },
  });

  const payload = buildNodePropertyPatchPayload({
    targetKey: "ios:SIM-1",
    node,
    base,
    draft,
  });

  assert.equal(payload.nodeId, "ios:runtime:1717");
  assert.equal(payload.oid, 1717);
  assert.deepEqual(payload.changes, {
    frame: { x: 18 },
    view: { accessibilityLabel: "Start" },
    layer: { opacity: 0.5 },
  });
  assert.equal(hasNodePropertyChanges(payload.changes), true);
  assert.equal(hasNodePropertyChanges({}), false);
});

function nodeFixture() {
  return {
    id: "ios:runtime:1717",
    parentId: "root",
    type: "UIButton",
    className: "UIButton",
    name: "Continue Button",
    frame: { x: 10, y: 20, width: 120, height: 44 },
    depth: 2,
    visible: true,
    interactive: true,
    color: "#1677ff",
    source: "runtime-tree",
    view: {
      isHidden: false,
      alpha: 0.75,
      isUserInteractionEnabled: true,
      accessibilityIdentifier: "primary",
      accessibilityLabel: "Continue",
    },
    layer: {
      bounds: { x: 0, y: 0, width: 120, height: 44 },
      position: { x: 70, y: 42 },
      anchorPoint: { x: 0.5, y: 0.5 },
      masksToBounds: true,
      cornerRadius: 12,
      opacity: 0.8,
      isHidden: false,
      zPosition: 2,
    },
    style: {
      text: "继续",
      backgroundColor: "#1677ff",
      foregroundColor: "#ffffff",
      alpha: 0.7,
      cornerRadius: 10,
    },
  };
}

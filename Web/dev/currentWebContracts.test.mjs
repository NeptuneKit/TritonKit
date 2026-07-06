import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
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

const { hierarchyScenes } = await viteServer.ssrLoadModule("/src/data/mockData.ts");

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

test("keeps view-tree labels readable for deep and long runtime node names", () => {
  const css = readFileSync(new URL("../src/styles.css", import.meta.url), "utf8");
  const viewTreeRowRule = css.match(/\.view-tree-row \{[^}]+\}/)?.[0] ?? "";
  const treeNodeRule = css.match(/\.view-tree \.ant-tree-treenode \{[^}]+\}/)?.[0] ?? "";
  const treeTitleRule = css.match(/\.view-tree \.ant-tree-title \{[^}]+\}/)?.[0] ?? "";
  const treeStatusStaleRule = css.match(/\.view-tree-status\.is-stale \{[^}]+\}/)?.[0] ?? "";
  const typeRule = css.match(/\.view-tree-row strong \{[^}]+\}/)?.[0] ?? "";
  const labelRule = css.match(/\.view-tree-row span \{[^}]+\}/)?.[0] ?? "";
  const copyRule = css.match(/\.tree-node-copy \{[^}]+\}/)?.[0] ?? "";
  const deviceStageRule = css.match(/\.device-stage \{[^}]+\}/)?.[0] ?? "";
  const controllerBadgeRule = css.match(/\.controller-shell-badge \{[^}]+\}/)?.[0] ?? "";
  const controllerBadgeNameRule = css.match(/\.controller-shell-badge strong \{[^}]+\}/)?.[0] ?? "";
  const controllerBadgeStatusRule = css.match(/\.controller-shell-badge em \{[^}]+\}/)?.[0] ?? "";
  const controllerBadgeStaleRule = css.match(/\.controller-shell-badge\.is-stale \{[^}]+\}/)?.[0] ?? "";

  assert.match(viewTreeRowRule, /grid-template-columns:\s*18px minmax\(0, 1fr\)/);
  assert.match(viewTreeRowRule, /clamp\(0px, var\(--tree-depth\) \* 14px, 112px\)/);
  assert.match(treeNodeRule, /align-items:\s*flex-start/);
  assert.match(treeTitleRule, /white-space:\s*normal/);
  assert.match(treeStatusStaleRule, /background:\s*rgba\(216, 168, 111, 0\.1\)/);
  assert.match(copyRule, /white-space:\s*normal/);
  assert.match(typeRule, /overflow-wrap:\s*anywhere/);
  assert.match(typeRule, /white-space:\s*normal/);
  assert.match(labelRule, /overflow-wrap:\s*anywhere/);
  assert.match(labelRule, /white-space:\s*normal/);
  assert.doesNotMatch(typeRule, /text-overflow:\s*ellipsis/);
  assert.doesNotMatch(labelRule, /text-overflow:\s*ellipsis/);
  assert.match(deviceStageRule, /position:\s*relative/);
  assert.match(deviceStageRule, /grid-template-rows:\s*auto minmax\(0, 1fr\)/);
  assert.match(deviceStageRule, /row-gap:\s*8px/);
  assert.match(controllerBadgeRule, /pointer-events:\s*auto/);
  assert.match(controllerBadgeRule, /user-select:\s*text/);
  assert.match(controllerBadgeStatusRule, /font-style:\s*normal/);
  assert.match(controllerBadgeStaleRule, /background:\s*rgba\(30, 22, 12, 0\.82\)/);
  assert.match(controllerBadgeNameRule, /overflow-wrap:\s*anywhere/);
  assert.match(controllerBadgeNameRule, /white-space:\s*normal/);
  assert.doesNotMatch(controllerBadgeNameRule, /text-overflow:\s*ellipsis/);
});

test("keeps real portrait screenshots from collapsing inside the device stage grid", () => {
  const css = readFileSync(new URL("../src/styles.css", import.meta.url), "utf8");
  const portraitRealFrameRule =
    css.match(/\.device-frame\.has-real-frame\.orientation-portrait,\s*\.device-frame\.has-real-frame\.orientation-unknown \{[^}]+\}/)?.[0] ?? "";
  const portraitRealFrameRules = [
    ...css.matchAll(/\.device-frame\.has-real-frame\.orientation-portrait,\s*\.device-frame\.has-real-frame\.orientation-unknown \{[^}]+\}/g),
  ].map((match) => match[0]);
  const portraitRealFrameMobileRule = portraitRealFrameRules.at(-1) ?? "";

  assert.match(portraitRealFrameRule, /height:\s*min\(720px, calc\(100dvh - 160px\)\)/);
  assert.doesNotMatch(portraitRealFrameRule, /height:\s*min\([^;]*100%/);
  assert.match(portraitRealFrameMobileRule, /height:\s*min\(620px, calc\(100dvh - 150px\)\)/);
  assert.doesNotMatch(portraitRealFrameMobileRule, /height:\s*min\([^;]*100%/);
});

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

const { loadStreamTargetFps, saveStreamTargetFps } = await viteServer.ssrLoadModule("/src/streamPreferences.ts");

after(async () => {
  delete globalThis.localStorage;
  await viteServer.close();
});

test("stream target fps persists supported values", () => {
  const store = new Map();
  globalThis.localStorage = {
    getItem: (key) => store.get(key) ?? null,
    setItem: (key, value) => store.set(key, value),
  };

  assert.equal(loadStreamTargetFps(), 15);
  saveStreamTargetFps(60);
  assert.equal(loadStreamTargetFps(), 60);
});

test("stream target fps ignores unsupported stored values", () => {
  globalThis.localStorage = {
    getItem: () => "999",
    setItem: () => {},
  };

  assert.equal(loadStreamTargetFps(), 15);
});

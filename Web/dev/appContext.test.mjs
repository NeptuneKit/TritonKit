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

const { webHostHierarchyQuery } = await viteServer.ssrLoadModule("/src/AppContext.tsx");

after(async () => {
  await viteServer.close();
});

test("iOS simulator hierarchy defaults to host source", () => {
  assert.equal(
    webHostHierarchyQuery("SIM-1", "ios", { scope: "simulator", kind: "simulator" }).toString(),
    "platform=ios&target=SIM-1&scope=simulator&kind=simulator&source=host",
  );
});

test("iOS real-device hierarchy defaults to runtime source", () => {
  assert.equal(
    webHostHierarchyQuery("ios-real:abc", "ios", { scope: "real", kind: "real-device" }).toString(),
    "platform=ios&target=ios-real%3Aabc&scope=real&kind=real-device&source=runtime",
  );
});

test("explicit hierarchy source is preserved", () => {
  assert.equal(
    webHostHierarchyQuery("SIM-1", "ios", { source: "runtime" }).toString(),
    "platform=ios&target=SIM-1&source=runtime",
  );
});

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

const { mockWorkspaceWorkbench } = await viteServer.ssrLoadModule("/src/data/mockData.ts");
const {
  getWorkbenchOverviewItems,
  getWorkbenchPathRows,
  getWorkbenchSuggestedCommands,
} = await viteServer.ssrLoadModule("/src/workbenchModel.ts");

after(async () => {
  await viteServer.close();
});

test("summarizes run, provider, and atlas facts from the read-only workspace DTO", () => {
  const items = getWorkbenchOverviewItems(mockWorkspaceWorkbench);

  assert.deepEqual(
    items.map((item) => [item.key, item.value]),
    [
      ["run", "run-local-20260707-001 · running"],
      ["app", "Overloaded · com.linhay.overloaded"],
      ["target", "ios/simulator · iPhone 16 Pro"],
      ["providers", "LLM on · VLM on · ready"],
      ["atlas", "7 screens · 9 states · 6 transitions · 3 paths"],
      ["latestPause", "inspect_vlm_grounding_failure"],
    ],
  );
});

test("keeps VLM replay requirements explicit on Atlas path rows", () => {
  const paths = getWorkbenchPathRows(mockWorkspaceWorkbench);
  const loginPath = paths.find((path) => path.pathId === "path-login-dashboard");

  assert.equal(loginPath?.requiresVLM, true);
  assert.equal(loginPath?.health, "healthy");
  assert.equal(loginPath?.primaryCommand?.includes("triton test run"), true);
  assert.equal(loginPath?.primaryCommand?.includes("--allow-vlm"), true);
  assert.deepEqual(loginPath?.sourceRuns, ["run-local-20260707-001", "run-local-20260707-002"]);
});

test("keeps workbench commands read-only and machine-readable", () => {
  const commands = getWorkbenchSuggestedCommands(mockWorkspaceWorkbench);

  assert.deepEqual(commands.map((command) => command.key), [
    "workspace-inspect",
    "map-health",
    "path-export-flow",
    "path-run",
  ]);
  assert.equal(commands.every((command) => command.command.includes("--json")), true);
  assert.equal(commands.some((command) => command.command.includes("--allow-vlm")), true);
});

import assert from "node:assert/strict";
import { after, test } from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createServer } from "vite";

const server = await createServer({
  configFile: false,
  root: new URL("..", import.meta.url).pathname,
  appType: "custom",
  esbuild: { jsx: "automatic" },
  server: { hmr: false, middlewareMode: true, ws: false },
  optimizeDeps: { noDiscovery: true },
  ssr: { noExternal: ["@linhey/rhine-design"] },
});
after(() => server.close());
const { RunWorkbenchView } = await server.ssrLoadModule("/src/components/RunWorkbenchView.tsx");

function fixture() {
  return {
    run: {
      runId: "run-synthetic-001", status: "failed", goal: "Verify a synthetic route",
      app: { name: "Synthetic App", bundleId: "example.synthetic" },
      target: { platform: "ios", scope: "simulator", name: "Synthetic target", targetSelector: "synthetic" },
      llmEnabled: false, vlmEnabled: true, providersReady: false,
      latestPause: { reason: "evidence unavailable", evidenceRef: "evidence-synthetic" },
      latestRecoveryProposal: { title: "Review evidence", summary: "Inspect the missing observation", evidenceRefs: [] },
      appMap: { mapRef: "synthetic-map", screenCount: 2, stateCount: 3, transitionCount: 1, pathCount: 1, coverageStatus: "unknown", pathIds: ["synthetic-path"] },
      suggestedCommands: [{ key: "inspect", label: "Inspect run", command: "triton workspace inspect --json" }],
    },
    paths: [{ pathId: "synthetic-path", name: "Synthetic route", status: "blocked", confirmed: false, replayable: false, requiresVLM: true, health: "unhealthy", sourceRuns: ["run-synthetic-001"], suggestedCommands: [] }],
    evidenceRefs: [],
  };
}
const render = props => renderToStaticMarkup(createElement(RunWorkbenchView, props));

test("keeps run, provider, coverage, pause, and path failures explicit without executing commands", () => {
  const html = render({ workbench: fixture() });
  for (const text of ["failed", "LLM off", "VLM on", "not ready", "unknown", "evidence unavailable", "Review evidence", "Inspect the missing observation", "unhealthy", "blocked", "export first", "triton workspace inspect --json"]) {
    assert.ok(html.includes(text), `Missing ${text}`);
  }
  assert.match(html, /role="tablist"/);
  assert.match(html, /当前运行/);
  assert.match(html, /Atlas 路径/);
  assert.match(html, /建议命令/);
  assert.doesNotMatch(html, />执行<|>运行<|onClick=|\/web\//);
});

test("distinguishes no data, loading, and read failure from successful run content", () => {
  assert.match(render({}), /暂无运行记录/);
  const loading = render({ state: "loading" });
  assert.match(loading, /aria-busy="true"/);
  assert.match(loading, /正在读取工作台/);
  assert.doesNotMatch(loading, /暂无运行记录/);
  const failed = render({ state: "error", errorMessage: "Synthetic request unavailable" });
  assert.match(failed, /role="alert"/);
  assert.match(failed, /Synthetic request unavailable/);
  assert.match(failed, /重新读取/);
  assert.doesNotMatch(failed, /暂无运行记录|已成功/);
});

test("retains previous DTO during refresh or failure and labels it as previous data", () => {
  for (const state of ["loading", "error"]) {
    const html = render({ workbench: fixture(), state });
    assert.match(html, /run-synthetic-001/);
    assert.match(html, /上次读取/);
  }
});

test("uses an explicit empty state for absent paths and commands", () => {
  const workbench = fixture();
  workbench.paths = [];
  workbench.run.suggestedCommands = [];
  const html = render({ workbench });
  assert.match(html, /暂无路径/);
  assert.match(html, /暂无建议命令/);
  assert.doesNotMatch(html, /复制命令/);
});

test("does not infer healthy coverage or suppress long identity text", () => {
  const workbench = fixture();
  workbench.run.app.name = "SyntheticVeryLongApplicationName".repeat(20);
  const html = render({ workbench });
  assert.ok(html.includes(workbench.run.app.name));
  assert.match(html, /unknown/);
  assert.match(html, /synthetic-map/);
});


test("keeps the task, target, unknown coverage and actionable failures before the secondary tabs", () => {
  const workbench = fixture();
  const html = render({ workbench });
  const summary = html.slice(0, html.indexOf('role="tablist"'));
  for (const text of [workbench.run.goal, workbench.run.runId, "failed", workbench.run.app.name,
    workbench.run.target.name, "ios/simulator", "unknown", "evidence unavailable", "not ready"]) {
    assert.ok(summary.includes(text), `Missing primary fact ${text}`);
  }
  assert.ok(!summary.includes(workbench.run.appMap.mapRef), "Map reference is secondary metadata");
  assert.equal((summary.match(/run-synthetic-001/g) ?? []).length, 1, "Run identity is presented once");
  assert.match(html, /<details[^>]*>[\s\S]*<summary[^>]*>运行详情/);
});

test("puts injected pane actions in the page header and keeps metadata in the content", () => {
  const html = render({ workbench: fixture(), headerActions: createElement("button", { type: "button", "aria-label": "窗格操作" }, "更多") });
  const header = html.match(/<header[^>]*>([\s\S]*?)<\/header>/)?.[1] ?? "";
  assert.match(header, /窗格操作/);
  assert.match(header, /运行与路径/);
  assert.doesNotMatch(header, /run-synthetic-001|failed|synthetic-map/);
  assert.match(html, /^<section[^>]*class="rhine-workbench"/);
  assert.doesNotMatch(html, /rhine-surface/);
});

test("all path outcomes and suggestions remain reachable including blocked and later paths", () => {
  const workbench = fixture();
  workbench.paths.push({ ...workbench.paths[0], pathId: "second-path", name: "Second route", status: "candidate", health: "warning",
    replayable: true, confirmed: true, requiresVLM: false, sourceRuns: ["source-second"],
    suggestedCommands: [{ key: "second-run", label: "Replay second", command: "triton test run synthetic-second.yaml --json" }] });
  workbench.paths[0].suggestedCommands = [{ key: "blocked-inspect", label: "Inspect blocked", command: "triton test inspect synthetic-blocked.yaml --json" }];
  workbench.paths.push({ ...workbench.paths[1], pathId: "third-path", name: "Third route", sourceRuns: ["source-third"],
    suggestedCommands: [{ key: "third-run", label: "Replay third", command: "triton test run synthetic-third.yaml --json" }] });
  const html = render({ workbench });
  for (const text of ["blocked", "candidate", "unhealthy", "warning", "source-second", "source-third", "未确认", "已确认", "不需要 VLM", "export first"]) assert.ok(html.includes(text), text);
  for (const path of workbench.paths) {
    assert.ok(html.includes(path.pathId));
    assert.ok(html.includes(path.name));
    for (const suggestion of path.suggestedCommands) assert.ok(html.includes(suggestion.command), suggestion.command);
  }
  assert.match(html, /aria-label="Atlas 路径列表"/);
  assert.doesNotMatch(html, /<table/);
});

test("retains secondary metadata and evidence under disclosure without changing their values", () => {
  const workbench = fixture();
  workbench.evidenceRefs = ["synthetic-global-evidence"];
  workbench.run.latestBootstrapProposal = { title: "Synthetic bootstrap", summary: "Review starting state", evidenceRefs: ["synthetic-bootstrap-evidence"] };
  workbench.run.latestRecoveryProposal.evidenceRefs = ["synthetic-recovery-evidence"];
  const html = render({ workbench });
  for (const text of ["example.synthetic", "synthetic-map", "evidence-synthetic", "synthetic-global-evidence", "synthetic-bootstrap-evidence", "synthetic-recovery-evidence", "Synthetic bootstrap", "Review starting state"]) assert.ok(html.includes(text), text);
  assert.match(html, /LLM off/); assert.match(html, /VLM on/);
  assert.match(html, /2 个界面/); assert.match(html, /3 个状态/); assert.match(html, /1 次转换/); assert.match(html, /1 条路径/);
});

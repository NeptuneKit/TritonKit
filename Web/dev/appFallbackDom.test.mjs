import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { after, test } from "node:test";
import { Window } from "happy-dom";
import { createServer } from "vite";

const viteServer = await createServer({
  appType: "custom",
  server: {
    hmr: false,
    middlewareMode: true,
    ws: false,
  },
});

const { App } = await viteServer.ssrLoadModule("/src/App.tsx");
const {
  computeParityClaim,
  getMaterialExplanation,
  resolveDefaultMaterialSource,
  resolveEvidenceSources,
} = await viteServer.ssrLoadModule("/src/data/hierarchyMaterialPolicy.ts");
const { hierarchyScenes } = await viteServer.ssrLoadModule("/src/data/mockData.ts");

after(async () => {
  await viteServer.close();
});

test("keeps subtree snapshots out of default hierarchy materials", () => {
  const node = {
    id: "button",
    type: "UIButton",
    name: "button",
    frame: { x: 0, y: 0, width: 100, height: 44 },
    depth: 1,
    visible: true,
    interactive: true,
    color: "#2563eb",
    visualSources: [
      {
        kind: "subtreeSnapshot",
        dataUrl: "data:image/png;base64,AAA=",
        rect: { x: 0, y: 0, width: 100, height: 44 },
        capturedBy: "UIView.render",
      },
    ],
  };

  assert.equal(resolveDefaultMaterialSource(node), null);
  assert.deepEqual(resolveEvidenceSources(node).map((source) => source.kind), ["subtreeSnapshot"]);
});

test("allows only layerOwnContents as default hierarchy material", () => {
  const node = {
    id: "imageView",
    type: "UIImageView",
    name: "imageView",
    frame: { x: 0, y: 0, width: 80, height: 80 },
    depth: 1,
    visible: true,
    interactive: false,
    color: "#94a3b8",
    visualSources: [
      {
        kind: "subtreeSnapshot",
        dataUrl: "data:image/png;base64,BBB=",
        rect: { x: 0, y: 0, width: 80, height: 80 },
        capturedBy: "CALayer.render",
      },
      {
        kind: "layerOwnContents",
        dataUrl: "data:image/png;base64,CCC=",
        rect: { x: 0, y: 0, width: 80, height: 80 },
        contentsScale: 3,
        contentsGravity: "resizeAspectFill",
      },
    ],
  };

  assert.equal(resolveDefaultMaterialSource(node)?.kind, "layerOwnContents");
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
  const typeRule = css.match(/\.view-tree-row strong \{[^}]+\}/)?.[0] ?? "";
  const labelRule = css.match(/\.view-tree-row span \{[^}]+\}/)?.[0] ?? "";
  const deviceStageRule = css.match(/\.device-stage \{[^}]+\}/)?.[0] ?? "";
  const controllerBadgeRule = css.match(/\.controller-shell-badge \{[^}]+\}/)?.[0] ?? "";
  const controllerBadgeNameRule = css.match(/\.controller-shell-badge strong \{[^}]+\}/)?.[0] ?? "";

  assert.match(viewTreeRowRule, /grid-template-columns:\s*18px minmax\(0, 1fr\)/);
  assert.match(viewTreeRowRule, /clamp\(0px, var\(--tree-depth\) \* 14px, 112px\)/);
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
  assert.match(controllerBadgeNameRule, /overflow-wrap:\s*anywhere/);
  assert.match(controllerBadgeNameRule, /white-space:\s*normal/);
  assert.doesNotMatch(controllerBadgeNameRule, /text-overflow:\s*ellipsis/);
});

test("does not claim Lookin parity when only subtree snapshot evidence exists", () => {
  const scene = {
    platform: "ios",
    rootId: "root",
    viewport: { width: 390, height: 844 },
    nodes: [
      {
        id: "root",
        type: "UIWindow",
        name: "root",
        frame: { x: 0, y: 0, width: 390, height: 844 },
        depth: 0,
        visible: true,
        interactive: false,
        color: "#94a3b8",
      },
      {
        id: "titleLabel",
        type: "UILabel",
        name: "titleLabel",
        frame: { x: 24, y: 88, width: 160, height: 32 },
        depth: 1,
        visible: true,
        interactive: false,
        color: "#94a3b8",
        visualSources: [
          {
            kind: "subtreeSnapshot",
            dataUrl: "data:image/png;base64,DDD=",
            rect: { x: 24, y: 88, width: 160, height: 32 },
            capturedBy: "UIView.render",
          },
        ],
      },
    ],
  };

  assert.deepEqual(computeParityClaim(scene), {
    level: "snapshotEvidenceViewer",
    canClaimLookinParity: false,
    reasons: [
      "subtreeSnapshot is evidence only and cannot reconstruct layer-own contents",
      "not every visible non-root node has layerOwnContents source",
    ],
  });
});

test("explains hierarchy material source and evidence sources", () => {
  const node = {
    id: "titleLabel",
    type: "UILabel",
    name: "titleLabel",
    frame: { x: 24, y: 88, width: 160, height: 32 },
    depth: 1,
    visible: true,
    interactive: false,
    color: "#94a3b8",
    visualSources: [
      {
        kind: "subtreeSnapshot",
        dataUrl: "data:image/png;base64,EEE=",
        rect: { x: 24, y: 88, width: 160, height: 32 },
        capturedBy: "UIView.render",
      },
      {
        kind: "mainScreenshotCrop",
        dataUrl: "data:image/png;base64,FFF=",
        rect: { x: 24, y: 88, width: 160, height: 32 },
      },
    ],
  };

  assert.deepEqual(getMaterialExplanation(node), {
    nodeId: "titleLabel",
    defaultMaterial: null,
    reason: "No layerOwnContents source available",
    evidenceSources: ["subtreeSnapshot", "mainScreenshotCrop"],
  });
});

test("does not mount mock targets when readonly host bridge returns no targets", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);

      fetchCalls.push({ pathname: url.pathname, method });
      assert.equal(url.pathname, "/web/host-targets");

      return new Response(
        JSON.stringify({
          ok: true,
          capturedAt: "2026-06-13T10:00:00.000Z",
          source: {
            commands: ["triton sim list --json"],
            runtimeScope: "host",
            readonly: true,
          },
          targets: [],
          commandOutputs: [],
        }),
        {
      if (url.pathname === "/web/target-registry") {
        return new Response(JSON.stringify({ ok: false }), {
          status: 404,
          headers: {
            "content-type": "application/json",
          },
        });
      }

          status: 200,
          headers: {
            "content-type": "application/json",
          },
        }
      );
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => {
      const subtitle = document.querySelector(".toolbar-title span")?.textContent?.trim();
      const noticeTitle = document.querySelector(".bridge-notice strong")?.textContent?.trim();
      const noticeDetail = document.querySelector(".bridge-notice span")?.textContent?.trim();

      return (
        subtitle === "No host targets" &&
        noticeTitle === "当前没有可用 host target" &&
        typeof noticeDetail === "string" &&
        noticeDetail.includes("targets 为空") &&
        noticeDetail.includes("triton sim list --json")
      );
    });

    assert.deepEqual(fetchCalls, [
      { pathname: "/web/target-registry", method: "GET" },
      { pathname: "/web/host-targets", method: "GET" },
    ]);
    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "No host targets");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "当前没有可用 host target"
    );
    assert.match(document.querySelector(".bridge-notice span")?.textContent ?? "", /targets 为空/);
    assert.match(document.querySelector(".bridge-notice span")?.textContent ?? "", /triton sim list --json/);
    assert.deepEqual(deviceRowNames(), []);
    assert.doesNotMatch(bodyText(), /QA mock fallback|DXY iPhone 15|Pixel API 35|DevEco Local/);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("does not mount mock targets when host bridge request fails", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);

      fetchCalls.push({
        pathname: url.pathname,
        method,
        forcedMode: url.searchParams.get("__tritonkit_mock_host_targets"),
      });
      return new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: {
          "content-type": "application/json",
        },
      });
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => {
      const subtitle = document.querySelector(".toolbar-title span")?.textContent?.trim();
      const noticeTitle = document.querySelector(".bridge-notice strong")?.textContent?.trim();
      const noticeDetail = document.querySelector(".bridge-notice span")?.textContent?.trim();

      return (
        subtitle === "Host bridge unavailable" &&
        noticeTitle === "Host bridge 请求失败" &&
        noticeDetail === "Host targets request failed: 502"
      );
    });

    assert.deepEqual(fetchCalls, []);
    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "Host bridge unavailable");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "Host bridge 请求失败"
    );
    assert.equal(document.querySelector(".bridge-notice span")?.textContent?.trim(), "Host targets request failed: 502");
    assert.deepEqual(deviceRowNames(), []);
    assert.doesNotMatch(bodyText(), /QA mock fallback|DXY iPhone 15|Pixel API 35|DevEco Local/);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("does not render static mock hierarchy when host hierarchy is unavailable", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?panel=view-tree&node=music-tab",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);
      fetchCalls.push({ pathname: url.pathname, method });

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T12:00:00.000Z",
            source: {
              commands: ["triton sim list --json"],
              runtimeScope: "host",
              readonly: true,
            },
            targets: [
              {
                id: "host:ios:SIM1",
                target: "SIM1",
                name: "iPhone 15",
                platform: "ios",
                appName: "Overloaded",
                bundleIdentifier: "overloaded.cn.debug",
                runtime: "iOS 26.5",
                state: "Booted",
                statusLabel: "Ready",
                ready: true,
                scope: "simulator",
                kind: "simulator",
                transport: "simctl",
                source: "simctl",
                readonly: true,
                blockedReasons: [],
                sensitive: false,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "SIM1",
            source: {
              command: "triton screenshot --target SIM1 --json",
              runtimeScope: "host",
              readonly: true,
            },
            artifact: "/tmp/sim.png",
            pixelWidth: 390,
            pixelHeight: 844,
            dataUrl: "data:image/png;base64,AAA=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-logs") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T12:00:00.000Z",
            source: {
              command: "triton logs --target SIM1 --json",
              runtimeScope: "host",
              readonly: true,
            },
            entries: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-hierarchy") {
        return new Response(
          JSON.stringify({
            ok: false,
            error: {
              code: "hierarchy_unavailable",
              message: "No active runtime hierarchy",
            },
          }),
          { status: 503, headers: { "content-type": "application/json" } }
        );
      }

      throw new Error("Unexpected fetch route: " + url.pathname);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await act(async () => {
      await waitFor(() => fetchCalls.some((call) => call.pathname === "/web/host-hierarchy"), 3000);
    });
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 0));
    });
    await waitFor(() => bodyText().includes("未拿到实时视图层级"), 3000);

    assert.ok(fetchCalls.some((call) => call.pathname === "/web/host-hierarchy"));
    assert.equal(document.querySelectorAll(".view-tree-row").length, 0);
    assert.equal(document.querySelector(".view-node-highlight"), null);
    assert.doesNotMatch(bodyText(), /serverTab|photosTab|musicTab|settingsTab|QA mock fallback/);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("keeps runtime hierarchy nested when root parentId is null", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?target=host%3Aios%3ASIM1&panel=view-tree",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const runtimeScene = {
    platform: "ios",
    rootId: "root",
    viewport: { width: 390, height: 844 },
    nodes: [
      {
        id: "root",
        parentId: null,
        type: "UIWindow",
        name: "keyWindow",
        frame: { x: 0, y: 0, width: 390, height: 844 },
        depth: 0,
        visible: true,
        interactive: false,
        color: "#ffffff",
      },
      {
        id: "child",
        parentId: "root",
        type: "UIViewControllerWrapperView",
        name: "wrapper",
        frame: { x: 0, y: 0, width: 390, height: 760 },
        depth: 1,
        visible: true,
        interactive: false,
        color: "#7dd3fc",
      },
      {
        id: "button",
        parentId: "child",
        type: "UIButton",
        name: "primaryAction",
        frame: { x: 24, y: 120, width: 180, height: 44 },
        depth: 3,
        visible: true,
        interactive: true,
        color: "#fb7185",
      },
    ],
  };

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input) => {
      const url = new URL(resolveRequestURL(input), window.location.href);

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-20T02:00:00.000Z",
            source: {
              commands: ["triton sim list --json", "triton list --json"],
              runtimeScope: "host",
              readonly: true,
            },
            targets: [
              {
                id: "host:ios:SIM1",
                target: "SIM1",
                name: "iPhone 15",
                platform: "ios",
                appName: null,
                bundleIdentifier: "overloaded.cn.debug",
                runtime: "iOS 26.5",
                state: "Booted",
                statusLabel: "Ready",
                ready: true,
                scope: "simulator",
                kind: "simulator",
                transport: "simctl",
                source: "simctl",
                readonly: true,
                blockedReasons: [],
                sensitive: false,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-hierarchy") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-20T02:00:00.000Z",
            source: {
              command: "triton hierarchy --platform ios --target SIM1 --json",
              runtimeScope: "runtime-tree",
              readonly: true,
            },
            scene: runtimeScene,
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "SIM1",
            source: {
              command: "triton screenshot --target SIM1 --json",
              runtimeScope: "host",
              readonly: true,
            },
            artifact: "/tmp/sim.png",
            pixelWidth: 390,
            pixelHeight: 844,
            dataUrl: "data:image/png;base64,AAA=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      return new Response(JSON.stringify({ ok: true, entries: [] }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => selectedViewTreeNodeId() === "button");
    const rows = Array.from(document.querySelectorAll(".view-tree-row"));
    assert.deepEqual(rows.map((row) => row.getAttribute("data-node-id")), ["root", "child", "button"]);
    assert.deepEqual(rows.map((row) => row.style.getPropertyValue("--tree-depth")), ["0", "1", "2"]);
    assert.deepEqual(rows.map((row) => row.getAttribute("aria-level")), ["1", "2", "3"]);
    assert.equal(currentAppName(), "iPhone 15");
    assert.doesNotMatch(currentAppName(), /前台 App 未暴露/);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("switches devices from the narrow toolbar title target menu", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async () =>
      new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: {
          "content-type": "application/json",
        },
      }),
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => hasRequestFailedFallbackNotice());
    assert.equal(document.querySelector(".toolbar-title strong")?.textContent?.trim(), "DXY iPhone 15");

    const titleSwitch = document.querySelector('button[aria-label="切换设备"]');
    assert.ok(titleSwitch, "Expected toolbar title to expose a target switch button");

    await act(async () => {
      titleSwitch.click();
    });

    const menu = document.querySelector('[role="listbox"][aria-label="切换设备"]');
    assert.ok(menu, "Expected toolbar target menu to open");

    const androidOption = Array.from(document.querySelectorAll(".toolbar-target-option")).find((option) =>
      option.textContent?.includes("Pixel API 35")
    );
    assert.ok(androidOption, "Expected Android target in toolbar menu");

    await act(async () => {
      androidOption.click();
    });

    await waitFor(() => document.querySelector(".toolbar-title strong")?.textContent?.trim() === "Pixel API 35");
    assert.equal(currentAppName(), "Overloaded");
    assert.equal(document.querySelector('[role="listbox"][aria-label="切换设备"]'), null);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("renders bounded iOS host logs in the log strip when readonly host logs are available", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);
      fetchCalls.push({ pathname: url.pathname, method });

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-15T10:41:31.000Z",
            source: {
              commands: [
                "triton sim list --json",
                "triton device list --platform android --json",
                "triton device list --platform harmony --json",
              ],
              runtimeScope: "host-emulator",
              readonly: true,
            },
            targets: [
              {
                id: "sim:AAAA-BBBB",
                target: "AAAA-BBBB",
                name: "iPhone 17",
                platform: "ios",
                appName: "DXY",
                bundleIdentifier: "cn.dxy.app",
                runtime: "iOS 26.5",
                state: "Booted",
                statusLabel: "Booted",
                ready: true,
                scope: "emulator",
                kind: "emulator",
                source: "simctl",
                readonly: true,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-logs") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-15T10:41:31.000Z",
            source: {
              command: "triton sim logs --simulator AAAA-BBBB --output <tmp.ndjson> --duration 2 --style ndjson --json",
              runtimeScope: "host-simulator",
              readonly: true,
            },
            entries: [
              { id: "host-log-0", time: "10:41:29", level: "info", message: "App launched" },
              { id: "host-log-1", time: "10:41:31", level: "error", message: "Network timeout" },
            ],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "AAAA-BBBB",
            source: {
              command: "triton sim screenshot --json",
              runtimeScope: "host-simulator",
              readonly: true,
            },
            artifact: "/tmp/mock.png",
            pixelWidth: 1206,
            pixelHeight: 2622,
            dataUrl:
              "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0uoAAAAASUVORK5CYII=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      throw new Error(`Unexpected fetch route: ${url.pathname}`);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => logsText().includes("应用已启动") && logsText().includes("网络请求超时"));

    assert.match(logsText(), /应用已启动/);
    assert.match(logsText(), /网络请求超时/);
    assert.equal(document.querySelector(".log-row")?.getAttribute("title"), "App launched");
    assert.ok(fetchCalls.some((call) => call.pathname === "/web/host-logs" && call.method === "GET"));

    await clickRightSideTab(act, "设置");
    assert.match(document.querySelector('[aria-label="设置"]')?.textContent ?? "", /语言偏好/);
    const englishOption = document.querySelector('input[name="display-language"][value="en-US"]');
    assert.ok(englishOption, "Expected English language option");
    await act(async () => {
      englishOption.click();
    });

    assert.equal(window.localStorage.getItem("tritonkit.web.displayLanguage"), "en-US");
    assert.deepEqual(rightSideTabLabels(), ["Config", "Network", "Logs", "Settings"]);

    await clickRightSideTab(act, "Logs");
    await waitFor(() => logsText().includes("App launched") && logsText().includes("Network timeout"));
    assert.doesNotMatch(logsText(), /应用已启动|网络请求超时/);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("renders only ready wired real device targets and requests App runtime screenshot", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];
  const hostInputPayloads = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);
      fetchCalls.push({ pathname: url.pathname, method });

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-18T09:30:00.000Z",
            source: {
              commands: [
                "triton sim list --json",
                "triton device list --platform ios --scope real --json",
              ],
              runtimeScope: "host-device",
              readonly: true,
            },
            targets: [
              {
                id: "host:ios:00008140-redacted",
                target: "00008140-redacted",
                name: "Lin iPhone",
                platform: "ios",
                appName: null,
                bundleIdentifier: null,
                runtime: "iOS 18.5",
                state: "connected",
                statusLabel: "Ready",
                ready: true,
                scope: "real",
                kind: "real-device",
                transport: "wired",
                source: "devicectl",
                readonly: true,
                blockedReasons: [],
                sensitive: true,
              },
              {
                id: "host:ios:offline-redacted",
                target: "offline-redacted",
                name: "Offline iPhone",
                platform: "ios",
                appName: null,
                bundleIdentifier: null,
                runtime: "iOS 18.5",
                state: "offline",
                statusLabel: "offline",
                ready: false,
                scope: "real",
                kind: "real-device",
                source: "devicectl",
                readonly: true,
                blockedReasons: ["offline", "ddi-missing"],
                sensitive: true,
              },
              {
                id: "host:ios:wireless-redacted",
                target: "wireless-redacted",
                name: "Wireless iPhone",
                platform: "ios",
                appName: null,
                bundleIdentifier: null,
                runtime: "iOS 27.0",
                state: "connected",
                statusLabel: "connected",
                ready: true,
                scope: "real",
                kind: "real-device",
                transport: "localNetwork",
                source: "devicectl",
                readonly: true,
                blockedReasons: [],
                sensitive: true,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        assert.equal(url.searchParams.get("platform"), "ios");
        assert.equal(url.searchParams.get("scope"), "real");
        assert.equal(url.searchParams.get("kind"), "real-device");
        assert.equal(url.searchParams.get("source"), "runtime");
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "00008140-redacted",
            source: {
              command: "triton screenshot --output /tmp/runtime.png --json",
              runtimeScope: "app-runtime",
              readonly: true,
            },
            artifact: "memory://runtime.png",
            pixelWidth: 390,
            pixelHeight: 844,
            dataUrl: "data:image/png;base64,iVBORw0KGgo=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-input") {
        assert.equal(url.searchParams.get("platform"), "ios");
        assert.equal(url.searchParams.get("scope"), "real");
        assert.equal(url.searchParams.get("kind"), "real-device");
        assert.equal(url.searchParams.get("source"), "runtime");
        hostInputPayloads.push(JSON.parse(init?.body?.toString() ?? "{}"));
        return new Response(
          JSON.stringify({
            ok: true,
            action: "type",
            message: "Inserted text",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      throw new Error("Unexpected fetch route: " + url.pathname);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => deviceRowText().includes("Lin iPhone"));

    assert.match(deviceRowText(), /Lin iPhone/);
    assert.equal(document.querySelectorAll(".device-row-icon").length, 0);
    assert.ok(Array.from(document.querySelectorAll(".device-platform-badge")).some((badge) => badge.textContent?.trim() === "iOS"));
    assert.doesNotMatch(deviceRowText(), /真机/);
    assert.doesNotMatch(deviceRowText(), /App runtime 已连接/);
    assert.doesNotMatch(deviceRowText(), /前台 App 未暴露/);
    assert.doesNotMatch(deviceRowText(), /Offline iPhone/);
    assert.doesNotMatch(deviceRowText(), /Wireless iPhone/);
    assert.doesNotMatch(deviceRowText(), /Pixel API 35/);
    assert.doesNotMatch(deviceRowText(), /DevEco Local/);
    assert.match(bodyText(), /triton device list --platform ios --scope real --json/);
    assert.match(bodyText(), /就绪/);
    assert.equal(document.querySelector('[aria-label="主屏幕"]'), null);
    await waitFor(() => fetchCalls.some((call) => call.pathname === "/web/host-screenshot"));
    assert.doesNotMatch(bodyText(), /真机画面未接入/);
    assert.deepEqual(fetchCalls.map((call) => call.pathname), ["/web/host-targets", "/web/host-screenshot"]);

    const screen = document.querySelector(".device-screen");
    assert.ok(screen, "Expected interactive device screen");
    await act(async () => {
      screen.dispatchEvent(new window.KeyboardEvent("keydown", { key: "x", bubbles: true }));
    });
    await waitFor(() => hostInputPayloads.length === 1);
    assert.deepEqual(hostInputPayloads[0], { type: "type", text: "x" });
    await act(async () => {
      screen.dispatchEvent(new window.KeyboardEvent("keydown", { key: "Backspace", bubbles: true }));
    });
    await waitFor(() => hostInputPayloads.length === 2);
    assert.deepEqual(hostInputPayloads[1], { type: "deleteBackward" });
    await act(async () => {
      screen.dispatchEvent(new window.KeyboardEvent("keydown", { key: "Delete", bubbles: true }));
    });
    await waitFor(() => hostInputPayloads.length === 3);
    assert.deepEqual(hostInputPayloads[2], { type: "deleteBackward" });
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("pauses iOS real-device live screenshot polling while view tree is active", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?target=ios-real%3A7a9d976cc4d4&panel=view-tree",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);
      fetchCalls.push({ pathname: url.pathname, method });

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-20T01:00:00.000Z",
            source: {
              commands: [
                "triton device list --platform ios --scope real --json",
                "triton list --json",
              ],
              runtimeScope: "host-device",
              readonly: true,
            },
            targets: [
              {
                id: "ios-real:7a9d976cc4d4",
                target: "ios-real:7a9d976cc4d4",
                name: "iPhone",
                platform: "ios",
                appName: "Overloaded",
                bundleIdentifier: "overloaded.cn.debug",
                runtime: "iOS 26.5",
                state: "connected",
                statusLabel: "Ready",
                ready: true,
                scope: "real",
                kind: "real-device",
                transport: "wired",
                source: "devicectl",
                readonly: true,
                blockedReasons: [],
                sensitive: false,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        assert.equal(url.searchParams.get("source"), "runtime");
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "ios-real:7a9d976cc4d4",
            source: {
              command: "triton screenshot --target triton:connection:14 --json",
              runtimeScope: "app-runtime",
              readonly: true,
            },
            artifact: "memory://runtime.png",
            pixelWidth: 402,
            pixelHeight: 874,
            dataUrl: "data:image/png;base64,iVBORw0KGgo=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-hierarchy") {
        assert.equal(url.searchParams.get("source"), "runtime");
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-20T01:00:00.000Z",
            source: {
              command: "triton hierarchy --platform ios --target triton:connection:14 --json",
              runtimeScope: "runtime-tree",
              readonly: true,
            },
            scene: hierarchyScenes.ios,
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      throw new Error("Unexpected fetch route: " + url.pathname);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => fetchCalls.some((call) => call.pathname === "/web/host-screenshot"));
    await waitFor(() => fetchCalls.some((call) => call.pathname === "/web/host-hierarchy"));
    const screenshotCalls = fetchCalls.filter((call) => call.pathname === "/web/host-screenshot").length;

    await act(async () => {
      await new Promise((resolve) => window.setTimeout(resolve, 1250));
    });

    assert.equal(fetchCalls.filter((call) => call.pathname === "/web/host-screenshot").length, screenshotCalls);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("shows explicit runtime server guidance when iOS real-device live screenshot is unavailable", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      fetchCalls.push({ pathname: url.pathname, method: init?.method ?? resolveRequestMethod(input) });

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T12:30:00.000Z",
            source: {
              commands: ["triton device list --platform ios --scope real --json"],
              runtimeScope: "host-device",
              readonly: true,
            },
            targets: [
              {
                id: "host:ios:ios-real:abc",
                target: "ios-real:abc",
                name: "Debug iPhone",
                platform: "ios",
                appName: null,
                bundleIdentifier: null,
                runtime: "iOS 26.5",
                state: "connected",
                statusLabel: "connected",
                ready: true,
                scope: "real",
                kind: "real-device",
                transport: "wired",
                source: "devicectl",
                readonly: true,
                blockedReasons: [],
                sensitive: false,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        return new Response(
          JSON.stringify({
            ok: false,
            error: {
              code: "app_runtime_unavailable",
              message: "server_unavailable",
              hint: "Start `triton serve --host 127.0.0.1 --port 19421`, launch a Debug app that embeds TritonKit runtime, then retry the App runtime mirror.",
            },
          }),
          { status: 409, headers: { "content-type": "application/json" } }
        );
      }

      throw new Error("Unexpected fetch route: " + url.pathname);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => fetchCalls.some((call) => call.pathname === "/web/host-screenshot"));
    await waitFor(() => bodyText().includes("App runtime 未连接"));

    assert.match(bodyText(), /真机实时画面依赖 Debug App 内嵌 TritonKit runtime/);
    assert.match(bodyText(), /triton serve --host 127\.0\.0\.1 --port 19421/);
    assert.equal(document.querySelector(".real-screenshot"), null);
    assert.ok(document.querySelector(".real-screenshot-pending.is-error"));
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("dispatches iOS Simulator canvas tap through the host input bridge", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];
  const hostInputPayloads = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);
      fetchCalls.push({ pathname: url.pathname, method });

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-18T11:30:00.000Z",
            source: {
              commands: ["triton sim list --json"],
              runtimeScope: "host-device",
              readonly: true,
            },
            targets: [
              {
                id: "sim:AAAA-BBBB",
                target: "AAAA-BBBB",
                name: "iPhone 17",
                platform: "ios",
                appName: "前台 App 未暴露 · iPhone 17",
                bundleIdentifier: "Target AAAA-BBBB",
                runtime: "iOS 26.5",
                state: "Booted",
                statusLabel: "Booted",
                ready: true,
                scope: "simulator",
                kind: "simulator",
                source: "simctl",
                readonly: true,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        assert.equal(url.searchParams.get("platform"), "ios");
        assert.equal(url.searchParams.get("scope"), "simulator");
        assert.equal(url.searchParams.get("kind"), "simulator");
        assert.equal(url.searchParams.get("source"), "host");
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "AAAA-BBBB",
            source: {
              command: "triton sim screenshot --simulator AAAA-BBBB --output /tmp/frame.png --json",
              runtimeScope: "host-simulator",
              readonly: true,
            },
            artifact: "memory://simulator-frame.png",
            pixelWidth: 390,
            pixelHeight: 844,
            dataUrl: "data:image/png;base64,iVBORw0KGgo=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-input") {
        assert.equal(url.searchParams.get("platform"), "ios");
        assert.equal(url.searchParams.get("scope"), "simulator");
        assert.equal(url.searchParams.get("kind"), "simulator");
        assert.equal(url.searchParams.get("source"), "host");
        const requestBody = JSON.parse(init?.body?.toString() ?? "{}");
        hostInputPayloads.push(requestBody);
        return new Response(
          JSON.stringify({
            ok: true,
            action: requestBody.type,
            message: "iOS Simulator input was submitted through Triton host-HID adapter.",
            activationClassName: requestBody.type === "tap" ? "UITextField" : undefined,
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      throw new Error("Unexpected fetch route: " + url.pathname);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => document.querySelector(".device-screen.is-interactive"));
    const screen = document.querySelector(".device-screen");
    assert.ok(screen, "Expected iOS Simulator screen to accept input");
    screen.getBoundingClientRect = () => ({
      left: 0,
      top: 0,
      width: 390,
      height: 844,
      right: 390,
      bottom: 844,
      x: 0,
      y: 0,
      toJSON() {
        return {};
      },
    });

    await act(async () => {
      screen.dispatchEvent(new window.PointerEvent("pointerdown", { pointerId: 1, clientX: 180, clientY: 410, bubbles: true }));
      screen.dispatchEvent(new window.PointerEvent("pointerup", { pointerId: 1, clientX: 180, clientY: 410, bubbles: true }));
    });

    await waitFor(() => hostInputPayloads.length === 1);
    assert.deepEqual(hostInputPayloads[0], { type: "tap", x: 180, y: 410, width: 390, height: 844 });
    const relay = document.querySelector('input[aria-label="设备键盘输入"]');
    assert.ok(relay, "Expected Web keyboard relay input after tapping the device screen");
    assert.equal(document.activeElement, relay);

    await setTextInputValue(act, relay, "hello");
    await waitFor(() => hostInputPayloads.length === 2);
    assert.deepEqual(hostInputPayloads[1], { type: "type", text: "hello" });

    await setTextInputValue(act, relay, "");
    await waitFor(() => hostInputPayloads.length === 7);
    assert.deepEqual(hostInputPayloads.slice(2), [
      { type: "deleteBackward" },
      { type: "deleteBackward" },
      { type: "deleteBackward" },
      { type: "deleteBackward" },
      { type: "deleteBackward" },
    ]);

    assert.ok(fetchCalls.some((call) => call.pathname === "/web/host-input" && call.method === "POST"));
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("dispatches canvas long press and pinch gestures through the host input bridge", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const hostInputPayloads = [];
  const hostInputSources = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T09:10:00.000Z",
            source: {
              commands: ["triton sim list --json"],
              runtimeScope: "host-device",
              readonly: true,
            },
            targets: [
              {
                id: "sim:GESTURE",
                target: "GESTURE",
                name: "Gesture iPhone",
                platform: "ios",
                appName: "前台 App 未暴露 · Gesture iPhone",
                bundleIdentifier: "Target GESTURE",
                runtime: "iOS 26.5",
                state: "Booted",
                statusLabel: "Booted",
                ready: true,
                scope: "simulator",
                kind: "simulator",
                source: "simctl",
                readonly: true,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "GESTURE",
            source: {
              command: "triton sim screenshot --simulator GESTURE --output /tmp/frame.png --json",
              runtimeScope: "host-simulator",
              readonly: true,
            },
            artifact: "memory://simulator-frame.png",
            pixelWidth: 390,
            pixelHeight: 844,
            dataUrl: "data:image/png;base64,iVBORw0KGgo=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-input") {
        const requestBody = JSON.parse(init?.body?.toString() ?? "{}");
        hostInputPayloads.push(requestBody);
        hostInputSources.push(url.searchParams.get("source"));
        return new Response(
          JSON.stringify({
            ok: requestBody.type === "longPress",
            action: requestBody.type,
            message: requestBody.type === "longPress" ? "long press submitted" : "pinch unsupported",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      throw new Error("Unexpected fetch route: " + url.pathname);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => document.querySelector(".device-screen.is-interactive"));
    const screen = document.querySelector(".device-screen");
    assert.ok(screen, "Expected iOS Simulator screen to accept input");
    screen.getBoundingClientRect = () => ({
      left: 0,
      top: 0,
      width: 390,
      height: 844,
      right: 390,
      bottom: 844,
      x: 0,
      y: 0,
      toJSON() {
        return {};
      },
    });

    await act(async () => {
      screen.dispatchEvent(new window.PointerEvent("pointerdown", { pointerId: 1, clientX: 190, clientY: 420, bubbles: true }));
    });
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 570));
    });
    await waitFor(() => hostInputPayloads.length === 1);
    await act(async () => {
      screen.dispatchEvent(new window.PointerEvent("pointerup", { pointerId: 1, clientX: 190, clientY: 420, bubbles: true }));
    });

    assert.equal(hostInputPayloads.length, 1);
    assert.equal(hostInputPayloads[0].type, "longPress");
    assert.equal(hostInputSources[0], "runtime");
    assert.equal(hostInputPayloads[0].x, 190);
    assert.equal(hostInputPayloads[0].y, 420);
    assert.equal(hostInputPayloads[0].width, 390);
    assert.equal(hostInputPayloads[0].height, 844);
    assert.ok(hostInputPayloads[0].duration >= 0.5);

    await act(async () => {
      screen.dispatchEvent(new window.PointerEvent("pointerdown", { pointerId: 10, clientX: 160, clientY: 420, bubbles: true }));
      screen.dispatchEvent(new window.PointerEvent("pointerdown", { pointerId: 11, clientX: 220, clientY: 420, bubbles: true }));
      screen.dispatchEvent(new window.PointerEvent("pointermove", { pointerId: 10, clientX: 130, clientY: 420, bubbles: true }));
      screen.dispatchEvent(new window.PointerEvent("pointermove", { pointerId: 11, clientX: 250, clientY: 420, bubbles: true }));
      screen.dispatchEvent(new window.PointerEvent("pointerup", { pointerId: 11, clientX: 250, clientY: 420, bubbles: true }));
    });

    await waitFor(() => hostInputPayloads.length === 2);
    assert.equal(hostInputSources[1], "runtime");
    assert.deepEqual(hostInputPayloads[1], {
      type: "pinch",
      centerX: 190,
      centerY: 420,
      startDistance: 60,
      endDistance: 120,
      scale: 2,
      width: 390,
      height: 844,
      duration: 0.25,
    });

    const zoomInButton = document.querySelector('[aria-label="发送放大捏合"]');
    assert.ok(zoomInButton, "Expected explicit pinch zoom-in control");
    await act(async () => {
      zoomInButton.dispatchEvent(new window.MouseEvent("click", { bubbles: true }));
    });

    await waitFor(() => hostInputPayloads.length === 3);
    assert.equal(hostInputSources[2], "runtime");
    assert.deepEqual(hostInputPayloads[2], {
      type: "pinch",
      centerX: 195,
      centerY: 422,
      startDistance: 85.8,
      endDistance: 171.6,
      scale: 2,
      width: 390,
      height: 844,
      duration: 0.25,
    });
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("does not show keyboard relay when tap result is not an editable control", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-18T15:54:44Z",
            source: {
              commands: ["triton sim list --json"],
              runtimeScope: "host-device",
              readonly: true,
            },
            targets: [
              {
                id: "sim:AAAA-BBBB",
                target: "AAAA-BBBB",
                name: "iPhone 17",
                platform: "ios",
                appName: "前台 App 未暴露 · iPhone 17",
                bundleIdentifier: "Target AAAA-BBBB",
                runtime: "iOS 26.5",
                state: "Booted",
                statusLabel: "Booted",
                ready: true,
                scope: "simulator",
                kind: "simulator",
                source: "simctl",
                readonly: true,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "AAAA-BBBB",
            source: {
              command: "triton sim screenshot --simulator AAAA-BBBB --output /tmp/frame.png --json",
              runtimeScope: "host-simulator",
              readonly: true,
            },
            artifact: "memory://simulator-frame.png",
            pixelWidth: 390,
            pixelHeight: 844,
            dataUrl: "data:image/png;base64,iVBORw0KGgo=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-input") {
        const requestBody = JSON.parse(init?.body?.toString() ?? "{}");
        assert.equal(requestBody.type, "tap");
        return new Response(
          JSON.stringify({
            ok: true,
            action: "tap",
            message: "iOS Simulator tap was submitted through Triton host-HID adapter.",
            activationClassName: "UIButton",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      throw new Error("Unexpected fetch route: " + url.pathname);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => document.querySelector(".device-screen.is-interactive"));
    const screen = document.querySelector(".device-screen");
    assert.ok(screen, "Expected iOS Simulator screen to accept input");
    screen.getBoundingClientRect = () => ({
      left: 0,
      top: 0,
      width: 390,
      height: 844,
      right: 390,
      bottom: 844,
      x: 0,
      y: 0,
      toJSON() {
        return {};
      },
    });

    await act(async () => {
      screen.dispatchEvent(new window.PointerEvent("pointerdown", { pointerId: 1, clientX: 180, clientY: 410, bubbles: true }));
      screen.dispatchEvent(new window.PointerEvent("pointerup", { pointerId: 1, clientX: 180, clientY: 410, bubbles: true }));
    });

    await waitFor(() => !document.querySelector(".input-activity-badge"));
    assert.equal(document.querySelector('input[aria-label="设备键盘输入"]'), null);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("keeps request-failed fallback notice while switching Android and Harmony targets in mounted DOM", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);

      fetchCalls.push({
        pathname: url.pathname,
        method,
        forcedMode: url.searchParams.get("__tritonkit_mock_host_targets"),
      });
      return new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: {
          "content-type": "application/json",
        },
      });
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => hasRequestFailedFallbackNotice());
    assert.deepEqual(fetchCalls, []);

    await clickDeviceRow(act, "Pixel API 35");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      currentAppName() === "Overloaded" &&
      currentBundleId() === "overloaded.cn.debug" &&
      bodyText().includes("/api/catalog") &&
      bodyText().includes("Android ADB 目标已就绪：emulator-5556")
    );

    await clickDeviceRow(act, "DevEco Local");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      currentAppName() === "Triton Smoke" &&
      currentBundleId() === "com.tritonkit.demo" &&
      bodyText().includes("/capabilities") &&
      bodyText().includes("已从 HDC 列表 fallback 发现目标")
    );

    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "Host bridge unavailable");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "Host bridge 请求失败"
    );
    assert.equal(document.querySelector(".bridge-notice span")?.textContent?.trim(), "Host targets request failed: 502");
    assert.equal(currentAppName(), "Triton Smoke");
    assert.equal(currentBundleId(), "com.tritonkit.demo");
    assert.match(bodyText(), /\/capabilities/);
    assert.match(bodyText(), /已从 HDC 列表 fallback 发现目标/);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("restores iOS DTO after round-tripping Android and Harmony targets in request-failed fallback", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);

      fetchCalls.push({
        pathname: url.pathname,
        method,
        forcedMode: url.searchParams.get("__tritonkit_mock_host_targets"),
      });
      return new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: {
          "content-type": "application/json",
        },
      });
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      currentAppName() === "丁香园" &&
      currentBundleId() === "cn.dxy.iDxyer" &&
      networkEvidenceText().includes("/v1/home/feed") &&
      logsText().includes("已选择 iOS 目标，并匹配到内嵌 App runtime")
    );

    assert.deepEqual(fetchCalls, []);

    await clickDeviceRow(act, "Pixel API 35");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      currentAppName() === "Overloaded" &&
      currentBundleId() === "overloaded.cn.debug" &&
      networkEvidenceText().includes("/api/catalog") &&
      logsText().includes("Android ADB 目标已就绪：emulator-5556")
    );

    await clickDeviceRow(act, "DevEco Local");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      currentAppName() === "Triton Smoke" &&
      currentBundleId() === "com.tritonkit.demo" &&
      networkEvidenceText().includes("/capabilities") &&
      logsText().includes("已从 HDC 列表 fallback 发现目标")
    );

    await clickDeviceRow(act, "DXY iPhone 15");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      currentAppName() === "丁香园" &&
      currentBundleId() === "cn.dxy.iDxyer" &&
      networkEvidenceText().includes("/v1/home/feed") &&
      logsText().includes("已选择 iOS 目标，并匹配到内嵌 App runtime")
    );

    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "Host bridge unavailable");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "Host bridge 请求失败"
    );
    assert.equal(document.querySelector(".bridge-notice span")?.textContent?.trim(), "Host targets request failed: 502");
    assert.equal(currentAppName(), "丁香园");
    assert.equal(currentBundleId(), "cn.dxy.iDxyer");
    assert.match(networkEvidenceText(), /\/v1\/home\/feed/);
    assert.match(logsText(), /已选择 iOS 目标，并匹配到内嵌 App runtime/);
    assert.doesNotMatch(logsText(), /Android ADB 目标已就绪：emulator-5556/);
    assert.doesNotMatch(logsText(), /已从 HDC 列表 fallback 发现目标/);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("keeps target switching only in devices tab during request-failed fallback round-trip", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);

      fetchCalls.push({
        pathname: url.pathname,
        method,
        forcedMode: url.searchParams.get("__tritonkit_mock_host_targets"),
      });
      return new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: {
          "content-type": "application/json",
        },
      });
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => hasRequestFailedFallbackNotice());
    assert.deepEqual(fetchCalls, []);

    await clickTabButton(act, "视图树");
    await waitFor(() =>
      viewTreeText().includes("UIStackView") &&
      viewTreeText().includes("questionList")
    );
    assert.equal(viewTreeHeaderText(), "");
    assert.deepEqual(viewTreeTargetNames(), []);
    assert.equal(viewTreeTargetText(), "");

    await clickTabButton(act, "设备");
    await clickDeviceRow(act, "Pixel API 35");
    await clickTabButton(act, "视图树");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      viewTreeText().includes("AndroidComposeView") &&
      viewTreeText().includes("settingsList") &&
      currentAppName() === "Overloaded" &&
      currentBundleId() === "overloaded.cn.debug" &&
      networkEvidenceText().includes("/api/catalog") &&
      logsText().includes("Android ADB 目标已就绪：emulator-5556")
    );
    assert.deepEqual(viewTreeTargetNames(), []);

    await clickTabButton(act, "设备");
    await clickDeviceRow(act, "DevEco Local");
    await clickTabButton(act, "视图树");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      viewTreeText().includes("Column") &&
      viewTreeText().includes("settingsContent") &&
      currentAppName() === "Triton Smoke" &&
      currentBundleId() === "com.tritonkit.demo" &&
      networkEvidenceText().includes("/capabilities") &&
      logsText().includes("已从 HDC 列表 fallback 发现目标")
    );
    assert.deepEqual(viewTreeTargetNames(), []);

    await clickTabButton(act, "设备");
    await clickDeviceRow(act, "DXY iPhone 15");
    await clickTabButton(act, "视图树");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      viewTreeText().includes("UIStackView") &&
      viewTreeText().includes("questionList") &&
      currentAppName() === "丁香园" &&
      currentBundleId() === "cn.dxy.iDxyer" &&
      networkEvidenceText().includes("/v1/home/feed") &&
      logsText().includes("已选择 iOS 目标，并匹配到内嵌 App runtime")
    );

    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "Host bridge unavailable");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "Host bridge 请求失败"
    );
    assert.equal(viewTreeHeaderText(), "");
    assert.match(viewTreeText(), /UIStackView/);
    assert.match(viewTreeText(), /questionList/);
    assert.doesNotMatch(viewTreeText(), /AndroidComposeView/);
    assert.doesNotMatch(viewTreeText(), /settingsContent/);
    assert.equal(currentAppName(), "丁香园");
    assert.equal(currentBundleId(), "cn.dxy.iDxyer");
    assert.match(networkEvidenceText(), /\/v1\/home\/feed/);
    assert.match(logsText(), /已选择 iOS 目标，并匹配到内嵌 App runtime/);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("syncs selected device and view-tree node into the URL route", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed&target=host%3Aandroid%3Aemulator-5556&panel=view-tree&node=lazy-column",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async () => new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: {
        "content-type": "application/json",
      },
    }),
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      viewTreeText().includes("AndroidComposeView") &&
      selectedViewTreeNodeId() === "lazy-column"
    );
    assert.equal(viewTreeHeaderText(), "");

    let route = new URL(window.location.href);
    assert.equal(route.searchParams.get("target"), "host:android:emulator-5556");
    assert.equal(route.searchParams.get("panel"), "view-tree");
    assert.equal(route.searchParams.get("node"), "lazy-column");
    assert.equal(route.searchParams.get("__tritonkit_mock_host_targets"), "request-failed");

    assert.deepEqual(viewTreeTargetNames(), []);
    await clickTabButton(act, "设备");
    await clickDeviceRow(act, "DevEco Local");
    await clickTabButton(act, "视图树");
    await waitFor(() =>
      viewTreeText().includes("ArkUIRoot") &&
      selectedViewTreeNodeId() !== "lazy-column"
    );

    route = new URL(window.location.href);
    assert.equal(route.searchParams.get("target"), "host:harmony:127.0.0.1:5555");
    assert.equal(route.searchParams.get("panel"), "view-tree");
    assert.equal(route.searchParams.get("node"), null);
    assert.equal(route.searchParams.get("__tritonkit_mock_host_targets"), "request-failed");

    await clickViewTreeNode(act, "debug-link");
    await waitFor(() => selectedViewTreeNodeId() === "debug-link");

    route = new URL(window.location.href);
    assert.equal(route.searchParams.get("target"), "host:harmony:127.0.0.1:5555");
    assert.equal(route.searchParams.get("panel"), "view-tree");
    assert.equal(route.searchParams.get("node"), "debug-link");
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("highlights selected view-tree node area on the device canvas", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed&panel=view-tree&node=back",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async () => new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: {
        "content-type": "application/json",
      },
    }),
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      selectedViewTreeNodeId() === "back" &&
      selectedViewNodeHighlightId() === "back"
    );
    const highlight = selectedViewNodeHighlight();
    assert.ok(highlight, "Expected selected view node highlight");
    assert.equal(highlight.getAttribute("data-node-type"), "UIButton");
    assertApproxPercent(highlight.style.left, 3.59);
    assertApproxPercent(highlight.style.top, 6.52);
    assertApproxPercent(highlight.style.width, 8.72);
    assertApproxPercent(highlight.style.height, 4.03);

    await clickViewTreeNode(act, "title");
    await waitFor(() =>
      selectedViewTreeNodeId() === "title" &&
      selectedViewNodeHighlightId() === "title"
    );
    assert.equal(selectedViewNodeHighlight()?.getAttribute("data-node-type"), "UILabel");
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("shows selected view-tree node details in config tab and previews hot edits locally", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?target=host%3Aios%3ASIM1&panel=view-tree",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const mangledControllerClass =
    "_TtC10OverloadedP33_2366C6587D0D3ED5C44035A7EBDE340F31LocalPhotoPreviewViewController";
  const readableControllerClass = "LocalPhotoPreviewViewController";
  const hierarchySceneWithSwiftPrivateController = {
    ...hierarchyScenes.ios,
    controllerContext: {
      ...hierarchyScenes.ios.controllerContext,
      activeControllerId: "ios:controller:88",
      activeControllerName: readableControllerClass,
      activeControllerClassName: mangledControllerClass,
      stack: [
        hierarchyScenes.ios.controllerContext.stack[0],
        {
          id: "ios:controller:88",
          oid: 88,
          className: mangledControllerClass,
          name: readableControllerClass,
          title: "Search",
        },
      ],
    },
    nodes: hierarchyScenes.ios.nodes.map((node) =>
      node.id === "ios:controller:88"
        ? { ...node, type: mangledControllerClass, name: `${readableControllerClass}#88` }
        : node
    ),
  };

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input) => {
      const url = new URL(resolveRequestURL(input), window.location.href);

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T12:00:00.000Z",
            source: {
              commands: ["triton sim list --json"],
              runtimeScope: "host",
              readonly: true,
            },
            targets: [
              {
                id: "host:ios:SIM1",
                target: "SIM1",
                name: "iPhone 15",
                platform: "ios",
                appName: "Overloaded",
                bundleIdentifier: "overloaded.cn.debug",
                runtime: "iOS 26.5",
                state: "Booted",
                statusLabel: "Ready",
                ready: true,
                scope: "simulator",
                kind: "simulator",
                transport: "simctl",
                source: "simctl",
                readonly: true,
                blockedReasons: [],
                sensitive: false,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-hierarchy") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T12:00:00.000Z",
            source: {
              command: "triton hierarchy --platform ios --target SIM1 --json",
              runtimeScope: "host",
              readonly: true,
            },
            scene: hierarchySceneWithSwiftPrivateController,
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "SIM1",
            source: {
              command: "triton screenshot --target SIM1 --json",
              runtimeScope: "host",
              readonly: true,
            },
            artifact: "/tmp/sim.png",
            pixelWidth: 390,
            pixelHeight: 844,
            dataUrl: "data:image/png;base64,AAA=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-logs") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T12:00:00.000Z",
            source: {
              command: "triton logs --target SIM1 --json",
              runtimeScope: "host",
              readonly: true,
            },
            entries: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      throw new Error(`Unexpected fetch route: ${url.pathname}`);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => controllerShellBadgeText() === readableControllerClass);
    assert.equal(controllerShellBadgeTitle(), `MainTabBarController > ${readableControllerClass}`);

    await clickViewTreeNode(act, "back");
    await waitFor(() => selectedViewTreeNodeId() === "back" && selectedViewNodeHighlightId() === "back");
    assert.equal(controllerShellBadgeText(), readableControllerClass);
    assert.equal(controllerShellBadgeTitle(), `MainTabBarController > ${readableControllerClass}`);
    assert.match(document.querySelector(".selected-node-panel")?.textContent ?? "", /UIButton/);
    assert.match(document.querySelector(".selected-node-panel")?.textContent ?? "", /backButton/);
    assert.match(document.querySelector(".selected-node-panel")?.textContent ?? "", /Runtime DTO/);

    assertApproxPercent(selectedViewNodeHighlight()?.style.left ?? "", 3.59);

    await setTextInputValue(act, document.querySelector('input[aria-label="修改选中节点 X"]'), "40");
    await waitFor(() => (document.querySelector(".selected-node-panel")?.textContent ?? "").includes("本地热修改预览"));
    assertApproxPercent(selectedViewNodeHighlight()?.style.left ?? "", 10.26);

    await setTextInputValue(act, document.querySelector('input[aria-label="修改选中节点背景色"]'), "#ff0000");
    await setTextInputValue(act, document.querySelector('input[aria-label="修改选中节点 Radius"]'), "12");
    await setTextInputValue(act, document.querySelector('input[aria-label="修改选中节点 Opacity"]'), "0.5");
    assert.equal(selectedViewNodeHighlight()?.style.getPropertyValue("--view-node-accent"), "#ff0000");
    assert.equal(selectedViewNodeHighlight()?.style.getPropertyValue("--view-node-radius"), "12px");
    assert.equal(selectedViewNodeHighlight()?.style.getPropertyValue("--view-node-alpha"), "0.5");

    await act(async () => {
      document.querySelector('input[aria-label="隐藏选中节点预览"]')?.click();
    });
    assert.equal(selectedViewNodeHighlight()?.getAttribute("data-hot-hidden"), "true");

    await clickButtonByLabel(act, "重置");
    await waitFor(() => (document.querySelector(".selected-node-panel")?.textContent ?? "").includes("Runtime DTO"));
    assertApproxPercent(selectedViewNodeHighlight()?.style.left ?? "", 3.59);
    assert.notEqual(selectedViewNodeHighlight()?.style.getPropertyValue("--view-node-accent"), "#ff0000");
    assert.equal(selectedViewNodeHighlight()?.getAttribute("data-hot-hidden"), "false");
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("live view-tree refresh updates the controller shell badge when the app page changes", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?target=host%3Aios%3ASIM1&panel=view-tree",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  let hierarchyRequests = 0;
  const sceneForController = (controllerName) => ({
    ...hierarchyScenes.ios,
    controllerContext: {
      ...hierarchyScenes.ios.controllerContext,
      activeControllerId: "ios:controller:88",
      activeControllerName: controllerName,
      activeControllerClassName: `Demo.${controllerName}`,
      stack: [
        hierarchyScenes.ios.controllerContext.stack[0],
        {
          id: "ios:controller:88",
          oid: 88,
          className: `Demo.${controllerName}`,
          name: controllerName,
        },
      ],
    },
    nodes: hierarchyScenes.ios.nodes.map((node) =>
      node.id === "ios:controller:88"
        ? { ...node, type: `Demo.${controllerName}`, name: `${controllerName}#88` }
        : node
    ),
  });

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input) => {
      const url = new URL(resolveRequestURL(input), window.location.href);

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T12:00:00.000Z",
            source: {
              commands: ["triton sim list --json"],
              runtimeScope: "host",
              readonly: true,
            },
            targets: [
              {
                id: "host:ios:SIM1",
                target: "SIM1",
                name: "iPhone 15",
                platform: "ios",
                appName: "Overloaded",
                bundleIdentifier: "overloaded.cn.debug",
                runtime: "iOS 26.5",
                state: "Booted",
                statusLabel: "Ready",
                ready: true,
                scope: "simulator",
                kind: "simulator",
                transport: "simctl",
                source: "simctl",
                readonly: true,
                blockedReasons: [],
                sensitive: false,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-hierarchy") {
        hierarchyRequests += 1;
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T12:00:00.000Z",
            source: {
              command: "triton hierarchy --platform ios --target SIM1 --json",
              runtimeScope: "host",
              readonly: true,
            },
            scene: sceneForController(hierarchyRequests === 1 ? "FirstViewController" : "SecondViewController"),
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "SIM1",
            source: {
              command: "triton screenshot --target SIM1 --json",
              runtimeScope: "host",
              readonly: true,
            },
            artifact: "/tmp/sim.png",
            pixelWidth: 390,
            pixelHeight: 844,
            dataUrl: "data:image/png;base64,AAA=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-logs") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T12:00:00.000Z",
            source: {
              command: "triton logs --target SIM1 --json",
              runtimeScope: "host-simulator",
              readonly: true,
            },
            entries: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      throw new Error(`Unexpected fetch route: ${url.pathname}`);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => controllerShellBadgeText() === "FirstViewController");
    await act(async () => {
      await new Promise((resolve) => window.setTimeout(resolve, 1100));
    });
    await waitFor(() => controllerShellBadgeText() === "SecondViewController");
    assert.ok(hierarchyRequests >= 2, "Expected live hierarchy refresh to request a fresh scene");
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("snapshot mode stops live refresh and selects view nodes instead of sending input", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?target=host%3Aios%3ASIM1&panel=view-tree&node=window",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);
      fetchCalls.push({ pathname: url.pathname, method });

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T12:00:00.000Z",
            source: {
              commands: ["triton sim list --json"],
              runtimeScope: "host",
              readonly: true,
            },
            targets: [
              {
                id: "host:ios:SIM1",
                target: "SIM1",
                name: "iPhone 15",
                platform: "ios",
                appName: "Overloaded",
                bundleIdentifier: "overloaded.cn.debug",
                runtime: "iOS 26.5",
                state: "Booted",
                statusLabel: "Ready",
                ready: true,
                scope: "simulator",
                kind: "simulator",
                transport: "simctl",
                source: "simctl",
                readonly: true,
                blockedReasons: [],
                sensitive: false,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-hierarchy") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T12:00:00.000Z",
            source: {
              command: "triton hierarchy --platform ios --target SIM1 --json",
              runtimeScope: "host",
              readonly: true,
            },
            scene: hierarchyScenes.ios,
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "SIM1",
            source: {
              command: "triton screenshot --target SIM1 --json",
              runtimeScope: "host",
              readonly: true,
            },
            artifact: "/tmp/sim.png",
            pixelWidth: 390,
            pixelHeight: 844,
            dataUrl: "data:image/png;base64,AAA=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-logs") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T12:00:00.000Z",
            source: {
              command: "triton logs --target SIM1 --json",
              runtimeScope: "host",
              readonly: true,
            },
            entries: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-input") {
        throw new Error("Snapshot mode must not send host input");
      }

      throw new Error(`Unexpected fetch route: ${url.pathname}`);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => selectedViewTreeNodeId() === "window" && document.querySelector(".live-preview-badge"));
    await clickButtonByLabel(act, "快照");
    await waitFor(() => document.querySelector(".snapshot-refresh-button"));

    const screenshotCallsAfterSnapshot = fetchCalls.filter((call) => call.pathname === "/web/host-screenshot").length;
    await act(async () => {
      await new Promise((resolve) => window.setTimeout(resolve, 1250));
    });
    assert.equal(fetchCalls.filter((call) => call.pathname === "/web/host-screenshot").length, screenshotCallsAfterSnapshot);

    const screen = document.querySelector(".device-screen");
    assert.ok(screen, "Expected device screen");
    screen.getBoundingClientRect = () => ({
      x: 0,
      y: 0,
      left: 0,
      top: 0,
      right: 390,
      bottom: 844,
      width: 390,
      height: 844,
      toJSON: () => ({}),
    });

    await act(async () => {
      screen.dispatchEvent(new window.PointerEvent("pointerdown", { pointerId: 1, clientX: 20, clientY: 60, bubbles: true }));
      screen.dispatchEvent(new window.PointerEvent("pointerup", { pointerId: 1, clientX: 20, clientY: 60, bubbles: true }));
    });
    await waitFor(() => selectedViewTreeNodeId() === "back");
    assert.equal(new URL(window.location.href).searchParams.get("node"), "back");
    assert.equal(fetchCalls.some((call) => call.pathname === "/web/host-input"), false);

    const screenshotCallsBeforeManualRefresh = fetchCalls.filter((call) => call.pathname === "/web/host-screenshot").length;
    await clickButtonByLabel(act, "刷新");
    await waitFor(() => fetchCalls.filter((call) => call.pathname === "/web/host-screenshot").length === screenshotCallsBeforeManualRefresh + 1);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("filters targets through the shared search box across devices and view-tree panels", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);

      fetchCalls.push({
        pathname: url.pathname,
        method,
        forcedMode: url.searchParams.get("__tritonkit_mock_host_targets"),
      });
      return new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: {
          "content-type": "application/json",
        },
      });
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => hasRequestFailedFallbackNotice());
    assert.deepEqual(fetchCalls, []);
    assert.equal(deviceRowNames().length, 3);

    await fillSearchInput(act, "Overloaded");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      deviceRowNames().length === 1 &&
      deviceRowText().includes("Pixel API 35") &&
      deviceRowText().includes("Overloaded")
    );

    assert.equal(currentAppName(), "丁香园");
    assert.equal(currentBundleId(), "cn.dxy.iDxyer");

    await clickDeviceRow(act, "Pixel API 35");
    await waitFor(() =>
      currentAppName() === "Overloaded" &&
      currentBundleId() === "overloaded.cn.debug" &&
      networkEvidenceText().includes("/api/catalog") &&
      logsText().includes("Android ADB 目标已就绪：emulator-5556")
    );

    await clickTabButton(act, "视图树");
    await waitFor(() =>
      viewTreeText().includes("AndroidComposeView") &&
      viewTreeTargetNames().length === 0
    );

    await fillSearchInput(act, "DXY");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      viewTreeText().includes("AndroidComposeView") &&
      viewTreeTargetNames().length === 0
    );

    assert.equal(viewTreeHeaderText(), "");
    assert.equal(currentAppName(), "Overloaded");
    assert.equal(currentBundleId(), "overloaded.cn.debug");

    await clickTabButton(act, "设备");
    await waitFor(() => deviceRowNames().length === 1 && deviceRowNames()[0] === "DXY iPhone 15");
    await clickDeviceRow(act, "DXY iPhone 15");
    await clickTabButton(act, "视图树");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      viewTreeText().includes("UIStackView") &&
      currentAppName() === "丁香园" &&
      currentBundleId() === "cn.dxy.iDxyer" &&
      networkEvidenceText().includes("/v1/home/feed") &&
      logsText().includes("已选择 iOS 目标，并匹配到内嵌 App runtime")
    );

    await clickTabButton(act, "设备");
    await fillSearchInput(act, "NoSuchTarget");
    await waitFor(() =>
      deviceRowNames().length === 0 &&
      deviceRowText().includes("未找到匹配 target") &&
      !deviceRowText().includes("暂无运行中的仿真器")
    );

    await clickTabButton(act, "视图树");
    await waitFor(() =>
      viewTreeText().includes("UIStackView") &&
      viewTreeTargetNames().length === 0 &&
      viewTreeTargetText() === ""
    );

    await fillSearchInput(act, "");
    await clickTabButton(act, "设备");
    await waitFor(() => deviceRowNames().length === 3);

    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "Host bridge unavailable");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "Host bridge 请求失败"
    );
    assert.equal(currentAppName(), "丁香园");
    assert.equal(currentBundleId(), "cn.dxy.iDxyer");
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("shows search empty state across devices and view-tree panels without implying no running targets", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);

      fetchCalls.push({
        pathname: url.pathname,
        method,
        forcedMode: url.searchParams.get("__tritonkit_mock_host_targets"),
      });
      return new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: {
          "content-type": "application/json",
        },
      });
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => hasRequestFailedFallbackNotice());
    assert.deepEqual(fetchCalls, []);
    assert.equal(deviceRowNames().length, 3);

    await fillSearchInput(act, "zzzz-no-target");
    await waitFor(() => deviceRowNames().length === 0 && emptyDevicesText() === "未找到匹配 target");
    assert.doesNotMatch(deviceRowText(), /暂无运行中的仿真器/);
    assert.equal(currentAppName(), "丁香园");
    assert.equal(currentBundleId(), "cn.dxy.iDxyer");

    await clickTabButton(act, "视图树");
    await waitFor(() => viewTreeText().includes("UIStackView") && viewTreeTargetNames().length === 0);
    assert.equal(emptyDevicesText(), undefined);
    assert.equal(viewTreeTargetText(), "");
    assert.equal(viewTreeHeaderText(), "");
    assert.equal(currentAppName(), "丁香园");
    assert.equal(currentBundleId(), "cn.dxy.iDxyer");

    await fillSearchInput(act, "");
    await clickTabButton(act, "设备");
    await waitFor(() => deviceRowNames().length === 3);
    assert.equal(emptyDevicesText(), undefined);
    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "Host bridge unavailable");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "Host bridge 请求失败"
    );
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("keeps network and logs as persistent right-side DevTools tabs", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T10:00:00.000Z",
            source: {
              commands: ["triton sim list --json"],
              runtimeScope: "host",
              readonly: true,
            },
            targets: [
              {
                id: "host:ios:60667794-96F8-40E6-8664-85538EC4663E",
                target: "60667794-96F8-40E6-8664-85538EC4663E",
                name: "DXY iPhone 15",
                platform: "ios",
                appName: "丁香园",
                bundleIdentifier: "cn.dxy.iDxyer",
                runtime: "iOS 18.5",
                state: "Booted",
                statusLabel: "Ready",
                ready: true,
                scope: "simulator",
                kind: "simulator",
                source: "host",
                readonly: true,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-logs") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T10:00:01.000Z",
            source: {
              command: "triton sim logs --json",
              runtimeScope: "host-simulator",
              readonly: true,
            },
            entries: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "60667794-96F8-40E6-8664-85538EC4663E",
            source: {
              command: "triton sim screenshot --json",
              runtimeScope: "host-simulator",
              readonly: true,
            },
            artifact: "/tmp/mock.png",
            pixelWidth: 1206,
            pixelHeight: 2622,
            dataUrl:
              "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0uoAAAAASUVORK5CYII=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      throw new Error(`Unexpected fetch route: ${url.pathname}`);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => networkEvidenceText().includes("/v1/home/feed"));
    let devtoolsRail = document.querySelector(".hub-devtools");
    assert.ok(devtoolsRail, "Expected evidence panes to live in the right-side DevTools tab area");
    assert.equal(document.querySelector(".hub-bottom"), null);
    assert.equal(document.querySelector(".device-controls"), null);
    assert.equal(document.querySelector(".traffic-lights"), null);
    assert.equal(document.querySelector('.toolbar-cluster[aria-label="添加模拟器和设备"]'), null);
    assert.equal(document.querySelectorAll('.hub-toolbar button[aria-label="收起侧边栏"], .hub-toolbar button[aria-label="展开侧边栏"]').length, 1);
    assert.ok(document.querySelector('button[aria-label="收起右侧面板"]'));
    assert.ok(document.querySelector('button[aria-label="刷新全局数据"]'));
    for (const unusedToolbarLabel of ["添加目标", "筛选与排序", "键盘", "屏幕布局", "展开", "更多", "调整", "文档", "信息"]) {
      assert.equal(
        document.querySelector(`.hub-toolbar button[aria-label="${unusedToolbarLabel}"]`),
        null,
        `Expected unused toolbar action ${unusedToolbarLabel} to be removed`
      );
    }
    const topTabs = document.querySelector('.inspector-tabs[role="tablist"]');
    assert.ok(topTabs, "Expected right-side top tab list");
    assert.deepEqual(rightSideTabLabels(), ["配置", "网络", "日志", "设置"]);
    assert.equal(activeRightSideTab(), "配置");
    assert.equal(document.querySelector('.inspector-tabs button[role="tab"][aria-label="信息"]'), null);
    assert.equal(document.querySelector('.inspector-tabs button[role="tab"][aria-label="应用"]'), null);

    await clickRightSideTab(act, "网络");
    await waitFor(() => networkEvidenceText().includes("/v1/home/feed"));
    assert.ok(devtoolsRail.contains(document.querySelector('[aria-label="网络证据"]')));
    assert.equal(document.querySelector('[aria-label="运行日志"]')?.hasAttribute("hidden"), true);
    assert.equal(activeRightSideTab(), "网络");

    await clickButtonByLabel(act, "收起右侧面板");
    await waitFor(() => document.querySelector(".hub-devtools") === null);
    assert.equal(document.querySelector(".inspector-tabs"), null);
    assert.equal(document.querySelector(".hub-body")?.classList.contains("is-devtools-hidden"), true);
    assert.ok(document.querySelector('button[aria-label="展开右侧面板"]'));

    await clickButtonByLabel(act, "展开右侧面板");
    await waitFor(() => document.querySelector(".hub-devtools") !== null);
    devtoolsRail = document.querySelector(".hub-devtools");
    assert.ok(devtoolsRail, "Expected right-side DevTools to be restored");
    assert.equal(document.querySelector(".hub-body")?.classList.contains("is-devtools-hidden"), false);
    assert.equal(activeRightSideTab(), "网络");

    await clickRightSideTab(act, "日志");
    await waitFor(() => logsText().includes("已选择 iOS 目标"));
    assert.equal(document.querySelector('[aria-label="网络证据"]')?.hasAttribute("hidden"), true);
    assert.ok(devtoolsRail.contains(document.querySelector('[aria-label="运行日志"]')));
    assert.equal(activeRightSideTab(), "日志");
    await clickRightSideTab(act, "网络");
    await waitFor(() => networkEvidenceText().includes("/v1/home/feed"));
    assert.equal(document.querySelector('[aria-label="运行日志"]')?.hasAttribute("hidden"), true);
    assert.equal(document.querySelectorAll('button[aria-label^="隐藏网络"]').length, 0);
    assert.equal(document.querySelectorAll('button[aria-label^="显示网络"]').length, 0);
    assert.equal(document.querySelectorAll('button[aria-label^="隐藏日志"]').length, 0);
    assert.equal(document.querySelectorAll('button[aria-label^="显示日志"]').length, 0);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("keeps device canvas in point mode without bottom control groups after removing 3D probe", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);
      fetchCalls.push({ pathname: url.pathname, method });

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-19T09:00:00Z",
            source: {
              commands: ["triton sim list --json"],
              runtimeScope: "host-device",
              readonly: true,
            },
            targets: [
              {
                id: "sim:AAAA-BBBB",
                target: "AAAA-BBBB",
                name: "iPhone 17",
                platform: "ios",
                appName: "前台 App 未暴露 · iPhone 17",
                bundleIdentifier: "Target AAAA-BBBB",
                runtime: "iOS 26.5",
                state: "Booted",
                statusLabel: "Booted",
                ready: true,
                scope: "simulator",
                kind: "simulator",
                source: "simctl",
                readonly: true,
              },
            ],
            commandOutputs: [],
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "AAAA-BBBB",
            source: {
              command: "triton sim screenshot --simulator AAAA-BBBB --output /tmp/frame.png --json",
              runtimeScope: "host-simulator",
              readonly: true,
            },
            artifact: "memory://simulator-frame.png",
            pixelWidth: 390,
            pixelHeight: 844,
            dataUrl: "data:image/png;base64,iVBORw0KGgo=",
          }),
          { status: 200, headers: { "content-type": "application/json" } }
        );
      }

      if (url.pathname === "/web/host-hierarchy") {
        throw new Error("3D probe mode should not request host hierarchy from the Web UI");
      }

      throw new Error("Unexpected fetch route: " + url.pathname);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => document.querySelector(".device-screen.is-interactive"));
    const screen = document.querySelector(".device-screen");
    assert.ok(screen, "Expected device screen to stay interactive");
    assert.equal(document.querySelector(".device-controls"), null);
    assert.equal(document.querySelector('button[aria-label="点选"]'), null);
    assert.equal(document.querySelector('button[aria-label="探测"]'), null);
    assert.equal(document.querySelector(".hierarchy-stage"), null);
    assert.equal(document.querySelector(".hierarchy-scene-viewer"), null);
    assert.equal(document.querySelector(".hierarchy-three-canvas"), null);
    assert.equal(document.querySelector('[aria-label="画布缩放控制"]'), null);
    assert.equal(document.querySelector(".canvas-zoom-controls"), null);
    assert.match(screen.className, /tool-point/);
    assert.equal(screen.getAttribute("aria-label"), "设备画面，当前工具 点选");
    assert.ok(document.querySelector(".live-preview-badge"), "Expected live preview control to remain available");

    await act(async () => {
      await new Promise((resolve) => window.setTimeout(resolve, 1250));
    });
    assert.equal(fetchCalls.some((call) => call.pathname === "/web/host-hierarchy"), false);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("keeps view tree available without rendering a 3D hierarchy canvas", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      if (url.pathname === "/web/host-hierarchy") {
        throw new Error("Removed 3D mode should not call host hierarchy from Web canvas");
      }
      return new Response(JSON.stringify({ ok: true }), {
        status: 200,
        headers: {
          "content-type": "application/json",
        },
      });
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => hasRequestFailedFallbackNotice());
    assert.equal(document.querySelector('button[aria-label="探测"]'), null);
    assert.equal(document.querySelector(".hierarchy-stage"), null);
    assert.equal(document.querySelector(".hierarchy-scene-viewer"), null);

    await clickTabButton(act, "视图树");
    await waitFor(() => viewTreeText().includes("UIStackView") && viewTreeText().includes("questionList"));

    await clickTabButton(act, "设备");
    await clickDeviceRow(act, "Pixel API 35");
    await clickTabButton(act, "视图树");
    await waitFor(() => viewTreeText().includes("AndroidComposeView") && viewTreeText().includes("settingsList"));

    await clickTabButton(act, "设备");
    await clickDeviceRow(act, "DevEco Local");
    await clickTabButton(act, "视图树");
    await waitFor(() => viewTreeText().includes("ArkUIRoot") && viewTreeText().includes("settingsContent"));
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("lets users tune live preview fps without changing selected host target state", async () => {
  const window = new Window({
    url: "http://127.0.0.1:34127/",
  });
  const restoreCallbacks = [];
  installDomGlobals(window, restoreCallbacks);
  const fetchCalls = [];

  overrideGlobal("IS_REACT_ACT_ENVIRONMENT", true, restoreCallbacks);
  overrideGlobal(
    "fetch",
    async (input, init) => {
      const url = new URL(resolveRequestURL(input), window.location.href);
      const method = init?.method ?? resolveRequestMethod(input);
      fetchCalls.push({ pathname: url.pathname, method });

      if (url.pathname === "/web/host-targets") {
        return new Response(
          JSON.stringify({
            ok: true,
            capturedAt: "2026-06-15T10:00:00.000Z",
            source: {
              commands: ["triton sim list --json", "triton device list --platform harmony --json"],
              runtimeScope: "host",
              readonly: true,
            },
            targets: [
              {
                id: "host:harmony:127.0.0.1:5555",
                target: "127.0.0.1:5555",
                name: "127.0.0.1:5555",
                platform: "harmony",
                appName: "前台 App 未暴露 · 127.0.0.1:5555",
                bundleIdentifier: "Target 127.0.0.1:5555",
                runtime: "HarmonyOS NEXT",
                state: "Booted",
                statusLabel: "Connected",
                ready: true,
                scope: "host",
                kind: "emulator",
                source: "triton device list --platform harmony --json",
                readonly: true,
              },
            ],
            commandOutputs: [],
          }),
          {
            status: 200,
            headers: {
              "content-type": "application/json",
            },
          }
        );
      }

      if (url.pathname === "/web/host-screenshot") {
        return new Response(
          JSON.stringify({
            ok: true,
            simulator: "127.0.0.1:5555",
            source: {
              command: "triton observe screenshot --platform harmony --target 127.0.0.1:5555 --json",
              runtimeScope: "host",
              readonly: true,
            },
            artifact: "memory://harmony-frame.png",
            pixelWidth: 320,
            pixelHeight: 700,
            dataUrl: "data:image/png;base64,iVBORw0KGgo=",
          }),
          {
            status: 200,
            headers: {
              "content-type": "application/json",
            },
          }
        );
      }

      throw new Error(`Unexpected fetch ${url.pathname}`);
    },
    restoreCallbacks
  );

  const [{ act, createElement }, { createRoot }] = await Promise.all([
    import("react"),
    import("react-dom/client"),
  ]);
  const container = document.createElement("div");
  document.body.appendChild(container);
  const root = createRoot(container);

  try {
    await act(async () => {
      root.render(createElement(App));
    });

    await waitFor(() => livePreviewFpsText() === "1 fps" && metricValue("帧率") === "1");
    assert.equal(currentAppName(), "前台 App 未暴露 · 127.0.0.1:5555");
    assert.equal(currentBundleId(), "Target 127.0.0.1:5555");
    assert.equal(previewFpsControlValue(), undefined);

    await clickLivePreviewBadge(act);
    await waitFor(() => previewFpsControlValue() === "1");
    await setPreviewFps(act, 15);
    await waitFor(() => livePreviewFpsText() === "15 fps" && metricValue("帧率") === "15");

    assert.equal(previewFpsControlValue(), "15");
    assert.equal(currentAppName(), "前台 App 未暴露 · 127.0.0.1:5555");
    assert.equal(currentBundleId(), "Target 127.0.0.1:5555");
    assert.ok(fetchCalls.some((call) => call.pathname === "/web/host-targets" && call.method === "GET"));
    assert.ok(fetchCalls.some((call) => call.pathname === "/web/host-screenshot" && call.method === "GET"));
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

function resolveRequestURL(input) {
  if (typeof input === "string") {
    return input;
  }
  if (input instanceof URL) {
    return input.href;
  }
  return input.url;
}

function resolveRequestMethod(input) {
  if (typeof input === "object" && input && "method" in input && input.method) {
    return input.method;
  }
  return "GET";
}

function installDomGlobals(window, restoreCallbacks) {
  const bindings = {
    window,
    self: window,
    document: window.document,
    navigator: window.navigator,
    HTMLElement: window.HTMLElement,
    SVGElement: window.SVGElement,
    Node: window.Node,
    Text: window.Text,
    Event: window.Event,
    CustomEvent: window.CustomEvent,
    MutationObserver: window.MutationObserver,
    getComputedStyle: window.getComputedStyle.bind(window),
    requestAnimationFrame: window.requestAnimationFrame.bind(window),
    cancelAnimationFrame: window.cancelAnimationFrame.bind(window),
    setTimeout: window.setTimeout.bind(window),
    clearTimeout: window.clearTimeout.bind(window),
  };

  for (const [name, value] of Object.entries(bindings)) {
    overrideGlobal(name, value, restoreCallbacks);
  }
}

function overrideGlobal(name, value, restoreCallbacks) {
  const descriptor = Object.getOwnPropertyDescriptor(globalThis, name);
  restoreCallbacks.push(() => {
    if (descriptor) {
      Object.defineProperty(globalThis, name, descriptor);
      return;
    }
    Reflect.deleteProperty(globalThis, name);
  });
  Object.defineProperty(globalThis, name, {
    configurable: true,
    writable: true,
    value,
  });
}

function restoreGlobalOverrides(restoreCallbacks) {
  while (restoreCallbacks.length > 0) {
    const restore = restoreCallbacks.pop();
    restore?.();
  }
}

async function waitFor(predicate, timeoutMs = 1500) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    if (predicate()) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 0));
  }

  throw new Error("Timed out waiting for fallback notice to appear in mounted DOM");
}

async function clickDeviceRow(act, deviceName) {
  const row = Array.from(document.querySelectorAll(".device-row")).find((candidate) =>
    candidate.textContent?.includes(deviceName)
  );
  assert.ok(row, `Expected to find device row for ${deviceName}`);
  await act(async () => {
    row.click();
  });
}

async function clickViewTreeNode(act, nodeId) {
  const row = document.querySelector(`.view-tree-row[data-node-id="${nodeId}"]`);
  assert.ok(row, `Expected to find view-tree node for ${nodeId}`);
  await act(async () => {
    row.click();
  });
}

async function clickRightSideTab(act, label) {
  const tab = Array.from(document.querySelectorAll('.inspector-tabs [role="tab"]')).find((candidate) =>
    candidate.textContent?.trim() === label
  );
  assert.ok(tab, `Expected to find right-side tab for ${label}`);
  await act(async () => {
    tab.click();
  });
}

async function clickTabButton(act, label) {
  const tab = Array.from(document.querySelectorAll(".sidebar-panel-switch button")).find((candidate) =>
    candidate.textContent?.includes(label)
  );
  assert.ok(tab, `Expected to find sidebar tab for ${label}`);
  await act(async () => {
    tab.click();
  });
}

async function clickButtonByLabel(act, label) {
  const button = document.querySelector(`button[aria-label="${label}"]`) ??
    Array.from(document.querySelectorAll("button")).find((candidate) => candidate.textContent?.trim() === label);
  assert.ok(button, `Expected to find button for ${label}`);
  await act(async () => {
    button.click();
  });
}

async function fillSearchInput(act, value) {
  const input = document.querySelector('input[placeholder="搜索"]');
  assert.ok(input && "value" in input, "Expected to find search input");
  await act(async () => {
    const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value")?.set;
    assert.ok(setter, "Expected HTMLInputElement value setter");
    setter.call(input, value);
    input.dispatchEvent(new window.Event("input", { bubbles: true, cancelable: true }));
    input.dispatchEvent(new window.Event("change", { bubbles: true, cancelable: true }));
  });
}

async function setTextInputValue(act, input, value) {
  assert.ok(input && "value" in input, "Expected text input element");
  await act(async () => {
    const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value")?.set;
    assert.ok(setter, "Expected HTMLInputElement value setter");
    setter.call(input, value);
    input.dispatchEvent(new window.Event("input", { bubbles: true, cancelable: true }));
    input.dispatchEvent(new window.Event("change", { bubbles: true, cancelable: true }));
  });
}

async function setPreviewFps(act, value) {
  const increase = document.querySelector('button[aria-label="提高实时预览帧率"]');
  const decrease = document.querySelector('button[aria-label="降低实时预览帧率"]');
  assert.ok(increase, "Expected to find live preview fps increase button");
  assert.ok(decrease, "Expected to find live preview fps decrease button");

  while (Number(previewFpsControlValue()) < value) {
    await act(async () => {
      increase.click();
    });
  }

  while (Number(previewFpsControlValue()) > value) {
    await act(async () => {
      decrease.click();
    });
  }
}

async function clickLivePreviewBadge(act) {
  const badge = document.querySelector('button[aria-label="展开实时预览帧率控制"]');
  assert.ok(badge, "Expected to find live preview fps badge button");
  await act(async () => {
    badge.click();
  });
}

function hasRequestFailedFallbackNotice() {
  return (
    document.querySelector(".toolbar-title span")?.textContent?.trim() === "Host bridge unavailable" &&
    document.querySelector(".bridge-notice strong")?.textContent?.trim() ===
      "Host bridge 请求失败" &&
    document.querySelector(".bridge-notice span")?.textContent?.trim() === "Host targets request failed: 502"
  );
}

function currentAppName() {
  return document.querySelector(".app-tile strong")?.textContent?.trim();
}

function currentBundleId() {
  return document.querySelector(".app-tile span")?.textContent?.trim();
}

function deviceRowNames() {
  return Array.from(document.querySelectorAll(".device-row strong")).map((candidate) => candidate.textContent?.trim() ?? "");
}

function bodyText() {
  return document.body.textContent ?? "";
}

function networkEvidenceText() {
  return document.querySelector('[aria-label="网络证据"], [aria-label="Network evidence"]')?.textContent ?? "";
}

function logsText() {
  return document.querySelector('[aria-label="运行日志"], [aria-label="Runtime logs"]')?.textContent ?? "";
}

function hierarchySceneText() {
  return document.querySelector(".hierarchy-scene-viewer")?.textContent ?? "";
}

function hierarchySceneLabel() {
  return document.querySelector(".hierarchy-scene-viewer")?.getAttribute("aria-label") ?? "";
}

function hierarchyRotationText() {
  return document.querySelector(".hierarchy-rotation-state")?.textContent ?? "";
}

function viewTreeHeaderText() {
  return document.querySelector(".view-tree-title")?.textContent?.trim() ?? "";
}

function livePreviewFpsText() {
  return document.querySelector(".live-preview-badge em")?.textContent?.trim();
}

function previewFpsControlValue() {
  return document.querySelector('input[aria-label="调整实时预览帧率"]')?.value;
}

function metricValue(label) {
  const metric = Array.from(document.querySelectorAll(".metric")).find((candidate) =>
    Array.from(candidate.querySelectorAll("span")).some((labelNode) => labelNode.textContent?.trim() === label)
  );
  return metric?.querySelector("strong")?.textContent?.trim();
}

function viewTreeText() {
  return document.querySelector(".view-tree-list")?.textContent ?? "";
}

function selectedViewTreeNodeId() {
  return document.querySelector(".view-tree-row.is-selected")?.getAttribute("data-node-id") ?? null;
}

function selectedViewNodeHighlight() {
  return document.querySelector(".view-node-highlight");
}

function selectedViewNodeHighlightId() {
  return selectedViewNodeHighlight()?.getAttribute("data-node-id") ?? null;
}

function controllerShellBadgeText() {
  return document.querySelector(".controller-shell-badge")?.textContent?.trim() ?? "";
}

function controllerShellBadgeTitle() {
  return document.querySelector(".controller-shell-badge")?.getAttribute("title") ?? "";
}

function assertApproxPercent(actual, expected, tolerance = 0.02) {
  assert.ok(actual.endsWith("%"), `Expected percent value, got ${actual}`);
  const numeric = Number.parseFloat(actual);
  assert.ok(Math.abs(numeric - expected) <= tolerance, `Expected ${actual} to be within ${tolerance}% of ${expected}%`);
}

function activeRightSideTab() {
  return document.querySelector('.inspector-tabs [role="tab"][aria-selected="true"]')?.textContent?.trim();
}

function rightSideTabLabels() {
  return Array.from(document.querySelectorAll('.inspector-tabs [role="tab"]')).map((tab) => tab.textContent?.trim() ?? "");
}

function viewTreeTargetNames() {
  return Array.from(document.querySelectorAll(".view-tree-target-chip strong")).map((candidate) =>
    candidate.textContent?.trim() ?? ""
  );
}

function viewTreeTargetText() {
  return document.querySelector(".view-tree-target-list")?.textContent ?? "";
}

function deviceRowText() {
  return document.querySelector(".device-list")?.textContent ?? "";
}

function emptyDevicesText() {
  return document.querySelector(".empty-devices")?.textContent?.trim();
}

function hostHierarchyResponseForDom(platform, method = "GET") {
  const cases = {
    ios: ["UIStackView", "questionList", "#6ea8ff"],
    android: ["AndroidComposeView", "settingsList", "#34d399"],
    harmony: ["ArkUIRoot", "settingsContent", "#f59e0b"],
  };
  const [type, name, color] = cases[platform] ?? cases.ios;
  return {
    ok: true,
    capturedAt: "2026-06-19T00:00:00.000Z",
    source: {
      command: `triton hierarchy --platform ${platform} --target local --json`,
      runtimeScope: platform === "ios" ? "runtime-tree" : "host-layout",
      readonly: true,
    },
    control: {
      action: "hierarchy.capture",
      entrypoint: "web-dev-bridge",
      method,
      readonly: true,
      mutatesApp: false,
    },
    captureEvidence: {
      captureId: `${platform}-mock-capture`,
      capturedAt: "2026-06-19T00:00:00.000Z",
      target: {
        id: "local",
        ambiguous: false,
      },
      source: {
        kind: "triton-hierarchy",
        nodeSlice: "styled",
        screenshotSlice: "none",
      },
      hydration: {
        dataUrlCount: 0,
        nodeCount: 2,
        failedNodeCount: 0,
      },
    },
    scene: {
      platform,
      rootId: `${platform}-root`,
      viewport: { width: 390, height: 844 },
      nodes: [
        {
          id: `${platform}-root`,
          type: platform === "ios" ? "UIWindow" : "RootView",
          name: "root",
          frame: { x: 0, y: 0, width: 390, height: 844 },
          depth: 0,
          visible: true,
          interactive: false,
          color,
        },
        {
          id: `${platform}-child`,
          parentId: `${platform}-root`,
          type,
          name,
          frame: { x: 24, y: 120, width: 342, height: 56 },
          depth: 3,
          visible: true,
          interactive: true,
          color,
          renderHints: { preferredMode: "slice", quality: "approximate" },
        },
      ],
    },
  };
}

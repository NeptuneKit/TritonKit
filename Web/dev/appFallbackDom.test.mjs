import assert from "node:assert/strict";
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

after(async () => {
  await viteServer.close();
});

test("mounts QA mock fallback notice in DOM when readonly host bridge returns no targets", async () => {
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
        subtitle === "QA mock fallback" &&
        noticeTitle === "当前没有可用 host target，正在展示 QA mock fallback" &&
        typeof noticeDetail === "string" &&
        noticeDetail.includes("targets 为空") &&
        noticeDetail.includes("triton sim list --json")
      );
    });

    assert.deepEqual(fetchCalls, [{ pathname: "/web/host-targets", method: "GET" }]);
    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "QA mock fallback");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "当前没有可用 host target，正在展示 QA mock fallback"
    );
    assert.match(document.querySelector(".bridge-notice span")?.textContent ?? "", /targets 为空/);
    assert.match(document.querySelector(".bridge-notice span")?.textContent ?? "", /triton sim list --json/);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("mounts QA mock fallback error notice in DOM when host bridge request fails", async () => {
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
        subtitle === "QA mock fallback" &&
        noticeTitle === "Host bridge 请求失败，正在展示 QA mock fallback" &&
        noticeDetail === "Host targets request failed: 502"
      );
    });

    assert.deepEqual(fetchCalls, []);
    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "QA mock fallback");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "Host bridge 请求失败，正在展示 QA mock fallback"
    );
    assert.equal(document.querySelector(".bridge-notice span")?.textContent?.trim(), "Host targets request failed: 502");
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

    await waitFor(() => logsText().includes("App launched") && logsText().includes("Network timeout"));

    assert.match(logsText(), /App launched/);
    assert.match(logsText(), /Network timeout/);
    assert.ok(fetchCalls.some((call) => call.pathname === "/web/host-logs" && call.method === "GET"));
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
        hostInputPayloads.push(JSON.parse(init?.body?.toString() ?? "{}"));
        return new Response(
          JSON.stringify({
            ok: true,
            action: "tap",
            message: "iOS Simulator tap was submitted through Triton host-HID adapter.",
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
      bodyText().includes("ADB target ready: emulator-5556")
    );

    await clickDeviceRow(act, "DevEco Local");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      currentAppName() === "Triton Smoke" &&
      currentBundleId() === "com.tritonkit.demo" &&
      bodyText().includes("/capabilities") &&
      bodyText().includes("HDC target discovered from plain list fallback")
    );

    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "QA mock fallback");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "Host bridge 请求失败，正在展示 QA mock fallback"
    );
    assert.equal(document.querySelector(".bridge-notice span")?.textContent?.trim(), "Host targets request failed: 502");
    assert.equal(currentAppName(), "Triton Smoke");
    assert.equal(currentBundleId(), "com.tritonkit.demo");
    assert.match(bodyText(), /\/capabilities/);
    assert.match(bodyText(), /HDC target discovered from plain list fallback/);
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
      logsText().includes("Selected host iOS target and paired embedded runtime")
    );

    assert.deepEqual(fetchCalls, []);

    await clickDeviceRow(act, "Pixel API 35");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      currentAppName() === "Overloaded" &&
      currentBundleId() === "overloaded.cn.debug" &&
      networkEvidenceText().includes("/api/catalog") &&
      logsText().includes("ADB target ready: emulator-5556")
    );

    await clickDeviceRow(act, "DevEco Local");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      currentAppName() === "Triton Smoke" &&
      currentBundleId() === "com.tritonkit.demo" &&
      networkEvidenceText().includes("/capabilities") &&
      logsText().includes("HDC target discovered from plain list fallback")
    );

    await clickDeviceRow(act, "DXY iPhone 15");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      currentAppName() === "丁香园" &&
      currentBundleId() === "cn.dxy.iDxyer" &&
      networkEvidenceText().includes("/v1/home/feed") &&
      logsText().includes("Selected host iOS target and paired embedded runtime")
    );

    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "QA mock fallback");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "Host bridge 请求失败，正在展示 QA mock fallback"
    );
    assert.equal(document.querySelector(".bridge-notice span")?.textContent?.trim(), "Host targets request failed: 502");
    assert.equal(currentAppName(), "丁香园");
    assert.equal(currentBundleId(), "cn.dxy.iDxyer");
    assert.match(networkEvidenceText(), /\/v1\/home\/feed/);
    assert.match(logsText(), /Selected host iOS target and paired embedded runtime/);
    assert.doesNotMatch(logsText(), /ADB target ready: emulator-5556/);
    assert.doesNotMatch(logsText(), /HDC target discovered from plain list fallback/);
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("keeps target switching available inside view-tree panel during request-failed fallback round-trip", async () => {
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
      viewTreeTargetNames().includes("DXY iPhone 15") &&
      viewTreeTitle() === "丁香园" &&
      viewTreeText().includes("UIStackView") &&
      viewTreeText().includes("questionList")
    );

    await clickViewTreeTarget(act, "Pixel API 35");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      viewTreeTitle() === "Overloaded" &&
      viewTreeText().includes("AndroidComposeView") &&
      viewTreeText().includes("settingsList") &&
      currentAppName() === "Overloaded" &&
      currentBundleId() === "overloaded.cn.debug" &&
      networkEvidenceText().includes("/api/catalog") &&
      logsText().includes("ADB target ready: emulator-5556")
    );

    await clickViewTreeTarget(act, "DevEco Local");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      viewTreeTitle() === "Triton Smoke" &&
      viewTreeText().includes("Column") &&
      viewTreeText().includes("settingsContent") &&
      currentAppName() === "Triton Smoke" &&
      currentBundleId() === "com.tritonkit.demo" &&
      networkEvidenceText().includes("/capabilities") &&
      logsText().includes("HDC target discovered from plain list fallback")
    );

    await clickViewTreeTarget(act, "DXY iPhone 15");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      viewTreeTitle() === "丁香园" &&
      viewTreeText().includes("UIStackView") &&
      viewTreeText().includes("questionList") &&
      currentAppName() === "丁香园" &&
      currentBundleId() === "cn.dxy.iDxyer" &&
      networkEvidenceText().includes("/v1/home/feed") &&
      logsText().includes("Selected host iOS target and paired embedded runtime")
    );

    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "QA mock fallback");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "Host bridge 请求失败，正在展示 QA mock fallback"
    );
    assert.equal(viewTreeTitle(), "丁香园");
    assert.match(viewTreeText(), /UIStackView/);
    assert.match(viewTreeText(), /questionList/);
    assert.doesNotMatch(viewTreeText(), /AndroidComposeView/);
    assert.doesNotMatch(viewTreeText(), /settingsContent/);
    assert.equal(currentAppName(), "丁香园");
    assert.equal(currentBundleId(), "cn.dxy.iDxyer");
    assert.match(networkEvidenceText(), /\/v1\/home\/feed/);
    assert.match(logsText(), /Selected host iOS target and paired embedded runtime/);
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
      logsText().includes("ADB target ready: emulator-5556")
    );

    await clickTabButton(act, "视图树");
    await waitFor(() =>
      viewTreeTargetNames().length === 1 &&
      viewTreeTargetNames()[0] === "Pixel API 35" &&
      viewTreeTitle() === "Overloaded"
    );

    await fillSearchInput(act, "DXY");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      viewTreeTargetNames().length === 1 &&
      viewTreeTargetNames()[0] === "DXY iPhone 15"
    );

    assert.equal(viewTreeTitle(), "Overloaded");
    assert.equal(currentAppName(), "Overloaded");
    assert.equal(currentBundleId(), "overloaded.cn.debug");

    await clickViewTreeTarget(act, "DXY iPhone 15");
    await waitFor(() =>
      hasRequestFailedFallbackNotice() &&
      viewTreeTitle() === "丁香园" &&
      currentAppName() === "丁香园" &&
      currentBundleId() === "cn.dxy.iDxyer" &&
      networkEvidenceText().includes("/v1/home/feed") &&
      logsText().includes("Selected host iOS target and paired embedded runtime")
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
      viewTreeTargetNames().length === 0 &&
      viewTreeTargetText().includes("未找到匹配 target")
    );

    await fillSearchInput(act, "");
    await waitFor(() => viewTreeTargetNames().length === 3);
    await clickTabButton(act, "设备");
    await waitFor(() => deviceRowNames().length === 3);

    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "QA mock fallback");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "Host bridge 请求失败，正在展示 QA mock fallback"
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
    await waitFor(() => viewTreeTargetNames().length === 0 && emptyDevicesText() === "未找到匹配 target");
    assert.equal(viewTreeTitle(), "丁香园");
    assert.equal(currentAppName(), "丁香园");
    assert.equal(currentBundleId(), "cn.dxy.iDxyer");

    await fillSearchInput(act, "");
    await waitFor(() => viewTreeTargetNames().length === 3);
    await clickTabButton(act, "设备");
    await waitFor(() => deviceRowNames().length === 3);
    assert.equal(emptyDevicesText(), undefined);
    assert.equal(document.querySelector(".toolbar-title span")?.textContent?.trim(), "QA mock fallback");
    assert.equal(
      document.querySelector(".bridge-notice strong")?.textContent?.trim(),
      "Host bridge 请求失败，正在展示 QA mock fallback"
    );
  } finally {
    await act(async () => {
      root.unmount();
    });
    restoreGlobalOverrides(restoreCallbacks);
    window.close();
  }
});

test("lets users hide and restore network evidence independently from logs", async () => {
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

    await waitFor(() => hasRequestFailedFallbackNotice() && networkEvidenceText().includes("/v1/home/feed"));
    assert.ok(document.querySelector('[aria-label="运行日志"]'));
    assert.equal(document.querySelectorAll('button[aria-label="隐藏网络"]').length, 1);
    assert.equal(document.querySelectorAll('button[aria-label="隐藏日志"]').length, 2);

    await clickButtonByLabel(act, "隐藏网络");
    await waitFor(() => !document.querySelector('[aria-label="网络证据"]'));
    assert.equal(networkEvidenceText(), "");
    assert.ok(document.querySelector('[aria-label="运行日志"]'));
    assert.equal(document.querySelector('[aria-label="证据面板已隐藏"]'), null);
    assert.equal(document.querySelectorAll('button[aria-label="显示网络"]').length, 1);

    await clickButtonByLabel(act, "隐藏日志");
    await waitFor(() => !document.querySelector('[aria-label="网络证据"]') && !document.querySelector('[aria-label="运行日志"]'));
    assert.equal(document.querySelector('[aria-label="网络证据"]'), null);
    assert.equal(document.querySelector('[aria-label="运行日志"]'), null);
    assert.equal(document.querySelector('[aria-label="证据面板已隐藏"]'), null);
    assert.ok(document.querySelector(".device-hub-window.is-evidence-hidden"));
    assert.equal(document.querySelectorAll('button[aria-label="显示网络"]').length, 1);
    assert.equal(document.querySelectorAll('button[aria-label="显示日志"]').length, 1);

    await clickButtonByLabel(act, "显示网络");
    await waitFor(() => networkEvidenceText().includes("/v1/home/feed"));
    assert.equal(document.querySelector('[aria-label="运行日志"]'), null);
    assert.equal(document.querySelectorAll('button[aria-label="隐藏网络"]').length, 1);
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

async function clickTabButton(act, label) {
  const tab = Array.from(document.querySelectorAll(".sidebar-panel-switch button")).find((candidate) =>
    candidate.textContent?.includes(label)
  );
  assert.ok(tab, `Expected to find sidebar tab for ${label}`);
  await act(async () => {
    tab.click();
  });
}

async function clickViewTreeTarget(act, deviceName) {
  const row = Array.from(document.querySelectorAll(".view-tree-target-chip")).find((candidate) =>
    candidate.textContent?.includes(deviceName)
  );
  assert.ok(row, `Expected to find view-tree target chip for ${deviceName}`);
  await act(async () => {
    row.click();
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
    document.querySelector(".toolbar-title span")?.textContent?.trim() === "QA mock fallback" &&
    document.querySelector(".bridge-notice strong")?.textContent?.trim() ===
      "Host bridge 请求失败，正在展示 QA mock fallback" &&
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
  return document.querySelector('[aria-label="网络证据"]')?.textContent ?? "";
}

function logsText() {
  return document.querySelector('[aria-label="运行日志"]')?.textContent ?? "";
}

function viewTreeTitle() {
  return document.querySelector(".view-tree-title strong")?.textContent?.trim();
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

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

const { fetchHostTargets } = await viteServer.ssrLoadModule("/src/data/iosSimulatorClient.ts");

after(async () => {
  await viteServer.close();
});

test("fetchHostTargets prefers target registry, hides host_offline, and keeps real-device runtime_not_found visible", async () => {
  const calls = [];
  const restore = installFetch(async (input, init) => {
    const url = new URL(resolveRequestURL(input), "http://127.0.0.1:34127");
    calls.push({ pathname: url.pathname, method: init?.method ?? "GET" });

    assert.equal(url.pathname, "/web/target-registry");
    return jsonResponse({
      ok: true,
      action: "web.target-registry",
      targets: [
        {
          id: "host:ios:SIM-1",
          platform: "ios",
          kind: "simulator",
          host: {
            target: "SIM-1",
            name: "iPhone 16",
            runtime: "iOS 26.5",
            scope: "simulator",
            kind: "simulator",
            source: "simctl",
            state: "Booted",
            ready: true,
            transport: "simctl",
          },
          runtime: {
            id: "triton:ios-simulator:SIM-1",
            state: "connected",
            transport: "embedded",
            appBundleId: "overloaded.cn.debug",
            capabilities: ["screenshot", "hierarchy"],
          },
          mirror: { state: "ready" },
        },
        {
          id: "ios-real:73f725dfa795",
          platform: "ios",
          kind: "real-device",
          host: {
            target: "ios-real:73f725dfa795",
            name: "Lin iPhone",
            runtime: "iOS 26.5",
            scope: "real",
            kind: "real-device",
            source: "devicectl",
            state: "connected",
            ready: true,
            transport: "wired",
          },
          runtime: null,
          mirror: { state: "runtime_not_found" },
          diagnosis: {
            code: "runtime_not_found",
            message: "Host target is ready but no Debug App runtime is connected.",
            severity: "warning",
          },
          nextAction: {
            code: "start_debug_app",
            title: "启动已集成 TritonKit 的 Debug App",
          },
          transportDiagnostics: [
            {
              code: "ios_usb_tunnel_unavailable",
              message: "No supported iOS USB tunnel adapter was found on PATH.",
              severity: "info",
            },
          ],
        },
        {
          id: "host:ios:OFFLINE-SIM",
          platform: "ios",
          kind: "simulator",
          host: {
            target: "OFFLINE-SIM",
            name: "Offline iPhone",
            runtime: "iOS 26.5",
            scope: "simulator",
            kind: "simulator",
            source: "simctl",
            state: "Shutdown",
            ready: false,
            transport: "simctl",
          },
          runtime: null,
          mirror: { state: "host_offline" },
          diagnosis: {
            code: "host_offline",
            message: "Host target is not online.",
            severity: "info",
          },
        },
      ],
    });
  });

  try {
    const result = await fetchHostTargets();

    assert.deepEqual(calls, [{ pathname: "/web/target-registry", method: "GET" }]);
    assert.deepEqual(result.sourceCommands, ["triton serve /web/target-registry"]);
    assert.equal(result.targets.length, 2);

    const simulator = result.targets.find((target) => target.scope === "simulator");
    assert.equal(simulator.name, "iPhone 16");
    assert.equal(simulator.targetSelector, "SIM-1");
    assert.equal(simulator.status, "ready");
    assert.equal(simulator.canScreenshot, true);
    assert.equal(simulator.screenshotSource, "host");

    const realDevice = result.targets.find((target) => target.scope === "real");
    assert.equal(realDevice.name, "Lin iPhone");
    assert.equal(realDevice.status, "limited");
    assert.equal(realDevice.statusLabel, "runtime_not_found");
    assert.equal(realDevice.transport, "wired");
    assert.equal(realDevice.realSource, "ios-real-device");
    assert.equal(realDevice.canScreenshot, false);
    assert.equal(realDevice.screenshotSource, "runtime");
    assert.match(realDevice.lastAction, /Debug App/);
    assert.ok(realDevice.blockedReasons.some((reason) => reason.includes("runtime_not_found")));
    assert.ok(realDevice.blockedReasons.some((reason) => reason.includes("ios_usb_tunnel_unavailable")));
  } finally {
    restore();
  }
});

test("fetchHostTargets falls back to legacy host-targets when target registry is unavailable", async () => {
  const calls = [];
  const restore = installFetch(async (input, init) => {
    const url = new URL(resolveRequestURL(input), "http://127.0.0.1:34127");
    calls.push({ pathname: url.pathname, method: init?.method ?? "GET" });

    if (url.pathname === "/web/target-registry") {
      return jsonResponse({ ok: false }, 404);
    }

    assert.equal(url.pathname, "/web/host-targets");
    return jsonResponse({
      ok: true,
      capturedAt: "2026-06-23T10:00:00.000Z",
      source: {
        commands: ["triton sim list --json"],
        runtimeScope: "host-device",
        readonly: true,
      },
      targets: [
        {
          id: "host:ios:SIM-1",
          target: "SIM-1",
          name: "iPhone 16",
          platform: "ios",
          appName: "Overloaded",
          bundleIdentifier: "overloaded.cn.debug",
          runtime: "iOS 26.5",
          state: "Booted",
          statusLabel: "Ready",
          ready: true,
          scope: "simulator",
          kind: "simulator",
          source: "simctl",
          readonly: true,
          blockedReasons: [],
        },
      ],
      commandOutputs: [],
    });
  });

  try {
    const result = await fetchHostTargets();

    assert.deepEqual(calls, [
      { pathname: "/web/target-registry", method: "GET" },
      { pathname: "/web/host-targets", method: "GET" },
    ]);
    assert.equal(result.capturedAt, "2026-06-23T10:00:00.000Z");
    assert.deepEqual(result.sourceCommands, ["triton sim list --json"]);
    assert.equal(result.targets[0].name, "iPhone 16");
    assert.equal(result.targets[0].status, "ready");
  } finally {
    restore();
  }
});

function installFetch(handler) {
  const original = globalThis.fetch;
  globalThis.fetch = handler;
  return () => {
    globalThis.fetch = original;
  };
}

function jsonResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function resolveRequestURL(input) {
  if (typeof input === "string") {
    return input;
  }
  if (input instanceof URL) {
    return input.toString();
  }
  return input.url;
}

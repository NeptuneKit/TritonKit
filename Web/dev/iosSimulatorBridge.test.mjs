import assert from "node:assert/strict";
import { chmod, mkdtemp, writeFile } from "node:fs/promises";
import { createServer as createTestHttpServer } from "node:http";
import { join } from "node:path";
import test from "node:test";
import { tmpdir } from "node:os";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { HostBridgeNotice } from "../src/components/HostBridgeNotice.ts";
import { describeHostBridgePresentation } from "../src/data/hostBridgePresentation.ts";
import {
  createIosSimulatorBridgeMiddleware,
  getManagedTritonServeBindHost,
  mapTritonHostCapturesToWebTargets,
  mapTritonDeviceListToWebTargets,
  mapTritonSimListToWebTargets,
} from "./iosSimulatorBridge.mjs";

test("managed Triton serve binds all interfaces for real-device Debug runtime access", () => {
  assert.equal(getManagedTritonServeBindHost(), "0.0.0.0");
});

test("maps triton sim list output into readonly Web iOS targets", () => {
  const result = mapTritonSimListToWebTargets({
    ok: true,
    simulators: [
      {
        id: "sim:AAAA-BBBB",
        udid: "AAAA-BBBB",
        name: "TritonKit Dedicated iPhone 17",
        platform: "iOS Simulator",
        runtime: "iOS 26.5",
        state: "Booted",
        isAvailable: true,
        isBooted: true,
        deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-17",
        runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-26-5",
        source: "simctl",
      },
      {
        id: "sim:CCCC-DDDD",
        udid: "CCCC-DDDD",
        name: "iPad (A16)",
        platform: "iOS Simulator",
        runtime: "iOS 26.5",
        state: "Shutdown",
        isAvailable: true,
        isBooted: false,
        deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPad-A16",
        runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-26-5",
        source: "simctl",
      },
    ],
  });

  assert.equal(result.ok, true);
  assert.equal(result.source.command, "triton sim list --json");
  assert.equal(result.simulators.length, 1);
  assert.equal(result.simulators[0].id, "sim:AAAA-BBBB");
  assert.equal(result.simulators[0].statusLabel, "Booted");
  assert.equal(result.simulators[0].canScreenshot, true);
});

test("rejects malformed triton sim list output", () => {
  assert.throws(
    () => mapTritonSimListToWebTargets({ ok: true, simulators: "not-an-array" }),
    /simulators/
  );
});

test("maps ready emulator targets and visible real devices for Android and Harmony", () => {
  const result = mapTritonDeviceListToWebTargets(
    {
      ok: true,
      targets: [
        {
          id: "android:emulator-5554",
          target: "emulator-5554",
          name: "Pixel API 35",
          platform: "android",
          appName: "Overloaded",
          packageName: "overloaded.cn.debug",
          ready: true,
          scope: "emulator",
          kind: "emulator",
          state: "device",
          source: "adb",
        },
        {
          id: "android:RF8N",
          target: "RF8N",
          ready: true,
          scope: "real",
          kind: "real-device",
          state: "device",
          transport: "usb",
          blockedReasons: [],
        },
        {
          id: "android:emulator-5556",
          target: "emulator-5556",
          ready: false,
          scope: "emulator",
          kind: "emulator",
          state: "offline",
        },
      ],
    },
    "android"
  );

  assert.equal(result.length, 2);
  assert.equal(result[0].id, "android:emulator-5554");
  assert.equal(result[0].platform, "android");
  assert.equal(result[0].appName, "Overloaded");
  assert.equal(result[0].bundleIdentifier, "overloaded.cn.debug");
  assert.equal(result[0].ready, true);
  assert.equal(result[1].id, "android:RF8N");
  assert.equal(result[1].scope, "real");
  assert.equal(result[1].kind, "real-device");
  assert.equal(result[1].ready, true);
  assert.equal(result[1].transport, "usb");
});

test("filters non-ready real devices from the visible device list", () => {
  const result = mapTritonDeviceListToWebTargets(
    {
      ok: true,
      targets: [
        {
          id: "ios:00008140-redacted",
          target: "00008140-redacted",
          name: "Lin iPhone",
          platform: "ios",
          runtime: "iOS 18.5",
          ready: false,
          scope: "real",
          kind: "real-device",
          state: "device_not_trusted",
          source: "devicectl",
          blockedReasons: ["device_not_trusted"],
        },
      ],
    },
    "ios"
  );

  assert.equal(result.length, 0);
});

test("shows ready iOS localNetwork real devices as App runtime mirror candidates", () => {
  const result = mapTritonDeviceListToWebTargets(
    {
      ok: true,
      targets: [
        {
          id: "ios:wireless",
          target: "ios-real:wireless",
          name: "Wireless iPhone",
          platform: "ios",
          runtime: "iOS 27.0",
          ready: true,
          scope: "real",
          kind: "real-device",
          state: "connected",
          source: "devicectl",
          transport: "localNetwork",
        },
      ],
    },
    "ios"
  );

  assert.equal(result.length, 1);
  assert.equal(result[0].source, "runtime");
  assert.equal(result[0].transport, "localNetwork");
});

test("shows iOS localNetwork real device when an App runtime target is connected", () => {
  const result = mapTritonHostCapturesToWebTargets([
    {
      id: "ios-real-command",
      platform: "ios",
      command: "triton device list --platform ios --scope real --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        ok: true,
        targets: [
          {
            id: "ios-real:7a9d976cc4d4",
            target: "ios-real:7a9d976cc4d4",
            name: "iPhone",
            platform: "ios",
            runtime: "iOS 26.5",
            ready: true,
            scope: "real",
            kind: "real-device",
            state: "connected",
            source: "devicectl",
            transport: "localNetwork",
          },
        ],
      },
    },
    {
      id: "runtime-command",
      platform: "runtime",
      command: "triton list --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        targets: [
          {
            id: "triton:connection:7",
            platform: "ios",
            connected: true,
            activeHierarchyAvailable: true,
            transport: "local-websocket",
          },
        ],
      },
    },
  ]);

  assert.equal(result.targets.length, 1);
  assert.equal(result.targets[0].id, "ios-real:7a9d976cc4d4");
  assert.equal(result.targets[0].source, "runtime");
  assert.equal(result.targets[0].transport, "localNetwork");
});

test("keeps host targets ok when optional App runtime target discovery is unavailable", () => {
  const result = mapTritonHostCapturesToWebTargets([
    {
      id: "ios-command",
      platform: "ios",
      command: "triton sim list --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        ok: true,
        simulators: [
          {
            id: "sim:AAAA-BBBB",
            udid: "AAAA-BBBB",
            name: "Overloaded-v2 Dedicated iPhone 16 Pro",
            platform: "iOS Simulator",
            runtime: "iOS 26.5",
            state: "Booted",
            isAvailable: true,
            isBooted: true,
            source: "simctl",
          },
        ],
      },
    },
    {
      id: "runtime-command",
      platform: "runtime",
      command: "triton list --json",
      ok: false,
      exitCode: 1,
      stdout: JSON.stringify({
        ok: false,
        error: {
          code: "server_unavailable",
          message: "Could not connect to the server.",
        },
      }),
      stderr: "",
      parsed: null,
    },
  ]);

  assert.equal(result.ok, true);
  assert.equal(result.targets.length, 1);
  assert.equal(result.targets[0].id, "sim:AAAA-BBBB");
  assert.equal(result.commandOutputs.at(-1).ok, false);
});

test("combines iOS, Android, and Harmony host captures for visible target switching", () => {
  const result = mapTritonHostCapturesToWebTargets([
    {
      id: "ios-command",
      platform: "ios",
      command: "triton sim list --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        ok: true,
        simulators: [
          {
            id: "sim:AAAA-BBBB",
            udid: "AAAA-BBBB",
            name: "iPhone 15 Pro",
            platform: "iOS Simulator",
            runtime: "iOS 18.5",
            state: "Booted",
            isAvailable: true,
            isBooted: true,
            source: "simctl",
          },
        ],
      },
    },
    {
      id: "ios-real-command",
      platform: "ios",
      command: "triton device list --platform ios --scope real --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        ok: true,
        targets: [
          {
            id: "ios:00008140-redacted",
            target: "00008140-redacted",
            name: "Lin iPhone",
            runtime: "iOS 18.5",
            ready: true,
            scope: "real",
            kind: "real-device",
            state: "Ready",
            source: "devicectl",
            transport: "wired",
          },
        ],
      },
    },
    {
      id: "android-command",
      platform: "android",
      command: "triton device list --platform android --scope emulator --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        ok: true,
        targets: [
          {
            id: "android:emulator-5554",
            target: "emulator-5554",
            name: "Pixel API 35",
            appName: "Overloaded",
            packageName: "overloaded.cn.debug",
            runtime: "Android 15",
            ready: true,
            scope: "emulator",
            kind: "emulator",
            state: "device",
          },
        ],
      },
    },
    {
      id: "harmony-command",
      platform: "harmony",
      command: "triton device list --platform harmony --scope emulator --json",
      ok: true,
      exitCode: 0,
      stdout: "",
      stderr: "",
      parsed: {
        ok: true,
        targets: [
          {
            id: "harmony:127.0.0.1:5555",
            target: "127.0.0.1:5555",
            name: "DevEco Local",
            appName: "Triton Smoke",
            bundleIdentifier: "com.tritonkit.demo",
            runtime: "HarmonyOS NEXT",
            ready: true,
            scope: "emulator",
            kind: "emulator",
            state: "Ready",
          },
        ],
      },
    },
  ]);

  assert.equal(result.ok, true);
  assert.deepEqual(result.source.commands, [
    "triton sim list --json",
    "triton device list --platform ios --scope real --json",
    "triton device list --platform android --scope emulator --json",
    "triton device list --platform harmony --scope emulator --json",
  ]);
  assert.deepEqual(
    result.targets.map((target) => `${target.platform}:${target.name}:${target.bundleIdentifier ?? target.target}`),
    [
      "ios:iPhone 15 Pro:AAAA-BBBB",
      "ios:Lin iPhone:00008140-redacted",
      "android:Pixel API 35:overloaded.cn.debug",
      "harmony:DevEco Local:com.tritonkit.demo",
    ]
  );
});

test("surfaces QA mock fallback when host bridge succeeds but returns no targets", () => {
  const result = describeHostBridgePresentation(
    {
      loading: false,
      capturedAt: "2026-06-13T10:00:00.000Z",
      sourceCommands: [
        "triton sim list --json",
        "triton device list --platform android --json",
        "triton device list --platform harmony --json",
      ],
    },
    0
  );

  assert.equal(result.toolbarLabel, "No host targets");
  assert.equal(result.notice?.tone, "warning");
  assert.equal(result.notice?.title, "当前没有可用 host target");
  assert.match(result.notice?.detail ?? "", /targets 为空/);
  assert.match(result.notice?.detail ?? "", /triton sim list --json/);
});

test("surfaces QA mock fallback when host bridge request fails", () => {
  const result = describeHostBridgePresentation(
    {
      loading: false,
      error: "Host targets request failed: 502",
      sourceCommands: [],
    },
    0
  );

  assert.equal(result.toolbarLabel, "Host bridge unavailable");
  assert.equal(result.notice?.tone, "error");
  assert.equal(result.notice?.title, "Host bridge 请求失败");
  assert.equal(result.notice?.detail, "Host targets request failed: 502");
});

test("server-renders warning fallback notice markup for readonly host bridge", () => {
  const presentation = describeHostBridgePresentation(
    {
      loading: false,
      capturedAt: "2026-06-13T10:00:00.000Z",
      sourceCommands: ["triton sim list --json"],
    },
    0
  );

  assert.ok(presentation.notice);

  const markup = renderToStaticMarkup(createElement(HostBridgeNotice, { notice: presentation.notice }));

  assert.match(markup, /class="bridge-notice is-warning"/);
  assert.match(markup, /role="status"/);
  assert.match(markup, /aria-label="Host bridge 状态"/);
  assert.match(markup, /<strong>当前没有可用 host target<\/strong>/);
  assert.match(markup, /<span>只读 host bridge 已成功返回，但 targets 为空。来源：triton sim list --json<\/span>/);
});

test("server-renders error fallback notice markup when host bridge request fails", () => {
  const presentation = describeHostBridgePresentation(
    {
      loading: false,
      error: "Host targets request failed: 502",
      sourceCommands: [],
    },
    0
  );

  assert.ok(presentation.notice);

  const markup = renderToStaticMarkup(createElement(HostBridgeNotice, { notice: presentation.notice }));

  assert.match(markup, /class="bridge-notice is-error"/);
  assert.match(markup, /<strong>Host bridge 请求失败<\/strong>/);
  assert.match(markup, /<span>Host targets request failed: 502<\/span>/);
});

test("dispatches iOS real-device Web input through App runtime", async () => {
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({
    targets: [
      {
        id: "triton:connection:2",
        platform: "ios",
        connected: true,
        deviceDescription: "iPhone",
        transport: "local-websocket",
      },
      {
        id: "triton:ios-simulator:SIM-UDID",
        platform: "ios",
        connected: true,
        simulatorUDID: "SIM-UDID",
        deviceDescription: "Simulator",
        transport: "local-websocket",
      },
    ],
  }));
  process.exit(0);
}
if (args.join(" ") !== "input --target triton:connection:2 --json --summary") {
  process.stderr.write("unexpected args: " + args.join(" "));
  process.exit(64);
}
process.stdin.resume();
process.stdin.on("end", () => {
  process.stdout.write(JSON.stringify({ ok: true, action: "tap", message: "Tapped through runtime" }));
});
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/host-input?platform=ios&target=ios-real%3Aabc&scope=real&kind=real-device&source=runtime",
    body: JSON.stringify({ type: "tap", x: 20, y: 40 }),
  });

  assert.equal(response.statusCode, 200);
  assert.match(response.headers["content-type"], /application\/json/);
  assert.deepEqual(JSON.parse(response.body), {
    ok: true,
    action: "tap",
    message: "Tapped through runtime",
  });
});

test("proxies iOS Simulator Web input through triton serve host target route", async () => {
  const received = [];
  const server = await createFakeHostInputServer(received, {
    ok: true,
    action: "tap",
    message: "iOS Simulator tap was submitted through Triton host-HID adapter.",
  });
  const middleware = createIosSimulatorBridgeMiddleware({
    tritonPath: process.execPath,
    hostInputBaseURL: server.baseURL,
  });

  try {
    const response = await invokeMiddleware(middleware, {
      method: "POST",
      url: "/web/host-input?platform=ios&target=AAAA-BBBB&scope=simulator&kind=simulator&source=host",
      body: JSON.stringify({ type: "tap", x: 180, y: 410, width: 390, height: 844 }),
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(JSON.parse(response.body), {
      ok: true,
      action: "tap",
      message: "iOS Simulator tap was submitted through Triton host-HID adapter.",
    });
    assert.deepEqual(received, [
      {
        method: "POST",
        pathname: "/web/input",
        target: "host:ios:AAAA-BBBB",
        body: { type: "tap", x: 180, y: 410, width: 390, height: 844 },
      },
    ]);
  } finally {
    await server.close();
  }
});

test("target registry route reuses managed Triton serve after readiness probe", async () => {
  const received = [];
  const server = await createFakeHostInputServer(received, {
    ok: true,
    action: "web.target-registry",
    targets: [],
  });
  const middleware = createIosSimulatorBridgeMiddleware({
    tritonPath: process.execPath,
    hostInputBaseURL: server.baseURL,
  });

  try {
    const response = await invokeMiddleware(middleware, {
      method: "GET",
      url: "/web/target-registry",
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(JSON.parse(response.body), {
      ok: true,
      action: "web.target-registry",
      targets: [],
    });
    assert.deepEqual(received, [
      {
        method: "GET",
        pathname: "/health",
        target: null,
        body: {},
      },
      {
        method: "GET",
        pathname: "/web/target-registry",
        target: null,
        body: {},
      },
    ]);
  } finally {
    await server.close();
  }
});

test("dispatches iOS Simulator runtime long press through matched App runtime", async () => {
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({
    targets: [
      {
        id: "triton:connection:2",
        platform: "ios",
        connected: true,
        deviceDescription: "iPhone",
        transport: "local-websocket"
      },
      {
        id: "triton:ios-simulator:SIM-UDID",
        platform: "ios",
        connected: true,
        simulatorUDID: "SIM-UDID",
        deviceDescription: "Simulator",
        transport: "local-websocket"
      }
    ]
  }));
  process.exit(0);
}
if (args.join(" ") !== "input --target triton:ios-simulator:SIM-UDID --json --summary") {
  process.stderr.write("unexpected args: " + args.join(" "));
  process.exit(64);
}
let body = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => { body += chunk; });
process.stdin.on("end", () => {
  const request = JSON.parse(body);
  process.stdout.write(JSON.stringify({
    ok: true,
    action: request.type,
    message: "Long press through runtime"
  }));
});
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/host-input?platform=ios&target=SIM-UDID&scope=simulator&kind=simulator&source=runtime",
    body: JSON.stringify({ type: "longPress", x: 20, y: 40, width: 390, height: 844, duration: 0.52 }),
  });

  assert.equal(response.statusCode, 200);
  assert.deepEqual(JSON.parse(response.body), {
    ok: true,
    action: "longPress",
    message: "Long press through runtime",
  });
});

test("captures iOS real-device Web screenshot from App runtime mirror", async () => {
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
import { writeFileSync } from "node:fs";

const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({
    targets: [
      {
        id: "triton:connection:2",
        platform: "ios",
        connected: true,
        deviceDescription: "iPhone",
        transport: "local-websocket",
      },
      {
        id: "triton:ios-simulator:SIM-UDID",
        platform: "ios",
        connected: true,
        simulatorUDID: "SIM-UDID",
        deviceDescription: "Simulator",
        transport: "local-websocket",
      },
    ],
  }));
  process.exit(0);
}

const artifactIndex = args.indexOf("--output");
if (artifactIndex >= 0) {
  writeFileSync(args[artifactIndex + 1], Buffer.from(${JSON.stringify(Buffer.from(pngBytes(12, 8)).toString("base64"))}, "base64"));
}

process.stdout.write(JSON.stringify({
  ok: true,
  format: "png",
  width: 12,
  height: 8,
  scale: 1,
  output: args[artifactIndex + 1],
  bytes: 24,
}));
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "GET",
    url: "/web/host-screenshot?platform=ios&target=ios-real%3Aabc&scope=real&kind=real-device&source=runtime",
  });

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, true);
  assert.equal(body.source.runtimeScope, "app-runtime");
  assert.match(body.source.command, /^triton screenshot --target triton:connection:2 --output /);
  assert.equal(body.pixelWidth, 12);
  assert.equal(body.pixelHeight, 8);
  assert.match(body.dataUrl, /^data:image\/png;base64,/);
});

test("rejects iOS real-device screenshot when only simulator runtime is connected", async () => {
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({
    targets: [
      {
        id: "triton:ios-simulator:SIM-UDID",
        platform: "ios",
        connected: true,
        simulatorUDID: "SIM-UDID",
        activeHierarchyAvailable: true
      }
    ]
  }));
  process.exit(0);
}
process.stderr.write("unexpected args: " + args.join(" "));
process.exit(64);
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "GET",
    url: "/web/host-screenshot?platform=ios&target=ios-real%3A7a9d976cc4d4&scope=real&kind=real-device&source=runtime",
  });

  assert.equal(response.statusCode, 409);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, false);
  assert.equal(body.error.code, "app_runtime_unavailable");
  assert.match(body.error.message, /No connected iOS real-device App runtime target matched host target ios-real:7a9d976cc4d4/);
  assert.match(body.error.message, /triton:ios-simulator:SIM-UDID/);
});

test("forces /web/host-targets failure for dev browser fallback smoke", async () => {
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath: process.execPath });
  const response = await invokeMiddleware(middleware, {
    method: "GET",
    url: "/web/host-targets?__tritonkit_mock_host_targets=request-failed",
  });

  assert.equal(response.statusCode, 502);
  assert.match(response.headers["content-type"], /application\/json/);
  assert.deepEqual(JSON.parse(response.body), {
    ok: false,
    error: {
      code: "web_host_targets_forced_failure",
      message: "Forced /web/host-targets failure for dev browser smoke.",
    },
  });
});

test("serves readonly Lookin-style hierarchy scenes for iOS Android and Harmony host targets", async () => {
  const cases = [
    ["ios", "AAAA-BBBB", "UIStackView", "questionList"],
    ["android", "emulator-5554", "AndroidComposeView", "settingsList"],
    ["harmony", "127.0.0.1:5555", "ArkUIRoot", "settingsContent"],
  ];

  for (const [platform, target, type, name] of cases) {
    const tritonPath = await createFakeTritonScript({
      stdout: JSON.stringify({
        ok: true,
        capturedAt: "2026-06-19T00:00:00.000Z",
        source: {
          command: `triton debug hierarchy --platform ${platform} --target ${target} --json`,
          runtimeScope: platform === "ios" ? "runtime-tree" : "host-layout",
          readonly: true,
        },
        scene: {
          platform,
          rootId: "root",
          viewport: { width: 390, height: 844 },
          nodes: [
            {
              id: "root",
              type: "RootView",
              name: "root",
              frame: { x: 0, y: 0, width: 390, height: 844 },
              depth: 0,
              visible: true,
              interactive: false,
              color: "#6ea8ff",
            },
            {
              id: "child",
              parentId: "root",
              type,
              name,
              frame: { x: 24, y: 120, width: 342, height: 56 },
              depth: 1,
              visible: true,
              interactive: true,
              color: "#fb7185",
            },
          ],
        },
      }),
      outputTemplate: "unused",
    });
    const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
    const response = await invokeMiddleware(middleware, {
      method: "GET",
      url: `/web/host-hierarchy?platform=${platform}&target=${encodeURIComponent(target)}`,
    });

    assert.equal(response.statusCode, 200);
    assert.match(response.headers["content-type"], /application\/json/);

    const body = JSON.parse(response.body);
    assert.equal(body.ok, true);
    assert.equal(body.source.command, `triton debug hierarchy --platform ${platform} --target ${target} --json`);
    assert.equal(body.source.runtimeScope, platform === "ios" ? "runtime-tree" : "host-layout");
    assert.equal(body.source.readonly, true);
    assert.equal(body.scene.platform, platform);
    assert.ok(body.scene.viewport.width > 0);
    assert.ok(body.scene.viewport.height > 0);
    assert.ok(body.scene.nodes.some((node) => node.type === type));
    assert.ok(body.scene.nodes.some((node) => node.name === name));
  }
});

test("resolves bare iOS real-device hierarchy target through App runtime mirror", async () => {
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({
    targets: [
      {
        id: "triton:connection:42",
        platform: "ios",
        connected: true,
        deviceDescription: "iPhone",
        transport: "local-websocket"
      },
      {
        id: "triton:ios-simulator:SIM-UDID",
        platform: "ios",
        connected: true,
        simulatorUDID: "SIM-UDID",
        deviceDescription: "Simulator",
        transport: "local-websocket"
      }
    ]
  }));
  process.exit(0);
}
if (args.join(" ") !== "debug hierarchy --platform ios --target triton:connection:42 --json") {
  process.stderr.write("unexpected args: " + args.join(" "));
  process.exit(64);
}
process.stdout.write(JSON.stringify({
  ok: true,
  capturedAt: "2026-06-19T00:00:00.000Z",
  source: {
    command: "triton debug hierarchy --platform ios --target triton:connection:42 --json",
    runtimeScope: "runtime-tree",
    readonly: true
  },
  scene: {
    platform: "ios",
    rootId: "root",
    viewport: { width: 428, height: 926 },
    nodes: [
      {
        id: "root",
        type: "UIWindow",
        name: "keyWindow",
        frame: { x: 0, y: 0, width: 428, height: 926 },
        depth: 0,
        visible: true,
        interactive: false,
        color: "#6ea8ff"
      }
    ]
  }
}));
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "GET",
    url: "/web/host-hierarchy?platform=ios&target=ios-real%3A7a9d976cc4d4",
  });

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, true);
  assert.equal(body.source.command, "triton debug hierarchy --platform ios --target triton:connection:42 --json");
  assert.equal(body.scene.viewport.width, 428);
});

test("rejects iOS real-device hierarchy when only simulator runtime is connected", async () => {
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({
    targets: [
      {
        id: "triton:ios-simulator:SIM-UDID",
        platform: "ios",
        connected: true,
        simulatorUDID: "SIM-UDID",
        activeHierarchyAvailable: true,
        appName: "Overloaded",
        bundleIdentifier: "overloaded.cn.debug",
        transport: "local-websocket"
      }
    ]
  }));
  process.exit(0);
}
process.stderr.write("unexpected args: " + args.join(" "));
process.exit(64);
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "GET",
    url: "/web/host-hierarchy?platform=ios&target=ios-real%3A7a9d976cc4d4&scope=real&kind=real-device&source=runtime",
  });

  assert.equal(response.statusCode, 409);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, false);
  assert.equal(body.error.code, "app_runtime_unavailable");
  assert.match(body.error.message, /No connected iOS real-device App runtime target matched host target ios-real:7a9d976cc4d4/);
  assert.match(body.error.message, /triton:ios-simulator:SIM-UDID/);
});

test("exposes explicit Web hierarchy capture control through POST without mutating the app", async () => {
  const tritonPath = await createFakeTritonScript({
    stdout: JSON.stringify({
      ok: true,
      capturedAt: "2026-06-19T00:00:00.000Z",
      source: {
        command: "triton debug hierarchy --platform ios --target AAAA-BBBB --json",
        runtimeScope: "runtime-tree",
        readonly: true,
      },
      scene: {
        platform: "ios",
        rootId: "root",
        viewport: { width: 390, height: 844 },
        nodes: [
          {
            id: "root",
            type: "UIWindow",
            name: "keyWindow",
            frame: { x: 0, y: 0, width: 390, height: 844 },
            depth: 0,
            visible: true,
            interactive: false,
            color: "#6ea8ff",
          },
        ],
      },
    }),
    outputTemplate: "unused",
  });
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB",
  });

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, true);
  assert.deepEqual(body.control, {
    action: "hierarchy.capture",
    entrypoint: "web-dev-bridge",
    method: "POST",
    readonly: true,
    mutatesApp: false,
  });
  assert.equal(body.source.command, "triton debug hierarchy --platform ios --target AAAA-BBBB --json");
});

test("hydrates platform hierarchy scene dataRef slices into data URLs", async () => {
  const nodePng = pngBytes(10, 6);
  const dataServer = await createFakeRuntimeDataServer({
    "22222222-2222-2222-2222-222222222222": nodePng,
  });
  try {
    const tritonPath = await createFakeTritonScript({
      stdout: JSON.stringify({
        ok: true,
        capturedAt: "2026-06-19T01:00:00Z",
        source: {
          command: "triton debug hierarchy --platform ios --target AAAA-BBBB --json",
          runtimeScope: "runtime-tree",
          readonly: true,
        },
        scene: {
          platform: "ios",
          rootId: "root",
          viewport: { width: 390, height: 844 },
          nodes: [
            {
              id: "root",
              type: "UIWindow",
              name: "keyWindow",
              frame: { x: 0, y: 0, width: 390, height: 844 },
              depth: 0,
              visible: true,
              interactive: false,
              color: "#6ea8ff",
            },
            {
              id: "button",
              parentId: "root",
              type: "UIButton",
              name: "Continue",
              frame: { x: 24, y: 132, width: 342, height: 58 },
              depth: 1,
              visible: true,
              interactive: true,
              color: "#2563eb",
              slice: {
                available: true,
                mode: "node-screenshot-ref",
                source: "triton-runtime-data-ref",
                dataRef: "22222222-2222-2222-2222-222222222222",
              },
              renderHints: {
                preferredMode: "slice",
                fallbackMode: "style",
                quality: "exact",
              },
            },
          ],
        },
      }),
      outputTemplate: "unused",
    });
    const middleware = createIosSimulatorBridgeMiddleware({
      tritonPath,
      runtimeDataBaseURL: dataServer.baseURL,
    });
    const response = await invokeMiddleware(middleware, {
      method: "POST",
      url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB",
    });

    assert.equal(response.statusCode, 200);
    const body = JSON.parse(response.body);
    const button = body.scene.nodes.find((node) => node.id === "button");
    assert.equal(button.slice.dataRef, "22222222-2222-2222-2222-222222222222");
    assert.equal(button.slice.dataUrl, `data:image/png;base64,${nodePng.toString("base64")}`);
    assert.equal(button.visualSources[0].kind, "subtreeSnapshot");
    assert.equal(button.visualSources[0].dataRef, "22222222-2222-2222-2222-222222222222");
    assert.equal(button.visualSources[0].dataUrl, `data:image/png;base64,${nodePng.toString("base64")}`);
    assert.equal(button.visualSources[0].capturedBy, "UIView.render");
    assert.equal(button.renderHints.preferredMode, "slice");
    assert.equal(button.renderHints.quality, "exact");
    assert.equal(body.captureEvidence.source.kind, "triton-hierarchy");
    assert.equal(body.captureEvidence.source.nodeSlice, "real");
    assert.equal(body.captureEvidence.source.screenshotSlice, "real");
    assert.equal(body.captureEvidence.hydration.dataUrlCount, 1);
    assert.equal(body.captureEvidence.hydration.nodeCount, 2);
    assert.equal(body.captureEvidence.hydration.failedNodeCount, 0);
  } finally {
    await dataServer.close();
  }
});

test("falls back to legacy iOS runtime hierarchy and converts it to a Web scene when platform scene schema is unavailable", async () => {
  const legacyPayload = {
    appInfo: {
      appName: "Overloaded",
      screenWidth: 402,
      screenHeight: 874,
    },
    displayItems: [
      {
        indentLevel: 0,
        frame: [[0, 0], [402, 874]],
        alpha: 1,
        isHidden: false,
        backgroundColor: { red: 1, green: 1, blue: 1, alpha: 1 },
        layerObject: { oid: 2, classChainList: ["UIWindow", "UIView"] },
        subitems: [
          {
            indentLevel: 1,
            frame: [[0, 106], [402, 685]],
            alpha: 1,
            isHidden: false,
            backgroundColor: { red: 0.96, green: 0.96, blue: 0.96, alpha: 1 },
            layerObject: { oid: 26, classChainList: ["SectionUI.SKCollectionView", "UICollectionView"] },
            hostViewControllerObject: { oid: 88, classChainList: ["Demo.ProfileViewController", "UIViewController"] },
            subitems: [
              {
                indentLevel: 2,
                frame: [[24, 132], [342, 58]],
                alpha: 1,
                isHidden: false,
                layerObject: { oid: 38, classChainList: ["UILabel", "UIView"] },
                subitems: [],
              },
            ],
          },
        ],
      },
    ],
  };
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
if (process.argv.includes("--platform")) {
  process.stderr.write("Error: Unknown option '--platform'\\n");
  process.exit(64);
}
process.stdout.write(${JSON.stringify(JSON.stringify(legacyPayload))});
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB",
  });

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, true);
  assert.equal(body.source.command, "triton debug hierarchy --target AAAA-BBBB --json");
  assert.equal(body.source.runtimeScope, "runtime-tree");
  assert.equal(body.scene.platform, "ios");
  assert.equal(body.scene.viewport.width, 402);
  assert.equal(body.scene.viewport.height, 874);
  const controller = body.scene.nodes.find((node) => node.id === "ios:controller:88");
  assert.ok(controller);
  assert.equal(controller.type, "Demo.ProfileViewController");
  assert.equal(controller.name, "ProfileViewController#88");
  assert.equal(controller.raw.role, "UIViewController");
  assert.equal(controller.renderHints.preferredMode, "structure");
  const collection = body.scene.nodes.find((node) => node.type === "SectionUI.SKCollectionView");
  assert.equal(collection.parentId, controller.id);
  assert.equal(body.scene.controllerContext.activeControllerId, "ios:controller:88");
  assert.equal(body.scene.controllerContext.activeControllerName, "ProfileViewController");
  assert.equal(body.scene.controllerContext.source, "scene-controller-node-fallback");
  assert.ok(body.scene.nodes.some((node) => node.type === "SectionUI.SKCollectionView"));
  assert.ok(body.scene.nodes.some((node) => node.type === "UILabel" && node.renderHints.preferredMode === "slice"));
});

test("falls back to legacy iOS runtime hierarchy when scene mode cannot resolve a simulator UDID target", async () => {
  const legacyPayload = {
    appInfo: { screenWidth: 402, screenHeight: 874 },
    displayItems: [
      {
        indentLevel: 0,
        frame: [[0, 0], [402, 874]],
        alpha: 1,
        isHidden: false,
        layerObject: { oid: 2, classChainList: ["UIWindow", "UIView"] },
        subitems: [
          {
            indentLevel: 1,
            frame: [[24, 132], [342, 58]],
            alpha: 1,
            isHidden: false,
            layerObject: { oid: 38, classChainList: ["UILabel", "UIView"] },
            subitems: [],
          },
        ],
      },
    ],
  };
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
if (process.argv.includes("--platform")) {
  process.stdout.write(JSON.stringify({ ok: false, error: { code: "target_not_found", message: "Target not found: AAAA-BBBB" } }));
  process.exit(1);
}
process.stdout.write(${JSON.stringify(JSON.stringify(legacyPayload))});
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB",
  });

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, true);
  assert.equal(body.source.command, "triton debug hierarchy --target AAAA-BBBB --json");
  assert.ok(body.scene.nodes.some((node) => node.type === "UILabel"));
});

test("hydrates legacy iOS screenshotRef into hierarchy node slice data URLs", async () => {
  const nodePng = pngBytes(12, 8);
  const dataServer = await createFakeRuntimeDataServer({
    "11111111-1111-1111-1111-111111111111": nodePng,
  });
  try {
    const legacyPayload = {
      appInfo: { screenWidth: 402, screenHeight: 874 },
      displayItems: [
        {
          indentLevel: 0,
          frame: [[0, 0], [402, 874]],
          alpha: 1,
          isHidden: false,
          layerObject: { oid: 2, classChainList: ["UIWindow", "UIView"] },
          subitems: [
            {
              indentLevel: 1,
              frame: [[24, 132], [342, 58]],
              alpha: 1,
              isHidden: false,
              customDisplayTitle: "Continue",
              screenshotRef: "11111111-1111-1111-1111-111111111111",
              backgroundColor: { red: 0.1, green: 0.2, blue: 0.3, alpha: 1 },
              layerObject: { oid: 38, classChainList: ["UIButtonLabel", "UILabel", "UIView"] },
              subitems: [],
            },
          ],
        },
      ],
    };
    const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
if (process.argv.includes("--platform")) {
  process.stderr.write("Error: Unknown option '--platform'\\n");
  process.exit(64);
}
process.stdout.write(${JSON.stringify(JSON.stringify(legacyPayload))});
`);
    const middleware = createIosSimulatorBridgeMiddleware({
      tritonPath,
      runtimeDataBaseURL: dataServer.baseURL,
    });
    const response = await invokeMiddleware(middleware, {
      method: "POST",
      url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB",
    });

    assert.equal(response.statusCode, 200);
    const body = JSON.parse(response.body);
    const button = body.scene.nodes.find((node) => node.type === "UIButtonLabel");
    assert.ok(button);
    assert.equal(button.name, "Continue");
    assert.equal(button.style.text, "Continue");
    assert.deepEqual(button.slice, {
      available: true,
      mode: "node-screenshot-ref",
      source: "triton-runtime-data-ref",
      dataRef: "11111111-1111-1111-1111-111111111111",
      dataUrl: `data:image/png;base64,${nodePng.toString("base64")}`,
    });
    assert.equal(button.visualSources[0].kind, "subtreeSnapshot");
    assert.equal(button.visualSources[0].dataRef, "11111111-1111-1111-1111-111111111111");
    assert.equal(button.visualSources[0].dataUrl, `data:image/png;base64,${nodePng.toString("base64")}`);
    assert.equal(button.visualSources[0].capturedBy, "UIView.render");
    assert.equal(button.renderHints.preferredMode, "slice");
    assert.equal(button.renderHints.quality, "exact");
  } finally {
    await dataServer.close();
  }
});

test("rejects unsupported /web/host-hierarchy platform with readonly unsupported envelope", async () => {
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath: process.execPath });
  const response = await invokeMiddleware(middleware, {
    method: "GET",
    url: "/web/host-hierarchy?platform=webos&target=local",
  });

  assert.equal(response.statusCode, 501);
  assert.match(response.headers["content-type"], /application\/json/);
  assert.deepEqual(JSON.parse(response.body), {
    ok: false,
    error: {
      code: "web_host_hierarchy_platform_not_supported",
      message: "Readonly host hierarchy is not available for platform: webos",
    },
  });
});

test("captures bounded iOS host logs through /web/host-logs", async () => {
  const tritonPath = await createFakeTritonScript({
    stdout: JSON.stringify({
      ok: true,
      action: "sim.logs",
      runtimeScope: "host-simulator",
      target: "sim:AAAA-BBBB",
      tool: "xcrun",
      exitCode: 0,
      riskLevel: "evidence",
      sourceCommand: "triton sim logs --simulator AAAA-BBBB --output /tmp/fake.ndjson --duration 2 --style ndjson --json",
      artifact: "__OUTPUT__",
      stdoutBytes: 231,
      stderrBytes: 0,
      stdoutTruncated: false,
      stderrTruncated: false,
      note: "Bounded simulator log stream was written.",
    }),
    outputTemplate:
      '{"timestamp":"2026-06-15T10:41:29Z","messageType":"Info","eventMessage":"App launched"}\n' +
      '{"timestamp":"2026-06-15T10:41:31Z","messageType":"Error","eventMessage":"Network timeout"}\n',
  });
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "GET",
    url: "/web/host-logs?platform=ios&target=AAAA-BBBB",
  });

  assert.equal(response.statusCode, 200);
  assert.match(response.headers["content-type"], /application\/json/);
  assert.deepEqual(JSON.parse(response.body), {
    ok: true,
    capturedAt: "2026-06-15T10:41:31.000Z",
    source: {
      command: "triton sim logs --simulator AAAA-BBBB --output <tmp.ndjson> --duration 2 --style ndjson --json",
      runtimeScope: "host-simulator",
      readonly: true,
    },
    entries: [
      {
        id: "host-log-0",
        time: "10:41:29",
        level: "info",
        message: "App launched",
      },
      {
        id: "host-log-1",
        time: "10:41:31",
        level: "error",
        message: "Network timeout",
      },
    ],
  });
});

test("rejects non-iOS /web/host-logs requests with readonly unsupported envelope", async () => {
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath: process.execPath });
  const response = await invokeMiddleware(middleware, {
    method: "GET",
    url: "/web/host-logs?platform=android&target=emulator-5554",
  });

  assert.equal(response.statusCode, 501);
  assert.match(response.headers["content-type"], /application\/json/);
  assert.deepEqual(JSON.parse(response.body), {
    ok: false,
    error: {
      code: "web_host_logs_platform_not_supported",
      message: "Readonly host logs are currently only exposed for iOS Simulator targets.",
    },
  });
});

function invokeMiddleware(middleware, request) {
  return new Promise((resolveResponse, reject) => {
    const response = {
      statusCode: 200,
      headers: {},
      setHeader(name, value) {
        this.headers[name.toLowerCase()] = value;
      },
      end(body) {
        resolveResponse({
          statusCode: this.statusCode,
          headers: this.headers,
          body: String(body ?? ""),
        });
      },
    };

    Promise.resolve(
      middleware(
        {
          method: request.method,
          url: request.url,
          on(event, callback) {
            if (event === "data" && request.body) {
              callback(Buffer.from(request.body));
            }
            if (event === "end") {
              queueMicrotask(callback);
            }
            return this;
          },
        },
        response,
        () => reject(new Error("readonly host input route should not call next()"))
      )
    ).catch(reject);
  });
}

function createFakeHostInputServer(received, responseBody) {
  return new Promise((resolve, reject) => {
    const server = createTestHttpServer((req, res) => {
      const url = new URL(req.url ?? "/", "http://127.0.0.1");
      let body = "";
      req.on("data", (chunk) => {
        body += chunk;
      });
      req.on("end", () => {
        received.push({
          method: req.method,
          pathname: url.pathname,
          target: url.searchParams.get("target"),
          body: JSON.parse(body || "{}"),
        });
        res.statusCode = 200;
        res.setHeader("content-type", "application/json");
        res.end(JSON.stringify(responseBody));
      });
    });
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      resolve({
        baseURL: `http://127.0.0.1:${address.port}`,
        close: () => new Promise((resolveClose, rejectClose) => server.close((error) => error ? rejectClose(error) : resolveClose())),
      });
    });
  });
}

function createFakeRuntimeDataServer(refs) {
  return new Promise((resolve, reject) => {
    const server = createTestHttpServer((req, res) => {
      const url = new URL(req.url ?? "/", "http://127.0.0.1");
      const ref = decodeURIComponent(url.pathname.replace(/^\/data\//, ""));
      const data = refs[ref];
      if (!data) {
        res.statusCode = 404;
        res.end();
        return;
      }
      res.statusCode = 200;
      res.setHeader("content-type", "image/png");
      res.end(data);
    });
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      resolve({
        baseURL: `http://127.0.0.1:${address.port}`,
        close: () => new Promise((resolveClose, rejectClose) => server.close((error) => error ? rejectClose(error) : resolveClose())),
      });
    });
  });
}

async function createFakeTritonScript({ stdout, outputTemplate }) {
  const directory = await mkdtemp(join(tmpdir(), "tritonkit-web-bridge-test-"));
  const scriptPath = join(directory, "fake-triton.mjs");
  const script = `#!/usr/bin/env node
import { writeFileSync } from "node:fs";

const artifactIndex = process.argv.indexOf("--output");
if (artifactIndex >= 0) {
  const outputPath = process.argv[artifactIndex + 1];
  if (outputPath) {
    writeFileSync(outputPath, Buffer.from(${JSON.stringify(Buffer.from(outputTemplate).toString("base64"))}, "base64"));
  }
}

const payload = JSON.parse(${JSON.stringify(stdout)});
if (artifactIndex >= 0) {
  payload.artifact = process.argv[artifactIndex + 1];
}
process.stdout.write(JSON.stringify(payload));
`;
  await writeFile(scriptPath, script, "utf8");
  await chmod(scriptPath, 0o755);
  return scriptPath;
}

async function createFakeTritonScriptFromSource(script) {
  const directory = await mkdtemp(join(tmpdir(), "tritonkit-web-bridge-test-"));
  const scriptPath = join(directory, "fake-triton.mjs");
  await writeFile(scriptPath, script, "utf8");
  await chmod(scriptPath, 0o755);
  return scriptPath;
}

function pngBytes(width, height) {
  const buffer = Buffer.alloc(24);
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(buffer, 0);
  buffer.writeUInt32BE(width, 16);
  buffer.writeUInt32BE(height, 20);
  return buffer;
}

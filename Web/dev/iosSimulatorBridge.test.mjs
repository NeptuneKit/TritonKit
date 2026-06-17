import assert from "node:assert/strict";
import { chmod, mkdtemp, writeFile } from "node:fs/promises";
import { join } from "node:path";
import test from "node:test";
import { tmpdir } from "node:os";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { HostBridgeNotice } from "../src/components/HostBridgeNotice.ts";
import { describeHostBridgePresentation } from "../src/data/hostBridgePresentation.ts";
import {
  createIosSimulatorBridgeMiddleware,
  mapTritonHostCapturesToWebTargets,
  mapTritonDeviceListToWebTargets,
  mapTritonSimListToWebTargets,
} from "./iosSimulatorBridge.mjs";

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

test("maps only ready emulator targets for Android and Harmony", () => {
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

  assert.equal(result.length, 1);
  assert.equal(result[0].id, "android:emulator-5554");
  assert.equal(result[0].platform, "android");
  assert.equal(result[0].appName, "Overloaded");
  assert.equal(result[0].bundleIdentifier, "overloaded.cn.debug");
  assert.equal(result[0].ready, true);
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
      id: "android-command",
      platform: "android",
      command: "triton device list --platform android --json",
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
      command: "triton device list --platform harmony --json",
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
    "triton device list --platform android --json",
    "triton device list --platform harmony --json",
  ]);
  assert.deepEqual(
    result.targets.map((target) => `${target.platform}:${target.name}:${target.bundleIdentifier ?? target.target}`),
    [
      "ios:iPhone 15 Pro:AAAA-BBBB",
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

  assert.equal(result.toolbarLabel, "QA mock fallback");
  assert.equal(result.notice?.tone, "warning");
  assert.equal(result.notice?.title, "当前没有可用 host target，正在展示 QA mock fallback");
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

  assert.equal(result.toolbarLabel, "QA mock fallback");
  assert.equal(result.notice?.tone, "error");
  assert.equal(result.notice?.title, "Host bridge 请求失败，正在展示 QA mock fallback");
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
  assert.match(markup, /<strong>当前没有可用 host target，正在展示 QA mock fallback<\/strong>/);
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
  assert.match(markup, /<strong>Host bridge 请求失败，正在展示 QA mock fallback<\/strong>/);
  assert.match(markup, /<span>Host targets request failed: 502<\/span>/);
});

test("keeps Web host input POST route readonly with 405 semantics", async () => {
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath: process.execPath });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/host-input",
  });

  assert.equal(response.statusCode, 405);
  assert.match(response.headers["content-type"], /application\/json/);
  assert.deepEqual(JSON.parse(response.body), {
    ok: false,
    error: {
      code: "web_host_input_readonly",
      message: "TritonKit Web mock is readonly; use CLI or HTTP runtime contracts for host input.",
    },
  });
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
        },
        response,
        () => reject(new Error("readonly host input route should not call next()"))
      )
    ).catch(reject);
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
    writeFileSync(outputPath, ${JSON.stringify(outputTemplate)});
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

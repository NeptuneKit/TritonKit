import assert from "node:assert/strict";
import test from "node:test";
import {
  createIosSimulatorBridgeMiddleware,
  getManagedTritonServeBindHost,
} from "./ios-bridge/index.mjs";
import {
  createFakeHostInputServer,
  createFakeRuntimeDataServer,
  createFakeTritonScript,
  createFakeTritonScriptFromSource,
  invokeMiddleware,
  pngBytes,
} from "./ios-bridge/testSupport.mjs";

test("managed Triton serve binds all interfaces for real-device Debug runtime access", () => {
  assert.equal(getManagedTritonServeBindHost(), "0.0.0.0");
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

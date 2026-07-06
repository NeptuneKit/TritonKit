import assert from "node:assert/strict";
import test from "node:test";
import { createIosSimulatorBridgeMiddleware } from "./index.mjs";
import {
  createFakeHostInputServer,
  createFakeTritonScriptFromSource,
  invokeMiddleware,
} from "./testSupport.mjs";

test("forwards iOS node property patches to the matching App runtime target", async () => {
  const received = [];
  const nodePropertyServer = await createFakeHostInputServer(received, {
    ok: true,
    success: true,
    action: "node.patch",
    applied: ["view.alpha"],
    skipped: [],
  });
  try {
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
        latestHierarchyAvailable: true
      }
    ]
  }));
  process.exit(0);
}
process.stderr.write("unexpected args: " + args.join(" "));
process.exit(64);
`);
    const middleware = createIosSimulatorBridgeMiddleware({
      tritonPath,
      hostInputBaseURL: nodePropertyServer.baseURL,
    });
    const response = await invokeMiddleware(middleware, {
      method: "POST",
      url: "/web/node-property?platform=ios&target=SIM-UDID&scope=simulator&kind=simulator",
      body: JSON.stringify({
        nodeId: "ios:runtime:1717",
        changes: { view: { alpha: 0.5 } },
      }),
    });

    assert.equal(response.statusCode, 200);
    assert.equal(JSON.parse(response.body).ok, true);
    assert.equal(received.length, 1);
    assert.equal(received[0].method, "POST");
    assert.equal(received[0].pathname, "/web/node-property");
    assert.equal(received[0].target, "triton:ios-simulator:SIM-UDID");
    assert.deepEqual(received[0].body, {
      nodeId: "ios:runtime:1717",
      changes: { view: { alpha: 0.5 } },
    });
  } finally {
    await nodePropertyServer.close();
  }
});

test("forwards iOS node property patches to an exact bundle-scoped runtime target", async () => {
  const received = [];
  const nodePropertyServer = await createFakeHostInputServer(received, {
    ok: true,
    success: true,
    action: "node.patch",
    applied: ["view.accessibilityLabel"],
    skipped: [],
  });
  try {
    const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({
    targets: [
      {
        id: "triton:ios-simulator:SIM-UDID/app:com.example.other",
        platform: "ios",
        connected: true,
        simulatorUDID: "SIM-UDID",
        bundleIdentifier: "com.example.other",
        latestHierarchyAvailable: true
      },
      {
        id: "triton:ios-simulator:SIM-UDID/app:com.example.demo",
        platform: "ios",
        connected: true,
        simulatorUDID: "SIM-UDID",
        bundleIdentifier: "com.example.demo",
        latestHierarchyAvailable: true
      }
    ]
  }));
  process.exit(0);
}
process.stderr.write("unexpected args: " + args.join(" "));
process.exit(64);
`);
    const middleware = createIosSimulatorBridgeMiddleware({
      tritonPath,
      hostInputBaseURL: nodePropertyServer.baseURL,
    });
    const target = encodeURIComponent("triton:ios-simulator:SIM-UDID/app:com.example.demo");
    const response = await invokeMiddleware(middleware, {
      method: "POST",
      url: `/web/node-property?platform=ios&target=${target}&source=runtime`,
      body: JSON.stringify({
        nodeId: "ios:runtime:130",
        changes: { view: { accessibilityLabel: "Smoke" } },
      }),
    });

    assert.equal(response.statusCode, 200);
    assert.equal(JSON.parse(response.body).ok, true);
    assert.equal(received.length, 1);
    assert.equal(received[0].target, "triton:ios-simulator:SIM-UDID/app:com.example.demo");
  } finally {
    await nodePropertyServer.close();
  }
});

test("rejects ambiguous iOS simulator node property runtime mirrors", async () => {
  const tritonPath = await createFakeTritonScriptFromSource(`#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({
    targets: [
      { id: "triton:ios-simulator:SIM-UDID/app:com.example.one", platform: "ios", connected: true, simulatorUDID: "SIM-UDID" },
      { id: "triton:ios-simulator:SIM-UDID/app:com.example.two", platform: "ios", connected: true, simulatorUDID: "SIM-UDID" }
    ]
  }));
  process.exit(0);
}
process.stderr.write("unexpected args: " + args.join(" "));
process.exit(64);
`);
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/node-property?platform=ios&target=SIM-UDID&scope=simulator&kind=simulator",
    body: JSON.stringify({
      nodeId: "ios:runtime:130",
      changes: { view: { accessibilityLabel: "Smoke" } },
    }),
  });

  assert.equal(response.statusCode, 409);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, false);
  assert.equal(body.error.code, "web_host_node_property_failed");
  assert.match(body.error.message, /Multiple connected iOS simulator App runtime targets/);
});

test("rejects non-iOS node property patches at the Web bridge boundary", async () => {
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath: "/bin/echo" });
  const response = await invokeMiddleware(middleware, {
    method: "POST",
    url: "/web/node-property?platform=android&target=emulator-5554",
    body: JSON.stringify({
      nodeId: "android:node:1",
      changes: { view: { alpha: 0.5 } },
    }),
  });

  assert.equal(response.statusCode, 501);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, false);
  assert.equal(body.error.code, "web_node_property_platform_not_supported");
});

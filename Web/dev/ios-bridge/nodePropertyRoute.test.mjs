import assert from "node:assert/strict";
import test from "node:test";
import { createIosSimulatorBridgeMiddleware } from "./index.mjs";
import { createFakeHostInputServer, invokeMiddleware } from "./testSupport.mjs";

const readonlyNodePropertyResponse = {
  ok: false,
  error: {
    code: "web_node_property_readonly",
    message: "Triton Web is a readonly device hub and does not execute browser write actions.",
    endpoint: "/web/node-property",
    hint: "Use `triton debug patch-node … --json` for an explicit, auditable node patch.",
  },
};

test("rejects node property patches without resolving or forwarding a runtime target", async () => {
  const received = [];
  const upstream = await createFakeHostInputServer(received, { ok: true, action: "node.patch" });
  const middleware = createIosSimulatorBridgeMiddleware({
    tritonPath: process.execPath,
    hostInputBaseURL: upstream.baseURL,
  });

  try {
    const response = await invokeMiddleware(middleware, {
      method: "POST",
      url: "/web/node-property?platform=ios&target=SIM-UDID&scope=simulator&kind=simulator",
      body: "{ malformed-json",
    });

    assert.equal(response.statusCode, 405);
    assert.match(response.headers["content-type"], /application\/json/);
    assert.deepEqual(JSON.parse(response.body), readonlyNodePropertyResponse);
    assert.deepEqual(received, []);
  } finally {
    await upstream.close();
  }
});

test("rejects non-POST node property requests with the same readonly envelope", async () => {
  const middleware = createIosSimulatorBridgeMiddleware({ tritonPath: process.execPath });
  const response = await invokeMiddleware(middleware, {
    method: "GET",
    url: "/web/node-property?platform=android&target=emulator-5554",
  });

  assert.equal(response.statusCode, 405);
  assert.deepEqual(JSON.parse(response.body), readonlyNodePropertyResponse);
});

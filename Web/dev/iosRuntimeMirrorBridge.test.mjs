import assert from "node:assert/strict";
import { chmod, mkdtemp, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import { join } from "node:path";
import test from "node:test";
import { tmpdir } from "node:os";
import { createIosSimulatorBridgeMiddleware } from "./ios-bridge/index.mjs";
import { webHostRuntimeError } from "./ios-bridge/runtimeMirror.mjs";

test("real-device mirror failure does not propose a LAN-facing managed server", () => {
  const response = webHostRuntimeError(
    "ios",
    { scope: "real", kind: "real-device", target: "ios-real:device-1" },
    new Error("No connected runtime"),
    "screenshot"
  );

  assert.equal(response.error.code, "app_runtime_unavailable");
  assert.equal(
    response.error.hint,
    "Triton Web does not auto-start a LAN-facing runtime server; use an explicit approved CLI/HTTP device workflow."
  );
  assert.doesNotMatch(response.error.hint, /0\.0\.0\.0|TRITON_HOST|LAN IP/);
});

test("resolves single iOS simulator runtime target for runtime hierarchy mirror when simulator UDID is unavailable", async () => {
  const tritonPath = await createFakeTritonScript(`#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(" ") === "list --json") {
  process.stdout.write(JSON.stringify({ targets: [{ id: "triton:connection:14", platform: "ios", connected: true }] }));
  process.exit(0);
}
if (args.join(" ") !== "debug hierarchy --platform ios --target triton:connection:14 --json") {
  process.stderr.write("unexpected args: " + args.join(" "));
  process.exit(64);
}
process.stdout.write(JSON.stringify({
  ok: true,
  capturedAt: "2026-07-03T16:18:48.000Z",
  source: {
    command: "triton debug hierarchy --platform ios --target triton:connection:14 --json",
    runtimeScope: "runtime-tree",
    readonly: true
  },
  scene: {
    platform: "ios",
    rootId: "root",
    viewport: { width: 402, height: 874 },
    nodes: [
      {
        id: "root",
        type: "UIWindow",
        name: "keyWindow",
        frame: { x: 0, y: 0, width: 402, height: 874 },
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
    url: "/web/host-hierarchy?platform=ios&target=AAAA-BBBB&source=runtime",
  });

  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.ok, true);
  assert.equal(body.source.command, "triton debug hierarchy --platform ios --target triton:connection:14 --json");
  assert.equal(body.scene.rootId, "root");
});

async function createFakeTritonScript(source) {
  const dir = await mkdtemp(join(tmpdir(), "tritonkit-web-runtime-mirror-"));
  const scriptPath = join(dir, "triton");
  await writeFile(scriptPath, source);
  await chmod(scriptPath, 0o755);
  return scriptPath;
}

async function invokeMiddleware(middleware, request) {
  const server = createServer((req, res) => middleware(req, res, () => {
    res.statusCode = 404;
    res.end("not found");
  }));
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  const port = typeof address === "object" && address ? address.port : 0;
  try {
    const response = await fetch(`http://127.0.0.1:${port}${request.url}`, {
      method: request.method ?? "GET",
    });
    return {
      statusCode: response.status,
      headers: Object.fromEntries(response.headers.entries()),
      body: await response.text(),
    };
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

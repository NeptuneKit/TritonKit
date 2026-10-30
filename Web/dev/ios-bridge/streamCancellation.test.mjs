import assert from "node:assert/strict";
import { createServer, get } from "node:http";
import { setTimeout as delay } from "node:timers/promises";
import test from "node:test";
import { handleStreamRoute } from "./streamRoutes.mjs";

// This file runs in its own Node test worker. Never let an orphaned regression
// path reach a user's fixed-port server after a fixture has been closed.
const systemFetch = globalThis.fetch;
globalThis.fetch = (input, options) => {
  if (new URL(input).port === "19421") throw new Error("unbound fixed-port request in test");
  return systemFetch(input, options);
};

async function until(predicate, message) {
  const deadline = Date.now() + 1500;
  while (!predicate() && Date.now() < deadline) await delay(10);
  assert.ok(predicate(), message);
}

async function listen(server) {
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  return `http://127.0.0.1:${server.address().port}`;
}

async function fixture(t, { holdHeaders = false, holdHealth = false, framebufferUnavailable = false, holdFirstScreenshot = false, blockFirstResponse = false, rapidStream = false, frameContentType = "image/jpeg", framePayload = Buffer.from("frame-one") } = {}) {
  const partBytes = Buffer.concat([Buffer.from(`--fixture\r\nContent-Type: ${frameContentType}\r\nContent-Length: ${framePayload.length}\r\n\r\n`), framePayload, Buffer.from("\r\n")]);
  const upstreamRequests = [];
  const bridgeRequests = [];
  const healthRequests = [];
  const screenshotRequests = [];
  const heldScreenshots = [];
  const errors = [];
  const handlers = [];
  const upstream = createServer((req, res) => {
    if (req.url === "/health") {
      healthRequests.push(res);
      if (!holdHealth) res.end("ok");
      return;
    }
    if (req.url.startsWith("/web/screenshot?")) {
      screenshotRequests.push(req.url);
      if (holdFirstScreenshot && screenshotRequests.length === 1) {
        heldScreenshots.push(res);
        return;
      }
      res.writeHead(200, { "content-type": "image/jpeg" });
      res.end("fixture-jpeg");
      return;
    }
    if (framebufferUnavailable) {
      res.writeHead(503);
      res.end("fixture framebuffer unavailable");
      return;
    }
    const request = { req, res, closed: false, sentBytes: 0 };
    upstreamRequests.push(request);
    res.once("close", () => { request.closed = true; });
    if (!holdHeaders) {
      res.writeHead(200, { "content-type": "multipart/x-mixed-replace; boundary=fixture" });
      res.write(partBytes);
      if (rapidStream) {
        const chunk = Buffer.alloc(64 * 1024, 0x61);
        let timer;
        const pump = () => {
          if (res.destroyed || res.writableEnded || request.sentBytes >= 64 * 1024 * 1024) return;
          request.sentBytes += chunk.length;
          if (res.write(chunk)) timer = setTimeout(pump, 1);
          else res.once("drain", pump);
        };
        res.once("close", () => { clearTimeout(timer); res.removeListener("drain", pump); });
        pump();
      }
    }
  });
  const upstreamURL = await listen(upstream);
  // Use the actual configured upstream; fixed-port requests remain forbidden.
  const bridge = createServer((req, res) => {
    const flow = { writes: 0, maxQueuedBytes: 0, gate: blockFirstResponse && bridgeRequests.length === 0 };
    const write = res.write.bind(res);
    res.write = (...args) => {
      flow.writes += 1;
      const accepted = write(...args);
      flow.maxQueuedBytes = Math.max(flow.maxQueuedBytes, res.writableLength);
      return flow.gate ? false : accepted;
    };
    flow.release = () => { flow.gate = false; res.emit("drain"); };
    bridgeRequests.push({ req, res, flow });
    const handler = handleStreamRoute({
      url: new URL(req.url, "http://fixture.local"), req, res,
      tritonPath: "/unused-fixture-triton", hostInputBaseURL: upstreamURL,
    }).catch((error) => { errors.push(error); res.destroy(); });
    handlers.push(handler);
  });
  const bridgeURL = await listen(bridge);
  const clients = [];
  t.after(async () => {
    for (const client of clients) client.request.destroy();
    bridge.closeAllConnections();
    upstream.closeAllConnections();
    await Promise.all([new Promise((resolve) => bridge.close(resolve)), new Promise((resolve) => upstream.close(resolve))]);
    await Promise.all(handlers);
    // Cleanup must also contain the old implementation's late-listener defect:
    // close has already happened, but its iOS fallback may subscribe afterward.
    for (const { req, res } of bridgeRequests) { req.emit("close"); res.emit("close"); }
  });
  function connect(platform = "android", { paused = false } = {}) {
    const client = { chunks: [], byteChunks: [], ended: false, response: null };
    client.request = get(`${bridgeURL}/web/${platform}/mjpeg?udid=fixture-target&fps=5`, { agent: false }, (response) => {
      client.response = response;
      response.on("data", (data) => { client.chunks.push(data.toString()); client.byteChunks.push(data); });
      if (paused) response.pause();
      response.on("end", () => { client.ended = true; });
      response.on("error", () => {});
    });
    client.request.on("error", () => {});
    clients.push(client);
    return client;
  }
  return { connect, upstreamRequests, bridgeRequests, healthRequests, screenshotRequests, heldScreenshots, errors, partBytes };
}

for (const platform of ["android", "harmony", "ios-simulator"]) {
  test(`${platform}: closing before upstream headers cancels the pending request`, async (t) => {
    const f = await fixture(t, { holdHeaders: true });
    const client = f.connect(platform);
    await until(() => f.upstreamRequests.length === 1, "upstream request started");
    client.request.destroy();
    await until(() => f.upstreamRequests[0].closed, "pending upstream must close without waiting for headers/timeout");
    assert.equal(f.upstreamRequests.length, 1, "cancellation must not start a fallback stream");
    assert.deepEqual(f.errors, []);
  });
}

test("closing during server readiness does not start an upstream stream", async (t) => {
  const f = await fixture(t, { holdHealth: true });
  const client = f.connect();
  await until(() => f.healthRequests.length === 1, "readiness check started");
  client.request.destroy();
  await until(() => f.bridgeRequests[0].res.destroyed, "downstream disconnected");
  f.healthRequests[0].end("ok");
  await delay(80);
  assert.equal(f.upstreamRequests.length, 0);
});

test("closing a streaming response releases upstream and reconnect uses a fresh request", async (t) => {
  const f = await fixture(t);
  const first = f.connect();
  await until(() => first.chunks.length > 0, "first frame arrived");
  first.request.destroy();
  const second = f.connect();
  await until(() => second.chunks.length > 0 && f.upstreamRequests[0].closed, "old stream closed and new stream connected");
  assert.equal(f.upstreamRequests.length, 2);
  assert.equal(f.upstreamRequests[1].closed, false);
  f.upstreamRequests[1].res.write("frame-two");
  await until(() => second.chunks.join("").includes("frame-two"), "reconnected stream still receives frames");
  second.request.destroy();
  await until(() => f.upstreamRequests[1].closed, "new stream also cleaned up");
});

test("two subscribers are independent and the remaining subscriber keeps receiving frames", async (t) => {
  const f = await fixture(t);
  const first = f.connect("harmony");
  await until(() => first.chunks.length > 0, "first subscriber connected");
  const second = f.connect("harmony");
  await until(() => second.chunks.length > 0, "second subscriber connected");
  first.request.destroy();
  await until(() => f.upstreamRequests[0].closed, "first upstream closed");
  assert.equal(f.upstreamRequests[1].closed, false);
  f.upstreamRequests[1].res.write("surviving-frame");
  await until(() => second.chunks.join("").includes("surviving-frame"), "remaining subscriber survives");
});

test("normal upstream completion ends downstream and removes cancellation listeners", async (t) => {
  const f = await fixture(t);
  const client = f.connect();
  await until(() => client.chunks.length > 0, "stream started");
  f.upstreamRequests[0].res.end("last-frame");
  await until(() => client.ended, "downstream ended naturally");
  assert.ok(client.chunks.join("").includes("last-frame"));
  assert.equal(f.bridgeRequests[0].req.listenerCount("close"), 0, "request body completion is not our cancellation signal");
  assert.equal(f.bridgeRequests[0].req.listenerCount("aborted"), 0);
  assert.equal(f.bridgeRequests[0].res.listenerCount("close"), 0);
  assert.deepEqual(f.errors, []);
});


test("iOS polling fallback keeps other subscribers and stops after the last response closes", async (t) => {
  const f = await fixture(t, { framebufferUnavailable: true });
  const first = f.connect("ios-simulator");
  await until(() => first.chunks.length > 0, "first polling subscriber has a frame");
  const second = f.connect("ios-simulator");
  await until(() => second.chunks.length > 0, "second polling subscriber has a frame");
  first.request.destroy();
  const before = second.chunks.length;
  await until(() => second.chunks.length > before, "closing one polling subscriber does not stop the other");
  second.request.destroy();
  await until(() => f.bridgeRequests.every(({ res }) => res.destroyed), "all responses closed");
  await delay(100); // Allow the already-running fake screenshot to complete.
  const requestsAfterClose = f.screenshotRequests.length;
  await delay(120);
  assert.equal(f.screenshotRequests.length, requestsAfterClose, "no new screenshots after the final subscriber closes");
  const resumed = f.connect("ios-simulator");
  await until(() => resumed.chunks.length > 0 && f.screenshotRequests.length > requestsAfterClose, "polling reconnect starts capturing again");
});

test("generic upstream failure retains the existing HTTP 500 response", async (t) => {
  const f = await fixture(t, { framebufferUnavailable: true });
  const client = f.connect();
  await until(() => client.ended, "failure response ended");
  assert.equal(client.response.statusCode, 500);
  assert.equal(client.chunks.join(""), "Android stream proxy failed");
  assert.equal(f.bridgeRequests[0].res.listenerCount("close"), 0);
});


test("iOS pending screenshot failure cannot start another capture after the last subscriber closes", async (t) => {
  const f = await fixture(t, { framebufferUnavailable: true, holdFirstScreenshot: true });
  const client = f.connect("ios-simulator");
  await until(() => f.heldScreenshots.length === 1, "first screenshot request is pending");
  assert.match(new URL(f.screenshotRequests[0], "http://fixture.local").searchParams.get("target"), /^triton:ios-simulator:/);
  client.request.destroy();
  await until(() => f.bridgeRequests[0].res.destroyed, "last response has closed");
  f.heldScreenshots[0].writeHead(503);
  f.heldScreenshots[0].end("first screenshot unavailable");
  await delay(150);
  assert.equal(f.screenshotRequests.length, 1, "must not fall back to a new host:ios capture after cancellation");
  assert.deepEqual(f.errors, []);
});


for (const platform of ["android", "harmony", "ios-simulator"]) {
  test(`${platform}: a blocked downstream waits for drain before forwarding more data`, async (t) => {
    const f = await fixture(t, { blockFirstResponse: true });
    const client = f.connect(platform);
    await until(() => f.bridgeRequests[0]?.flow.writes === 1, "first write reached the blocked response");
    f.upstreamRequests[0].res.write("second-upstream-frame");
    await delay(60);
    assert.equal(f.bridgeRequests[0].flow.writes, 1, "must not read and enqueue another upstream chunk while blocked");
    f.bridgeRequests[0].flow.release();
    await until(() => client.chunks.join("").includes("second-upstream-frame"), "drain resumes forwarding");
    f.upstreamRequests[0].res.end("completed");
    await until(() => client.ended, "response completes after drain");
    assert.equal(f.bridgeRequests[0].res.listenerCount("drain"), 0);
    assert.equal(f.bridgeRequests[0].res.listenerCount("error"), 0);
  });
}

for (const event of ["close", "error", "aborted"]) {
  test(`blocked downstream ${event} releases the reader and drain listeners`, async (t) => {
    const f = await fixture(t, { blockFirstResponse: true });
    const client = f.connect();
    await until(() => f.bridgeRequests[0]?.flow.writes === 1, "response is blocked");
    const { req, res } = f.bridgeRequests[0];
    if (event === "close") client.request.destroy();
    else if (event === "error") res.emit("error", new Error("fixture downstream failure"));
    else req.emit("aborted");
    await until(() => f.upstreamRequests[0].closed, "cancel upstream while waiting for drain");
    await until(() => res.listenerCount("drain") === 0 && res.listenerCount("error") === 0 && req.listenerCount("aborted") === 0, "all stream listeners removed");
    assert.deepEqual(f.errors, []);
  });
}

test("iOS fallback waits within a frame and leaves other subscribers independent", async (t) => {
  const f = await fixture(t, { framebufferUnavailable: true, blockFirstResponse: true });
  const first = f.connect("ios-simulator");
  await until(() => f.bridgeRequests[0]?.flow.writes > 0, "fallback started a frame");
  await delay(80);
  assert.equal(f.bridgeRequests[0].flow.writes, 1, "do not append the rest of this frame or another frame before drain");
  const second = f.connect("ios-simulator");
  await until(() => second.chunks.join("").includes("fixture-jpeg"), "unblocked subscriber keeps receiving frames");
  f.bridgeRequests[0].flow.release();
  await until(() => first.chunks.join("").includes("fixture-jpeg"), "blocked subscriber resumes after drain");
  first.request.destroy();
  second.request.destroy();
  await until(() => f.bridgeRequests.every(({ res }) => res.destroyed), "both subscribers closed");
  assert.equal(f.bridgeRequests[0].res.listenerCount("drain"), 0);
});

test("real paused TCP consumer keeps the proxy output queue bounded and disconnects promptly", async (t) => {
  const f = await fixture(t, { rapidStream: true });
  const client = f.connect("android", { paused: true });
  await until(() => client.response !== null && f.upstreamRequests[0].sentBytes >= 512 * 1024, "real socket transfer started");
  await delay(900);
  const { res, flow } = f.bridgeRequests[0];
  t.diagnostic(JSON.stringify({ maxQueuedBytes: flow.maxQueuedBytes, upstreamBytes: f.upstreamRequests[0].sentBytes, rssBytes: process.memoryUsage().rss }));
  assert.ok(flow.maxQueuedBytes <= 1024 * 1024, `output must remain bounded, observed ${flow.maxQueuedBytes} queued bytes`);
  client.request.destroy();
  await until(() => f.upstreamRequests[0].closed, "real blocked upstream canceled on disconnect");
  await until(() => res.listenerCount("drain") === 0, "drain waiter removed");
});


for (const event of ["close", "error", "aborted"]) {
  test(`iOS fallback ${event} during drain wait stops capture and removes listeners`, async (t) => {
    const f = await fixture(t, { framebufferUnavailable: true, blockFirstResponse: true });
    const client = f.connect("ios-simulator");
    await until(() => f.bridgeRequests[0]?.flow.writes === 1, "fallback is blocked within a frame");
    const { req, res } = f.bridgeRequests[0];
    if (event === "close") client.request.destroy();
    else if (event === "error") res.emit("error", new Error("fixture fallback failure"));
    else req.emit("aborted");
    await until(() => res.listenerCount("drain") === 0 && res.listenerCount("error") === 0 && req.listenerCount("aborted") === 0, "fallback cancellation removes all waits");
    await delay(80);
    const captures = f.screenshotRequests.length;
    await delay(80);
    assert.equal(f.screenshotRequests.length, captures, "last blocked subscriber no longer keeps capture alive");
    assert.equal(f.bridgeRequests[0].flow.writes, 1, "cancellation never resumes the remaining frame writes");
    assert.deepEqual(f.errors, []);
  });
}

for (const platform of ["android", "harmony", "ios-simulator"]) {
  test(`${platform}: configured upstream carries multipart frame bytes unchanged`, async (t) => {
    const png = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7l8AAAAASUVORK5CYII=", "base64");
    const f = await fixture(t, { frameContentType: platform === "android" ? "image/png" : "image/jpeg", framePayload: platform === "android" ? png : Buffer.from([0xff, 0xd8, 0xff, 0xd9]) });
    const client = f.connect(platform);
    await until(() => client.byteChunks.length > 0, "configured upstream delivered a frame");
    assert.equal(client.response.statusCode, 200);
    assert.equal(client.response.headers["content-type"], "multipart/x-mixed-replace; boundary=fixture");
    assert.deepEqual(Buffer.concat(client.byteChunks), f.partBytes);
    client.request.destroy();
    await until(() => f.upstreamRequests.length === 1 && f.upstreamRequests[0].closed, "configured upstream released after cancellation");
    assert.deepEqual(f.errors, []);
  });
}

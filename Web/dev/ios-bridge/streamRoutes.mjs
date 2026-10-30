import { randomUUID } from "node:crypto";
import { mkdir, readFile, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { runTritonJSON } from "./process.mjs";
import { sendJSON } from "./http.mjs";
import { ensureTritonServe } from "./tritonServe.mjs";

const simulatorFrameCache = new Map();

export async function handleStreamRoute({ url, req, res, tritonPath, hostInputBaseURL }) {
  if (url.pathname === "/web/ios-simulator/screenshot") {
    await handleIosSimulatorScreenshot(url, res, tritonPath);
    return true;
  }

  if (url.pathname === "/web/ios-simulator/frame") {
    await handleIosSimulatorFrame(url, res, tritonPath);
    return true;
  }

  if (url.pathname === "/web/android/mjpeg") {
    await handleGenericMjpegProxy({
      url,
      req,
      res,
      tritonPath,
      hostInputBaseURL,
      platformLabel: "Android",
      targetParam: url.searchParams.get("udid") || url.searchParams.get("serial") || "emulator-5554",
      fpsDefault: 15,
      fpsMax: 30,
      upstreamPath: "/web/android/framebuffer",
    });
    return true;
  }

  if (url.pathname === "/web/harmony/mjpeg") {
    await handleGenericMjpegProxy({
      url,
      req,
      res,
      tritonPath,
      hostInputBaseURL,
      platformLabel: "Harmony",
      targetParam: url.searchParams.get("udid") || url.searchParams.get("serial") || "booted",
      fpsDefault: 10,
      fpsMax: 15,
      upstreamPath: "/web/harmony/framebuffer",
    });
    return true;
  }

  if (url.pathname === "/web/ios-simulator/mjpeg") {
    await handleIosSimulatorMjpeg(url, req, res, tritonPath, hostInputBaseURL);
    return true;
  }

  return false;
}

async function handleIosSimulatorScreenshot(url, res, tritonPath) {
  const simulator = url.searchParams.get("simulator") || "booted";
  const outputDir = join(tmpdir(), `tritonkit-web-ios-${randomUUID()}`);
  const outputPath = join(outputDir, "screenshot.png");
  await mkdir(outputDir, { recursive: true });
  try {
    const payload = await runTritonJSON(tritonPath, [
      "sim",
      "screenshot",
      "--simulator",
      simulator,
      "--output",
      outputPath,
      "--json",
    ]);
    const image = await readFile(outputPath);
    sendJSON(res, 200, {
      ok: true,
      simulator,
      source: {
        command: "triton sim screenshot --json",
        runtimeScope: "host-simulator",
        readonly: true,
      },
      artifact: payload.artifact,
      pixelWidth: payload.pixelWidth ?? null,
      pixelHeight: payload.pixelHeight ?? null,
      dataUrl: `data:image/png;base64,${image.toString("base64")}`,
    });
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
}

async function handleIosSimulatorFrame(url, res, tritonPath) {
  const udid = url.searchParams.get("udid") || "booted";
  const simulator = udid === "booted" ? "booted" : udid;
  try {
    const fastRes = await fetch(`http://127.0.0.1:19421/web/screenshot?target=host:ios:${simulator}&t=${Date.now()}`);
    if (fastRes.ok) {
      const buffer = Buffer.from(await fastRes.arrayBuffer());
      writeImageResponse(res, buffer, "image/png");
      return;
    }
  } catch {
    // Slow fallback below.
  }

  const outputDir = join(tmpdir(), `tritonkit-web-frame-${randomUUID()}`);
  const outputPath = join(outputDir, "frame.png");
  await mkdir(outputDir, { recursive: true });
  try {
    await runTritonJSON(tritonPath, [
      "sim",
      "screenshot",
      "--simulator",
      simulator,
      "--output",
      outputPath,
      "--json",
    ]);
    const image = await readFile(outputPath);
    writeImageResponse(res, image, "image/png");
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
}

async function handleGenericMjpegProxy({
  url,
  req,
  res,
  tritonPath,
  hostInputBaseURL,
  platformLabel,
  targetParam,
  fpsDefault,
  fpsMax,
  upstreamPath,
}) {
  const requestedFps = parseInt(url.searchParams.get("fps") || String(fpsDefault), 10);
  const fps = Math.min(fpsMax, Math.max(1, requestedFps));
  console.log(`[PROXY] Starting ${platformLabel} MJPEG stream proxy for target: ${targetParam}, fps: ${fps}`);

  const connection = createMjpegConnection(req, res);
  try {
    try {
      await ensureTritonServe(tritonPath, hostInputBaseURL);
    } catch (error) {
      if (!connection.signal.aborted) {
        console.error(`[PROXY] ensureTritonServe failed for ${platformLabel}: ${error.message}`);
      }
    }
    if (connection.signal.aborted) return;

    const fetchUrl = new URL(upstreamPath, hostInputBaseURL);
    fetchUrl.searchParams.set("target", targetParam);
    fetchUrl.searchParams.set("fps", String(fps));
    const fastRes = await fetchMjpegResponse(fetchUrl, connection.signal);
    if (fastRes.ok) {
      await pipeMjpegResponse(res, fastRes, `${platformLabel} target: ${targetParam}`, connection.signal);
      return;
    }
    await fastRes.body?.cancel();
    console.error(`[PROXY] Upstream returned non-ok status for ${platformLabel}: ${fastRes.status} ${fastRes.statusText}`);
  } catch (error) {
    if (!connection.signal.aborted) {
      console.error(`[PROXY] Fetch exception for ${platformLabel} target: ${targetParam}: ${error.message}`);
    }
  } finally {
    connection.dispose();
  }
  if (connection.signal.aborted || res.destroyed || res.writableEnded) return;
  if (!res.headersSent) res.writeHead(500, { "Content-Type": "text/plain" });
  res.end(`${platformLabel} stream proxy failed`);
}

async function handleIosSimulatorMjpeg(url, req, res, tritonPath, hostInputBaseURL) {
  const udid = url.searchParams.get("udid") || "booted";
  const simulator = udid === "booted" ? "booted" : udid;
  const requestedFps = parseInt(url.searchParams.get("fps") || "15", 10);
  const fps = Math.min(120, Math.max(1, requestedFps));
  const connection = createMjpegConnection(req, res);
  let polling = false;

  try {
    try {
      await ensureTritonServe(tritonPath, hostInputBaseURL);
    } catch {
      // Fallback to polling below, only while the client is still connected.
    }
    if (connection.signal.aborted) return;

    try {
      const fastRes = await fetchMjpegResponse(
        new URL(`/web/ios-simulator/framebuffer?target=${encodeURIComponent(`host:ios:${simulator}`)}&fps=${fps}`, hostInputBaseURL),
        connection.signal
      );
      if (fastRes.ok) {
        await pipeMjpegResponse(res, fastRes, `iOS simulator: ${simulator}`, connection.signal);
        return;
      }
      await fastRes.body?.cancel();
    } catch {
      if (res.headersSent) return;
    }
    if (connection.signal.aborted || res.destroyed) return;

    res.writeHead(200, mjpegHeaders());
    // A simulator ID is only meaningful within its upstream and CLI configuration.
    const cacheKey = JSON.stringify([new URL(hostInputBaseURL).href, tritonPath, simulator]);
    let cache = simulatorFrameCache.get(cacheKey);
    if (!cache) {
      cache = createSimulatorFrameCache();
      simulatorFrameCache.set(cacheKey, cache);
    }
    const listenerId = randomUUID();
    cache.activeListeners.set(listenerId, fps);
    let active = true;
    let pushTimer;
    const stop = () => {
      if (!active) return;
      active = false;
      clearTimeout(pushTimer);
      cache.activeListeners.delete(listenerId);
      if (cache.activeListeners.size === 0) {
        cache.loopActive = false;
        clearTimeout(cache.loopTimer);
        cache.loopTimer = null;
        cache.buffer = null;
        // Retire this generation before aborting its pending HTTP screenshot.
        // A reconnect always acquires a fresh cache, even while old work unwinds.
        if (simulatorFrameCache.get(cacheKey) === cache) simulatorFrameCache.delete(cacheKey);
        cache.controller.abort();
      }
      connection.signal.removeEventListener("abort", stop);
      connection.dispose();
    };
    connection.signal.addEventListener("abort", stop, { once: true });
    // The polling listener owns connection cleanup until the response closes.
    polling = true;
    if (connection.signal.aborted) { stop(); return; }
    startSimulatorGrabLoop(cacheKey, cache, tritonPath, simulator, hostInputBaseURL);

    const pushFrame = async () => {
      if (!active) return;
      // Keep one coherent frame while a slow client waits for drain. The shared
      // cache may advance for other subscribers, but this response never queues
      // the next frame while the current one is blocked by its output buffer.
      const buffer = cache.buffer;
      if (buffer) {
        const parts = [
          "--tritonboundary\r\n",
          `Content-Type: ${cache.contentType}\r\n`,
          `Content-Length: ${buffer.length}\r\n\r\n`,
          buffer,
          "\r\n",
        ];
        for (const part of parts) {
          if (!await writeMjpegChunk(res, part, connection.signal)) {
            stop();
            return;
          }
        }
      }
      if (active) pushTimer = setTimeout(pushFrame, Math.round(1000 / fps));
    };
    pushFrame();
  } finally {
    if (!polling) connection.dispose();
  }
}

function startSimulatorGrabLoop(cacheKey, cache, tritonPath, simulator, hostInputBaseURL) {
  if (cache.loopActive) return;
  cache.loopActive = true;
  const isActive = () => simulatorFrameCache.get(cacheKey) === cache
    && cache.loopActive && !cache.controller.signal.aborted && cache.activeListeners.size > 0;
  const captureSignal = () => AbortSignal.any([cache.controller.signal, AbortSignal.timeout(3000)]);

  const grabFrame = async () => {
    cache.loopTimer = null;
    if (!isActive()) {
      cache.loopActive = false;
      return;
    }

    let isFastChannel = false;
    let newBuffer = null;
    let newContentType = "image/jpeg";

    try {
      let targetId = `triton:ios-simulator:${simulator}`;
      let fastRes = await fetch(
        new URL(`/web/screenshot?target=${encodeURIComponent(targetId)}&t=${Date.now()}`, hostInputBaseURL),
        { signal: captureSignal() }
      );
      if (!isActive()) { await fastRes.body?.cancel(); return; }
      if (!fastRes.ok) {
        await fastRes.body?.cancel();
        if (!isActive()) return;
        targetId = `host:ios:${simulator}`;
        fastRes = await fetch(
          new URL(`/web/screenshot?target=${encodeURIComponent(targetId)}&t=${Date.now()}`, hostInputBaseURL),
          { signal: captureSignal() }
        );
      }
      if (!isActive()) { await fastRes.body?.cancel(); return; }

      if (fastRes.ok) {
        const contentType = fastRes.headers.get("content-type") || "";
        if (contentType.includes("image")) {
          newBuffer = Buffer.from(await fastRes.arrayBuffer());
          newContentType = contentType;
          isFastChannel = true;
        } else {
          await fastRes.body?.cancel();
        }
      } else {
        await fastRes.body?.cancel();
      }
    } catch {
      // Slow fallback below.
    }

    if (!isActive()) return;
    if (!newBuffer) {
      const outputDir = join(tmpdir(), `tritonkit-web-grab-${randomUUID()}`);
      const outputPath = join(outputDir, "frame.png");
      try {
        await mkdir(outputDir, { recursive: true });
        if (!isActive()) return;
        await runTritonJSON(tritonPath, [
          "sim",
          "screenshot",
          "--simulator",
          simulator,
          "--output",
          outputPath,
          "--json",
        ]);
        // Already-dispatched CLI work may finish after cancellation; never
        // publish it or let it schedule another capture for a later generation.
        if (!isActive()) return;
        newBuffer = await readFile(outputPath);
        newContentType = "image/png";
      } catch {
        // ignore
      } finally {
        await rm(outputDir, { recursive: true, force: true });
      }
    }

    if (newBuffer && isActive()) {
      cache.buffer = newBuffer;
      cache.contentType = newContentType;
      cache.lastFetchTime = Date.now();
    }

    if (isActive()) {
      const maxFps = Math.max(...cache.activeListeners.values(), 15);
      const fastDelay = maxFps >= 60 ? 2 : Math.max(0, Math.round(1000 / (maxFps * 2)));
      const delay = isFastChannel ? fastDelay : 1200;
      cache.loopTimer = setTimeout(grabFrame, delay);
    } else {
      cache.loopActive = false;
    }
  };

  grabFrame();
}

// A GET request's close event can mean its request body has completed. The
// long-lived response owns the preview subscription, including the time spent
// waiting for readiness and upstream headers.
function createMjpegConnection(req, res) {
  const controller = new AbortController();
  const close = () => controller.abort();
  res.once("close", close);
  res.once("error", close);
  req.once("aborted", close);
  if (req.aborted || res.destroyed || res.writableEnded) close();
  return {
    signal: controller.signal,
    dispose() {
      res.removeListener("close", close);
      res.removeListener("error", close);
      req.removeListener("aborted", close);
    },
  };
}

async function fetchMjpegResponse(url, clientSignal) {
  const timeout = new AbortController();
  const timeoutId = setTimeout(() => timeout.abort(), 5000);
  try {
    return await fetch(url, { signal: AbortSignal.any([clientSignal, timeout.signal]) });
  } finally {
    clearTimeout(timeoutId);
  }
}

async function pipeMjpegResponse(res, upstreamResponse, label, signal) {
  if (signal.aborted || res.destroyed) {
    await upstreamResponse.body?.cancel();
    return;
  }
  res.writeHead(200, {
    ...mjpegHeaders(),
    "Content-Type": upstreamResponse.headers.get("content-type") || "multipart/x-mixed-replace; boundary=tritonboundary",
  });
  const reader = upstreamResponse.body.getReader();
  const cancel = () => { reader.cancel().catch(() => {}); };
  signal.addEventListener("abort", cancel, { once: true });
  try {
    while (!signal.aborted) {
      const { done, value } = await reader.read();
      if (done || signal.aborted) break;
      if (!await writeMjpegChunk(res, Buffer.from(value), signal)) break;
    }
  } catch (error) {
    if (!signal.aborted) console.error(`[PROXY] Stream piping error for ${label}: ${error.message}`);
  } finally {
    signal.removeEventListener("abort", cancel);
    await reader.cancel().catch(() => {});
    reader.releaseLock();
    if (!res.destroyed && !res.writableEnded) res.end();
  }
}

// ServerResponse.write(false) is a request to stop producing, not a failure.
// Keep only the current chunk until drain; cancellation must also wake this wait
// because a closed response will never drain.
async function writeMjpegChunk(res, chunk, signal) {
  if (signal.aborted || res.destroyed || res.writableEnded) return false;
  try {
    if (res.write(chunk)) return true;
  } catch {
    return false;
  }
  return new Promise((resolve) => {
    const finish = (drained) => {
      res.removeListener("drain", onDrain);
      res.removeListener("close", onStop);
      res.removeListener("error", onStop);
      res.removeListener("finish", onStop);
      signal.removeEventListener("abort", onStop);
      resolve(drained);
    };
    const onDrain = () => finish(true);
    const onStop = () => finish(false);
    res.once("drain", onDrain);
    res.once("close", onStop);
    res.once("error", onStop);
    res.once("finish", onStop);
    signal.addEventListener("abort", onStop, { once: true });
    if (signal.aborted || res.destroyed || res.writableEnded) onStop();
  });
}

function createSimulatorFrameCache() {
  return {
    buffer: null,
    contentType: "image/png",
    lastFetchTime: 0,
    activeListeners: new Map(),
    currentFps: 0,
    loopActive: false,
    loopTimer: null,
    controller: new AbortController(),
  };
}

function writeImageResponse(res, buffer, contentType) {
  res.writeHead(200, {
    "Content-Type": contentType,
    "Content-Length": buffer.length,
    "Cache-Control": "no-store",
    "Access-Control-Allow-Origin": "*",
  });
  res.end(buffer);
}

function mjpegHeaders() {
  return {
    "Content-Type": "multipart/x-mixed-replace; boundary=tritonboundary",
    "Cache-Control": "no-cache, no-store, must-revalidate",
    "Connection": "close",
    "Pragma": "no-cache",
    "Access-Control-Allow-Origin": "*",
  };
}


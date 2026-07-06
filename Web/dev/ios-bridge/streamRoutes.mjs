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

  try {
    await ensureTritonServe(tritonPath, hostInputBaseURL);
  } catch (error) {
    console.error(`[PROXY] ensureTritonServe failed for ${platformLabel}: ${error.message}`);
  }

  let proxyStarted = false;
  const controller = new AbortController();
  const timeoutId = setTimeout(() => {
    if (!proxyStarted) {
      console.warn(`[PROXY] ${platformLabel} stream proxy request timed out for target: ${targetParam}`);
      controller.abort();
    }
  }, 5000);

  try {
    const fetchUrl = `http://127.0.0.1:19421${upstreamPath}?target=${targetParam}&fps=${fps}`;
    console.log(`[PROXY] Fetching from upstream ${platformLabel}: ${fetchUrl}`);
    const fastRes = await fetch(fetchUrl, { signal: controller.signal });
    clearTimeout(timeoutId);

    if (fastRes.ok) {
      console.log(`[PROXY] Upstream connected for ${platformLabel} target: ${targetParam}. Piping response...`);
      proxyStarted = true;
      await pipeMjpegResponse(req, res, fastRes, `${platformLabel} target: ${targetParam}`);
      return;
    }
    console.error(`[PROXY] Upstream returned non-ok status for ${platformLabel}: ${fastRes.status} ${fastRes.statusText}`);
  } catch (error) {
    console.error(`[PROXY] Fetch exception for ${platformLabel} target: ${targetParam}: ${error.message}`);
    if (proxyStarted) {
      try {
        res.end();
      } catch {
        // ignore
      }
      return;
    }
  }
  res.writeHead(500, { "Content-Type": "text/plain" });
  res.end(`${platformLabel} stream proxy failed`);
}

async function handleIosSimulatorMjpeg(url, req, res, tritonPath, hostInputBaseURL) {
  const udid = url.searchParams.get("udid") || "booted";
  const simulator = udid === "booted" ? "booted" : udid;
  const requestedFps = parseInt(url.searchParams.get("fps") || "15", 10);
  const fps = Math.min(120, Math.max(1, requestedFps));
  const targetInterval = Math.round(1000 / fps);

  try {
    await ensureTritonServe(tritonPath, hostInputBaseURL);
  } catch {
    // Fallback to polling below.
  }

  let proxyStarted = false;
  const controller = new AbortController();
  const timeoutId = setTimeout(() => {
    if (!proxyStarted) {
      controller.abort();
    }
  }, 5000);

  try {
    const fastRes = await fetch(
      `http://127.0.0.1:19421/web/ios-simulator/framebuffer?target=host:ios:${simulator}&fps=${fps}`,
      { signal: controller.signal }
    );
    clearTimeout(timeoutId);

    if (fastRes.ok) {
      proxyStarted = true;
      await pipeMjpegResponse(req, res, fastRes, `iOS simulator: ${simulator}`);
      return;
    }
  } catch {
    if (proxyStarted) {
      try {
        res.end();
      } catch {
        // ignore
      }
      return;
    }
  }

  res.writeHead(200, mjpegHeaders());

  let cache = simulatorFrameCache.get(simulator);
  if (!cache) {
    cache = createSimulatorFrameCache();
    simulatorFrameCache.set(simulator, cache);
  }

  const listenerId = randomUUID();
  cache.activeListeners.set(listenerId, requestedFps);
  startSimulatorGrabLoop(tritonPath, simulator);

  let active = true;

  req.on("close", () => {
    active = false;
    if (cache) {
      cache.activeListeners.delete(listenerId);
      if (cache.activeListeners.size === 0 && cache.baguetteProcess) {
        try {
          cache.baguetteProcess.kill();
        } catch {
          // ignore
        }
        cache.baguetteProcess = null;
      }
    }
  });

  const pushFrame = () => {
    if (!active) return;

    if (cache.buffer) {
      try {
        res.write("--tritonboundary\r\n");
        res.write(`Content-Type: ${cache.contentType}\r\n`);
        res.write(`Content-Length: ${cache.buffer.length}\r\n\r\n`);
        res.write(cache.buffer);
        res.write("\r\n");
      } catch {
        // ignore
      }
    }

    if (active) {
      setTimeout(pushFrame, targetInterval);
    }
  };

  pushFrame();
}

function startSimulatorGrabLoop(tritonPath, simulator) {
  let cache = simulatorFrameCache.get(simulator);
  if (!cache) {
    cache = createSimulatorFrameCache();
    simulatorFrameCache.set(simulator, cache);
  }

  if (cache.loopActive) return;
  cache.loopActive = true;

  const grabFrame = async () => {
    if (!cache.loopActive || cache.activeListeners.size === 0) {
      cache.loopActive = false;
      return;
    }

    let isFastChannel = false;
    let newBuffer = null;
    let newContentType = "image/jpeg";

    try {
      let targetId = `triton:ios-simulator:${simulator}`;
      let fastRes = await fetch(
        `http://127.0.0.1:19421/web/screenshot?target=${targetId}&t=${Date.now()}`,
        { signal: AbortSignal.timeout(3000) }
      );
      if (!fastRes.ok) {
        targetId = `host:ios:${simulator}`;
        fastRes = await fetch(
          `http://127.0.0.1:19421/web/screenshot?target=${targetId}&t=${Date.now()}`,
          { signal: AbortSignal.timeout(3000) }
        );
      }

      if (fastRes.ok) {
        const contentType = fastRes.headers.get("content-type") || "";
        if (contentType.includes("image")) {
          newBuffer = Buffer.from(await fastRes.arrayBuffer());
          newContentType = contentType;
          isFastChannel = true;
        }
      }
    } catch {
      // Slow fallback below.
    }

    if (!newBuffer && cache.loopActive && cache.activeListeners.size > 0) {
      const outputDir = join(tmpdir(), `tritonkit-web-grab-${randomUUID()}`);
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
        newBuffer = await readFile(outputPath);
        newContentType = "image/png";
      } catch {
        // ignore
      } finally {
        await rm(outputDir, { recursive: true, force: true });
      }
    }

    if (newBuffer) {
      cache.buffer = newBuffer;
      cache.contentType = newContentType;
      cache.lastFetchTime = Date.now();
    }

    if (cache.loopActive && cache.activeListeners.size > 0) {
      const maxFps = Math.max(...cache.activeListeners.values(), 15);
      const fastDelay = maxFps >= 60 ? 2 : Math.max(0, Math.round(1000 / (maxFps * 2)));
      const delay = isFastChannel ? fastDelay : 1200;
      setTimeout(grabFrame, delay);
    } else {
      cache.loopActive = false;
    }
  };

  grabFrame();
}

async function pipeMjpegResponse(req, res, upstreamResponse, label) {
  res.writeHead(200, {
    ...mjpegHeaders(),
    "Content-Type": upstreamResponse.headers.get("content-type") || "multipart/x-mixed-replace; boundary=tritonboundary",
  });
  const reader = upstreamResponse.body.getReader();
  req.on("close", () => {
    console.log(`[PROXY] Client connection closed for ${label}`);
    reader.cancel().catch(() => {});
  });

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        console.log(`[PROXY] Upstream stream finished for ${label}`);
        break;
      }
      res.write(Buffer.from(value));
    }
  } catch (error) {
    console.error(`[PROXY] Stream piping error for ${label}: ${error.message}`);
  } finally {
    res.end();
  }
}

function createSimulatorFrameCache() {
  return {
    buffer: null,
    contentType: "image/png",
    lastFetchTime: 0,
    activeListeners: new Map(),
    baguetteProcess: null,
    currentFps: 0,
    loopActive: false,
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


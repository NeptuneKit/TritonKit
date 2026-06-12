import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, readFile, rm } from "node:fs/promises";
import { createServer as createHttpServer } from "node:http";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";

const bridgeRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const runtimeHost = "127.0.0.1";
const runtimePort = 19421;
let managedTritonServe = null;

export function mapTritonSimListToWebTargets(payload) {
  if (!payload || !Array.isArray(payload.simulators)) {
    throw new Error("Expected triton sim list payload with simulators[]");
  }

  const bootedSimulators = payload.simulators.filter((simulator) => {
    const state = String(simulator.state ?? "Unknown");
    return Boolean(simulator.isBooted) || state.toLowerCase() === "booted";
  });

  return {
    ok: Boolean(payload.ok),
    capturedAt: new Date().toISOString(),
    source: {
      command: "triton sim list --json",
      runtimeScope: "host-simulator",
      readonly: true,
    },
    simulators: bootedSimulators.map((simulator) => {
      const state = String(simulator.state ?? "Unknown");
      const isBooted = Boolean(simulator.isBooted) || state.toLowerCase() === "booted";
      return {
        id: String(simulator.id ?? `sim:${simulator.udid}`),
        udid: String(simulator.udid ?? ""),
        name: String(simulator.name ?? "Unnamed Simulator"),
        platform: String(simulator.platform ?? "iOS Simulator"),
        runtime: String(simulator.runtime ?? ""),
        runtimeIdentifier: String(simulator.runtimeIdentifier ?? ""),
        deviceTypeIdentifier: String(simulator.deviceTypeIdentifier ?? ""),
        state,
        statusLabel: state,
        isAvailable: Boolean(simulator.isAvailable),
        isBooted,
        canScreenshot: isBooted,
        source: String(simulator.source ?? "simctl"),
        readonly: true,
      };
    }),
  };
}

export function mapTritonDeviceListToWebTargets(payload, platform) {
  if (!payload || !Array.isArray(payload.targets)) {
    throw new Error(`Expected triton device list payload with targets[] for ${platform}`);
  }

  return payload.targets
    .filter((target) => Boolean(target.ready) && target.scope === "emulator" && target.kind === "emulator")
    .map((target) => ({
      id: String(target.id ?? `${platform}:${target.target}`),
      target: String(target.target ?? ""),
      name: String(target.name ?? target.target ?? `${platform} emulator`),
      platform,
      runtime: String(target.runtime ?? platform),
      state: String(target.state ?? "Ready"),
      statusLabel: String(target.state ?? "Ready"),
      ready: Boolean(target.ready),
      scope: String(target.scope ?? "emulator"),
      kind: String(target.kind ?? "emulator"),
      source: String(target.source ?? platform),
      readonly: true,
    }));
}

export function createIosSimulatorBridgeMiddleware(options = {}) {
  const root = options.root ? resolve(options.root) : bridgeRoot;
  const tritonPath = resolveTritonBinary(root);

  return async function iosSimulatorBridgeMiddleware(req, res, next) {
    if (!req.url?.startsWith("/web/")) {
      next();
      return;
    }

    try {
      const url = new URL(req.url, "http://127.0.0.1");
      if (url.pathname === "/web/ios-simulator/targets") {
        const payload = await runTritonJSON(tritonPath, ["sim", "list", "--json"]);
        sendJSON(res, 200, mapTritonSimListToWebTargets(payload));
        return;
      }

      if (url.pathname === "/web/host-targets") {
        const response = await collectHostTargets(tritonPath);
        sendJSON(res, 200, response);
        return;
      }

      if (url.pathname === "/web/ios-simulator/screenshot") {
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
        return;
      }

      if (url.pathname === "/web/host-screenshot") {
        const platform = url.searchParams.get("platform") || "ios";
        const target = url.searchParams.get("target") || "booted";
        const screenshot = await captureHostScreenshot(tritonPath, platform, target);
        sendJSON(res, 200, screenshot);
        return;
      }

      if (url.pathname === "/web/host-input" && req.method === "POST") {
        const input = await readJSONBody(req);
        const response = await runHostInput(tritonPath, input);
        sendJSON(res, 200, response);
        return;
      }

      sendJSON(res, 404, { ok: false, error: { code: "web_ios_bridge_route_not_found" } });
    } catch (error) {
      sendJSON(res, 502, {
        ok: false,
        error: {
          code: "web_ios_bridge_failed",
          message: error instanceof Error ? error.message : String(error),
          hint: "Verify `CLI/.build/debug/triton sim list --json` works, and boot a simulator before requesting screenshots.",
        },
      });
    }
  };
}

async function collectHostTargets(tritonPath) {
  const ios = await runTritonCapture(tritonPath, ["sim", "list", "--json"], "ios");
  const android = await runTritonCapture(tritonPath, ["device", "list", "--platform", "android", "--json"], "android");
  const harmony = await runTritonCapture(tritonPath, ["device", "list", "--platform", "harmony", "--json"], "harmony");

  const iosTargets = ios.parsed ? mapTritonSimListToWebTargets(ios.parsed).simulators.map((target) => ({
    id: target.id,
    target: target.udid,
    name: target.name,
    platform: "ios",
    runtime: target.runtime,
    state: target.state,
    statusLabel: target.statusLabel,
    ready: target.isBooted,
    scope: "emulator",
    kind: "emulator",
    source: target.source,
    readonly: true,
  })) : [];
  const androidTargets = android.parsed ? mapTritonDeviceListToWebTargets(android.parsed, "android") : [];
  const harmonyTargets = harmony.parsed ? mapTritonDeviceListToWebTargets(harmony.parsed, "harmony") : [];
  const commandOutputs = [ios, android, harmony].map(({ parsed, ...output }) => output);

  return {
    ok: commandOutputs.every((output) => output.ok),
    capturedAt: new Date().toISOString(),
    source: {
      commands: commandOutputs.map((output) => output.command),
      runtimeScope: "host-emulator",
      readonly: true,
    },
    targets: [...iosTargets, ...androidTargets, ...harmonyTargets],
    commandOutputs,
  };
}

async function captureHostScreenshot(tritonPath, platform, target) {
  const outputDir = join(tmpdir(), `tritonkit-web-host-${randomUUID()}`);
  const outputPath = join(outputDir, "screenshot.bin");
  await mkdir(outputDir, { recursive: true });
  try {
    const args = platform === "ios"
      ? ["sim", "screenshot", "--simulator", target, "--output", outputPath, "--json"]
      : ["device", "screenshot", "--platform", platform, "--device", target, "--output", outputPath, "--json"];
    const payload = await runTritonJSON(tritonPath, args);
    const image = await readFile(outputPath);
    const dimensions = readImageDimensions(image);
    const mimeType = imageMimeType(image);
    return {
      ok: true,
      simulator: target,
      source: {
        command: `triton ${args.join(" ")}`,
        runtimeScope: platform === "ios" ? "host-simulator" : `host-${platform}`,
        readonly: true,
      },
      artifact: payload.artifact,
      pixelWidth: payload.pixelWidth ?? dimensions.width,
      pixelHeight: payload.pixelHeight ?? dimensions.height,
      dataUrl: `data:${mimeType};base64,${image.toString("base64")}`,
    };
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
}

async function runHostInput(tritonPath, input) {
  const action = input?.action;
  const platform = input?.platform;
  const target = input?.target;
  if (!["tap", "swipe"].includes(action) || !["ios", "android", "harmony"].includes(platform) || !target) {
    throw new Error("Expected host input with action tap|swipe, platform ios|android|harmony, and target");
  }

  if (platform === "ios") {
    return runTritonWebHostInput(tritonPath, input);
  }

  const args = action === "tap"
    ? buildTapArgs(input)
    : buildSwipeArgs(input);
  const result = await runCommand(tritonPath, args);
  return {
    ok: result.exitCode === 0,
    action,
    platform,
    target,
    command: `triton ${args.join(" ")}`,
    exitCode: result.exitCode,
    stdout: result.stdout,
    stderr: result.stderr,
    parsed: tryParseJSON(result.stdout),
    coordinateSpace: "framebuffer-pixels",
  };
}

export function normalizeIosRuntimeInput(input, appInfo) {
  const screenWidth = numericOrNull(appInfo?.screenWidth);
  const screenHeight = numericOrNull(appInfo?.screenHeight);
  if (!screenWidth || !screenHeight || !input.width || !input.height) {
    return input;
  }

  const scaleX = screenWidth / input.width;
  const scaleY = screenHeight / input.height;
  if (!Number.isFinite(scaleX) || !Number.isFinite(scaleY) || scaleX <= 0 || scaleY <= 0) {
    return input;
  }

  if (input.action === "tap") {
    return {
      ...input,
      x: clamp(Math.round(input.x * scaleX), 0, screenWidth),
      y: clamp(Math.round(input.y * scaleY), 0, screenHeight),
      width: screenWidth,
      height: screenHeight,
    };
  }

  return {
    ...input,
    startX: clamp(Math.round(input.startX * scaleX), 0, screenWidth),
    startY: clamp(Math.round(input.startY * scaleY), 0, screenHeight),
    endX: clamp(Math.round(input.endX * scaleX), 0, screenWidth),
    endY: clamp(Math.round(input.endY * scaleY), 0, screenHeight),
    width: screenWidth,
    height: screenHeight,
  };
}

async function runTritonWebHostInput(tritonPath, input) {
  const status = await ensureTritonWebServer(tritonPath);
  const target = `host:ios:${input.target}`;
  const inputPayload = buildTritonInputPayload(input);
  if (!status.serverReachable) {
    const error = {
      ok: false,
      error: {
        code: "server_unavailable",
        message: "Could not start or reach Triton server before dispatching iOS host input.",
        hint: `Run \`triton serve --host ${runtimeHost} --port ${runtimePort}\`, then retry.`,
      },
    };
    return {
      ok: false,
      action: input.action,
      platform: "ios",
      target: input.target,
      command: `triton serve POST /web/input?target=${target}`,
      exitCode: null,
      stdout: JSON.stringify(error),
      stderr: "",
      parsed: error,
      coordinateSpace: "framebuffer-pixels",
    };
  }

  const response = await fetch(`http://${runtimeHost}:${runtimePort}/web/input?target=${encodeURIComponent(target)}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(inputPayload),
    signal: AbortSignal.timeout(20_000),
  });
  const body = await response.text();
  const parsed = tryParseJSON(body) ?? { ok: response.ok, action: input.action };
  return {
    ok: response.ok && parsed?.ok !== false,
    action: input.action,
    platform: "ios",
    target: input.target,
    command: `triton serve POST /web/input?target=${target}`,
    exitCode: response.ok ? 0 : 1,
    stdout: body || JSON.stringify(parsed),
    stderr: "",
    parsed,
    coordinateSpace: "framebuffer-pixels",
  };
}

async function ensureTritonWebServer(tritonPath) {
  let status = await readTritonServerStatus();
  if (status.serverReachable) {
    return status;
  }

  if (!managedTritonServe || managedTritonServe.exitCode !== null) {
    managedTritonServe = spawn(tritonPath, ["serve", "--host", runtimeHost, "--port", String(runtimePort)], {
      cwd: bridgeRoot,
      detached: true,
      stdio: "ignore",
    });
    managedTritonServe.unref();
  }

  const deadline = Date.now() + 8000;
  while (Date.now() < deadline) {
    await delay(350);
    status = await readTritonServerStatus();
    if (status.serverReachable) {
      return status;
    }
  }
  return status;
}

async function readTritonServerStatus() {
  try {
    const response = await fetch(`http://${runtimeHost}:${runtimePort}/status`, {
      signal: AbortSignal.timeout(900),
    });
    return { serverReachable: response.ok };
  } catch {
    return { serverReachable: false };
  }
}

function delay(ms) {
  return new Promise((resolveDelay) => {
    setTimeout(resolveDelay, ms);
  });
}

function buildTritonInputPayload(input) {
  if (input.action === "tap") {
    return {
      type: "tap",
      x: input.x,
      y: input.y,
      width: input.width,
      height: input.height,
    };
  }
  return {
    type: "swipe",
    startX: input.startX,
    startY: input.startY,
    endX: input.endX,
    endY: input.endY,
    width: input.width,
    height: input.height,
    duration: input.duration,
  };
}

function numericOrNull(value) {
  const number = Number(value);
  return Number.isFinite(number) && number > 0 ? number : null;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function buildTapArgs(input) {
  assertNumber(input.x, "x");
  assertNumber(input.y, "y");
  const args = ["tap"];
  appendPlatformTargetArgs(args, input.platform, input.target);
  args.push("--x", String(Math.round(input.x)), "--y", String(Math.round(input.y)), "--json");
  return args;
}

function buildSwipeArgs(input) {
  for (const key of ["startX", "startY", "endX", "endY"]) {
    assertNumber(input[key], key);
  }
  const args = ["swipe"];
  appendPlatformTargetArgs(args, input.platform, input.target);
  args.push(
    "--start-x",
    String(Math.round(input.startX)),
    "--start-y",
    String(Math.round(input.startY)),
    "--end-x",
    String(Math.round(input.endX)),
    "--end-y",
    String(Math.round(input.endY)),
    "--json"
  );
  return args;
}

function appendPlatformTargetArgs(args, platform, target) {
  if (platform !== "ios") {
    args.push("--platform", platform);
  }
  args.push("--target", target);
}

function assertNumber(value, name) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error(`Expected numeric ${name}`);
  }
}

function readJSONBody(req) {
  return new Promise((resolveBody, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk.toString("utf8");
    });
    req.on("end", () => {
      try {
        resolveBody(JSON.parse(body || "{}"));
      } catch (error) {
        reject(error);
      }
    });
    req.on("error", reject);
  });
}

function resolveTritonBinary(root) {
  const candidates = [
    process.env.TRITONKIT_TRITON_BIN,
    join(root, "CLI", ".build", "debug", "triton"),
    join(root, "CLI", ".build", "arm64-apple-macosx", "debug", "triton"),
  ].filter(Boolean);

  const found = candidates.find((candidate) => existsSync(candidate));
  if (!found) {
    throw new Error("No triton binary found. Run `swift build --package-path CLI --product triton` first.");
  }
  return found;
}

async function runTritonJSON(tritonPath, args) {
  const result = await runCommand(tritonPath, args);
  if (result.exitCode !== 0) {
    throw new Error(result.stderr || result.stdout || `triton exited with ${result.exitCode}`);
  }
  try {
    return JSON.parse(result.stdout);
  } catch (error) {
    throw new Error(`Failed to parse triton JSON: ${error instanceof Error ? error.message : String(error)}`);
  }
}

async function runTritonCapture(tritonPath, args, platform) {
  const result = await runCommand(tritonPath, args);
  return {
    id: `${platform}-${Date.now()}-${Math.random().toString(16).slice(2)}`,
    platform,
    command: `triton ${args.join(" ")}`,
    ok: result.exitCode === 0,
    exitCode: result.exitCode,
    stdout: result.stdout,
    stderr: result.stderr,
    parsed: result.exitCode === 0 ? tryParseJSON(result.stdout) : null,
  };
}

function tryParseJSON(value) {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function imageMimeType(buffer) {
  if (buffer.length >= 8 && buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return "image/png";
  }
  if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return "image/jpeg";
  }
  return "application/octet-stream";
}

function readImageDimensions(buffer) {
  if (imageMimeType(buffer) === "image/png" && buffer.length >= 24) {
    return {
      width: buffer.readUInt32BE(16),
      height: buffer.readUInt32BE(20),
    };
  }
  if (imageMimeType(buffer) === "image/jpeg") {
    let offset = 2;
    while (offset + 9 < buffer.length) {
      if (buffer[offset] !== 0xff) break;
      const marker = buffer[offset + 1];
      const length = buffer.readUInt16BE(offset + 2);
      if (marker >= 0xc0 && marker <= 0xc3) {
        return {
          height: buffer.readUInt16BE(offset + 5),
          width: buffer.readUInt16BE(offset + 7),
        };
      }
      offset += 2 + length;
    }
  }
  return { width: null, height: null };
}

function runCommand(command, args) {
  return new Promise((resolveCommand, reject) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill("SIGTERM");
      reject(new Error(`Timed out running ${command} ${args.join(" ")}`));
    }, 20_000);

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString("utf8");
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString("utf8");
    });
    child.on("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
    child.on("close", (exitCode) => {
      clearTimeout(timer);
      resolveCommand({ exitCode: exitCode ?? 1, stdout, stderr });
    });
  });
}

function sendJSON(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.statusCode = statusCode;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Cache-Control", "no-store");
  res.end(body);
}

export function createStandaloneIosSimulatorBridgeServer(options = {}) {
  return createHttpServer(createIosSimulatorBridgeMiddleware(options));
}

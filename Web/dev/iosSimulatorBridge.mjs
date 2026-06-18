import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, readFile, rm } from "node:fs/promises";
import { createServer as createHttpServer } from "node:http";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";

const bridgeRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const defaultHostInputBaseURL = "http://127.0.0.1:19421";
let managedTritonServeProcess;

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
    .filter((target) => shouldExposeHostDeviceTarget(target))
    .map((target) => ({
      id: String(target.id ?? `${platform}:${target.target}`),
      target: String(target.target ?? ""),
      name: String(target.name ?? target.target ?? `${platform} emulator`),
      platform,
      appName: normalizeOptionalString(target.appName),
      bundleIdentifier: normalizeOptionalString(target.bundleIdentifier ?? target.bundleId ?? target.packageName ?? target.bundle),
      runtime: String(target.runtime ?? platform),
      state: String(target.state ?? "Ready"),
      statusLabel: String(target.state ?? "Ready"),
      ready: Boolean(target.ready),
      scope: String(target.scope ?? "emulator"),
      kind: String(target.kind ?? "emulator"),
      transport: normalizeOptionalString(target.transport),
      source: String(target.source ?? platform),
      readonly: true,
      blockedReasons: Array.isArray(target.blockedReasons) ? target.blockedReasons.map(String) : [],
      sensitive: Boolean(target.sensitive),
    }));
}

function shouldExposeHostDeviceTarget(target) {
  const scope = String(target.scope ?? "");
  const kind = String(target.kind ?? "");
  if (scope === "real" || kind === "real-device") {
    return Boolean(target.ready) && hasDirectRealDeviceConnection(target);
  }
  return Boolean(target.ready) && (scope === "emulator" || scope === "simulator" || kind === "emulator" || kind === "simulator");
}

function hasDirectRealDeviceConnection(target) {
  const transport = String(target.transport ?? "").toLowerCase();
  return transport === "wired" || transport === "usb";
}

export function createIosSimulatorBridgeMiddleware(options = {}) {
  const root = options.root ? resolve(options.root) : bridgeRoot;
  const tritonPath = options.tritonPath ? resolve(options.tritonPath) : resolveTritonBinary(root);
  const hostInputBaseURL = options.hostInputBaseURL || defaultHostInputBaseURL;

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
        if (url.searchParams.get("__tritonkit_mock_host_targets") === "request-failed") {
          sendJSON(res, 502, {
            ok: false,
            error: {
              code: "web_host_targets_forced_failure",
              message: "Forced /web/host-targets failure for dev browser smoke.",
            },
          });
          return;
        }
        const response = await collectHostTargets(tritonPath);
        sendJSON(res, 200, response);
        return;
      }

      if (url.pathname === "/web/host-logs") {
        const platform = url.searchParams.get("platform") || "ios";
        const target = url.searchParams.get("target") || "booted";
        if (platform !== "ios") {
          sendJSON(res, 501, {
            ok: false,
            error: {
              code: "web_host_logs_platform_not_supported",
              message: "Readonly host logs are currently only exposed for iOS Simulator targets.",
            },
          });
          return;
        }
        const response = await captureHostLogs(tritonPath, target);
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
        const scope = url.searchParams.get("scope") || "";
        const kind = url.searchParams.get("kind") || "";
        const source = url.searchParams.get("source") || "";
        try {
          const screenshot = await captureHostScreenshot(tritonPath, platform, target, { scope, kind, source });
          sendJSON(res, 200, screenshot);
        } catch (error) {
          sendJSON(res, 409, webHostRuntimeError(platform, { scope, kind, source }, error, "screenshot"));
        }
        return;
      }

      if (url.pathname === "/web/host-input" && req.method === "POST") {
        const platform = url.searchParams.get("platform") || "ios";
        const target = url.searchParams.get("target") || "local";
        const scope = url.searchParams.get("scope") || "";
        const kind = url.searchParams.get("kind") || "";
        const source = url.searchParams.get("source") || "";
        const body = await readRequestBody(req);
        const input = JSON.parse(body || "{}");
        try {
          const result = await dispatchHostInput(tritonPath, platform, target, input, {
            scope,
            kind,
            source,
            hostInputBaseURL,
            manageHostInputServer: !options.hostInputBaseURL,
          });
          sendJSON(res, 200, result);
        } catch (error) {
          sendJSON(res, 409, webHostRuntimeError(platform, { scope, kind, source }, error, "input"));
        }
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
  const captures = [];
  for (const plan of hostTargetCapturePlans()) {
    captures.push(await runTritonCapture(tritonPath, plan.args, plan.platform));
  }

  return mapTritonHostCapturesToWebTargets(captures);
}

function hostTargetCapturePlans() {
  return [
    { platform: "ios", args: ["sim", "list", "--json"] },
    { platform: "ios", args: ["device", "list", "--platform", "ios", "--scope", "real", "--json"] },
    { platform: "android", args: ["device", "list", "--platform", "android", "--scope", "emulator", "--json"] },
    { platform: "android", args: ["device", "list", "--platform", "android", "--scope", "real", "--json"] },
    { platform: "harmony", args: ["device", "list", "--platform", "harmony", "--scope", "emulator", "--json"] },
    { platform: "harmony", args: ["device", "list", "--platform", "harmony", "--scope", "real", "--json"] },
  ];
}

export function mapTritonHostCapturesToWebTargets(captures) {
  const targets = captures.flatMap((capture) => mapHostCaptureToWebTargets(capture));
  const commandOutputs = captures.map(({ parsed, ...output }) => output);

  return {
    ok: commandOutputs.every((output) => output.ok),
    capturedAt: new Date().toISOString(),
    source: {
      commands: commandOutputs.map((output) => output.command),
      runtimeScope: "host-device",
      readonly: true,
    },
    targets,
    commandOutputs,
  };
}

function mapHostCaptureToWebTargets(capture) {
  if (!capture?.parsed) return [];
  if (Array.isArray(capture.parsed.simulators)) {
    return mapTritonSimListToWebTargets(capture.parsed).simulators.map((target) => ({
      id: target.id,
      target: target.udid,
      name: target.name,
      platform: "ios",
      appName: normalizeOptionalString(target.appName),
      bundleIdentifier: normalizeOptionalString(target.bundleIdentifier ?? target.bundleId),
      runtime: target.runtime,
      state: target.state,
      statusLabel: target.statusLabel,
      ready: target.isBooted,
      scope: "simulator",
      kind: "simulator",
      source: target.source,
      readonly: true,
      blockedReasons: [],
      sensitive: false,
    }));
  }
  if (Array.isArray(capture.parsed.targets)) {
    return mapTritonDeviceListToWebTargets(capture.parsed, capture.platform);
  }
  return [];
}

function normalizeOptionalString(value) {
  if (value === undefined || value === null) {
    return null;
  }
  const text = String(value).trim();
  return text.length > 0 ? text : null;
}

async function captureHostScreenshot(tritonPath, platform, target, options = {}) {
  const outputDir = join(tmpdir(), `tritonkit-web-host-${randomUUID()}`);
  const outputPath = join(outputDir, isIOSRuntimeMirror(platform, options) ? "screenshot.png" : "screenshot.bin");
  await mkdir(outputDir, { recursive: true });
  try {
    const args = isIOSRuntimeMirror(platform, options)
      ? ["screenshot", "--output", outputPath, "--json"]
      : platform === "ios"
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
        runtimeScope: isIOSRuntimeMirror(platform, options) ? "app-runtime" : platform === "ios" ? "host-simulator" : `host-${platform}`,
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

function isIOSRuntimeMirror(platform, options = {}) {
  return platform === "ios" && (options.source === "runtime" || options.scope === "real" || options.kind === "real-device");
}

function webHostRuntimeError(platform, options, error, action) {
  const runtimeMirror = isIOSRuntimeMirror(platform, options);
  return {
    ok: false,
    error: {
      code: runtimeMirror ? "app_runtime_unavailable" : `web_host_${action}_failed`,
      message: error instanceof Error ? error.message : String(error),
      hint: runtimeMirror
        ? "Start `triton serve --host 127.0.0.1 --port 19421`, launch a Debug app that embeds TritonKit runtime, then retry the App runtime mirror."
        : "Verify the selected host target is ready and the platform screenshot/input command is supported.",
    },
  };
}

async function dispatchHostInput(tritonPath, platform, target, input, options = {}) {
  if (isWebHostInputTarget(platform, options)) {
    return dispatchHostTargetInput(tritonPath, platform, target, input, options);
  }
  if (!isIOSRuntimeMirror(platform, options)) {
    return {
      ok: false,
      action: String(input?.type ?? "input"),
      message: "Web host input is only enabled for iOS real-device App runtime mirror targets in this bridge.",
    };
  }
  const result = await runCommand(tritonPath, ["input", "--json", "--summary"], {
    stdin: `${JSON.stringify(input)}\n`,
  });
  if (result.exitCode !== 0) {
    throw new Error(result.stderr || result.stdout || `triton input exited with ${result.exitCode}`);
  }
  const lines = result.stdout.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  const first = lines.map(tryParseJSON).find((record) => record && typeof record === "object" && "ok" in record);
  if (!first) {
    throw new Error("triton input did not return a JSON input result");
  }
  return first;
}

function isWebHostInputTarget(platform, options = {}) {
  if (!["ios", "android", "harmony"].includes(platform)) return false;
  if (isIOSRuntimeMirror(platform, options)) return false;
  return options.scope === "simulator" ||
    options.scope === "emulator" ||
    options.source === "host" ||
    options.kind === "simulator" ||
    options.kind === "emulator";
}

async function dispatchHostTargetInput(tritonPath, platform, target, input, options = {}) {
  if (options.manageHostInputServer) {
    await ensureTritonServe(tritonPath, options.hostInputBaseURL || defaultHostInputBaseURL);
  }
  const targetID = `host:${platform}:${target}`;
  const url = new URL("/web/input", options.hostInputBaseURL || defaultHostInputBaseURL);
  url.searchParams.set("target", targetID);
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(input),
  });
  if (!response.ok) {
    throw new Error(await describeFetchBridgeError(response, "triton serve /web/input failed"));
  }
  return response.json();
}

async function ensureTritonServe(tritonPath, baseURL) {
  if (await canReachTritonServe(baseURL)) return;
  if (!managedTritonServeProcess || managedTritonServeProcess.exitCode !== null) {
    const url = new URL(baseURL);
    managedTritonServeProcess = spawn(tritonPath, [
      "serve",
      "--host",
      url.hostname,
      "--port",
      String(url.port || 19421),
    ], {
      stdio: "ignore",
    });
    managedTritonServeProcess.once("error", () => {});
  }

  const deadline = Date.now() + 3000;
  while (Date.now() < deadline) {
    if (await canReachTritonServe(baseURL)) return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`triton serve did not become ready at ${baseURL}`);
}

async function canReachTritonServe(baseURL) {
  try {
    const response = await fetch(new URL("/health", baseURL), { signal: AbortSignal.timeout(500) });
    return response.ok;
  } catch {
    return false;
  }
}

async function describeFetchBridgeError(response, fallback) {
  try {
    const payload = await response.json();
    const error = payload?.error;
    const parts = [error?.code, error?.message, error?.hint].filter(Boolean);
    if (parts.length > 0) return parts.join(" · ");
  } catch {
    // Fall back to the HTTP status below.
  }
  return `${fallback}: ${response.status}`;
}

async function captureHostLogs(tritonPath, target) {
  const outputDir = join(tmpdir(), `tritonkit-web-logs-${randomUUID()}`);
  const outputPath = join(outputDir, "host-logs.ndjson");
  await mkdir(outputDir, { recursive: true });
  try {
    const args = ["sim", "logs", "--simulator", target, "--output", outputPath, "--duration", "2", "--style", "ndjson", "--json"];
    await runTritonJSON(tritonPath, args);
    const raw = await readFile(outputPath, "utf8");
    const entries = parseHostLogEntries(raw);
    const capturedAt = resolveLogsCapturedAt(raw) ?? new Date().toISOString();
    return {
      ok: true,
      capturedAt,
      source: {
        command: redactArtifactPath(`triton ${args.join(" ")}`, outputPath),
        runtimeScope: "host-simulator",
        readonly: true,
      },
      entries,
    };
  } finally {
    await rm(outputDir, { recursive: true, force: true });
  }
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

function parseHostLogEntries(raw) {
  return raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line, index) => {
      const parsed = tryParseJSON(line);
      const timestamp = normalizeLogTimestamp(parsed) ?? null;
      return {
        id: `host-log-${index}`,
        time: formatLogTime(timestamp),
        level: normalizeLogLevel(parsed),
        message: normalizeLogMessage(parsed, line),
      };
    });
}

function resolveLogsCapturedAt(raw) {
  const lines = raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  const last = lines.at(-1);
  const parsed = last ? tryParseJSON(last) : null;
  return normalizeLogTimestamp(parsed);
}

function normalizeLogTimestamp(record) {
  if (!record || typeof record !== "object") return null;
  const candidates = [
    record.timestamp,
    record.date,
    record.time,
  ];
  for (const candidate of candidates) {
    if (typeof candidate === "string" && !Number.isNaN(Date.parse(candidate))) {
      return new Date(candidate).toISOString();
    }
  }
  return null;
}

function formatLogTime(isoTimestamp) {
  if (!isoTimestamp) return "--:--:--";
  return new Date(isoTimestamp).toLocaleTimeString("en-GB", { hour12: false, timeZone: "UTC" });
}

function normalizeLogLevel(record) {
  if (!record || typeof record !== "object") return "info";
  const value = [
    record.messageType,
    record.level,
    record.severity,
  ].find((candidate) => typeof candidate === "string");
  const normalized = String(value ?? "info").toLowerCase();
  if (normalized.includes("error") || normalized.includes("fault")) return "error";
  if (normalized.includes("warn")) return "warn";
  return "info";
}

function normalizeLogMessage(record, fallbackLine) {
  if (record && typeof record === "object") {
    const message = [
      record.eventMessage,
      record.message,
      record.msg,
    ].find((candidate) => typeof candidate === "string" && candidate.trim().length > 0);
    if (message) return message.trim();
  }
  return fallbackLine;
}

function redactArtifactPath(command, outputPath) {
  return command.replace(outputPath, "<tmp.ndjson>");
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

function runCommand(command, args, options = {}) {
  return new Promise((resolveCommand, reject) => {
    const child = spawn(command, args, { stdio: [options.stdin === undefined ? "ignore" : "pipe", "pipe", "pipe"] });
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
    if (options.stdin !== undefined) {
      child.stdin.end(options.stdin);
    }
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

function readRequestBody(req) {
  return new Promise((resolveBody, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk.toString("utf8");
    });
    req.on("end", () => resolveBody(body));
    req.on("error", reject);
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

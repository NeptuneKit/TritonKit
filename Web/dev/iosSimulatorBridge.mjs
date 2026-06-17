import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, readFile, rm } from "node:fs/promises";
import { createServer as createHttpServer } from "node:http";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";

const bridgeRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

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
      appName: normalizeOptionalString(target.appName),
      bundleIdentifier: normalizeOptionalString(target.bundleIdentifier ?? target.bundleId ?? target.packageName ?? target.bundle),
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
  const tritonPath = options.tritonPath ? resolve(options.tritonPath) : resolveTritonBinary(root);

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
        const screenshot = await captureHostScreenshot(tritonPath, platform, target);
        sendJSON(res, 200, screenshot);
        return;
      }

      if (url.pathname === "/web/host-input" && req.method === "POST") {
        sendJSON(res, 405, {
          ok: false,
          error: {
            code: "web_host_input_readonly",
            message: "TritonKit Web mock is readonly; use CLI or HTTP runtime contracts for host input.",
          },
        });
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

  return mapTritonHostCapturesToWebTargets([ios, android, harmony]);
}

export function mapTritonHostCapturesToWebTargets(captures) {
  const [ios, android, harmony] = captures;
  const iosTargets = ios?.parsed ? mapTritonSimListToWebTargets(ios.parsed).simulators.map((target) => ({
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
    scope: "emulator",
    kind: "emulator",
    source: target.source,
    readonly: true,
  })) : [];
  const androidTargets = android?.parsed ? mapTritonDeviceListToWebTargets(android.parsed, "android") : [];
  const harmonyTargets = harmony?.parsed ? mapTritonDeviceListToWebTargets(harmony.parsed, "harmony") : [];
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

function normalizeOptionalString(value) {
  if (value === undefined || value === null) {
    return null;
  }
  const text = String(value).trim();
  return text.length > 0 ? text : null;
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

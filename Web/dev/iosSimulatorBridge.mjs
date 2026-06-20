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
const defaultRuntimeDataBaseURL = "http://127.0.0.1:19421";
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
  return mapTritonDeviceListToWebTargetsWithRuntime(payload, platform);
}

function mapTritonDeviceListToWebTargetsWithRuntime(payload, platform, runtimeTargets = []) {
  if (!payload || !Array.isArray(payload.targets)) {
    throw new Error(`Expected triton device list payload with targets[] for ${platform}`);
  }

  return payload.targets
    .filter((target) => shouldExposeHostDeviceTarget(target, platform, runtimeTargets))
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
      source: isRealDeviceRuntimeVisible(target, platform, runtimeTargets) ? "runtime" : String(target.source ?? platform),
      readonly: true,
      blockedReasons: Array.isArray(target.blockedReasons) ? target.blockedReasons.map(String) : [],
      sensitive: Boolean(target.sensitive),
    }));
}

function shouldExposeHostDeviceTarget(target, platform, runtimeTargets = []) {
  const scope = String(target.scope ?? "");
  const kind = String(target.kind ?? "");
  if (scope === "real" || kind === "real-device") {
    return Boolean(target.ready) && (
      hasDirectRealDeviceConnection(target) ||
      isRealDeviceRuntimeVisible(target, platform, runtimeTargets)
    );
  }
  return Boolean(target.ready) && (scope === "emulator" || scope === "simulator" || kind === "emulator" || kind === "simulator");
}

function hasDirectRealDeviceConnection(target) {
  const transport = String(target.transport ?? "").toLowerCase();
  return transport === "wired" || transport === "usb";
}

function isRealDeviceRuntimeVisible(target, platform, runtimeTargets = []) {
  if (platform !== "ios") return false;
  const scope = String(target.scope ?? "");
  const kind = String(target.kind ?? "");
  if (scope !== "real" && kind !== "real-device") return false;
  const transport = String(target.transport ?? "").toLowerCase();
  if (transport !== "localnetwork" && transport !== "network") return false;
  if (Boolean(target.ready)) return true;
  return runtimeTargets.some((runtimeTarget) => {
    const runtimePlatform = String(runtimeTarget.platform ?? "").toLowerCase();
    const connected = runtimeTarget.connected !== false;
    const simulatorUDID = normalizeOptionalString(runtimeTarget.simulatorUDID);
    const activeHierarchy = runtimeTarget.activeHierarchyAvailable !== false || runtimeTarget.latestHierarchyAvailable !== false;
    return runtimePlatform === "ios" && connected && !simulatorUDID && activeHierarchy;
  });
}

export function createIosSimulatorBridgeMiddleware(options = {}) {
  const root = options.root ? resolve(options.root) : bridgeRoot;
  const tritonPath = options.tritonPath ? resolve(options.tritonPath) : resolveTritonBinary(root);
  const hostInputBaseURL = options.hostInputBaseURL || defaultHostInputBaseURL;
  const runtimeDataBaseURL = options.runtimeDataBaseURL || defaultRuntimeDataBaseURL;

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

      if (url.pathname === "/web/host-hierarchy") {
        const platform = url.searchParams.get("platform") || "ios";
        const target = url.searchParams.get("target") || "local";
        const scope = url.searchParams.get("scope") || undefined;
        const kind = url.searchParams.get("kind") || undefined;
        const source = url.searchParams.get("source") || undefined;
        if (!["GET", "POST"].includes(req.method ?? "GET")) {
          sendJSON(res, 405, {
            ok: false,
            error: {
              code: "web_host_hierarchy_method_not_allowed",
              message: "Host hierarchy capture only supports GET and POST.",
            },
          });
          return;
        }
        if (!["ios", "android", "harmony"].includes(platform)) {
          sendJSON(res, 501, {
            ok: false,
            error: {
              code: "web_host_hierarchy_platform_not_supported",
              message: `Readonly host hierarchy is not available for platform: ${platform}`,
            },
          });
          return;
        }
        try {
          sendJSON(res, 200, await captureHostHierarchy(tritonPath, platform, target, req.method ?? "GET", { runtimeDataBaseURL, scope, kind, source, target }));
        } catch (error) {
          sendJSON(res, 409, {
            ok: false,
            error: {
              code: "web_host_hierarchy_failed",
              message: error instanceof Error ? error.message : String(error),
            },
          });
        }
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
          const screenshot = await captureHostScreenshot(tritonPath, platform, target, { scope, kind, source, target });
          sendJSON(res, 200, screenshot);
        } catch (error) {
          sendJSON(res, 409, webHostRuntimeError(platform, { scope, kind, source, target }, error, "screenshot"));
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
            target,
            hostInputBaseURL,
            manageHostInputServer: !options.hostInputBaseURL,
          });
          sendJSON(res, 200, result);
        } catch (error) {
          sendJSON(res, 409, webHostRuntimeError(platform, { scope, kind, source, target }, error, "input"));
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
  captures.push(await runTritonCapture(tritonPath, ["list", "--json"], "runtime"));

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
  const runtimeTargets = captures.flatMap((capture) => {
    if (capture?.platform !== "runtime" || !Array.isArray(capture.parsed?.targets)) return [];
    return capture.parsed.targets;
  });
  const targets = captures.flatMap((capture) => mapHostCaptureToWebTargets(capture, runtimeTargets));
  const commandOutputs = captures.map(({ parsed, ...output }) => output);

  const requiredHostOutputs = commandOutputs.filter((output) => output.platform !== "runtime");

  return {
    ok: requiredHostOutputs.every((output) => output.ok),
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

function mapHostCaptureToWebTargets(capture, runtimeTargets = []) {
  if (!capture?.parsed) return [];
  if (capture.platform === "runtime") return [];
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
    return mapTritonDeviceListToWebTargetsWithRuntime(capture.parsed, capture.platform, runtimeTargets);
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
  const runtimeMirror = isIOSRuntimeMirror(platform, options);
  const outputPath = join(outputDir, runtimeMirror ? "screenshot.png" : "screenshot.bin");
  await mkdir(outputDir, { recursive: true });
  try {
    const runtimeTarget = runtimeMirror ? await resolveIOSRuntimeMirrorTarget(tritonPath, target, options) : null;
    const args = runtimeMirror
      ? ["screenshot", "--target", runtimeTarget, "--output", outputPath, "--json"]
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
        runtimeScope: runtimeMirror ? "app-runtime" : platform === "ios" ? "host-simulator" : `host-${platform}`,
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
  return platform === "ios" && (
    options.source === "runtime" ||
    options.scope === "real" ||
    options.kind === "real-device" ||
    String(options.target ?? "").startsWith("ios-real:")
  );
}

async function resolveIOSRuntimeMirrorTarget(tritonPath, hostTarget, options = {}) {
  const payload = await runTritonJSON(tritonPath, ["list", "--json"]);
  const runtimeTargets = Array.isArray(payload?.targets)
    ? payload.targets.filter((target) => String(target.platform ?? "").toLowerCase() === "ios" && target.connected !== false)
    : [];
  if (runtimeTargets.length === 0) {
    throw new Error("No connected iOS App runtime targets were reported by `triton list --json`.");
  }

  if (isIOSRealHostTarget(hostTarget, options)) {
    const realTargets = runtimeTargets.filter((target) => !normalizeOptionalString(target.simulatorUDID));
    if (realTargets.length === 1) return String(realTargets[0].id);
    if (realTargets.length > 1) {
      throw new Error(`Multiple connected iOS real-device App runtime targets are available: ${describeRuntimeTargets(realTargets)}.`);
    }
    const activeRuntimeTarget = runtimeTargets.find((target) =>
      target.activeHierarchyAvailable === true || target.latestHierarchyAvailable === true
    );
    if (activeRuntimeTarget) return String(activeRuntimeTarget.id);
    throw new Error(`No connected iOS real-device App runtime target matched host target ${hostTarget}.`);
  }

  const simulatorUDID = String(hostTarget ?? "").replace(/^sim:/, "");
  const simulatorTarget = runtimeTargets.find((target) => {
    const runtimeID = String(target.id ?? "");
    const runtimeSimulatorUDID = String(target.simulatorUDID ?? "");
    return runtimeSimulatorUDID === simulatorUDID || runtimeID === hostTarget || runtimeID.endsWith(simulatorUDID);
  });
  if (simulatorTarget) return String(simulatorTarget.id);
  if (runtimeTargets.length === 1) return String(runtimeTargets[0].id);
  throw new Error(`No connected iOS App runtime target matched host target ${hostTarget}. Available: ${describeRuntimeTargets(runtimeTargets)}.`);
}

function isIOSRealHostTarget(hostTarget, options = {}) {
  return options.scope === "real" ||
    options.kind === "real-device" ||
    String(hostTarget ?? options.target ?? "").startsWith("ios-real:");
}

function describeRuntimeTargets(targets) {
  return targets.map((target) => String(target.id ?? "<unknown>")).join(", ");
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
  const runtimeTarget = await resolveIOSRuntimeMirrorTarget(tritonPath, target, options);
  const result = await runCommand(tritonPath, ["input", "--target", runtimeTarget, "--json", "--summary"], {
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

async function captureHostHierarchy(tritonPath, platform, target, method = "GET", options = {}) {
  const runtimeMirror = isIOSRuntimeMirror(platform, options);
  const hierarchyTarget = runtimeMirror ? await resolveIOSRuntimeMirrorTarget(tritonPath, target, options) : target;
  const args = ["hierarchy", "--platform", platform, "--target", hierarchyTarget, "--json"];
  let payload;
  try {
    payload = await runTritonJSON(tritonPath, args);
  } catch (error) {
    if (platform === "ios" && shouldFallbackToLegacyIosHierarchy(error)) {
      const legacyPayload = await runTritonJSON(tritonPath, ["hierarchy", "--target", hierarchyTarget, "--json"]);
      return attachHierarchyCaptureControl(
        await mapLegacyIosHierarchyToHostResponse(legacyPayload, target, {
          runtimeDataBaseURL: options.runtimeDataBaseURL || defaultRuntimeDataBaseURL,
        }),
        method,
        target
      );
    }
    throw error;
  }
  if (!payload || payload.ok !== true || !payload.scene) {
    throw new Error("triton hierarchy did not return a valid HostHierarchyResponse scene");
  }
  return attachHierarchyCaptureControl(
    await hydrateHierarchySceneNodeSlices(payload, options.runtimeDataBaseURL || defaultRuntimeDataBaseURL),
    method,
    target
  );
}

function shouldFallbackToLegacyIosHierarchy(error) {
  const message = error instanceof Error ? error.message : String(error);
  return message.includes("Unknown option '--platform'") ||
    message.includes("unknown option '--platform'") ||
    message.includes('"code" : "target_not_found"') ||
    message.includes('"code":"target_not_found"') ||
    message.includes("Target not found");
}

function attachHierarchyCaptureControl(payload, method, target) {
  const captureEvidence = hierarchyCaptureEvidence(payload, target);
  return {
    ...payload,
    control: {
      action: "hierarchy.capture",
      entrypoint: "web-dev-bridge",
      method,
      readonly: true,
      mutatesApp: false,
    },
    captureEvidence,
  };
}

function hierarchyCaptureEvidence(payload, target) {
  const nodes = Array.isArray(payload?.scene?.nodes) ? payload.scene.nodes : [];
  const visualSources = nodes.flatMap(hierarchyNodeVisualSources);
  const dataUrlCount = visualSources.filter((source) => source.kind !== "styledFallback" && Boolean(source.dataUrl)).length;
  const realSliceCount = visualSources.filter((source) => source.kind !== "styledFallback" && Boolean(source.dataUrl || source.dataRef)).length;
  const failedNodeCount = visualSources.filter((source) => source.kind !== "styledFallback" && Boolean(source.dataRef) && !source.dataUrl).length;
  const sourceCommand = String(payload?.source?.command ?? "");
  return {
    captureId: hierarchyCaptureId(payload, target, nodes.length, dataUrlCount),
    capturedAt: payload?.capturedAt ?? new Date().toISOString(),
    target: {
      id: target,
      ambiguous: false,
    },
    source: {
      kind: sourceCommand.includes("--platform") ? "triton-hierarchy" : "fallback",
      nodeSlice: realSliceCount > 0 ? "real" : nodes.length > 0 ? "styled" : "none",
      screenshotSlice: dataUrlCount > 0 ? "real" : "none",
    },
    hydration: {
      dataUrlCount,
      nodeCount: nodes.length,
      failedNodeCount,
    },
  };
}

function hierarchyCaptureId(payload, target, nodeCount, dataUrlCount) {
  const capturedAt = String(payload?.capturedAt ?? "");
  return Buffer.from([target, capturedAt, nodeCount, dataUrlCount].join("|")).toString("base64url").slice(0, 24);
}

async function mapLegacyIosHierarchyToHostResponse(payload, target, options = {}) {
  const viewport = resolveLegacyIosViewport(payload);
  const nodes = [];
  const rootItems = Array.isArray(payload?.displayItems) ? payload.displayItems : [];
  for (const item of rootItems) {
    await appendLegacyIosNode(nodes, item, undefined, viewport, options);
  }
  if (nodes.length === 0) {
    throw new Error("legacy iOS hierarchy did not include displayItems[]");
  }
  return {
    ok: true,
    capturedAt: new Date().toISOString(),
    source: {
      command: `triton hierarchy --target ${target} --json`,
      runtimeScope: "runtime-tree",
      readonly: true,
    },
    scene: {
      platform: "ios",
      rootId: nodes[0].id,
      viewport,
      nodes,
      controllerContext: resolveLegacyIosControllerContext(payload?.controllerContext, nodes),
    },
  };
}

function resolveLegacyIosControllerContext(context, nodes) {
  if (context && (context.activeControllerName || Array.isArray(context.stack) && context.stack.length > 0)) {
    return context;
  }
  const controllerNodes = nodes.filter(isLegacyIosControllerNode);
  const active = controllerNodes
    .filter((node) => node.visible)
    .filter((node) => !/UITrackingElementWindowController|UIEditingOverlayViewController/.test(node.type))
    .sort((first, second) => {
      const area = second.frame.width * second.frame.height - first.frame.width * first.frame.height;
      return area === 0 ? second.depth - first.depth : area;
    })[0] ?? controllerNodes[0];
  if (!active) return undefined;
  const entry = legacyIosControllerEntryFromNode(active);
  return {
    activeControllerId: entry.id,
    activeControllerName: entry.name,
    activeControllerClassName: entry.className,
    stack: [entry],
    source: "scene-controller-node-fallback",
  };
}

function isLegacyIosControllerNode(node) {
  return node?.source === "runtime-controller" ||
    node?.raw?.role === "UIViewController" ||
    String(node?.id ?? "").startsWith("ios:controller:");
}

function legacyIosControllerEntryFromNode(node) {
  return {
    id: node.id,
    oid: Number.isFinite(Number(node.raw?.identifier)) ? Number(node.raw.identifier) : undefined,
    className: node.type,
    name: String(node.name ?? node.type).replace(/#\d+$/, "") || node.type,
  };
}

function resolveLegacyIosViewport(payload) {
  const appInfo = payload?.appInfo && typeof payload.appInfo === "object" ? payload.appInfo : {};
  const root = Array.isArray(payload?.displayItems) ? payload.displayItems[0] : null;
  const rootFrame = parseLegacyFrame(root?.frame);
  return {
    width: positiveNumber(appInfo.screenWidth) ?? rootFrame.width ?? 390,
    height: positiveNumber(appInfo.screenHeight) ?? rootFrame.height ?? 844,
  };
}

async function appendLegacyIosNode(nodes, item, parentId, viewport, options, context = {}) {
  if (!item || typeof item !== "object") return;
  const frame = parseLegacyFrame(item.frame);
  if (!frame) return;
  const oid = item.layerObject?.oid ?? item.viewObject?.oid ?? nodes.length;
  const controllerOID = item.hostViewControllerObject?.oid;
  const shouldInsertController = controllerOID !== undefined && controllerOID !== null && controllerOID !== context.currentControllerOID;
  const controllerId = shouldInsertController ? `ios:controller:${controllerOID}` : null;
  const depthOffset = Number.isFinite(Number(context.depthOffset)) ? Number(context.depthOffset) : 0;
  if (shouldInsertController) {
    const controllerType = legacyIosControllerClassName(item);
    const controllerName = legacyIosControllerNodeName(item);
    const controllerFrame = clampFrameToViewport(frame, viewport);
    nodes.push({
      id: controllerId,
      parentId,
      type: controllerType,
      name: controllerName,
      frame: controllerFrame,
      depth: Math.max(0, legacyIosNodeDepth(item, parentId) + depthOffset),
      visible: item.isHidden !== true,
      interactive: false,
      color: "#b48cff",
      source: "runtime-controller",
      style: {
        display: "controller",
        text: controllerName,
        backgroundColor: "#b48cff",
        alpha: typeof item.alpha === "number" ? item.alpha : 1,
      },
      visualSources: [
        {
          kind: "styledFallback",
          rect: controllerFrame,
          reason: "UIViewController host object has no standalone view snapshot",
        },
      ],
      raw: {
        platform: "ios",
        source: "runtime-tree",
        role: "UIViewController",
        identifier: String(controllerOID),
      },
      renderHints: {
        preferredMode: "structure",
        fallbackMode: "wireframe",
        quality: "semantic",
      },
    });
  }
  const type = legacyIosClassName(item);
  const id = `ios:runtime:${oid}`;
  const depth = legacyIosNodeDepth(item, parentId) + depthOffset + (shouldInsertController ? 1 : 0);
  const alpha = typeof item.alpha === "number" ? item.alpha : 1;
  const visible = item.isHidden !== true && alpha > 0.01 && frame.width > 0 && frame.height > 0;
  const interactive = legacyIosNodeIsInteractive(type, item);
  const color = legacyIosNodeColor(item, interactive);
  const slice = await legacyIosNodeSlice(item, options);
  const visualSources = hierarchyNodeVisualSources({ frame: clampFrameToViewport(frame, viewport), slice });
  nodes.push({
    id,
    parentId: controllerId ?? parentId,
    type,
    name: legacyIosNodeName(type, oid, item),
    frame: clampFrameToViewport(frame, viewport),
    depth,
    visible,
    interactive,
    color,
    source: "runtime-tree",
    style: legacyIosNodeStyle(item, color, alpha),
    slice,
    visualSources,
    renderHints: legacyIosRenderHints(type, frame, viewport, slice),
  });
  const children = Array.isArray(item.subitems) ? item.subitems : [];
  const childContext = {
    depthOffset: depthOffset + (shouldInsertController ? 1 : 0),
    currentControllerOID: controllerOID ?? context.currentControllerOID,
  };
  for (const child of children) {
    await appendLegacyIosNode(nodes, child, id, viewport, options, childContext);
  }
}

function legacyIosNodeDepth(item, parentId) {
  return Number.isFinite(Number(item.indentLevel)) ? Number(item.indentLevel) : parentId ? 1 : 0;
}

function parseLegacyFrame(value) {
  if (!Array.isArray(value) || !Array.isArray(value[0]) || !Array.isArray(value[1])) return null;
  const x = Number(value[0][0]);
  const y = Number(value[0][1]);
  const width = Number(value[1][0]);
  const height = Number(value[1][1]);
  if (![x, y, width, height].every(Number.isFinite)) return null;
  return { x, y, width, height };
}

function positiveNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) && number > 0 ? number : null;
}

function legacyIosClassName(item) {
  return String(
    item.layerObject?.classChainList?.[0] ??
      item.viewObject?.classChainList?.[0] ??
      item.hostViewControllerObject?.classChainList?.[0] ??
      "UIView"
  );
}

function legacyIosControllerClassName(item) {
  return String(item.hostViewControllerObject?.classChainList?.[0] ?? "UIViewController");
}

function legacyIosControllerNodeName(item) {
  const type = legacyIosControllerClassName(item);
  const oid = item.hostViewControllerObject?.oid ?? "unknown";
  const shortType = type.split(".").at(-1) ?? type;
  return `${shortType}#${oid}`;
}

function legacyIosNodeName(type, oid, item) {
  if (item.representedAsKeyWindow) return "keyWindow";
  const title = normalizeOptionalString(item.customDisplayTitle);
  if (title) return title;
  const shortType = type.split(".").at(-1) ?? type;
  return `${shortType}#${oid}`;
}

function legacyIosNodeIsInteractive(type, item) {
  return /(button|control|cell|collection|table|scroll|textfield|textview|switch|slider|segmented)/i.test(type) ||
    (Array.isArray(item.eventHandlers) && item.eventHandlers.length > 0);
}

function legacyIosNodeColor(item, interactive) {
  const background = item.backgroundColor;
  if (background && typeof background === "object" && typeof background.red === "number") {
    const alpha = typeof background.alpha === "number" ? background.alpha : 1;
    if (alpha > 0.03) {
      return rgbFloatToHex(background.red, background.green, background.blue);
    }
  }
  return interactive ? "#2563eb" : "#94a3b8";
}

function rgbFloatToHex(red, green, blue) {
  const toHex = (value) => Math.max(0, Math.min(255, Math.round(Number(value ?? 0) * 255))).toString(16).padStart(2, "0");
  return `#${toHex(red)}${toHex(green)}${toHex(blue)}`;
}

function legacyIosNodeStyle(item, color, alpha) {
  const title = normalizeOptionalString(item.customDisplayTitle);
  return {
    display: legacyIosStyleDisplay(legacyIosClassName(item)),
    text: title ?? undefined,
    backgroundColor: color,
    alpha,
  };
}

function legacyIosStyleDisplay(type) {
  if (/button|control/i.test(type)) return "button";
  if (/label|text/i.test(type)) return "text";
  if (/cell|card/i.test(type)) return "card";
  if (/collection|table|scroll|stack/i.test(type)) return "container";
  if (/navigation|bar/i.test(type)) return "bar";
  return "view";
}

async function legacyIosNodeSlice(item, options) {
  const screenshotRef = normalizeOptionalString(item.screenshotRef);
  if (!screenshotRef) {
    return {
      available: false,
      mode: "node-screenshot-ref",
      source: "triton-runtime-data-ref",
    };
  }
  const dataUrl = await fetchRuntimeDataRefDataUrl(options.runtimeDataBaseURL || defaultRuntimeDataBaseURL, screenshotRef);
  if (!dataUrl) {
    return {
      available: false,
      mode: "node-screenshot-ref",
      source: "triton-runtime-data-ref",
    };
  }
  return {
    available: true,
    mode: "node-screenshot-ref",
    source: "triton-runtime-data-ref",
    dataRef: screenshotRef,
    dataUrl,
  };
}

async function fetchRuntimeDataRefDataUrl(baseURL, screenshotRef) {
  if (typeof fetch !== "function") return null;
  const url = runtimeDataRefURL(baseURL, screenshotRef);
  try {
    const response = await fetch(url);
    if (!response.ok) return null;
    const buffer = Buffer.from(await response.arrayBuffer());
    if (buffer.length === 0) return null;
    const mimeType = imageMimeType(buffer);
    if (!mimeType.startsWith("image/")) return null;
    return `data:${mimeType};base64,${buffer.toString("base64")}`;
  } catch {
    return null;
  }
}

async function hydrateHierarchySceneNodeSlices(payload, runtimeDataBaseURL) {
  const nodes = Array.isArray(payload?.scene?.nodes) ? payload.scene.nodes : [];
  if (nodes.length === 0) return payload;
  const hydratedNodes = await Promise.all(nodes.map(async (node) => {
    const hydratedSlice = await hydrateHierarchyNodeSlice(node, runtimeDataBaseURL);
    const visualSources = await hydrateHierarchyVisualSources({ ...node, slice: hydratedSlice }, runtimeDataBaseURL);
    return {
      ...node,
      slice: hydratedSlice,
      visualSources,
      renderHints: {
        preferredMode: visualSources.some((source) => source.kind === "layerOwnContents") ? "slice" : node.renderHints?.preferredMode ?? "style",
        fallbackMode: node.renderHints?.fallbackMode ?? "style",
        quality: visualSources.some((source) => source.dataUrl || source.dataRef) ? "exact" : node.renderHints?.quality ?? "approximate",
      },
    };
  }));
  return {
    ...payload,
    scene: {
      ...payload.scene,
      nodes: hydratedNodes,
    },
  };
}

async function hydrateHierarchyNodeSlice(node, runtimeDataBaseURL) {
  const dataRef = normalizeOptionalString(node?.slice?.dataRef);
  if (!node?.slice?.available || node.slice.dataUrl || !dataRef) {
    return node?.slice;
  }
  const dataUrl = await fetchRuntimeDataRefDataUrl(runtimeDataBaseURL, dataRef);
  if (!dataUrl) return node.slice;
  return {
    ...node.slice,
    dataUrl,
  };
}

async function hydrateHierarchyVisualSources(node, runtimeDataBaseURL) {
  const sources = hierarchyNodeVisualSources(node);
  return Promise.all(sources.map(async (source) => {
    const dataRef = normalizeOptionalString(source?.dataRef);
    if (!dataRef || source.dataUrl || source.kind === "styledFallback") return source;
    const dataUrl = await fetchRuntimeDataRefDataUrl(runtimeDataBaseURL, dataRef);
    return dataUrl ? { ...source, dataUrl } : source;
  }));
}

function hierarchyNodeVisualSources(node) {
  const explicit = Array.isArray(node?.visualSources) ? node.visualSources.filter(Boolean) : [];
  const legacy = legacySliceVisualSource(node);
  if (!legacy) return explicit;
  const alreadyRepresented = explicit.some((source) =>
    source?.kind === "subtreeSnapshot" &&
    (normalizeOptionalString(source.dataRef) === legacy.dataRef || normalizeOptionalString(source.dataUrl) === legacy.dataUrl)
  );
  return alreadyRepresented ? explicit : [...explicit, legacy];
}

function legacySliceVisualSource(node) {
  if (!node?.slice?.available) return null;
  const dataRef = normalizeOptionalString(node.slice.dataRef);
  const dataUrl = normalizeOptionalString(node.slice.dataUrl);
  if (!dataRef && !dataUrl) return null;
  const rect = node.frame && typeof node.frame === "object"
    ? node.frame
    : { x: 0, y: 0, width: 1, height: 1 };
  return {
    kind: "subtreeSnapshot",
    dataRef: dataRef || undefined,
    dataUrl: dataUrl || undefined,
    rect,
    capturedBy: node.slice.source === "triton-runtime-data-ref" ? "UIView.render" : "unknown",
  };
}

function runtimeDataRefURL(baseURL, screenshotRef) {
  const normalizedBaseURL = String(baseURL || defaultRuntimeDataBaseURL).replace(/\/+$/, "");
  const normalizedRef = String(screenshotRef).replace(/^\/+/, "");
  if (normalizedRef.startsWith("data/")) {
    return `${normalizedBaseURL}/${normalizedRef.split("/").map(encodeURIComponent).join("/")}`;
  }
  return `${normalizedBaseURL}/data/${encodeURIComponent(normalizedRef)}`;
}

function legacyIosRenderHints(type, frame, viewport, slice) {
  if (slice?.available && slice.dataUrl) {
    return { preferredMode: "slice", fallbackMode: "style", quality: "exact" };
  }
  const isFullscreen = frame.width >= viewport.width * 0.96 && frame.height >= viewport.height * 0.9;
  if (isFullscreen && /window|transition|shadow|container|wrapper|root/i.test(type)) {
    return { preferredMode: "wireframe", fallbackMode: "wireframe", quality: "fallback" };
  }
  return { preferredMode: "slice", fallbackMode: "style", quality: "approximate" };
}

function clampFrameToViewport(frame, viewport) {
  return {
    x: Math.max(0, Math.min(viewport.width, frame.x)),
    y: Math.max(0, Math.min(viewport.height, frame.y)),
    width: Math.max(0, Math.min(viewport.width, frame.width)),
    height: Math.max(0, Math.min(viewport.height, frame.height)),
  };
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

import { runTritonCapture } from "./process.mjs";

export async function collectHostTargets(tritonPath) {
  const captures = [];
  for (const plan of hostTargetCapturePlans()) {
    captures.push(await runTritonCapture(tritonPath, plan.args, plan.platform));
  }
  captures.push(await runTritonCapture(tritonPath, ["list", "--json"], "runtime"));

  return mapTritonHostCapturesToWebTargets(captures);
}

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
    if (platform === "android" || platform === "harmony") {
      return Boolean(target.ready);
    }
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

export function hostTargetCapturePlans() {
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
    return mapTritonSimListToWebTargets(capture.parsed).simulators
      .filter((target) => isIOSSimulatorWebAvailable(target, runtimeTargets))
      .map((target) => ({
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

function isIOSSimulatorWebAvailable(target, runtimeTargets = []) {
  const iosRuntimeTargets = runtimeTargets.filter((runtimeTarget) => {
    const platform = String(runtimeTarget.platform ?? "").toLowerCase();
    return platform === "ios" && runtimeTarget.connected !== false;
  });
  if (iosRuntimeTargets.length === 0) return false;

  const matched = iosRuntimeTargets.some((runtimeTarget) => normalizeOptionalString(runtimeTarget.simulatorUDID) === target.udid);
  if (matched) return true;

  const unscoped = iosRuntimeTargets.filter((runtimeTarget) => !normalizeOptionalString(runtimeTarget.simulatorUDID));
  return unscoped.length === 1 && iosRuntimeTargets.length === 1;
}

function normalizeOptionalString(value) {
  if (value === undefined || value === null) {
    return null;
  }
  const text = String(value).trim();
  return text.length > 0 ? text : null;
}

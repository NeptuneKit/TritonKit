import { runTritonJSON } from "./process.mjs";

export function isIOSRuntimeMirror(platform, options = {}) {
  return platform === "ios" && (
    options.source === "runtime" ||
    options.scope === "real" ||
    options.kind === "real-device" ||
    String(options.target ?? "").startsWith("ios-real:")
  );
}

export async function resolveIOSRuntimeMirrorTarget(tritonPath, hostTarget, options = {}) {
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
    throw new Error(`No connected iOS real-device App runtime target matched host target ${hostTarget}. Available iOS runtime targets: ${describeRuntimeTargets(runtimeTargets)}.`);
  }

  const exactTarget = runtimeTargets.find((target) => String(target.id ?? "") === String(hostTarget ?? ""));
  if (exactTarget) return String(exactTarget.id);

  const simulatorUDID = simulatorUDIDFromTarget(hostTarget);
  const simulatorTargets = runtimeTargets.filter((target) => {
    const runtimeSimulatorUDID = String(target.simulatorUDID ?? "");
    return runtimeSimulatorUDID === simulatorUDID;
  });
  if (simulatorTargets.length === 1) return String(simulatorTargets[0].id);
  if (simulatorTargets.length > 1) {
    throw new Error(`Multiple connected iOS simulator App runtime targets matched ${hostTarget}: ${describeRuntimeTargets(simulatorTargets)}.`);
  }
  if (options.source === "runtime" && runtimeTargets.length === 1) return String(runtimeTargets[0].id);
  throw new Error(`No connected iOS App runtime target matched host target ${hostTarget}. Available: ${describeRuntimeTargets(runtimeTargets)}.`);
}

export function webHostRuntimeError(platform, options, error, action) {
  const runtimeMirror = isIOSRuntimeMirror(platform, options);
  return {
    ok: false,
    error: {
      code: runtimeMirror ? "app_runtime_unavailable" : `web_host_${action}_failed`,
      message: error instanceof Error ? error.message : String(error),
      hint: runtimeMirror
        ? "Triton Web does not auto-start a LAN-facing runtime server; use an explicit approved CLI/HTTP device workflow."
        : "Verify the selected host target is ready and the platform screenshot/input command is supported.",
    },
  };
}

function isIOSRealHostTarget(hostTarget, options = {}) {
  return options.scope === "real" ||
    options.kind === "real-device" ||
    String(hostTarget ?? options.target ?? "").startsWith("ios-real:");
}

function describeRuntimeTargets(targets) {
  return targets.map((target) => String(target.id ?? "<unknown>")).join(", ");
}

function simulatorUDIDFromTarget(target) {
  const text = String(target ?? "").replace(/^sim:/, "").replace(/^triton:ios-simulator:/, "");
  return text.split("/app:")[0];
}

function normalizeOptionalString(value) {
  if (value === undefined || value === null) {
    return null;
  }
  const text = String(value).trim();
  return text.length > 0 ? text : null;
}

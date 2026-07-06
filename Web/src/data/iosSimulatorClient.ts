import type { DeviceTarget } from "../types";

export async function fetchHostTargets() {
  const registry = await fetchJSON("/web/target-registry");
  if (registry?.ok && Array.isArray(registry.targets)) {
    return {
      sourceCommands: ["triton serve /web/target-registry"],
      targets: registry.targets
        .filter((target: any) => target.mirror?.state !== "host_offline")
        .map(mapRegistryTarget),
    };
  }

  const legacy = await fetchJSON("/web/host-targets");
  return {
    capturedAt: legacy?.capturedAt,
    sourceCommands: legacy?.source?.commands ?? [],
    targets: Array.isArray(legacy?.targets) ? legacy.targets.map(mapLegacyTarget) : [],
  };
}

async function fetchJSON(url: string) {
  try {
    const response = await fetch(url);
    if (!response.ok) return null;
    return await response.json();
  } catch {
    return null;
  }
}

function mapRegistryTarget(target: any): DeviceTarget {
  const host = target.host ?? {};
  const runtime = target.runtime ?? {};
  const diagnosis = target.diagnosis ?? {};
  const transportDiagnostics = target.transportDiagnostics ?? [];
  const ready = target.mirror?.state === "ready";
  const blockedReasons = [
    diagnosis.code,
    ...transportDiagnostics.map((item: any) => item.code),
  ].filter(Boolean);

  return {
    id: target.id,
    name: host.name ?? target.id,
    platform: target.platform,
    device: host.name ?? target.id,
    appName: runtime.appBundleId ?? target.nextAction?.title ?? "App runtime unavailable",
    bundleId: runtime.appBundleId ?? host.target ?? target.id,
    os: host.runtime ?? "",
    status: ready ? "ready" : "limited",
    statusLabel: ready ? "ready" : diagnosis.code ?? target.mirror?.state ?? "limited",
    transport: host.transport ?? runtime.transport ?? "unknown",
    screenshotTone: ready ? "live" : "limited",
    screenSize: "",
    fps: 0,
    latencyMs: 0,
    proxyMode: "off",
    proxyLabel: "off",
    hierarchyNodes: 0,
    lastAction: target.nextAction?.title ?? diagnosis.message ?? "",
    actionResult: ready ? "ok" : "warning",
    accent: "#1677FF",
    Icon: (() => null) as any,
    realSource: host.scope === "real" ? "ios-real-device" : "ios-simulator",
    scope: host.scope,
    kind: host.kind,
    targetSelector: host.target,
    blockedReasons,
    canScreenshot: ready,
    screenshotSource: host.scope === "real" ? "runtime" : "host",
    readonly: true,
  };
}

function mapLegacyTarget(target: any): DeviceTarget {
  return {
    id: target.id,
    name: target.name,
    platform: target.platform,
    device: target.name,
    appName: target.appName ?? "",
    bundleId: target.bundleIdentifier ?? target.target,
    os: target.runtime ?? "",
    status: target.ready ? "ready" : "limited",
    statusLabel: target.ready ? "ready" : target.statusLabel ?? "limited",
    transport: target.source ?? "simctl",
    screenshotTone: "host",
    screenSize: "",
    fps: 0,
    latencyMs: 0,
    proxyMode: "off",
    proxyLabel: "off",
    hierarchyNodes: 0,
    lastAction: "",
    actionResult: target.ready ? "ok" : "warning",
    accent: "#1677FF",
    Icon: (() => null) as any,
    realSource: "ios-simulator",
    scope: target.scope,
    kind: target.kind,
    targetSelector: target.target,
    blockedReasons: target.blockedReasons ?? [],
    canScreenshot: target.ready,
    screenshotSource: "host",
    readonly: target.readonly,
  };
}

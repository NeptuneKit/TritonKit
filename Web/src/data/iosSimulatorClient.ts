import { MonitorSmartphone, Smartphone, TabletSmartphone } from "lucide-react";
import type {
  BridgeCommandOutput,
  DeviceTarget,
  HierarchyScene,
  HostHierarchyResponse,
  HostTargetLogsResponse,
  HostTargetsResponse,
  HostWebTarget,
  IosSimulatorScreenshotResponse,
  IosSimulatorTargetsResponse,
} from "../types";

export async function fetchHostTargets(): Promise<{
  targets: DeviceTarget[];
  capturedAt: string;
  sourceCommands: string[];
  commandOutputs: BridgeCommandOutput[];
}> {
  if (resolveForcedHostTargetsMode() === "request-failed") {
    throw new Error("Host targets request failed: 502");
  }
  const response = await fetch(resolveHostTargetsRequestPath(), { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Host targets request failed: ${response.status}`);
  }
  const payload = (await response.json()) as HostTargetsResponse;
  return {
    targets: payload.targets.filter(shouldExposeHostWebTarget).map(mapHostTargetToDeviceTarget),
    capturedAt: payload.capturedAt,
    sourceCommands: payload.source.commands,
    commandOutputs: payload.commandOutputs,
  };
}

export async function fetchIosSimulatorTargets(): Promise<{
  targets: DeviceTarget[];
  capturedAt: string;
  sourceCommand: string;
}> {
  const response = await fetch("/web/ios-simulator/targets", { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`iOS Simulator targets request failed: ${response.status}`);
  }
  const payload = (await response.json()) as IosSimulatorTargetsResponse;
  return {
    targets: payload.simulators.map(mapIosSimulatorToDeviceTarget),
    capturedAt: payload.capturedAt,
    sourceCommand: payload.source.command,
  };
}

export async function fetchIosSimulatorScreenshot(simulator: string): Promise<IosSimulatorScreenshotResponse> {
  const params = new URLSearchParams({ simulator });
  const response = await fetch(`/web/ios-simulator/screenshot?${params.toString()}`, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`iOS Simulator screenshot request failed: ${response.status}`);
  }
  return (await response.json()) as IosSimulatorScreenshotResponse;
}

export async function fetchHostScreenshot(target: DeviceTarget): Promise<IosSimulatorScreenshotResponse> {
  const params = new URLSearchParams({
    platform: target.platform,
    target: target.targetSelector ?? target.udid ?? target.id,
  });
  if (target.scope) params.set("scope", target.scope);
  if (target.kind) params.set("kind", target.kind);
  if (target.screenshotSource) params.set("source", target.screenshotSource);
  const response = await fetch(`/web/host-screenshot?${params.toString()}`, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(await describeBridgeError(response, "Host screenshot request failed"));
  }
  return (await response.json()) as IosSimulatorScreenshotResponse;
}

export type HostInputResponse = {
  ok: boolean;
  action?: string;
  message?: string;
  targetClassName?: string;
  matchedClassName?: string;
  activationClassName?: string;
};

export async function sendHostInput(target: DeviceTarget, input: Record<string, unknown>): Promise<HostInputResponse> {
  const params = new URLSearchParams({
    platform: target.platform,
    target: target.targetSelector ?? target.udid ?? target.id,
  });
  if (target.scope) params.set("scope", target.scope);
  if (target.kind) params.set("kind", target.kind);
  if (target.screenshotSource) params.set("source", target.screenshotSource);
  const response = await fetch(`/web/host-input?${params.toString()}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(input),
  });
  if (!response.ok) {
    throw new Error(await describeBridgeError(response, "Host input request failed"));
  }
  return (await response.json()) as HostInputResponse;
}

export async function fetchHostLogs(target: DeviceTarget): Promise<HostTargetLogsResponse> {
  const params = new URLSearchParams({
    platform: target.platform,
    target: target.targetSelector ?? target.udid ?? target.id,
  });
  const response = await fetch(`/web/host-logs?${params.toString()}`, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Host logs request failed: ${response.status}`);
  }
  return (await response.json()) as HostTargetLogsResponse;
}

export async function fetchHostHierarchy(target: DeviceTarget): Promise<HierarchyScene> {
  const payload = await fetchHostHierarchyResponse(target);
  return payload.scene;
}

export async function fetchHostHierarchyResponse(
  target: DeviceTarget,
  options: { method?: "GET" | "POST" } = {}
): Promise<HostHierarchyResponse> {
  const params = new URLSearchParams({
    platform: target.platform,
    target: target.targetSelector ?? target.udid ?? target.id,
  });
  if (target.scope) params.set("scope", target.scope);
  if (target.kind) params.set("kind", target.kind);
  if (target.screenshotSource) params.set("source", target.screenshotSource);
  const response = await fetch(`/web/host-hierarchy?${params.toString()}`, {
    cache: "no-store",
    method: options.method ?? "GET",
  });
  if (!response.ok) {
    throw new Error(await describeBridgeError(response, "Host hierarchy request failed"));
  }
  return (await response.json()) as HostHierarchyResponse;
}

async function describeBridgeError(response: Response, fallback: string) {
  try {
    const payload = (await response.json()) as { error?: { code?: string; message?: string; hint?: string } };
    const parts = [payload.error?.code, payload.error?.message, payload.error?.hint].filter(Boolean);
    if (parts.length > 0) {
      return parts.join(" · ");
    }
  } catch {
    // Fall back to the HTTP status below.
  }
  return `${fallback}: ${response.status}`;
}

function mapIosSimulatorToDeviceTarget(simulator: IosSimulatorTargetsResponse["simulators"][number]): DeviceTarget {
  const isBooted = simulator.isBooted;
  const isAvailable = simulator.isAvailable;
  const status = isBooted ? "ready" : isAvailable ? "limited" : "busy";
  return {
    id: simulator.id,
    name: simulator.name,
    platform: "ios",
    device: simulator.name,
    appName: isBooted ? `前台 App 未暴露 · ${simulator.name}` : "Simulator",
    bundleId: formatUnknownTargetIdentity(simulator.udid),
    os: simulator.runtime,
    status,
    statusLabel: simulator.statusLabel,
    transport: "triton sim list --json",
    screenshotTone: "ios-screen",
    screenSize: isBooted ? "Awaiting framebuffer" : "Not booted",
    fps: isBooted ? 1 : 0,
    latencyMs: 0,
    proxyMode: "off",
    proxyLabel: "Readonly host state",
    hierarchyNodes: 0,
    lastAction: isBooted ? "Ready for readonly screenshot" : "Boot simulator via CLI before screenshot",
    actionResult: isBooted ? "ok" : "warning",
    accent: isBooted ? "#64d26a" : "#8bb6ff",
    Icon: Smartphone,
    realSource: "ios-simulator",
    scope: "simulator",
    kind: "simulator",
    targetSelector: simulator.udid,
    udid: simulator.udid,
    runtimeIdentifier: simulator.runtimeIdentifier,
    deviceTypeIdentifier: simulator.deviceTypeIdentifier,
    canScreenshot: simulator.canScreenshot,
    frameOrientation: inferPlaceholderOrientation(simulator.deviceTypeIdentifier),
    readonly: true,
  };
}

function mapHostTargetToDeviceTarget(target: HostWebTarget): DeviceTarget {
  const hostAppName = normalizeHostIdentity(target.appName);
  const hostBundleIdentifier = normalizeHostIdentity(target.bundleIdentifier);
  const isRealDevice = isHostRealDevice(target);
  const status = hostTargetStatus(target);
  const fallbackAppName = fallbackHostAppName(target, isRealDevice);

  if (target.platform === "ios") {
    return {
      id: target.id,
      name: target.name,
      platform: "ios",
      device: target.name,
      appName: hostAppName ?? fallbackAppName,
      bundleId: hostBundleIdentifier ?? formatUnknownTargetIdentity(target.target),
      os: target.runtime,
      status,
      statusLabel: target.statusLabel,
      transport: isRealDevice ? "triton device list --platform ios --scope real --json" : "triton sim list --json",
      screenshotTone: "ios-screen",
      screenSize: isRealDevice ? "App runtime framebuffer" : "Awaiting framebuffer",
      fps: isRealDevice ? 1 : 1,
      latencyMs: 0,
      proxyMode: "off",
      proxyLabel: "Readonly host state",
      hierarchyNodes: 0,
      lastAction: isRealDevice ? "Ready for App runtime mirror" : "Ready for readonly screenshot",
      actionResult: target.ready ? "ok" : "warning",
      accent: target.ready ? "#64d26a" : "#f59e0b",
      Icon: Smartphone,
      realSource: isRealDevice ? "ios-real-device" : "ios-simulator",
      scope: target.scope,
      kind: target.kind,
      targetSelector: target.target,
      udid: target.target,
      blockedReasons: target.blockedReasons ?? [],
      sensitive: target.sensitive,
      canScreenshot: target.ready,
      canInput: target.ready,
      screenshotSource: isRealDevice ? "runtime" : "host",
      frameOrientation: "portrait",
      readonly: true,
    };
  }

  const isAndroid = target.platform === "android";
  const platform = target.platform;
  return {
    id: target.id,
    name: target.name,
    platform: target.platform,
    device: target.target,
    appName: hostAppName ?? fallbackAppName,
    bundleId: hostBundleIdentifier ?? formatUnknownTargetIdentity(target.target),
    os: target.runtime || (isAndroid ? "Android" : "Harmony"),
    status,
    statusLabel: target.statusLabel,
    transport: `triton device list --platform ${platform} --scope ${isRealDevice ? "real" : "emulator"} --json`,
    screenshotTone: isAndroid ? "android-screen" : "harmony-screen",
    screenSize: isRealDevice ? "真机画面未接入" : "Awaiting framebuffer",
    fps: 0,
    latencyMs: 0,
    proxyMode: "off",
    proxyLabel: isRealDevice ? "Host real device target" : "Host emulator target",
    hierarchyNodes: 0,
    lastAction: isRealDevice ? "Real device listed by readonly Triton discovery" : "Ready for readonly screenshot",
    actionResult: target.ready ? "ok" : "warning",
    accent: target.ready ? (isAndroid ? "#32d583" : "#cc3d5a") : "#f59e0b",
    Icon: isAndroid ? MonitorSmartphone : TabletSmartphone,
    realSource: isRealDevice
      ? isAndroid ? "android-real-device" : "harmony-real-device"
      : isAndroid ? "android-emulator" : "harmony-emulator",
    scope: target.scope,
    kind: target.kind,
    targetSelector: target.target,
    blockedReasons: target.blockedReasons ?? [],
    sensitive: target.sensitive,
    canScreenshot: !isRealDevice && target.ready,
    canInput: !isRealDevice && target.ready,
    screenshotSource: "host",
    frameOrientation: "portrait",
    readonly: true,
  };
}

function isHostRealDevice(target: HostWebTarget) {
  return target.scope === "real" || target.kind === "real-device";
}

function fallbackHostAppName(target: HostWebTarget, isRealDevice: boolean) {
  if (target.platform === "ios" && isRealDevice) {
    return "App runtime 镜像";
  }
  return `前台 App 未暴露 · ${target.name}`;
}

function shouldExposeHostWebTarget(target: HostWebTarget) {
  if (isHostRealDevice(target)) {
    return target.ready && hasDirectRealDeviceConnection(target);
  }
  return target.ready;
}

function hasDirectRealDeviceConnection(target: HostWebTarget) {
  const transport = target.transport?.toLowerCase();
  return transport === "wired" || transport === "usb";
}

function hostTargetStatus(target: HostWebTarget) {
  if (target.ready) return "ready" as const;
  const state = target.state.toLowerCase();
  if (state.includes("offline") || state.includes("shutdown") || state.includes("disconnected")) {
    return "busy" as const;
  }
  return "limited" as const;
}

function normalizeHostIdentity(value?: string | null) {
  const text = value?.trim();
  return text && text.length > 0 ? text : undefined;
}

function resolveHostTargetsRequestPath() {
  return "/web/host-targets";
}

function resolveForcedHostTargetsMode() {
  if (!import.meta.env.DEV || typeof window === "undefined") {
    return null;
  }

  const currentParams = new URLSearchParams(window.location.search);
  const forcedMode = currentParams.get("__tritonkit_mock_host_targets");
  return forcedMode === "request-failed" ? forcedMode : null;
}

function formatUnknownTargetIdentity(value?: string | null) {
  const text = value?.trim();
  if (!text) {
    return "Target 未暴露";
  }
  return `Target ${text}`;
}

function inferPlaceholderOrientation(deviceTypeIdentifier: string) {
  if (/iPhone|iPod/.test(deviceTypeIdentifier)) {
    return "portrait" as const;
  }
  if (/iPad/.test(deviceTypeIdentifier)) {
    return "portrait" as const;
  }
  return "unknown" as const;
}

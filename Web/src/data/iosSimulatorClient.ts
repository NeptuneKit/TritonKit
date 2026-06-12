import { MonitorSmartphone, Smartphone, TabletSmartphone } from "lucide-react";
import type {
  BridgeCommandOutput,
  DeviceTarget,
  HostInputRequest,
  HostInputResponse,
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
  const response = await fetch("/web/host-targets", { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Host targets request failed: ${response.status}`);
  }
  const payload = (await response.json()) as HostTargetsResponse;
  return {
    targets: payload.targets.map(mapHostTargetToDeviceTarget),
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
  const response = await fetch(`/web/host-screenshot?${params.toString()}`, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Host screenshot request failed: ${response.status}`);
  }
  return (await response.json()) as IosSimulatorScreenshotResponse;
}

export async function sendHostInput(input: HostInputRequest): Promise<HostInputResponse> {
  const response = await fetch("/web/host-input", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  if (!response.ok) {
    throw new Error(`Host input request failed: ${response.status}`);
  }
  return (await response.json()) as HostInputResponse;
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
    appName: isBooted ? "SpringBoard" : "Simulator",
    bundleId: simulator.udid,
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
  if (target.platform === "ios") {
    return {
      id: target.id,
      name: target.name,
      platform: "ios",
      device: target.name,
      appName: "SpringBoard",
      bundleId: target.target,
      os: target.runtime,
      status: "ready",
      statusLabel: target.statusLabel,
      transport: "triton sim list --json",
      screenshotTone: "ios-screen",
      screenSize: "Awaiting framebuffer",
      fps: 1,
      latencyMs: 0,
      proxyMode: "off",
      proxyLabel: "Readonly host state",
      hierarchyNodes: 0,
      lastAction: "Ready for screenshot and Triton input",
      actionResult: "ok",
      accent: "#64d26a",
      Icon: Smartphone,
      realSource: "ios-simulator",
      targetSelector: target.target,
      udid: target.target,
      canScreenshot: true,
      frameOrientation: "portrait",
      readonly: false,
    };
  }

  const isAndroid = target.platform === "android";
  return {
    id: target.id,
    name: target.name,
    platform: target.platform,
    device: target.target,
    appName: isAndroid ? "Android Emulator" : "Harmony Emulator",
    bundleId: target.id,
    os: target.runtime || (isAndroid ? "Android" : "Harmony"),
    status: "ready",
    statusLabel: target.statusLabel,
    transport: isAndroid ? "triton device list --platform android --json" : "triton device list --platform harmony --json",
    screenshotTone: isAndroid ? "android-screen" : "harmony-screen",
    screenSize: "Awaiting framebuffer",
    fps: 0,
    latencyMs: 0,
    proxyMode: "off",
    proxyLabel: "Host emulator target",
    hierarchyNodes: 0,
    lastAction: "Ready for screenshot and Triton input",
    actionResult: "ok",
    accent: isAndroid ? "#32d583" : "#cc3d5a",
    Icon: isAndroid ? MonitorSmartphone : TabletSmartphone,
    realSource: isAndroid ? "android-emulator" : "harmony-emulator",
    targetSelector: target.target,
    canScreenshot: true,
    frameOrientation: "portrait",
    readonly: false,
  };
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

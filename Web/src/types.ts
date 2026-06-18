import type { LucideIcon } from "lucide-react";

export type DevicePlatform = "ios" | "android" | "harmony";

export type DeviceStatus = "ready" | "busy" | "limited";

export type ProxyMode = "record" | "mock" | "blocked" | "off";

export type DeviceFrameOrientation = "portrait" | "landscape" | "unknown";

export type DeviceTarget = {
  id: string;
  name: string;
  platform: DevicePlatform;
  device: string;
  appName: string;
  bundleId: string;
  os: string;
  status: DeviceStatus;
  statusLabel: string;
  transport: string;
  screenshotTone: string;
  screenSize: string;
  fps: number;
  latencyMs: number;
  proxyMode: ProxyMode;
  proxyLabel: string;
  hierarchyNodes: number;
  lastAction: string;
  actionResult: "ok" | "warning" | "failed";
  accent: string;
  Icon: LucideIcon;
  realSource?: "ios-simulator" | "ios-real-device" | "android-emulator" | "android-real-device" | "harmony-emulator" | "harmony-real-device";
  scope?: "simulator" | "emulator" | "real" | string;
  kind?: "simulator" | "emulator" | "real-device" | string;
  targetSelector?: string;
  udid?: string;
  blockedReasons?: string[];
  sensitive?: boolean;
  runtimeIdentifier?: string;
  deviceTypeIdentifier?: string;
  canScreenshot?: boolean;
  canInput?: boolean;
  screenshotSource?: "host" | "runtime";
  screenshotDataUrl?: string;
  screenshotPixelWidth?: number | null;
  screenshotPixelHeight?: number | null;
  frameOrientation?: DeviceFrameOrientation;
  readonly?: boolean;
};

export type BridgeCommandOutput = {
  id: string;
  platform: DevicePlatform | "host";
  command: string;
  ok: boolean;
  exitCode: number | null;
  stdout: string;
  stderr: string;
};

export type IosSimulatorWebTarget = {
  id: string;
  udid: string;
  name: string;
  platform: string;
  runtime: string;
  runtimeIdentifier: string;
  deviceTypeIdentifier: string;
  state: string;
  statusLabel: string;
  isAvailable: boolean;
  isBooted: boolean;
  canScreenshot: boolean;
  source: string;
  readonly: boolean;
};

export type IosSimulatorTargetsResponse = {
  ok: boolean;
  capturedAt: string;
  source: {
    command: string;
    runtimeScope: string;
    readonly: boolean;
  };
  simulators: IosSimulatorWebTarget[];
};

export type HostWebTarget = {
  id: string;
  target: string;
  name: string;
  platform: DevicePlatform;
  appName?: string | null;
  bundleIdentifier?: string | null;
  runtime: string;
  state: string;
  statusLabel: string;
  ready: boolean;
  scope: string;
  kind: string;
  transport?: string | null;
  source: string;
  readonly: boolean;
  blockedReasons?: string[];
  sensitive?: boolean;
};

export type HostTargetsResponse = {
  ok: boolean;
  capturedAt: string;
  source: {
    commands: string[];
    runtimeScope: string;
    readonly: boolean;
  };
  targets: HostWebTarget[];
  commandOutputs: BridgeCommandOutput[];
};

export type HostTargetLogsResponse = {
  ok: boolean;
  capturedAt: string;
  source: {
    command: string;
    runtimeScope: string;
    readonly: boolean;
  };
  entries: LogEntry[];
};

export type IosSimulatorScreenshotResponse = {
  ok: boolean;
  simulator: string;
  source: {
    command: string;
    runtimeScope: string;
    readonly: boolean;
  };
  artifact: string;
  pixelWidth: number | null;
  pixelHeight: number | null;
  dataUrl: string;
};

export type NetworkEvent = {
  id: string;
  method: "GET" | "POST" | "PUT";
  path: string;
  status: number;
  latencyMs: number;
  mode: ProxyMode;
};

export type LogEntry = {
  id: string;
  time: string;
  level: "info" | "warn" | "error";
  message: string;
};

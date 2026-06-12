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
  realSource?: "ios-simulator" | "android-emulator" | "harmony-emulator";
  targetSelector?: string;
  udid?: string;
  runtimeIdentifier?: string;
  deviceTypeIdentifier?: string;
  canScreenshot?: boolean;
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
  source: string;
  readonly: boolean;
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

export type HostInputRequest =
  | {
      action: "tap";
      platform: DevicePlatform;
      target: string;
      x: number;
      y: number;
      width?: number;
      height?: number;
    }
  | {
      action: "swipe";
      platform: DevicePlatform;
      target: string;
      startX: number;
      startY: number;
      endX: number;
      endY: number;
      width?: number;
      height?: number;
      duration?: number;
    };

export type HostInputResponse = {
  ok: boolean;
  action: "tap" | "swipe";
  platform: DevicePlatform;
  target: string;
  command: string;
  exitCode: number | null;
  stdout: string;
  stderr: string;
  parsed: unknown;
  coordinateSpace?: "runtime-points" | "framebuffer-pixels";
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

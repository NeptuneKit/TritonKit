import type { LucideIcon } from "lucide-react";

export type DevicePlatform = "ios" | "android" | "harmony";

export type DeviceStatus = "ready" | "busy" | "limited";

export type ProxyMode = "record" | "mock" | "blocked" | "off";

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

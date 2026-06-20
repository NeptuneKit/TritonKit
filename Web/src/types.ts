import type { LucideIcon } from "lucide-react";

export type DevicePlatform = "ios" | "android" | "harmony";

export type DeviceStatus = "ready" | "busy" | "limited";

export type ProxyMode = "record" | "mock" | "blocked" | "off";

export type DeviceFrameOrientation = "portrait" | "landscape" | "unknown";

export type HierarchyFrame = {
  x: number;
  y: number;
  width: number;
  height: number;
};

export type HierarchyPoint = {
  x: number;
  y: number;
};

export type HierarchySize = {
  width: number;
  height: number;
};

export type HierarchyLayerMetadata = {
  bounds: HierarchyFrame;
  position: HierarchyPoint;
  anchorPoint: HierarchyPoint;
  zPosition: number;
  transform?: number[];
  sublayerTransform?: number[];
  masksToBounds: boolean;
  cornerRadius: number;
  opacity: number;
  isHidden: boolean;
  contentsScale?: number;
  contentsGravity?: string;
  contentsRect?: HierarchyFrame;
  borderWidth?: number;
  borderColor?: string;
  shadowOpacity?: number;
  shadowRadius?: number;
  shadowOffset?: HierarchySize;
  shadowColor?: string;
};

export type HierarchyViewMetadata = {
  className?: string;
  isHidden?: boolean;
  alpha?: number;
  isUserInteractionEnabled?: boolean;
  accessibilityIdentifier?: string;
  accessibilityLabel?: string;
};

export type HierarchyVisualSource =
  | {
      kind: "subtreeSnapshot";
      dataUrl?: string;
      dataRef?: string;
      rect: HierarchyFrame;
      capturedBy: "UIView.render" | "CALayer.render" | "drawHierarchy" | "unknown";
    }
  | {
      kind: "layerOwnContents";
      dataUrl?: string;
      dataRef?: string;
      rect: HierarchyFrame;
      contentsScale?: number;
      contentsGravity?: string;
      contentsRect?: HierarchyFrame;
    }
  | {
      kind: "mainScreenshotCrop";
      dataUrl?: string;
      dataRef?: string;
      rect: HierarchyFrame;
    }
  | {
      kind: "styledFallback";
      reason: string;
    };

export type HierarchyLayerNode = {
  id: string;
  parentId?: string | null;
  type: string;
  className?: string;
  name: string;
  frame: HierarchyFrame;
  depth: number;
  visible: boolean;
  interactive: boolean;
  color: string;
  source?: string;
  view?: HierarchyViewMetadata;
  layer?: HierarchyLayerMetadata;
  visualSources?: HierarchyVisualSource[];
  slice?: {
    available?: boolean;
    dataRef?: string;
    dataUrl?: string;
    mode?: string;
    source?: string;
  };
  style?: {
    display?: string;
    text?: string;
    backgroundColor?: string;
    foregroundColor?: string;
    alpha?: number;
    cornerRadius?: number;
  };
  raw?: {
    platform?: string;
    source?: string;
    role?: string;
    identifier?: string;
  };
  renderHints?: {
    preferredMode?: "slice" | "style" | "fallback" | "wireframe" | string;
    fallbackMode?: "style" | "fallback" | "wireframe" | string;
    quality?: "exact" | "approximate" | "fallback" | string;
  };
};

export type HierarchyControllerEntry = {
  id?: string;
  oid?: number;
  className: string;
  name: string;
  title?: string;
};

export type HierarchyControllerContext = {
  activeControllerId?: string;
  activeControllerName?: string;
  activeControllerClassName?: string;
  stack: HierarchyControllerEntry[];
  source: string;
};

export type HierarchyScene = {
  platform: DevicePlatform;
  rootId: string;
  viewport: {
    width: number;
    height: number;
  };
  nodes: HierarchyLayerNode[];
  controllerContext?: HierarchyControllerContext;
};

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

export type HostHierarchyResponse = {
  ok: boolean;
  capturedAt: string;
  source: {
    command: string;
    runtimeScope: string;
    readonly: boolean;
  };
  control?: {
    action: "hierarchy.capture" | string;
    entrypoint: "web-dev-bridge" | string;
    method: "GET" | "POST" | string;
    readonly: boolean;
    mutatesApp: boolean;
  };
  captureEvidence?: {
    captureId: string;
    capturedAt: string;
    target: {
      id?: string;
      bundleId?: string;
      processId?: number;
      appName?: string;
      ambiguous?: boolean;
    };
    source: {
      kind: "triton-hierarchy" | "fallback";
      nodeSlice: "real" | "styled" | "none";
      screenshotSlice: "real" | "none";
    };
    hydration: {
      dataUrlCount: number;
      nodeCount: number;
      failedNodeCount: number;
    };
  };
  scene: HierarchyScene;
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

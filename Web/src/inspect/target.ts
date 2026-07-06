import type { DeviceTarget, WebInputCapability } from "../types";

export type InspectTarget = {
  key: string;
  platform: DeviceTarget["platform"];
  target: string;
  name: string;
  scope?: string;
  kind?: string;
  screenshotSource?: "host" | "runtime";
  hierarchySource?: "host" | "runtime";
  inputCapabilities: WebInputCapability[];
};

export function inspectTargetFromDeviceTarget(target: DeviceTarget): InspectTarget {
  const inspectTarget = {
    platform: target.platform,
    target: target.targetSelector ?? target.udid ?? target.id,
    name: target.name,
    scope: target.scope,
    kind: target.kind,
    screenshotSource: target.screenshotSource,
    hierarchySource: hierarchySourceForTarget(target),
    inputCapabilities: target.inputCapabilities ?? [],
  };

  return {
    ...inspectTarget,
    key: inspectTargetKey(inspectTarget),
  };
}

export function inspectTargetKey(target: Omit<InspectTarget, "key" | "name" | "inputCapabilities">) {
  return [
    target.platform,
    target.scope ?? "unknown",
    target.kind ?? "unknown",
    target.target,
    target.hierarchySource ?? "default",
  ].map(encodeURIComponent).join(":");
}

export function hierarchySourceForTarget(target: Pick<DeviceTarget, "platform" | "scope" | "kind" | "targetSelector" | "id" | "screenshotSource">) {
  if (target.platform !== "ios") return undefined;
  if (target.scope === "real" || target.kind === "real-device" || (target.targetSelector ?? target.id).startsWith("ios-real:")) {
    return "runtime";
  }
  return target.screenshotSource ?? "host";
}

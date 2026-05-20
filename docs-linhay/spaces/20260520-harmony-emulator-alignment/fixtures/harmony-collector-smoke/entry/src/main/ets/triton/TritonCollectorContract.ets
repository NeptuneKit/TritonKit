export interface TritonCollectorManifest {
  schemaVersion: number;
  platform: string;
  transport: string;
  runtimeMode: string;
  enabled: boolean;
  capabilities: string[];
  endpointPath: string;
}

export interface TritonCollectorConfiguration {
  enabled: boolean;
  runtimeMode: string;
  endpointPath: string;
  redactionPolicy: string;
  allowScreenshots: boolean;
  includesScreenshotData: boolean;
}

export interface TritonCollectorSnapshotMetadata {
  platform: string;
  appBundleName: string;
  abilityName: string;
  pageName: string;
  route: string;
  geometryWidth: number;
  geometryHeight: number;
  screenshotFormat: string;
  screenshotDataRef: string;
  redactionPolicy: string;
  redactionStatus: string;
}

export const tritonDebugManifest: TritonCollectorManifest = {
  schemaVersion: 1,
  platform: 'harmony',
  transport: 'embedded-websocket',
  runtimeMode: 'debug',
  enabled: true,
  capabilities: [
    'app-info',
    'view-snapshot',
    'accessibility',
    'geometry',
    'screenshot-metadata',
  ],
  endpointPath: '/tritonkit/collector',
};

export const tritonReleaseManifest: TritonCollectorManifest = {
  schemaVersion: 1,
  platform: 'harmony',
  transport: 'embedded-websocket',
  runtimeMode: 'release',
  enabled: false,
  capabilities: [],
  endpointPath: '/tritonkit/collector',
};

export const tritonReleaseConfiguration: TritonCollectorConfiguration = {
  enabled: false,
  runtimeMode: 'release',
  endpointPath: '/tritonkit/collector',
  redactionPolicy: 'summary',
  allowScreenshots: false,
  includesScreenshotData: false,
};

export const tritonSnapshotMetadata: TritonCollectorSnapshotMetadata = {
  platform: 'harmony',
  appBundleName: 'com.neptunekit.tritonkit.collectorsmoke',
  abilityName: 'EntryAbility',
  pageName: 'CollectorSmokePage',
  route: '/collector-smoke',
  geometryWidth: 360,
  geometryHeight: 780,
  screenshotFormat: 'png',
  screenshotDataRef: 'artifacts/harmony-collector-smoke.png',
  redactionPolicy: 'summary',
  redactionStatus: 'redacted',
};

export function tritonDebugSummary(): string {
  return `${tritonDebugManifest.platform}|${tritonDebugManifest.transport}|enabled=${tritonDebugManifest.enabled}`;
}

export function tritonCapabilitySummary(): string {
  return tritonDebugManifest.capabilities.join(',');
}

export function tritonReleaseSummary(): string {
  return `releaseEnabled=${tritonReleaseManifest.enabled}|capabilities=${tritonReleaseManifest.capabilities.length}|screenshots=${tritonReleaseConfiguration.allowScreenshots}`;
}

export function tritonSnapshotSummary(): string {
  return `${tritonSnapshotMetadata.appBundleName}|${tritonSnapshotMetadata.abilityName}|${tritonSnapshotMetadata.route}|${tritonSnapshotMetadata.screenshotFormat}|dataRef=${tritonSnapshotMetadata.screenshotDataRef}`;
}

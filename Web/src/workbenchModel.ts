import type {
  WorkspaceAppMapPathSummary,
  WorkspaceCommandSuggestion,
  WorkspaceWorkbenchDTO,
} from "./types";

export type WorkbenchTone = "success" | "warning" | "error" | "processing" | "default";

export type WorkbenchOverviewItem = {
  key: string;
  label: string;
  value: string;
  tone: WorkbenchTone;
};

export type WorkbenchPathRow = {
  key: string;
  pathId: string;
  name: string;
  status: WorkspaceAppMapPathSummary["status"];
  confirmed: boolean;
  replayable: boolean;
  requiresVLM: boolean;
  health: WorkspaceAppMapPathSummary["health"];
  sourceRuns: string[];
  primaryCommand: string | null;
};

export type WorkbenchCommandRow = WorkspaceCommandSuggestion & {
  source: "run" | "path";
};

export function getWorkbenchOverviewItems(workbench: WorkspaceWorkbenchDTO): WorkbenchOverviewItem[] {
  const { run } = workbench;
  const map = run.appMap;
  return [
    {
      key: "run",
      label: "Run",
      value: `${run.runId} · ${run.status}`,
      tone: run.status === "passed" ? "success" : run.status === "failed" ? "error" : "processing",
    },
    {
      key: "app",
      label: "App",
      value: `${run.app.name} · ${run.app.bundleId}`,
      tone: "default",
    },
    {
      key: "target",
      label: "Target",
      value: `${run.target.platform}/${run.target.scope} · ${run.target.name}`,
      tone: "default",
    },
    {
      key: "providers",
      label: "Providers",
      value: `${run.llmEnabled ? "LLM on" : "LLM off"} · ${run.vlmEnabled ? "VLM on" : "VLM off"} · ${run.providersReady ? "ready" : "not ready"}`,
      tone: run.providersReady ? "success" : "warning",
    },
    {
      key: "atlas",
      label: "Atlas",
      value: `${map.screenCount} screens · ${map.stateCount} states · ${map.transitionCount} transitions · ${map.pathCount} paths`,
      tone: map.coverageStatus === "covered" ? "success" : "warning",
    },
    {
      key: "latestPause",
      label: "Latest pause",
      value: run.latestPause?.reason ?? "none",
      tone: run.latestPause ? "warning" : "success",
    },
  ];
}

export function getWorkbenchPathRows(workbench: WorkspaceWorkbenchDTO): WorkbenchPathRow[] {
  return workbench.paths.map((path) => ({
    key: path.pathId,
    pathId: path.pathId,
    name: path.name,
    status: path.status,
    confirmed: path.confirmed,
    replayable: path.replayable,
    requiresVLM: path.requiresVLM,
    health: path.health,
    sourceRuns: [...path.sourceRuns],
    primaryCommand: path.suggestedCommands.find((command) => command.key.includes("run"))?.command ?? null,
  }));
}

export function getWorkbenchSuggestedCommands(workbench: WorkspaceWorkbenchDTO): WorkbenchCommandRow[] {
  const runCommands: WorkbenchCommandRow[] = workbench.run.suggestedCommands.map((command) => ({
    ...command,
    source: "run",
  }));
  const firstReplayablePath = workbench.paths.find((path) => path.replayable && path.suggestedCommands.length > 0);
  const pathCommands: WorkbenchCommandRow[] = firstReplayablePath
    ? firstReplayablePath.suggestedCommands.map((command) => ({ ...command, source: "path" }))
    : [];
  return [...runCommands, ...pathCommands];
}

export function toneForPathHealth(health: WorkspaceAppMapPathSummary["health"]): WorkbenchTone {
  if (health === "healthy") return "success";
  if (health === "warning") return "warning";
  return "error";
}

export function tagColorForTone(tone: WorkbenchTone): string {
  switch (tone) {
    case "success": return "green";
    case "warning": return "gold";
    case "error": return "red";
    case "processing": return "blue";
    case "default": return "default";
  }
}

import type { HierarchyScene, WorkspaceWorkbenchDTO } from "../types";

export const mockWorkspaceWorkbench: WorkspaceWorkbenchDTO = {
  run: {
    runId: "run-local-20260707-001",
    status: "running",
    goal: "登录 Overloaded 并进入 Dashboard",
    app: {
      name: "Overloaded",
      bundleId: "com.linhay.overloaded",
    },
    target: {
      platform: "ios",
      scope: "simulator",
      name: "iPhone 16 Pro",
      targetSelector: "booted",
    },
    llmEnabled: true,
    vlmEnabled: true,
    providersReady: true,
    latestPause: {
      reason: "inspect_vlm_grounding_failure",
      evidenceRef: "evidence/actions/vlm-001/vlm-failure.json",
    },
    latestBootstrapProposal: {
      title: "稳定启动",
      summary: "使用 current observation 的 visibleTexts 建立首步候选，并等待业务 anchor。",
      evidenceRefs: ["evidence/model/bootstrap-proposal-000.json"],
    },
    latestRecoveryProposal: {
      title: "偏航回正",
      summary: "最新 step 建议回到 Login CTA，重新执行 VLM grounding 后再验证 Dashboard anchor。",
      evidenceRefs: ["evidence/model/recovery-proposal-001.json", "atlas/deltas.jsonl#transition_0001"],
    },
    appMap: {
      mapRef: "atlas/app-map/app-map.json",
      screenCount: 7,
      stateCount: 9,
      transitionCount: 6,
      pathCount: 3,
      coverageStatus: "needs_suite_coverage",
      pathIds: ["path-login-dashboard", "path-settings-return", "path-media-open"],
    },
    suggestedCommands: [
      {
        key: "workspace-inspect",
        label: "Inspect run",
        command: "triton workspace inspect run-local-20260707-001 --json",
      },
      {
        key: "map-health",
        label: "Map health",
        command: "triton map health atlas/app-map --json",
      },
    ],
  },
  paths: [
    {
      pathId: "path-login-dashboard",
      name: "Login to Dashboard",
      status: "verified",
      confirmed: true,
      replayable: true,
      requiresVLM: true,
      health: "healthy",
      sourceRuns: ["run-local-20260707-001", "run-local-20260707-002"],
      suggestedCommands: [
        {
          key: "path-export-flow",
          label: "Export flow",
          command: "triton map export-flow atlas/app-map --path path-login-dashboard --output flows/path-login-dashboard.tritontest.yaml --json",
        },
        {
          key: "path-run",
          label: "Replay path",
          command: "triton test run flows/path-login-dashboard.tritontest.yaml --evidence-dir evidence/replay/path-login-dashboard --allow-vlm --json",
        },
      ],
    },
    {
      pathId: "path-settings-return",
      name: "Settings return",
      status: "candidate",
      confirmed: false,
      replayable: true,
      requiresVLM: false,
      health: "warning",
      sourceRuns: ["run-local-20260707-001"],
      suggestedCommands: [
        {
          key: "path-settings-export-flow",
          label: "Export flow",
          command: "triton map export-flow atlas/app-map --path path-settings-return --output flows/path-settings-return.tritontest.yaml --json",
        },
      ],
    },
    {
      pathId: "path-media-open",
      name: "Open media tab",
      status: "blocked",
      confirmed: false,
      replayable: false,
      requiresVLM: true,
      health: "unhealthy",
      sourceRuns: ["run-local-20260707-003"],
      suggestedCommands: [
        {
          key: "path-media-show",
          label: "Show path",
          command: "triton map path show atlas/app-map --path path-media-open --json",
        },
      ],
    },
  ],
  evidenceRefs: [
    "events.jsonl#observation.captured",
    "evidence/model/decision-001.json",
    "evidence/actions/action-001.json",
    "atlas/app-map/paths/path-login-dashboard.json",
  ],
};

export const hierarchyScenes: Record<string, HierarchyScene> = {
  ios: {
    platform: "ios",
    rootId: "window",
    viewport: { width: 390, height: 844 },
    controllerContext: {
      activeControllerId: "main-controller",
      activeControllerName: "MainTabBarController",
      activeControllerClassName: "MainTabBarController",
      source: "runtime-tree",
      stack: [
        { id: "main-controller", className: "MainTabBarController", name: "MainTabBarController" },
        { id: "feed-controller", className: "FeedViewController", name: "FeedViewController" },
      ],
    },
    nodes: [
      node("window", null, "UIWindowScene", "mainScene", 0, 0, 390, 844, 0),
      node("root", "window", "UIView", "rootView", 0, 0, 390, 844, 1),
      node("stack", "root", "UIStackView", "questionList", 16, 96, 358, 520, 2),
      node("back", "root", "UIButton", "backButton", 16, 52, 44, 44, 2, "backButton"),
      node("title", "root", "UILabel", "titleLabel", 72, 56, 180, 28, 2),
      node("tabbar", "root", "UITabBar", "tabbar", 0, 760, 390, 84, 2),
      node("server-tab", "tabbar", "UIButton", "serverTab", 0, 760, 98, 84, 3),
      node("photos-tab", "tabbar", "UIButton", "photosTab", 98, 760, 98, 84, 3),
      node("music-tab", "tabbar", "UIButton", "musicTab", 196, 760, 97, 84, 3),
      node("settings-tab", "tabbar", "UIButton", "settingsTab", 293, 760, 97, 84, 3),
    ],
  },
};

function node(
  id: string,
  parentId: string | null,
  type: string,
  name: string,
  x: number,
  y: number,
  width: number,
  height: number,
  depth: number,
  accessibilityIdentifier = name
) {
  return {
    id,
    parentId,
    type,
    name,
    frame: { x, y, width, height },
    depth,
    visible: true,
    interactive: type === "UIButton",
    color: "#1677FF",
    source: "runtime-tree",
    view: { accessibilityIdentifier, accessibilityLabel: name, alpha: 1 },
    raw: { source: "runtime-tree", role: type },
  };
}

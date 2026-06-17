export type HostBridgeSnapshot = {
  loading: boolean;
  error?: string;
  capturedAt?: string;
  sourceCommands: string[];
};

export type HostBridgeNoticeTone = "warning" | "error";

export type HostBridgeNotice = {
  tone: HostBridgeNoticeTone;
  title: string;
  detail: string;
};

export type HostBridgePresentation = {
  toolbarLabel: string;
  notice?: HostBridgeNotice;
};

export function describeHostBridgePresentation(
  bridge: HostBridgeSnapshot,
  hostTargetCount: number
): HostBridgePresentation {
  if (bridge.loading) {
    return {
      toolbarLabel: "正在加载本机仿真器",
    };
  }

  if (bridge.error) {
    return {
      toolbarLabel: "QA mock fallback",
      notice: {
        tone: "error",
        title: "Host bridge 请求失败，正在展示 QA mock fallback",
        detail: bridge.error,
      },
    };
  }

  if (hostTargetCount === 0) {
    return {
      toolbarLabel: "QA mock fallback",
      notice: {
        tone: "warning",
        title: "当前没有可用 host target，正在展示 QA mock fallback",
        detail: summarizeReadonlyBridge(bridge),
      },
    };
  }

  return {
    toolbarLabel: "Readonly host targets",
  };
}

function summarizeReadonlyBridge(bridge: HostBridgeSnapshot) {
  const commands = bridge.sourceCommands.filter((command) => command.trim().length > 0);
  if (commands.length > 0) {
    return `只读 host bridge 已成功返回，但 targets 为空。来源：${commands.join(" · ")}`;
  }
  if (bridge.capturedAt) {
    return `只读 host bridge 已成功返回，但 targets 为空。capturedAt=${bridge.capturedAt}`;
  }
  return "只读 host bridge 已成功返回，但 targets 为空。";
}

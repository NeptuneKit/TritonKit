export type HostBridgePresentationInput = {
  loading?: boolean;
  error?: string | null;
  sourceCommands?: string[];
  capturedAt?: string;
};

export function describeHostBridgePresentation(input: HostBridgePresentationInput, targetCount: number) {
  if (input.loading) {
    return { toolbarLabel: "Loading host targets", notice: null };
  }
  if (input.error) {
    return {
      toolbarLabel: "Host bridge unavailable",
      notice: { tone: "error", title: "Host bridge 请求失败", detail: input.error },
    };
  }
  if (targetCount === 0) {
    const source = input.sourceCommands?.join(", ") || "unknown source";
    return {
      toolbarLabel: "No host targets",
      notice: {
        tone: "warning",
        title: "当前没有可用 host target",
        detail: `只读 host bridge 已成功返回，但 targets 为空。来源：${source}`,
      },
    };
  }
  return { toolbarLabel: `${targetCount} host targets`, notice: null };
}

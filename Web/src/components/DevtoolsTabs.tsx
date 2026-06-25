import { Tabs } from "antd";
import { type DevtoolsPanel, type DisplayLanguage } from "./inspectorWorkspaceModel";

export function DevtoolsTabs({
  activePanel,
  language,
  onSelectPanel,
}: {
  activePanel: DevtoolsPanel;
  language: DisplayLanguage;
  onSelectPanel: (panel: DevtoolsPanel) => void;
}) {
  const tabs: Array<{ id: DevtoolsPanel; label: string }> = [
    { id: "config", label: language === "zh-CN" ? "证据" : "Evidence" },
    { id: "network", label: language === "zh-CN" ? "Trace" : "Trace" },
    { id: "logs", label: language === "zh-CN" ? "日志" : "Logs" },
  ];

  return (
    <Tabs
      activeKey={activePanel}
      className="inspector-tabs"
      role="tablist"
      aria-label={language === "zh-CN" ? "右侧工具分区" : "Right-side tool sections"}
      items={tabs.map((tab) => ({ key: tab.id, label: tab.label }))}
      onChange={(key) => onSelectPanel(key as DevtoolsPanel)}
    />
  );
}

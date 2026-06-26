import { Tabs } from "antd";
import { EyeOutlined, ApiOutlined, FileTextOutlined } from "@ant-design/icons";
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
  const tabs: Array<{ id: DevtoolsPanel; label: string; icon: React.ReactNode }> = [
    { id: "config", label: language === "zh-CN" ? "样式" : "Style", icon: <EyeOutlined /> },
    { id: "network", label: language === "zh-CN" ? "Trace" : "Trace", icon: <ApiOutlined /> },
    { id: "logs", label: language === "zh-CN" ? "日志" : "Logs", icon: <FileTextOutlined /> },
  ];

  return (
    <Tabs
      activeKey={activePanel}
      className="inspector-tabs"
      aria-label={language === "zh-CN" ? "右侧工具分区" : "Right-side tool sections"}
      items={tabs.map((tab) => ({ key: tab.id, label: tab.label, icon: tab.icon }))}
      onChange={(key) => onSelectPanel(key as DevtoolsPanel)}
    />
  );
}

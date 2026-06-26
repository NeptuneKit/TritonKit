import { Button, Space } from "antd";
import { MonitorSmartphone, PanelLeft, PanelRight, RefreshCw, Settings2 } from "lucide-react";
import { platformLabel } from "./inspectorWorkspaceModel";
import type { DeviceTarget } from "../types";

export function DeviceHubToolbar({
  target,
  targets,
  bridgeSubtitle,
  isSidebarVisible,
  isDevtoolsVisible,
  isRefreshing,
  isTargetMenuOpen,
  onToggleSidebar,
  onToggleDevtools,
  onOpenSettings,
  onRefresh,
  onToggleTargetMenu,
  onCloseTargetMenu,
  onSelectTarget,
}: {
  target: DeviceTarget;
  targets: DeviceTarget[];
  bridgeSubtitle: string;
  isSidebarVisible: boolean;
  isDevtoolsVisible: boolean;
  isRefreshing: boolean;
  isTargetMenuOpen: boolean;
  onToggleSidebar: () => void;
  onToggleDevtools: () => void;
  onOpenSettings: () => void;
  onRefresh: () => void;
  onToggleTargetMenu: () => void;
  onCloseTargetMenu: () => void;
  onSelectTarget: (targetId: string) => void;
}) {
  const toolbarSubtitle = bridgeSubtitle === "Readonly host targets" ? target.os : bridgeSubtitle;

  return (
    <aside className="hub-toolbar-vertical" aria-label="工具栏">
      <div className="toolbar-title" hidden>
        <strong>{target.name}</strong>
        <span>{toolbarSubtitle}</span>
      </div>
      <Space orientation="vertical" size={4} align="center">
        <div className="toolbar-target-switcher">
          <Button
            className="toolbar-target-trigger"
            type="text"
            shape="circle"
            aria-label="切换设备"
            title={target.name}
            icon={<MonitorSmartphone size={17} strokeWidth={2.2} />}
            onClick={onToggleTargetMenu}
          />
          {isTargetMenuOpen ? (
            <div className="toolbar-target-menu" role="listbox" aria-label="切换设备">
              {targets.map((candidate) => (
                <button
                  key={candidate.id}
                  type="button"
                  className="toolbar-target-option"
                  role="option"
                  aria-selected={candidate.id === target.id}
                  onClick={() => {
                    onSelectTarget(candidate.id);
                    onCloseTargetMenu();
                  }}
                >
                  <strong>{candidate.name}</strong>
                  <span>{candidate.appName}</span>
                  <em>
                    {platformLabel[candidate.platform]} · {candidate.os}
                  </em>
                </button>
              ))}
            </div>
          ) : null}
        </div>

        <div className="toolbar-divider" />

        <Button
          className={`icon-tool ${isSidebarVisible ? "is-active" : ""}`}
          type="text"
          shape="circle"
          aria-label={isSidebarVisible ? "收起侧边栏" : "展开侧边栏"}
          title={isSidebarVisible ? "收起侧边栏" : "展开侧边栏"}
          icon={<PanelLeft size={17} strokeWidth={2.2} />}
          onClick={onToggleSidebar}
        />
        <Button
          className={`icon-tool ${isDevtoolsVisible ? "is-active" : ""}`}
          type="text"
          shape="circle"
          aria-label={isDevtoolsVisible ? "收起右侧面板" : "展开右侧面板"}
          title={isDevtoolsVisible ? "收起右侧面板" : "展开右侧面板"}
          icon={<PanelRight size={17} strokeWidth={2.2} />}
          onClick={onToggleDevtools}
        />

        <div className="toolbar-divider" />

        <Button
          className="icon-tool"
          type="text"
          shape="circle"
          aria-label="打开设置"
          title="打开设置"
          icon={<Settings2 size={17} strokeWidth={2.2} />}
          onClick={onOpenSettings}
        />
        <Button
          className={`icon-tool ${isRefreshing ? "is-spinning" : ""}`}
          type="text"
          shape="circle"
          aria-label={isRefreshing ? "正在刷新全局数据" : "刷新全局数据"}
          title={isRefreshing ? "正在刷新全局数据" : "刷新全局数据"}
          disabled={isRefreshing}
          icon={<RefreshCw size={17} strokeWidth={2.2} />}
          onClick={onRefresh}
        />
      </Space>
    </aside>
  );
}

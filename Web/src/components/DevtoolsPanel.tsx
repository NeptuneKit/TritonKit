import { Inspector } from "./Inspector";
import { NetworkStrip } from "./NetworkStrip";
import { LogStrip } from "./LogStrip";
import type { DevtoolsPanel as DevtoolsPanelType, DisplayLanguage, HierarchyNodeHotEditDraft } from "./inspectorWorkspaceModel";
import type {
  HierarchyLayerNode,
  LogEntry,
  NetworkEvent,
} from "../types";

export function DevtoolsPanelContent({
  activePanel,
  language,
  selectedNode,
  selectedNodeDraft,
  events,
  logs,
  onLayoutChange,
}: {
  activePanel: DevtoolsPanelType;
  language: DisplayLanguage;
  selectedNode: HierarchyLayerNode | null;
  selectedNodeDraft?: HierarchyNodeHotEditDraft;
  events: NetworkEvent[];
  logs: LogEntry[];
  onLayoutChange?: (nodeId: string, field: string, value: number) => void;
}) {
  return (
    <div className="devtools-panel-stack">
      <Inspector
        hidden={activePanel !== "config"}
        selectedNode={selectedNode}
        selectedNodeDraft={selectedNodeDraft}
        onLayoutChange={onLayoutChange}
      />
      <NetworkStrip
        id="network-evidence-panel"
        hidden={activePanel !== "network"}
        language={language}
        events={events}
      />
      <LogStrip
        id="logs-evidence-panel"
        hidden={activePanel !== "logs"}
        language={language}
        entries={logs}
      />
    </div>
  );
}

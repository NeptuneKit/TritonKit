import type { ReactNode } from "react";
import { mockWorkspaceWorkbench } from "../data/mockData";
import type { WorkspaceWorkbenchDTO } from "../types";
import { RunWorkbenchView } from "./RunWorkbenchView";

export type RunWorkbenchCardProps = {
  nodeId: string;
  headerActions?: ReactNode;
  workbench?: WorkspaceWorkbenchDTO;
};

export function RunWorkbenchCard({ workbench = mockWorkspaceWorkbench, headerActions }: RunWorkbenchCardProps) {
  return <div className="rhine-workbench-host">
    <div className="rhine-workbench-scroll">
      <RunWorkbenchView headerActions={headerActions} workbench={workbench} />
    </div>
  </div>;
}

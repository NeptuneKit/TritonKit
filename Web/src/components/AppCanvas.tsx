import { WorkspaceCanvas, type WorkspaceCanvasProps } from './WorkspaceCanvas';
import { StreamCard } from './StreamCard';
import { InspectorCard } from './InspectorCard';
import { RunWorkbenchCard } from './RunWorkbenchCard';

export function NodeRenderer(props: Omit<WorkspaceCanvasProps, 'renderCard'>) {
  return <WorkspaceCanvas {...props} renderCard={(card, nodeId, headerActions) => {
    if (card === 'stream') return <StreamCard nodeId={nodeId} headerActions={headerActions} />;
    if (card === 'inspector') return <InspectorCard nodeId={nodeId} headerActions={headerActions} />;
    return <RunWorkbenchCard nodeId={nodeId} headerActions={headerActions} />;
  }} />;
}

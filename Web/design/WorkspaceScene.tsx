import { useEffect, useState } from 'react';
import { WorkspaceShell } from '../src/components/WorkspaceShell';
import { WorkspaceCanvas } from '../src/components/WorkspaceCanvas';
import { StreamPanel } from '../src/components/StreamPanel';
import { InspectorPanel } from '../src/components/InspectorPanel';
import { RunWorkbenchView } from '../src/components/RunWorkbenchView';
import { makeInitialRoot, removeLeaf, splitLeaf, updateNode, type LayoutNode } from '../src/layoutModel';
import { SyntheticContextProvider } from './SyntheticContext';
import { makeWorkbenchFixture } from './fixtures';
import { syntheticScreen } from './StreamScene';
import type { DevicePlatform } from '../src/types';

export function WorkspaceScene({ state = 'ready', platform = 'ios', copyText }: {state?: string; platform?: DevicePlatform; copyText?: (text: string) => Promise<void>}) {
  const [root, setRoot] = useState<LayoutNode>(() => state === 'empty' ? { kind: 'leaf', id: 'design-root', card: null } : {
    kind: 'split', id: 'design-root', direction: 'v', ratio: .5,
    first: { kind: 'leaf', id: 'design-stream', card: 'stream' },
    second: { kind: 'leaf', id: 'design-inspector', card: 'inspector' },
  });
  const [imageUrl, setImageUrl] = useState('');
  useEffect(() => {
    const url = URL.createObjectURL(new Blob([syntheticScreen], {type: 'image/svg+xml'}));
    setImageUrl(url);
    return () => URL.revokeObjectURL(url);
  }, []);
  return <SyntheticContextProvider platform={platform} state={state} selectedNode>
    <WorkspaceShell><WorkspaceCanvas node={root} isRoot
      onSplit={(id, direction) => setRoot(old => splitLeaf(old, id, direction))}
      onClose={id => setRoot(old => removeLeaf(old, id) ?? makeInitialRoot())}
      onUnload={id => setRoot(old => updateNode(old, id, node => node.kind === 'leaf' ? {...node, card: null} : node))}
      onSelectCard={(id, card) => setRoot(old => updateNode(old, id, node => node.kind === 'leaf' ? {...node, card} : node))}
      onDividerDrag={(id, delta) => setRoot(old => updateNode(old, id, node => node.kind === 'split' ? {...node, ratio: Math.max(.1, Math.min(.9, node.ratio + delta))} : node))}
      renderCard={(card, id, headerActions) => card === 'stream' ? imageUrl && <StreamPanel headerActions={headerActions} nodeId={id} streamImageUrl={request => `${imageUrl}#${request.platform}-${request.fps}-${request.connectTime}`} /> : card === 'inspector' ? <InspectorPanel headerActions={headerActions} nodeId={id} copyText={copyText} /> : <div className="rhine-workbench-scroll"><RunWorkbenchView headerActions={headerActions} workbench={makeWorkbenchFixture(state)} copyCommand={copyText} /></div>}
    /></WorkspaceShell>
  </SyntheticContextProvider>;
}

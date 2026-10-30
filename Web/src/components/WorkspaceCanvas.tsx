import { useCallback, useEffect, useRef, useState, type CSSProperties, type PointerEvent, type ReactNode } from 'react';
import { Button, IconButton, Menu, Stack, Surface, Text, type MenuItem } from '@linhey/rhine-design';
import type { CardType, LayoutNode, SplitNode } from '../layoutModel';
import './workspaceCanvas.css';

type Direction = SplitNode['direction'];
const cards: { type: CardType; name: string; description: string }[] = [
  { type: 'stream', name: '设备预览', description: '只读查看设备画面，并联动选择视图或 AX 节点。' },
  { type: 'inspector', name: '界面层级', description: '查看视图树、节点属性和无障碍信息。' },
  { type: 'workbench', name: '运行与路径', description: '只读查看运行、路径状态与建议 CLI 命令。' },
];

function normalizedRatio(ratio: number) { return Number.isFinite(ratio) ? Math.min(0.9, Math.max(0.1, ratio)) : 0.5; }

export function workspaceVisualDirection(direction: Direction, width: number): Direction {
  return direction === 'v' && width < 880 ? 'h' : direction;
}

export function dividerKeyboardDelta(key: string, direction: Direction, ratio: number): number | null {
  const current = normalizedRatio(ratio);
  if (key === 'Home') return 0.1 - current;
  if (key === 'End') return 0.9 - current;
  if (key === (direction === 'v' ? 'ArrowRight' : 'ArrowDown')) return Math.min(0.05, 0.9 - current);
  if (key === (direction === 'v' ? 'ArrowLeft' : 'ArrowUp')) return -Math.min(0.05, current - 0.1);
  return null;
}

export function createDividerMovement(pointerId: number, start: number, size: number) {
  let previous = start;
  let active = Number.isFinite(size) && size > 0;
  return {
    pointerId,
    move(id: number, position: number): number {
      if (!active || id !== pointerId || !Number.isFinite(position)) return 0;
      const delta = (position - previous) / size;
      previous = position;
      return delta;
    },
    stop() { active = false; },
  };
}

export interface WorkspaceCanvasProps {
  node: LayoutNode;
  onSplit: (id: string, direction: Direction) => void;
  onClose: (id: string) => void;
  onUnload: (id: string) => void;
  onSelectCard: (id: string, card: CardType) => void;
  onDividerDrag: (id: string, delta: number, direction: Direction) => void;
  renderCard: (card: CardType, nodeId: string, headerActions: ReactNode) => ReactNode;
  isRoot?: boolean;
}

export function WorkspaceCanvas({ isRoot = true, ...props }: WorkspaceCanvasProps) {
  const root = useRef<HTMLDivElement>(null);
  const restoreFocus = useRef(false);
  useEffect(() => {
    if (restoreFocus.current) { restoreFocus.current = false; root.current?.focus(); }
  }, [props.node]);
  const afterLayout = (action: () => void) => { restoreFocus.current = true; action(); };
  return <div ref={root} className="rhine-workspace-canvas" role="region" aria-label="工作台窗格" tabIndex={-1}>
    <WorkspaceNode {...props} isRoot={isRoot}
      onClose={id => afterLayout(() => props.onClose(id))}
      onUnload={id => afterLayout(() => props.onUnload(id))}
      onSelectCard={(id, card) => afterLayout(() => props.onSelectCard(id, card))}
      onSplit={(id, direction) => afterLayout(() => props.onSplit(id, direction))}
    />
  </div>;
}

function WorkspaceNode(props: WorkspaceCanvasProps & { isRoot: boolean }) {
  const { node, onSplit, onClose, onUnload, onSelectCard, renderCard, isRoot } = props;
  if (node.kind === 'split') return <WorkspaceSplit {...props} node={node} />;
  const card = cards.find(item => item.type === node.card);
  const actions: MenuItem[] = [
    { id: 'split-v', label: '左右分割', onSelect: () => onSplit(node.id, 'v') },
    { id: 'split-h', label: '上下分割', onSelect: () => onSplit(node.id, 'h') },
    ...(card ? [{ id: 'unload', label: '更换组件', onSelect: () => onUnload(node.id) }] : []),
    ...(!isRoot ? [{ id: 'close', label: '关闭当前窗格', onSelect: () => onClose(node.id) }] : []),
  ];
  const headerActions = <Menu label="窗格操作" trigger={<IconButton label={`${card?.name ?? '空白窗格'}：窗格操作`} icon="more" />} items={actions} />;
  return <Surface padding="none" className="rhine-workspace-pane" data-workspace-node={node.id}>
    <div className="rhine-workspace-content">
      {node.card ? renderCard(node.card, node.id, headerActions) : <div className="rhine-workspace-picker">
        <Stack gap={4}>
          <header className="rhine-workspace-picker-heading"><Text as="h2" variant="heading">添加视图</Text>{headerActions}</header>
          {cards.map(item => <Button key={item.type} variant="secondary" className="rhine-workspace-card-choice" data-workspace-card={item.type} onClick={() => onSelectCard(node.id, item.type)}>
            <span className="rhine-workspace-card-copy"><strong>{item.name}</strong><span>{item.description}</span></span>
          </Button>)}
        </Stack>
      </div>}
    </div>
  </Surface>;
}

function WorkspaceSplit({ node, ...props }: WorkspaceCanvasProps & { node: SplitNode; isRoot: boolean }) {
  const root = useRef<HTMLDivElement>(null);
  const divider = useRef<HTMLDivElement>(null);
  const drag = useRef<ReturnType<typeof createDividerMovement> | null>(null);
  const [width, setWidth] = useState(1280);
  const direction = workspaceVisualDirection(node.direction, width);
  const ratio = normalizedRatio(node.ratio);
  const stopDrag = useCallback(() => {
    const active = drag.current;
    drag.current = null;
    if (!active) return;
    active.stop();
    if (divider.current?.hasPointerCapture(active.pointerId)) divider.current.releasePointerCapture(active.pointerId);
  }, []);

  useEffect(() => {
    const element = root.current;
    if (!element) return;
    const measure = () => setWidth(element.clientWidth);
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  useEffect(() => stopDrag, [stopDrag]);
  useEffect(() => { stopDrag(); }, [direction, node.id, stopDrag]);

  const pointerStart = (event: PointerEvent<HTMLDivElement>) => {
    if (event.button !== 0 || drag.current) return;
    const rect = root.current?.getBoundingClientRect();
    if (!rect) return;
    const size = direction === 'v' ? rect.width : rect.height;
    if (size <= 0) return;
    event.preventDefault();
    event.currentTarget.focus();
    event.currentTarget.setPointerCapture(event.pointerId);
    drag.current = createDividerMovement(event.pointerId, direction === 'v' ? event.clientX : event.clientY, size);
  };
  const pointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const delta = drag.current?.move(event.pointerId, direction === 'v' ? event.clientX : event.clientY) ?? 0;
    if (delta) props.onDividerDrag(node.id, delta, node.direction);
  };
  const pointerEnd = (event: PointerEvent<HTMLDivElement>) => {
    if (drag.current?.pointerId === event.pointerId) stopDrag();
  };
  const tracks = `minmax(0, ${ratio}fr) var(--rhine-space-3) minmax(0, ${1 - ratio}fr)`;
  const style: CSSProperties = direction === 'v' ? { gridTemplateColumns: tracks } : { gridTemplateRows: tracks };

  return <div ref={root} className="rhine-workspace-split" data-direction={direction} style={style}>
    <div className="rhine-workspace-branch"><WorkspaceNode {...props} node={node.first} isRoot={false} /></div>
    <div ref={divider} className="rhine-workspace-divider" role="separator" tabIndex={0}
      aria-label={direction === 'v' ? '调整左右窗格比例' : '调整上下窗格比例'}
      aria-orientation={direction === 'v' ? 'vertical' : 'horizontal'}
      aria-valuemin={10} aria-valuemax={90} aria-valuenow={Math.round(ratio * 100)} aria-valuetext={`前一窗格 ${Math.round(ratio * 100)}%`}
      onPointerDown={pointerStart} onPointerMove={pointerMove} onPointerUp={pointerEnd} onPointerCancel={pointerEnd} onLostPointerCapture={pointerEnd}
      onKeyDown={event => {
        const delta = dividerKeyboardDelta(event.key, direction, ratio);
        if (delta === null) return;
        event.preventDefault(); event.stopPropagation();
        if (delta) props.onDividerDrag(node.id, delta, node.direction);
      }}
    />
    <div className="rhine-workspace-branch"><WorkspaceNode {...props} node={node.second} isRoot={false} /></div>
  </div>;
}

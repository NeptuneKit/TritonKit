import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { Badge, Button, Checkbox, CopyButton, Dialog, Divider, EmptyState, Icon, IconButton, Inline, KeyValue, Notice, NumberField, Popover, Select, Skeleton, Stack, Switch, Tabs, Text, TextField } from "@linhey/rhine-design";
import { useAppContext } from "../AppContext";
import { deriveAxTree, deriveViewTree, findSelectedNode } from "../inspect/hierarchyDerive";
import { buildNodePropertyDraft, buildNodePropertyPatchPayload, hasNodePropertyChanges, type NodePropertyDraft } from "../inspect/nodePropertyDraft";
import { changedHierarchyTreeNodeIds, snapshotHierarchyTree } from "../inspect/treeUpdateHighlight";
import { getInspectorTreeTabs } from "../inspectorTreeTabs";
import type { HierarchyLayerNode } from "../types";
import { InspectorHierarchyTree } from "./InspectorHierarchyTree";
import "./inspectorPanel.css";

const EMPTY_NODES: HierarchyLayerNode[] = [];
const noHighlights = (revision = 0) => ({ view: new Set<string>(), ax: new Set<string>(), revision });
type UpdateDraft = <K extends keyof NodePropertyDraft>(section: K, patch: Partial<NodePropertyDraft[K]>) => void;
export type InspectorPanelProps = { nodeId: string; headerActions?: ReactNode; copyText?: (text: string) => Promise<void> };

export function InspectorPanel({ nodeId, headerActions, copyText }: InspectorPanelProps) {
  const { inspectTargets, resolveInspectSlotTarget, getInspectSession, refreshInspectSession,
    setInspectOverlayMode, selectInspectNode, hoverInspectNode, setFocusedInspectTarget, bindInspectSlot } = useAppContext();
  const target = resolveInspectSlotTarget(nodeId);
  const targetKey = target?.key ?? null;
  const session = getInspectSession(targetKey);
  const selectedId = session?.selectedNodeId ?? null;
  const nodes = session?.scene?.nodes ?? EMPTY_NODES;
  const selected = useMemo(() => findSelectedNode(nodes, selectedId), [nodes, selectedId]);
  const [binding, setBinding] = useState<"follow" | "pinned">("follow");
  const [simplify, setSimplify] = useState(true);
  const [tab, setTab] = useState("view");
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [draft, setDraft] = useState(() => buildNodePropertyDraft(selected));
  const [request, setRequest] = useState<{ key: string | null; busy: boolean; error?: string }>({ key: null, busy: false });
  const [highlights, setHighlights] = useState(noHighlights);
  const previous = useRef<{ key: string | null; view: Map<string, string>; ax: Map<string, string> }>({ key: null, view: new Map(), ax: new Map() });
  const highlightTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const requestEpoch = useRef(0);
  const refresh = useRef(refreshInspectSession);
  refresh.current = refreshInspectSession;
  const viewTree = useMemo(() => deriveViewTree(nodes, { simplify }), [nodes, simplify]);
  const axTree = useMemo(() => deriveAxTree(nodes), [nodes]);
  const tabs = getInspectorTreeTabs(target?.platform, nodes, nodes.length > 0);
  const activeTab = tabs.some(item => item.key === tab) ? tab : tabs[0]?.key ?? "view";
  const busy = Boolean(session?.loading || (request.key === targetKey && request.busy));
  const error = session?.error || (request.key === targetKey ? request.error : undefined);

  useEffect(() => {
    if (binding === "follow") bindInspectSlot(nodeId, { mode: "followWorkbenchFocus" });
    else if (targetKey) bindInspectSlot(nodeId, { mode: "pinnedTarget", targetKey });
  }, [binding, bindInspectSlot, nodeId, targetKey]);
  useEffect(() => { setDetailsOpen(false); }, [selectedId, targetKey]);
  useEffect(() => { setDraft(buildNodePropertyDraft(selected)); }, [selected]);

  const readHierarchy = useCallback(async () => {
    if (!targetKey) return;
    const epoch = ++requestEpoch.current;
    setRequest({ key: targetKey, busy: true });
    try {
      await refresh.current(targetKey, "manualRefresh");
      if (epoch === requestEpoch.current) setRequest({ key: targetKey, busy: false });
    } catch (cause) {
      if (epoch === requestEpoch.current) setRequest({ key: targetKey, busy: false, error: cause instanceof Error ? cause.message : "无法读取层级，请检查连接后重试。" });
    }
  }, [targetKey]);
  useEffect(() => {
    void readHierarchy();
    return () => { requestEpoch.current++; };
  }, [readHierarchy]);

  useEffect(() => {
    const snapshot = { key: targetKey, view: snapshotHierarchyTree(viewTree), ax: snapshotHierarchyTree(axTree) };
    const sameTarget = previous.current.key === targetKey;
    const changed = {
      view: changedHierarchyTreeNodeIds(sameTarget ? previous.current.view : new Map(), snapshot.view),
      ax: changedHierarchyTreeNodeIds(sameTarget ? previous.current.ax : new Map(), snapshot.ax),
    };
    previous.current = snapshot;
    if (highlightTimer.current !== null) clearTimeout(highlightTimer.current);
    setHighlights(current => ({ ...changed, revision: current.revision + 1 }));
    if (changed.view.size || changed.ax.size) {
      highlightTimer.current = setTimeout(() => { setHighlights(current => noHighlights(current.revision)); highlightTimer.current = null; }, 1000);
    }
    return () => { if (highlightTimer.current !== null) clearTimeout(highlightTimer.current); };
  }, [targetKey, viewTree, axTree]);

  const updateDraft: UpdateDraft = useCallback((section, patch) => {
    setDraft(current => current ? { ...current, [section]: { ...current[section], ...patch } } : current);
  }, []);
  const patch = useMemo(() => {
    const base = buildNodePropertyDraft(selected);
    return selected && draft && base ? buildNodePropertyPatchPayload({ targetKey, node: selected, base, draft }) : null;
  }, [targetKey, selected, draft]);
  const hasChanges = hasNodePropertyChanges(patch?.changes);
  const status = !target ? "等待连接" : busy ? "更新中" : error ? "读取失败" : session?.stale ? "待更新" : session?.scene ? "就绪" : "等待数据";
  const frame = selected ? `(${selected.frame.x.toFixed(0)}, ${selected.frame.y.toFixed(0)}) ${selected.frame.width.toFixed(0)} × ${selected.frame.height.toFixed(0)}` : "—";

  return <section className="rhine-inspector" role="region" aria-label="界面与 AX 审查" aria-busy={busy}>
    <header className="rhine-inspector-heading">
      <Inline gap={2} className="rhine-inspector-identity"><Text as="h2" variant="heading">界面层级</Text><Badge tone={error ? "error" : status === "就绪" ? "success" : "neutral"}>{status}</Badge></Inline>
      <Inline gap={1} className="rhine-inspector-header-actions">
        <Button variant="quiet" aria-label="更新层级" busy={busy} busyLabel="正在更新层级" disabled={!target} onClick={() => { void readHierarchy(); }}><Icon name="refresh" /></Button>
        {headerActions}
      </Inline>
    </header>
    <div className="rhine-inspector-body"><Stack gap={3}>
      <div className="rhine-inspector-targets">
        <Select className="rhine-inspector-target" label="目标源" value={targetKey ?? ""} disabled={!inspectTargets.length} onChange={event => {
          const next = event.target.value;
          if (binding === "pinned") bindInspectSlot(nodeId, { mode: "pinnedTarget", targetKey: next });
          setFocusedInspectTarget(next, nodeId);
        }}>
          {!targetKey && <option value="">未关联设备流</option>}
          {inspectTargets.map(item => <option key={item.key} value={item.key}>[{item.platform.toUpperCase()}] {item.name}</option>)}
        </Select>
        <Inline gap={1} className="rhine-inspector-target-actions">
          <Popover title="目标关联" trigger={<Button variant="secondary" aria-label={`目标关联设置：${binding === "follow" ? "跟随" : "固定"}`}>{binding === "follow" ? "跟随" : "固定"}</Button>}>
            <Select label="目标关联" value={binding} onChange={event => setBinding(event.target.value === "pinned" ? "pinned" : "follow")}>
              <option value="follow">跟随</option><option value="pinned">固定</option>
            </Select>
          </Popover>
          <Checkbox label="简化" checked={simplify} onChange={event => setSimplify(event.target.checked)} />
          <Popover title="层级来源说明" trigger={<IconButton label="查看层级来源说明" icon="info" />}>
            <Stack gap={3}>{tabs.map(item => <Stack key={item.key} gap={1}><Text as="h3" variant="heading">{item.label}</Text><Text>{item.description}</Text></Stack>)}</Stack>
          </Popover>
        </Inline>
      </div>
      {error && <Notice tone="error" title="层级读取失败">{error}{nodes.length > 0 && " 以下保留上次读取的节点。"}</Notice>}
      {busy && (nodes.length ? <Notice title="更新中">保留上次读取的节点，等待新的结果。</Notice> : <Skeleton label="正在读取层级" lines={3} />)}
      {!target && <EmptyState title="等待连接" description="关联设备流后查看界面层级与节点属性。" />}
      {selected && <div className="rhine-inspector-selection">
        <Text as="strong" variant="label">选中：{selected.type || selected.className || "Unknown"}</Text>
        <Inline gap={2}>
          <Dialog open={detailsOpen} onOpenChange={setDetailsOpen} title="节点属性"
            trigger={<Button variant="secondary">节点详情</Button>}>
            <Stack gap={4}>
              <KeyValue items={[
                { key: "type", label: "类型", value: selected.type || selected.className || "Unknown" },
                { key: "name", label: "名称", value: selected.name || selected.id },
                { key: "id", label: "节点 ID", value: selected.id }, { key: "parent", label: "父节点", value: selected.parentId || "—" },
                { key: "depth", label: "层级", value: String(selected.depth ?? "—") },
                { key: "source", label: "来源", value: selected.source || selected.raw?.source || "—" },
                { key: "status", label: "状态", value: `${selected.visible === false ? "隐藏" : "可见"} · ${selected.interactive ? "可交互" : "只读"}` },
                { key: "frame", label: "Frame", value: frame },
              ]} />
              {draft && <InspectorPropertyEditor node={selected} draft={draft} onChange={updateDraft} />}
              <Divider />
              <div className="rhine-inspector-footer"><Text variant="caption" tone="muted">{hasChanges ? "只读草稿：请使用 CLI 显式应用" : "无改动"}</Text><Inline gap={2}>
              <CopyButton label="复制 DTO" value={JSON.stringify(selected, null, 2)} copy={copyText} />
              {patch && <CopyButton label="复制 patch" value={JSON.stringify(patch, null, 2)} copy={copyText} />}
            </Inline></div>
            </Stack>
          </Dialog>
          <CopyButton label="复制 DTO" value={JSON.stringify(selected, null, 2)} copy={copyText} />
        </Inline>
      </div>}
      {target && <Tabs label="层级来源" value={activeTab} onValueChange={value => {
        setTab(value);
        if (targetKey) setInspectOverlayMode(targetKey, value === "ax" ? "ax" : "view");
      }} items={tabs.map(item => {
        const kind = item.key === "ax" ? "ax" : "view";
        const tree = kind === "ax" ? axTree : viewTree;
        return { value: item.key, label: item.label, content: <Stack gap={3}>
          {tree.length ? <InspectorHierarchyTree key={`${targetKey}:${kind}`} label={item.label} nodes={tree}
            selectedNodeId={selectedId} hoveredNodeId={session?.hoveredNodeId} updatedNodeIds={highlights[kind]} updateRevision={highlights.revision}
            onSelect={id => { if (targetKey) selectInspectNode(targetKey, id); }}
            onHover={id => { if (targetKey) hoverInspectNode(targetKey, id); }} />
            : !busy && <EmptyState title={kind === "ax" ? "无 AX 节点" : "无数据或未就绪"} description="可更新层级，或检查当前目标与数据来源。" />}
        </Stack> };
      })} />}
    </Stack></div>
  </section>;
}

export function InspectorPropertyEditor({ node, draft, onChange }: { node: HierarchyLayerNode; draft: NodePropertyDraft; onChange: UpdateDraft }) {
  const [tab, setTab] = useState("geometry");
  return <div className="rhine-inspector-properties"><Tabs label="节点属性分类" value={tab} onValueChange={setTab} items={[
    { value: "geometry", label: "Geometry", content: <div className="rhine-inspector-property-grid">
      <PropertyNumber label="x" value={draft.frame.x} onChange={x => onChange("frame", { x })} />
      <PropertyNumber label="y" value={draft.frame.y} onChange={y => onChange("frame", { y })} />
      <PropertyNumber label="width" min={0} value={draft.frame.width} onChange={width => onChange("frame", { width })} />
      <PropertyNumber label="height" min={0} value={draft.frame.height} onChange={height => onChange("frame", { height })} />
    </div> },
    { value: "view", label: "View", content: <div className="rhine-inspector-property-grid">
      <Switch label="hidden" checked={draft.view.isHidden} onCheckedChange={isHidden => onChange("view", { isHidden })} />
      <Switch label="userInteraction" checked={draft.view.isUserInteractionEnabled} onCheckedChange={isUserInteractionEnabled => onChange("view", { isUserInteractionEnabled })} />
      <PropertyNumber label="alpha" min={0} max={1} step={0.05} value={draft.view.alpha} onChange={alpha => onChange("view", { alpha })} />
    </div> },
    { value: "layer", label: "Layer", content: <div className="rhine-inspector-property-grid">
      <Switch label="hidden" checked={draft.layer.isHidden} onCheckedChange={isHidden => onChange("layer", { isHidden })} />
      <Switch label="masksToBounds" checked={draft.layer.masksToBounds} onCheckedChange={masksToBounds => onChange("layer", { masksToBounds })} />
      <PropertyNumber label="opacity" min={0} max={1} step={0.05} value={draft.layer.opacity} onChange={opacity => onChange("layer", { opacity })} />
      <PropertyNumber label="cornerRadius" min={0} value={draft.layer.cornerRadius} onChange={cornerRadius => onChange("layer", { cornerRadius })} />
      <PropertyNumber label="zPosition" value={draft.layer.zPosition} onChange={zPosition => onChange("layer", { zPosition })} />
    </div> },
    { value: "ax", label: "AX", content: <div className="rhine-inspector-property-grid">
      <TextField label="accessibilityIdentifier" value={draft.view.accessibilityIdentifier} onChange={event => onChange("view", { accessibilityIdentifier: event.target.value })} />
      <TextField label="accessibilityLabel" value={draft.view.accessibilityLabel} onChange={event => onChange("view", { accessibilityLabel: event.target.value })} />
      <TextField label="text" value={draft.style.text} onChange={event => onChange("style", { text: event.target.value })} />
      <TextField label="backgroundColor" value={draft.style.backgroundColor} onChange={event => onChange("style", { backgroundColor: event.target.value })} />
      <TextField label="foregroundColor" value={draft.style.foregroundColor} onChange={event => onChange("style", { foregroundColor: event.target.value })} />
      <PropertyNumber label="styleAlpha" min={0} max={1} step={0.05} value={draft.style.alpha} onChange={alpha => onChange("style", { alpha })} />
      <PropertyNumber label="styleCornerRadius" min={0} value={draft.style.cornerRadius} onChange={cornerRadius => onChange("style", { cornerRadius })} />
    </div> },
    { value: "raw", label: "Raw", content: <pre className="rhine-inspector-raw">{JSON.stringify(node, null, 2)}</pre> },
  ]} /></div>;
}

function PropertyNumber({ label, value, onChange, ...props }: { label: string; value: number; onChange: (value: number) => void; min?: number; max?: number; step?: number }) {
  return <NumberField label={label} value={value} controls={false} {...props} onValueChange={next => { if (next !== null) onChange(next); }} />;
}

import React, { useState, useEffect, useCallback, useMemo, useRef } from "react";
import { Button, Card, Checkbox, Flex, Input, InputNumber, message, Modal, Select, Space, Spin, Switch, Tabs, Tag, Tree, Typography } from "antd";
import { Copy, Maximize2, RefreshCw, Search, SlidersHorizontal } from "lucide-react";
import { useAppContext } from "../AppContext";
import { deriveAxTree, deriveViewTree, findSelectedNode, type HierarchyTreeNode } from "../inspect/hierarchyDerive";
import { buildNodePropertyDraft, buildNodePropertyPatchPayload, hasNodePropertyChanges, type NodePropertyDraft } from "../inspect/nodePropertyDraft";
import { changedHierarchyTreeNodeIds, snapshotHierarchyTree } from "../inspect/treeUpdateHighlight";
import { getInspectorTreeTabs } from "../inspectorTreeTabs";
import type { HierarchyLayerNode } from "../types";

const EMPTY_HIERARCHY_NODES: any[] = [];
type InspectorTreeKind = "view" | "ax";

function emptyUpdatedTreeNodeIds(): Record<InspectorTreeKind, Set<string>> {
  return { view: new Set(), ax: new Set() };
}

export function InspectorCard({ nodeId }: { nodeId: string }) {
  const {
    inspectTargets,
    resolveInspectSlotTarget,
    getInspectSession,
    refreshInspectSession,
    setInspectOverlayMode,
    selectInspectNode,
    hoverInspectNode,
    setFocusedInspectTarget,
    bindInspectSlot,
  } = useAppContext();
  const [bindingMode, setBindingMode] = useState<"follow" | "pinned">("follow");
  const currentTarget = resolveInspectSlotTarget(nodeId);
  const currentSession = getInspectSession(currentTarget?.key);
  const selectedNodeId = currentSession?.selectedNodeId ?? null;
  const flatNodes = currentSession?.scene?.nodes ?? EMPTY_HIERARCHY_NODES;

  const [selectedNodeData, setSelectedNodeData] = useState<{
    className: string;
    identifier: string;
    axText: string;
    frame: string;
  } | null>(null);
  const [selectedNodeDetails, setSelectedNodeDetails] = useState<HierarchyLayerNode | null>(null);
  const [detailsModalOpen, setDetailsModalOpen] = useState(false);
  const [nodePatchDraft, setNodePatchDraft] = useState<NodePropertyDraft | null>(null);

  const [loading, setLoading] = useState(false);
  const [liveViewTreeData, setLiveViewTreeData] = useState<HierarchyTreeNode[]>([]);
  const [liveAxTreeData, setLiveAxTreeData] = useState<HierarchyTreeNode[]>([]);
  const [liveTreeNodes, setLiveTreeNodes] = useState<any[]>([]);
  const [updatedTreeNodeIds, setUpdatedTreeNodeIds] = useState(emptyUpdatedTreeNodeIds);
  const [simplify, setSimplify] = useState(true);
  const previousTreeSnapshotsRef = useRef<Record<InspectorTreeKind, Map<string, string>>>({
    view: new Map(),
    ax: new Map(),
  });
  const previousTargetKeyRef = useRef<string | null>(null);
  const clearHighlightTimerRef = useRef<number | null>(null);

  // ─── 双向选择联动：根据选中的全局 selectedNodeId 查找并渲染当前节点属性 ─────────────────────
  useEffect(() => {
    if (!currentTarget) {
      setSelectedNodeData(null);
      setSelectedNodeDetails(null);
      return;
    }
    const matchedNode = findSelectedNode(flatNodes, selectedNodeId);
    if (matchedNode) {
      const identifier = matchedNode.view?.accessibilityIdentifier || "";
      const axText = matchedNode.view?.accessibilityLabel || matchedNode.style?.text || "";
      const frameStr = matchedNode.frame
        ? `(${matchedNode.frame.x.toFixed(0)}, ${matchedNode.frame.y.toFixed(0)}) ${matchedNode.frame.width.toFixed(0)}x${matchedNode.frame.height.toFixed(0)}`
        : "--";
      setSelectedNodeData({
        className: matchedNode.type || matchedNode.className || 'Unknown',
        identifier,
        axText,
        frame: frameStr
      });
      setSelectedNodeDetails(matchedNode);
    } else {
      setSelectedNodeData(null);
      setSelectedNodeDetails(null);
    }
  }, [selectedNodeId, currentTarget, flatNodes]);

  useEffect(() => {
    setDetailsModalOpen(false);
  }, [selectedNodeId]);

  useEffect(() => {
    setNodePatchDraft(buildNodePropertyDraft(selectedNodeDetails));
  }, [selectedNodeDetails]);

  useEffect(() => {
    if (bindingMode === "follow") {
      bindInspectSlot(nodeId, { mode: "followWorkbenchFocus" });
    } else if (currentTarget) {
      bindInspectSlot(nodeId, { mode: "pinnedTarget", targetKey: currentTarget.key });
    }
  }, [bindingMode, bindInspectSlot, currentTarget, nodeId]);

  useEffect(() => () => {
    if (clearHighlightTimerRef.current !== null) {
      window.clearTimeout(clearHighlightTimerRef.current);
    }
  }, []);

  // ─── 响应式树结构计算：监听 hierarchyScenes 并在更新时重新映射视图树 ─────────────────────
  useEffect(() => {
    if (!currentTarget) {
      setLiveTreeNodes([]);
      setLiveViewTreeData([]);
      setLiveAxTreeData([]);
      previousTreeSnapshotsRef.current = { view: new Map(), ax: new Map() };
      previousTargetKeyRef.current = null;
      setUpdatedTreeNodeIds(emptyUpdatedTreeNodeIds());
      return;
    }
    setLiveTreeNodes(flatNodes);
    if (!flatNodes || flatNodes.length === 0) {
      setLiveViewTreeData([]);
      setLiveAxTreeData([]);
      previousTreeSnapshotsRef.current = { view: new Map(), ax: new Map() };
      previousTargetKeyRef.current = currentTarget.key;
      setUpdatedTreeNodeIds(emptyUpdatedTreeNodeIds());
      return;
    }

    const viewTree = deriveViewTree(flatNodes, { simplify });
    const axTree = deriveAxTree(flatNodes);
    const nextSnapshots = {
      view: snapshotHierarchyTree(viewTree),
      ax: snapshotHierarchyTree(axTree),
    };
    const targetChanged = previousTargetKeyRef.current !== currentTarget.key;
    const previousSnapshots = targetChanged
      ? { view: new Map<string, string>(), ax: new Map<string, string>() }
      : previousTreeSnapshotsRef.current;
    const nextUpdatedTreeNodeIds = {
      view: changedHierarchyTreeNodeIds(previousSnapshots.view, nextSnapshots.view),
      ax: changedHierarchyTreeNodeIds(previousSnapshots.ax, nextSnapshots.ax),
    };

    previousTreeSnapshotsRef.current = nextSnapshots;
    previousTargetKeyRef.current = currentTarget.key;
    setLiveViewTreeData(viewTree);
    setLiveAxTreeData(axTree);

    if (nextUpdatedTreeNodeIds.view.size === 0 && nextUpdatedTreeNodeIds.ax.size === 0) {
      return;
    }

    setUpdatedTreeNodeIds(nextUpdatedTreeNodeIds);
    if (clearHighlightTimerRef.current !== null) {
      window.clearTimeout(clearHighlightTimerRef.current);
    }
    clearHighlightTimerRef.current = window.setTimeout(() => {
      setUpdatedTreeNodeIds(emptyUpdatedTreeNodeIds());
      clearHighlightTimerRef.current = null;
    }, 1000);
  }, [flatNodes, currentTarget, simplify]);

  const buildTreeData = useCallback((nodes: HierarchyTreeNode[], treeKind: InspectorTreeKind): any[] => {
    const highlightedNodeIds = updatedTreeNodeIds[treeKind];
    const mapTreeNode = (node: HierarchyTreeNode): any => {
      const identifier = node.view?.accessibilityIdentifier || "";
      const axText = node.view?.accessibilityLabel || node.style?.text || "";
      const frameStr = node.frame
        ? `(${node.frame.x.toFixed(0)}, ${node.frame.y.toFixed(0)}) ${node.frame.width.toFixed(0)}x${node.frame.height.toFixed(0)}`
        : "--";

      return {
        title: (
          <span
            onMouseEnter={() => currentTarget?.key && hoverInspectNode(currentTarget.key, node.id)}
            onMouseLeave={() => currentTarget?.key && hoverInspectNode(currentTarget.key, null)}
            className={`inspect-tree-node-title${highlightedNodeIds.has(node.id) ? " is-updated" : ""}`}
          >
            {node.type || node.className || 'Unknown'}
            {axText ? ` "${axText}"` : ''}
            {identifier ? ` [${identifier}]` : ''}
          </span>
        ),
        key: node.id,
        nodeData: {
          className: node.type || node.className || 'Unknown',
          identifier,
          axText,
          frame: frameStr
        },
        parentId: node.parentId,
        interactive: node.interactive || false,
        children: node.children.map(mapTreeNode)
      };
    };

    return nodes.map(mapTreeNode);
  }, [currentTarget, hoverInspectNode, updatedTreeNodeIds]);

  const viewTreeData = useMemo(
    () => buildTreeData(liveViewTreeData, "view"),
    [buildTreeData, liveViewTreeData]
  );
  const axTreeData = useMemo(
    () => buildTreeData(liveAxTreeData, "ax"),
    [buildTreeData, liveAxTreeData]
  );

  const treeTabs = getInspectorTreeTabs(currentTarget?.platform, liveTreeNodes, liveTreeNodes.length > 0);
  const renderTree = (treeData: any[], emptyText: string, description?: string) => (
    <>
      {description && (
        <div style={{ padding: "0 0 8px", color: "rgba(255,255,255,0.38)", fontSize: 11 }}>
          {description}
        </div>
      )}
      {treeData.length > 0
        ? <Tree selectedKeys={selectedNodeId ? [selectedNodeId] : []} treeData={treeData} onSelect={handleSelect} showLine={{ showLeafIcon: false }} defaultExpandAll style={{ background: 'transparent', fontSize: 11, whiteSpace: 'nowrap' }} />
        : <div style={{ padding: 12, textAlign: "center", color: "rgba(255,255,255,0.25)", fontSize: 12 }}>{emptyText}</div>}
    </>
  );

  const fetchHierarchy = useCallback(async () => {
    if (!currentTarget) return;
    setLoading(true);
    try {
      await refreshInspectSession(currentTarget.key, "manualRefresh");
    } catch (err) {
      console.error(err);
      message.error(`无法拉取实时视图树 (请确保后端已支持)`);
    } finally {
      setLoading(false);
    }
  }, [currentTarget, refreshInspectSession]);

  useEffect(() => {
    fetchHierarchy();
  }, [fetchHierarchy]);

  const handleSelect = (selectedKeys: any) => {
    if (!currentTarget) return;
    selectInspectNode(currentTarget.key, selectedKeys[0] || null);
  };

  const copySelectedNodeDetails = useCallback(async () => {
    if (!selectedNodeDetails) return;
    const text = JSON.stringify(selectedNodeDetails, null, 2);
    if (typeof globalThis.navigator?.clipboard?.writeText === "function") {
      await globalThis.navigator.clipboard.writeText(text);
      message.success("选中节点的 DTO JSON 已复制到剪切板");
    } else {
      message.warning("当前浏览器不支持剪切板写入");
    }
  }, [selectedNodeDetails]);

  const nodePatchPayload = useMemo(() => {
    if (!selectedNodeDetails || !nodePatchDraft) return null;
    const base = buildNodePropertyDraft(selectedNodeDetails);
    if (!base) return null;
    return buildNodePropertyPatchPayload({
      targetKey: currentTarget?.key ?? null,
      node: selectedNodeDetails,
      base,
      draft: nodePatchDraft,
    });
  }, [currentTarget?.key, nodePatchDraft, selectedNodeDetails]);
  const nodePatchHasChanges = hasNodePropertyChanges(nodePatchPayload?.changes);

  const updateNodePatchDraft = useCallback(<K extends keyof NodePropertyDraft>(
    section: K,
    patch: Partial<NodePropertyDraft[K]>,
  ) => {
    setNodePatchDraft((current) => current ? {
      ...current,
      [section]: {
        ...current[section],
        ...patch,
      },
    } : current);
  }, []);

  const copyNodePatchDraft = useCallback(async () => {
    if (!nodePatchPayload) return;
    const text = JSON.stringify(nodePatchPayload, null, 2);
    if (typeof globalThis.navigator?.clipboard?.writeText === "function") {
      await globalThis.navigator.clipboard.writeText(text);
      message.success("节点属性 patch 草稿已复制到剪切板");
    } else {
      message.warning("当前浏览器不支持剪切板写入");
    }
  }, [nodePatchPayload]);

  return (
    <Card
      size="small"
      title={
        <Flex align="center" gap={6}>
          <Search size={14} color="#1677ff" />
          <span>界面与 AX 审查</span>
        </Flex>
      }
      extra={<Tag color="blue">C5</Tag>}
      className="bento-card theme-blue"
    >
      <div className="card-content-wrapper" style={{ display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: "12px 12px 0 12px" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 12 }}>
          <div style={{ display: "flex", alignItems: "center", flex: 1, gap: 6 }}>
            <span style={{ fontSize: 11, color: "rgba(255,255,255,0.45)", marginRight: 6, whiteSpace: "nowrap" }}>目标源:</span>
            <Select
              size="small"
              style={{ width: "100%", maxWidth: 160 }}
              value={currentTarget?.key}
              onChange={(targetKey) => setFocusedInspectTarget(targetKey, nodeId)}
              placeholder="未关联设备流"
              options={inspectTargets.map((target) => ({
                value: target.key,
                label: `[${target.platform.toUpperCase()}] ${target.name}`,
              }))}
              notFoundContent={<span style={{ fontSize: 11, color: "rgba(255,255,255,0.25)" }}>无活动画面流</span>}
            />
            <Select
              size="small"
              style={{ width: 92 }}
              value={bindingMode}
              onChange={(mode) => setBindingMode(mode)}
              options={[
                { value: "follow", label: "跟随" },
                { value: "pinned", label: "固定" },
              ]}
            />
          </div>
          <div style={{ display: "flex", alignItems: "center" }}>
            <Checkbox
              checked={simplify}
              onChange={(e) => setSimplify(e.target.checked)}
              style={{ fontSize: 11, color: "rgba(255,255,255,0.45)", marginRight: 8 }}
            >
              简化
            </Checkbox>
            <Button type="text" size="small" style={{ color: "rgba(255,255,255,0.45)" }} icon={<RefreshCw size={12} className={loading ? "spin" : ""} />} onClick={fetchHierarchy} />
          </div>
        </div>
          <p style={{ marginBottom: 0 }}><span>审查状态:</span> <span className="label-val" style={{ color: currentTarget ? "#52c41a" : "#64748b" }}>{currentTarget ? (currentSession?.loading ? "更新中" : "就绪") : "等待连接"}</span></p>
          {selectedNodeData && (
            <div style={{ display: "flex", alignItems: "center", gap: 6, marginTop: 8, minWidth: 0 }}>
              <Tag color="blue" style={{ margin: 0, maxWidth: 240, overflow: "hidden", textOverflow: "ellipsis" }}>
                选中: {selectedNodeData.className}
              </Tag>
              <Button
                type="text"
                size="small"
                icon={<Maximize2 size={12} />}
                onClick={() => setDetailsModalOpen(true)}
                style={{ color: "rgba(255,255,255,0.65)", height: 22, padding: "0 6px" }}
              >
                详情
              </Button>
              <Button
                type="text"
                size="small"
                icon={<Copy size={12} />}
                onClick={copySelectedNodeDetails}
                disabled={!selectedNodeDetails}
                style={{ color: "rgba(255,255,255,0.65)", height: 22, padding: "0 6px" }}
              >
                复制
              </Button>
            </div>
          )}
        </div>

        <div style={{ flex: 1, overflow: 'auto', padding: "0 12px", position: "relative" }}>
          {loading && (
            <div style={{ position: "absolute", inset: 0, display: "flex", justifyContent: "center", alignItems: "center", background: "rgba(0,0,0,0.5)", zIndex: 10 }}>
              <Spin size="small" />
            </div>
          )}
          <Tabs
            key={treeTabs.map((tab) => tab.key).join("|")}
            size="small"
            defaultActiveKey={treeTabs[0]?.key ?? "view"}
            onChange={(key) => {
              if (!currentTarget) return;
              if (key === "view" || key === "ax") setInspectOverlayMode(currentTarget.key, key);
            }}
            items={treeTabs.map((tab) => ({
              key: tab.key,
              label: tab.label,
              children: tab.key === "ax"
                ? renderTree(axTreeData, "无 AX 节点", tab.description)
                : renderTree(viewTreeData, "无数据或未就绪", tab.description),
            }))}
          />
        </div>
      </div>
      <Modal
        title={
          <Flex align="center" gap={8}>
            <SlidersHorizontal size={15} color="#1677ff" />
            <span>节点属性</span>
          </Flex>
        }
        open={detailsModalOpen}
        onCancel={() => setDetailsModalOpen(false)}
        footer={
          <Flex justify="space-between" align="center" gap={8}>
            <Typography.Text type="secondary" style={{ fontSize: 12 }}>
              {nodePatchHasChanges ? "只读草稿：请使用 CLI 显式应用" : "无改动"}
            </Typography.Text>
            <Space size={8}>
              <Button icon={<Copy size={13} />} onClick={copySelectedNodeDetails} disabled={!selectedNodeDetails}>
                复制 DTO
              </Button>
              <Button type="primary" icon={<Copy size={13} />} onClick={copyNodePatchDraft} disabled={!nodePatchPayload}>
                复制 patch
              </Button>
            </Space>
          </Flex>
        }
        width={960}
        centered
        destroyOnHidden
        className="inspector-property-sheet-modal"
      >
        {selectedNodeDetails && nodePatchDraft && (
          <div className="inspector-property-sheet">
            <aside className="inspector-property-summary">
              <div className="inspector-property-class">{selectedNodeDetails.type || selectedNodeDetails.className || "Unknown"}</div>
              <div className="inspector-property-name">{selectedNodeDetails.name || selectedNodeDetails.id}</div>
              <PropertySummaryRow label="节点 ID" value={selectedNodeDetails.id} />
              <PropertySummaryRow label="父节点" value={selectedNodeDetails.parentId || "--"} />
              <PropertySummaryRow label="层级" value={String(selectedNodeDetails.depth ?? "--")} />
              <PropertySummaryRow label="来源" value={selectedNodeDetails.source || selectedNodeDetails.raw?.source || "--"} />
              <PropertySummaryRow label="状态" value={`${selectedNodeDetails.visible === false ? "隐藏" : "可见"} · ${selectedNodeDetails.interactive ? "可交互" : "只读"}`} />
              <PropertySummaryRow label="Frame" value={selectedNodeData?.frame || "--"} />
            </aside>
            <section className="inspector-property-main">
              <Tabs
                size="small"
                defaultActiveKey="geometry"
                items={[
                  {
                    key: "geometry",
                    label: "Geometry",
                    children: (
                      <PropertyGrid>
                        <PropertyNumber label="x" value={nodePatchDraft.frame.x} onChange={(x) => updateNodePatchDraft("frame", { x })} />
                        <PropertyNumber label="y" value={nodePatchDraft.frame.y} onChange={(y) => updateNodePatchDraft("frame", { y })} />
                        <PropertyNumber label="width" min={0} value={nodePatchDraft.frame.width} onChange={(width) => updateNodePatchDraft("frame", { width })} />
                        <PropertyNumber label="height" min={0} value={nodePatchDraft.frame.height} onChange={(height) => updateNodePatchDraft("frame", { height })} />
                      </PropertyGrid>
                    ),
                  },
                  {
                    key: "view",
                    label: "View",
                    children: (
                      <PropertyGrid>
                        <PropertySwitch label="hidden" checked={nodePatchDraft.view.isHidden} onChange={(isHidden) => updateNodePatchDraft("view", { isHidden })} />
                        <PropertySwitch label="userInteraction" checked={nodePatchDraft.view.isUserInteractionEnabled} onChange={(isUserInteractionEnabled) => updateNodePatchDraft("view", { isUserInteractionEnabled })} />
                        <PropertyNumber label="alpha" min={0} max={1} step={0.05} value={nodePatchDraft.view.alpha} onChange={(alpha) => updateNodePatchDraft("view", { alpha })} />
                      </PropertyGrid>
                    ),
                  },
                  {
                    key: "layer",
                    label: "Layer",
                    children: (
                      <PropertyGrid>
                        <PropertySwitch label="hidden" checked={nodePatchDraft.layer.isHidden} onChange={(isHidden) => updateNodePatchDraft("layer", { isHidden })} />
                        <PropertySwitch label="masksToBounds" checked={nodePatchDraft.layer.masksToBounds} onChange={(masksToBounds) => updateNodePatchDraft("layer", { masksToBounds })} />
                        <PropertyNumber label="opacity" min={0} max={1} step={0.05} value={nodePatchDraft.layer.opacity} onChange={(opacity) => updateNodePatchDraft("layer", { opacity })} />
                        <PropertyNumber label="cornerRadius" min={0} value={nodePatchDraft.layer.cornerRadius} onChange={(cornerRadius) => updateNodePatchDraft("layer", { cornerRadius })} />
                        <PropertyNumber label="zPosition" value={nodePatchDraft.layer.zPosition} onChange={(zPosition) => updateNodePatchDraft("layer", { zPosition })} />
                      </PropertyGrid>
                    ),
                  },
                  {
                    key: "ax",
                    label: "AX",
                    children: (
                      <PropertyGrid>
                        <PropertyText label="accessibilityIdentifier" value={nodePatchDraft.view.accessibilityIdentifier} onChange={(accessibilityIdentifier) => updateNodePatchDraft("view", { accessibilityIdentifier })} />
                        <PropertyText label="accessibilityLabel" value={nodePatchDraft.view.accessibilityLabel} onChange={(accessibilityLabel) => updateNodePatchDraft("view", { accessibilityLabel })} />
                        <PropertyText label="text" value={nodePatchDraft.style.text} onChange={(text) => updateNodePatchDraft("style", { text })} />
                        <PropertyText label="backgroundColor" value={nodePatchDraft.style.backgroundColor} onChange={(backgroundColor) => updateNodePatchDraft("style", { backgroundColor })} />
                        <PropertyText label="foregroundColor" value={nodePatchDraft.style.foregroundColor} onChange={(foregroundColor) => updateNodePatchDraft("style", { foregroundColor })} />
                        <PropertyNumber label="styleAlpha" min={0} max={1} step={0.05} value={nodePatchDraft.style.alpha} onChange={(alpha) => updateNodePatchDraft("style", { alpha })} />
                        <PropertyNumber label="styleCornerRadius" min={0} value={nodePatchDraft.style.cornerRadius} onChange={(cornerRadius) => updateNodePatchDraft("style", { cornerRadius })} />
                      </PropertyGrid>
                    ),
                  },
                  {
                    key: "raw",
                    label: "Raw",
                    children: (
                      <pre className="inspector-property-raw">
                        {JSON.stringify(selectedNodeDetails, null, 2)}
                      </pre>
                    ),
                  },
                ]}
              />
            </section>
          </div>
        )}
      </Modal>
    </Card>
  );
}

function PropertySummaryRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="inspector-property-summary-row">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function PropertyGrid({ children }: { children: React.ReactNode }) {
  return <div className="inspector-property-grid">{children}</div>;
}

function PropertyNumber({
  label,
  value,
  onChange,
  min,
  max,
  step,
}: {
  label: string;
  value: number;
  onChange: (value: number) => void;
  min?: number;
  max?: number;
  step?: number;
}) {
  return (
    <label className="inspector-property-row">
      <span>{label}</span>
      <InputNumber
        size="small"
        value={value}
        min={min}
        max={max}
        step={step}
        onChange={(next) => onChange(typeof next === "number" ? next : value)}
      />
    </label>
  );
}

function PropertyText({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="inspector-property-row">
      <span>{label}</span>
      <Input size="small" value={value} onChange={(event) => onChange(event.target.value)} />
    </label>
  );
}

function PropertySwitch({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
}) {
  return (
    <label className="inspector-property-row inspector-property-row-switch">
      <span>{label}</span>
      <Switch size="small" checked={checked} onChange={onChange} />
    </label>
  );
}

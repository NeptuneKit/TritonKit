import React, { useState, useEffect, useCallback } from "react";
import { Card, Tag, Flex, Button, message, Select, Tabs, Tree, Spin, Checkbox, Modal } from "antd";
import { Maximize2, Search, RefreshCw } from "lucide-react";
import { useAppContext } from "../AppContext";
import { LayoutNode } from "../App";
import { filterEffectivelyVisibleNodes } from "../hierarchyVisibility";

function findPath(node: LayoutNode, targetId: string, path: string[] = []): string[] | null {
  if (node.kind === "leaf") {
    return node.id === targetId ? path : null;
  }
  const left = findPath(node.first, targetId, [...path, "L"]);
  if (left) return left;
  const right = findPath(node.second, targetId, [...path, "R"]);
  return right;
}

function getDistance(root: LayoutNode, id1: string, id2: string): number {
  const path1 = findPath(root, id1);
  const path2 = findPath(root, id2);
  if (!path1 || !path2) return 999;
  let i = 0;
  while (i < path1.length && i < path2.length && path1[i] === path2[i]) {
    i++;
  }
  return (path1.length - i) + (path2.length - i);
}

export function InspectorCard({ nodeId }: { nodeId: string }) {
  const {
    activeStreams,
    focusedNodeId,
    layoutRoot,
    selectedNodeId,
    setSelectedNodeId,
    hoveredNodeId,
    setHoveredNodeId,
    hierarchyScenes,
    setHierarchyScene,
    fetchHierarchy: globalFetchHierarchy
  } = useAppContext();
  const [selectedUdid, setSelectedUdid] = useState<string | null>(null);

  // 自动关联设备逻辑：优先选择激活（聚焦）的卡片，其次选择布局树上距离最近的卡片
  useEffect(() => {
    if (activeStreams.length === 0) {
      setSelectedUdid(null);
      return;
    }

    const focusedStream = activeStreams.find((s) => s.nodeId === focusedNodeId);
    if (focusedStream) {
      setSelectedUdid(focusedStream.udid);
      return;
    }

    if (layoutRoot && !selectedUdid) {
      let minDistance = 9999;
      let closestUdid = activeStreams[0].udid;
      for (const s of activeStreams) {
        const d = getDistance(layoutRoot, nodeId, s.nodeId);
        if (d < minDistance) {
          minDistance = d;
          closestUdid = s.udid;
        }
      }
      setSelectedUdid(closestUdid);
    }
  }, [activeStreams, focusedNodeId, layoutRoot, nodeId, selectedUdid]);

  const currentStream = activeStreams.find((s) => s.udid === selectedUdid);

  const [selectedNodeData, setSelectedNodeData] = useState<{
    className: string;
    identifier: string;
    axText: string;
    frame: string;
  } | null>(null);
  const [selectedNodeDetails, setSelectedNodeDetails] = useState<any | null>(null);
  const [detailsModalOpen, setDetailsModalOpen] = useState(false);

  const [loading, setLoading] = useState(false);
  const [liveViewTreeData, setLiveViewTreeData] = useState<any[]>([]);
  const [liveAxTreeData, setLiveAxTreeData] = useState<any[]>([]);
  const [simplify, setSimplify] = useState(true);

  // ─── 双向选择联动：根据选中的全局 selectedNodeId 查找并渲染当前节点属性 ─────────────────────
  useEffect(() => {
    if (!currentStream) {
      setSelectedNodeData(null);
      setSelectedNodeDetails(null);
      return;
    }
    const nodes = filterEffectivelyVisibleNodes(hierarchyScenes[currentStream.udid] || []);
    const matchedNode = nodes.find(n => n.id === selectedNodeId);
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
  }, [selectedNodeId, currentStream, hierarchyScenes]);

  useEffect(() => {
    setDetailsModalOpen(false);
  }, [selectedNodeId]);

  // ─── 响应式树结构计算：监听 hierarchyScenes 并在更新时重新映射视图树 ─────────────────────
  useEffect(() => {
    if (!currentStream) {
      setLiveViewTreeData([]);
      setLiveAxTreeData([]);
      return;
    }
    const flatNodes = filterEffectivelyVisibleNodes(hierarchyScenes[currentStream.udid] || []);
    if (!flatNodes || flatNodes.length === 0) {
      setLiveViewTreeData([]);
      setLiveAxTreeData([]);
      return;
    }

    const nodeMap: { [id: string]: any } = {};

    // 1. Map flat nodes to TreeNode structure
    flatNodes.forEach((node: any) => {
      const identifier = node.view?.accessibilityIdentifier || "";
      const axText = node.view?.accessibilityLabel || node.style?.text || "";
      const frameStr = node.frame
        ? `(${node.frame.x.toFixed(0)}, ${node.frame.y.toFixed(0)}) ${node.frame.width.toFixed(0)}x${node.frame.height.toFixed(0)}`
        : "--";

      nodeMap[node.id] = {
        title: (
          <span
            onMouseEnter={() => setHoveredNodeId(node.id)}
            onMouseLeave={() => setHoveredNodeId(null)}
            style={{ display: "inline-block", width: "100%" }}
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
        children: []
      };
    });

    // 2. Link children to parents
    const roots: any[] = [];
    flatNodes.forEach((node: any) => {
      const treeNode = nodeMap[node.id];
      if (!treeNode) return;
      if (treeNode.parentId && nodeMap[treeNode.parentId]) {
        nodeMap[treeNode.parentId].children.push(treeNode);
      } else {
        roots.push(treeNode);
      }
    });

    // 3. Filter AX tree by collapsing non-AX nodes and lifting children
    const filterAx = (nodes: any[]): any[] => {
      const result: any[] = [];
      nodes.forEach((n) => {
        const hasAx = n.nodeData.axText !== "" || n.nodeData.identifier !== "" || n.interactive;
        const filteredChildren = filterAx(n.children);
        if (hasAx) {
          result.push({
            ...n,
            children: filteredChildren
          });
        } else {
          result.push(...filteredChildren);
        }
      });
      return result;
    };

    // 4. Simplify View Tree helper (collapse single-child noise containers)
    const filterSimplify = (nodes: any[]): any[] => {
      const result: any[] = [];
      const noiseClasses = [
        "UIView", "UITransitionView", "UIDropShadowView",
        "UILayoutContainerView", "UIViewControllerWrapperView",
        "WKCompositingView", "WKScrollView", "WKContentView"
      ];

      nodes.forEach((n) => {
        const simplifiedChildren = filterSimplify(n.children);
        const isNoiseClass = noiseClasses.includes(n.nodeData.className);
        const hasNoTextOrId = !n.nodeData.axText && !n.nodeData.identifier;

        if (isNoiseClass && hasNoTextOrId && simplifiedChildren.length === 1) {
          result.push(simplifiedChildren[0]);
        } else {
          result.push({
            ...n,
            children: simplifiedChildren
          });
        }
      });
      return result;
    };

    setLiveViewTreeData(simplify ? filterSimplify(roots) : roots);
    setLiveAxTreeData(filterAx(roots));
  }, [hierarchyScenes, currentStream, simplify, setHoveredNodeId]);

  const fetchHierarchy = useCallback(async () => {
    if (!currentStream) return;
    setLoading(true);
    try {
      await globalFetchHierarchy(currentStream.udid, currentStream.platform);
    } catch (err) {
      console.error(err);
      message.error(`无法拉取实时视图树 (请确保后端已支持)`);
    } finally {
      setLoading(false);
    }
  }, [currentStream, globalFetchHierarchy]);

  useEffect(() => {
    fetchHierarchy();
  }, [fetchHierarchy]);

  const handleSelect = (selectedKeys: any) => {
    setSelectedNodeId(selectedKeys[0] || null);
  };

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
          <div style={{ display: "flex", alignItems: "center", flex: 1 }}>
            <span style={{ fontSize: 11, color: "rgba(255,255,255,0.45)", marginRight: 6, whiteSpace: "nowrap" }}>目标源:</span>
            <Select
              size="small"
              style={{ width: "100%", maxWidth: 160 }}
              value={selectedUdid}
              onChange={setSelectedUdid}
              placeholder="未关联设备流"
              options={activeStreams.map((s) => ({
                value: s.udid,
                label: `[${s.platform.toUpperCase()}] ${s.name}`,
              }))}
              notFoundContent={<span style={{ fontSize: 11, color: "rgba(255,255,255,0.25)" }}>无活动画面流</span>}
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
          <p style={{ marginBottom: 0 }}><span>审查状态:</span> <span className="label-val" style={{ color: currentStream ? "#52c41a" : "#64748b" }}>{currentStream ? "就绪" : "等待连接"}</span></p>
        </div>

        <div style={{ flex: 1, overflow: 'auto', padding: "0 12px", position: "relative" }}>
          {loading && (
            <div style={{ position: "absolute", inset: 0, display: "flex", justifyContent: "center", alignItems: "center", background: "rgba(0,0,0,0.5)", zIndex: 10 }}>
              <Spin size="small" />
            </div>
          )}
          <Tabs
            size="small"
            defaultActiveKey="view"
            items={[
              {
                key: 'view',
                label: '视图树',
                children: liveViewTreeData.length > 0
                  ? <Tree selectedKeys={selectedNodeId ? [selectedNodeId] : []} treeData={liveViewTreeData} onSelect={handleSelect} showLine={{ showLeafIcon: false }} defaultExpandAll style={{ background: 'transparent', fontSize: 11, whiteSpace: 'nowrap' }} />
                  : <div style={{ padding: 12, textAlign: "center", color: "rgba(255,255,255,0.25)", fontSize: 12 }}>无数据或未就绪</div>
              },
              {
                key: 'ax',
                label: 'AX 树',
                children: liveAxTreeData.length > 0
                  ? <Tree selectedKeys={selectedNodeId ? [selectedNodeId] : []} treeData={liveAxTreeData} onSelect={handleSelect} showLine={{ showLeafIcon: false }} defaultExpandAll style={{ background: 'transparent', fontSize: 11, whiteSpace: 'nowrap' }} />
                  : <div style={{ padding: 12, textAlign: "center", color: "rgba(255,255,255,0.25)", fontSize: 12 }}>无 AX 节点</div>
              }
            ]}
          />
        </div>

        <div style={{ padding: "12px", borderTop: "1px solid rgba(255,255,255,0.1)", background: "rgba(0,0,0,0.2)" }}>
          <div style={{ fontSize: 12, lineHeight: 1.6, marginBottom: 8 }}>
            <Flex justify="space-between">
              <span style={{ color: "rgba(255,255,255,0.45)" }}>选中节点</span>
              <span style={{ color: "#1677ff", fontWeight: "bold" }}>{selectedNodeData?.className || "--"}</span>
            </Flex>
            <Flex justify="space-between">
              <span style={{ color: "rgba(255,255,255,0.45)" }}>元素标识</span>
              <span>{selectedNodeData?.identifier || "--"}</span>
            </Flex>
            <Flex justify="space-between">
              <span style={{ color: "rgba(255,255,255,0.45)" }}>AX 文本</span>
              <span>{selectedNodeData?.axText ? `"${selectedNodeData.axText}"` : "--"}</span>
            </Flex>
            <Flex justify="space-between">
              <span style={{ color: "rgba(255,255,255,0.45)" }}>几何框架</span>
              <span>{selectedNodeData?.frame || "--"}</span>
            </Flex>
          </div>
          {selectedNodeDetails && (
            <Button
              type="text"
              size="small"
              block
              icon={<Maximize2 size={12} />}
              onClick={() => setDetailsModalOpen(true)}
              style={{ color: "rgba(255,255,255,0.65)" }}
            >
              查看更多信息
            </Button>
          )}
          <Button type="primary" size="small" block onClick={() => message.success("选中节点的 DTO JSON 已复制到剪切板")} disabled={!selectedNodeData || !currentStream}>
            复制 DTO JSON
          </Button>
        </div>
      </div>
      <Modal
        title="节点详情"
        open={detailsModalOpen}
        onCancel={() => setDetailsModalOpen(false)}
        footer={null}
        width={720}
        centered
        destroyOnHidden
      >
        {selectedNodeDetails && (
          <div style={{ fontSize: 12 }}>
            <Flex justify="space-between">
              <span style={{ color: "rgba(255,255,255,0.45)" }}>节点 ID</span>
              <span style={{ overflowWrap: "anywhere", textAlign: "right" }}>{selectedNodeDetails.id || "--"}</span>
            </Flex>
            <Flex justify="space-between">
              <span style={{ color: "rgba(255,255,255,0.45)" }}>父节点</span>
              <span style={{ overflowWrap: "anywhere", textAlign: "right" }}>{selectedNodeDetails.parentId || "--"}</span>
            </Flex>
            <Flex justify="space-between">
              <span style={{ color: "rgba(255,255,255,0.45)" }}>层级 / 来源</span>
              <span>{selectedNodeDetails.depth ?? "--"} / {selectedNodeDetails.source || selectedNodeDetails.raw?.source || "--"}</span>
            </Flex>
            <Flex justify="space-between">
              <span style={{ color: "rgba(255,255,255,0.45)" }}>状态</span>
              <span>{selectedNodeDetails.visible === false ? "隐藏" : "可见"} · {selectedNodeDetails.interactive ? "可交互" : "只读"}</span>
            </Flex>
            <pre
              style={{
                background: "rgba(0,0,0,0.24)",
                border: "1px solid rgba(255,255,255,0.08)",
                borderRadius: 6,
                color: "rgba(255,255,255,0.72)",
                fontSize: 11,
                lineHeight: 1.45,
                margin: "12px 0 0",
                maxHeight: "52vh",
                overflow: "auto",
                padding: 8,
                whiteSpace: "pre-wrap",
                overflowWrap: "anywhere",
              }}
            >
              {JSON.stringify(selectedNodeDetails, null, 2)}
            </pre>
          </div>
        )}
      </Modal>
    </Card>
  );
}

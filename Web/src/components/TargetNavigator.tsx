import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import { DownOutlined } from "@ant-design/icons";
import { Input, Tree } from "antd";
import type { DataNode } from "antd/es/tree";
import { Search } from "lucide-react";
import {
  defaultViewTreeSelection,
  readableViewTreeLabel,
  readableViewTreeName,
  viewTreeNodesForScene,
  type HierarchyCacheEntry,
  type ViewTreeNode,
} from "./inspectorWorkspaceModel";

export function TargetNavigator({
  hierarchy,
  selectedHierarchyNode,
  onSelectHierarchyNode,
}: {
  hierarchy?: HierarchyCacheEntry;
  selectedHierarchyNode: string | null;
  onSelectHierarchyNode: (nodeId: string | null) => void;
}) {
  const [searchValue, setSearchValue] = useState("");
  const [width, setWidth] = useState(288);
  const isDragging = useRef(false);
  const startX = useRef(0);
  const startWidth = useRef(0);

  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    isDragging.current = true;
    startX.current = e.clientX;
    startWidth.current = width;
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
  }, [width]);

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (!isDragging.current) return;
      const delta = e.clientX - startX.current;
      const newWidth = Math.max(180, Math.min(500, startWidth.current + delta));
      setWidth(newWidth);
    };

    const handleMouseUp = () => {
      if (isDragging.current) {
        isDragging.current = false;
        document.body.style.cursor = "";
        document.body.style.userSelect = "";
      }
    };

    document.addEventListener("mousemove", handleMouseMove);
    document.addEventListener("mouseup", handleMouseUp);
    return () => {
      document.removeEventListener("mousemove", handleMouseMove);
      document.removeEventListener("mouseup", handleMouseUp);
    };
  }, []);

  return (
    <aside className="hub-sidebar" aria-label="视图层级" style={{ width } as CSSProperties}>
      <ViewTreePanel
        hierarchy={hierarchy}
        selectedHierarchyNode={selectedHierarchyNode}
        searchValue={searchValue}
        onSelectHierarchyNode={onSelectHierarchyNode}
      />
      <div className="sidebar-search-box">
        <Input
          className="sidebar-search"
          prefix={<Search size={14} />}
          placeholder="搜索节点"
          allowClear
          value={searchValue}
          onChange={(e) => setSearchValue(e.target.value)}
        />
      </div>
      <div
        className="sidebar-resize-handle"
        onMouseDown={handleMouseDown}
      />
    </aside>
  );
}

function ViewTreePanel({
  hierarchy,
  selectedHierarchyNode,
  searchValue,
  onSelectHierarchyNode,
}: {
  hierarchy?: HierarchyCacheEntry;
  selectedHierarchyNode: string | null;
  searchValue: string;
  onSelectHierarchyNode: (nodeId: string | null) => void;
}) {
  const hierarchyScene = hierarchy?.scene;
  const treeNodes = useMemo(() => (hierarchyScene ? viewTreeNodesForScene(hierarchyScene) : []), [hierarchyScene]);
  const defaultSelection = hierarchyScene ? defaultViewTreeSelection(hierarchyScene) : null;
  const selectedNode = selectedHierarchyNode ?? defaultSelection;
  const normalizedSearch = searchValue.trim().toLowerCase();

  const { treeData, expandedKeys } = useMemo<{
    treeData: DataNode[];
    expandedKeys: string[];
  }>(() => {
    const matchesSearch = (node: ViewTreeNode): boolean => {
      if (!normalizedSearch) return true;
      const displayType = readableViewTreeLabel(node.type).toLowerCase();
      const displayName = node.name ? readableViewTreeLabel(node.name).toLowerCase() : "";
      return displayType.includes(normalizedSearch) || displayName.includes(normalizedSearch);
    };

    const hasMatchingDescendant = (node: ViewTreeNode): boolean => {
      if (matchesSearch(node)) return true;
      return node.children?.some(hasMatchingDescendant) ?? false;
    };

    const collectExpandedKeys = (node: ViewTreeNode): string[] => {
      const keys: string[] = [];
      if (node.children?.length) {
        keys.push(node.id);
        for (const child of node.children) {
          keys.push(...collectExpandedKeys(child));
        }
      }
      return keys;
    };

    const toTreeData = (node: ViewTreeNode): DataNode | null => {
      if (normalizedSearch && !hasMatchingDescendant(node)) return null;

      const displayType = readableViewTreeLabel(node.type);
      const displayName = readableViewTreeName(displayType, node.name ? readableViewTreeLabel(node.name) : null);
      const title = displayName ? `${displayType} ${displayName}` : displayType;

      const children = node.children
        ?.map((child) => toTreeData(child))
        .filter((child): child is DataNode => child !== null);

      return {
        key: node.id,
        title,
        children: children?.length ? children : undefined,
      };
    };

    const filteredData = treeNodes
      .map((node) => toTreeData(node))
      .filter((node): node is DataNode => node !== null);

    let expanded: string[] = [];
    if (normalizedSearch) {
      for (const node of treeNodes) {
        if (hasMatchingDescendant(node)) {
          expanded.push(...collectExpandedKeys(node));
        }
      }
      expanded = [...new Set(expanded)];
    } else {
      expanded = hierarchyScene?.nodes.map((n) => n.id) ?? [];
    }

    return { treeData: filteredData, expandedKeys: expanded };
  }, [treeNodes, normalizedSearch, hierarchyScene]);

  if (hierarchy?.loading && !hierarchyScene) {
    return <p className="view-tree-empty">加载中...</p>;
  }

  if (hierarchy?.error && !hierarchyScene) {
    return (
      <div className="view-tree-empty" title={hierarchy.error}>
        <p>加载失败</p>
        <small>{hierarchy.error}</small>
      </div>
    );
  }

  if (!hierarchyScene) {
    return <p className="view-tree-empty">暂无数据</p>;
  }

  return (
    <Tree
      className="view-tree"
      showLine
      blockNode
      expandedKeys={expandedKeys}
      selectedKeys={selectedNode ? [selectedNode] : []}
      treeData={treeData}
      switcherIcon={({ expanded }) => (
        <DownOutlined
          style={{ transform: `rotate(${expanded ? 0 : -90}deg)`, transition: "transform 0.3s" }}
        />
      )}
      onSelect={(keys) => onSelectHierarchyNode(String(keys[0] ?? ""))}
    />
  );
}

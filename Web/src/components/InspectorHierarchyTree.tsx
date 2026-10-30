import { useEffect, useId, useLayoutEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { Icon } from "@linhey/rhine-design";
import type { HierarchyTreeNode } from "../inspect/hierarchyDerive";
import "./inspectorTree.css";

// Temporary design adaptation: https://github.com/linhay/rhine-design/issues/117
// Product hierarchy browsing needs tree semantics; TreeSelect is a different interaction.
export type InspectorTreeRow = {
  node: HierarchyTreeNode;
  parentId: string | null;
  level: number;
  position: number;
  siblingCount: number;
};

export function visibleInspectorRows(nodes: HierarchyTreeNode[], collapsed: ReadonlySet<string>): InspectorTreeRow[] {
  const rows: InspectorTreeRow[] = [];
  const visit = (siblings: HierarchyTreeNode[], parentId: string | null, level: number) => {
    siblings.forEach((node, index) => {
      rows.push({ node, parentId, level, position: index + 1, siblingCount: siblings.length });
      if (!collapsed.has(node.id)) visit(node.children, node.id, level + 1);
    });
  };
  visit(nodes, null, 1);
  return rows;
}

type TreeKeyAction = { focus: string } | { expand: string } | { collapse: string } | { select: string };
export function inspectorTreeKeyAction(rows: InspectorTreeRow[], id: string, key: string, collapsed: ReadonlySet<string>): TreeKeyAction | null {
  const index = rows.findIndex(row => row.node.id === id);
  const row = rows[index];
  if (!row) return null;
  if (key === "ArrowDown") return { focus: rows[Math.min(rows.length - 1, index + 1)].node.id };
  if (key === "ArrowUp") return { focus: rows[Math.max(0, index - 1)].node.id };
  if (key === "Home") return { focus: rows[0].node.id };
  if (key === "End") return { focus: rows[rows.length - 1].node.id };
  if (key === "ArrowRight" && row.node.children.length) {
    return collapsed.has(id) ? { expand: id } : { focus: row.node.children[0].id };
  }
  if (key === "ArrowLeft") {
    if (row.node.children.length && !collapsed.has(id)) return { collapse: id };
    if (row.parentId) return { focus: row.parentId };
  }
  if (key === "Enter" || key === " ") return { select: id };
  return null;
}

export function recoverInspectorFocus(previousRows: InspectorTreeRow[], rows: InspectorTreeRow[], focusedId: string | null): string | null {
  const visible = new Set(rows.map(row => row.node.id));
  if (focusedId && visible.has(focusedId)) return focusedId;
  const previous = new Map(previousRows.map(row => [row.node.id, row.parentId]));
  const visited = new Set<string>();
  let parent = focusedId ? previous.get(focusedId) : null;
  while (parent && !visited.has(parent)) {
    if (visible.has(parent)) return parent;
    visited.add(parent);
    parent = previous.get(parent);
  }
  return rows[0]?.node.id ?? null;
}

export function inspectorNullBlurReleasesFocus(rows: InspectorTreeRow[], blurredId: string | null, isConnected: boolean): boolean {
  // Removal can emit focusout before DOM detachment; use the pending visible rows too.
  return isConnected && (blurredId === null || rows.some(row => row.node.id === blurredId));
}

const EMPTY_UPDATED = new Set<string>();
export type InspectorHierarchyTreeProps = {
  nodes: HierarchyTreeNode[];
  label: string;
  selectedNodeId?: string | null;
  hoveredNodeId?: string | null;
  updatedNodeIds?: ReadonlySet<string>;
  updateRevision?: number;
  onSelect: (id: string | null) => void;
  onHover: (id: string | null) => void;
};

export function InspectorHierarchyTree({ nodes, label, selectedNodeId, hoveredNodeId, updatedNodeIds = EMPTY_UPDATED, updateRevision = 0, onSelect, onHover }: InspectorHierarchyTreeProps) {
  const instanceId = useId();
  const tree = useRef<HTMLDivElement>(null);
  const [collapsed, setCollapsed] = useState<Set<string>>(() => new Set());
  const [focusedId, setFocusedId] = useState<string | null>(selectedNodeId ?? null);
  const elements = useRef(new Map<string, HTMLDivElement>());
  const rowElements = useRef(new Map<string, HTMLDivElement>());
  const ownsFocus = useRef(false);
  const hoverRef = useRef(onHover);
  hoverRef.current = onHover;
  const allRows = useMemo(() => visibleInspectorRows(nodes, new Set()), [nodes]);
  const rows = useMemo(() => visibleInspectorRows(nodes, collapsed), [nodes, collapsed]);
  const previousRows = useRef(rows);
  const currentState = useRef({ rows, selectedNodeId });
  currentState.current = { rows, selectedNodeId };
  const pendingReveal = useRef<string | null>(null);
  const previousSelection = useRef(selectedNodeId);
  const tabStop = recoverInspectorFocus(previousRows.current, rows, focusedId);

  const reveal = (id: string) => {
    // The item wrapper owns its entire subtree; reveal the visible row instead.
    rowElements.current.get(id)?.scrollIntoView({ block: "nearest", inline: "nearest" });
  };
  const focus = (id: string | null) => {
    setFocusedId(id);
    const element = id ? elements.current.get(id) : tree.current;
    element?.focus({ preventScroll: true });
    if (id) reveal(id);
  };

  useLayoutEffect(() => {
    const next = recoverInspectorFocus(previousRows.current, rows, focusedId);
    previousRows.current = rows;
    if (next !== focusedId) {
      setFocusedId(next);
      if (ownsFocus.current) focus(next);
    }
    const pending = pendingReveal.current;
    if (pending && rowElements.current.has(pending)) {
      reveal(pending);
      pendingReveal.current = null;
    }
  }, [rows, focusedId]);

  // Only a changed external selection reveals ancestors; a refresh must not undo a deliberate collapse.
  useEffect(() => {
    if (previousSelection.current === selectedNodeId) return;
    previousSelection.current = selectedNodeId;
    if (!selectedNodeId) return;
    const byId = new Map(allRows.map(row => [row.node.id, row]));
    const ancestors = new Set<string>();
    let parent = byId.get(selectedNodeId)?.parentId;
    while (parent && !ancestors.has(parent)) {
      ancestors.add(parent);
      parent = byId.get(parent)?.parentId;
    }
    pendingReveal.current = selectedNodeId;
    setCollapsed(current => {
      if (![...ancestors].some(id => current.has(id))) return current;
      return new Set([...current].filter(id => !ancestors.has(id)));
    });
    if (rowElements.current.has(selectedNodeId)) {
      reveal(selectedNodeId);
      pendingReveal.current = null;
    }
    if (!ownsFocus.current) setFocusedId(selectedNodeId);
  }, [selectedNodeId, allRows]);

  useEffect(() => {
    const element = tree.current;
    const document = element?.ownerDocument;
    const view = document?.defaultView;
    if (!element || !document || !view) return;
    const release = () => {
      ownsFocus.current = false;
      const current = currentState.current;
      setFocusedId(current.rows.some(row => row.node.id === current.selectedNodeId) ? current.selectedNodeId ?? null : current.rows[0]?.node.id ?? null);
    };
    const outside = (event: Event) => { if (!element.contains(event.target as Node)) release(); };
    const blur = (event: FocusEvent) => {
      if (event.relatedTarget && element.contains(event.relatedTarget as Node)) return;
      const target = event.target as HTMLElement | null;
      const blurredId = target?.closest<HTMLElement>("[data-node-id]")?.dataset.nodeId ?? null;
      if (event.relatedTarget || inspectorNullBlurReleasesFocus(currentState.current.rows, blurredId, target?.isConnected ?? false)) release();
    };
    document.addEventListener("pointerdown", outside, true);
    document.addEventListener("focusin", outside, true);
    element.addEventListener("focusout", blur);
    view.addEventListener("blur", release);
    return () => {
      document.removeEventListener("pointerdown", outside, true);
      document.removeEventListener("focusin", outside, true);
      element.removeEventListener("focusout", blur);
      view.removeEventListener("blur", release);
      hoverRef.current(null);
    };
  }, []);

  const setExpanded = (id: string, expanded: boolean) => {
    setCollapsed(current => {
      const next = new Set(current);
      if (expanded) next.delete(id); else next.add(id);
      return next;
    });
  };
  const byId = new Map(allRows.map(row => [row.node.id, row]));
  const renderNodes = (siblings: HierarchyTreeNode[]): ReactNode => siblings.map(node => {
    const row = byId.get(node.id)!;
    const expanded = !collapsed.has(node.id);
    const hasChildren = node.children.length > 0;
    const className = node.type || node.className || "Unknown";
    const text = node.view?.accessibilityLabel || node.style?.text || "";
    const identifier = node.view?.accessibilityIdentifier || "";
    const updated = updatedNodeIds.has(node.id);
    const accessibleName = [className, text && `“${text}”`, identifier && `[${identifier}]`, updated && "已更新"].filter(Boolean).join(" ");
    return <div key={node.id} id={`${instanceId}-${encodeURIComponent(node.id)}`}
      ref={element => { if (element) elements.current.set(node.id, element); else elements.current.delete(node.id); }}
      role="treeitem" aria-label={accessibleName} aria-level={row.level} aria-posinset={row.position} aria-setsize={row.siblingCount}
      aria-expanded={hasChildren ? expanded : undefined} aria-selected={selectedNodeId === node.id}
      tabIndex={tabStop === node.id ? 0 : -1} data-node-id={node.id} className="rhine-inspector-tree-item"
      onFocus={event => { if (event.target === event.currentTarget) { ownsFocus.current = true; setFocusedId(node.id); reveal(node.id); } }}
      onKeyDown={event => {
        if (event.target !== event.currentTarget || event.altKey || event.ctrlKey || event.metaKey) return;
        const action = inspectorTreeKeyAction(rows, node.id, event.key, collapsed);
        if (!action) return;
        event.preventDefault(); event.stopPropagation();
        if ("focus" in action) focus(action.focus);
        else if ("expand" in action) setExpanded(action.expand, true);
        else if ("collapse" in action) setExpanded(action.collapse, false);
        else onSelect(action.select);
      }}>
      {/* Restart only the visual update; the focus-owning treeitem and child group keep their identity. */}
      <div key={updated ? updateRevision : "idle"} ref={element => { if (element) rowElements.current.set(node.id, element); else rowElements.current.delete(node.id); }}
        data-tree-row={node.id} data-update-revision={updated ? updateRevision : undefined} data-updated={updated || undefined} data-hovered={hoveredNodeId === node.id || undefined}
        className="rhine-inspector-tree-row" style={{ "--rhine-inspector-depth": Math.min(row.level - 1, 3) } as CSSProperties}
        onMouseEnter={() => onHover(node.id)} onMouseLeave={() => onHover(null)}
        onClick={() => { focus(node.id); onSelect(node.id); }}>
        {hasChildren ? <button type="button" tabIndex={-1} className="rhine-inspector-tree-toggle"
          aria-label={`${expanded ? "折叠" : "展开"} ${className}`}
          onClick={event => { event.stopPropagation(); focus(node.id); setExpanded(node.id, !expanded); }}>
          <Icon name={expanded ? "chevronDown" : "chevronRight"} size={16} />
        </button> : <span className="rhine-inspector-tree-leaf" aria-hidden="true" />}
        <span className="rhine-inspector-tree-title"><strong>{className}</strong>{text && <span>“{text}”</span>}{identifier && <span>[{identifier}]</span>}
          {row.level > 4 && <span className="rhine-inspector-tree-depth">第 {row.level} 层</span>}
          {updated && <span className="rhine-inspector-tree-updated">已更新</span>}
        </span>
      </div>
      {hasChildren && expanded && <div role="group">{renderNodes(node.children)}</div>}
    </div>;
  });

  return <div ref={tree} role="tree" aria-label={label} className="rhine-inspector-tree" tabIndex={rows.length ? -1 : 0}
    onFocus={event => { if (event.target === event.currentTarget) ownsFocus.current = true; }}>
    {renderNodes(nodes)}
  </div>;
}

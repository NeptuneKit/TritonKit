import React, { createContext, useContext, useState, useCallback, useMemo, useReducer, useRef } from 'react';
import type { LayoutNode } from "./layoutModel";
import type { DeviceTarget, HierarchyScene } from "./types";
import { inspectHierarchyQuery } from "./inspect/hierarchyQuery";
import {
  createInspectSessionState,
  getSession,
  inspectSessionReducer,
  resolveSlotTargetKey,
  type InspectSession,
  type SlotBinding,
} from "./inspect/sessionStore";
import { inspectTargetFromDeviceTarget, type InspectTarget } from "./inspect/target";

export interface StreamState {
  nodeId: string;
  udid: string;
  name: string;
  platform: "ios" | "android" | "harmony";
  scope?: string;
  kind?: string;
  source?: string;
  targetKey?: string;
}

export interface HierarchyFetchOptions {
  scope?: string;
  kind?: string;
  source?: string;
}

interface AppContextType {
  layoutRoot: LayoutNode | null;
  activeStreams: StreamState[];
  focusedNodeId: string | null;
  registerStream: (state: StreamState) => void;
  unregisterStream: (nodeId: string) => void;
  setFocusedNodeId: (nodeId: string) => void;
  selectedNodeId: string | null;
  setSelectedNodeId: (id: string | null) => void;
  hoveredNodeId: string | null;
  setHoveredNodeId: (id: string | null) => void;
  hierarchyScenes: { [udid: string]: any[] };
  setHierarchyScene: (udid: string, nodes: any[]) => void;
  fetchHierarchy: (udid: string, platform: string, options?: HierarchyFetchOptions) => Promise<any[]>;
  inspectTargets: InspectTarget[];
  inspectSessions: Record<string, InspectSession>;
  loadInspectTargets: (targets: DeviceTarget[]) => InspectTarget[];
  setFocusedInspectTarget: (targetKey: string | null, sourceSlotId?: string) => void;
  bindInspectSlot: (slotId: string, binding: SlotBinding) => void;
  resolveInspectSlotTarget: (slotId: string) => InspectTarget | null;
  getInspectSession: (targetKey: string | null | undefined) => InspectSession | undefined;
  refreshInspectSession: (targetKey: string, reason: string) => Promise<HierarchyScene | null>;
  setInspectOverlayMode: (targetKey: string, mode: InspectSession["overlayMode"]) => void;
  selectInspectNode: (targetKey: string, nodeId: string | null) => void;
  hoverInspectNode: (targetKey: string, nodeId: string | null) => void;
}

export const AppContext = createContext<AppContextType | null>(null);

export function useAppContext() {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error("useAppContext must be used within AppContextProvider");
  return ctx;
}

export function AppContextProvider({ children, layoutRoot }: { children: React.ReactNode, layoutRoot: LayoutNode }) {
  const [activeStreams, setActiveStreams] = useState<StreamState[]>([]);
  const [focusedNodeId, setFocusedNodeId] = useState<string | null>(null);
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null);
  const [hoveredNodeId, setHoveredNodeId] = useState<string | null>(null);
  const [hierarchyScenes, setHierarchyScenes] = useState<{ [udid: string]: any[] }>({});
  const [inspectState, dispatchInspect] = useReducer(inspectSessionReducer, undefined, () => createInspectSessionState());
  const refreshSeqRef = useRef<Record<string, number>>({});

  const registerStream = useCallback((state: StreamState) => {
    setActiveStreams(prev => {
      const filtered = prev.filter(s => s.nodeId !== state.nodeId);
      return [...filtered, state];
    });
  }, []);

  const unregisterStream = useCallback((nodeId: string) => {
    setActiveStreams(prev => prev.filter(s => s.nodeId !== nodeId));
  }, []);

  const setHierarchyScene = useCallback((udid: string, nodes: any[]) => {
    setHierarchyScenes(prev => ({
      ...prev,
      [udid]: nodes
    }));
  }, []);

  const fetchHierarchy = useCallback(async (udid: string, platform: string, options: HierarchyFetchOptions = {}) => {
    try {
      const params = webHostHierarchyQuery(udid, platform, options);
      const res = await fetch(`/web/host-hierarchy?${params.toString()}`);
      if (!res.ok) throw new Error("Failed to fetch");
      const data = await res.json();
      if (data && data.scene && data.scene.nodes && Array.isArray(data.scene.nodes)) {
        const flatNodes = data.scene.nodes;
        setHierarchyScenes(prev => ({
          ...prev,
          [udid]: flatNodes
        }));
        return flatNodes;
      }
    } catch (e) {
      console.error("fetchHierarchy failed", e);
    }
    return [];
  }, []);

  const loadInspectTargets = useCallback((targets: DeviceTarget[]) => {
    const inspectTargets = targets.map(inspectTargetFromDeviceTarget);
    dispatchInspect({ type: "targetsLoaded", targets: inspectTargets });
    return inspectTargets;
  }, []);

  const setFocusedInspectTarget = useCallback((targetKey: string | null, sourceSlotId?: string) => {
    dispatchInspect({ type: "focusedTargetChanged", targetKey, sourceSlotId });
  }, []);

  const bindInspectSlot = useCallback((slotId: string, binding: SlotBinding) => {
    dispatchInspect({ type: "slotBindingChanged", slotId, binding });
  }, []);

  const resolveInspectSlotTarget = useCallback((slotId: string) => {
    const targetKey = resolveSlotTargetKey(inspectState, slotId);
    return inspectState.targets.find((target) => target.key === targetKey) ?? null;
  }, [inspectState]);

  const getInspectSession = useCallback((targetKey: string | null | undefined) => {
    return getSession(inspectState, targetKey);
  }, [inspectState]);

  const refreshInspectSession = useCallback(async (targetKey: string) => {
    const target = inspectState.targets.find((item) => item.key === targetKey);
    if (!target) return null;
    const seq = (refreshSeqRef.current[targetKey] ?? 0) + 1;
    refreshSeqRef.current[targetKey] = seq;
    dispatchInspect({ type: "sessionRefreshStarted", targetKey, seq });
    try {
      const params = inspectHierarchyQuery(target);
      const res = await fetch(`/web/host-hierarchy?${params.toString()}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      if (!data?.scene?.nodes || !Array.isArray(data.scene.nodes)) {
        throw new Error("Hierarchy scene is missing nodes");
      }
      dispatchInspect({ type: "sessionRefreshSucceeded", targetKey, seq, scene: data.scene });
      setHierarchyScenes(prev => ({
        ...prev,
        [target.target]: data.scene.nodes
      }));
      return data.scene;
    } catch (error) {
      dispatchInspect({ type: "sessionRefreshFailed", targetKey, seq, error: (error as Error).message });
      return null;
    }
  }, [inspectState.targets]);

  const setInspectOverlayMode = useCallback((targetKey: string, mode: InspectSession["overlayMode"]) => {
    dispatchInspect({ type: "sessionOverlayChanged", targetKey, mode });
  }, []);

  const selectInspectNode = useCallback((targetKey: string, nodeId: string | null) => {
    dispatchInspect({ type: "sessionNodeSelected", targetKey, nodeId });
    setSelectedNodeId(nodeId);
  }, []);

  const hoverInspectNode = useCallback((targetKey: string, nodeId: string | null) => {
    dispatchInspect({ type: "sessionNodeHovered", targetKey, nodeId });
    setHoveredNodeId(nodeId);
  }, []);

  const value = useMemo(() => ({
    layoutRoot,
    activeStreams,
    focusedNodeId,
    registerStream,
    unregisterStream,
    setFocusedNodeId,
    selectedNodeId,
    setSelectedNodeId,
    hoveredNodeId,
    setHoveredNodeId,
    hierarchyScenes,
    setHierarchyScene,
    fetchHierarchy,
    inspectTargets: inspectState.targets,
    inspectSessions: inspectState.sessions,
    loadInspectTargets,
    setFocusedInspectTarget,
    bindInspectSlot,
    resolveInspectSlotTarget,
    getInspectSession,
    refreshInspectSession,
    setInspectOverlayMode,
    selectInspectNode,
    hoverInspectNode,
  }), [
    layoutRoot,
    activeStreams,
    focusedNodeId,
    registerStream,
    unregisterStream,
    setFocusedNodeId,
    selectedNodeId,
    setSelectedNodeId,
    hoveredNodeId,
    setHoveredNodeId,
    hierarchyScenes,
    setHierarchyScene,
    fetchHierarchy,
    inspectState.targets,
    inspectState.sessions,
    loadInspectTargets,
    setFocusedInspectTarget,
    bindInspectSlot,
    resolveInspectSlotTarget,
    getInspectSession,
    refreshInspectSession,
    setInspectOverlayMode,
    selectInspectNode,
    hoverInspectNode,
  ]);

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function webHostHierarchyQuery(udid: string, platform: string, options: HierarchyFetchOptions = {}) {
  const params = new URLSearchParams({ platform, target: udid });
  if (options.scope) params.set("scope", options.scope);
  if (options.kind) params.set("kind", options.kind);
  const source = options.source ?? defaultHierarchySource(udid, platform, options);
  if (source) params.set("source", source);
  return params;
}

function defaultHierarchySource(udid: string, platform: string, options: HierarchyFetchOptions) {
  if (platform !== "ios") return undefined;
  if (options.scope === "real" || options.kind === "real-device" || udid.startsWith("ios-real:")) return "runtime";
  return "host";
}

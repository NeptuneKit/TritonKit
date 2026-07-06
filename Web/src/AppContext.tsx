import React, { createContext, useContext, useState, useCallback, useMemo } from 'react';
import type { LayoutNode } from "./layoutModel";

export interface StreamState {
  nodeId: string;
  udid: string;
  name: string;
  platform: "ios" | "android" | "harmony";
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
  fetchHierarchy: (udid: string, platform: string) => Promise<any[]>;
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

  const fetchHierarchy = useCallback(async (udid: string, platform: string) => {
    try {
      const params = new URLSearchParams({ platform, target: udid });
      if (platform === "ios") params.set("source", "runtime");
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
    fetchHierarchy
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
    fetchHierarchy
  ]);

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

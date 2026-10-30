import { useCallback, useEffect, useMemo, useReducer, useRef, useState, type ContextType, type ReactNode } from "react";
import { AppContext, type StreamState } from "../src/AppContext";
import { createInspectSessionState, getSession, inspectSessionReducer, resolveSlotTargetKey, type InspectSessionAction, type InspectSessionState, type SlotBinding } from "../src/inspect/sessionStore";
import { inspectTargetFromDeviceTarget } from "../src/inspect/target";
import type { DevicePlatform, DeviceTarget, HierarchyLayerNode, HierarchyScene } from "../src/types";
import { makeSyntheticHierarchy, makeSyntheticTargets } from "./syntheticData";

type ContextValue = NonNullable<ContextType<typeof AppContext>>;
export type SyntheticContextProviderProps = {
  children: ReactNode;
  platform?: DevicePlatform;
  state?: string;
  selectedNode?: boolean;
};
type Configuration = { platform: DevicePlatform; state: string; selectedNode: boolean };
type SyntheticAction = InspectSessionAction | { type: "syntheticReset"; value: InspectSessionState };

function initialState({ platform, state, selectedNode }: Configuration): InspectSessionState {
  const targets = makeSyntheticTargets(state === "empty" ? "ready" : state).map(inspectTargetFromDeviceTarget);
  const result = createInspectSessionState(targets);
  result.focusedTargetKey = targets.find(target => target.platform === platform)?.key ?? targets[0]?.key ?? null;
  for (const target of targets) {
    result.sessions[target.key] = {
      ...result.sessions[target.key], scene: makeSyntheticHierarchy(target.platform, state),
      selectedNodeId: selectedNode && state !== "empty" ? "child-action" : null,
      loading: state === "loading", error: state === "error" ? "合成层级读取失败；可重试验证恢复路径。" : undefined,
      stale: state === "error", overlayMode: "view", updatedAt: 1,
    };
  }
  return result;
}

export function SyntheticContextProvider({ children, platform = "ios", state = "ready", selectedNode = false }: SyntheticContextProviderProps) {
  const configuration = useRef<Configuration>({ platform, state, selectedNode });
  configuration.current = { platform, state, selectedNode };
  const [inspect, dispatch] = useReducer((current: InspectSessionState, action: SyntheticAction) =>
    action.type === "syntheticReset" ? action.value : inspectSessionReducer(current, action), configuration.current, initialState);
  const inspectRef = useRef(inspect);
  inspectRef.current = inspect;
  const [activeStreams, setActiveStreams] = useState<StreamState[]>([]);
  const [focusedNodeId, setFocusedNodeId] = useState<string | null>(null);
  const pending = useRef(new Map<ReturnType<typeof setTimeout>, (scene: HierarchyScene | null) => void>());
  const sequence = useRef<Record<string, number>>({});
  const revision = useRef(0);
  const generation = useRef(0);
  const mounted = useRef(true);
  const initialConfiguration = useRef(`${platform}:${state}:${selectedNode}`);

  const cancelPending = useCallback(() => {
    generation.current++;
    for (const [timer, resolve] of pending.current) { clearTimeout(timer); resolve(null); }
    pending.current.clear();
  }, []);
  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; cancelPending(); };
  }, [cancelPending]);
  useEffect(() => {
    const key = `${platform}:${state}:${selectedNode}`;
    if (key === initialConfiguration.current) return;
    cancelPending();
    initialConfiguration.current = key;
    sequence.current = {};
    revision.current = 0;
    dispatch({ type: "syntheticReset", value: initialState(configuration.current) });
  }, [platform, state, selectedNode, cancelPending]);

  const registerStream = useCallback((stream: StreamState) => setActiveStreams(current => {
    const existing = current.find(item => item.nodeId === stream.nodeId);
    if (existing && JSON.stringify(existing) === JSON.stringify(stream)) return current;
    return [...current.filter(item => item.nodeId !== stream.nodeId), stream];
  }), []);
  const unregisterStream = useCallback((nodeId: string) => setActiveStreams(current => current.some(item => item.nodeId === nodeId) ? current.filter(item => item.nodeId !== nodeId) : current), []);
  const loadInspectTargets = useCallback((targets: DeviceTarget[]) => {
    const next = targets.map(inspectTargetFromDeviceTarget);
    dispatch({ type: "targetsLoaded", targets: next });
    return next;
  }, []);
  const setFocusedInspectTarget = useCallback((targetKey: string | null, sourceSlotId?: string) => {
    dispatch({ type: "focusedTargetChanged", targetKey, sourceSlotId });
  }, []);
  const bindInspectSlot = useCallback((slotId: string, binding: SlotBinding) => {
    if (JSON.stringify(inspectRef.current.slotBindings[slotId]) !== JSON.stringify(binding)) dispatch({ type: "slotBindingChanged", slotId, binding });
  }, []);
  const resolveInspectSlotTarget = useCallback((slotId: string) => {
    const current = inspectRef.current;
    const key = resolveSlotTargetKey(current, slotId);
    return current.targets.find(target => target.key === key) ?? null;
  }, []);
  const getInspectSession = useCallback((targetKey: string | null | undefined) => getSession(inspectRef.current, targetKey), []);
  const refreshInspectSession = useCallback((targetKey: string, _reason: string): Promise<HierarchyScene | null> => {
    const target = inspectRef.current.targets.find(item => item.key === targetKey);
    if (!target || !mounted.current) return Promise.resolve(null);
    const seq = Math.max(sequence.current[targetKey] ?? 0, inspectRef.current.sessions[targetKey]?.requestSeq ?? 0) + 1;
    sequence.current[targetKey] = seq;
    const requestGeneration = generation.current;
    const config = configuration.current;
    dispatch({ type: "sessionRefreshStarted", targetKey, seq });
    return new Promise(resolve => {
      const timer = setTimeout(() => {
        pending.current.delete(timer);
        if (!mounted.current || requestGeneration !== generation.current || seq !== sequence.current[targetKey]) { resolve(null); return; }
        if (config.state === "loading") { resolve(null); return; }
        if (config.state === "error") {
          dispatch({ type: "sessionRefreshFailed", targetKey, seq, error: "合成层级读取失败；可重试验证恢复路径。" });
          resolve(null); return;
        }
        const scene = makeSyntheticHierarchy(target.platform, config.state);
        const currentRevision = ++revision.current;
        // Synthetic deletion verifies focus recovery without touching a device.
        if (config.state === "deep" && currentRevision > 1) {
          scene.nodes = scene.nodes.filter(node => node.id !== "deep-23");
        }
        scene.nodes = scene.nodes.map(node => node.id === "child-action" ? { ...node,
          view: { ...node.view, accessibilityLabel: `${node.view?.accessibilityLabel ?? "Synthetic action"} · refresh ${currentRevision}` } } : node);
        dispatch({ type: "sessionRefreshSucceeded", targetKey, seq, scene });
        resolve(scene);
      }, 240);
      pending.current.set(timer, resolve);
    });
  }, []);
  const setInspectOverlayMode = useCallback((targetKey: string, mode: "none" | "view" | "ax") => {
    dispatch({ type: "sessionOverlayChanged", targetKey, mode });
  }, []);
  const selectInspectNode = useCallback((targetKey: string, nodeId: string | null) => {
    dispatch({ type: "sessionNodeSelected", targetKey, nodeId });
  }, []);
  const hoverInspectNode = useCallback((targetKey: string, nodeId: string | null) => {
    if (inspectRef.current.sessions[targetKey]?.hoveredNodeId !== nodeId) dispatch({ type: "sessionNodeHovered", targetKey, nodeId });
  }, []);
  const setSelectedNodeId = useCallback((nodeId: string | null) => {
    const key = inspectRef.current.focusedTargetKey;
    if (key) dispatch({ type: "sessionNodeSelected", targetKey: key, nodeId });
  }, []);
  const setHoveredNodeId = useCallback((nodeId: string | null) => {
    const key = inspectRef.current.focusedTargetKey;
    if (key) dispatch({ type: "sessionNodeHovered", targetKey: key, nodeId });
  }, []);
  const setHierarchyScene = useCallback((udid: string, nodes: HierarchyLayerNode[]) => {
    const target = inspectRef.current.targets.find(item => item.target === udid);
    if (!target) return;
    const seq = Math.max(sequence.current[target.key] ?? 0, inspectRef.current.sessions[target.key]?.requestSeq ?? 0) + 1;
    sequence.current[target.key] = seq;
    dispatch({ type: "sessionRefreshStarted", targetKey: target.key, seq });
    dispatch({ type: "sessionRefreshSucceeded", targetKey: target.key, seq,
      scene: { ...makeSyntheticHierarchy(target.platform, "empty"), nodes } });
  }, []);
  const fetchHierarchy = useCallback(async (udid: string, _platform: string) => {
    const target = inspectRef.current.targets.find(item => item.target === udid);
    if (!target) return [];
    return (await refreshInspectSession(target.key, "syntheticLegacyRead"))?.nodes ?? [];
  }, [refreshInspectSession]);

  const value = useMemo<ContextValue>(() => {
    const focused = getSession(inspect, inspect.focusedTargetKey);
    return {
      layoutRoot: null, activeStreams, focusedNodeId, registerStream, unregisterStream, setFocusedNodeId,
      selectedNodeId: focused?.selectedNodeId ?? null, setSelectedNodeId,
      hoveredNodeId: focused?.hoveredNodeId ?? null, setHoveredNodeId,
      hierarchyScenes: Object.fromEntries(inspect.targets.map(target => [target.target, inspect.sessions[target.key]?.scene?.nodes ?? []])),
      setHierarchyScene, fetchHierarchy, inspectTargets: inspect.targets, inspectSessions: inspect.sessions,
      loadInspectTargets, setFocusedInspectTarget, bindInspectSlot, resolveInspectSlotTarget, getInspectSession,
      refreshInspectSession, setInspectOverlayMode, selectInspectNode, hoverInspectNode,
    };
  }, [inspect, activeStreams, focusedNodeId, registerStream, unregisterStream, setSelectedNodeId, setHoveredNodeId,
    setHierarchyScene, fetchHierarchy, loadInspectTargets, setFocusedInspectTarget, bindInspectSlot, resolveInspectSlotTarget,
    getInspectSession, refreshInspectSession, setInspectOverlayMode, selectInspectNode, hoverInspectNode]);
  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

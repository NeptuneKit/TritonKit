import type { HierarchyScene } from "../types";
import type { InspectTarget } from "./target";

export type SlotBinding =
  | { mode: "followWorkbenchFocus" }
  | { mode: "followSlot"; slotId: string }
  | { mode: "pinnedTarget"; targetKey: string };

export type InspectSession = {
  targetKey: string;
  scene?: HierarchyScene;
  selectedNodeId?: string | null;
  hoveredNodeId?: string | null;
  overlayMode: "none" | "view" | "ax";
  loading: boolean;
  error?: string;
  stale: boolean;
  updatedAt?: number;
  requestSeq: number;
};

export type InspectSessionState = {
  targets: InspectTarget[];
  focusedTargetKey: string | null;
  sourceSlotTargets: Record<string, string>;
  slotBindings: Record<string, SlotBinding>;
  sessions: Record<string, InspectSession>;
};

export type InspectSessionAction =
  | { type: "targetsLoaded"; targets: InspectTarget[] }
  | { type: "focusedTargetChanged"; targetKey: string | null; sourceSlotId?: string }
  | { type: "slotBindingChanged"; slotId: string; binding: SlotBinding }
  | { type: "sessionRefreshStarted"; targetKey: string; seq: number }
  | { type: "sessionRefreshSucceeded"; targetKey: string; seq: number; scene: HierarchyScene }
  | { type: "sessionRefreshFailed"; targetKey: string; seq: number; error: string }
  | { type: "sessionOverlayChanged"; targetKey: string; mode: InspectSession["overlayMode"] }
  | { type: "sessionNodeSelected"; targetKey: string; nodeId: string | null }
  | { type: "sessionNodeHovered"; targetKey: string; nodeId: string | null };

export function createInspectSessionState(targets: InspectTarget[] = []): InspectSessionState {
  const sessions = Object.fromEntries(targets.map((target) => [target.key, makeSession(target.key)]));
  return {
    targets,
    focusedTargetKey: targets[0]?.key ?? null,
    sourceSlotTargets: {},
    slotBindings: {},
    sessions,
  };
}

export function inspectSessionReducer(state: InspectSessionState, action: InspectSessionAction): InspectSessionState {
  switch (action.type) {
    case "targetsLoaded": {
      const sessions = { ...state.sessions };
      for (const target of action.targets) {
        sessions[target.key] ??= makeSession(target.key);
      }
      const targetKeys = new Set(action.targets.map((target) => target.key));
      return {
        ...state,
        targets: action.targets,
        focusedTargetKey: state.focusedTargetKey && targetKeys.has(state.focusedTargetKey)
          ? state.focusedTargetKey
          : action.targets[0]?.key ?? null,
        sessions,
      };
    }
    case "focusedTargetChanged":
      return {
        ...state,
        focusedTargetKey: action.targetKey,
        sourceSlotTargets: action.sourceSlotId && action.targetKey
          ? { ...state.sourceSlotTargets, [action.sourceSlotId]: action.targetKey }
          : state.sourceSlotTargets,
      };
    case "slotBindingChanged":
      return { ...state, slotBindings: { ...state.slotBindings, [action.slotId]: action.binding } };
    case "sessionRefreshStarted":
      return updateSession(state, action.targetKey, (session) => ({
        ...session,
        loading: true,
        error: undefined,
        requestSeq: action.seq,
      }));
    case "sessionRefreshSucceeded":
      return updateSessionIfCurrent(state, action.targetKey, action.seq, (session) => ({
        ...session,
        scene: action.scene,
        selectedNodeId: action.scene.nodes.some((node) => node.id === session.selectedNodeId) ? session.selectedNodeId : null,
        loading: false,
        error: undefined,
        stale: false,
        updatedAt: Date.now(),
      }));
    case "sessionRefreshFailed":
      return updateSessionIfCurrent(state, action.targetKey, action.seq, (session) => ({
        ...session,
        loading: false,
        error: action.error,
      }));
    case "sessionOverlayChanged":
      return updateSession(state, action.targetKey, (session) => ({ ...session, overlayMode: action.mode }));
    case "sessionNodeSelected":
      return updateSession(state, action.targetKey, (session) => ({ ...session, selectedNodeId: action.nodeId }));
    case "sessionNodeHovered":
      return updateSession(state, action.targetKey, (session) => ({ ...session, hoveredNodeId: action.nodeId }));
  }
}

export function resolveSlotTargetKey(state: InspectSessionState, slotId: string) {
  const binding = state.slotBindings[slotId] ?? { mode: "followWorkbenchFocus" };
  if (binding.mode === "pinnedTarget") return binding.targetKey;
  if (binding.mode === "followSlot") return state.sourceSlotTargets[binding.slotId] ?? state.focusedTargetKey;
  return state.focusedTargetKey ?? state.targets[0]?.key ?? null;
}

export function sessionRefreshRequest(state: InspectSessionState, targetKey: string) {
  const seq = (state.sessions[targetKey]?.requestSeq ?? 0) + 1;
  return {
    seq,
    state: inspectSessionReducer(state, { type: "sessionRefreshStarted", targetKey, seq }),
  };
}

export function sessionRefreshSucceeded(state: InspectSessionState, targetKey: string, seq: number, scene: HierarchyScene) {
  return inspectSessionReducer(state, { type: "sessionRefreshSucceeded", targetKey, seq, scene });
}

export function getSession(state: InspectSessionState, targetKey: string | null | undefined) {
  return targetKey ? state.sessions[targetKey] : undefined;
}

function makeSession(targetKey: string): InspectSession {
  return {
    targetKey,
    overlayMode: "none",
    loading: false,
    stale: true,
    requestSeq: 0,
  };
}

function updateSession(state: InspectSessionState, targetKey: string, update: (session: InspectSession) => InspectSession): InspectSessionState {
  const session = state.sessions[targetKey] ?? makeSession(targetKey);
  return {
    ...state,
    sessions: {
      ...state.sessions,
      [targetKey]: update(session),
    },
  };
}

function updateSessionIfCurrent(state: InspectSessionState, targetKey: string, seq: number, update: (session: InspectSession) => InspectSession): InspectSessionState {
  const session = state.sessions[targetKey] ?? makeSession(targetKey);
  if (session.requestSeq !== seq) return state;
  return updateSession(state, targetKey, update);
}

export type StreamGesturePlatform = "ios" | "android" | "harmony";
export type StreamGestureType = "tap" | "swipe" | "longPress";

export interface StreamImageLayout {
  width: number;
  height: number;
  left: number;
  top: number;
  naturalWidth: number;
  naturalHeight: number;
}

export interface ViewportRect {
  left: number;
  top: number;
}

export interface PointerClientPoint {
  clientX: number;
  clientY: number;
}

export interface DevicePoint {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface StreamGestureSession {
  pointerId: number;
  start: DevicePoint;
  startedAt: number;
  longPressSent: boolean;
}

export type StreamGestureInput =
  | {
      type: "tap" | "longPress";
      x: number;
      y: number;
      width: number;
      height: number;
      duration?: number;
    }
  | {
      type: "swipe";
      startX: number;
      startY: number;
      endX: number;
      endY: number;
      width: number;
      height: number;
      duration: number;
    };

const TAP_MOVE_THRESHOLD = 24;
export const LONG_PRESS_THRESHOLD_MS = 650;

export function mapPointerToDevicePoint(
  point: PointerClientPoint,
  viewport: ViewportRect,
  layout: StreamImageLayout,
): DevicePoint | null {
  if (layout.width <= 0 || layout.height <= 0 || layout.naturalWidth <= 0 || layout.naturalHeight <= 0) {
    return null;
  }
  const xInImage = point.clientX - viewport.left - layout.left;
  const yInImage = point.clientY - viewport.top - layout.top;
  if (xInImage < 0 || yInImage < 0 || xInImage > layout.width || yInImage > layout.height) {
    return null;
  }
  return {
    x: clampRound((xInImage / layout.width) * layout.naturalWidth, 0, layout.naturalWidth),
    y: clampRound((yInImage / layout.height) * layout.naturalHeight, 0, layout.naturalHeight),
    width: layout.naturalWidth,
    height: layout.naturalHeight,
  };
}

export function createGestureSession(input: {
  pointerId: number;
  point: DevicePoint | null;
  startedAt: number;
}): StreamGestureSession | null {
  if (!input.point) return null;
  return {
    pointerId: input.pointerId,
    start: input.point,
    startedAt: input.startedAt,
    longPressSent: false,
  };
}

export function longPressFromSession(
  session: StreamGestureSession,
  input: { now: number; currentPoint?: DevicePoint | null },
): StreamGestureInput | null {
  if (session.longPressSent) return null;
  if (input.now - session.startedAt < LONG_PRESS_THRESHOLD_MS) return null;
  if (input.currentPoint && distance(session.start, input.currentPoint) > TAP_MOVE_THRESHOLD) return null;
  session.longPressSent = true;
  return {
    type: "longPress",
    x: session.start.x,
    y: session.start.y,
    width: session.start.width,
    height: session.start.height,
    duration: seconds(input.now - session.startedAt),
  };
}

export function finishGestureSession(
  session: StreamGestureSession | null,
  input: { point: DevicePoint | null; endedAt: number },
): StreamGestureInput | null {
  if (!session || !input.point || session.longPressSent) return null;
  const duration = seconds(input.endedAt - session.startedAt);
  if (distance(session.start, input.point) <= TAP_MOVE_THRESHOLD) {
    return {
      type: "tap",
      x: input.point.x,
      y: input.point.y,
      width: input.point.width,
      height: input.point.height,
    };
  }
  return {
    type: "swipe",
    startX: session.start.x,
    startY: session.start.y,
    endX: input.point.x,
    endY: input.point.y,
    width: input.point.width,
    height: input.point.height,
    duration,
  };
}

export function webHostInputQueryForGesture(input: {
  platform: StreamGesturePlatform;
  target: string;
  gestureType: StreamGestureType;
}): string | null {
  const params = new URLSearchParams({
    platform: input.platform,
    target: input.target,
    scope: input.platform === "ios" ? "simulator" : "emulator",
    kind: input.platform === "ios" ? "simulator" : "emulator",
    source: input.platform === "ios" && input.gestureType === "longPress" ? "runtime" : "host",
  });
  return params.toString();
}

function distance(a: DevicePoint, b: DevicePoint): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function seconds(ms: number): number {
  return Math.round(Math.max(0, ms) / 10) / 100;
}

function clampRound(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, Math.round(value)));
}

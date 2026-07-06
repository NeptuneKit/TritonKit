const STREAM_TARGET_FPS_KEY = "triton-stream-target-fps";
const STREAM_TARGET_FPS_VALUES = new Set([1, 5, 15, 30, 60, 120]);

export function loadStreamTargetFps(defaultValue = 15) {
  if (typeof globalThis.localStorage?.getItem !== "function") return defaultValue;
  const value = Number(globalThis.localStorage.getItem(STREAM_TARGET_FPS_KEY));
  return STREAM_TARGET_FPS_VALUES.has(value) ? value : defaultValue;
}

export function saveStreamTargetFps(value: number) {
  if (!STREAM_TARGET_FPS_VALUES.has(value)) return;
  if (typeof globalThis.localStorage?.setItem === "function") {
    globalThis.localStorage.setItem(STREAM_TARGET_FPS_KEY, String(value));
  }
}

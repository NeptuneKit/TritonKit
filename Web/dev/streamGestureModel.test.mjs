import assert from "node:assert/strict";
import { after, test } from "node:test";
import { createServer } from "vite";

const viteServer = await createServer({
  appType: "custom",
  server: {
    hmr: false,
    middlewareMode: true,
    ws: false,
  },
});

const {
  createGestureSession,
  finishGestureSession,
  longPressFromSession,
  mapPointerToDevicePoint,
  webHostInputQueryForGesture,
} = await viteServer.ssrLoadModule("/src/streamGestureModel.ts");

after(async () => {
  await viteServer.close();
});

const viewport = { left: 10, top: 20 };
const layout = {
  left: 50,
  top: 25,
  width: 200,
  height: 400,
  naturalWidth: 1000,
  naturalHeight: 2000,
};

test("maps browser pointer coordinates to device image coordinates", () => {
  assert.deepEqual(mapPointerToDevicePoint({ clientX: 160, clientY: 245 }, viewport, layout), {
    x: 500,
    y: 1000,
    width: 1000,
    height: 2000,
  });
});

test("ignores pointer coordinates outside the rendered image", () => {
  assert.equal(mapPointerToDevicePoint({ clientX: 20, clientY: 245 }, viewport, layout), null);
});

test("short stationary pointer creates tap input", () => {
  const start = mapPointerToDevicePoint({ clientX: 160, clientY: 245 }, viewport, layout);
  const end = mapPointerToDevicePoint({ clientX: 162, clientY: 247 }, viewport, layout);
  const session = createGestureSession({ pointerId: 7, point: start, startedAt: 100 });
  assert.deepEqual(finishGestureSession(session, { point: end, endedAt: 180 }), {
    type: "tap",
    x: 510,
    y: 1010,
    width: 1000,
    height: 2000,
  });
});

test("drag beyond threshold creates swipe input instead of tap", () => {
  const start = mapPointerToDevicePoint({ clientX: 80, clientY: 145 }, viewport, layout);
  const end = mapPointerToDevicePoint({ clientX: 220, clientY: 385 }, viewport, layout);
  const session = createGestureSession({ pointerId: 7, point: start, startedAt: 100 });
  assert.deepEqual(finishGestureSession(session, { point: end, endedAt: 620 }), {
    type: "swipe",
    startX: 100,
    startY: 500,
    endX: 800,
    endY: 1700,
    width: 1000,
    height: 2000,
    duration: 0.52,
  });
});

test("long press emits once and suppresses pointerup tap", () => {
  const point = mapPointerToDevicePoint({ clientX: 160, clientY: 245 }, viewport, layout);
  const session = createGestureSession({ pointerId: 7, point, startedAt: 100 });
  assert.deepEqual(longPressFromSession(session, { now: 760 }), {
    type: "longPress",
    x: 500,
    y: 1000,
    width: 1000,
    height: 2000,
    duration: 0.66,
  });
  assert.equal(longPressFromSession(session, { now: 900 }), null);
  assert.equal(finishGestureSession(session, { point, endedAt: 920 }), null);
});

test("host input query follows platform gesture support", () => {
  assert.equal(
    webHostInputQueryForGesture({ platform: "ios", target: "SIM-1", gestureType: "tap" }),
    "platform=ios&target=SIM-1&scope=simulator&kind=simulator&source=host",
  );
  assert.equal(
    webHostInputQueryForGesture({ platform: "ios", target: "SIM-1", gestureType: "longPress" }),
    "platform=ios&target=SIM-1&scope=simulator&kind=simulator&source=host",
  );
  assert.equal(
    webHostInputQueryForGesture({ platform: "android", target: "emulator-5554", gestureType: "longPress" }),
    "platform=android&target=emulator-5554&scope=emulator&kind=emulator&source=host",
  );
  assert.equal(
    webHostInputQueryForGesture({ platform: "harmony", target: "H1", gestureType: "longPress" }),
    "platform=harmony&target=H1&scope=emulator&kind=emulator&source=host",
  );
});

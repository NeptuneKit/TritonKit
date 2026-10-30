import assert from "node:assert/strict";
import { after, test } from "node:test";
import { createServer } from "vite";
const viteServer = await createServer({ configFile: false, appType: "custom", optimizeDeps: { noDiscovery: true }, server: { hmr: false, middlewareMode: true, ws: false } });
after(() => viteServer.close());
const { observeStreamVisibility, releaseStreamImage, observeFirstStreamFrame, attachStreamImage } = await viteServer.ssrLoadModule("/src/streamVisibility.ts");
class Events {
  listeners = new Map();
  addEventListener(type, listener) { const values = this.listeners.get(type) ?? new Set(); values.add(listener); this.listeners.set(type, values); }
  removeEventListener(type, listener) { this.listeners.get(type)?.delete(listener); }
  emit(type) { for (const listener of [...(this.listeners.get(type) ?? [])]) listener({ type }); }
  listenerCount() { return [...this.listeners.values()].reduce((sum, values) => sum + values.size, 0); }
}
function fixture({ hidden = false, intersection = true } = {}) {
  const intersections = [], resizes = [], mutations = [], timers = new Map(); let timerID = 0, now = 0;
  class Observer {
    targets = []; disconnected = false;
    constructor(callback, bucket) { this.callback = callback; bucket.push(this); }
    observe(target) { this.targets.push(target); }
    disconnect() { this.disconnected = true; }
    fire(entries = []) { this.callback(entries); }
  }
  const doc = Object.assign(new Events(), { visibilityState: hidden ? "hidden" : "visible" });
  const view = Object.assign(new Events(), {
    innerWidth: 1000, innerHeight: 800, getComputedStyle: element => element.style,
    IntersectionObserver: intersection ? class extends Observer { constructor(cb) { super(cb, intersections); } } : undefined,
    ResizeObserver: class extends Observer { constructor(cb) { super(cb, resizes); } },
    MutationObserver: class extends Observer { constructor(cb) { super(cb, mutations); } },
    performance: { now: () => now },
    setTimeout(callback, delay = 0) { const id = ++timerID; timers.set(id, { callback, due: now + delay }); return id; }, clearTimeout(id) { timers.delete(id); },
  }); doc.defaultView = view;
  const makeElement = (parentElement = null) => Object.assign(new Events(), {
    ownerDocument: doc, parentElement, isConnected: true, hidden: false,
    style: { display: "block", visibility: "visible", opacity: "1", contentVisibility: "visible" },
    rect: { left: 10, top: 10, right: 510, bottom: 410, width: 500, height: 400 },
    getBoundingClientRect() { return this.rect; }, getClientRects() { return this.rect.width > 0 && this.rect.height > 0 ? [this.rect] : []; },
    hasAttribute(name) { return name === "hidden" && this.hidden; },
  });
  const ancestor = makeElement(), element = makeElement(ancestor);
  const io = (visible, target = element, width = 500, height = 400) => {
    for (const observer of intersections.filter(item => item.targets.includes(target))) observer.fire([{ target, isIntersecting: visible, intersectionRect: { width, height } }]);
  };
  const advance = (milliseconds) => {
    const target = now + milliseconds;
    while (timers.size > 0) {
      const [id, pending] = [...timers.entries()].sort((a, b) => a[1].due - b[1].due)[0];
      if (pending.due > target) break;
      now = pending.due; timers.delete(id); pending.callback();
    }
    now = target;
  };
  const tick = () => { if (timers.size > 0) advance(Math.min(...[...timers.values()].map(timer => timer.due)) - now); };
  return { doc, view, element, ancestor, makeElement, intersections, resizes, mutations, timers, tick, advance, io };
}
test("initial hidden preview never connects, visibility changes reconnect once", () => {
  const f = fixture({ hidden: true }), events = [], stop = observeStreamVisibility(f.element, value => events.push(value));
  f.io(true); assert.deepEqual(events, [false]); f.doc.visibilityState = "visible"; f.doc.emit("visibilitychange");
  f.doc.emit("visibilitychange"); assert.deepEqual(events, [false, true]);
  f.doc.visibilityState = "hidden"; f.doc.emit("visibilitychange"); f.doc.visibilityState = "visible"; f.doc.emit("visibilitychange");
  assert.deepEqual(events, [false, true, false, true]); stop();
});
test("pagehide overrides a visible document until pageshow", () => {
  const f = fixture(), events = [], stop = observeStreamVisibility(f.element, v => events.push(v));
  f.io(true); f.view.emit("pagehide"); f.doc.emit("visibilitychange"); assert.deepEqual(events, [false, true, false]);
  f.view.emit("pageshow"); assert.deepEqual(events, [false, true, false, true]); stop();
});
test("requires a positive intersection, not only isIntersecting", () => {
  const f = fixture(), events = [], stop = observeStreamVisibility(f.element, v => events.push(v));
  f.io(true, f.element, 0, 400); assert.deepEqual(events, [false]); f.io(true); f.io(false); assert.deepEqual(events, [false, true, false]); stop();
});
test("ancestor CSS hiding pauses and restores without an intersection event", () => {
  const f = fixture(), events = [], stop = observeStreamVisibility(f.element, v => events.push(v)); f.io(true);
  for (const [property, value] of [["visibility", "hidden"], ["display", "none"], ["opacity", "0"], ["contentVisibility", "hidden"]]) {
    const old = f.ancestor.style[property]; f.ancestor.style[property] = value; f.mutations[0].fire(); assert.equal(events.at(-1), false);
    f.ancestor.style[property] = old; f.mutations[0].fire(); assert.equal(events.at(-1), true);
  }
  f.ancestor.hidden = true; f.mutations[0].fire(); assert.equal(events.at(-1), false);
  f.ancestor.hidden = false; f.mutations[0].fire(); assert.equal(events.at(-1), true); stop();
});
test("zero-sized viewport and offscreen geometry stop capture", () => {
  const f = fixture(), events = [], stop = observeStreamVisibility(f.element, v => events.push(v)); f.io(true);
  f.element.rect.width = 0; f.resizes[0].fire(); assert.equal(events.at(-1), false);
  f.element.rect.width = 500; f.resizes[0].fire(); assert.equal(events.at(-1), true);
  f.element.rect.top = 900; f.element.rect.bottom = 1300; f.view.emit("scroll"); assert.equal(events.at(-1), false); stop();
});
test("fallback without IntersectionObserver still respects geometry and scroll", () => {
  const f = fixture({ intersection: false }), events = [], stop = observeStreamVisibility(f.element, v => events.push(v));
  assert.deepEqual(events, [true]); f.element.rect.right = -10; f.view.emit("scroll"); assert.equal(events.at(-1), false);
  f.element.rect.right = 510; f.view.emit("scroll"); assert.equal(events.at(-1), true); stop();
});
test("one hidden preview does not pause another subscriber", () => {
  const f = fixture(), second = f.makeElement(f.ancestor), a = [], b = [];
  const stopA = observeStreamVisibility(f.element, v => a.push(v)), stopB = observeStreamVisibility(second, v => b.push(v));
  f.io(true); f.io(true, second); f.io(false); assert.equal(a.at(-1), false); assert.equal(b.at(-1), true); stopA(); stopB();
});
test("disposing removes observers/listeners and ignores queued callbacks", () => {
  const f = fixture(), events = [], stop = observeStreamVisibility(f.element, v => events.push(v)); f.io(true); stop();
  const count = events.length; f.io(false); f.mutations[0].fire(); f.resizes[0].fire(); f.view.emit("pagehide");
  assert.equal(events.length, count); assert.equal(f.doc.listenerCount(), 0); assert.equal(f.view.listenerCount(), 0);
  assert.ok([...f.intersections, ...f.mutations, ...f.resizes].every(o => o.disconnected));
});
test("releasing an image replaces the network source without requesting the page", () => {
  const writes = [], removals = [], image = { set src(value) { writes.push(value); }, removeAttribute(name) { removals.push(name); } };
  releaseStreamImage(image); assert.deepEqual(removals, ["srcset"]); assert.equal(writes.length, 1); assert.match(writes[0], /^data:image\//);
});
test("first-frame detection and cancellation clear pending work", () => {
  const f = fixture(), image = Object.assign(f.makeElement(), { naturalWidth: 0, naturalHeight: 0, src: "http://example.test/web/android/mjpeg", currentSrc: "http://example.test/web/android/mjpeg" }); let frames = 0;
  const stop = observeFirstStreamFrame(image, () => frames++); assert.equal(frames, 0); f.tick(); image.naturalWidth = 1080; image.naturalHeight = 2400; f.tick();
  assert.equal(frames, 1); assert.equal(f.timers.size, 0); image.emit("load"); assert.equal(frames, 1); stop();
  image.naturalWidth = 0; const stopPending = observeFirstStreamFrame(image, () => frames++); assert.equal(f.timers.size, 1); stopPending();
  assert.equal(f.timers.size, 0); assert.equal(image.listenerCount(), 0);
});

test("reattaching the same StrictMode image restores its source and ignores the placeholder frame", () => {
  const f = fixture(); const source = "http://example.test/web/android/mjpeg?udid=emulator-5554&t=1";
  const image = Object.assign(f.makeElement(), {
    naturalWidth: 1, naturalHeight: 1, src: source, currentSrc: "data:image/gif;base64,placeholder",
    removeAttribute() {}, getAttribute(name) { return name === "src" ? this.src : null; },
  });
  releaseStreamImage(image); assert.match(image.src, /^data:/);
  attachStreamImage(image, source); assert.equal(image.src, source);
  let frames = 0; const stop = observeFirstStreamFrame(image, () => frames++);
  assert.equal(frames, 0); f.tick(); assert.equal(frames, 0);
  image.currentSrc = source; image.naturalWidth = 1080; image.naturalHeight = 2400; f.tick();
  assert.equal(frames, 1); stop();
});

test("completed CSS transitions and animations recheck ancestor visibility", () => {
  const f = fixture(), events = [], stop = observeStreamVisibility(f.element, v => events.push(v)); f.io(true);
  // A class mutation can happen before the computed opacity reaches its final value.
  f.mutations[0].fire(); f.ancestor.style.opacity = "0"; f.view.emit("transitionend");
  assert.equal(events.at(-1), false);
  f.ancestor.style.opacity = "1"; f.view.emit("animationend"); assert.equal(events.at(-1), true);
  stop(); assert.equal(f.view.listenerCount(), 0);
});


test("first-frame probe continues beyond 30 seconds and stops at the 45 second budget", () => {
  const f = fixture(), image = Object.assign(f.makeElement(), { naturalWidth: 0, naturalHeight: 0, src: "http://example.test/web/harmony/mjpeg", currentSrc: "http://example.test/web/harmony/mjpeg" });
  let frames = 0; observeFirstStreamFrame(image, () => frames++);
  f.advance(30_000); assert.equal(f.timers.size, 1); assert.equal(image.listenerCount(), 2);
  f.advance(14_900); assert.equal(f.timers.size, 1);
  f.advance(100); assert.equal(f.timers.size, 0); assert.equal(image.listenerCount(), 0);
  image.naturalWidth = 1308; image.naturalHeight = 2880; image.emit("load"); f.advance(60_000);
  assert.equal(frames, 0); assert.equal(f.timers.size, 0);
});

test("a first frame after 30 seconds is observed and late cancellation is immediate", () => {
  const f = fixture(), image = Object.assign(f.makeElement(), { naturalWidth: 0, naturalHeight: 0, src: "http://example.test/web/harmony/mjpeg", currentSrc: "http://example.test/web/harmony/mjpeg" });
  let frames = 0; observeFirstStreamFrame(image, () => frames++);
  f.advance(35_000); image.naturalWidth = 1308; image.naturalHeight = 2880; f.advance(100);
  assert.equal(frames, 1); assert.equal(f.timers.size, 0); assert.equal(image.listenerCount(), 0);
  image.naturalWidth = 0; image.naturalHeight = 0;
  const stop = observeFirstStreamFrame(image, () => frames++);
  f.advance(32_000); assert.equal(f.timers.size, 1); stop();
  assert.equal(f.timers.size, 0); assert.equal(image.listenerCount(), 0);
  image.naturalWidth = 1308; image.naturalHeight = 2880; image.emit("load"); f.advance(60_000);
  assert.equal(frames, 1); assert.equal(f.timers.size, 0);
});

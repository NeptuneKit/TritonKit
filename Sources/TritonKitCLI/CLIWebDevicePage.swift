import Foundation
import Hummingbird
import NIOCore

let singleDeviceWebRoutePath = "/web/device"
let singleDeviceWebRootRoutePath = "/"
let singleDeviceWebSimulatorRoutePath = "/simulators/:id"

func singleDeviceWebPageResponse(initialTarget: String? = nil) -> Response {
    Response(
        status: .ok,
        headers: [.contentType: "text/html; charset=utf-8"],
        body: .init(byteBuffer: ByteBuffer(string: singleDeviceWebPageHTML(initialTarget: initialTarget)))
    )
}

func singleDeviceWebPageHTML(initialTarget: String? = nil) -> String {
    let initialTargetJSON: String
    if let initialTarget,
       let data = try? JSONEncoder().encode(initialTarget),
       let json = String(data: data, encoding: .utf8) {
        initialTargetJSON = json
    } else {
        initialTargetJSON = "null"
    }
    return #"""
<!doctype html>
<html lang="en" data-triton-page="single-device-detail">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Baguette-like device mirror">
  <title>TritonKit Device Mirror</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f3f4f7;
      --surface: rgba(255, 255, 255, 0.92);
      --surface-strong: #ffffff;
      --ink: #202124;
      --muted: #6a6d75;
      --line: rgba(26, 28, 35, 0.10);
      --blue: #2f64e9;
      --blue-dark: #214fca;
      --ok: #0d8f64;
      --warn: #ba6b00;
      --shadow: 0 18px 60px rgba(36, 41, 54, 0.16);
      --phone-radius: 76px;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    * {
      box-sizing: border-box;
    }

    html,
    body {
      min-height: 100%;
    }

    body {
      margin: 0;
      background:
        radial-gradient(circle at 50% -10%, rgba(255, 255, 255, 0.96), rgba(255, 255, 255, 0) 38%),
        linear-gradient(180deg, #f8f9fb 0%, var(--bg) 100%);
      color: var(--ink);
      overflow-x: hidden;
    }

    button,
    textarea {
      font: inherit;
    }

    button {
      border: 0;
      cursor: pointer;
    }

    button:disabled {
      cursor: not-allowed;
      opacity: 0.42;
    }

    .device-mirror-workbench {
      min-height: 100vh;
      display: grid;
      grid-template-rows: auto 1fr;
      gap: 12px;
      padding: 18px 20px 30px;
    }

    .mirror-toolbar {
      width: min(1120px, calc(100vw - 40px));
      min-height: 64px;
      margin: 0 auto;
      padding: 8px 14px;
      display: grid;
      grid-template-columns: minmax(150px, 1fr) auto minmax(280px, 1fr);
      align-items: center;
      gap: 18px;
      border: 1px solid rgba(255, 255, 255, 0.76);
      border-radius: 34px;
      background: var(--surface);
      box-shadow: var(--shadow);
      backdrop-filter: blur(24px);
    }

    .toolbar-left,
    .toolbar-actions {
      display: flex;
      align-items: center;
      gap: 12px;
      min-width: 0;
    }

    .toolbar-actions {
      justify-content: flex-end;
    }

    .icon-button {
      width: 44px;
      height: 44px;
      flex: 0 0 44px;
      display: inline-grid;
      place-items: center;
      border-radius: 16px;
      background: transparent;
      color: #25272d;
      transition: background 140ms ease, color 140ms ease, transform 140ms ease;
    }

    .icon-button:hover {
      background: rgba(31, 35, 45, 0.07);
    }

    .icon-button:active {
      transform: scale(0.96);
    }

    .icon-button.active {
      background: var(--blue);
      color: #ffffff;
      box-shadow: 0 10px 24px rgba(47, 100, 233, 0.32);
    }

    .icon {
      width: 24px;
      height: 24px;
      fill: none;
      stroke: currentColor;
      stroke-width: 2.2;
      stroke-linecap: round;
      stroke-linejoin: round;
    }

    .target-title {
      min-width: 0;
      display: grid;
      gap: 3px;
    }

    .target-name {
      font-size: 22px;
      line-height: 1.1;
      font-weight: 760;
      letter-spacing: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      max-width: 260px;
    }

    .target-subtitle {
      color: var(--muted);
      font-size: 12px;
      line-height: 1.2;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      max-width: 320px;
    }

    .codec-switch {
      display: grid;
      grid-template-columns: 1fr 1fr;
      padding: 5px;
      min-width: 238px;
      border-radius: 24px;
      border: 1px solid var(--line);
      background: #e9eaee;
      box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.08);
    }

    .codec-button {
      height: 40px;
      padding: 0 26px;
      border-radius: 20px;
      background: transparent;
      color: #5c5f66;
      font-size: 21px;
      line-height: 1;
      font-weight: 760;
      letter-spacing: 0.08em;
    }

    .codec-button.active {
      color: #ffffff;
      background: var(--blue);
      box-shadow: 0 9px 18px rgba(47, 100, 233, 0.28);
    }

    .mirror-stage {
      min-height: calc(100vh - 112px);
      position: relative;
      display: grid;
      grid-template-rows: auto 1fr;
      place-items: start center;
      padding-bottom: 8px;
    }

    .target-strip {
      position: relative;
      z-index: 4;
      display: flex;
      align-items: center;
      gap: 8px;
      margin: 2px auto 10px;
      max-width: min(720px, calc(100vw - 56px));
      overflow-x: auto;
      padding: 6px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.74);
      border: 1px solid rgba(255, 255, 255, 0.72);
      box-shadow: 0 12px 36px rgba(35, 39, 50, 0.12);
      backdrop-filter: blur(16px);
    }

    .target-strip[hidden] {
      display: none;
    }

    .target-row {
      flex: 0 0 auto;
      max-width: 230px;
      min-height: 34px;
      padding: 0 13px;
      border-radius: 999px;
      color: #525660;
      background: transparent;
      font-size: 12px;
      line-height: 1;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .target-row.selected {
      color: #ffffff;
      background: #262a33;
    }

    .device-rig {
      position: relative;
      width: min(76vw, 760px);
      min-width: 350px;
      display: grid;
      justify-items: center;
      padding: 4px 52px 12px;
    }

    .phone-shell {
      position: relative;
      width: clamp(360px, min(48vw, calc(100vh - 170px) * 0.46), 560px);
      aspect-ratio: 402 / 874;
      border-radius: var(--phone-radius);
      padding: 12px;
      background: linear-gradient(145deg, #2d2f34, #050505 26%, #0b0b0c 74%, #32343a);
      box-shadow:
        0 24px 70px rgba(11, 14, 20, 0.26),
        inset 0 0 0 1px rgba(255, 255, 255, 0.08);
    }

    .phone-shell::before {
      content: "";
      position: absolute;
      inset: 5px;
      border-radius: calc(var(--phone-radius) - 5px);
      border: 1px solid rgba(255, 255, 255, 0.12);
      pointer-events: none;
    }

    .phone-screen {
      position: relative;
      width: 100%;
      height: 100%;
      overflow: hidden;
      border-radius: calc(var(--phone-radius) - 22px);
      background: #000000;
      display: grid;
      place-items: center;
      transform: translateZ(0);
    }

    .preview-image {
      display: none;
      width: 100%;
      height: 100%;
      object-fit: cover;
      cursor: crosshair;
      user-select: none;
      -webkit-user-drag: none;
    }

    .screen-empty {
      padding: 34px;
      color: rgba(255, 255, 255, 0.62);
      text-align: center;
      line-height: 1.55;
      font-size: 15px;
    }

    .screen-hud {
      display: none;
    }

    .hud-pill {
      min-height: 30px;
      display: inline-flex;
      align-items: center;
      gap: 7px;
      border-radius: 999px;
      padding: 0 10px;
      color: rgba(255, 255, 255, 0.84);
      background: rgba(0, 0, 0, 0.38);
      font-size: 12px;
      line-height: 1;
      backdrop-filter: blur(10px);
    }

    .phone-side {
      position: absolute;
      width: 8px;
      border-radius: 5px;
      background: #33353a;
      box-shadow: inset 1px 0 1px rgba(255, 255, 255, 0.14);
    }

    .phone-side.left-short {
      left: 39px;
      top: 204px;
      height: 58px;
    }

    .phone-side.left-mid {
      left: 39px;
      top: 312px;
      height: 108px;
    }

    .phone-side.left-low {
      left: 39px;
      top: 454px;
      height: 106px;
    }

    .phone-side.right {
      right: 39px;
      top: 388px;
      height: 164px;
    }

    .floating-tool {
      position: fixed;
      bottom: 34px;
      z-index: 5;
      width: 68px;
      height: 68px;
      display: grid;
      place-items: center;
      border-radius: 50%;
      color: #25272d;
      background: rgba(255, 255, 255, 0.88);
      box-shadow: 0 12px 36px rgba(35, 39, 50, 0.16);
      backdrop-filter: blur(18px);
    }

    .bottom-tool.left {
      left: 38px;
    }

    .bottom-tool.right {
      right: 38px;
    }

    .action-log {
      position: fixed;
      left: 50%;
      bottom: 34px;
      z-index: 6;
      max-width: min(540px, calc(100vw - 190px));
      transform: translateX(-50%);
      border-radius: 999px;
      padding: 10px 16px;
      color: rgba(255, 255, 255, 0.88);
      background: rgba(13, 17, 23, 0.78);
      box-shadow: 0 12px 32px rgba(13, 17, 23, 0.2);
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 12px;
      line-height: 1.35;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      backdrop-filter: blur(14px);
    }

    .action-log[hidden] {
      display: none;
    }

    .sr-only {
      position: absolute;
      width: 1px;
      height: 1px;
      padding: 0;
      margin: -1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
      white-space: nowrap;
      border: 0;
    }

    @media (max-width: 920px) {
      .device-mirror-workbench {
        padding: 12px 12px 24px;
      }

      .mirror-toolbar {
        width: calc(100vw - 24px);
        grid-template-columns: 1fr;
        border-radius: 28px;
      }

      .codec-switch {
        width: 100%;
        min-width: 0;
      }

      .toolbar-actions {
        justify-content: space-between;
      }

      .device-rig {
        width: 100vw;
        min-width: 0;
        padding-inline: 26px;
      }

      .phone-shell {
        width: min(92vw, 460px);
      }

      .floating-tool {
        width: 58px;
        height: 58px;
        bottom: 22px;
      }

      .bottom-tool.left {
        left: 20px;
      }

      .bottom-tool.right {
        right: 20px;
      }
    }
  </style>
</head>
<body class="device-mirror-workbench">
  <header class="mirror-toolbar" aria-label="Device mirror toolbar">
    <div class="toolbar-left">
      <button class="icon-button" id="backButton" type="button" title="Back" aria-label="Back">
        <svg class="icon" viewBox="0 0 24 24"><path d="M15 18l-6-6 6-6"/></svg>
      </button>
      <div class="target-title">
        <div id="toolbarTitle" class="target-name">No target</div>
        <div id="toolbarMeta" class="target-subtitle">Waiting for TritonKit runtime</div>
      </div>
    </div>

    <div class="codec-switch" aria-label="Preview codec">
      <button class="codec-button active" type="button">H.264</button>
      <button class="codec-button" type="button">MJPEG</button>
    </div>

    <div class="toolbar-actions">
      <button class="icon-button" id="swipeDownButton" type="button" title="Swipe Down" aria-label="Swipe Down">
        <svg class="icon" viewBox="0 0 24 24"><rect x="8" y="3" width="8" height="18" rx="3"/><path d="M5 8h3M16 16h3"/></svg>
      </button>
      <button class="icon-button" id="swipeUpButton" type="button" title="Swipe Up" aria-label="Swipe Up">
        <svg class="icon" viewBox="0 0 24 24"><path d="M12 4v11"/><path d="M8 8l4-4 4 4"/><rect x="8" y="16" width="8" height="5" rx="2"/></svg>
      </button>
      <button class="icon-button active" id="tapModeButton" type="button" title="Tap Mode" aria-label="Tap Mode">
        <svg class="icon" viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/></svg>
      </button>
      <button class="icon-button" id="targetButton" type="button" title="Targets" aria-label="Targets">
        <svg class="icon" viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="14" rx="2"/><path d="M8 9h8M8 13h5"/></svg>
      </button>
      <button class="icon-button action-control" id="homeButton" type="button" title="Home" aria-label="Home">
        <svg class="icon" viewBox="0 0 24 24"><path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/><path d="M9 20v-6h6v6"/></svg>
      </button>
      <button class="icon-button" id="refreshButton" type="button" title="Refresh" aria-label="Refresh">
        <svg class="icon" viewBox="0 0 24 24"><path d="M20 11a8 8 0 1 0-2.3 5.6"/><path d="M20 4v7h-7"/></svg>
      </button>
      <button class="icon-button action-control" id="copyButton" type="button" title="Copy Target" aria-label="Copy Target">
        <svg class="icon" viewBox="0 0 24 24"><rect x="9" y="9" width="11" height="11" rx="2"/><rect x="4" y="4" width="11" height="11" rx="2"/></svg>
      </button>
    </div>
  </header>

  <main class="mirror-stage">
    <nav id="targetList" class="target-strip" aria-label="Connected targets"></nav>

    <section class="device-rig" aria-label="Device preview">
      <span class="phone-side left-short"></span>
      <span class="phone-side left-mid"></span>
      <span class="phone-side left-low"></span>
      <span class="phone-side right"></span>

      <div class="phone-shell">
        <div class="phone-screen">
          <div class="screen-hud">
            <span id="connectionBadge" class="hud-pill">checking</span>
            <span id="previewMeta" class="hud-pill">no screenshot</span>
          </div>
          <img id="previewImage" class="preview-image" alt="Device screenshot">
          <div id="emptyPreview" class="screen-empty">Connect one TritonKit runtime target to preview and operate it here.</div>
        </div>
      </div>
    </section>
  </main>

  <button class="floating-tool bottom-tool left" id="infoButton" type="button" title="Device Info" aria-label="Device Info">
    <svg class="icon" viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="2"/><path d="M12 4v16"/></svg>
  </button>
  <button class="floating-tool bottom-tool right" id="brightnessButton" type="button" title="Visual Mode" aria-label="Visual Mode">
    <svg class="icon" viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4"/></svg>
  </button>
  <pre id="actionLog" class="action-log" hidden></pre>

  <section class="sr-only" aria-label="Device details">
    <span id="targetBadge">0 targets</span>
    <span id="statusText">Waiting for server status.</span>
    <span id="lastUpdated">-</span>
    <span id="targetId">-</span>
    <span id="appName">-</span>
    <span id="bundleId">-</span>
    <span id="targetPlatform">-</span>
    <span id="deviceName">-</span>
    <span id="osName">-</span>
    <span id="hierarchyState">-</span>
    <textarea id="textValue" spellcheck="false"></textarea>
    <button class="action-control" id="typeButton" type="button">Type</button>
    <button class="action-control" id="pasteButton" type="button">Paste</button>
    <button class="action-control" id="clearButton" type="button">Clear Focused Input</button>
  </section>

  <script>
    window.__TRITON_INITIAL_TARGET__ = \#(initialTargetJSON);

    const state = {
      status: null,
      target: null,
      targets: [],
      selectedTargetKey: null,
      preferredTargetSelector: window.__TRITON_INITIAL_TARGET__ || new URLSearchParams(location.search).get('target'),
      targetListOpen: false,
      geometry: null,
      screenshotObjectURL: null,
      refreshTimer: null,
      refreshInFlight: false,
      screenshotInFlight: false
    };

    const els = {
      toolbarTitle: document.getElementById('toolbarTitle'),
      toolbarMeta: document.getElementById('toolbarMeta'),
      connectionBadge: document.getElementById('connectionBadge'),
      targetBadge: document.getElementById('targetBadge'),
      refreshButton: document.getElementById('refreshButton'),
      targetButton: document.getElementById('targetButton'),
      targetId: document.getElementById('targetId'),
      appName: document.getElementById('appName'),
      bundleId: document.getElementById('bundleId'),
      targetPlatform: document.getElementById('targetPlatform'),
      deviceName: document.getElementById('deviceName'),
      osName: document.getElementById('osName'),
      hierarchyState: document.getElementById('hierarchyState'),
      targetList: document.getElementById('targetList'),
      previewImage: document.getElementById('previewImage'),
      emptyPreview: document.getElementById('emptyPreview'),
      previewMeta: document.getElementById('previewMeta'),
      statusText: document.getElementById('statusText'),
      lastUpdated: document.getElementById('lastUpdated'),
      actionLog: document.getElementById('actionLog'),
      textValue: document.getElementById('textValue'),
      swipeUpButton: document.getElementById('swipeUpButton'),
      swipeDownButton: document.getElementById('swipeDownButton'),
      typeButton: document.getElementById('typeButton'),
      pasteButton: document.getElementById('pasteButton'),
      clearButton: document.getElementById('clearButton'),
      homeButton: document.getElementById('homeButton'),
      copyButton: document.getElementById('copyButton')
    };

    async function fetchJSON(path, options = {}) {
      const response = await fetch(path, {
        ...options,
        headers: {
          'Accept': 'application/json',
          ...(options.body ? { 'Content-Type': 'application/json' } : {}),
          ...(options.headers || {})
        }
      });
      const text = await response.text();
      const data = text ? JSON.parse(text) : {};
      if (!response.ok) {
        const message = data.error?.message || response.statusText || 'Request failed';
        throw Object.assign(new Error(message), { status: response.status, data });
      }
      return data;
    }

    async function fetchBlob(path, timeoutMs = 8000) {
      const controller = new AbortController();
      const timeout = window.setTimeout(() => controller.abort(), timeoutMs);
      const response = await fetch(path, {
        signal: controller.signal,
        headers: { 'Accept': 'image/png,image/jpeg' }
      }).finally(() => window.clearTimeout(timeout));
      if (!response.ok) {
        let detail = response.statusText;
        try {
          const data = await response.json();
          detail = data.error?.message || detail;
        } catch (_) {}
        throw new Error(detail);
      }
      return response.blob();
    }

    function pill(el, text, mode) {
      el.textContent = text;
      el.dataset.mode = mode || '';
    }

    function setControlsEnabled(enabled) {
      document.querySelectorAll('.action-control').forEach((control) => {
        control.disabled = !enabled;
      });
      els.previewImage.style.pointerEvents = enabled ? 'auto' : 'none';
    }

    function targetKey(target) {
      return [
      target.id,
      target.platform || '',
      target.bundleIdentifier || '',
      target.appName || '',
        target.hierarchyCacheState || '',
        target.identityState || ''
      ].join('|');
    }

    function targetMatchesSelector(target, selector) {
      const normalized = String(selector || '').trim();
      if (!normalized) { return false; }
      return target.id === normalized
        || target.simulatorUDID === normalized
        || target.id.endsWith(`:${normalized}`)
        || target.deviceDescription === normalized
        || target.appName === normalized
        || target.bundleIdentifier === normalized;
    }

    function platformLabel(target) {
      const value = String(target?.platform || '').toLowerCase();
      if (value === 'android') { return 'Android Emulator'; }
      if (value === 'harmony') { return 'Harmony / DevEco Emulator'; }
      if (value === 'ios') { return 'iOS Simulator'; }
      return value ? value : 'Runtime';
    }

    function operationScopeText(target) {
      if (target?.source === 'host') {
        const hostPlatform = String(target?.platform || '').toLowerCase();
        if (hostPlatform === 'android') {
          return 'Ready for Android emulator preview and host-side input actions.';
        }
        if (hostPlatform === 'harmony') {
          return 'Ready for Harmony emulator preview and host-side input actions.';
        }
        return 'Ready for iOS simulator framebuffer preview. App-level input uses the embedded runtime when available.';
      }
      const platform = String(target?.platform || '').toLowerCase();
      if (platform === 'android') {
        return 'Ready for Android emulator preview through the connected runtime target.';
      }
      if (platform === 'harmony') {
        return 'Ready for Harmony emulator preview through the connected runtime target.';
      }
      return 'Ready for iOS simulator preview and embedded runtime input actions.';
    }

    function isActiveTarget(target) {
      if (target.source === 'host' && target.ready === true) { return true; }
      return target.activeHierarchyAvailable === true || target.hierarchyCacheState === 'active';
    }

    function chooseTarget(targets) {
      if (!targets.length) {
        state.selectedTargetKey = null;
        return null;
      }

      const preferred = state.preferredTargetSelector
        ? targets.find((target) => targetMatchesSelector(target, state.preferredTargetSelector))
        : null;
      if (state.preferredTargetSelector) {
        if (!preferred) {
          state.selectedTargetKey = null;
          return null;
        }
        state.selectedTargetKey = targetKey(preferred);
        return preferred;
      }
      const selected = state.selectedTargetKey
        ? targets.find((target) => targetKey(target) === state.selectedTargetKey)
        : null;
      const target = selected
        || targets.find(isActiveTarget)
        || targets.find((candidate) => candidate.connected)
        || targets[0];
      state.selectedTargetKey = targetKey(target);
      return target;
    }

    function renderTargets(targets) {
      els.targetList.innerHTML = '';
      els.targetList.hidden = targets.length <= 1 || !state.targetListOpen;
      for (const target of targets) {
        const row = document.createElement('button');
        const key = targetKey(target);
        row.className = 'target-row';
        if (key === state.selectedTargetKey) {
          row.classList.add('selected');
        }
        row.type = 'button';
        row.textContent = `${platformLabel(target)} · ${target.appName || target.bundleIdentifier || target.id}`;
        row.title = [
          target.id,
          target.source || '',
          target.platform || '',
          target.bundleIdentifier || '',
          target.deviceDescription || '',
          target.hierarchyCacheState || ''
        ].filter(Boolean).join(' | ');
        row.addEventListener('click', () => {
          state.targetListOpen = false;
          selectTarget(target).catch((error) => writeLog('target select failed', error.data || error.message));
        });
        els.targetList.appendChild(row);
      }
    }

    function renderDevice(targets) {
      const target = chooseTarget(targets);
      state.target = target;

      renderTargets(targets);
      setControlsEnabled(Boolean(target));

      if (!target) {
        const text = state.preferredTargetSelector
          ? `Waiting for target ${state.preferredTargetSelector}...`
          : 'Connect one TritonKit runtime target to preview and operate it here.';
        els.toolbarTitle.textContent = 'No target';
        els.toolbarMeta.textContent = text;
        els.targetId.textContent = '-';
        els.appName.textContent = '-';
        els.bundleId.textContent = '-';
        els.targetPlatform.textContent = '-';
        els.deviceName.textContent = '-';
        els.osName.textContent = '-';
        els.hierarchyState.textContent = '-';
        els.statusText.textContent = text;
        els.previewImage.style.display = 'none';
        els.emptyPreview.style.display = 'block';
        els.emptyPreview.textContent = text;
        pill(els.previewMeta, 'no screenshot', '');
        return null;
      }

      els.toolbarTitle.textContent = target.appName || target.bundleIdentifier || 'Device';
      els.toolbarMeta.textContent = [
        platformLabel(target),
        target.bundleIdentifier,
        target.deviceDescription,
        target.hierarchyCacheState
      ].filter(Boolean).join(' | ');
      els.targetId.textContent = target.id;
      els.appName.textContent = target.appName || '-';
      els.bundleId.textContent = target.bundleIdentifier || '-';
      els.targetPlatform.textContent = platformLabel(target);
      els.deviceName.textContent = target.deviceDescription || '-';
      els.osName.textContent = target.osDescription || '-';
      els.hierarchyState.textContent = target.hierarchyCacheState || '-';
      els.statusText.textContent = targets.length > 1
        ? 'Previewing the selected device target.'
        : operationScopeText(target);
      els.emptyPreview.style.display = 'none';
      return target;
    }

    async function refreshStatus() {
      if (state.refreshInFlight) { return; }
      state.refreshInFlight = true;
      try {
      const status = await fetchJSON('/status');
      const targetsResponse = await fetchJSON('/web/targets');
      const targets = targetsResponse.targets || [];
      state.status = status;
      state.targets = targets;

      pill(els.connectionBadge, status.connected ? 'connected' : 'disconnected', status.connected ? 'ready' : 'warn');
      els.targetBadge.textContent = `${targets.length} target${targets.length === 1 ? '' : 's'}`;
      const target = renderDevice(targets);
      els.lastUpdated.textContent = new Date().toLocaleTimeString();

      if (target) {
        await refreshGeometry(target);
        await refreshScreenshot(target);
      }
      } finally {
        state.refreshInFlight = false;
      }
    }

    async function selectTarget(target) {
      state.preferredTargetSelector = null;
      state.selectedTargetKey = targetKey(target);
      const selected = renderDevice(state.targets);
      if (!selected) { return; }
      await refreshGeometry(selected);
      await refreshScreenshot(selected);
    }

    async function refreshGeometry(target) {
      try {
        state.geometry = await fetchJSON(`/web/geometry?target=${encodeURIComponent(target.id)}`);
      } catch (error) {
        state.geometry = null;
        writeLog('geometry failed', error.data || error.message);
      }
    }

    async function refreshScreenshot(target) {
      if (state.screenshotInFlight) { return; }
      state.screenshotInFlight = true;
      try {
        const blob = await fetchBlob(`/web/screenshot?target=${encodeURIComponent(target.id)}&t=${Date.now()}`);
        if (state.screenshotObjectURL) {
          URL.revokeObjectURL(state.screenshotObjectURL);
        }
        state.screenshotObjectURL = URL.createObjectURL(blob);
        els.previewImage.src = state.screenshotObjectURL;
        if (els.previewImage.decode) {
          await els.previewImage.decode().catch(() => {});
        }
        els.previewImage.style.display = 'block';
        els.emptyPreview.style.display = 'none';
        const bounds = state.geometry?.bounds;
        const loadedSize = els.previewImage.naturalWidth && els.previewImage.naturalHeight
          ? `${els.previewImage.naturalWidth} x ${els.previewImage.naturalHeight}`
          : 'screenshot loaded';
        pill(els.previewMeta, bounds ? `${Math.round(bounds.width)} x ${Math.round(bounds.height)}` : loadedSize, 'ready');
      } catch (error) {
        els.previewImage.style.display = 'none';
        els.emptyPreview.style.display = 'block';
        els.emptyPreview.textContent = error.message;
        pill(els.previewMeta, 'screenshot unavailable', 'warn');
      } finally {
        state.screenshotInFlight = false;
      }
    }

    function runRefresh(label = 'refresh') {
      refreshStatus().catch((error) => writeLog(`${label} failed`, error.data || error.message));
    }

    function pointFromPreview(event) {
      const rect = els.previewImage.getBoundingClientRect();
      const bounds = state.geometry?.bounds;
      const width = bounds?.width || els.previewImage.naturalWidth || rect.width;
      const height = bounds?.height || els.previewImage.naturalHeight || rect.height;
      const x = (event.clientX - rect.left) / Math.max(rect.width, 1) * width;
      const y = (event.clientY - rect.top) / Math.max(rect.height, 1) * height;
      return { x: Math.round(x * 10) / 10, y: Math.round(y * 10) / 10, width, height };
    }

    function swipeRequest(direction) {
      const bounds = state.geometry?.bounds || {
        width: els.previewImage.naturalWidth || 390,
        height: els.previewImage.naturalHeight || 844
      };
      const centerX = Math.round(bounds.width / 2);
      const topY = Math.round(bounds.height * 0.24);
      const bottomY = Math.round(bounds.height * 0.76);
      return direction === 'up'
        ? { type: 'swipe', startX: centerX, startY: bottomY, endX: centerX, endY: topY, width: bounds.width, height: bounds.height, duration: 0.25 }
        : { type: 'swipe', startX: centerX, startY: topY, endX: centerX, endY: bottomY, width: bounds.width, height: bounds.height, duration: 0.25 };
    }

    async function sendInput(input) {
      const target = state.target;
      if (!target) {
        writeLog('blocked', 'Select a connected target before operating.');
        return;
      }

      const result = await fetchJSON(`/web/input?target=${encodeURIComponent(target.id)}`, {
        method: 'POST',
        body: JSON.stringify(input)
      });
      writeLog(input.type, result);
      window.setTimeout(() => runRefresh('refresh'), 180);
    }

    function writeLog(label, value) {
      const body = typeof value === 'string' ? value : JSON.stringify(value);
      els.actionLog.hidden = false;
      els.actionLog.textContent = `[${new Date().toLocaleTimeString()}] ${label}: ${body}`;
    }

    els.refreshButton.addEventListener('click', () => {
      runRefresh('refresh');
    });

    els.targetButton.addEventListener('click', () => {
      state.targetListOpen = !state.targetListOpen;
      renderTargets(state.targets);
    });

    els.previewImage.addEventListener('click', (event) => {
      const point = pointFromPreview(event);
      sendInput({ type: 'tap', x: point.x, y: point.y, width: point.width, height: point.height })
        .catch((error) => writeLog('tap failed', error.data || error.message));
    });

    els.swipeUpButton.addEventListener('click', () => {
      sendInput(swipeRequest('up')).catch((error) => writeLog('swipe failed', error.data || error.message));
    });

    els.swipeDownButton.addEventListener('click', () => {
      sendInput(swipeRequest('down')).catch((error) => writeLog('swipe failed', error.data || error.message));
    });

    els.typeButton.addEventListener('click', () => {
      sendInput({ type: 'type', text: els.textValue.value }).catch((error) => writeLog('type failed', error.data || error.message));
    });

    els.pasteButton.addEventListener('click', () => {
      sendInput({ type: 'paste', text: els.textValue.value }).catch((error) => writeLog('paste failed', error.data || error.message));
    });

    els.clearButton.addEventListener('click', () => {
      sendInput({ type: 'clear' }).catch((error) => writeLog('clear failed', error.data || error.message));
    });

    els.homeButton.addEventListener('click', () => writeLog('home', 'Host-side Home is not exposed in this embedded runtime surface yet.'));
    els.copyButton.addEventListener('click', () => {
      const text = state.target?.id || '';
      if (!text || !navigator.clipboard) {
        writeLog('copy', text || 'No target selected.');
        return;
      }
      navigator.clipboard.writeText(text)
        .then(() => writeLog('copy', text))
        .catch(() => writeLog('copy failed', text));
    });

    setControlsEnabled(false);
    runRefresh('initial load');
    state.refreshTimer = window.setInterval(() => {
      runRefresh('poll');
    }, 3000);
  </script>
</body>
</html>
"""#
}

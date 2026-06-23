---
name: tritonkit-web-mock-ui
description: Use when designing, implementing, or validating TritonKit Web mock UI screens, React/Vite prototypes, design evidence, and browser smoke checks without turning Web into the business-control surface.
metadata:
  version: 0.1.0-dev
---

# TritonKit Web Mock UI

## Trigger

Use this skill when the user asks for a Web UI mock, dashboard concept, browser prototype, design iteration, or React/Vite implementation for TritonKit.

Do not use it for CLI / HTTP contract work unless the request also needs a human-facing Web mock.

## Product Boundary

- CLI and HTTP remain the business-control contract.
- Web mock screens consume DTO-shaped mock data or read-only endpoints by default.
- Do not introduce create / update / delete / execute / approve / deny control loops in Web first.
- Do not treat `Web/` as Wails revival or active production UI unless a new space explicitly changes that boundary.

## Required Setup

1. Create or update a `docs-linhay/spaces/<space-key>/README.md` before code.
2. Include BDD scenarios, scope, out-of-scope, technology choices, and validation method.
3. Use `Web/` for the repo-tracked React / TypeScript / Vite mock app unless the space states a different location.
4. Keep Vite ports aligned with repo policy:

   ```text
   dev:     127.0.0.1:34127
   preview: 127.0.0.1:34128
   strictPort: true
   ```

5. Keep generated output untracked:
   - `Web/node_modules/`
   - `Web/dist/`
   - screenshots directories

## Implementation Pattern

- Prefer React + TypeScript + Vite for interactive mocks.
- Keep mock DTOs in a small data module such as `Web/src/data/mockData.ts`.
- Keep top-level state and page composition in `Web/src/App.tsx`.
- Use icons from `lucide-react`.
- Build the real tool screen first, not a landing page.
- Current Web mock UI uses Ant Design as the primary display component system. For new or refactored Web mock screens, prefer AntD primitives for page chrome, navigation, panels, forms, trees, tabs, descriptions, tags and buttons before adding custom DOM/CSS.
- Before changing AntD component code, query the local AntD CLI with `antd design.md --format json` and component docs such as `antd info <Component> --format json`; after changing usage, run `antd usage Web/src --format json` and `antd lint Web/src --format json`.
- Keep `antd/dist/reset.css` imported once from the Web entrypoint, and keep AntD theme seed/token overrides in a top-level `ConfigProvider` instead of scattering one-off runtime colors, radii or spacing values through CSS.
- If `Web/src/App.tsx` grows beyond state orchestration or approaches large-file territory, split presentation into component files and move hierarchy/formatting/localization helper logic into a model/helper module. `App.tsx` should remain responsible for route, host bridge, target, screenshot, hierarchy and evidence state composition.
- Device screenshot canvases, coordinate hit-testing, node highlight overlays and other runtime-evidence surfaces may remain custom DOM/SVG when AntD components would obscure machine-readable geometry or event semantics.
- Real simulator screenshot frames must keep a browser-stable intrinsic size. Avoid using percentage-only container height such as `height: min(..., calc(100% - ...))` as the primary size for portrait real screenshots inside CSS grid / auto rows; it can compute to `0px` and leave only device chrome visible. Prefer viewport-based fallback such as `100dvh` plus a minimum height, and add a CSS contract test when changing frame sizing.
- When a visible label depends on runtime state such as foreground app name, bundle id, hierarchy owner, readiness, or command result, first confirm the CLI / HTTP DTO exposes a machine-readable field. Web may pass through optional fields and show honest unknown/fallback states, but must not invent app identity, hierarchy source, or business status from emulator type, screenshot pixels, or static mock names.
- If a human-facing Web mock reveals a missing CLI / HTTP field, preserve the optional field in the Web bridge where useful, add a clear fallback label, and file or link a development feedback issue for the missing machine-readable contract.
- For iOS real-device runtime mirrors, never fallback to an iOS Simulator runtime target. If the selected host target is `ios-real:*`, the runtime resolver must choose a connected iOS runtime target without `simulatorUDID`; otherwise return an explicit `app_runtime_unavailable` / target mismatch error. Showing a simulator screenshot for a real device is worse than showing no screenshot.
- For iOS real-device runtime mirrors, the Triton server must be reachable from the device. If Web manages `triton serve`, bind it to `0.0.0.0` while keeping the browser-facing base URL on `127.0.0.1`; a localhost-only server works for iOS Simulator but prevents physical devices from connecting.
- Real-device Debug Apps must point their embedded runtime to the current Mac LAN host, either through an app build setting such as `TritonKitDefaultHost` or a launch environment variable such as `TRITON_HOST=<Mac LAN IP>`. Re-detect the Mac IP for each session with `ifconfig` / `route get default` and prove it with `curl http://<ip>:19421/status`; stale Wi-Fi or tunnel IPs can leave the App launched but disconnected. If Triton `app launch` does not support iOS real-device env/args, record that as the Triton-first fallback reason and use `xcrun devicectl device process launch --environment-variables ...` after confirming the device is unlocked.
- For TritonKit emulator work, default information architecture is:
  - target list
  - device mirror
  - target inspector
  - actions
  - network evidence
  - logs

## Device Canvas Interaction Pattern

- When the Web canvas mirrors a real screenshot and proxies device input, keep the machine action boundary in Triton CLI / HTTP. The Web UI may collect human gestures, but it should emit DTO-shaped `tap`, `swipe`, `type`, `paste`, `deleteBackward`, or similar input payloads instead of calling platform tools directly.
- For the Inspect Session click relay, default to short single-pointer `tap` only: enable it only for real host targets with `canInput=true`, `readonly=false`, a real screenshot, and live mode. Keep snapshot mode and readonly demos as node-selection / evidence-only surfaces. After a successful tap, refresh the screenshot and record visible action evidence; refresh hierarchy/logs when available.
- Simulator gestures are not all equivalent at the host boundary. If host-side adapters do not expose a gesture such as iOS Simulator `longPress` or `pinch`, Web must mark that request as a runtime-backed input (`source=runtime`) and let the embedded runtime return the public API result or boundary error; do not keep retrying the host-side surface after it has reported unsupported.
- Long press dispatch should happen when the hold threshold is reached while the pointer is still down, not only on `pointerup`. Track whether the long press was already dispatched so releasing the pointer does not send a duplicate long press or a fallback tap.
- Do not infer focused App controls from screenshot pixels. A tap on the canvas may open a local keyboard relay, but whether the App focused an input must be determined by the preceding Triton input result, runtime state, screenshot, AX, or other machine-readable evidence.
- For keyboard entry on a screenshot canvas, prefer a visible focused relay input near the tap point over relying only on `keydown` on a generic `div`. This preserves browser text editing behavior, IME composition direction, paste, selection deletion, and Backspace/Delete semantics.
- Keep relay semantics explicit:
  - appended text maps to `type`;
  - paste maps to `paste`;
  - deletion maps to repeated `deleteBackward`;
  - Escape or an equivalent UI action dismisses only the relay, not the remote App state.
- Tests should cover the relay at the DOM payload level: tap creates/focuses the relay, typed text emits `type`, deletion emits `deleteBackward`, and paste emits `paste` without requiring a real device.

## Evidence Panel Interaction Pattern

- Network and log evidence are separate panes. If users can hide them, keep independent state for each pane rather than coupling all evidence visibility to a single logs toggle.
- Every hidden evidence pane needs a visible restore path, preferably in a persistent device-control area that remains available after the pane is hidden.
- If both network and logs are hidden and restore controls already exist in the persistent canvas controls, collapse the bottom evidence region entirely instead of rendering an extra hidden-state strip.
- Keep evidence pane controls as UI state only. Hiding network/log strips must not stop capture, mutate backend state, or change CLI/HTTP evidence contracts unless a separate requirement explicitly adds that control loop.

## Hierarchy Viewer Pattern

- For Lookin-style hierarchy views, keep a platform-neutral DTO such as `HierarchyScene` / `HierarchyLayerNode` as the fact source, then derive both the sidebar tree and the canvas visualization from it.
- A Web mock may render a 3D hierarchy scene with Three.js, but it should remain a read-only visualization unless CLI / HTTP exposes a machine-readable inspect/probe action.
- Three-platform hierarchy demos must include iOS, Android, and Harmony data, even if the first slice is mock data. Use platform-specific node names and frame/depth geometry so target switching proves the viewer is not hard-coded to iOS.
- Keep a DOM fallback or overlay for tests and non-WebGL environments. Tests should verify target-specific layer text, rotation state changes, and that drag gestures inside the hierarchy viewer do not become device tap/swipe input.
- If a Web dev bridge endpoint exists for hierarchy data, it should call `triton hierarchy --platform <platform> --target <target> --json` and pass through `HostHierarchyResponse.scene`; keep static DTOs only as demo/test fallback when the bridge or command is unavailable.
- For real three-platform hierarchy validation, start and diagnose Android/Harmony emulators through Triton first: use `triton device start --platform android|harmony --plan-only --json` to capture the launch ledger, execute `triton device start ... --json` when needed, then prove readiness with `triton device list`, `triton device wait-ready`, and `triton hierarchy --platform <platform> --target <target> --json`. Raw `emulator`, `hdc`, or `adb` commands should only appear as sourceCommands or fallback evidence.
- Do not claim Lookin parity until real per-node hierarchy metadata and screenshot/surface slices are available from Triton runtime/host contracts.
- When the Web device shell labels UIKit route state, controller ownership, foreground hierarchy owner, or similar app semantics, prefer a first-class `HierarchyScene` fact field such as `controllerContext` from runtime / CLI. Only use parent-chain or geometry fallback from `ios:controller:*` nodes for old runtimes, and visibly label the UI as fallback instead of presenting it as authoritative runtime route state.
- For selected hierarchy nodes, derive visible context from the same `HierarchyScene`: find the selected node's nearest controller ancestor first, then fall back to scene-level active controller context. Do not infer current `UIViewController` from screenshot pixels, UIKit wrapper view class names, app display names, or mock target names.

## Validation

Run these before delivery:

```bash
npm run build
git diff --check
```

If the dev server is needed:

```bash
npm run dev
```

Then open `http://127.0.0.1:34127/` in a browser automation tool and verify:

- page title and primary screen text are visible;
- console has no errors except known dev-tool informational logs;
- no horizontal overflow at a desktop viewport around 1200 px;
- target/device switching changes visible DTO values;
- screenshot evidence is saved under the corresponding space screenshots directory.

## Documentation

Update:

- the space `README.md`;
- `docs-linhay/memory/YYYY-MM-DD.md`;
- this skill when a new reusable Web mock workflow appears.

Only update `AGENTS.md` when the rule is repo-wide and long-lived.

---
name: tritonkit-web-mock-ui
description: Use when designing, implementing, or validating TritonKit Web mock UI screens, React/Vite prototypes, design evidence, and browser smoke checks without turning Web into the business-control surface.
metadata:
  version: 0.1.0-dev
---

# TritonKit Web Mock UI

开工与交付按[经验索引](../../../docs-linhay/memory/EXPERIENCE.md)只读命中主题，未命中再检索；读取、证据、修订与退出遵循[治理闭环](../../../docs-linhay/dev/20260619-agent-workflow-skill-governance.md)。

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
- New or refactored Web screens use the fixed installed Rhine Design package and its public components, tokens, theme and motion contracts. SP-246 migrates the remaining Web surfaces to Rhine. For any future project snapshot that still contains Ant Design, scope migration by page and preserve its behavior until that page is authorized. Read [the product design system](../../../DESIGN_SYSTEM.md), [design workflow](../../../docs-linhay/dev/rhine-design-workflow.md), and the actual package’s `skills/rhine-design/SKILL.md`; a globally installed skill or upstream showcase does not establish installed API availability.
- When changing a remaining AntD component, query the local AntD CLI with `antd design.md --format json` and component docs such as `antd info <Component> --format json`; after changing usage, run `antd usage Web/src --format json` and `antd lint Web/src --format json`.
- Use one supported Rhine theme root for the app and keep portal/focus behavior inside it. Retain an AntD reset/ConfigProvider only when the actual candidate still has AntD consumers; after the last consumer is migrated, remove the dependency, reset and obsolete styles together. Never copy private CSS, patch `node_modules`, or nest Rhine providers.
- If `Web/src/App.tsx` grows beyond state orchestration or approaches large-file territory, split presentation into component files and move hierarchy/formatting/localization helper logic into a model/helper module. `App.tsx` should remain responsible for route, host bridge, target, screenshot, hierarchy and evidence state composition.
- Device screenshot canvases, coordinate hit-testing, node highlight overlays and other runtime-evidence surfaces may remain custom DOM/SVG when design-library components would obscure machine-readable geometry or event semantics. Under CSS zoom, convert pointer client coordinates using the same rendered content `getBoundingClientRect()` width/height and origin; do not mix them with unscaled clientWidth/layout pixels. Preserve image letterboxing and verify a known node at 100% and 200%.
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

## Design-first adoption and feedback

1. Inventory the existing page’s distinctive visuals, motion, data/permission semantics and recovery path. Record what remains, what changes and why in the space and `design/` page record.
2. Read the fixed package README, design/interaction rules, component index, relevant contracts and bundled skill. Use official review exports when available; product code owns scenes and synthetic data, while the library owns the shell, routing and iframe protocol. Keep review configuration independent from production configuration, secrets and real backend access.
3. Validate the interactive design using the actual page component and styles before wiring it into the existing app. If both design and implementation are authorized, continue through implementation and regression without a new approval stop. Never ship review scenes/mocks with the normal build.
4. Apply [the continuous feedback workflow](../../../docs-linhay/dev/rhine-design-workflow.md#持续反馈与临时适配) for new preferences, successful combinations and findings as well as gaps. Feedback is already authorized, must be deduplicated and sanitized, and must be read back or retained as a pending draft on failure.
5. Inspect installed exports/contracts before declaring a gap. Keep any necessary temporary adaptation minimal and reversible, marked `Temporary design adaptation` plus its issue URL; record its removal conditions in the product design system. Do not grow another component library.
6. On related work or an authorized upgrade, check issue outcomes against the actual new artifact, refresh manifest/lock/artifact/bundled-skill records together, validate equivalent product behavior, then remove only covered adaptations. No background polling.

## Page preference acceptance

Component migration does not prove that page hierarchy and user preferences have been adopted. Review these product compositions against [SP-247](../../../docs-linhay/spaces/SP-247-rhine-page-preferences/README.md), then verify the resulting page:

- Keep one `Surface` boundary per pane. Compose its content with a semantic `section`; do not stack another themed Surface and override its private borders, clipping or decorations. Pass `headerActions` into the page title row so refresh and the pane Menu share one action area instead of reserving another mostly empty toolbar row. The action area contains actions; identity and status belong with the related content.
- Use public Popover/Disclosure for low-frequency settings, explanations and facts. Keep the active target, failure, unknown/incomplete data and recovery path discoverable without opening help. Preserve existing fields, selection, permissions, busy/focus behavior and drafts; compactness comes from removing duplicate containers and prose, not smaller text or controls. Confirm every moved control remains reachable at 400/520/880 px and 200% CSS zoom.
- The installed 0.11.3 DataTable has a 500px minimum table width. For a small path collection without sorting/pagination requirements, prefer a product composition of public layout, text, disclosure and copy components; do not override private table CSS to force it into a narrow pane. Preserve all path state/source/command fields, and retain server-side list contracts where they actually exist.

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

## Split layout and inspector adaptations

- Divider movement is incremental: update the previous pointer position after each move before emitting a ratio delta. Repeated events at the same position must yield zero, and opposite movements must cancel. Normalize against the rendered container rectangle, retain pointer identity/capture, and clean up on release, cancellation and unmount; test keyboard Home/End and directional bounds separately.
- Rhine 0.11.3 exports TreeSelect but no persistent hierarchy browser. Keep the product-specific `InspectorHierarchyTree` adaptation tied to [#117](https://github.com/linhay/rhine-design/issues/117), with ARIA tree/level/selection, roving focus, arrows/Home/End, long text, hover and external-selection reveal. Do not substitute TreeSelect or drop platform source semantics. Recheck the actual release before removing the adaptation.
- In a nested resident tree, Home/End and external selection must reveal the visible row, not the enclosing treeitem wrapper containing its whole descendant group. Preserve nested `group` semantics and one roving tab stop. Repeated updates of the same node must restart its highlight without remounting the focused treeitem; a lifetime timer reset alone does not restart an already-running CSS animation.
- Deleting a focused node can dispatch `focusout` before DOM detach, while `isConnected` is still true. Do not equate that intermediate event with an intentional user focus exit. Verify deletion recovery in a real browser across the commit, including an outside-focus counterexample; SSR and manually detached fixtures do not prove it. The finding and current repair/verification status are tracked in [SP-247](../../../docs-linhay/spaces/SP-247-rhine-page-preferences/README.md), not declared passed by this rule.
- Update highlights have both a CSS animation and a lifetime timer. Observe real animation progress, one-second marker cleanup, system/manual reduced motion, resize and unmount. Pausing only CSS while the timer still removes the marker does not provide paused semantics; do not advertise full/paused review controls until the entire scene, including timers and frame loops, supports them.

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

For Vite SSR tests, disable automatic dependency discovery with `optimizeDeps: { noDiscovery: true }`; limit normal Vite dev scanning to `optimizeDeps.entries: ["index.html"]` so independent `dist-review` output is not treated as another app entry. Passing assertions do not excuse asynchronous dependency-scan errors at shutdown.

Run the actual package scripts before delivery; `npm run build` includes TypeScript checking. Validate the affected normal build and independent review build, and inspect production output for leaked review code/scenes. Record pass, fail, skipped and not-run separately:

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
- screenshot evidence is saved under the corresponding space screenshots directory;
- affected scenes at 400/520/880 px, 200% zoom, long text, loading/empty/error, keyboard/focus, overlays and themes remain usable; distinguish review CSS zoom from browser zoom;
- changed motion is actually observed during playback, pause, system/manual reduced motion, resize and unmount cleanup. Do not advertise pause/full controls unless every animation in the scene implements them; static screenshots do not prove motion;
- mock/browser evidence is not described as native, Wails, real-device or production acceptance.

### Preview lifecycle acceptance

- Keep connection intent and selected target/FPS separate from visibility. Observe the stable viewport, require a positive intersection area, and include page visibility/pagehide plus ancestor CSS visibility and transition completion. Window blur alone is not hiding.
- Explicitly replace a multipart image source when releasing it. React StrictMode may detach and reattach the same DOM ref; setup must restore the current source, and a transparent placeholder must not count as a real frame.
- A dev proxy must listen to response close before waiting for readiness or upstream headers and abort only that subscriber. In Hummingbird, prefer acquiring the subscription inside response-body execution, consume inbound close even while no frame is available, and bind release to the acquired session. If a synchronous native startup failure must retain its HTTP status, an eager subscription needs an idempotent RAII lease that also releases when the body never executes. A terminated session must not be reused by a later subscription.
- Validate a single preview, two subscribers, final cancellation, fresh reconnection, and early disconnect with actual HTTP fixtures. Keep process identity in capture observations; a server replacement invalidates observations tied to its old PID.
- Keep known-platform framebuffer target lookup lightweight: preserve selector/alias/current rules, but avoid unrelated platform discovery and foreground-app enrichment on every reconnect. Compare this hot path separately from registry refresh requests.
- Keep capture, proxy-header and first-frame UI budgets distinct. A multipart HTTP 200 without a decoded image is a failure. Align the bounded UI probe with the sum of capture stages and startup margin; extending a deadline must retain immediate cancellation and terminal-session tests. Node writeHead alone may not flush downstream headers, so the browser response timestamp does not identify upstream header latency.
- Prefer semantic preview state and accessible controls over an old presentation class when parallel UI work changes components. Bind browser evidence to a frozen Web source/asset manifest and the actual binary/PID.
- For native Page Visibility acceptance, check the actual document state. Playwright enables focus emulation by default; attach to an isolated owned Chrome default context with `connectOverCDP(..., { noDefaults: true })` when supported, and use numeric polling while hidden because requestAnimationFrame pauses. Synthetic visibility events or a helper-only test are not native browser proof.

- 截图采集进程很短时，固定频率ps可能与采集周期重合，只看到`(adb)`等不完整命令；未记录进程状态时不能据此判定已退出。保留原窗口失败，延长显示正对照并给采样间隔加抖动；不能把缺失完整命令当“无采集”，也不能把PID采样数称为精确帧数。 全机ps查询出现长样本空洞时，只查询绑定服务的子进程与argv，并先用自有子进程验证解析；缺样本必须失败，不能当作零采集。

## Documentation

Update:

- the space `README.md`;
- `docs-linhay/memory/YYYY-MM-DD.md`;
- this skill when a new reusable Web mock workflow appears.

Only update `AGENTS.md` when the rule is repo-wide and long-lived.


### 慢消费者与无首帧释放

- MJPEG代理必须检查`res.write`返回值，false后暂停上游读取/下一帧，drain后继续；close/error/abort/finish必须解除等待并移除监听。真实暂停TCP消费者验证输出队列，不能只测模拟false或把队列字节当VM物理收益。
- fallback等待时固定当前帧内容、类型和长度，避免共享缓存变化拼出不一致帧。采集频率与推送频率另行验证。
- eager启动iOS采集需要成功订阅的RAII所有权，direct/packaged分别验收未运行body、无首帧断开、双订阅及错误契约；fixture的terminal不代表native默认运行状态已有故障检测。经验与反证见[SP-244第七轮](../../../docs-linhay/spaces/SP-244-emulator-service-slimming/plans/20261030-further-memory-candidates.md)。

### PNG帧与观测窗口

- `mjpeg`路径不保证每帧都是JPEG；读取typed帧格式并保持Content-Type、Content-Length与Data一致。原始PNG直通必须验证真实设备、源码代理、实际解包资产和原生WKWebView；单个Chromium fixture不足以证明客户端兼容，WKWebView harness也不等于完整桌面壳验收。
- PNG的ImageIO complete状态不保证容器有末尾IEND；用有界chunk结构和no-cache metadata检查，避免为了校验再次全图解码。明确CRC/压缩像素语义未完整验证，不把结构检查描述成任意图片可解码保证。
- 上游就绪查询、流与流内截图fallback须消费同一配置来源；测试直接监听配置地址，不通过fetch重写hardcoded默认端口掩盖错误。
- 源码iOS截图fallback的共享缓存按上游URL、CLI路径与设备共同绑定；最后订阅释放时取消该generation的fetch/timer并移出缓存。立即重连使用新generation，旧await回调不得供帧或释放新订阅。用两个真实临时HTTP上游和pending截图证明隔离/取消，不靠测试唯一设备ID掩盖跨上游串流。见[SP251发布前修复](../../../docs-linhay/spaces/SP-251-release-v0-2-38/plans/20261030-release.md)。
- 分别记录恢复请求与首帧已到达的时间。隐藏负窗口止于恢复请求前，保留可见阶段完整正对照和采样数量；不能把恢复等待期计入隐藏，也不能把进程采样计数当精确帧数。经验、失败反证与真实收益范围见[SP-244第九轮](../../../docs-linhay/spaces/SP-244-emulator-service-slimming/plans/20261030-png-adoption-commit.md)。

---
name: tritonkit-real-project-regression
description: Use when TritonKit moves from demo/self-test into a real iOS app, Harmony app, or customer project for regression testing, adoption validation, or actual requirement discovery. Guides the AI agent to isolate external repo changes, run release CLI plus host-side or embedded runtime checks, collect machine-readable evidence, and turn real-project gaps into docs, fixes, or GitHub issues.
metadata:
  version: 0.1.0-dev
---

# TritonKit Real Project Regression

## Embedded discovery migration

`triton serve` never advertises implicitly, including with an explicit LAN bind. Use `--advertise` or `TRITON_ADVERTISE=true|1` only when discovery is intended; `--no-advertise` overrides it. `false|0` disables it; other environment values fail before bind. Read `discovery` in `triton status --json` / `GET /status`: wanted is intent, advertising requires a real publication callback, failed includes the NetService error, stopped means withdrawn/disabled. Older servers omit the field. `identityVerified` remains false: publication is neither peer authentication nor proof of LAN reachability.

The SDK's `.environment()` no longer browses or selects the first Bonjour service. Prefer explicit App-process `TRITON_HOST` / `TRITON_PORT`, Debug bundle host, or `.device(...)`. For intentional discovery, use `.environment(discoveryPolicy: .bonjour(timeout: 0.15))` or App-process `TRITON_DISCOVERY=bonjour`; `disabled` is the default. `TRITON_DISCOVERY_TIMEOUT_SECONDS` must be finite and greater than 0, at most 5. Invalid configuration, multiple/unresolved/removed candidates, or no candidates make `start()` reject discovery without connecting to a fallback host. `.bonjourDiscovery(timeout:)` exposes the reason and candidates; `.bonjour(timeout:)` retains its optional endpoint API. Resolve ambiguity with an explicit host. A public ID, name, one candidate or TCP readiness never authenticates the service. Keep all SDK symbols in the existing file-level `#if DEBUG` bootstrap; Release discovery and runtime remain no-op. When upgrading from versions that browsed automatically, migrate the Debug bootstrap and verify the installed CLI/SDK schema before testing.

## Principle

Real-project validation is not demo smoke. Treat the business app as an external system under test:

- Do not mix real-app repo changes into TritonKit commits.
- Prefer released `triton` for external adoption checks.
- Preserve command, JSON output, screenshot, evidence, or issue links for every finding.
- Do not publish private app identity, bundle IDs, accounts, internal hosts, private paths, credentials, full logs, or unredacted evidence.

For old/new Xcode checks, preserve scoped `triton device doctor --platform ios --json` output. `commandSupport` is `help-advertised-only`, not boot/install/launch or business validation. Simulator-only health does not depend on CoreDevice; all/real requires its discovery contract. Use the chosen DEVELOPER_DIR in the child environment without global switching, distinguish real toolchain runs from contract fixtures, and do not retry a state-changing operation via an alternate backend.

## Standard Workflow

1. Confirm app repo, branch, target device/simulator/emulator, and requirement.
2. Check both repos before changing anything:
   ```bash
   git status --short --branch
   ```
3. Prepare CLI and confirm binary:
   ```bash
   triton version --json
   ```
4. Choose the provider before starting a session. Use the bundled iOS Runner below for allowed app UI without an app SDK; start the local server explicitly when embedded runtime is needed:
   ```bash
   triton serve --host 127.0.0.1 --port 19421
   ```
5. Preserve Triton-first facts before fallback:
   ```bash
   triton doctor --json
   triton status --json
   triton capabilities --json
   triton schema --json
   ```
6. Observe before action, execute the smallest flow, then verify business state with `wait`, `verify`, screenshot, or evidence.
7. Redact before sharing externally.
8. If the real app exposes a TritonKit gap, use `tritonkit-dev-feedback` to prepare a redacted issue.

## Reference Routing

Start with [references/feature-index.md](references/feature-index.md) to map the requested feature to the smallest reference file. Then read only the matched reference(s).

## Bundled iOS Runner regression

For iOS UI regression without modifying the target app, use `triton device runner`. The complete CLI package includes the XCTest project and native USB transport; the target app needs no embedded TritonKit SDK. The runtime workflow does not require Appium, WebDriverAgent, Python, or `iproxy`. Keep the packaged `ios-runner` resources and their manifest matched to the CLI version. Xcode and a compatible iOS SDK remain required; physical devices also need pairing/trust, Developer Mode, an Apple Development signing identity, unlock, and any system UI Automation authorization. Do not change lock settings or authorization on the user's behalf.

Preserve discovery and the exact command schema, then use one explicit `ios-real:<device-id>` or booted `sim:<UDID>` target. Only `prepare` takes signing options: supply `--team` if no unique valid team is available and use `--allow-provisioning-updates` only when provisioning changes are authorized.

```bash
triton device list --platform ios --scope real --json
triton schema --command device.runner --json
triton device runner doctor --device 'ios-real:<device-id>' --json
triton device runner prepare --device 'ios-real:<device-id>' --timeout 600 --json
triton device runner start --device 'ios-real:<device-id>' --allow-bundle '<bundle-id>' --ttl 600 --json
triton device runner activate --device 'ios-real:<device-id>' --bundle-id '<bundle-id>' --json
triton device runner inspect --device 'ios-real:<device-id>' --bundle-id '<bundle-id>' --limit 40 --json
triton device runner tap --device 'ios-real:<device-id>' --bundle-id '<bundle-id>' --identifier '<observed-identifier>' --request-id action-001 --json
triton device runner inspect --device 'ios-real:<device-id>' --bundle-id '<bundle-id>' --json
triton device runner status --device 'ios-real:<device-id>' --json
triton device runner stop --device 'ios-real:<device-id>' --json
```

Repeat `--allow-bundle` at `start` for each authorized app; the fixture is always allowed. Do not broaden the app list after an action fails. Use identifiers or unique labels from the latest inspect only; selectors expire after 30 seconds, and actions clear the observation. `scroll --direction up|down|left|right` and `type --identifier '<observed-identifier>' --text-file '<private-text-file>'` retain the same device/bundle binding. Type requires verified focus. Safari address input and navigation remain unverified in the live validation; do not count an available command or an activated Safari app as a passed navigation flow.

Assign a request ID before actions. Delivery `unknown` does not authorize an automatic retry or backend switch: query the original ID, distinguish pending/absent/complete, and verify actual business state. The session's idempotency cache is bounded and does not survive a new Runner session.

```bash
triton device runner receipt --device 'ios-real:<device-id>' --request-id action-001 --json
triton device runner screenshot --device 'ios-real:<device-id>' --bundle-id '<bundle-id>' --request-id capture-001 --output '<fresh-private.png>' --json
triton device runner receipt --device 'ios-real:<device-id>' --request-id capture-001 --output '<fresh-recovered.png>' --json
```

A screenshot is a sensitive device-screen frame, which may show system UI or the app switcher; bundle metadata does not prove frame ownership. A tap/scroll/type acknowledgment proves submission only. Accept a regression result only after a fresh inspection or screenshot establishes the flow's business postcondition. `status` separates health/process ownership from historical automation readiness: `automationPreviouslyVerified` is historical and `automationReady: null` is not a current UI-readiness verdict.

CLI commands do not require `triton serve`. HTTP clients use the same service through `/v1/device/runner/doctor|prepare|start|status|stop|request|receipt` on the local `127.0.0.1:19421` server. Existing `act`, `observe`, `device screenshot`, embedded `/request` and `/input` retain their provider contracts; do not claim those surfaces automatically route through the Runner. The TTL is a bounded Mac-managed XCTest session, not permanent background operation or proof of lock/reboot survival or standalone execution without the Mac. Stop the owned session when finished and redact all screenshots, bundle/target identities, signing metadata, private paths and logs before public handoff.

## Common Commands

Triton-first facts:

```bash
triton doctor --json
triton status --json
triton capabilities --json
triton schema --json
triton list --json
```

Observation and verification:

```bash
triton observe tree --platform <ios|android|harmony> --device <selector> --outline --json
triton wait --text '<text>' --timeout 15 --json
triton verify text-exists '<text>' --json
triton screenshot --output /tmp/<case>.png --json
triton evidence capture --case <case> --output /tmp/<case>.tritonevidence --json
```

For an iOS Simulator coordinate-only action, use `triton act tap --device sim:<UDID> --at <x,y> --json`. This explicit host selector bypasses embedded `/targets`, preventing a same-Simulator stale/background runtime from being selected; a canonical `triton:ios-simulator:<UDID>/app:<bundle-id>` remains the exact embedded target form. Host-HID acknowledgement is not a business verdict, so always follow it with observation, wait/verify, screenshot, or evidence.

Treat evidence capture as one machine-readable completion gate: parse stdout as exactly one manifest and inspect `ok`, `partial`, top-level `error`, and every `skipped[].error`. Expected unsupported artifacts may yield `ok:true, partial:true`; request or artifact-write failures yield `ok:false, partial:true`, `error.code=evidence_capture_partial`, and a non-zero exit. Do not accept a bundle merely because some status/list/version artifacts exist.

Planning and replay:

```bash
triton plan ios-smoke --device <selector> --bundle-id <bundle-id> --url <url> --text <text> --evidence /tmp/<case>.tritonevidence --json
triton plan inspect <file.tritonplan> --json
triton replay <file.tritonplan> --dry-run --json
triton replay <file.tritonplan> --json
```

For recorder-derived flows, only `triton test import <case.tritontestcase> --output <plan.tritontest.yaml> --bundle-id <bundle-id> --device-platform ios-simulator --json`, then `triton test validate`, then `triton test run --target <target-id>` can lead to a real runtime verdict. If a future 3 × 20 reliability collection is being prepared, `triton test reliability-preflight --collection <private.json> --json` may freeze its private inputs only: accept `ready_to_collect` only with `writesEvidence=false`, `usesRuntime=false`, and `eligibleForReliabilityGate=false`; its negative control must not reuse a supported flow's normalized-plan digest and must declare an exact `expectedFailureType` for a non-optional, read-only terminal assertion. It does not boot/select a Simulator, start/reuse a server, reset an App, write evidence, or prove a verdict. Keep its private path/UDID/bundle/target/reset data out of public reports, then use a separately authorized live harness for actual collection. `testrec replay --dry-run`, `local-simulated`, and `matrix` are offline diagnostics: even if their compatibility fields say `ready`, `passed`, or `passedCount`, require `verdictBoundary.countsAsRealTestVerdict=false` and do not use them as regression evidence or reliability-gate samples. Treat an older replay result without this boundary as legacy/unknown, not affirmative proof.

For an explicitly authorized receipt-backed collection, run `test reliability-reserve` only against a fresh private root, record its lowercase `receiptSha256` in operator/CI state outside that root, then call `test reliability-sample` one slot at a time with `--expect-receipt-sha256 <64-lowercase-hex>`, `--confirm`, exact canonical iOS Simulator/App target, private reset receipt, and an operator-owned already-running `127.0.0.1:19421` server. Receipt-backed `test reliability --collection-receipt` requires the same expected anchor before it scans evidence. Never derive the expected anchor from the current root just before use: it would not detect a complete receipt replacement. The receipt root holds a collection-wide lease: a busy or stale lease fails closed before target execution and must not be deleted or reused automatically. It must not manage App/Simulator/server lifecycle or clean/retry evidence. Treat the sample's single typed JSON result as the verdict contract: an expected negative nonpass is `ok=true` / exit 0 only for terminal `failed` with the exact frozen assertion failure type; a supported nonpass, unexpected negative pass, or wrong negative failure type is `ok=false` / exit 1 without a second error envelope. Legacy `test reliability --samples` is diagnostic-only and cannot pass the Stage 1 gate. Configuration, receipt anchor, reset, or target rejection is a single `TKCLIErrorResponse`. SHA-256 anchor checking is not a signature, identity proof, remote ledger, or hostile-filesystem defense. Do not begin a live collection without explicit dedicated-target, reset, server-ownership, negative-control, and private-evidence authorization.

After a receipt-bound runner finishes, it must seal one private `reliability/identity-chain-v2.json` only if binding, reset receipt, normalized plan, runtime target, `run/run.json`, and `run/events.jsonl` all exist; a write or component failure preserves the claimed slot and must not be backfilled, cleaned, or rerun automatically. Receipt-backed report exposes only `identityChain.state`, expected/valid/missing/invalid counts, and `receiptAnchorVerified`: missing v2 chains block as `identity_chain_incomplete`, while body/frozen identity/terminal evidence/component/manifest disagreement blocks as `identity_chain_invalid`. These are offline byte-consistency checks, not evidence that reset, App/runtime execution, history, target exclusivity, or hostile-filesystem integrity was real; never put chain hashes, private paths, target/bundle/UDID, flow, run, or reset identities in a public regression report.

For receipt-backed reports, read the additive `stage1` cohort contract rather than conflating the compatible top-level metrics: `stage1.stage1A` is only the 60 supported slots (3 flows × 20) and owns supported ECR/ORR plus strict per-flow completeness; `stage1.stage1B` is all 61 receipt/control slots and owns full receipt integrity plus FER across every terminal failed/blocked slot, including the expected negative control and any supported nonpass. Legacy `reliability --samples` has model value `stage1=nil` and omits that JSON field. For receipt-backed output `stage1.gate` must equal the top-level gate; an integrity-only Stage 1B blocker is not `stop_expansion`. Report only counts, rates, statuses, and blocker codes—never any private slot identity.

## Observation and recovery boundaries

- Refresh `observe tree --outline` aliases before `node resolve @N`: the 30-second window also requires a fresh matching whole-tree observation. Changed or partial trees cannot preserve alias validity. Hierarchy `collection` limits bound traversal; they cannot hard-cancel native IPC or prove absence from a partial tree.
- `observe ocr --image <path>` / `--device <selector>` produces candidates without OIDs or action refs, in top-left raw-raster pixels. Only known explicit scale allows points; file mtime leaves `freshness=unknown`. Preserve confidence, capture source, and partial metadata; structure-unavailable policy requires an explicit reason.
- `observe settle` and workspace opt-in `--visual-settle` (HTTP `/workspace/run` optional `visualSettle`) do not prove business readiness. Workspace visual waiting is off by default; `unknown/timeout` stops the chain. A settled screen still needs the flow's wait/assertion.
- Capture `debug ui-health` and action `outcome`/`uiHealth` when diagnosing stalled UI. Legacy health is `unknown`; new SDK health is `ready|busy|timed_out|circuit_open`. An action with `outcome=unknown` may still finish: do not automatically replay or switch to HID. Stop and collect a fresh read-only observation before deciding the business result.

## Completion Gate

- Requirement has machine-readable pass/fail evidence.
- Real app repo changes are isolated and explicitly reported.
- TritonKit repo changes, if any, have focused tests and docs/memory updates.
- Public handoff is redacted.
- Any product gap is turned into a doc update, code fix, or redacted GitHub issue.

## Device Hub acceptance

Read [Device Hub acceptance](references/device-hub-acceptance.md) before metadata, management or specialized-platform validation. Start from the current authorization and exact target; preserve restoration obligations, partial results and unverified controls independently of historical successful runs.

## 2026-09 issue 合同补充

- `xcode test --jsonl` 默认 compact；完整 raw 日志在 artifact，显式 `--progress full` 才转发。按子命令 schema 选参数，`xcode run` 不接受 `--progress`。
- DerivedData 存在不证明 cache 命中。`reuseVerification=unknown`，`incrementalExpected=false` 仅表示没有验证过的预期；读取 `observedBuild.taskLogCounts/logCoverage`，不擅自称增量或全量。
- 默认不传 `--derived-data-path`，由 Xcode 使用用户级 DerivedData。该参数必须显式指定，只用于隔离或恢复，可能造成高磁盘占用，非必要不要开启。排查构建缓存用 `triton xcode derived-data inspect --json` 或 `cleanup --json` 预览；`.triton/DerivedData` 只能作为显式 legacy root。Triton 不提供 DerivedData 删除；通用自动删除需求已撤出范围。兼容参数 `--confirm` 在删除前返回 `derived_data_cleanup_unavailable`，活动 Xcode lane 保留 `xcode_not_idle`；等待空闲不会启用删除，不建议重试 confirm。若用户另行要求人工清理，先只读检查并明确该独立操作范围，不自动回退手工删除。逻辑文件字节不是可回收磁盘量，修改时间不是最后使用时间。
- `debug attrs --oid` 支持 UIView/CALayer oid；UILabel 的有效字体/颜色与 UTF-16 run 有界输出，正文预览和 run 都要检查截断字段。
- collection cell 激活尊重 allowsSelection/delegate，success 只证明公开 callback，必须验证业务后置条件。`act tap --duration` 不支持长按，提前 typed unsupported；embedded longPress 和非滚动手势也不伪造成功，使用 App 显式注册的 semantic DEBUG action 或检查实际 provider 能力。
- Harmony ArkWeb bridge-call 需可达 DevTools socket 与页面 `window.__tritonBridge.methods` 自有函数白名单；函数接收 `(params, complete, reject)`，支持返回值/Promise/callback。明确选中 CDP page ID，stale/ambiguous 失败关闭；不把 CDP page ID 当导航 session 验证，清理失败也可能发生在页面方法已执行之后，重试前先验业务状态。

`triton xcode ... --package <Package.swift-or-directory>` 的相对 `--derived-data-path` 按 package 工作目录解析并在 invocation/cache 元数据中给出绝对路径；`xcode test --result-bundle <relative>` 同样按 package 工作目录规范化，执行命令、inline xcresult parser 和最终 `resultBundlePath` 共享该位置。绝对路径保持不变；非 package 工作流保留调用目录语义。

## Optional view-highlight acceptance

`triton highlight capabilities/apply/status/clear` is optional; never require an embedded SDK for ordinary host screenshots. See [the highlight workflow](../tritonkit-emulator-cli-takeover/references/view-highlight.md). Validate real properties, before/during/after images, exact session cleanup, TTL, business-write conflicts and reconnect. Screenshot success is not restoration success; preserve operationID/sessionID and incomplete cleanup evidence. This slice supports Debug UIKit ordinary views only.

## Optional floating-picker acceptance (SP-201, unreleased)

SP-201 is integrated into local main but is not a published release; the SP-209 SDK hub remains an isolated worktree candidate. Use a matching candidate SDK and CLI only when this feature is in the regression scope. Keep business-app edits isolated. Inside the existing file-level `#if DEBUG` bootstrap, enable `config.features.insert(.inspector)` and `config.picker = .init(enabled: true, ttlSeconds: 300)`; keep `.input` enabled for actions. Picker defaults to off, adds no third-party dependency, and remains no-op in Release. `TRITON_PICKER_ENABLED=1` only enables the default picker environment configuration: `.inspector` opt-in and the app's runtime startup gate still apply. Fixture auto-insertion is not general app behavior.

After confirming an explicit embedded runtime target, preserve these commands and their JSON results; perform the tap only after reading a valid selection with `tap` in `supportedActions`:

```bash
triton inspect capabilities --target '<runtime-target>' --json
triton inspect selection --target '<runtime-target>' --json
triton act tap --target '<runtime-target>' \
  --selection '<selection.id>' --selection-revision '<selection.revision>' \
  --runtime-instance-id '<runtimeInstanceID>' --json
```

All three guard fields come from one current response; do not substitute a bare OID, coordinates or another provider after rejection. Validate separately: dragging and releasing on a button emits no business click; one guarded tap increments the business count once; re-selection/parent changes reject an already-read revision; expiry, target loss and runtime replacement reject stale identity; labels and cells remain `observeOnly` and cannot be clicked through the selection guard. The initial executable scope is eligible `UIButton` only; SwiftUI virtual nodes, WebView DOM, Android and Harmony are deferred.

Check overlay exclusion from normal AX/hierarchy/screenshots and action targeting, disabled configuration, and Release no-op using actual native evidence. HTML interactions and tests excluded by `canImport(UIKit)` are not native proof. Selection previews are independent of `triton highlight` property changes. Cleanup is explicit: `triton inspect clear --target '<runtime-target>' --runtime-instance-id '<runtimeInstanceID>' --json`. Preserve action receipts and business postconditions independently, and redact selection labels, identifiers and images before sharing.


For native picker interaction regressions, exercise direct drag preview/crosshair/magnifier, long-press relocation, release-to-open compass, persistent navigation, stable unobstructed placement and parent-child return memory. Assert no business action during selection; record a held-drag screenshot as well as the released selection. Simulator tests can verify haptic trigger conditions, not physical feel. Wait for an explicit XCTest handoff before the CLI action; an already-valid selection is not proof the zero-click assertions finished. Keep image-only rendering of video/Metal/remote WebView content and multi-scene/device coverage explicit when untested.

### SDK hub 与选择器运行时开关

Debug App 预先授权 `.inspector` 后，在 MainActor 通过 `TritonKit.shared.setPickerEnabled(true/false)` 开关，读取 `isPickerEnabled` 判断会话状态；不重新 start SDK。接入代码放独立 Debug bootstrap。宿主负责自己的唤回入口，SDK 不实现宿主调试菜单。

圆球单击以系统 pageSheet 打开 SDK hub：首页真实连接摘要，连接、选择器、SDK 功能、应用、入口五路由。放大镜、辅助框、触感在选择器二级配置。SDK 功能是宿主配置的只读展示，不代表平台支持、provider 就绪或业务可执行；不展示未被消费的隐私配置或硬编码 SDK 版本，不为填充菜单添加无效按钮。

系统 modal 内部使用 UINavigationController 与 insetGrouped UITableViewController；iOS 15+ 使用 medium/large detents、grabber，iOS 13/14 降级系统 pageSheet，不承诺半屏。验收 modal 打开暂隐藏圆球、全部选择提示与罗盘，下拉或关闭恢复有效选择上下文；系统遮罩拦截整个窗口业务触摸，外围透传仅适用于 modal 关闭后。罗盘只保留节点导航和清除。隐藏操作仅在入口页经系统 UIAlertController 确认后执行，取消保持状态；确认后旧 selection guard 失效，宿主 API 恢复从空选择开始。分别核对隐藏/恢复前后连接与业务计数不变、Release 不能开启，以及浅深色、小屏滚动和子页面返回。SP-209 为未发布候选，使用前核对匹配源码/版本与实际验证记录；自绘卡片通过记录不能代替系统 modal 验收。


### Host geometry and Android foreground evidence

For Simulator host AX, `ios_host_ax_geometry_unavailable` rejects missing/invalid geometry before coordinate-dependent work; preserve that failure and inspect `triton device doctor --platform ios --scope simulator --json`, rather than guessing dimensions. Android `device foreground` adds `observed.activity` and `observed.component` from trustworthy resumed activity records; unknown omits them, and foreground identity does not prove business readiness. Legacy ADB text input quotes remote-shell literals and redacts source commands; distinguish shell safety from device Unicode/keymap and `%s` input support. Record offline fixture acceptance separately from real-device input.

## Device Hub host input authority

Discover `triton schema --command act.tap --json` on the actual CLI before using `--hid-only`. Explicit `--platform ios` defaults to AX activation, including coordinates: `source=host-ax`, `strategy=accessibility-perform-press`, `verification.required=true`. For a touch-path regression use `triton act tap --platform ios --device sim:<UDID> --at 120,240 --hid-only --json`; only local Simulator coordinates are accepted, with no semantic/embedded/WebView fallback. Without `--platform`, existing explicit Simulator coordinate selectors retain host HID routing.

Tap and `triton sim swipe` use the native digitizer bundled in triton, without an external Baguette executable or chrome lookup. Device Hub guest HID ownership returns `ios_host_hid_device_hub_attached`; unknown ownership and unsupported display topology fail closed. No automatic SpringBoard restart or heal occurs. Follow the selected-device doctor next step; `hidCompatibility.hostChromeLayout` is bundle presence only and `chromeLookupVerified=false`. Framework compatibility, booted state, AX activation, screenshots and ACKs do not prove HID delivery. Do not attribute an external native CUA drag/scroll failure to Triton. No verified host multi-tap/long-press primitive is supplied here; `act tap --duration` stays unsupported. App-owned semantic actions can check business state but cannot replace physical-touch regression proof. Report that boundary and preserve the typed error instead of claiming Device Hub HID support.

### Android hierarchy freshness

UIAutomator exit zero does not prove a current tree. Triton uses a unique dump path and validates its acknowledgement and XML. On `hierarchy_unavailable`, retain the failure and recapture after the UI has a usable root; never reuse old tree coordinates or claim business verification. Remote cleanup is limited to the current capture path and is best effort.

## Wired iOS backend selection

USB/wired is observed transport metadata, not a backend switch: iOS real discovery and app management use the selected Xcode's public `devicectl` / CoreDevice file-JSON route. Apple DeviceHub.app is not an automatic GUI/private-protocol fallback. Preserve command-specific sourceCommand(s), tool/source, artifacts and verification fields; do not assume all outputs contain strategy/transport/verification. Missing transport remains unknown. Physical `device logs` explicitly uses optional `idevicesyslog` with a verified USB identity alias; XCTest Runner and embedded runtime remain separate explicit surfaces. Distinguish inventory eligibility, host ACK, Runner/runtime readiness and business verification. A future physical Device Hub adapter needs a supported API/version matrix, exact identity, opt-in/readiness/ownership, fresh geometry and independent evidence; unknown delivery does not authorize replay or backend switching.

## Selected Simulator display diagnostics

Use `triton device doctor --platform ios --scope simulator --device sim:<UUID> --json` to read independent `simulatorDiagnostics.resize` and `.display` state/reason snapshots and an exact-target nextAction. Omitted --device adds no geometry query. Top-level doctor ok/capability names do not prove capture/input; captureVerified and inputDispatchVerified remain false. Unknown/unsupported/timeout is not inactive/primary. `resize.reason=unsupportedDevice` identifies an exact target-bound native capability rejection; `resize.hint` explains that repeating the same query cannot enable it. Use a verified compatible target/toolchain, or explicitly connected embedded App-only observation without claiming host capture/input recovery. Snapshot success is not an atomic lock or action verification; do not bypass unknown geometry, silently capture another display, or replay uncertain input. Different Xcode versions and user projects require their own evidence.

### Runner 启动失败诊断

Runner `start` 失败的 `error.startup` 分开报告 `launch`、`transport`、`health`、`uiAutomation` 的 `verified|unverified`；transport 指本次收到经过鉴权的 Runner 响应，不代表 XCTest DTX 已就绪。已知 native XCTest driver channel refusal 返回 `ios_runner_xctest_driver_channel_refused`；启动失败、就绪前进程退出分别为 `ios_runner_native_launch_failed` / `ios_runner_native_exited`，其余仍用 `ios_runner_start_not_ready` 并指出未验证阶段。公开响应仅使用固定分类，不回传原始日志、路径、配对或签名身份。分类只读本会话 native logs 的有界尾部，未命中特征不表示无原生错误；不要假设解锁即可修复，也不据此诊断确定的 Apple 工具链问题。保留 private session，检查配对/授权/XCTest兼容性后先 stop/recover，再显式启动新会话。CLI与HTTP使用同一 service/envelope。

### Runner 观察与坐标几何

Runner `inspect` / `screenshot` 自行读取前台 App 的 `app.frame` 与 XCTest device orientation。未知方向不再丢弃已取得的层级或 PNG：结果标记 `partial=true`、`geometryAvailability=unavailable`、`coordinateActionsAvailable=false`，附固定的 `geometryError.code/message/field`，并省略 `geometry` 和 `observationID`。旧坐标观察立即失效；不得根据图像尺寸猜测方向或复用旧 ID。已返回的最新语义 selector 仍可使用。缺少有限正值 App frame 返回 `observation_window_unavailable`，App 不在前台仍返回 `cross_app_not_foreground`。`appAlertPresent` 仅覆盖该 App 的 alerts；`systemAlertDetection=not-probed` 不证明无系统弹窗。恢复已知方向并重新观察后才可使用坐标动作；截图仍是敏感的整屏证据，不保证只包含目标 App。

### Embedded navigation button activation

Public UIControl target/action and accessibilityActivate remain supported. If a navigation/toolbar view cannot activate through either path, embedded tap returns `unsupported_capability` with `bar-button-action-unsupported`; it never guesses a UIBarButtonItem association from matching titles or retries behind a sheet. Expose a customView control/accessibility action, or use fresh coordinates with an explicit Simulator target and host HID. Physical devices require an already-ready allowlisted Runner or manual interaction; verify the business result separately.

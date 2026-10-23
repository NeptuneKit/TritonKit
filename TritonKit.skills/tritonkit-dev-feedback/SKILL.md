---
name: tritonkit-dev-feedback
description: Use when Codex is helping someone try, adopt, evaluate, or integrate TritonKit during its development stage, especially when the user has any requirement, bug, missing capability, confusing behavior, documentation gap, or compatibility concern that should become a GitHub issue in NeptuneKit/TritonKit. The AI agent should reproduce or clarify the finding, collect evidence, and submit the GitHub issue directly instead of asking the user to file it themselves.
metadata:
  version: 0.1.0-dev
---

# TritonKit Dev Feedback

## Embedded discovery migration

`triton serve` never advertises implicitly, including with an explicit LAN bind. Use `--advertise` or `TRITON_ADVERTISE=true|1` only when discovery is intended; `--no-advertise` overrides it. `false|0` disables it; other environment values fail before bind. Read `discovery` in `triton status --json` / `GET /status`: wanted is intent, advertising requires a real publication callback, failed includes the NetService error, stopped means withdrawn/disabled. Older servers omit the field. `identityVerified` remains false: publication is neither peer authentication nor proof of LAN reachability.

The SDK's `.environment()` no longer browses or selects the first Bonjour service. Prefer explicit App-process `TRITON_HOST` / `TRITON_PORT`, Debug bundle host, or `.device(...)`. For intentional discovery, use `.environment(discoveryPolicy: .bonjour(timeout: 0.15))` or App-process `TRITON_DISCOVERY=bonjour`; `disabled` is the default. `TRITON_DISCOVERY_TIMEOUT_SECONDS` must be finite and greater than 0, at most 5. Invalid configuration, multiple/unresolved/removed candidates, or no candidates make `start()` reject discovery without connecting to a fallback host. `.bonjourDiscovery(timeout:)` exposes the reason and candidates; `.bonjour(timeout:)` retains its optional endpoint API. Resolve ambiguity with an explicit host. A public ID, name, one candidate or TCP readiness never authenticates the service. Keep all SDK symbols in the existing file-level `#if DEBUG` bootstrap; Release discovery and runtime remain no-op. When upgrading from versions that browsed automatically, migrate the Debug bootstrap and verify the installed CLI/SDK schema before testing.

## Principle

TritonKit is in active development. Treat user needs, bugs, rough edges, missing APIs, confusing behavior, documentation gaps, and compatibility friction as repository feedback.

The agent owns the issue filing action when GitHub access is available. Do not ask the user to file an issue when enough context exists.

Repository: `NeptuneKit/TritonKit`

For the bundled iOS product workflow, see [Runner regression](../tritonkit-real-project-regression/SKILL.md#bundled-ios-runner-regression) and preserve `triton schema --command device.runner --json`. Target apps need no embedded SDK; the CLI includes its Runner and native USB transport without Appium/WebDriverAgent/Python/iproxy runtime dependencies. Xcode, compatible SDK, pairing, Developer Mode, signing, unlock and UI Automation authorization remain system prerequisites. Report prepare, health, prior automation proof, action receipt and business outcome separately. Safari input/navigation is not live-validated, and a TTL session is not permanent background or standalone operation.

For Xcode compatibility findings, preserve `triton device doctor --platform ios --scope all --json` and its `commandSupport`: `help-advertised-only` verifies advertised flags, not successful device actions. Report selected-toolchain runs separately from legacy JSON/help fixtures; never infer old-Xcode execution or retry a failed write through another backend.

If the user defines Xcode26 support as retaining existing commands, verify registrations/argument forms without demanding another SDK installation. Authorized isolated action checks must create and record a new task-owned Simulator, not reuse a shutdown business/default device. For install timeouts, preserve the failure and inspect app info/list before recovery: timeout does not imply no side effect. `xcode run --timeout` should reach Simulator install/launch as well as build/settings; no override retains legacy defaults. Host lifecycle acknowledgements and black screenshots are not UI/business success.

For Device Hub information, prefer `triton device info --platform ios --device <selector> --lock-state --json`. It is a readonly file-JSON snapshot, not a boot/pair/unlock operation. Report `passcodeRequired` and `unlockedSinceBoot` as distinct observed fields; do not infer screenLocked or business readiness. Preserve `not-probed` versus unknown, identity mismatch/backend failure versus success, and keep raw IDs/serials/IPs/private CoreDevice artifacts out of public feedback. A structured CoreDevice1001 getlockstate rejection maps to `unsupported_device_info_query`, not a successful snapshot or a global promise of Simulator support. Preserve that failure; querying details without the flag is a separate deliberate operation. Full Device Hub integration is a per-capability claim, not implied by a passing discovery or Simulator fixture.

## Fast workflow

1. Clarify only the minimum missing detail needed to avoid filing the wrong issue.
2. Check whether an existing open issue clearly covers the same feedback; comment instead of duplicating when appropriate.
3. Pick the narrowest reference below and read only that file plus `references/issue-filing.md`.
4. Reproduce or inspect locally when possible. Prefer machine-readable `triton ... --json` / `--jsonl` output.
5. Redact private app, account, network, path, log, screenshot, and evidence data before creating public GitHub content.
6. Run the public issue preflight in `references/issue-filing.md` immediately before any `gh issue create` or `gh issue edit`.
7. Create or update the issue with `gh issue create --repo NeptuneKit/TritonKit` / `gh issue edit --repo NeptuneKit/TritonKit`, or report the auth/network blocker with the exact command and body file.

## Reference routing

| Current feedback | Read |
| --- | --- |
| Ordinary bug, docs gap, feature request, or existing evidence to file | `references/issue-filing.md` |
| iOS embedded runtime hierarchy, snapshot, state, AX, input, WebView, media, semantic provider, or Xcode-run evidence | `references/evidence-ios-runtime.md` |
| Host-side iOS Simulator, Android Emulator, HarmonyOS / DevEco Emulator, Web Device Hub, install/launch/screenshot/readiness evidence | `references/evidence-host-devices.md` |
| Device Hub metadata, management, containers, or specialized platform evidence | [device-hub-feedback.md](references/device-hub-feedback.md) |
| CLI schema, capabilities, doctor, plan, replay, recovery, output contract, failure code, or taxonomy inconsistency | `references/schema-contract-feedback.md` |
| User asks how to add TritonKit to an iOS app via SwiftPM/CocoaPods | `references/app-integration-ios.md` |
| User asks how to use TritonKit with Harmony host-side validation or embedded SDK | `references/app-integration-harmony.md` |

## Device Hub feedback

For discovery, containers, Crash/Temporary, physical administration or specialized platforms, read [Device Hub feedback](references/device-hub-feedback.md). Preserve per-capability implementation and acceptance levels; historical execution never authorizes actions for the current report.

## Bounded observation feedback

For observation/recovery reports, preserve the exact entry and sanitized contract fields: outline aliases expire after 30 seconds and require a matching live whole-tree check; hierarchy `collection` partial/limits do not hard-cancel native IPC. OCR (`observe ocr --image` / `--device`) is candidate-only with no OID/action ref, top-left raw-raster pixels and points only with known scale; file mtime leaves freshness unknown. Record capture source, freshness, confidence and any explicit structure-unavailable reason.

Visual `observe settle` never proves business readiness. Workspace `--visual-settle` / HTTP `/workspace/run` optional `visualSettle` is disabled by default; unknown/timeout stops the chain. Record `debug ui-health` (legacy unknown, new SDK ready/busy/timed_out/circuit_open) separately from business assertions, and retain action `outcome`/`uiHealth`. Do not reproduce an unknown-outcome timeout by automatically replaying it or substituting HID: the original action may still complete. Probe health and take a fresh read-only observation first.

## Always keep

- Triton-first evidence for local simulator/emulator/device work: run `triton status/doctor/capabilities/schema/plan` or an exact command schema before falling back to raw `xcrun`, `adb`, `hdc`, DevEco CLI, XcodeBuildMCP, or `xcodebuild`.
- Issue bodies must include background, current behavior, expected behavior, reproduction/evidence, and proposed next step.
- Public reports must preserve useful facts: platform/tool versions, TritonKit version, commands, error codes, sanitized logs, and minimal snippets.
- Public reports must not include secrets, tokens, private project names, app names, bundle IDs, team IDs, organizations, users, accounts, emails, phone numbers, internal hosts, absolute private paths, full private logs, or unredacted artifacts.
- Keep implementation work separate from feedback filing unless the user explicitly asks to fix the issue too.
- For iOS Simulator coordinate-tap feedback, record whether the selector was a host form (`sim:<UDID>`, raw UUID, `booted`, `current`) or a canonical embedded form (`triton:ios-simulator:<UDID>/app:<bundle-id>`). Host-form coordinate taps must not be reported as embedded runtime actions, and host-HID acknowledgement alone is not proof of the foreground App's business postcondition.
- When feedback includes `testrec replay` / `local-simulated` / `matrix` output, report `verdictBoundary` explicitly. Legacy `ready`, `passed`, and `passedCount` are offline diagnostic compatibility state, not a real runtime verdict or reliability sample; a result without the additive boundary is legacy/unknown. Route real-verdict feedback through `test import -> test validate -> test run` with redacted placeholders rather than proposing a second testrec executor.
- When feedback includes `test reliability-preflight`, report it as an offline collection-contract check only. `ready_to_collect` must retain `writesEvidence=false`, `usesRuntime=false`, and `eligibleForReliabilityGate=false`; a negative control is valid only with its frozen assertion failure type and a non-optional read-only assertion plan. It does not establish a target/server/reset receipt, execute a test, or pass a reliability gate. Never include the private collection, plan/evidence paths, UDID, bundle, target, flow, selector, or reset identity in feedback.
- When feedback includes receipt-backed reliability collection, distinguish `reliability-reserve` from `reliability-sample`: reserve only writes an immutable private receipt at a fresh operator-owned root and returns `receiptSha256`; operator/CI must keep that hash outside the root. Sample and receipt-backed report require `--expect-receipt-sha256 <64-lowercase-hex>` and fail before reset/lease/target/runner/evidence scanning when it is missing, malformed, or mismatched. Never call a hash recomputed from the current root an external anchor, and never expose the hash, receipt, root, target, reset, evidence, bundle, or UUID in public feedback. A busy or stale lease is fail-closed (`reliability_collection_busy`), not an invitation to delete/retry. Neither command may be described as booting, selecting, resetting, installing, launching, stopping, or taking over shared runtime lifecycle. A negative result is `ok=true` / exit 0 only for terminal `failed` with its frozen deterministic assertion failure type exactly matched; blocked, stopped, launch/primitive/transport/AI failures, missing/wrong failure type, supported nonpass, or negative unexpected pass are still one typed `ok=false` / exit 1 result, not a second error envelope. `reliability --samples` is legacy diagnostic-only and cannot pass the Stage 1 gate. SHA-256 anchor checking is not a signature, identity proof, remote ledger, or hostile-filesystem defense.
- For a receipt-bound slot, `reliability-sample` writes private `reliability/identity-chain-v2.json` only after its runner has finished and the fixed binding/reset/plan/runtime/run components are present. Public report feedback may state only the `identityChain` aggregate (`state`, expected/valid/missing/invalid slot counts, `receiptAnchorVerified`); it must never expose chain hashes, artifact paths, flow IDs, run IDs, reset identities, target IDs, bundles, or UUIDs. `identity_chain_incomplete` means a receipt-declared slot has no v2 chain; `identity_chain_invalid` means chain, terminal proof, frozen identity, component bytes, or manifest declaration no longer agrees. Neither result proves a real reset, real runtime/App execution, history, or hostile-filesystem resistance, and operators must not backfill/retry a claimed slot to manufacture a chain.
- For receipt-backed reliability feedback, identify the additive `stage1` cohort explicitly: `stage1A` measures only the 60 supported slots (3 × 20 ECR/ORR and strict per-flow count), while `stage1B` measures all 61 receipt/control slots (binding/reset/plan/target/manifest/outcome/identity-chain integrity and FER across expected-negative plus any supported nonpass). Legacy `--samples` has model value `stage1=nil` and omits that JSON field; receipt-backed `stage1.gate` must equal the top-level gate, and a Stage 1B integrity blocker alone is not `stop_expansion`. Public feedback may include only aggregate counts/rates/statuses/blocker codes, never a slot, flow, receipt, path, target, hash, run, or reset identity.

## 2026-09 issue 合同补充

- `xcode test --jsonl` 默认 compact；完整 raw 日志在 artifact，显式 `--progress full` 才转发。按子命令 schema 选参数，`xcode run` 不接受 `--progress`。
- DerivedData 存在不证明 cache 命中。`reuseVerification=unknown`，`incrementalExpected=false` 仅表示没有验证过的预期；读取 `observedBuild.taskLogCounts/logCoverage`，不擅自称增量或全量。
- 默认不传 `--derived-data-path`，由 Xcode 使用用户级 DerivedData。该参数必须显式指定，只用于隔离或恢复，可能造成高磁盘占用，非必要不要开启。排查构建缓存用 `triton xcode derived-data inspect --json` 或 `cleanup --json` 预览；`.triton/DerivedData` 只能作为显式 legacy root。Triton 不提供 DerivedData 删除；通用自动删除需求已撤出范围。兼容参数 `--confirm` 在删除前返回 `derived_data_cleanup_unavailable`，活动 Xcode lane 保留 `xcode_not_idle`；等待空闲不会启用删除，不建议重试 confirm。若用户另行要求人工清理，先只读检查并明确该独立操作范围，不自动回退手工删除。统计为逻辑文件字节和修改时间，不是可回收磁盘量或最后使用时间；只接受精确 `.triton/DerivedData` 根或用户全局根，symlink 目标不跟随。
- `debug attrs --oid` 支持 UIView/CALayer oid；UILabel 的有效字体/颜色与 UTF-16 run 有界输出，正文预览和 run 都要检查截断字段。
- collection cell 激活尊重 allowsSelection/delegate，success 只证明公开 callback，必须验证业务后置条件。`act tap --duration` 不支持长按，提前 typed unsupported；embedded longPress 和非滚动手势也不伪造成功，使用 App 显式注册的 semantic DEBUG action 或检查实际 provider 能力。
- Harmony ArkWeb bridge-call 需可达 DevTools socket 与页面 `window.__tritonBridge.methods` 自有函数白名单；函数接收 `(params, complete, reject)`，支持返回值/Promise/callback。明确选中 CDP page ID，stale/ambiguous 失败关闭；不把 CDP page ID 当导航 session 验证，清理失败也可能发生在页面方法已执行之后，重试前先验业务状态。

`triton xcode ... --package <Package.swift-or-directory>` 的相对 `--derived-data-path` 按 package 工作目录解析并在 invocation/cache 元数据中给出绝对路径；`xcode test --result-bundle <relative>` 同样按 package 工作目录规范化，执行命令、inline xcresult parser 和最终 `resultBundlePath` 共享该位置。绝对路径保持不变；非 package 工作流保留调用目录语义。

## Optional view-highlight acceptance

`triton highlight capabilities/apply/status/clear` is optional; never require an embedded SDK for ordinary host screenshots. See [the highlight workflow](../tritonkit-emulator-cli-takeover/references/view-highlight.md). Validate real properties, before/during/after images, exact session cleanup, TTL, business-write conflicts and reconnect. Screenshot success is not restoration success; preserve operationID/sessionID and incomplete cleanup evidence. This slice supports Debug UIKit ordinary views only.

## Optional floating-picker feedback (SP-201, unreleased)

The SP-201 UIKit floating picker is integrated into local main but is not a published release; the SP-209 SDK hub remains an isolated worktree candidate. Verify a matching candidate SDK/CLI and command schema before suggesting `triton inspect capabilities/selection/clear`. Preserve source/version, explicit runtime target, configuration, selection state and action outcome separately; never describe an HTML mock or a macOS-skipped UIKit test as native acceptance.

In the app's existing file-level `#if DEBUG` bootstrap, opt into both `config.features.insert(.inspector)` and `config.picker = .init(enabled: true, ttlSeconds: 300)`. The default is off and Release is no-op, with no added third-party dependency. `TRITON_PICKER_ENABLED=1` enables the default picker environment configuration only; it does not insert `.inspector` or replace the app's runtime startup gate. The fixture inserts the feature for convenience; ordinary apps must do so explicitly. Keep `.input` enabled when guarded taps are required.

Read `triton inspect selection --target '<runtime-target>' --json`, then use `triton act tap --target '<runtime-target>' --selection '<selection.id>' --selection-revision '<selection.revision>' --runtime-instance-id '<runtimeInstanceID>' --json` with fields from that same response. Selection does not trigger a business action. Only eligible UIKit buttons support guarded taps; labels/cells are `observeOnly`, with SwiftUI virtual nodes, DOM, Android and Harmony deferred. Re-selection, expiry or identity loss must reject the old guard without coordinate/OID fallback. Check `ok`, validity, supported actions and the business postcondition; record whether the defect is entry visibility, gesture leakage, target identity, delivery or business behavior. Clear deliberately with `triton inspect clear --target '<runtime-target>' --runtime-instance-id '<runtimeInstanceID>' --json` when cleanup is intended. Redact labels, identifiers and screenshots before public feedback.

### SDK hub 与选择器运行时开关

Debug App 预先授权 `.inspector` 后，在 MainActor 通过 `TritonKit.shared.setPickerEnabled(true/false)` 开关，读取 `isPickerEnabled` 判断会话状态；不重新 start SDK。接入代码放独立 Debug bootstrap。宿主负责自己的唤回入口，SDK 不实现宿主调试菜单。

圆球单击以系统 pageSheet 打开 SDK hub：首页真实连接摘要，连接、选择器、SDK 功能、应用、入口五路由。放大镜、辅助框、触感在选择器二级配置。SDK 功能是宿主配置的只读展示，不代表平台支持、provider 就绪或业务可执行；不展示未被消费的隐私配置或硬编码 SDK 版本，不为填充菜单添加无效按钮。

系统 modal 内部使用 UINavigationController 与 insetGrouped UITableViewController；iOS 15+ 使用 medium/large detents、grabber，iOS 13/14 降级系统 pageSheet，不承诺半屏。验收 modal 打开暂隐藏圆球、全部选择提示与罗盘，下拉或关闭恢复有效选择上下文；系统遮罩拦截整个窗口业务触摸，外围透传仅适用于 modal 关闭后。罗盘只保留节点导航和清除。隐藏操作仅在入口页经系统 UIAlertController 确认后执行，取消保持状态；确认后旧 selection guard 失效，宿主 API 恢复从空选择开始。分别核对隐藏/恢复前后连接与业务计数不变、Release 不能开启，以及浅深色、小屏滚动和子页面返回。SP-209 为未发布候选，使用前核对匹配源码/版本与实际验证记录；自绘卡片通过记录不能代替系统 modal 验收。


### Host geometry and Android foreground evidence

For Simulator host AX, `ios_host_ax_geometry_unavailable` rejects missing/invalid geometry before coordinate-dependent work; preserve that failure and inspect `triton device doctor --platform ios --scope simulator --json`, rather than guessing dimensions. Android `device foreground` adds `observed.activity` and `observed.component` from trustworthy resumed activity records; unknown omits them, and foreground identity does not prove business readiness. Legacy ADB text input quotes remote-shell literals and redacts source commands; distinguish shell safety from device Unicode/keymap and `%s` input support. Record offline fixture acceptance separately from real-device input.

## Device Hub host input authority

Discover `triton schema --command act.tap --json` on the actual CLI before using `--hid-only`. Explicit `--platform ios` defaults to AX activation, including coordinates: `source=host-ax`, `strategy=accessibility-perform-press`, `verification.required=true`. For a touch-path regression use `triton act tap --platform ios --device sim:<UDID> --at 120,240 --hid-only --json`; only local Simulator coordinates are accepted, with no semantic/embedded/WebView fallback. Without `--platform`, existing explicit Simulator coordinate selectors retain host HID routing.

Tap and `triton sim swipe` use the native digitizer bundled in triton, without an external Baguette executable or chrome lookup. Device Hub guest HID ownership returns `ios_host_hid_device_hub_attached`; unknown ownership and unsupported display topology fail closed. No automatic SpringBoard restart or heal occurs. Follow the selected-device doctor next step; `hidCompatibility.hostChromeLayout` is bundle presence only and `chromeLookupVerified=false`. Framework compatibility, booted state, AX activation, screenshots and ACKs do not prove HID delivery. Do not attribute an external native CUA drag/scroll failure to Triton. No verified host multi-tap/long-press primitive is supplied here; `act tap --duration` stays unsupported. App-owned semantic actions can check business state but cannot replace physical-touch regression proof. Report that boundary and preserve the typed error instead of claiming Device Hub HID support.

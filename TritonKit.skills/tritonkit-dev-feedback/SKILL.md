---
name: tritonkit-dev-feedback
description: Use when Codex is helping someone try, adopt, evaluate, or integrate TritonKit during its development stage, especially when the user has any requirement, bug, missing capability, confusing behavior, documentation gap, or compatibility concern that should become a GitHub issue in NeptuneKit/TritonKit. The AI agent should reproduce or clarify the finding, collect evidence, and submit the GitHub issue directly instead of asking the user to file it themselves.
metadata:
  version: 0.1.0-dev
---

# TritonKit Dev Feedback

## Principle

TritonKit is in active development. Treat user needs, bugs, rough edges, missing APIs, confusing behavior, documentation gaps, and compatibility friction as repository feedback.

The agent owns the issue filing action when GitHub access is available. Do not ask the user to file an issue when enough context exists.

Repository: `NeptuneKit/TritonKit`

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
| CLI schema, capabilities, doctor, plan, replay, recovery, output contract, failure code, or taxonomy inconsistency | `references/schema-contract-feedback.md` |
| User asks how to add TritonKit to an iOS app via SwiftPM/CocoaPods | `references/app-integration-ios.md` |
| User asks how to use TritonKit with Harmony host-side validation or embedded SDK | `references/app-integration-harmony.md` |

## Device Hub metadata feedback

For `device files`, record selector/domain/optional directory/user scope with private values redacted. Default output is shallow token metadata, not file content; --include-sensitive filenames/relative paths and private JSON artifacts must not enter an issue. distinguish unsupported_device_file_query (observed CoreDevice capability restriction), device_file_domain_policy_required (temporary before backend), device_files_limit_exceeded (local acceptance budget, not remote transport/disk hard limit), and identity/domain/request-scope mismatch (fail closed). Never silently retry DeviceFS/another backend or boot/pair/unlock a device to make feedback green; missing metadata is unknown, non-directory is not necessarily regular, isWritable does not authorize a write. Full Device Hub progress is per capability and actual acceptance, not help or one metadata query.

For `device mountpoint` feedback, preserve command/error/token/identityBinding metadata but never publish private JSON dataPath/raw IDs. Exact unique echoed-device binding is required because result has no identity. query_failed is not proof of global platform unsupported; a token/artifact is not path existence, mounted state, contents, read/write or business verification. No automatic target preparation/Finder/explicit mount-unmount/backend retry; CoreDevice service and private artifact side effects should be declared.

Hardware observation feedback: device info.hardware.platformObservation optional additive/exact explicit platform/deviceType/reality with layout source, old missing field nil-compatible. No name/product/marketing/runtime/capabilities/legacy ios OS/iPadOS/physical inference, reported iOS+iPad stays ios/ipad; unknown reality not physical and unknown raw observation values not echoed. Present modern even null/partial blocks deprecated mirrors, no controls/business/ID/argv/dispatch change. Require nested schema/CLI binding/roundtrip/current SDK readonly evidence, fixtures other families not control acceptance.

Platform feedback: device platforms --json is compiled Apple catalog, optional --apple-platform catalog filter; --inventory one availableSimulator metadata/globalfamilycount, unknown retained/no IDs/names/rawruntime. Default zeroqueries/no physical/boot/control/server. iOS runtime not iPadOS/iPhone-iPad proof, no Mac guess; 0 not unavailable. Report-only auth/control false not old command denial. Old ios namespace/IDs/argv stable; generic sim and Applecap arrays not specialized acceptance. Require fixture default/filter/provider/staticerrorprivacy plus actual envelopes, never native action/state claim from counts.

Administration regression and feedback must distinguish readonly --plan-only, fixture-tested explicit execution, and separately authorized physical acceptance. Use the Device Hub 能力组 section below; do not execute real pairing or diagnostic collection without task authorization. Private native logs and identifiers must remain local.

Relative-directory feedback adds optional --subdirectory only inside explicit native container/app view (raw1..32/4096UTF8/255each, no absolute/dot/dotdot/empty/control, no normalize/URLdecode). Do not publish scope fields or nativepath; exact directoryToken/entry scope correlation, not auth/secrecy. Input+standard-root shape totalbudget before discovery/artifacts and fresh actual UTF8-home/UUID binding+recheck before directory IO; root and each relative-layer same-FD owner/nofollow, system ancestors nofollow only. No content/recursive/outsidecontainer/Temporary-domain creation/Finder/autoprep/fallback; require actual owned state restore, not readonlyreview/fixtures.

Single container feedback preserves optional directoryToken and container-scoped entry tokens; --container-identifier is a private one-component native name only with app views, never verified bundle/group identity. Do not paste selector input or nativepath/private artifacts in issues. Input never selection-field echoed; include-sensitive leaf names can coincidentally match it. Root/each-relative-layer owner/nofollow and pre-discovery/artifact parameter validation are required; never normalize, auto-select, fallback or recurse. This remains shallow metadata, not installation/auth/business proof.

For explicit `device fs list` feedback preserve backend=devicefs/view=mount-root|app-data-containers|app-group-containers, entryIdentityVerification (native devicefs synthetic dirent/stat IDs not comparable; same-directory nofollow double-stat, other FS strict dirent binding; not atomic/provenance), default private entry tokens/kind/regular size and typed root/reader/limit errors; never publish nativepath/private fileJSON, include-sensitive names or raw physical IDs/aliases. It inspects shallow root metadata but not contents/domain mapping/mount provenance/writeauthorization/business readiness. Same-FD owner/nofollow and currentUUID root binding are required, query timeout is not FUSE deadline/remotehardlimit/atomic snapshot; no files-error fallback or autoprep/Finder/explicitmount. Real acceptance is owned-only state restore proof, not static fixture success or proof of physical listing.

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
- 排查 repo-local 构建缓存占用时先运行 `triton xcode derived-data inspect --root .triton/DerivedData --json`；`triton xcode derived-data cleanup --json` 只做 dry-run，确认条目和预计释放量后才允许显式追加 `--confirm`。仅接受 canonical repo-local `.triton/DerivedData` 或用户全局 Xcode DerivedData root，禁止清理源码/配置/凭据路径，也不要在 Xcode 正在构建时清理。
- `debug attrs --oid` 支持 UIView/CALayer oid；UILabel 的有效字体/颜色与 UTF-16 run 有界输出，正文预览和 run 都要检查截断字段。
- collection cell 激活尊重 allowsSelection/delegate，success 只证明公开 callback，必须验证业务后置条件。`act tap --duration` 不支持长按，提前 typed unsupported；embedded longPress 和非滚动手势也不伪造成功，使用 App 显式注册的 semantic DEBUG action 或检查实际 provider 能力。
- Harmony ArkWeb bridge-call 需可达 DevTools socket 与页面 `window.__tritonBridge.methods` 自有函数白名单；函数接收 `(params, complete, reject)`，支持返回值/Promise/callback。明确选中 CDP page ID，stale/ambiguous 失败关闭；不把 CDP page ID 当导航 session 验证，清理失败也可能发生在页面方法已执行之后，重试前先验业务状态。

## Device Hub 能力组（2026-10-10）

`device containers --device <selector> --bundle-id <id> [--group-id <id>] [--list] --json` 查询 SDK 显式 bundle/group membership 与容器路径绑定，默认只公开 tokens、状态和能力边界。`--list` 只对所选 Simulator 的受限原生容器做浅层元数据读取，逐级 nofollow/owner/预算检查，不读取业务内容。真实设备支持 SDK 元数据，不将其设备路径当作本机路径打开。旧 SDK 缺少参数明确 unsupported，缺绑定字段 unavailable；不能按 App 名/目录名猜归属，`deviceFSBindingVerified=false` 始终保留。

Crash 的三条契约独立：`device files --domain-type systemCrashLogs` 是 CoreDevice 浅元数据文件域；`device fs list --view diagnostic-reports` 只枚举 DeviceFS 明确的 `DiagnosticReports` namespace，缺目录就失败，不能猜 root 映射或宣称与文件域逐项等价；`device diagnose` 是敏感诊断 ZIP 采集，可能含宿主日志。均不得由目录存在推导额外权限。

Temporary 查询可能创建客户端域，实际是否新建没有可靠后置证据。默认继续返回 `device_file_domain_policy_required`；只有 `device files --domain-type temporary --domain-identifier <client-id> --allow-domain-creation --confirm --execute-runner --audit-record <id>` 才允许执行，执行前持久审计，`riskLevel=automation`、creation unknown，失败可能已经创建且不自动重试。本轮无真实 Temporary 查询。

`sim pairs --json` 读取原生 watch/phone 配对关系，不证明输入、连接或业务就绪。`device platforms --include-real-devices [--device <exact-id-or-inventory-token>] --json` 独立发现/选择 Apple physical 硬件元数据；只有 SDK 显式 physical 纳入，不从名称、transport 或 capability 数组推断，旧 iOS 路由不扩大。Crown/侧键、tvOS 焦点/选择/返回、visionOS 视角/场景/专门输入仍无已验证程序后端，明确未支持；macOS 仍区分 Xcode build/test 工作流与 Device Hub 控制。

`device platform-control --platform <watchos|tvos|visionos|macos> --action <control> --json` 目前只提供事实契约：watchOS Crown/Action 与 tvOS remote/focus 返回 `fixture-only`（Crown 需有限非零 `--delta`），visionOS gaze/pinch/scene、watchOS side-button 与 macOS Device Hub 控制返回 `unsupported`。所有这些结果均为 `executable=false`、`actionsExecuted=false`；没有 Triton XCTest runner 或目标绑定时，不得把 XCTest API 名称、fixture 或 GUI 证据升级为真实输入验收。

`device pair|unpair|diagnose --platform ios --scope real --device <selector> --plan-only --json` 保留只读策略审查。执行后端要求 `--execute-runner --confirm --audit-record <id>`；diagnose 另需 `--output <private.zip>`，可设 `--maximum-archive-bytes`。先持久化 intent，再单次原生命令、严格 file-JSON 绑定和独立配对后置状态 / 诊断 ZIP 检查，最后写 completion；成功、失败、超时、部分完成分开，未知状态不重试。诊断仍可能包含宿主 CoreDevice 日志，即使关闭 host sysdiagnose；与 Crash 日志域不同。输出目录须已存在且仅当前用户可访问，拒绝覆盖/符号链接，0600 发布及本地大小限额不等于原生采集峰值限制。外部工具使用路径，前后 inode 检查不消除同用户并发替换风险。此后端本轮仅隔离 fixture 验证，未获真机执行/诊断采集验收授权；旧 `sim pair/unpair/diagnose` 保留。

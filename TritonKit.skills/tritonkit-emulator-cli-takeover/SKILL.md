---
name: tritonkit-emulator-cli-takeover
description: Use when designing, implementing, extending, or validating TritonKit local CLI takeover of iOS Simulator, Android Emulator, or HarmonyOS / DevEco Emulator capabilities. Covers local target discovery, app lifecycle, readiness, screenshots, AX/layout, logs, command ledger, evidence, destructive-action policy, WebView-aware action routing, and deciding what belongs in `triton` CLI without adding Web, remote agents, real-device orchestration, or device-cloud services.
metadata:
  version: 0.1.0-dev
---

# TritonKit Emulator CLI Takeover

## Core Boundary

TritonKit's emulator takeover surface is **local CLI + local simulator/emulator**.

Include:

- iOS Simulator, Android Emulator, HarmonyOS / DevEco Emulator.
- DEBUG-only embedded runtime.
- Local `.tritonevidence`, `.tritonplan`, `.tritoncase`, and `.tritonbatch`.
- Agent-facing machine-readable CLI contracts.

Exclude by default:

- Physical devices, remote agents, device cloud, Web / Wails UI as business control surfaces, public HTTP product APIs, Postgres, Kafka, Webhook, multi-tenant operations, and built-in VLM loops.

Before using fallback tools for any local emulator or simulator action, preserve a Triton fact source first:

```bash
triton status --json
triton doctor --json
triton capabilities --json
triton schema --json
triton schema --command <command> --json
triton plan ... --json
```

Fallback to `baguette`, raw `xcrun` / `simctl`, `hdc`, `adb`, DevEco Emulator CLI, XcodeBuildMCP, or raw `xcodebuild` only when Triton proves failure, unsupported scope/capability, or missing schema coverage. Keep the Triton command, error code or unsupported evidence, and fallback command in the report.

## Device Hub Official Discovery

Use existing CLI contracts, not Device Hub window automation:

```bash
triton device list --platform ios --scope simulator --json
triton device list --platform ios --scope all --json
triton target resolve sim:<udid> --platform ios --json
```

Xcode 27 CoreDevice inventory includes simulated and physical devices. Prefer authoritative `properties` when present; derive kind from observed hardware reality, never from the name, transport, or UUID shape. The combined iOS inventory joins canonical `sim:<UDID>` identities and prefers simctl lifecycle facts; explicit `--scope all` must fail if either backend fails, rather than claim complete discovery. Explicit simulator selectors without scope remain simulator-only. Missing/unknown metadata reports `ready=false` with `readiness-unknown`; physical discovery readiness is development-service eligibility, not unlocked state or business readiness. `--scope real` is existing readonly discovery compatibility, not permission to orchestrate physical devices. Keep raw captures private and distinguish anonymized captured shapes from synthesized new-only fixtures. Do not parse terminal tables, map preparedness numbers without a documented contract, or enable input/screenshot capabilities merely because CoreDevice advertises them.

For an already-started Simulator or paired physical iOS target, use `triton device info --platform ios --device <selector> [--lock-state] --json` for whitelisted properties. The optional lock query returns observed `passcodeRequired` and `unlockedSinceBoot`, not screenLocked or business readiness; unrequested is `not-probed`, absent fields unknown. It never starts/pairs/unlocks a target or retries another backend. Raw identities, serials, network addresses and upstream capabilities stay private. Structured CoreDevice1001 lock capability rejection returns `unsupported_device_info_query`; preserve that failure, not a silently downgraded success or global Simulator guarantee. Device Hub full coverage must be reported per capability/platform and evidence, not inferred from this snapshot.

`triton sim rename <explicit-uuid> "New Name" [--timeout <seconds>] --json` is a standalone reversible display-name mutation, not boot/delete/clone. Reject ambiguous/physical typed selectors, blank/control names and invalid timeout before execution. Treat success as submission-only; independently use device list to verify name/canonical identity/state. Acceptance must restore only the explicitly owned instance's original name and never overwrite an unexpected third-party rename.

`triton device files --platform ios --device <selector> --domain-type systemCrashLogs --json` lists shallow metadata only; app domains require --domain-identifier. Optional --subdirectory/--username bind the JSON query scope. Default name/path metadata is private (opaque correlation token); explicit --include-sensitive exposes only filenames/relative paths. No contents, owners/xattrs/isWritable authorization/raw identifiers, recursion/copy or automatic backend retry. JSON/entry limits reject local acceptance only; temporary requires a separate side-effect policy and returns device_file_domain_policy_required before backend. Simulator-specific CoreDevice1001 listFiles rejection is unsupported_device_file_query, not a global platform claim. Restore only explicitly owned instances after acceptance; never borrow booted business devices.

`device mountpoint --platform ios --device <selector> --json` independently returns a DeviceFS correlation token and private artifact references. Require unique echoed raw --device exact binding; native path/raw physical IDs remain private. Do not access returned path, invoke Finder, explicitly mount/unmount, or auto boot/pair/unlock/retry; filesystem/mount/content/business verification remain false. CoreDevice service/private artifact side effects remain, and metadata does not prove path presence or read/write authorization. Unknown capability errors query_failed, not guessed unsupported; local JSON limits are not remote hard limits.

Device info hardware.platformObservation is optional/additive, fresh identity-bound explicit exact hardware platform/deviceType/reality with sourceLayout; old missing field decodes nil. iOS+iPad remains ios/ipad, no name/product/marketing/runtime/legacy ios/capability inference; unknown reality not physical, unknown raw observations not echoed, modern present/null/partial forbids deprecated fallback. Preserve IDs/argv/dispatch/no auto controls/business proof. Check nested schema/CLI roundtrip, separate current physical readonly evidence from other-family fixtures/controls.

Apple platform report: `device platforms --json` compiled catalog, not current SDK/action availability. --apple-platform catalog-only filter; --inventory one available Simulator metadata query/global family counts (unknown retained), no IDs/name/rawruntime or physical/boot/control. Default zero queries/no server. iOS runtime not iPadOS/iPhone-iPad proof, no Mac Simulator guess; zero not unavailable. Report-only false control/auth flags not old command denial. Old ios IDs/argv stable, no capability-array/generic command autoenable; errors static/code only. Keep compiled report, observed counts and actual action acceptance separate.

`device pair|unpair|diagnose --platform ios --scope real --device <selector> --plan-only --json` 保留只读策略审查。执行后端要求 `--execute-runner --confirm --audit-record <id>`；diagnose 另需 `--output <private.zip>`，可设 `--maximum-archive-bytes`。先持久化 intent，再单次原生命令、严格 file-JSON 绑定和独立配对后置状态 / 诊断 ZIP 检查，最后写 completion；成功、失败、超时、部分完成分开，未知状态不重试。诊断仍可能包含宿主 CoreDevice 日志，即使关闭 host sysdiagnose；与 Crash 日志域不同。输出目录须已存在且仅当前用户可访问，拒绝覆盖/符号链接，0600 发布及本地大小限额不等于原生采集峰值限制。外部工具使用路径，前后 inode 检查不消除同用户并发替换风险。此后端本轮仅隔离 fixture 验证，未获真机执行/诊断采集验收授权；旧 `sim pair/unpair/diagnose` 保留。

Bounded container-relative metadata: optional `--subdirectory <relative-directory>` requires explicit container/app view; raw1...32 components/4096 UTF8 bytes/255 each, no absolute/dot/dotdot/empty/control, no normalize/URLdecode. Standard-root shape budget64/16384 preflight before discovery/artifacts (placeholder never IO/identity), fresh actual parent UTF8 bytes and UUID binding then exact combined recheck before directory IO. Root/every relative owner/noFollow same FD, not all system ancestors owner=current uid. Scope tokens add exact subdir bytes, omitted old compatibility; no scope-field echo/only opt-in leaves. Existing opted-in directory selection only, no create/content/recursive/outsidecontainer/Finder/autoprep/fallback; app tmp metadata not Temporary-domain creation. Actual owned privacy/bounds/state restore acceptance mandatory.

Single native container metadata: add `--container-identifier <native-child-name>` only to app-data/app-group views. One raw 1...255-byte UTF8 component, no dot/dotdot/slash/control; pre-discovery/artifact validation, never normalize. Same FD root and every relative-layer owner/nofollow. No verified bundle/group identity/install proof; requested identifier not selection-field echoed, opaque directoryToken/view+container entry salt, old omitted-scope tokens unchanged. Include-sensitive only leaf names (coincidences allowed); no outside-container paths/content/recursion/fallback/Finder/autoprep. Native names come from explicitly opt-in namespace listing, no automatic child selection; actual owned lifecycle restoration required.

`device fs list --platform ios --device <selector> --json` deliberately lists standard identity-bound DeviceFS fixed namespace shallow metadata only (--view mount-root default|app-data-containers|app-group-containers); no bundle/group-ID navigation. Device-root owner checked before namespace open then namespace owner, same FD chain. Exact fstatfs devicefs admits observed synthetic dirent/stat ID difference while always requiring double nofollow stat inode/device/kind, other filesystems strict dirent binding. entryIdentityVerification not snapshot/provenance proof, old root tokens compatible/new view-salted; never automatic files-error fallback. Fresh private mountpoint/UUID+exact parent binding and same-FD owner/nofollow are mandatory. Default token/kind/regular size, include-sensitive adds names only. No content/subdirectory/domain guess/temporary/Finder/explicitmount/auto boot-pair-unlock. hostFilesystemInspected=true, mountStateVerified/readWriteAuthorizationVerified/businessReadinessVerified/contentsRead=false. Query timeout is not FUSE syscall deadline; limits are local acceptance, not remote hard limits or atomic snapshot. Nativepaths/private artifacts never publish; domain navigation remains missing.

## Standard Workflow

1. Update the relevant `docs-linhay/spaces/<space-key>/README.md` or technical design with BDD acceptance.
2. Add focused failing tests for model/parser/schema/CLI behavior.
3. Implement shared DTOs and contracts before CLI glue.
4. Keep agent-facing output JSON / JSONL and schema-backed.
5. Update command schema, capability matrix, output contracts, failure codes, and recovery categories in the same slice.
6. Sync docs, memory, and relevant skills.
7. Validate with focused tests first, then package-level tests.

## Reference Routing

Start with [references/feature-index.md](references/feature-index.md) to map the requested feature to the smallest reference file. Then read only the matched reference(s).

## Old/New Xcode Command Compatibility

Use `triton device doctor --platform ios --scope simulator|real|all --json` before selecting host paths. `commandSupport` reports nested upstream help and required flags on the selected Xcode, marked `help-advertised-only`; it does not prove boot/install/launch success. Common argv and file JSON remain compatible without new-only output flags or removed details `--show`. Simulator-only health does not depend on CoreDevice; all/real requires its discovery contract. Respect DEVELOPER_DIR in the child environment, do not switch global Xcode, and never retry a state-changing operation via an alternate command just because the first failed. Report old-toolchain fixture coverage separately from real installed-toolchain verification.

## Common Agent Commands

Target and readiness:

```bash
triton device doctor --platform ios --json
triton device doctor --platform android --json
triton device doctor --platform harmony --json
triton device list --platform ios --json
triton device list --platform android --json
triton device list --platform harmony --json
triton device use <alias-or-id> --json
triton device wait-ready --device <alias-or-id> --json
```

Observation and action:

```bash
triton observe tree --platform <ios|android|harmony> --device <selector> --outline --json
triton node resolve @1 --platform <ios|android|harmony> --device <selector> --json
triton act tap "登录" --platform <android|harmony> --device <selector> --json
triton act tap "登录" --target <ios-runtime-target-from-triton-list> --json
triton act tap --device sim:<ios-simulator-udid> --at <x,y> --json
triton act swipe --target <ios-runtime-target-from-triton-list> --start-x 110 --start-y 700 --end-x 110 --end-y 140 --duration 0.6 --json
triton act tap --webview-aware --selector "#submit" --webview-id <webview-id> --page-session-id <page-session-id> --expect-text "成功" --json
triton wait text "成功" --platform <ios|android|harmony> --device <selector> --json
```

The iOS coordinate-only form with `sim:<UDID>`, a raw Simulator UUID, `booted`, or `current` is a constrained host-HID path: it bypasses embedded target resolution so a stale/background runtime on the same Simulator cannot receive the action. Canonical `triton:ios-simulator:<UDID>` and `/app:<bundle-id>` selectors remain embedded-runtime targets. Treat host-HID success as submission-only and verify the business postcondition separately.

Evidence:

```bash
triton sim record --simulator <udid-or-booted> --output /tmp/<case>.mov --duration 10 --json
triton sim logs --simulator <udid-or-booted> --output /tmp/<case>-sim.ndjson --duration 5 --json
triton sim app-console --simulator <udid-or-booted> --bundle-id <bundle-id> --output /tmp/<case>-app-console.log --duration 5 --max-bytes 10485760 --json
triton evidence capture --case <case> --output <dir.tritonevidence> --json
triton evidence summary <dir.tritonevidence> --json
triton evidence redact <dir.tritonevidence> --profile ios-private --output <redacted.tritonevidence> --json
```

For iOS Simulator evidence, inspect `manifest.primaryArtifact.fidelity` before visual acceptance. A successful host-composited capture uses `kind=screenshot`, `scope=host-simulator`, `source=simctl-framebuffer`, and `fidelity=full-screen`; the embedded App-layer image remains `kind=screenshot.runtime`, `scope=runtime-app-layer`, and `fidelity=app-layer`. If the host framebuffer cannot be captured, expect `ok=false`, `partial=true`, `skipped[].kind=screenshot.host`, `error.code=host_screenshot_unavailable`, and a structured `triton sim screenshot` fallback. Never treat a runtime-only App-layer screenshot as proof that system sheets or compositor UI are visible.

## Safety Rules

- Destructive or state-changing host actions require explicit flags or policy.
- Host command success is not business success. Verify with `wait`, `find`, `assert`, screenshot, app prefs, layout/AX, or evidence.
- Simulator video success is not `simctl` exit zero or MOV container duration. Require `durationValidation=passed` and inspect `actualDurationSeconds`; `sim_record_truncated` or `sim_record_invalid_artifact` means the MOV is failed evidence.
- Keep logging sources explicit: `sim logs` is unified logging only, while `sim app-console` relaunches one App and writes merged process stdout/stderr to a sensitive bounded artifact. Never infer one source from the other or inline console content into issue/evidence JSON.
- Multiple local targets must return `ambiguous_target`; do not pick an unsafe default.
- Logs, screenshots, layout dumps, and data snapshots must be bounded and redacted when persisted into evidence.
- When host layout, embedded runtime, and WebView provider sources coexist, preserve source boundaries, `confidence`, `missingSources`, and `candidateOnly` state.

## 2026-09 issue 合同补充

- `xcode test --jsonl` 默认 compact；完整 raw 日志在 artifact，显式 `--progress full` 才转发。按子命令 schema 选参数，`xcode run` 不接受 `--progress`。
- DerivedData 存在不证明 cache 命中。`reuseVerification=unknown`，`incrementalExpected=false` 仅表示没有验证过的预期；读取 `observedBuild.taskLogCounts/logCoverage`，不擅自称增量或全量。
- 排查 repo-local 构建缓存占用时先运行 `triton xcode derived-data inspect --root .triton/DerivedData --json`；cleanup 默认 dry-run，只有确认候选和预计释放量后才显式追加 `--confirm`。仅接受 canonical repo-local `.triton/DerivedData` 或用户全局 Xcode DerivedData root；Xcode 构建进行中不要清理。
- `debug attrs --oid` 支持 UIView/CALayer oid；UILabel 的有效字体/颜色与 UTF-16 run 有界输出，正文预览和 run 都要检查截断字段。
- collection cell 激活尊重 allowsSelection/delegate，success 只证明公开 callback，必须验证业务后置条件。`act tap --duration` 不支持长按，提前 typed unsupported；embedded longPress 和非滚动手势也不伪造成功，使用 App 显式注册的 semantic DEBUG action 或检查实际 provider 能力。
- Harmony ArkWeb bridge-call 需可达 DevTools socket 与页面 `window.__tritonBridge.methods` 自有函数白名单；函数接收 `(params, complete, reject)`，支持返回值/Promise/callback。明确选中 CDP page ID，stale/ambiguous 失败关闭；不把 CDP page ID 当导航 session 验证，清理失败也可能发生在页面方法已执行之后，重试前先验业务状态。

## Simulator resource profiles (simslim migration)

Use the Triton-first resource surface for iOS Simulator daemon overrides:
`triton sim resource profiles|features|status|doctor|plan|apply|verify|measure|restore --json`.
`apply` emits a receipt containing exact managed labels; retain it and pass it to `restore` for lossless rollback. `measure` reports `phys_footprint` for the target `launchd_sim` process tree and must be treated as invalid when `partial=true`.

## Device Hub 能力组（2026-10-10）

`device containers --device <selector> --bundle-id <id> [--group-id <id>] [--list] --json` 查询 SDK 显式 bundle/group membership 与容器路径绑定，默认只公开 tokens、状态和能力边界。`--list` 只对所选 Simulator 的受限原生容器做浅层元数据读取，逐级 nofollow/owner/预算检查，不读取业务内容。真实设备支持 SDK 元数据，不将其设备路径当作本机路径打开。旧 SDK 缺少参数明确 unsupported，缺绑定字段 unavailable；不能按 App 名/目录名猜归属，`deviceFSBindingVerified=false` 始终保留。

Crash 的三条契约独立：`device files --domain-type systemCrashLogs` 是 CoreDevice 浅元数据文件域；`device fs list --view diagnostic-reports` 只枚举 DeviceFS 明确的 `DiagnosticReports` namespace，缺目录就失败，不能猜 root 映射或宣称与文件域逐项等价；`device diagnose` 是敏感诊断 ZIP 采集，可能含宿主日志。均不得由目录存在推导额外权限。

Temporary 查询可能创建客户端域，实际是否新建没有可靠后置证据。默认继续返回 `device_file_domain_policy_required`；只有 `device files --domain-type temporary --domain-identifier <client-id> --allow-domain-creation --confirm --execute-runner --audit-record <id>` 才允许执行，执行前持久审计，`riskLevel=automation`、creation unknown，失败可能已经创建且不自动重试。本轮无真实 Temporary 查询。

`sim pairs --json` 读取原生 watch/phone 配对关系，不证明输入、连接或业务就绪。`device platforms --include-real-devices [--device <exact-id-or-inventory-token>] --json` 独立发现/选择 Apple physical 硬件元数据；只有 SDK 显式 physical 纳入，不从名称、transport 或 capability 数组推断，旧 iOS 路由不扩大。Crown/侧键、tvOS 焦点/选择/返回、visionOS 视角/场景/专门输入仍无已验证程序后端，明确未支持；macOS 仍区分 Xcode build/test 工作流与 Device Hub 控制。

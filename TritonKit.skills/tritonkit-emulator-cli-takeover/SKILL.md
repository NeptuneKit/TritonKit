---
name: tritonkit-emulator-cli-takeover
description: Use when designing, implementing, extending, or validating TritonKit local CLI takeover of iOS Simulator, Android Emulator, or HarmonyOS / DevEco Emulator capabilities. Covers local target discovery, app lifecycle, readiness, screenshots, optional App view highlighting and restoration, AX/layout, logs, command ledger, evidence, destructive-action policy, WebView-aware action routing, and deciding what belongs in `triton` CLI without adding Web, remote agents, real-device orchestration, or device-cloud services.
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

Fallback to raw `xcrun` / `simctl`, `hdc`, `adb`, DevEco Emulator CLI, XcodeBuildMCP, or raw `xcodebuild` only when Triton proves failure, unsupported scope/capability, or missing schema coverage. Keep the Triton command, error code or unsupported evidence, and fallback command in the report.

## Device Hub routing

Read [Device Hub contracts](references/device-hub-contracts.md) for Apple discovery, metadata, containers, Crash/Temporary, management execution, and specialized platform runners. Physical administration is outside this skill's default emulator scope; use [real-device acceptance](../tritonkit-real-project-regression/references/device-hub-acceptance.md) only when the current task explicitly authorizes the target and actions.

## Standard Workflow

1. Update the owning project’s technical design with BDD acceptance.
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

Android wait-ready combines adb state, `sys.boot_completed=1` and PackageManager availability. A package path during boot is insufficient. Inspect install results and app postconditions separately. A screenshot `android_screenshot_failed` caused by `/sdcard` or remote command failure is not a reason to reinstall adb.

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

Without `--platform`, the iOS coordinate-only form with `sim:<UDID>`, a raw Simulator UUID, `booted`, or `current` is a constrained host-HID path: it bypasses embedded target resolution so a stale/background runtime on the same Simulator cannot receive the action. Canonical `triton:ios-simulator:<UDID>` and `/app:<bundle-id>` selectors remain embedded-runtime targets. Treat host-HID success as submission-only and verify the business postcondition separately.

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

## Bounded observation and UI recovery

- Android UIAutomator exit zero can still mean a null-root failure. Each Triton dump uses a unique remote path, validates its acknowledgement and current XML, and cleans only that path. On `hierarchy_unavailable`, preserve failure and recapture; never continue coordinate actions using the previous tree.

- `observe tree --outline` aliases are valid for 30 seconds and `node resolve @N` validates a fresh whole-tree observation for the same target/platform. Refresh on stale, changed, or incomplete trees; an alias is not an executable OID. Inspect hierarchy `collection.visitedNodes` and `collection.limitReasons` (nonempty reasons mean incomplete collection): traversal deadlines cannot forcibly cancel native IPC already in progress.
- Use `observe ocr --image <path>` or `observe ocr --platform <platform> --device <selector> --json` explicitly for text candidates. Candidates have no OID/action reference; coordinates are top-left raw-raster pixels, with points only for a known explicit scale. File mtime does not prove screenshot freshness (`freshness=unknown`). `--policy structure-unavailable` requires `--structure-unavailable-reason`.
- `observe settle --device <selector> --json` reports visual stability with `businessVerified=false`. Workspace `--visual-settle` (HTTP `/workspace/run` optional `visualSettle`) is off by default; visual `unknown` or `timeout` stops the action chain. Continue with a business wait/assertion after a settled result.
- `debug ui-health --target <runtime-id> --json` uses the existing ping request: legacy SDK health is `unknown`; new SDK states are `ready|busy|timed_out|circuit_open`. Preserve action `outcome`/`uiHealth`. An action timeout with `outcome=unknown` may complete later: stop, probe health and re-observe read-only; never automatically replay or substitute a HID action.

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
- 默认不传 `--derived-data-path`，由 Xcode 使用用户级 DerivedData。该参数必须显式指定，只用于隔离或恢复，可能造成高磁盘占用，非必要不要开启。排查构建缓存用 `triton xcode derived-data inspect --json` 或 `cleanup --json` 预览；`.triton/DerivedData` 只能作为显式 legacy root。Triton 不提供 DerivedData 删除；通用自动删除需求已撤出范围。兼容参数 `--confirm` 在删除前返回 `derived_data_cleanup_unavailable`，活动 Xcode lane 保留 `xcode_not_idle`；等待空闲不会启用删除，不建议重试 confirm。若用户另行要求人工清理，先只读检查并明确该独立操作范围，不自动回退手工删除。统计为逻辑文件字节和修改时间，不是可回收磁盘量或最后使用时间；只接受精确 `.triton/DerivedData` 根或用户全局根，symlink 目标不跟随。
- `debug attrs --oid` 支持 UIView/CALayer oid；UILabel 的有效字体/颜色与 UTF-16 run 有界输出，正文预览和 run 都要检查截断字段。
- collection cell 激活尊重 allowsSelection/delegate，success 只证明公开 callback，必须验证业务后置条件。`act tap --duration` 不支持长按，提前 typed unsupported；embedded longPress 和非滚动手势也不伪造成功，使用 App 显式注册的 semantic DEBUG action 或检查实际 provider 能力。
- Harmony ArkWeb bridge-call 需可达 DevTools socket 与页面 `window.__tritonBridge.methods` 自有函数白名单；函数接收 `(params, complete, reject)`，支持返回值/Promise/callback。明确选中 CDP page ID，stale/ambiguous 失败关闭；不把 CDP page ID 当导航 session 验证，清理失败也可能发生在页面方法已执行之后，重试前先验业务状态。

## Simulator resource profiles (simslim migration)

Inspect the installed CLI's `triton schema --command sim.resource --json` and each selected subcommand before using `profiles`, `features`, `status`, `doctor`, `plan`, `apply`, `verify`, `measure`, or `restore`; choose only supported output options. These development contracts do not establish support in an older release.

The catalog is pinned to simslim commit `6518ba7eab1123d7e1d7797b0e05f51043b42a5b`. Plan/apply/verify use the same managed-label resolution: `com.apple.sharingd`, `com.apple.assistantd`, and `com.apple.gamed` remain enabled, keeping widgets also keeps their `com.apple.navd` dependency, and unknown daemon overrides remain untouched. Verify the exact managed disabled set, including extra disables of protected or retained services.

Retain the apply receipt and use it for target-bound, conservative delta restore. Restore changes only known managed labels whose current state still matches the recorded applied state; it preserves detected intervening overrides and never re-disables protected services. Legacy receipts without managed-label sets restore no inferred delta. This is not a lossless history of later user edits, including edits that reassert the same value. `measure` reports `phys_footprint` for the target `launchd_sim` process tree and is invalid when `partial=true`.

## Resize, preferences, and capture acceptance

Query the installed schema before selecting these capabilities; preserve unsupported/error facts when the installed release does not cover them.

- Resize state must come from a fresh, target-bound selected-Xcode query for each complete action. Active or unknown state rejects host touch and AX activation with the current adapters; never bypass the guard or treat an unsupported query as inactive. A confirmed fresh, target-bound Resizable display supports video routing; unknown state rejects recording. Active screenshots use the current boot's display UUID; unknown state refuses capture. Do not persist that UUID or infer HID support from screenshot capability; recording must independently validate its own display identity.
- `app prefs get` uses `present` to distinguish missing from `false`, `0`, or empty values. `app prefs import --input <file> --input-format json|plist --key <key> [--key <key> ...]` requires an explicit key allowlist and validates the entire input dictionary before writing; invalid unselected entries also reject the import. Only the bundle's app-data preferences plist is covered, not AppGroup or suite domains.
- Preferences set/import defaults to no relaunch. Optional `--relaunch` performs terminate then launch after verified disk writing; a relaunch failure can return `ok:false` with `diskWriteVerified:true`. Even a successful launch leaves `runtimeConsumptionVerified:false`: verify the App's business state separately before claiming it consumed the preferences. Import receipts describe keys/types without echoing imported values.
- Proxy capture export/evidence requires a complete validated capture: empty, malformed, unknown-schema, partial-line, over-limit, or `.incomplete`-marked sources fail closed without publishing a prefix as complete. Inspect counts, redaction, and `truncation`; `not-observed` proves no observed requests and `partial-source` preserves the limitation of mixed legacy placeholder input. URL userinfo/query/fragment removal and names-only headers do not make URL paths or target identities safe for public sharing.

## Offline Simulator swipe (#215)

`triton sim swipe --simulator booted --start-x 360 --start-y 700 --end-x 80 --end-y 700 --duration 0.35 --json` 通过TritonKit 内置 SimulatorKit/IOHID 适配器执行，不依赖 embedded server 或 Web 服务。默认坐标为 Simulator points；可成对传 `--width/--height` 表示源图坐标空间。duration 为有限正数且最多 10 秒。成功只证明 host submission，必须用同目标 `triton sim ax --device <udid> --json` / `triton sim screenshot` 检查 settled 后置条件。后端不可用时失败关闭，不自动落回 embedded runtime。

## Optional independent view highlight

Implemented in the source tree: optional Debug UIKit border highlighting and conditional restoration. Use [view-highlight.md](references/view-highlight.md) for `highlight capabilities/apply/status/clear`. Ordinary screenshots retain their existing access requirements; no built-in SDK is mandatory. First provider is Debug UIKit. Capture and restoration are separate facts; preserve recovery IDs and verify clear receipts. Automatic screenshot composition and cross-platform providers remain future slices.

## Device Hub host input authority

Discover `triton schema --command act.tap --json` on the actual CLI before using `--hid-only`. Explicit `--platform ios` defaults to AX activation, including coordinates: `source=host-ax`, `strategy=accessibility-perform-press`, `verification.required=true`. For a touch-path regression use `triton act tap --platform ios --device sim:<UDID> --at 120,240 --hid-only --json`; only local Simulator coordinates are accepted, with no semantic/embedded/WebView fallback. Without `--platform`, existing explicit Simulator coordinate selectors retain host HID routing.

Tap and `triton sim swipe` use the native digitizer bundled in triton, without an external Baguette executable or chrome lookup. Device Hub guest HID ownership returns `ios_host_hid_device_hub_attached`; unknown ownership and unsupported display topology fail closed. No automatic SpringBoard restart or heal occurs. Follow the selected-device doctor next step; `hidCompatibility.hostChromeLayout` is bundle presence only and `chromeLookupVerified=false`. Framework compatibility, booted state, AX activation, screenshots and ACKs do not prove HID delivery. Do not attribute an external native CUA drag/scroll failure to Triton. No verified host multi-tap/long-press primitive is supplied here; `act tap --duration` stays unsupported. App-owned semantic actions can check business state but cannot replace physical-touch regression proof. Report that boundary and preserve the typed error instead of claiming Device Hub HID support.

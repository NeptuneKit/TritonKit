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

## Bounded observation and UI recovery

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
- 默认不传 `--derived-data-path`，由 Xcode 使用用户级 DerivedData。该参数必须显式指定，只用于隔离或恢复，可能造成高磁盘占用，非必要不要开启。排查构建缓存先用 `triton xcode derived-data inspect --json` 或 `cleanup --json` 预览；`.triton/DerivedData` 只能作为显式 legacy root，若 guidance 报告其占用过大，先询问用户是否清理，再执行任何删除。`--confirm` 当前在删除前返回 `derived_data_cleanup_unavailable`；活动 Xcode lane 返回 `xcode_not_idle`。不要自动回退手工删除。统计为逻辑文件字节和修改时间，不是可回收磁盘量或最后使用时间；只接受精确 `.triton/DerivedData` 根或用户全局根，symlink 目标不跟随。#214 的独占缓存/竞态删除协议尚未收口。
- `debug attrs --oid` 支持 UIView/CALayer oid；UILabel 的有效字体/颜色与 UTF-16 run 有界输出，正文预览和 run 都要检查截断字段。
- collection cell 激活尊重 allowsSelection/delegate，success 只证明公开 callback，必须验证业务后置条件。`act tap --duration` 不支持长按，提前 typed unsupported；embedded longPress 和非滚动手势也不伪造成功，使用 App 显式注册的 semantic DEBUG action 或检查实际 provider 能力。
- Harmony ArkWeb bridge-call 需可达 DevTools socket 与页面 `window.__tritonBridge.methods` 自有函数白名单；函数接收 `(params, complete, reject)`，支持返回值/Promise/callback。明确选中 CDP page ID，stale/ambiguous 失败关闭；不把 CDP page ID 当导航 session 验证，清理失败也可能发生在页面方法已执行之后，重试前先验业务状态。

## Simulator resource profiles (simslim migration)

Use the Triton-first resource surface for iOS Simulator daemon overrides:
`triton sim resource profiles|features|status|doctor|plan|apply|verify|measure|restore --json`.
`apply` emits a receipt containing exact managed labels; retain it and pass it to `restore` for lossless rollback. `measure` reports `phys_footprint` for the target `launchd_sim` process tree and must be treated as invalid when `partial=true`.

## Offline Simulator swipe (#215)

`triton sim swipe --simulator booted --start-x 360 --start-y 700 --end-x 80 --end-y 700 --duration 0.35 --json` 通过现有 Baguette host HID 适配器执行，不依赖 embedded server 或 Web 服务。默认坐标为 Simulator points；可成对传 `--width/--height` 表示源图坐标空间。duration 为有限正数且最多 10 秒。成功只证明 host submission，必须用同目标 `triton sim ax --device <udid> --json` / `triton sim screenshot` 检查 settled 后置条件。后端不可用时失败关闭，不自动落回 embedded runtime。

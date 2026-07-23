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
triton act swipe --target <ios-runtime-target-from-triton-list> --start-x 110 --start-y 700 --end-x 110 --end-y 140 --duration 0.6 --json
triton act tap --webview-aware --selector "#submit" --webview-id <webview-id> --page-session-id <page-session-id> --expect-text "成功" --json
triton wait text "成功" --platform <ios|android|harmony> --device <selector> --json
```

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

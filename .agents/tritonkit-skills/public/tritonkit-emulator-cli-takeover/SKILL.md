---
name: tritonkit-emulator-cli-takeover
description: Use when designing, implementing, extending, or validating TritonKit local CLI takeover of iOS Simulator, Android Emulator, or HarmonyOS / DevEco Emulator capabilities. Covers single-machine emulator target discovery, app lifecycle, readiness, screenshots, AX/layout, logs, command ledger, evidence, destructive-action policy, and deciding what belongs in `triton` CLI without adding Web, remote agents, real-device orchestration, or device-cloud services.
metadata:
  version: 0.1.0-dev
---

# TritonKit Emulator CLI Takeover

## Principle

TritonKit's emulator takeover surface is **local CLI + local simulator/emulator**.

The product boundary is:

- Include: iOS Simulator, Android Emulator, HarmonyOS / DevEco Emulator, DEBUG-only embedded runtime, local `.tritonevidence`, `.tritonplan`, `.tritoncase`, and `.tritonbatch`.
- Exclude by default: physical devices, remote agents, device cloud, Web / Wails UI, public HTTP product APIs, Postgres, Kafka, Webhook, multi-tenant operations, and built-in VLM loops.

The `triton` CLI is the stable interface for AI agents. Platform tools such as `xcrun simctl`, `adb`, `emu`, `hdc`, `aa`, `bm`, `uitest`, and `hilog` are implementation details behind JSON / JSONL contracts.

## Reference Docs

Start from the current space and technical design:

- `docs-linhay/spaces/20260521-ai-phone-emulator-cli/README.md`
- `docs-linhay/spaces/20260521-ai-phone-emulator-cli/technical-design.md`
- `docs-linhay/dev/ai-cli-readable-control.md`
- `docs-linhay/references/ai-phone.md`

For platform-specific slices, also check:

- iOS Simulator: `docs-linhay/spaces/20260520-simulator-takeover/README.md`
- Harmony Emulator: `docs-linhay/spaces/20260520-harmony-emulator-alignment/README.md`
- Evidence UX runs: `docs-linhay/spaces/20260521-harness-ux-run-evidence/README.md`

## CLI Admission Rules

Put a capability into `triton` CLI when an agent needs it to prepare, observe, execute, verify, replay, or archive a local emulator regression with machine-readable output.

Default in-scope CLI domains:

- `schema`, `doctor`, `capabilities`, and `plan`;
- `device list/use/wait-ready --platform ios|android|harmony`;
- iOS `sim list/use/boot/shutdown/screenshot/status-bar/privacy/location/ui/pasteboard/push`;
- app lifecycle: `list/info/install/uninstall/launch/terminate/open-url`;
- app data: containers, preferences, safe data reset/snapshot when policy is explicit;
- UI artifacts: screenshot, AX/layout tree, bounded logs;
- hybrid observation: host-side emulator layout/screenshot/frontmost-app evidence fused with DEBUG-only embedded runtime snapshots when available;
- runtime actions: `find/tap/swipe/type/paste/clear/wait/assert`;
- replay and evidence: `.tritonplan`, `.tritonevidence`, command ledger, case lint, local batch.

Do not add Web / Wails UI, remote orchestration, real-device flows, or central services to satisfy this domain. If the requirement truly needs those, create a new space and reset the product boundary first.

## Integration Guide Contract

When changing iOS / Harmony / CLI onboarding or usage guides, keep these entry points aligned:

- `README.md` must split iOS embedded runtime, Harmony host-side adapter, Harmony embedded SDK, and CLI install/run guidance.
- `tritonkit-dev-feedback` must be able to guide external users through iOS, Harmony, or CLI adoption before filing feedback.
- `tritonkit-real-project-regression` must treat iOS and Harmony apps as external systems under test, using host-side checks when embedded runtime is not required.
- Harmony docs must state that host-side HDC / DevEco Emulator control does not require embedded SDK integration.
- Harmony embedded SDK docs must state package id/import path `tritonkit`, Debug-only runtime, Release disabled/no-op behavior, provider-owned business semantics, and `--runtime-base-url` direct checks while standalone.
- CLI docs must keep Homebrew as the released install path and local `swift build --package-path CLI --scratch-path .build/cli -c release --product triton` as the unreleased-source fallback.

## Current Implemented Surface

iOS Simulator:

```bash
triton sim list --json
triton sim use <udid> --json
triton sim boot <udid> --wait --jsonl
triton sim shutdown <udid-or-booted> --json
triton sim screenshot --simulator <udid-or-booted> --output /tmp/<case>-sim.png --json
triton sim record --simulator <udid-or-booted> --output /tmp/<case>-sim.mov --duration 10 --json
triton sim logs --simulator <udid-or-booted> --output /tmp/<case>-sim.ndjson --duration 5 --json
triton sim status-bar list --simulator booted --json
triton sim privacy grant location com.example.app --simulator booted --json
triton sim location set 37.7749,-122.4194 --simulator booted --json
triton sim ui appearance dark --simulator booted --json
triton sim diagnose --output /tmp/sim-diagnostics --json
triton sim logverbose booted enable --json
triton sim runtime list --json
triton sim pasteboard set "hello" --simulator booted --json
triton sim push --bundle-id com.example.app --payload /tmp/push.json --simulator booted --json

triton app list --simulator <udid-or-booted> --user-only --json
triton app info --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app install --app <path.app> --simulator <udid-or-booted> --json
triton app uninstall --bundle-id <bundle-id> --simulator <udid-or-booted> --confirm --json
triton app launch --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app terminate --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app open-url '<url>' --simulator <udid-or-booted> --json
triton app open-url '<url>' --simulator <udid-or-booted> --wait-ready --snapshot --json
triton app container --bundle-id <bundle-id> --kind data --simulator <udid-or-booted> --json
triton app prefs get <key> --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app prefs dump --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app prefs set <key> <json-value> --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton smoke ios --simulator <udid-or-booted> --bundle-id <bundle-id> --open-url '<url>' --wait-text '<text>' --screenshot /tmp/<case>.png --evidence /tmp/<case>.tritonevidence --json
```

HarmonyOS / DevEco Emulator:

```bash
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device use --platform harmony --target <hdc-target> --json
triton device wait-ready --platform harmony --target <hdc-target> --json
triton app inspect --platform harmony --bundle <bundle> --json
triton app launch --platform harmony --bundle <bundle> --ability <ability> --json
triton smoke harmony --target <hdc-target> --bundle <bundle> --ability <ability> --open-url '<url>' --wait-text '<text>' --screenshot /tmp/<case>.jpeg --evidence /tmp/<case>.tritonevidence --json
triton observe current --platform harmony --target <hdc-target> --json
triton observe tree --platform harmony --target <hdc-target> --json
triton node resolve --platform harmony --target <hdc-target> --text "登录" --json
```

Standalone Harmony embedded HTTP runtime:

```bash
triton device runtime-url --platform harmony --target <hdc-target> --probe-manifest --json
triton runtime manifest --runtime-base-url http://127.0.0.1:28767 --json
triton state route --runtime-base-url http://127.0.0.1:28767 --json
triton snapshot --runtime-base-url http://127.0.0.1:28767 --json
triton ledger --runtime-base-url http://127.0.0.1:28767 --jsonl
triton set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:28767 --json
```

iOS embedded runtime observation:

```bash
triton list --json
triton ax --target triton:ios-simulator:<SIMULATOR_UDID> --json
triton tap "登录" --target <SIMULATOR_UDID> --json
triton observe current --platform ios --json
triton observe tree --platform ios --runtime-base-url <baseURL> --json
triton node resolve --platform ios --text "登录" --json
triton webview list --platform ios --json
triton webview current --platform ios --json
triton webview current-url --platform ios --json
triton route assert-current-url https://example.invalid/path --platform ios --json
triton webview call <method> --platform ios --json
triton webview events --platform ios --limit 50 --json
triton evidence summary /tmp/<case>.tritonevidence --json
triton evidence redact /tmp/<case>.tritonevidence --profile ios-private --output /tmp/<case>-redacted.tritonevidence --json
```

`webview list/current/current-url` 当前是 provider metadata 能力。iOS 已能从当前可见 `WKWebView` 读取 `url/title/pageSessionID/isLoading/estimatedProgress/frame` 等元数据；`route assert-current-url` 只断言 provider URL，不操作 H5 页面。真正的 DOM、页面事件和业务动作仍必须通过页面或 App 显式 opt-in 的 allowlist bridge 暴露。`webview call` 只能调用 allowlist 方法，不是任意 JavaScript eval。没有 WebView provider 时，输出必须保持 `candidateOnly=true`、`providerStatus=unavailable`、`bridgeStatus=unavailable`，并在 `missingCapabilities` 中声明 `webview.url`、`webview.dom`、`webview.bridge-call`、`webview.tap`、`webview.type` 等缺失项；不得把 AX/WebKit 容器误报为 DOM/JS/bridge 可用。Harmony 侧若未注册 WebView provider，也只能保持 host-only layout/candidate 边界，不能声明页面 bridge 可用。

When multiple iOS Simulator apps connect to the same `triton serve`, embedded runtime targets use stable ids shaped as `triton:ios-simulator:<SIMULATOR_UDID>`. Runtime commands may pass either the full target id or the simulator UDID. If more than one runtime target is connected and the command still uses the default `triton:local`, the expected result is `error.code=ambiguous_target`, not last-connection wins.

For the Harmony demo, `28767` is the host-access embedded runtime port exposed through HDC `fport`; `18765` is the device-to-host gateway fallback port.

When debugging Harmony direct runtime defaults, verify against a real HDC target before changing CLI defaults:

```bash
TRITON_BIN=.build/cli-scratch/debug/triton docs-linhay/scripts/verify-harmony-runtime-emulator-smoke.sh --target <hdc-target> --no-forward
```

Use `--no-forward` when the HDC fport already exists, because repeating `hdc fport tcp:28767 tcp:28767` can fail with a host listen conflict even though the existing forwarded endpoint is healthy. Keep mock contract smoke separate from real emulator smoke: the mock script should use an isolated test port while asserting the schema/default output remains `28767`.

Android Emulator is an accepted product direction but should be added as a later adapter slice. Keep DTOs and command ledger schemas platform-neutral now, but do not claim Android commands are implemented until `schema --command app --json` exposes them.

## Safety Rules

- Destructive or state-changing host actions must require explicit flags or policy. Current example: `app uninstall` requires `--confirm` and otherwise returns `destructive_action_requires_policy`.
- Host command success is not business success. After `launch`, `open-url`, `install`, or `uninstall`, verify with `wait`, `find`, `assert`, screenshot, app prefs, layout/AX, or evidence.
- Multiple local targets must return `ambiguous_target` instead of picking an unsafe default.
- Every host action should preserve source command, target, elapsed time, risk/policy metadata when available, and next verification advice.
- Logs, screenshots, layout dumps, and data snapshots must be bounded and redacted when persisted into evidence.
- When a platform has both host-side and embedded runtime observation, keep source boundaries visible. Host layout can prove current visible nodes and coordinates; embedded runtime can prove App-private route, responder, semantic action, WebView controller, and bridge state; WebView/page bridge can prove DOM/JS/page events. Fusion may produce stable `fusedNodeId` values, but must preserve `sources`, `confidence`, `missingSources`, and `candidateOnly` when Web/runtime semantics are absent.

## Implementation Workflow

1. Update the relevant `space` README or technical design with BDD acceptance before code changes.
2. Add or update model/parser tests first:
   - iOS simctl argv and parser behavior;
   - Harmony hdc / aa / bm parser behavior;
   - Android adb parser behavior when that adapter lands;
   - error envelopes and destructive policy failures.
3. Implement shared contracts before CLI glue when a DTO or source-command shape is reusable.
4. Expose the CLI in a focused file under `Sources/TritonKitCLI/`, keeping JSON / JSONL as the agent-facing default.
5. Update `commandSchemas()` for every agent-facing command.
6. Sync docs and skills:
   - `README.md`;
   - `docs-linhay/dev/ai-cli-readable-control.md`;
   - current emulator takeover space;
   - `tritonkit-real-project-regression`;
   - `tritonkit-dev-feedback`;
   - memory entry.
7. If a new user-facing skill is added, include it in CI/release asset packaging and version stamping.

## Validation

Minimum local validation:

```bash
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command device --json
.build/cli/debug/triton schema --command app --json
.build/cli/debug/triton schema --command smoke --json
.build/cli/debug/triton schema --command evidence --json
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-host-smoke.sh
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/qmd-sync.sh
```

Run real emulator smoke only when safe for the current machine:

```bash
.build/cli/debug/triton sim list --json
.build/cli/debug/triton sim status-bar list --simulator booted --json
.build/cli/debug/triton app uninstall --bundle-id com.example.missing --simulator booted --json
.build/cli/debug/triton app launch --bundle-id com.example.missing --simulator booted --json
.build/cli/debug/triton device list --platform harmony --json
.build/cli/debug/triton device wait-ready --platform harmony --target <hdc-target> --json
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-runtime-base-url-smoke.sh
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-runtime-emulator-smoke.sh --target <hdc-target> --no-forward
```

Avoid erasing emulators, uninstalling business apps, installing data bundles, changing privacy/location, or collecting broad logs unless the current task explicitly requires it and the command records policy metadata.

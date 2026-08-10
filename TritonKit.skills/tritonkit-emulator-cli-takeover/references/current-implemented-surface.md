## Current Implemented Surface

Cross-platform host device entry:

```bash
triton device doctor --platform ios --json
triton device doctor --platform android --json
triton device doctor --platform harmony --json
triton device list --platform ios --json
triton device list --platform android --json
triton device list --platform harmony --json
triton device alias set iphone15 --platform ios --target <simulator-udid> --json
triton device alias set android-a --platform android --target <adb-serial> --json
triton device alias set harmony-a --platform harmony --target <hdc-target> --json
triton device use iphone15 --json
triton device current --json
triton device resolve iphone15 --json
triton device wait-ready --device iphone15 --json
triton device wait-ready --device android-a --json
triton device wait-ready --device harmony-a --json
triton device screenshot --device iphone15 --output /tmp/<case>-sim.png --json
triton device screenshot --device android-a --output /tmp/<case>.png --json
triton device screenshot --device harmony-a --output /tmp/<case>.jpeg --json
triton device start --platform android --avd Dxyer_API_34 --headless --gpu swiftshader_indirect --plan-only --json
triton device stop --platform android --device android-a --confirm --json
triton device stop --platform harmony --hvd "Codex Test Phone" --path ~/.Huawei/Emulator/deployed --confirm --json
```

Use `--device <selector>` as the default agent-facing target selector for common host-side commands. Selectors can be aliases, full ids such as `sim:<udid>` / `android:<serial>` / `harmony:<target>`, raw platform ids, `booted`, or `current`. `--platform`, `--name`, `--runtime`, `--state`, and `--ready` are filters; they may auto-select only when the filtered candidate set is unique. Keep `sim` for iOS-only advanced maintenance; `device runtime-url --device <selector>` is the Harmony embedded runtime port-forward setup path, and `--platform harmony --target <target>` remains the direct raw-target form.

For agent navigation across iOS Simulator host AX, Android bridge/layout, Harmony host layout, or embedded runtime trees, prefer a fresh outline before selecting numbered nodes:

```bash
triton observe tree --platform <ios|android|harmony> --device <selector> --outline --json
triton node resolve @1 --platform <ios|android|harmony> --device <selector> --json
```

`@N` aliases are repo-local snapshots written to `.triton/node-aliases.json`, not a daemon session. If `node resolve @N` returns `stale_node_alias`, run the `nextAction` refresh command instead of guessing from the old cache.

For a local agent Run that needs app launch plus the first observation as Atlas seed, use `triton workspace run --target <selector> --platform <ios|android|harmony> --scope <simulator|emulator|real> --resolve-target --app <app> --goal "<goal>" --app-mode launch --bundle-id <ios-bundle-id> --observe-live --observe-kind tree --json` for iOS, or the matching Android `--package-name/--activity` / Harmony `--bundle/--ability` options. `--resolve-target` / HTTP `resolveTarget=true` resolves `current`, `booted`, and workspace aliases through host target discovery, writes the stable host target id plus `selector`, raw `hostTarget`, readiness metadata, and `sourceCommands` to `evidence/model/target.json`, and then uses the resolved raw target for app lifecycle, live observe, action, and wait/assert. Keep default dry / fixture runs unresolved unless the run should touch host discovery. Preserve custom `--adb` / `--hdc` on workspace commands so Android/Harmony target sourceCommands remain reproducible. This writes `evidence/actions/app-ready.json`; launch-only evidence uses `phase=launch_submitted`, while successful live observation in the same run upgrades it to `phase=launch_observed`, `ready=true`, `observedAfterLifecycle=true`, and `observationRef=events.jsonl#observation.captured`. It also saves initial raw `ObserveOutput` to `evidence/observations/0000.json` and derives `observation.captured` / initial Atlas screen from it. Without `--app-mode launch`, workspace run stays in dry app lifecycle mode. Even with `launch_observed`, do not claim business completion without later wait/assert/action/verification events. The built-in workspace business checkpoint is `--business-ready-text <text>` / HTTP `businessReadyText`; by default it exact-matches the initial observation visible text, writes `evidence/business/ready.json`, emits `business.ready` plus passed `verify.checked`, and only then can `workspace run` return `run.status=passed` for that checkpoint. When the initial frame is insufficient, add `--business-ready-live-wait` / HTTP `businessReadyLiveWait=true`; Triton calls runtime wait(text), records `check=runtime_wait`, `source=runtime.wait`, timeout/interval and nested wait evidence, and only returns passed when wait `ok=true`. When the flow needs verify semantics instead of waiting, add `--business-ready-assert` / HTTP `businessReadyAssert=true`; Triton calls runtime verify text-exists through the assertion provider, records `check=runtime_assert`, `source=runtime.assert`, `phase=assertion_passed|assertion_failed`, and nested assertion evidence.

When the model-selected candidate should actually mutate the app, add `--execute-actions` / HTTP `executeActions=true` after confirming provider and policy readiness. Workspace model decision requests include the goal, runner bounds, provider status, and current observation visibleTexts. For a real local LLM decision provider, use `--llm-provider openai-compatible --llm-base-url http://127.0.0.1:<port>/v1 --llm-model <model>`; for OpenAI-compatible VLM provider readiness and evidence metadata, use `--vlm-provider openai-compatible --vlm-base-url http://127.0.0.1:<port>/v1 --vlm-model <model>`; for local `mlx-swift-lm` VLM, use `--vlm-provider mlx-swift-lm --vlm-model <id>` or `--vlm-model-path <path>` with optional `--vlm-helper <helper>` and `--vlm-allow-model-download`. HTTP fields are `llmProvider`, `llmBaseURL`, `llmModel`, `llmAPIKeyEnv`, `allowRemoteLLM`, `vlmProvider`, `vlmBaseURL`, `vlmModel`, `vlmModelPath`, `vlmHelper`, `vlmAllowModelDownload`, `vlmAPIKeyEnv`, and `allowRemoteVLM`. Remote LLM/VLM endpoints are rejected unless `--allow-remote-llm` / `allowRemoteLLM=true` or `--allow-remote-vlm` / `allowRemoteVLM=true` is explicit, because workspace evidence or screenshots may be sent to that endpoint. If a model decision provider returns an action/query/confidence/candidateSource, Triton uses that provider output for runtime action execution, events, model evidence, Atlas transition, and exported flow. The default provider derives one bounded step candidate from visibleTexts, preferring `Continue`, `Start`, `Get Started`, `Next`, `Login`, `Log In`, and `Sign In`, then the first visible text, and falling back to `Continue` when no visible text exists. If VLM provider readiness is true and the selected observation has a readable local screenshot artifact, Triton writes a run-local coordinate contract, calls VLM grounding before the tap, writes step-indexed `evidence/actions/vlm-000/vlm-grounding.json` / `vlm-001/vlm-grounding.json` plus overlay/request/response artifacts, and executes the grounded runtime point. The action evidence then includes `usedVLMGrounding=true`, `proofSource=vlm.grounding+runtime.input`, and `vlmGrounding` refs. If VLM grounding fails before runtime action execution, Triton writes `evidence/actions/vlm-<step>/vlm-failure.json`, records failed action evidence with `failureKind=vlm_grounding_failed`, `proofSource=vlm.grounding`, and `usedVLMGrounding=false`, writes a workspace recovery proposal, and pauses with `inspect_vlm_grounding_failure`; when no readable screenshot exists, Triton does not claim VLM grounding and keeps the bounded runtime selector path with `proofSource=runtime.input`. Triton writes step-indexed `evidence/actions/action-000.json`, `evidence/model/decision-000.json`, and `evidence/model/verify-000.json`, emits `action.executed` with the action evidence ref, and marks the Atlas transition `executed_unverified` when no later verification is attached. If the same run also uses `--observe-live`, Triton observes again after a successful action, writes post-action raw `ObserveOutput` to `evidence/observations/0001.json`, emits `observation.captured` with `phase=post_action`, adds Atlas `screen_0001/state_0001`, and records the transition as `screen_0000 -> screen_0001`. If the same run also uses `--business-ready-text <text> --business-ready-live-wait` / HTTP `businessReadyLiveWait=true`, Triton runs wait(text) after the action; a matched wait writes `evidence/business/ready.json` with `stage=post_action` and `phase=post_action_wait_matched`, emits `business.ready` plus passed `verify.checked`, returns `run.status=passed`, and marks the Atlas transition `verified`. If the same run uses `--business-ready-text <text> --business-ready-assert` / HTTP `businessReadyAssert=true`, Triton runs runtime verify text-exists after the action; a passed assertion writes the same artifact with `stage=post_action`, `check=runtime_assert`, and `phase=post_action_assertion_passed`, then marks the Atlas transition `verified`. If that post-action checkpoint fails and `--observe-live --max-steps <N>` keeps budget available, Triton continues a bounded recovery loop: the next model request uses the latest post-action observation, writes `decision-001/action-001/verify-001`, appends `transition_0001`, and stops when the checkpoint passes, policy rejects, an action fails, observation is unavailable, or maxSteps is reached. The same Atlas chain is projected into `atlas/app-map/` with app-map screens, transitions, candidate paths, run record, and `workspace inspect.appMap` summary; use `triton workspace merge-map <run-id> --map-dir <dir.tritonmap> --json` or `POST /workspace/runs/:runId/merge-map` with `mapDir` to accumulate those run-local maps into a long-lived local map with merged `sourceRuns` and path health. If the initial business checkpoint already passed, workspace run skips the candidate action.

For recovery consumption, read `evidence/model/recovery-<step>.json` before inferring from prose. Its schema is `kind=triton.workspace.recovery-proposal` and includes `failureCode`, `trigger`, `diagnosis.type/phase/confidence/evidenceRefs`, `proposal.action/policyDecision/command`, top-level `evidenceRefs`, and `nextActions[]`. A post-action business checkpoint failure with remaining runner budget proposes `action=continue`, `policyDecision=allowed`, and `usesLatestObservation=true`; policy rejection and unverified action failures propose `stop` plus review next actions; VLM grounding failures propose `stop` with `policyDecision=requires_review` and `inspect_vlm_grounding_failure`.

Long-lived workspace app-map merges preserve run-local Atlas states as screen `stateVariants` and expose `coverage` in `app-map.json`, `triton map inspect`, `triton workspace merge-map`, and HTTP merge-map responses. Use that coverage summary to inspect observed run, screen, state, transition, path, suite, confirmed path, replayable path, pass, fail, and flake counts across sessions. Use `triton map health --map <dir.tritonmap> --json` or HTTP `GET /v1/app-map/health?map=<dir.tritonmap>` when deciding whether an app-map is ready for replay: the response includes `stateHealth[]`, `transitionHealth[]`, `unhealthyStateRefs`, `unhealthyTransitionIds`, transition `coveredByPathIds`, `coveredBySuite`, `replayable`, and stable `issueCodes` such as `uncovered_by_suite`.

For Harmony target discovery, expect HDC output shape drift. `triton device list --platform harmony --json` should parse `hdc list targets -v` stdout and stderr, fallback to plain `hdc list targets` when verbose output has no target rows, and treat single-column plain targets such as `127.0.0.1:5555` as connected DevEco emulator candidates. Do not parse prose errors such as `Connect server failed` as targets.

For Harmony host discovery, parse optional foreground app identity from `triton device list --platform harmony --json` when present. Treat `identityState=current` with `current=true` as the only current foreground identity. Treat `identityState=unknown` or `identityState=unsupported` as an explicit no-identity boundary; do not substitute the HDC target id, emulator name, or selected alias as `appName` / `bundleIdentifier`.

When a Harmony HVD was started through Triton's `triton-harmony-emulator` launchd keepalive job, stop it through `triton device stop --platform harmony ... --confirm --json`. The command checks and unloads `gui/<uid>/triton-harmony-emulator` before running DevEco `Emulator -stop`, which prevents launchd from immediately restarting the emulator.

iOS Simulator:

```bash
triton sim list --json
triton sim use <udid> --json
triton sim boot <udid> --wait --jsonl
triton sim shutdown <udid-or-booted> --json
triton sim screenshot --simulator <udid-or-booted> --output /tmp/<case>-sim.png --json
triton sim record --simulator <udid-or-booted> --output /tmp/<case>-sim.mov --duration 10 --json
triton sim logs --simulator <udid-or-booted> --output /tmp/<case>-sim.ndjson --duration 5 --json
triton sim app-console --simulator <udid-or-booted> --bundle-id <bundle-id> --output /tmp/<case>-app-console.log --duration 5 --max-bytes 10485760 --json
triton sim status-bar list --simulator booted --json
triton sim privacy grant location com.example.app --simulator booted --json
triton sim location set 37.7749,-122.4194 --simulator booted --json
triton sim ui appearance dark --simulator booted --json
triton sim diagnose --output /tmp/sim-diagnostics --json
triton sim logverbose booted enable --json
triton sim runtime list --json
triton sim pasteboard set "hello" --simulator booted --json
triton sim push --bundle-id com.example.app --payload /tmp/push.json --simulator booted --json
triton sim pair <watch-udid> <phone-udid> --json
triton sim unpair <pair-uuid> --json
triton sim clone <udid> "Clone for Smoke" --json
triton sim erase <udid> --confirm --json
triton sim upgrade <udid> <runtime-id> --json
triton sim runtime verify <runtime-id> --json
triton sim runtime add /tmp/iOSSimulatorRuntime.dmg --json
triton sim runtime delete all --dry-run --json
triton sim runtime delete <runtime-id> --confirm --json
triton sim runtime unmount <runtime-id> --json
triton sim runtime scan-and-mount --json
triton sim runtime match list --json
triton sim runtime match set iphoneos26.5 23F77 --json
triton sim runtime match set iphoneos26.5 --default --json
triton sim runtime dyld-cache update <runtime-id> --json
triton sim runtime dyld-cache remove <runtime-id> --confirm --json
triton sim personalization personalize <runtime-id> --json
triton sim personalization remove-manifest manifest.plist --confirm --json
triton sim personalization remove-all-manifests --confirm --json
triton sim personalization remove-personalization <id> --confirm --json
triton sim personalization revoke-manifests --confirm --json
triton sim personalization scan-and-personalize --json

triton app list --device iphone15 --user-only --json
triton app info --device iphone15 --bundle-id <bundle-id> --json
triton app install --device iphone15 --app <path.app> --json
triton app uninstall --device iphone15 --bundle-id <bundle-id> --confirm --json
triton app launch --device iphone15 --bundle-id <bundle-id> --json
triton app terminate --device iphone15 --bundle-id <bundle-id> --json
triton app open-url '<url>' --device iphone15 --json
triton app open-url '<url>' --device iphone15 --wait-ready --snapshot --json
triton app container --device iphone15 --bundle-id <bundle-id> --kind data --json
triton app prefs get <key> --device iphone15 --bundle-id <bundle-id> --json
triton app prefs dump --device iphone15 --bundle-id <bundle-id> --json
triton app prefs set <key> <json-value> --device iphone15 --bundle-id <bundle-id> --json
triton app prefs set <key> --type data --base64 <base64> --device iphone15 --bundle-id <bundle-id> --json
triton app prefs set <key> --type data --hex <hex> --device iphone15 --bundle-id <bundle-id> --json
triton smoke ios --device iphone15 --bundle-id <bundle-id> --open-url '<url>' --wait-text '<text>' --screenshot /tmp/<case>.png --evidence /tmp/<case>.tritonevidence --json
```

Treat the two log paths as separate fact sources. `sim logs` returns `sourceType=unified-log` and `sourcesCaptured=[unified-log]`; it does not capture App process stdout/stderr. `sim app-console` performs an App metadata preflight, terminates/relaunches the selected bundle through `console-pty`, and returns `sourcesCaptured=[process-stdout,process-stderr]` with `streamLayout=merged-pty`. Its artifact is sensitive, bounded by `--duration` and `--max-bytes`, and never inlined in JSON. Environment values in `--env KEY=VALUE` must be redacted from source commands.

HarmonyOS / DevEco Emulator:

```bash
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device use harmony-a --json
triton device wait-ready --device harmony-a --json
triton app inspect --platform harmony --bundle <bundle> --json
triton app install --device harmony-a --hap <debug-signed.hap> --json
triton app launch --platform harmony --device harmony-a --bundle <bundle> --ability <ability> --json
triton smoke harmony --device harmony-a --bundle <bundle> --ability <ability> --open-url '<url>' --wait-text '<text>' --screenshot /tmp/<case>.jpeg --evidence /tmp/<case>.tritonevidence --json
triton observe current --device harmony-a --json
triton observe tree --device harmony-a --outline --json
triton node resolve @1 --device harmony-a --json
triton node resolve --device harmony-a --text "登录" --json
triton act tap "登录" --platform harmony --device harmony-a --json
triton act swipe --platform harmony --device harmony-a --start-x 350 --start-y 900 --end-x 350 --end-y 300 --json
triton act type "hello" --platform harmony --device harmony-a --json
triton act paste "hello" --platform harmony --device harmony-a --json
```

`device list --platform harmony` may include `targets[].appName`, `targets[].bundleIdentifier`, `targets[].identityState`, and `targets[].current`. These fields are optional host facts, not app lifecycle proof; continue to verify business state with `app inspect/launch`, `observe`, `wait`, `assert`, screenshot, or evidence commands.

For Harmony host actions, schema exposes host-side output selectors alongside embedded runtime contracts. Parse `tap --platform harmony` as `host.harmony-tap`, `swipe --platform harmony` as `host.harmony-swipe`, and `type` / `paste --platform harmony` as `host.harmony-text-input`; do not reuse the embedded `input.result` parser for those host outputs. Parse `wait --platform harmony` as `host.harmony-wait`; do not reuse the embedded `wait.result` parser. Each layout dump/recv poll is bounded by `min(5s, remaining wait budget)`. A transient dump or recv timeout is retried and recorded through `transientFailureCount`, `lastTransientError`, and `sourceCommands`; persistent transfer timeouts end as the normal `timedOut=true` wait result instead of a generic `request_failed`. Parse `ax/screenshot --platform harmony` as `host.harmony-artifact`; do not reuse `host.artifact`. Parse `press --platform harmony` as `host.harmony-key-action`; do not reuse `host.key-action`. Treat `clear --platform harmony` as an explicit unsupported boundary (`harmony-clear-text`) until a stable host clear primitive exists, and treat any reappearance of legacy selectors (`host.tap`, `host.swipe`, `host.text-input`, `host.wait`) as schema regression.

Standalone Harmony embedded HTTP runtime:

```bash
triton device runtime-url --device harmony-a --probe-manifest --json
# Compatibility path:
triton device runtime-url --platform harmony --target <hdc-target> --probe-manifest --json
triton debug runtime manifest --runtime-base-url http://127.0.0.1:28767 --json
triton debug state route --runtime-base-url http://127.0.0.1:28767 --json
triton debug snapshot --runtime-base-url http://127.0.0.1:28767 --json
triton debug ledger --runtime-base-url http://127.0.0.1:28767 --jsonl
triton act set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:28767 --json
```

iOS embedded runtime observation:

```bash
triton list --json
triton debug ax --target triton:ios-simulator:<SIMULATOR_UDID> --json
triton act tap "登录" --target <ios-runtime-target-from-triton-list> --json
triton act swipe --target <ios-runtime-target-from-triton-list> --start-x 110 --start-y 700 --end-x 110 --end-y 140 --duration 0.6 --json
triton act tap --webview-aware --selector "#submit" --webview-id <webview-id> --page-session-id <page-session-id> --expect-text "成功" --json
triton observe current --platform ios --json
triton observe tree --platform ios --runtime-base-url <baseURL> --outline --json
triton observe tree --platform ios --device <simulator-selector> --json
triton wait --platform ios --device <simulator-selector> --text "登录" --json
triton node resolve @1 --platform ios --json
triton node resolve --platform ios --text "登录" --json
triton webview list --platform ios --json
triton webview current --platform ios --json
triton webview current-url --platform ios --json
triton route assert-current-url https://example.invalid/path --platform ios --json
triton webview call <method> --platform ios --json
triton webview events --platform ios --limit 50 --json
triton evidence summary /tmp/<case>.tritonevidence --json
triton evidence redact /tmp/<case>.tritonevidence --profile ios-private --output /tmp/<case>-redacted.tritonevidence --json
triton xctrace record --template "Time Profiler" --device <SIMULATOR_UDID> --time-limit 5s --output /tmp/<case>.trace --json
triton coverage report --xcresult /tmp/<case>.xcresult --output /tmp/<case>-coverage.json --json
```

For iOS Simulator host AX flows, `wait --platform ios` polls the same `host-layout` source as `observe tree --platform ios --device <selector>`. It supports `--text`, `--exists`, `--gone`, and optional `--role`, returns the `host.ios-wait` contract, and remains available when the management server or embedded runtime is disconnected. It is Simulator-only; do not route iOS real-device selectors into the private-framework AX adapter. Embedded idle, hierarchy-change, and predicate waits still use plain `wait` with a runtime target.

For a resolved embedded iOS `UICollectionViewCell` tap, the default remains fail-closed with `strategy=ancestor-collection-cell-unsupported` and `error.code=unsupported_capability`. Query and AX-label/oid paths may opt into one auditable host-HID coordinate submission:

```bash
triton act tap "<text>" --target <ios-runtime-target-from-triton-list> --allow-host-hid-fallback --json
triton act tap --ax-label "<label>" --target <ios-runtime-target-from-triton-list> --allow-host-hid-fallback --json
```

The fallback is accepted only for a connected iOS Simulator with a `simulatorUDID`, fresh finite positive matched geometry, and an on-screen center. It is not available for coordinate-only taps, Android, Harmony, physical devices, stale/off-screen geometry, or an unresolved node. A fallback result must retain `source=host-hid`, `strategy=host-hid-coordinate-tap`, `fallbackFromStrategy`, matched geometry, bounded `sourceCommands`, and `verification.required=true` / `status=not-verified`. Host acknowledgement is submission evidence only; follow it with `wait` / `verify` / evidence capture before claiming a business postcondition.

`triton evidence summary` / `inspect` now expose `primaryArtifacts[]`; agent should inspect those first before traversing the entire artifact set.

`triton replay ... --json` should also be consumed top-down: check `recoveryProposal`, `failedStepIndex`, `failureCode`, `failureError`, `failureWorkflowCategories[]`, `failureRecoveryCategories[]`, `failurePrimaryArtifacts[]`, `recoveryCommands[]`, and `suggestedCommands[]` before traversing every replay step. `recoveryProposal` is the repair-advisor envelope: read `diagnosis`, `evidenceRefs`, `proposal.policyDecision`, and `nextActions[]` before deciding whether to retry, inspect artifacts, or stop for review. Then inspect the failed step `error` payload when present, including `wait/input/evidence` failures that only returned `ok=false`. If `failureError.nextAction` exists, expect replay recovery commands and proposal next actions to expose the same path. Prefer replay failures that preserve runtime/target/transport error codes directly; treat unnecessary fallback to `step_failed` as a control-surface bug.

`webview list/current` 当前是 Web 容器候选发现能力，证据可能来自 WebView provider、iOS runtime AX/tree 或 Harmony host layout。先读取 `primarySource`：WebView 语义优先 `webview-provider`，其次 `runtime-tree`，再次 `host-layout`。`webview current-url/snapshot/call/events/wait` 与 `route assert-current-url` 是 provider 级能力：只断言 provider URL 或读取 provider 显式暴露的 bounded snapshot、allowlist bridge 与 page events，不操作 H5 页面，也不是任意 JavaScript eval。没有 WebView provider 时，输出必须保持 `candidateOnly=true`、`providerStatus=unavailable`、`bridgeStatus=unavailable`，并在 `missingCapabilities` 中声明 `webview.url`、`webview.dom`、`webview.bridge-call`、`webview.tap`、`webview.type` 等缺失项；不得把 AX/WebKit 容器误报为 DOM/JS/bridge 可用。Harmony 侧若未注册 WebView provider，也只能保持 host-only layout/candidate 边界，不能声明页面 bridge 可用。

When native AX / host hit-testing only reaches the `WKWebView` container and cannot identify H5 controls, keep the agent-facing action surface on `triton act tap`, not a low-level `webview click` command. Use the opt-in form `triton act tap --webview-aware --selector <css> --webview-id <id> --page-session-id <id> --expect-text <text> --json`. The runtime action is `webview.tap`, but the CLI result is an action envelope with `status=passed|failed|uncertain`: DOM dispatch is explicitly `trusted=false`, so a tap without `--expect-text` or another explicit verification must return `uncertain` rather than claim business success. Use `--webview-id` and `--page-session-id` to disambiguate multiple WebViews or page reloads. Keep `expect-request`, CDP / remote debugging, arbitrary JavaScript eval, and trusted HID synthesis as separate future slices unless the current space updates the boundary and tests.

When multiple iOS Simulator apps connect to the same `triton serve`, embedded runtime targets use stable ids shaped as `triton:ios-simulator:<SIMULATOR_UDID>`. Runtime commands may pass either the full target id or the simulator UDID. If more than one runtime target is connected and the command still uses the default `triton:local`, the expected result is `error.code=ambiguous_target`, not last-connection wins.

For the Harmony demo, `28767` is the host-access embedded runtime port exposed through HDC `fport`; `18765` is the device-to-host gateway fallback port.

When debugging Harmony direct runtime defaults, verify against a real HDC target before changing CLI defaults:

```bash
TRITON_BIN=.build/cli-scratch/debug/triton docs-linhay/scripts/verify-harmony-runtime-emulator-smoke.sh --target <hdc-target> --no-forward
```

Use `--no-forward` when the HDC fport already exists, because repeating `hdc fport tcp:28767 tcp:28767` can fail with a host listen conflict even though the existing forwarded endpoint is healthy. Keep mock contract smoke separate from real emulator smoke: the mock script should use an isolated test port while asserting the schema/default output remains `28767`.

Android Emulator host-side support is now part of the implemented local CLI takeover surface. Treat `adb`-backed device discovery, readiness, start/stop, screenshot, app lifecycle, UIAutomator observe/wait/tap, and `smoke android` as schema-backed Triton commands; continue to keep DTOs, evidence, and command-ledger schemas platform-neutral across iOS, Android, and Harmony.

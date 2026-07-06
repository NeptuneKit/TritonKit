# Strong Control Milestones And Subagent Map

## Milestones

### M0: Contract Baseline

Goal: define the public Triton contract before adding private or helper
implementations.

Checklist:

- [x] Add strong-control capability DTOs.
- [x] Expose iOS host AX/HID as optional readonly probes.
- [x] Expose Android bridge `status/probe/install/forward` commands.
- [x] Protect root `Package.swift` from CLI/private-framework/Android build
  dependencies.
- [x] Keep ADB/UIAutomator and embedded-runtime fallback behavior intact.

Exit gate:

```bash
swift test --filter StrongControl
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command device --json
docs-linhay/scripts/check-docs.sh
```

Status on 2026-07-02:

- Shared DTO and root package boundary tests exist.
- `device` schema exposes `strongControl[]?`, `ios-host-ax`, and
  `ios-host-hid`.
- `device bridge status/probe/install/forward` exists in schema and CLI.
  `install` / `forward` can execute the adb runner only when
  `--confirm --audit-record --execute-runner` are present.

### M1: Android Bridge Minimal APK

Goal: build the smallest installable helper that satisfies the CLI bridge
contract.

Implementation note:

- `Tools/AndroidBridge/` contains the TritonKit helper project adapted from
  the archived `sim-use` bridge reference.
- The helper stays outside root SwiftPM dependency resolution and root
  `Package.swift` remains protected by boundary tests.
- The local machine currently has Android SDK/platform/build-tools 34 and JDK
  17, so the helper targets SDK 34 for local reproducibility.

Checklist:

- [x] Add minimal Android helper project outside root SwiftPM dependency
  resolution.
- [x] Implement `AccessibilityService`.
- [x] Implement `/ping` and `/a11y_tree_full`.
- [x] Implement `/tap`, `/swipe`, `/keyboard/input`, `/paste`, `/keyboard/key`.
- [x] Implement ContentProvider auth token at
  `content://jp.lycorp.tritonkit.bridge/auth_token`.
- [x] Produce one APK artifact and build command.

Exit gate:

```bash
triton device bridge install --platform android --device <emulator> --apk <apk> --confirm --audit-record <id> --execute-runner --json
triton device bridge forward --platform android --device <emulator> --confirm --audit-record <id> --execute-runner --json
triton device bridge status --platform android --device <emulator> --json
```

Status on 2026-07-02:

- Gradle build and unit tests pass with JDK 17 and Android SDK 34.
- Release APK is produced at
  `Tools/AndroidBridge/app/build/outputs/apk/release/app-release.apk`.
- `aapt dump badging` confirms package
  `jp.lycorp.tritonkit.bridge`, version `0.1.0`, and target SDK 34.

### M2: Android Real Bridge Smoke

Goal: prove the bridge path works on one local emulator.

Checklist:

- [x] Run Triton-first status / doctor / capability checks.
- [x] Install and forward the bridge.
- [x] Verify `device bridge status` can detect install state and auth token.
- [x] Make `device bridge probe` reachable through the forwarded local port.
- [x] Capture `observe tree` with `primarySource.name=android-bridge`.
- [x] Run `wait --platform android` against bridge text.
- [x] Run at least one bridge-backed `act tap`.
- [x] Save command evidence under this space.

Exit gate:

```bash
triton observe tree --platform android --device <emulator> --json
triton wait --platform android --device <emulator> --text <text> --json
triton act tap <text> --platform android --device <emulator> --json
```

Status on 2026-07-02:

- Triton-first facts were captured before adb fallback.
- One local emulator booted and reached ready state.
- `bridge install` and `bridge forward` succeeded through Triton with audit
  record `m1-local-smoke`.
- `bridge status` reports `installed=true` and `authTokenAvailable=true`.
- The root cause of the initial `bridge probe` failure was a wrong default
  forward target (`tcp:19422` instead of the helper's `tcp:8080`) plus a local
  emulator AccessibilityService that was not enabled.
- `bridge probe`, `observe tree`, `wait`, and `act tap` now pass on
  `emulator-5554` with `android-bridge` source evidence.
- Evidence is recorded in
  `evidence/20260702-android-bridge-smoke-v01.md`.

### M3: iOS Host Adapter Boundary

Goal: move from probe to CLI-only host AX/HID adapter without dependency
leakage.

Checklist:

- [x] Add CLI-only adapter entrypoints.
- [x] Keep stable unavailable errors when `idb` or private frameworks are
  missing.
- [x] Implement readonly host AX tree first.
- [x] Route `observe tree --platform ios --device <selector>` to host AX nodes.
- [x] Implement `node resolve --platform ios` over host AX nodes.
- [x] Implement HID actions only after readonly evidence passes.
- [x] Keep root `Package.swift` dependency-boundary test passing.

Exit gate:

```bash
triton device doctor --platform ios --json
triton observe tree --platform ios --device sim:<udid> --json
triton node resolve <text> --platform ios --device sim:<udid> --json
triton act tap <text> --platform ios --device sim:<udid> --json
```

Status on 2026-07-05:

- `triton sim ax` exists as the host-side simulator AX entrypoint.
- `triton node resolve` is restored as a first-class root workflow, and
  `schema --command node --json` now reports `surfaceLayer=workflow` with
  `deprecatedForMainPath=false`.
- Raw low-level node inspection remains under `triton debug node`; remaining
  M3 work is the actual host AX readonly data path, stable unavailable
  diagnostics, and HID-backed action path.

Status on 2026-07-06:

- `triton sim ax --json` now returns stable `TKCLIErrorResponse` envelopes for
  missing private framework / translator, missing simulator target, frontmost
  AX root failure, platform-element conversion failure, and tree-unavailable
  cases.
- `schema --command sim --json` exposes the `ax` subcommand, its
  `host.simulator-ax` output contract, and host AX failure codes. Fake-UDID
  smoke returns `surface=sim.ax` with `code=simulator_not_found`, which gives
  subagents a machine-readable no-state-change probe before real simulator
  smoke.
- Remaining M3 work is still: prove readonly host AX tree on a booted local
  simulator, route `observe tree --platform ios --device sim:<udid>` to that
  tree, then layer `node resolve` and HID actions after readonly evidence.

Status later on 2026-07-06:

- `observe current|tree --platform ios --device <selector> --json` now routes
  simulator host targets to the private-framework AX tree and returns the same
  `observe.surface` shape with `primarySource.name=host-layout`.
- `node resolve --platform ios --device <selector> --text <text> --json`
  reuses that host AX observe tree for readonly text/id/point resolution.
- `observe-ios-host-ax` is now a schema/capability-matrix capability with
  `runtimeScope=host-ios`, recovery commands, and host AX failure codes.
- Parser-stage `--device sim:<missing-udid>` failures now return JSON
  `ok=false` envelopes instead of raw text errors, so subagents can smoke
  target absence without mutating simulator state.
- Remaining M3 work is now: run a real booted Simulator AX observe/node smoke,
  capture evidence, then implement HID-backed `act` only after readonly proof.
- `docs-linhay/scripts/verify.sh --local` passes after the schema/capability
  sync, including Swift tests, release CLI build, iOS Simulator build,
  docs structure, and diff whitespace checks.

Status latest on 2026-07-06:

- Real booted Simulator smoke passed on `TritonKit Dedicated iPhone 17`
  (`0333546D-2AC6-4C22-AF01-293E2F4BA5BC`, iOS 26.5).
- `sim ax`, `observe tree --platform ios --device <udid>`, and
  `node resolve --platform ios --device <udid> --text "设置"` all returned
  host-layout evidence from private host AX.
- `act tap --platform ios --device <udid> --text "通用"` now submits a
  host-side `accessibilityPerformPress` through the same private AX translator
  path and returns clean `HostIOSTapOutput`.
- Post-action observe proved navigation into Settings / General with labels
  `通用` and `关于本机`.
- Evidence is recorded in
  `evidence/20260706-ios-host-ax-tap-smoke-v01.md`.
- Remaining M3 work is limited to broadening host HID beyond tap
  (`type`/`swipe` if still needed) and deciding whether to expose higher-level
  action aliases in M4.

### M4: Alias And Outline

Goal: add a small agent convenience layer only after real tree sources are
proven.

Checklist:

- [x] Add deterministic outline output for Android bridge, iOS host AX, and
  embedded runtime nodes.
- [x] Add session-local or repo-local `@N` aliases.
- [x] Add explicit stale alias failure shape.
- [x] Avoid daemon cache until repeated runs prove it is needed.

Exit gate:

```bash
triton observe tree --platform android --device <emulator> --outline --json
triton node resolve @1 --platform android --device <emulator> --json
```

Status on 2026-07-06:

- `observe tree --outline --json` now emits deterministic `outline[]` entries
  with `@N` aliases and writes the repo-local cache
  `.triton/node-aliases.json`.
- `node resolve @N --platform <platform> ... --json` resolves from that cache;
  stale target/platform mismatches return `stale_node_alias` with a
  machine-readable `nextAction` that refreshes aliases through
  `observe tree --outline --json`.
- The cache is intentionally repo-local and file-backed. No daemon/session
  service was introduced.
- Schema/capabilities now expose `observe-outline` and
  `node-alias-resolve`; `observe.surface` documents `outline?` and
  `aliasCache?`.
- Offline tests cover Android bridge nodes, iOS host AX nodes, parser support
  for positional `node resolve @1`, schema capability alignment, and stale
  alias error mapping.
- Actual CLI smoke passed on the booted iOS Simulator path from a temporary
  workspace: `observe tree --platform ios --device booted --outline --json`
  produced 14 aliases, `node resolve @1 --platform ios --device booted --json`
  returned `ok=true`, and a deliberate mismatched `--target` returned
  `code=stale_node_alias`.
- Android real exit gate later passed on `emulator-5554` after Triton
  `device start --platform android --avd Dxyer_API_34` and bridge forward.
  `observe tree --platform android --device emulator-5554 --outline --json`
  returned `primarySource.name=android-bridge` with 33 aliases, and
  `node resolve @1 --platform android --device emulator-5554 --json` returned
  `ok=true` from the bridge source.
- Evidence is recorded in
  `evidence/20260706-m4-android-outline-smoke-v01.md`.

### M5: Release Hardening

Goal: make the feature reviewable and shippable.

Checklist:

- [x] Run full local verification.
- [x] Update docs and memory.
- [x] Confirm root SwiftPM dependency boundary.
- [x] Confirm Android helper packaging is not pulled into business App
  dependency resolution.
- [x] Prepare one reviewable commit series.

Exit gate:

```bash
docs-linhay/scripts/verify.sh --local
docs-linhay/scripts/check-docs.sh
git diff --check
```

Status on 2026-07-06:

- `docs-linhay/scripts/verify.sh --local` passed after the M3/M4 CLI,
  schema, docs, and public skill changes. The gate included SwiftPM dependency
  boundary, Swift tests, release CLI build, Harmony host smoke, iOS runtime
  observe smoke, iOS Simulator build, docs structure, and diff whitespace.
- M4 Android real exit gate passed separately after bringing up
  `emulator-5554` through Triton `device start`.
- The Android cleanup gap found during that gate is closed: `triton device stop
  --platform android --device emulator-5554 --confirm --json` now executes
  `adb -s emulator-5554 emu kill` for emulator-scoped targets and was verified
  against the same AVD without affecting a connected Android real device.
- Reviewable commit series was created on `main` after this pass:
  `fb278bd6 feat(cli): strengthen emulator control workflows`,
  `877e1692 feat(web): refine host bridge mock inspector`,
  `1d2bbcf7 feat(demo): add camera smoke harness`, and
  `5fc2d49d fix(cli): expose simulator camera privacy service`.
- The actual CLI commit intentionally uses one domain-level commit rather than
  fragile hunk splits across overlapping schema/test files.

Recommended commit series:

1. `host-ios-ax-takeover`: iOS host AX observe/node/tap support and focused
   tests.
   Files: `CLIHostSimulatorAXDriver.swift`, `CLIHostSimAXCommand.swift`,
   `CLIActionCommands.swift`, `CLIHostModels.swift`,
   `CLIRuntimeTransport*.swift`, `CLISchemaActionCommands.swift`,
   `CLISchemaHostCommands.swift`, `CLISchemaCapabilityContracts.swift`,
   `FailureDiagnosticsTests.swift`, `ObservationOutputTests.swift`,
   `SelectorFlagTests.swift`, `SimulatorAdvancedControlsTests.swift`,
   `CLIHelpTests.swift`.
2. `observe-outline-node-aliases`: agent-readable outline output, repo-local
   `.triton/node-aliases.json`, stale alias errors, and schema contracts.
   Files: `CLIObservationCommands.swift`, `CLIObservationModels.swift`,
   `CLIObservationRuntime.swift`, `CLISchemaObservationCommands.swift`,
   `CLISchemaOutputContracts.swift`, `CLISchemaRuntime.swift`,
   `CLISchemaShared.swift`, `TKCLITransportSchemaModels.swift`,
   schema/selector/observation tests. Some tests overlap with commit 1 and
   should be hunk-staged.
3. `android-emulator-stop-cleanup`: schema-backed Android Emulator stop via
   `triton device stop --platform android --device <selector> --confirm`.
   Files: `CLIHostDeviceCommands.swift`, `CLIHostModels.swift`,
   `CLISchemaHostCommands.swift`, `CLIRuntimeTransport.swift`,
   `TKAndroidADBSupport.swift`, `DeviceCrossPlatformTests.swift`. This commit
   is the cleanup gap found during the Android M4 smoke.
4. `strong-emulator-control-docs`: README, public skill, dev docs, memory,
   milestone, and evidence updates for M3/M4/M5. Stage docs by hunk so Web/demo
   references do not leak into CLI-only commits.
5. Optional separate review: `web-mock-host-bridge-ui`.
   Files under `Web/` only, including untracked Web tests/data/helpers.
6. Optional separate review: `demo-camera-harness`.
   Files: `Examples/TritonKitDemo/TritonKitDemo/App.swift`,
   `Examples/TritonKitDemo/TritonKitDemo/Info.plist`.

## Parallel Subagent Areas

Recommended execution rule: use subagents for isolated write surfaces only.
Main-control owns integration, conflict resolution, focused verification,
docs, memory, and final completion judgment.

### A: Android Bridge APK

Write scope:

- Android helper source and build files.
- Minimal helper build/install docs.

Do not touch:

- Root `Package.swift`.
- iOS adapter files.
- Web/Wails files.

Evidence:

- APK path.
- Build command.
- Endpoint list.
- Emulator smoke output or exact blocker.

Current status: M1 completed locally. Future work in this area should be
limited to endpoint defects found by M2 smoke.

Can run in parallel with: C, E.

### B: Android CLI Integration Audit

Write scope:

- Narrow CLI tests or fixes under `Sources/TritonKitCLI/` only when the APK
  exposes a contract mismatch.

Do not touch:

- Android helper source.
- iOS adapter files.

Evidence:

- Diff summary.
- Focused test command.
- One JSON sample for `device bridge status` or `observe tree`.

Current status: install / forward / status / probe / observe / wait / tap
source selection exists. Next work should focus on endpoint-specific Android
bridge actions beyond coordinate tap, only if the current adb-input mutation is
insufficient.

Can run in parallel with: C, D, E.

### C: iOS Adapter Spike

Write scope:

- CLI-only adapter boundary and tests.
- Optional local wrapper scripts if needed.

Do not touch:

- Root `Package.swift`.
- Android helper source.
- Embedded SDK sources except approved shared DTOs.

Evidence:

- `device doctor --platform ios --json` sample.
- Adapter availability matrix.
- Focused tests for unavailable and available-probe paths.

Current status: CLI entrypoints exist (`sim ax`, `observe --device <selector>`,
`node resolve --device <selector>`) and schema/capability metadata is aligned.
Booted Simulator evidence now covers host AX observe/node and host AX press tap.
M4 aliases now consume the public observe DTO, so future iOS adapter work should
only broaden HID beyond tap when a concrete workflow needs type/swipe and can
provide post-action observe evidence.

Can run in parallel with: A, B, E.

### D: Alias And Outline Contract

Write scope:

- Schema, tests, and docs for outline / alias behavior.

Do not touch:

- Android APK.
- iOS private adapter implementation.

Evidence:

- Contract examples for `@N`.
- Stale alias failure shape.
- Focused schema tests.

Current status: implemented. `observe tree --outline --json` emits `outline[]`
and writes `.triton/node-aliases.json`; `node resolve @N` resolves that cache;
`stale_node_alias` is schema-backed and returns a refresh `nextAction`.
Android real-emulator exit gate passed later on 2026-07-06 with
`emulator-5554`, `primarySource.name=android-bridge`, and `outline_count=33`.

Can run in parallel with: B after M2 tree output shape is stable.

### E: Verification And Evidence

Write scope:

- Space evidence docs.
- Memory entries.
- Small scripts only when they remove manual repetition.

Do not touch:

- Runtime implementation files.
- Helper APK implementation.

Evidence:

- Command transcript summary.
- Artifact paths.
- Failed command output and blocker classification.

Can run in parallel with: A, B, C.

## Execution Checklist

| Batch | Owner | Milestone slice | Depends on | Parallel with | Main-control gate |
| --- | --- | --- | --- | --- | --- |
| 0 | Main-control | M0 bridge / strong-control contract | Current M0 schema baseline | none | Done locally: `device` schema shows bridge commands and strong-control failure shapes |
| 1 | Subagent A | M1 Android helper APK | Batch 0 bridge contract | C, E | Done locally: APK builds and endpoint contract matches CLI schema |
| 2 | Main-control + B | M2 Android real bridge smoke and narrow CLI fixes | M1 helper APK | E | Done locally: bridge probe, observe, wait, and tap pass on `emulator-5554` |
| 3 | Subagent C | M3 iOS host adapter tap spike | Current iOS probes | D, E | Done locally: readonly observe/node and `act tap --platform ios` pass on booted Simulator |
| 3 | Subagent D | M4 outline / alias contract | M2 tree sample or stable DTO fixture | C, E | Done locally: deterministic outline tests, stale alias failure tests, iOS host AX outline smoke |
| 3 | Subagent E | Evidence refresh for M3/M4 | Space exists | C, D | Done locally: M3/M4 evidence files, plan status, and memory are current |
| 4 | Main-control | M5 release hardening | Batches 0-3 merged | none | Done locally: full local gate passed, Android cleanup gap closed, reviewable commit boundaries prepared |

## Main-Control Rules

1. One subagent owns one write area at a time.
2. Main-control reads diff and runs focused tests before merging any subagent
   output.
3. No subagent may add host/private/helper dependencies to root `Package.swift`.
4. No subagent may claim completion without machine-readable Triton command
   evidence.
5. Run `verify.sh --local` at milestone exits, not after every patch.

## Suggested Batch Plan

Completed batches:

- Batch 0: M0 contract baseline.
- Batch 1: M1 Android Bridge APK.
- Batch 2: M2 Android real bridge smoke and Android bridge CLI integration fixes.
- Batch 3: M3 iOS host AX observe/node/tap and M4 outline / alias contract.

Next batch:

- Main-control: decide whether the current branch should be pushed as-is or
  further split in a review branch. After those four commits, `main` was ahead
  of `origin/main` by the four commits listed above.
- Optional implementation subagents may continue only on concrete gaps:
  iOS host HID beyond tap, Android bridge endpoint parity, Web mock polishing,
  or Demo camera runtime smoke.

## Subagent Handoff Packets

Use these packets when opening a later subagent team. Main-control still owns
integration and completion.

### Packet C: iOS Host Adapter

Goal: extend M3 beyond the completed readonly/tap path only if more HID primitives
are still needed.

Write scope:

- `Sources/TritonKitCLI/` iOS host adapter, real-simulator evidence handling,
  HID action routing, and focused tests.
- Shared DTO changes only when required by the public JSON contract.

Non-goals:

- Do not add `idb`, FBSimulatorControl, or Apple private framework dependencies
  to root `Package.swift`.
- Do not broaden HID beyond tap until a concrete workflow needs type/swipe and
  can provide post-action observe evidence.

Required evidence:

- `triton device doctor --platform ios --json`
- `triton observe tree --platform ios --device sim:<udid> --json`
- `triton node resolve <text> --platform ios --device sim:<udid> --json`
- `triton act tap <text> --platform ios --device sim:<udid> --json`
- focused Swift test command and result

Stop if `idb` command shape or private framework availability cannot be proven
from local tools or primary project docs.

### Packet D: Alias And Outline

Goal: complete M4 agent convenience output after real node trees are stable.

Write scope:

- CLI schema, models, tests, and docs for outline and `@N` alias behavior.

Non-goals:

- Do not edit Android helper APK source.
- Do not edit iOS host adapter internals beyond consuming its public tree DTO.
- Do not introduce a daemon cache.

Required evidence:

- deterministic outline JSON example for Android bridge or fixture tree
- stale alias failure JSON example
- focused schema / CLI tests

Stop if tree node identity is still unstable enough that aliases would be
misleading.

### Packet E: Verification And Evidence

Goal: keep the space reviewable while implementation subagents move in
parallel.

Write scope:

- `docs-linhay/spaces/20260702-strong-emulator-control/evidence/`
- `docs-linhay/memory/2026-07-02.md`
- small verification scripts only if they remove repeated manual transcript
  work.

Non-goals:

- Do not edit implementation files.
- Do not mark a milestone complete without command evidence from main-control
  or the owning implementation subagent.

Required evidence:

- command transcript summary with exact Triton commands
- artifact paths
- blocker classification for unavailable host tools
- docs structure check result

Stop if evidence contradicts a milestone checkbox; report the mismatch instead
of editing the checkbox optimistically.

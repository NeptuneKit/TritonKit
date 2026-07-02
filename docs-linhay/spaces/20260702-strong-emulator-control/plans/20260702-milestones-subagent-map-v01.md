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

- [ ] Add CLI-only adapter entrypoints.
- [ ] Keep stable unavailable errors when `idb` or private frameworks are
  missing.
- [ ] Implement readonly host AX tree first.
- [ ] Implement `node resolve --platform ios` over host AX nodes.
- [ ] Implement HID actions only after readonly evidence passes.
- [ ] Keep root `Package.swift` dependency-boundary test passing.

Exit gate:

```bash
triton device doctor --platform ios --json
triton observe tree --platform ios --device sim:<udid> --json
triton node resolve <text> --platform ios --device sim:<udid> --json
triton act tap <text> --platform ios --device sim:<udid> --json
```

### M4: Alias And Outline

Goal: add a small agent convenience layer only after real tree sources are
proven.

Checklist:

- [ ] Add deterministic outline output for Android bridge, iOS host AX, and
  embedded runtime nodes.
- [ ] Add session-local or repo-local `@N` aliases.
- [ ] Add explicit stale alias failure shape.
- [ ] Avoid daemon cache until repeated runs prove it is needed.

Exit gate:

```bash
triton observe tree --platform android --device <emulator> --json
triton node resolve @1 --platform android --device <emulator> --json
```

### M5: Release Hardening

Goal: make the feature reviewable and shippable.

Checklist:

- [ ] Run full local verification.
- [ ] Update docs and memory.
- [ ] Confirm root SwiftPM dependency boundary.
- [ ] Confirm Android helper packaging is not pulled into business App
  dependency resolution.
- [ ] Prepare one reviewable commit series.

Exit gate:

```bash
docs-linhay/scripts/verify.sh --local
docs-linhay/scripts/check-docs.sh
git diff --check
```

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
| 3 | Subagent C | M3 iOS host adapter readonly spike | Current iOS probes | D, E | unavailable and available-probe paths are tested; no root package dependency leak |
| 3 | Subagent D | M4 outline / alias contract | M2 tree sample or stable DTO fixture | C, E | deterministic outline and stale alias failure tests |
| 3 | Subagent E | Evidence refresh for M3/M4 | Space exists | C, D | evidence path, blocker classification, and command transcript are current |
| 4 | Main-control | M5 release hardening | Batches 0-3 merged | none | focused tests, `docs-linhay/scripts/check-docs.sh`, `git diff --check`, then full local gate if needed |

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

Next batch:

- Subagent C: iOS adapter spike.
- Subagent D: alias/outline contract.
- Subagent E: M3/M4 evidence refresh.

Final batch:

- Main-control: merge, run gates, update docs/memory, prepare commit.

## Subagent Handoff Packets

Use these packets when opening a later subagent team. Main-control still owns
integration and completion.

### Packet C: iOS Host Adapter

Goal: complete M3 readonly host adapter before any HID mutation.

Write scope:

- `Sources/TritonKitCLI/` iOS host adapter, observe, node resolve, and focused
  tests.
- Shared DTO changes only when required by the public JSON contract.

Non-goals:

- Do not add `idb`, FBSimulatorControl, or Apple private framework dependencies
  to root `Package.swift`.
- Do not implement HID tap/swipe/type until readonly tree and node resolve have
  evidence.

Required evidence:

- `triton device doctor --platform ios --json`
- `triton observe tree --platform ios --device sim:<udid> --json`
- `triton node resolve <text> --platform ios --device sim:<udid> --json`
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

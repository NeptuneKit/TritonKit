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
- iOS `sim list/use/boot/shutdown/screenshot`;
- app lifecycle: `list/info/install/uninstall/launch/terminate/open-url`;
- app data: containers, preferences, safe data reset/snapshot when policy is explicit;
- UI artifacts: screenshot, AX/layout tree, bounded logs;
- runtime actions: `find/tap/swipe/type/paste/clear/wait/assert`;
- replay and evidence: `.tritonplan`, `.tritonevidence`, command ledger, case lint, local batch.

Do not add Web / Wails UI, remote orchestration, real-device flows, or central services to satisfy this domain. If the requirement truly needs those, create a new space and reset the product boundary first.

## Current Implemented Surface

iOS Simulator:

```bash
triton sim list --json
triton sim use <udid> --json
triton sim boot <udid> --wait --jsonl
triton sim shutdown <udid-or-booted> --json
triton sim screenshot --simulator <udid-or-booted> --output /tmp/<case>-sim.png --json

triton app list --simulator <udid-or-booted> --user-only --json
triton app info --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app install --app <path.app> --simulator <udid-or-booted> --json
triton app uninstall --bundle-id <bundle-id> --simulator <udid-or-booted> --confirm --json
triton app launch --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app terminate --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app open-url '<url>' --simulator <udid-or-booted> --json
triton app container --bundle-id <bundle-id> --kind data --simulator <udid-or-booted> --json
triton app prefs get <key> --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app prefs dump --bundle-id <bundle-id> --simulator <udid-or-booted> --json
```

HarmonyOS / DevEco Emulator:

```bash
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device use --platform harmony --target <hdc-target> --json
triton device wait-ready --platform harmony --target <hdc-target> --json
triton app inspect --platform harmony --bundle <bundle> --json
triton app launch --platform harmony --bundle <bundle> --ability <ability> --json
```

Android Emulator is an accepted product direction but should be added as a later adapter slice. Keep DTOs and command ledger schemas platform-neutral now, but do not claim Android commands are implemented until `schema --command app --json` exposes them.

## Safety Rules

- Destructive or state-changing host actions must require explicit flags or policy. Current example: `app uninstall` requires `--confirm` and otherwise returns `destructive_action_requires_policy`.
- Host command success is not business success. After `launch`, `open-url`, `install`, or `uninstall`, verify with `wait`, `find`, `assert`, screenshot, app prefs, layout/AX, or evidence.
- Multiple local targets must return `ambiguous_target` instead of picking an unsafe default.
- Every host action should preserve source command, target, elapsed time, risk/policy metadata when available, and next verification advice.
- Logs, screenshots, layout dumps, and data snapshots must be bounded and redacted when persisted into evidence.

## Implementation Workflow

1. Update the relevant `space` README or technical design with BDD acceptance before code changes.
2. Add or update model/parser tests first:
   - iOS simctl argv and parser behavior;
   - Harmony hdc / aa / bm parser behavior;
   - Android adb parser behavior when that adapter lands;
   - error envelopes and destructive policy failures.
3. Implement shared contracts before CLI glue when a DTO or source-command shape is reusable.
4. Expose the CLI in `Sources/TritonKitCLI/main.swift`, keeping JSON / JSONL as the agent-facing default.
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
swift build --product triton
.build/debug/triton schema --command device --json
.build/debug/triton schema --command app --json
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/qmd-sync.sh
```

Run real emulator smoke only when safe for the current machine:

```bash
.build/debug/triton sim list --json
.build/debug/triton app uninstall --bundle-id com.example.missing --simulator booted --json
.build/debug/triton app launch --bundle-id com.example.missing --simulator booted --json
.build/debug/triton device list --platform harmony --json
.build/debug/triton device wait-ready --platform harmony --target <hdc-target> --json
```

Avoid erasing emulators, uninstalling business apps, installing data bundles, changing privacy/location, or collecting broad logs unless the current task explicitly requires it and the command records policy metadata.

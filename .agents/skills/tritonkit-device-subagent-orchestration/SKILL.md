---
name: tritonkit-device-subagent-orchestration
description: Use when orchestrating TritonKit device-related subagent tracks, including Android Emulator support and cross-platform real-device support; route to the matching space plan, assign scoped Codex subagents, preserve write-surface isolation, and combine with tritonkit-subagent-supervision for integration and final DoD.
metadata:
  version: 0.1.0-dev
---

# TritonKit Device Subagent Orchestration

Use this internal skill when a TritonKit device track needs project-scoped Codex subagents. It replaces the older track-specific `tritonkit-android-subagent-orchestration` and `tritonkit-real-device-subagent-orchestration` entries.

Always combine with `tritonkit-subagent-supervision`: subagents do scoped work, while the main agent owns boundary, integration, verification, docs, memory, and final completion judgment.

## Track Router

Choose exactly one track unless the user explicitly asks to coordinate multiple tracks.

### Android Emulator Support

Use this track for Android Emulator support, fake adb, Android device/app lifecycle, UIAutomator observe, smoke, and evidence work.

Source of truth:

- `docs-linhay/spaces/20260605-android-emulator-support/README.md`
- `docs-linhay/spaces/20260605-android-emulator-support/plans/20260605-android-emulator-support-plan-v01.md`
- `docs-linhay/spaces/20260605-android-emulator-support/plans/20260605-android-emulator-execution-breakdown-v01.md`

Agent split:

| Agent | Config | Execution steps | Primary write surface |
| --- | --- | --- | --- |
| Contract | `.codex/agents/tritonkit_android_contract_agent.toml` | Step 1, Step 13 | schema, capabilities, failure code tests |
| Fake ADB | `.codex/agents/tritonkit_android_fake_adb_agent.toml` | Step 2 | fake adb fixtures, parser tests |
| Device | `.codex/agents/tritonkit_android_device_agent.toml` | Step 3-7 | Android device doctor/list/resolve/wait/screenshot |
| App | `.codex/agents/tritonkit_android_app_agent.toml` | Step 8 | Android app lifecycle and open-url |
| Observe Smoke | `.codex/agents/tritonkit_android_observe_smoke_agent.toml` | Step 9-12, Step 14 | UIAutomator, smoke, evidence, replay proof |

Batching:

1. Batch 1: Contract and Fake ADB.
2. Batch 2: Device and App after contract and fixture surfaces stabilize.
3. Batch 3: Observe Smoke after device/app CLI surfaces stabilize.

Main agent owns Step 0, Step 15, Step 16, Step 17, integration, verification, real emulator smoke when available, docs, memory, and completion judgment.

### Cross-Platform Real Device Support

Use this track for iOS / Android / Harmony real-device support, devicectl / adb / hdc real targets, app lifecycle, smoke/evidence, and build-run planning.

Source of truth:

- `docs-linhay/spaces/20260608-cross-platform-real-device-takeover/README.md`
- `docs-linhay/spaces/20260608-cross-platform-real-device-takeover/technical-design.md`
- `docs-linhay/spaces/20260608-cross-platform-real-device-takeover/plans/p0-p3-plan.md`
- `docs-linhay/spaces/20260608-cross-platform-real-device-takeover/plans/20260608-subagent-execution-plan-v01.md`
- `docs-linhay/spaces/20260608-ios-real-device-takeover/README.md`
- `docs-linhay/spaces/20260608-ios-real-device-takeover/technical-design.md`

Agent split:

| Agent | Config | Phase | Primary write surface |
| --- | --- | --- | --- |
| Contract | `.codex/agents/tritonkit_real_device_contract_agent.toml` | P0/P1 | schema, DTOs, selectors, failure-code and evidence contracts |
| iOS Device | `.codex/agents/tritonkit_ios_real_device_agent.toml` | P0 | devicectl command builder/parser, iOS real-device readiness |
| Android Device | `.codex/agents/tritonkit_android_real_device_agent.toml` | P0 | adb real-device parser, Android real target readiness |
| Harmony Device | `.codex/agents/tritonkit_harmony_real_device_agent.toml` | P0 | HDC real-device parser, Harmony real target readiness |
| App Lifecycle | `.codex/agents/tritonkit_real_device_app_agent.toml` | P1 | cross-platform install/launch/open-url app lifecycle |
| Smoke Evidence | `.codex/agents/tritonkit_real_device_smoke_evidence_agent.toml` | P1/P3 | smoke, wait/assert proof, evidence, screenshots/log summaries |
| Build | `.codex/agents/tritonkit_real_device_build_agent.toml` | P2 | Xcode real-device build, Gradle, hvigor build-run planning |

Batching:

1. Batch 1: Contract, iOS Device, Android Device, Harmony Device.
2. Batch 2: App Lifecycle and Smoke Evidence after target identity and resolver contracts stabilize.
3. Batch 3: Build after P0/P1 surfaces stabilize.

Keep raw real-device logs, screenshots, serials, UDIDs, HDC targets, accounts, and private bundle ids out of public issue text.

## Shared Execution Rules

1. Check `git status --short --branch` before spawning.
2. Confirm the active `space` and source plan before assigning subagents.
3. If multi-day execution starts, create the track worktree under `../TritonKit-worktrees/<space-key>/`.
4. Confirm no uncommitted user work will be overwritten.
5. Confirm relevant `.codex/agents/*.toml` configs use the required local access for host tools:

```toml
sandbox_mode = "danger-full-access"
approval_policy = "never"
```

6. Assign each subagent a narrow step or phase and explicit non-goals.
7. Do not let two subagents own the same implementation files in the same batch unless the main agent has split line-level responsibilities.
8. Pull subagent results in batches, run focused tests after each batch, and resolve conflicts centrally.
9. Do not let a subagent declare the feature complete. Code changes alone are not completion.

## Stop Conditions

Stop only when the track is integrated and verified, the user pauses, or a concrete blocker prevents progress. Report the blocker with the exact source plan step, affected subagent, failed command or missing environment condition, and next action.

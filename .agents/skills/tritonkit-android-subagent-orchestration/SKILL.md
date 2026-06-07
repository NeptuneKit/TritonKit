---
name: tritonkit-android-subagent-orchestration
description: Use when orchestrating TritonKit Android Emulator support with project-scoped Codex subagents, especially the five-agent split for contract, fake adb, device, app lifecycle, and observe/smoke/evidence work.
metadata:
  version: 0.1.0-dev
---

# TritonKit Android Subagent Orchestration

## Trigger

Use this skill when the user asks to start, design, supervise, or coordinate subagents for Android Emulator support in TritonKit.

Always combine it with `tritonkit-subagent-supervision`: subagents do scoped work, while the main agent owns boundary, integration, verification, docs, memory, qmd, and final completion judgment. The user has authorized the main agent to act as leader for this Android support track, so the main agent should manage the subagent team proactively and only interrupt the user for boundary changes, destructive actions, environment blockers, or decisions that cannot be made from the plan.

## Source of Truth

Read these first:

- `docs-linhay/spaces/20260605-android-emulator-support/README.md`
- `docs-linhay/spaces/20260605-android-emulator-support/plans/20260605-android-emulator-support-plan-v01.md`
- `docs-linhay/spaces/20260605-android-emulator-support/plans/20260605-android-emulator-execution-breakdown-v01.md`

Project-scoped Codex agents live in `.codex/agents/`.

Android subagent configs must run with full local access because this track
uses host adb/emulator commands, sibling worktrees, and external artifacts:

```toml
sandbox_mode = "danger-full-access"
approval_policy = "never"
```

## Agent Split

| Agent | Config | Execution steps | Primary write surface |
| --- | --- | --- | --- |
| Contract | `.codex/agents/tritonkit_android_contract_agent.toml` | Step 1, Step 13 | schema, capabilities, failure code tests |
| Fake ADB | `.codex/agents/tritonkit_android_fake_adb_agent.toml` | Step 2 | fake adb fixtures, parser tests |
| Device | `.codex/agents/tritonkit_android_device_agent.toml` | Step 3-7 | Android device doctor/list/resolve/wait/screenshot |
| App | `.codex/agents/tritonkit_android_app_agent.toml` | Step 8 | Android app lifecycle and open-url |
| Observe Smoke | `.codex/agents/tritonkit_android_observe_smoke_agent.toml` | Step 9-12, Step 14 | UIAutomator, smoke, evidence, replay proof |

Main agent owns Step 0, Step 15, Step 16, and Step 17.

## Parallelization

Batch 1 can run in parallel:

1. Contract agent.
2. Fake ADB agent.

Batch 2 can run after the Contract agent has at least stabilized `HostDevicePlatform.android` and schema placeholders, and Fake ADB has basic device fixtures:

1. Device agent.
2. App agent can begin command-builder work once selector/resolver contracts are known.

Batch 3 can begin when Device and App provide stable CLI surfaces:

1. Observe Smoke agent.

Do not let two subagents own the same implementation files in the same batch unless the main agent has explicitly split line-level responsibilities.

## Prompt Templates

Contract:

```text
Use tritonkit_android_contract_agent. Implement Android Emulator contract work from Step 1 and Step 13 only. Start with red tests. Do not implement adb runtime beyond compile-only stubs.
```

Fake ADB:

```text
Use tritonkit_android_fake_adb_agent. Implement fake adb fixtures and parser tests from Step 2 only. Do not modify schema or app/device runtime except minimal compile support.
```

Device:

```text
Use tritonkit_android_device_agent. Implement Step 3-7 for `triton device --platform android`. Depend on existing contract and fake adb fixtures. Do not implement app lifecycle or UIAutomator smoke.
```

App:

```text
Use tritonkit_android_app_agent. Implement Step 8 for `triton app --platform android`. Reuse the Android device selector. Do not treat adb success as business success.
```

Observe Smoke:

```text
Use tritonkit_android_observe_smoke_agent. Implement Step 9-12 and, if a real emulator is available, Step 14. Keep sensitive UI in artifacts, not stdout.
```

## Main Agent Checklist

Before spawning:

1. Check `git status --short --branch`.
2. If multi-day execution starts, create `../TritonKit-worktrees/20260605-android-emulator-support/` from `feat/20260605-android-emulator-support`.
3. Confirm no uncommitted user work will be overwritten.
4. Confirm every `.codex/agents/tritonkit_android_*_agent.toml` uses `sandbox_mode = "danger-full-access"` and `approval_policy = "never"`.
5. Assign each subagent a narrow step range and explicit non-goals.

During integration:

1. Pull subagent results in small batches.
2. Run focused tests after each batch.
3. Resolve conflicts centrally.
4. Do not let a subagent declare the feature complete.

Before final completion:

1. Run the directed Swift tests listed in Step 17.
2. Run `docs-linhay/scripts/verify.sh --local`, or document exact blockers.
3. Run real Android Emulator smoke when the environment is available.
4. Update README, dev docs, public skill if needed, memory, and qmd.
5. Report residual risks and unimplemented phases.

## Stop Conditions

Stop only when the feature is integrated and verified, the user pauses, or a concrete blocker prevents progress. Code changes alone are not completion.

---
name: tritonkit-real-device-subagent-orchestration
description: Use when orchestrating TritonKit cross-platform real-device support with project-scoped Codex subagents for contracts, iOS devicectl, Android adb real devices, Harmony hdc real devices, app lifecycle, smoke/evidence, and build-run planning.
metadata:
  version: 0.1.0-dev
---

# TritonKit Real Device Subagent Orchestration

## Trigger

Use this skill when the user asks to create, start, coordinate, or supervise subagents for iOS / Android / Harmony real-device support in TritonKit.

Always combine it with `tritonkit-subagent-supervision`: subagents do scoped implementation or design work, while the main agent owns boundary, integration, verification, docs, memory, and final completion judgment.

## Source of Truth

Read these first:

- `docs-linhay/spaces/20260608-cross-platform-real-device-takeover/README.md`
- `docs-linhay/spaces/20260608-cross-platform-real-device-takeover/technical-design.md`
- `docs-linhay/spaces/20260608-cross-platform-real-device-takeover/plans/p0-p3-plan.md`
- `docs-linhay/spaces/20260608-cross-platform-real-device-takeover/plans/20260608-subagent-execution-plan-v01.md`
- `docs-linhay/spaces/20260608-ios-real-device-takeover/README.md`
- `docs-linhay/spaces/20260608-ios-real-device-takeover/technical-design.md`

Project-scoped Codex agents live in `.codex/agents/`.

Real-device subagent configs must run with full local access because this track uses host tools (`devicectl`, `adb`, `hdc`), sibling worktrees, real-project artifacts, and evidence directories:

```toml
sandbox_mode = "danger-full-access"
approval_policy = "never"
```

## Agent Split

| Agent | Config | Phase | Primary write surface |
| --- | --- | --- | --- |
| Contract | `.codex/agents/tritonkit_real_device_contract_agent.toml` | P0/P1 | schema, DTOs, selectors, failure-code and evidence contracts |
| iOS Device | `.codex/agents/tritonkit_ios_real_device_agent.toml` | P0 | devicectl command builder/parser, iOS real-device readiness |
| Android Device | `.codex/agents/tritonkit_android_real_device_agent.toml` | P0 | adb real-device parser, Android real target readiness |
| Harmony Device | `.codex/agents/tritonkit_harmony_real_device_agent.toml` | P0 | HDC real-device parser, Harmony real target readiness |
| App Lifecycle | `.codex/agents/tritonkit_real_device_app_agent.toml` | P1 | cross-platform install/launch/open-url app lifecycle |
| Smoke Evidence | `.codex/agents/tritonkit_real_device_smoke_evidence_agent.toml` | P1/P3 | smoke, wait/assert proof, evidence, screenshots/log summaries |
| Build | `.codex/agents/tritonkit_real_device_build_agent.toml` | P2 | Xcode real-device build, Gradle, hvigor build-run planning |

## Parallelization

Batch 1 can run in parallel:

1. Contract agent.
2. iOS Device agent.
3. Android Device agent.
4. Harmony Device agent.

Batch 2 can run after target identity and resolver contracts are stable:

1. App Lifecycle agent.
2. Smoke Evidence agent can start fixture and evidence taxonomy work, but should not depend on unfinished app commands for live flows.

Batch 3 starts after P0/P1 surfaces are stable:

1. Build agent.

Do not let two subagents own the same implementation files in the same batch unless the main agent has explicitly split line-level responsibilities.

## Prompt Templates

Contract:

```text
Use tritonkit_real_device_contract_agent. Implement cross-platform real-device contract work from P0/P1 only. Start with red tests. Do not implement platform adapters beyond compile-only stubs.
```

iOS Device:

```text
Use tritonkit_ios_real_device_agent. Implement iOS real-device P0 for `triton device --platform ios --scope real`: devicectl doctor/list/resolve/wait-ready parser and fixtures. Do not implement app lifecycle or Xcode build-run.
```

Android Device:

```text
Use tritonkit_android_real_device_agent. Implement Android real-device P0 for `triton device --platform android --scope real`, distinguishing real devices from emulator serials. Do not implement app lifecycle or UIAutomator smoke.
```

Harmony Device:

```text
Use tritonkit_harmony_real_device_agent. Implement Harmony real-device P0 for `triton device --platform harmony --scope real`, distinguishing real HDC devices from DevEco emulator targets. Do not implement app lifecycle or uitest smoke.
```

App Lifecycle:

```text
Use tritonkit_real_device_app_agent. Implement cross-platform P1 app lifecycle for real devices: install, launch, open-url, terminate, info/list. Do not treat host action success as business readiness.
```

Smoke Evidence:

```text
Use tritonkit_real_device_smoke_evidence_agent. Implement cross-platform real-device smoke/evidence proof paths. Business pass must come from runtime, host layout, wait/assert, or evidence, not from host launch alone.
```

Build:

```text
Use tritonkit_real_device_build_agent. Implement or design P2 build-run contracts for iOS Xcode real-device, Android Gradle, and Harmony hvigor. Do not modify signing/certificate assets.
```

## Main Agent Checklist

Before spawning:

1. Check `git status --short --branch`.
2. Confirm the active space is `docs-linhay/spaces/20260608-cross-platform-real-device-takeover/`.
3. If multi-day execution starts, create `../TritonKit-worktrees/20260608-cross-platform-real-device-takeover/` from `feat/20260608-cross-platform-real-device-takeover`.
4. Confirm no uncommitted user work will be overwritten.
5. Confirm every `.codex/agents/tritonkit_*real_device*_agent.toml` uses `sandbox_mode = "danger-full-access"` and `approval_policy = "never"`.
6. Assign each subagent a narrow phase and explicit non-goals.

During integration:

1. Pull subagent results in batches.
2. Run focused tests after each batch.
3. Resolve conflicts centrally.
4. Do not let a subagent declare the whole feature complete.
5. Keep raw real-device logs, screenshots, serials, UDIDs, HDC targets, accounts, and private bundle ids out of public issue text.

Before final completion:

1. Run the directed Swift tests from `plans/p0-p3-plan.md`.
2. Run `docs-linhay/scripts/verify.sh --local`, or document exact blockers.
3. Run real-device smoke only when a suitable local device and artifact are available.
4. Update docs and memory.
5. Report residual risks and unimplemented phases.

## Stop Conditions

Stop only when the phase is integrated and verified, the user pauses, or a concrete blocker prevents progress. Subagent code changes alone are not completion.

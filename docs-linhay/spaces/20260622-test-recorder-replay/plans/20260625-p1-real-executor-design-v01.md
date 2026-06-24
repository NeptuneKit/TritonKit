# Test Recorder P1 Real Executor Design v01

> Space: `20260622-test-recorder-replay`
> Date: 2026-06-25
> Status: design gate, no implementation
> Scope: future `testrec replay --executor local-device` only

## Decision

Do not implement the real executor yet. This plan defines the minimum contract required before `local-device` can stop returning `unsupported_replay_executor`.

The executor must remain Triton-first: it talks to existing CLI/HTTP contracts for target discovery, action execution, observation, and evidence. It must not call `xcrun`, `adb`, `hdc`, DevEco, XcodeBuildMCP, or platform tools directly unless Triton schema/capabilities prove the required action is missing.

## P1 scope

Include:

1. local machine targets only: iOS Simulator, Android Emulator, HarmonyOS / DevEco Emulator;
2. one target per replay run;
3. deterministic contract execution from `compiled-contract.json`;
4. pre/post observation evidence for each page and action step;
5. fail-closed blockers for unsupported capabilities, redaction findings, missing target, ambiguous target, missing observation, and unsafe action;
6. `.tritonevidence` output compatible with current `triton evidence summary`.

Exclude:

- true devices;
- remote agents;
- device farm;
- Runtime extraction;
- Web/Wails control UI;
- live LLM/VLM decision authority;
- live network policy application;
- destructive lifecycle actions without explicit policy.

## Required inputs

The executor may run only when these are present:

- `.tritontestcase/compiled-contract.json`;
- `.tritontestcase/contract-capabilities.json`;
- target selector: `--platform <platform>` and optional `--device <selector>`;
- explicit `--evidence-dir <dir.tritonevidence>`;
- redaction gate clear: no `contract.redaction` finding unless a future approved-review artifact exists.

## Target discovery

Target discovery must use Triton facts first:

1. `triton status --json`
2. `triton doctor --json`
3. `triton capabilities --json`
4. `triton schema --command <command> --json`
5. target-specific Triton list/resolve command when exposed

The selected target evidence must be written to the evidence bundle as `target/target.json` and referenced by `run/replay-result.json.execution.targetRef`.

Failure codes:

- `target_not_found`
- `target_ambiguous`
- `target_not_ready`
- `target_capability_missing`

## Execution loop

For each replay step:

1. read dry-run plan;
2. capture before observation;
3. run page match if the step has a page precondition;
4. execute the planned Triton action command;
5. capture after observation;
6. emit one `testrec.replay.step` event;
7. stop on first failed, blocked, unsafe, or unsupported step.

The executor must not synthesize success from an action command exit code alone. A step passes only when command result and expected evidence are consistent.

## Device action execution

Action execution uses existing Triton action contracts only:

- `triton act tap ... --json`
- `triton act type ... --json`
- future `triton act scroll/swipe/... --json` only after schema exposes them

No direct platform fallback in the executor. If Triton cannot express the action, return `unsupported_action`.

Step result fields must keep current taxonomy:

- `executed`
- `failed`
- `skipped`
- `blocked`
- `not-run`

`simulated-passed` stays local-simulated only.

## Evidence capture

A real executor evidence bundle must contain at minimum:

```text
<run>.tritonevidence/
├── manifest.json
├── target/target.json
├── run/run.json
├── run/replay-result.json
├── run/events.jsonl
├── observations/
│   ├── step-001-before.json
│   ├── step-001-after.json
│   └── ...
└── screenshots/
    ├── step-001-before.png
    ├── step-001-after.png
    └── ...
```

Existing result / events / manifest consistency rules still apply:

- `run.summary.verdict` matches replay status;
- `manifest.run.eventCount` equals JSONL line count;
- every artifactRef resolves to a manifest artifact;
- every failure has `code`, `message`, `path`, and recovery command if one is known.

## Network boundary

P1 real executor does not apply network fixtures to live traffic. Network Map is evidence and planning input only.

Allowed statuses:

- `observed-only`
- `not-applied`
- `unsupported_network_policy`

Do not mark a live network policy as applied until a separate network policy plan defines proxy/runtime control and proof artifacts.

## Destructive policy

The real executor must not do these without an explicit future flag and policy artifact:

- boot/erase device;
- install/uninstall app;
- clear app data;
- reset simulator/emulator;
- change system proxy;
- accept OS permissions globally.

If a required destructive action is missing approval, return `destructive_action_requires_approval`.

## BDD acceptance

Scenario: missing target

- Given a compiled test case
- When `local-device` cannot resolve the requested target
- Then replay returns `blocked`
- And evidence contains `target_not_found`
- And no action command is executed

Scenario: unsupported action

- Given a compiled test case with an action not exposed by Triton schema
- When `local-device` plans execution
- Then the step is `blocked`
- And replay status is `blocked`
- And no platform fallback is attempted

Scenario: successful single action

- Given a ready local simulator target
- And a compiled test case with one supported action
- When `local-device` runs with `--evidence-dir`
- Then replay writes before/after observations
- And writes one step event
- And `triton evidence summary <dir> --json` reads the bundle

Scenario: redaction gate

- Given compiled contract quality findings include `contract.redaction`
- When `local-device` runs
- Then replay is `blocked`
- And no target action is executed

## First implementation slices

1. Add `local-device` dry-run executor profile acceptance tests for target requirement fields. Covered by `codex/20260625-testrec-local-device-profile` regression.
2. Add `local-device` non-dry-run fail-closed test that returns `target_not_found` without device action. Covered by `codex/20260625-testrec-local-device-target-gate` regression.
3. Add evidence writer parity for blocked local-device runs. Covered by `codex/20260625-testrec-local-device-evidence` regression.
4. Add schema readiness gate before target discovery, so `local-device` returns `target_capability_missing` when Triton action / observation schema cannot express the requested platform. Covered by `codex/20260625-testrec-local-device-readiness` regression.
5. Add one platform only after Triton action / observation schema proves enough capability. Android schema-ready evidence is covered by `codex/20260625-testrec-android-schema-ready`; target discovery still fail-closes as `target_not_found` and no device action executes.
6. Add target resolution evidence for `target_not_found` blocked runs. Covered by `codex/20260625-testrec-target-resolution-evidence`; writes `target/target-resolution.json` with Triton-first planned source commands and `commandsExecuted=false`.
7. Add more actions only after each action has one evidence-backed acceptance test.

## Stop rule

If a change needs Runtime abstraction, Web control, model decisioning, live network policy, or destructive device lifecycle control, stop and create a separate space.

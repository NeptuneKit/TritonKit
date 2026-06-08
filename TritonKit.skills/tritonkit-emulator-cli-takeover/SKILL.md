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

`triton capabilities --json` is the agent-facing environment matrix, not a flat help list. Each capability should expose `name`, `supported`, `reason`, `group`, `requiredBy`, `nextAction`, and `evidence` so an agent can choose between target selection, runtime connection, host tooling, action, assertion, and evidence capture without reading prose docs.

`triton doctor --json` is the ordered recovery view over that matrix. It should expose top-level `nextWorkflows`, plus `checks[].id`, `status`, `code`, `hint`, `nextAction`, `relatedCapabilities`, and `workflowCategories` so an agent can distinguish missing server, missing target/runtime, limited action surface, and available planning commands without re-joining doctor and capabilities by hand.

`triton plan ios-smoke|open-url|webview-check --json` is the first task planning layer. It should return ordered command recommendations for local emulator work, but it must not execute those commands or replace explicit wait/assert/evidence proof.

When `triton plan open-url ... --json` returns `mode=bootstrap` because the local server or runtime needs recovery, keep the bootstrap commands in `steps[]` and preserve the goal-specific workflow in `afterRecoverySteps[]`. Execute `steps[]` first, then execute `afterRecoverySteps[].argv` after recovery; do not discard the open-url/wait/screenshot/evidence workflow just because bootstrap is needed.

Harmony open-url planning should be schema-backed: `triton plan open-url --platform harmony --device <selector> --bundle <bundle> --ability <ability> --hap <path.hap> --url <url> --text <text> --evidence <dir.tritonevidence> --json` should produce install/open-url/wait/screenshot/evidence-summary steps when `--hap` is present.

`triton plan --json` should also expose `mode`, with `bootstrap` for environment recovery/discovery planning and `task` for goal-specific workflow planning. Emulator agents should use `mode` to decide whether to recover local simulator state first or proceed into a smoke/open-url/webview workflow.

`triton plan --json` should also expose top-level `nextWorkflows`. Emulator agents should be able to align plan routing with `doctor.nextWorkflows` and `capabilities[].requiredBy` directly, instead of inferring the lane only from `goal` or the first step command.

`plan.steps[]` should also expose `workflowCategories`. Emulator agents should be able to enter a concrete step and still know whether it belongs to `target`, `app`, `observe`, `route`, `assert`, `evidence`, `smoke`, or another workflow lane without rebuilding that mapping from command roots.

`triton plan inspect` and `triton replay --dry-run` steps should preserve the same `workflowCategories` vocabulary. Emulator agents should be able to compare offline replay planning and dry-run execution lanes without inventing a separate replay-specific taxonomy.

Bootstrap entry responses should expose top-level `surface` fields. Emulator agents should be able to distinguish `status`, `doctor`, `capabilities`, and `plan` JSON responses without relying on the invoking shell command string or surrounding logs.

Generic `triton plan --json` steps must also be executable Triton commands, not prose. If the runtime target is missing, the default connect step should point to `triton xcode run --json`; agents can then use schema/failure codes to choose a fallback.

`plan.nextStep` must be one of the returned `steps[].id` values. Do not make agents infer the first actionable command from an abstract category such as `observe`.

Task plan command strings must stay schema-aligned. If a plan recommends `triton <command> ...`, the root command, subcommand, and every `--flag` should be present in `triton schema --json`; fix schema or the plan before relying on undocumented arguments.

Subcommand-level `nextCommands[]` entries are recovery contracts too. When adding or changing host-device, app, sim, smoke, Xcode, evidence, or action subcommands, verify every subcommand suggestion against `triton schema --json`.

Command-level and subcommand-level `nextCommands[]` must be single `triton ...` invocations. Do not put pipes, redirects, command substitutions, or shell scripts into recovery suggestions; describe stdin or artifact prerequisites in schema metadata or surrounding docs.

Command-level and subcommand-level `nextCommands[]` lists must not contain blank entries or duplicates at the same level. Agents should be able to treat the list as ordered recovery candidates without ad hoc filtering.

Command-level and subcommand-level `nextCommands[]` roots must stay in the fixed recovery command taxonomy. Emulator recovery suggestions should point to known diagnostic, discovery, target, project/Xcode, observe, action, assert, evidence, replay, or smoke roots; do not introduce a new root command as a recovery suggestion without defining its recovery role and updating tests/docs/skills.

Each recovery root also needs a stable category: `diagnose`, `discover`, `prepare-target`, `project`, `observe`, `act`, `verify`, `archive`, `replay`, `smoke`, or `plan`. Use this to keep emulator recovery flows stage-aware instead of treating all next commands as an undifferentiated list.

Use schema `recoveryCommands[]` as the structured recovery surface when available. It mirrors `nextCommands[]` and adds `category`, so emulator workflows can distinguish target preparation, observation, action, verification, and evidence archive steps without parsing prose.

Use `plan.steps[].category` as the structured workflow stage when available. It uses the same category taxonomy as `recoveryCommands[]`, so emulator workflows can plan target preparation, project setup, action, verification, archive, smoke, and policy-review phases without re-parsing each command string.

For smoke/evidence/replay flows, `triton capabilities --json` should expose separate `evidence`, `evidence-summary`, `evidence-redact`, `capture`, `smoke-ios`, `smoke-harmony`, `record`, `plan-inspect`, `replay`, and `replay-dry-run` entries. `plan-inspect` only summarizes a `.tritonplan` offline, and `replay-dry-run` only validates it; neither is execution proof.

Every schema-level `providedCapabilities[]` entry must be discoverable through `triton capabilities --json`, with a non-`misc` `group`, a usable `nextAction`, and non-empty `evidence`. When adding emulator, host, app, Xcode, action, WebView, smoke, or evidence capabilities, update both the schema and capabilities matrix in the same slice.

Capability names are index keys and must be unique in both schema `providedCapabilities[]` and the capabilities matrix. Do not duplicate a capability name to express multiple transports; use group, requiredBy, evidence, or distinct capability names instead.

Capability metadata arrays must be clean: `requiredBy` and `evidence` values should be non-empty and unique per capability. Use distinct evidence names when a host-side flow produces multiple artifacts.

Capability `nextAction.category` values must match the same recovery category taxonomy used by schema `recoveryCommands[]` and `plan.steps[].category`. Emulator workflows should be able to route capability next actions by category without parsing the command root.

Doctor check `nextAction.category` values should be available through the doctor output contract as well. Emulator takeover agents should use doctor for ordered diagnostics and capabilities for the detailed matrix, while both surfaces share the same category vocabulary.

Doctor checks should also expose workflow taxonomy directly. `checks[].workflowCategories` must be derived from the referenced capabilities' `requiredBy[]`, and `doctor.nextWorkflows` should mirror the first actionable `fail`/`warn` check. Emulator agents should be able to pick a recovery lane from doctor alone, then consult capabilities only for deeper evidence and next-action detail.

Error envelope `nextAction.category` values should be visible in both schema failure shapes and any `TKCLIErrorDetail?` output contract. Emulator takeover agents should route recoverable failures by category instead of parsing prose hints or command roots.

Plan steps should expose `requires`, `expectedArtifacts`, and `stopConditions` arrays. Emulator takeover flows should use those fields to decide when to prepare a target, wait for runtime readiness, capture evidence, or stop after timeout/assertion/artifact failures.

Plan steps should expose executable `argv` arrays. Emulator takeover agents should execute `argv` directly and keep `command` for logging or human copy/paste, not as the primary machine contract.

`triton plan inspect <file.tritonplan> --json` should expose the same execution metadata vocabulary on `steps[]`: `argv`, `category`, `requires`, `expectedArtifacts`, `stopConditions`, and `validationErrors`. Use it to audit reusable emulator smoke flows offline before `replay --dry-run` or real replay.

`triton replay <file.tritonplan> --dry-run --json` should expose `argv`, `category`, `requires`, `expectedArtifacts`, and `stopConditions` on each returned step. Compare dry-run `steps[].argv` with inspect `steps[].argv` before executing emulator flows against a live app; keep `steps[].command` as the human-readable/logging form.

Replay dry-run should reject statically invalid emulator smoke steps before touching a runtime: multiple `tap` selectors, multiple `wait` conditions, missing `paste/type` text, and missing `wait` condition are validation failures.

Capability groups must stay in the fixed agent taxonomy: `action`, `assert`, `bootstrap`, `evidence`, `host`, `observe`, `replay`, `route`, `runtime`, `smoke`, `target`, `webview`, and `xcode`. Do not create near-duplicate groups or fall back to `misc` for new emulator, host, app, or evidence capabilities.

Capability `requiredBy` values must stay in the fixed workflow taxonomy: `action`, `app`, `assert`, `evidence`, `observe`, `project`, `replay`, `route`, `runtime`, `smoke`, `target`, `webview-check`, and `xcode`. Add a new workflow category only when it changes agent planning behavior, and update schema tests, docs, and public skills in the same slice.

Capability `evidence` values must stay in the fixed artifact taxonomy. For emulator takeover, new evidence names must correspond to real host command JSON, host artifacts, screenshots, host layout, runtime AX/snapshot/ledger, WebView provider output, input results, evidence bundles, smoke summaries, or replay plans; do not use prose labels as evidence identifiers.

Every capability must expose at least one evidence source. Low-level observe capabilities such as hierarchy, attrs, object, geometry, hit, and archive export should point to surface tree, runtime AX, hierarchy node, snapshot JSON, target resolution, screenshot metadata, or host artifact evidence instead of leaving the array empty.

Use `nextAction.requiresLongRunningProcess=true` only for actual process bootstrap that an agent must keep alive or wait on. In the current capabilities matrix this means the server bootstrap `serve --host 127.0.0.1 --port 19421`; emulator list, wait-ready, screenshot, action, smoke, evidence, and schema discovery next actions should stay one-shot commands.

Keep `nextAction.args` placeholders as complete argv tokens. Use `<selector>`, `<path>`, `<path.png>`, `<udid|booted>`, `<x,y>`, or similar standalone tokens; do not mix placeholders into partial strings that an agent would need to parse with ad hoc string logic.

Apply the same placeholder rule to schema `nextCommands[]`, schema examples, and plan step `argv`. Avoid `sim:<udid>` style partial placeholders in executable suggestions; use a standalone placeholder such as `<sim-target-id>`. Plan execution facts should stay pure Triton argv and should not depend on shell redirection syntax.

Plan step `command` values must still be single `triton ...` invocations for logging and copy/paste. Do not put pipes, redirects, command substitutions, or shell scripts into `plan.steps[].command`; agent execution should use `plan.steps[].argv`, and stdin or artifact prerequisites should live in step metadata.

Every command that exposes `providedCapabilities[]` must also expose parseable `outputContracts[]`: non-empty `selector`, non-empty `model`, non-empty field list, no duplicate field names, and non-empty field `name`, `type`, and `description`. Within one command, each `outputContracts[].selector` must be unique so an agent can map a selector to one output model. Any `subcommands[].outputSelectors[]` value must be covered by the parent command's `outputContracts[].selector` set. Emulator and host-side commands often return multiple envelope shapes; declare the stable primary output models instead of relying on prose.

Output contract field types must be machine-readable. Use scalar or DTO names, optional `?`, arrays `[Type]`, dictionaries `[Key:Value]`, or unions `TypeA|TypeB`; do not describe field types with prose.

Output contract models must also be machine-readable. Use stable model names, arrays, dictionaries, or unions; avoid prose such as "metadata dictionary" and avoid raw Swift generic snippets that agents would need to parse specially.

Output contract selectors and kinds must be stable agent keys. Use dot-separated lower-kebab selectors such as `host.device-list` and single lower-kebab kinds such as `host-device-list`; do not introduce spaces, camelCase, underscores, or prose labels.

Output contract formats must stay in the fixed taxonomy `json`, `jsonl`, and `archive`. Use `json` for single envelopes, `jsonl` for progress/event streams, and `archive` for inspectable artifacts; do not invent emulator-specific format labels in schema.

Output contract kinds must stay in the fixed agent taxonomy. When adding emulator, host, app, smoke, evidence, or runtime output models, add a stable kind with clear response/event/artifact semantics and update the schema tests, docs, and public skills in the same slice.

Every command with a failure surface must expose stable `failureCodes[]`. Host-side emulator commands may fail through HDC, simctl, artifact writing, target selection, or runtime transport; keep those codes explicit in schema so agents can classify recovery without scraping stderr.

Failure codes must be lower_snake_case and non-duplicated within each command or subcommand. Emulator recovery branches should consume `error.code` as-is instead of normalizing prose labels, hyphenated names, or aliases.

Subcommand failure codes must be covered by parent command failure codes. When adding host-device, app, sim, smoke, Xcode, or evidence subcommands, update the parent code set in the same slice.

Options and subcommands must expose enough metadata for agents to plan without reading source: non-empty option `name`, `type`, and `description`; non-empty subcommand `name` and `summary`; no duplicates inside the same parent command.

Command names, subcommand names, and pure long flag names are CLI routing keys. Keep root and subcommand names lower-kebab, and keep slash-separated long flag aliases such as `--refresh/--no-refresh` lower-kebab per alias.

Subcommand and task synopsis belongs in `usageForms[]`, not `options[]`. Emulator commands with many host-side forms such as `sim runtime ...`, `sim privacy ...`, `device alias set ...`, or `app open-url ...` should expose those forms through `usageForms[]` so agents can distinguish command shapes from flags.

Positional arguments belong in `argumentForms[]`, not `options[]`. Emulator commands that accept `<selector>`, `<path>`, `<text>`, `<bundle>`, or similar argv positions should expose them as argument forms; `options[]` should remain pure `--long-flag` metadata.

Subcommand parameter references must be covered by the parent schema. If an emulator, app, sim, smoke, Xcode, evidence, or action subcommand declares `requiredOptions[]`, `optionalOptions[]`, or `oneOfRequiredOptions[]`, every referenced flag or positional argument must exist in the parent command's `options[]` or `argumentForms[]`.

Command-level `requiredOptions[]` is for direct command invocation only. If a command exposes `subcommands[]`, keep subcommand-specific requirements on the subcommand and do not summarize them on the parent command with prose or `subcommand:--flag` strings.

Default providers and inherited defaults must be schema-backed Triton commands. Use values such as `triton xcode use` or `triton sim use`; do not put raw tool names, README references, or prose setup notes into `defaultProviders[]` or `inheritsDefaultsFrom[]`.

Command and subcommand `artifacts[]` values must stay in the fixed schema artifact taxonomy. For emulator and host flows, use stable names such as `simulator-screenshot`, `simulator-video`, `simulator-logs`, `simulator-diagnostics`, `app-container`, `app-preferences`, `harmony-layout`, `screenshot`, `evidence-bundle`, `stdout-log`, `stderr-log`, `trace`, and `coverage-json`.

JSONL long-running event contracts must be stable. Keep `jsonlEvents[]` as dot-separated event keys, keep subcommand final events concrete such as `xcode.build.summary`, and ensure `finalEventKind` appears in the same `jsonlEvents[]` list.

Retryable host commands and subcommands must expose recovery `nextCommands[]`. If an emulator, Xcode, xctrace, coverage, app, evidence, or smoke command is marked retryable, agents need a schema-backed next command to recover, continue, or archive evidence.

Failure-code-bearing commands and subcommands must also expose a recovery path. If a command has `failureCodes[]`, keep command-level `nextCommands[]` non-empty; if a subcommand has `failureCodes[]`, provide subcommand-level `nextCommands[]` or make sure the parent command recovery path is usable for that failure surface. This applies even when the command is not marked retryable, such as action or observation commands that can fail through target resolution or runtime transport.

Failure-code families must map to recovery categories. Host emulator failures such as target unavailable, runtime disconnected, host command timeout, unsupported actions, artifact output rejection, and assertion mismatch should all be classifiable into the fixed recovery category taxonomy before agents choose concrete recovery commands.

Artifact and output failure codes must expose an archive-oriented recovery path. If simulator video, screenshot, logs, diagnostics, trace, coverage, or plan output fails because a path is rejected, a write fails, or output is too large, `recoveryCommands[]` should include an `archive` category such as evidence/capture/export/screenshot/xcresult so the agent can preserve failure context.

Assertion, route, and text-not-found failures must expose a verification-oriented recovery path. If an emulator smoke, wait, assert, route, find, or semantic action reports `assertion_failed`, `route_mismatch`, or `text_not_found`, `recoveryCommands[]` should include a `verify` category such as wait/assert/route so the agent can re-check the expected state.

Runtime transport failures must expose a diagnostic recovery path. If embedded runtime or host-adapter commands report `server_unavailable`, `request_failed`, `request_timeout`, `runtime_unavailable`, or `runtime_not_connected`, `recoveryCommands[]` should include a `diagnose` category such as status/doctor/capabilities so the agent can check server, target, runtime, and hierarchy/cache state before retrying.

Target failures must expose a target-preparation recovery path. If emulator, simulator, app, Xcode, observation, action, assertion, evidence, smoke, or replay commands report `ambiguous_target`, `device_not_ready`, `simulator_not_found`, `target_not_found`, `target_offline`, or `target_unavailable`, `recoveryCommands[]` should include a `prepare-target` category such as `triton target resolve <selector> --json` so the agent can resolve, select, or wait for the target before continuing.

Project and Xcode failures must expose a project recovery path. If build, test, run, xcresult, xctrace, coverage, smoke, or app launch flows report `ambiguous_workspace`, `invalid_workspace_path`, `scheme_not_found`, `workspace_not_found`, or `xcode_not_idle`, `recoveryCommands[]` should include a `project` category such as `triton xcode discover --path . --json` so the agent can rediscover workspace/project/scheme context before retrying.

Action and replay step failures must expose an action recovery path. If emulator, runtime, smoke, replay, or batch input flows report `action_failed` or `step_failed`, `recoveryCommands[]` should include an `act` category such as `triton input --json --summary --strict` so the agent can return to an executable action surface with a strict summary gate.

Destructive and confirmation failures must expose a planning recovery path. If simulator, emulator, app lifecycle, runtime maintenance, or host-state commands report `confirmation_required` or `destructive_action_requires_policy`, `recoveryCommands[]` should include a `plan` category such as `triton plan --format json` so the agent can return to a policy-aware planning step before executing a destructive command.

Unsupported failures must expose a planning recovery path. If emulator, embedded runtime, WebView, semantic action, or provider-backed commands report `action_not_supported`, `unsupported_capability`, `unsupported_runtime_scope`, `webview_method_not_allowed`, or `webview_wait_unsupported`, `recoveryCommands[]` should include a `plan` category such as `triton plan --format json` so the agent can choose a supported capability or alternate workflow instead of retrying the unsupported command.

Command-level `outputFormats[]` values must stay in the fixed taxonomy `text`, `json`, `jsonl`, `logs`, `tree`, `auto`, `archive`, `file`, and `json-metadata`, with no duplicates inside one command. This is the selectable CLI output mode, separate from `outputContracts[].format`.

Examples are agent-facing argv samples. Keep `triton sim`, `triton app`, `triton device`, `triton smoke`, and action examples schema-backed: every example flag must be declared in `triton schema --json`, including host-only flags such as `--duration`, `--style`, `--confirm`, `--dry-run`, `--bundle`, `--ability`, `--user-only`, and `--kind`.

Each schema example must contain exactly one extractable `triton` invocation. Pipelines and stdin preparation are acceptable for examples such as batch input, but do not put multiple `triton` calls into one example; multi-step emulator workflows belong in `triton plan`, `.tritonplan`, or procedural docs.

Action capability `nextAction` values must match the current executable schema. Use `swipe --start-x/--start-y/--end-x/--end-y`, `clear --at x,y`, and `input --json --summary --strict`; embedded `press` remains unsupported and should point to schema/diagnostics rather than claiming host HID availability.

Host capability `nextAction` values must also be schema-aligned. For example, Harmony app install uses `app install --platform harmony --hap <path.hap>`, while iOS install uses `--app <path.app>`; simulator artifacts should expose documented `--simulator`, `--output`, `--bundle-id`, and `--payload` flags in `triton schema --command sim --json`.

## Integration Guide Contract

When changing iOS / Harmony / CLI onboarding or usage guides, keep these entry points aligned:

- `README.md` must split iOS embedded runtime, Harmony host-side adapter, Harmony embedded SDK, and CLI install/run guidance.
- `tritonkit-dev-feedback` must be able to guide external users through iOS, Harmony, or CLI adoption before filing feedback.
- `tritonkit-real-project-regression` must treat iOS and Harmony apps as external systems under test, using host-side checks when embedded runtime is not required.
- Harmony docs must state that host-side HDC / DevEco Emulator control does not require embedded SDK integration.
- Harmony embedded SDK docs must state package id/import path `tritonkit`, Debug-only runtime, Release disabled/no-op behavior, provider-owned business semantics, and `--runtime-base-url` direct checks while standalone.
- CLI docs must keep Homebrew as the released install path and local `swift build --package-path CLI --scratch-path .build/cli -c release --product triton` as the unreleased-source fallback.

## Current Implemented Surface

Cross-platform host device entry:

```bash
triton device doctor --platform ios --json
triton device doctor --platform harmony --json
triton device list --platform ios --json
triton device list --platform harmony --json
triton device alias set iphone15 --platform ios --target <simulator-udid> --json
triton device alias set harmony-a --platform harmony --target <hdc-target> --json
triton device use iphone15 --json
triton device current --json
triton device resolve iphone15 --json
triton device wait-ready --device iphone15 --json
triton device wait-ready --device harmony-a --json
triton device screenshot --device iphone15 --output /tmp/<case>-sim.png --json
triton device screenshot --device harmony-a --output /tmp/<case>.jpeg --json
triton device stop --platform harmony --hvd "Codex Test Phone" --path ~/.Huawei/Emulator/deployed --confirm --json
```

Use `--device <selector>` as the default agent-facing target selector for common host-side commands. Selectors can be aliases, full ids such as `sim:<udid>` / `harmony:<target>`, raw platform ids, `booted`, or `current`. `--platform`, `--name`, `--runtime`, `--state`, and `--ready` are filters; they may auto-select only when the filtered candidate set is unique. Keep `sim` for iOS-only advanced maintenance; `device runtime-url --device <selector>` is the Harmony embedded runtime port-forward setup path, and `--platform harmony --target <target>` remains the direct raw-target form.

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
triton smoke ios --device iphone15 --bundle-id <bundle-id> --open-url '<url>' --wait-text '<text>' --screenshot /tmp/<case>.png --evidence /tmp/<case>.tritonevidence --json
```

HarmonyOS / DevEco Emulator:

```bash
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device use harmony-a --json
triton device wait-ready --device harmony-a --json
triton app inspect --platform harmony --bundle <bundle> --json
triton app install --device harmony-a --hap <debug-signed.hap> --json
triton app launch --device harmony-a --bundle <bundle> --ability <ability> --json
triton smoke harmony --device harmony-a --bundle <bundle> --ability <ability> --open-url '<url>' --wait-text '<text>' --screenshot /tmp/<case>.jpeg --evidence /tmp/<case>.tritonevidence --json
triton observe current --device harmony-a --json
triton observe tree --device harmony-a --json
triton node resolve --device harmony-a --text "登录" --json
triton tap "登录" --platform harmony --device harmony-a --json
triton swipe --platform harmony --device harmony-a --start-x 350 --start-y 900 --end-x 350 --end-y 300 --json
triton type "hello" --platform harmony --device harmony-a --json
triton paste "hello" --platform harmony --device harmony-a --json
```

For Harmony host actions, schema exposes host-side output selectors alongside embedded runtime contracts. Parse `tap --platform harmony` as `host.harmony-tap`, `swipe --platform harmony` as `host.harmony-swipe`, and `type` / `paste --platform harmony` as `host.harmony-text-input`; do not reuse the embedded `input.result` parser for those host outputs. Parse `wait --platform harmony` as `host.harmony-wait`; do not reuse the embedded `wait.result` parser. Parse `ax/screenshot --platform harmony` as `host.harmony-artifact`; do not reuse `host.artifact`. Parse `press --platform harmony` as `host.harmony-key-action`; do not reuse `host.key-action`. Treat `clear --platform harmony` as an explicit unsupported boundary (`harmony-clear-text`) until a stable host clear primitive exists, and treat any reappearance of legacy selectors (`host.tap`, `host.swipe`, `host.text-input`, `host.wait`) as schema regression.

Standalone Harmony embedded HTTP runtime:

```bash
triton device runtime-url --device harmony-a --probe-manifest --json
# Compatibility path:
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
triton xctrace record --template "Time Profiler" --device <SIMULATOR_UDID> --time-limit 5s --output /tmp/<case>.trace --json
triton coverage report --xcresult /tmp/<case>.xcresult --output /tmp/<case>-coverage.json --json
```

`triton evidence summary` / `inspect` now expose `primaryArtifacts[]`; agent should inspect those first before traversing the entire artifact set.

`triton replay ... --json` should also be consumed top-down: check `failedStepIndex`, `failureCode`, `failureError`, `failureWorkflowCategories[]`, `failureRecoveryCategories[]`, `failurePrimaryArtifacts[]`, `recoveryCommands[]`, and `suggestedCommands[]` before traversing every replay step. Then inspect the failed step `error` payload when present, including `wait/input/evidence` failures that only returned `ok=false`. If `failureError.nextAction` exists, expect replay recovery commands to expose the same path. Prefer replay failures that preserve runtime/target/transport error codes directly; treat unnecessary fallback to `step_failed` as a control-surface bug.

`webview list/current` 当前是 Web 容器候选发现能力，证据可能来自 WebView provider、iOS runtime AX/tree 或 Harmony host layout。先读取 `primarySource`：WebView 语义优先 `webview-provider`，其次 `runtime-tree`，再次 `host-layout`。`webview current-url/snapshot/call/events/wait` 与 `route assert-current-url` 是 provider 级能力：只断言 provider URL 或读取 provider 显式暴露的 bounded snapshot、allowlist bridge 与 page events，不操作 H5 页面，也不是任意 JavaScript eval。没有 WebView provider 时，输出必须保持 `candidateOnly=true`、`providerStatus=unavailable`、`bridgeStatus=unavailable`，并在 `missingCapabilities` 中声明 `webview.url`、`webview.dom`、`webview.bridge-call`、`webview.tap`、`webview.type` 等缺失项；不得把 AX/WebKit 容器误报为 DOM/JS/bridge 可用。Harmony 侧若未注册 WebView provider，也只能保持 host-only layout/candidate 边界，不能声明页面 bridge 可用。

When multiple iOS Simulator apps connect to the same `triton serve`, embedded runtime targets use stable ids shaped as `triton:ios-simulator:<SIMULATOR_UDID>`. Runtime commands may pass either the full target id or the simulator UDID. If more than one runtime target is connected and the command still uses the default `triton:local`, the expected result is `error.code=ambiguous_target`, not last-connection wins.

For the Harmony demo, `28767` is the host-access embedded runtime port exposed through HDC `fport`; `18765` is the device-to-host gateway fallback port.

When debugging Harmony direct runtime defaults, verify against a real HDC target before changing CLI defaults:

```bash
TRITON_BIN=.build/cli-scratch/debug/triton docs-linhay/scripts/verify-harmony-runtime-emulator-smoke.sh --target <hdc-target> --no-forward
```

Use `--no-forward` when the HDC fport already exists, because repeating `hdc fport tcp:28767 tcp:28767` can fail with a host listen conflict even though the existing forwarded endpoint is healthy. Keep mock contract smoke separate from real emulator smoke: the mock script should use an isolated test port while asserting the schema/default output remains `28767`.

Android Emulator host-side support is now part of the implemented local CLI takeover surface. Treat `adb`-backed device discovery, readiness, screenshot, app lifecycle, UIAutomator observe/wait/tap, and `smoke android` as schema-backed Triton commands; continue to keep DTOs, evidence, and command-ledger schemas platform-neutral across iOS, Android, and Harmony.

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
.build/cli/debug/triton app uninstall --device booted --bundle-id com.example.missing --confirm --json
.build/cli/debug/triton app launch --device booted --bundle-id com.example.missing --json
.build/cli/debug/triton device list --platform harmony --json
.build/cli/debug/triton device wait-ready --device <hdc-target> --json
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-runtime-base-url-smoke.sh
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-runtime-emulator-smoke.sh --target <hdc-target> --no-forward
```

Avoid erasing emulators, uninstalling business apps, installing data bundles, changing privacy/location, or collecting broad logs unless the current task explicitly requires it and the command records policy metadata.

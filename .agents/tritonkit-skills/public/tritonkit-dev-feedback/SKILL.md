---
name: tritonkit-dev-feedback
description: Use when Codex is helping someone try, adopt, evaluate, or integrate TritonKit during its development stage, especially when the user has any requirement, bug, missing capability, confusing behavior, documentation gap, or compatibility concern that should become a GitHub issue in NeptuneKit/TritonKit. The AI agent should reproduce or clarify the finding, collect evidence, and submit the GitHub issue directly instead of asking the user to file it themselves.
metadata:
  version: 0.1.0-dev
---

# TritonKit Dev Feedback

## Principle

TritonKit is in active development. Treat any user need, bug report, rough edge, missing API, unclear documentation, or integration friction as valid feedback for the repository.

The AI agent owns the issue filing action. Do not tell the user to open an issue when the agent has enough context and GitHub access; create the issue directly.

Repository: `NeptuneKit/TritonKit` (`https://github.com/NeptuneKit/TritonKit`)

## Workflow

1. Clarify only the minimum missing detail needed to avoid filing a wrong issue.
2. If the user is adopting TritonKit, first choose the matching checklist below:
   - iOS app embedded runtime: SwiftPM/CocoaPods plus Debug-only bootstrap.
   - Harmony host-side validation: `triton device/app --platform harmony` without embedded runtime.
   - Harmony embedded SDK: package id/import path `tritonkit`, Debug-only runtime, provider-based app semantics, and `--runtime-base-url` checks while standalone.
   - CLI-only use: Homebrew release install by default, local source build only for unreleased validation.
3. Reproduce or inspect locally when possible. Prefer machine-readable TritonKit checks:
   - `triton evidence --name <case> --output /tmp/<case>.tritonevidence --json`
   - `triton evidence inspect /tmp/<case>.tritonevidence --json`
   - `triton evidence summary /tmp/<case>.tritonevidence --json`
   - first read `primaryArtifacts[]` from the summary/manifest before scanning the full artifact list
   - `triton evidence redact /tmp/<case>.tritonevidence --profile ios-private --output /tmp/<case>-redacted.tritonevidence --json`
   - `triton capture --case <case> --output /tmp/<case>.tritonevidence --json`
   - `triton assert text-exists|text-not-exists <text> --json`
   - `triton record --output /tmp/<case>.tritonplan --json` when a reusable plan template helps describe the flow
   - `triton plan inspect /tmp/<case>.tritonplan --json`
   - `triton replay /tmp/<case>.tritonplan --dry-run --json` before sharing a reusable flow
   - when replay fails, preserve `failedStepIndex`, `failureCode`, `failureError`, `failureWorkflowCategories[]`, `failureRecoveryCategories[]`, `failurePrimaryArtifacts[]`, `recoveryCommands[]`, and `suggestedCommands[]` from `triton replay ... --json` instead of flattening the failure into a generic "replay failed"; preserve the failed step `error` payload too when present, including `wait/input/evidence` failures that returned `ok=false` without throwing; if `failureError.nextAction` exists but replay recovery commands do not expose the same recovery path, report it as a replay recovery-consistency bug; if the payload downgraded a clear runtime/target/transport error to `step_failed`, report it as a replay failure-routing bug
   - `triton status --json`
   - `triton doctor --json`
   - `triton capabilities --json`
   - `triton schema --json`
   - `triton schema --command <name> --json` for the exact command being reported; every command in the schema inventory must be individually discoverable.
   - `triton plan --json`
   - `triton plan ios-smoke|open-url|webview-check --json` when feedback depends on a multi-step agent workflow; task plans are recommendations and must not be reported as execution proof.
   - `triton runtime manifest --json`
   - `triton snapshot --include app,scene,route,ax,geometry --json`
   - `triton ledger --limit 50 --jsonl`
   - Treat `triton doctor --json` as ordered diagnostics: preserve top-level `nextWorkflows`, plus each check's `id`, `status`, `code`, `hint`, `nextAction`, `relatedCapabilities`, and `workflowCategories` when reporting a recovery path.
   - Treat `triton capabilities --json` as an environment capability matrix: preserve `capabilities[].group`, `requiredBy`, `nextAction`, and `evidence` when reporting why an agent could or could not run a workflow; schema-provided capabilities should never be reported as complete if they are missing any of those planning fields.
   - Treat missing or invalid top-level bootstrap `surface` fields as contract bugs. `status`, `doctor`, `capabilities`, and `plan` responses should identify their own entry surface directly in JSON, not only via command context.
   - Treat duplicate capability names in either schema `providedCapabilities[]` or `triton capabilities --json` as indexing bugs.
   - Treat empty or duplicate values in `capabilities[].requiredBy` or `capabilities[].evidence` as capability metadata quality bugs.
   - Treat unknown `capabilities[].group` values as taxonomy bugs. Valid groups are `action`, `assert`, `bootstrap`, `evidence`, `host`, `observe`, `replay`, `route`, `runtime`, `smoke`, `target`, `webview`, and `xcode`.
   - Treat unknown `capabilities[].requiredBy` values as workflow taxonomy bugs. Valid workflow categories are `action`, `app`, `assert`, `evidence`, `observe`, `project`, `replay`, `route`, `runtime`, `smoke`, `target`, `webview-check`, and `xcode`.
   - Treat unknown `capabilities[].evidence` values as artifact taxonomy bugs. Evidence names must map to real stdout JSON, schema/status output, host artifacts, runtime snapshots, WebView provider output, route assertions, input results, evidence bundles, smoke summaries, tritonplans, Xcode artifacts, or unsupported envelopes.
   - Treat an empty `capabilities[].evidence` array as a capability contract bug. Even diagnostics, unsupported capabilities, and low-level observe commands must expose at least one evidence source.
   - Treat `capabilities[].nextAction` as an executable schema-backed recommendation; if it uses a root command, subcommand, or `--flag` absent from `triton schema --json`, report that mismatch as a contract bug.
   - Treat unexpected `nextAction.requiresLongRunningProcess=true` as a contract bug unless the action is the server bootstrap command `serve --host 127.0.0.1 --port 19421`.
   - Treat malformed `nextAction.args` placeholders as contract bugs. Placeholder values must be complete argv tokens such as `<selector>` or `<dir.tritonevidence>`, not partial string fragments.
   - Treat missing or invalid `nextAction.category` as a capability contract bug. The category should match the nextAction command root's recovery taxonomy value, such as `diagnose`, `prepare-target`, `project`, `observe`, `act`, `verify`, `archive`, `replay`, `smoke`, or `plan`.
   - Treat missing `doctor.checks[].nextAction.category` in the doctor output contract as a diagnostic contract bug. Doctor checks should expose the same category vocabulary as capabilities and plan steps.
   - Treat missing or invalid `doctor.checks[].workflowCategories` as a diagnostic planning bug. Doctor should expose the workflow taxonomy implied by `relatedCapabilities`, so agents do not need to re-derive it from the capabilities matrix before choosing recovery.
   - Treat missing or invalid `doctor.nextWorkflows` as a diagnostic planning bug. The first actionable `fail`/`warn` check should already expose its affected workflow taxonomy at the doctor root.
   - Treat missing or invalid `plan.nextWorkflows` as a planning routing bug. `triton plan --json` should expose the same workflow taxonomy lane vocabulary as `doctor` and `capabilities`, so an agent can align recovery and execution planning without inferring it only from `goal` or command strings.
   - Treat missing or invalid `plan.steps[].workflowCategories` as a planning routing bug. Agents should be able to enter a concrete plan step and still read the affected workflow lane directly, without falling back to root-command heuristics.
   - Treat missing or invalid `triton plan inspect ... --json` or `triton replay ... --dry-run --json` step `workflowCategories` as replay routing bugs. Inspect and dry-run should preserve the same workflow lane vocabulary as doctor, capabilities, and task plan steps.
   - Treat missing `error.nextAction.category` in any `TKCLIErrorDetail?` output contract as an error-envelope contract bug. Failure recovery should expose the same category vocabulary as capabilities, doctor checks, and plan steps.
   - Treat schema `failureShape` values that advertise `nextAction?` without its `category` field as recovery contract bugs.
   - Treat malformed placeholders in `schema.nextCommands[]`, `schema.examples[]`, or `plan.steps[].argv` as contract bugs. Plans should emit Triton argv, not shell redirection or partial placeholder strings.
   - Treat shell control operators in `plan.steps[].command` as plan contract bugs. A plan step command should be a single `triton ...` invocation; stdin/file requirements belong in metadata.
   - Treat `triton plan ... --json` as schema-backed recommendations: if a returned command uses an undocumented root command, subcommand, or `--flag`, report it as a schema/plan contract bug with the exact plan step and `triton schema --json` excerpt.
   - Treat missing or invalid `plan.mode` as a plan contract bug. `bootstrap` should mean environment recovery/discovery planning, and `task` should mean goal-specific workflow planning.
   - Treat natural-language plan commands as plan contract bugs. `steps[].argv` should describe an executable Triton invocation, and `steps[].command` should remain a matching human-readable/logging form with non-empty `id`, `title`, `when`, and `expected`.
   - Prefer `plan.steps[].argv` over parsing `plan.steps[].command`; treat missing or empty `argv` as a plan execution contract bug.
   - Treat `plan.nextStep` values that do not match any returned `steps[].id` as plan contract bugs; agents should be able to jump directly to the next step.
   - Treat missing or invalid `plan.steps[].category` as a plan contract bug. The category should match the command root's recovery taxonomy value, such as `diagnose`, `prepare-target`, `project`, `observe`, `act`, `verify`, `archive`, `replay`, `smoke`, or `plan`.
   - Treat missing or empty `plan.steps[].requires`, `plan.steps[].expectedArtifacts`, or `plan.steps[].stopConditions` as plan contract bugs. Agents should not infer prerequisites, evidence, or stop/re-plan gates from prose.
   - Treat missing `steps[].argv`, `steps[].category`, `steps[].requires`, `steps[].expectedArtifacts`, `steps[].stopConditions`, or `steps[].validationErrors` in `triton plan inspect <file.tritonplan> --json` as replay-plan inspect contract bugs. Agents should be able to audit reusable `.tritonplan` flows offline before dry-run or execution.
   - Treat missing `steps[].argv`, `steps[].category`, `steps[].requires`, `steps[].expectedArtifacts`, or `steps[].stopConditions` in `triton replay <file.tritonplan> --dry-run --json` as replay result contract bugs. Dry-run `steps[].argv` should expose substituted argv tokens and enough metadata to compare against `plan inspect` before real execution; keep `steps[].command` as the human-readable/logging form.
   - Treat replay dry-run accepting a statically invalid step as a validation bug. Examples: `tap` with multiple selectors, `wait` with multiple conditions, `paste/type` without `value` or `text`, or `wait` without a condition.
   - Treat schema `nextCommands[]` as recovery contracts. If a next command references an undocumented command, subcommand, or `--flag`, file it as a schema self-consistency bug.
   - Treat subcommand `nextCommands[]` the same way; a subcommand recovery suggestion must still be a schema-backed `triton ...` command.
   - Treat shell control operators in command-level or subcommand-level `nextCommands[]` as recovery contract bugs; next commands should be single `triton ...` invocations.
   - Treat blank or duplicate command-level/subcommand-level `nextCommands[]` entries as recovery list quality bugs; agents should not need to filter or deduplicate recovery candidates.
   - Treat `nextCommands[]` root commands outside the documented recovery command taxonomy as recovery taxonomy bugs. New recovery roots need an explicit role in diagnostics, discovery, target selection, project/Xcode, observation, action, assertion, evidence, replay, or smoke.
   - Treat recovery roots without a stable category as taxonomy bugs. Valid recovery categories are `diagnose`, `discover`, `prepare-target`, `project`, `observe`, `act`, `verify`, `archive`, `replay`, `smoke`, and `plan`.
   - Prefer schema `recoveryCommands[]` over raw `nextCommands[]` when reporting agent recovery planning. Each entry should mirror one next command and expose `{command, category}`; mismatches are schema wire contract bugs.
   - Treat unmapped `failureCodes[]` families as recovery taxonomy bugs. Each stable `error.code` should map to one or more valid recovery categories before an agent turns it into reusable recovery logic; exact command-level recovery coverage may be narrower and should be reported separately.
   - Treat artifact/output failure codes without an `archive` recovery category as recovery coverage bugs. Codes such as `artifact_output_rejected`, `artifact_write_failed`, `file_write_failed`, `overwrite_refused`, and `xcresult_output_too_large` should lead to evidence, capture, export, screenshot, xcresult, or another archive-oriented command.
   - Treat assertion/route/text-not-found failure codes without a `verify` recovery category as recovery coverage bugs. Codes such as `assertion_failed`, `route_mismatch`, and `text_not_found` should lead to wait/assert/route-style verification commands.
   - Treat runtime transport failure codes without a `diagnose` recovery category as recovery coverage bugs. Codes such as `server_unavailable`, `request_failed`, `request_timeout`, `runtime_unavailable`, and `runtime_not_connected` should lead to status/doctor/capabilities-style diagnostic commands.
   - Treat target failure codes without a `prepare-target` recovery category as recovery coverage bugs. Codes such as `ambiguous_target`, `device_not_ready`, `simulator_not_found`, `target_not_found`, `target_offline`, and `target_unavailable` should lead to target/device/sim/app-style preparation commands, preferably `triton target resolve <selector> --json`.
   - Treat Project / Xcode failure codes without a `project` recovery category as recovery coverage bugs. Codes such as `ambiguous_workspace`, `invalid_workspace_path`, `scheme_not_found`, `workspace_not_found`, and `xcode_not_idle` should lead to Xcode project discovery/defaults commands, preferably `triton xcode discover --path . --json`.
   - Treat action/step failure codes without an `act` recovery category as recovery coverage bugs. Codes such as `action_failed` and `step_failed` should lead to executable action commands, preferably `triton input --json --summary --strict`.
   - Treat destructive/confirmation failure codes without a `plan` recovery category as recovery coverage bugs. Codes such as `confirmation_required` and `destructive_action_requires_policy` should lead to planning or policy review commands, preferably `triton plan --format json`.
   - Treat unsupported failure codes without a `plan` recovery category as recovery coverage bugs. Codes such as `action_not_supported`, `unsupported_capability`, `unsupported_runtime_scope`, `webview_method_not_allowed`, and `webview_wait_unsupported` should lead to capability-boundary planning commands, preferably `triton plan --format json`.
   - Treat a command with `providedCapabilities[]` but no `outputContracts[]` as an incomplete agent-facing schema; include the command name and the missing output contract in the issue.
   - Treat an `outputContracts[]` entry with empty `selector`, empty `model`, empty `fields[]`, duplicate field names, or empty field `name` / `type` / `description` as a low-signal schema bug; report the command and selector.
   - Treat natural-language `outputContracts[].fields[].type` values as schema field type bugs. Field types should use machine-readable scalar/DTO names, optional `?`, arrays `[Type]`, dictionaries `[Key:Value]`, or unions `TypeA|TypeB`.
   - Treat natural-language or Swift-generic `outputContracts[].model` values as schema model bugs. Model values should use the same machine-readable scalar/DTO, optional, array, dictionary, or union grammar.
   - Treat malformed `outputContracts[].selector` or `kind` values as agent key bugs. Selectors should be dot-separated lower-kebab segments; kinds should be a single lower-kebab key.
   - Treat any `outputContracts[].format` outside `json`, `jsonl`, or `archive` as an output taxonomy bug. New formats must define how agents parse, stream, or archive the result before entering schema.
   - Treat unknown `outputContracts[].kind` values as output model taxonomy bugs. New kinds must define the agent-facing response, event, or artifact semantics before consumers rely on them.
   - Treat duplicate `outputContracts[].selector` values within the same command as schema lookup bugs; an agent must be able to use a selector to identify one output model unambiguously.
   - Treat any `subcommands[].outputSelectors[]` value that is absent from the parent command's `outputContracts[].selector` set as a schema lookup bug.
   - Treat a command with `exitCodeOnFailure != 0` or a non-empty `failureShape` but empty `failureCodes[]` as a recovery contract bug; agent workflows need stable codes, not only prose failure text.
   - Treat non-lower_snake_case or duplicate `failureCodes[]` values as recovery contract bugs. Agents should be able to map `error.code` directly to a recovery branch without normalizing casing, hyphens, spaces, or duplicate aliases.
   - Treat a subcommand `failureCodes[]` entry that is absent from the parent command `failureCodes[]` as a schema consistency bug; parent schemas should expose the complete recovery code set.
   - Treat empty or duplicate option names, empty option types/descriptions, empty subcommand names/summaries, or duplicate subcommands as schema quality bugs.
   - Treat malformed command names, subcommand names, or pure long flag names as CLI key bugs. Root commands and subcommands should be lower-kebab; `options[].name` values that start with `--` may be slash-separated aliases such as `--language/--lang`, but each alias should remain lower-kebab.
   - Treat Subcommand / Task entries left in `options[]` as schema-shape bugs. Command usage synopsis belongs in `usageForms[]` with `form`, `kind`, and `description`.
   - Treat positional arguments left in `options[]` as schema-shape bugs. Positional arguments belong in `argumentForms[]` with `name`, `type`, `required`, and `description`; pure flags belong in `options[]`.
   - Treat `subcommands[].requiredOptions[]`, `optionalOptions[]`, or `oneOfRequiredOptions[]` entries that are absent from the parent command's `options[]` or `argumentForms[]` as schema reference bugs. A subcommand must not require flags or positional arguments that the parent schema does not expose.
   - Treat non-empty command-level `requiredOptions[]` on commands that also expose `subcommands[]` as schema-shape bugs. Subcommand requirements belong on the specific subcommand; command-level requirements are only for direct command invocations without subcommands.
   - Treat `defaultProviders[]` or `inheritsDefaultsFrom[]` values that are not schema-backed `triton ...` commands as planning contract bugs. Defaults should point to executable setup commands, not prose or tool names.
   - Treat unknown or duplicate command-level or subcommand-level `artifacts[]` values as schema artifact taxonomy bugs. Artifact names should map to stable evidence files, host artifacts, runtime snapshots, logs, traces, coverage, screenshots, or bundle components.
   - Treat malformed or duplicate `jsonlEvents[]` values as JSONL event contract bugs. Event keys should be dot-separated stable keys; command-level templates may use a complete placeholder token such as `<action>`, while subcommands should use concrete action names.
   - Treat `finalEventKind` values absent from the same schema object's `jsonlEvents[]` as JSONL completion contract bugs.
   - Treat `retryable=true` without non-empty `nextCommands[]` as a recovery contract bug. Retryable commands should tell agents how to recover, continue, or capture evidence after an uncertain result.
   - Treat `failureCodes[]` without any recovery command path as a recovery contract bug. A command with failure codes needs non-empty command-level `nextCommands[]`; a subcommand with failure codes needs either subcommand-level `nextCommands[]` or a parent command recovery path.
   - Treat empty, duplicate, or unknown command-level `outputFormats[]` values as command taxonomy bugs. Valid values are `text`, `json`, `jsonl`, `logs`, `tree`, `auto`, `archive`, `file`, and `json-metadata`.
   - Treat examples as executable schema samples. If an example uses a command, subcommand, or `--flag` absent from schema, report it as a schema/example contract bug; include the exact example.
   - Treat schema examples containing zero or multiple `triton` invocations as schema/example contract bugs. An example may include `printf`, a shell pipeline, or stdin preparation, but it must expose exactly one reusable Triton invocation for agents to extract.
   - When reporting smoke/evidence/replay readiness, keep `evidence`, `evidence-summary`, `evidence-redact`, `capture`, `smoke-ios`, `smoke-harmony`, `record`, `plan-inspect`, `replay`, and `replay-dry-run` separate; `plan-inspect` is offline `.tritonplan` summary inspection, `replay-dry-run` is offline validation, and smoke success still needs wait/assert/evidence proof.
   - WebView checks:
     - `triton webview list --platform ios --json`
     - `triton webview current --platform ios --json`
     - `triton webview current-url --platform ios --json`
     - `triton route assert-current-url '<expected-url>' --platform ios --json`
     - `triton webview call <method> --platform ios --json`
     - `triton webview events --platform ios --limit 50 --json`
     - iOS `webview list/current` can expose visible `WKWebView` candidates from runtime AX/tree; read `primarySource` first to distinguish provider-backed facts from runtime-tree or host-layout candidates;
     - `primarySource` priority for `webview list/current` is `webview-provider`, then `runtime-tree`, then `host-layout`; `webview current-url` and route URL assertions require provider URL metadata;
     - `webview call/events` require a page or app opt-in allowlist bridge and must not be reported as arbitrary JavaScript eval;
     - Harmony without a registered WebView provider is host-only: layout candidates are useful evidence, but DOM, URL, JS, and bridge capabilities must remain unsupported;
     - when reporting `triton capabilities --json`, keep `webview-list/current` separate from provider-level `webview-current-url/snapshot/bridge-call/events/wait` and `route-current-url-assert`.
   - iOS embedded runtime target checks:
     - `triton list --json` should expose iOS Simulator runtime targets as `triton:ios-simulator:<SIMULATOR_UDID>` with `simulatorUDID`;
     - pass either `--target triton:ios-simulator:<SIMULATOR_UDID>` or `--target <SIMULATOR_UDID>` when multiple simulator apps are connected;
     - when multiple runtime targets are connected and the command still relies on default `triton:local`, expect `error.code=ambiguous_target` instead of last-connection wins.
   - host-side simulator checks that do not require embedded runtime:
     - `triton sim list --json`
     - `triton device alias set iphone15 --platform ios --target <udid> --json` for repeated multi-simulator validation;
     - prefer `--device <alias-or-id>` on common host-side commands; use `--simulator booted|<udid>` only when an iOS-specific selector is clearer;
     - `triton sim use <udid> --json`
     - `triton sim boot <udid> --wait --jsonl`
     - `triton sim screenshot --simulator booted --output /tmp/<case>-sim.png --json`
     - `triton app list --device iphone15 --user-only --json`
     - `triton app info --device iphone15 --bundle-id <bundle-id> --json`
     - `triton app install --device iphone15 --app <path.app> --json`
     - `triton app uninstall --device iphone15 --bundle-id <bundle-id> --confirm --json`
     - `triton app launch --device iphone15 --bundle-id <bundle-id> --json`
     - `triton app terminate --device iphone15 --bundle-id <bundle-id> --json`
     - `triton app open-url '<url>' --device iphone15 --json`
     - `triton app open-url '<url>' --device iphone15 --wait-ready --snapshot --json`
     - `triton app container --device iphone15 --bundle-id <bundle-id> --kind data --json`
     - `triton app prefs get <key> --device iphone15 --bundle-id <bundle-id> --json`
     - `triton app prefs set <key> <json-value> --device iphone15 --bundle-id <bundle-id> --json`
     - `triton sim pair <watch-udid> <phone-udid> --json`
     - `triton sim unpair <pair-uuid> --json`
     - `triton sim clone <udid> "Clone for Smoke" --json`
     - `triton sim erase <udid> --confirm --json`
     - `triton sim upgrade <udid> <runtime-id> --json`
     - `triton sim runtime list --json`
     - `triton sim runtime verify <runtime-id> --json`
     - `triton sim runtime delete all --dry-run --json`
     - `triton sim runtime delete <runtime-id> --confirm --json`
     - `triton sim runtime match list --json`
     - `triton sim runtime dyld-cache remove <runtime-id> --confirm --json`
     - `triton sim personalization scan-and-personalize --json`
     - destructive maintenance commands should be checked with `--confirm` or `--dry-run` before filing feedback.
   - host-side Harmony checks that do not require embedded runtime:
     - `triton device doctor --platform harmony --json`
     - `triton device list --platform harmony --json`
     - `triton device alias set harmony-a --platform harmony --target <hdc-target> --json` for repeated multi-emulator validation;
     - `triton device wait-ready --device harmony-a --json`
     - `triton device stop --platform harmony --hvd <hvd-name> --path <deployed-path> --confirm --json` when Triton's `triton-harmony-emulator` launchd keepalive job started the HVD;
     - `triton app inspect --platform harmony --bundle <bundle> --target <hdc-target> --json`
     - `triton app install --device harmony-a --hap <debug-signed.hap> --json`
     - `triton app launch --device harmony-a --bundle <bundle> --ability <ability> --json`
     - `triton app open-url --device harmony-a --bundle <bundle> --ability <ability> '<url>' --json`
     - `triton ax --platform harmony --target <hdc-target> --output /tmp/<case>-layout.json --json`
     - `triton wait --platform harmony --target <hdc-target> --text '<text>' --timeout 15 --json`
     - `triton tap '<text>' --platform harmony --target <hdc-target> --json`
     - for `ax/screenshot --platform harmony`, parse `host.harmony-artifact` instead of `host.artifact`;
     - for `tap/swipe/type/paste --platform harmony`, parse the host output contracts (`host.harmony-tap`, `host.harmony-swipe`, or `host.harmony-text-input`) instead of assuming the embedded `input.result` model;
     - for `press --platform harmony`, parse `host.harmony-key-action` instead of `host.key-action`;
     - for `wait --platform harmony`, parse `host.harmony-wait` instead of assuming the embedded `wait.result` model;
     - for `clear --platform harmony`, expect explicit `unsupported_capability`; capabilities should expose `harmony-clear-text` as unsupported with a schema-backed next action, not as an executable host action;
     - treat any reappearance of legacy selectors (`host.tap`, `host.swipe`, `host.text-input`, `host.wait`) as a schema regression bug;
     - `triton screenshot --device harmony-a --output /tmp/<case>.jpeg --json`
     - `triton smoke harmony --device harmony-a --bundle <bundle> --ability <ability> --open-url <url> --wait-text <text> --screenshot /tmp/<case>.jpeg --evidence /tmp/<case>.tritonevidence --json`
     - when multiple HDC targets are `Connected`, expect `error.code=ambiguous_target` and pass `--device <alias-or-id>` or an explicit `--target`.
     - host-side layout and screenshot artifacts may contain private UI data; inspect or summarize instead of attaching raw files when redaction is uncertain.
     - when a disposable HarmonyOS NEXT smoke app is needed, use the local `harmony-next` skill's `references/quickStart/ets/minimal-project-scaffold.md` and copy `references/templates/empty-ability-app/` instead of hand-rolling `oh-package.json5` / `module.json5` / `hvigorfile.ts`.
   - Harmony embedded SDK feedback should distinguish generic HAR capability from app-provided semantics:
     - run `triton device runtime-url --device harmony-a --probe-manifest --json` first when the runtime is on a Harmony emulator/device and the host needs an HDC fport base URL; if you already have the raw HDC target id, `--platform harmony --target <hdc-target>` is the direct explicit form;
     - Harmony demo host-access embedded runtime defaults to `http://127.0.0.1:28767`; `18765` is the demo device-to-host gateway fallback port and should not be treated as the host direct runtime default;
     - if an HDC fport already exists, use `docs-linhay/scripts/verify-harmony-runtime-emulator-smoke.sh --target <hdc-target> --no-forward` to verify the live endpoint without re-registering the same port mapping;
     - use `triton runtime manifest --runtime-base-url http://127.0.0.1:<port> --json`, `triton state route --runtime-base-url ... --json`, `triton snapshot --runtime-base-url ... --json`, `triton ledger --runtime-base-url ... --jsonl`, and `triton set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url ... --json` when validating a standalone embedded HTTP runtime before it is connected through `triton serve`;
     - generic runtime endpoints may return `unsupported_runtime_scope` for scene, route, responder, semantic actions, input, screenshot, hit-test, or system alerts;
     - if the app registers scene / route / responder / action providers, verify that `runtime.manifest` dynamically marks those capabilities as supported;
     - report missing provider hooks as feature requests, and report falsely-supported capabilities as bugs.
   - Xcode workflow feedback should include the smallest machine-readable evidence path available:
     - `triton schema --command xcode --json`, `triton schema --command xcresult --json`, and `triton schema --command coverage --json` when reporting command contract mismatches;
     - `triton xcode discover --path . --json` and the selected `triton xcode use ... --json` command, with private paths and scheme/app names redacted;
     - `triton xcode build --jsonl --timeout <seconds>` or `triton xcode test --result-bundle /tmp/<case>.xcresult --jsonl`, preserving stdout/stderr artifact paths and error codes;
     - `triton xcresult summary --path /tmp/<case>.xcresult --json` and `triton xcresult failures --path /tmp/<case>.xcresult --json` for test failures; these are redacted by default, and `--include-sensitive` must not be used for public issue material;
     - `triton coverage report --xcresult /tmp/<case>.xcresult --output /tmp/<case>-coverage.json --json` only when coverage is relevant; attach summaries, not raw private coverage files;
     - clearly state whether `xcode run` only reached build/install/launch or whether runtime `status/wait/assert/screenshot/evidence` also proved business readiness.
   - `triton find "HTTP"`, `triton tap "HTTP"`, `triton type "hello"`, `triton paste "console"`, or `triton clear` for agent-facing action checks; these default to JSON, and `--format text` is only for human-readable debugging.
   - For form flows, prefer semantic embedded actions when available: `triton focus "用户名" --json`, `triton set-text "用户名" "alice" --json`, `triton set-text "密码" "$TRITON_PASSWORD" --secure --json`, `triton select-segment "协议" "HTTP" --json`, and `triton set-switch "记住我" on --json`.
   - When the same text appears multiple times, run `triton find "<text>" --all` first; if you know a point inside the intended candidate, prefer `triton tap "<text>" --at x,y`, otherwise use `triton tap "<text>" --index <n>` or `triton tap "<text>" --within x,y,width,height`.
   - When `tap` or `assert` fails, preserve the JSON envelope's nearest candidates / nearestText, candidateCount, and suggestedCommands in the issue summary instead of reducing it to "not found".
   - relevant `swift test`, smoke scripts, or app-level reproduction steps.
4. Redact before filing or preparing an issue:
   - replace private project names, app names, bundle IDs, team IDs, organization names, user names, account IDs, email addresses, phone numbers, local usernames, internal domains, and absolute private paths with stable placeholders such as `<private-app>`, `<bundle-id>`, `<team-id>`, `<user>`, `<account>`, `<internal-host>`, and `<repo-path>`;
   - keep reproducibility-critical public facts such as platform, OS/tool versions, TritonKit version, command names, error codes, sanitized route shape, and minimal redacted snippets;
   - do not attach full private logs, screenshots with personal data, unredacted `.tritonevidence`, `.tritonplan`, `.xcresult`, HDC/Simulator dumps, or app archives;
   - inspect evidence manifests and artifact names before upload; if redaction cannot be verified, summarize the evidence instead of attaching it.
5. Classify the issue:
   - `bug`: behavior is broken, unstable, misleading, or inconsistent with documented/schema behavior.
   - `feature`: user needs a new capability or extension.
   - `docs`: documentation, onboarding, examples, or CLI help are unclear.
   - `question`: only if no concrete change is identifiable yet.
6. Create the issue with `gh issue create --repo NeptuneKit/TritonKit`.
7. Report the issue URL back to the user with a short summary and any local verification result.

## iOS App Integration Guide

Use this when helping someone add TritonKit to an app.

### Package Manager

SwiftPM:

```text
https://github.com/NeptuneKit/TritonKit.git
```

Add the `TritonKit` product to the iOS app target. Keep every app-side source file that imports or starts TritonKit behind `#if DEBUG`; do not rely only on the library's Release no-op behavior.

SwiftPM / Xcode package product dependencies do not have a CocoaPods-style `:configurations => ['Debug']` switch. The supported SwiftPM path is source-level Debug isolation with the dedicated bootstrap file below, plus TritonKit's Release no-op runtime. If the production Release target must not link TritonKit at all, create a separate Debug-only app target or scheme and attach the `TritonKit` product only to that target.

CocoaPods during development, restricted to Debug configurations:

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'TritonKitShared',
      :git => 'https://github.com/NeptuneKit/TritonKit.git',
      :branch => 'main',
      :configurations => ['Debug']
  pod 'TritonKit',
      :git => 'https://github.com/NeptuneKit/TritonKit.git',
      :branch => 'main',
      :configurations => ['Debug']
end
```

### App Bootstrap

Put TritonKit bootstrap code in a dedicated iOS file and wrap the entire file in `#if DEBUG`. For team apps, prefer an opt-in Debug bootstrap so ordinary Debug builds do not expose the runtime unless the developer explicitly enables it.

```swift
// TritonKitDebugBootstrap.swift
#if DEBUG
import Foundation
import TritonKit

enum TritonKitDebugBootstrap {
    static func startIfEnabled() {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let isEnabled = arguments.contains("--triton-enabled")
            || environment["TRITON_ENABLED"] == "1"
            || UserDefaults.standard.bool(forKey: "TRITON_ENABLED")

        guard isEnabled else { return }

        TritonKit.shared.start { config in
            config.endpoint = .environment()
            config.autoReconnect = true
            config.features = [.hierarchy, .accessibility, .input]
            config.redaction.secureText = .lengthOnly
            config.redaction.collectClipboard = false
            config.redaction.collectNetwork = false
            config.redaction.collectLogs = false
            config.appIdentity = .init(name: "YourApp", tags: ["debug", "opt-in"])
        }
    }

    static func stop() {
        TritonKit.shared.stop()
    }
}
#endif
```

Enable it from Xcode with launch argument `--triton-enabled`, environment variable `TRITON_ENABLED=1`, or Debug-only user default `TRITON_ENABLED=true`. `config.endpoint = .environment()` reads `TRITON_HOST` / `TRITON_PORT` and falls back to `127.0.0.1:19421`. Use `TritonKit.shared.start { config in config.endpoint = .device("192.168.1.20", port: 19421) }` when a physical device needs to connect to a Mac LAN address.

Preferred facade APIs:

| Need | API |
| --- | --- |
| Start with environment fallback | `TritonKit.shared.start()` |
| Start with explicit local CLI port | `TritonKit.shared.start(.local(port: 19421))` |
| Start from environment variables | `TritonKit.shared.start(.environment())` |
| Start from a device to a Mac LAN address | `TritonKit.shared.start(.device("192.168.1.20", port: 19421))` |
| Start with advanced options | `TritonKit.shared.start { config in ... }` |
| Stop the debug runtime | `TritonKit.shared.stop()` |
| Observe connection state | `TritonKit.shared.onStateChange { state in ... }` |
| Observe connection errors | `TritonKit.shared.onError { error in ... }` |

For advanced debug bootstrap code, keep the same file-level `#if DEBUG` guard and configure the facade in one closure:

```swift
#if DEBUG
TritonKit.shared.start { config in
    config.endpoint = .device("192.168.1.20", port: 19421)
    config.autoReconnect = true
    config.features = [.hierarchy, .accessibility, .input]
    config.redaction.secureText = .lengthOnly
    config.appIdentity = .init(name: "YourApp", tags: ["smoke"])
}
#endif
```

Observe connection status without implementing a full delegate:

```swift
#if DEBUG
enum TritonKitDebugObservers {
    private static var stateToken: TritonKit.ObservationToken?
    private static var errorToken: TritonKit.ObservationToken?

    static func start() {
        stateToken = TritonKit.shared.onStateChange { state in
            print("TritonKit state:", state)
        }
        errorToken = TritonKit.shared.onError { error in
            print("TritonKit error:", error)
        }
    }
}
#endif
```

Retain observation tokens for as long as callbacks are needed, and call `cancel()` when an observer should be removed. `start` retains the default request handler internally; only use the lower-level `delegate` / `connect(host:port:)` API when you need a custom delegate or custom message routing.

Then call it only from a Debug branch in AppDelegate:

```swift
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        TritonKitDebugBootstrap.startIfEnabled()
        #endif

        return true
    }
}
```

For SwiftUI, keep the same dedicated Debug bootstrap file and call it from a guarded `onAppear`:

```swift
import SwiftUI

@main
struct YourApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    #if DEBUG
                    TritonKitDebugBootstrap.startIfEnabled()
                    #endif
                }
        }
    }
}
```

### CLI Installation And Verification

For released TritonKit builds, install or update the macOS CLI with Homebrew first:

```bash
brew install NeptuneKit/tap/triton
brew update
brew upgrade triton
```

When the report depends on unreleased source changes, or Homebrew / GitHub Release assets are unavailable, build and use the local release CLI:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
.build/cli/release/triton version --json
```

If installing that build into an existing `PATH` location while `triton serve` may be running from the old binary, stop the server first or replace the executable atomically:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
cp .build/cli/release/triton ~/.local/bin/triton.new
mv ~/.local/bin/triton.new ~/.local/bin/triton
triton version --json
```

Start the macOS server before launching the app:

```bash
triton serve --host 127.0.0.1 --port 19421
```

For physical devices, bind to a reachable Mac interface and set `TRITON_HOST` to the Mac LAN IP:

```bash
triton serve --host 0.0.0.0 --port 19421
```

Then verify:

```bash
triton status --json
triton list --json
triton runtime manifest --json
triton state app --json
triton state scene --json
triton state route --json
triton state responder --json
triton sim list --json
triton sim use 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json
triton sim boot 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --wait --jsonl
triton app list --device booted --user-only --json
triton app info --device booted --bundle-id com.example.app --json
triton app install --device booted --app /tmp/Demo.app --json
triton app uninstall --device booted --bundle-id com.example.app --confirm --json
triton app launch --device booted --bundle-id com.example.app --json
triton app open-url 'example://debug' --device booted --json
triton app container --device booted --bundle-id com.example.app --kind data --json
triton app prefs get DEBUG-mock --device booted --bundle-id com.example.app --json
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device wait-ready --device 127.0.0.1:10100 --json
triton app inspect --platform harmony --bundle com.example.app --target 127.0.0.1:10100 --json
triton app launch --device 127.0.0.1:10100 --bundle com.example.app --ability EntryAbility --json
triton hierarchy --json
triton ax --json
triton ax --target 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json
triton runtime manifest --json
triton tap "first-check"
triton type "hello"
triton find "hello" --all
triton tap "hello" --at 240,580
triton tap "hello" --index 2
triton hit --at 240,580 --json
triton press home
triton assert text-exists first-check --json
triton evidence --name first-check --output /tmp/first-check.tritonevidence --json
triton capture --case first-check --output /tmp/first-check.tritonevidence --json
triton record --output /tmp/first-flow.tritonplan --json
triton replay /tmp/first-flow.tritonplan --dry-run --var username=alice --var password-env=TRITON_PASSWORD --json
```

If more than one iOS Simulator app connects to the same `triton serve`, use `triton list --json` to read `simulatorUDID` and pass it as `--target`. The full target id also works: `triton:ios-simulator:<SIMULATOR_UDID>`. A default `triton:local` command returning `ambiguous_target` is the expected safe behavior in that state.

### Network Notes

- For physical devices or local-network testing, add `NSLocalNetworkUsageDescription` to the app target if iOS prompts for local network access.
- If App Transport Security blocks cleartext local development traffic, use a debug-only ATS exception. Do not ship broad ATS exceptions in production.
- Release builds should compile, but `TritonKit.isRuntimeEnabled` is false and the embedded runtime does not connect, collect hierarchy, upload data, or respond to control messages. App-side integration files should still be explicitly wrapped in `#if DEBUG` so production entry points do not import or start TritonKit.

## Harmony App Integration Guide

Use this when helping someone validate TritonKit with HarmonyOS / DevEco Emulator or add the Harmony embedded SDK to a Harmony app.

### Choose The Harmony Path

| Need | Path | App package change |
| --- | --- | --- |
| Discover emulator targets, wait for readiness, inspect/launch apps | Host-side HDC adapter through `triton device/app --platform harmony` | No |
| Validate app-process manifest, snapshot, ledger, state providers, and semantic actions | Harmony embedded SDK direct runtime checks | Yes, Debug-only |

Host-side Harmony validation does not require a running TritonKit embedded runtime:

```bash
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device wait-ready --device 127.0.0.1:10100 --json
triton app inspect --platform harmony --bundle com.example.app --target 127.0.0.1:10100 --json
triton app launch --device 127.0.0.1:10100 --bundle com.example.app --ability EntryAbility --json
```

If multiple HDC targets are `Connected`, pass `--device <alias-or-id>` or an explicit `--target`; `ambiguous_target` is the expected machine-readable failure.

For Harmony embedded SDK work, use the TritonKit brand name but keep the actual OHPM package id and ArkTS import path lowercase:

```text
tritonkit
```

Until a published OHPM package exists, use the aligned `harmony-TritonKit` source/HAR for validation. Keep business app integration Debug-only. Release builds must expose disabled/no-op behavior and must not collect UI, screenshots, logs, route state, or action data.

Business semantics must be app-provided. A generic HAR should return `unsupported_runtime_scope` for route, responder, semantic action, input, screenshot, hit-test, or system-alert capabilities unless the app registers the matching provider. Missing provider hooks are feature requests; falsely-supported capabilities are bugs.

When validating a standalone embedded HTTP runtime before it is connected through `triton serve`, first ask Triton to prepare or discover the HDC fport URL, then use direct runtime commands:

```bash
triton device alias set harmony-a --platform harmony --target 127.0.0.1:10100 --json
triton device runtime-url --device harmony-a --probe-manifest --json
triton runtime manifest --runtime-base-url http://127.0.0.1:28767 --json
triton state route --runtime-base-url http://127.0.0.1:28767 --json
triton snapshot --runtime-base-url http://127.0.0.1:28767 --json
triton ledger --runtime-base-url http://127.0.0.1:28767 --jsonl
triton set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:28767 --json
```

For the Harmony demo, `28767` is the host-access embedded runtime port exposed through HDC `fport`; `18765` is the device-to-host gateway fallback port used by the demo UI. If an HDC fport already exists, use `docs-linhay/scripts/verify-harmony-runtime-emulator-smoke.sh --target <hdc-target> --no-forward` to verify the live endpoint without re-registering the same port mapping.

### Distribution Notes

- Repository: `https://github.com/NeptuneKit/TritonKit`
- Local source fallback: build `.build/cli/release/triton` from `CLI/Package.swift` when validating unreleased changes.
- Manual local CLI updates must use a temporary file plus `mv`, or stop `triton serve` before replacing the active binary path.
- Released Homebrew install path: `brew install NeptuneKit/tap/triton`.
- Homebrew updates come from `NeptuneKit/homebrew-tap` after release automation has run.
- Homebrew installs only the macOS CLI. iOS embedded runtime still uses SwiftPM/CocoaPods; Harmony embedded SDK uses the Harmony package/source path.
- GitHub Release assets include `triton-macos-arm64.tar.gz`, `triton-macos-x86_64.tar.gz`, `tritonkit_checksums.txt`, and project skill packages.
- If Homebrew or GitHub Release assets are unavailable, use the local release build and include the missing distribution evidence in the issue.

## Issue Content

Use a concise, reproducible issue body:

```markdown
## Background
<What the user was trying to do. Mention TritonKit is in active development if relevant.>

## Current Behavior
<Observed behavior, error envelope, sanitized logs, screenshots, or command output.>

## Expected Behavior
<What should happen or what capability is needed.>

## Reproduction / Evidence
<Commands, sanitized app/simulator context, files, versions, and whether reproduction was confirmed.>

## Proposed Next Step
<Smallest useful product or engineering action.>
```

Title format:

- `[Bug] <short behavior>`
- `[Feature] <short capability>`
- `[Docs] <short documentation gap>`
- `[Question] <short uncertainty>`

## Boundaries

- File issues for development-stage feedback even when the request is exploratory.
- If GitHub auth or network access blocks issue creation, state the blocker and provide the exact `gh issue create` command and issue body that should be run.
- Do not include secrets, private tokens, local-only credentials, full private logs, real project names, private bundle IDs, user names, account identifiers, emails, phone numbers, internal hostnames, or absolute private filesystem paths.
- Do not upload evidence bundles or screenshots until they have been checked for private project or personal information. Prefer sanitized excerpts and manifest summaries when in doubt.
- When attaching a `.tritonplan`, keep secrets as `${variable}` placeholders and document the expected `--var key-env=ENV_NAME` bindings instead of writing secret values into the issue.
- Do not create duplicate issues if an existing open issue clearly covers the same feedback; comment on the existing issue instead when appropriate.
- Keep implementation work separate from feedback filing unless the user explicitly asks for a fix in the same turn.

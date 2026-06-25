# Schema and contract feedback

Use this for machine-readable CLI contract problems: `schema`, `doctor`, `capabilities`, `plan`, `replay`, `evidence`, output contracts, failure envelopes, recovery commands, and taxonomy.

## Baseline commands

```bash
triton status --json
triton doctor --json
triton capabilities --json
triton schema --json
triton schema --command <name> --json
triton plan --json
```

Every command in the schema inventory must be individually discoverable with `triton schema --command <name> --json`.

## Capability and diagnostics rules

File feedback when:

- `status`, `doctor`, `capabilities`, or `plan` lacks a top-level `surface`.
- Capability names are duplicated.
- `capabilities[].group`, `requiredBy`, or `evidence` contains unknown, empty, or duplicate values.
- `capabilities[].nextAction` references an undocumented command, subcommand, or flag.
- `nextAction.category`, `doctor.checks[].nextAction.category`, `doctor.checks[].workflowCategories`, `doctor.nextWorkflows`, `plan.nextWorkflows`, or `plan.steps[].workflowCategories` is missing or outside the recovery taxonomy.
- `nextAction.requiresLongRunningProcess=true` is used for a one-shot command or lacks lifecycle events.

Valid capability groups include `action`, `assert`, `bootstrap`, `evidence`, `host`, `observe`, `semantic`, `replay`, `route`, `runtime`, `smoke`, `target`, `webview`, and `xcode`.

Valid recovery categories include `diagnose`, `discover`, `prepare-target`, `project`, `observe`, `act`, `verify`, `archive`, `replay`, `smoke`, and `plan`.

## Plan and replay rules

File feedback when:

- A plan command is natural language, shell control flow, or not a single schema-backed `triton ...` invocation.
- `steps[].argv` is missing, empty, malformed, or inconsistent with `steps[].command`.
- `plan.nextStep` does not match a returned step id.
- `steps[].category`, `requires`, `expectedArtifacts`, `stopConditions`, or `validationErrors` is missing where applicable.
- `plan inspect` or `replay --dry-run` drops argv, category, requirements, expected artifacts, stop conditions, validation errors, or workflow categories.
- Replay dry-run accepts statically invalid steps, such as tap with multiple selectors, wait with multiple conditions, paste/type without value, or wait without a condition.
- Replay failure routing downgrades clear runtime/target/transport errors to generic `step_failed`.
- `failureError.nextAction` and replay `recoveryCommands[]` disagree.

Preserve `failedStepIndex`, `failureCode`, `failureError`, `failureWorkflowCategories[]`, `failureRecoveryCategories[]`, `failurePrimaryArtifacts[]`, `recoveryCommands[]`, `suggestedCommands[]`, and failed step error payloads.

## Recovery and failure-code rules

File feedback when:

- `nextCommands[]` or `recoveryCommands[]` contains shell operators, blanks, duplicates, unknown roots, undocumented flags, or mismatched categories.
- `failureCodes[]` is missing, duplicated, not lower_snake_case, unmapped to recovery categories, or present on a subcommand but absent from the parent.
- Artifact/output failures lack `archive` recovery.
- Assertion/text/route failures lack `verify` recovery.
- Runtime transport failures lack `diagnose` recovery.
- Target failures lack `prepare-target` recovery.
- Project/Xcode failures lack `project` recovery.
- Action/step failures lack `act` recovery.
- Destructive/confirmation and unsupported failures lack `plan` recovery.

## Output contract rules

File feedback when:

- A command has `providedCapabilities[]` but no `outputContracts[]`.
- An output contract has empty selector/model/fields, duplicate fields, empty field name/type/description, or unsupported format.
- Model or field types are natural-language prose instead of machine-readable scalar/DTO/optional/array/dictionary/union grammar.
- Selectors or kinds are malformed, duplicated, or not referenced correctly by subcommands.
- Options, subcommands, positional arguments, usage forms, examples, artifacts, JSONL events, or final event kinds are malformed, duplicated, or inconsistent with schema.

Treat examples as executable schema samples: they should expose exactly one reusable Triton invocation, with any stdin/file setup represented as metadata or a separate preparation step.

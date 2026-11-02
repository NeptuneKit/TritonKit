# Schema And Capability Contracts

Use this reference when real-project automation depends on `doctor`, `capabilities`, `schema`, `plan`, output contracts, recovery commands, or failure categories.

## Fact Source Order

Preserve:

```bash
triton doctor --json
triton status --json
triton capabilities --json
triton schema --json
```

Use `doctor.checks[]` first for ordered recovery. Preserve `doctor.nextWorkflows` and check `workflowCategories`.

Use `capabilities[].group`, `requiredBy`, `nextAction`, and `evidence` to decide the next stage.

## Treat As TritonKit Contract Bugs

Report a TritonKit issue before building reusable regression logic when any of these appear:

- duplicate capability names
- empty or duplicate `requiredBy` / `evidence`
- unknown capability groups, workflow categories, or evidence values
- malformed `nextAction.args` placeholders
- `nextAction.requiresLongRunningProcess=true` on one-shot commands
- blank or duplicate `nextCommands[]`
- recovery roots without stable categories
- failure codes without category-appropriate recovery commands
- missing `plan.steps[].argv`, `category`, `requires`, `expectedArtifacts`, `stopConditions`, or `validationErrors`
- schema examples using undeclared commands or flags
- output contracts with empty selector/model/fields
- duplicate output contract selectors
- non-lower_snake_case or duplicate failure codes

Prefer structured `recoveryCommands[]` over parsing prose `nextCommands[]`.

Prefer `plan.steps[].argv` over parsing `plan.steps[].command`.

## Recovery Categories

Use the same recovery category vocabulary across doctor, capabilities, plan, and errors:

`diagnose`, `discover`, `prepare-target`, `project`, `observe`, `act`, `verify`, `archive`, `replay`, `smoke`, `plan`.


## Platform-bound task plans

General planning uses `triton plan --platform harmony --json` with no action argument. Explicit Android/Harmony `plan open-url` chooses host steps before embedded bootstrap, even with an unavailable server. Default/iOS open-url retains bootstrap and `afterRecoverySteps`; do not apply its runtime recovery chain to a host-only goal.

Harmony plans preserve target, bundle, ability, optional HAP install, URL, wait text and evidence in an existing host smoke sequence. Run the URL-bearing smoke once; do not prepend another URL action. Android can plan host open-url/wait/screenshot, but requested package-bound evidence returns `unsupported_capability` because the plan interface has no Android package input. Do not reinterpret iOS bundle-id or Harmony bundle/ability as a package, or replace unavailable host proof with embedded capture.

Prefer `argv` tokens for URLs containing `&` and paths/text containing spaces. A constructed plan can exit 0 while `ok=false`; inspect the JSON error and supported steps. Replace placeholders and check prerequisites before execution. A plan response proves neither device readiness nor business completion. Inspect the installed `schema --command plan --json` before relying on these contracts in an older release.

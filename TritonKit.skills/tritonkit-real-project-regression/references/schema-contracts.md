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

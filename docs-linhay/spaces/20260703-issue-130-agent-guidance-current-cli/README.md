# Space: 20260703-issue-130-agent-guidance-current-cli

## Issue

- GitHub: https://github.com/NeptuneKit/TritonKit/issues/130
- Title: `[Docs] Agent guidance references unavailable state command and app prefs --platform flag`

## Background

Agent-facing guidance still referenced removed or mismatched CLI forms such as `triton state route --json` and `triton app prefs get ... --platform ios`. TritonKit 0.2.7 exposes the current route/state surfaces through `triton debug state route --json` or runtime observation commands, and `app prefs get` accepts `--device` / `--simulator` selectors rather than `--platform`.

## BDD

1. Given an agent follows current README/public skill guidance
2. When it needs route state or App preferences
3. Then examples must use currently available CLI forms
4. And active docs checks must reject removed root `triton state route` guidance

## Scope

- In scope: current README, public skills, docs check, memory.
- Out of scope: compatibility aliases for old commands and historical space migration.

## Validation

- Red: `swift test --package-path CLI --scratch-path .build/cli-test --filter CLIHelpTests/retiredStateRootSuggestsCurrentDebugAndObservationCommands` failed before the hint was added.
- Green:
  - `swift test --package-path CLI --filter CLIHelpTests`
  - `swift test --package-path CLI --scratch-path .build/cli-test --filter SchemaFactSourceTests/schemaExamplesDoNotRecommendRetiredRootCommands`
  - `swift test --package-path CLI --scratch-path .build/cli-test --filter SchemaFactSourceTests/schemaCommandFilteringAndUnknownCommandDiagnosticsAreMachineReadable`
  - `git diff --check`
  - `docs-linhay/scripts/check-docs.sh`

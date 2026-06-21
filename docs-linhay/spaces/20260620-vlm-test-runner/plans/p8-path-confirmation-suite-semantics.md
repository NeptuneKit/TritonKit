# P8 Path Confirmation / Suite Semantics

## Goal

Turn App Map paths from automatic run-derived observations into maintainable test plan assets.

A passing run can create an observed candidate path, but suite membership is explicit. This prevents a newly discovered path from silently entering CI or smoke execution.

## Implemented Scope

New commands:

- `triton map path confirm <dir.tritonmap> --path <pathId> --json`
- `triton map path unconfirm <dir.tritonmap> --path <pathId> --json`
- `triton map suite add-path <dir.tritonmap> --suite smoke --path <pathId> --json`
- `triton map suite remove-path <dir.tritonmap> --suite smoke --path <pathId> --json`
- existing `triton map suite inspect <dir.tritonmap> --suite smoke --json`

Merge behavior:

- `triton map merge ... --confirm` confirms generated paths and adds them to the smoke suite.
- `triton map merge ...` without `--confirm` creates observed candidate paths only.
- Candidate paths remain replayable/exportable if their transitions are replayable, but they are not suite-eligible until confirmed.

Suite behavior:

- `suite add-path` requires the path to be confirmed and replayable.
- `suite remove-path` keeps the path asset but removes suite membership.
- `path unconfirm` removes the path from all suites.
- Suite path lists are sorted and de-duplicated for stable JSON.

## Machine Contract Updates

- `TKAppMapPath.confirmed` is now the gate for suite eligibility.
- `TKAppMapHealthResponse.unconfirmedPathIds` exposes candidate paths.
- New response models: `TKAppMapPathMutationResponse`, `TKAppMapSuiteMutationResponse`.
- New capabilities: `app-map-path-confirm`, `app-map-suite-edit`.
- New failure codes: `unconfirmed_path`, `non_replayable_path`.

## Explicitly Out Of Scope

- Suite runner execution.
- Suite tags / glob config.
- Regression suite policy beyond the existing smoke suite file.
- HTML/JUnit reports.
- Selector healing.
- AI suggested paths.

## Validation

Targeted checks completed during implementation:

- `swift test --package-path CLI --filter AppMapPathGraphTests --filter SchemaFactSourceTests --filter SchemaFactSourceCapabilityTests --filter SchemaFactSourceWorkflowTests`

Result: passed, 115 tests.

Full collective validation remains the final gate for the current large implementation slice.

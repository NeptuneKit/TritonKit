# P1 Screen Workspace Evidence Projection

## Goal

P1 turns P0E runner evidence into screen workspace input data.

It is an offline projection step:

```text
.tritonevidence/run/events.jsonl
-> .tritonevidence/screens.json
-> .tritonevidence/transitions.json
```

P1 does not execute runner steps, does not touch devices or simulators, and does not create `.tritonmap`.

## CLI Contract

```bash
triton evidence project-screens <dir.tritonevidence> --json
```

Success output:

```json
{
  "ok": true,
  "schemaVersion": 1,
  "kind": "triton.screen-workspace.projection-result",
  "evidenceDir": "<dir.tritonevidence>",
  "screensRef": "screens.json",
  "transitionsRef": "transitions.json",
  "screenCount": 2,
  "transitionCount": 1,
  "warningCount": 0,
  "warnings": []
}
```

Missing observation output:

```json
{
  "ok": false,
  "error": {
    "type": "projection_error",
    "code": "missing_observation_events",
    "message": "No observation.captured events found in run/events.jsonl."
  }
}
```

## Input Contract

Required input:

- `manifest.json`
- `run/events.jsonl`
- at least one `observation.captured`

Optional input:

- `normalized-plan.json`, used only to attach `tap.point` and `coordinateSpace` to projected transitions.

No runtime, simulator, VLM provider, App Map, or replay state is read.

## screens.json

`screens.json` groups `observation.captured` events by strict fingerprint:

```text
screenshotSha256 + axTextHash + hierarchySha256
```

Exact fingerprint match means the observations belong to the same run-local screen candidate.

Screen ids are run-local and deterministic in first-seen order:

```text
screen-000
screen-001
screen-002
```

The output does not include `screenTemplateId`, `screenId` from an App Map, AI summary, VLM grounding, or cross-run merge metadata.

## transitions.json

`transitions.json` is derived only from action steps with P0E observations.

P1 supports transition projection for:

```text
tap before + tap after + after.changed=true
```

It skips transition creation when:

- the action is not `tap`
- `before` or `after` observation is missing
- `after.changed` is not `true`
- before and after observations resolve to the same screen

Warnings are written into `transitions.json`, but warnings do not fail projection.

## Manifest / Summary

Projection updates `manifest.json` with:

- `screenWorkspace.screensPath`
- `screenWorkspace.transitionsPath`
- `screenWorkspace.screenCount`
- `screenWorkspace.transitionCount`
- `screenWorkspace.warningCount`

It also adds artifact records:

- `screen-workspace.screens -> screens.json`
- `screen-workspace.transitions -> transitions.json`

`triton evidence summary <dir.tritonevidence> --json` exposes the same `screenWorkspace` block.

## Scope Guard

P1 does not implement:

- runner execution changes
- `.tritonmap`
- `screens.json` cross-run merge
- screen template ids
- path / suite
- VLM grounding
- AI assertions
- selector healing
- HTML / JUnit
- replay consumption

## Done Evidence

Unit and contract tests:

```bash
swift test --package-path CLI --filter ScreenWorkspaceProjectionTests
swift test --package-path CLI --filter SchemaFactSourceSurfaceContractTests --filter SchemaFactSourceTests --filter SchemaFactSourceCapabilityTests
```

Required regression checks:

```bash
swift test --package-path CLI --filter EvidenceBundleTests
swift test --package-path CLI --filter TestRunExecutionTests
```

Real P0E projection smoke:

```bash
triton evidence project-screens docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0e-fixture-pass.tritonevidence --json
triton evidence project-screens docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0e-fixture-failure.tritonevidence --json
```

Expected:

- pass evidence: `screenCount >= 2`, `transitionCount >= 1`
- failure evidence: `screenCount >= 1`, `transitionCount == 0`
- no `.tritonmap` file

## Verdict

P1 opens later screen workspace projection work, but still does not open VLM, App Map merge, selector healing, full runner execution, or report generation.

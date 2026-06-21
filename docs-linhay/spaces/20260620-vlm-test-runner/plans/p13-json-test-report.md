# P13 JSON Test Report

## Goal

Add an offline report projection for existing `.tritonevidence` test runs so agents and CI can inspect step status, screenshots, VLM overlays, failure type, and observation state changes without re-running the device.

## Scope

- Add `triton test report <dir.tritonevidence> --json`.
- Read `manifest.json`, `run/run.json`, and `run/events.jsonl`.
- Aggregate per-step command, status, assertion, failure, artifact refs, observations, screenCandidate fingerprints, visibleTexts, and VLM grounding when present.
- Count events, steps, assertions, artifacts, observations, failures, screenshots, and overlays.
- Return reports for both pass and failure evidence with `ok: true`; test result remains in `summary.status` and `failure`.

## Out of Scope

- HTML report.
- JUnit output.
- Re-running tests.
- Device/runtime operations.
- App Map mutation.
- AI assertions or visual defect scoring.

## CLI Contract

```bash
triton test report <dir.tritonevidence> --json
```

Response kind:

```json
{
  "ok": true,
  "schemaVersion": 1,
  "kind": "triton.test.report",
  "evidenceDir": "...",
  "summary": {
    "status": "passed",
    "stepCount": 5,
    "observationCount": 3,
    "screenshotCount": 3,
    "overlayCount": 0
  },
  "steps": []
}
```

## Validation

- `swift test --package-path CLI --filter TestRunExecutionTests`
- `swift test --package-path CLI --filter SchemaFactSourceWorkflowTests`
- Real evidence smoke:

```bash
CLI/.build/debug/triton test report docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260621-p10-suite-run.tritonevidence-root/001-path-fixture-login-home.tritonevidence --json
```

The real evidence smoke reports `status=passed`, `stepCount=5`, `observationCount=3`, `screenshotCount=3`, and includes Login/Home visibleTexts from observation screen candidates.

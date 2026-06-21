# P16 Static App Map Viewer + Session-to-Test

## Goal

Export human-readable App Map inspection artifacts and editable test drafts from existing deterministic evidence without introducing Web/Wails, a server, or a business-control UI.

## Scope

- Add `triton map viewer <dir.tritonmap> --output <file.html> --json`.
- Add `triton test create --from-session <dir.tritonevidence> --output <path.tritontest.yaml> --json`.
- Consume existing App Map runtime projections:
  - `inspectTritonAppMap`
  - `listTritonAppMapScreens`
  - `listTritonAppMapTransitions`
  - `listTritonAppMapPaths`
- Consume existing runner evidence:
  - `manifest.json`
  - `normalized-plan.json`
- Render a single static HTML file with:
  - counts and pass/fail summary
  - paths table
  - screens table
  - transitions table
- Render an editable `.tritontest.yaml` draft from `normalized-plan.json` and immediately validate it with existing P0B validation.
- Return `triton.app-map.viewer-result`.
- Return `triton.test.create-result`.

## Out of Scope

- Web/Wails runtime.
- HTTP route.
- Interactive editing.
- Running tests.
- Mutating `.tritonmap`.
- Reconstructing tests from incomplete evidence without `normalized-plan.json`.
- AI/VLM inference or selector healing.

## Validation

- `swift test --package-path CLI --filter AppMapPathGraphTests --filter SchemaFactSourceWorkflowTests`
- `swift test --package-path CLI --filter TestCreateFromSessionTests --filter TestValidationTests --filter SchemaFactSourceWorkflowTests`
- `CLI/.build/debug/triton map viewer docs-linhay/spaces/20260620-vlm-test-runner/.tritonmap --output /tmp/triton-app-map-viewer.html --json`
- `CLI/.build/debug/triton test create --from-session docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260621-p10-suite-run.tritonevidence-root/001-path-fixture-login-home.tritonevidence --output /tmp/generated-from-session.tritontest.yaml --json`
- `CLI/.build/debug/triton test validate /tmp/generated-from-session.tritontest.yaml --json`

Smoke artifact:

- `docs-linhay/spaces/20260620-vlm-test-runner/app-map-viewer.html`
- `docs-linhay/spaces/20260620-vlm-test-runner/generated-from-session.tritontest.yaml`

Result: targeted App Map/schema tests passed, targeted session-to-test/schema tests passed, real `.tritonmap` viewer export returned `screenCount=4`, `transitionCount=2`, `pathCount=1`, and real `.tritonevidence` create/validate smoke returned `ok=true` with `stepCount=5`.

## Collective Gate

- `swift test --package-path CLI` passed with 400 tests.
- `CLI/.build/debug/triton schema --command test --json | rg "test-create-from-session|test.create|create --from-session"` passed.
- `CLI/.build/debug/triton capabilities --json | rg "test-create-from-session|app-map-viewer|action-provider-parse"` passed.
- `git diff --check` passed.
- `docs-linhay/scripts/check-docs.sh` passed.

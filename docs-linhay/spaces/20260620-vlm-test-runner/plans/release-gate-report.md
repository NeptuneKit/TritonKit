# Final Delivery Report

## Scope

This report freezes the VLM test runner / App Map workstream after P0A-P16. No new feature work should be added before review. The current gate is about auditability, artifact policy, validation evidence, and commit slicing.

## Completed Phases

- P0A Primitive fact gate.
- P0B validate / normalize only.
- P0C run event writer and fixture evidence.
- P0D minimal runner execution.
- P0E screen workspace readiness.
- P1 screen workspace evidence projection.
- P1-P2 App Map test path graph.
- P2B exported flow re-run gate.
- P3 App Map inspection and path operations.
- P4 mock VLM grounding contract.
- P5 OpenAI-compatible grounding contract.
- P6 deterministic runner primitives.
- P7 VLM-assisted tap target.
- P8 path confirmation and suite semantics.
- P10 suite runner.
- P11 HTTP API thin wrapper.
- P12 tap(text).
- P13 JSON test report.
- P14 mock AI assertions.
- P15 action provider parser.
- P16 static App Map viewer and session-to-test.

## Commands Added Or Extended

### Test

- `triton test validate <path.tritontest.yaml> --json`
- `triton test normalize <path.tritontest.yaml> --json`
- `triton test run <path.tritontest.yaml> --json --evidence-dir <dir>`
- `triton test report <dir.tritonevidence> --json`
- `triton test create --from-session <dir.tritonevidence> --output <path.tritontest.yaml> --json`

### Evidence / App Map

- `triton evidence project-workspace <dir.tritonevidence> --json`
- `triton map merge <dir.tritonevidence> --into <dir.tritonmap> --confirm --json`
- `triton map inspect <dir.tritonmap> --json`
- `triton map screens <dir.tritonmap> --json`
- `triton map transitions <dir.tritonmap> --json`
- `triton map path show <dir.tritonmap> --path <path-id> --json`
- `triton map health <dir.tritonmap> --json`
- `triton map suite inspect <dir.tritonmap> --suite <suite-id> --json`
- `triton map suite run <dir.tritonmap> --suite <suite-id> --target <target> --evidence-root <dir> --json`
- `triton map export-flow <dir.tritonmap> --path <path-id> --out <file.tritontest.yaml> --json`
- `triton map viewer <dir.tritonmap> --output <file.html> --json`

### VLM / Action Provider

- `triton vlm ground --provider mock ... --json`
- `triton vlm ground --provider openai-compatible ... --json`
- `triton action parse --provider ui-tars --input <raw> --json`
- `triton action parse --provider agentcpm-gui --input <json> --json`

## Schema And Capability Contracts

Added or extended output selectors include:

- `test.validation`
- `test.normalized-plan`
- `test.run-result`
- `test.report`
- `test.create`
- `app-map.viewer`
- `vlm.ground`
- `action.provider.parse`

Capability governance was updated for:

- `test-create-from-session`
- `app-map-viewer`
- `action-provider-parse`
- `test-run-ai-mock`
- `test-report`
- `app-map-viewer-html`
- `tritontest-yaml`
- `ai_` failure recovery categories
- `action` recovery root category

## Worktree Audit

Current changed files fall into these categories.

### A. Core Shared Models

- `Sources/TritonKitShared/TKCLITransportSchemaModels.swift`
- `Sources/TritonKitShared/TKTestRunEventModels.swift`
- `Sources/TritonKitShared/TKVLMModels.swift`

### B. CLI Commands And Runtimes

- `Sources/TritonKitCLI/CLIActionProviderCommands.swift`
- `Sources/TritonKitCLI/CLIActionProviderRuntime.swift`
- `Sources/TritonKitCLI/CLIAppMapCommands.swift`
- `Sources/TritonKitCLI/CLIAppMapRuntime.swift`
- `Sources/TritonKitCLI/CLIRuntimeTransport.swift`
- `Sources/TritonKitCLI/CLIServeCommand.swift`
- `Sources/TritonKitCLI/CLITestCommands.swift`
- `Sources/TritonKitCLI/CLITestCreateRuntime.swift`
- `Sources/TritonKitCLI/CLITestReportRuntime.swift`
- `Sources/TritonKitCLI/CLITestRunRuntime.swift`
- `Sources/TritonKitCLI/CLITestValidationRuntime.swift`
- `Sources/TritonKitCLI/CLIVLMCommands.swift`
- `Sources/TritonKitCLI/CLIVLMRuntime.swift`

### C. Tests

- `CLI/Tests/TritonKitCLITests/ActionProviderParserTests.swift`
- `CLI/Tests/TritonKitCLITests/AppMapPathGraphTests.swift`
- `CLI/Tests/TritonKitCLITests/ScreenWorkspaceProjectionTests.swift`
- `CLI/Tests/TritonKitCLITests/TestCreateFromSessionTests.swift`
- `CLI/Tests/TritonKitCLITests/TestRunExecutionTests.swift`
- `CLI/Tests/TritonKitCLITests/TestValidationTests.swift`
- `CLI/Tests/TritonKitCLITests/VLMGroundingTests.swift`
- Schema governance tests under `SchemaFactSource*.swift`.

### D. Docs / Plans / Memory

- `docs-linhay/spaces/20260620-vlm-test-runner/README.md`
- `docs-linhay/spaces/20260620-vlm-test-runner/plans/*.md`
- `docs-linhay/memory/2026-06-21.md`

### E. Samples / Generated Artifacts

- `docs-linhay/spaces/20260620-vlm-test-runner/app-map-viewer.html`
- `docs-linhay/spaces/20260620-vlm-test-runner/generated-from-session.tritontest.yaml`
- `docs-linhay/spaces/20260620-vlm-test-runner/.tritonmap/`

### F. Evidence Bundles

- Existing P0A-P0E evidence under `docs-linhay/spaces/20260620-vlm-test-runner/evidence/` was already tracked before this gate.
- New 20260621 P10/VLM smoke evidence is small, but should be reviewed separately from core code. Do not mix evidence bundles into core runtime commits.
- Temporary final gate smoke evidence was written under `/tmp/triton-final-gate.JgcLsJ` and is not intended for repository commit.

Unrelated untracked spaces observed and intentionally excluded from this gate:

- `docs-linhay/spaces/20260619-issue-68-harmony-app-target-failure/`
- `docs-linhay/spaces/20260621-issue-76-media-fixture-seed/`

## Artifact Policy

Commit candidates:

- Plans and final report.
- Small sample HTML/YAML artifacts.
- Small App Map sample files when needed for documentation and smoke reproducibility.
- Small golden VLM/action JSON artifacts only if reviewed as documentation evidence.

Do not commit as part of core runtime commits:

- Large raw `.tritonevidence` bundles.
- Screenshot-heavy smoke outputs.
- Temporary final gate outputs under `/tmp`.
- Server logs, DerivedData, or raw simulator dumps.

## Final Smoke

Runtime status before final smoke:

- `triton status --json` returned `ok=true`, `serverReachable=true`, `connected=true`, `targetCount=2`.
- Fixture target used: `triton:ios-simulator:0333546D-2AC6-4C22-AF01-293E2F4BA5BC`.

Final smoke root:

- `/tmp/triton-final-gate.JgcLsJ`

Executed chain:

1. `triton test validate docs-linhay/spaces/20260620-vlm-test-runner/generated-from-session.tritontest.yaml --json` passed.
2. `triton test run ... --target <fixture-target> --evidence-dir /tmp/triton-final-gate.JgcLsJ/run1.tritonevidence --json` passed.
3. `triton evidence project-workspace /tmp/triton-final-gate.JgcLsJ/run1.tritonevidence --json` passed with `screenCount=2`, `transitionCount=1`.
4. `triton map merge ... --into /tmp/triton-final-gate.JgcLsJ/map.tritonmap --confirm --json` passed with one path.
5. `triton map inspect /tmp/triton-final-gate.JgcLsJ/map.tritonmap --json` passed with `observedRuns=1`, `passCount=1`, `failCount=0`.
6. `triton map export-flow ... --out /tmp/triton-final-gate.JgcLsJ/exported.tritontest.yaml --json` passed with `stepCount=5`.
7. `triton test validate /tmp/triton-final-gate.JgcLsJ/exported.tritontest.yaml --json` passed.
8. `triton map viewer ... --output /tmp/triton-final-gate.JgcLsJ/viewer.html --json` passed.
9. `triton test create --from-session /tmp/triton-final-gate.JgcLsJ/run1.tritonevidence --output /tmp/triton-final-gate.JgcLsJ/created.tritontest.yaml --json` passed.
10. `triton action parse --provider ui-tars --input "Action: click(start_box='(500,330)')" --json` passed with `primitive=tap`.
11. Reset to Login used Triton runtime-point tap after text tap hit a non-UIView target.
12. Exported flow re-run passed.
13. Re-run evidence projected and merged back into the same map.
14. Final `map inspect` passed with `observedRuns=2`, `passCount=2`, `failCount=0`.

## Final Test Gate

Passed:

- `swift test --package-path CLI` passed with 400 tests.
- `CLI/.build/debug/triton schema --command test --json | rg "test-create-from-session|test.create|create --from-session"` passed.
- `CLI/.build/debug/triton capabilities --json | rg "test-create-from-session|app-map-viewer|action-provider-parse"` passed.
- `git diff --check` passed.
- `docs-linhay/scripts/check-docs.sh` passed.

Not run in this gate:

- Root package `swift test`; this workstream is CLI package scoped.
- Real external remote VLM provider call; OpenAI-compatible behavior was validated against a local compatible fixture server.
- Multi-path suite smoke; current suite runner evidence proves the single fixture path.

## Known Gaps

1. Remote VLM against a real external model remains unverified in this gate.
2. VLM-assisted `tap(target)` remains opt-in and is not enabled by default CI.
3. Suite runner real smoke currently covers one path, not a multi-path suite.
4. Existing tracked evidence directory already contains sizeable P0A/P0E artifacts; future evidence should be slimmed or explicitly marked golden.
5. HTTP thin wrapper exists for App Map / suite paths, but this final smoke focused on CLI contracts.
6. HTML viewer is static readonly and does not control devices.
7. Action provider support is parse-only; it does not execute parsed actions.
8. Final runtime smoke required resetting fixture state before re-run because launch does not guarantee app screen reset.

## Commit Plan

Recommended commit split:

1. Core test contract, runner events, deterministic runner primitives.
2. Screen workspace projection and App Map path graph.
3. VLM grounding and action parser contracts.
4. Reports, static viewer, and session-to-test.
5. Schema/capability taxonomy governance.
6. Docs, samples, final report, and reviewed evidence artifacts.

Do not stage unrelated issue spaces or temporary final gate outputs.


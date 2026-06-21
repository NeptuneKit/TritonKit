# P14 Mock AI Assertions

## Goal

Add reportable AI-style test steps without introducing remote model calls or autonomous loops. P14 creates the evidence contract that later real VLM/AI assertions can replace.

## Scope

- Validate and normalize:
  - `assertWithAI.prompt/provider`
  - `assertNoDefectsWithAI.provider`
  - `extractTextWithAI.provider`
  - `assertScreenshot.baseline/threshold/cropOn`
- AI steps default to `optional: true` except `assertScreenshot`, which remains blocking by default.
- P14 provider is limited to `mock`; remote model providers remain out of scope.
- Runner captures an observation and writes `ai.assertion` or `ai.extraction` artifacts.
- Optional AI failure records `failure.recorded` and `step.finished(status=failed)` but continues the run and preserves final pass status when later required steps pass.
- `assertScreenshot` performs strict SHA256 baseline comparison and writes a `screenshot.diff` JSON artifact.

## Out of Scope

- Remote VLM / OpenAI-compatible AI assertions.
- Visual defect scoring.
- Pixel threshold diff implementation.
- HTML/JUnit report output.
- Autonomous action loop.
- Selector healing.

## Validation

- `swift test --package-path CLI --filter TestValidationTests --filter TestRunExecutionTests --filter SchemaFactSourceWorkflowTests`

Result: 34 tests passed.

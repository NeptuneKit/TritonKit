# Workspace Runs And Evidence

Use this reference when touching workspace run, model decisions, Atlas/app-map, replay, `.tritonplan`, or evidence archive behavior.

## Workspace Run

For local agent runs that need app launch plus initial observation:

```bash
triton workspace run --target <selector> --platform <ios|android|harmony> --scope <simulator|emulator|real> --resolve-target --app <app> --goal "<goal>" --app-mode launch --observe-live --observe-kind tree --json
```

`--resolve-target` resolves `current`, `booted`, and workspace aliases through host target discovery and writes stable target evidence.

Without `--app-mode launch`, workspace run stays in dry app lifecycle mode.

## Business Readiness

Built-in checkpoint:

- CLI: `--business-ready-text <text>`
- HTTP: `businessReadyText`

Modes:

- default: exact-match initial observation visible text
- live wait: `--business-ready-live-wait`
- runtime assert: `--business-ready-assert`

Do not claim business completion from launch or action alone. Require wait/assert/verification evidence.

## Model Decisions

Only mutate the app with:

```bash
--execute-actions
```

Remote LLM/VLM endpoints require explicit `--allow-remote-llm` or `--allow-remote-vlm` because evidence or screenshots may be sent out.

If VLM grounding fails before runtime execution, write VLM failure evidence and stop for review.

## Replay And Recovery

Consume replay JSON top-down:

- `recoveryProposal`
- `failedStepIndex`
- `failureCode`
- `failureError`
- `failureWorkflowCategories[]`
- `failureRecoveryCategories[]`
- `failurePrimaryArtifacts[]`
- `recoveryCommands[]`
- `suggestedCommands[]`

Prefer replay failures that preserve runtime/target/transport error codes directly. Treat unnecessary fallback to `step_failed` as a control-surface bug.

## Evidence

Use:

```bash
triton evidence capture --case <case> --output <dir.tritonevidence> --json
triton evidence summary <dir.tritonevidence> --json
triton evidence redact <dir.tritonevidence> --profile ios-private --output <redacted.tritonevidence> --json
```

Inspect `primaryArtifacts[]` first before traversing the full artifact set.

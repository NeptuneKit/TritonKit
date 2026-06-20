# P1-P2 App Map Test Path Graph

## Goal

把 P0E runner evidence 继续投影成可复用的 App Map 与测试路径图：

```text
.tritonevidence/run/events.jsonl
-> screens.json
-> transitions.json
-> .tritonmap/
-> paths.json
-> suites/smoke.json
-> map inspect / replay-path dry-run / export-flow
```

P1-P2 仍然不是 runner 执行能力扩展。它只消费已存在的 `.tritonevidence`，生成离线、可审计、可再次 validate 的路径图材料。

## Scope

Implemented commands:

```bash
triton evidence project-workspace <run.tritonevidence> --json
triton map merge <run.tritonevidence> --into <dir.tritonmap> --json
triton map inspect <dir.tritonmap> --json
triton map paths <dir.tritonmap> --json
triton map export-flow <dir.tritonmap> --path <path-id> --out <file.tritontest.yaml> --json
```

Supported inputs:

- P0E `.tritonevidence` with `run/events.jsonl`.
- `observation.captured` events with `screenCandidate` fingerprint.
- P1 `screens.json` and `transitions.json`, generated automatically by `map merge` if missing.
- P0D-compatible normalized plan and manifest metadata for app bundle/platform.

Still out of scope:

- VLM / AI assertions.
- Runner step expansion.
- `tap(text)`, input, swipe, scroll.
- App exploration or autonomous loop.
- Cross-version visual similarity merge.
- AI screen naming.
- Selector healing.
- HTML / JUnit report.
- Real replay execution. `export-flow` produces a deterministic `.tritontest.yaml`; execution remains P0D runner behavior.

## Artifact Contract

`.tritonmap/` contains:

```text
.tritonmap/
├── app-map.json
├── screens/
│   └── <screen-id>.json
├── transitions/
│   └── <transition-id>.json
├── paths/
│   └── <path-id>.json
├── suites/
│   └── smoke.json
└── runs/
    └── <run-id>.json
```

`app-map.json` records app identity and artifact counts.

`screens/*.json` records stable map-level screen ids derived from strict fingerprint:

```text
screenshotSha256 + axTextHash + hierarchySha256
```

`transitions/*.json` records replayable action transitions only when:

- source transition came from a tap action.
- before and after observations exist.
- `after.changed=true`.
- before and after screen ids differ.
- trigger has `runtime-point`.

`paths/*.json` is generated from confirmed replayable transition chains. Current P1-P2 only creates a single observed path per evidence run when the run has at least one replayable transition.

`suites/smoke.json` contains confirmed replayable paths.

`runs/*.json` records source evidence run verdict and projected artifact counts.

## Command Results

`triton map merge` returns:

- `projectedWorkspace`: whether `screens.json` / `transitions.json` were generated during merge.
- `screenCount`
- `transitionCount`
- `pathCount`
- `suiteCount`
- `screenIDs`
- `transitionIDs`
- `pathIDs`

`triton map inspect` returns:

- map counts.
- health: `observedRuns`, `passCount`, `failCount`, `flakeCount`.

`triton map paths` returns replayable/confirmed paths and path health.

`triton map export-flow` writes a P0D-compatible `.tritontest.yaml`:

1. `launch`
2. `takeScreenshot`
3. `assertVisible` for start screen primary text
4. `tap(point/runtime-point)`
5. `assertVisible` for end screen primary text

The exported YAML must pass `triton test validate`.

## Fixture Smoke

Pass evidence:

```bash
triton evidence project-workspace docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0e-fixture-pass.tritonevidence --json
triton map merge docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0e-fixture-pass.tritonevidence --into docs-linhay/spaces/20260620-vlm-test-runner/.tritonmap --confirm --json
triton map inspect docs-linhay/spaces/20260620-vlm-test-runner/.tritonmap --json
triton map paths docs-linhay/spaces/20260620-vlm-test-runner/.tritonmap --json
triton map export-flow docs-linhay/spaces/20260620-vlm-test-runner/.tritonmap --path path-fixture-login-home --out docs-linhay/spaces/20260620-vlm-test-runner/generated-fixture-login-home.tritontest.yaml --json
triton test validate docs-linhay/spaces/20260620-vlm-test-runner/generated-fixture-login-home.tritontest.yaml --json
```

Observed result:

- `screenCount=2`
- `transitionCount=1`
- `pathCount=1`
- `suiteCount=1`
- `pathIDs=["path-fixture-login-home"]`
- exported flow validates with steps: `launch`, `takeScreenshot`, `assertVisible("Fixture Login")`, `tap(point/runtime-point)`, `assertVisible("Fixture Home")`

Failure evidence:

```bash
triton map merge docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0e-fixture-failure.tritonevidence --into docs-linhay/spaces/20260620-vlm-test-runner/.tritonmap-failure --json
triton map inspect docs-linhay/spaces/20260620-vlm-test-runner/.tritonmap-failure --json
```

Observed result:

- `screenCount=1`
- `transitionCount=0`
- `pathCount=0`
- health: `passCount=0`, `failCount=1`

Generated flow execution was not rerun in the current session because `triton status --json` returned `server_unavailable`; no Triton runtime server was listening at `127.0.0.1:19421`.

## Validation

Focused tests:

```bash
swift test --package-path CLI --filter AppMapPathGraphTests
swift test --package-path CLI --filter ScreenWorkspaceProjectionTests
swift test --package-path CLI --filter EvidenceBundleTests
swift test --package-path CLI --filter TestRunExecutionTests
swift test --package-path CLI --filter SchemaFactSourceTests
```

Smoke commands above must pass before P1-P2 is considered usable.

## Verdict

P1-P2 is implemented as an offline evidence projection and path export layer.

It opens the next deterministic path workflow work, but still does not open VLM, AI assertions, runner step expansion, autonomous exploration, selector healing, HTML/JUnit, or real replay execution.

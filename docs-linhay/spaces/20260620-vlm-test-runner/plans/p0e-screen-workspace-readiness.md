# P0E Screen Workspace Readiness

## Goal

P0E 不扩展 runner step，也不生成 screen graph。目标是让 P0D minimal runner 产生的 `.tritonevidence/run/events.jsonl` 足以在 P1 中派生 Screen Workspace Evidence。

一句话：先别画地图，先让每一步都留下可计算的界面观察点。

## Scope

Included:

- `observation.captured` run event。
- `takeScreenshot` 的 `after` observation。
- `tap(point/runtime-point)` 的 `before` / `after` observation。
- `assertVisible(text/source=ax/match=exact)` 失败时的 `after` observation。
- observation artifact refs：screenshot、AX、hierarchy。
- `screenCandidate` fingerprint：`screenshotSha256`、`axTextHash`、`hierarchySha256`、`visibleTexts`。
- `coordinate-contract.json`，固定 canonical tap space 为 `runtime-point`。
- `manifest.run.observationCount` 与 `evidence summary` 可读回 observation count。

Explicitly excluded:

- `screens.json`
- `transitions.json`
- `.tritonmap`
- path / suite
- VLM
- AI assert
- selector healing
- HTML / JUnit
- `tap(text)`
- `input` / `swipe` / `scroll`

## Event Contract

`observation.captured` 示例：

```json
{
  "schemaVersion": 1,
  "type": "observation.captured",
  "runId": "run-...",
  "stepIndex": 3,
  "phase": "before",
  "artifacts": {
    "screenshot": "../debug/step-003-before.png",
    "ax": "../debug/step-003-before-ax.json",
    "hierarchy": "../debug/step-003-before-hierarchy.json"
  },
  "screenCandidate": {
    "screenshotSha256": "...",
    "axTextHash": "...",
    "hierarchySha256": "...",
    "visibleTexts": ["Fixture Login", "Go Home"]
  }
}
```

For tap after observation, `changed` is set when the before / after screen candidate fingerprint differs.

P0E deliberately uses `screenCandidate`; it does not introduce `screenId`, `screenTemplateId`, or `transitionId`.

## Coordinate Contract

Every P0E runner evidence bundle contains:

```text
coordinate-contract.json
```

Observed fixture contract on iOS Simulator:

```json
{
  "schemaVersion": 1,
  "canonicalTapSpace": "runtime-point",
  "runtimeScreenshotSpace": {
    "kind": "runtime-point-sized-image",
    "width": 402,
    "height": 874,
    "scale": 1
  },
  "runtimeGeometry": {
    "width": 402,
    "height": 874,
    "scale": 3,
    "orientation": "portrait"
  },
  "vlmImageSpace": "not-supported-in-p0e",
  "hostFramebufferSpace": "not-supported-in-p0e"
}
```

This means P0E fixes `runtime-point` as the canonical tap space. VLM image space and host framebuffer space stay explicitly unsupported until a later phase.

## Real Simulator Smoke

Target:

```text
triton:ios-simulator:0333546D-2AC6-4C22-AF01-293E2F4BA5BC
```

Fixture:

```text
TritonKitTestFixture
com.neptunekit.tritonkit.testfixture
```

Pass evidence:

```text
docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0e-fixture-pass.tritonevidence/
```

Observed facts:

| Fact | Evidence | Verdict |
|---|---|---|
| runner still reuses P0B validate / normalize | response embeds `normalizedPlan`; `normalized-plan.json` exists | pass |
| Login observation exists | `events.jsonl` line 12 has `visibleTexts` containing `Fixture Login` | pass |
| tap before / after observations exist | `events.jsonl` lines 28 and 29 are `phase=before/after` for step 3 | pass |
| tap visible change is recorded | tap after observation has `changed=true` and `Fixture Home` visible text | pass |
| Home observation exists | `events.jsonl` line 37 has `visibleTexts` containing `Fixture Home` | pass |
| observation artifacts exist | screenshot, AX, and hierarchy refs are present for every observation | pass |
| evidence summary reads observation count | `summary.run.observationCount=4` | pass |
| coordinate contract exists | `coordinate-contract.json` declares `canonicalTapSpace=runtime-point` | pass |

Failure evidence:

```text
docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0e-fixture-failure.tritonevidence/
```

Observed facts:

| Fact | Evidence | Verdict |
|---|---|---|
| CLI exit code is non-zero | smoke captured `EXIT_CODE=1` | pass |
| failed step has observation | `events.jsonl` line 21 is `observation.captured` for step 2 | pass |
| failure observation has fingerprints | `screenCandidate` includes screenshot, AX text, and hierarchy hashes | pass |
| failure screenshot / AX / hierarchy exist | `debug/step-002-failure.png`, `debug/step-002-ax.json`, `debug/step-002-hierarchy.json` | pass |
| evidence summary reads observation count | `summary.run.observationCount=2` | pass |
| evidence closes cleanly | `run.finished` status is `failed` | pass |

Unsupported evidence:

```text
docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0e-unsupported.tritonevidence/
```

Observed facts:

| Fact | Evidence | Verdict |
|---|---|---|
| unsupported step remains validation_error | `error.type=validation_error`, `error.code=unsupported_step` | pass |
| CLI exit code is non-zero | smoke captured `EXIT_CODE=1` | pass |
| no evidence directory is created | target `.tritonevidence` path is absent | pass |
| no device operation is entered | validation fails before runner evidence creation | pass |

## Tests

Focused verification:

```bash
swift test --package-path CLI --filter TestRunExecutionTests
swift test --package-path CLI --filter TestValidationTests
swift test --package-path CLI --filter EvidenceBundleTests
swift test --package-path CLI --filter SchemaFactSourceTests
```

All focused CLI tests passed on 2026-06-20.

Root package note:

```bash
swift test --filter TKTestRunEventModelsTests
```

This command is currently blocked by unrelated existing root test compile errors in `TKXcodeWorkflowModelsTests.swift` and `TKDisplayItemTests.swift`; the P0E shared event model still compiles through the CLI package dependency build.

## Verdict

`pass-with-gap`

P0E opens P1 Screen Workspace Evidence projection:

```text
.tritonevidence/run/events.jsonl
→ observation.captured
→ screens.json / transitions.json in P1
```

P0E does not open VLM, App Map merge, selector healing, full runner execution, or report generation.

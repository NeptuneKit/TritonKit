# P0D Minimal Runner Execution

## Goal

P0D 只实现最小 runner execution：

```bash
triton test run <path.tritontest.yaml> --json --evidence-dir <dir>
```

Runner 必须先复用 P0B validate / normalize。只有 normalized plan 通过后，才允许进入设备动作。

P0D 的 runner 仍是薄编排层：

- 不重新实现设备控制 runtime。
- 不新增 VLM / App Map / replay / report 系统。
- 不把 unsupported step 降级成 runtime failure；unsupported 必须仍是 `validation_error`。

## Scope

Included primitives:

- `launch`
- `takeScreenshot`
- `tap(point/runtime-point)`
- `assertVisible(text/source=ax/match=exact)`

Explicitly excluded:

- `tap(text)`
- `input`
- `swipe`
- VLM
- App Map
- replay
- screens / transitions
- selector healing
- HTML / JUnit

Implementation note: P0D `launch` 绑定并验证已连接 TritonKit runtime target 与 `app.bundleId` 对齐。它不在 runner 内实现 host-side install / launch / reset。真实 smoke 使用 `triton app terminate` / `triton app launch` 在 runner 外部重置 fixture 状态。

## Command Contract

Success:

```json
{
  "ok": true,
  "schemaVersion": 1,
  "kind": "triton.test.run-result",
  "input": "path.tritontest.yaml",
  "evidenceDir": "path.tritonevidence",
  "normalizedPlan": {},
  "run": {},
  "summary": {}
}
```

Failure during execution:

```json
{
  "ok": false,
  "failedStepIndex": 2,
  "failure": {
    "type": "assert_visible_failed",
    "message": "Expected text to exist: Definitely Not Existing",
    "selector": {
      "text": {
        "value": "Definitely Not Existing",
        "match": "exact",
        "source": "ax"
      }
    },
    "artifactRefs": [
      "../debug/step-002-failure.png",
      "../debug/step-002-ax.json"
    ]
  }
}
```

Validation failure:

```json
{
  "ok": false,
  "error": {
    "type": "validation_error",
    "code": "unsupported_step",
    "path": "$.steps[1].swipe"
  }
}
```

Validation failure exits non-zero before evidence directory creation and before primitive executor invocation.

## Evidence Contract

P0D writes:

```text
<dir>.tritonevidence/
├── manifest.json
├── normalized-plan.json
├── runtime-target.json
├── run/
│   ├── run.json
│   └── events.jsonl
├── screenshots/
│   ├── step-001.png
│   └── step-001.json
└── debug/
    ├── step-002-assert-result.json
    ├── step-002-ax.json
    ├── step-002-hierarchy.json
    ├── step-002-failure.png
    └── step-002-failure-screenshot.json
```

Event log remains P0C-compatible:

- `run.started`
- `step.started`
- `command.executed`
- `artifact.created`
- `assertion.result`
- `failure.recorded`
- `step.finished`
- `run.finished`

`manifest.json` includes `run.eventsPath=run/events.jsonl`, `run.metaPath=run/run.json`, `run.eventCount`, screenshot paths, debug artifact paths, and success / failure verdict.

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

Plans:

```text
docs-linhay/spaces/20260620-vlm-test-runner/p0d-fixture-pass.tritontest.yaml
docs-linhay/spaces/20260620-vlm-test-runner/p0d-fixture-failure.tritontest.yaml
docs-linhay/spaces/20260620-vlm-test-runner/p0d-unsupported.tritontest.yaml
```

Pass evidence:

```text
docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0d-fixture-pass.tritonevidence/
```

Observed facts:

| Fact | Evidence | Verdict |
|---|---|---|
| P0B validate/normalize reused | `normalized-plan.json` exists and response embeds `normalizedPlan` | pass |
| launch binds fixture target | `runtime-target.json` points to fixture runtime target | pass |
| screenshot artifacts exist | `screenshots/step-001.png`, `screenshots/step-004.png` | pass |
| AX exact text finds Login/Home | two `assertion.result` events are `passed` | pass |
| point tap changes UI | after tap at `201,289.5`, final assertion finds `Fixture Home` | pass |
| run events are readable | `eventCount=27`, `status=passed` | pass |
| evidence summary reads run manifest | `verdict=success`, `stepCount=6` | pass |

Failure evidence:

```text
docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0d-fixture-failure.tritonevidence/
```

Observed facts:

| Fact | Evidence | Verdict |
|---|---|---|
| CLI exit code is non-zero | smoke captured `EXIT_CODE=1` | pass |
| failure reason is machine-readable | `failure.type=assert_visible_failed` | pass |
| failed assertion selector is recorded | selector text is `Definitely Not Existing` | pass |
| failure screenshot exists | `debug/step-002-failure.png` | pass |
| AX/hierarchy debug artifacts exist | `debug/step-002-ax.json`, `debug/step-002-hierarchy.json` | pass |
| evidence is not truncated | `run/events.jsonl` closes with `run.finished failed` | pass |
| evidence summary reads failure | `verdict=failure`, `frictionCount=1` | pass |

Unsupported evidence:

```bash
triton test run p0d-unsupported.tritontest.yaml --json --evidence-dir .../20260620-p0d-unsupported.tritonevidence
```

Observed facts:

| Fact | Evidence | Verdict |
|---|---|---|
| unsupported step remains validation_error | `error.type=validation_error`, `error.code=unsupported_step` | pass |
| CLI exit code is non-zero | smoke captured `EXIT_CODE=1` | pass |
| no evidence directory is created | `20260620-p0d-unsupported.tritonevidence` absent | pass |
| no primitive executor invocation | focused fake-executor test recorded zero operations | pass |

## Tests

Focused tests:

```bash
swift test --package-path CLI --filter TestRunExecutionTests
swift test --package-path CLI --filter TestValidationTests
```

Verification on 2026-06-20:

| Command | Result |
|---|---|
| `swift test --package-path CLI --filter TestRunExecutionTests` | pass, 3 tests |
| `swift test --package-path CLI --filter TestValidationTests` | pass, 7 tests |
| `triton status/doctor/capabilities/schema --json` before simulator smoke | pass; schema exposes P0D run contract |
| real pass smoke | pass, exit code 0 |
| real failure smoke | expected failure, command exit code 1 |
| real unsupported smoke | expected validation failure, command exit code 1, no evidence dir |

## Verdict

P0D verdict: `pass-with-gap`.

Allowed:

- Use `triton test run` for P0B-supported minimal deterministic flows.
- Continue improving evidence manifest and suite-level validation around this minimal executor.

Still blocked:

- Full runner execution surface.
- VLM / AI assertions.
- selector healing.
- App Map / screen transition graph.
- replay evidence.
- HTML / JUnit reports.
- `tap(text)`, `input`, `swipe`, `scrollUntilVisible`.

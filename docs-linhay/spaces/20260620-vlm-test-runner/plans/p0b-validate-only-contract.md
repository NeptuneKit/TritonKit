# P0B Validate Only Contract

## Verdict

P0A 只打开 P0B validate-only，不打开 runner execution。

P0B 的目标是把 `.tritontest.yaml` 离线解析为 normalized plan，并在失败时输出机器可读 validation error。它不访问设备、simulator、runtime server、VLM、App Map、evidence replay 或 `.tritonevidence/run`。

## Command

```bash
triton test validate docs-linhay/spaces/20260620-vlm-test-runner/samples/pass-contract.tritontest.yaml --json
triton test validate docs-linhay/spaces/20260620-vlm-test-runner/samples/pass-contract.tritontest.yaml --emit-normalized-plan --json
triton test normalize docs-linhay/spaces/20260620-vlm-test-runner/samples/pass-contract.tritontest.yaml --json
```

Invalid contract sample:

```bash
triton test validate docs-linhay/spaces/20260620-vlm-test-runner/samples/invalid-contract-swipe.tritontest.yaml --json
```

## Supported YAML Surface

Supported top-level fields:

- `version: 1`
- `name`
- `app.bundleId`
- `device.platform`
- `settings.strict`
- `settings.timeoutMs`
- `settings.retry.count`
- `settings.retry.intervalMs`
- `steps`

Supported steps only:

- `launch`
- `takeScreenshot`
- `tap.point`
- `assertVisible.text`

Out of P0B:

- step execution
- `tap(text)`
- input
- swipe
- `scrollUntilVisible`
- `assertNotVisible`
- VLM target
- AI assertion
- App Map
- replay

## Normalized Plan Shape

```json
{
  "schemaVersion": 1,
  "kind": "triton.test.normalized-plan",
  "name": "login-flow",
  "app": {
    "bundleId": "com.example.LoginFixture"
  },
  "device": {
    "platform": "ios"
  },
  "settings": {
    "strict": true,
    "timeoutMs": 5000,
    "retry": {
      "count": 0,
      "intervalMs": 250
    }
  },
  "steps": [
    {
      "index": 0,
      "id": "step-000",
      "kind": "action",
      "type": "launch",
      "optional": false
    },
    {
      "index": 1,
      "id": "step-001",
      "kind": "observation",
      "type": "takeScreenshot",
      "optional": false
    },
    {
      "index": 2,
      "id": "step-002",
      "kind": "action",
      "type": "tap",
      "optional": false,
      "point": {
        "x": 191.5,
        "y": 329.25,
        "coordinateSpace": "runtime-point"
      }
    },
    {
      "index": 3,
      "id": "step-003",
      "kind": "assertion",
      "type": "assertVisible",
      "optional": false,
      "selector": {
        "text": "Home",
        "match": "exact",
        "source": "ax"
      }
    }
  ]
}
```

## Validation Error Shape

```json
{
  "ok": false,
  "error": {
    "type": "validation_error",
    "message": "swipe is not supported by the P0B validate-only contract.",
    "path": "$.steps[0].swipe",
    "code": "unsupported_step",
    "allowed": ["launch", "takeScreenshot", "tap", "assertVisible"]
  }
}
```

Required error codes:

- `unknown_step`
- `missing_required_field`
- `invalid_point`
- `unsupported_step`
- `unsupported_selector`
- `unsupported_coordinate_space`
- `invalid_optional_type`
- `invalid_timeout`
- `duplicate_step_id`
- `invalid_app_bundle_id`

## Implementation Boundaries

- YAML parser: `Yams`, scoped to `CLI/Package.swift`.
- Root SwiftPM embedded SDK package remains unchanged.
- `triton test validate` and `triton test normalize` are offline commands.
- `test-validate` / `test-normalized-plan` capabilities are marked as `test` group and point back to offline CLI next actions.
- `test` schema exposes `test.validation` and `test.normalized-plan` output contracts.

## Smoke Result

Validated on 2026-06-20 with the local debug CLI:

```bash
CLI/.build/arm64-apple-macosx/debug/triton test validate \
  docs-linhay/spaces/20260620-vlm-test-runner/samples/pass-contract.tritontest.yaml \
  --json
```

Result:

- exit code: `0`
- `ok=true`
- `normalizedPlan.kind=triton.test.normalized-plan`
- 4 normalized steps: `launch`, `takeScreenshot`, `tap`, `assertVisible`

```bash
CLI/.build/arm64-apple-macosx/debug/triton test validate \
  docs-linhay/spaces/20260620-vlm-test-runner/samples/invalid-contract-swipe.tritontest.yaml \
  --json
```

Result:

- exit code: `1`
- `ok=false`
- `error.type=validation_error`
- `error.code=unsupported_step`
- `error.path=$.steps[0].swipe`
- `error.allowed=["launch","takeScreenshot","tap","assertVisible"]`

## P0C Stub

P0C is not implemented in this slice.

P0C should be named Run Event Writer + Fixture App, not test run. It should add only:

- fixture app with Login/Home failure states
- `.tritonevidence/run/events.jsonl`
- action/assert/screenshot event writer
- no general runner execution loop yet

P0D remains the first phase allowed to implement minimal runner execution.

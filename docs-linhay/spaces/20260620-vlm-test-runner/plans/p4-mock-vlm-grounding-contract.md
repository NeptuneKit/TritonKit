# P4 Mock VLM Grounding Contract

## Goal

建立离线、可测试、可审计的 VLM grounding 契约，为后续 OpenAI-compatible provider 和 runner VLM step 留接口。

P4 只回答一件事：给定截图、目标文案和 `coordinate-contract.json`，能否产出可复查的 `runtime-point` 与 overlay evidence。

## Scope

Implemented:

- `triton vlm ground --provider mock --image <screenshot.png> --target <text> --coordinate-contract <coordinate-contract.json> --json`
- `--output-dir <dir>` 写出 VLM grounding artifacts。
- mock provider 返回 `normalized_0_1000` 点位。
- CLI runtime 将 normalized point 转换为 canonical `runtime-point`。
- 输出 `TKVLMGroundResponse`，包含 image metadata、coordinate contract reference、point、transform 和 artifacts。
- 写出 `vlm-request.redacted.json`、`vlm-response.json`、`vlm-overlay.png`。
- overlay 显示 target、normalized point、runtime point、image sha prefix、crosshair 和 circle。
- fail-closed errors：unsupported provider、missing image、invalid coordinate contract、unsupported coordinate space、out-of-bounds point、overlay/artifact write failure。
- `triton schema` / `triton capabilities` 暴露 `vlm` command 与 `vlm-ground-mock` capability。

Out of scope:

- remote VLM
- API key / provider config
- OpenAI-compatible endpoint
- runner VLM step
- tap(text)
- selector healing
- App Map merge from VLM result
- AI assertion
- autonomous loop

## Command Contract

`triton vlm ground --provider mock --image <screenshot.png> --target "Go Home button" --coordinate-contract <coordinate-contract.json> --output-dir <dir> --json`

## Output Contract

Stable output model: `TKVLMGroundResponse`.

Required fields:

- `ok=true`
- `kind=triton.vlm.ground-result`
- `provider=mock`
- `point.normalized` in `normalized_0_1000`
- `point.runtimePoint` in `runtime-point`
- `transform.inputSpace=normalized_0_1000`
- `transform.imageSpace=image-pixel`
- `transform.outputSpace=runtime-point`
- `artifacts.overlay`
- `artifacts.request`
- `artifacts.response`

## Evidence Smoke

Input evidence:

- `docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260621-p2b-rerun.tritonevidence/debug/step-003-before.png`
- `docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260621-p2b-rerun.tritonevidence/coordinate-contract.json`

Generated artifacts:

- `docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260621-vlm-mock-grounding/vlm-overlay.png`
- `docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260621-vlm-mock-grounding/vlm-request.redacted.json`
- `docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260621-vlm-mock-grounding/vlm-response.json`

Smoke result:

- `provider=mock`
- `point.coordinateSpace=runtime-point`
- `point.runtimePoint=(201, 289.5)`
- `transform.inputSpace=normalized_0_1000`
- `transform.outputSpace=runtime-point`
- overlay crosshair lands on the fixture `Go Home` button.

## Validation

Passed:

- `swift test --package-path CLI --filter VLMGroundingTests`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `swift test --package-path CLI --filter AppMapPathGraphTests`
- `swift test --package-path CLI --filter ScreenWorkspaceProjectionTests`
- `swift test --package-path CLI --filter TestRunExecutionTests`
- `CLI/.build/debug/triton vlm ground --provider mock ... --json`

## Decision

P4 opens provider adapter work, not runner integration.

Next allowed step: OpenAI-compatible point grounding with localhost-first fail-closed policy.

Still blocked: using VLM result to trigger device action inside `triton test run`.

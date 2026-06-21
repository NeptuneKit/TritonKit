# P5 OpenAI-Compatible Point Grounding

## Goal

在 P4 mock grounding contract 之后，接入 OpenAI-compatible point grounding provider，但保持安全边界：默认 localhost-first、远端显式授权、无 runner execution 集成。

## Scope

Implemented:

- `triton vlm ground --provider openai-compatible`。
- `--base-url <url>` 指向 OpenAI-compatible `/v1` base。
- `--model <model>` 指定模型名，默认 `vlm-grounding`。
- `--api-key-env <ENV>` 从环境变量读取 API key，不把 secret 写入 artifact。
- `--allow-remote-vlm` 显式允许非 localhost provider。
- 默认只允许 `localhost`、`127.0.0.1`、`::1`。
- 调用 `/chat/completions`，请求包含 target prompt 与 screenshot data URL。
- strict parser 支持 `(x,y)`、顶层 JSON point、嵌套 `point` / `normalized` / `normalizedPoint`。
- provider 返回点位仍统一为 `normalized_0_1000`，CLI runtime 转换到 `runtime-point`。
- output 顶层新增 `model` 与 redacted `baseURL`。
- request artifact 只保存 image metadata、target、model、baseURL、redaction/network，不保存 base64 screenshot。
- response artifact 保存 provider rawText 与 parsed normalized point。

Out of scope:

- runner VLM step
- tap(text)
- AI assertion
- selector healing
- remote provider 默认启用
- provider 配置文件
- App Map merge from VLM result
- autonomous loop

## Failure Contract

New failure codes:

- `vlm_openai_base_url_required`
- `vlm_openai_base_url_invalid`
- `vlm_remote_provider_requires_approval`
- `vlm_api_key_missing`
- `vlm_provider_request_invalid`
- `vlm_provider_request_failed`
- `vlm_provider_response_invalid`
- `vlm_provider_point_parse_failed`

These failures occur before artifact write when configuration or authorization is invalid.

## CLI Smoke

A temporary localhost fixture server was started on `127.0.0.1:19455` and returned a Chat Completions-compatible response:

`{"choices":[{"message":{"content":"{\"point\":{\"x\":500,\"y\":331.2356979405034}}"}}]}`

Smoke command:

`triton vlm ground --provider openai-compatible --base-url http://127.0.0.1:19455/v1 --model fixture-grounder --image <step-003-before.png> --target "Go Home button" --coordinate-contract <coordinate-contract.json> --output-dir <dir> --json`

Generated artifacts:

- `docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260621-vlm-openai-compatible-grounding/vlm-overlay.png`
- `docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260621-vlm-openai-compatible-grounding/vlm-request.redacted.json`
- `docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260621-vlm-openai-compatible-grounding/vlm-response.json`

Smoke result:

- `provider=openai-compatible`
- `model=fixture-grounder`
- `baseURL=http://127.0.0.1:19455/v1`
- `point.runtimePoint=(201, 289.5)`
- `transform.outputSpace=runtime-point`

## Validation

Passed:

- `swift test --package-path CLI --filter VLMGroundingTests`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- localhost fixture server CLI smoke

## Decision

P5 opens provider configuration and real localhost model-server integration.

Still blocked: using provider output as a runner action. That remains a later explicit runner/VLM integration phase.

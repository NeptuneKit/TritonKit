# Local MLX Swift VLM Provider

## Background

TritonKit already has a VLM grounding contract for screenshot + target text -> normalized point -> runtime-point evidence. The current providers are deterministic mock and OpenAI-compatible HTTP. This space adds a local MLX Swift provider track without making model inference part of the default runner path.

## Goal

Build P17-P22 as a staged local VLM provider program:

- P17 fake MLX provider contract
- P18 real-model manual smoke
- P19 explicit MLX-assisted tap(target)
- P20 provider comparison
- P21 App Map VLM health
- P22 model cache management

## Scope

P17-P22 add the local MLX Swift VLM provider track as a controlled grounding backend. The track covers fake CI grounding, a manual real-model gate, explicit runner opt-in, provider comparison, App Map health, and local model cache governance.

The first implementation keeps the main CLI free of a hard `mlx-swift-lm` package dependency. The default test path uses the deterministic fake provider contract; true model loading remains a manual gate until a local model/helper is available.

## BDD Scenarios

### P17 provider discovery

Given the CLI is built
When an agent runs `triton vlm providers --json`
Then `mlx-swift-lm` appears as an experimental local VLM provider
And it is not enabled by default in CI
And it reports point-grounding support.

### P17 fake grounding

Given a screenshot, coordinate contract, target, and fake helper raw response
When an agent runs `triton vlm ground --provider mlx-swift-lm --model-path <path> --image <png> --target <text> --coordinate-contract <json> --json`
Then the command returns `triton.vlm.ground-result`
And writes request, response, raw output, parsed point, transform, overlay, and model metadata artifacts
And the output point is in runtime-point space.

### P17 fail closed

Given the fake helper returns unsupported output
When an agent runs MLX grounding
Then the command returns one machine-readable error envelope
And no tap or runner action is executed.

### P19 explicit runner opt-in

Given a `.tritontest.yaml` step uses `tap.target` with `grounding: vlm`
When an agent runs `triton test run` without `--allow-vlm`
Then validation or execution fails closed
And no tap is performed.

Given `--allow-vlm` is present
When grounding succeeds through `mlx-swift-lm`
Then the runner taps the resolved runtime point
And evidence includes VLM request, response, parsed point, transform, overlay, and model metadata.

### P20 provider comparison

Given one screenshot, coordinate contract, and target
When an agent runs `triton vlm compare` with multiple providers
Then each provider records an independent passed or failed result
And the command writes comparison metrics and overlay evidence.

### P21 App Map health

Given run evidence contains VLM grounding events
When an agent merges it into `.tritonmap`
Then screens, transitions, and paths can expose provider-level `vlmHealth`
And `triton map vlm-health` returns aggregate provider statistics.

### P22 model cache

Given a local MLX model cache directory
When an agent runs `triton vlm model list|inspect|preflight|prune|remove`
Then the command stays local, never downloads by default, and only removes ready models through explicit `remove`.

## Non-goals

- No autonomous GUI loop.
- No model output action execution.
- No default runner dependency.
- No default model download.
- No true model smoke in CI.
- No App Map health until P21.

## Validation

P17-P22 default validation is fake/local-only:

- `swift test --package-path CLI --filter 'VLMProviderComparisonTests|VLMModelCacheTests|AppMapVLMHealthTests|TestValidationTests|VLMMlxSwiftLM|SchemaFactSourceTests'`
- `triton vlm providers --json`
- `triton schema --command vlm --json`
- `triton schema --command map --json`
- `triton capabilities --json`
- `git diff --check`
- `docs-linhay/scripts/check-docs.sh`

Manual real-model validation is tracked separately in `plans/p18-real-model-smoke.md` and must not become default CI.

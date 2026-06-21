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

P17 is the first implementation slice. It must add provider-level contracts, strict parser behavior, deterministic fake helper execution, evidence artifacts, schema/capability visibility, and tests. Real model inference and runner execution expansion stay out until P17 is stable.

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

## Non-goals

- No autonomous GUI loop.
- No model output action execution.
- No default runner dependency.
- No default model download.
- No true model smoke in CI.
- No App Map health until P21.

## Validation

P17 must pass focused parser/evidence tests, VLM schema/capability smoke, `git diff --check`, and `docs-linhay/scripts/check-docs.sh`.

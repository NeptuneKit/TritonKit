# Local MLX Swift VLM Provider

## Current governance — 2026-11-03

[Issue #274](https://github.com/NeptuneKit/TritonKit/issues/274) and [SP-273](../SP-273-issue-274-explicit-inference/README.md) govern the current explicit-inference change. Both local inference (including llama-server) and OpenAI-compatible inference default to disabled; the outer agent consumes Triton observation/control/evidence. Saving provider/model/endpoint/API-key environment/helper configuration or granting remote access does not enable inference or authorize a daemon launch/model load.

Workspace opt-in is CLI `--enable-llm` / `--enable-vlm`, or HTTP optional `enableLLM` / `enableVLM` (default `false`), independently. An LLM-only run does not need VLM readiness. `--dry-model-fixture` remains synthetic mock-only and does not consume online/helper configuration. Dedicated `vlm ground/compare --provider ...` requests retain their explicit inference meaning and default mock; model download and deterministic replay `--allow-vlm` remain separately authorized. Provider errors stay bounded and visible, with no hidden local fallback.

BDD: configured-but-disabled providers receive no inference requests or helper launches; enabling only the requested provider preserves that separation; basic observation/control/evidence works without model readiness. New implementation and validation are tracked in SP-273, not asserted passed here. The reported llama-server process ownership, startup trigger, and low-memory slowdown have not been reproduced or attributed. Historical helper smoke does not establish low-memory stability. Human-dependent validation is outside the current autonomous delivery scope, without converting unknowns into passes.

SP-273 budget contract: online POST transport has a 30-second total deadline with task cancellation requested on timeout, not an end-to-end command bound or a response-memory limit. MLX grounding/download retain 120/3600-second execution budgets plus up to 4 seconds of direct-helper TERM/KILL cleanup and a shared 0.25-second EOF drain budget; stdout/stderr retention is 1 MiB each and truncated stdout fails. Unknown descendants are not guaranteed terminated. Controlled timeout/pipe fixtures do not establish real-model inference, download, or low-memory acceptance.

The P17–P23 plan below is historical scope and evidence. Its manual-gate references describe the original plan, not a new request for human work. Any later workspace default-on direction is superseded by the explicit-inference contract above.

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
- P23 explicit model download command

## Scope

P17-P23 add the local MLX Swift VLM provider track as a controlled grounding backend. The track covers fake CI grounding, a manual real-model gate, explicit runner opt-in, provider comparison, App Map health, local model cache governance, and explicit helper-mediated model download.

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

### P23 model download

Given an external MLX helper is configured
When an agent runs `triton vlm model download <model-id> --provider mlx-swift-lm --json`
Then the main CLI invokes the helper, writes the model into the local cache, inspects the ready entry, and returns `triton.vlm.model-download-result`.

Given no helper is configured
When an agent runs the same command
Then it fails closed with `mlx_helper_required` and does not create a model cache entry.

## Non-goals

- No autonomous GUI loop.
- No model output action execution.
- No default runner dependency.
- No default model download.
- No true model smoke in CI.
- No App Map health until P21.

## Validation

P17-P23 default validation is fake/local-only:

- `swift test --package-path CLI --filter 'VLMProviderComparisonTests|VLMModelCacheTests|AppMapVLMHealthTests|TestValidationTests|VLMMlxSwiftLM|SchemaFactSourceTests'`
- `triton vlm providers --json`
- `triton vlm model download <model-id> --helper <helper> --json`
- `triton schema --command vlm --json`
- `triton schema --command map --json`
- `triton capabilities --json`
- `git diff --check`
- `docs-linhay/scripts/check-docs.sh`

Manual real-model validation is tracked separately in `plans/p18-real-model-smoke.md` and must not become default CI.

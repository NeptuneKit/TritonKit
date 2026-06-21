# P18 Real Model Manual Smoke

## Objective

Validate that a real local `mlx-swift-lm` vision-language model can ground a fixture screenshot into a parseable runtime point. This is a manual gate and is intentionally excluded from default CI.

## Preconditions

- Apple Silicon Mac.
- A local VLM model compatible with `mlx-swift-lm`.
- No model weights committed to the repository.
- Fixture screenshot and `coordinate-contract.json` available.

## Commands

TritonKit keeps the main CLI unlinked from MLX. A real model smoke must provide an executable helper through `TRITON_MLX_HELPER` or `TRITON_MLX_SWIFT_LM_HELPER`.

Helper argv contract:

    <helper> ground --request <request.json>

The helper reads the request JSON and writes only the raw point output to stdout, for example `{"x":512,"y":734,"scale":1000}`. TritonKit parses, transforms, validates, overlays, and records evidence.

Example smoke:

    export TRITON_MLX_HELPER=/path/to/triton-mlx-provider

    triton vlm model preflight <model-path> --provider mlx-swift-lm --json

    triton vlm ground \
      --provider mlx-swift-lm \
      --model-path <model-path> \
      --image <fixture-login.png> \
      --target "Go Home button" \
      --coordinate-contract <coordinate-contract.json> \
      --output-dir /tmp/triton-mlx-ground \
      --json

    triton vlm compare \
      --image <fixture-login.png> \
      --target "Go Home button" \
      --coordinate-contract <coordinate-contract.json> \
      --provider mock \
      --provider mlx-swift-lm \
      --model-path <model-path> \
      --json

## Evidence To Keep

- `artifacts/mlx-smoke-result.json`
- `artifacts/mlx-grounding-overlay.png`
- `artifacts/mlx-model-metadata.json`
- model id or local path reference
- raw output and parsed point
- latency note

Do not commit model weights, tokenizer files, downloaded cache directories, or large generated screenshots unless they are intentionally curated golden artifacts.

## Done Definition

1. At least one true local model completes `vlm ground`.
2. The response is parsed by TritonKit's strict grounding parser.
3. Overlay can be inspected manually and lands near the requested UI target.
4. Model metadata and latency are recorded.
5. The smoke remains manual and out of default CI.

## Current Status

Manual gate pending until a compatible local model/helper is available in the developer environment. The CLI-side external helper contract is implemented and covered by tests; no true model weights were present in `~/.cache/triton/mlx-models` during this run.

The helper contract is also documented at `Tools/TritonMLXProvider/README.md` for external helper implementation.

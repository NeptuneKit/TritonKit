# P20 Provider Comparison

## Objective

Add `triton vlm compare` so agents can compare multiple grounding providers against the same screenshot, target, and coordinate contract.

## Command

    triton vlm compare \
      --image <fixture-login.png> \
      --target "Go Home button" \
      --coordinate-contract <coordinate-contract.json> \
      --provider mock \
      --provider mlx-swift-lm \
      --agreement-threshold-points 24 \
      --json

## Output Contract

The command returns `triton.vlm.compare-result` with provider-level status, runtime points, error category, latency, agreement metrics, `compare-overlay.png`, and `compare-results.json`.

## Failure Policy

One provider failure does not crash the whole comparison. The failed provider records a machine-readable error result and successful providers still contribute to agreement metrics.

## Done Definition

1. `mock`, `openai-compatible`, and `mlx-swift-lm` are accepted providers.
2. Provider-level success/failure is represented in JSON.
3. Agreement threshold defaults to 24 runtime points and is configurable.
4. Overlay and structured result artifacts are written.
5. Schema/capability taxonomy exposes the command.

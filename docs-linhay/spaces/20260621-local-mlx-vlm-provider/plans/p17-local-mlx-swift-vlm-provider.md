# P17 Local MLX Swift VLM Provider

## Objective

Add `mlx-swift-lm` as a local VLM grounding provider behind the existing TritonKit VLM contract, using a deterministic fake helper for CI and tests. P17 proves contract, parser, evidence, and schema behavior without loading a real model.

## Implementation Rules

- Keep MLX as a provider adapter, not a runner dependency.
- Do not add `mlx-swift-lm` to the root Package.swift.
- Prefer helper/subprocess isolation; the first P17 implementation may use a fake helper contract only.
- Default model download is disabled.
- Provider output must be strict point grounding, not actions or plans.
- Evidence must be written for every successful grounding call.

## Required Artifacts

Successful MLX fake grounding writes:

- `mlx-grounding-request.redacted.json`
- `mlx-grounding-response.json`
- `mlx-grounding-raw-output.txt`
- `mlx-grounding-parsed-point.json`
- `mlx-grounding-transform.json`
- `mlx-grounding-overlay.png`
- `mlx-model-metadata.json`

## Parser Contract

Accepted outputs:

- `{"x":512,"y":734,"scale":1000}`
- `{"point":{"x":512,"y":734,"scale":1000}}`
- `(512, 734)`
- `{"error":"target_not_visible"}`

Rejected outputs:

- multiple points
- natural language explanations
- action lists
- missing x/y
- out-of-bounds points
- unsupported scale

## Done Definition

1. `triton vlm providers --json` shows `mlx-swift-lm` as experimental.
2. `triton vlm ground --provider mlx-swift-lm` can complete through deterministic fake helper behavior.
3. Parser, coordinate, evidence, and overlay tests pass.
4. Default behavior does not download models.
5. Default runner behavior is unchanged.
6. Schema/capability taxonomy includes provider and artifacts.

# P19 MLX-Assisted Runner

## Objective

Allow `tap.target` steps to use `mlx-swift-lm` only when runner execution is explicitly started with `--allow-vlm`. The model remains a point-grounding backend; AX assertions and the rest of the flow stay deterministic.

## Contract

- `--allow-vlm` is required for any VLM-assisted tap.
- `--vlm-allow-model-download` is separately required before model download can be allowed.
- Grounding success resolves one runtime point and then delegates to the existing point tap primitive.
- Grounding failure fails closed and never taps.
- Evidence records VLM artifacts and event metadata.
- App Map paths produced from VLM grounding use `source: vlm-assisted`.

## Explicit Non-Goals

- No model-generated multi-action plan.
- No autonomous loop.
- No default CI real-model run.
- No implicit model download.

## Done Definition

1. Validation preserves MLX local model fields for `tap.target`.
2. Runner accepts MLX-assisted tap only behind explicit VLM allowance.
3. Failure before point resolution does not execute a tap.
4. Evidence contains provider, model/modelPath, target, point, and artifacts.
5. App Map can distinguish `vlm-assisted` paths from deterministic paths.

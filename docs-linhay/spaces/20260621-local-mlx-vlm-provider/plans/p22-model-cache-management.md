# P22 MLX Model Cache Management

## Objective

Provide local cache governance for `mlx-swift-lm` models without making model download implicit or uncontrolled.

## Commands

    triton vlm model list --provider mlx-swift-lm --json
    triton vlm model inspect <model-id-or-path> --provider mlx-swift-lm --json
    triton vlm model preflight <model-id-or-path> --provider mlx-swift-lm --json
    triton vlm model prune --provider mlx-swift-lm --json
    triton vlm model remove <model-id-or-path> --provider mlx-swift-lm --json

## Cache Location

Default: `~/.cache/triton/mlx-models/`

Override: `TRITON_MLX_MODEL_CACHE=/path/to/cache`

## Policy

- Default behavior never downloads models.
- `prune` removes incomplete, temporary, or corrupt cache entries only.
- Ready model removal requires explicit `remove <model-id-or-path>`.
- `preflight` checks local readiness and does not execute a UI action.
- Model metadata can be referenced from grounding evidence.

## Done Definition

1. `list`, `inspect`, `preflight`, `prune`, and `remove` are available.
2. Cache dir is configurable through `TRITON_MLX_MODEL_CACHE`.
3. Ready models are not deleted by `prune`.
4. Explicit `remove` is required for ready model deletion.
5. Schema/capability taxonomy exposes model cache contracts.

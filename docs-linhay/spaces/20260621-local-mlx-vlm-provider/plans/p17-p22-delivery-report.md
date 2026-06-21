# P17-P22 Delivery Report

## Completed In Code

- P17: `mlx-swift-lm` provider contract with deterministic fake grounding, strict parser, coordinate transform, overlay, evidence, schema, and capability exposure.
- P19: VLM-assisted `tap.target` local model fields and explicit runner allowance plumbing.
- P20: `triton vlm compare` with provider-level results, agreement metrics, and comparison artifacts.
- P21: App Map VLM health projection, `triton map vlm-health`, and static viewer health summary.
- P22: `triton vlm model list|inspect|preflight|prune|remove` with local cache policy.

## Manual Gate

P18 remains a manual real-model gate. It requires a compatible local `mlx-swift-lm` VLM model and must produce human-inspectable overlay/evidence before being marked complete.

## Validation

Focused suite:

    swift test --package-path CLI --filter 'VLMProviderComparisonTests|VLMModelCacheTests|AppMapVLMHealthTests|TestValidationTests|VLMMlxSwiftLM|SchemaFactSourceTests'

Result:

    129 tests passed

## Intentional Boundaries

- No hard `mlx-swift-lm` dependency in the main CLI target.
- No default model download.
- No real-model CI.
- No autonomous model action loop.
- No direct execution of model-generated multi-action output.
- HTML viewer remains static readonly.

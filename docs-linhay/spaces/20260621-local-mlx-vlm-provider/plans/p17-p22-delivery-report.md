# P17-P22 Delivery Report

## Completed In Code

- P17: `mlx-swift-lm` provider contract with deterministic fake grounding, strict parser, coordinate transform, overlay, evidence, schema, and capability exposure.
- P18 helper contract: `TRITON_MLX_HELPER` / `TRITON_MLX_SWIFT_LM_HELPER` can point to an external `mlx-swift-lm` executable using `ground --request <request.json>` and stdout-only raw point output.
- P19: VLM-assisted `tap.target` local model fields and explicit runner allowance plumbing.
- P20: `triton vlm compare` with provider-level results, agreement metrics, and comparison artifacts.
- P21: App Map VLM health projection, `triton map vlm-health`, and static viewer health summary.
- P22: `triton vlm model list|inspect|preflight|prune|remove` with local cache policy.

## Manual Gate

P18 real-model gate passed with a quality gap. A local helper built from `mlx-swift-lm` loaded `mlx-community/Qwen2-VL-2B-Instruct-4bit` from `~/.cache/triton/mlx-models/qwen2-vl-2b-instruct-4bit`, returned parseable normalized point JSON, and TritonKit generated the normal VLM evidence bundle.

Evidence:

- `docs-linhay/spaces/20260621-local-mlx-vlm-provider/evidence/20260621-p18-qwen2-vl-real-helper/cli-response.json`
- `docs-linhay/spaces/20260621-local-mlx-vlm-provider/evidence/20260621-p18-qwen2-vl-real-helper/mlx-grounding-overlay.png`
- `docs-linhay/spaces/20260621-local-mlx-vlm-provider/evidence/20260621-p18-qwen2-vl-real-helper/mlx-model-metadata.json`

The Qwen2-VL 2B output was `{"x": 500, "y": 500, "scale": 1000}`, producing runtime point `{x: 201, y: 437}`. This is enough to prove the local MLX runtime chain, but not enough to trust grounding quality for default runner execution.

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

## Helper Scaffold

The external helper contract is documented at `Tools/TritonMLXProvider/README.md`. This keeps `mlx-swift-lm` and model downloader/tokenizer dependencies outside the default `triton` CLI package while preserving a stable P18 manual smoke entry.

The helper is a separate SwiftPM executable package. It depends on:

- `mlx-swift-lm`
- `mlx-swift` through `mlx-swift-lm`
- `swift-transformers`
- `swift-huggingface`

Current `mlx-swift` SwiftPM builds code dependencies but does not colocate `mlx.metallib` for this helper executable. `Tools/TritonMLXProvider/Scripts/build-mlx-metallib.sh` compiles the MLX Metal kernels and copies `mlx.metallib` next to `triton-mlx-provider`.

## Next Model Baseline

Qwen3-VL is now the correct forward-looking baseline. The first smoke used `Qwen2-VL-2B-Instruct-4bit` only because it is small enough for a fast manual runtime proof. Next comparison should use:

- `lmstudio-community/Qwen3-VL-4B-Instruct-MLX-4bit`
- `mlx-community/Qwen2.5-VL-3B-Instruct-4bit`

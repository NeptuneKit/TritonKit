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

Manual real-model gate passed with a quality gap.

The helper contract is documented at `Tools/TritonMLXProvider/README.md` for external helper implementation.

## 2026-06-21 Smoke Result

### Model

- Provider: `mlx-swift-lm`
- Helper: `Tools/TritonMLXProvider/.build/arm64-apple-macosx/debug/triton-mlx-provider`
- Metal runtime: colocated `Tools/TritonMLXProvider/.build/arm64-apple-macosx/debug/mlx.metallib`
- Model: `mlx-community/Qwen2-VL-2B-Instruct-4bit`
- Model path: `~/.cache/triton/mlx-models/qwen2-vl-2b-instruct-4bit`
- Model size on disk: about 1.2 GiB

### Helper Build Notes

`mlx-swift-lm` is pulled through SwiftPM, but the current `mlx-swift` SwiftPM package does not emit `mlx.metallib` as a colocated runtime resource for this helper executable. The helper therefore requires:

    swift build --package-path Tools/TritonMLXProvider -c debug --product triton-mlx-provider
    Tools/TritonMLXProvider/Scripts/build-mlx-metallib.sh debug

The script compiles MLX Metal kernels into `mlx.metallib` and copies it next to the helper binary.

### Direct Helper Smoke

Command shape:

    Tools/TritonMLXProvider/.build/arm64-apple-macosx/debug/triton-mlx-provider ground --request /tmp/request.json

Result:

    {"x": 500, "y": 500, "scale": 1000}

Latency:

    real 4.25s

### Triton CLI Smoke

Command shape:

    TRITON_MLX_HELPER=$PWD/Tools/TritonMLXProvider/.build/arm64-apple-macosx/debug/triton-mlx-provider \
      swift run --package-path CLI triton vlm ground \
        --provider mlx-swift-lm \
        --image docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0a-smoke/pass-before.png \
        --target "Fixture Login" \
        --coordinate-contract docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0e-fixture-pass.tritonevidence/coordinate-contract.json \
        --model mlx-community/Qwen2-VL-2B-Instruct-4bit \
        --model-path ~/.cache/triton/mlx-models/qwen2-vl-2b-instruct-4bit \
        --no-model-download \
        --output-dir docs-linhay/spaces/20260621-local-mlx-vlm-provider/evidence/20260621-p18-qwen2-vl-real-helper \
        --json

Evidence:

- `docs-linhay/spaces/20260621-local-mlx-vlm-provider/evidence/20260621-p18-qwen2-vl-real-helper/cli-response.json`
- `docs-linhay/spaces/20260621-local-mlx-vlm-provider/evidence/20260621-p18-qwen2-vl-real-helper/mlx-grounding-overlay.png`
- `docs-linhay/spaces/20260621-local-mlx-vlm-provider/evidence/20260621-p18-qwen2-vl-real-helper/mlx-model-metadata.json`
- `docs-linhay/spaces/20260621-local-mlx-vlm-provider/evidence/20260621-p18-qwen2-vl-real-helper/mlx-grounding-raw-output.txt`
- `docs-linhay/spaces/20260621-local-mlx-vlm-provider/evidence/20260621-p18-qwen2-vl-real-helper/mlx-grounding-parsed-point.json`

Parsed output:

    normalized = { x = 500, y = 500, scale = 1000 }
    runtimePoint = { x = 201, y = 437 }

### Verdict

- Real local MLX model execution: `pass`
- Triton external helper integration: `pass`
- Evidence generation: `pass`
- Grounding quality for `Fixture Login`: `pass-with-gap`

The Qwen2-VL 2B smoke proves the local inference chain, but the returned point is generic center-screen output and should not unlock default VLM-assisted runner execution. Qwen3-VL 4B 4bit should be the next baseline model for quality comparison.

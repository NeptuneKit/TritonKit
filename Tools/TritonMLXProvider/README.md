# Triton MLX Provider Helper

This directory documents the helper executable contract used by `triton vlm ground --provider mlx-swift-lm`.

The main `triton` CLI intentionally does not link `mlx-swift-lm`, tokenizer packages, downloader packages, or model weights. Real local VLM inference is delegated to an external helper so the default CLI build and CI remain lightweight.

## Runtime Contract

Set one of these environment variables before running TritonKit:

    export TRITON_MLX_HELPER=/absolute/path/to/triton-mlx-provider
    # or
    export TRITON_MLX_SWIFT_LM_HELPER=/absolute/path/to/triton-mlx-provider

TritonKit invokes:

    $TRITON_MLX_HELPER ground --request <request.json>

The helper must:

- read the JSON request file
- load or reuse the requested local MLX VLM model
- run one screenshot + target grounding prompt
- write only the raw point response to stdout
- write diagnostics to stderr
- exit non-zero on model loading or generation failure

Accepted stdout examples:

    {"x":512,"y":734,"scale":1000}
    {"point":{"x":512,"y":734,"scale":1000}}
    (512,734)
    {"error":"target_not_visible"}

Do not print explanations, action lists, chain-of-thought, logs, or progress messages to stdout.

## Request Shape

The helper receives a JSON object with this stable shape:

    {
      "schemaVersion": 1,
      "provider": "mlx-swift-lm",
      "model": "mlx-community/Qwen2.5-VL-3B-Instruct-4bit",
      "modelPath": "/Users/me/.cache/triton/mlx-models/qwen2.5-vl",
      "image": {
        "path": "/path/to/screenshot.png",
        "width": 402,
        "height": 874,
        "sha256": "..."
      },
      "target": "Go Home button",
      "maxTokens": 64,
      "temperature": 0,
      "seed": 0,
      "promptTemplate": "gui-grounding-v1",
      "allowModelDownload": false
    }

If both `modelPath` and `model` are present, prefer `modelPath`. If only `model` is present and `allowModelDownload` is false, the helper should use an already cached model or fail closed.

## Prompt Boundary

The helper should send only the screenshot and target grounding prompt to the model. It must not send full test plans, App Map graphs, previous run traces, secrets, or multi-action budgets.

Prompt intent:

    You are a GUI visual grounding model.
    Given a screenshot and a target description, locate the center point of the target UI element.
    Return ONLY compact JSON:
    {"x": <number>, "y": <number>, "scale": 1000}
    Coordinates are normalized to [0, 1000].
    If the target is not visible, return {"error":"target_not_visible"}.

## Official MLX Swift LM Notes

The current `mlx-swift-lm` main branch is a Swift 6.1+ 3.x package. It exposes `MLXVLM`, `MLXLMCommon`, and `MLXHuggingFace`; its VLM quick start uses a `ChatSession` with `respond(to:image:)`, and the `VLMRegistry` includes models such as `mlx-community/Qwen2.5-VL-3B-Instruct-4bit` and `HuggingFaceTB/SmolVLM2-500M-Video-Instruct-mlx`.

A real helper should be developed and tested outside the main CLI package first, then pointed at TritonKit through `TRITON_MLX_HELPER` for P18 manual smoke.

## Build Helper

Build the helper executable with SwiftPM:

    swift build --package-path Tools/TritonMLXProvider -c debug --product triton-mlx-provider

The SwiftPM dependency chain brings in `mlx-swift-lm`, `mlx-swift`, `swift-transformers`, and `swift-huggingface`. The current `mlx-swift` SwiftPM package compiles the Swift/C++ code but does not emit the Metal runtime library as a package resource for this external executable. The helper therefore also needs a colocated `mlx.metallib`.

Generate and copy the Metal runtime library next to the executable:

    Tools/TritonMLXProvider/Scripts/build-mlx-metallib.sh debug

Expected colocated files:

    Tools/TritonMLXProvider/.build/arm64-apple-macosx/debug/triton-mlx-provider
    Tools/TritonMLXProvider/.build/arm64-apple-macosx/debug/mlx.metallib

Without `mlx.metallib`, MLX fails before model loading with `Failed to load the default metallib`.

## Model Baseline

Use `Qwen3-VL` as the forward-looking local VLM baseline. For the first P18 smoke, `mlx-community/Qwen2-VL-2B-Instruct-4bit` was used because it is materially smaller and downloads quickly enough for a manual gate.

Recommended sequence:

- First smoke: `mlx-community/Qwen2-VL-2B-Instruct-4bit`
- Baseline: `lmstudio-community/Qwen3-VL-4B-Instruct-MLX-4bit`
- Comparison candidate: `mlx-community/Qwen2.5-VL-3B-Instruct-4bit`

## P18 Manual Smoke

    triton vlm model preflight <model-path> --provider mlx-swift-lm --json

    TRITON_MLX_HELPER=/absolute/path/to/triton-mlx-provider \
      triton vlm ground \
        --provider mlx-swift-lm \
        --model-path <model-path> \
        --image <fixture-login.png> \
        --target "Go Home button" \
        --coordinate-contract <coordinate-contract.json> \
        --output-dir /tmp/triton-mlx-ground \
        --json

The gate is complete only after a real model produces parseable output and the generated overlay is manually checked.

Current local smoke result:

- Model: `mlx-community/Qwen2-VL-2B-Instruct-4bit`
- Model path: `~/.cache/triton/mlx-models/qwen2-vl-2b-instruct-4bit`
- Image: `docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0a-smoke/pass-before.png`
- Target: `Fixture Login`
- CLI evidence: `docs-linhay/spaces/20260621-local-mlx-vlm-provider/evidence/20260621-p18-qwen2-vl-real-helper/`
- Raw output: `{"x": 500, "y": 500, "scale": 1000}`
- Runtime point: `{"x": 201, "y": 437}`
- Status: real model path passed, grounding quality remains weak and should not enable default runner execution.

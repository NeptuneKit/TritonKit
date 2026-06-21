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

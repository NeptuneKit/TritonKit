# TritonMLXProvider

Experimental local MLX VLM grounding helper for TritonKit test-runner research.

This tool is intentionally isolated under `Tools/`:

- it is not part of the root SwiftPM package;
- it is not built by default CI or release packaging;
- it does not change the current public `triton vlm ground` provider list;
- it is a local model backend candidate for future `openai-compatible` / helper-adapter work.

## Contract

```bash
triton-mlx-provider ground --request request.json
```

The request is JSON:

```json
{
  "schemaVersion": 1,
  "provider": "mlx-swift-lm",
  "model": "mlx-community/Qwen2-VL-2B-Instruct-4bit",
  "modelPath": null,
  "image": {
    "path": "/absolute/path/screenshot.png",
    "width": 402,
    "height": 874,
    "sha256": "optional-known-sha"
  },
  "target": "登录按钮",
  "maxTokens": 64,
  "temperature": 0,
  "seed": null,
  "promptTemplate": null,
  "allowModelDownload": false
}
```

The helper loads a local `modelPath`, or downloads `model` only when `allowModelDownload=true`. Stdout is a compact JSON object compatible with TritonKit's VLM provider response artifact shape:

```json
{
  "schemaVersion": 1,
  "provider": "mlx-swift-lm",
  "model": "mlx-community/Qwen2-VL-2B-Instruct-4bit",
  "coordinateSpace": "normalized_0_1000",
  "point": {
    "x": 500,
    "y": 331,
    "scale": 1000
  },
  "confidence": 1,
  "rationale": "local MLX VLM point grounding response",
  "rawText": "{\"x\":500,\"y\":331,\"scale\":1000}"
}
```

## Validation

```bash
swift package describe --package-path Tools/TritonMLXProvider
swift build --package-path Tools/TritonMLXProvider --scratch-path .build/tools-mlx-provider
```

Do not wire this helper into default TritonKit CI, release assets, or public skills until the CLI has an explicit local-helper provider contract.

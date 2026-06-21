# P23 Model Download Command

## Objective

Add an explicit CLI entry for local MLX model download while keeping the main `triton` CLI free of `mlx-swift-lm`, tokenizer, HuggingFace downloader, and model-weight dependencies.

## Command

    triton vlm model download <model-id> \
      --provider mlx-swift-lm \
      --cache-dir ~/.cache/triton/mlx-models \
      --helper /absolute/path/to/triton-mlx-provider \
      --json

`--helper` is optional when `TRITON_MLX_HELPER` or `TRITON_MLX_SWIFT_LM_HELPER` is set.

## Boundary

- The main CLI does not download model files directly.
- Download requires the external helper and fails closed with `mlx_helper_required` when no helper is configured.
- Ready cache entries are idempotent and return `status=already-ready` without invoking the helper.
- Existing incomplete cache directories are not overwritten unless `--force` is passed.
- Downloaded model files are written to the local model cache and are never committed to the repo.

## Helper Contract

The CLI invokes:

    <helper> download --request <request.json>

Request:

    {
      "schemaVersion": 1,
      "provider": "mlx-swift-lm",
      "model": "mlx-community/Qwen2-VL-2B-Instruct-4bit",
      "cacheDir": "/Users/me/.cache/triton/mlx-models",
      "outputPath": "/Users/me/.cache/triton/mlx-models/mlx-community__Qwen2-VL-2B-Instruct-4bit",
      "force": false
    }

Helper stdout:

    {"modelPath":"/Users/me/.cache/triton/mlx-models/mlx-community__Qwen2-VL-2B-Instruct-4bit","bytesDownloaded":123456}

Diagnostics and progress must go to stderr.

## Output

The CLI returns `triton.vlm.model-download-result`:

    {
      "ok": true,
      "provider": "mlx-swift-lm",
      "model": "mlx-community/Qwen2-VL-2B-Instruct-4bit",
      "status": "downloaded",
      "downloaded": true,
      "modelPath": "...",
      "modelEntry": {
        "status": "ready"
      }
    }

## Validation

- `swift test --package-path CLI --filter 'VLMModelCacheTests|SchemaFactSourceWorkflowTests|SchemaFactSourceTaxonomies'`
- `swift build --package-path Tools/TritonMLXProvider -c debug --product triton-mlx-provider`
- CLI smoke with fake helper:

    triton vlm model download mlx-community/Fake-VL-4bit \
      --provider mlx-swift-lm \
      --cache-dir /tmp/triton-models \
      --helper /tmp/fake-helper.sh \
      --json

## Verdict

P23 is complete when download appears in help/schema/capabilities, helper-mediated CLI smoke returns a ready cache entry, and model cache tests cover helper invocation plus fail-closed missing-helper behavior.

---
name: tritonkit-local-mlx-vlm-provider
description: Use when designing, implementing, or validating TritonKit local MLX Swift VLM provider work, including mlx-swift-lm helper contracts, model cache/download commands, Qwen model smoke, Metal runtime resources, and VLM-assisted runner boundaries.
metadata:
  version: 0.1.0-dev
---

# TritonKit Local MLX Swift VLM Provider

Use this skill when work touches the local `mlx-swift-lm` VLM provider track:

- `triton vlm providers`, `ground`, `compare`, or `model *`
- `mlx-swift-lm` / `swift-transformers` / `swift-huggingface` helper integration
- local model cache, explicit model download, preflight, prune, or remove
- Qwen VL model selection or real local model smoke
- VLM-assisted workspace / runner defaults and evidence-gated execution boundaries

## Product Boundary

The main `triton` CLI owns schema, capabilities, evidence, coordinate transforms, runner policy, and machine-readable errors.

The main CLI must not link heavy ML runtime dependencies or model weights directly:

- no direct `mlx-swift-lm` dependency in `CLI/Package.swift`
- no direct `swift-transformers` or `swift-huggingface` dependency in the main CLI
- no model weights, model caches, `.build` products, or downloaded Hugging Face snapshots in git

Real local MLX execution is delegated to an external helper package under `Tools/TritonMLXProvider/`.

## Helper Contract

Resolve the helper through explicit CLI option or environment:

- `--helper <path>` when a command supports it
- `TRITON_MLX_HELPER`
- `TRITON_MLX_SWIFT_LM_HELPER`

Grounding helper:

```bash
triton-mlx-provider ground --request <request.json>
```

Download helper:

```bash
triton-mlx-provider download --request <request.json>
```

The helper writes only compact machine output to stdout:

- `ground`: one raw point result, such as JSON point or tuple point
- `download`: JSON containing at least `modelPath`, optionally `bytesDownloaded`

Progress logs, model loading diagnostics, and download progress must go to stderr. Triton parses stdout and continues to own response validation, coordinate transform, overlay generation, evidence artifacts, and error envelopes.

## Metal Runtime Resource

SwiftPM pulls MLX Swift/C++ sources, but the external helper may not automatically colocate `mlx.metallib` / `default.metallib` beside the helper binary.

If real MLX execution fails before model inference with a missing metallib error, rebuild and copy the Metal runtime:

```bash
Tools/TritonMLXProvider/Scripts/build-mlx-metallib.sh debug
```

Do not vendor the generated metallib unless a future packaging plan explicitly chooses that distribution model.

## Model Cache Commands

The local cache command family is:

```bash
triton vlm model list --json
triton vlm model inspect <model-id> --json
triton vlm model preflight <model-id> --json
triton vlm model download <model-id> --provider mlx-swift-lm --helper <helper> --json
triton vlm model prune --json
triton vlm model remove <model-id> --json
```

Default cache root is `~/.cache/triton/mlx-models`, overridable by `TRITON_MLX_MODEL_CACHE` or command option when available.

Required behavior:

- ready cache entries are idempotent and return `already-ready`
- incomplete cache entries are not overwritten unless `--force` is explicit
- missing helper fails closed with `mlx_helper_required`
- prune never deletes ready models
- ready model deletion requires explicit `remove`

## Workspace / Runner Policy

The Agent Mobile Runtime Platform product direction now defaults LLM/VLM on for local `workspace run` and bounded explore flows:

- LLM/VLM participates in flow bootstrap, flow recovery, scene understanding, selector disambiguation, Atlas labeling, next-action candidate generation, and workflow seed generation by default
- direct VLM grounding commands still expose explicit flags/options for focused CLI use
- local replay / stable regression keeps model participation on; policy can restrict actions to plan-first while LLM/VLM still helps bootstrap the flow, recover from drift, observe, verify, diagnose, and suggest repair
- pass/fail impact is still controlled by step / runner policy; model conclusions are assistive unless explicitly marked `required`
- `workspace run` can now call a real local OpenAI-compatible LLM decision provider with `--llm-provider openai-compatible --llm-base-url <local /v1> --llm-model <model>`, can preflight/write evidence for OpenAI-compatible VLM with `--vlm-provider openai-compatible --vlm-base-url <local /v1> --vlm-model <model>`, can use VLM grounding before bounded tap actions when the selected observation has a readable local screenshot artifact, can continue a bounded recovery loop after post-action business checkpoint failure with step-indexed model/action/verify artifacts and Atlas deltas, projects the run-local Atlas into `atlas/app-map/`, and can merge that run-local app-map into a long-lived local map with `workspace merge-map` or `POST /workspace/runs/:runId/merge-map`; `mlx-swift-lm` workspace helper wiring remains a follow-up

Default-on must not weaken execution boundaries:

- no direct model action execution
- no model-generated multi-action plan execution
- no hidden fallback from deterministic selectors to VLM; default VLM fallback must be reported as `usedVLM=true` with confidence, artifacts, and fallback reason
- no screenshot or evidence upload to remote models by default
- every model participation must be evidence-backed and policy-gated

`tap.target` with VLM grounding must write evidence artifacts for request, raw output, parsed point, transform, overlay, model metadata, confidence, and policy decision. The model proposes a point or selector candidate; Triton still owns coordinate transform, action execution, error envelope, and ledger output.

## Model Selection Baseline

Treat small real-model smoke as chain validation, not quality validation.

Current local baseline facts:

- `mlx-community/Qwen2-VL-2B-Instruct-4bit` proves local helper execution and evidence wiring.
- Qwen3-VL / Qwen2.5-VL family models are better candidates for future grounding quality comparison.
- Real model quality gates must remain manual until latency, output stability, and point accuracy are measured on fixture screenshots.

## Validation

For code changes, start with focused red tests before implementation. Useful filters:

```bash
swift test --package-path CLI --filter VLMMlxSwiftLM
swift test --package-path CLI --filter VLMModelCacheTests
swift test --package-path CLI --filter VLMProviderComparisonTests
swift test --package-path CLI --filter SchemaFactSourceWorkflowTests
```

For helper changes:

```bash
swift build --package-path Tools/TritonMLXProvider -c debug --product triton-mlx-provider
```

For real local model validation, keep it manual and evidence-backed:

```bash
TRITON_MLX_HELPER=<helper> swift run --package-path CLI triton vlm ground --provider mlx-swift-lm --model <model-id> --image <fixture.png> --target <text> --coordinate-contract <coordinate-contract.json> --evidence-dir <dir> --json
```

Before closing the work:

```bash
git diff --check
docs-linhay/scripts/check-docs.sh
```

Run full `swift test --package-path CLI` only when runtime contracts, shared schema, or CLI command behavior changed.

## Evidence Policy

Keep curated small evidence only when it explains a gate:

- request/response JSON
- overlay image when useful
- compact real-smoke CLI response
- plan or delivery report references

Do not commit:

- model cache snapshots
- Hugging Face model files
- large screenshot bundles
- `.build` directories
- transient logs

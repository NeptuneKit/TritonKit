# VLM models, local cache and explicit inference

## Prerequisites

Inference is optional. Ordinary observation/actions/evidence work without a model. The CLI family is **`vlm model` (singular)**; inspect the installed release before choosing commands:

```bash
triton version --json
triton schema --command vlm --json
triton vlm providers --json
triton vlm model list --json
```

Local `mlx-swift-lm` execution needs a separately built/installed compatible `triton-mlx-provider` helper and its Metal runtime resources; the CLI does not embed heavy ML libraries or model weights. Model download uses network/disk and requires explicit authorization. Remote inference can send screenshots/business evidence off-host and needs separate consent.

## Workflow

### Inspect, download, preflight

Use an explicit model ID or the returned cache path. Default cache is `~/.cache/triton/mlx-models`, overridden by `TRITON_MLX_MODEL_CACHE`; download also has `--cache-dir`.

```bash
triton vlm model inspect '<model-id-or-path>' --json
triton vlm model preflight '<model-id-or-path>' --json
triton vlm model download '<model-id>' --provider mlx-swift-lm --helper '<helper-path>' --cache-dir '<owned-cache-root>' --json
triton vlm model preflight '<downloaded-model-path>' --json
```

Download helper selection is `--helper`, then `TRITON_MLX_HELPER` / `TRITON_MLX_SWIFT_LM_HELPER`. A ready cache can return `already-ready`; incomplete entries fail rather than being silently overwritten. `--force` explicitly permits replacement; do not use it as an automatic recovery step. Preserve `mlx_helper_required` and provider diagnostics when no helper is available.

### Ground or compare a captured image

Use a real screenshot and its matching coordinate contract; never guess image-to-runtime scale or treat OCR pixels as an executable OID. Dedicated `ground`/`compare` default to mock; explicitly selecting a real provider requests inference. These commands produce candidates/evidence, not App input.

```bash
triton vlm ground --provider mock --image '<screen.png>' --target 'Continue' --coordinate-contract '<coordinate-contract.json>' --output-dir '<fresh-grounding-dir>' --json
triton vlm compare --provider mock --image '<screen.png>' --target 'Continue' --coordinate-contract '<coordinate-contract.json>' --output-dir '<fresh-comparison-dir>' --json
```

For OpenAI-compatible inference, select `--provider openai-compatible`, `--base-url`, `--model` and, where required, `--api-key-env`. Non-local endpoints additionally need `--allow-remote-vlm`. For local MLX select `--provider mlx-swift-lm` plus `--model`/`--model-path`; helper selection uses the environment on these grounding commands, not an invented `ground --helper` flag. Download during grounding is off unless explicitly allowed; `--no-model-download` wins over `--allow-model-download`.

### Participate in Workspace

Configuration is not enablement. `workspace run` requires `--enable-llm` and/or `--enable-vlm`; HTTP uses `enableLLM`/`enableVLM`, both false by default. Remote consent alone never enables inference, and LLM-only runs need not pass VLM readiness. Read [workspace runs](workspace-runs.md) before combining these options with lifecycle/target/observation settings.

```bash
triton workspace run --target '<selector>' --app '<app>' --goal 'Inspect next step' --enable-vlm --vlm-provider mlx-swift-lm --vlm-model-path '<model-path>' --vlm-helper '<helper-path>' --json
```

This does not authorize App actions. `--execute-actions` is a separate opt-in; each action still needs a current observation, provider/policy checks and a business wait/assertion. `--dry-model-fixture` is synthetic and ignores real online/helper configuration. A grounding failure stops before runtime input, retains its failure/recovery artifacts, and must not trigger hidden selector/model fallback.

### Cache lifecycle

```bash
triton vlm model list --json
triton vlm model prune --json
triton vlm model remove '<model-id-or-path>' --json
```

**Prune and remove delete cache data.** Authorize them separately; the commands have no invented `--confirm`/`--dry-run` safety flags. Prune removes incomplete entries, never ready models; remove is the explicit ready-model deletion path. Inspect exact ownership/model identity first, avoid active helpers and preserve needed artifacts. Do not remove caches to conceal a failed load or download.

## Verification

Inspect `ok`, status, preflight checks, selected provider, actual model path, raw/parsed grounding, coordinate transform, overlay and request/response artifacts. A preflight only establishes its reported checks; mock output and a returned point do not prove real inference quality, physical tapping or business success.

Online Workspace transport has a 30-second total deadline; ongoing bytes do not reset it. Local helper budgets are 120 seconds grounding and 3600 seconds download, followed by bounded cleanup/drain; retained output is capped at 1 MiB per stream and truncated stdout is rejected. These component bounds do not prove immediate remote cancellation, strict whole-command duration, low-memory behavior or cleanup of every unknown descendant.

## Limits

No default screenshot upload, automatic model loading, hidden local fallback, model-generated multi-action execution or automatic App replay. API keys are selected by environment-variable name, not pasted into evidence/examples. Preserve raw local business facts; sharing/inference permission is a caller decision.

A missing metallib is a helper deployment failure, not an excuse to weaken model validation. Use the helper provider's documented build/install process; do not vendor generated MLX libraries or model weights into the skills bundle. Real quality needs controlled latency, stability and grounding-accuracy samples. Cache presence or one historical smoke is not that acceptance.

# P21 App Map VLM Health

## Objective

Project VLM grounding outcomes into App Map health so `.tritonmap` can answer which providers are succeeding, failing, or becoming slow for grounded targets.

## Merge Inputs

`triton map merge` reads `vlm.grounding.finished`, `vlm.grounding.failed`, and failure events associated with normalized VLM tap steps.

## Map Fields

Screens, transitions, and paths may carry `vlmHealth.providers.<provider>` with grounding runs, success count, failure count, parse failures, out-of-bounds failures, mean latency, last model, and last seen timestamp.

VLM-assisted paths must preserve `source: vlm-assisted`, provider id, and grounding target.

## Command

    triton map vlm-health .tritonmap --json
    triton map vlm-health .tritonmap --provider mlx-swift-lm --json
    triton map vlm-health .tritonmap --screen screen-fixture-login --json

## Viewer

The static App Map viewer includes a readonly VLM provider health summary. It does not control devices or execute model calls.

## Done Definition

1. Merge reads VLM grounding events.
2. Provider health aggregates success, failure, parse failure, out-of-bounds, and latency.
3. `map vlm-health` supports global, provider, and screen-scoped inspection.
4. `map inspect` remains stable and is not overloaded with VLM noise.
5. Viewer displays a provider health summary.

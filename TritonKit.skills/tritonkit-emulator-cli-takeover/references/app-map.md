# App-map paths, suites and flow export

## Prerequisites

An App-map is a local `.tritonmap` directory projected from evidence/Workspace Atlas, not an assertion that every transition was executed or verified. Keep the original run evidence. Use a current installed schema and an operator-owned map/evidence directory:

```bash
triton schema --command map --json
triton schema --command workspace --json
```

Read [workspace runs](workspace-runs.md) for target resolution, app launch, observation, optional inference and business checkpoints. Map edits and test execution need their own task authorization.

## Workflow

1. Merge an existing evidence run or Workspace run without silently confirming its paths:

```bash
triton map merge '<run.tritonevidence>' --into '<app.tritonmap>' --json
triton workspace merge-map '<run-id>' --map-dir '<app.tritonmap>' --json
```

The optional `--confirm` confirms eligible generated paths; inspect them first instead of making it a default. Run IDs and paths below are observed outputs, not names to invent.

2. Inspect inventory, coverage and replay health:

```bash
triton map inspect '<app.tritonmap>' --json
triton map health '<app.tritonmap>' --json
triton map screens '<app.tritonmap>' --offset 0 --limit 100 --json
triton map transitions '<app.tritonmap>' --offset 0 --limit 100 --json
triton map paths '<app.tritonmap>' --offset 0 --limit 100 --json
triton map path show '<app.tritonmap>' --path '<path-id>' --json
```

CLI list commands accept offset/limit (1–1000) and report truncation/next offset. Preserve screen state variants rather than merging different observed UI states into a claimed single state.

3. When a reviewed path is replayable and suite inclusion is authorized, confirm and add it:

```bash
triton map path confirm '<app.tritonmap>' --path '<path-id>' --json
triton map suite add-path '<app.tritonmap>' --suite smoke --path '<path-id>' --json
triton map suite inspect '<app.tritonmap>' --suite smoke --json
```

`path unconfirm` removes eligibility and suite membership; `suite remove-path` removes only that suite membership. These modify the map, not the App.

4. Export one reviewed path and validate the resulting plan before running it:

```bash
triton map export-flow '<app.tritonmap>' --path '<path-id>' --out '<fresh-flow.tritontest.yaml>' --json
triton test validate '<fresh-flow.tritontest.yaml>' --json
triton map viewer '<app.tritonmap>' --output '<fresh-viewer.html>' --json
```

`map export-flow` uses `--out`; `workspace export-flow <run-id>` uses `--output`. A static viewer does not execute tests or repair the map.

5. Only with a ready exact runtime target and authorized App actions, run the selected suite:

```bash
triton map suite run '<app.tritonmap>' --suite smoke --target '<runtime-target>' --evidence-root '<owned-evidence-root>' --json
```

The suite exports flows, invokes the existing live test executor and merges result evidence. VLM-assisted test steps remain disabled unless `--allow-vlm` is explicit; remote VLM requires its separate consent/configuration. Do not silently enable models to make a deterministic test pass.

## Verification

Read `coverage`, state/transition health, unhealthy refs, `coveredByPathIds`, `coveredBySuite`, `replayable` and issue codes such as `uncovered_by_suite`. Observed screens, confirmed paths, suite coverage, pass/fail/flake counts and business-verified transitions are different facts.

A confirmation is a user's local eligibility decision, not a successful test. `unconfirmed_path`, `non_replayable_path`, `empty_app_map_suite` or partial/failed run evidence must not be upgraded to pass. Preserve the original failure/recovery envelope before investigating artifacts; do not blindly rerun the suite after unknown delivery.

`map vlm-health <map> --provider <id> --screen <id> --json` reports recorded provider/screen health, not a new inference or model-quality acceptance. The equivalent local HTTP read/query routes are in [HTTP API](http-api.md).

## Limits

No universal reset recipe, automatic full-app exploration, 3×20 reliability acceptance, all-platform parity or permanent task owner is established by map presence. Filesystem mutation, App mutation, model calls and artifact export have separate authorization and verification boundaries. Use [test recorder/import](../../tritonkit-real-project-regression/references/test-recorder.md) for recorded source contracts rather than an invented replay engine.

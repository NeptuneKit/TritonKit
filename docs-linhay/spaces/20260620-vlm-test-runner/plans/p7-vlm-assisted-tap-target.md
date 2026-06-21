# P7 VLM-assisted tap(target)

## Goal

Connect the existing VLM grounding provider contract to `triton test run` without turning the runner into an autonomous agent.

This phase only allows one explicit visual grounding operation for `tap(target)`, then converts the result into the existing runtime-point tap primitive. The runner remains the owner of validation, execution budget, artifacts, failure classification, and evidence.

## Implemented Scope

Validate / normalize accepts:

- `tap.target`
- `tap.grounding: vlm`
- `tap.provider: mock`
- `tap.provider: openai-compatible`

Runner execution accepts VLM-assisted tap only when the user passes `triton test run <path.tritontest.yaml> --json --allow-vlm`.

Remote OpenAI-compatible endpoints still require explicit remote approval with `--allow-remote-vlm`.

Execution behavior:

- Reuses P0B validate / normalize before any device operation.
- Rejects VLM-assisted steps with `vlm_step_not_allowed` before runtime resolution when `--allow-vlm` is missing.
- Captures before observation from the runner-owned runtime state.
- Calls `groundVLMTarget` with the before screenshot and `coordinate-contract.json`.
- Converts provider output into canonical `runtime-point`.
- Executes the existing tap primitive with the resolved runtime point.
- Captures after observation.
- Writes `vlm.grounding` into `.tritonevidence/run/events.jsonl`.
- Saves `vlm-overlay.png`, `vlm-request.redacted.json`, and `vlm-response.json`.

## App Map Impact

`.tritonmap` path merge now marks paths derived from evidence containing a `vlm.grounding` event as `source: vlm-assisted`.

Deterministic paths remain `source: deterministic`.

If the same path is first observed deterministically and later observed with VLM-assisted evidence, the path source upgrades to `vlm-assisted` without creating a duplicate path.

## Explicitly Out Of Scope

- `tap(text)`
- `tap(id)`
- `tap(index)`
- relationship selectors
- selector healing
- VLM retries beyond provider-level failure handling
- AI assertions
- AI defect scan
- VLM action provider
- autonomous loop
- suite runner
- JUnit / HTML report

## Failure Contract

Validation failures:

- `unsupported_grounding`
- `vlm_unsupported_provider`
- existing `unsupported_selector` for `tap.text`

Runtime failures:

- `vlm_step_not_allowed`
- `vlm_image_not_found`
- `vlm_coordinate_contract_not_found`
- `vlm_coordinate_contract_invalid`
- `vlm_coordinate_space_unsupported`
- `vlm_image_metadata_unavailable`
- `vlm_artifact_write_failed`
- `vlm_openai_base_url_required`
- `vlm_openai_base_url_invalid`
- `vlm_remote_provider_requires_approval`
- `vlm_api_key_missing`
- `vlm_provider_request_invalid`
- `vlm_provider_request_failed`
- `vlm_provider_response_invalid`
- `vlm_provider_point_parse_failed`
- `vlm_point_out_of_bounds`

## Validation

Targeted checks completed during implementation:

- `swift test --package-path CLI --filter TestValidationTests --filter TestRunExecutionTests --filter RunEventWriterTests --filter ScreenWorkspaceProjectionTests --filter AppMapPathGraphTests`

Result: passed, 27 tests.

Full collective validation remains the final gate for the current large implementation slice.

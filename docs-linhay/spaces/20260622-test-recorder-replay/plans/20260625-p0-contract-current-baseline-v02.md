# Test Recorder P0 Contract Current Baseline v02

> Space: `20260622-test-recorder-replay`
> Date: 2026-06-25
> Baseline: `origin/main` at `5761b754`
> Purpose: freeze the latest implemented contract surface after the P0 handoff and matrix/evidence hardening slices.

## Current product decision

The product boundary remains unchanged:

1. Test Recorder is the delivery vehicle; Agent Runtime is observed but not extracted.
2. `.tritontestcase` is the durable test contract package.
3. `inspect / compile / replay / matrix` are the current machine-readable control surfaces.
4. Web remains read-only workspace / rendered surface / page inspector / evidence viewer, not a business-control surface.
5. LLM / VLM may produce or explain proposals later, but current P0 execution is deterministic and does not let models decide pass / fail.

## Implemented P0 contract surface

| Area | Current state |
| --- | --- |
| Package | `.tritontestcase` with `manifest.json`, `contract-capabilities.json`, raw action/network/page streams and compiled artifacts. |
| Inspect | Validates required package files, capabilities ref, artifact presence, artifact identity, lifecycle stage and health. |
| Compile | Deterministic compiler creates `compiled-contract.json`, action map, page map, network map, redacted fixtures, quality findings and `compile-proposals.jsonl`. |
| Proposals | `triton testrec proposals` is read-only; proposals are review inputs and do not auto-apply. |
| Page match | `triton testrec match-page` consumes compiled source fingerprint and caller-provided target fingerprint, scores with deterministic matcher and returns evidence. |
| Replay dry-run | Produces page checks, planned Triton argv, blockers, executor profiles and redaction gate without touching devices. |
| Local simulated replay | Offline executor writes replay result, JSONL events, run summary, manifest artifacts, target fingerprints and copied network fixtures when requested. |
| Matrix | `triton testrec matrix` fans out dry-run or local-simulated replay across target selectors. |
| Matrix evidence | `--executor local-simulated --evidence-root` writes one evidence bundle per target and suggests generic `triton evidence summary` follow-up commands. |
| HTTP | Local management routes mirror the CLI case operations for session/event/stop, inspect, compile, proposals, match-page, replay dry-run, replay and matrix. |

## Model and evidence boundary

Current P0 is intentionally model-free at execution time:

- `llmUsed=false`
- `vlmUsed=false`
- `llmDecisionAuthority=false`
- caller-provided target fingerprints are treated as evidence inputs, not as live model calls
- deterministic matcher owns score and decision
- redaction findings block dry-run, local-simulated replay and matrix until reviewed

This keeps the future LLM / VLM role clean: models can generate fingerprints, explanations and candidate mappings, but replay status still needs deterministic checks and evidence artifacts.

## Evidence baseline

The latest merged slices established these evidence properties:

1. replay evidence bundle is readable by generic `triton evidence summary`;
2. `manifest.run.summary` aligns with replay result status, step count and friction count;
3. page match evidence can trace to `pages/target-fingerprints.json` when target fingerprints are supplied;
4. network results can trace to copied fixture artifacts in evidence bundles;
5. matrix local-simulated mode writes isolated per-target evidence bundles instead of one aggregate manifest;
6. matrix suggested commands include per-target replay commands and per-target `evidence summary` commands;
7. redaction blockers propagate through dry-run matrix and local-simulated matrix.

## Deliberate gaps

These remain outside the current baseline:

- system-level action listener;
- true live target-device executor;
- real VLM fingerprint generation during replay;
- LLM proposal apply / approve / reject workflow;
- network fixture application to a live proxy;
- runtime-core extraction;
- Web/Wails product UI;
- cloud device farm, remote agents, SaaS dashboard or multi-user collaboration.

## Next smallest useful slices

Do not reopen product discussion before these are either done or explicitly rejected:

1. Improve `match-page` follow-up suggestions so boundary cases point agents to `inspect`, `proposals` and `compile` review commands.
2. Add a narrow contract test that `contract-capabilities.json` unsupported items never count as pass in replay/matrix summaries.
3. Add HTTP parity coverage only where CLI contract fields already exist.
4. Start real executor design only after a separate plan defines target discovery, device action execution, evidence capture and destructive-policy boundaries.
5. Defer Agent Runtime extraction until at least one real target-device replay produces useful failure evidence.

## Review rule

When this space feels like it wants `runtime-core`, stop and ask:

> Is this needed to make `.tritontestcase -> inspect -> compile -> replay/matrix -> evidence` more reliable right now?

If the answer is no, it belongs in a future Agent Runtime space, not this P0 line.

# Test Recorder P0 Contract Handoff v01

## Scope

This handoff covers the P0 contract path only:

1. `.tritontestcase` package contract.
2. `contract-capabilities.json` and `manifest.capabilitiesRef`.
3. `triton testrec inspect`.
4. `triton testrec compile`.
5. `triton testrec replay --dry-run` and `--executor local-simulated`.

Out of scope for this P0 remains unchanged: system-level action recording, real device replay, Runtime extraction, Web/Wails product UI, live LLM/VLM calls, and network policy application.

## Current evidence

- Branch: `codex/20260622-test-recorder-replay-evidence`.
- Base: `origin/main` at `bde9af6f` / `v0.2.4`.
- Local delta at handoff: `0 behind / 15 ahead` before this handoff note.
- Full local gate passed with elevated execution for socket-capable tests:
  - `docs-linhay/scripts/verify.sh --local`
- Focused gates already covered during implementation:
  - `swift test --package-path CLI --scratch-path /private/tmp/triton-testrec-origin-check-build2 --filter TestRecorderContractTests`
  - `swift test --package-path CLI --scratch-path /private/tmp/triton-testrec-origin-check-build2 --filter SchemaFactSourceTests`
  - `git diff --check`
  - `docs-linhay/scripts/check-docs.sh`

## P0 acceptance status

| Requirement | Status | Evidence |
| --- | --- | --- |
| `.tritontestcase` schema | Satisfied for P0 | `manifest.json`, `contract-capabilities.json`, artifact identity, lifecycle, schema contracts |
| capability contract | Satisfied for P0 | `manifest.capabilitiesRef` honored, path-limited to package, reflected in `artifacts[]` |
| inspect | Satisfied for P0 | validates required files, invalid JSON, unsupported capabilities, artifact identity, lifecycle |
| compile | Satisfied for P0 | deterministic compiled contract, action/page/network maps, redacted fixtures, quality findings, proposals |
| replay dry-run | Satisfied for P0 | page checks, planned Triton argv, blockers, executor profiles, redaction gate |
| local-simulated replay | Satisfied for P0 | replay-result, page/network/step evidence, contractRef, manifest parity, fixture artifact checks |
| model role boundary | Satisfied for P0 | `llmUsed=false`, `vlmUsed=false`, deterministic matcher, no model decision authority |
| Web UI | Deferred | README keeps Web out of P0; no Web/Wails control surface added |

## Known deliberate gaps

- No global OS action listener.
- No real target-device executor.
- No live VLM fingerprint generation; caller-provided target fingerprints are consumed as evidence.
- No LLM proposal apply / approve / reject flow.
- No runtime-core extraction; Action Map / Page Map / Network Map remain Test Recorder internals.
- No network fixture application to a live proxy.

## Next smallest useful step

If continuing this branch, prefer merge / PR preparation over adding product surface. The next implementation work should be a separate slice only if it closes one of the deliberate gaps above.

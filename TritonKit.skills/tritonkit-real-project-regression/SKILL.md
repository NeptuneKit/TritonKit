---
name: tritonkit-real-project-regression
description: Use when TritonKit moves from demo/self-test into a real iOS app, Harmony app, or customer project for regression testing, adoption validation, or actual requirement discovery. Guides the AI agent to isolate external repo changes, run release CLI plus host-side or embedded runtime checks, collect machine-readable evidence, and turn real-project gaps into docs, fixes, or GitHub issues.
metadata:
  version: 0.1.0-dev
---

# TritonKit Real Project Regression

## Principle

Real-project validation is not demo smoke. Treat the business app as an external system under test:

- Do not mix real-app repo changes into TritonKit commits.
- Prefer released `triton` for external adoption checks.
- Preserve command, JSON output, screenshot, evidence, or issue links for every finding.
- Do not publish private app identity, bundle IDs, accounts, internal hosts, private paths, credentials, full logs, or unredacted evidence.

## Standard Workflow

1. Confirm app repo, branch, target device/simulator/emulator, and requirement.
2. Check both repos before changing anything:
   ```bash
   git status --short --branch
   ```
3. Prepare CLI and confirm binary:
   ```bash
   triton version --json
   ```
4. Start the local server explicitly when embedded runtime is needed:
   ```bash
   triton serve --host 127.0.0.1 --port 19421
   ```
5. Preserve Triton-first facts before fallback:
   ```bash
   triton doctor --json
   triton status --json
   triton capabilities --json
   triton schema --json
   ```
6. Observe before action, execute the smallest flow, then verify business state with `wait`, `verify`, screenshot, or evidence.
7. Redact before sharing externally.
8. If the real app exposes a TritonKit gap, use `tritonkit-dev-feedback` to prepare a redacted issue.

## Reference Routing

Start with [references/feature-index.md](references/feature-index.md) to map the requested feature to the smallest reference file. Then read only the matched reference(s).

## Common Commands

Triton-first facts:

```bash
triton doctor --json
triton status --json
triton capabilities --json
triton schema --json
triton list --json
```

Observation and verification:

```bash
triton observe tree --platform <ios|android|harmony> --device <selector> --outline --json
triton wait --text '<text>' --timeout 15 --json
triton verify text-exists '<text>' --json
triton screenshot --output /tmp/<case>.png --json
triton evidence capture --case <case> --output /tmp/<case>.tritonevidence --json
```

Treat evidence capture as one machine-readable completion gate: parse stdout as exactly one manifest and inspect `ok`, `partial`, top-level `error`, and every `skipped[].error`. Expected unsupported artifacts may yield `ok:true, partial:true`; request or artifact-write failures yield `ok:false, partial:true`, `error.code=evidence_capture_partial`, and a non-zero exit. Do not accept a bundle merely because some status/list/version artifacts exist.

Planning and replay:

```bash
triton plan ios-smoke --device <selector> --bundle-id <bundle-id> --url <url> --text <text> --evidence /tmp/<case>.tritonevidence --json
triton plan inspect <file.tritonplan> --json
triton replay <file.tritonplan> --dry-run --json
triton replay <file.tritonplan> --json
```

For recorder-derived flows, only `triton test import <case.tritontestcase> --output <plan.tritontest.yaml> --bundle-id <bundle-id> --device-platform ios-simulator --json`, then `triton test validate`, then `triton test run --target <target-id>` can lead to a real runtime verdict. If a future 3 × 20 reliability collection is being prepared, `triton test reliability-preflight --collection <private.json> --json` may freeze its private inputs only: accept `ready_to_collect` only with `writesEvidence=false`, `usesRuntime=false`, and `eligibleForReliabilityGate=false`; its negative control must not reuse a supported flow's normalized-plan digest and must declare an exact `expectedFailureType` for a non-optional, read-only terminal assertion. It does not boot/select a Simulator, start/reuse a server, reset an App, write evidence, or prove a verdict. Keep its private path/UDID/bundle/target/reset data out of public reports, then use a separately authorized live harness for actual collection. `testrec replay --dry-run`, `local-simulated`, and `matrix` are offline diagnostics: even if their compatibility fields say `ready`, `passed`, or `passedCount`, require `verdictBoundary.countsAsRealTestVerdict=false` and do not use them as regression evidence or reliability-gate samples. Treat an older replay result without this boundary as legacy/unknown, not affirmative proof.

For an explicitly authorized receipt-backed collection, run `test reliability-reserve` only against a fresh private root; then call `test reliability-sample` one slot at a time with `--confirm`, exact canonical iOS Simulator/App target, private reset receipt, and an operator-owned already-running `127.0.0.1:19421` server. The receipt root holds a collection-wide lease: a busy or stale lease fails closed before target execution and must not be deleted or reused automatically. It must not manage App/Simulator/server lifecycle or clean/retry evidence. Treat the sample's single typed JSON result as the verdict contract: an expected negative nonpass is `ok=true` / exit 0 only for terminal `failed` with the exact frozen assertion failure type; a supported nonpass, unexpected negative pass, or wrong negative failure type is `ok=false` / exit 1 without a second error envelope. Legacy `test reliability --samples` is diagnostic-only and cannot pass the Stage 1 gate. Configuration, receipt, reset, or target rejection is a single `TKCLIErrorResponse`. Do not begin a live collection without explicit dedicated-target, reset, server-ownership, negative-control, and private-evidence authorization.

## Completion Gate

- Requirement has machine-readable pass/fail evidence.
- Real app repo changes are isolated and explicitly reported.
- TritonKit repo changes, if any, have focused tests and docs/memory updates.
- Public handoff is redacted.
- Any product gap is turned into a doc update, code fix, or redacted GitHub issue.

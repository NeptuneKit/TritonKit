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

## Completion Gate

- Requirement has machine-readable pass/fail evidence.
- Real app repo changes are isolated and explicitly reported.
- TritonKit repo changes, if any, have focused tests and docs/memory updates.
- Public handoff is redacted.
- Any product gap is turned into a doc update, code fix, or redacted GitHub issue.

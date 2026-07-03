# Space: 20260703-issue-131-doctor-host-device-scope

## Issue

- GitHub: https://github.com/NeptuneKit/TritonKit/issues/131
- Title: `[Feature] Scope doctor next actions for host-side device workflows`

## Background

`triton doctor --json` can currently report `ok: true` while making an embedded action-surface warning, such as `press`, the primary next action. During host-side Harmony workflows, agents need guidance toward `triton device ... --platform harmony` rather than embedded runtime diagnostics.

## BDD

1. Given host-side Harmony device commands are available in the CLI schema
2. When an agent inspects `triton doctor --json`
3. Then the doctor output should include a host-device workflow next action
4. And an `ok=true` doctor response must not make unrelated embedded action diagnostics the only primary path for host-device work

## Scope

- In scope: doctor machine-readable checks/next action ranking, schema contract tests, docs/memory.
- Out of scope: changing `triton device doctor` behavior, running real HDC/DevEco commands, introducing a long-lived server dependency.

## Validation

- Red: add a doctor contract test proving host-device guidance is absent or outranked.
- Green:
  - `swift test --package-path CLI --scratch-path .build/cli-test --filter SchemaFactSourceTests/doctorResponseExposesOrderedRecoveryChecks`
  - `swift test --package-path CLI --scratch-path .build/cli-test --filter SchemaFactSourceTests/agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts`
  - `git diff --check`
  - `docs-linhay/scripts/check-docs.sh`
  - `docs-linhay/scripts/verify.sh --local`

## Notes

- Top-level `triton doctor` now accepts `--platform ios|android|harmony`.
- Without `--platform`, `ok=true` doctor output uses `host-device` as the primary next step and returns `triton device list --json`.
- With `--platform harmony`, primary next action is `triton device list --platform harmony --json`.
- Embedded `action-surface` warnings remain in `checks[]`; they no longer outrank host-device guidance when there is no failure.

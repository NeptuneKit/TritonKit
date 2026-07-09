# GitHub Issues 141-142: Host Device And Cell Tap Contracts

## Background

This space records the 2026-07-09 issue closure slice for:

- GitHub issue #141: activate selectable collection/table cells from `act tap`.
- GitHub issue #142: make Harmony host-device discovery, schemas, and open-url failure envelopes agent-safe.

No feature worktree was created because the fix is a small same-day contract hardening change on `main`.

## BDD Acceptance

Scenario: iOS coordinate tap lands inside a selectable `UICollectionViewCell`.

- Given the embedded runtime resolves the hit point inside a visible collection view cell.
- When an agent runs `triton act tap --x <x> --y <y> --json`.
- Then Triton activates the selectable cell ancestor and reports `strategy=ancestor-collection-cell-selection`.

Scenario: an agent asks for host-device schemas.

- Given `triton device list --platform harmony --json` is a valid host-device command.
- When the agent runs `triton schema --command "device list" --json`.
- Then Triton returns a machine-readable `device` schema filtered to the `list` subcommand instead of `unknown_command_schema`.

Scenario: Harmony `aa start` reports failure on stdout while `hdc` exits 0.

- Given `hdc shell aa start -U` prints `error: failed to start ability` or `Error Code:<code>`.
- When Triton runs `triton app open-url --platform harmony ... --json`.
- Then Triton treats the host command as failed and maps it to `host_open_url_failed`.

Scenario: `triton list` is used in a mixed embedded-runtime and host-device session.

- Given `triton list` only reports embedded runtime targets.
- When an agent inspects schema or next commands.
- Then the contract explicitly points host workflows to `triton target list --platform <platform> --json` and `triton device list --platform <platform> --json`.

## Implementation Notes

- `CLIHostProcessRuntime.hostCommandHasSemanticFailure` now recognizes Harmony `aa start` semantic failures even when `hdc` exits 0.
- `device` schema now exposes subcommand metadata for nested lookup, including `device list`.
- `list` schema now documents embedded-runtime-only scope and host-device discovery next commands.
- `act` / `tap` schema text now documents selectable `UITableViewCell` / `UICollectionViewCell` ancestor activation strategies.

## Verification

Focused checks:

```bash
swift test --package-path CLI --scratch-path .build/cli --filter SimulatorAdvancedControlsTests/runHostCommandTreatsHarmonyAAStartErrorCodeAsFailure
swift test --package-path CLI --scratch-path .build/cli --filter SchemaFactSourceTests/schemaLookupSupportsNestedCommandSelectors
swift test --package-path CLI --scratch-path .build/cli --filter SchemaFactSourceTests/agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts
swift test --package-path CLI --scratch-path .build/cli --filter WebViewRouteTests/tapSchemaDocumentsSelectableCellAncestorActivation
```

Full local gate before closure:

```bash
docs-linhay/scripts/verify.sh --local
```

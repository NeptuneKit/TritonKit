# Schema And Agent Contracts

Use this reference when changing `triton schema`, `triton capabilities`, output contracts, recovery commands, failure codes, examples, or command taxonomy.

## Capability Matrix

Every schema-level `providedCapabilities[]` entry must be discoverable through `triton capabilities --json`.

Each capability must have:

- unique `name`
- non-`misc` `group`
- usable `nextAction`
- non-empty `requiredBy`
- non-empty `evidence`

Keep capability groups in the fixed taxonomy:

`action`, `assert`, `bootstrap`, `evidence`, `host`, `observe`, `replay`, `route`, `runtime`, `smoke`, `target`, `test`, `webview`, `xcode`.

## Recovery Taxonomy

Use stable recovery categories:

`diagnose`, `discover`, `prepare-target`, `project`, `observe`, `act`, `verify`, `archive`, `replay`, `smoke`, `plan`.

Failure families must map to recovery categories:

- transport/runtime failures -> `diagnose`
- target failures -> `prepare-target`
- project/Xcode failures -> `project`
- action failures -> `act`
- assertion/route/text failures -> `verify`
- artifact/output failures -> `archive`
- destructive/unsupported failures -> `plan`

## Output Contracts

Commands with `providedCapabilities[]` must expose parseable `outputContracts[]`.

Output contract selectors should be dot-separated lower-kebab keys, such as `host.device-list`.

Output contract kinds should be single lower-kebab keys, such as `host-device-list`.

Formats stay in `json`, `jsonl`, or `archive`.

## Schema Hygiene

- `nextCommands[]` and `examples[]` should be single extractable `triton ...` invocations.
- Command and flag names are stable routing keys and should stay lower-kebab.
- Positional args belong in `argumentForms[]`, not `options[]`.
- Subcommand requirements must reference known parent options or argument forms.
- Failure codes must be lower_snake_case and covered by parent command failure codes.

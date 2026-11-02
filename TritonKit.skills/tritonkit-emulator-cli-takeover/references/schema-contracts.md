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

## Compact leaf discovery

On a CLI whose schema help advertises `--compact`, request a resolved leaf with `triton schema --command act.type --compact --json` or `triton schema --command test.run --compact --json`. The default remains the full command schema. Compact discovery is read-only and does not execute or validate the target action.

Use the returned effective arguments, selector constraints, applicable output contracts, original safety semantics, version and fingerprint together. Unknown or unresolved metadata is not permission to act. Refresh a cached leaf when the CLI version/fingerprint changes; a smaller JSON payload is not evidence of faster command execution.

### Side-effect metadata

Missing subcommand effects are `unknown`, including when decoding an older schema without the field. Neither `unknown` nor an unmatched condition proves readonly behavior or permission to execute. `sideEffectCases` carries audited conditional metadata with `sourceCommand`, positional prefix/count and known parsed option values; apply a case only when every condition is known and satisfied for that exact source command. Preserve these fields when consuming compact schemas. An absent conditional confirmation value inherits the base; confirmation metadata is not execution authorization. Actual command validation, confirmation guards and unknown-outcome/no-replay rules remain authoritative. This release audits act/app/sim/build; it does not claim all other command effects are classified.

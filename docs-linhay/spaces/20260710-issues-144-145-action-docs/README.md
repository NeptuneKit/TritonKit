# Issues 144-145 Action Docs

## Background

GitHub issues #144 and #145 report agent-facing ambiguity in TritonKit 0.2.9 CLI discovery:

- #144: `triton act swipe` works for iOS embedded runtime targets, but help/schema suggests only Android or Harmony host adapters and makes it easy to pass a host simulator selector such as `sim:<udid>` instead of the embedded runtime target from `triton list --json`.
- #145: schema examples can be read as retired top-level action commands such as `triton tap`, while the supported surface is `triton act tap`; Harmony app lifecycle examples also need to make `--bundle` and `--ability` prominent for launch/open-url.

## Scope

In scope:

- Update CLI help/schema metadata for `act` and action subcommands.
- Add recovery hints for retired top-level action roots.
- Clarify README guidance for iOS runtime action targets and Harmony app lifecycle arguments.
- Add focused CLI/schema tests before implementation.
- Close the two GitHub issues after validation.

Out of scope:

- Adding compatibility aliases for retired top-level action roots.
- Changing runtime action execution behavior.
- Adding new Web/Wails surfaces.
- Running real private-app smoke flows.

## BDD Scenarios

### Scenario: agent discovers Harmony tap through the supported action surface

Given an agent reads `triton schema --command act --json`
When it looks at usage forms and examples for tap
Then every tap example is fully qualified as `triton act tap ...`
And retired root examples such as `triton tap ...` are not exposed.

### Scenario: agent recovers from a retired top-level action command

Given an agent runs `triton tap --help`
When Triton rejects the retired root
Then the error includes a recovery hint pointing to `triton act tap ...`.

### Scenario: agent performs an iOS embedded-runtime swipe

Given an iOS Simulator app has a connected TritonKit embedded runtime
When an agent reads `triton act swipe --help` or schema
Then the help explains that iOS gestures use `--target <runtime-target>` from `triton list --json`
And it distinguishes that target from host selectors such as `sim:<udid>`.

### Scenario: agent launches or opens a Harmony app route

Given an agent reads app lifecycle examples
When it prepares Harmony `app launch` or `app open-url`
Then the examples use `--platform harmony --device <target> --bundle <bundle-id> --ability <ability-name>`
And they do not imply iOS `--bundle-id` works for Harmony.

## Validation

- `swift test --package-path CLI --filter SchemaFactSourceContractTests`
- `swift test --package-path CLI --filter SchemaFactSourceWorkflowTests`
- `swift test --package-path CLI --filter CLIHelpTests`
- `docs-linhay/scripts/check-docs.sh`

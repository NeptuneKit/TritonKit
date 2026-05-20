## Background

Real-project regression flows currently use TritonKit for runtime observation and in-app actions, but still fall back to raw host-side commands for simulator setup and verification:

- `xcrun simctl openurl <udid> <url>` for debug deep links.
- `xcrun simctl get_app_container <udid> <bundle-id> data` for locating app containers.
- `plutil -p .../Library/Preferences/<bundle-id>.plist` for checking environment/mock/account state.

This makes agent workflows less discoverable and less auditable because these steps sit outside the `triton` JSON contract.

## Current Behavior

`triton schema --json` exposes runtime-focused commands such as `status`, `list`, `ax`, `find`, `tap`, `type`, `wait`, `assert`, `evidence`, and `capture`, but it does not expose equivalent host-side simulator/device commands for deep links, containers, preferences, permissions, location, UI settings, or logs.

Agents therefore reasonably copy raw `xcrun simctl` commands from project notes when preparing app state.

## Expected Behavior

TritonKit should provide first-class host-side adapter commands with stable JSON output, while still using `xcrun simctl` / `devicectl` internally when appropriate.

Suggested first slice:

- `triton host simulators --json`
- `triton app open-url <url> --device <udid> --json`
- `triton app container --device <udid> --bundle-id <id> --kind data --json`
- `triton app prefs dump|get --device <udid> --bundle-id <id> [--key <key>] --json`
- `triton sim privacy ... --json`
- `triton sim location ... --json`
- `triton sim ui ... --json`
- Later: `triton logs stream --device <udid> --bundle-id <id> --jsonl`

The CLI should make clear when an operation only proves the host action was submitted, for example `open-url`, and recommend runtime-side verification with `triton wait/find/assert`.

## Reproduction / Evidence

Local research was captured in:

`docs-linhay/spaces/20260520-xcrun-host-adapter-research/README.md`

Local environment:

- Xcode 26.5, Build 17F42
- `xcrun version 72`
- Available SDKs include iOS/iOS Simulator/macOS/tvOS/watchOS/visionOS/DriverKit 26.5

`xcrun simctl help` confirms relevant simulator capabilities: `openurl`, `get_app_container`, `privacy`, `location`, `ui`, `status_bar`, `io screenshot`, `io recordVideo`, `push`, `spawn`, and `diagnose`.

`xcrun devicectl --help` confirms JSON output to file is the supported machine interface for CoreDevice automation.

## Proposed Next Step

Design and implement a small host-side process adapter in the CLI layer. Consider `SKProcessRunner` (`https://github.com/linhay/SKProcessRunner`) as the process execution abstraction because it already supports cwd/env, stdout/stderr capture, streaming output, timeout, truncation, PTY, and long-lived pipe sessions.

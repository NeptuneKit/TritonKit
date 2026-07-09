# Platform Command Surfaces

Use this reference when changing iOS Simulator, Android Emulator, Harmony / DevEco, app lifecycle, observe, screenshot, or host action commands.

## Common Target Commands

```bash
triton device doctor --platform ios --json
triton device doctor --platform android --json
triton device doctor --platform harmony --json
triton device list --platform ios --json
triton device list --platform android --json
triton device list --platform harmony --json
triton device alias set iphone15 --platform ios --target <simulator-udid> --json
triton device use iphone15 --json
triton device current --json
triton device resolve iphone15 --json
triton device wait-ready --device iphone15 --json
```

Use `--device <selector>` as the default agent-facing target selector for common host-side commands. Selectors can be aliases, full ids, raw platform ids, `booted`, or `current`.

## Observation

Prefer fresh outline before selecting numbered nodes:

```bash
triton observe tree --platform <ios|android|harmony> --device <selector> --outline --json
triton node resolve @1 --platform <ios|android|harmony> --device <selector> --json
```

`@N` aliases are repo-local snapshots written to `.triton/node-aliases.json`. If stale, refresh instead of guessing.

## iOS Simulator

Examples:

```bash
triton sim list --json
triton sim boot <udid> --wait --jsonl
triton sim screenshot --simulator <udid-or-booted> --output /tmp/case.png --json
triton app install --device iphone15 --app <path.app> --json
triton app launch --device iphone15 --bundle-id <bundle-id> --json
```

Embedded runtime targets use stable ids shaped as `triton:ios-simulator:<SIMULATOR_UDID>`. If more than one runtime target is connected and the command uses default `triton:local`, return `ambiguous_target`.

## Android Emulator

Android Emulator host-side support includes ADB-backed discovery, readiness, start/stop, screenshot, app lifecycle, UIAutomator observe/wait/tap, and `smoke android`.

Keep DTOs, evidence, and command-ledger schemas platform-neutral across iOS, Android, and Harmony.

## Harmony / DevEco Emulator

Examples:

```bash
triton device list --platform harmony --json
triton device wait-ready --device harmony-a --json
triton app install --device harmony-a --hap <debug-signed.hap> --json
triton app launch --device harmony-a --bundle <bundle> --ability <ability> --json
triton observe tree --device harmony-a --outline --json
triton act tap "登录" --platform harmony --device harmony-a --json
```

HDC output shape drifts. Parse verbose and plain target outputs, and do not parse prose errors as targets.

Foreground app identity from Harmony host discovery is optional host fact, not app lifecycle proof.

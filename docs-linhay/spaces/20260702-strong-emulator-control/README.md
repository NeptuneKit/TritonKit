# Strong Emulator Control

## Background

TritonKit already has local emulator / simulator control through CLI-first
contracts. The next step is stronger local control inspired by
`lycorp-jp/sim-use`, while keeping TritonKit as the only public automation API.

Useful reference lanes:

- iOS Simulator: host-side `idb` / FBSimulatorControl-style AX tree and HID
  input.
- Android Emulator: optional helper APK with AccessibilityService, `adb
  forward`, and local HTTP endpoints for tree and input.

## Goal

Make local iOS Simulator and Android Emulator control stronger without leaking
host-only dependencies into the embedded SDK or root SwiftPM package.

Agent-facing commands should remain Triton commands:

- `triton observe current|tree --platform ios|android --json`
- `triton node resolve --platform ios|android --json`
- `triton act tap|swipe|type|paste|press --platform ios|android --json`
- `triton wait --platform ios|android --json`
- `triton device doctor|bridge ... --json`

## Scope

In scope:

- CLI/schema/capability contracts for optional strong-control adapters.
- Android bridge APK and real emulator smoke after the CLI contract is stable.
- iOS host adapter boundary that stays CLI-only.
- Stable fallback to existing embedded runtime, `simctl`, ADB, or UIAutomator
  when strong control is unavailable.

Out of scope:

- Web/Wails UI.
- Remote device cloud or multi-tenant server.
- Real-device strong control.
- Adding `idb`, FBSimulatorControl, Gradle, or Android helper dependencies to
  root `Package.swift`.

## Acceptance

- Root SwiftPM remains safe for business App dependency resolution.
- Strong-control unavailable states return stable JSON errors and next actions.
- Android bridge can be installed, forwarded, probed, and used on one local
  emulator.
- iOS host adapter can prove readonly availability before any HID mutation.
- Docs and memory stay updated, and milestone exits run project gates.

## Plans

- `plans/20260702-milestones-subagent-map-v01.md`: milestone checklist and
  subagent parallel work areas.

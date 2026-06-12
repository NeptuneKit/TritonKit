# Issue 45: Foreground App Identity for Host Emulator Targets

## Background

GitHub issue: https://github.com/NeptuneKit/TritonKit/issues/45

Harmony host emulator discovery currently reports the HDC target identity through `triton device list --platform harmony --json`, but it does not expose the foreground app identity. Agent summaries and the Web mock can only show an emulator label or an unknown-app fallback.

This work stays inside the local CLI + local emulator boundary. The primary product surface is the machine-readable CLI/HTTP schema and host adapter contract; no Web/Wails business-control entry is added.

## Scope

- Add optional foreground app identity fields to the host emulator target contract without breaking existing `HostDeviceTarget` consumers.
- Prefer Harmony host discovery first, because issue evidence comes from `hdc list targets -v`.
- Keep iOS and Android target DTOs backward compatible by exposing optional fields rather than requiring platform support in this slice.
- Update schema/output contracts/capabilities and docs so agents can discover the new contract from `triton schema --command device --json`.

Out of scope:

- No Web/Wails command or control surface.
- No remote agent, device cloud, physical-device orchestration, or public HTTP product API.
- No fake app identity when HDC does not provide a stable foreground package/app name.

## BDD Scenarios

### Scenario 1: Harmony target exposes current foreground app when host data is available

Given a connected Harmony emulator target
And HDC/host observation returns a foreground app package or application label for that target
When an agent runs `triton device list --platform harmony --json`
Then each target remains shaped as `HostDeviceTarget`
And the matching target includes optional `appName`, `bundleIdentifier`, `identityState`, and `current`
And `identityState` is `current`
And `current` is `true`
And agents can render the app identity without calling `app list --bundle`.

### Scenario 2: Harmony target reports unknown or unsupported instead of guessing

Given a connected Harmony emulator target
And HDC cannot provide a stable foreground app package or label
When an agent runs `triton device list --platform harmony --json`
Then Triton does not invent `appName` or `bundleIdentifier`
And the target includes `identityState` as `unknown` or `unsupported`
And `current` is `false`
And the response keeps target readiness, HDC state, transport, and source command intact.

### Scenario 3: Schema and optional DTO fields remain backward compatible

Given existing iOS, Android, and Harmony host-device consumers
When `triton schema --command device --json` is inspected
Then the `host.device-list` output contract documents optional foreground identity fields on `HostDeviceTarget`
And existing required fields such as `platform`, `id`, `target`, `state`, `ready`, `source`, `name`, `runtime`, and `transport` remain available
And the new fields are optional so older target data can decode safely.

## Acceptance Criteria

- Tests are added before implementation for the host target DTO, Harmony parser/identity state behavior, and schema output contract fields.
- `triton device list --platform harmony --json` can surface current foreground app identity when host parsing yields one.
- When HDC foreground identity is not stable or unavailable, Triton returns explicit `identityState=unknown` or `identityState=unsupported` and does not fabricate app names or bundle identifiers.
- `HostDeviceTarget` keeps backward-compatible optional fields across iOS, Android, and Harmony.
- Schema/output contract docs mention the optional identity fields and remain machine-readable.
- Focused Swift tests pass; CLI schema/build smoke is run if the local environment permits.
- Documentation and memory are updated.

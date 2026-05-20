P0 implementation has started.

Implemented in the first slice:

- Shared host adapter models:
  - `TKSimctlCommand`
  - `TKHostSimulatorTarget`
  - `TKSimctlDeviceListParser`
  - `TKHostPreferencesSnapshot`
- CLI commands:
  - `triton sim list --json`
  - `triton sim boot <udid> --json`
  - `triton sim shutdown <udid|booted> --json`
  - `triton sim screenshot --simulator <udid|booted> --output <path> --json`
  - `triton app open-url <url> --simulator <udid|booted> --json`
  - `triton app container --bundle-id <id> --kind data --simulator <udid|booted> --json`
  - `triton app prefs get <key> --bundle-id <id> --simulator <udid|booted> --json`
  - `triton app prefs dump --bundle-id <id> --simulator <udid|booted> --json`
- Schema exposure:
  - `triton schema --command sim --json`
  - `triton schema --command app --json`

Validation:

- Added failing tests first for host adapter models.
- `swift test --filter TKHostAdapterModelsTests` passes.
- `swift test` passes 50 tests.
- `swift build --product triton` passes.
- `.build/debug/triton sim list --json` returns the local Xcode 26.5 simulator list.
- Missing app container returns stable `app_container_not_found` JSON error.

Follow-up P0 work:

- Add `app list/info/install/launch/terminate`.
- Add `.tritonplan` schema v2 host steps.
- Add `capture/evidence --include host` artifacts.

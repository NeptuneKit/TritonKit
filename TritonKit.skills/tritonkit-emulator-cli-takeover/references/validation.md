## Validation

Start with the installed CLI and preserve the current contract before selecting any target:

```bash
triton version --json
triton schema --command device --json
triton schema --command app --json
triton schema --command smoke --json
triton schema --command evidence --json
triton device list --platform ios --scope simulator --json
triton device list --platform harmony --json
```

Use only an explicitly authorized, dedicated Simulator/emulator for action checks. Pass its exact selector instead of a shared `booted` default. Query readiness and installed App state before a scoped install/launch flow, then verify the App's postcondition and capture bounded evidence. Restore owned changes and check all other instances remain unchanged.

For Harmony runtime validation, use the verified URL from `triton device runtime-url --device <hdc-target> --probe-manifest --json`, then inspect the runtime manifest and snapshot with that URL. Reuse an existing healthy forward; do not create conflicting forwards to satisfy a smoke check.

Repository-maintainer Swift tests and smoke scripts require a separate source checkout and its instructions; they are not included in this public bundle. Installed CLI schema checks alone do not substitute for those tests or real device acceptance. See [Device Hub contracts](device-hub-contracts.md) for current Apple platform evidence levels.

Avoid erasing emulators, uninstalling business apps, installing data bundles, changing privacy/location, or collecting broad logs unless the current task explicitly requires it and the command records policy metadata.

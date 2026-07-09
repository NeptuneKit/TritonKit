## Validation

Minimum local validation:

```bash
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command device --json
.build/cli/debug/triton schema --command app --json
.build/cli/debug/triton schema --command smoke --json
.build/cli/debug/triton schema --command evidence --json
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-host-smoke.sh
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/check-docs.sh
```

Run real emulator smoke only when safe for the current machine:

```bash
.build/cli/debug/triton sim list --json
.build/cli/debug/triton sim status-bar list --simulator booted --json
.build/cli/debug/triton app uninstall --device booted --bundle-id com.example.missing --confirm --json
.build/cli/debug/triton app launch --device booted --bundle-id com.example.missing --json
.build/cli/debug/triton device list --platform harmony --json
.build/cli/debug/triton device wait-ready --device <hdc-target> --json
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-runtime-base-url-smoke.sh
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-runtime-emulator-smoke.sh --target <hdc-target> --no-forward
```

Avoid erasing emulators, uninstalling business apps, installing data bundles, changing privacy/location, or collecting broad logs unless the current task explicitly requires it and the command records policy metadata.

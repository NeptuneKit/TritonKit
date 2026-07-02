# Android Bridge Smoke Evidence 2026-07-02

Scope: local Android Emulator `emulator-5554`, Triton CLI debug build,
TritonKit Android bridge package `jp.lycorp.tritonkit.bridge`.

## Triton-First Facts

Commands run before adb fallback:

```bash
.build/cli/debug/triton status --json
.build/cli/debug/triton doctor --format json
.build/cli/debug/triton capabilities --json
.build/cli/debug/triton schema --command device --json
.build/cli/debug/triton device doctor --platform android --json
.build/cli/debug/triton device list --platform android --json
```

Key facts:

- `device list` found ready emulator `android:emulator-5554`.
- `device` schema reports `bridge --remote-port` default `8080`.
- Android bridge status reports package installed and auth token available.

## Bridge Bootstrap

The helper AccessibilityService was not enabled initially:

```text
enabled_accessibility_services=null
accessibility_enabled=0
```

After Triton evidence proved the gap, adb fallback enabled the service:

```bash
adb -s emulator-5554 shell settings put secure enabled_accessibility_services jp.lycorp.tritonkit.bridge/jp.lycorp.tritonkit.bridge.service.TritonKitAccessibilityService
adb -s emulator-5554 shell settings put secure accessibility_enabled 1
adb -s emulator-5554 shell content insert --uri content://jp.lycorp.tritonkit.bridge/toggle_socket_server --bind enabled:b:true
```

Log evidence:

```text
TritonKitA11yService: HTTP server started on port 8080
TritonKitHttpServer: HTTP server listening on 127.0.0.1:8080
```

## Smoke Commands

Forward and ping:

```bash
.build/cli/debug/triton device bridge forward --platform android --device emulator-5554 --confirm --audit-record m2-remote-port-fix --execute-runner --json
.build/cli/debug/triton device bridge probe --platform android --device emulator-5554 --json
```

Result:

- `bridge.forward` succeeded with `remoteEndpoint=tcp:8080`.
- `bridge.probe` succeeded with `probeReachable=true`.
- `/ping` returned `protocol_version=2`, `bridge_version=0.1.0`.

Tree:

```bash
.build/cli/debug/triton observe tree --platform android --device emulator-5554 --json
```

Result:

- `ok=true`
- `primarySource.name=android-bridge`
- first tree sample had 33 nodes and included `Chrome`.
- source commands used ContentProvider token retrieval and redacted Bearer curl.

Wait:

```bash
.build/cli/debug/triton wait --platform android --device emulator-5554 --text Chrome --timeout 3 --json
```

Result:

- `ok=true`
- `matched=true`
- source commands used `android-bridge` tree curl, not UIAutomator.

Tap:

```bash
.build/cli/debug/triton act tap Chrome --platform android --device emulator-5554 --json
```

Result:

- `ok=true`
- tap point `667,1971`
- match source came from bridge tree; mutation used `adb shell input tap`.

After tap:

```bash
.build/cli/debug/triton observe tree --platform android --device emulator-5554 --json
```

Result:

- `primarySource.name=android-bridge`
- observed Chrome onboarding text including `Welcome to Chrome`.

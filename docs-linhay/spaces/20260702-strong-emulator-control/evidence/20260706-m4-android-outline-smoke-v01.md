# M4 Android Outline Smoke

Date: 2026-07-06

Scope: verify the M4 `observe tree --outline` and `node resolve @N` contract
against a real local Android Emulator using the Android bridge source.

## Triton-First Facts

```bash
.build/cli/debug/triton device list --platform android --json
```

Initial result before start: `ok=true`, `targets=[]`.

```bash
.build/cli/debug/triton device doctor --platform android --json
```

Result: `ok=true`; `adb` was available with version summary
`Android Debug Bridge version 1.0.41`.

```bash
.build/cli/debug/triton device start --platform android --avd Dxyer_API_34 --headless --gpu swiftshader_indirect --plan-only --json
```

Result: `ok=true`, `planOnly=true`, planned source command
`emulator @Dxyer_API_34 -no-window -gpu swiftshader_indirect`, nextAction
`device wait-ready --platform android --device emulator-5554 --json`.

```bash
.build/cli/debug/triton device start --platform android --avd Dxyer_API_34 --headless --gpu swiftshader_indirect --json
```

Result: `ok=true`, `started=true`, `pid=71500`, target `emulator-5554`.

```bash
.build/cli/debug/triton device wait-ready --platform android --device emulator-5554 --timeout 5 --json
```

Result after boot settled: `ok=true`, `ready=true`, target
`android:emulator-5554`.

## Bridge Readiness

```bash
.build/cli/debug/triton device bridge status --platform android --device emulator-5554 --json
```

Result: `ok=true`, `installed=true`, `authTokenAvailable=true`.

```bash
.build/cli/debug/triton device bridge probe --platform android --device emulator-5554 --json
```

First result: `ok=false`, `error.code=android_bridge_probe_failed`, because
`127.0.0.1:19422` was not forwarded yet.

```bash
.build/cli/debug/triton device bridge forward --platform android --device emulator-5554 --confirm --audit-record m4-outline-smoke --execute-runner --json
```

Result: `ok=true`; source command
`adb -s emulator-5554 forward tcp:19422 tcp:8080`.

```bash
.build/cli/debug/triton device bridge probe --platform android --device emulator-5554 --json
```

Result: `ok=true`, `probeReachable=true`, response summary included
`"result":"pong"` and `bridge_version:"0.1.0"`.

## M4 Exit Gate

The gate ran in a temporary workspace so `.triton/node-aliases.json` was not
written into the repository:

```bash
tmpdir=$(mktemp -d /tmp/triton-m4-android.XXXXXX)
(
  cd "$tmpdir" &&
  /Users/linhey/Desktop/linhay-open-sources/TritonKit/.build/cli/debug/triton observe tree --platform android --device emulator-5554 --outline --json > observe.json &&
  /Users/linhey/Desktop/linhay-open-sources/TritonKit/.build/cli/debug/triton node resolve @1 --platform android --device emulator-5554 --json > resolve.json
)
```

Observed summary:

```text
tmpdir '/private/tmp/triton-m4-android.nXLOJn'
observe_ok True primary android-bridge outline_count 33 cache /private/tmp/triton-m4-android.nXLOJn/.triton/node-aliases.json
resolve_ok True query @1 node_source android-bridge nodeID android-bridge:
```

Conclusion: M4 Android real exit gate passed with `primarySource.name` equal to
`android-bridge`; `node resolve @1` consumed the repo-local alias cache and
returned a bridge node.

## Cleanup

Initial Triton-first stop attempt before the Android stop fix:

```bash
.build/cli/debug/triton device stop --platform android --device emulator-5554 --confirm --json
```

Result: ArgumentParser rejected the command because `device stop` currently
requires Harmony-only `--hvd` / `--path` arguments. Android emulator stop is
not exposed as a Triton schema-backed action yet.

Fallback cleanup command:

```bash
adb -s emulator-5554 emu kill
```

Result: `OK: killing emulator, bye bye`.

Post-cleanup Triton check:

```bash
.build/cli/debug/triton device list --platform android --json
```

Result: `ok=true`, `targets=[]`.

Follow-up regression after adding schema-backed Android stop:

```bash
.build/cli/debug/triton device start --platform android --avd Dxyer_API_34 --headless --gpu swiftshader_indirect --json
.build/cli/debug/triton device wait-ready --platform android --device emulator-5554 --timeout 5 --json
.build/cli/debug/triton device stop --platform android --device emulator-5554 --confirm --json
.build/cli/debug/triton device list --platform android --json
```

Result: `device start` returned `ok=true`, `target=emulator-5554`;
`wait-ready` returned `ok=true`, `ready=true`, `kind=emulator`; `device stop`
returned `ok=true`, `target=android:emulator-5554`, source command
`adb -s emulator-5554 emu kill`; the follow-up list had no remaining emulator
targets. A connected Android real device remained listed separately as
`scope=real`, proving the stop path stayed emulator-scoped.

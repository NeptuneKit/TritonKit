# Harmony integration

Use this when helping someone validate TritonKit with HarmonyOS / DevEco Emulator or add the Harmony embedded SDK.

## Choose the path

| Need | Path | App package change |
| --- | --- | --- |
| Discover emulator targets, wait for readiness, inspect/launch apps | Host-side HDC adapter through `triton device/app --platform harmony` | No |
| Validate app-process manifest, snapshot, ledger, state providers, and semantic actions | Harmony embedded SDK direct runtime checks | Yes, Debug-only |

## Host-side validation

Host-side Harmony validation does not require a running embedded runtime:

```bash
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device wait-ready --device 127.0.0.1:10100 --json
triton app inspect --platform harmony --bundle com.example.app --target 127.0.0.1:10100 --json
triton app launch --device 127.0.0.1:10100 --bundle com.example.app --ability EntryAbility --json
```

`triton device list --platform harmony --json` may include `targets[].appName`, `bundleIdentifier`, `identityState`, and `current`. File feedback when stable foreground identity is available but missing. Do not report `unknown` or `unsupported` as an app mismatch by itself.

If multiple HDC targets are connected, pass `--device <alias-or-id>` or `--target <hdc-target>`. `ambiguous_target` is the expected safe failure.

## Embedded SDK

Use the TritonKit brand name, but keep the OHPM package id and ArkTS import path lowercase:

```text
tritonkit
```

Until a published OHPM package exists, use the aligned `harmony-TritonKit` source/HAR for validation. Keep business app integration Debug-only. Release builds must be disabled/no-op and must not collect UI, screenshots, logs, route state, or action data.

Business semantics must be app-provided. A generic HAR should return `unsupported_runtime_scope` for route, responder, semantic action, input, screenshot, hit-test, or system-alert capabilities unless the app registers the matching provider. Missing providers are feature requests; falsely supported capabilities are bugs.

## Runtime URL validation

Before standalone embedded HTTP runtime checks are connected through `triton serve`, ask Triton to prepare or discover the HDC fport URL:

```bash
triton device alias set harmony-a --platform harmony --target 127.0.0.1:10100 --json
triton device runtime-url --device harmony-a --probe-manifest --json
triton debug runtime manifest --runtime-base-url http://127.0.0.1:28767 --json
triton debug state route --runtime-base-url http://127.0.0.1:28767 --json
triton debug snapshot --runtime-base-url http://127.0.0.1:28767 --json
triton debug ledger --runtime-base-url http://127.0.0.1:28767 --jsonl
triton act set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:28767 --json
```

For the Harmony demo, `28767` is the host-access embedded runtime port exposed through HDC `fport`; `18765` is the device-to-host gateway fallback port used by the demo UI.

If an HDC fport already exists, use:

```bash
docs-linhay/scripts/verify-harmony-runtime-emulator-smoke.sh --target <hdc-target> --no-forward
```

## Distribution notes

- Repository: `https://github.com/NeptuneKit/TritonKit`
- Released CLI: `brew install NeptuneKit/tap/triton`
- Local unreleased CLI fallback: `swift build --package-path CLI --scratch-path .build/cli -c release --product triton`
- Manual local CLI updates must use a temporary file plus `mv`, or stop `triton serve` first.
- Homebrew installs only the macOS CLI. iOS uses SwiftPM/CocoaPods; Harmony embedded SDK uses the Harmony package/source path.
- GitHub Release assets include macOS arm64/x86_64 CLI tarballs, checksum manifest, and project skill packages.

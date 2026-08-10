## Harmony App Integration Guide

Use this shape when the real app needs Harmony / DevEco validation.

Host-side Harmony checks do not require any app package dependency:

```bash
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device wait-ready --device <hdc-target> --json
triton app inspect --platform harmony --bundle <bundle> --target <hdc-target> --json
triton app install --device <hdc-target> --hap <debug-signed.hap> --json
triton app launch --platform harmony --device <hdc-target> --bundle <bundle> --ability <ability> --json
triton app open-url --platform harmony --device <hdc-target> --bundle <bundle> --ability <ability> '<url>' --json
triton debug ax --platform harmony --target <hdc-target> --output /tmp/<case>-layout.json --json
triton wait --platform harmony --target <hdc-target> --text '<text>' --timeout 15 --json
triton act tap '<text>' --platform harmony --target <hdc-target> --json
triton screenshot --device <hdc-target> --output /tmp/<case>.jpeg --json
triton smoke harmony --device <hdc-target> --bundle <bundle> --ability <ability> --open-url '<url>' --wait-text '<text>' --screenshot /tmp/<case>.jpeg --evidence /tmp/<case>.tritonevidence --json
```

When building a real Harmony app through DevEco `assembleApp`, select only the installable signed artifact:

```bash
triton build harmony --project <project> --module entry --task assembleApp --product default --mode debug --no-daemon --json
```

`assembleApp` may emit an unsigned HAP beside a `*-signed.hap` sibling. TritonKit routes `artifact` and the install `nextAction --hap` to the signed HAP only. If no signed candidate exists, it returns the single `hap_artifact_not_found` envelope with a signing hint instead of suggesting an unsigned install. The legacy `assembleHap` emulator/debug discovery path may still accept an unsigned fixture; do not treat that compatibility path as proof of real-device installability.

When multiple HDC targets are `Connected`, pass `--device <alias-or-id>` or an explicit `--target`; `ambiguous_target` is the expected machine-readable failure.
Host-side layout and screenshot artifacts may contain private UI data; inspect or summarize them before attaching evidence to public issues.

For Harmony embedded SDK work, keep the TritonKit brand separate from the OHPM package id. The actual package id and ArkTS import path are lowercase:

```text
tritonkit
```

Until the Harmony package is published, use the aligned `harmony-TritonKit` source/HAR for validation. Keep the app integration Debug-only. Release builds must compile to disabled/no-op behavior and must not collect UI, screenshots, logs, route state, or action data.

Business semantics are not generic HAR capabilities. Route, responder, and semantic action state should come from app provider hooks. If providers are not registered, `unsupported_runtime_scope` is the correct runtime result; if the manifest marks those capabilities supported without providers, file a bug.

For a standalone Harmony embedded runtime before it is connected through `triton serve`, use direct runtime checks:

```bash
triton device runtime-url --device harmony-a --probe-manifest --json
triton debug runtime manifest --runtime-base-url http://127.0.0.1:28767 --json
triton debug state route --runtime-base-url http://127.0.0.1:28767 --json
triton debug snapshot --runtime-base-url http://127.0.0.1:28767 --json
triton debug ledger --runtime-base-url http://127.0.0.1:28767 --jsonl
triton act set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:28767 --json
```

For the Harmony demo, `28767` is the host-access embedded runtime port exposed through HDC `fport`; `18765` is only the demo device-to-host gateway fallback port.

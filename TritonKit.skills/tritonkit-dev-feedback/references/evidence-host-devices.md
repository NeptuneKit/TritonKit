# Host-side device and emulator evidence

Use this for host-side iOS Simulator, Android Emulator, HarmonyOS / DevEco Emulator, Web Device Hub, install/launch/readiness/screenshot flows, and cases that do not require an embedded runtime.

## Triton-first rule

Before raw `xcrun` / `simctl`, `adb`, `hdc`, DevEco CLI, XcodeBuildMCP, or raw `xcodebuild`, capture Triton evidence:

```bash
triton status --json
triton doctor --json
triton capabilities --json
triton schema --json
triton schema --command <command> --json
triton plan --json
```

Fallback reports must include the Triton command, error code, unsupported result, or missing schema/capability proof.

## iOS Simulator host-side checks

```bash
triton sim list --json
triton device alias set iphone15 --platform ios --target <udid> --json
triton sim use <udid> --json
triton sim boot <udid> --wait --jsonl
triton sim screenshot --simulator booted --output /tmp/<case>-sim.png --json
triton sim logs --simulator booted --output /tmp/<case>-sim.ndjson --duration 5 --json
triton sim app-console --simulator booted --bundle-id <bundle-id> --output /tmp/<case>-app-console.log --duration 5 --max-bytes 10485760 --json
triton app list --device iphone15 --user-only --json
triton app info --device iphone15 --bundle-id <bundle-id> --json
triton app install --device iphone15 --app <path.app> --json
triton app launch --device iphone15 --bundle-id <bundle-id> --json
triton app terminate --device booted --bundle-id <bundle-id> --json
triton app open-url "<url>" --device iphone15 --wait-ready --snapshot --json
triton app container --device iphone15 --bundle-id <bundle-id> --kind data --json
triton app prefs get <key> --device iphone15 --bundle-id <bundle-id> --json
```

For a physical iOS target, the redacted `ios-real:*` selector is enough for `app install`, `app info`, and `app launch`; all three must enter the same live real-device discovery without requiring explicit `--platform ios --scope real`. Preserve the redacted selector, resolved readiness state, stable error code, and sanitized `sourceCommand`; never publish the raw CoreDevice identifier. A remaining lock/trust/Developer Mode/DDI failure is actionable evidence, while a launch-only `target_not_found` for a selector accepted by install/info is a TritonKit resolution regression.

Do not treat `app terminate` as a physical iOS lifecycle success. An `ios-real:*` bundle-ID request deliberately returns `app_terminate_pid_resolution_unavailable` before submitting `devicectl` until TritonKit has a verified PID contract. If a cold restart is desired, choose the returned `app launch` nextAction explicitly and report it as a separate launch alternative, never as successful termination.

iOS host screenshot is Simulator-only. When `device list` returns a ready physical target, `triton screenshot --platform ios --device <ios-real-selector> --output <path> --json` must return `unsupported_scope` before any `simctl` invocation, and `device doctor --platform ios --scope real --json` must omit `device.screenshot`. Preserve that envelope and its schema `nextAction`; use a connected embedded DEBUG runtime screenshot if available, otherwise label any external manual screenshot as fallback evidence rather than Triton host capture.

For an iOS Simulator runtime evidence bundle, `manifest.primaryArtifact.fidelity=full-screen` is the visual acceptance gate. The primary `screenshot` must come from `simctl-framebuffer`; `screenshot.runtime` is App-layer diagnostics only and may omit system-composited sheets, grabbers, navigation chrome, keyboards, or SpringBoard UI. If the host framebuffer is unavailable, report the failed-partial manifest, `screenshot.host` skip, `host_screenshot_unavailable`, and the structured Triton fallback command instead of attaching the runtime image as faithful visual proof.

Preserve log provenance in feedback: `sim logs` is `unified-log` only; `sim app-console` is merged App process stdout/stderr and relaunches the App. Console artifacts are sensitive. Report only bounded, sanitized excerpts, retain `sourcesCaptured` and truncation metadata, and never paste a full private artifact into a public issue.

Destructive commands such as uninstall, erase, runtime delete, dyld-cache remove, or pairing changes must show `--dry-run` or `--confirm` behavior in the report.

## Harmony host-side checks

```bash
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device alias set harmony-a --platform harmony --target <hdc-target> --json
triton device wait-ready --device harmony-a --json
triton app inspect --platform harmony --bundle <bundle> --target <hdc-target> --json
triton app install --device harmony-a --hap <debug-signed.hap> --json
triton app launch --platform harmony --device harmony-a --bundle <bundle> --ability <ability> --json
triton app open-url --platform harmony --device harmony-a --bundle <bundle> --ability <ability> "<url>" --json
triton debug ax --platform harmony --target <hdc-target> --output /tmp/<case>-layout.json --json
triton wait --platform harmony --target <hdc-target> --text "<text>" --timeout 15 --json
triton act tap "<text>" --platform harmony --target <hdc-target> --json
triton screenshot --device harmony-a --output /tmp/<case>.jpeg --json
```

When `device list` reports `identityState=unknown` or `unsupported`, preserve that boundary; do not fabricate app identity from emulator labels. Multiple connected HDC targets should produce `ambiguous_target` until `--device` or `--target` is supplied.

For Harmony host output contracts, parse `host.harmony-artifact`, `host.harmony-tap`, `host.harmony-swipe`, `host.harmony-text-input`, `host.harmony-key-action`, and `host.harmony-wait`. Treat legacy selectors such as `host.tap` or `host.wait` as schema regressions.

## Android host-side checks

```bash
triton device doctor --platform android --json
triton device list --platform android --json
triton device alias set android-a --platform android --target <adb-serial> --json
triton device wait-ready --device android-a --json
triton app inspect --platform android --device android-a --bundle <package> --json
triton app install --platform android --device android-a --apk <debug.apk> --json
triton app launch --platform android --device android-a --package-name <package> --json
triton app open-url --platform android --device android-a --package-name <package> "<url>" --json
triton debug ax --platform android --device android-a --output /tmp/<case>-window.xml --json
triton wait --platform android --device android-a --text "<text>" --timeout 15 --json
```

## Web Device Hub

For Web Device Hub launch/discovery feedback:

```bash
triton web --print-command --json
```

Preserve `mode`, `repoRoot`, `webRoot`, `bundledWebRoot`, `tritonBin`, `url`, `installCommand`, and `command`. Web is a local readonly launcher, not the business-control surface.

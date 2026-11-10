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

For `sim logs`, retain the partial artifact referenced by a nonzero `ok:false, partial:true` response. Record `artifactBytes`, `stdoutBytes`, `artifactTruncated`, `maximumBytes`, `captureEndedBy`, and `terminationReason`; do not treat file presence or a byte-limited prefix as a complete capture.

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

Harmony wait `--role` matches the native ArkUI `type` case-insensitively and exactly (for example `button` matches `Button`, and `Text` matches `Text`); it does not expand accessibility-role aliases. Text and role must match the same node for `--text` / `--exists`; `--gone` uses the same role constraint. Preserve positive-role, wrong-role and missing-text controls.

Harmony wait's `--timeout` covers target discovery plus condition polling. Discovery deadline exhaustion is one `harmony_discovery_timeout` error envelope; a discovered target whose condition does not become true returns the structured wait timeout result. Keep discovery-stage and condition-stage failures distinct, and do not call missing-target, transfer or role mismatch a successful wait.

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

## Coordinate tap routing evidence

- For iOS Simulator coordinate-tap feedback, record whether the selector was a host form (`sim:<UDID>`, raw UUID, `booted`, `current`) or a canonical embedded form (`triton:ios-simulator:<UDID>/app:<bundle-id>`). Host-form coordinate taps must not be reported as embedded runtime actions, and host-HID acknowledgement alone is not proof of the foreground App's business postcondition.

## ArkWeb bridge-call boundaries

- Harmony ArkWeb bridge-call 需可达 DevTools socket 与页面 `window.__tritonBridge.methods` 自有函数白名单；函数接收 `(params, complete, reject)`，支持返回值/Promise/callback。明确选中 CDP page ID，stale/ambiguous 失败关闭；不把 CDP page ID 当导航 session 验证，清理失败也可能发生在页面方法已执行之后，重试前先验业务状态。

## Host geometry and Android foreground evidence

For Simulator host AX, `ios_host_ax_geometry_unavailable` rejects missing/invalid geometry before coordinate-dependent work; preserve that failure and inspect `triton device doctor --platform ios --scope simulator --json`, rather than guessing dimensions. Android `device foreground` adds `observed.activity` and `observed.component` from trustworthy resumed activity records; unknown omits them, and foreground identity does not prove business readiness. Legacy ADB text input quotes remote-shell literals and redacts source commands; distinguish shell safety from device Unicode/keymap and `%s` input support. Record offline fixture acceptance separately from real-device input.

## Device Hub host input authority

Discover `triton schema --command act.tap --json` on the actual CLI before using `--hid-only`. Explicit `--platform ios` defaults to AX activation, including coordinates: `source=host-ax`, `strategy=accessibility-perform-press`, `verification.required=true`. For a touch-path regression use `triton act tap --platform ios --device sim:<UDID> --at 120,240 --hid-only --json`; only local Simulator coordinates are accepted, with no semantic/embedded/WebView fallback. Without `--platform`, existing explicit Simulator coordinate selectors retain host HID routing.

Tap and `triton sim swipe` use the native digitizer bundled in triton, without an external Baguette executable or chrome lookup. Device Hub guest HID ownership returns `ios_host_hid_device_hub_attached`; unknown ownership and unsupported display topology fail closed. No automatic SpringBoard restart or heal occurs. Follow the selected-device doctor next step; `hidCompatibility.hostChromeLayout` is bundle presence only and `chromeLookupVerified=false`. Framework compatibility, booted state, AX activation, screenshots and ACKs do not prove HID delivery. Do not attribute an external native CUA drag/scroll failure to Triton. No verified host multi-tap/long-press primitive is supplied here; `act tap --duration` stays unsupported. App-owned semantic actions can check business state but cannot replace physical-touch regression proof. Report that boundary and preserve the typed error instead of claiming Device Hub HID support.

### Android hierarchy freshness

UIAutomator exit zero does not prove a current tree. Triton uses a unique dump path and validates its acknowledgement and XML. On `hierarchy_unavailable`, retain the failure and recapture after the UI has a usable root; never reuse old tree coordinates or claim business verification. Remote cleanup is limited to the current capture path and is best effort.

## Selected Simulator display diagnostics

Use `triton device doctor --platform ios --scope simulator --device sim:<UUID> --json` to read independent `simulatorDiagnostics.resize` and `.display` state/reason snapshots and an exact-target nextAction. Omitted --device adds no geometry query. Top-level doctor ok/capability names do not prove capture/input; captureVerified and inputDispatchVerified remain false. Unknown/unsupported/timeout is not inactive/primary. `resize.reason=unsupportedDevice` identifies an exact target-bound native capability rejection; `resize.hint` explains that repeating the same query cannot enable it. Use a verified compatible target/toolchain, or explicitly connected embedded App-only observation without claiming host capture/input recovery. Snapshot success is not an atomic lock or action verification; do not bypass unknown geometry, silently capture another display, or replay uncertain input. Different Xcode versions and user projects require their own evidence.



## Explicit primary-LCD still capture

For an explicit primary-LCD still image, use `triton sim screenshot --simulator <UUID> --primary-framebuffer --output <new-path.png> --json` only when the installed schema advertises it. It conflicts with `--display` and never activates automatically. A fresh Resize query must be inactive or exactly unsupportedDevice, and the complete target/argv-bound display inventory must contain exactly one active primary integrated LCD. In the exact unsupportedDevice case, inactive non-primary virtual displays may remain; active/primary/unknown states and malformed responses reject capture. A verified inactive Resize query still requires a singleton LCD inventory. The PNG is validated and exclusively published; existing outputs are never overwritten. `primaryFramebuffer` reports captureScope, displayUniqueID, resizeState/reason, resizeVerified and inputDispatchVerified=false. Unsupported stays unknown; this is neither complete App/Resizable content nor permission for touch, AX, recording or streaming. Queries are separate non-atomic snapshots.

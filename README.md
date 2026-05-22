# TritonKit

TritonKit provides a DEBUG-only embedded iOS runtime, Harmony / DevEco Emulator host-side contracts, Harmony embedded runtime alignment notes, and a macOS `triton` CLI for inspecting and controlling apps during development. It is designed for AI agents and automation scripts that need machine-readable access to app hierarchy, accessibility nodes, geometry, screenshots, and supported in-app controls.

TritonKit is in active development. If you hit a missing capability, unclear behavior, integration issue, or documentation gap, open an issue in `NeptuneKit/TritonKit`; AI agents using this repository should collect evidence and file the issue directly when they have GitHub access.

Before filing a public issue, redact private project and personal information. Do not include real app names, private bundle IDs, team IDs, organization names, user names, accounts, emails, phone numbers, internal hosts, absolute private paths, full private logs, or unredacted screenshots/evidence bundles. Use stable placeholders while keeping versions, commands, error codes, and the smallest sanitized reproduction details.

## Choose An Integration Path

| Need | Start Here | Notes |
| --- | --- | --- |
| Add in-app runtime to an iOS app | [iOS Embedded Runtime Integration Guide](#ios-embedded-runtime-integration-guide) | SwiftPM or CocoaPods, always visibly Debug-only in app source. |
| Install or update the macOS agent CLI | [CLI Integration Guide](#cli-integration-guide) | Homebrew for released builds, local source build only for unreleased validation. |
| Prepare a HarmonyOS / DevEco Emulator | [Harmony App Integration Guide](#harmony-app-integration-guide) | Host-side HDC adapter works without embedded runtime. |
| Validate a Harmony embedded runtime | [Harmony App Integration Guide](#harmony-app-integration-guide) | Use package id / import path `tritonkit` and `--runtime-base-url` direct checks while the SDK is standalone. |

## iOS Embedded Runtime Integration Guide

Use this shape when adding TritonKit to an iOS app. The app-side integration must be visibly Debug-only: put all TritonKit imports and startup code in a dedicated bootstrap file wrapped by `#if DEBUG`, then call that bootstrap only from a guarded app entry point.

### 1. Install The iOS Runtime

#### SwiftPM

In Xcode, add this package URL:

```text
https://github.com/NeptuneKit/TritonKit.git
```

Add the `TritonKit` product to the iOS app target. `TritonKitShared` is pulled in as a package target dependency. Keep every app-side source file that imports or starts TritonKit behind `#if DEBUG`; do not rely only on the library's Release no-op behavior.

SwiftPM / Xcode package product dependencies do not have a CocoaPods-style `:configurations => ['Debug']` switch. The supported SwiftPM path is source-level Debug isolation with the dedicated bootstrap file below, plus TritonKit's Release no-op runtime. If your production Release target must not link TritonKit at all, create a separate Debug-only app target or scheme and attach the `TritonKit` product only to that target.

For command-line package manifests:

```swift
.package(url: "https://github.com/NeptuneKit/TritonKit.git", branch: "main")
```

#### CocoaPods

During development, point CocoaPods at the repository and restrict both pods to Debug configurations:

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'TritonKitShared',
      :git => 'https://github.com/NeptuneKit/TritonKit.git',
      :branch => 'main',
      :configurations => ['Debug']
  pod 'TritonKit',
      :git => 'https://github.com/NeptuneKit/TritonKit.git',
      :branch => 'main',
      :configurations => ['Debug']
end
```

After versioned pod publication, this can become:

```ruby
pod 'TritonKit', '~> 0.1.0', :configurations => ['Debug']
```

### 2. Start TritonKit In The App

Put TritonKit bootstrap code in a dedicated iOS file and wrap the entire file in `#if DEBUG`.

```swift
// TritonKitDebugBootstrap.swift
#if DEBUG
import TritonKit

enum TritonKitDebugBootstrap {
    static func start() {
        TritonKit.shared.start()
    }
}
#endif
```

`start()` reads `TRITON_HOST` / `TRITON_PORT` and falls back to `127.0.0.1:19421`. Use `TritonKit.shared.start(.device("192.168.1.20", port: 19421))` when a physical device needs to connect to a Mac LAN address.

Preferred facade APIs:

| Need | API |
| --- | --- |
| Start with environment fallback | `TritonKit.shared.start()` |
| Start with explicit local CLI port | `TritonKit.shared.start(.local(port: 19421))` |
| Start from environment variables | `TritonKit.shared.start(.environment())` |
| Start from a device to a Mac LAN address | `TritonKit.shared.start(.device("192.168.1.20", port: 19421))` |
| Start with advanced options | `TritonKit.shared.start { config in ... }` |
| Stop the debug runtime | `TritonKit.shared.stop()` |
| Observe connection state | `TritonKit.shared.onStateChange { state in ... }` |
| Observe connection errors | `TritonKit.shared.onError { error in ... }` |

For advanced debug bootstrap code, keep the same file-level `#if DEBUG` guard and configure the facade in one closure:

```swift
#if DEBUG
TritonKit.shared.start { config in
    config.endpoint = .device("192.168.1.20", port: 19421)
    config.autoReconnect = true
    config.features = [.hierarchy, .accessibility, .input]
    config.redaction.secureText = .lengthOnly
    config.appIdentity = .init(name: "YourApp", tags: ["smoke"])
}
#endif
```

Observe connection status without implementing a full delegate:

```swift
#if DEBUG
enum TritonKitDebugObservers {
    private static var stateToken: TritonKit.ObservationToken?
    private static var errorToken: TritonKit.ObservationToken?

    static func start() {
        stateToken = TritonKit.shared.onStateChange { state in
            print("TritonKit state:", state)
        }
        errorToken = TritonKit.shared.onError { error in
            print("TritonKit error:", error)
        }
    }
}
#endif
```

Retain observation tokens for as long as callbacks are needed, and call `cancel()` when an observer should be removed. `start` retains the default request handler internally; only use the lower-level `delegate` / `connect(host:port:)` API when you need a custom delegate or custom message routing.

Then call it only from a Debug branch in the app bootstrap:

```swift
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        TritonKitDebugBootstrap.start()
        #endif

        return true
    }
}
```

For a SwiftUI app, keep the same dedicated Debug bootstrap file and call it from a guarded `onAppear`:

```swift
import SwiftUI

@main
struct YourApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    #if DEBUG
                    TritonKitDebugBootstrap.start()
                    #endif
                }
        }
    }
}
```

### 3. iOS Network Notes

For physical devices or local-network testing, add development-only network privacy text to the app target as needed:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Allow TritonKit to connect to the local development CLI.</string>
```

If your app blocks cleartext development traffic through App Transport Security, add a debug-only ATS exception for your local workflow. Do not ship broad ATS exceptions in production.

### 4. iOS Runtime Boundary

`TritonKit.isRuntimeEnabled` is `true` only in `DEBUG` builds. In Release builds the public API remains compileable, but the embedded runtime does not connect, collect hierarchy, upload data, or respond to control messages. App-side integration files should still be explicitly wrapped in `#if DEBUG` so production entry points do not import or start TritonKit.

## CLI Integration Guide

Use the CLI guide independently when an agent only needs host-side simulator or Harmony / DevEco Emulator control. Use it together with the iOS or Harmony embedded runtime guides when the app process exposes TritonKit runtime endpoints.

### 1. Install The CLI

#### Homebrew

Install the released macOS `triton` binary with Homebrew first:

```bash
brew install NeptuneKit/tap/triton
```

Update it with:

```bash
brew update
brew upgrade triton
```

Homebrew installs only the macOS CLI. The iOS runtime still needs SwiftPM or CocoaPods integration in the app target.

TritonKit's release workflow updates the default tap repository, `NeptuneKit/homebrew-tap`, when a tag matching `v*` is pushed. Maintainers should publish through `docs-linhay/scripts/release.sh <version>`, which checks the tap repository, `TAP_GITHUB_TOKEN`, local validation, the GitHub Actions run, GitHub Release assets, and Homebrew fetch.

The tap formula is generated from:

- `.github/homebrew/triton.rb.template`
- `tritonkit_checksums.txt` from the GitHub Release assets

For a release tag such as `v0.1.0`, the expected install and update path is:

```bash
brew tap NeptuneKit/tap
brew install triton
brew update
brew upgrade triton
```

#### Local Source Fallback

Use the local source build only when validating unreleased TritonKit changes from this checkout, or when Homebrew / GitHub Release assets are unavailable:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
.build/cli/release/triton version --json
```

Use that binary directly or copy it into a directory on `PATH` for local regression work.

If a `triton serve` process may already be running from the target path, do not overwrite that path in place. Stop the server first, or install through a temporary file and atomically move it into place:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
cp .build/cli/release/triton ~/.local/bin/triton.new
mv ~/.local/bin/triton.new ~/.local/bin/triton
triton version --json
```

This avoids confusing macOS failures where a newly invoked CLI is killed after the active binary file was overwritten.

#### Manual Release Asset

After a versioned release is published, GitHub Releases provide architecture-specific CLI archives:

- `triton-macos-arm64.tar.gz`
- `triton-macos-x86_64.tar.gz`

Download the archive for your Mac, then copy `triton` into a directory on `PATH`.

When replacing an existing `triton` executable manually, use the same temporary-file plus `mv` pattern above, or stop `triton serve` before copying over the active path.

### 2. Run The CLI

Start the macOS-side server before launching the app:

```bash
triton serve --host 127.0.0.1 --port 19421
```

For an iOS Simulator, `127.0.0.1:19421` is the usual development path. For a physical device, bind the server to a reachable Mac interface and set `TRITON_HOST` to the Mac LAN IP:

```bash
triton serve --host 0.0.0.0 --port 19421
```

Then verify from another shell:

```bash
triton status --json
triton list --json
triton runtime manifest --json
triton state app --json
triton state scene --json
triton state route --json
triton state responder --json
triton snapshot --include app,scene,route,ax,geometry --json
triton hierarchy --json
triton ax --json
```

When validating a standalone embedded runtime HTTP endpoint before it is connected through `triton serve`, bypass the local control server with `--runtime-base-url`:

```bash
triton device runtime-url --platform harmony --target 127.0.0.1:10100 --probe-manifest --json
triton runtime manifest --runtime-base-url http://127.0.0.1:28767 --json
triton state route --runtime-base-url http://127.0.0.1:28767 --json
triton snapshot --runtime-base-url http://127.0.0.1:28767 --json
triton ledger --runtime-base-url http://127.0.0.1:28767 --jsonl
triton set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:28767 --json
```

For the Harmony demo, `28767` is the host-access embedded runtime port exposed through HDC `fport`; `18765` remains the device-to-host gateway fallback port used by the demo UI.

Host-side simulator helpers are available without a running TritonKit runtime. They wrap `xcrun simctl` but keep JSON output and stable Triton error envelopes:

```bash
triton sim list --json
triton sim use 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json
triton sim boot 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --wait --jsonl
triton sim screenshot --simulator booted --output /tmp/sim.png --json
triton app list --simulator booted --user-only --json
triton app info --bundle-id com.example.app --simulator booted --json
triton app install --app /tmp/Demo.app --simulator booted --json
triton app uninstall --bundle-id com.example.app --simulator booted --confirm --json
triton app launch --bundle-id com.example.app --simulator booted --json
triton app terminate --bundle-id com.example.app --simulator booted --json
triton app open-url "example://debug" --simulator booted --json
triton app container --bundle-id com.example.app --kind data --json
triton app prefs get DEBUG-mock --bundle-id com.example.app --json
triton app prefs dump --bundle-id com.example.app --json
```

`app open-url` only proves the URL was submitted to Simulator. Continue with `triton wait`, `triton find`, `triton assert`, or `triton app prefs get` to verify the business state.

Xcode project discovery and `xcodebuild` execution are also exposed through Triton CLI. Use this path before falling back to XcodeBuildMCP or raw `xcodebuild` so the agent sees stable JSON/JSONL contracts:

```bash
triton xcode discover --path . --json
triton xcode use --workspace App.xcworkspace --scheme App --configuration Debug --simulator 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json
triton xcode schemes --json
triton xcode settings --jsonl --timeout 1800
triton xcode build --jsonl --timeout 1800
triton xcode test --result-bundle /tmp/App.xcresult --jsonl
triton xcode run --jsonl
```

`xcode settings/build/test/run --jsonl` emits invocation, stdout/stderr samples, heartbeat, and summary events with stdout/stderr log paths and byte counts, which gives agents a way to inspect long-running builds without waiting blindly.

`xcode run` proves build, install, and launch were submitted. It does not prove business readiness; continue with `triton status`, `triton wait`, `triton assert`, screenshot, or evidence.

HarmonyOS NEXT / DevEco Emulator P0 discovery is exposed through the same host-side contract. It does not require a running TritonKit embedded runtime:

```bash
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device wait-ready --platform harmony --target 127.0.0.1:10100 --json
triton app inspect --platform harmony --bundle com.example.app --target 127.0.0.1:10100 --json
triton app install --platform harmony --hap /tmp/Demo.hap --target 127.0.0.1:10100 --json
triton app launch --platform harmony --bundle com.example.app --ability EntryAbility --target 127.0.0.1:10100 --json
triton app open-url --platform harmony --bundle com.example.app --ability EntryAbility "example://debug" --target 127.0.0.1:10100 --json
triton ax --platform harmony --target 127.0.0.1:10100 --output /tmp/harmony-layout.json --json
triton wait --platform harmony --target 127.0.0.1:10100 --text "目标页" --timeout 15 --json
triton tap "我的" --platform harmony --target 127.0.0.1:10100 --json
triton screenshot --platform harmony --target 127.0.0.1:10100 --output /tmp/smoke.jpeg --json
```

When multiple HDC targets are `Connected`, Triton returns `error.code=ambiguous_target` and requires an explicit `--target`. The adapter records `sourceCommand`; risk/policy metadata is for audit and configuration validation, not an interactive confirmation gate.

Harmony host-side `ax/wait/tap/screenshot` wrap `uitest dumpLayout`, `uitest uiInput click`, and `snapshot_display` with JSON envelopes. Layout and screenshot outputs can contain private UI data; inspect or redact artifacts before attaching them to public issues.

For repeatable regression flows, wait for asynchronous UI state before the next action or assertion:

```bash
triton tap "登录"
triton wait --gone "登录" --timeout 15 --json
triton wait --text "我的" --timeout 15 --json
triton wait --predicate 'text.exists("我的") && !text.exists("登录")' --timeout 15 --json
triton assert text-exists "我的" --json
triton assert text-not-exists "Qinghai" --within 180,120,190,500 --json
```

When the same text appears multiple times, list candidates first and then select by point, index, or bounds:

```bash
triton find "hello" --all
triton tap "hello" --at 240,580
triton tap "hello" --index 2
triton tap "hello" --within 180,0,220,500
```

For form-like flows, prefer embedded semantic commands over a fragile `tap` plus `type` chain:

```bash
triton focus "用户名" --json
triton set-text "用户名" "alice" --json
triton set-text "密码" "$TRITON_PASSWORD" --secure --json
triton select-segment "协议" "HTTP" --json
triton set-switch "记住我" on --json
triton ledger --limit 50 --jsonl
```

`set-text --secure` redacts the text value in command output and runtime ledger while preserving inserted length. `ledger --jsonl` is the recent embedded request/action replay stream for debugging selector resolution, runtime errors, elapsed time, and redaction state.

When a pass/fail decision needs attachable evidence, export a bundle with a machine-readable manifest:

```bash
triton capture --case login-success --output /tmp/login-success.tritonevidence --json
triton evidence --name login-success --output /tmp/login-success.tritonevidence --json
triton evidence inspect /tmp/login-success.tritonevidence --json
```

The first evidence bundle format is a directory package. It contains `manifest.json` plus artifacts such as `status.json`, `targets.json`, `version.json`, `hierarchy.json`, `ax.json`, `geometry.json`, `archive.json`, `screenshot.png`, and `screenshot.json`. Unsupported requested artifacts, such as `logs` in the current embedded runtime, are recorded in `manifest.skipped` with reasons. `capture` is the regression-oriented one-shot wrapper; `evidence` remains the lower-level capture/inspect command.

For repeatable short smoke flows, store the command sequence in a `.tritonplan` and replay it:

```bash
triton record --output /tmp/login-flow.tritonplan --json
triton plan inspect /tmp/login-flow.tritonplan --json
triton replay /tmp/login-flow.tritonplan --dry-run --var username=alice --var password-env=TRITON_PASSWORD --json
triton replay /tmp/login-flow.tritonplan --var username=alice --var password-env=TRITON_PASSWORD --json
```

`record` currently writes an editable starter template; it does not capture live terminal history or global input events yet. `replay` supports `tap`, `paste`, `type`, `clear`, `wait`, `screenshot`, and `evidence` steps, `${variable}` substitution, `--var key=value`, `--var key-env=ENV_NAME`, and secure value redaction in step summaries.

## Harmony App Integration Guide

Harmony has two separate integration paths. Keep them distinct when writing docs, issues, or smoke scripts:

| Path | Purpose | Requires app package changes |
| --- | --- | --- |
| Host-side HDC / DevEco Emulator adapter | Target discovery, readiness, app inspect, app launch, screenshots, layout, logs, and future evidence capture | No |
| Harmony embedded SDK | App-process manifest, snapshot, ledger, app state, route/responder providers, and semantic action providers | Yes, Debug-only |

For host-side emulator control, start with the CLI commands in [Run The CLI](#2-run-the-cli). This path is the default for emulator preparation and does not require a Harmony app to embed TritonKit.

For Harmony embedded SDK work, use the TritonKit brand name but keep the actual OHPM package id and ArkTS import path lowercase:

```text
tritonkit
```

The Harmony SDK currently comes from the `harmony-TritonKit` alignment work. Until an OHPM package is published, use the aligned source/HAR from that project for SDK validation and keep the business app integration Debug-only.

The embedded runtime must follow the same Release boundary as iOS: Debug builds may expose `platform=harmony` runtime metadata and app-provided semantics; Release builds must report disabled/no-op behavior and must not collect UI, screenshots, logs, route state, or action data.

Business semantics are opt-in provider hooks. A generic HAR must not pretend it can infer app-specific route, responder, or semantic action state. If the app registers scene, route, responder, or action providers, verify that `runtime.manifest` marks those capabilities as supported; otherwise `unsupported_runtime_scope` is the expected result.

When the Harmony embedded runtime is reachable through HDC `fport` but has not been connected through `triton serve`, use direct runtime checks:

```bash
triton device runtime-url --platform harmony --target 127.0.0.1:10100 --probe-manifest --json
triton runtime manifest --runtime-base-url http://127.0.0.1:28767 --json
triton state route --runtime-base-url http://127.0.0.1:28767 --json
triton snapshot --runtime-base-url http://127.0.0.1:28767 --json
triton ledger --runtime-base-url http://127.0.0.1:28767 --jsonl
triton set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:28767 --json
```

For the Harmony demo, `28767` is the host-access embedded runtime port exposed through HDC `fport`; `18765` remains the device-to-host gateway fallback port used by the demo UI.

## Release Assets

GitHub CI publishes release artifacts in two phases:

- `triton-macos-arm64.tar.gz`
- `tritonkit-skills.tar.gz`
- `tritonkit_checksums.txt`

The arm64 CLI package, combined skill package, and checksum manifest are enough to create the GitHub Release and update the Homebrew tap for Apple Silicon. `triton-macos-x86_64.tar.gz` is uploaded later by the Intel backfill job, which also refreshes `tritonkit_checksums.txt` and the tap formula.

CI writes the release version into both the CLI and packaged skills:

- `triton version --json` reports the CI-resolved version.
- Packaged `SKILL.md` files include `metadata.version` in front matter.
- Tag builds use the tag without the leading `v`, for example `v1.2.3` becomes `1.2.3`.
- Non-tag builds use a development version with the current short commit SHA.

For maintainers, the release flow is:

1. Run `docs-linhay/scripts/release.sh <version>`.
2. The script verifies the clean checkout, tap repository, `TAP_GITHUB_TOKEN`, and local gate.
3. The script creates and pushes an annotated `v*` tag.
4. CI builds arm64, packages skills, generates `tritonkit_checksums.txt`, uploads the initial GitHub Release assets, and updates the Homebrew tap.
5. The script returns after the arm64 Release and `brew fetch --formula NeptuneKit/tap/triton` are ready.
6. CI builds x86_64 independently; when the Intel runner finishes, it uploads the x86 asset, merges the checksum manifest, and updates the tap again.

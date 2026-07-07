# TritonKit

TritonKit provides a DEBUG-only embedded iOS runtime, Harmony / DevEco Emulator host-side contracts, Harmony embedded runtime alignment notes, and a macOS `triton` CLI for inspecting and controlling apps during development. It is designed for AI agents and automation scripts that need machine-readable access to app hierarchy, accessibility nodes, geometry, screenshots, and supported in-app controls.

TritonKit is in active development. If you hit a missing capability, unclear behavior, integration issue, or documentation gap, open an issue in `NeptuneKit/TritonKit`; AI agents using this repository should collect evidence and file the issue directly when they have GitHub access.

Before filing a public issue, redact private project and personal information. Do not include real app names, private bundle IDs, team IDs, organization names, user names, accounts, emails, phone numbers, internal hosts, absolute private paths, full private logs, or unredacted screenshots/evidence bundles. Use stable placeholders while keeping versions, commands, error codes, and the smallest sanitized reproduction details.

## Choose An Integration Path

| Need | Start Here | Notes |
| --- | --- | --- |
| Add in-app runtime to an iOS app | [iOS Embedded Runtime Integration Guide](#ios-embedded-runtime-integration-guide) | SwiftPM or CocoaPods, always visibly Debug-only in app source. |
| Install or update the macOS agent CLI | [CLI Integration Guide](#cli-integration-guide) | Homebrew for released builds, local source build only for unreleased validation. |
| Build, test, run, and diagnose an unknown Apple repo | [CLI Integration Guide](#cli-integration-guide) | Use `triton xcode`, `triton xcresult`, and artifact commands before raw `xcodebuild`. |
| Prepare a HarmonyOS / DevEco Emulator | [Harmony App Integration Guide](#harmony-app-integration-guide) | Host-side HDC adapter works without embedded runtime. |
| Validate a Harmony embedded runtime | [Harmony App Integration Guide](#harmony-app-integration-guide) | Use package id / import path `tritonkit` and `--runtime-base-url` direct checks while the SDK is standalone. |
| Add optional Codex / agent workflows | [Optional Agent Skills](#optional-agent-skills) | Install only the public skills; internal skills are for TritonKit repository maintenance. |

## Optional Agent Skills

TritonKit ships optional Codex / agent skills for AI-assisted adoption, feedback, and local emulator regression work. They are not required to use the iOS runtime, Harmony runtime notes, or macOS `triton` CLI.

External users and adopting projects should install the public skill bundle as one directory named `TritonKit.skills/` inside the configured Codex / agent skills directory. Do not copy the three public skills as separate top-level directories. Current public skills inside the bundle are:

- `tritonkit-dev-feedback`: collect adoption feedback, missing capabilities, confusing behavior, and documentation gaps as actionable TritonKit issues.
- `tritonkit-emulator-cli-takeover`: guide local CLI takeover of iOS Simulator, Android Emulator, and HarmonyOS / DevEco Emulator workflows.
- `tritonkit-real-project-regression`: validate TritonKit against real app projects while isolating external repo changes and preserving machine-readable evidence.

Do not install `.agents/skills/` into adopting projects by default. Those skills are repo-maintenance, governance, planning, supervision, and implementation workflows for TritonKit maintainers, and release packaging excludes them.

If you previously installed the three public skills as separate top-level directories, remove them before installing this bundle:

```sh
# Replace AGENT_SKILLS_DIR with your Codex / agent's configured skills directory.
rm -rf "$AGENT_SKILLS_DIR"/tritonkit-dev-feedback \
       "$AGENT_SKILLS_DIR"/tritonkit-emulator-cli-takeover \
       "$AGENT_SKILLS_DIR"/tritonkit-real-project-regression
```

If you install from a source checkout, copy the whole bundle directory:

```sh
mkdir -p "$AGENT_SKILLS_DIR"
rm -rf "$AGENT_SKILLS_DIR"/TritonKit.skills
cp -R TritonKit.skills "$AGENT_SKILLS_DIR"/TritonKit.skills
```

If you install from a release asset, extract the bundle into that same configured skills directory:

```sh
tar -xzf tritonkit-skills.tar.gz -C "$AGENT_SKILLS_DIR"
```

You can also use the repository installer, which removes the old separate-skill layout and installs the bundle:

```sh
docs-linhay/scripts/install-public-skills.sh "$AGENT_SKILLS_DIR"
docs-linhay/scripts/install-public-skills.sh "$AGENT_SKILLS_DIR" --from-tar tritonkit-skills.tar.gz
```

Restart the Codex / agent session after installation so the new skills are discovered.

## iOS Embedded Runtime Integration Guide

Use this shape when adding TritonKit to an iOS app. The app-side integration must be visibly Debug-only: put all TritonKit imports and startup code in a dedicated bootstrap file wrapped by `#if DEBUG`, then call that bootstrap only from a guarded app entry point.

### 1. Install The iOS Runtime

#### SwiftPM

In Xcode, add this package URL:

```text
https://github.com/NeptuneKit/TritonKit.git
```

Add only the `TritonKit` product to the iOS app target. `TritonKitShared` is an internal shared-contract target pulled in transitively; app integrations should not select or import it directly. Keep every app-side source file that imports or starts TritonKit behind `#if DEBUG`; do not rely only on the package runtime guard.

SwiftPM supports configuration-scoped build settings, so TritonKit defines `TRITONKIT_RUNTIME_ENABLED` only for Debug package builds and keeps the embedded runtime no-op in Release. SwiftPM / Xcode package product dependencies still do not have a CocoaPods-style `:configurations => ['Debug']` switch: the package product may remain attached to the target even though the runtime is disabled. If the production Release target must not link TritonKit at all, create a separate Debug-only app target or scheme and attach the `TritonKit` product only to that target.

For command-line package manifests:

```swift
.package(url: "https://github.com/NeptuneKit/TritonKit.git", branch: "main")
```

#### CocoaPods

During development, point CocoaPods at the repository and restrict the TritonKit pod to Debug configurations. Do not add `TritonKitShared` explicitly; the `TritonKit` podspec resolves the matching shared-contract pod transitively. The podspec defines `TRITONKIT_RUNTIME_ENABLED` for the TritonKit pod target only in Debug builds, so the app target should not need custom `OTHER_SWIFT_FLAGS` for this macro.

```ruby
target 'YourApp' do
  use_frameworks!

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

Put TritonKit bootstrap code in a dedicated iOS file and wrap the entire file in `#if DEBUG`. For team apps, prefer an opt-in Debug bootstrap so ordinary Debug builds do not expose the runtime unless the developer explicitly enables it.

```swift
// TritonKitDebugBootstrap.swift
#if DEBUG
import Foundation
import TritonKit

enum TritonKitDebugBootstrap {
    static func startIfEnabled() {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let isEnabled = arguments.contains("--triton-enabled")
            || environment["TRITON_ENABLED"] == "1"
            || UserDefaults.standard.bool(forKey: "TRITON_ENABLED")

        guard isEnabled else { return }

        TritonKit.shared.start { config in
            config.endpoint = .environment()
            config.autoReconnect = true
            config.features = [.hierarchy, .accessibility, .input]
            config.redaction.secureText = .lengthOnly
            config.redaction.collectClipboard = false
            config.redaction.collectNetwork = false
            config.redaction.collectLogs = false
            config.appIdentity = .init(name: "YourApp", tags: ["debug", "opt-in"])
        }
    }

    static func stop() {
        TritonKit.shared.stop()
    }
}
#endif
```

Enable it from Xcode with the launch argument `--triton-enabled`, the environment variable `TRITON_ENABLED=1`, or the Debug-only user default `TRITON_ENABLED=true`. `config.endpoint = .environment()` reads `TRITON_HOST` / `TRITON_PORT` and falls back to `127.0.0.1:19421`. Use `TritonKit.shared.start { config in config.endpoint = .device("192.168.1.20", port: 19421) }` when a physical device needs to connect to a Mac LAN address.

`config.features` is an app-owned runtime capability gate. Keep the single `TritonKit` package product attached to the Debug app target, then enable only the app-process capabilities this build should expose. Disabled capabilities remain visible in `triton debug runtime manifest --json` as `supported=true, enabled=false` with `reason=Capability disabled by app runtime configuration`; runtime requests for disabled input, WebView, or semantic actions return `error.code=capability_disabled` instead of executing. Omit `config.features` to use the default Debug capability set.

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
    config.features = [.appInfo, .hierarchy, .accessibility, .geometry, .screenshot, .input, .webView, .semantic]
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
        TritonKitDebugBootstrap.startIfEnabled()
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
                    TritonKitDebugBootstrap.startIfEnabled()
                    #endif
                }
        }
    }
}
```

### 3. App Semantic Providers

Use semantic providers when the strongest proof is app-domain state rather than AX text, layout, or pixels. Providers are opt-in, Debug-only hooks owned by the app. They can expose typed business facts and an action catalog to agents without adding domain-specific commands to TritonKit core.

Register providers from the same guarded Debug bootstrap path:

```swift
#if DEBUG
enum TritonKitSemanticProviders {
    private static var mediaToken: TritonKit.ObservationToken?

    static func register() {
        mediaToken = TritonKit.shared.registerSemanticStateProvider(
            domain: "media-playback",
            displayName: "Media Playback",
            schema: [
                TKRuntimeSemanticStateField(path: "isReady", type: "Bool"),
                TKRuntimeSemanticStateField(path: "isPlaying", type: "Bool"),
                TKRuntimeSemanticStateField(path: "elapsed", type: "Double"),
                TKRuntimeSemanticStateField(path: "routeActiveCount", type: "Int"),
            ],
            actions: [
                TKRuntimeSemanticActionDescriptor(name: "pause"),
                TKRuntimeSemanticActionDescriptor(
                    name: "seek",
                    arguments: [
                        TKRuntimeSemanticActionArgument(name: "seconds", type: "Double", required: true)
                    ]
                ),
            ],
            redaction: TKRuntimeSemanticRedaction(redactedPaths: ["currentURL"])
        ) {
            [
                "isReady": .bool(true),
                "isPlaying": .bool(true),
                "elapsed": .double(12.3),
                "routeActiveCount": .int(1),
            ]
        }
    }
}
#endif
```

Agents should read provider-backed semantics through snapshot:

```bash
triton debug snapshot --include semantic,app,scene --json
triton debug runtime manifest --json
triton capabilities --json
```

The `semantic` section reports registered domains, provider source, confidence, typed state, schema fields, redaction metadata, evidence commands, and provider-declared action descriptors. In this slice, `app-semantic-action` means the action catalog is discoverable through snapshot; generic provider action execution is a future command slice. If no provider is registered, TritonKit returns an empty semantic domain list with a warning, and agents must not infer business readiness from visible UI alone.

`triton debug runtime manifest --json` also advertises `semanticDomains[]` with domain, source, confidence, schema, action catalog, redaction policy, and evidence commands. The manifest intentionally does not include state values; use `debug snapshot --include semantic` for current facts.

### 4. iOS Network Notes

For physical devices or local-network testing, add development-only network privacy text to the app target as needed:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Allow TritonKit to connect to the local development CLI.</string>
```

If your app blocks cleartext development traffic through App Transport Security, add a debug-only ATS exception for your local workflow. Do not ship broad ATS exceptions in production.

### 5. iOS Runtime Boundary

`TritonKit.isRuntimeEnabled` is `true` only when the package manager build defines `TRITONKIT_RUNTIME_ENABLED` (SwiftPM Debug package configuration, or the TritonKit CocoaPods pod target Debug configuration). In Release package builds the public API remains compileable, but the embedded runtime does not connect, collect hierarchy, upload data, or respond to control messages. App-side integration files should still be explicitly wrapped in `#if DEBUG` so production entry points do not import or start TritonKit.

### 6. WebView Observation

Hybrid pages are exposed through the CLI instead of a browser UI. On iOS, `triton webview list/current --platform ios --json` can discover visible `WKWebView` candidates from the runtime tree; `triton webview current-url --platform ios --json` and `triton route assert-current-url '<url>' --platform ios --json` require provider URL metadata and are the smoke path for proving the native flow opened the expected H5 link. Provider-backed descriptors expose `providerCapabilities` so agents can read `supportsCurrentURL`, `supportsSnapshot`, `supportsBridgeCall`, `supportsEvents`, `supportsDOMInput`, and `supportsContentEditableTyping` with stable `supported`, `reason`, and `nextAction` fields. The embedded iOS provider supports focused `activeElement` text insertion for visible `input`, `textarea`, and `contenteditable` elements after runtime focus; broader page interaction remains opt-in. `triton webview call <method> --platform ios --json` only invokes methods explicitly allowlisted by the page or app, and `triton webview events --platform ios --limit 50 --json` only reads page events the app bridge has reported. TritonKit does not expose arbitrary JavaScript eval by default.

Harmony host-side layout can identify visible Web candidates without source changes, but it must not be treated as DOM, URL, JS, or bridge access. Register a Harmony embedded WebView provider before claiming provider-level capabilities. `triton capabilities --json` mirrors this split: `webview-list/current` are candidate discovery capabilities, while `webview-current-url/snapshot/bridge-call/events/wait` and `route-current-url-assert` are provider-level capabilities with separate `nextAction` and `evidence`.

## CLI Integration Guide

Use the CLI guide independently when an agent only needs host-side simulator or Harmony / DevEco Emulator control. Use it together with the iOS or Harmony embedded runtime guides when the app process exposes TritonKit runtime endpoints.

Host-side iOS Simulator setup should still prefer Triton commands before external fallback tools. `triton sim tap --simulator booted --x 200 --y 400 --json` and `triton sim type --simulator booted --text ascii --json` are reserved agent-facing entries for this lane, but the current public `xcrun simctl io` contract exposes screenshot/video/screen configuration primitives only, not stable tap or keyboard type primitives. TritonKit therefore returns `unsupported_host_input` for those commands instead of pretending host input succeeded; non-ASCII text is rejected earlier with `unsupported_text_input`. Use embedded runtime semantic input, app-owned debug hooks, pasteboard flows, screenshots, app preferences, or evidence capture to prove business state until a stable host input adapter is selected.

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

#### Readonly Web Device Hub

If you want the readonly Web Device Hub for local inspection, run:

```bash
triton web --print-command --json
triton web
```

`triton web` is a local launcher for the readonly Device Hub only. In a source checkout it starts the React/Vite dev server from `Web/`; in a released archive or Homebrew install it serves bundled `web/` static assets from the CLI package. It does not replace the CLI / HTTP control surface, and it does not introduce browser-side create / update / execute business actions.

If the default port is already occupied, `triton web --json` reports `web_port_in_use` before invoking npm/Vite. Use `lsof -nP -iTCP:34127 -sTCP:LISTEN` to find stale listeners, stop the old `triton web` / Vite process, or run `triton web --port <free-port>`. If a packaged/Homebrew server reports missing static assets, reinstall or update the package so `share/triton/web/index.html` exists, or pass `--root /path/to/TritonKit` when validating from a checkout.

For a non-mutating preflight, use `triton web status --json` to inspect whether the Web port is listening and `triton web doctor --json` to get ordered launch-readiness checks and recovery actions. These commands do not start npm/Vite and do not stop existing processes.

For unreleased validation from this repo, the debug build also supports the same launcher flow:

```bash
swift run --package-path CLI triton web --print-command --json
```

#### Manual Release Asset

After a versioned release is published, GitHub Releases provide architecture-specific CLI archives:

- `triton-macos-arm64.tar.gz`
- `triton-macos-x86_64.tar.gz`

Download the archive for your Mac, then copy `triton` into a directory on `PATH`. To keep `triton web` available outside a source checkout, also copy the archive's `web/` directory to `share/triton/web` next to that install prefix, for example `/usr/local/share/triton/web`.

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
triton debug runtime manifest --json
triton debug state app --json
triton debug state scene --json
triton debug state route --json
triton debug state responder --json
triton debug snapshot --include app,scene,route,ax,geometry --json
triton debug hierarchy --json
triton debug ax --json
```

Use `triton target list|use|current|resolve|wait-ready` as the preferred target-selection entry. When multiple iOS Simulator apps are connected to the same `triton serve`, it exposes stable embedded runtime targets shaped as `triton:ios-simulator:<SIMULATOR_UDID>`. Pass either the full target id or the simulator UDID through `--target`; commands that still rely on the default `triton:local` return `error.code=ambiguous_target` instead of choosing a connection implicitly.

When validating a standalone embedded runtime HTTP endpoint before it is connected through `triton serve`, bypass the local control server with `--runtime-base-url`:

```bash
triton target list --platform ios --json
triton target use 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --platform ios --json
triton target resolve booted --platform ios --json
triton target wait-ready booted --platform ios --json
triton device alias set harmony-a --platform harmony --target 127.0.0.1:10100 --json
triton device runtime-url --device harmony-a --probe-manifest --json
triton debug runtime manifest --runtime-base-url http://127.0.0.1:28767 --json
triton debug state route --runtime-base-url http://127.0.0.1:28767 --json
triton debug snapshot --runtime-base-url http://127.0.0.1:28767 --json
triton debug ledger --runtime-base-url http://127.0.0.1:28767 --jsonl
triton act set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:28767 --json
```

If you already have the raw HDC target id, you can call `triton device runtime-url --platform harmony --target 127.0.0.1:10100 --probe-manifest --json` directly.

For the Harmony demo, `28767` is the host-access embedded runtime port exposed through HDC `fport`; `18765` remains the device-to-host gateway fallback port used by the demo UI.

Host-side simulator helpers are available without a running TritonKit runtime. They wrap `xcrun simctl` but keep JSON output and stable Triton error envelopes:

```bash
triton sim list --json
triton sim use 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json
triton sim boot 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --wait --jsonl
triton sim screenshot --simulator booted --output /tmp/sim.png --json
triton sim record --simulator booted --output /tmp/sim.mov --duration 10 --json
triton sim logs --simulator booted --output /tmp/sim.ndjson --duration 5 --style ndjson --json
triton sim pair <watch-udid> <phone-udid> --json
triton sim unpair <pair-uuid> --json
triton sim clone <udid> "Clone for Smoke" --json
triton sim erase <udid> --confirm --json
triton sim upgrade <udid> <runtime-id> --json
triton sim status-bar list --simulator booted --json
triton sim status-bar override --simulator booted --time "09:41" --batteryLevel 100 --json
triton sim privacy grant location com.example.app --simulator booted --json
triton sim location set 37.7749,-122.4194 --simulator booted --json
triton sim ui appearance dark --simulator booted --json
triton sim pasteboard set "hello" --simulator booted --json
triton sim pasteboard get --simulator booted --json
triton sim pasteboard sync host device --simulator booted --json
triton sim push --bundle-id com.example.app --payload /tmp/push.json --simulator booted --json
triton sim runtime list --json
triton sim runtime verify com.apple.CoreSimulator.SimRuntime.iOS-26-5 --json
triton sim runtime add /tmp/iOSSimulatorRuntime.dmg --json
triton sim runtime delete all --dry-run --json
triton sim runtime delete com.apple.CoreSimulator.SimRuntime.iOS-26-5 --confirm --json
triton sim runtime unmount com.apple.CoreSimulator.SimRuntime.iOS-26-5 --json
triton sim runtime scan-and-mount --json
triton sim runtime match list --json
triton sim runtime match set iphoneos26.5 23F77 --json
triton sim runtime match set iphoneos26.5 --default --json
triton sim runtime dyld-cache update com.apple.CoreSimulator.SimRuntime.iOS-26-5 --json
triton sim runtime dyld-cache remove com.apple.CoreSimulator.SimRuntime.iOS-26-5 --confirm --json
triton sim personalization personalize com.apple.CoreSimulator.SimRuntime.iOS-26-5 --json
triton sim personalization remove-manifest manifest.plist --confirm --json
triton sim personalization remove-all-manifests --confirm --json
triton sim personalization remove-personalization 12345 --confirm --json
triton sim personalization revoke-manifests --confirm --json
triton sim personalization scan-and-personalize --json
triton app list --device booted --user-only --json
triton app info --device booted --bundle-id com.example.app --json
triton app install --device booted --app /tmp/Demo.app --json
triton app uninstall --device booted --bundle-id com.example.app --confirm --json
triton app launch --device booted --bundle-id com.example.app --json
triton app terminate --device booted --bundle-id com.example.app --json
triton app go "example://debug"
triton app go "example://debug" --device booted
triton app open-url "example://debug" --device booted --json
triton webview current-url --platform ios --json
triton route assert-current-url "https://example.invalid/path" --platform ios --json
triton app container --device booted --bundle-id com.example.app --kind data --json
triton app prefs get DEBUG-mock --device booted --bundle-id com.example.app --json
triton app prefs set DEBUG-mock true --device booted --bundle-id com.example.app --json
triton app prefs set SeedState --type data --base64 W3t9XQ== --device booted --bundle-id com.example.app --json
triton app prefs dump --device booted --bundle-id com.example.app --json
triton workspace run --target booted --platform ios --scope simulator --app com.example.app --goal "Explore login" --app-mode launch --bundle-id com.example.app --observe-live --observe-kind tree --json
triton workspace run --target booted --platform ios --scope simulator --app com.example.app --goal "Open login" --app-mode launch --bundle-id com.example.app --observe-live --business-ready-text Continue --json
triton workspace run --target booted --platform ios --scope simulator --app com.example.app --goal "Open dashboard" --business-ready-text Dashboard --business-ready-live-wait --json
triton workspace run --target current --app com.example.app --goal "Explore login" --llm-provider mock --vlm-provider mock --execute-actions --json
triton workspace run --target current --app com.example.app --goal "Explore login" --llm-provider openai-compatible --llm-base-url http://127.0.0.1:8000/v1 --llm-model local-workspace-model --vlm-provider mock --execute-actions --json
triton workspace run --target current --app com.example.app --goal "Explore login" --llm-provider mock --vlm-provider openai-compatible --vlm-base-url http://127.0.0.1:8000/v1 --vlm-model local-vlm-model --json
triton workspace run --target current --app com.example.app --goal "Open dashboard" --llm-provider mock --vlm-provider mock --execute-actions --business-ready-text Dashboard --business-ready-live-wait --json
triton workspace run --target booted --platform ios --scope simulator --app com.example.app --goal "Explore login" --observe-live --observe-kind tree --json
triton workspace inspect <run-id> --json
triton workspace export-flow <run-id> --output flow.tritonflow.yaml --json
```

`sim screenshot` captures the CoreSimulator framebuffer. Its JSON output includes `pixelWidth`, `pixelHeight`, `display.*`, `orientationPolicy=raw-framebuffer`, and `orientationNote`; use `--display internal|external|<screen-id>|<display-uuid>` when the default display selected by `simctl` is not the one you want. Triton does not rotate iPad framebuffer screenshots yet, so downstream evidence viewers should treat the orientation metadata as authoritative.

Destructive commands require `--confirm` by default, and `runtime delete` supports `--dry-run` first so agents can inspect the selected runtimes before deleting anything.

For local emulator or simulator actions, use Triton as the first control surface before fallback tools. Before running `baguette`, raw `xcrun` / `simctl`, `hdc`, `adb`, DevEco Emulator CLI, XcodeBuildMCP, or raw `xcodebuild`, run and preserve a machine-readable Triton check such as `triton status --json`, `triton doctor --json`, `triton capabilities --json`, `triton schema --command <command> --json`, or a task-specific `triton plan ... --json`. Fallback is allowed only when that Triton output proves `server_unavailable`, `unsupported_capability`, a missing schema / capability, or a task plan that does not cover the required action. Issue reports and regression notes should include the Triton command, stable error code or unsupported evidence, and the fallback command that was used.

`app go <url>` is the short iOS deep-link smoke entry: it opens the URL, waits for embedded runtime readiness, returns an app/route/AX snapshot summary, and defaults to JSON output. Use `--device <selector>` only when the current/default target is ambiguous.
For iOS simulator selectors, `sim:` is optional. `--device 60667794-96F8-40E6-8664-85538EC4663E` and `--device sim:60667794-96F8-40E6-8664-85538EC4663E` both resolve to the same simulator; keep `sim:` only when you want explicit platform disambiguation.
`app open-url` is the lower-level host action and only proves the URL was submitted to Simulator. Continue with `triton wait`, `triton act find`, `triton verify`, `triton webview current-url`, `triton route assert-current-url`, or `triton app prefs get` to verify the business state.
`workspace run --app-mode launch` submits `triton app launch` through the host app adapter and writes `evidence/actions/app-ready.json`. Without live observation this stays `phase=launch_submitted`; with `--observe-live` after launch it becomes `phase=launch_observed`, `ready=true`, and backlinks to `events.jsonl#observation.captured`. `businessReady` remains `false` until a later wait/assert/action/verification step proves the business flow is ready. The first built-in business checkpoint is `--business-ready-text <text>`: by default it matches exact visible text from the initial observation, writes `evidence/business/ready.json`, emits `business.ready` plus passed `verify.checked`, and returns `run.status=passed` only when matched. Add `--business-ready-live-wait` to call runtime wait(text) instead; the artifact records `check=runtime_wait`, `source=runtime.wait`, `phase=wait_matched|wait_timeout|wait_unmatched`, and nested wait evidence. `workspace run` can call a local OpenAI-compatible LLM for model decisions with `--llm-provider openai-compatible --llm-base-url http://127.0.0.1:<port>/v1 --llm-model <model>`, and can preflight a local OpenAI-compatible VLM with `--vlm-provider openai-compatible --vlm-base-url http://127.0.0.1:<port>/v1 --vlm-model <model>`. Remote LLM/VLM endpoints are rejected unless `--allow-remote-llm` or `--allow-remote-vlm` is explicit; API keys are read by env name without writing secret values to artifacts. Add `--execute-actions` only when the model-selected candidate should be executed through the runtime action provider; it writes `evidence/actions/action-000.json`, emits `action.executed` pointing at that evidence, and marks the Atlas transition `executed_unverified` until a later wait or verify proves business readiness. If a ready VLM provider and a readable initial screenshot artifact are both available, Triton generates `coordinate-contract.json`, calls VLM grounding before the tap, writes `evidence/actions/vlm-000/vlm-grounding.json` plus overlay/request/response artifacts, uses the grounded runtime point for the tap, and marks action evidence with `proofSource=vlm.grounding+runtime.input`; otherwise the bounded runtime selector path remains `proofSource=runtime.input`. When `--execute-actions` is combined with `--business-ready-live-wait`, Triton runs the wait after the action; a matched wait writes `stage=post_action`, `phase=post_action_wait_matched`, returns `run.status=passed`, and marks the Atlas transition `verified`. Without `--app-mode launch`, the app lifecycle remains a dry skeleton and `--observe-live` only seeds the initial Atlas screen.

Xcode project discovery and `xcodebuild` execution are also exposed through Triton CLI. Use this path before falling back to XcodeBuildMCP or raw `xcodebuild` so the agent sees stable JSON/JSONL contracts; if fallback is still required, keep the `triton schema --command xcode --json` or `triton xcode ...` failure / unsupported evidence with the fallback log:

```bash
triton xcode discover --path . --json
triton xcode use --workspace App.xcworkspace --scheme App --configuration Debug --simulator 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json
triton xcode schemes --json
triton xcode status --json
triton xcode wait-idle --workspace App.xcworkspace --timeout 120 --json
triton xcode settings --jsonl --timeout 1800
triton xcode build --jsonl --timeout 1800
triton xcode test --result-bundle /tmp/App.xcresult --jsonl
triton xcresult summary --path /tmp/App.xcresult --json
triton xcresult failures --path /tmp/App.xcresult --json
triton xcode run --jsonl
triton xctrace record --template "Time Profiler" --device 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --time-limit 5s --output /tmp/App.trace --json
triton coverage report --xcresult /tmp/App.xcresult --output /tmp/coverage.json --json
```

If `triton xcode build/test/run` returns `xcodebuild_interrupted` or `orphaned_xcodebuild`, inspect the final summary's stdout/stderr artifact paths and run `triton xcode status --json` followed by `triton xcode wait-idle --workspace <workspace> --timeout 120 --json` before retrying or falling back.

`xcode settings/build/test/run --jsonl` emits invocation, stdout/stderr samples, heartbeat, and summary events with stdout/stderr log paths and byte counts, which gives agents a way to inspect long-running builds without waiting blindly.

`xcode test` writes the result bundle but does not yet inline all test counts or failures into the final build summary. Run `triton xcresult summary` and `triton xcresult failures` against the bundle to produce issue-ready test evidence.

`xcresult summary/failures` redact private paths, emails, bearer tokens, password/token/API-key fragments, and long token-like strings by default across JSON and text output, including `path` and `sourceCommand`. Use `--include-sensitive` only for local private debugging, not for public issues.

`xcode run` proves build, install, and launch were submitted. It does not prove business readiness; continue with `triton status`, `triton wait`, `triton verify`, screenshot, or evidence.

`xctrace record` and `coverage report` are artifact commands. They return paths, source commands, and byte summaries; they do not inline large `.trace` or coverage payloads and do not prove app business readiness by themselves. Stdout-backed artifact writes reject existing files and symbolic links by default to avoid accidental overwrite during agent runs.

Common host target discovery, selection, and readiness are exposed through `triton target`. Keep `triton device` for host-side tool probing, aliasing, Android Emulator start/stop, runtime-url, screenshot, and Harmony stop orchestration, and keep `triton sim` for iOS-only advanced maintenance such as runtime, privacy, location, status bar, pasteboard, push, logs, and diagnostics.

```bash
triton target list --platform ios --json
triton target use 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --platform ios --json
triton target wait-ready 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --platform ios --json
triton device doctor --platform ios --json
triton device list --platform ios --json
triton device screenshot --platform ios --target 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --output /tmp/sim.png --json
```

Android Emulator host-side discovery and smoke do not require an embedded TritonKit runtime:

```bash
triton target list --platform android --json
triton target use emulator-5554 --platform android --json
triton target wait-ready emulator-5554 --platform android --json
triton device doctor --platform android --json
triton device list --platform android --json
triton device start --platform android --avd Dxyer_API_34 --headless --gpu swiftshader_indirect --plan-only --json
triton device stop --platform android --device emulator-5554 --confirm --json
triton device alias set android-a --platform android --target emulator-5554 --json
triton device screenshot --device android-a --output /tmp/android-before.png --json
triton app list --platform android --device android-a --json
triton app inspect --platform android --device android-a --bundle com.android.settings --json
triton app launch --platform android --device android-a --package-name com.android.settings --json
triton observe tree --platform android --target emulator-5554 --outline --json
triton node resolve @1 --platform android --target emulator-5554 --json
triton debug ax --platform android --device android-a --output /tmp/android-window.xml --json
triton wait --platform android --target emulator-5554 --text "Settings" --timeout 10 --json
triton act tap --platform android --target emulator-5554 "Network & internet" --json
triton smoke android --device android-a --package com.android.settings --wait-text "Settings" --tap-text "Network & internet" --post-tap-wait-text "Internet" --screenshot /tmp/android-smoke.png --evidence /tmp/android-smoke.tritonevidence --json
```

Android `app inspect` uses `adb shell dumpsys package` and returns `host.android-app-inspect`. Android host-side `observe tree` / `ax` / `wait` / `tap` currently rely on `adb shell uiautomator dump` followed by `adb shell cat` of the dumped XML. `observe tree --outline` writes repo-local `.triton/node-aliases.json` aliases for immediate `node resolve @N` follow-up; refresh the outline when `node resolve` returns `stale_node_alias`. Parse `ax --platform android` as `host.android-ax`, and keep UIAutomator-backed commands serialized per emulator target during smoke or evidence capture; concurrent dump/read-back flows on the same emulator have previously produced host command exits before the XML was fully available.

HarmonyOS NEXT / DevEco Emulator host-side discovery does not require a running TritonKit embedded runtime:

```bash
triton target list --platform harmony --json
triton target use 127.0.0.1:10100 --platform harmony --json
triton target wait-ready 127.0.0.1:10100 --platform harmony --json
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device screenshot --device 127.0.0.1:10100 --output /tmp/smoke.jpeg --json
triton device stop --platform harmony --hvd "Codex Test Phone" --path ~/.Huawei/Emulator/deployed --confirm --json
triton app inspect --platform harmony --bundle com.example.app --target 127.0.0.1:10100 --json
triton app install --device 127.0.0.1:10100 --hap /tmp/Demo.hap --json
triton app launch --device 127.0.0.1:10100 --bundle com.example.app --ability EntryAbility --json
triton app open-url --device 127.0.0.1:10100 --bundle com.example.app --ability EntryAbility "example://debug" --json
triton debug ax --platform harmony --target 127.0.0.1:10100 --output /tmp/harmony-layout.json --json
triton wait --platform harmony --target 127.0.0.1:10100 --text "目标页" --timeout 15 --json
triton act tap "我的" --platform harmony --target 127.0.0.1:10100 --json
triton screenshot --platform harmony --target 127.0.0.1:10100 --output /tmp/smoke.jpeg --json
```

When multiple HDC targets are `Connected`, Triton returns `error.code=ambiguous_target` and requires an explicit `--target`. The adapter records `sourceCommand`; risk/policy metadata is for audit and configuration validation, not an interactive confirmation gate.

Harmony `device list --platform harmony --json` also attempts a read-only foreground app identity probe for connected targets. When HDC exposes a stable foreground mission, targets may include optional `appName`, `bundleIdentifier`, `identityState=current`, and `current=true`. If HDC does not expose a stable identity, Triton keeps `appName` / `bundleIdentifier` empty and reports `identityState=unknown`; if the host command itself cannot run, it reports `identityState=unsupported`. Do not treat the emulator target id or device label as an app identity.

When Triton starts a Harmony HVD through its `triton-harmony-emulator` launchd keepalive job, close it with `triton device stop --platform harmony ... --confirm --json` instead of raw `Emulator -stop`. The Triton command unloads `gui/<uid>/triton-harmony-emulator` before calling DevEco `Emulator -stop`, so launchd does not restart the emulator after a successful stop.

Harmony host-side `ax/wait/tap/screenshot` wrap `uitest dumpLayout`, `uitest uiInput click`, and `snapshot_display` with JSON envelopes. Layout and screenshot outputs can contain private UI data; inspect or redact artifacts before attaching them to public issues.

For repeatable regression flows, wait for asynchronous UI state before the next action or assertion:

```bash
triton act tap "登录" --json
triton wait --gone "登录" --timeout 15 --json
triton wait --text "我的" --timeout 15 --json
triton wait --predicate 'text.exists("我的") && !text.exists("登录")' --timeout 15 --json
triton verify text-exists "我的" --json
triton verify text-not-exists "Qinghai" --within 180,120,190,500 --json
```

When the same text appears multiple times, list candidates first and then select by point, index, or bounds:

```bash
triton act find "hello" --all --json
triton act tap "hello" --at 240,580 --json
triton act tap "hello" --index 2 --json
triton act tap "hello" --within 180,0,220,500 --json
```

For form-like flows, prefer embedded semantic commands over a fragile `tap` plus `type` chain:

```bash
triton act focus "用户名" --json
triton act set-text "用户名" "alice" --json
triton act set-text "密码" "$TRITON_PASSWORD" --secure --json
triton act select-segment "协议" "HTTP" --json
triton act set-switch "记住我" on --json
triton debug ledger --limit 50 --jsonl
```

`act set-text --secure` redacts the text value in command output and runtime ledger while preserving inserted length. `debug ledger --jsonl` is the recent embedded request/action replay stream for debugging selector resolution, runtime errors, elapsed time, and redaction state.

For iOS video regression with `AVPlayer` or `AVPlayerViewController`, include the media snapshot section before asserting playback behavior:

```bash
triton debug snapshot --include media,ax,screenshot-metadata --json
triton screenshot --json
triton evidence capture --case video-regression --output /tmp/video-regression.tritonevidence --json
```

The `media` section reports visible AVPlayer-backed surfaces, player status/rate/time metadata when public APIs expose it, AX playback-control candidates, automation confidence, fallback advice, and evidence commands. System `AVPlayerViewController` controls are not guaranteed to expose stable actionable AX nodes in every route; when the snapshot is `surface-only`, add app-owned DEBUG overlay controls with stable accessibility identifiers for play, pause, seek, progress, elapsed time, and duration, then verify those controls with `wait`, `act find`, `act tap`, and `verify`.

For app-domain readiness that cannot be proven from generic UI, prefer a registered semantic provider and include the semantic snapshot section:

```bash
triton debug snapshot --include semantic,app,scene --json
triton debug runtime manifest --json
triton capabilities --json
```

`semantic.domains[]` contains provider-backed state and an action descriptor catalog. Treat those descriptors as discoverability metadata in this release; generic `state query/assert/action perform` commands are not implemented yet.
`debug runtime manifest` exposes the lighter `semanticDomains[]` catalog so agents can discover domains and provider source before querying the snapshot.

When a pass/fail decision needs attachable evidence, export a bundle with a machine-readable manifest:

```bash
triton evidence capture --case login-success --output /tmp/login-success.tritonevidence --json
triton evidence inspect /tmp/login-success.tritonevidence --json
```

The first evidence bundle format is a directory package. It contains `manifest.json` plus artifacts such as `status.json`, `targets.json`, `version.json`, `hierarchy.json`, `ax.json`, `geometry.json`, `archive.json`, `screenshot.png`, and `screenshot.json`. `--include host,xcode` adds small read-only host/Xcode artifacts under `artifacts/host/` and `artifacts/xcode/`, including repo-local defaults, simulator list, Xcode process status, and shallow discovery when available. When an Xcode build/test/run summary was already written explicitly, pass `--xcode-summary /path/to/summary.json` to import that `TKXcodeActionSummary` as `artifacts/xcode/action-summary.json`; TritonKit does not copy stdout/stderr logs, `.xcresult`, or `.trace` files from the summary. These artifacts are marked sensitive for redaction. Unsupported requested artifacts, such as `logs` in the current embedded runtime, are recorded in `manifest.skipped` with reasons. `evidence capture` is the Prove workflow entry; use the explicit `capture` subcommand for new flows.

When an agent needs the next command sequence before executing a workflow, ask `plan` for a task-specific recommendation. The plan is only a recommendation; run the returned steps explicitly and use `wait`, `assert`, and `evidence` as proof.

```bash
triton plan ios-smoke --device iphone15 --bundle-id com.example.app --url myapp://smoke --text Home --evidence /tmp/smoke.tritonevidence --json
triton plan open-url --device iphone15 --url myapp://detail --text Ready --json
triton plan open-url --platform harmony --device harmony-a --bundle com.example.app --ability EntryAbility --hap /tmp/Demo.hap --url example://home --text Ready --evidence /tmp/harmony.tritonevidence --json
triton plan webview-check --expected-url https://example.com --text Loaded --json
```

When `plan open-url` is requested while the local server is unavailable, the JSON response keeps bootstrap recovery in `steps[]` and preserves the goal-specific workflow in `afterRecoverySteps[]`. Agents should start with `steps[]`, then execute `afterRecoverySteps[].argv` after recovery instead of re-planning from memory.

For repeatable short smoke flows, store the command sequence in a `.tritonplan` and replay it:

```bash
triton record --output /tmp/login-flow.tritonplan --json
triton plan inspect /tmp/login-flow.tritonplan --json
triton replay /tmp/login-flow.tritonplan --dry-run --var username=alice --var password-env=TRITON_PASSWORD --json
triton replay /tmp/login-flow.tritonplan --var username=alice --var password-env=TRITON_PASSWORD --json
```

`record` currently writes an editable starter template; it does not capture live terminal history or global input events yet. `replay` supports `tap`, `paste`, `type`, `clear`, `wait`, `screenshot`, and `evidence` steps, `${variable}` substitution, `--var key=value`, `--var key-env=ENV_NAME`, and secure value redaction in step summaries. `triton capabilities --json` exposes `plan-inspect` separately from `replay-dry-run`, so agents can discover offline plan inspection before choosing dry-run or real replay.

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
triton device alias set harmony-a --platform harmony --target 127.0.0.1:10100 --json
triton device runtime-url --device harmony-a --probe-manifest --json
triton debug runtime manifest --runtime-base-url http://127.0.0.1:28767 --json
triton debug state route --runtime-base-url http://127.0.0.1:28767 --json
triton debug snapshot --runtime-base-url http://127.0.0.1:28767 --json
triton debug ledger --runtime-base-url http://127.0.0.1:28767 --jsonl
triton act set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:28767 --json
```

If you already have the raw HDC target id, you can call `triton device runtime-url --platform harmony --target 127.0.0.1:10100 --probe-manifest --json` directly.

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
- Packaged skills are rooted at `TritonKit.skills/` and include `TritonKit.skills/BUILD_INFO.json` with the release version, optional tag, source commit, dirty flag, build time, and included skill list.
- Tag builds use the tag without the leading `v`, for example `v1.2.3` becomes `1.2.3`.
- Non-tag builds use a development version with the current short commit SHA.

For maintainers, the release flow is:

1. Run `docs-linhay/scripts/release.sh <version>`.
2. The script verifies the clean checkout, tap repository, `TAP_GITHUB_TOKEN`, and local gate.
3. The script creates and pushes an annotated `v*` tag.
4. CI builds arm64, packages skills, generates `tritonkit_checksums.txt`, uploads the initial GitHub Release assets, and updates the Homebrew tap.
5. The script returns after the arm64 Release and `brew fetch --formula NeptuneKit/tap/triton` are ready.
6. CI builds x86_64 independently; when the Intel runner finishes, it uploads the x86 asset, merges the checksum manifest, and updates the tap again.

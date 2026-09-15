# iOS app integration

Use this when helping someone add TritonKit to an iOS app.

## Package manager

SwiftPM URL:

```text
https://github.com/NeptuneKit/TritonKit.git
```

Add only the `TritonKit` product to the iOS app target. Do not ask app teams to select or import internal TritonKit targets directly.

TritonKit defines `TRITONKIT_RUNTIME_ENABLED` only for Debug package builds and keeps Release runtime no-op. SwiftPM/Xcode package products do not have a CocoaPods-style Debug-only product dependency switch. If production Release must not link TritonKit at all, use a separate Debug-only app target or scheme and attach the product only there.

CocoaPods development setup:

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'TritonKit',
      :git => 'https://github.com/NeptuneKit/TritonKit.git',
      :branch => 'main',
      :configurations => ['Debug']
end
```

Add only `TritonKit`. The podspec defines the Debug runtime macro for the pod target; do not ask users to add custom app-target `OTHER_SWIFT_FLAGS`.

## Debug bootstrap

Put bootstrap code in a dedicated iOS file and wrap the whole file in `#if DEBUG`. Prefer explicit opt-in so ordinary Debug builds do not expose the runtime.

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

Call it only from a Debug branch in AppDelegate, SceneDelegate, or SwiftUI `onAppear`:

```swift
#if DEBUG
TritonKitDebugBootstrap.startIfEnabled()
#endif
```

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

Retain observation tokens for as long as callbacks are needed. Use lower-level `delegate` / `connect(host:port:)` only for custom delegates or custom message routing.

## CLI and network

Install released CLI with Homebrew:

```bash
brew install NeptuneKit/tap/triton
brew update
brew upgrade triton
triton serve --host 127.0.0.1 --port 19421
```

For physical devices, bind to a reachable Mac interface and set `TRITON_HOST` to the Mac LAN IP:

```bash
triton serve --host 0.0.0.0 --port 19421
```

### Real-device runtime readiness

For real-device smoke, launch success only proves host submission (`businessReady=false`), not runtime connectivity. After starting the server on a trusted development network, inject variables into the Debug **App process**:

```bash
triton app launch --platform ios --scope real --device '<ios-real-selector>' \
  --bundle-id '<bundle-id>' --env TRITON_ENABLED=1 \
  --env 'TRITON_HOST=<mac-lan-ip>' --env TRITON_PORT=19421 --json
triton list --json
```

Replace placeholders, allow local-network access, and relaunch an already-running App as needed for environment changes. Mac shell exports alone do not configure the device process; device loopback is not the Mac, and `0.0.0.0` is a bind address, not the App endpoint. Do not automatically widen server exposure. Match the intended App runtime from `list` and pass its id via `smoke ios --target` separately from `--device`; no USB tunnel, auto endpoint injection, or host/runtime identity binding is promised. If runtime resolution fails, stop and report `runtime.connect/runtime_not_connected`; do not continue to wait/assert/evidence or count host success as business pass.

Build unreleased CLI changes with:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
.build/cli/release/triton version --json
```

If replacing an executable that may be running `triton serve`, stop the server first or write `triton.new` and atomically `mv` it into place.

Add `NSLocalNetworkUsageDescription` for local-network device testing when iOS prompts. Use debug-only ATS exceptions for cleartext local development; do not ship broad ATS exceptions.

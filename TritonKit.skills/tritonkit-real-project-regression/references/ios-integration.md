## iOS App Integration Guide

Use this exact shape when the real app needs TritonKit embedded runtime access.

SwiftPM:

```text
https://github.com/NeptuneKit/TritonKit.git
```

Add only the `TritonKit` product to the iOS app target. App integrations should not select or import internal TritonKit targets directly. Keep every app-side source file that imports or starts TritonKit behind `#if DEBUG`; do not rely only on the package runtime guard.

SwiftPM supports configuration-scoped build settings, so TritonKit defines `TRITONKIT_RUNTIME_ENABLED` only for Debug package builds and keeps the embedded runtime no-op in Release. SwiftPM / Xcode package product dependencies still do not have a CocoaPods-style `:configurations => ['Debug']` switch: the package product may remain attached to the target even though the runtime is disabled. If the production Release target must not link TritonKit at all, create a separate Debug-only app target or scheme and attach the `TritonKit` product only to that target.

CocoaPods during development. Add only the `TritonKit` pod; do not add sibling TritonKit pods. The podspec defines `TRITONKIT_RUNTIME_ENABLED` for the TritonKit pod target Debug configuration, while Release remains no-op:

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'TritonKit',
      :git => 'https://github.com/NeptuneKit/TritonKit.git',
      :branch => 'main',
      :configurations => ['Debug']
end
```

Create a dedicated Debug bootstrap file. For team apps, prefer an opt-in Debug bootstrap so ordinary Debug builds do not expose the runtime unless the developer explicitly enables it:

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

Enable it from Xcode with launch argument `--triton-enabled`, environment variable `TRITON_ENABLED=1`, or Debug-only user default `TRITON_ENABLED=true`. `config.endpoint = .environment()` reads `TRITON_HOST` / `TRITON_PORT` and falls back to `127.0.0.1:19421`. Use `TritonKit.shared.start { config in config.endpoint = .device("192.168.1.20", port: 19421) }` when a physical device needs to connect to a Mac LAN address.

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

Call the bootstrap only from a guarded app entry point:

```swift
#if DEBUG
TritonKitDebugBootstrap.startIfEnabled()
#endif
```

# TritonKit

TritonKit provides a DEBUG-only embedded iOS runtime and a macOS `triton` CLI for inspecting and controlling an app during development. It is designed for AI agents and automation scripts that need machine-readable access to app hierarchy, accessibility nodes, geometry, screenshots, and supported in-app controls.

TritonKit is in active development. If you hit a missing capability, unclear behavior, integration issue, or documentation gap, open an issue in `NeptuneKit/TritonKit`; AI agents using this repository should collect evidence and file the issue directly when they have GitHub access.

## Install The iOS Runtime

### SwiftPM

In Xcode, add this package URL:

```text
https://github.com/NeptuneKit/TritonKit.git
```

Add the `TritonKit` product to the iOS app target. `TritonKitShared` is pulled in as a package target dependency.

For command-line package manifests:

```swift
.package(url: "https://github.com/NeptuneKit/TritonKit.git", branch: "main")
```

### CocoaPods

During development, point CocoaPods at the repository:

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'TritonKitShared', :git => 'https://github.com/NeptuneKit/TritonKit.git', :branch => 'main'
  pod 'TritonKit', :git => 'https://github.com/NeptuneKit/TritonKit.git', :branch => 'main'
end
```

After versioned pod publication, this can become:

```ruby
pod 'TritonKit', '~> 0.1.0'
```

## Start TritonKit In The App

Keep the runtime behind `DEBUG`. The library also no-ops outside `DEBUG`, but guarding the integration keeps production code paths explicit.

```swift
import UIKit

#if DEBUG
import TritonKit
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    #if DEBUG
    private let tritonHandler = TritonKitRequestHandler()
    #endif

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        let host = ProcessInfo.processInfo.environment["TRITON_HOST"] ?? "127.0.0.1"
        let port = UInt16(ProcessInfo.processInfo.environment["TRITON_PORT"] ?? "") ?? 19421

        TritonKit.shared.delegate = tritonHandler
        TritonKit.shared.dataURL = URL(string: "http://\(host):\(port)")
        TritonKit.shared.connect(host: host, port: port)
        #endif

        return true
    }
}
```

For a SwiftUI app, keep the same handler alive for the app lifetime, then call the same setup from `onAppear` or your app bootstrap object.

## Install The CLI

### Homebrew

After a versioned release is published, install the macOS `triton` binary with Homebrew:

```bash
brew install NeptuneKit/tap/triton
```

Update it with:

```bash
brew update
brew upgrade triton
```

Homebrew installs only the macOS CLI. The iOS runtime still needs SwiftPM or CocoaPods integration in the app target.

TritonKit's release workflow updates the default tap repository, `NeptuneKit/homebrew-tap`, when a tag matching `v*` is pushed. Maintainers need to configure `TAP_GITHUB_TOKEN` in this repository with permission to push to that tap. Without that secret, GitHub Release assets remain available, but the Homebrew formula will not update automatically.

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

### Manual Release Asset

GitHub Releases provide architecture-specific CLI archives:

- `triton-macos-arm64.tar.gz`
- `triton-macos-x86_64.tar.gz`

Download the archive for your Mac, then copy `triton` into a directory on `PATH`.

## Run The CLI

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
triton hierarchy --json
triton ax --json
```

## iOS Network Notes

For physical devices or local-network testing, add development-only network privacy text to the app target as needed:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Allow TritonKit to connect to the local development CLI.</string>
```

If your app blocks cleartext development traffic through App Transport Security, add a debug-only ATS exception for your local workflow. Do not ship broad ATS exceptions in production.

## Runtime Boundary

`TritonKit.isRuntimeEnabled` is `true` only in `DEBUG` builds. In Release builds the public API remains compileable, but the embedded runtime does not connect, collect hierarchy, upload data, or respond to control messages.

## Release Assets

GitHub CI publishes workflow artifacts that include:

- `triton-macos-arm64.tar.gz`
- `triton-macos-arm64.zip`
- `triton-macos-x86_64.tar.gz`
- `triton-macos-x86_64.zip`
- `tritonkit_checksums.txt`
- `tritonkit-dev-feedback.tar.gz`
- `tritonkit-dev-feedback.zip`
- `tritonkit-real-project-regression.tar.gz`
- `tritonkit-real-project-regression.zip`

Tag pushes matching `v*` upload the same files as GitHub Release assets and update the Homebrew tap formula when `TAP_GITHUB_TOKEN` is configured.

CI writes the release version into both the CLI and packaged skills:

- `triton version --json` reports the CI-resolved version.
- Packaged `SKILL.md` files include `metadata.version` in front matter.
- Tag builds use the tag without the leading `v`, for example `v1.2.3` becomes `1.2.3`.
- Non-tag builds use a development version with the current short commit SHA.

For maintainers, the release flow is:

1. Push a version tag matching `v*`.
2. CI builds and uploads both macOS architectures.
3. CI generates `tritonkit_checksums.txt`.
4. CI renders the Homebrew formula from `.github/homebrew/triton.rb.template`.
5. CI pushes `Formula/triton.rb` to `NeptuneKit/homebrew-tap` when `TAP_GITHUB_TOKEN` is configured.

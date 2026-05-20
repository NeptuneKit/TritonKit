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

### Local Source Fallback

Use the local source build only when validating unreleased TritonKit changes from this checkout:

```bash
swift build -c release --product triton
.build/release/triton version --json
```

Use that binary directly or copy it into a directory on `PATH` for local regression work.

If a `triton serve` process may already be running from the target path, do not overwrite that path in place. Stop the server first, or install through a temporary file and atomically move it into place:

```bash
swift build -c release --product triton
cp .build/release/triton ~/.local/bin/triton.new
mv ~/.local/bin/triton.new ~/.local/bin/triton
triton version --json
```

This avoids confusing macOS failures where a newly invoked CLI is killed after the active binary file was overwritten.

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

### Manual Release Asset

After a versioned release is published, GitHub Releases provide architecture-specific CLI archives:

- `triton-macos-arm64.tar.gz`
- `triton-macos-x86_64.tar.gz`

Download the archive for your Mac, then copy `triton` into a directory on `PATH`.

When replacing an existing `triton` executable manually, use the same temporary-file plus `mv` pattern above, or stop `triton serve` before copying over the active path.

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

1. Run `docs-linhay/scripts/release.sh <version>`.
2. The script verifies the clean checkout, tap repository, `TAP_GITHUB_TOKEN`, and local gate.
3. The script creates and pushes an annotated `v*` tag.
4. CI builds both macOS architectures, packages skills, generates `tritonkit_checksums.txt`, and uploads GitHub Release assets.
5. CI renders the Homebrew formula from `.github/homebrew/triton.rb.template` and pushes `Formula/triton.rb` to `NeptuneKit/homebrew-tap`.
6. The script watches the CI run and verifies the published release plus `brew fetch --formula NeptuneKit/tap/triton`.

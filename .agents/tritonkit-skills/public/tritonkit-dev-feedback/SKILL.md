---
name: tritonkit-dev-feedback
description: Use when Codex is helping someone try, adopt, evaluate, or integrate TritonKit during its development stage, especially when the user has any requirement, bug, missing capability, confusing behavior, documentation gap, or compatibility concern that should become a GitHub issue in NeptuneKit/TritonKit. The AI agent should reproduce or clarify the finding, collect evidence, and submit the GitHub issue directly instead of asking the user to file it themselves.
metadata:
  version: 0.1.0-dev
---

# TritonKit Dev Feedback

## Principle

TritonKit is in active development. Treat any user need, bug report, rough edge, missing API, unclear documentation, or integration friction as valid feedback for the repository.

The AI agent owns the issue filing action. Do not tell the user to open an issue when the agent has enough context and GitHub access; create the issue directly.

Repository: `NeptuneKit/TritonKit` (`https://github.com/NeptuneKit/TritonKit`)

## Workflow

1. Clarify only the minimum missing detail needed to avoid filing a wrong issue.
2. If the user is adopting TritonKit in an iOS app, first guide them through the iOS integration checklist below.
3. Reproduce or inspect locally when possible. Prefer machine-readable TritonKit checks:
   - `triton evidence --name <case> --output /tmp/<case>.tritonevidence --json`
   - `triton evidence inspect /tmp/<case>.tritonevidence --json`
   - `triton capture --case <case> --output /tmp/<case>.tritonevidence --json`
   - `triton assert text-exists|text-not-exists <text> --json`
   - `triton record --output /tmp/<case>.tritonplan --json` when a reusable plan template helps describe the flow
   - `triton plan inspect /tmp/<case>.tritonplan --json`
   - `triton replay /tmp/<case>.tritonplan --dry-run --json` before sharing a reusable flow
   - `triton status --json`
   - `triton doctor --json`
   - `triton schema --json`
   - `triton plan --json`
   - `triton runtime manifest --json`
   - `triton snapshot --include app,scene,route,ax,geometry --json`
   - `triton ledger --limit 50 --jsonl`
   - host-side simulator checks that do not require embedded runtime:
     - `triton sim list --json`
     - `triton sim use <udid> --json`
     - `triton sim boot <udid> --wait --jsonl`
     - `triton sim screenshot --simulator booted --output /tmp/<case>-sim.png --json`
     - `triton app list --simulator booted --user-only --json`
     - `triton app info --bundle-id <bundle-id> --simulator booted --json`
     - `triton app install --app <path.app> --simulator booted --json`
     - `triton app uninstall --bundle-id <bundle-id> --simulator booted --confirm --json`
     - `triton app launch --bundle-id <bundle-id> --simulator booted --json`
     - `triton app terminate --bundle-id <bundle-id> --simulator booted --json`
     - `triton app open-url '<url>' --simulator booted --json`
     - `triton app container --bundle-id <bundle-id> --kind data --json`
     - `triton app prefs get <key> --bundle-id <bundle-id> --json`
   - host-side Harmony checks that do not require embedded runtime:
     - `triton device doctor --platform harmony --json`
     - `triton device list --platform harmony --json`
     - `triton device wait-ready --platform harmony --target <hdc-target> --json`
     - `triton app inspect --platform harmony --bundle <bundle> --target <hdc-target> --json`
     - `triton app launch --platform harmony --bundle <bundle> --ability <ability> --target <hdc-target> --json`
     - when multiple HDC targets are `Connected`, expect `error.code=ambiguous_target` and pass `--target`.
     - when a disposable HarmonyOS NEXT smoke app is needed, use the local `harmony-next` skill's `references/quickStart/ets/minimal-project-scaffold.md` and copy `references/templates/empty-ability-app/` instead of hand-rolling `oh-package.json5` / `module.json5` / `hvigorfile.ts`.
   - Harmony embedded SDK feedback should distinguish generic HAR capability from app-provided semantics:
     - run `triton device runtime-url --platform harmony --target <hdc-target> --probe-manifest --json` first when the runtime is on a Harmony emulator/device and the host needs an HDC fport base URL;
     - use `triton runtime manifest --runtime-base-url http://127.0.0.1:<port> --json`, `triton state route --runtime-base-url ... --json`, `triton snapshot --runtime-base-url ... --json`, `triton ledger --runtime-base-url ... --jsonl`, and `triton set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url ... --json` when validating a standalone embedded HTTP runtime before it is connected through `triton serve`;
     - generic runtime endpoints may return `unsupported_runtime_scope` for scene, route, responder, semantic actions, input, screenshot, hit-test, or system alerts;
     - if the app registers scene / route / responder / action providers, verify that `runtime.manifest` dynamically marks those capabilities as supported;
     - report missing provider hooks as feature requests, and report falsely-supported capabilities as bugs.
   - `triton find "HTTP"`, `triton tap "HTTP"`, `triton type "hello"`, `triton paste "console"`, or `triton clear` for agent-facing action checks; these default to JSON, and `--format text` is only for human-readable debugging.
   - For form flows, prefer semantic embedded actions when available: `triton focus "用户名" --json`, `triton set-text "用户名" "alice" --json`, `triton set-text "密码" "$TRITON_PASSWORD" --secure --json`, `triton select-segment "协议" "HTTP" --json`, and `triton set-switch "记住我" on --json`.
   - When the same text appears multiple times, run `triton find "<text>" --all` first; if you know a point inside the intended candidate, prefer `triton tap "<text>" --at x,y`, otherwise use `triton tap "<text>" --index <n>` or `triton tap "<text>" --within x,y,width,height`.
   - relevant `swift test`, smoke scripts, or app-level reproduction steps.
4. Classify the issue:
   - `bug`: behavior is broken, unstable, misleading, or inconsistent with documented/schema behavior.
   - `feature`: user needs a new capability or extension.
   - `docs`: documentation, onboarding, examples, or CLI help are unclear.
   - `question`: only if no concrete change is identifiable yet.
5. Create the issue with `gh issue create --repo NeptuneKit/TritonKit`.
6. Report the issue URL back to the user with a short summary and any local verification result.

## iOS App Integration Guide

Use this when helping someone add TritonKit to an app.

### Package Manager

SwiftPM:

```text
https://github.com/NeptuneKit/TritonKit.git
```

Add the `TritonKit` product to the iOS app target. Keep every app-side source file that imports or starts TritonKit behind `#if DEBUG`; do not rely only on the library's Release no-op behavior.

SwiftPM / Xcode package product dependencies do not have a CocoaPods-style `:configurations => ['Debug']` switch. The supported SwiftPM path is source-level Debug isolation with the dedicated bootstrap file below, plus TritonKit's Release no-op runtime. If the production Release target must not link TritonKit at all, create a separate Debug-only app target or scheme and attach the `TritonKit` product only to that target.

CocoaPods during development, restricted to Debug configurations:

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

### App Bootstrap

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

Then call it only from a Debug branch in AppDelegate:

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

For SwiftUI, keep the same dedicated Debug bootstrap file and call it from a guarded `onAppear`:

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

### CLI Verification

When the report depends on unreleased source changes, build and use the local release CLI first:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
.build/cli/release/triton version --json
```

If installing that build into an existing `PATH` location while `triton serve` may be running from the old binary, stop the server first or replace the executable atomically:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
cp .build/cli/release/triton ~/.local/bin/triton.new
mv ~/.local/bin/triton.new ~/.local/bin/triton
triton version --json
```

For released TritonKit builds, install or update the macOS CLI with Homebrew:

```bash
brew install NeptuneKit/tap/triton
brew update
brew upgrade triton
```

Start the macOS server before launching the app:

```bash
triton serve --host 127.0.0.1 --port 19421
```

For physical devices, bind to a reachable Mac interface and set `TRITON_HOST` to the Mac LAN IP:

```bash
triton serve --host 0.0.0.0 --port 19421
```

Then verify:

```bash
triton status --json
triton list --json
triton runtime manifest --json
triton state app --json
triton state scene --json
triton state route --json
triton state responder --json
triton sim list --json
triton sim use 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json
triton sim boot 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --wait --jsonl
triton app list --simulator booted --user-only --json
triton app info --bundle-id com.example.app --simulator booted --json
triton app install --app /tmp/Demo.app --simulator booted --json
triton app uninstall --bundle-id com.example.app --simulator booted --confirm --json
triton app launch --bundle-id com.example.app --simulator booted --json
triton app open-url 'example://debug' --simulator booted --json
triton app container --bundle-id com.example.app --kind data --json
triton app prefs get DEBUG-mock --bundle-id com.example.app --json
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device wait-ready --platform harmony --target 127.0.0.1:10100 --json
triton app inspect --platform harmony --bundle com.example.app --target 127.0.0.1:10100 --json
triton app launch --platform harmony --bundle com.example.app --ability EntryAbility --target 127.0.0.1:10100 --json
triton hierarchy --json
triton ax --json
triton runtime manifest --json
triton tap "first-check"
triton type "hello"
triton find "hello" --all
triton tap "hello" --at 240,580
triton tap "hello" --index 2
triton hit --at 240,580 --json
triton press home
triton assert text-exists first-check --json
triton evidence --name first-check --output /tmp/first-check.tritonevidence --json
triton capture --case first-check --output /tmp/first-check.tritonevidence --json
triton record --output /tmp/first-flow.tritonplan --json
triton replay /tmp/first-flow.tritonplan --dry-run --var username=alice --var password-env=TRITON_PASSWORD --json
```

### Network Notes

- For physical devices or local-network testing, add `NSLocalNetworkUsageDescription` to the app target if iOS prompts for local network access.
- If App Transport Security blocks cleartext local development traffic, use a debug-only ATS exception. Do not ship broad ATS exceptions in production.
- Release builds should compile, but `TritonKit.isRuntimeEnabled` is false and the embedded runtime does not connect, collect hierarchy, upload data, or respond to control messages. App-side integration files should still be explicitly wrapped in `#if DEBUG` so production entry points do not import or start TritonKit.

### Distribution Notes

- Repository: `https://github.com/NeptuneKit/TritonKit`
- Local source fallback: build `.build/cli/release/triton` from `CLI/Package.swift` when validating unreleased changes.
- Manual local CLI updates must use a temporary file plus `mv`, or stop `triton serve` before replacing the active binary path.
- Released Homebrew install path: `brew install NeptuneKit/tap/triton`.
- Homebrew updates come from `NeptuneKit/homebrew-tap` after release automation has run.
- GitHub Release assets include `triton-macos-arm64.tar.gz`, `triton-macos-x86_64.tar.gz`, `tritonkit_checksums.txt`, and project skill packages.
- If Homebrew or GitHub Release assets are unavailable, use the local release build and include the missing distribution evidence in the issue.

## Issue Content

Use a concise, reproducible issue body:

```markdown
## Background
<What the user was trying to do. Mention TritonKit is in active development if relevant.>

## Current Behavior
<Observed behavior, error envelope, logs, screenshots, or command output.>

## Expected Behavior
<What should happen or what capability is needed.>

## Reproduction / Evidence
<Commands, app/simulator context, files, versions, and whether reproduction was confirmed.>

## Proposed Next Step
<Smallest useful product or engineering action.>
```

Title format:

- `[Bug] <short behavior>`
- `[Feature] <short capability>`
- `[Docs] <short documentation gap>`
- `[Question] <short uncertainty>`

## Boundaries

- File issues for development-stage feedback even when the request is exploratory.
- If GitHub auth or network access blocks issue creation, state the blocker and provide the exact `gh issue create` command and issue body that should be run.
- Do not include secrets, private tokens, local-only credentials, or full private logs.
- When attaching a `.tritonplan`, keep secrets as `${variable}` placeholders and document the expected `--var key-env=ENV_NAME` bindings instead of writing secret values into the issue.
- Do not create duplicate issues if an existing open issue clearly covers the same feedback; comment on the existing issue instead when appropriate.
- Keep implementation work separate from feedback filing unless the user explicitly asks for a fix in the same turn.

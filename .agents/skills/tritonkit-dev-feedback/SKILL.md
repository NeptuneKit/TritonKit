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
   - `triton find "HTTP"`, `triton tap "HTTP"`, `triton type "hello"`, `triton paste "console"`, or `triton clear` for agent-facing action checks; these default to JSON, and `--format text` is only for human-readable debugging.
   - When the same text appears multiple times, run `triton find "<text>" --all` first; if you know a point inside the intended candidate, prefer `triton tap "<text>" --at x,y`, otherwise use `triton tap "<text>" --index <n>` or `triton tap "<text>" --within x,y,width,height`.
   - relevant `swift test`, smoke scripts, or app-level reproduction steps.
4. Classify the issue:
   - `bug`: behavior is broken, unstable, misleading, or inconsistent with documented/schema behavior.
   - `feature`: user needs a new capability or extension.
   - `docs`: documentation, onboarding, examples, or CLI help are unclear.
   - `question`: only if no concrete change is identifiable yet.
5. Create the issue with `gh issue create --repo NeptuneKit/TritonKit`.
6. Report the issue URL back to the user with a short summary and any local verification result.

## iOS Integration Checklist

Use this when helping someone add TritonKit to an app.

### Package Manager

SwiftPM:

```text
https://github.com/NeptuneKit/TritonKit.git
```

Add the `TritonKit` product to the iOS app target.

CocoaPods during development:

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'TritonKitShared', :git => 'https://github.com/NeptuneKit/TritonKit.git', :branch => 'main'
  pod 'TritonKit', :git => 'https://github.com/NeptuneKit/TritonKit.git', :branch => 'main'
end
```

### App Bootstrap

Keep the integration explicit in `DEBUG`. The runtime is also no-op outside `DEBUG`, but app code should make the development-only boundary obvious.

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

For SwiftUI, keep the `TritonKitRequestHandler` alive for the app lifetime and call the same setup from the app bootstrap object or `onAppear`.

### CLI Verification

When the report depends on unreleased source changes, build and use the local release CLI first:

```bash
swift build -c release --product triton
.build/release/triton version --json
```

If installing that build into an existing `PATH` location while `triton serve` may be running from the old binary, stop the server first or replace the executable atomically:

```bash
swift build -c release --product triton
cp .build/release/triton ~/.local/bin/triton.new
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
triton hierarchy --json
triton ax --json
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
- Release builds should compile, but `TritonKit.isRuntimeEnabled` is false and the embedded runtime does not connect, collect hierarchy, upload data, or respond to control messages.

### Distribution Notes

- Repository: `https://github.com/NeptuneKit/TritonKit`
- Local source fallback: build `.build/release/triton` from the repo checkout when validating unreleased changes.
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

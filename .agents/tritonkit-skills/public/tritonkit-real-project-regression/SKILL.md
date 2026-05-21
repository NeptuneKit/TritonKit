---
name: tritonkit-real-project-regression
description: Use when TritonKit moves from demo/self-test into a real iOS app or customer project for regression testing, adoption validation, or actual requirement discovery. Guides the AI agent to isolate external repo changes, run release CLI plus embedded runtime checks, collect machine-readable evidence, and turn real-project gaps into docs, fixes, or GitHub issues.
metadata:
  version: 0.1.0-dev
---

# TritonKit Real Project Regression

## Principle

Real-project validation is not the same as demo smoke. Treat the business app as an external system under test: avoid mixing its local changes into TritonKit commits, collect reproducible evidence, and keep every finding traceable to a command, output file, screenshot, or issue.

## Workflow

1. Confirm the real app, target branch, device/simulator, and the requirement being validated.
2. Check both repos before changing anything:
   - TritonKit: `git status --short --branch`
   - real app repo: `git status --short --branch`
3. Prepare the macOS `triton` CLI:
   - Prefer the released Homebrew binary when validating an external app: `brew install NeptuneKit/tap/triton` or `brew upgrade triton`.
   - If testing unreleased TritonKit changes from this repo, keep using the local release CLI.
   - If copying the local build into an existing `PATH` location while `triton serve` may be running from that path, stop the server first or replace through a temporary file and same-directory `mv`.
   - Confirm the active binary with `triton version --json` or `.build/cli/release/triton version --json`.
4. Integrate TritonKit into the app only through the intended DEBUG-only package path:
   - SwiftPM or CocoaPods as requested; CocoaPods examples must use `:configurations => ['Debug']`.
   - For SwiftPM, do not claim configuration-scoped package dependencies exist. Use source-level `#if DEBUG` isolation, or create a separate Debug-only app target/scheme if Release must not link TritonKit at all.
   - Put all app-side TritonKit code in a dedicated iOS file such as `TritonKitDebugBootstrap.swift`.
   - Wrap the entire file in `#if DEBUG`, including `import TritonKit` and `TritonKit.shared.start(...)`.
   - Call the bootstrap only from a `#if DEBUG` branch in AppDelegate, SceneDelegate, or SwiftUI `onAppear`.
   - Prefer `TritonKit.shared.start()` or the `start { config in ... }` facade; only use lower-level `delegate` / `connect(host:port:)` when the real app needs a custom delegate.
5. Start server with explicit port: `triton serve --host 127.0.0.1 --port 19421`.
6. Verify connection and target identity:
   - `triton status --json`
   - `triton list --json`
   - `triton runtime manifest --json`
   - `triton state app --json`
   - `triton state scene --json`
   - `triton state route --json`
   - `triton state responder --json`
   - `triton snapshot --include app,scene,route,ax,geometry --json`
   - `triton ledger --limit 50 --jsonl`
7. Prepare host-side simulator state through Triton before falling back to raw `xcrun`:
   - list simulators: `triton sim list --json`;
   - set a workspace default simulator when a flow will be reused: `triton sim use <udid> --json`;
   - boot and wait for readiness: `triton sim boot <udid> --wait --jsonl`;
   - list installed apps: `triton app list --simulator <udid-or-booted> --user-only --json`;
   - inspect installed app metadata: `triton app info --bundle-id <bundle-id> --simulator <udid-or-booted> --json`;
   - install simulator builds: `triton app install --app <path.app> --simulator <udid-or-booted> --json`;
   - uninstall disposable simulator apps only with explicit policy: `triton app uninstall --bundle-id <bundle-id> --simulator <udid-or-booted> --confirm --json`;
   - launch or terminate apps: `triton app launch --bundle-id <bundle-id> --simulator <udid-or-booted> --json` / `triton app terminate --bundle-id <bundle-id> --simulator <udid-or-booted> --json`;
   - submit app debug routes: `triton app open-url '<url>' --simulator <udid-or-booted> --json`;
   - locate containers: `triton app container --bundle-id <bundle-id> --kind data --simulator <udid-or-booted> --json`;
   - verify App preferences: `triton app prefs get <key> --bundle-id <bundle-id> --simulator <udid-or-booted> --json`;
   - capture host-side framebuffer: `triton sim screenshot --simulator <udid-or-booted> --output /tmp/<case>-sim.png --json`;
   - only use raw `xcrun simctl` when the needed capability is not in `triton schema --command sim --json` or `triton schema --command app --json`.
8. Prepare Xcode build/test/run through Triton before falling back to XcodeBuildMCP or raw `xcodebuild`:
   - discover project containers: `triton xcode discover --path <repo> --json`;
   - set reusable defaults: `triton xcode use --workspace <workspace>|--project <project> --scheme <scheme> --configuration Debug --simulator <udid> --json`;
   - list schemes: `triton xcode schemes --json`;
   - inspect app product settings: `triton xcode settings --jsonl --timeout <seconds>` for large workspaces, or `triton xcode settings --json` for quick projects;
   - build: `triton xcode build --jsonl`;
   - test: `triton xcode test --result-bundle /tmp/<case>.xcresult --jsonl`;
   - build/install/launch: `triton xcode run --jsonl`;
   - `xcode run` only proves build/install/launch submission; verify business readiness with `triton status`, `triton wait`, `triton assert`, screenshot, or evidence.
   - `xcode settings/build/test/run --jsonl` includes stdout/stderr log paths and byte counts; inspect those artifacts before waiting longer or falling back.
   - use XcodeBuildMCP only as a temporary fallback when `triton schema --command xcode --json` does not expose the needed capability.
9. For HarmonyOS NEXT / DevEco Emulator validation, use Triton host-side device discovery before raw `hdc`:
   - probe tools: `triton device doctor --platform harmony --json`;
   - list HDC targets: `triton device list --platform harmony --json`;
   - wait for boot readiness: `triton device wait-ready --platform harmony --target <hdc-target> --json`;
   - inspect app metadata: `triton app inspect --platform harmony --bundle <bundle> --target <hdc-target> --json`;
   - launch an Ability: `triton app launch --platform harmony --bundle <bundle> --ability <ability> --target <hdc-target> --json`;
   - when multiple targets are `Connected`, pass `--target`; `ambiguous_target` is the expected machine-readable failure.
   - if a disposable Harmony fixture app is needed, use the local `harmony-next` skill's minimal Empty Ability scaffold:
     - guide: `references/quickStart/ets/minimal-project-scaffold.md`;
     - template: `references/templates/empty-ability-app/`;
     - stable UI signals: `Harmony Smoke Ready`, `smoke-title`, `smoke-counter`, `smoke-increment`;
     - validation path: `ohpm install`, `hvigorw --mode module -p module=entry@default assembleHap`, HDC install/start, `uitest dumpLayout`, and `uitest screenCap`.
   - when validating a standalone Harmony embedded HTTP runtime before it is connected through `triton serve`, use direct runtime checks:
     - `triton device runtime-url --platform harmony --target <hdc-target> --probe-manifest --json` to prepare HDC fport and get the `baseURL`;
     - `triton runtime manifest --runtime-base-url http://127.0.0.1:<port> --json`;
     - `triton state route --runtime-base-url http://127.0.0.1:<port> --json`;
     - `triton snapshot --runtime-base-url http://127.0.0.1:<port> --json`;
     - `triton ledger --runtime-base-url http://127.0.0.1:<port> --jsonl`;
     - `triton set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:<port> --json` when an app action provider is registered.
10. Run observation before action:
   - prefer one-shot regression capture when a full report is needed: `triton capture --case <case> --output /tmp/<case>.tritonevidence --json`.
   - prefer one-shot evidence when a report or issue needs attachable proof: `triton evidence --name <case> --output /tmp/<case>.tritonevidence --json`.
   - inspect an existing bundle without reconnecting runtime: `triton evidence inspect /tmp/<case>.tritonevidence --json`.
   - `triton geometry --json`
   - `triton ax --json`
   - `triton screenshot --json --output <path>`
   - `triton export --format archive --output <path>`
11. Execute the smallest user-flow regression with machine-readable commands:
   - if the flow will be reused, first create or update a `.tritonplan`; use `triton record --output <file.tritonplan> --json` only as an editable starter template, not as proof that live recording happened;
   - inspect reusable flows with `triton plan inspect <file.tritonplan> --json`;
   - dry-run reusable flows before touching the app: `triton replay <file.tritonplan> --dry-run --var key=value --var secret-env=ENV --json`;
   - replay committed flows with `triton replay <file.tritonplan> --json`, keeping secure values in environment variables and using `--var <name>-env=<ENV>`;
   - prefer action commands that are already machine-readable by default: `triton find "HTTP"`, `triton tap "HTTP"`, `triton type "hello"`, `triton paste "console"`, `triton clear`; use `--format text` only for human-readable debugging;
   - for form flows, prefer semantic embedded actions over a `tap` plus `type` chain: `triton focus "用户名" --json`, `triton set-text "用户名" "alice" --json`, `triton set-text "密码" "$TRITON_PASSWORD" --secure --json`, `triton select-segment "协议" "HTTP" --json`, `triton set-switch "记住我" on --json`;
   - when labels repeat, run `triton find "<text>" --all`; if a known point lies inside the intended candidate, prefer `triton tap "<text>" --at x,y`, otherwise choose `triton tap "<text>" --index <n>` or `triton tap "<text>" --within x,y,width,height`;
   - keep `triton type --text <text>` only for compatibility with older scripts, never together with positional `<text>`;
   - keep `triton press --button <button>` only for compatibility with older scripts; prefer positional `triton press <button>`;
   - for batch input, use `triton input --json --summary --strict`;
   - after taps, submissions, and navigation, use `triton wait --text`, `triton wait --gone`, `triton wait --idle`, or a safe `triton wait --predicate` instead of fixed sleeps;
   - use `triton assert text-exists|text-not-exists <text> --json` for final pass/fail checks; add `--within x,y,width,height`, `--role`, or `--count` when labels repeat across headers, sidebars, and cells;
   - assert expected state through `wait`, a second `ax`, `find`, `screenshot`, archive check, or a fresh `evidence` bundle.
12. Store outputs under `/tmp` during iteration, then copy only durable screenshots or docs into the correct `docs-linhay/spaces/<space-key>/` location when the result is worth keeping.
13. If the real app exposes a missing TritonKit capability, unclear behavior, or bug, use `tritonkit-dev-feedback` and file/prepare the GitHub issue directly.

## iOS App Integration Guide

Use this exact shape when the real app needs TritonKit embedded runtime access.

SwiftPM:

```text
https://github.com/NeptuneKit/TritonKit.git
```

Add the `TritonKit` product to the iOS app target. Keep every app-side source file that imports or starts TritonKit behind `#if DEBUG`; do not rely only on the library's Release no-op behavior.

SwiftPM / Xcode package product dependencies do not have a CocoaPods-style `:configurations => ['Debug']` switch. The supported SwiftPM path is source-level Debug isolation with the dedicated bootstrap file below, plus TritonKit's Release no-op runtime. If the production Release target must not link TritonKit at all, create a separate Debug-only app target or scheme and attach the `TritonKit` product only to that target.

CocoaPods during development:

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

Create a dedicated Debug bootstrap file:

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

Call the bootstrap only from a guarded app entry point:

```swift
#if DEBUG
TritonKitDebugBootstrap.start()
#endif
```

## CLI Install Contract

Use the local release CLI while TritonKit is pre-release or while validating unreleased source changes:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
.build/cli/release/triton version --json
```

When installing that local build into `~/.local/bin/triton` or another existing `PATH` location, avoid overwriting a path that may be backing a running `triton serve` process. Stop the server first, or use atomic replacement:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
cp .build/cli/release/triton ~/.local/bin/triton.new
mv ~/.local/bin/triton.new ~/.local/bin/triton
triton version --json
```

Use Homebrew for real-project adoption checks by default:

```bash
brew install NeptuneKit/tap/triton
brew update
brew upgrade triton
```

Homebrew installs only the macOS CLI. The app-side embedded runtime still comes from SwiftPM or CocoaPods and must remain DEBUG-only.

Release assets live in `NeptuneKit/TritonKit` GitHub Releases and include arm64/x86_64 CLI archives plus `tritonkit_checksums.txt`. The Homebrew tap is updated from those release assets after `v*` tag releases. If the release or tap is unavailable in a test environment, do not fail the regression setup on Homebrew; use the local release CLI and file a TritonKit issue with the missing distribution evidence.

## Boundaries

- Do not commit or revert real app repo changes unless the user explicitly asks.
- Do not treat a successful tap as completion; verify the resulting app state.
- Do not add Web/Wails UI to satisfy real-project needs when CLI/HTTP can provide the contract.
- System alerts and SpringBoard-level controls remain outside embedded runtime scope; expect `runtime_ui_interrupted` or unsupported errors.
- If the requirement becomes product work, create or update the corresponding `space` before implementation.

## Existing Regression Entrypoints

- Generic complex harness: `docs-linhay/scripts/verify-complex-harness.sh`
- Intent CLI smoke: `docs-linhay/scripts/verify-intent-cli-smoke.sh`
- Overloaded real-app smoke: `docs-linhay/scripts/verify-overloaded-triton-smoke.sh`

## Replay Plan Notes

- `.tritonplan` schema version 1 supports `tap`, `paste`, `type`, `clear`, `wait`, `screenshot`, and `evidence`.
- Use `${variable}` placeholders for account names, passwords, hosts, or output paths.
- Use `secure: true` on password-like `paste` or `type` steps; replay summaries must redact values.
- Prefer an `evidence` step at the end of a reused smoke flow so the final state is attachable to issues and regression reports.
- For stale-list regressions, pair `capture` with `assert text-not-exists <stale text> --within <right-list-bounds>` so the report contains both artifacts and a machine-readable pass/fail result.

---
name: tritonkit-real-project-regression
description: Use when TritonKit moves from demo/self-test into a real iOS app, Harmony app, or customer project for regression testing, adoption validation, or actual requirement discovery. Guides the AI agent to isolate external repo changes, run release CLI plus host-side or embedded runtime checks, collect machine-readable evidence, and turn real-project gaps into docs, fixes, or GitHub issues.
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
4. Integrate TritonKit into the app only through the intended DEBUG-only package path when embedded runtime access is required:
   - If the task only needs Harmony host-side emulator discovery, readiness, app inspect, or app launch, do not add an app dependency; use the Harmony host-side commands below.
   - If the task needs iOS embedded runtime access, use the iOS package path below.
   - If the task needs Harmony embedded runtime access, use the Harmony package/source path below and keep provider semantics opt-in.
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
   - for iOS Simulator embedded runtime, confirm `triton list --json` exposes `triton:ios-simulator:<SIMULATOR_UDID>` and `simulatorUDID`;
   - if multiple iOS Simulator runtime targets are connected, pass `--target <SIMULATOR_UDID>` or `--target triton:ios-simulator:<SIMULATOR_UDID>` for runtime commands; default `triton:local` should return `ambiguous_target`.
   - `triton runtime manifest --json`
   - `triton state app --json`
   - `triton state scene --json`
   - `triton state route --json`
   - `triton state responder --json`
   - `triton snapshot --include app,scene,route,ax,geometry --json`
   - `triton ledger --limit 50 --jsonl`
   - when the real app has hybrid pages, verify WebView state explicitly:
     - `triton webview list --platform ios --json`
     - `triton webview current --platform ios --json`
     - `triton webview current-url --platform ios --json`
     - `triton route assert-current-url '<expected-url>' --platform ios --json`
     - `triton webview call <method> --platform ios --json` only for page/app allowlisted methods;
     - `triton webview events --platform ios --limit 50 --json`;
     - treat iOS WebView metadata as provider evidence, not DOM control;
     - treat Harmony host layout Web candidates as host-only until an embedded WebView provider is registered.
7. Prepare host-side simulator state through Triton before falling back to raw `xcrun`:
   - list simulators: `triton sim list --json`;
   - for repeated multi-simulator work, create a stable selector: `triton device alias set iphone15 --platform ios --target <udid> --json`;
   - prefer unified selectors for common host actions: `--device <alias-or-id>`; keep `--simulator <udid-or-booted>` for compatibility with existing scripts;
   - set a workspace default simulator when a flow will be reused: `triton sim use <udid> --json`;
   - boot and wait for readiness: `triton sim boot <udid> --wait --jsonl`;
   - list installed apps: `triton app list --device iphone15 --user-only --json`;
   - inspect installed app metadata: `triton app info --device iphone15 --bundle-id <bundle-id> --json`;
   - install simulator builds: `triton app install --device iphone15 --app <path.app> --json`;
   - uninstall disposable simulator apps only with explicit policy: `triton app uninstall --device iphone15 --bundle-id <bundle-id> --confirm --json`;
   - launch apps: `triton app launch --device iphone15 --bundle-id <bundle-id> --json`;
   - terminate apps: `triton app terminate --device iphone15 --bundle-id <bundle-id> --json`;
   - submit app debug routes: `triton app open-url '<url>' --device iphone15 --json`; when a DEBUG embedded runtime is connected, prefer `triton app open-url '<url>' --device iphone15 --wait-ready --snapshot --json` to capture readiness and snapshot summary in the same result;
   - locate containers: `triton app container --device iphone15 --bundle-id <bundle-id> --kind data --json`;
   - verify App preferences: `triton app prefs get <key> --device iphone15 --bundle-id <bundle-id> --json`;
   - set simulator App preferences from property-list compatible JSON values: `triton app prefs set <key> <json-value> --device iphone15 --bundle-id <bundle-id> --json`;
   - capture host-side framebuffer: `triton sim screenshot --simulator <udid-or-booted> --output /tmp/<case>-sim.png --json`;
   - only use raw `xcrun simctl` when the needed capability is not in `triton schema --command sim --json` or `triton schema --command app --json`.
8. Prepare Xcode build/test/run through Triton before falling back to XcodeBuildMCP or raw `xcodebuild`:
   - discover project containers: `triton xcode discover --path <repo> --json`;
   - set reusable defaults: `triton xcode use --workspace <workspace>|--project <project> --scheme <scheme> --configuration Debug --simulator <udid> --json`;
   - list schemes: `triton xcode schemes --json`;
   - diagnose current Xcode build/test occupancy before starting a smoke run: `triton xcode status --json`;
   - wait for the current workspace to stop building/testing: `triton xcode wait-idle --workspace <workspace> --timeout <seconds> --json`;
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
   - for repeated multi-emulator work, create a stable selector: `triton device alias set harmony-a --platform harmony --target <hdc-target> --json`;
   - wait for boot readiness: `triton device wait-ready --device harmony-a --json`;
   - inspect app metadata: `triton app inspect --platform harmony --bundle <bundle> --target <hdc-target> --json`;
   - install a debug HAP when needed: `triton app install --device harmony-a --hap <debug-signed.hap> --json`;
   - launch an Ability: `triton app launch --device harmony-a --bundle <bundle> --ability <ability> --json`;
   - run the one-command host smoke when available: `triton smoke harmony --device harmony-a --bundle <bundle> --ability <ability> --open-url <url> --wait-text <text> --screenshot /tmp/<case>.jpeg --evidence /tmp/<case>.tritonevidence --json`;
   - when multiple targets are `Connected`, pass `--device <alias-or-id>` or narrow with `--platform`, `--name`, `--runtime`, `--state`, and `--ready`; `ambiguous_target` is the expected machine-readable failure.
   - if a disposable Harmony fixture app is needed, use the local `harmony-next` skill's minimal Empty Ability scaffold:
     - guide: `references/quickStart/ets/minimal-project-scaffold.md`;
     - template: `references/templates/empty-ability-app/`;
     - stable UI signals: `Harmony Smoke Ready`, `smoke-title`, `smoke-counter`, `smoke-increment`;
     - validation path: `ohpm install`, `hvigorw --mode module -p module=entry@default assembleHap`, HDC install/start, `uitest dumpLayout`, and `uitest screenCap`.
   - when validating a standalone Harmony embedded HTTP runtime before it is connected through `triton serve`, use direct runtime checks:
     - `triton device runtime-url --platform harmony --target <hdc-target> --probe-manifest --json` to prepare HDC fport and get the `baseURL`;
     - the Harmony demo host-access embedded runtime default is `http://127.0.0.1:28767`; `18765` is reserved for the demo device-to-host gateway fallback path;
     - `triton runtime manifest --runtime-base-url http://127.0.0.1:<port> --json`;
     - `triton state route --runtime-base-url http://127.0.0.1:<port> --json`;
     - `triton snapshot --runtime-base-url http://127.0.0.1:<port> --json`;
     - `triton ledger --runtime-base-url http://127.0.0.1:<port> --jsonl`;
     - `triton set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:<port> --json` when an app action provider is registered.
10. Run observation before action:
   - prefer one-shot regression capture when a full report is needed: `triton capture --case <case> --output /tmp/<case>.tritonevidence --json`.
   - prefer one-shot evidence when a report or issue needs attachable proof: `triton evidence --name <case> --output /tmp/<case>.tritonevidence --json`.
   - inspect an existing bundle without reconnecting runtime: `triton evidence inspect /tmp/<case>.tritonevidence --json`.
   - summarize evidence before public handoff: `triton evidence summary /tmp/<case>.tritonevidence --json`.
   - write a safe handoff bundle: `triton evidence redact /tmp/<case>.tritonevidence --profile ios-private --output /tmp/<case>-redacted.tritonevidence --json`.
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
   - when `tap` or `assert` fails, read nearest candidates / nearestText and suggestedCommands from the JSON envelope before changing the test flow;
   - keep `triton type --text <text>` only for compatibility with older scripts, never together with positional `<text>`;
   - keep `triton press --button <button>` only for compatibility with older scripts; prefer positional `triton press <button>`;
   - for batch input, use `triton input --json --summary --strict`;
   - after taps, submissions, and navigation, use `triton wait --text`, `triton wait --gone`, `triton wait --idle`, or a safe `triton wait --predicate` instead of fixed sleeps;
   - use `triton assert text-exists|text-not-exists <text> --json` for final pass/fail checks; add `--within x,y,width,height`, `--role`, or `--count` when labels repeat across headers, sidebars, and cells;
   - assert expected state through `wait`, a second `ax`, `find`, `screenshot`, archive check, or a fresh `evidence` bundle.
12. Store outputs under `/tmp` during iteration, then copy only durable screenshots or docs into the correct `docs-linhay/spaces/<space-key>/` location when the result is worth keeping.
13. Before sharing evidence outside the real app repo, sanitize project and personal information:
   - replace private project names, app names, bundle IDs, team IDs, organization names, user names, account IDs, email addresses, phone numbers, local usernames, internal domains, and absolute private paths with stable placeholders;
   - keep platform/tool versions, TritonKit version, command names, error codes, redacted route shape, and minimal sanitized snippets needed for reproduction;
   - do not attach full private logs, screenshots with personal data, unredacted `.tritonevidence`, `.tritonplan`, `.xcresult`, HDC/Simulator dumps, app archives, or credentials.
14. If the real app exposes a missing TritonKit capability, unclear behavior, or bug, use `tritonkit-dev-feedback` and file/prepare the GitHub issue directly after redaction.

## Real-Project Smoke Issue Closure

Use this checklist before commenting on or closing a real-project smoke issue such as iOS one-command smoke, Xcode occupancy diagnostics, WebView route checks, Harmony host-side smoke, or simulator takeover slices.

1. Confirm the implementation is on `main` and pushed to `origin/main`; reference the exact commit hash in the issue comment or session notes.
2. Confirm the relevant CLI schema exposes the capability, for example `triton schema --command smoke --json`, `triton schema --command xcode --json`, `triton schema --command app --json`, or `triton schema --command webview --json`.
3. Run the narrow unit or mock tests that own the orchestration and error shape.
4. Run at least one structured host/runtime verification that exercises the user-facing command. For iOS one-command smoke this means `triton smoke ios ... --json`; for open-url readiness it means `triton app open-url <url> --wait-ready --snapshot --json`; for Harmony host smoke this means the HDC-backed `device/app/ax/wait/screenshot` chain or `smoke harmony` when available.
5. Treat host action acknowledgements as submission evidence only. `simctl openurl`, HDC `aa start`, `xcode run`, tap, launch, or install success does not close a business smoke issue until a later `wait`, `assert`, snapshot, screenshot, or evidence result proves the expected app state.
6. Attach or summarize evidence after redaction. Public comments must avoid real app names, bundle IDs, team IDs, private paths, screenshots with personal data, full logs, credentials, and unredacted `.tritonevidence`, `.xcresult`, or HDC/Simulator dumps.
7. Update the owning `docs-linhay/spaces/<space-key>/README.md` or technical note with the current state, including which issues are still open.
8. Write memory for the decision, closure criteria, residual risks, and follow-up issues.
9. Run docs/skill sync for pure documentation closures, or the full relevant test gate for code closures.
10. Only close the issue once the issue-specific closure criteria are met. Keep epics such as simulator takeover open unless the scoped P0/P1 acceptance criteria are satisfied and remaining advanced scope has been split into follow-up issues or explicitly deferred in the closure comment.

Do not collapse multiple open issues into a single closure comment just because they share an orchestration layer. A shared implementation can close one issue and leave related issue slices open.

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

## Harmony App Integration Guide

Use this shape when the real app needs Harmony / DevEco validation.

Host-side Harmony checks do not require any app package dependency:

```bash
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device wait-ready --platform harmony --target <hdc-target> --json
triton app inspect --platform harmony --bundle <bundle> --target <hdc-target> --json
triton app install --platform harmony --hap <debug-signed.hap> --target <hdc-target> --json
triton app launch --platform harmony --bundle <bundle> --ability <ability> --target <hdc-target> --json
triton app open-url --platform harmony --bundle <bundle> --ability <ability> '<url>' --target <hdc-target> --json
triton ax --platform harmony --target <hdc-target> --output /tmp/<case>-layout.json --json
triton wait --platform harmony --target <hdc-target> --text '<text>' --timeout 15 --json
triton tap '<text>' --platform harmony --target <hdc-target> --json
triton screenshot --platform harmony --target <hdc-target> --output /tmp/<case>.jpeg --json
triton smoke harmony --target <hdc-target> --bundle <bundle> --ability <ability> --open-url '<url>' --wait-text '<text>' --screenshot /tmp/<case>.jpeg --evidence /tmp/<case>.tritonevidence --json
```

When multiple HDC targets are `Connected`, pass `--target`; `ambiguous_target` is the expected machine-readable failure.
Host-side layout and screenshot artifacts may contain private UI data; inspect or summarize them before attaching evidence to public issues.

For Harmony embedded SDK work, keep the TritonKit brand separate from the OHPM package id. The actual package id and ArkTS import path are lowercase:

```text
tritonkit
```

Until the Harmony package is published, use the aligned `harmony-TritonKit` source/HAR for validation. Keep the app integration Debug-only. Release builds must compile to disabled/no-op behavior and must not collect UI, screenshots, logs, route state, or action data.

Business semantics are not generic HAR capabilities. Route, responder, and semantic action state should come from app provider hooks. If providers are not registered, `unsupported_runtime_scope` is the correct runtime result; if the manifest marks those capabilities supported without providers, file a bug.

For a standalone Harmony embedded runtime before it is connected through `triton serve`, use direct runtime checks:

```bash
triton device runtime-url --platform harmony --target <hdc-target> --probe-manifest --json
triton runtime manifest --runtime-base-url http://127.0.0.1:28767 --json
triton state route --runtime-base-url http://127.0.0.1:28767 --json
triton snapshot --runtime-base-url http://127.0.0.1:28767 --json
triton ledger --runtime-base-url http://127.0.0.1:28767 --jsonl
triton set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:28767 --json
```

For the Harmony demo, `28767` is the host-access embedded runtime port exposed through HDC `fport`; `18765` is only the demo device-to-host gateway fallback port.

## CLI Install Contract

Use Homebrew for real-project adoption checks by default:

```bash
brew install NeptuneKit/tap/triton
brew update
brew upgrade triton
```

Use the local release CLI only while TritonKit is pre-release, while validating unreleased source changes, or when Homebrew / GitHub Release assets are unavailable:

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

Homebrew installs only the macOS CLI. The app-side embedded runtime still comes from SwiftPM or CocoaPods and must remain DEBUG-only.

Release assets live in `NeptuneKit/TritonKit` GitHub Releases and include arm64/x86_64 CLI archives plus `tritonkit_checksums.txt`. The Homebrew tap is updated from those release assets after `v*` tag releases. If the release or tap is unavailable in a test environment, do not fail the regression setup on Homebrew; use the local release CLI and file a TritonKit issue with the missing distribution evidence.

## Boundaries

- Do not commit or revert real app repo changes unless the user explicitly asks.
- Do not publish real app identity, private bundle IDs, personal accounts, user names, emails, internal hosts, absolute private paths, or unredacted evidence in TritonKit issues.
- Inspect evidence manifests, screenshot pixels, and artifact filenames before attaching them to public issues. If redaction cannot be verified, summarize the evidence instead.
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

# iOS Runtime Capability Gating

## Background

TritonKit iOS embedded runtime currently exposes a `TritonKit.Configuration.features` field, but the request handling path does not consistently use it to enable or disable app-process capabilities. Adopting apps need one stable `TritonKit` package product while still being able to opt in to only the runtime capabilities they need.

This space keeps the external package boundary unchanged: app integrators continue to add only the `TritonKit` product. The first implementation slice focuses on runtime gating and machine-readable manifest output, not public SwiftPM product fragmentation.

## Goals

- Let app bootstrap code enable a bounded set of iOS embedded runtime capabilities.
- Keep unsupported and disabled capabilities distinguishable in CLI/runtime JSON.
- Preserve the single public `TritonKit` product for SwiftPM and CocoaPods users.
- Make disabled capabilities fail with stable machine-readable errors instead of silently collecting or acting.

## Non-Goals

- Do not expose new public package products such as `TritonKitObserve`, `TritonKitInput`, or `TritonKitWebView` in this slice.
- Do not change the Debug-only / Release no-op boundary.
- Do not add Web/Wails product UI.
- Do not expand host-side simulator HID or system alert control.

## Capability Groups

- `runtime-core`: connection, lifecycle, manifest, state/error observation, ledger.
- `observe`: app, scene, route, responder, hierarchy, accessibility, geometry, hit-test, screenshot metadata, media snapshot.
- `input`: tap, swipe, type, paste, clear, delete backward, semantic focus/text/segment/switch actions.
- `webview`: WKWebView discovery, current URL, snapshot, wait, events, allowlisted bridge calls, focused DOM input.
- `semantic`: app-owned semantic state providers and provider catalog metadata.

## BDD Scenarios

### Scenario 1: App disables input

Given an iOS Debug app starts TritonKit with observation enabled and input disabled
When the CLI requests a tap, text input, or semantic text action
Then the runtime returns a JSON error with `code=capability_disabled`
And the runtime does not execute the action.

### Scenario 2: App disables WebView

Given an iOS Debug app starts TritonKit without WebView capability
When the CLI requests `webview.list`, `webview.current`, `webview.snapshot`, `webview.call`, `webview.events`, or `webview.wait`
Then the runtime returns `code=capability_disabled`
And the manifest marks WebView capabilities as supported but disabled.

### Scenario 3: Manifest explains enabled state

Given TritonKit starts with a subset of capabilities
When the CLI reads `runtime manifest --json`
Then each advertised runtime capability includes `supported`, `enabled`, and a reason when disabled
And unsupported host/system capabilities remain unsupported rather than disabled.

### Scenario 4: Existing integrations stay source-compatible

Given an app uses the current `config.features = [...]` API
When it builds against this slice
Then the API still compiles
And the feature set maps to the new runtime capability gates.

## Acceptance

- Focused tests cover disabled input, disabled WebView, disabled semantic provider visibility, and manifest enabled state.
- Release no-op behavior remains unchanged.
- README documents single-product package entry and runtime capability gating.
- `docs-linhay/memory/2026-06-18.md` records the decision and verification.

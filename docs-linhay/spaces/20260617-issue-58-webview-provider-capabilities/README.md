# Issue 58: WebView Provider Capabilities

## Background

`triton webview current-url` and `triton webview snapshot --include metadata,text,dom` can already observe an iOS `WKWebView` through the embedded DEBUG runtime provider. Agents still cannot reliably tell whether the current provider supports current URL, snapshot, bridge calls, page events, DOM input, or contenteditable typing, and unsupported paths do not consistently explain recovery.

Issue: https://github.com/NeptuneKit/TritonKit/issues/58

## Goal

Expose provider-level WebView capability status in machine-readable CLI/HTTP contracts so agents can choose the correct next command or stop at a linked-validation path when a capability is out of scope.

## Scope

- Add focused WebView capability details to iOS provider descriptors returned by `webview current`, provider-backed `webview list`, and `webview snapshot`.
- Preserve existing `capabilities` and `missingCapabilities` arrays for compatibility.
- Add stable unsupported reason and next action data for bridge calls, page events, DOM input, and contenteditable typing.
- Keep CLI/HTTP as the product surface. No Web or Wails UI changes.
- Document DOM input as out of scope unless a supported provider path exists; recommended recovery is linked validation through URL, snapshot, wait, route assertions, or app-level semantic actions.

## Out Of Scope

- Implementing arbitrary DOM input, contenteditable typing, or generic JavaScript eval.
- Adding Web/Wails screens.
- Changing Android or Harmony provider behavior beyond preserving existing unsupported envelopes.
- Running qmd-sync or memory integration in this worker worktree.

## BDD Scenarios

### Scenario: Agent reads iOS provider capability detail

Given an iOS WebView provider descriptor is returned by the embedded runtime
When an agent reads `webview current --json` or the `webView` field in `webview snapshot --json`
Then the descriptor includes structured provider capabilities for current URL, snapshot, bridge call, events, DOM input, and contenteditable typing
And each capability has `supported`, `reason`, and `nextAction` fields stable enough for machine parsing.

### Scenario: Unsupported bridge method explains recovery

Given an iOS WebView bridge call reaches a page without an allowlisted bridge method
When `triton webview call <method> --json` returns `webview_method_not_allowed`
Then the error includes a stable recovery suggestion to expose the method through `window.__tritonBridge.methods` or fall back to snapshot/wait/route validation.

### Scenario: DOM input remains an explicit boundary

Given a provider descriptor is available
When an agent inspects DOM input or contenteditable typing capability
Then the capability is marked unsupported with a reason and next action that points to linked validation rather than pretending native DOM typing is available.

## Test Plan

- Add shared DTO tests proving WebView descriptor capability detail round-trips through JSON and legacy descriptors still decode.
- Add runtime provider tests proving iOS provider defaults include supported current URL/snapshot/events and unsupported DOM input/contenteditable with stable next action.
- Add bridge error script tests proving `webview_method_not_allowed` includes a recovery hint.
- Run focused Swift tests for WebView shared/runtime models.

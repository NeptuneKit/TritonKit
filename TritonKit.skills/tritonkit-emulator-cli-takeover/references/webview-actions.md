# WebView-Aware Actions

Use this reference when native AX / host hit-testing only reaches the `WKWebView` container and cannot identify H5 controls.

## Agent Surface

Keep the primary agent-facing action on `triton act tap`, not a low-level `webview click` command:

```bash
triton act tap --webview-aware --selector <css> --webview-id <id> --page-session-id <id> --expect-text <text> --json
```

The runtime action is `webview.tap`, but the CLI output is an action envelope with:

- `status=passed|failed|uncertain`
- `trusted=false` for DOM-dispatched click
- source command suitable for agent replay
- recovery command for native coordinate tap or WebView snapshot/wait

## Verification Semantics

- DOM click is not trusted HID input. Do not claim business success from dispatch alone.
- Without `--expect-text` or another explicit verification, return `uncertain`.
- With `--expect-text`, call WebView wait after the tap and return `passed` only when it matches.
- Return `failed` for element-not-found, not-interactable, provider unavailable, or verification miss.

## Disambiguation

Use `--webview-id` when multiple WebView candidates exist.

Use `--page-session-id` when reloads or navigations can stale a selector.

## Boundaries

Do not fold these into the first WebView-aware tap slice unless the current space explicitly updates scope and tests:

- `expect-request`
- CDP / remote debugging
- arbitrary JavaScript eval
- trusted HID synthesis
- Web or Wails UI control surfaces

## Required Contract Updates

When changing this lane, update together:

- shared request/response DTOs
- embedded runtime route mapping
- runtime capability gate and manifest capability
- CLI `act tap` parser and output contract
- schema `act` options, failure codes, examples, and provided capabilities
- focused tests for shared models, runtime script, CLI parser, schema, and capability matrix

# iOS embedded runtime evidence

Use this for iOS app-process runtime feedback: hierarchy, snapshot, state, AX, input, WebView, media playback, semantic providers, runtime target routing, and Xcode-run readiness.

## Baseline

Prefer released CLI through Homebrew. Use a local source build only when the finding depends on unreleased code.

```bash
triton version --json
triton status --json
triton list --json
triton debug runtime manifest --json
```

When multiple iOS Simulator apps connect to the same server, `triton list --json` should expose targets like `triton:ios-simulator:<SIMULATOR_UDID>` with `simulatorUDID`. Commands should fail with `ambiguous_target` instead of silently choosing `triton:local`.

## Observation evidence

Use the narrow command that matches the symptom:

```bash
triton debug hierarchy --json
triton debug ax --json
triton debug snapshot --include app,scene,route,ax,geometry --json
triton debug snapshot --include media,ax,screenshot-metadata --json
triton debug snapshot --include semantic,app,scene --json
triton debug state app --json
triton debug state scene --json
triton debug state route --json
triton debug state responder --json
triton debug ledger --limit 50 --jsonl
```

For an embedded runtime screenshot, always use a `.png` output and inspect both metadata and magic bytes. A successful current runtime returns `format=png` with `89 50 4e 47 0d 0a 1a 0a`; `artifact_write_failed` means the runtime metadata, bytes, or output extension disagreed, and Triton intentionally did not publish the artifact. Do not rename JPEG bytes to `.png` or attach a mismatched artifact to evidence.

For media reports, preserve `media.surfaces[]`, `media.controls[]`, `automationConfidence`, `fallbackAdvice[]`, and `evidenceCommands[]`. If confidence is `surface-only`, report the missing controllable surface and recommend app-owned DEBUG overlay controls rather than claiming pause/resume/seek proof.

For semantic reports, preserve provider-backed `semantic.domains[]`, `source`, `confidence`, `state`, `schema`, `actions`, `redaction`, and `evidenceCommands[]`. Do not report generic provider action execution as implemented until a dedicated command contract exists.

## Action evidence

```bash
triton act find "<text>" --all --json
triton act tap "<text>" --json
triton act tap "<text>" --at x,y --json
triton act tap "<text>" --index <n> --json
triton act tap "<text>" --within x,y,width,height --json
triton act swipe --target <ios-runtime-target-from-triton-list> --start-x 110 --start-y 700 --end-x 110 --end-y 140 --duration 0.6 --json
triton act focus "<label>" --json
triton act set-text "<label>" "<value>" --json
triton act set-text "<label>" "$SECRET" --secure --json
triton act select-segment "<label>" "<segment>" --json
triton act set-switch "<label>" on --json
triton verify text-exists "<text>" --json
triton verify text-not-exists "<text>" --json
```

When `tap` or `verify` fails, preserve candidate count, nearest candidates / nearestText, error code, and `suggestedCommands[]`.

For a `UIButton` primary-action menu on iOS 17.4+, expect the button tap to return `strategy=button-primary-menu-action`, then prove that the menu opened with `triton verify text-exists "<menu-action-title>" --json`. Do not report a presented `UIAction` as selected through the embedded runtime: direct item selection has no safe public embedded API and returns one failed input result with `error.code=unsupported_capability` and `strategy=button-primary-menu-item-unsupported`. Use host HID or an app-owned semantic DEBUG action when selection is required.

Treat a presented `UIAlertController` action as a modal boundary. A safe public accessibility activation returns `strategy=alert-action-accessibility-activate`; otherwise expect one `unsupported_capability` result with `strategy=alert-action-unsupported`. Never interpret a collection/table selection behind the alert as successful alert handling, and verify the alert is gone or the expected postcondition is visible.

For an embedded `UITableViewCell` match, `strategy=ancestor-table-cell-selection` now means Triton honored `willSelectRowAt`, selected the resolved row, and invoked `didSelectRowAt` before returning. Preserve the success message and then verify the delegate's visible business postcondition; do not treat row selection state alone as proof when the delegate starts asynchronous work.

## WebView evidence

```bash
triton webview list --platform ios --json
triton webview current --platform ios --json
triton webview current-url --platform ios --json
triton route assert-current-url "<expected-url>" --platform ios --json
triton webview call <method> --platform ios --json
triton webview events --platform ios --limit 50 --json
```

Read `primarySource` first. Priority is `webview-provider`, then `runtime-tree`, then `host-layout`. URL assertions require provider URL metadata. Bridge calls require a page or app opt-in allowlist and must not be reported as arbitrary JavaScript eval.

## Evidence bundles and replay

```bash
triton evidence capture --case <case> --output /tmp/<case>.tritonevidence --json
triton evidence summary /tmp/<case>.tritonevidence --json
triton evidence inspect /tmp/<case>.tritonevidence --json
triton evidence redact /tmp/<case>.tritonevidence --profile ios-private --output /tmp/<case>-redacted.tritonevidence --json
triton record --output /tmp/<case>.tritonplan --json
triton plan inspect /tmp/<case>.tritonplan --json
triton replay /tmp/<case>.tritonplan --dry-run --json
```

Read `primaryArtifacts[]` before scanning every artifact. For replay failures, preserve `recoveryProposal`, `failedStepIndex`, `failureCode`, `failureError`, `failureWorkflowCategories[]`, `failureRecoveryCategories[]`, `failurePrimaryArtifacts[]`, `recoveryCommands[]`, `suggestedCommands[]`, and the failed step error payload.

## Xcode workflow evidence

Prefer Triton Xcode commands before XcodeBuildMCP or raw `xcodebuild`:

```bash
triton schema --command xcode --json
triton xcode discover --path . --json
triton xcode build --jsonl --timeout <seconds>
triton xcode test --result-bundle /tmp/<case>.xcresult --jsonl
triton xcresult summary --path /tmp/<case>.xcresult --json
triton xcresult failures --path /tmp/<case>.xcresult --json
```

For temporary Xcode dependency diagnosis, `xcode settings/build/test/run` accepts repeatable `--build-setting KEY=VALUE`. Preserve the resulting `sourceCommand` as evidence that argument boundaries were retained; values are intentionally auditable, so do not use this option for secrets.

If fallback is required, include the missing schema/capability evidence and the fallback command. State whether build/install/launch completed and whether runtime status/wait/assert/screenshot/evidence proved app readiness.

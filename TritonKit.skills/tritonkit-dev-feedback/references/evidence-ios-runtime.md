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

For media reports, preserve `media.surfaces[]`, `media.controls[]`, `automationConfidence`, `fallbackAdvice[]`, and `evidenceCommands[]`. If confidence is `surface-only`, report the missing controllable surface and recommend app-owned DEBUG overlay controls rather than claiming pause/resume/seek proof.

For semantic reports, preserve provider-backed `semantic.domains[]`, `source`, `confidence`, `state`, `schema`, `actions`, `redaction`, and `evidenceCommands[]`. Do not report generic provider action execution as implemented until a dedicated command contract exists.

## Action evidence

```bash
triton act find "<text>" --all --json
triton act tap "<text>" --json
triton act tap "<text>" --at x,y --json
triton act tap "<text>" --index <n> --json
triton act tap "<text>" --within x,y,width,height --json
triton act focus "<label>" --json
triton act set-text "<label>" "<value>" --json
triton act set-text "<label>" "$SECRET" --secure --json
triton act select-segment "<label>" "<segment>" --json
triton act set-switch "<label>" on --json
triton verify text-exists "<text>" --json
triton verify text-not-exists "<text>" --json
```

When `tap` or `verify` fails, preserve candidate count, nearest candidates / nearestText, error code, and `suggestedCommands[]`.

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

Read `primaryArtifacts[]` before scanning every artifact. For replay failures, preserve `failedStepIndex`, `failureCode`, `failureError`, `failureWorkflowCategories[]`, `failureRecoveryCategories[]`, `failurePrimaryArtifacts[]`, `recoveryCommands[]`, `suggestedCommands[]`, and the failed step error payload.

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

If fallback is required, include the missing schema/capability evidence and the fallback command. State whether build/install/launch completed and whether runtime status/wait/assert/screenshot/evidence proved app readiness.

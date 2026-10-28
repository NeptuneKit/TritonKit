# GitHub issue reply drafts — 2026-10-28

These 13 replies are **unsent drafts**. No issue has been closed by this document. New implementation candidates are local and unpublished; the integrated local validation has passed; original-device gaps remain. Before posting, the controller must reconcile each draft with the [final validation record](20261028-validation.md), fill in an actual published version or commit only if available, and retain all unresolved acceptance limits. The linked record contains the executed checks, evidence boundaries and remaining risks.

## #214 — DerivedData usage and cleanup

The proposed disposition is **not planned for general automatic cache deletion**. This is a scope decision, not a claim that race-safe deletion has been implemented.

The v0.2.25 safety mitigation remains: inspect and cleanup preview are read-only. Confirmed cleanup returns `xcode_not_idle` when build activity is present or unknown, and `derived_data_cleanup_unavailable` even when idle. Waiting for idle does not enable deletion. Since v0.2.26, ordinary Xcode builds use Xcode's default user-level DerivedData; an explicit `--derived-data-path` remains available for deliberate isolation. Existing caches are not removed by that change.

The later scope decision cancelled general automatic deletion, superseding the earlier comment's plan for a general exclusive-ownership/deletion protocol. External Xcode builds do not participate in Triton's lock, so process snapshots cannot establish safe exclusion. Any future Triton-owned cache lifecycle needs its own scope and acceptance criteria.

We still cannot identify which versions or invocations produced the original directories, prove duplicate contents, or establish reclaimable physical space from logical bytes and modification times. No real cache was deleted in this review. This batch contains a local documentation/audit candidate only; its integrated documentation checks have passed. Closing as not planned would retain the supported inspection capabilities and would not represent deletion as completed.

## #221 — Focused UISearchBarTextField resolves to its wrapper

A local candidate changes unqualified input resolution to keep an already-focused `UIKeyInput` owner before traversing its internal field editor, while traversing non-input parents that forward `isFirstResponder`. The selected view must still report actual focus: a merely typeable child or an unfocused search field is not selected, and the operation does not acquire focus automatically. Explicit target selection and the foreground/modal checks remain in place.

The intended result is that a focused search field receives the subsequent `type` action instead of resolving to its `UISearchBar` wrapper. Regression cases cover a forwarding container, a standard search bar, another focused field and no focused field.

The candidate is local and unpublished. All 7 App-hosted UIKit tests for this issue and #223 passed on iOS 27.0 / Xcode 27.1, including public input-owner identity and unfocused-field protection. The original reported application/session has not been reproduced.

## #222 — Device Hub chrome lookup and input authority

The original chrome lookup dependency and input-authority ambiguity were addressed in **v0.2.33**, including implementation commit `c0ce0cc2` and release tag `e2b1d959`. Tap/swipe use the bundled isolated native digitizer. `act tap --hid-only` enforces the coordinate HID path; explicit `--platform ios` otherwise retains AX semantics. Device Hub guest ownership and unknown geometry still refuse input with typed failures. The display query uses the observed `devicectl device info displays` contract.

The existing release evidence records a dedicated Xcode 27.1 / iOS 27.0 Simulator acceptance covering tap business counters, swipe postconditions, Hub-attached refusal/recovery and Triton framebuffer capture. These are historical acceptance results, not new device runs from this batch.

This does not claim general Device Hub physical-device control, automatic system-alert handling, or support for host multi-tap/long-press. The specific system-alert path from the comments was not part of that acceptance, and embedded app trees cannot establish what is covering the app at system level. Other toolchains and the original private project remain unverified. Remaining target-specific display diagnostic guidance is being addressed by the unpublished candidate for #224. The present #222 batch work is an unsent audit/reply draft, not another released fix.

## #223 — Target/action UIBarButtonItem inside a page sheet

A local candidate implements the typed-refusal option allowed by this issue. When a navigation/toolbar view has neither a usable public UIControl action nor successful public `accessibilityActivate`, the response now reports `unsupported_capability` with strategy `bar-button-action-unsupported` and recovery guidance. It does **not** claim general support for activating all UIBarButtonItem target/actions.

UIKit does not provide a public mapping from the generated view back to its bar item. The candidate therefore does not guess by title, use private KVC, or search behind the presented sheet for an action. Existing public control/accessibility activation remains supported. Recovery points to an explicit Simulator target with fresh coordinates for host input, or an already-ready, allowlisted Runner/manual interaction on a physical device. Host acknowledgement still requires a separate business-state check; a Device Hub/HID refusal is not bypassed.

The candidate is local and unpublished. Four App-hosted UIKit cases passed, including a real page sheet with a target/action navigation button and a same-title background control that remained untouched. The original private application still needs its own business-state check.

## #224 — Resize/display query failures and unusable doctor guidance

A local candidate makes `device doctor --platform ios --scope simulator --device sim:<UUID> --json` report separate, target-bound appResize and display-topology states and unknown reasons under `simulatorDiagnostics`. Omitting `--device` does not add geometry queries. Tool-level `ok` and capability names are explicitly separate from `captureVerified` and `inputDispatchVerified`, which remain false for these read-only snapshots.

The candidate also preserves the typed `ios_simulator_display_safety_unknown` failure instead of wrapping that error as generic `host_action_failed`, and binds screenshot/AX/HID recovery guidance to the selected Simulator. The probes do not grant permission for a later action; actions still perform their own fresh checks. Unknown resize/display state remains a refusal, with no silent framebuffer or input fallback.

The Xcode 27.1 display-query compatibility fix already shipped in v0.2.33. The new local candidate passed the complete CLI suite and a real Simulator doctor invocation that returned separate resize/display diagnostics while keeping capture/input verification false. Xcode 26.6 and the original application environment remain unverified; this closes the diagnostic gap without claiming the old toolchain failure has been reproduced and fixed.

## #225 — Runner readiness hides early XCTest transport failure

A local candidate separates Runner startup evidence into native launch, transport, health and UI automation stages. A recognized XCTest driver-channel refusal can now end readiness polling with a bounded, sanitized diagnostic instead of only the generic unlock/readiness advice. Native launch failure and early process exit are distinguished, while successful health evidence is retained if UI automation readiness remains unproven.

Classification reads a bounded tail from this session's native output files, refuses symlinks/non-regular files, and does not expose raw logs, local paths or credentials. Unknown or unreadable evidence stays a conservative readiness failure; it is not assigned an invented root cause. This does not imply that unlocking alone fixes the condition or that Apple tooling has been proven defective.

The candidate is local and unpublished. Startup-stage, bounded log-signature and failure-envelope fixtures passed in the complete CLI suite. The original physical iOS/Xcode combination has not been rerun; native XCTest success does not by itself prove resident Runner readiness.

## #226 — Dash-prefixed real-device launch arguments

A local candidate inserts `--` immediately after the bundle identifier when an iOS real-device launch contains app arguments. Leading dashes, dictionary-like values and multiple arguments remain opaque argv values in their original order. Environment forwarding is retained, and launches without app arguments keep the prior argv shape.

This addresses the command-construction boundary where devicectl could interpret an app argument as one of its own options. It does not change Simulator launch or retry a failed launch through another backend.

The candidate is local and unpublished. The command-builder regression failed with the old implementation and passed after restoration of the fix (42 shared host-adapter tests); the complete integrated CLI suite also passed. The original physical-device launch has not been executed here.

## #227 — Android build severity and timeout duration

A local candidate classifies Android diagnostics using structured severity markers rather than incidental occurrences of “error”. Gradle task names are not compiler errors; Kotlin `w:` remains a warning even if its message contains “error”, while `e:` and explicit source-location diagnostics retain their severity. A Gradle failure banner is recognized without counting the accompanying headings/footer repeatedly.

The timeout summary now uses measured monotonic elapsed time, including process cleanup, instead of reporting zero duration. Timeout remains a failed build with no installable-artifact claim, even when the captured log contains no compiler errors. Counts still describe the bounded log sample, not necessarily the complete compiler output.

The candidate is local and unpublished. An isolated CLI comparison reproduced version 0.2.33 reporting two errors, zero warnings and duration zero; the candidate reported zero errors, one warning and 2058 ms for the same timeout fixture. The complete CLI suite passed. The private Android project has not been rebuilt, so this does not establish the cause of its slow compilation.

## #228 — Android readiness before boot/provider availability

A local candidate requires adb connectivity, `sys.boot_completed=1` and a successful PackageManager probe before wait-ready reports readiness. A package path appearing before boot completion is insufficient. The receipt retains the individual probe provenance instead of equating `pm path android` with full boot readiness.

The screenshot error mapping is also narrowed: a remote shared-storage/capture failure is reported as `android_screenshot_failed`, not a missing adb executable. A genuine host-side inability to locate adb remains `android_adb_not_found`.

The candidate is local and unpublished. A fake-adb CLI comparison reproduced version 0.2.33 reporting ready while boot completion was zero; the candidate returned device_not_ready. The complete CLI suite passed. This is sampled readiness, not an atomic guarantee of later install or business readiness. The original Android 14 cold boot under memory pressure and subsequent APK install remain unverified.

## #229 — Stale UIAutomator XML reported as current

A local candidate gives each hierarchy capture a unique remote dump path and requires both a successful dump response for that exact path and a usable newly read XML hierarchy. Exit status zero accompanied by an ERROR/null-root message is rejected as `hierarchy_unavailable`; the previous shared dump is not read or stamped with a fresh successful capture time.

Observation and coordinate-target resolution share this fresh-capture path. Missing, empty, truncated or invalid/no-node XML is rejected. Cleanup is best effort and addresses only the current capture's path; its command ledger records an attempt, not proof of deletion. No gesture is automatically replayed after a hierarchy failure.

The candidate is local and unpublished. The same isolated fake-adb scenario made version 0.2.33 return a stale node after null-root; the candidate returned hierarchy_unavailable and no stale node. The complete CLI suite passed. The original loaded emulator and display-size mismatch have not been reproduced on a real device.

## #230 — Runner inspect/screenshot blocked by coordinate geometry

The local investigation found that inspect and screenshot unconditionally depended on the same app-frame/orientation geometry validation used for coordinate actions. A local candidate separates observation availability from permission to use coordinates. With a verified foreground app and a valid frame but unknown orientation, inspection/screenshot may return partial observation/PNG evidence with `coordinateActionsAvailable=false`, without usable coordinate geometry or an observation ID. Previous coordinate observations are invalidated rather than reused.

The candidate keeps allowlist, foreground, valid-frame and freshness checks. Missing/invalid app frame or a nonforeground app produces an actionable refusal. It does not guess orientation from aspect ratio, change device orientation, or automatically dismiss permissions/system alerts. `appAlertPresent` covers the queried app's alerts only; `systemAlertDetection=not-probed` explicitly avoids claiming comprehensive interruption detection.

The candidate is local and unpublished. The 32 protocol tests, complete CLI suite and a real Simulator XCTest for unknown orientation passed, including observation/screenshot availability and rejection of old coordinate IDs. This uses an injected unknown orientation; the exact failed field and ready → activate → observe path on the original physical device remain unverified. No cause is attributed to a permission alert without evidence.

## #231 — Preserve partial Simulator log artifacts

A local candidate writes `sim logs` stdout incrementally to an exclusively created, owner-only artifact with a bounded byte limit. Child nonzero/signal exit, timeout, incomplete drain or output truncation retains the captured prefix and returns a failure/partial envelope containing artifact path, byte counts, truncation/limit metadata and incomplete provenance. A partial capture is not reported as success, and native log bodies are not inlined into JSON.

The new `--max-bytes` limit defaults to 10 MiB. After the retained-output cap, the process output is still drained without allowing the artifact to grow. Existing files/symlinks are rejected before the child starts. This does not recover logs already lost in the original runs; an artifact may be empty or end mid-line, and incremental writes do not promise power-loss durability.

The candidate is local and unpublished. Fake-process tests passed, and a dedicated real Simulator capture was also tested: killing only the owned log child returned a single failure/partial JSON, retained 607402 bytes in a 0600 artifact, and reported matching byte counts. The Simulator was then shut down successfully. Hour-long capture and recovery of already-lost historical logs have not been tested or claimed.

## #232 — Wired iOS backend selection

A local documentation/schema candidate now explains the selection policy per operation: real-device scope selects the chosen Xcode's public `devicectl` / CoreDevice route with fresh file JSON and exact identity binding; USB is transport metadata, not a trigger to switch backend. Missing transport remains unknown. Apple DeviceHub.app is not an automatic GUI/private-protocol fallback, and Triton's read-only Web Device Hub is a separate interface.

The operation matrix maps actual fields instead of claiming every response has a uniform source/strategy/transport/verification DTO. It distinguishes inventory eligibility, host acknowledgement, Runner/runtime readiness and business verification. It also documents exceptions explicitly: physical system-log sampling uses optional `idevicesyslog` with a verified USB identity alias, while XCTest Runner and embedded runtime are separate explicit surfaces.

A future physical-device Device Hub adapter would require a supported API/toolchain matrix, exact identity mapping, explicit selection, readiness/capability and ownership evidence, fresh geometry where relevant, typed delivery/failure semantics and independent postconditions. Unsupported or uncertain delivery would not authorize automatic replay or backend switching.

The local documentation/schema candidate passed the complete CLI contract suite and documentation checks. It introduces no new Device Hub backend and claims no new USB or physical-device acceptance. Capability-specific evidence remains separate from general Device Hub control.

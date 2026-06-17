# Issue #59: iOS Tap and Capture Target Fix

## Background

Issue #59 reports two iOS automation gaps:

1. `triton tap` can fail on a visible `UIButton` when the embedded runtime finds a `UIControl` but the control does not expose `.primaryActionTriggered` or `.touchUpInside` target/action metadata. A visible, enabled button should have a reliable public UIKit tap path where possible, or return a clear diagnostic that tells the caller which fallback is required.
2. `triton capture --target <id>` resolves the top-level target correctly, but nested collectors such as hierarchy, AX, screenshot, geometry, and archive still use the default `triton:local` target. In multi-target sessions, those nested calls can be skipped as `ambiguous_target`.

TritonKit should keep the product contract at the CLI/embedded-runtime boundary. This work must not introduce raw `xcrun`, SimulatorKit HID, or host-only device actions as the public API.

## Scope

- Fix target propagation inside iOS capture/evidence collectors so an explicit runtime target is reused consistently.
- Add focused regression tests for `capture --target`.
- Inspect the UIKit tap path and, if the existing public UIKit boundary permits a small safe fix, make a focused change for visible enabled `UIButton` without primary/touchUpInside actions.
- If a full tap fallback needs device-level HID or a broader runtime contract, leave a machine-readable diagnostic/test coverage rather than expanding the product surface in this slice.

Out of scope:

- New host-side real HID or SimulatorKit tap implementation.
- Web/Wails UI work.
- Real-device support changes.
- qmd sync or memory integration; the main controller will handle those.

## BDD Acceptance Scenarios

### Scenario: Capture uses the explicit runtime target for every nested collector

Given two embedded runtime targets are connected
And the caller runs `triton capture --target triton:ios-simulator:SIM-1 --include hierarchy --include ax --include screenshot --include geometry --include archive`
When capture invokes each nested collector
Then every runtime request uses `triton:ios-simulator:SIM-1`
And no nested collector falls back to `triton:local`
And the evidence manifest target remains the explicit target.

### Scenario: Capture without explicit target keeps existing default behavior

Given capture is run without `--target`
When nested collectors execute
Then existing default target resolution behavior is preserved
And JSON output remains backward compatible.

### Scenario: Visible enabled UIButton without primary/touchUpInside is not a dead end

Given a visible enabled `UIButton` is selected by `triton tap`
And the button does not expose primary or touchUpInside target/actions
When the embedded runtime handles the tap request
Then it either triggers a safe public UIKit activation path
Or returns a clear diagnostic that the control lacks a dispatchable UIKit action and a coordinate/runtime fallback is required.

## Test Plan

1. Add a focused CLI runtime test proving `capture --target <id>` passes the explicit target to nested hierarchy, AX, screenshot, geometry, and archive collection calls.
2. Preserve a test for default capture target behavior where no explicit target is provided.
3. If the tap implementation changes, add a UIKit-runtime test or narrow helper test for visible enabled `UIButton` with no primary/touchUpInside action.
4. Run the smallest relevant Swift test filter first, then broaden only if needed.

## Notes

- Keep JSON fields and error codes compatible unless a new diagnostic is required.
- Do not run `docs-linhay/scripts/qmd-sync.sh` in this worker.

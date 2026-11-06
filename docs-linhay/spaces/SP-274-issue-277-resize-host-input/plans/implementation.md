# SP-274 implementation

## Failure

On `origin/main` v0.2.40 behavior, the exact target-bound CoreDeviceError 1001 fixture classified as `.unknown(.unsupportedDevice)`, then `nativeHIDGuardSnapshot` immediately threw `ios_simulator_resize_state_unknown` before checking DTUHID ownership or connected-screen geometry. This matched #277's refusal before any gesture.

## Change

`iosSimulatorResizeAllowsHostInput` distinguishes a bound capability rejection from ambiguous Resize state. Native HID continues only for `.inactive` and `.unknown(.unsupportedDevice)`; active sessions and all other unknown reasons remain fail-closed. The diagnostic state remains unknown with its native reason, and explicit primary-framebuffer routing retains its existing safe LCD-only behavior.

## Acceptance

- Focused Resize/primary-framebuffer suites: passed (33 tests, 6 suites).
- Real Simulator tap/capture: not executed; this is an out-of-scope runtime acceptance requiring a maintained device session. The fixture does not claim original user-site recovery.

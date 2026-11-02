# Device Hub feedback

Read the bundled [Device Hub contracts](../../tritonkit-emulator-cli-takeover/references/device-hub-contracts.md) for exact privacy, identity, metadata, policy and execution boundaries. Then use [issue filing](issue-filing.md).

For each finding, record the selected CLI/Xcode version, command shape with private placeholders, observed error/status, whether the backend ran, and evidence level. Separate implemented backend, real native acceptance, isolated fixture, plan-only and GUI-only. CoreDevice capability strings, catalog counts and SDK test builds do not establish physical actions or specialized input.

- Files and containers: distinguish metadata from contents, native container selection from SDK App/group binding, and Simulator traversal from physical metadata support. Preserve unsupported/policy-required/limit/mismatch errors; do not silently retry a different backend. Default opaque tokens are not authorization, and opt-in names/paths stay private.
- Administration: `--plan-only` remains valid, but pair/unpair/diagnose now also have authorized execution backends and recorded physical iOS acceptance. Report the current result rather than saying these commands are universally plan-only. A partial diagnostic archive or unknown postcondition must not be rewritten as success.
- Platform inputs: watchOS/tvOS explicit runner exists; native builds and attachment transport passed, actual input acceptance remains blocked by runtime availability. watchOS Action lacks an isolated postcondition. Preserve side-button/visionOS/macOS Device Hub unsupported boundaries.
- Temporary: possible creation and audit are part of the contract; no real query acceptance is recorded. Do not reproduce automatically as a readonly probe.
- App lifecycle: installation, native launch and independently observed process are distinct evidence; none alone proves business UI success.

Do not pair/unpair, collect diagnostics, install/launch an App, create Temporary domains or drive inputs solely to file a report. Apply the current task's explicit scope and target authorization. Before retrying any timed-out or unknown mutation, inspect independent state; do not switch targets to conceal an unfinished restore.

Keep raw device identity, group/bundle IDs, native paths, serials, IP addresses, private JSON/logs, diagnostic archives and attachment contents local. Publish only redacted facts, aggregate results and stable error codes. Past test devices and authorization are not reusable public defaults.

## Device info query boundaries

For Device Hub information, prefer `triton device info --platform ios --device <selector> --lock-state --json`. It is a readonly file-JSON snapshot, not a boot/pair/unlock operation. Report `passcodeRequired` and `unlockedSinceBoot` as distinct observed fields; do not infer screenLocked or business readiness. Preserve `not-probed` versus unknown, identity mismatch/backend failure versus success, and keep raw IDs/serials/IPs/private CoreDevice artifacts out of public feedback. A structured CoreDevice1001 getlockstate rejection maps to `unsupported_device_info_query`, not a successful snapshot or a global promise of Simulator support. Preserve that failure; querying details without the flag is a separate deliberate operation. Full Device Hub integration is a per-capability claim, not implied by a passing discovery or Simulator fixture.

## Wired iOS backend selection

USB/wired is observed transport metadata, not a backend switch: iOS real discovery and app management use the selected Xcode's public `devicectl` / CoreDevice file-JSON route. Apple DeviceHub.app is not an automatic GUI/private-protocol fallback. Preserve command-specific sourceCommand(s), tool/source, artifacts and verification fields; do not assume all outputs contain strategy/transport/verification. Missing transport remains unknown. Physical `device logs` explicitly uses optional `idevicesyslog` with a verified USB identity alias; XCTest Runner and embedded runtime remain separate explicit surfaces. Distinguish inventory eligibility, host ACK, Runner/runtime readiness and business verification. A future physical Device Hub adapter needs a supported API/version matrix, exact identity, opt-in/readiness/ownership, fresh geometry and independent evidence; unknown delivery does not authorize replay or backend switching.

# TritonKit iOS Runner

This bundled source project is built, signed, installed and started by TritonKit. It uses public XCTest and Network APIs; target applications need no embedded SDK. It is a bounded UI test session, not a permanent background daemon.

## Native project

- Project: `TritonIOSRunner.xcodeproj`
- Scheme: `TritonIOSRunner`
- UI test: `TritonIOSRunnerTests/TritonIOSRunnerTests/testServe`
- Fixture: `dev.tritonkit.runnerfixture`
- Test bundle: `dev.tritonkit.iosrunner.tests` (Runner app suffix `.xctrunner`)
- iOS deployment minimum: 17.0

The fixture is launched and both known AX identifiers are checked before the listener starts. `/health` reports network readiness only; `/probe` checks the live fixture AX and foreground state for automation readiness. A listener failure fails the XCTest method.

## Session configuration

Required `TRITON_RUNNER_TOKEN` (16...256 bytes), `TRITON_RUNNER_SESSION` (1...128 bytes); optional `TRITON_RUNNER_PORT` (default 19439), `TRITON_RUNNER_TTL` (10...3600 seconds, default 300), `TRITON_RUNNER_ALLOWED_BUNDLES` (comma-separated exact IDs, at most 32). The fixture is always allowed. Aliases `fixture`, `settings`, `calculator`, `safari` require matching `expectedBundle` and session whitelist membership. `app: "target"` accepts an explicitly whitelisted `expectedBundle`.

All requests require the v2 authenticated channel, X-Session-ID and bounded X-Request-ID. No Bearer or token is transmitted. GET `/health`; POST `/probe`, `/snapshot`, `/screenshot`, `/tap`, `/receipt`, `/home`, `/activateFixture`, `/crossApp`, `/environment`, `/stop`. Results retain one envelope `{ok,sessionID,requestID,result,error}`.

`/crossApp` accepts app, expectedBundle, operation, optional selector (`kind: identifier|label`, exact value), direction, text, limit. Operations: activate, probe, inspect, tap, typeText, scroll, home, back, screenshot, navigateExample. Inspect returns at most 40 items. Selectors must be present in the most recent observation within 30 seconds, then live, unique and hittable. Text is nonempty, at most 4096 UTF-8 bytes, and is sent only to the observed focused editable field; ambiguity is rejected. navigateExample remains a Safari-specific diagnostic for `https://example.com`.

## Budgets and evidence

UI work is serial, at most 8 pending UI requests and 8 connections. Network connections have a 20-second lifetime. Every UI route uses a session-local ledger with at most 256 immutable IDs and 32 MiB of accounted encoded receipt/fingerprint storage. Pending normal receipts reserve 512 KiB; screenshot receipts reserve 12 MiB. Completion releases unused reservation; exhausted budgets reject new requests without evicting an old ID. Oversize receipts retain a failure receipt and never rerun the action. These are encoded byte budgets, not a hard process RSS bound. A transport timeout does not cancel XCTest: query `/receipt` before deciding what happened.

Screenshots are device-screen captures with `captureScope: "device-screen"` and `postconditionVerified: false`; selected bundle metadata does not establish visible app ownership. PNG budget 8 MiB is checked after encoding. Actions return submission evidence; callers must independently check postconditions. Neither TTL nor connection timeout can interrupt a blocked XCTest call. AX return bounds do not bound XCTest's internal snapshot.

Tokens, session configuration, native logs, screenshots and receipts must remain private. The Runner does not return input text or field values, but Apple XCTest may include typed content in native action logs.

## Protocol tests

Run `swift test --package-path CLI/Sources/TritonKitCLI/Resources/ios-runner --scratch-path .build/ios-runner-protocol-tests` from the repository root. These macOS tests run the shipped Network server, parser, authentication, routing and ledger with an injected UI executor; they do not validate UIKit, signing or physical-device lifecycle.

## Authenticated channel v2

The client sends `TRITON2\n` and a random 32-byte nonce. The server returns the same magic, a fresh 32-byte nonce and a CryptoKit HMAC-SHA256 proof binding the session and both nonces. The client verifies proof before sending any request. HKDF-SHA256 derives separate proof/request/response keys from the existing session secret. Requests and responses are AES-GCM sealed complete HTTP messages, framed with a 4-byte big-endian sealed-box length. Each connection handles exactly one request and response; no plaintext fallback exists.

The CLI and bundled Runner must upgrade together, then prepare/start a fresh session. Proof and record verification use system CryptoKit; the client copy of SecureChannel.swift is checked for byte equality. TTL is checked at routing and again before queued UI execution. The protocol proves session-key possession, not process/device identity; it does not provide forward secrecy or prevent denial of service, credential-file access, or transparent forwarding of opaque ciphertext. Limits are 80 KiB request plaintext and 12 MiB + 16 KiB response plaintext, plus 28 bytes sealed-box overhead.

## Observation geometry

Cross-App inspect/screenshot read their own app-frame points and device orientation. Unknown orientation returns the actual observation with partial=true and coordinateActionsAvailable=false, omitting geometry/observationID and invalidating old coordinate authority. Missing/invalid app frames fail with observation_window_unavailable. No direction is guessed from pixels/aspect ratio. The app must remain foreground; appAlertPresent is not a complete system-alert detector. Run TritonIOSRunnerTests/testCrossAppObservationWithoutOrientation explicitly for the fixture readiness → activation → observation → stale-coordinate refusal path. Physical device acceptance remains separate from host protocol tests.

# TritonKit v0.2.45

## Highlights

- Preserve original business values through recorder compilation/import, response fixtures, network URL parameters, WebView readable values/raw text, Harmony input readback and captured provider evidence. Secure/redaction conversion remains explicit and separate from original collection.
- Add shared action receipts and optional evidence bundles for the implemented typed-device/specialized-runner paths, retaining provider JSON, captured host output, byte/hash and completeness metadata. Acknowledgement, execution knowledge, business success and capture persistence remain separate facts.
- Fix Android display-size selection: a valid explicit Override wins over Physical size; diagnostic-only, malformed or ambiguous output no longer invents geometry.
- Verify exact public stable release metadata and complete arm64 byte size/SHA anonymously before Homebrew publication.
- Extend readonly Simulator resource dependency diagnostics without broadening managed profiles or mutation.
- Complete eight public skill guides (DSH, local HTTP, leases, UI details/3D, readonly Web, recording/import, App-map, VLM models), add 22-family navigation and remove repository-only links from the shipped guides.

## Distribution and verification

macOS arm64 CLI, bundled readonly Web, unsigned iOS XCTest Runner resources, four public skills and checksums are aligned to 0.2.45. The SDK is distributed by the same SwiftPM tag (iOS 16+). x86_64/CocoaPods remain retired; DSH documentation is not a new npm/plugin release or automatic installation.

The exact candidate main CI, tag CI, Release build/package and Homebrew tap jobs passed. Local checks included root runtime/shared tests, CLI XCTest167 + SwiftTesting1876, Web174 (0 failures/skips), skills38 and release contracts. Fully downloaded archives, Runner/skills metadata, all eight guide contents and SwiftPM tag identity passed; Homebrew upgrade/test returned an actual 0.2.45 binary with the same bytes as the archive.

CI anonymous metadata/byte verification passed before tap publication. Local anonymous direct downloads also matched every asset byte/hash. The local anonymous metadata API was rate-limited (403), including a post-reset retry; that original checker was not weakened and its failures were retained separately.

## Known boundaries

- The sampled iPad default live preview did **not** pass: HTTP409, with a separate readonly diagnostic reporting `ios_simulator_resize_capture_state_unknown`. No device settings, geometry or guard was changed. Readonly Atlas/suggestion-tab rendering passed separately after closing preview and draining in-flight requests; it does not erase the preview failure or establish all-platform streaming.
- Some Run/Atlas content is presentation/demo data, not live business execution evidence. Browser write routes still refuse complete input DTOs with 405. LLM/VLM inference remains disabled by default.
- SP-281 P2/ordinary host-throw/Simulator HID/unified-owner integration is not claimed complete. Optional leases/process-local admission are not global Stop, fleet authorization or a sandbox.
- Unknown delivery must not trigger automatic input replay. `manifest.ok` proves capture completeness, not successful App behavior. Local raw artifacts are not automatically authorized for public sharing.
- This publication does not establish new physical-device, user-App, IME, real-model, iOS16 native behavior or reliability acceptance; the extra local Simulator build was explicitly skipped.

Upgrade with `brew upgrade NeptuneKit/tap/triton`. Update agent skills separately with the guarded, version-matched bundle workflow and verify BUILD_INFO/metadata; a CLI upgrade alone does not update agent skills.

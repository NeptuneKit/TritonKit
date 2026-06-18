# 2026-06-18 Implementation Plan

## Slice P0

1. Keep `Package.swift` public products unchanged.
2. Add capability enabled state to shared runtime manifest DTOs.
3. Map existing `TritonKit.Configuration.features` onto runtime capability checks.
4. Gate request handling before observe/input/webview/semantic work executes.
5. Return stable `capability_disabled` JSON error payloads.
6. Update README and memory.

## Test Plan

- `swift test --filter TKRuntimeManifestModelsTests`
- `swift test --filter TKPlatformFallbackTests`
- `swift test --filter TKRuntimeWebViewSnapshotTests`
- `docs-linhay/scripts/check-docs.sh`

Run broader Swift tests if shared model changes require it.

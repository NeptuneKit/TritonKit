# Space: 20260703-issue-132-appintents-pod-build

## Issue

- GitHub: https://github.com/NeptuneKit/TritonKit/issues/132
- Title: `[Bug] Xcode 26.6 simulator build fails during AppIntents metadata extraction`

## Background

A CocoaPods Debug simulator build can fail inside the `TritonKit` pod target during `ExtractAppIntentsMetadata`, before the host app sources build. The reported failure shapes are missing `*.swiftconstvalues` files for simulator architectures and `appintentsmetadataprocessor error: Missing value for --source-files`.

## BDD

1. Given a host app includes `TritonKit` through CocoaPods for a Debug iOS Simulator build
2. When the `TritonKit` pod target has no AppIntents surface to export
3. Then Xcode must not run an AppIntents metadata extraction step that fails the pod target
4. And the podspec contract must keep the Debug runtime compile flag behavior unchanged

## Scope

- In scope: CocoaPods target build settings and podspec contract tests/docs.
- Out of scope: adding AppIntents, changing SwiftPM package behavior, or touching host app Podfiles.

## Validation

- Red: podspec contract test must fail before adding the AppIntents extraction disable setting.
- Green: podspec contract test and pod lint/build checks pass after the podspec update.
- Red command: `docs-linhay/scripts/verify-ios-debug-isolation.sh`
- Green commands:
  - `docs-linhay/scripts/verify-ios-debug-isolation.sh`
  - `pod lib lint TritonKit.podspec --allow-warnings --skip-tests`
  - `git diff --check`
  - `docs-linhay/scripts/check-docs.sh`
- Pod lint evidence: CocoaPods validation passed, and Xcode reported `Metadata extraction skipped. No AppIntents.framework dependency found.`

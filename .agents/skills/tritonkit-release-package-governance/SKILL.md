---
name: tritonkit-release-package-governance
description: Use when preparing or publishing a TritonKit release, especially when the user says the release must be whole, asks about updating built-in packages across endpoints, or touches CLI/Homebrew/Web/SwiftPM/CocoaPods/public skill package version alignment.
metadata:
  version: 0.1.0-dev
---

# TritonKit Release Package Governance

Use this skill for maintainer-side release work. It is an internal `.agents/skills/` workflow and must not be packaged into `TritonKit.skills/`.

## Release Boundary

A whole TritonKit release means these public package surfaces are aligned to the same tag version:

- CLI binary release assets and `triton version --json` output, stamped by CI from the `v*` tag.
- Bundled Web asset inside the CLI tarballs and Homebrew install.
- Public skill bundle `tritonkit-skills.tar.gz`, stamped by CI from the `v*` tag.
- iOS embedded SDK CocoaPods spec: `TritonKit.podspec`.
- Web package manifests: `Web/package.json` and `Web/package-lock.json`.

SwiftPM has no version field in `Package.swift`; consumers update by resolving the Git tag. Do not add a package version field to SwiftPM manifests.

## Required Workflow

1. Pick the next tag. If a tag has already been published, never move it; create the next patch release.
2. Before changing versions, run `docs-linhay/scripts/verify-release-package-versions.sh <version>` to prove the current manifests would fail for the target.
3. Update `TritonKit.podspec`, `Web/package.json`, and `Web/package-lock.json`.
4. Do not manually edit `Sources/TritonKitCLI/CLIBuildInfo.swift` for a release version. CI writes `TritonKitBuildInfo.cliVersion` during release builds.
5. Run focused validation:
   - `docs-linhay/scripts/verify-release-package-versions.sh <version>`
   - `docs-linhay/scripts/verify-release-automation.sh`
   - `git diff --check`
   - `docs-linhay/scripts/check-docs.sh`
   - `npm --prefix Web run build`
   - `pod lib lint TritonKit.podspec --allow-warnings --skip-tests`
6. Run release preflight with Xcode simulator checks disabled only when the local environment does not need that coverage: `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local`.
7. Update `docs-linhay/dev/` and `docs-linhay/memory/YYYY-MM-DD.md` for release contract changes.
8. Commit and push `main`, then publish through `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/release.sh v<version> --yes`.
9. After release, verify GitHub Release assets, GitHub Actions success including x86_64 backfill, Homebrew upgrade, `triton version --json`, packaged `triton web --print-command --json`, and a real `triton web` HTTP smoke.

## Recovery Rules

- If the wrong tag was pushed but GitHub Release has not been created, cancel only that superseded release workflow, delete the mistaken local and remote tag, correct version manifests on `main`, commit, push, and publish the intended tag. Do not cancel a valid current release workflow.
- If `release.sh` reports that GitHub Actions completed before assets were visible, treat it as a possible observation race first: inspect `gh release view v<version>`, the Release workflow jobs, checksum file, Homebrew tap commit, and installed `triton version --json` before deciding the release failed.
- Do not move an already published tag. If a GitHub Release exists for the wrong version, stop and make an explicit maintainer decision; the default recovery is a new higher version tag, not retagging history.
- For Homebrew validation, check the remote formula first, then run `brew update`, `brew upgrade NeptuneKit/tap/triton`, `brew test NeptuneKit/tap/triton`, and verify packaged web mode from outside the repository so a source checkout does not mask release behavior with dev mode.

## CI / Release Performance Contract

- `CI` handles validation only. `v*` tag validation must stay on the contracts fast path and must not wait for Swift tests or CocoaPods lint.
- Release asset builds live in the independent `Release` workflow. Do not restore release builds as active jobs in the `CI` workflow.
- arm64 release assets are the Apple Silicon publish gate: arm64 CLI, public skill bundle, checksum manifest, GitHub Release, and Homebrew tap must become available before waiting on x86_64.
- x86_64 CLI is a backfill asset. Build it on the arm64 macOS runner with `swift build --package-path CLI --scratch-path .build/cli-x86 -c release --product triton --triple x86_64-apple-macosx14.0`, then verify `file` reports `Mach-O 64-bit executable x86_64` before upload.
- Release SwiftPM cache keys are architecture-specific: keep separate `release-cli-arm64` and `release-cli-x86_64` cache keys so dependency/build cache does not force the release path back onto the Intel runner.
- `publish-x86-release-asset` must checkout the repository before calling `gh release download`; the GitHub CLI requires git repository context for release lookup.

## Reporting

State which surfaces were aligned, which validations passed, and whether CocoaPods was only linted or also pushed to a pod repo/trunk. If CocoaPods publishing is not performed, say that explicitly.

# SP-189 — Issue #220 package-relative xcresult path

## Scope

Fix `triton xcode test --package ... --result-bundle <relative>` so xcodebuild and inline xcresult parsing resolve the bundle against the package working directory.

## BDD

- Given a package action runs xcodebuild from the package directory, when a relative result bundle is supplied, then the command and parser use the same package-resolved filesystem path.
- Given an absolute result bundle or a non-package action, then the path remains unchanged.

## Validation

- `swift test --package-path CLI --filter XcodeCommandTests.packageRelativeResultBundleUsesPackageWorkingDirectory --no-parallel`

Real Xcode execution is not available in this environment; the regression covers path normalization and command contract.

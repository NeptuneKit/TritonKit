# Space: 20260703-issue-128-harmony-install-failure

## Issue

- GitHub: https://github.com/NeptuneKit/TritonKit/issues/128
- Title: `[Bug] Harmony app install reports ok=true when HDC reports install failure`

## Background

Harmony `hdc install -r <path.hap>` can exit with status `0` while stdout contains a semantic install failure such as `msg:error: failed to install bundle. code:9568332 error: install sign info inconsistent.` TritonKit previously treated this as a successful host action because `runHostCommand` only checked the process exit code and the generic HDC `[fail]` marker.

## BDD

1. Given `triton app install --platform harmony --hap <path> --json` runs an HDC install command
2. When HDC exits `0` but stdout contains `msg:error:` or `failed to install bundle`
3. Then TritonKit must classify the host command as failed
4. And the JSON path must return a failure envelope instead of `ok=true`

## Scope

- In scope: HDC install semantic failure detection for stdout/stderr markers.
- Out of scope: real device install smoke, signing repair, Harmony uninstall behavior, or new HDC diagnostics model.

## Validation

- Red: `swift test --package-path CLI --scratch-path .build/cli-test --filter DeviceCrossPlatformTests/harmonyAppInstallTreatsHDCStdoutFailureAsCommandFailure`
- Green: same focused test after extending HDC install semantic failure detection.
- Regression: `swift test --package-path CLI --scratch-path .build/cli-test --filter DeviceCrossPlatformTests`
- Local gate: `docs-linhay/scripts/verify.sh --local`
- Hygiene: `git diff --check`, `docs-linhay/scripts/check-docs.sh`

# Space: 20260703-issue-129-harmony-uninstall

## Issue

- GitHub: https://github.com/NeptuneKit/TritonKit/issues/129
- Title: `[Feature] Add Harmony support to app uninstall`

## Background

Harmony install/launch/info already use the host-side HDC path, but `triton app uninstall` only exposes iOS and Android. Agents currently fall back to raw `hdc -t <target> shell bm uninstall -n <bundle-id>` when a Harmony bundle must be removed before reinstalling a differently signed HAP.

## BDD

1. Given a Harmony emulator target selected by `--device harmony:<target>` or `--target <target>`
2. When an agent runs `triton app uninstall --platform harmony --bundle-id <bundle> --confirm --json`
   or `triton app uninstall --platform harmony --bundle <bundle> --confirm --json`
3. Then TritonKit must execute `hdc -t <target> shell bm uninstall -n <bundle>`
4. And success/failure must use the existing host action JSON envelope

## Scope

- In scope: Harmony uninstall plan, `--bundle` / `--bundle-id` CLI options, Android `--package-name` parser compatibility with existing schema, help/schema examples, focused tests.
- Out of scope: raw HDC fallback docs, real DevEco emulator smoke, bundle signing recovery.

## Validation

- Red: Harmony uninstall planning test fails before the command builder/runtime support exists.
- Green:
  - `swift test --package-path CLI --scratch-path .build/cli-test --filter DeviceCrossPlatformTests/issue129AppUninstallParsesHarmonyBundleAndAndroidPackageIdentifiers`
  - `swift test --package-path CLI --scratch-path .build/cli-test --filter DeviceCrossPlatformTests/hostAppUninstallSupportsHarmonyBMUninstall`
  - `swift test --package-path CLI --scratch-path .build/cli-test --filter SchemaFactSourceTests/appSchemaExposesHostAppSubcommandsUsedByPlans`
  - `swift test --package-path CLI --scratch-path .build/cli-test --filter DeviceCrossPlatformTests`
  - `git diff --check`
  - `docs-linhay/scripts/check-docs.sh`
  - `docs-linhay/scripts/verify.sh --local`

# 20260608 Semantic Provider Capabilities

## Background

GitHub issue [#38](https://github.com/NeptuneKit/TritonKit/issues/38) records a framework-level adoption gap from real iOS app regression: agents can inspect generic UI/AX facts, but many readiness checks are app-domain semantics such as playback readiness, elapsed-time progress, cache cleanup, route counts, or business-specific recovery state.

Issue #36 added media playback observation helpers, but TritonKit should not hard-code every business domain into core. Apps need an opt-in semantic provider contract so they can expose typed state and action catalogs to agents while keeping privacy, redaction, and source confidence explicit.

## Goal

Add a first provider-backed semantic capability slice that lets agents discover app-owned semantic domains and read typed state through machine-readable runtime contracts.

## Scope

In scope for this slice:

- add shared DTOs for semantic domains, manifest summaries, state fields, action descriptors, redaction metadata, and snapshot response;
- add a DEBUG runtime registry for app-provided semantic state providers;
- include semantic state in `triton snapshot --include semantic --json`;
- advertise `app.semantic_state` and `app.semantic_action` boundaries plus registered semantic domain/source summaries in runtime manifest and CLI capabilities;
- expose the first query/assert/action discovery contract through existing `snapshot` schema and capability metadata without adding execution commands yet;
- update schema/docs/skills/memory so agents distinguish provider-backed business facts from AX/layout inference.

Out of scope for this slice:

- executing provider-backed domain actions;
- a dedicated `triton state query/assert/action perform` command family;
- Web/Wails UI;
- private API, host injection, or media-specific logic in the semantic core.

## Acceptance Scenarios

1. Given an app registers a semantic provider for `media-playback`, when a runtime snapshot includes `semantic`, then the snapshot returns that domain with provider source, confidence, typed state, schema fields, action descriptors, redaction metadata, and evidence commands.
2. Given no semantic provider is registered, when a runtime snapshot includes `semantic`, then the snapshot returns an empty domain list plus a clear warning and does not infer business readiness from AX/layout alone.
3. Given agents inspect runtime manifest, then they can discover registered semantic domains, provider source/confidence, schema fields, action descriptors, redaction policy, and the `app.semantic_state` / `app.semantic_action` boundaries without reading state values from manifest.
4. Given agents inspect CLI capabilities, then they can discover provider-backed semantic state/action planning metadata, query/assert/action workflow categories, evidence names, and the next snapshot command.
5. Given agents inspect command schema, then `snapshot` documents `semantic` as an include section and exposes semantic state, domain schema, redaction, and action catalog fields in its output contract.

## Verification

- `swift test --filter TKRuntimeStateModelsTests`
- `swift test --filter TKRuntimeManifestModelsTests`
- `swift test --filter TKPlatformFallbackTests.semanticProviderRegistry`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `docs-linhay/scripts/check-docs.sh`
- `docs-linhay/scripts/qmd-sync.sh`
- `docs-linhay/scripts/verify.sh --local`

Local note: on macOS 26.4 / Xcode 17F42, some root-package SwiftPM test runs can hang after `Build complete!` while `swiftpm-xctest-helper` is still loading the `.xctest` bundle in dyld `fcntl`, before any test case starts. Use a clean temp copy named `TritonKit` for CLI package checks when the feature worktree basename causes SwiftPM package identity drift.

## Session Notes

### 2026-06-09 CLI Package Identity Follow-up

The CLI package is a nested SwiftPM package that depends on the repository root package by local path. When the worktree directory name does not match the root package identity, SwiftPM can fail to resolve the local dependency from `CLI/Package.swift` unless the dependency is explicitly named.

Fix applied in commit `564d124`:

- changed `CLI/Package.swift` from `.package(path: "..")` to `.package(name: "tritonkit", path: "..")`;
- kept the root `Package.swift` boundary unchanged so iOS app consumers still avoid CLI-only dependencies;
- confirmed no lockfile or generated file changes were required.

Verification sequence:

- `swift test --package-path CLI --filter SchemaFactSourceTests` passed with 105 tests;
- `swift test --package-path CLI` passed with 194 tests;
- `swift test` from the repository root passed with 164 tests.

Reusable workflow:

1. If a nested SwiftPM package fails on a local path dependency in a dated worktree, inspect the depended package's declared `name` before changing product or target references.
2. Prefer an explicit `.package(name:path:)` dependency identity for local package dependencies that cross worktree/package boundaries.
3. Re-run the focused schema/contract suite first, then the nested package test suite, then the root package test suite.
4. Check `git status --short` and `git diff --stat` after SwiftPM resolution to ensure `.resolved` files or generated artifacts were not unintentionally changed.

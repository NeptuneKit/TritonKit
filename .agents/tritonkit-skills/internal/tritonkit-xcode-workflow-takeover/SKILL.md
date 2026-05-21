---
name: tritonkit-xcode-workflow-takeover
description: Use when designing, implementing, extending, or validating TritonKit Xcode workflow takeover capabilities inspired by XcodeBuildMCP, including project/workspace discovery, schemes, xcodebuild build/test/run, xcresult, coverage, logs, SwiftPM, physical device/macOS workflows, LLDB, host UI integration, and deciding what should not be imported.
metadata:
  version: 0.1.0-dev
---

# TritonKit Xcode Workflow Takeover

## Principle

Eat XcodeBuildMCP's useful capabilities, not its public API. TritonKit exposes `triton` CLI/HTTP schema as the product contract; XcodeBuildMCP is a reference for workflows, structured output, session defaults, and daemon patterns.

Use this skill when the task touches:

- project/workspace/package discovery;
- scheme/build setting/bundle metadata;
- `xcodebuild` build/test/run;
- `.xcresult` parsing, failures, attachments, coverage;
- logs, SwiftPM, physical devices, macOS app workflow;
- LLDB/debugging or host UI;
- optional XcodeBuildMCP bridge decisions.

## Required Context

Start from:

- `docs-linhay/spaces/20260520-xcode-workflow-takeover/README.md`
- `docs-linhay/spaces/20260520-xcode-workflow-takeover/technical-design.md`
- `docs-linhay/references/xcodebuildmcp.md`
- `docs-linhay/dev/20260520-simulator-takeover-architecture.md`

## Adoption Rules

- `triton xcode`, `triton xcresult`, `triton coverage`, `triton logs`, `triton spm`, `triton debug`, and `triton device` are the target command namespaces.
- As of 2026-05-21, Xcode build/test/run should default to `triton xcode` instead of XcodeBuildMCP. Use XcodeBuildMCP only as a reference or temporary fallback when a needed Triton capability is missing.
- Long-running build/test/run/log/debug commands emit JSONL progress and a final summary envelope.
- Build/test/log/coverage artifacts must be eligible for `.tritonevidence`.
- Build/run output must bind to simulator app targets and, when possible, embedded runtime targets.
- `xcode run` only proves build/install/launch; verify business readiness with runtime `status`, `wait`, `find`, `assert`, screenshot, or evidence.
- Do not expose XcodeBuildMCP tool names, workflow flags, or MCP server config as user-facing TritonKit API.
- Do not add Node as a required runtime dependency. Any bridge must be optional and wrapped behind Triton output/error contracts.
- Do not use Xcode IDE Bridge as a first-phase dependency.
- Do not let host UI automation replace embedded runtime control; host UI is only for system UI / SpringBoard / simulator-level gaps.

## Current Implemented Surface

```bash
triton xcode discover --path . --json
triton xcode use --workspace App.xcworkspace --scheme App --configuration Debug --simulator <udid> --json
triton xcode schemes --json
triton xcode settings --json
triton xcode build --jsonl
triton xcode test --result-bundle /tmp/App.xcresult --jsonl
triton xcode run --jsonl
```

Current boundaries:

- `xcode run` covers build, simulator install, and simulator launch; it does not prove business readiness.
- Continue readiness checks with `triton status`, `triton wait`, `triton assert`, screenshot, or evidence.
- `xcresult`, coverage, logs, and evidence xcode artifacts are still follow-up slices.

## Implementation Workflow

1. Update BDD in the xcode workflow takeover space first.
2. Add shared models and fixtures before CLI implementation:
   - discovery summaries;
   - scheme/settings/bundle info;
   - build/test progress events;
   - xcresult summaries;
   - coverage summaries.
3. Implement the domain service behind CLI so future HTTP/MCP can reuse it.
4. Add CLI schema entries for every agent-facing command.
5. Add or update evidence/plan integration when artifacts or replay steps change.
6. Sync `README.md`, `docs-linhay/dev/ai-cli-readable-control.md`, relevant skills, memory, and qmd.

## Validation

Minimum validation:

```bash
swift test
swift build --product triton
.build/debug/triton schema --command xcode --json
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/qmd-sync.sh
```

When implementation exists, add focused smoke:

```bash
.build/debug/triton xcode discover --path <repo> --json
.build/debug/triton xcode build --workspace <workspace> --scheme <scheme> --simulator <udid> --jsonl
.build/debug/triton xcode test --workspace <workspace> --scheme <scheme> --result-bundle /tmp/<case>.xcresult --jsonl
.build/debug/triton xcresult failures --path /tmp/<case>.xcresult --json
```

Use temporary or explicit output paths such as `/tmp` or `.triton/`; do not scatter build artifacts in repo root.

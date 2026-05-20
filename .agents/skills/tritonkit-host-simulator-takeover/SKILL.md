---
name: tritonkit-host-simulator-takeover
description: Use when designing, implementing, extending, or validating TritonKit host-side Apple Simulator takeover capabilities such as `triton sim`, `triton app`, xcrun/simctl wrappers, workspace simulator defaults, boot wait JSONL, app metadata, containers, preferences, host artifacts, plan/evidence integration, or replacing raw xcrun usage with Triton CLI contracts.
metadata:
  version: 0.1.0-dev
---

# TritonKit Host Simulator Takeover

## Principle

TritonKit should be the stable interface seen by AI agents and automation. Apple tools such as `xcrun simctl`, `xcodebuild`, `devicectl`, `xctrace`, and `xcresulttool` are implementation resources behind `triton` CLI/HTTP schema, not the default product contract exposed to agents.

Keep the boundary explicit:

- Embedded runtime handles DEBUG-only in-app observation and control.
- Host simulator adapter runs only in macOS CLI / `triton serve`.
- CLI/HTTP schema, JSON/JSONL output, stable error codes, and evidence/plan integration are the user-facing contract.
- Raw `xcrun simctl` is a fallback only when `triton schema --command sim --json` or `triton schema --command app --json` does not expose the required capability.

## Current P0 Contract

Simulator commands:

```bash
triton sim list --json
triton sim use <udid> --json
triton sim boot <udid> --json
triton sim boot <udid> --wait --jsonl
triton sim shutdown <udid-or-booted> --json
triton sim screenshot --simulator <udid-or-booted> --output /tmp/<case>-sim.png --json
```

App commands:

```bash
triton app list --simulator <udid-or-booted> --user-only --json
triton app info --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app install --app <path.app> --simulator <udid-or-booted> --json
triton app launch --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app terminate --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app open-url '<url>' --simulator <udid-or-booted> --json
triton app container --bundle-id <bundle-id> --kind data --simulator <udid-or-booted> --json
triton app prefs get <key> --bundle-id <bundle-id> --simulator <udid-or-booted> --json
triton app prefs dump --bundle-id <bundle-id> --simulator <udid-or-booted> --json
```

`triton sim use` writes repo-local workspace defaults to `.triton/host-defaults.json`. Do not run smoke writes in the repository unless that file is intentionally part of the test. Use a temporary working directory for validation when possible.

`triton app open-url` only proves that the URL was submitted to Simulator. Always verify business completion with `triton wait`, `triton find`, `triton assert`, `triton app prefs get`, a fresh screenshot, or an evidence bundle.

`simctl appinfo` can exit 0 for a missing bundle while only echoing `CFBundleIdentifier`; Triton normalizes this to `app_info_not_available`. Do not treat raw `simctl` exit code alone as proof of installed app metadata.

## Implementation Workflow

1. Start from the simulator takeover space:
   - `docs-linhay/spaces/20260520-simulator-takeover/README.md`
   - `docs-linhay/spaces/20260520-simulator-takeover/technical-design.md`
   - `docs-linhay/dev/20260520-simulator-takeover-architecture.md`
2. Define or update BDD acceptance in the space before code changes.
3. Add shared model tests first:
   - command argv builders in `Tests/TritonKitSharedTests/TKHostAdapterModelsTests.swift`;
   - parser behavior for JSON/OpenStep plist/plain text outputs;
   - stable error edge cases such as missing apps or ambiguous targets.
4. Implement shared contracts in `Sources/TritonKitShared/TKHostAdapterModels.swift`.
5. Expose CLI commands in `Sources/TritonKitCLI/main.swift`, keeping output machine-readable:
   - one-shot commands return JSON;
   - progress commands return JSONL when requested;
   - failures return `{ ok:false, error:{ code, message, hint, nextAction? } }`;
   - host actions include source command / risk metadata where available.
6. Update `commandSchemas()` for every agent-facing command.
7. Sync documentation:
   - `README.md`;
   - `docs-linhay/dev/ai-cli-readable-control.md`;
   - simulator takeover space implementation notes;
   - `tritonkit-real-project-regression` when real app validation flow changes;
   - `tritonkit-dev-feedback` when issue evidence commands change;
   - memory entry for decisions, risks, and verification.

## Validation

Minimum local validation for host simulator adapter changes:

```bash
swift test --filter TKHostAdapterModelsTests
swift test
swift build --product triton
.build/debug/triton schema --command sim --json
.build/debug/triton schema --command app --json
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/qmd-sync.sh
```

Run real simulator smoke only when it is safe for the current machine state:

```bash
.build/debug/triton sim list --json
.build/debug/triton app list --simulator booted --user-only --json
.build/debug/triton app info --bundle-id <known-bundle-id> --simulator booted --json
.build/debug/triton app info --bundle-id com.example.missing --simulator booted --json
```

For `sim use`, validate in `/tmp` or another disposable directory:

```bash
mkdir -p /tmp/triton-sim-use-smoke
(cd /tmp/triton-sim-use-smoke && /path/to/triton sim use <udid> --json)
```

Avoid destructive or stateful smoke such as reinstalling business apps, erasing simulators, uninstalling apps, replacing `.xcappdata`, or modifying privacy/location unless the current task explicitly requires it.

## Priority Backlog

Keep P0/P1 focused on real-project regression value:

- P0 remaining: `app uninstall` with explicit confirmation policy, safer default simulator resolution, app install result enrichment.
- P1: `sim privacy`, `sim location`, `sim ui/status-bar`, push notification, media/contact import, keychain certificates, pasteboard, iCloud sync, `.xcappdata`, logs, host evidence artifacts.
- P2+: host UI snapshot/tap/type/press, record video, diagnose, xctrace, Xcode build/test, coverage, SwiftPM, runtime maintenance.

## Boundaries

- Do not add Web/Wails UI for host simulator control while CLI/HTTP can satisfy the automation contract.
- Do not put host-side process execution into the iOS embedded runtime.
- Do not expose XcodeBuildMCP tool names as TritonKit product API; use it as reference only.
- Do not use interactive confirmation gates for long-running automation. Use `riskLevel`, objective required config, audit metadata, and explicit command flags/policy instead.

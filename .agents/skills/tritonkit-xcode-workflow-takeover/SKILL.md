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
- As of 2026-05-21, Xcode build/test/run should default to `triton xcode` instead of XcodeBuildMCP. Use XcodeBuildMCP only as a reference or temporary fallback after `triton schema --command xcode --json`, `triton capabilities --json`, `triton plan ... --json`, or a `triton xcode ... --jsonl` result proves the needed capability is missing, unsupported, or failed with a stable Triton error code.
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
triton xcode discover --path . --max-depth 8 --json
triton xcode use --workspace App.xcworkspace --scheme App --configuration Debug --simulator <udid> --json
triton xcode use --package Package.swift --scheme PackageName --destination 'generic/platform=iOS Simulator' --json
triton xcode schemes --timeout-seconds 300 --disable-automatic-package-resolution --json
triton xcode status --json
triton xcode wait-idle --workspace <workspace> --timeout <seconds> --json
triton xcode settings --jsonl --timeout <seconds>
triton xcode build --jsonl
triton xcode build --package Package.swift --scheme PackageName --destination 'generic/platform=iOS Simulator' --jsonl
triton xcode test --result-bundle /tmp/App.xcresult --jsonl
triton xcode run --jsonl
triton xcresult summary --path /tmp/App.xcresult --json
triton xcresult failures --path /tmp/App.xcresult --json
triton xctrace record --template "Time Profiler" --device <udid> --time-limit 5s --output /tmp/App.trace --json
triton coverage report --xcresult /tmp/App.xcresult --output /tmp/coverage.json --json
```

Current boundaries:

- Xcode DerivedData defaults to the fixed repo-local `.triton/DerivedData` incremental cache across `xcode settings/build/test/run` and `build ios`. Do not auto-derive project/workspace hash subdirectories or defer this default until a conflict is detected. Use an explicit `--derived-data-path` only when the caller needs isolation or cache recovery, and preserve the default cache unless cleanup is explicitly requested.
- `xcode discover` defaults to a depth of 8 so nested real-project containers are discoverable while build/dependency noise stays excluded. Keep `--max-depth` explicit when a repository needs a different bound.
- `xcode schemes` defaults to a 300-second timeout and supports `--disable-automatic-package-resolution` for deterministic discovery. On `xcode_schemes_timeout`, preserve the selected workspace/project/package in `nextAction` and retry with a bounded longer timeout before raw `xcodebuild` fallback.
- `xcode run` covers build, simulator install, and simulator launch; it does not prove business readiness.
- Continue readiness checks with `triton status`, `triton wait`, `triton assert`, screenshot, or evidence.
- Real workspaces may exceed default timeouts. Use `triton xcode settings/build/test/run --timeout <seconds>` and preserve the JSONL summary or stable error envelope before falling back to raw `xcodebuild`.
- When `xcode discover` returns `Package.swift`, consume that path through `--package` or persist it with `xcode use --package ...`. Do not fall back merely because no `.xcworkspace` / `.xcodeproj` exists. Package actions run `xcodebuild` from the package directory, expose `package` in invocation/final output, and share the same JSONL artifacts as project actions.
- Treat target identity as one contract across the resolved invocation and generated `xcodebuild` command. Explicit precedence is `--destination` > real-device selector > `--simulator` > workspace default destination. For `--simulator`, UUID and `sim:<UUID>` selectors synthesize `id=<UUID>`; human-readable names synthesize `name=<name>`. Never persist or generate `id=<device name>`.
- Treat launch environment transport as target-specific. Simulator launch uses `SIMCTL_CHILD_*`; real-device launch must pass one explicit `devicectl --environment-variables <JSON dictionary>` argument instead of relying on caller `DEVICECTL_CHILD_*`. Preserve the flag name in `sourceCommand`, redact the entire JSON argument by argv index, and keep the unredacted value only in the executed process argv.
- Use `triton app pull` for bounded host retrieval from an iOS real-device app data or app group container. Resolve the target through `ios-real:`/alias selectors; never fall back to Simulator `app container` for a real device. Keep destination overwrite explicit, stage before atomic publication, require explicit directory allowance, enforce the byte bound, and preserve the redacted target plus devicectl JSON/log artifacts in the result.
- When build/test behavior looks stuck, run `triton xcode status --json` first, then `triton xcode wait-idle --workspace <workspace> --timeout <seconds> --json`; timeout returns `xcode_not_idle` with blocking PIDs.
- `xcode status` should only classify `xcodebuild`, `SwiftBuildService`, `XCBBuildService`, and `xctest` as Xcode-lane blockers. Do not treat unrelated SwiftPM `swift-build --package-path ...` provider builds as active Xcode workflow blockers.
- `xcode wait-idle` treats transient internal `pgrep` / `ps` timeout as poll noise when later status can be observed; final timeout should prefer `xcode_not_idle` with the latest process context over a bare host probe timeout.
- `xcode settings/build/test/run --jsonl` emits invocation, stdout/stderr samples, heartbeat, and summary events with stdout/stderr log paths and byte counts. Use those artifacts before deciding to wait longer or fall back to raw `xcodebuild`.
- If `xcode build/test/run` returns `xcodebuild_interrupted`, inspect stdout/stderr artifact paths and run `triton xcode status --json` before retrying. If it returns `orphaned_xcodebuild`, the final summary includes `postActionProcessStatus` and `nextActions`; run `triton xcode wait-idle --workspace <workspace> --timeout 120 --json` or cancel stale PIDs before retrying.
- `xcode settings/build/test/run --json` keeps stdout for the final JSON envelope but emits the same progress JSONL to stderr so agent wrappers do not see long-running builds as empty-output hangs.
- `xcode test --result-bundle <path> --jsonl` emits a final `TKXcodeActionSummary` with default-redacted `testResultSummary` and `topFailures` when the result bundle can be parsed. Failed tests return an `ok:false` summary and a non-zero process exit; inspect the inline top failures first, then use `triton xcresult failures --path <path> --json` for the full list.
- `xctrace record` and `coverage report` are artifact-first host commands. They return paths/source commands/byte summaries; large trace or coverage payloads stay in artifacts and do not prove business readiness.
- `xctrace record --output <path.trace>` rejects existing output unless `--append-run` is explicit; `--append-run` requires an existing non-symlink trace path. Symlink outputs are always rejected before invoking `xctrace`.
- Stdout-backed artifact writes reject existing output files and symbolic links by default. Use fresh paths under `/tmp`, `.triton/`, or an explicit artifact directory for repeatable agent runs.
- `xcresult summary/failures` is available for result bundle triage. Output is redacted by default across JSON and text, including `path`, `sourceCommand/sourceCommands`, private paths, emails, Bearer/token/password/API-key fragments, and long token-like strings. Use `--include-sensitive` only for local private debugging. `triton evidence --include xcode,host` captures only small read-only host/Xcode artifacts for now: repo-local defaults, simulator list, Xcode process status, and shallow discovery. If an Xcode build/test/run `TKXcodeActionSummary` was explicitly saved, `--xcode-summary <summary.json>` imports only that summary into `artifacts/xcode/action-summary.json`; it does not copy stdout/stderr logs, raw `.xcresult`, `.trace`, attachments, or scan temp/DerivedData. Raw `.xcresult` ingestion, attachments, semantic coverage summaries, logs, and automatic build/test/run collection are still follow-up slices.
- Xcode 26.6 emits array-shaped summary `devicesAndConfigurations` / `testFailures` and may flatten a failed test into a `Test Case` with direct `Failure Message` children instead of a `Test Case Run`. Keep singleton compatibility and Triton's stable DTO shape, but cover both forms with compact sanitized fixtures plus a real local `.xcresult` smoke; never attach that raw bundle publicly.
- `triton schema --command xcode|xcode.build|xcresult|xctrace|coverage --json` exposes structured agent-planning fields in addition to prose shapes: `requiredOptions`, `inheritsDefaultsFrom`, `jsonlEvents`, `finalEventKind`, `artifacts`, `retryable`, `nextCommands`, `outputContracts`, `failureCodes`, and `subcommands[]`. Dotted and space-separated nested selectors both narrow the parent envelope to one subcommand. Prefer `subcommands[]` for planning: it uses atomic `requiredOptions`, `oneOfRequiredOptions`, `optionalOptions`, `defaultProviders`, `outputSelectors`, and subcommand-level failure codes so agents do not parse human strings like `summary/failures:--path`. Treat these as planning/output-selection hints; concrete commands still validate their own arguments.

## Error Recovery

Use this table before falling back to raw `xcodebuild`:

| Error code | Meaning | Next action |
| --- | --- | --- |
| `invalid_workspace_path` | Missing or invalid workspace/project/package/repo path | Run `triton xcode discover --path . --json`, then pass an explicit `--workspace`, `--project`, or `--package`. |
| `ambiguous_workspace` | Multiple containers or conflicting options | Pick exactly one discovered `.xcworkspace`, `.xcodeproj`, or `Package.swift`; then run `triton xcode use ... --json`. |
| `scheme_not_found` | Scheme is absent or not shared | Run `triton xcode schemes --workspace <path> --json`; use a shared scheme or fix the project. |
| `xcode_schemes_timeout` | `xcodebuild -list -json` exceeded the schemes discovery timeout | Retry the suggested `triton xcode schemes` command with the preserved workspace/project/package, a bounded longer `--timeout-seconds`, and optionally `--disable-automatic-package-resolution`; inspect the stable error envelope before falling back. |
| `simulator_not_found` | No simulator default or invalid UDID | Run `triton sim list --json`, boot/select one simulator, then pass `--simulator <udid>` or `triton sim use <udid> --json`. |
| `xcode_not_idle` | Existing build/test processes still match the workspace | Run `triton xcode status --json`; wait, cancel stale PIDs manually, or retry with a more specific workspace. |
| `xcodebuild_failed` | Underlying build/test failed | Inspect stdout/stderr artifact paths from the JSONL summary; then run `triton xcresult summary/failures` if a result bundle exists. |
| `xcodebuild_interrupted` | `xcodebuild` returned an interrupted result without a terminal build/test outcome | Inspect stdout/stderr artifact paths, run `triton xcode status --json`, then retry with a longer timeout if no matching process remains. |
| `orphaned_xcodebuild` | Triton saw an interrupted result while a matching `xcodebuild` process remained active | Run `triton xcode status --json` and `triton xcode wait-idle --workspace <workspace> --timeout 120 --json`, or cancel stale PIDs before retrying. |
| `app_path_unresolved` | Build settings did not resolve `.app` path | Run `triton xcode settings --jsonl`; inspect `BUILT_PRODUCTS_DIR` and `FULL_PRODUCT_NAME`. |
| `bundle_id_unresolved` | Built app has no readable bundle id | Inspect the built `.app` Info.plist and verify `CFBundleIdentifier`. |
| `result_bundle_not_found` | `.xcresult` path is missing/incomplete | Check the `--result-bundle` path and rerun `triton xcode test --result-bundle <path> --jsonl`. |
| `xcresulttool_failed` | `xcrun xcresulttool` returned non-zero | Verify Xcode selection and result bundle compatibility; keep stderr as sanitized issue evidence. |
| `xcresult_parse_failed` | Apple changed JSON shape or parser is too strict | Keep the bundle and sanitized compact JSON output; file a parser compatibility issue. |
| `xcresult_output_too_large` | Compact xcresult JSON exceeded the inline parse limit | Preserve the `.xcresult` bundle and use smaller follow-up queries when available; do not attach raw private JSON publicly. |
| `artifact_output_rejected` | Artifact output path already exists or is a symbolic link | Choose a fresh path under an explicit artifact directory; do not overwrite or follow symlinks during automated runs. |
| `coverage_report_failed` | `xccov` failed or coverage is absent | Verify tests were run with coverage and narrow with `--only-targets`, `--target`, or `--file`. |
| `validation_failed` | Local CLI arguments conflict | Fix the argument combination before retrying; for coverage, use only one of `--only-targets`, `--target`, or `--file`. |

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
6. Sync `README.md`, `docs-linhay/dev/ai-cli-readable-control.md`, relevant skills, and memory.

## Validation

Minimum validation:

```bash
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command xcode --json
.build/cli/debug/triton schema --command xcode.build --json
docs-linhay/scripts/check-docs.sh
```

When implementation exists, add focused smoke:

```bash
.build/cli/debug/triton xcode discover --path <repo> --json
.build/cli/debug/triton xcode build --package <repo>/Package.swift --scheme <scheme> --destination 'generic/platform=iOS Simulator' --jsonl
.build/cli/debug/triton xcode build --workspace <workspace> --scheme <scheme> --simulator <udid> --jsonl
.build/cli/debug/triton xcode test --workspace <workspace> --scheme <scheme> --result-bundle /tmp/<case>.xcresult --jsonl
.build/cli/debug/triton xctrace record --template "Time Profiler" --device <udid> --time-limit 1s --output /tmp/<case>.trace --json
.build/cli/debug/triton coverage report --xcresult /tmp/<case>.xcresult --output /tmp/<case>-coverage.json --json
.build/cli/debug/triton xcresult summary --path /tmp/<case>.xcresult --json
.build/cli/debug/triton xcresult failures --path /tmp/<case>.xcresult --json
```

Use temporary or explicit output paths such as `/tmp` or `.triton/`; do not scatter build artifacts in repo root.

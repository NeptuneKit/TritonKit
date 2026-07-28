---
name: tritonkit-dev-feedback
description: Use when Codex is helping someone try, adopt, evaluate, or integrate TritonKit during its development stage, especially when the user has any requirement, bug, missing capability, confusing behavior, documentation gap, or compatibility concern that should become a GitHub issue in NeptuneKit/TritonKit. The AI agent should reproduce or clarify the finding, collect evidence, and submit the GitHub issue directly instead of asking the user to file it themselves.
metadata:
  version: 0.1.0-dev
---

# TritonKit Dev Feedback

## Principle

TritonKit is in active development. Treat user needs, bugs, rough edges, missing APIs, confusing behavior, documentation gaps, and compatibility friction as repository feedback.

The agent owns the issue filing action when GitHub access is available. Do not ask the user to file an issue when enough context exists.

Repository: `NeptuneKit/TritonKit`

## Fast workflow

1. Clarify only the minimum missing detail needed to avoid filing the wrong issue.
2. Check whether an existing open issue clearly covers the same feedback; comment instead of duplicating when appropriate.
3. Pick the narrowest reference below and read only that file plus `references/issue-filing.md`.
4. Reproduce or inspect locally when possible. Prefer machine-readable `triton ... --json` / `--jsonl` output.
5. Redact private app, account, network, path, log, screenshot, and evidence data before creating public GitHub content.
6. Run the public issue preflight in `references/issue-filing.md` immediately before any `gh issue create` or `gh issue edit`.
7. Create or update the issue with `gh issue create --repo NeptuneKit/TritonKit` / `gh issue edit --repo NeptuneKit/TritonKit`, or report the auth/network blocker with the exact command and body file.

## Reference routing

| Current feedback | Read |
| --- | --- |
| Ordinary bug, docs gap, feature request, or existing evidence to file | `references/issue-filing.md` |
| iOS embedded runtime hierarchy, snapshot, state, AX, input, WebView, media, semantic provider, or Xcode-run evidence | `references/evidence-ios-runtime.md` |
| Host-side iOS Simulator, Android Emulator, HarmonyOS / DevEco Emulator, Web Device Hub, install/launch/screenshot/readiness evidence | `references/evidence-host-devices.md` |
| CLI schema, capabilities, doctor, plan, replay, recovery, output contract, failure code, or taxonomy inconsistency | `references/schema-contract-feedback.md` |
| User asks how to add TritonKit to an iOS app via SwiftPM/CocoaPods | `references/app-integration-ios.md` |
| User asks how to use TritonKit with Harmony host-side validation or embedded SDK | `references/app-integration-harmony.md` |

## Always keep

- Triton-first evidence for local simulator/emulator/device work: run `triton status/doctor/capabilities/schema/plan` or an exact command schema before falling back to raw `xcrun`, `adb`, `hdc`, DevEco CLI, XcodeBuildMCP, or `xcodebuild`.
- Issue bodies must include background, current behavior, expected behavior, reproduction/evidence, and proposed next step.
- Public reports must preserve useful facts: platform/tool versions, TritonKit version, commands, error codes, sanitized logs, and minimal snippets.
- Public reports must not include secrets, tokens, private project names, app names, bundle IDs, team IDs, organizations, users, accounts, emails, phone numbers, internal hosts, absolute private paths, full private logs, or unredacted artifacts.
- Keep implementation work separate from feedback filing unless the user explicitly asks to fix the issue too.
- When feedback includes `testrec replay` / `local-simulated` / `matrix` output, report `verdictBoundary` explicitly. Legacy `ready`, `passed`, and `passedCount` are offline diagnostic compatibility state, not a real runtime verdict or reliability sample; a result without the additive boundary is legacy/unknown. Route real-verdict feedback through `test import -> test validate -> test run` with redacted placeholders rather than proposing a second testrec executor.
- When feedback includes `test reliability-preflight`, report it as an offline collection-contract check only. `ready_to_collect` must retain `writesEvidence=false`, `usesRuntime=false`, and `eligibleForReliabilityGate=false`; a negative control is valid only with its frozen assertion failure type and a non-optional read-only assertion plan. It does not establish a target/server/reset receipt, execute a test, or pass a reliability gate. Never include the private collection, plan/evidence paths, UDID, bundle, target, flow, selector, or reset identity in feedback.
- When feedback includes receipt-backed reliability collection, distinguish `reliability-reserve` from `reliability-sample`: reserve only writes an immutable private receipt at a fresh operator-owned root, while sample requires explicit `--confirm`, an already-running loopback server, one exact canonical iOS Simulator/App target, a private reset receipt, and a collection-wide active-sample lease before target/runner access. A busy or stale lease is fail-closed (`reliability_collection_busy`), not an invitation to delete/retry. Neither command may be described as booting, selecting, resetting, installing, launching, stopping, or taking over shared runtime lifecycle. A negative result is `ok=true` / exit 0 only for terminal `failed` with its frozen deterministic assertion failure type exactly matched; blocked, stopped, launch/primitive/transport/AI failures, missing/wrong failure type, supported nonpass, or negative unexpected pass are still one typed `ok=false` / exit 1 result, not a second error envelope. `reliability --samples` is legacy diagnostic-only and cannot pass the Stage 1 gate. Do not expose the receipt, root, target, reset, evidence, bundle, or UUID in public feedback.

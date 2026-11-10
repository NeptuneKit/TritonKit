---
name: tritonkit-dev-feedback
description: Use when helping someone try, adopt, evaluate, or integrate TritonKit and a requirement, bug, missing capability, confusing behavior, documentation gap, or compatibility concern needs evidence and a GitHub issue in NeptuneKit/TritonKit.
metadata:
  version: 0.1.0-dev
---

# TritonKit Dev Feedback

## Principle

Treat real-task needs, bugs and friction as repository feedback. When GitHub access is available, the agent owns evidence collection and issue filing; do not send the user away to file it. This skill authorizes feedback, not source changes, tool upgrades or operations on unrelated projects. Follow any narrower user boundary.

Repository: `NeptuneKit/TritonKit`.

## Minimal workflow

1. Identify the behavior, affected version and smallest missing fact. Reproduce with a read-only query or isolated fixture where possible.
2. Search **open and closed** issues and their follow-up comments. Add new evidence to the matching issue; distinguish the old fix's scope from the new failure.
3. Read [issue filing](references/issue-filing.md), then only the matching reference below. Do not preload the full reference directory for an ordinary report.
4. Preserve the exact command, actual result, expected result, version and relevant error/contract fields. Use machine-readable output and a positive/negative control when applicable.
5. Before creating, editing or commenting publicly, run the filing reference's redaction preflight. Submit the sanitized body from a file, read back the result and retain its link. On auth/network failure, retain the draft and concrete failure.
6. Keep implementation separate unless already authorized. A closed issue, new version or passing CI does not prove the original scenario recovered; recheck the original reproduction before retiring a workaround.

## Reference routing

| Feedback topic | Read only as needed |
| --- | --- |
| Ordinary bug, docs gap, feature request, existing evidence | [Issue filing and public preflight](references/issue-filing.md) |
| Embedded iOS hierarchy, AX, snapshot, input, WebView, media, providers | [iOS runtime evidence](references/evidence-ios-runtime.md) |
| Host Simulator / Android / Harmony, screenshot, HID, readiness, ArkWeb | [Host device evidence](references/evidence-host-devices.md) |
| Device Hub metadata, physical management, containers, wired backends | [Device Hub contracts](references/device-hub-feedback.md) |
| CLI schema, capabilities, doctor, plan, replay, recovery, output/error contracts | [Schema feedback](references/schema-contract-feedback.md) |
| Xcode compatibility, builds, timeouts, progress, DerivedData | [Xcode contracts](references/xcode-feedback.md) |
| Bonjour advertisement, SDK discovery or discovery migration | [Discovery contracts](references/discovery-migration.md) |
| Bounded hierarchy, OCR, settle, UI health or unknown action outcome | [Observation contracts](references/observation-feedback.md) |
| Offline testrec, preflight, receipt-backed samples or Stage 1 reliability | [Reliability contracts](references/reliability-feedback.md) |
| Optional highlight, floating picker, guarded selection or SDK hub | [Picker and highlight contracts](references/picker-feedback.md) |
| Bundled iOS Runner setup, startup failures or observation geometry | [Runner contracts](references/runner-feedback.md) |
| iOS SwiftPM integration | [iOS integration](references/app-integration-ios.md) |
| Harmony host or embedded SDK integration | [Harmony integration](references/app-integration-harmony.md) |

## Always keep

- Use Triton-first evidence for local simulator/emulator/device work: preserve relevant `status`, `doctor`, `capabilities`, exact command `schema` or `plan` facts before falling back to raw platform tools. Record the failure/unsupported boundary and fallback command.
- Issue bodies include background, current behavior, expected behavior, reproduction/evidence and proposed next step. Keep useful platform/tool versions, sanitized commands, error codes and minimal snippets.
- Never publish secrets, tokens, private project/app/bundle/team/account identities, internal hosts, absolute private paths, full private logs, unredacted screenshots or artifacts. Redaction must cover linked evidence as well as prose.
- Inspect state after failure. Unknown action outcome must not trigger blind replay, backend substitution or cleanup of someone else's state. Parameter acceptance, submission/ACK, observed effect and business completion are separate claims.
- Mock/fixture checks, native execution and user-project acceptance are different evidence. Preserve failures, partial results and unknowns. Never weaken a required check or infer action permission from discovery or capability metadata.

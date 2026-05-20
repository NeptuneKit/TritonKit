# Request: replace interactive confirmation with automation-friendly policy mode

## Resolution

Upstream issue: `https://github.com/linhay/harmony-next.skills/issues/10`

Status: closed by `68a3f3e docs: make emulator automation policy non-interactive`.

Final accepted semantics:

- The skill does not implement authorization or interactive confirmation gates.
- Users are treated as having full execution permission by default.
- Policy describes execution mode, artifact directory, timeout and redaction contract.
- `blocked` is reserved for objective missing runtime configuration, such as missing target, artifactDir, redaction policy, timeout or audit command record.
- Risk classification remains useful for audit and reporting, but does not stop long-running automation by itself.

## Background

The current `harmony-next` skill and DevEco Emulator playbook classify several operations as requiring user confirmation:

- starting/stopping Emulator or HVD
- app install/uninstall/clean/start
- saving real layout, screenshots, recordings, logs, sandbox files
- `hdc file send` / `hdc file recv`
- `fport/rport`
- `hitrace`, `uinput`, wide `hilog -x`
- display, foldable, power, and window-policy changes

This is safe for ad-hoc interactive use, but it blocks long-running automation. A supervising agent cannot reliably run an overnight or multi-step emulator workflow if every sensitive-but-expected operation requires a human prompt.

## Problem

The playbook currently mixes two different concerns:

1. whether an operation is risky or sensitive
2. whether the agent must stop and ask a human before continuing

For long automation mode, risk classification is still useful, but human confirmation should be replaceable by a pre-approved policy.

Example workflows affected:

- boot an HVD, wait for HDC target, install app, launch ability, collect screenshots and layout, archive evidence
- run regression plans that need `screenCap`, `dumpLayout`, `file recv`, and trimmed `hilog`
- collect failure evidence after a test step without waking a human operator
- run multi-target emulator smoke tests in CI or a local unattended session

## Proposal

Keep the risk levels, but remove "interactive user confirmation" as the only allowed gate. Add an automation policy model.

Suggested policy levels:

- `readonly`: allow only low-risk read operations.
- `evidence`: allow screenshots/layout/log excerpts/file recv into an explicit artifact directory, with redaction metadata.
- `automation`: allow emulator lifecycle, app install/start, UI input, evidence collection, and bounded logs.
- `diagnostic`: allow heavier diagnostics such as `hitrace` or broad `hilog`, still with limits.
- `forbidden`: never run destructive/system-level operations such as flash/erase/format/smode/mount unless the caller explicitly opts into a separate break-glass mode.

Suggested configuration channels:

- environment variable, for example `HARMONY_NEXT_AUTOMATION_POLICY=automation`
- CLI/tool argument, for example `--policy automation`
- repo-local config, for example `.harmony-next-policy.json`
- per-run artifact directory requirement for evidence modes

Suggested output contract:

- every gated operation records `riskLevel`, `policy`, `operation`, `target`, `artifacts`, `redactionStatus`, and `sourceCommand`
- if policy is insufficient, return a structured blocked result with required policy level
- do not prompt interactively in long automation mode

## Safety boundary to keep

This issue is not asking to remove safety classification.

The skill should still default to conservative behavior for unknown users and ad-hoc sessions. The requested change is to make the confirmation gate configurable so trusted automation can proceed without manual interruption.

The following should likely remain forbidden by default:

- `hdc target mount`
- `hdc smode`
- `hdc flash`
- `hdc erase`
- `hdc format`
- `hdc sideload`
- broad destructive clean/reset operations

## Acceptance criteria

1. The playbook distinguishes `risk level` from `interactive confirmation`.
2. Long-running automation can opt into a non-interactive policy.
3. Evidence collection can run unattended when an artifact directory and redaction policy are provided.
4. Insufficient policy returns a machine-readable blocked result instead of asking a human inline.
5. Destructive system-level operations remain forbidden unless explicitly modeled as a separate break-glass path.

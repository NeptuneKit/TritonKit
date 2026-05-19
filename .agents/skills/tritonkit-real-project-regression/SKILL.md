---
name: tritonkit-real-project-regression
description: Use when TritonKit moves from demo/self-test into a real iOS app or customer project for regression testing, adoption validation, or actual requirement discovery. Guides the AI agent to isolate external repo changes, run release CLI plus embedded runtime checks, collect machine-readable evidence, and turn real-project gaps into docs, fixes, or GitHub issues.
---

# TritonKit Real Project Regression

## Principle

Real-project validation is not the same as demo smoke. Treat the business app as an external system under test: avoid mixing its local changes into TritonKit commits, collect reproducible evidence, and keep every finding traceable to a command, output file, screenshot, or issue.

## Workflow

1. Confirm the real app, target branch, device/simulator, and the requirement being validated.
2. Check both repos before changing anything:
   - TritonKit: `git status --short --branch`
   - real app repo: `git status --short --branch`
3. Build TritonKit release CLI: `swift build -c release --product triton`.
4. Integrate TritonKit into the app only through the intended DEBUG-only package path:
   - SwiftPM or CocoaPods as requested.
   - Keep `TritonKitRequestHandler` alive for app lifetime.
   - Set `dataURL`, then `connect(host:port:)`.
5. Start server with explicit port: `triton serve --host 127.0.0.1 --port 19421`.
6. Verify connection and target identity:
   - `triton status --json`
   - `triton list --json`
7. Run observation before action:
   - `triton geometry --json`
   - `triton ax --json`
   - `triton screenshot --json --output <path>`
   - `triton export --format archive --output <path>`
8. Execute the smallest user-flow regression with machine-readable commands:
   - prefer `find`, `tap`, `type`, `input --json --summary --strict`;
   - assert expected state through a second `ax`, `find`, `screenshot`, or archive check.
9. Store outputs under `/tmp` during iteration, then copy only durable screenshots or docs into the correct `docs-linhay/spaces/<space-key>/` location when the result is worth keeping.
10. If the real app exposes a missing TritonKit capability, unclear behavior, or bug, use `tritonkit-dev-feedback` and file/prepare the GitHub issue directly.

## Boundaries

- Do not commit or revert real app repo changes unless the user explicitly asks.
- Do not treat a successful tap as completion; verify the resulting app state.
- Do not add Web/Wails UI to satisfy real-project needs when CLI/HTTP can provide the contract.
- System alerts and SpringBoard-level controls remain outside embedded runtime scope; expect `runtime_ui_interrupted` or unsupported errors.
- If the requirement becomes product work, create or update the corresponding `space` before implementation.

## Existing Regression Entrypoints

- Generic complex harness: `docs-linhay/scripts/verify-complex-harness.sh`
- Intent CLI smoke: `docs-linhay/scripts/verify-intent-cli-smoke.sh`
- Overloaded real-app smoke: `docs-linhay/scripts/verify-overloaded-triton-smoke.sh`

# Feature Index

Use this file to choose the smallest reference needed for an emulator CLI takeover task.

| Feature / Task | Read |
|---|---|
| Decide whether a capability belongs in `triton` CLI | `cli-admission-rules.md` |
| Add or change WebView-aware `act tap` / `webview.tap` | `webview-actions.md` |
| Work on `device proxy`, `sim proxy`, capture, mock, block, throttle, certs, or proxy evidence | `network-proxy.md` |
| Change `schema`, `capabilities`, output contracts, recovery commands, examples, or failure taxonomy | `schema-contracts.md` |
| Need current iOS / Android / Harmony command inventory and examples | `current-implemented-surface.md` |
| Change iOS Simulator, Android Emulator, Harmony / DevEco app lifecycle, observe, screenshot, or host actions | `platform-commands.md` |
| Update README, external integration guides, CLI/Harmony/iOS onboarding | `integration-guide-contract.md` |
| Touch workspace run, model decisions, Atlas/app-map, replay, `.tritonplan`, or evidence archive | `workspace-runs.md` |
| Plan host-side mutation, destructive action, or implementation sequence | `safety-rules.md`, then `implementation-workflow.md` |
| Choose verification commands or real emulator smoke checks | `validation.md` |

If no row fits, inspect `SKILL.md` for the core boundary and add a focused reference instead of creating a monolithic catch-all file.

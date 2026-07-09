## Real-Project Smoke Issue Closure

Use this checklist before commenting on or closing a real-project smoke issue such as iOS one-command smoke, Xcode occupancy diagnostics, WebView route checks, Harmony host-side smoke, or simulator takeover slices.

1. Confirm the implementation is on `main` and pushed to `origin/main`; reference the exact commit hash in the issue comment or session notes.
2. Confirm the relevant CLI schema exposes the capability, for example `triton schema --command smoke --json`, `triton schema --command xcode --json`, `triton schema --command app --json`, or `triton schema --command webview --json`.
3. Run the narrow unit or mock tests that own the orchestration and error shape.
4. Run at least one structured host/runtime verification that exercises the user-facing command. For iOS one-command smoke this means `triton smoke ios ... --json`; for open-url readiness it means `triton app open-url <url> --wait-ready --snapshot --json`; for Harmony host smoke this means the HDC-backed `device/app/ax/wait/screenshot` chain or `smoke harmony` when available.
5. Treat host action acknowledgements as submission evidence only. `simctl openurl`, HDC `aa start`, `xcode run`, tap, launch, or install success does not close a business smoke issue until a later `wait`, `assert`, snapshot, screenshot, or evidence result proves the expected app state.
6. Attach or summarize evidence after redaction. Public comments must avoid real app names, bundle IDs, team IDs, private paths, screenshots with personal data, full logs, credentials, and unredacted `.tritonevidence`, `.xcresult`, or HDC/Simulator dumps.
7. Update the owning `docs-linhay/spaces/<space-key>/README.md` or technical note with the current state, including which issues are still open.
8. Write memory for the decision, closure criteria, residual risks, and follow-up issues.
9. Run docs/skill sync for pure documentation closures, or the full relevant test gate for code closures.
10. Only close the issue once the issue-specific closure criteria are met. Keep epics such as simulator takeover open unless the scoped P0/P1 acceptance criteria are satisfied and remaining advanced scope has been split into follow-up issues or explicitly deferred in the closure comment.

Do not collapse multiple open issues into a single closure comment just because they share an orchestration layer. A shared implementation can close one issue and leave related issue slices open.

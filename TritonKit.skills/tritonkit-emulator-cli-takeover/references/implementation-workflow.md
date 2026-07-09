## Implementation Workflow

1. Update the relevant `space` README or technical design with BDD acceptance before code changes.
2. Add or update model/parser tests first:
   - iOS simctl argv and parser behavior;
   - Harmony hdc / aa / bm parser behavior;
   - Android adb parser behavior when that adapter lands;
   - error envelopes and destructive policy failures.
3. Implement shared contracts before CLI glue when a DTO or source-command shape is reusable.
4. Expose the CLI in a focused file under `Sources/TritonKitCLI/`, keeping JSON / JSONL as the agent-facing default.
5. Update `commandSchemas()` for every agent-facing command.
6. Sync docs and skills:
   - `README.md`;
   - `docs-linhay/dev/ai-cli-readable-control.md`;
   - current emulator takeover space;
   - `tritonkit-real-project-regression`;
   - `tritonkit-dev-feedback`;
   - memory entry.
7. If a new user-facing skill is added, include it in CI/release asset packaging and version stamping.

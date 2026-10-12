## Regression entrypoints

Use [the regression workflow](workflow.md) with the installed CLI. Repository-maintainer smoke scripts are not included in the public skill package; create a task-owned `.tritonplan` and inspect its schema-supported steps before executing it.

## Replay Plan Notes

- `.tritonplan` schema version 1 supports `tap`, `paste`, `type`, `clear`, `wait`, `screenshot`, and `evidence`.
- Use `${variable}` placeholders for account names, passwords, hosts, or output paths.
- Use `secure: true` on password-like `paste` or `type` steps; replay summaries must redact values.
- Prefer an `evidence` step at the end of a reused smoke flow so the final state is attachable to issues and regression reports.
- For stale-list regressions, pair `capture` with `assert text-not-exists <stale text> --within <right-list-bounds>` so the report contains both artifacts and a machine-readable pass/fail result.

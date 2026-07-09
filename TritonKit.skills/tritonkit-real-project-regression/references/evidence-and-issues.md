# Evidence And Issue Filing

Use this reference when collecting `.tritonevidence`, screenshots, redaction, public issue content, or closure comments.

## Evidence Collection

Prefer one-shot evidence when a report or issue needs attachable proof:

```bash
triton evidence capture --case <case> --output /tmp/<case>.tritonevidence --json
triton evidence inspect /tmp/<case>.tritonevidence --json
triton evidence summary /tmp/<case>.tritonevidence --json
triton evidence redact /tmp/<case>.tritonevidence --profile ios-private --output /tmp/<case>-redacted.tritonevidence --json
```

Inspect `primaryArtifacts[]` before traversing the full artifact set.

Store outputs under `/tmp` during iteration. Copy only durable screenshots/docs into the owning `docs-linhay/spaces/<space-key>/` when worth keeping.

## Redaction

Do not publish:

- real project names
- app names
- bundle IDs
- team IDs
- organization names
- usernames or account IDs
- email addresses or phone numbers
- internal hosts
- absolute private paths
- full private logs
- unredacted screenshots, `.tritonevidence`, `.tritonplan`, `.xcresult`, HDC/Simulator dumps, app archives, or credentials

Keep platform/tool versions, TritonKit version, command names, error codes, redacted route shape, and minimal sanitized snippets.

## Issue Closure Checklist

Before commenting on or closing a real-project smoke issue:

1. Confirm implementation is on `main` and pushed.
2. Confirm relevant schema exposes the capability.
3. Run narrow unit/mock tests.
4. Run one structured host/runtime verification for the user-facing command.
5. Treat host action acknowledgements as submission evidence only.
6. Attach or summarize redacted evidence.
7. Update owning `space` docs.
8. Write memory.
9. Run docs/skill sync or relevant test gate.
10. Close only the issue whose criteria are met.

Do not collapse multiple open issues into one closure comment just because they share an orchestration layer.

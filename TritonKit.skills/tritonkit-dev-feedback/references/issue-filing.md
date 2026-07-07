# Issue filing

Use this for ordinary feedback filing after the relevant evidence reference has been checked.

## Issue class

- `bug`: broken, unstable, misleading, unsafe, or inconsistent behavior.
- `feature`: a missing capability or requested extension.
- `docs`: unclear onboarding, examples, command help, release notes, or skill guidance.
- `question`: only when no concrete product or documentation change is identifiable yet.

## Title format

- `[Bug] <short behavior>`
- `[Feature] <short capability>`
- `[Docs] <short documentation gap>`
- `[Question] <short uncertainty>`

## Body template

```markdown
## Background
<What the user was trying to do. Mention TritonKit is in active development if relevant.>

## Current Behavior
<Observed behavior, error envelope, sanitized logs, screenshots, or command output.>

## Expected Behavior
<What should happen or what capability is needed.>

## Reproduction / Evidence
<Commands, sanitized app/simulator context, files, versions, and whether reproduction was confirmed.>

## Proposed Next Step
<Smallest useful product or engineering action.>
```

## Redaction

Replace private project names, app names, bundle IDs, team IDs, organizations, users, account IDs, emails, phone numbers, local usernames, internal domains, and absolute private paths with stable placeholders such as `<private-app>`, `<bundle-id>`, `<team-id>`, `<user>`, `<account>`, `<internal-host>`, and `<repo-path>`.

Do not attach full private logs, screenshots with personal data, unredacted `.tritonevidence`, `.tritonplan`, `.xcresult`, HDC/Simulator dumps, or app archives. Inspect manifests and artifact names first; summarize instead of attaching when redaction is uncertain.

When attaching a `.tritonplan`, keep secrets as variable placeholders and document expected `--var key-env=ENV_NAME` bindings.

## Public issue preflight

This preflight is mandatory immediately before any public `gh issue create` or `gh issue edit`.

1. Write the final issue body to a temporary Markdown file first, for example `/tmp/tritonkit-issue-body.md`. Do not pass a long body through shell quoting.
2. Scan the body file for private identifiers and absolute local paths before publishing:

   ```sh
   rg -n '(<known-private-app>|<known-private-bundle>|[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}|/Users/[^[:space:]]+|/private/[^[:space:]]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}|https?://[^[:space:]]*internal[^[:space:]]*)' /tmp/tritonkit-issue-body.md
   ```

3. Treat any match as a stop condition. Redact first, rerun the scan, and only publish after the scan is clean or every remaining match is a deliberate placeholder.
4. Use stable placeholders for identity fields: `<private-app>` for private app or project names, `<bundle-id>` for private bundle identifiers, `<simulator-target>` or `<ios-simulator-runtime-target>` for simulator/runtime targets, `<repo-path>` or `<local-path>` for absolute private paths, `<user>` for local usernames, `<team-id>` for team identifiers, and `<internal-host>` for private hosts.
5. Summarize evidence instead of attaching raw logs, screenshots, evidence bundles, crash reports, `.xcresult`, `.tritonplan`, HDC/Simulator dumps, or app archives unless redaction has been explicitly verified.
6. Include the final check result in the handoff, for example: `Redaction preflight passed: no private app name, bundle ID, simulator UDID, username, absolute path, or internal host retained.`

## Create the issue

1. Search first with a narrow phrase from the symptom and affected surface.
2. Write the issue body to a temp Markdown file.
3. Run the public issue preflight above and keep the issue body in the checked file.
4. Run `gh issue create --repo NeptuneKit/TritonKit --title "<title>" --body-file <body.md>` or `gh issue edit <number-or-url> --repo NeptuneKit/TritonKit --body-file <body.md>`.
5. Return the issue URL, local verification status, and final redaction preflight result.

If GitHub auth or network access blocks creation, report the blocker and provide the exact `gh issue create` / `gh issue edit` command and the checked body file path.

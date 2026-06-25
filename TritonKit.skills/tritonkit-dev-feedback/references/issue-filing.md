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

## GitHub workflow

1. Search first with a narrow phrase from the symptom and affected surface.
2. Write the issue body to a temp Markdown file.
3. Run `gh issue create --repo NeptuneKit/TritonKit --title "<title>" --body-file <body.md>`.
4. Return the issue URL plus the local verification status.

If GitHub auth or network access blocks creation, report the blocker and provide the exact `gh issue create` command and body.

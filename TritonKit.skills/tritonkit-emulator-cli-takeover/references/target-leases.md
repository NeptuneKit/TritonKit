# Target leases

## Prerequisites

Leases are opt-in, server-owned reservations for an explicit iOS Simulator target. Use the intended existing `triton serve` on loopback; do not stop or take over another agent's server. Discover the device, freeze its `sim:<UDID>` selector, and query the installed contract:

```bash
triton version --json
triton target list --platform ios --scope simulator --json
triton schema --command target.lease --json
```

The lease store lives in that serve process. Default TTL is 300 seconds, allowed range 30–86400. Owner is an opaque diagnostic label, not authenticated identity. A host selector and an embedded runtime target remain separate provider bindings.

## Workflow

1. Inspect before acquiring, then acquire for the authorized flow:

```bash
triton target lease status --target 'sim:<observed-UDID>' --json
triton target lease acquire --target 'sim:<observed-UDID>' --owner agent-a --ttl 300 --json
```

2. Read `lease.id`, `lease.target`, owner and expiry from the actual response. Reuse the exact token with lease-aware mutations on the same server/target, for example:

```bash
triton app open-url 'example://home' --device 'sim:<observed-UDID>' --lease '<lease.id>' --json
triton act tap --device 'sim:<observed-UDID>' --at 120,240 --lease '<lease.id>' --json
```

Check each selected command's schema for `--lease`; do not append it to arbitrary commands. Observe/wait/screenshot and business assertions remain independent proof.

3. Release only the token owned by this flow:

```bash
triton target lease release --target 'sim:<observed-UDID>' --lease '<lease.id>' --json
triton target lease status --target 'sim:<observed-UDID>' --json
```

4. If held by another owner, stop mutations and coordinate. Only when displacement is explicitly authorized:

```bash
triton target lease takeover --target 'sim:<observed-UDID>' --owner agent-b --ttl 300 --confirm --json
```

Takeover replaces the owner/token; it does not cancel an already-submitted provider action. The optional acquire/takeover field `--readonly-observation-allowed true|false` records observation policy; it is not a global barrier on all read commands.

## Verification

Inspect `ok`, `status`, nested lease and expiry, not exit status alone. Release `released=false,status=none` means no current lease was released, not that another owner was removed. Preserve `target_lease_conflict`, current owner/token metadata and suggested commands; do not manufacture a new token or retry through a no-lease path to evade the conflict.

After an action, take a fresh observation and verify its business postcondition. After timeout/unknown delivery, inspect read-only; do not resend merely because a lease expired or evidence failed.

## Limits

- Enforcement is opt-in: omitting `--lease` preserves the command's normal behavior. Read-only observation is not universally blocked by a held lease.
- Scope is not a fleet lock, cross-process authenticated owner, action deduplication system, sandbox, global Stop, or proof that no other caller touched the target. Admission/generation stores and Runner request receipts have different lifetimes.
- Server restart loses this in-memory lease state. Do not reuse a token against another server or infer absence of an in-flight action from an empty store.
- Native input, ordinary host throw paths and all CLI/HTTP entry owners are not uniformly wrapped in one receipt/lease pipeline. Read each concrete command contract; do not infer coverage from an `actionReceipt` field elsewhere.
- Physical devices, Android/Harmony resource receipts, test collection leases and XCTest Runner sessions are separate contracts.

HTTP method/body equivalents are in [local HTTP API](http-api.md); caller-side unknown-outcome recovery is in [workspace runs](workspace-runs.md).

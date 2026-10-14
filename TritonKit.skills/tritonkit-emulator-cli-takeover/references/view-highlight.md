# Optional App view highlighting

`triton highlight` is an independent optional capability. Ordinary host screenshots, inspection and supported actions do not acquire a new SDK requirement. Probe the selected App provider; do not install or inject one automatically.

```bash
triton highlight capabilities --target <target> --json
triton highlight apply --target <target> --spec highlights.json --operation-id <operation-id> --ttl 30 --json
triton highlight status --target <target> --operation <operation-id> --json
triton sim screenshot --simulator <udid> --output <highlighted.png> --json
triton highlight clear --target <target> --session <session-id> --json
```

After the probe, apply only when `capability.supported=true`. If it is false, capture an ordinary screenshot and report that highlighting was unavailable. Retain IDs from apply before taking the screenshot; even if capture fails, explicitly clear the session you created and inspect its cleanup receipt. These are separate commands; no automatic finally composition is provided.

A minimal spec:

```json
{"items":[{"markID":"primary","selector":{"identifier":"screen.primary"}}]}
```

The first provider supports Debug UIKit ordinary UIView/CALayer OID or unique identifier selectors, with optional ancestor `withinOID`; text/role selectors and reusable cell subtrees without a content epoch are unsupported. It temporarily changes real borderColor/borderWidth and retains typed original values inside the App. The default outline is #FF453A at 3 points; 1–10 nodes, default TTL 30 seconds, allowed 1–300. No nested session, permanent highlight, force restore, Android/Harmony provider or automatic screenshot composition is shipped by this slice.

Record operationID/runtimeInstanceID/sessionID. CLI exit and transport disconnection do not clear the session. A lost apply response retains operationID and reports unknown residue; reconnect and query the operation before retrying. Only admitted operations have dedupe tombstones; zero-write preflight rejection can be retried after its cause changes. Request `ok`, session state, cleanupComplete, restorationVerified and residualState describe separate facts. Main-queue opportunity is not proof that pixels were presented. Inspect the actual screenshot.

Take any report image with the existing screenshot commands, then explicitly clear **this session**. There is no screenshot `--highlight` adapter yet. Never treat image capture success as successful restoration. When business code changes one border field, clear preserves the entire current border group, exits nonzero and reports needs_attention/possible residue. Do not force old values back. If business code later resets originals or removes all owned changes, query/clear again and inspect the result; external resolution is not proof of our write-back.

App-side expiry uses a continuous clock and checks again on foreground activation. Main-thread stalls or process suspension can delay actual cleanup; waiting for TTL or losing connectivity is not evidence of restoration. Release returns typed unsupported without creating a writable session. A value-guarded provider cannot detect an unobserved same-value ABA change.

For Simulator visual evidence choose the actual display explicitly when needed: `triton sim screenshot --simulator <udid> --display 1 --output <output.png> --json`. A successful file write can still capture an inactive black display; inspect the artifact. App-layer screenshots only prove App content, not the system compositor.

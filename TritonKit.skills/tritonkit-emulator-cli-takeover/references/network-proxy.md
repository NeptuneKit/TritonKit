# Network Proxy Takeover

Use this reference when touching `triton device proxy`, `triton sim proxy`, certificate setup, proxy capture, session export, or proxy evidence.

## Boundary

Network takeover is simulator/emulator scoped. Real-device targets must return `proxy_real_device_not_supported` and must not generate mutation ledgers.

`device proxy serve` is the shared local capture / mock / block / throttle proxy for iOS Simulator, Android Emulator, and future verified Harmony proxy adapters.

## Lifecycle

Plan proxy work in this order:

1. `device proxy probe --plan-only --json`
2. `device proxy cert plan --json`
3. `device proxy cert install --confirm --audit-record <id> --execute-runner --json`
4. `device proxy serve --jsonl`
5. `device proxy start --plan-only --json`
6. `device proxy start --confirm --audit-record <id> --execute-runner --json`
7. `device proxy status --json`
8. `device proxy export --json`
9. `device proxy stop --restore-snapshot <restore-state-json> --plan-only --json`
10. `device proxy stop --restore-snapshot <restore-state-json> --confirm --audit-record <id> --execute-runner --json`

Only `device proxy serve --jsonl` is long-running. It must expose:

- `readyEvents=["proxy.serve.ready"]`
- `finalEvents=["proxy.serve.summary"]`
- `terminationSignals=["sigint","sigterm"]`

## Capture Semantics

`serve` writes `triton.proxy.capture.v1` metadata-only request events into `<dir>/requests.ndjson`.

It records method, URL, host, port, path, CONNECT tunnel metadata, and header names only. It must not store header values, bodies, decrypted TLS, or real response payloads.

`--mode record` may produce both `proxy.serve.request` and `proxy.serve.connection-failed` for the same request if upstream forwarding fails after capture.

## Session And Evidence

Persist session state at `<dir>/session-state.json` using schema `triton.proxy.session.v1`.

Archive proxy sessions with:

```bash
triton evidence capture --case <case> --include network.proxy-session --proxy-session <dir> --output <dir.tritonevidence> --json
```

Require `proxy.serve.request` before claiming traffic was observed. A HAR export is metadata-only evidence, not decrypted traffic evidence.

## Safety

- `start` / `stop` mutations require `--confirm`, `--audit-record`, and `--execute-runner`.
- iOS / Android start must preflight the proxy endpoint before mutation.
- Harmony remains probe-only until a verified proxy mutation command exists.

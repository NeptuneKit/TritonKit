# Local HTTP API and Runtime channel

## Prerequisites

This guide covers the existing local `triton serve` contract, not a public network product, Web browser write API or multi-tenant authorization layer. Default bind is `127.0.0.1:19421`; Bonjour publication is disabled unless explicitly selected. Do not expose it publicly or replace another session's server. Raw data/artifact paths are local to the server host.

```bash
triton version --json
triton schema --command serve --json
triton status --json
```

Start only if the task authorizes owning that service:

```bash
triton serve --host 127.0.0.1 --port 19421
```

CLI schema describes command contracts; there is no promise of a REST endpoint for every command or a `/schema` HTTP discovery API. Host-only CLI commands can work without serve. Embedded requests need the intended connected Debug runtime; Runner uses its own service/session rather than embedded `/input`.

## Workflow

### Establish identity and make a bounded request

```bash
curl --silent --show-error --max-time 10 'http://127.0.0.1:19421/status'
curl --silent --show-error --max-time 10 'http://127.0.0.1:19421/targets'
```

Select the exact runtime ID from that response. `/command` and `/request` take `{type,target,payload?}`; payload is the Codable Data **base64 string of encoded typed JSON**, not an arbitrary nested object. For a request without payload:

```bash
curl --silent --show-error --max-time 10 -H 'Content-Type: application/json' \
  --data '{"type":"hierarchy","target":"<observed-runtime-target>"}' \
  'http://127.0.0.1:19421/request'
```

`/command` returns a queued message ID/type; it does not wait for or prove the runtime result. `/request` waits for the matching runtime payload and can time out. Body targeting differs from `/input?target=...`, which takes one typed input object directly (for example `type=tap` plus coordinates). Query values must be URL-encoded. Prefer high-level CLI actions when they already own selection, lease and postcondition handling.

### Route inventory for the current local service

| Method | Path | Selection/body and result boundary |
| --- | --- | --- |
| GET | `/health`, `/status` | Transport health versus structured service/runtime/discovery status; health alone is not App readiness |
| GET | `/targets`, `/runtime/registrations` | Runtime inventory/registration facts; do not infer host or business readiness |
| POST / GET | `/data`, `/data/:id` | Upload bytes / fetch stored bytes; respect Content-Type and artifact identity, not a universal `ok` JSON |
| GET | `/hierarchy/latest` | `target` query; latest available hierarchy may be absent/stale |
| GET | `/geometry`, `/accessibility`, `/screenshot` | Targeted runtime observation; inspect returned metadata/artifact source and Content-Type |
| POST | `/hit` | Targeted typed hit-test request; hit selection is not input dispatch |
| POST | `/command`, `/request` | Typed command envelope with target in body; queued acknowledgement versus awaited runtime response |
| POST | `/input` | Runtime target in query, typed input body; no automatic business verification or replay |
| GET | `/`, `/web/device`, `/simulators/:id` | Existing readonly page entry, not action authorization |
| GET | `/web/targets`, `/web/target-registry` | Runtime/host display inventory; candidate-only stays candidate-only |
| GET | `/web/geometry`, `/web/screenshot` | Web presentation adapters; retain source/scope/fidelity rather than treating as a raw runtime alias |
| GET | `/web/ios-simulator/framebuffer`, `/web/android/framebuffer`, `/web/harmony/framebuffer` | Provider-specific capture/stream prerequisites and display/geometry guards |
| POST | `/workspace/run` | Workspace run DTO; target/launch/observation, optional inference and action gates remain independent |
| GET | `/workspace/runs/:runId` | Inspect one stored run; optional `runsDir`/`runs-dir` query |
| POST | `/workspace/runs/:runId/stop` | Request stop of that run, not a global provider cancellation barrier |
| POST | `/workspace/runs/:runId/export-flow` | Export DTO/file mutation, not test execution |
| POST | `/workspace/runs/:runId/merge-map` | Merge DTO/map mutation; inspect confirmation separately |
| GET | `/v1/app-map/inspect`, `/v1/app-map/paths`, `/v1/app-map/screens`, `/v1/app-map/transitions`, `/v1/app-map/health` | Required `map` query points to a server-local `.tritonmap`; CLI pagination flags are not automatically HTTP parameters |
| GET | `/v1/app-map/path`, `/v1/app-map/suite` | Required `map` plus path ID for path, optional suite (default smoke) for suite |
| POST | `/v1/app-map/suite/run` | Required `map`, `evidenceRoot`; optional suite/target/host/port/VLM fields; real test side effects require authorization |
| POST | `/v1/test-recorder/sessions` | Start explicit-event recording DTO (`platform`, `caseName`, `output`) |
| POST | `/v1/test-recorder/sessions/:sessionId/events`, `/v1/test-recorder/sessions/:sessionId/stop` | Append `{kind,payload}` object / stop the observed session |
| POST | `/v1/test-recorder/cases/inspect`, `/compile`, `/proposals`, `/match-page`, `/replay-dry-run`, `/replay`, `/matrix` | Paths are full `/v1/test-recorder/cases/<operation>`; typed case DTOs, offline analysis/replay boundaries remain |
| POST / GET | `/v1/device/runner/doctor`, `/v1/device/runner/status` | Explicit `device`; GET also admits `sessionRoot`/bounded timeout query |
| POST | `/v1/device/runner/prepare`, `/start`, `/stop`, `/request`, `/receipt` | Full Runner prefix for every operation, explicit device and operation-specific fields; authenticated Runner session/allowlist/receipt, not embedded input |
| POST | `/v1/device/command` | Closed device command arguments envelope, described below; not arbitrary argv |
| POST | `/v1/target-leases/acquire`, `/release`, `/takeover`, `/check` | Full lease prefix for every operation; body target plus owner/TTL or lease token as applicable |
| GET | `/v1/target-leases/status` | Exact target query; lease state alone does not establish business outcome |

Use the corresponding command's schema/CLI where this table does not define a full operation-specific DTO. Do not send guessed fields to a mutation endpoint. API catalogs and byte-valid JSON alone do not prove a provider supports that operation.

### Closed device command adapter

`POST /v1/device/command` requires exactly one `arguments` array (1–80 bounded strings, total body ≤64 KiB). Its allowlist is `orientation/fold/location/clipboard/foreground/recording/logs/crashes/tap/double-tap/press/swipe`; `type`, installation and arbitrary commands are not admitted merely because CLI has them. Supply one explicit `--device`; no `all`, help, worker, JSONL or output-format override. The server prepends `device` and normalizes one `--json`.

```json
{"arguments":["foreground","--platform","android","--device","android:<observed-serial>"]}
```

CLI `ok:false` is returned as the original JSON (HTTP 409), not erased in another wrapper. Invalid requests, output truncation and missing single-JSON responses have their own HTTP errors.

### Lease DTOs

Acquire uses `{target,owner,ttlSeconds?,readonlyObservationAllowed?}`; release/check use `{target,leaseID}`; takeover adds `confirm:true` and owner/optional TTL. See [target leases](target-leases.md) for safe acquire→action→release and conflict handling. Runner DTO/action examples and live prerequisites are in [Runner regression](../../tritonkit-real-project-regression/SKILL.md#bundled-ios-runner-regression).

## Verification

Check HTTP status **and** actual payload/error, provider outcome, partial/truncation and verification fields. Successful HTTP or schema parsing is not business success. `/request` may return the runtime's own payload instead of a new CLI envelope; `/command` is submission-only. A timeout or unknown outcome can follow delivery: inspect state/receipt read-only before deciding, never automatically replay.

For Workspace/map/recorder, preserve source artifacts, run verdicts and data paths; for captures, check actual bytes/format/dimensions/scope and manifest fidelity. Use [Workspace](workspace-runs.md), [App-map](app-map.md), [test recorder](../../tritonkit-real-project-regression/references/test-recorder.md) and [evidence validation](validation.md) rather than assuming a common pass flag.

## Limits

`/web/input`, `/web/node-property`, `/web/host-input`, `/web/command` and similar browser-write adapters return readonly refusals. Packaged/source Web preview paths and `/web/*/mjpeg` compatibility names have their own frontend server routing; port 34127 and serve port 19421 are not interchangeable services. See [Web preview](web-preview.md).

A loopback bind, optional lease and process-local admission/generation stores do not provide a hostile-host sandbox, authenticated multi-user owner, global Stop or fleet deduplication. Raw business values are retained within provider/collection limits; public sharing and remote inference need separate authorization. Body/output budgets are route-specific, not a blanket hard limit on every endpoint. Newer APIs may be absent from an installed older release; retain its unsupported/404/error evidence and use only a supported, authorized path.

# P11 HTTP API Thin Wrapper

## Goal

为 App Map inspection 和 suite runner 暴露本机 HTTP JSON route，让 agent 可以在长运行 `triton serve` 下通过 HTTP 读取和触发同一套 CLI/core 能力。

P11 是 thin wrapper：HTTP 不定义新业务语义，不领先 CLI，不新增 Web/Wails 控制面。

## Scope

Read-only routes:

- GET /v1/app-map/inspect?map=<dir.tritonmap>
- GET /v1/app-map/paths?map=<dir.tritonmap>
- GET /v1/app-map/screens?map=<dir.tritonmap>
- GET /v1/app-map/transitions?map=<dir.tritonmap>
- GET /v1/app-map/path?map=<dir.tritonmap>&path=<pathId>
- GET /v1/app-map/health?map=<dir.tritonmap>
- GET /v1/app-map/suite?map=<dir.tritonmap>&suite=smoke

Execution route:

- POST /v1/app-map/suite/run

The POST body mirrors the CLI options:

- map: required .tritonmap directory
- suite: optional, defaults to smoke
- evidenceRoot: required output directory
- target: optional, defaults to triton:local
- host / port: optional, default to the current serve host and port
- allowVLM / allowRemoteVLM / vlmBaseURL / vlmModel / vlmAPIKeyEnv: optional VLM passthrough flags

## Out of Scope

- No new App Map semantics.
- No new runner primitive.
- No auth, multi-tenant API, remote agent, device cloud, SSE, HTML report, or Web/Wails workflow.
- No HTTP-only operation unavailable from CLI.

## Error Contract

- Missing query/body fields return HTTP 400 with `ok=false` and `error.code=invalid_payload`.
- App Map runtime failures return HTTP 409 with the same App Map failure code family used by CLI, including `unconfirmed_path` and `non_replayable_path`.
- Suite run failures return a normal `triton.app-map.suite-run-result` JSON body with `ok=false`; the HTTP status is 409.

## Verification

- Targeted compile/test: `swift test --package-path CLI --filter AppMapPathGraphTests`.
- Live HTTP smoke with `triton serve`:
  - `GET /v1/app-map/inspect` returns `triton.app-map.inspect-result`.
  - `GET /v1/app-map/paths` returns the confirmed `path-fixture-login-home` with `observedRuns=2/passCount=2`.
  - `GET /v1/app-map/suite` returns smoke suite membership.
  - missing `map` returns HTTP 400 `invalid_payload`.
  - empty POST body returns HTTP 400 `invalid_payload`.

## Verdict

P11 status: implemented with read-only live HTTP smoke and POST validation smoke. Full suite execution through HTTP is intentionally not re-run here because P10 already produced the real simulator pass/failure suite-run evidence, and rerunning from the current Home state would intentionally produce a failure merge.

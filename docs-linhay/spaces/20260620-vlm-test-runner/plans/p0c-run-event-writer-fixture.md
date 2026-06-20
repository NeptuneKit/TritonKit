# P0C Run Event Writer + Dedicated Fixture App

## Goal

P0C 只为未来 runner 准备可审计执行地基：

- 有一个专用 `TritonKitTestFixture`，用稳定 visible text 和 `accessibilityIdentifier` 证明 AX/text observation 可以被测试系统依赖。
- 有 `.tritonevidence/run/run.json` 与 `.tritonevidence/run/events.jsonl` 契约，证明未来 runner 可以把动作、断言、截图、失败串进 evidence。
- 现有 `evidence inspect/summary` 可以读回 run 概览。

P0C 不是 `triton test run`。这一步完成后只打开 P0D minimal runner execution。

## Scope

Included:

- Dedicated fixture app: `Examples/TritonKitTestFixture`.
- Run metadata: `.tritonevidence/run/run.json`.
- Append-only event log: `.tritonevidence/run/events.jsonl`.
- Event schema/unit tests.
- Pass/failure events sample.
- Real iOS Simulator fixture smoke evidence.
- Evidence summary exposes run event count.

Explicitly excluded:

- `triton test run`.
- Step executor.
- selector retry / healing.
- App Map, `screens.json`, `transitions.json`.
- remote VLM.
- AI assertion.
- replay evidence.
- HTML report.

## Fixture Contract

`TritonKitTestFixture` uses bundle id `com.neptunekit.tritonkit.testfixture` and DEBUG-only embedded TritonKit bootstrap. The runtime host defaults to `127.0.0.1:19421`.

| Screen | Stable Text | Stable Identifier | Transition |
|---|---|---|---|
| Login | `Fixture Login` | `fixture.login.title` | `Go Home` -> Home |
| Home | `Fixture Home` | `fixture.home.title` | buttons to Settings, Delayed, List, Error, Alert |
| Settings | `Fixture Settings` | `fixture.settings.title` | `Back Home` -> Home |
| Delayed Loading | `Fixture Loading` then `Fixture Loaded` | `fixture.delayed.loading` / `fixture.delayed.loaded` | 0.5s deterministic state change |
| Dynamic List | `Fixture Dynamic List`, `Fixture Item 1...8` | `fixture.list.item.<n>` | fixed list content |
| Error State | `Fixture Error State`, `Fixture Error Message` | `fixture.error.title`, `fixture.error.message` | `Retry Home` -> Home |
| Modal / Alert | `Fixture Modal`, `Fixture Modal Message` | UIKit alert text | close action |

Implementation note: fixture renders the primary test surface through UIKit controls inside the SwiftUI app shell. This is deliberate because the P0A smoke showed SwiftUI-only title exposure was not stable enough for exact AX text.

## Run Metadata Contract

Path:

```text
.tritonevidence/run/run.json
```

Shape:

```json
{
  "schemaVersion": 1,
  "kind": "triton.test.run",
  "runId": "run-p0c-fixture-pass-001",
  "source": "manual-primitive-smoke",
  "status": "passed",
  "startedAt": "2026-06-20T08:32:53Z",
  "endedAt": "2026-06-20T08:32:57Z",
  "durationMs": 4000,
  "planRef": null,
  "evidenceManifestRef": "../manifest.json"
}
```

Status values:

- `running`
- `passed`
- `failed`
- `blocked`

## Event Log Contract

Path:

```text
.tritonevidence/run/events.jsonl
```

Rules:

- One compact JSON event per line.
- Append-only.
- First event must be `run.started`.
- Event type uses dot-style names.
- `schemaVersion` must be `1`.
- `run.finished` closes the log.

Required event types:

| Type | Required Fields |
|---|---|
| `run.started` | `schemaVersion`, `type`, `runId`, `timestamp` |
| `step.started` | plus `stepIndex`, `stepId`, `stepType` |
| `command.executed` | plus `stepIndex`, `command`, `status`, `exitCode` |
| `artifact.created` | plus `stepIndex`, `kind`, `ref` |
| `assertion.result` | plus `stepIndex`, `status`, `selector` |
| `step.finished` | plus `stepIndex`, `stepId`, `status`, `durationMs` |
| `run.finished` | plus `status`, `durationMs` |
| `failure.recorded` | plus `stepIndex`, `failure.type` |

## Evidence Samples

Pass sample:

```text
docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0c-fixture-pass.tritonevidence/
```

Key facts:

- `run/run.json` status is `passed`.
- `run/events.jsonl` has 13 events.
- Assertions cover `Fixture Login` and `Fixture Home`.
- Artifacts include screenshot, AX, hierarchy, status, targets, version.
- `evidence summary` exposes `run.eventCount=13` and `summary.verdict=success`.

Failure sample:

```text
docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0c-fixture-failure.tritonevidence/
```

Key facts:

- `run/run.json` status is `failed`.
- `run/events.jsonl` has 10 events.
- Missing text assertion is `Definitely Not Existing`.
- Command exit code is `1`.
- `failure.recorded.failure.type=assertion_failed`.
- Failure artifacts include screenshot, AX, and hierarchy.
- `evidence summary` exposes `run.eventCount=10` and `summary.verdict=failure`.

## Real Simulator Smoke

Target:

```text
triton:ios-simulator:0333546D-2AC6-4C22-AF01-293E2F4BA5BC
```

Fixture app:

```text
TritonKitTestFixture
com.neptunekit.tritonkit.testfixture
```

Executed hard chain:

```text
triton schema --command xcode --json
triton schema --command sim --json
triton list --json
triton tap "Back to Login" --target <fixture-target> --json
triton wait --target <fixture-target> --text "Fixture Login" --timeout 10 --json
triton screenshot --target <fixture-target> --output .../20260620-cli-p0c-fixture-login-uikit-stable-v01.png --metadata
triton hierarchy --target <fixture-target> --json --output .../20260620-p0c-fixture-login-hierarchy.json
triton ax --target <fixture-target> --json --with-hierarchy --output .../20260620-p0c-fixture-login-ax.json
triton assert text-exists "Fixture Login" --target <fixture-target> --json
triton assert text-exists "Definitely Not Existing" --target <fixture-target> --json
triton evidence --target <fixture-target> --output .../20260620-p0c-fixture-failure.tritonevidence --include status,list,version,hierarchy,ax,screenshot --json
triton tap "Go Home" --target <fixture-target> --json
triton wait --target <fixture-target> --text "Fixture Home" --timeout 10 --json
triton assert text-exists "Fixture Home" --target <fixture-target> --json
triton evidence --target <fixture-target> --output .../20260620-p0c-fixture-pass.tritonevidence --include status,list,version,hierarchy,ax,screenshot --json
```

Observed smoke facts:

| Fact | Evidence | Verdict |
|---|---|---|
| CLI can bind the fixture target | `triton list --json` shows fixture target connected | pass |
| Fixture launches with embedded runtime | `status --json` returns `runtime=embedded`, `connected=true` | pass |
| AX exact text finds Login/Home | `assert text-exists "Fixture Login"` and `"Fixture Home"` both pass | pass |
| Failure is machine-readable | missing text assertion returns `ok=false`, exit code `1` | pass |
| Failure does not break evidence | failure bundle still captures screenshot, AX, hierarchy | pass |
| Events are readable by summary | `evidence summary` exposes `run.eventCount` | pass |
| Runner can remain thin later | actions/assertions are represented as event rows | pass-with-gap |

## Tests

Focused tests:

```bash
swift test --package-path CLI --filter RunEventWriterTests
swift test --package-path CLI --filter EvidenceBundleTests/summaryExposesP0CRunEventOverview
```

Verification on 2026-06-20:

| Command | Result |
|---|---|
| `swift test --package-path CLI --scratch-path /tmp/triton-p0c-cli-verify --filter RunEventWriterTests` | pass, 3 tests |
| `swift test --package-path CLI --scratch-path /tmp/triton-p0c-cli-verify --filter EvidenceBundleTests/summaryExposesP0CRunEventOverview` | pass, 1 test |
| `swift test --package-path CLI --scratch-path /tmp/triton-p0c-cli-verify --filter TestValidationTests` | pass, 7 tests |
| `swift test --filter TKTestRunEventModelsTests` | blocked by unrelated root `Tests/TritonKitTests/TKDisplayItemTests.swift` compile errors |
| `git diff --check` | pass |
| `docs-linhay/scripts/check-docs.sh` | blocked by unrelated missing README at `docs-linhay/spaces/20260619-issue-68-harmony-app-target-failure` |

Root shared tests exist in `Tests/TritonKitSharedTests/TKTestRunEventModelsTests.swift`, but full root `swift test` is currently blocked by unrelated existing compile errors in `Tests/TritonKitTests/TKDisplayItemTests.swift`. P0C validation therefore uses the CLI package focused tests that compile the shared model through the CLI path dependency.

## Verdict

P0C verdict: `pass-with-gap`.

Allowed next step:

- P0D minimal runner execution for P0B-supported steps only: `launch`, `takeScreenshot`, `tap(point)`, `assertVisible(text)`.

Still blocked:

- remote VLM.
- AI assertions.
- selector healing.
- App Map.
- HTML report.
- replay evidence.

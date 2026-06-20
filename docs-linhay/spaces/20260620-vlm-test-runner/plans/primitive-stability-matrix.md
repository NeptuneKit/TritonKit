# Primitive Stability Matrix

## Goal

证明 TritonKit 现有 primitive 是否足以支撑 test runner 作为薄编排层。
Runner 不应该重新实现设备控制。
如果某个 primitive 不满足稳定性要求，必须先修 primitive，再进入 runner。

## Scope

Covered primitives:

- launch
- screenshot
- hierarchy
- accessibility / AX
- tap
- input
- assert visible
- evidence package
- replay / dry-run

Out of scope:

- remote VLM
- AI assertion
- selector healing
- App Map merge
- HTML report
- autonomous loop

## Verdict Values

Verdict 只允许以下值：

- `pass`
- `pass-with-gap`
- `blocker`
- `unknown`

禁止使用“基本可用”“看起来可以”“大概稳定”等模糊判断。

## Smoke Run

本轮使用现有 `Examples/TritonKitDemo` 作为临时 fixture。它不是最终测试 fixture：没有 Login、Home、Settings、Delayed Loading、Dynamic List、Error State、Modal / Alert。因此本轮 smoke 验证 primitive 链路，不验证最终 runner 业务 fixture。

Evidence root:

```text
docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0a-smoke/
```

Pass evidence:

```text
docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0a-pass.tritonevidence/
```

Failure evidence:

```text
docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0a-failure.tritonevidence/
```

Real simulator:

```text
id: sim:1B360513-22E7-46DB-A942-198EE522C6DC
udid: 1B360513-22E7-46DB-A942-198EE522C6DC
name: Overloaded-v2 Dedicated iPhone 16 Pro
runtime: iOS 26.5
state: Booted
```

Smoke chain actually executed:

```text
triton serve
-> triton device list --platform ios
-> triton xcode run Demo app
-> triton status/list
-> screenshot + geometry + hierarchy + AX
-> assertVisible("Complex harness: 0")
-> tap "Primary"
-> assertVisible("Complex harness: 1")
-> point tap center of Primary
-> assertVisible("Complex harness: 2")
-> focus text field
-> type "p0a"
-> assertVisible("mode=Inspect progress=50 count=2 switch=off text=p0a")
-> evidence package
-> assertVisible("Definitely Not Existing") failure
-> failure evidence package
-> evidence inspect/summary
-> record template
-> replay dry-run validation failure without vars
-> replay dry-run pass with vars
```

## Core Matrix

| Primitive | Existing Entry | CLI | HTTP | Evidence | Real Simulator Smoke | Known Gap | Verdict |
|---|---|---|---|---|---|---|---|
| launch | `triton xcode run`, `triton app launch` | yes | no direct `/app` endpoint | xcode JSONL and post-launch evidence | pass | launch ack does not prove business readiness; current fixture is not Login/Home | `pass-with-gap` |
| screenshot | `triton screenshot`, `triton sim screenshot` | yes | `/screenshot`, `/web/screenshot` | `screenshot.png`, `screenshot.json` | pass | runtime screenshot output is point-sized PNG while geometry keeps `scale=3`; host screenshot orientation may differ | `pass-with-gap` |
| hierarchy | `triton hierarchy` | yes | `/hierarchy/latest`, `/request` | `hierarchy.json`, `archive.json` | pass | refresh/cache semantics need runner policy; not all visible SwiftUI text is equally useful for assert | `pass-with-gap` |
| AX/text observation | `triton ax`, `triton find`, `triton assert` | yes | `/accessibility`, `/request` | `ax.json` | pass-with-gap | `TritonKit Demo` visible title failed AX assert; exact match only, no OCR | `pass-with-gap` |
| tap | `triton tap`, `triton sim tap` | yes | `/input` for runtime; host sim via CLI | action JSON sample plus post-action evidence | pass | query tap can return multiple candidates; runner must require disambiguation when needed | `pass-with-gap` |
| input | `triton type`, `triton paste`, `triton input` | yes | `/input` | resulting state captured by evidence | pass | focused input works; runner must make focus/target explicit | `pass-with-gap` |
| assertVisible | `triton assert text-exists` | yes | no dedicated assert endpoint; uses `/accessibility` internally | assertion result JSON; failure evidence captured separately | pass-with-gap | AX first is stable for harness labels but not all visible text; OCR explicitly out of P0 | `pass-with-gap` |
| evidence package | `triton evidence`, `triton capture` | yes | no `/evidence`; CLI composes HTTP/runtime artifacts | `.tritonevidence` manifest + artifacts | pass | evidence does not automatically include every prior action result unless runner writes run events | `pass-with-gap` |
| replay dry-run | `triton record`, `triton replay --dry-run` | yes | no HTTP replay endpoint | `.tritonplan` and replay result JSON | pass-with-gap | `record` is template-only; replay consumes `.tritonplan`, evidence consumption is via `evidence inspect/summary` | `pass-with-gap` |

Overall verdict: `pass-with-gap`.

Runner can likely be a thin orchestrator, but only if P0B starts with validate-only and P0C writes run events into existing `.tritonevidence/run/`. Full runner execution must wait until selector, coordinate, fixture, and action-event evidence gaps are closed.

## launch

### Current implementation

- Entry: `triton xcode run`, `triton app launch`
- Command: `triton xcode run --project Examples/TritonKitDemo/TritonKitDemo.xcodeproj --scheme TritonKitDemo --configuration Debug --simulator 1B360513-22E7-46DB-A942-198EE522C6DC --derived-data-path .triton/DerivedData/p0a-vlm-test-runner --timeout 180 --jsonl`
- HTTP: no direct `/app` launch endpoint; runtime readiness is observed via `/status` and `/targets`
- Output schema: xcode JSONL progress plus final `xcode.run` summary
- Artifact path: `evidence/20260620-p0a-smoke/bootstrap/xcode-run-demo.jsonl`

### Evidence sample

```bash
./.build/cli/debug/triton xcode run \
  --project Examples/TritonKitDemo/TritonKitDemo.xcodeproj \
  --scheme TritonKitDemo \
  --configuration Debug \
  --simulator 1B360513-22E7-46DB-A942-198EE522C6DC \
  --derived-data-path .triton/DerivedData/p0a-vlm-test-runner \
  --timeout 180 \
  --jsonl
```

Expected artifact:

```text
evidence/20260620-p0a-smoke/bootstrap/xcode-run-demo.jsonl
```

Observed:

- final `ok=true`
- `bundleID=com.neptunekit.tritonkit.demo`
- `appPath=.triton/DerivedData/p0a-vlm-test-runner/Build/Products/Debug-iphonesimulator/TritonKitDemo.app`
- post-launch `triton status --json` returned `connected=true`, `targetConnectionState=connected`, `targetCount=1`

### Stability notes

- launch only proves app process submission.
- business readiness still needs `status`, `wait`, `assert`, screenshot, or evidence.
- existing Demo app auto-connects embedded Triton runtime after launch.

### Verdict

`pass-with-gap`

## screenshot

### Current implementation

- Entry: `triton screenshot`
- Command: `triton screenshot --output <path.png> --json`
- HTTP: `/screenshot`
- Output schema: `{ bytes, format, height, output, scale, width }`
- Artifact path: `evidence/20260620-p0a-smoke/pass-before.png`, `pass-after.png`, `pass-after-point.png`, `input-after-type.png`

### Evidence sample

```bash
./.build/cli/debug/triton screenshot \
  --output docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0a-smoke/pass-before.png \
  --json
```

Expected artifact:

```text
evidence/20260620-p0a-smoke/pass-before.png
evidence/20260620-p0a-smoke/pass-screenshot-before.json
```

Observed:

```json
{
  "format": "png",
  "width": 402,
  "height": 874,
  "scale": 1
}
```

Geometry at the same time:

```json
{
  "bounds": { "x": 0, "y": 0, "width": 402, "height": 874 },
  "safeArea": { "top": 62, "left": 0, "bottom": 34, "right": 0 },
  "scale": 3,
  "orientation": "portrait"
}
```

### Stability notes

- coordinate space: runtime tap points and screenshot PNG dimensions both observed as 402x874 for this embedded runtime screenshot path.
- image size: screenshot output is point-sized PNG, not physical 1206x2622 pixels.
- orientation: portrait.
- simulator/device difference: host-side `sim screenshot` may still produce raw framebuffer orientation; runner must not assume host screenshot and runtime screenshot share identical transform.

### Verdict

`pass-with-gap`

## hierarchy

### Current implementation

- Entry: `triton hierarchy`
- Command: `triton hierarchy --json`
- HTTP: `/hierarchy/latest`, `/request` with runtime hierarchy request
- Output schema: runtime hierarchy JSON
- Artifact path: `evidence/20260620-p0a-smoke/pass-hierarchy-before.json`, `pass-hierarchy-after.json`, `20260620-p0a-pass.tritonevidence/hierarchy.json`

### Evidence sample

```bash
./.build/cli/debug/triton hierarchy --json
```

Expected artifact:

```text
evidence/20260620-p0a-smoke/pass-hierarchy-before.json
evidence/20260620-p0a-pass.tritonevidence/hierarchy.json
```

### Stability notes

- hierarchy capture succeeds once embedded runtime is connected.
- evidence package also exports `archive.json`, which includes hierarchy-related data.
- runner must define whether each step refreshes hierarchy or accepts latest cache.

### Verdict

`pass-with-gap`

## AX/text observation

### Current implementation

- Entry: `triton ax`, `triton find`, `triton assert`
- Command: `triton ax --json`, `triton find <text> --all --json`
- HTTP: `/accessibility`
- Output schema: `[TKAXNode]`, `TKTapTargetResolution`, `TKUIAssertResult`
- Artifact path: `evidence/20260620-p0a-smoke/pass-ax-before.json`, `pass-find-primary-before.json`, `pass-assert-title-before.json`

### Evidence sample

```bash
./.build/cli/debug/triton assert text-exists "Complex harness: 0" --json
```

Expected artifact:

```text
evidence/20260620-p0a-smoke/pass-assert-count0-before.json
```

Observed pass:

- `ok=true`
- `query=Complex harness: 0`

Observed gap:

```bash
./.build/cli/debug/triton assert text-exists "TritonKit Demo" --json
```

Output:

```json
{
  "ok": false,
  "query": "TritonKit Demo",
  "count": 0,
  "nearestText": ["Host", "127.0.0.1", "Port", "19421", "Overview"]
}
```

### Stability notes

- first source for `assertVisible(text)` is AX/accessibility.
- matching is exact.
- OCR is not used and should remain out of P0.
- not every visually present SwiftUI text is proven stable in AX sample.

### Verdict

`pass-with-gap`

## tap

### Current implementation

- Entry: `triton tap`
- Command: `triton tap Primary --index 1 --json`; `triton tap --x 191.8 --y 329.3 --json`
- HTTP: runtime `/input`; host simulator tap remains CLI host-side
- Output schema: input action result JSON
- Artifact path: `evidence/20260620-p0a-smoke/pass-tap-primary.json`, `pass-tap-primary-point.json`

### Evidence sample

```bash
./.build/cli/debug/triton find Primary --all --json
./.build/cli/debug/triton tap Primary --index 1 --json
./.build/cli/debug/triton assert text-exists "Complex harness: 1" --json
./.build/cli/debug/triton tap --x 191.8 --y 329.3 --json
./.build/cli/debug/triton assert text-exists "Complex harness: 2" --json
```

Expected artifact:

```text
evidence/20260620-p0a-smoke/pass-find-primary-before.json
evidence/20260620-p0a-smoke/pass-tap-primary.json
evidence/20260620-p0a-smoke/pass-assert-count1-after.json
evidence/20260620-p0a-smoke/pass-tap-primary-point.json
evidence/20260620-p0a-smoke/pass-assert-count2-after-point.json
```

Observed:

- text tap returned `ok=true`, `message=Dispatched UIControl.touchUpInside`
- point tap returned `ok=true`, `targetOID=122`, `activationClassName=UIButton`
- post text assertion changed from `Complex harness: 0` to `Complex harness: 1`
- post point assertion changed to `Complex harness: 2`

### Stability notes

- text query returned 2 candidates: AX `UIButton` and hierarchy text `UIButtonLabel`.
- `--index 1` selected the AX button candidate.
- runner should fail or require disambiguation for multi-candidate selectors unless selector policy explicitly chooses first.
- point tap proved runtime point coordinate can hit the same button for this screenshot/geometry path.

### Verdict

`pass-with-gap`

## input

### Current implementation

- Entry: `triton type`, `triton paste`, `triton input`
- Command: `triton type p0a --exact --json`
- HTTP: `/input`
- Output schema: input action result JSON
- Artifact path: `evidence/20260620-p0a-smoke/input-type-p0a.json`, `input-assert-summary-p0a.json`

### Evidence sample

```bash
./.build/cli/debug/triton find "Triton type target" --all --json
./.build/cli/debug/triton tap "Triton type target" --index 1 --json
./.build/cli/debug/triton type p0a --exact --json
./.build/cli/debug/triton assert text-exists "mode=Inspect progress=50 count=2 switch=off text=p0a" --json
```

Expected artifact:

```text
evidence/20260620-p0a-smoke/input-find-textfield.json
evidence/20260620-p0a-smoke/input-tap-textfield.json
evidence/20260620-p0a-smoke/input-type-p0a.json
evidence/20260620-p0a-smoke/input-assert-summary-p0a.json
```

Observed:

- text field found through AX as `UITextField`, `identifier=ComplexHarnessTextField`
- type result returned `ok=true`, `insertedLength=3`, `targetClassName=UITextField`
- summary assertion returned `ok=true`

### Stability notes

- focused input path works.
- runner must make focus/target explicit; otherwise typed text depends on current first responder.
- secure input redaction path was not tested in this smoke.

### Verdict

`pass-with-gap`

## assertVisible

### Current implementation

- Entry: `triton assert text-exists`
- Command: `triton assert text-exists <text> --json`
- HTTP: no dedicated assert endpoint; command requests `/status` and runtime `accessibility`
- Output schema: `TKUIAssertResult`
- Artifact path: `evidence/20260620-p0a-smoke/pass-assert-count1-after.json`, `fail-assert-missing-text.json`

### Evidence sample

```bash
./.build/cli/debug/triton assert text-exists "Complex harness: 1" --json
./.build/cli/debug/triton assert text-exists "Definitely Not Existing" --json
```

Expected artifact:

```text
evidence/20260620-p0a-smoke/pass-assert-count1-after.json
evidence/20260620-p0a-smoke/fail-assert-missing-text.json
```

Observed pass:

- `ok=true`
- `count=1`
- `targetConnectionState=connected`
- `hierarchyCacheState=active`

Observed failure:

- command exit code: non-zero
- `ok=false`
- `message=Expected text to exist: Definitely Not Existing`
- `nearestText[]` populated
- `suggestedCommands[]` includes `triton find ...` and `triton screenshot --json`

### Stability notes

- failure reason is machine-readable.
- failure screenshot/evidence is not automatic today; runner must call evidence capture on failed step.
- AX exact matching is usable but not enough for all visible text.

### Verdict

`pass-with-gap`

## evidence package

### Current implementation

- Entry: `triton evidence`, `triton capture`
- Command: `triton evidence --output <dir.tritonevidence> --include status,list,version,hierarchy,ax,screenshot,geometry,archive --json`
- HTTP: no `/evidence`; CLI composes `/status`, `/targets`, `/request`, screenshot image retrieval, and local files
- Output schema: `TKEvidenceManifest`
- Artifact path: `evidence/20260620-p0a-pass.tritonevidence/`, `evidence/20260620-p0a-failure.tritonevidence/`

### Evidence sample

```bash
./.build/cli/debug/triton evidence \
  --name p0a-pass \
  --output docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0a-pass.tritonevidence \
  --include status,list,version,hierarchy,ax,screenshot,geometry,archive \
  --json
```

Expected artifact:

```text
20260620-p0a-pass.tritonevidence/manifest.json
20260620-p0a-pass.tritonevidence/status.json
20260620-p0a-pass.tritonevidence/targets.json
20260620-p0a-pass.tritonevidence/version.json
20260620-p0a-pass.tritonevidence/hierarchy.json
20260620-p0a-pass.tritonevidence/ax.json
20260620-p0a-pass.tritonevidence/screenshot.png
20260620-p0a-pass.tritonevidence/screenshot.json
20260620-p0a-pass.tritonevidence/geometry.json
20260620-p0a-pass.tritonevidence/archive.json
```

Observed pass and failure manifests:

- `ok=true`
- artifact kinds: `status`, `list`, `version`, `hierarchy`, `ax`, `screenshot`, `screenshot-metadata`, `geometry`, `archive`
- `skipped=[]`
- target: `TritonKitDemo`, `com.neptunekit.tritonkit.demo`, `targetConnectionState=connected`
- cli: `version=0.1.0-dev`, `schemaVersion=1`

Consumption commands:

```bash
./.build/cli/debug/triton evidence inspect <dir.tritonevidence> --json
./.build/cli/debug/triton evidence summary <dir.tritonevidence> --json
```

Consumption artifacts:

```text
evidence/20260620-p0a-smoke/pass-evidence-inspect.json
evidence/20260620-p0a-smoke/pass-evidence-summary.json
evidence/20260620-p0a-smoke/fail-evidence-inspect.json
evidence/20260620-p0a-smoke/fail-evidence-summary.json
```

### Stability notes

- evidence package is immutable directory-shaped artifact.
- action results from earlier commands are not automatically embedded in `manifest.json`.
- runner should write `.tritonevidence/run/events.jsonl` so steps, tool calls, assertions, and screenshots are tied together.

### Verdict

`pass-with-gap`

## replay / dry-run

### Current implementation

- Entry: `triton record`, `triton replay`
- Command: `triton record --output <file.tritonplan> --json`; `triton replay <file.tritonplan> --dry-run --var ... --json`
- HTTP: no replay endpoint
- Output schema: `TKRecordPlanResponse`, `TKReplayResult`
- Artifact path: `evidence/20260620-p0a-smoke/replay-template.tritonplan`, `replay-template-dry-run-pass.json`

### Evidence sample

```bash
./.build/cli/debug/triton record \
  --output docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0a-smoke/replay-template.tritonplan \
  --json

./.build/cli/debug/triton replay \
  docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260620-p0a-smoke/replay-template.tritonplan \
  --dry-run \
  --var username=demo@example.com \
  --var password=demo-password \
  --json
```

Expected artifact:

```text
evidence/20260620-p0a-smoke/record-template.json
evidence/20260620-p0a-smoke/replay-template.tritonplan
evidence/20260620-p0a-smoke/replay-template-dry-run.json
evidence/20260620-p0a-smoke/replay-template-dry-run-pass.json
```

Observed:

- dry-run without variables failed with machine-readable `validation_failed`, `Missing replay variable: username`
- dry-run with variables returned `ok=true`, `dryRun=true`, `stepCount=8`, `executedCount=8`
- secure password value was redacted in generated command output

### Stability notes

- `record` is template-only, not interactive recording.
- `replay --dry-run` consumes `.tritonplan`, not `.tritonevidence`.
- `.tritonevidence` consumption is currently `evidence inspect/summary`.
- first runner slice should use normalized-plan rerun; evidence-transition replay and map-path replay are later concepts.

### Verdict

`pass-with-gap`

## P0A Done Definition

P0A is done only when all of the following are true:

1. `primitive-stability-matrix.md` exists and each primitive has one allowed verdict.
2. one real simulator pass smoke evidence exists.
3. one real simulator failure smoke evidence exists.
4. current `.tritonevidence` manifest samples exist.
5. current hierarchy / AX samples exist.
6. coordinate notes cover screenshot pixel/point, tap point, scale, and orientation.
7. matrix explicitly says whether runner can remain a thin orchestrator.

Current status:

- matrix exists: yes
- pass smoke evidence exists: yes
- failure smoke evidence exists: yes
- manifest samples exist: yes
- hierarchy / AX samples exist: yes
- coordinate notes exist: yes
- thin-runner verdict: `pass-with-gap`

Not sufficient for P0A:

- schema-only proof
- mock-only proof
- unit tests without real simulator
- docs-only judgment

## Runner Decision

Runner may proceed only as validate-only P0B next.

Do not start full runner execution yet. Before `triton test run`, close these gaps:

1. dedicated test fixture app with Login/Home/Settings/Delayed/List/Error/Modal
2. explicit selector policy for multi-candidate text matches
3. coordinate transform contract for runtime screenshot, host screenshot, VLM image input, tap point, scale, and orientation
4. run event writer that links actions/assertions/screenshots into `.tritonevidence/run/events.jsonl`

Remote VLM, AI assertion, selector healing, App Map merge, HTML report, and autonomous loop remain out of scope.

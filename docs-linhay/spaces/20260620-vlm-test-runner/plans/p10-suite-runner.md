# P10 Suite Runner

## Goal

让 .tritonmap 中已确认、可回放的 suite path 变成可批量执行的本机测试资产。

P10 只实现 suite 级编排：

- .tritonmap suite
- export-flow
- triton test run
- new .tritonevidence
- project-workspace
- merge back into same .tritonmap
- health backfill

它不扩展 runner primitive，也不改变 P8 的 path confirmation 语义。

## Scope

新增命令：

triton map suite run <dir.tritonmap> --suite smoke --target <target> --evidence-root <dir> --json

支持范围：

- 只执行 suite 中的 confirmed + replayable path。
- 每个 path 先导出为 .tritontest.yaml，再复用现有 triton test run。
- 每次 path run 生成独立 .tritonevidence。
- 每个成功生成 run events 的 evidence 自动执行 project-workspace。
- 每个 evidence merge 回同一个 .tritonmap，并保持 --confirm。
- suite policy stopOnFailure 为 true 时，首个失败 path 后停止。
- 输出 machine-readable per-path result。

## Out of Scope

- 不新增 runner step。
- 不实现 tap(text)、selector healing、AI assertion、HTML/JUnit、CI report。
- 不新增 screens / transitions 语义。
- 不做 HTTP API wrapper。
- 不做 parallel suite execution。
- 不跳过 P8：unconfirmed / non-replayable path 仍不可进入 suite run。

## Output Contract

- ok: suite 是否全部通过。
- kind: triton.app-map.suite-run-result。
- suiteId: 已执行的 suite id。
- evidenceRoot: 导出 flow 与 evidence bundle 的根目录。
- status: passed 或 failed。
- pathCount / passedCount / failedCount: suite 执行计数。
- stoppedOnFailure: suite policy 是否触发停止。
- results[]: 每个 path 的 pathId、status、flow、evidenceDir、runId、failure。

## Failure Semantics

- Unconfirmed path: fail with unconfirmed_path.
- Non-replayable path: fail with non_replayable_path.
- Validation or runner failure: recorded in the path result as failed.
- If the runner produced evidence with run events, P10 still attempts projection and merge so map health can see the failed run.
- Unsupported steps remain validation errors inside triton test run; P10 does not bypass validation.

## BDD

### Scenario: suite runner replays a confirmed path

- Given a .tritonmap contains one confirmed replayable smoke path.
- When triton map suite run <map> --suite smoke --target <target> --evidence-root <dir> --json runs.
- Then Triton exports the path to a .tritontest.yaml flow.
- And executes that flow through triton test run.
- And creates a new .tritonevidence.
- And projects screen workspace from the evidence.
- And merges the evidence back into the same .tritonmap.
- And the suite run response reports the path as passed.

### Scenario: suite runner stops on failure

- Given suite policy stopOnFailure=true.
- And the first path fails.
- When the suite is run.
- Then the response reports failedCount=1.
- And stoppedOnFailure=true.
- And later paths are not executed.

### Scenario: unconfirmed path is rejected

- Given a path exists in the map but is not confirmed.
- When the path is added to a suite or run through suite runner.
- Then Triton returns unconfirmed_path.
- And no device operation is triggered for that path.

## Implementation Notes

- TKAppMapSuiteRunResponse and TKAppMapSuiteRunPathResult are the stable JSON result models.
- runTritonAppMapSuite is the runtime orchestration entry.
- The live CLI uses TKLiveTestRunPrimitiveExecutor.
- Tests use an injected fake executor to prove export, run, projection, merge, and health backfill without requiring simulator availability.

## Verification

Targeted checks:

- swift test --package-path CLI --filter AppMapPathGraphTests
- swift test --package-path CLI --filter SchemaFactSourceTests --filter SchemaFactSourceCapabilityTests --filter SchemaFactSourceTaxonomies --filter SchemaFactSourceWorkflowTests

Final gate remains the collective verification for the current large slice:

- swift test --package-path CLI
- git diff --check
- docs-linhay/scripts/check-docs.sh

## Verdict

P10 status: implemented and validated with targeted tests, full CLI tests, schema/capability smoke, and a real iOS Simulator suite run pass smoke.

Real smoke evidence:

- Pass evidence root: docs-linhay/spaces/20260620-vlm-test-runner/evidence/20260621-p10-suite-run.tritonevidence-root
- Generated flow: evidence/20260621-p10-suite-run.tritonevidence-root/flows/001-path-fixture-login-home.tritontest.yaml
- Generated run: run-1f45eb68-cfb9-4a0b-b204-58e481bb8049
- Map health after durable pass merge: observedRuns=2, passCount=2, failCount=0.
- Failure smoke was verified separately by running the suite from Home state; it returned ok=false, failedCount=1, stoppedOnFailure=true, failure.type=assert_visible_failed, and exit code 1. That temporary failure run was not kept in the long-lived .tritonmap because its evidence root was /tmp.

This opens P11 HTTP API Thin Wrapper only after the full local CLI test gate is clean.

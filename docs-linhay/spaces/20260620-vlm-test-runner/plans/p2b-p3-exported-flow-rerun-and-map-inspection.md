# P2B-P3 Exported Flow Re-run Gate and App Map Inspection

## Goal

P2B 证明 App Map 里的 path 不是一次性 YAML 生成物，而是可以导出、重跑、回灌，并更新健康度的测试资产。

P3 在此基础上补齐 agent/CLI 可读的地图检查能力，让后续 AI/agent 不依赖 HTML，也能回答 screen、transition、path、suite 和 coverage gap。

## P2B Scope

Required chain:

```text
export-flow
-> validate
-> real triton test run
-> new .tritonevidence
-> project-workspace
-> merge back into same .tritonmap
-> inspect / paths health update
```

Implemented contract behavior:

- Same path id must not be duplicated after re-run merge.
- Map-level health is counted from `runs/*.json`.
- Path-level health is counted from `path.sourceRuns`.
- Re-merging the same run id must not double count path health.
- Failure evidence without a successful transition updates map run health but does not pollute the successful path.

## P3 Scope

New read-only commands:

```bash
triton map screens <dir.tritonmap> --json
triton map transitions <dir.tritonmap> --json
triton map path show <dir.tritonmap> --path <path-id> --json
triton map health <dir.tritonmap> --json
triton map suite inspect <dir.tritonmap> --suite smoke --json
```

These commands are offline and read only. They do not execute runner steps, touch devices, call VLM, heal selectors, or generate reports.

## Output Semantics

`map screens` answers:

- What screens exist?
- What visible text identifies each screen?
- Which runs observed a screen?

`map transitions` answers:

- What action edges exist?
- Which screens they connect?
- Whether the trigger is replayable.

`map path show` answers:

- Which screens and transitions form a path?
- Whether the path is confirmed and replayable.
- Path health across source runs.

`map health` answers:

- Global observed run health.
- Failing / unconfirmed / unreplayable paths.
- Screens not in any path.
- Transitions not covered by any suite path.

`map suite inspect` answers:

- Which paths are in a suite.
- The path health and replayability for each suite member.

## Out of Scope

- Remote VLM.
- AI assertion.
- `tap(text)`.
- input / swipe / scrollUntilVisible.
- selector healing.
- HTML / JUnit.
- Cross-version visual merge.
- AI screen naming.
- autonomous exploration.

## Done Definition

- `AppMapPathGraphTests` covers re-run merge health and P3 read-only operations.
- `SchemaFactSourceTests` covers command schema/capability taxonomy.
- Real fixture smoke starts Triton server, launches `TritonKitTestFixture`, runs exported flow, writes new evidence, projects workspace, merges back into the same `.tritonmap`, and verifies no duplicate path.
- Failure evidence merge increments map failure health but leaves the successful path health unchanged.
- README and memory record P2B/P3 status and any runtime smoke blocker.

## Smoke Result

Executed against `TritonKitTestFixture` on iOS Simulator `0333546D-2AC6-4C22-AF01-293E2F4BA5BC`.

Observed:

- Exported flow validated successfully.
- `triton test run` generated `evidence/20260621-p2b-rerun.tritonevidence`.
- New evidence projected to `screenCount=2`, `transitionCount=1`.
- Merge back into `.tritonmap-p2b` kept `pathCount=1` and `pathIDs=[\"path-fixture-login-home\"]`.
- After re-run, map health was `observedRuns=2`, `passCount=2`, `failCount=0`.
- Path health was `observedRuns=2`, `passCount=2`, `failCount=0`.
- After merging failure evidence, map health became `observedRuns=3`, `passCount=2`, `failCount=1`.
- Successful path health stayed `observedRuns=2`, `passCount=2`, `failCount=0`.

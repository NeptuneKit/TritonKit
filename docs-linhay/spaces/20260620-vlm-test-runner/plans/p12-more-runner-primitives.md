# P12 More Runner Primitives

## Goal

补齐 deterministic runner 的最小 text tap 能力，让测试 flow 可以表达常见的 `tap(text/source=ax/match=exact)`，同时保持 selector 边界克制。

## Scope

新增支持：

- `tap.text`
- `source: ax`
- `match: exact`

执行语义：

- validate / normalize 将 `tap.text` 转为 normalized plan selector。
- live runner 只从 AX nodes 做 exact text resolution。
- 执行前后与 point tap 一样记录 `observation.captured`。
- 找不到 AX exact text target 时返回 `text_not_found`，并保留 selector。
- input 失败时返回 `tap_failed`。

## Out of Scope

- 不做 id / index / relationship selector。
- 不做 selector healing。
- 不做 hierarchy fallback、OCR fallback 或 VLM fallback。
- 不做 regex / contains match。
- 不做 scrollUntil + tap 组合语义。

## BDD

- Given a `.tritontest.yaml` step has `tap.text`, `source=ax`, `match=exact`.
- When `triton test validate` runs.
- Then normalized plan contains a tap selector with text/source/match.
- When `triton test run` executes the plan.
- Then runner resolves the AX exact text target, sends the tap input request, and writes before/after observations.

## Verification

- `swift test --package-path CLI --filter TestValidationTests --filter TestRunExecutionTests` passes 17 tests.

## Verdict

P12 status: implemented at the smallest useful selector surface. It opens selector foundation work without enabling healing, hierarchy fallback, OCR, or VLM fallback.

# SP-150 Reliability Failure Recovery Semantics

> 状态：已完成（本地）
>
> Branch：`feat/SP-150-reliability-failure-recovery-semantics`
>
> 基线：`feat/SP-146-stage1-metric-contract@ab0daf99`

## 目标

收紧 Stage 1 reliability gate 的终态 failure 解释：已知的 failure type 不仅要有 recovery family 和同一终态步骤的 artifact，还必须与该终态 step type 语义一致。

当前按 failure type 单独映射 recovery；例如篡改后的 `tap` terminal step 带 `assert_visible_failed`，会获得 assertion recovery 并计入 ECR/FER。此 slice 使该类跨步骤伪解释 fail closed。

## 边界

- 仅改 `CLITestReliabilityRuntime.swift` 的离线 evidence 分析与 `TestReliabilityRuntimeTests.swift`；不改真实 test runner 写入的 failure taxonomy、receipt/anchor/identity chain、collection sampler、schema、testrec、Web/HTTP、Android 或 embedded runtime。
- terminal step type 必须从已验证的 `normalized-plan.json` 按 terminal `stepIndex` 取得，不能信任可篡改 event 字段；`launch_failed` 是每个已支持 executor 的 lazy runtime resolve 结果，允许落在任一已支持 step。
- `primitive_failed` 与未知/VLM 透传 failure type 没有可验证的步骤语义或 contract-backed recovery，保持 `missing_failure_recovery` 并不计 ECR/FER；步骤专属已知 type 必须精确匹配 terminal step type。
- 不启动 `triton serve`、Simulator、Xcode、设备或真实 `test run`；测试只写独立 Swift scratch 与合成临时 evidence。
- `20260722-issue-164-evidence-simulator-screenshot-fidelity` dirty worktree 继续只读隔离。

## BDD

1. Given terminal plan step 是 `tap`，When failure record 声称 `assert_visible_failed` 且 artifacts/timeline 均正确，Then evidence 仍标记 `terminal_failure_type_step_mismatch`，不计 ECR 或 FER。
2. Given terminal plan step 是 `assertVisible` 且同样的 assertion failure 有正确 terminal artifact，When report 分析，Then 保持可解释并计入对应指标。
3. Given terminal plan step 任意且 runner 只报告 `primitive_failed`，When report 分析，Then 它没有 contract-backed recovery，标记 `missing_failure_recovery`，不计 ECR 或 FER。
4. Given `launch_failed` 落在任一已支持 terminal step，When report 分析，Then 保持 preflight recovery 可解释；Given failure type 没有已知 recovery，Then 既有 `missing_failure_recovery` 语义保持，不以新的 mismatch 伪装未知 taxonomy。

## 验收与停止条件

- 先补上述红灯回归，再最小实现 terminal step type 归因和 mismatch issue；该 issue 必须使 evidence completeness 与 failure explainability 同时失败。
- 相关 focused tests 至少覆盖 `TestReliabilityRuntimeTests`、`TestReliabilityHarnessTests`、`TestReliabilityCollectionRuntimeTests` 与 `FailureDiagnosticsTests`，使用独立 `CLI/.build/sp150-reliability-failure-recovery-semantics` scratch；随后做 release `triton` build、diff/docs 检查。
- 若需要改 runner 的实际 failure 类型、既有 receipt 格式、真实采样或集成 SP-141/142/147/148，则停止并另行裁决。

## 实现与验证

- 红灯先证明旧实现会把跨类型 assertion failure 计为完整、可解释 evidence；最小实现改为从 validated normalized plan 的 terminal `stepIndex` 获取权威 type，以 pair allowlist 判定 recovery，并将 `terminal_failure_type_step_mismatch` 纳入 completeness invalidator。
- `primitive_failed` 已从 recovery allowlist 移除；未知/VLM 透传 type 继续返回 `missing_failure_recovery`。现有合法 assertion fixtures 已显式建模为 `assertVisible`，避免测试 fixture 自身伪造不匹配语义。
- 已覆盖 event type 与 plan type 故意对立时仍以 plan 断言 mismatch、两种跨类型 failure、action/assertion 两种 `primitive_failed`、未知 VLM type、未来 AI assertion 对立，以及 14 个 canonical terminal step 上的 `launch_failed` 兼容性。
- 验证通过：`TestReliabilityRuntimeTests` 35 项；`TestReliabilityRuntimeTests|TestReliabilityHarnessTests|TestReliabilityHarnessRuntimeTests|TestReliabilityCollectionRuntimeTests|TestReliabilityIdentityChainTests|FailureDiagnosticsTests` 共 81 项；独立 release scratch 的 `triton` build；`git diff --check`。
- 未启动 `triton serve`、Simulator、Xcode、设备或真实 runner，未读取或修改 #164。`check-docs.sh` / `verify.sh --ci-docs` 已如预期在 `SP-143-reliability-gate-integrity` 报既有连续编号门禁（本线未含 SP-141 / SP-142 / SP-147～SP-149 的并行登记项）；本 slice 不伪造占位或放宽 checker。

## 后续

- 已完成本地 checkpoint 后，仍须在用户授权的 integration worktree 以届时 main 重审 SP-143→146→150 链；本 slice 不合并、不推送。

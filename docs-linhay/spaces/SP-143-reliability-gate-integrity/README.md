# SP-143 Reliability Gate Integrity

## 状态

- 状态：已完成（本地 checkpoint）。
- 负责人：Codex。
- Branch：`feat/SP-143-reliability-gate-integrity`。
- Worktree：`../TritonKit-worktrees/SP-143-reliability-gate-integrity/`。
- 基线：`main@d016979d`。

## 裁决

**Adopt：只有 receipt-backed collection 才有资格给出 Stage 1 的 `gate=passed`；legacy `--samples` 保留为离线诊断输入，但固定为不可作为门禁结论。**

SP-140 已冻结 receipt、target、slot、reset 与 evidence sidecar，但 `test reliability --samples` 仍能直接以可变私有样本得到通过结论；negative control 也曾将任意 nonpassed terminal status 当作成功，且不同 flow/slot 可以同时驱动同一 collection。SP-143 将 legacy 输入明确降级为 `legacy-diagnostic`，把 report 的权威来源和 Stage 1 eligibility 作为机器可读字段，并补齐 negative taxonomy 与 collection-wide execution lease。与此同时，observation artifact 必须存在、匹配 manifest kind，并由同一步在 `command.executed` 之后、`observation.captured` 之前创建；终态 failure ref 也必须满足对应 step 时序，不能借用无关 artifact 抬高 ECR 或 FER。

## 边界

包括：

- `test reliability --samples` 继续可读取私有 legacy sample set、输出脱敏指标，但固定含 `receipt_required` blocker，不能产出 canonical passed gate。
- `test reliability --collection-receipt` 仍是唯一可能产生 `gate=passed` 的路径；report 明确输出 authority / Stage 1 eligibility。
- private negative control 必须冻结 `expectedFailureType`，且计划只能由非 optional 的 `launch` / `takeScreenshot` 前缀和 terminal `assertVisible` 或 `assertNotVisible` 组成；它只有在 terminal `.failed` 且实际 type 精确匹配 `assert_visible_failed` / `assert_not_visible_failed` 时才是 `ok=true`。blocked、stopped、launch、transport、primitive、AI、visual、任何写操作或 optional 前缀失败都不合格。
- 每个 sample 在读取 reset receipt 后、触碰 target resolver 或 runner 前，必须原子取得 receipt-root 的 `.reliability-active-sample` lease；其他 flow/slot 返回 `reliability_collection_busy`。正常返回只 `rmdir` 自己的空 lease；进程中断留下 stale lease，保持 fail-closed，绝不自动删除或重试。
- observation 的 `screenshot`、`ax`、`hierarchy` 分别只接受 manifest 的 `screenshot`、`accessibility`、`hierarchy` artifact，且每个 ref 都必须由同一步在该 step 的 command 后、该 observation 前创建。
- terminal failure 的 artifact refs 必须由同一终态失败 step 在 `command.executed` 与 `failure.recorded` 之间创建并声明。
- focused parser/schema/output-contract/reliability tests，且只用临时合成 evidence。

不包括：

- 任何 Simulator、App、server、Xcode、真实 `test run` 或 live 3×20+1 采样。
- receipt/reset/evidence 的签名、远端不可抵赖性或 hostile-filesystem 防护；这些仍是未来独立安全空间。
- receipt digest 外部锚定、可机器验证的 reset/runtime identity、以及 Stage 1 分母（60 supported 或 61 total）的文档裁决；这些是 live 前仍需完成的 P1，不在本 slice 伪装解决。
- workspace、testrec executor、Android、Web/Wails、#164 dirty evidence WIP，或对 SP-141/SP-142 的合并。

## BDD 验收

1. Given 61 份格式完整、但仅来自 legacy `--samples` 的样本，When 评估 reliability，Then report 保留诊断指标但 authority 为 legacy、eligibility 为 false、gate blocked 且含 `receipt_required`。
2. Given receipt-backed collection 的 61 个 sidecar/evidence 全部完整，When 评估，Then authority 为 receipt-backed、eligibility 为 true，且只有该路径可得到 `gate=passed`。
3. Given observation 把 `normalized-plan.json` 或其他已声明却错误 kind 的 artifact 冒充 screenshot/AX/hierarchy，或借用上一 step / command 前创建的 ref，When 评估，Then 标记 `observation_artifact_kind_mismatch` 或 `observation_artifact_step_mismatch`，不计 ECR。
4. Given terminal failure 使用上一 step 或 command 前创建的 artifact ref，When 评估，Then 标记 `terminal_failure_artifact_step_mismatch`，不计 FER/ECR。
5. Given 正常 runner 在 command 后、observation 前产出的同 step screenshot/accessibility/hierarchy 和 failure ref，When 评估，Then 既有 receipt-backed gate 保持兼容。
6. Given 一个 negative control 声明任意非 assertion failure type、使用 optional 前缀，或其计划含 tap/input/press/swipe/AI/visual 写入或不确定性，When preflight/reserve，Then 立即 fail closed，不创建 receipt。
7. Given negative runner 的 terminal status 是 blocked/stopped，或 `.failed` 但 type 为 launch/primitive/错误 assertion/缺失 failure，When sample，Then 仅输出 typed `ok=false` / exit 1；receipt report 也以 `negative_control_failure_type_mismatch` 阻断 gate。
8. Given 同一 receipt 的一个 sample 正在等 target 或执行，或遗留 `.reliability-active-sample`，When 另一个不同 flow/slot sample，Then 在其 target resolver 前返回 `reliability_collection_busy`，不自动清理 lease。

## 验证与停止条件

- 先添加上述 red tests，再做最小 runtime/model/schema 改动。
- 仅运行独立 scratch 的 `TestReliabilityRuntimeTests`、`TestReliabilityHarnessTests`、`TestReliabilityHarnessRuntimeTests`、`TestReliabilityCollectionRuntimeTests` 与必要 schema/contract tests，随后 `git diff --check` 与 docs check。
- 由于 SP-141/SP-142 已有待集成本地 checkpoint，本分支新增 SP-143 后的 docs 连号检查预期会报告缺 141/142；不得伪造或复制它们的登记。授权集成顺序仍为 SP-141 → SP-142 → SP-143 后统一复跑。
- 不启动 runtime/服务/设备；若实现要求真实 sampling、改动 #164 或更改 Stage 1 门槛，立即停止并重新裁决。

## 验证记录

- 纯离线、独立 `.build/sp143-reliability-gate-integrity` scratch 串行通过：`TestReliabilityRuntimeTests` 33、`TestReliabilityCollectionRuntimeTests` 4、`TestReliabilityHarnessTests` 16、`TestReliabilityHarnessRuntimeTests` 3、`TestRunExecutionTests` 9、`FailureDiagnosticsTests` 13、`SchemaFactSourceCapabilityTests` 22、`TestCreateFromSessionTests` 2、`PublicSkillCommandSchemaTests` 1；release `triton` build 通过。
- TDD 先复现并修复：optional negative-prefix 曾被接收；observation artifact 曾可借用上一 step 或 step command 前创建的文件。现在两类输入均使 ECR fail closed。
- `TestValidationTests` 的 10 个纯解析/schema 用例通过；其余 6 个既有 subprocess contract 用例硬编码 `CLI/.build/debug/triton`，与本 slice 的独立 scratch 约束冲突，报 `Missing triton executable`。未为绕过它写入默认 scratch。
- `SchemaFactSourceContractTests` 仍只报既有 device/sim app-console registry 6 项不一致；本 slice 的 output/failure/recovery taxonomy 已由 focused schema tests 覆盖。
- `git diff --check` 通过。`check-docs.sh` 与 `verify.sh --ci-docs` 如预期停在 `SP-143` 连号缺口：SP-141 / SP-142 尚是隔离的待集成本地 checkpoint；本 branch 未伪造其登记。
- 未启动或查询 Simulator、App、server、Xcode、设备或真实 `test run`；#164 dirty evidence worktree 未读取或修改。

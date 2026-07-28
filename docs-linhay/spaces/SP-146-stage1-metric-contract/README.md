# SP-146 Stage 1 Metric Contract

## 状态

- 状态：已完成（本地、纯离线公开合同）。
- 负责人：Codex。
- Branch：`feat/SP-146-stage1-metric-contract`。
- Worktree：`../TritonKit-worktrees/SP-146-stage1-metric-contract/`。
- 基线：`feat/SP-145-private-identity-chain-v2@50c89bea`。

## 裁决

**Adopt：保留既有顶层 ECR/FER/ORR 字段的编码和语义兼容性；仅为 receipt-backed report 增量公开两个不可混淆的 cohort summary。**

- **Stage 1A — supported reliability：** 三个 `supported` flow 的 60 个 receipt-frozen slot。ECR-A 只以 complete supported slot 为分子、60 为分母；完整性沿用一次全局 duplicate/core evidence analysis，因此跨 flow 重复 evidence、reset 或 run identity 也会扣减 A；ORR-A 只以 complete supported slot 的稳定签名为分母。
- **Stage 1B — receipt/control integrity：** 全部 61 个 receipt slot（含一个 expected negative control）。分子同时要求 receipt→binding→reset→plan→target→manifest/outcome→SP-145 private identity-chain 验证与同一份 core evidence 完整性；FER-B 只以 terminal `failed` / `blocked` receipt sample 为分母，包含 expected negative。
- 最终 `gate` 仍是聚合 verdict：Stage 1A 与 Stage 1B 都必须满足既有严格条件。该切片不放宽三 flow 每 flow 20 complete、expected negative 精确失败类型、receipt anchor 或 identity-chain 门槛。

这只是报告时的 cohort/metric 语义澄清，不是 3×20+1 已采集或 Stage 1 已通过的声明。

## 边界

包括：

- 仅在 `gateAuthority=receipt-backed` 时填充嵌套 `stage1.stage1A` / `stage1.stage1B` 的 privacy-safe count、metric 与 stage verdict；legacy `--samples` 的模型值为 `nil` 且 JSON 省略 `stage1`，不伪装成 canonical Stage 1 评估。
- 保留既有顶层 `evidenceCompleteness`、`failureExplainability`、`outcomeRepeatability`、`identityChain` 与 aggregate `gate`，不重定义既有 API 字段。
- 把 60 supported 的 ECR/ORR 与 61 receipt/control integrity、FER 公开分层；不暴露 receipt hash、artifact path、target、UDID、bundle、flow、run/reset identity 或 evidence 内容。
- 同步 CLI schema、README、路线图、public agent skill、space/index/memory，并用合成 private evidence 做 BDD/TDD。

不包括：

- 不启动/探测/停止 server，不访问 Simulator、Xcode、设备或真实 `test run`；不创建、修改、清理或回填真实 receipt/evidence。
- 不改变 SP-144 anchor、SP-145 identity-chain 算法、reset/App/runtime attestation、ECR/FER/ORR 既有字段编码、门槛数值或 live harness 行为。
- 不扩 testrec、workspace、Android、Harmony、Web/Wails，且不读取或修改 #164 WIP。

## BDD 验收

1. Given 60 个 complete supported slot 与一个 exact expected negative control，When receipt-backed report 生成，Then `stage1A` 明示 60 supported ECR/ORR，`stage1B` 明示 61 receipt/control integrity 与 FER，aggregate gate 才可 passed。
2. Given 60 个 supported slot 健康但 negative 缺失、意外 passed、failure taxonomy 不匹配或 identity-chain 无效，When report 生成，Then Stage 1A 可保持健康而 Stage 1B/aggregate 必须 blocked；不得把 negative 静默混入 supported ECR/ORR。
3. Given supported slot 缺失或非预期失败，When report 生成，Then Stage 1A 的 expected/complete/ORR cohort 明确，且既有每 flow 20 complete gate 不被 95% rate 放宽。
4. Given legacy `--samples`，When report 生成，Then 既有顶层诊断字段保持兼容，`stage1` 模型值为 `nil` 且 JSON 字段缺席，`receipt_required` 仍阻断 aggregate gate。
5. Given schema 与 JSON report，When agent 读取它，Then 能机器判别 Stage 1A/1B population、counts、metrics 与 blockers，且没有私有 identity 泄露。
6. Given cross-flow duplicate identity 或 negative manifest/runtime drift，When report 生成，Then A 的全局完整 slot count 或 B 的 61-slot integrity 必须扣减；harness 不得用 preflight target 回填或覆盖 runner manifest 来掩盖漂移。

## 验证与停止条件

- 先补 report/harness/schema 的失败测试，再最小实现；只串行使用独立 `CLI/.build/sp146-stage1-metric-contract` scratch。
- 预期执行 `TestReliabilityRuntimeTests`、`TestReliabilityHarnessTests`、`TestReliabilityHarnessRuntimeTests`、`TestValidationTests`、schema/capability/public skill tests、release build、dynamic schema 和 docs checks。
- `SchemaFactSourceContractTests` 的既有 device/sim registry 6 项，以及 SP-141 / SP-142 未集成造成的 docs 连号门禁，只记录为基线；不得用本 slice 的 placeholder、whitelist 或语义放宽掩盖。
- 若实现需要改变 live sample、anchor/chain format、现有 top-level metric 语义、真实环境所有权或公开私有证据，立即停止并另建裁决 space。

## 完成证据

- focused BDD/TDD：`TestReliabilityHarnessTests` 23、`TestReliabilityRuntimeTests` 33、`TestReliabilityHarnessRuntimeTests` 4、`TestReliabilityIdentityChainTests` 2、`TestValidationTests` 18、`FailureDiagnosticsTests` 13、`SchemaFactSourceCapabilityTests` 22、`PublicSkillCommandSchemaTests` 1、`TestRunExecutionTests` 9 全部通过。
- release `triton` 已在独立 scratch 编译；实际 `schema --command test --json` 已确认 receipt-backed `stage1`、Stage 1A 60-slot 与 Stage 1B 61-slot 字段及完整性说明。
- 终审已确认全局 duplicate、manifest/core completeness 与 runner manifest preservation 三项 P1 均已关闭；`git diff --check` 通过。
- 已知非本 slice 阻断：`SchemaFactSourceContractTests` 仍复现既有 device/sim registry 的 6 个 assertion failure；`check-docs.sh` 与 `verify.sh --ci-docs` 因 SP-141/SP-142 尚未集成、连续性在 SP-143 处停止。未创建 placeholder 或放宽门禁。

## 后续队列

1. 在 SP-146 local contract checkpoint 完成后，才向用户申请 dedicated Simulator、server ownership、reset recipe、safe negative control 与 private evidence lifecycle 的真实 3 × 20 + 1 授权。
2. 没有上述授权前，不推进 testrec/workspace/Android/Web 或 live sampling；只做非运行时的可靠性/事实债收口。

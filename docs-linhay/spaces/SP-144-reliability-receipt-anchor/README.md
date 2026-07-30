# SP-144 Reliability Receipt Anchor

## 状态

- 状态：本地完成（纯离线；未合并、未推送）。
- 负责人：Codex。
- Branch：`feat/SP-144-reliability-receipt-anchor`。
- Worktree：`../TritonKit-worktrees/SP-144-reliability-receipt-anchor/`。
- 基线：`feat/SP-143-reliability-gate-integrity@33ad1f9d`。

## 裁决

**Adopt：reserve 输出 raw `collection-receipt.json` bytes 的 SHA-256；receipt-backed sample 与 report 必须接收由 operator/CI 在 receipt root 外保存的预期 SHA-256，再执行任何 reset、lease、target、runner 或 evidence 扫描。**

SP-140/143 的 receipt、binding、reset 与 evidence sidecar 能校验 root 内的结构自洽，但它们都以当前 receipt bytes 重新计算 FNV 关联值。若整份 receipt 被替换为另一份结构正确的私有 receipt，现有链条没有 root 外的稳定参照。本 space 增加显式的 operator-owned expected SHA-256；它是完整性锚点，不是签名、身份认证、远端 ledger 或 hostile-filesystem 防护。

## 边界

包括：

- `reliability-reserve` 在保留既有 FNV `receiptDigest` 作为 reset/binding 内部关联值的同时，返回 canonical lowercase `receiptSha256`。
- `reliability-sample` 需要 `--expect-receipt-sha256 <64-lowercase-hex>`，并在读取 reset receipt、claim collection lease、解析 target、创建 slot 或调用 runner 前比较 raw receipt bytes。
- receipt-backed `reliability --collection-receipt` 同样需要该 expected anchor，并在扫描任何 evidence 前比较；legacy `--samples` 保持诊断输入，不要求 anchor，且继续固定 blocked。
- 缺失、格式错误或不匹配均返回单一脱敏 JSON failure envelope；不回显 input path、预期/实际 hash、target、UDID、bundle、selector 或 evidence 内容。
- schema、output contract、failure taxonomy、focused tests 和公开 agent 文档同步说明：只有调用方把 reserve 输出保存在 receipt root 外的独立可信状态时，anchor 才提供跨 root 的替换检测。

不包括：

- 签名、密钥、nonce、远端服务、ledger、CI secret、外部 anchor 文件格式或身份/不可抵赖设计。
- 对抗性文件系统、目录替换、symlink TOCTOU、evidence 本身篡改或并发攻击模型。
- reset 实际发生证明、runtime/app build identity、Stage 1 指标分母裁决、真实 Simulator/server/Xcode/test run、Android、Web/Wails、testrec executor 或 #164 dirty evidence WIP。

## BDD 验收

1. Given reserve 后调用方在 root 外保留 `receiptSha256`，When root 内 receipt 被替换成另一份内部自洽的有效 receipt，Then sample 在 reset/lease/resolver/runner 前以 anchor mismatch 停止。
2. Given 同一替换，When receipt-backed report 被请求，Then 在读取 evidence 前以单一 anchor failure 停止，绝不输出 `gate=passed`。
3. Given correct canonical SHA-256 和完整的合成 receipt/sample/evidence，When sample 或 report 执行，Then 既有 receipt-backed contract 保持可用；legacy `--samples` 仍无需 anchor 且固定 `receipt_required` blocked。
4. Given anchor 缺失、长度错误、非小写 hex 或 hash 不匹配，When JSON command 执行，Then stdout 仅含一个脱敏 error envelope，并且没有 target resolver、lease、slot 或 runner 副作用。
5. Given schema consumer，When 查询 `test` contract，Then `reliability` 表示 `--samples` 或 `--collection-receipt` 加 expected anchor 的条件组合，`reliability-sample` 将 anchor 标为必填；恢复建议只允许 `diagnose`。

## 验证与停止条件

- 先补 receipt replacement、missing/invalid/mismatch anchor、正确 anchor 保持兼容及 parser/schema 的 red tests；再做最小 SHA-256 / command / schema 实现。
- 仅串行使用 `CLI/.build/sp144-reliability-receipt-anchor` 跑 focused reliability、schema 与 output-contract suites；不启用 shared/default scratch。
- 不启动、探测、停止或复用 server；不访问 Simulator、设备、Xcode 或 #164。若实现需要密钥、真实 runtime identity、evidence cleanup、live sampling 或改变 Stage 1 指标语义，立即停止并转入独立 space。
- 因 SP-141/SP-142 尚未合并，本分支的 docs 连号门禁预期仍会在前置缺口停止；不得新增占位条目来伪造连续性。

本地验证已在独立 `CLI/.build/sp144-reliability-receipt-anchor` 串行完成：`TestReliabilityHarnessRuntimeTests` 4、`TestReliabilityHarnessTests` 18、`TestReliabilityCollectionRuntimeTests` 4、`TestValidationTests` 18、`TestReliabilityRuntimeTests` 33、`FailureDiagnosticsTests` 13、`SchemaFactSourceCapabilityTests` 22 和 `PublicSkillCommandSchemaTests` 1 全部通过，release `triton` build 与 `git diff --check` 通过。`SchemaFactSourceContractTests` 仍只有既有的 6 个 device/sim registry 基线失败（`device` 参数/selector/output、`sim app-console` recovery 与 device capability/example），不包含 anchor 断言；它们留给独立 schema 基线切片处理。

## 后续队列

1. SP-145：私有 identity-chain v2，区分可离线验证的 receipt/reset/target 绑定与必须 live 才能证明的 reset 事实、App build/runtime identity。
2. SP-146：Stage 1A（60 supported）与 Stage 1B（61 receipt/control）指标合同，避免把 expected negative 静默混入 ECR/FER/ORR 的公开分母。
3. 仅在上述离线合同完成后，再向用户请求 dedicated Simulator、server ownership、reset recipe、安全 negative control 和 private evidence 生命周期的真实 3 × 20 + 1 授权。

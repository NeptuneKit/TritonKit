# SP-135 Testrec Compatibility Guidance

## 状态

- 状态：验证完成，待本地 checkpoint。
- 负责人：Codex。
- Branch：`feat/SP-135-testrec-compatibility-guidance`。
- Worktree：`../TritonKit-worktrees/SP-135-testrec-compatibility-guidance/`。
- 基线：`feat/SP-134-ios-simulator-reliability-gate@21a57399`。

## 裁决

**Adopt：先收紧 `testrec` compatibility contract，不在本 slice 新建 reliability collection/harness。**

SP-126 已裁决 `test run` 是唯一真实执行与业务 verdict 入口；但现有 `testrec replay --dry-run`、`local-simulated` 与 matrix 仍可返回 `ready` / `passed` / `passedCount`。这些旧字段必须保留兼容，却不能继续被 agent 误读成真实设备测试通过。

因此本 slice 只增加可选、machine-readable 的 `verdictBoundary`：新生成的 dry-run、local-simulated replay 与 matrix 统一声明 `offline-diagnostic`、`countsAsRealTestVerdict=false`、`eligibleForReliabilityGate=false`，并提供不含真实路径、bundle 或 target 的 import → validate → run 模板。旧 `replay-result.json` 不含此字段时仍能 decode；消费者必须把缺失字段视为 legacy/unknown，而不是正向真实 verdict 证明。

两份审计同时指出未来 3 flow × 20 需要 collection preflight，但仓内尚没有三条冻结 imported flow，也没有可验证的 reset receipt / target binding 采集器。该工作留给后继独立 space，不能在本 slice 用占位符伪造采样能力。

## 边界

包括：

- 为 testrec dry-run、local-simulated replay、matrix result 和 executor profile 添加同一 additive verdict boundary。
- 将 `local-device` 的 unsupported 指引从“将来补齐 executor”改为条件性的 `test import -> test validate -> test run` 迁移模板。
- 更新 testrec schema、capability next action、README/agent 控制文档与 focused contract tests。
- 保留原有 `status`、`ok`、`passedCount`、artifact 及 evidence JSON 的 wire compatibility。

不包括：

- 新增或恢复 `testrec local-device`、matrix、网络或第二真实 executor。
- 改写 shared `TKEvidenceManifest` / `TKTestRunMetadata`，或把旧 generic evidence 的 `passed` 摘要重新定义为真机 verdict。
- 真实 3 × 20 采样、Simulator/server/Xcode/设备动作、workspace 接入、Android/Harmony/Web/Wails 写入。
- 读取、复用或修改 #164 WIP。

## BDD 验收

1. Given `testrec replay --dry-run` 或 `matrix` 返回 `ready`，When 编码 response，Then 每一层都有 `verdictBoundary`，声明它只可作为 offline diagnostic，不能计为真实 test verdict 或 reliability sample。
2. Given `local-simulated` replay / matrix 返回旧兼容的 `status=passed` 与 `passedCount`，When agent 消费 JSON，Then 顶层和每个 target 的 `verdictBoundary` 都明确 `countsAsRealTestVerdict=false`、`eligibleForReliabilityGate=false`；旧状态字段不改写。
3. Given `local-device` profile，When agent 查询能力，Then 它保持 `unsupported`，不承诺未来 testrec executor，而是给出只含占位符的 `test import`、`test validate`、`test run` 迁移模板；Given 既有 local-device replay request，Then 它仍只会返回无设备命令的 blocked diagnostic，并带同一非 verdict boundary 与迁移模板。
4. Given 历史 `run/replay-result.json` 没有新字段，When 用当前 DTO decode，Then 仍成功；缺失 boundary 只能表示 legacy/unknown，不能在本 slice 变成真实 verdict。
5. Given schema、capabilities、README 和 agent-facing control doc，When 检索 replay/matrix 指引，Then 都与 Hybrid 的单一真实 executor 规则一致，不会自动执行 import/run。

## 验证与停止条件

- 先为 boundary、legacy decode、migration template 和 capability/schema 写失败测试；最小实现后运行 `TestRecorderContractTests`、`TestImportTests`、schema/capability focused tests、release CLI/schema、`git diff --check` 与 docs gate。
- 只使用独立 Swift scratch；不启动 server、Simulator、Xcode、设备或 `test run`。
- 若需要改变旧 `status` / generic evidence `passed` 的含义、修改 shared evidence model，或实现 testrec real executor，则停止并新建独立 space。

## 验证结果

- TDD red：新增 boundary contract test 首先因各 response/profile 缺少 `verdictBoundary` 编译失败；最小实现后转绿。
- focused green：新增 simulated boundary / legacy decode test、HTTP handler replay boundary test、testrec schema contract test、`TestImportTests`（11/11）、`SchemaFactSourceCapabilityTests`（22/22）与 `FailureDiagnosticsTests`（13/13）均通过。
- release verification：独立 release scratch 编译成功；`triton schema --command testrec --json` 确认 dry-run/run/matrix boundary fields 与 import migration command，`testrec replay --help` / `matrix --help` 均声明 non-verdict 语义。
- 文档门禁：`git diff --check`、`docs-linhay/scripts/check-docs.sh` 与 `docs-linhay/scripts/verify.sh --ci-docs` 均通过。
- 已知基线：完整 `TestRecorderContractTests` 仍有一条既有 local-device schema expectation mismatch（当前 schema 走 `target_not_found`，历史断言期望 `target_capability_missing`）；本 slice 不改该 legacy route/runtime。新增行为与相关 focused tests 均已单独通过。
- 全程未启动 server、Simulator、Xcode、设备或 `test run`，也未读取或修改 #164 WIP。

## 后继队列

后继候选为 `ios-simulator-reliability-collection-preflight`：只冻结三条 imported flow、20-slot layout、canonical target / reset recipe 与 privacy contract；它仍不能启动真实 harness，也不能声称采样完成。实际立项时再分配下一个连续的 SP 编号。

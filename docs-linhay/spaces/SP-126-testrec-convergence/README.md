# SP-126 Testrec Convergence

## 状态

- 状态：已归档（2026-10-24；本期 Hybrid、bounded importer、真实单 flow 纵切和兼容边界已交付；不声明真实可靠性采样通过）。
- 负责人：Codex。
- 历史 Branch：`feat/SP-126-testrec-convergence`。
- 历史 Worktree：`../TritonKit-worktrees/SP-126-testrec-convergence/`（不作为恢复执行入口）。
- 基线：`main@931645ed`（2026-07-24 建立）。
- 前序 space：[SP-077 Test Recorder Replay](../20260622-test-recorder-replay/README.md)。SP-077 保留为历史需求与既有合同的兼容入口；本 space 保留已交付的收敛决策与证据。

## 已裁决的产品方向

采用 **Hybrid 收敛**，而不是保留两个独立执行器，也不是直接删除 `testrec`。

| 层 | 长期职责 | 本期处理 |
| --- | --- | --- |
| `testrec` | `.tritontestcase` 的显式事件采集、离线确定性编译、质量/脱敏发现、page matcher 与兼容读取 | 保留为 import/compatibility layer；停止新增独立 `local-device`、矩阵和真实网络执行器 |
| `test` | 唯一的可执行测试合同、真实 run、步骤观察、动作和 `.tritonevidence` | 接收由 `.tritontestcase` 导入的规范化测试合同，成为真实执行和最终 verdict 的唯一入口 |
| `workspace` | target 解析、App 生命周期、实时 observation、Atlas 与工作流编排 | 后续复用同一导入/测试合同；不再平行维护录制专属 run registry 或执行器 |
| `replay` | `.tritonplan` 的低层 smoke / 验证能力 | 继续作为低层能力，不吸收录制包、质量审查或测试生命周期 |

因此：`testrec` 有价值的原始合同不会丢失，但其 `local-simulated` 只能作为兼容和诊断基线，不能再被包装成真实回放成功；真实设备动作、前后 observation、证据和最终判定一律落到现有 `test run`。

## 可信基线集成历史与当前归档

`SP-127`（#168 iOS 真机 terminate fail-closed）、`SP-128`（#167 Xcode 真机 target preflight）与 `SP-129`（`serve` 默认 loopback）已按编号纳入独立的 `codex/sp126-trusted-baseline-integration` worktree，并完成联合 focused、schema、CLI 与本地门禁验证。

2026-07-24 的第一阶段仅形成可审查的本地 checkpoint，当时尚未合入 `main`。后续 SP-126～136 已由 `d0f09d3c` 进入主线；receipt-backed gate 的加固由 [SP-151](../SP-151-trusted-baseline-integration/README.md) / PR #177（`66f975d9`）整合。2026-10-24 文档收口核对这两个提交均为候选 `409670ef` 的祖先；本次未重新执行历史测试或设备验收。

真实设备 smoke、真实 Xcode build 与 Bonjour 广播语义仍按各自 space 的证据边界记录；这些限制不重新打开已交付的 importer 或门禁切片。SP-140、SP-143～151 保持已完成/已归档，不能将同一次真实采样缺口拆回多项开发待办。

## 本期边界

包括：

- 定义 `.tritontestcase` 到 `.tritontest.yaml` 的 fail-closed 导入契约与 provenance。
- 复用 `test validate` / `test run` 的规范化、动作、observation 和证据管线。
- 以单个 iOS Simulator、单条可映射动作完成第一条真实纵切；Android 必须先补 `test run` 的显式 host adapter，不能以当前 host surface 冒充同等执行器。
- 定义兼容命令、HTTP 路由和既有 artifact 的迁移策略与淘汰门槛。

不包括：

- 新建或补完 `testrec local-device`、`testrec matrix`、系统级动作监听、live network policy。
- 删除或大规模重命名现有 `testrec` CLI、HTTP route、`.tritontestcase` 或历史 evidence。
- 在没有真实 target 证据前宣称多平台 replay 已可用。
- 新增 Web/Wails 写操作，或把 Web 变成控制入口。
- 本期扩展到真机、远端 agent、设备云或完整跨平台矩阵。

## BDD 验收

1. **可导入的录制包**：SP-132 已完成 P0：给定已编译、无 blocker 的 `.tritontestcase`，当执行 `triton test import <case> --output <plan.tritontest.yaml> --bundle-id <bundle-id> --device-platform ios-simulator --json` 时，得到确定性的测试计划与来源 digest；随后 `triton test validate` 成功。该导入严格只读 compiled contract，不能静默把泛化 iOS source 标成 Simulator。
2. **安全失败**：给定含未审查脱敏 finding、未知 action 或缺失 page/action 证据的 case，当导入时，返回单一 JSON error envelope，并且不产生可运行计划、不连接目标设备。
3. **真实纵切**：SP-133 已验证：给定经 Triton-first 事实检查确认的 iOS Simulator / Debug embedded runtime 和一条可映射动作，`triton test run` 以导入计划顺序完成 target resolve、before observation、exact-AX-text action、after observation 和 `.tritonevidence`，最终 passed verdict 不来自 `local-simulated`。
4. **来源可审计**：SP-133 已验证：最终 evidence 的 `normalized-plan.json` 保留 source case / compiled-contract 的稳定身份和导入版本；`run.planRef` 指向该 artifact，公开摘要不记录敏感原文。
5. **兼容不误导**：既有 `triton testrec` CLI/HTTP 在迁移期继续可读可诊断；任何真实执行请求都明确导向 `test import` / `test run`，不会把 simulated result 表示为设备执行成功。

SP-135 已通过本地 checkpoint `37d8f9c7` 把这条兼容边界写进 replay/matrix 的 machine-readable output：旧 `ready` / `passed` 字段保留，但新增 boundary 明示它们不能计为真实 test verdict 或 reliability sample。

## 完成定义

本 space 按有限里程碑完成归档：SP-132 P0 importer 的 focused tests 已通过，SP-131 提供手写 canonical iOS Simulator 真实动作证据闭环，SP-133 又以 imported plan（不是 hand-written fixture）复现了同一纵切并直接读取 provenance。SP-134 已完成 ECR / FER / ORR 的离线 gate，SP-135 将 simulated compatibility 约束为 non-verdict，SP-136 已冻结真实 collection 的 target/reset/slot 前置合同。该结果仍只证明一条 iOS fixture flow，且尚无真实 3 flow × 20 + 1 negative 样本；不证明可靠性矩阵、workspace 编排、Android/真机 parity 或对外项目采用。

后续只保留一项[条件触发的真实可靠性专项](../SP-134-ios-simulator-reliability-gate/plans/20260727-reliability-gate-decision-v01.md#future-reliability-acceptance)：有明确项目将使用 recorder 导入/workspace 自动回归，或准备对外承诺该执行路径可靠性时，另建有限 space。触发前不占 active queue，也不阻塞本 space 归档。可先做 1 supported + 1 negative 的真实接线 smoke，但这不降低 61 槽门槛；完整可靠性 Go/No-Go 和 workspace 接入仍需专项数据。不得恢复 `testrec` 第二执行器。

详细方案见 [Hybrid Convergence Plan v01](./plans/20260724-hybrid-convergence-plan-v01.md)。

项目级 12 个月路线、平台层级、Go/No-Go 门槛和明确不做项见 [Agent-Native Local Execution Roadmap v01](../../plans/20260724-agent-native-local-execution-roadmap-v01.md)。

历史执行起点与阶段顺序见 [Luna Execution Handoff v01](./plans/20260724-luna-execution-handoff-v01.md)；该交接已失效，不是当前执行队列。

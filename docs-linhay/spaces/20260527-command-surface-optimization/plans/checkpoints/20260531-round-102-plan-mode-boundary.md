# Round 102 - plan mode boundary

## 背景

`triton plan` 现在同时承担两类职责：

1. 通用环境恢复 / 发现计划；
2. `ios-smoke`、`open-url`、`webview-check` 这类任务型 workflow 计划。

此前 `TKWorkflowPlanResponse` 只有 `goal/nextStep/steps[]`，agent 只能通过 `goal == general` 这种约定去猜当前响应属于哪一类规划。这会让 `schema / capabilities / plan` 的职责边界继续依赖隐式约定，而不是正式 wire contract。

## 本轮动作

1. 为 `TKWorkflowPlanResponse` 新增 `mode` 字段：
   - `bootstrap`：环境恢复 / 发现计划；
   - `task`：目标型 workflow 计划。
2. `buildWorkflowPlan(...)` 的三类 bootstrap 返回路径统一显式输出 `mode=bootstrap`：
   - server 不可达；
   - server 可达但 runtime 未连接；
   - connected 后的通用观察计划。
3. `buildTaskWorkflowPlan(...)` 与 `taskWorkflowPlan(...)` 输出 `mode=task`；未知 goal 的 validation failure 也保持 `task`，因为它仍属于任务型规划失败，而不是 bootstrap 恢复计划。
4. `TKWorkflowPlanResponse` decoder 对旧 JSON 做保守回推：
   - `goal == general` 或缺省 goal => `bootstrap`
   - 其他 goal => `task`
5. `plan.next-steps` output contract 新增 `mode` 字段说明。
6. 同步更新 dev 文档和 public skills，让 agent 明确把 `mode` 当作规划职责边界，而不是继续猜 `goal`。

## 结果

1. `plan` 现在能显式告诉 agent：当前要先做环境恢复，还是直接进入任务链路。
2. `capabilities` 继续回答“当前能做什么”，`plan` 则更清楚地回答“当前这份规划属于哪一类执行上下文”。
3. 没有改动实际计划步骤或命令序列；这是对现有信息架构的边界收紧，不是新 workflow。

## 验证

1. `swift test --filter TKCLITransportModelsTests`
2. `swift test --package-path CLI --filter SchemaFactSourceTests`
3. 后续文档收尾再跑：
   - `docs-linhay/scripts/check-docs.sh`
   - `git diff --check`

## 下一步

1. 继续审视 bootstrap 入口之间的职责线，尤其是 `status / doctor / capabilities / plan` 是否还需要更明确的“环境事实 / 诊断 / 规划”分工字段。
2. 若继续推进方案 C，可考虑把 task plan 再细分为更稳定的 task taxonomy，而不是只靠自由字符串 goal。

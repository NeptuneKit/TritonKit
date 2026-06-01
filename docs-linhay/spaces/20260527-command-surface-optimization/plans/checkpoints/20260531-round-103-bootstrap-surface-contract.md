# Round 103 - bootstrap surface contract

## 背景

虽然 `status`、`doctor`、`capabilities`、`plan` 在命令层已经各自分工，但 agent 消费 JSON 时，仍主要依赖调用上下文或文档记忆区分“这是状态事实、诊断排序、能力矩阵还是规划入口”。这意味着 bootstrap 入口的职责边界还没有完全进入机器可读 contract。

## 本轮动作

1. 为以下 response model 增加顶层 `surface` 字段：
   - `TKCLIStatusEnvelope` => `surface=status`
   - `TKDoctorResponse` => `surface=doctor`
   - `TKCapabilitiesResponse` => `surface=capabilities`
   - `TKWorkflowPlanResponse` => `surface=plan`
2. 为上述 shared model 增加 backward-compatible decoder：
   - 旧 JSON 缺少 `surface` 时自动回填默认值；
   - `plan` 继续保留 Round 102 的 `mode` 推断逻辑。
3. 更新 bootstrap output contracts：
   - `status`
   - `doctor`
   - `capabilities`
   - `plan.next-steps`
   都显式声明 `surface` 字段。
4. 更新共享模型测试与 `SchemaFactSourceTests`：
   - shared tests 断言 decode 后的 `surface` 值；
   - schema tests 断言 output contract 暴露 `surface`；
   - doctor / task plan 侧断言 builder 产物的 `surface` 一致。
5. 同步更新 dev 文档与 public skills，把 `surface` 定义为 bootstrap 入口职责边界字段，而不是继续让 agent 从命令上下文推断。

## 结果

1. bootstrap 四个入口现在都能在 JSON 自身声明“我是哪类入口”：
   - `status`：直接状态事实
   - `doctor`：有序诊断
   - `capabilities`：环境能力矩阵
   - `plan`：规划入口
2. `plan.surface=plan` 与 `plan.mode=bootstrap|task` 组合后，agent 可以先判断“这是规划入口”，再判断“这是环境恢复计划还是目标型 workflow 计划”。
3. 这一轮没有改变任何实际命令执行序列，只把入口职责边界正式落进 wire contract。

## 验证

1. `swift test --filter TKCLITransportModelsTests`
2. `swift test --package-path CLI --filter SchemaFactSourceTests`
3. 后续收尾校验：
   - `docs-linhay/scripts/check-docs.sh`
   - `git diff --check`

## 下一步

1. 继续审视 bootstrap 四个入口是否还缺少可让 agent 直接路由的固定 taxonomy，而不是依赖 prose。
2. 若继续推进方案 C，可考虑把 `doctor.nextStep` 与 `capabilities.requiredBy` 之间的工作流层级关系再收紧成更直接的任务 taxonomy。

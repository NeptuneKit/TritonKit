# Round 93: plan inspect capability

## 目标

把 `triton plan inspect <file.tritonplan> --json` 暴露为 agent 可发现的一等 capability，避免 agent 只能通过文档或 `plan` schema 猜到 `.tritonplan` 离线检查入口。

## Subagent 分工

- Curie（worker）：按 TDD 实现 `plan-inspect` capability，并补 schema / capabilities 不变量测试。
- Chandrasekhar（explorer）：只读审计下一轮 `steps[].argv` schema-backed 校验切片。
- 主控：复核 diff、补跑全 CLI 测试、补运行时输出证据、同步 docs / skills / memory。

## 完成内容

1. `runtimeCapabilities(...)` 新增 `plan-inspect`，三态下均 `supported=true`。
2. `plan-inspect` 的规划元数据固定为：
   - `group = replay`
   - `requiredBy = ["replay"]`
   - `nextAction = triton plan inspect <file.tritonplan> --json`
   - `evidence = ["tritonplan", "stdout-json"]`
3. `plan` schema 的 `providedCapabilities[]` 新增 `plan-inspect`，与 capabilities matrix 对齐。
4. 新增 `SchemaFactSourceTests.capabilitiesMatrixExposesPlanInspectCapability`，覆盖 server down / disconnected / connected 三态。
5. 更新 agent-facing CLI 文档、README 和 public skills，把 `plan-inspect` 与 `replay-dry-run` 分离表达。

## 验证

- Curie 红灯：`swift test --package-path CLI --filter SchemaFactSourceTests/capabilitiesMatrixExposesPlanInspectCapability`，失败点为 `capabilities["plan-inspect"] == nil`。
- Curie 绿灯：同一命令通过。
- Curie 回归：`swift test --package-path CLI --filter SchemaFactSourceTests`，77 个 Swift Testing 用例通过。
- 主控复验：`swift test --package-path CLI --filter SchemaFactSourceTests/capabilitiesMatrixExposesPlanInspectCapability`，通过。
- 主控复验：`swift test --package-path CLI --filter SchemaFactSourceTests`，77 个 Swift Testing 用例通过。
- 主控复验：`swift test --package-path CLI`，149 个 Swift Testing 用例通过。
- 主控运行证据：`swift run --package-path CLI triton capabilities --json` 输出包含 `plan-inspect`，`group=replay`，`nextAction.command=plan`，`nextAction.args=["inspect","<file.tritonplan>","--json"]`。

## 风险

1. 本轮只解决 capability 可发现性；`steps[].argv` 目前仍只做非空和 `triton` 前缀检查，下一轮应补 schema-backed argv helper。
2. `plan-inspect` 是离线摘要能力，不证明真实 replay 已执行；真实回归仍需 `replay --dry-run`、真实 `replay`、wait/assert/evidence。

## 下一步

1. Round 94：新增 `validateSchemaBackedArgv(...)` 测试 helper，优先让 task workflow plan 的 `steps[].argv` 直接对齐 schema。
2. 可选补强 replay / plan inspect 的 schema-backed argv 测试，继续把 agent 首选执行字段从 shell string 迁到 argv。

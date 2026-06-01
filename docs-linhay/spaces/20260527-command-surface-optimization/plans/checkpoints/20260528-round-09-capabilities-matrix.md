# Round 09: Capabilities Matrix

## 目标

将 `triton capabilities --json` 从平铺能力清单升级为 agent-facing 环境能力矩阵，使 agent 能直接判断当前环境可做什么、缺什么、下一步命令是什么，以及哪些 evidence 可证明执行结果。

## 完成结果

- 扩展 `TKRuntimeCapability`，新增 `group`、`requiredBy`、`nextAction`、`evidence` 字段。
- 更新 CLI capabilities 构建逻辑，为 target、runtime、xcode、host、observe、action、assert、evidence、replay 等能力补齐分组、依赖 workflow、恢复动作和证据面。
- `serverReachable=false` 且能力需要 server 时，`nextAction` 返回 `serve --host 127.0.0.1 --port 19421` 并标记 `requiresLongRunningProcess=true`。
- `connected=false` 且能力需要 embedded runtime 时，`nextAction` 返回 `status --json`，让 agent 先恢复连接状态再继续执行。
- 补齐 `capabilities` schema output contract，显式列出 `capabilities[].name/supported/reason/group/requiredBy/nextAction/evidence`。
- 更新 `docs-linhay/dev/ai-cli-readable-control.md`、`docs-linhay/dev/agent-facing-cli-information-architecture.md` 与对外 public skills，统一 capabilities 矩阵口径。

## 验收场景

1. agent 可通过 `triton capabilities --json` 识别 `target-list` 属于 `target` 分组，并读取 `target list --json` 作为下一步。
2. 未连接 embedded runtime 时，`runtime-manifest`、`capture`、`tap` 等能力保持 `supported=false`，并给出 `status --json` 恢复动作。
3. server 不可达时，需要 server 的能力给出 `serve --host 127.0.0.1 --port 19421` 恢复动作。
4. Xcode、evidence、action 能力都能暴露对应 group、requiredBy 和 evidence 字段。

## 已运行验证

- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，9 个 Swift Testing 用例通过。
- `swift test --package-path CLI` 通过，80 个 Swift Testing 用例通过。
- `swift test` 通过，125 个 Swift Testing 用例通过。

## 后续队列

- Round 10：把 `plan` 从通用 next-step 继续升级为任务型 planning 入口，优先覆盖 iOS smoke、open-url、webview-check 等 agent 高频目标。
- 后续可将 `target` 与 `capabilities` 的关系进一步收敛：`target resolve` 的结果进入 plan 的默认 target 消歧步骤。

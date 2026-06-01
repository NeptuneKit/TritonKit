# 20260527 Command Surface Optimization

## 背景

TritonKit 当前已经形成了较完整的本机 CLI 能力面，覆盖 Xcode workflow、iOS Simulator、Harmony host-side adapter、embedded runtime、WebView、UI action、assert、evidence 和 replay 等方向。随着命令数量增加，agent 面对 CLI 时需要更强的自发现、规划、诊断和证据闭环能力。

本期优化把长期方向明确为 agent-facing CLI 信息架构升级：`triton` 不只是命令集合，而是 agent 可通过绑定 skills 和机器可读 schema 使用的本机控制面。

## 关键决策

1. `triton` CLI 直接绑定随包发布的 skills；agent 使用时面对的是同一套当前 CLI + skills 契约。
2. 本期不背旧命令兼容负担；允许破坏性重排命令、schema 和信息架构。
3. 每次破坏性更新必须同步更新 `triton schema`、README、public skills、dev 文档和测试。
4. `schema` 是命令事实源，`capabilities` 是环境能力源，`doctor` 是诊断恢复入口，`plan` 是任务规划入口，`evidence` / `replay` / `assert` 是验收闭环入口。
5. 新增能力优先服务 agent 自动化，不恢复 Web / Wails UI，不引入远端 agent、真机、设备云或云端控制面。

## 目标

1. 收口当前命令面和 Host 命令文件复杂度，为后续长期演进建立清晰基线。
2. 让 agent 不依赖旧记忆或 README 猜命令，而是通过当前绑定 skills + `triton schema` 获取可执行契约。
3. 将 CLI 信息架构重排为 agent 可自发现、可规划、可执行、可诊断、可复跑的控制面。
4. 形成一条 iOS 和一条 Harmony 的标准 agent 回归样板链路。
5. 所有阶段保持 BDD / TDD、文档、memory 和 qmd 同步。

## 非目标

1. 不维护 legacy / compatibility 层。
2. 不保证旧命令名长期可用；旧入口可在同一期内被迁移、重命名或删除。
3. 不恢复 Web / Wails UI。
4. 不做真机、远端 agent、设备云、多租户、Postgres / Kafka / webhook 平台化能力。
5. 不执行 push、tag、release、Homebrew tap 更新，除非用户明确授权。
6. 不处理真实账号、证书、签名资产或私有项目敏感信息。

## BDD 验收场景

### 场景一：当前绑定 skills 驱动 CLI

- Given agent 安装了当前发布包中的 `triton` CLI 与随包 skills
- When agent 需要完成回归任务
- Then agent 应通过 skills 指引和 `triton schema --json` 获取当前命令契约
- And 不要求兼容旧版本 CLI 命令名或旧参数

### 场景二：schema 是事实入口

- Given 任意 agent-facing 命令发生破坏性调整
- When 改动完成
- Then `triton schema` 必须同步反映新命令、参数、错误码、输出模型和下一步建议
- And public skills、README、dev 文档与测试必须同步更新

### 场景三：agent 可自规划

- Given agent 不阅读源码
- When agent 执行 `triton doctor`、`triton capabilities`、`triton schema` 和 `triton plan`
- Then agent 能知道当前环境可做什么、缺什么、下一步命令是什么

### 场景四：失败可恢复

- Given 命令因为 server 不可达、target 多匹配、runtime 未连接、参数缺失或断言失败而失败
- When CLI 返回 JSON 错误
- Then 输出必须是单个合法 envelope
- And 包含 `code`、`message`、`hint` 与可机器读取的下一步恢复建议

### 场景五：回归可复跑

- Given agent 完成一次 iOS 或 Harmony smoke
- When 任务结束或失败
- Then 产出 evidence / replay / assert 可离线审计材料
- And 能通过 plan 或 replay 复现关键路径

## 关联文档

- 长期巡航计划：`plans/20260527-long-term-cruise-plan-v01.md`
- Agent-facing CLI 信息架构：`docs-linhay/dev/agent-facing-cli-information-architecture.md`
- AI CLI readable control：`docs-linhay/dev/ai-cli-readable-control.md`
- Agent entrypoint engineering：`docs-linhay/dev/agent-entrypoint-engineering.md`
- Autonomous evolution：`docs-linhay/spaces/20260524-autonomous-evolution/README.md`

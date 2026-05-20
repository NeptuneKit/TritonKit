# 20260521 ai-phone Device Cloud

## 结论

ai-phone 对 TritonKit 的价值不是“把 TritonKit 做成另一个三端真机 AI 自动化中台”，而是提醒我们补一层未来会越来越重要的能力：**从单机 host adapter 走向远端 host agent、设备池、执行安全层和批次化回归契约**。

TritonKit 当前正确的入口仍是 CLI/HTTP 机器可读契约。我们要吸收 ai-phone 的架构边界和产品契约，但不吃下它的 Python/FastAPI/Postgres/Vue 技术栈，不复制 GPLv3 代码，不首期引入内置 VLM loop、大盘或 Kafka。

## 参考

- ai-phone GitHub：`https://github.com/dongxinsuperman/ai-phone`
- ai-phone 参考归档：`docs-linhay/references/ai-phone.md`
- Harness UX run evidence：`docs-linhay/spaces/20260521-harness-ux-run-evidence/README.md`
- Simulator takeover：`docs-linhay/spaces/20260520-simulator-takeover/README.md`
- Harmony Emulator alignment：`docs-linhay/spaces/20260520-harmony-emulator-alignment/README.md`
- AI CLI 契约：`docs-linhay/dev/ai-cli-readable-control.md`

## 我们要做什么

### 要做：远端 host agent 的产品边界

先定义 TritonKit 从本机 `triton serve` 演进到远端 host agent 的边界：

```text
Triton control plane
  -> local / remote host agents
  -> simulator / emulator / physical device targets
  -> runtime targets
  -> evidence / command ledger
```

首期不一定实现远端连接，但 schema 要避免写死“本机唯一设备”。所有 target、action、artifact、error 都要能带 host/agent/source 信息。

### 要做：Device registry / readiness / lock

把 Apple Simulator、Harmony Emulator、未来真机统一到 device registry：

```text
targetId
platform
transport
hostId
state
readiness
appBindings
locks
capabilities
lastSeenAt
```

关键语义：

1. readiness 明确区分 `online` 和 `ready`。
2. 多 target 时返回 `ambiguous_target`。
3. 已被 session/job/manual lock 占用时不能被自动派发。
4. 设备不可用要在准入或执行前失败，不静默排队。

### 要做：Command ledger

每一次 host/runtime/device action 都应能写入 `.tritonevidence`：

```text
messageId
targetId
agentId
method
paramsSummary
startedAt
finishedAt
elapsedMs
ok
error
artifacts
sourceCommand
```

这会解决“agent 调了什么、底层实际执行了什么、失败在哪里”的排障问题。它也能解释为什么其他 AI 不该先用裸 `xcrun`：裸命令没有统一 schema、ledger、artifact 和 nextAction。

### 要做：执行安全层 metadata

吸收 ai-phone 的低成本安全规则，不先内置 VLM：

- 页面稳定后再截图或判定。
- 同坐标重复点击检测。
- 同屏 pHash / screenshot hash revisit。
- 滑动震荡检测。
- 动作后页面无变化检测。
- fixed sleep 过长或无验证动作提醒。
- 最终状态必须通过 `assert`、`wait`、fresh screenshot 或 evidence 验证。

首期可先写入 evidence metadata 和 warning，不直接接管决策。

### 要做：AI 可消费 case schema

引入更适合外部 agent 和回归平台的 case 表达：

```text
测试标题
前置条件
操作步骤
预期结果
```

TritonKit 可先做 `.tritoncase` 文档规范和 `case lint` 设计，后续再接入 `run submit`。

## 我们能做什么

### 能做：单机先行，schema 面向多 agent

当前可以继续用本机 `triton serve` 和本机 simulator/emulator，但输出结构提前带上：

- `hostId=local`
- `agentId=local`
- `targetId`
- `transport`
- `sourceCommand`
- `readiness`
- `capabilities`

这样后续加远端 agent 不会破坏已有 CLI/HTTP 契约。

### 能做：把 batch submission 做成本地文件契约

不用一开始做服务端队列。可以先定义本地 batch：

```bash
triton run submit --file smoke.tritonbatch --output out.tritonbatchrun --json
```

批次文件表达：

- `submissionName`
- `items`
- `caseId`
- `platforms`
- `deviceAliasPools`
- `runContent`
- `retryMax`
- `cachePolicy`

### 能做：把 command ledger 接进现有 evidence

比新建中台更现实的第一步，是让现有命令都能追加 ledger：

- `triton sim ...`
- `triton app ...`
- `triton device ...`
- `triton tap/swipe/type/press`
- `.tritonplan replay`
- `capture/evidence`

输出仍是 filesystem portable，不依赖数据库。

### 能做：轨迹缓存先做 checkpoint，不做 VLM 回放

ai-phone 的 V2/V3 很强，但复杂。TritonKit 可先做更小的能力：

- replay step 前记录 expected checkpoint。
- replay step 后验证 checkpoint。
- checkpoint 不满足时返回 `checkpoint_mismatch`。
- 所有 replay 结束后仍跑最终断言。

后续再考虑 intent replay 或在线重定位。

## 什么是合适做的

### 合适做：把 ai-phone 当生产化参考，不当技术栈模板

我们应该抄：

- Server/Agent 角色边界。
- 设备 registry、readiness、lock。
- submission/item/platform 展开模型。
- command ledger。
- 执行安全层。
- 轨迹缓存的安全边界。
- AI 可消费 case。
- 终态事件 payload。

不应该抄：

- Python / FastAPI / Postgres / Vue 作为 TritonKit 主栈。
- GPLv3 代码。
- Web 大盘优先路线。
- 内置 VLM provider 编排。
- Kafka 作为首期依赖。

### 合适做：CLI/HTTP-first，再谈 UI

TritonKit 的核心使用者是 AI agent、自动化脚本和真实项目回归。所有控制能力必须先有 CLI/HTTP JSON 契约。Web/Wails 只适合后续查看设备、队列和 evidence，不适合先定义 create/update/execute/approve 业务控制闭环。

### 合适做：外部 AI agent 仍然是主执行者

ai-phone 内置 VLM loop，TritonKit 当前不应这样走。更合适的是：

1. TritonKit 提供 device/runtime/host control。
2. TritonKit 提供 ledger/evidence/assert。
3. 外部 Codex/Claude/Gemini/CI agent 调用 TritonKit。
4. TritonKit 用 safety metadata 和最终断言约束外部 agent。

## 什么不适合做

1. 不把 TritonKit 改成 ai-phone clone。
2. 不直接复制 ai-phone GPLv3 代码。
3. 不首期做完整真机设备云。
4. 不默认依赖 Postgres/Kafka/Web 大盘。
5. 不内置 VLM 决策 loop 作为 P0。
6. 不让轨迹缓存或 replay 绕过统一 dispatcher。
7. 不把成功执行动作当成业务成功；必须保留最终断言。
8. 不把 system alert、信任电脑、设备解锁等能力伪装成可全自动。

## 分期

## CLI 进入决策

这个工具未来主要给 AI agent 使用，所以决策原则是：**凡是 agent 在一次本地或真实项目回归中需要直接调用、需要稳定 JSON、需要进入 evidence、需要能在无 UI 环境复跑的能力，都进入 CLI；凡是偏平台治理、后台持久化、多人协作管理、运维展示的能力，不作为 CLI 首期产品面。**

### 必须进 CLI

| 能力 | CLI 形态 | 原因 |
| --- | --- | --- |
| 能力发现 | `triton schema/doctor/capabilities/plan --json` | agent 开始工作前必须知道当前可做什么、下一步做什么 |
| Target / device 发现 | `triton device list/use/wait-ready --json` | 避免直接用 `xcrun`、`hdc`、`adb` 解析人读输出 |
| Workspace 默认 target | `triton sim use`、`triton device use` | 多步回归需要稳定上下文 |
| App 生命周期 | `triton app install/uninstall/launch/terminate/open-url/info/list/container/prefs --json` | 真实回归经常要准备 App、deep link、验证偏好 |
| Host screenshot / artifact | `triton sim screenshot`、`triton screenshot`、`triton capture/evidence` | issue、回归和失败排障必须可归档 |
| Runtime 观察与动作 | `ax/find/tap/swipe/type/paste/clear/press/wait/assert` | 这是 AI 控制 App 的日常动作面 |
| Command ledger 读取 | `triton evidence inspect`、后续 `triton evidence commands` | agent 需要复盘底层实际执行了什么 |
| Run / plan replay | `triton record/plan inspect/replay` | 可复跑 smoke 是 AI 自动化的核心资产 |
| Batch 本地提交 | `triton run submit/status/cancel --file ... --json` | CI 和 agent 需要无需 Web 的批次入口 |
| Case lint | `triton case lint --json` | 投递前发现自然语言 case 不可执行风险 |
| 本地锁 | `triton device lock/unlock --json` | 长流程要避免同一 target 被两个任务抢占 |
| Remote agent 自注册 | `triton agent connect/status/disconnect --json` | 接设备的机器需要用 CLI 加入控制面 |

### 可以进 CLI，但不做 P0

| 能力 | CLI 形态 | 分期 |
| --- | --- | --- |
| Device pool 解析 | `triton device pool list/resolve --json` | P2，先只读，不默认允许 agent 改全局池 |
| 终态事件导出 | `triton run events --submission <id> --jsonl` | P2/P3，先服务 CI 消费 |
| Webhook 本地配置检查 | `triton webhook test --url ... --json` | P3，真正发送策略走 serve 配置 |
| Checkpoint replay | `triton replay --checkpoint-policy strict|warn` | P3，先做状态验证，不做 VLM 重定位 |
| Remote artifact 拉取 | `triton evidence fetch --run <id> --output ...` | P3，远端 agent 后再做 |
| Agent 日志摘要 | `triton agent logs --agent <id> --jsonl` | P3，只输出摘要与 artifact，不倾倒无限日志 |

### 不进 CLI 首期

| 能力 | 归属 | 原因 |
| --- | --- | --- |
| Postgres schema / migration 管理 | 后台部署文档 | 不是 agent 执行回归所需动作 |
| Kafka 配置与消费 | serve 后台 / 部署 | 重型平台集成，不适合本地工具默认面 |
| 运维大盘 | Web/后台只读 | 人看趋势，agent 不靠它执行任务 |
| 多租户、权限、用户管理 | serve admin / 配置 | CLI 不应成为权限后台 |
| 全局设备池写入管理 | serve admin / 配置文件 | 避免 agent 误改共享资源 |
| 内置 VLM 决策 loop | 暂不做 | TritonKit 当前服务外部 AI agent，不抢 agent 角色 |
| V2/V3 轨迹缓存自动重定位 | 后续研究 | 风险高，必须先有 checkpoint 与最终断言 |
| Kafka/Webhook 生产投递保障 | 后台 | CLI 最多做本地测试和状态查询 |
| Web 工作台和报告大盘 | Web/Wails 只读 | 不定义业务控制闭环 |
| iOS 信任电脑、解锁、证书全自动 | 不承诺 | 系统安全边界，不能伪装成自动化能力 |

### HTTP / serve-only 能力

这些能力需要常驻进程、共享状态或跨机器路由，可以有 HTTP API，但不要求每个动作都做成 CLI 子命令：

1. Agent heartbeat、capability sync、target sync。
2. Command dispatch waiter 和 timeout routing。
3. 远端 artifact upload / download session。
4. Submission 队列调度器。
5. 终态 Webhook/Kafka publisher。
6. 设备池全局配置写入。
7. 多用户权限、token 发放、审计查询。

CLI 对这些能力只保留 agent 可用入口：`connect/status/list/submit/status/cancel/fetch`。

### P0：Evidence Ledger Foundation

- 定义 command ledger event schema。
- host/runtime action 写入 `.tritonevidence/commands.jsonl` 或 `run/events.jsonl`。
- 每条 action 带 target、agent、source command、elapsed、ok/error、artifacts。
- `capture/evidence` summary 聚合 command ledger。

### P1：Device Registry Foundation

- 统一 Apple Simulator / Harmony Emulator target DTO。
- 输出 readiness、capabilities、transport、hostId。
- lock 先作为 schema 和本地执行保护，不做分布式。
- 错误稳定：`ambiguous_target`、`device_not_ready`、`device_locked`、`unsupported_capability`。

### P2：Batch Case Contract

- 定义 `.tritoncase` 四字段 case。
- 定义 `.tritonbatch` wrapper。
- 支持本地 `run submit --file`。
- 支持 item-level final assertion 和 artifact summary。

### P3：Remote Host Agent

- `triton agent connect --server ...` 或等价 HTTP/WebSocket。
- agent heartbeat、capability sync、target sync。
- command dispatch、result ack、timeout、retry。
- filesystem evidence 先落 server，再考虑持久化后端。

### P4：Trajectory Replay / Webhook / UI

- checkpoint-based replay。
- intent replay 重定位。
- Webhook 终态事件。
- 设备/队列只读 UI。
- 大盘、Kafka、数据库作为可选平台化能力。

## 验收场景

### 场景一：host action 进入 command ledger

- Given agent 执行 `triton app open-url`
- When 命令完成
- Then evidence 中记录 target、method、source command、elapsed、ok/error
- And 下一步验证建议不依赖裸命令输出

### 场景二：多 target 不误选

- Given 当前存在多个 booted simulator 或多个 Harmony target
- When agent 未显式指定 target
- Then TritonKit 返回 `ambiguous_target`
- And 输出 candidates 和推荐参数

### 场景三：设备 ready 才派发

- Given target online 但未 ready
- When batch item 准备执行
- Then item 不进入真实动作
- And 返回 `device_not_ready` 或等待 JSONL progress

### 场景四：动作后必须验证业务状态

- Given agent 执行 deep link、tap 或 replay step
- When 底层命令返回 ok
- Then TritonKit summary 提示该 ok 只代表动作提交成功
- And 推荐或执行 `wait/find/assert/screenshot/evidence` 验证业务完成

### 场景五：AI case 可 lint

- Given `.tritoncase` 包含多个断言、模糊账号或“如果找不到则”
- When 执行 `triton case lint`
- Then 返回结构化 warning
- And 指向测试标题、前置条件、操作步骤或预期结果字段

## 完成定义

1. 明确哪些 ai-phone 能力适合 TritonKit，哪些不适合。
2. command ledger、device registry、case schema 和 execution safety 分期清楚。
3. 文档明确 GPLv3 只做设计参考，不复制代码。
4. 与 simulator takeover、Harmony alignment、Harness evidence 的边界清楚。
5. 后续实现可直接从 P0/P1 拆测试和 CLI/HTTP schema。

# ai-phone Reference

## 来源

- GitHub: `https://github.com/dongxinsuperman/ai-phone`
- 本地源码快照：`/tmp/ai-phone`
- 调研分支：`next/server-brain`
- 调研提交：`e03e8d1 Document AI-consumable case guidance`
- License：GNU GPLv3。TritonKit 只能借鉴架构与产品设计，不能直接复制代码或实现细节。

## 项目定位

ai-phone 是一个面向中小型公司的三端真机 AI 自动化中台，支持 iOS、Android、HarmonyOS。它不是单机 CLI，也不是简单执行器 SDK，而是把以下链路做成一个完整平台：

```text
外部投递
  -> Submission 队列
  -> 设备池调度
  -> Server 侧 VLM 决策
  -> Agent 执行真机动作
  -> 执行安全层
  -> 轨迹缓存
  -> HTML 报告 / 大盘 / 终态广播
```

对 TritonKit 的参考价值集中在 **远端 host agent、设备池调度、Server-side command ledger、执行安全层、轨迹缓存、AI 可消费 case schema、跨平台 driver 抽象和终态事件契约**。不应把它当作 TritonKit 的技术栈模板或 GUI 产品模板。

## 架构要点

ai-phone 当前推荐分支采用“Server 大脑，Agent 手脚”：

```text
FastAPI Server
  - API / SubmissionScheduler
  - 设备锁 / alias pool / readiness gate
  - VLM 决策 / 辅助审判 / 轨迹缓存
  - RunStep / RunLog / RunCommand
  - HTML 报告 / Analytics / 终态广播
      |
      | WebSocket: /ws/agent
      v
Agent on Mac
  - 发现 Android / iOS / HarmonyOS 真机
  - 镜像或截图通道
  - 执行 driver_command
      |
      v
真实设备
```

关键模型：

| 模型 | 作用 |
| --- | --- |
| `Submission` | 一次外部投递批次 |
| `SubmissionItem` | `case + platform` 的执行单元 |
| `Device` | 当前设备快照，带平台、serial、在线态、agent 归属 |
| `DeviceAlias` | 业务别名池，支持先规划别名、后绑定设备 |
| `Run` | 单次真实执行 |
| `RunStep` | VLM 每步动作、截图和耗时 |
| `RunLog` | 结构化日志与错误归因 |
| `RunCommand` | Server 下发到 Agent 的 driver RPC 证据链 |
| `vlm_trajectory_cache*` | V1/V2/V3 轨迹缓存 |

## 值得 TritonKit 抄的设计

### 1. Server 大脑，Agent 手脚

ai-phone 把 VLM key、模型选择、轨迹缓存、审判、断言、报告全部收在 Server，接手机的机器只跑 Agent。这个模型适合 TritonKit 后续从单机 `triton serve` 演进到多 host：

```text
triton serve
  -> local host adapter
  -> remote host agent registry
  -> device registry / target registry
  -> command ledger / evidence store
```

首期不需要做成平台中台，但应提前避免把所有状态都绑死在本机进程和单一 simulator。

### 2. 设备池调度模型

ai-phone 的调度模型很清晰：

- 按平台维护 FIFO：`android`、`ios`、`harmony`。
- 一个 case 可展开为多个 platform item。
- 派发前检查 device readiness。
- session / job / manual lock 防止抢占。
- `deviceAliasPool` 支持业务别名池。
- 无可用设备时在准入阶段拒绝，而不是提交后静默挂死。

TritonKit 可吸收为跨平台 target pool：

```text
triton device list --json
triton device use <target> --json
triton device wait-ready --jsonl
triton run submit --case <file> --platform ios --device-pool smoke-ios --json
```

### 3. Server-side command ledger

Server 大脑下每个设备动作都会产生 `RunCommand`：

```text
message_id
method
params
result
ok
rpc_elapsed_ms
```

这对排障非常有价值。TritonKit 当前 evidence 更偏“最后状态和 artifacts”，后续应补 `command ledger`：

```text
command_started
command_sent
command_result
command_timeout
command_failed
```

每条记录都应包含 target、driver、source command、参数摘要、耗时、错误码和 artifact 链接。

### 4. Submission API

ai-phone 的 `/api/submissions` 把批次投递、平台展开、回调、重试和缓存模式统一在 wrapper 中。这比直接暴露“启动一个 run”更适合 CI 和回归平台。

TritonKit 可借鉴但要保持 CLI/HTTP-first：

```json
{
  "submissionName": "smoke-2026-05-21",
  "callbackUrl": "https://example.com/triton/callback",
  "retryMax": 1,
  "items": [
    {
      "caseId": "login_001",
      "platforms": ["ios"],
      "deviceAliasPools": {"ios": ["iPhone-1"]},
      "runContent": "测试标题...\n前置条件...\n操作步骤...\n预期结果..."
    }
  ]
}
```

首期可先落为本地 `triton run submit --file cases.json --output out.tritonbatch --json`，再扩展 HTTP。

### 5. 执行安全层

ai-phone 不把截图直接交给 VLM 然后盲信下一步动作，而是在外层做护栏：

- 页面稳定检测。
- 同坐标点击检测。
- 同屏 pHash revisit。
- 滑动震荡检测。
- unknown 动作堆积检测。
- 审判系统介入。
- before / after + 全步骤上下文最终断言。

TritonKit 的 `.tritonplan replay`、`capture`、未来 `agent run` 都可以吸收这层思路。最适合先做的是本地低成本规则：同屏重复、同坐标重复、动作后无变化、固定 sleep 过长等，并把结果写入 evidence。

### 6. 轨迹缓存 V1/V2/V3

ai-phone 的轨迹缓存不是普通录制回放：

| 模式 | 机制 | TritonKit 可借鉴点 |
| --- | --- | --- |
| `v1` | 固定动作回放 | 仅适合高度稳定链路 |
| `v2` | 固定动作 + 状态路标对齐 | replay 前后做状态一致性检查 |
| `v3` | 保存动作意图，复跑时重定位 | UI 位置变化时不盲信旧坐标 |

TritonKit 现有 `.tritonplan` 更像显式脚本。后续可以增加 `plan checkpoints` 和 `intent-located step`，但必须保留最终断言：缓存或 replay 成功不等于业务成功。

### 7. AI 可消费测试用例四字段

ai-phone 推荐把自然语言 case 写成四字段：

```text
测试标题
前置条件
操作步骤
预期结果
```

这比传统 QA 提纲更适合 AI agent 执行。TritonKit 可把它沉淀为 `triton case lint` 或 `.tritoncase` schema：

- 前置条件必须可执行或可验证。
- 操作步骤单线，不写“如果找不到则”这类运行时业务分支。
- 预期结果只保留一个核心视觉断言。
- 账号、环境、入口路径必须明确。

### 8. 可执行链路契约

ai-phone 对动作执行边界做了硬约束：

- 模型坐标必须标记空间：`normalized` 或 `absolute`。
- 只在执行边界转换坐标。
- Parser 只识别动作、参数、坐标空间，不做业务推断。
- 所有设备动作必须走统一 dispatcher。
- `type` 只负责输入文本，不隐式点击输入框。
- 每轮默认只执行一个动作，多动作链必须受限。

这与 TritonKit 的 agent-facing CLI 非常契合，应该进入 host adapter / device adapter 的长期契约。

### 9. 三端 driver 抽象

ai-phone 的三端链路：

| 平台 | 控制 | 截图 / 镜像 |
| --- | --- | --- |
| Android | ADB / adbutils | scrcpy |
| iOS | WebDriverAgent / pymobiledevice3 | WDA MJPEG / DVT 截图 |
| HarmonyOS | hdc / hmdriver2 | hypium |

TritonKit 当前已在 Apple Simulator 和 Harmony Emulator 两条线上扩展 host adapter。ai-phone 提醒我们：driver 抽象应以 target/action/evidence 为中心，而不是以单一平台命令为中心。

### 10. 终态广播与报告

ai-phone 支持 item 终态和 submission 终态事件，广播到 stdout / Kafka / Webhook，并生成单 case 和汇总 HTML 报告。

TritonKit 首期不需要 Kafka 和大盘，但可以吸收终态 payload：

```text
event
version
submissionId
caseId
platform
state
statusReason
runId
device
elapsedMs
steps
reportUrl
artifactUrl
```

这能让 CI、外部平台、GitHub issue bot 用同一种方式消费结果。

## 不适合直接抄的部分

1. 不复制 GPLv3 代码进 TritonKit；只借鉴架构和契约。
2. 不把 TritonKit 改成 Python / FastAPI / Postgres / Vue 中台。
3. 不首期引入 Kafka、Postgres、运维大盘、多 worker、多 pod。
4. 不把内置 VLM 决策 loop 作为 TritonKit P0；TritonKit 当前仍优先服务外部 AI agent。
5. 不让 Web UI 先定义业务控制能力；CLI/HTTP 机器可读契约仍是事实入口。
6. 不默认承诺真机全平台接管；Apple Simulator、Harmony Emulator、真实 iOS/Android/Harmony 应分期。
7. 不把轨迹缓存当成万能 replay；起跑状态不可控时必须默认关闭。
8. 不允许辅助模型或缓存回放绕过统一 parser / dispatcher / 坐标转换。

## TritonKit 采纳优先级

### P0/P1 可吸收

- AI 可消费 case schema 和 lint 规则。
- command ledger 写入 `.tritonevidence`。
- host action / runtime action 的统一 action envelope。
- 页面稳定、同屏重复、同坐标重复等本地安全规则。
- 设备 readiness 和明确 `ambiguous_target` / `device_not_ready` 错误。
- `runContent -> expected assertion` 的最终断言入口。

### P2/P3 再吸收

- local submission batch 格式。
- device alias pool 和设备锁。
- 远端 host agent registry。
- `.tritonplan` checkpoint / state landmark。
- V2/V3 风格 intent replay。
- Webhook 终态通知。

### P4 或不吸收

- Kafka 广播。
- Postgres 作为默认依赖。
- 运维大盘。
- 内置多模型 VLM 编排。
- 完整三端真机中台化部署。

## 与现有 TritonKit spaces 的关系

- `20260521-ai-phone-device-cloud`：把 ai-phone 调研收敛成远端 host agent、设备池、执行安全层的独立需求空间。
- `20260521-harness-ux-run-evidence`：Harness 补 UX run 证据形态，ai-phone 补生产调度、安全执行和终态汇总。
- `20260520-simulator-takeover`：吸收 command ledger、device readiness、driver dispatcher、轨迹缓存 checkpoint 思路。
- `20260520-harmony-emulator-alignment`：吸收三端设备池和 hdc / hypium / driver abstraction 视角。
- `20260520-xcode-workflow-takeover`：可复用 command ledger、batch report、remote agent readiness 到 build/test job。

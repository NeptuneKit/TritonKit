# 20260521 Harness UX Run Evidence

## 结论

Harness 给 TritonKit 的启发不是“做一个 macOS GUI 版 Harness”，而是补齐一个目前缺失的产品层：**UX run evidence**。

TritonKit 现在已经能做命令式验证：`capture`、`evidence`、`.tritonplan`、`assert`。但它还缺少一种能回答“真实用户会怎么走、为什么卡住、哪里产生摩擦”的 run 产物。Harness 的价值正好在这里：`goal + persona + step screenshot + observation + intent + action + result + friction + verdict`。

本 space 的目标是把 Harness 中适合 TritonKit 的 run/evidence 设计吃进来，但不引入它的 GUI-first 产品形态、SwiftData run history、内置 LLM agent 或 WebDriverAgent 默认依赖。

ai-phone 与本 space 的关系：Harness 更强在单次 UX run 的可解释证据，ai-phone 更强在生产化调度、设备池、command ledger、执行安全层和终态汇总。两者都应落到 TritonKit 的 filesystem portable evidence 和 CLI/HTTP 契约，而不是落成 GUI-first 或中台-first 产品。

## 参考

- Harness GitHub：`https://github.com/awizemann/harness`
- Harness 参考归档：`docs-linhay/references/harness.md`
- ai-phone 参考归档：`docs-linhay/references/ai-phone.md`
- ai-phone device cloud：`docs-linhay/spaces/20260521-ai-phone-device-cloud/README.md`
- Simulator takeover：`docs-linhay/spaces/20260520-simulator-takeover/README.md`
- Xcode workflow takeover：`docs-linhay/spaces/20260520-xcode-workflow-takeover/README.md`
- AI CLI 契约：`docs-linhay/dev/ai-cli-readable-control.md`

## 我们要做什么

### 要做：UX Run 证据格式

新增一种可落入 `.tritonevidence` 的 UX run 子结构：

```text
<case>.tritonevidence/
  manifest.json
  run/
    events.jsonl
    meta.json
    step-001.png
    step-002.png
  artifacts/
    host/
    runtime/
    xcode/
```

它要能表达：

1. agent / 人类操作者的目标是什么。
2. persona 是什么。
3. 每一步看到了什么。
4. 为什么执行这个动作。
5. 实际执行了什么。
6. 动作是否成功。
7. 出现了什么 UX friction。
8. 最终 verdict 是 success / failure / blocked。

### 要做：Append-only JSONL run log

采用 Harness 的关键不变量：

1. `events.jsonl` append-only，不重写历史行。
2. 每行完整 JSON object。
3. 每行带 `schemaVersion`、`runId`、`ts`、`kind`。
4. screenshot 先写文件，再写 `step_started`。
5. screenshot path 使用相对路径。
6. parser 容忍最后一行截断。
7. 旧 schema 永久可读。

首期 row kinds：

```text
run_started
step_started
tool_call
tool_result
friction
step_completed
run_completed
```

### 要做：Friction taxonomy

固定 friction taxonomy，避免回归报告自由发挥：

| kind | 含义 |
| --- | --- |
| `dead_end` | 走了一条路，没进展或退回 |
| `ambiguous_label` | 文案/按钮含义不清 |
| `unresponsive` | 操作后没有视觉反馈 |
| `confusing_copy` | 提示、错误、正文难理解 |
| `unexpected_state` | 操作后的状态与预期不一致 |
| `auth_required` | 遇到需要登录但无法继续 |
| `agent_blocked` | 系统合成：预算耗尽、循环、解析失败等 |

### 要做：Clean evidence screenshot

如果未来给 agent 使用 AX candidate / tap target / Set-of-Mark 标记图：

1. 主 evidence screenshot 必须保持用户真实看到的干净画面。
2. agent-only overlay 只进入内存 payload 或单独 debug artifact。
3. issue、replay、friction report 默认引用 clean screenshot。

### 要做：Credential redaction

真实项目回归经常需要登录。借鉴 Harness：

1. 密码不进入 prompt。
2. 密码不进入 `.tritonplan`。
3. 密码不进入 `events.jsonl`。
4. 密码不进入截图描述。
5. 日志只记录 `fill_credential(field:"password")` 这类意图，不记录值。

## 我们能做什么

### 能做：先做证据格式，不做内置 agent

TritonKit 当前的定位是服务外部 AI agent。我们可以先提供 run log writer / parser / evidence schema，让外部 agent 调 `triton` 时把 observation、intent、tool_call、tool_result 写进去。

这比直接内置 LLM agent 更合适：

- 改动小。
- 不绑定模型供应商。
- 和现有 CLI/HTTP 契约一致。
- 真实项目回归可以马上用。

### 能做：让 `.tritonplan replay` 产出 UX run log

脚本式 replay 本身没有“persona reasoning”，但可以产出结构化 step log：

```text
step_started -> tool_call -> tool_result -> step_completed
```

当外部 agent 提供 `--observation` / `--intent` 或通过 HTTP event API 写入时，再补齐 UX 信息。

### 能做：把 `capture/evidence` 升级为 run-aware

`triton capture --case login --output login.tritonevidence --json` 可以生成：

- host artifacts
- runtime artifacts
- xcode artifacts
- run events
- friction events
- final verdict

### 能做：后期加入 agent-run mode

后续可以做：

```bash
triton run --goal "完成登录并进入首页" \
  --persona "第一次使用的普通用户" \
  --target booted \
  --budget-steps 40 \
  --output /tmp/login.tritonevidence \
  --jsonl
```

但这不应进入首期。原因是内置 agent 会引入模型选择、prompt、token budget、credential、provider SDK、成本控制等大块产品复杂度。

## 什么是合适做的

### 合适做：把 Harness 当 evidence 参考，不当产品模板

我们应该抄：

- run artifact shape
- event schema
- friction taxonomy
- screenshot 不变量
- credential redaction
- cycle detector 思路
- platform adapter 抽象

不应该抄：

- macOS GUI-first 产品路线
- SwiftData run history
- 内置多 provider LLM 客户端
- Step-by-step approval UI
- WebDriverAgent 默认依赖

### 合适做：先 filesystem portable，再考虑 UI

TritonKit 的核心消费方是 AI agent 和自动化脚本。run 结果应该先是可搬迁目录：

```text
events.jsonl + screenshots + meta.json + manifest.json
```

GUI replay 可以后做，不能反过来让 GUI 结构定义证据格式。

### 合适做：外部 agent 仍然是主执行者

首期不做“内置 Claude/OpenAI/Gemini agent loop”。我们只提供：

1. 稳定动作命令。
2. 稳定证据写入。
3. 稳定 replay / parser。
4. 稳定 friction / verdict schema。

让 Codex、Claude、Gemini、CI 脚本都能写同一种 run evidence。

### 合适做：WDA 只作为 fallback

WebDriverAgent 可以解决“没有 embedded runtime 的 iOS App 黑盒输入”问题，但成本高：

- vendored submodule 或下载策略。
- 每个 iOS runtime 需要 build cache。
- xcodebuild test runner 生命周期复杂。
- 端口、session、cleanup、日志都要管理。

所以 WDA 适合 P3/P4，不适合 P0/P1。

## 什么不适合做

1. 不把 TritonKit 改成 Harness clone。
2. 不新增 GUI run history 作为首期目标。
3. 不在核心 CLI 中内置模型供应商 SDK。
4. 不把 WDA 放到默认安装依赖。
5. 不把 agent overlay 图覆盖主证据截图。
6. 不把密码、token、账号密文写进 plan / prompt / JSONL / evidence。
7. 不让 UX run 取代现有 `.tritonplan`；两者关系是：plan 可复跑，run 解释一次执行过程。

## 分期

### P0：Run Evidence Schema

- `TKEvidenceRunEvent` shared model。
- `TKEvidenceFriction` shared model。
- `TKEvidenceRunMeta` shared model。
- `.tritonevidence/run/events.jsonl` writer。
- parser 容忍 partial tail。
- evidence manifest 链接 run artifacts。

### P1：CLI 写入与 replay 接入

- `triton evidence run start/append/complete` 或等价内部 API。
- `.tritonplan replay` 写 run events。
- `capture/evidence` 输出 final verdict 与 friction summary。
- README / real-project-regression skill 给出用法。

### P2：Agent UX Run 协议

- `triton run` 或 `triton agent-run` 命令面评估。
- persona / goal / budget schema。
- cycle detector。
- clean screenshot + debug overlay artifact。
- credential binding。

### P3：Black-box Fallback

- WebDriverAgent fallback 评估。
- WDA build cache by iOS runtime + WDA SHA。
- WDA input driver 只在 embedded runtime 不可用时启用。

## 验收场景

### 场景一：外部 agent 写 UX run evidence

- Given 外部 agent 正在执行登录回归
- When 每步调用 TritonKit 写入 observation、intent、tool call、tool result
- Then `.tritonevidence/run/events.jsonl` 可还原完整执行路径
- And 主截图保持 clean

### 场景二：replay 生成基础 run log

- Given `.tritonplan` 包含多个 runtime 和 host action
- When 执行 `triton replay plan.tritonplan --output out.tritonevidence --json`
- Then evidence 包含 run events
- And 每一步都有 tool_call/tool_result/step_completed

### 场景三：friction 进入 issue 证据

- Given agent 标记 `ambiguous_label`
- When 生成 evidence summary
- Then friction 按 kind 聚合
- And summary 能直接贴到 issue

### 场景四：敏感信息不落盘

- Given run 使用登录凭证
- When 完成 run
- Then `events.jsonl` 不包含密码原文
- And `manifest.json` 不包含密码原文
- And prompt / plan 不要求写入密码

## 完成定义

1. 明确 run/evidence schema。
2. run log writer/parser 有单元测试。
3. partial JSONL tail 可解析到最后一个完整 step。
4. evidence manifest 可链接 run events 与 screenshots。
5. friction taxonomy 写入 docs 和 shared model。
6. 文档明确 Harness 哪些抄、哪些不抄。

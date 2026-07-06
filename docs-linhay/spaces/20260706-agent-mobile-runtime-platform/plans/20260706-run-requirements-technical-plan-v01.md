# 20260706 Run Requirements And Technical Plan

## 本质

这个产品不是测试平台，也不是设备控制台，而是本地 App 运行理解器。

本质公式：

```text
Run = goal + local target + observation + LLM/VLM bootstrap/recovery + policy-gated action + evidence + atlas delta + replay seed
```

所有能力都从 `Run` 派生：

- Workbench 是 `Run` 的窗口。
- Atlas 是 `Run` 的空间记忆。
- Flow 是 `Run` 的沉淀结果。
- Report 是 `Run` 的索引视图。
- Deterministic replay 是 `Run` 的稳定回放模式。

不挂到 `Run` 事实流上的能力先不做。

## 需求方案

### 产品入口

默认入口只保留一个：

```bash
triton workspace run --target current --app <artifact-or-app-id> --goal "<goal>" --open --json
```

最小行为：

1. 解析本机 target，按 `platform + scope + capabilities` 返回事实。
2. 启动或附着 App。
3. 默认开启 LLM/VLM provider preflight。
4. 建立 `.triton/runs/<run-id>/`。
5. 按 `observe -> decide -> policy -> act -> verify -> record` 循环。
6. 每步写入 `events.jsonl` 和 artifacts。
7. 增量更新 Atlas。
8. 持续生成 flow seed。
9. 停止时输出 `report.json` 和 next actions。

### 目标用户

| 用户 | 核心诉求 | 产品承诺 |
| --- | --- | --- |
| AI agent | 不知道 App 结构时也能探索和执行 | 默认 LLM/VLM 理解，动作只能走 Triton 契约 |
| 本地研发 | 看懂 agent 做了什么 | 每一步 evidence-backed，可回看、可复跑、可接管 |
| 自动化维护者 | 把成功探索沉淀为稳定回归 | 从 Run 生成 `.tritonflow.yaml` / `.tritonplan` |

### 默认模式

`workspace run` 默认启用：

```yaml
llm:
  enabled: true
vlm:
  enabled: true
runner:
  actionPolicy: explore
```

模型默认参与：

- flow bootstrap：识别当前初始场景，帮助流程从登录态、弹窗、空态、异常页、不同入口等状态稳定启动。
- flow recovery：发现流程偏航、selector drift、页面变体或前置状态变化时，帮助流程回到正轨。
- 场景理解
- selector 消歧
- Atlas 节点命名和标签
- 下一步动作候选
- flow seed 生成
- 异常解释和 next actions

模型默认不能：

- 直接执行设备动作
- 输出多步 plan 后被自动批量执行
- 决定危险动作
- 无证据影响 pass/fail
- 默认上传截图或 evidence 到远端模型

### Flow Bootstrap 需求

Flow bootstrap 解决“同一流程在不同初始场景中稳定出发”。

常见初始场景：

- 已登录，当前在首页。
- 未登录，当前在登录页。
- 首次启动，有隐私、通知、升级或权限弹窗。
- App 停在上次使用的深层页面。
- 网络错误、空态、维护页或异常页。
- WebView / native shell 已加载但业务页未 ready。

模型职责：

- 识别当前 screen 是否已经满足流程 start anchor。
- 如果不满足，判断需要登录、关闭弹窗、返回、等待、打开入口还是停止。
- 给出一个 bootstrap proposal，而不是直接执行多步计划。
- 每个 proposal 必须引用 observation evidence 和 Atlas / flow anchor。

bootstrap 结束条件：

- 命中 flow start anchor。
- 达到 `maxBootstrapSteps`。
- 遇到危险动作或 unsupported capability。
- 模型无法解释当前状态。

### Flow Recovery 需求

Flow recovery 解决“流程偏航后回到正轨”。

触发条件：

- plan step 的 selector 找不到或候选过多。
- action 执行成功但 expected observation 未出现。
- 当前 screen signature 偏离 plan anchor。
- 出现弹窗、登录过期、网络错误或权限拦截。
- 连续动作没有产生新 screen / variant。

模型职责：

- 判断偏航类型：selector drift、screen variant、interrupt、precondition missing、slow loading、unsupported。
- 给出 repair proposal：重选 selector、关闭干扰、等待、返回上一个 anchor、重新 bootstrap 或停止。
- repair proposal 必须可编译成单个 Triton primitive 或 `stop`。
- repair 是否执行由 policy 决定；低风险动作可按 policy 自动执行，危险动作暂停等待批准。

recovery 结束条件：

- 回到最近 flow anchor。
- 进入可继续执行的等价 variant。
- 达到 `maxRecoverySteps`。
- repair 被 policy 拒绝。
- 模型无法给出可审计解释。

### 稳定回放模式

本地稳定回放显式开启：

```yaml
runner:
  actionPolicy: planFirst
ai:
  participation: full
```

含义：

- LLM/VLM 仍参与每一步 observe、bootstrap check、verify、drift detection、failure diagnosis 和 repair suggestion。
- 既有 `.tritonplan` 的下一步动作是主路径，模型不能自由生成任意新动作。
- 如果模型发现 selector drift、页面变体或前置状态变化，只能生成 repair proposal。
- repair 是否执行由 policy 决定，默认需要明确允许。
- 失败返回 `failureCode`、nearest candidates、evidenceId、model diagnosis、suggestedCommands。
- 模型缺失必须写入 run config 和 report；稳定回放不能把模型缺失静默当成正常。

### Run 状态

```text
created -> preflighted -> appReady -> running -> paused|completed|failed|stopped
```

暂停条件：

- 模型 provider 缺失。
- capability 不支持当前动作。
- policy 判定危险动作。
- 连续 N 步没有新 screen / variant。
- 模型输出不是单步 JSON action。
- 用户在 Workbench 手动暂停。

### BDD 场景

#### 场景 1：启动一次默认 AI Run

Given 本机存在一个可用 target 和可启动 App
When agent 执行 `triton workspace run --target current --app <app> --goal "<goal>" --json`
Then TritonKit 创建 run 目录，默认启用 LLM/VLM preflight，并返回 runId、target、capabilities、provider 状态和 first nextAction

#### 场景 2：Run 产生可审计事实流

Given Run 正在执行
When 每一步完成 observe / decide / policy / action / verify
Then `events.jsonl` 追加对应事件，事件包含 evidenceId、artifact path、policyDecision、command 和 result

#### 场景 3：模型只提出候选动作

Given VLM 识别出一个按钮入口
When 模型输出下一步动作候选
Then TritonKit 只接受一个 primitive action 或 `stop`，并在执行前经过 capability / policy gate

#### 场景 4：Atlas 实时更新

Given action 前后都有 observation evidence
When screen signature 或 state variant 发生变化
Then Atlas 写入 screen/state/transition delta，并能反查截图、hierarchy、action 和模型决策

#### 场景 5：探索沉淀为 flow seed

Given Run 到达目标或用户停止
When 请求导出 seed
Then TritonKit 输出 `.tritonflow.yaml` 和 `.tritonplan`，每一步带 selector、变量、证据引用和 dry-run 校验入口

#### 场景 6：本地稳定回放

Given 已有 `.tritonplan`
When agent 以 `actionPolicy=planFirst` 执行本地 replay
Then TritonKit 按 plan 优先执行动作，同时调用 LLM/VLM 参与流程启动、偏航回正、观察、验证、drift 诊断和修复建议；失败时返回稳定 failure envelope、model diagnosis 和 evidence backlink

#### 场景 7：流程从不同初始场景稳定启动

Given 同一个 flow 的 start anchor 是 `screen_home`
When Run 启动时 App 分别处于登录页、首页、权限弹窗和深层页面
Then LLM/VLM 生成 bootstrap check 和 bootstrap proposal；TritonKit 只执行 policy 允许的单步动作，直到命中 start anchor 或返回明确 stop reason

#### 场景 8：流程偏航后回正

Given Run 正在执行 plan step，预期进入 `screen_checkout`
When action 后出现登录过期弹窗或 selector drift
Then LLM/VLM 生成 recovery diagnosis 和 repair proposal；TritonKit 经 policy gate 后执行安全 repair，或暂停并返回 next actions

### 验收标准

- `Run` 是唯一顶层产品对象；Atlas、flow、report、Workbench 都能通过 runId 追溯。
- `.triton/runs/<run-id>/events.jsonl` 是事实源，其他产物都可以从它索引或重建。
- 默认 LLM/VLM 开启；模型缺失必须显式返回 setup nextAction，不能静默变成传统 runner。
- Flow bootstrap 必须能从不同初始场景生成 evidence-backed start-state 判断和单步 proposal。
- Flow recovery 必须能从失败 observation 生成 drift diagnosis、repair proposal 和 policy decision。
- 每个模型参与步骤都有 request、response、confidence、artifact、policy decision。
- 每个设备动作都能追溯到 Triton CLI/HTTP primitive。
- Atlas 至少覆盖 screen、state、transition、coverage、evidence backlink。
- Flow seed 至少能表达 launch、observe、tap、type、swipe、wait、verify、evidence。
- Web 只读展示 run facts；不定义 Web-only 业务语义。

## 技术方案

### 文件布局

```text
.triton/
└── runs/
    └── <run-id>/
        ├── run.json
        ├── config.yaml
        ├── events.jsonl
        ├── evidence/
        │   ├── screenshots/
        │   ├── hierarchy/
        │   ├── model/
        │   └── actions/
        ├── atlas/
        │   ├── atlas.json
        │   └── deltas.jsonl
        ├── flow.tritonflow.yaml
        ├── plan.tritonplan
        └── report.json
```

`events.jsonl` 是唯一必须先做好的文件。其他文件可以先是空壳或从 events 派生。

### 最小事件协议

每行一个 JSON 对象：

```json
{
  "eventId": "evt_0004",
  "runId": "run_20260706_120000",
  "type": "model.decided",
  "timestamp": "2026-07-06T12:00:00Z",
  "step": 2,
  "evidenceId": "ev_0002",
  "data": {}
}
```

首批事件类型：

```text
run.started
target.resolved
provider.checked
app.ready
observation.captured
flow.bootstrap.checked
flow.bootstrap.proposed
model.decided
policy.checked
action.executed
verify.checked
flow.recovery.detected
flow.recovery.proposed
flow.recovery.applied
flow.recovery.rejected
atlas.updated
flow.updated
run.paused
run.completed
run.failed
run.stopped
```

### Run DTO

```json
{
  "kind": "triton.workspace.run",
  "runId": "run_20260706_120000",
  "goal": "explore login to home",
  "status": "running",
  "target": {
    "id": "current",
    "platform": "ios",
    "scope": "simulator",
    "capabilities": ["screenshot", "input", "hierarchy"]
  },
  "ai": {
    "llmEnabled": true,
    "vlmEnabled": true,
    "actionPolicy": "explore",
    "providersReady": true,
    "providerStatus": "ready",
    "llmProvider": "mock",
    "llmProviderStatus": "ready",
    "vlmProvider": "mock",
    "vlmProviderStatus": "ready"
  },
  "paths": {
    "runDir": ".triton/runs/run_20260706_120000",
    "events": ".triton/runs/run_20260706_120000/events.jsonl"
  },
  "nextActions": []
}
```

### Observation DTO

```json
{
  "evidenceId": "ev_0002",
  "sources": ["screenshot", "hierarchy", "semantic-provider"],
  "screenshot": "evidence/screenshots/0002.png",
  "hierarchy": "evidence/hierarchy/0002.json",
  "dominantTexts": ["Login", "Continue"],
  "screenSignature": "sig_login_email_v1"
}
```

### Bootstrap Check DTO

```json
{
  "startAnchor": "screen_home",
  "currentScreenSignature": "sig_login_email_v1",
  "state": "needs_login",
  "ready": false,
  "summary": "The app is on the login screen; the target flow starts from home.",
  "proposal": {
    "action": "tap",
    "target": "Continue",
    "expected": "home screen or password step appears",
    "confidence": 0.74
  },
  "evidenceId": "ev_0002"
}
```

允许的 `state`：

```text
ready | needs_login | blocked_by_dialog | wrong_screen | loading | error_state | unknown
```

### Recovery Proposal DTO

```json
{
  "anchor": "screen_checkout",
  "failureCode": "expected_screen_missing",
  "diagnosis": "A login-expired dialog interrupted the checkout transition.",
  "kind": "interrupt",
  "proposal": {
    "action": "tap",
    "target": "Login again",
    "expected": "login screen opens",
    "confidence": 0.78
  },
  "policy": {
    "requiresApproval": false,
    "reason": "low-risk navigation repair"
  },
  "evidenceId": "ev_0014"
}
```

允许的 recovery `kind`：

```text
selector_drift | screen_variant | interrupt | precondition_missing | slow_loading | unsupported | unknown
```

### Model Decision DTO

```json
{
  "summary": "Login screen is visible and the email field is focused.",
  "action": "type",
  "target": "email field",
  "input": "alice@example.com",
  "confidence": 0.82,
  "expected": "email appears in the field",
  "usedVLM": true,
  "artifacts": {
    "request": "evidence/model/0002-request.redacted.json",
    "response": "evidence/model/0002-response.raw.txt"
  }
}
```

只允许：

```text
tap | type | swipe | wait | press | verify | stop
```

后续要加动作，先加 Triton primitive，再加模型 allowlist。

### Policy Gate DTO

```json
{
  "allowed": true,
  "reason": "action is in allowlist and target supports input",
  "capability": "input",
  "danger": false,
  "command": ["triton", "act", "type", "alice@example.com", "--json"]
}
```

必须拒绝：

- purchase
- delete
- logout
- uninstall
- permission escalation
- external payment
- unknown multi-action output

拒绝不算失败，写 `run.paused` 和 next actions。

### Atlas Delta DTO

```json
{
  "deltaId": "atlas_delta_0003",
  "kind": "transition",
  "fromScreenId": "screen_login",
  "toScreenId": "screen_home",
  "actionEventId": "evt_0008",
  "evidenceIds": ["ev_0002", "ev_0003"],
  "confidence": 0.76
}
```

首版 Atlas 不做复杂 ML 聚类。先用 deterministic signature：

```text
platform + appId + visible text hash + role hash + route/webview hint + coarse layout buckets
```

VLM 只补 label 和 tags，不决定节点合并。

### Flow Seed 规则

Flow seed 从 events 派生：

- `app.ready` -> `launchApp`
- `action.executed` -> `tap/type/swipe/press/wait`
- `verify.checked` -> `assertVisible` / `assertNotVisible`
- `atlas.updated` -> comment metadata
- evidence backlink -> `evidenceRef`

坐标不能成为唯一 selector。生成顺序：

1. semantic provider selector
2. id / accessibility label
3. text + within
4. VLM target description + evidenceRef
5. point fallback

### CLI / HTTP 面

CLI 首批只需要：

```bash
triton workspace run --target current --app <app> --goal "<goal>" --json
triton workspace run --target current --app <app> --goal "<goal>" --llm-provider mock --vlm-provider mock --json
triton workspace inspect <run-id> --json
triton workspace stop <run-id> --json
triton workspace export-flow <run-id> --output <file> --json
```

HTTP 只补同构 JSON endpoint，不新增 Web-only 控制：

```text
POST /workspace/run
GET  /workspace/runs/:runId
POST /workspace/runs/:runId/stop
POST /workspace/runs/:runId/export-flow
```

### Workbench

Workbench 首屏只读 Run facts：

- Live: current screenshot / stream。
- Understanding: 当前 screen、dominant text、LLM/VLM summary。
- Next Action: 模型候选、policy decision、可暂停。
- Atlas: 当前 screen 和最近 transitions。
- Timeline: events.jsonl。
- Flow Seed: 当前生成的 steps。

按钮只调用 CLI/HTTP 已有契约：pause / stop / approve dangerous action / export flow。不要新增设备控制按钮矩阵。

### 复用现有能力

| 需要 | 已有可复用 | 缺口 |
| --- | --- | --- |
| target facts | `status/doctor/capabilities/schema/plan --json`、Web target registry | 统一写入 `target.resolved` |
| app lifecycle | `triton app *` | 纳入 `app.ready` |
| observe | screenshot / hierarchy / semantic provider | 统一 `observe.captured` |
| action | `triton act *` | policy gate wrapper |
| evidence | `triton evidence capture` taxonomy | run 内轻量 evidence id |
| VLM | `triton vlm *`、MLX helper | workspace 默认 preflight |
| replay | `.tritonplan`、record/replay | 从 events 生成 seed |

### 第一刀实现

不要先做完整 Atlas 或 Web。第一刀只做事实流：

```text
workspace run dry skeleton:
target.resolved -> provider.checked -> app.ready -> observe.captured -> flow.bootstrap.checked -> run.stopped
```

验收：

- 不需要真实模型决策也能创建 run 目录和 events。
- `events.jsonl` schema 有 tests。
- `workspace inspect` 能读回 run 状态。
- `actionPolicy` 和 provider missing 的状态能写进 `run.json`。
- fake bootstrap check 能写入 `flow.bootstrap.checked`，并被 `workspace inspect` 读回。

第二刀再接一个 fake model decision：

```text
observe.captured -> model.decided(fake) -> policy.checked -> action.executed(dry) -> verify.checked -> flow.recovery.detected(fake) -> atlas.updated
```

这比先做 Atlas/DSL/UI 都便宜，而且会逼所有后续能力复用同一事实流。

### 第一刀落地状态（2026-07-07）

已落地最小本地 Run 事实流：

- 新增 `triton workspace run|inspect|stop|export-flow` CLI 入口，并在 `triton schema --command workspace --json` 中暴露命令契约。
- 新增同构 HTTP handler：`POST /workspace/run`、`GET /workspace/runs/:runId`、`POST /workspace/runs/:runId/stop`、`POST /workspace/runs/:runId/export-flow`。
- `workspace run` 会创建 `.triton/runs/<run-id>/` 兼容目录骨架，写入 `run.json`、`config.yaml`、`events.jsonl`、`report.json`、`atlas/atlas.json` 和首批 evidence placeholder。
- `atlas/atlas.json` 不再是空壳：默认从初始 `observation.captured` 生成一个 `screen_0000`、一个 `state_0000`、coverage 计数和 screenshot / hierarchy / event evidence backlink。
- `--dry-model-fixture` 会把测试协议里的失败动作写回 Atlas：`atlas/deltas.jsonl` 和 `atlas/atlas.json` 都包含 `transition_0000`，状态为 `candidate_failed`，从 `screen_0000` 回到 `screen_0000`，并引用 model / policy / action / verify evidence。
- `export-flow` 会从 `action.executed` 事件派生最小 action step；dry fixture 当前可导出 `tap Continue`，并保留 model / policy / verify evidence backlink。
- 默认写入 `llmEnabled=true`、`vlmEnabled=true`、`providersReady=false` 与 `configure_ai_provider` nextAction；当前不伪装真实模型或设备已执行。
- `events.jsonl` 首批事实流为 `run.started -> target.resolved -> provider.checked -> app.ready -> observation.captured -> flow.bootstrap.checked -> run.stopped`，并复用 `TKTestRunEventLogParser` 校验。
- `export-flow` 当前从事件流导出最小 `.tritonflow.yaml` seed，先覆盖 `launchApp / observe / bootstrapCheck` 三步。
- 新增显式 dry fixture：`--dry-model-fixture` / HTTP `dryModelFixture=true` 会追加 `model.decided -> policy.checked -> action.executed -> verify.checked -> flow.recovery.detected/proposed/rejected -> atlas.updated -> flow.updated` 事件，用于固定第二刀协议；默认不启用，避免把测试夹具伪装成真实 LLM/VLM 或设备动作。
- 新增显式 LLM/VLM provider preflight：`--llm-provider mock --vlm-provider mock` / HTTP `llmProvider=mock, vlmProvider=mock` 会记录 `providersReady=true`、`providerStatus=ready`、`llmProviderStatus=ready`、`vlmProviderStatus=ready`，并把 `provider.checked` phase 写为 `ready`、`flow.bootstrap.checked` phase 写为 `provider_ready`。
- 只配置 `--vlm-provider mock` 时仍是可审计 partial 状态：`providerStatus=partial`、`llmProviderStatus=missing`、`vlmProviderStatus=ready`，`provider.checked` phase 为 `vlm_ready_llm_missing`，`flow.bootstrap.checked` phase 为 `llm_missing`。

刻意未做：

- 未接真实 target discovery / app launch / screenshot / action execution。
- 未接真实 LLM provider、真实 VLM request/response、model decision、policy gate 或 recovery proposal。
- 未生成真实 observation 驱动的 Atlas transition、state variant 合并、coverage path 或 app-map merge；当前 transition 和 action flow step 只来自显式 dry fixture。
- 未做 Web Workbench 视图。

### 测试策略

文档落地后，代码实现按最小测试走：

- Shared model tests：Run/Event DTO encode/decode。
- CLI parser tests：`workspace run/inspect/stop/export-flow` 参数和 JSON output。
- Runtime unit tests：append events、read run state、reject invalid transition。
- Runtime unit tests：bootstrap ready / needs_login / blocked_by_dialog，recovery selector_drift / interrupt。
- HTTP `httptest`：run/inspect/stop/export-flow route。
- Fixture test：events -> flow seed。
- 手动 smoke：一个本机 target 跑到 `observe.captured`。

不需要先做大 E2E。Run event protocol 稳了，再补 Atlas 和 VLM 真机 smoke。

## 不做

- 不做云设备池。
- 不做多租户。
- 不做外部流水线产品面。
- 不做新数据库。
- 不做独立 MCP server。
- 不把 Web 做成设备控制台。
- 不让模型直接执行裸底层命令。
- 不把完整 Maestro DSL 搬进来。
- 不先做漂亮 report。

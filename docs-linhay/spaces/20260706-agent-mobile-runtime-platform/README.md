# Space: 20260706 Agent Mobile Runtime Platform

## 背景

用户要求为新插槽开独立 space，并把产品方向对齐到 Revyl 同类能力：让 AI agent 和研发团队可以启动移动运行环境、上传或安装 App、执行自然语言/机器可读测试动作、采集证据，并把探索过程沉淀为可复跑工作流。

TritonKit 的产品边界是本地单机：本机 CLI + 本机可连接 mobile target。target 可以是真机、模拟器或仿真器；产品层不按 real-device / simulator / emulator 分叉，而是用 `platform + scope + capabilities` 抹平差异。这个 space 用来重新定义一个更完整的产品方向，但不复制 Revyl 的云 SaaS、多租户、计费或远端设备池；把本机运行时能力包装成 agent-first 产品插槽。

## 产品目标

建立 TritonKit 的 Agent Mobile Runtime Platform：

- agent 可以通过 CLI/HTTP 发现 target、启动或附着本机真机/模拟器/仿真器、安装/启动 App。
- agent 可以执行截图、tap、type、swipe、wait、验证、日志/网络/性能观察等动作。
- 每次探索或测试都能生成结构化证据包，包含命令、截图、层级、日志和结果。
- 成功探索可以沉淀为可复跑 plan / workflow。
- 必须提供完整 Atlas map：基于本机 session/evidence 建立 screen、state、transition 和 coverage 图谱。
- 必须提供默认开启的 LLM/VLM 自主探索 loop：LLM/VLM 的核心职责是帮助流程回到正轨，并帮助同一流程在不同初始场景中稳定启动；模型只读取本机证据和机器可读状态，只通过 Triton CLI/HTTP 执行动作。
- Web 新插槽只作为人类可视化和调试入口，业务控制事实仍以 CLI/HTTP 机器可读契约为准。

## Revyl-like 能力映射

| Revyl 能力 | TritonKit 对应方向 | 一期边界 |
| --- | --- | --- |
| Cloud device session | Local target session | 只做本机真机/模拟器/仿真器，不做云设备池 |
| CLI / 本地回归运行 | `triton` CLI / HTTP JSON contracts | 优先已有命令，缺口再补 schema |
| MCP / agent tools | Codex/agent 通过 CLI/HTTP 控制 | 不先新增独立 MCP server |
| Natural-language mobile actions | `triton act` + 默认开启的 LLM/VLM 自主探索 loop + 可解释 plan/workflow | LLM/VLM loop 必做，但只驱动本机设备 |
| Replayable reports | `triton evidence capture` | 强化证据 manifest 和 artifacts |
| Atlas runtime map | 完整本机 Atlas map | 必做 screen/state/transition/coverage 图谱 |
| Automation gate | JSON output + exit code | 先服务本地自动回归；外部流水线以后另定边界 |

## 已接入基础能力

这些能力不是从零开始；本 space 应优先复用，再补缺口：

| 基础能力 | 当前已有 | 本 space 需要补齐 |
| --- | --- | --- |
| Target / capability 事实源 | `triton status/doctor/capabilities/schema/plan --json`；Web `/web/target-registry`；`DeviceTarget` / `InspectTarget` 已有 `platform`、`scope`、`kind`、`targetSelector`、`screenshotSource`、`inputCapabilities` | 统一 runtime session DTO，禁止上层直接按设备类型分叉 |
| App lifecycle | `triton app list/info/inspect/install/uninstall/launch/terminate/open-url` 已支持 `--scope simulator|emulator|real|all` 形态，iOS / Android / Harmony 逐步覆盖；`workspace run --app-mode launch` 已能把启动提交写入 `evidence/actions/app-ready.json` | 把未覆盖项收敛为 capability / unsupported / next action，不让调用方猜；`launch_submitted` 只代表启动命令提交，`launch_observed` 代表启动后拿到首帧观察，业务 ready 由 wait / verify 或 `--business-ready-text` checkpoint 证明 |
| Observe / hierarchy / WebView | 已有 runtime snapshot / AX / hierarchy、host layout、WebView provider、route/assertion 和 Inspect Session 状态模型 | Atlas graph 需要把这些 observation 转成 screen/state/transition 证据 |
| Device actions | `triton act find/tap/swipe/type/paste/clear/press/focus/set-text/select-segment/set-switch/input`；Web stream gesture 已走 `/web/host-input`；unsupported 输出已有稳定 envelope | LLM/VLM loop 只能调用这些动作入口，不能直接执行底层工具 |
| Evidence | `triton evidence capture --case <case> --output <dir.tritonevidence> --json`；证据 taxonomy 已覆盖 stdout/schema/status、host artifact、runtime snapshot/AX/ledger、input result、evidence bundle、tritonplan 等 | Atlas 和 VLM run 需要把 evidence id 作为共同索引 |
| Replay / workflow seed | `.tritonplan`、`triton record`、`triton plan inspect`、`triton replay --dry-run`、真实 `replay` 已有机器可读 failure / recovery surface | 从探索 session 生成可审查 workflow seed，而不是只录坐标 |
| Local LLM/VLM grounding | `triton vlm providers/ground/compare/model *` 轨道、MLX helper、模型 cache / download / preflight、grounding evidence artifacts 已有边界 | workspace run 默认启用 LLM/VLM 辅助理解和执行；每次模型参与都必须 evidence-backed、policy-gated，并写入 run ledger |
| Semantic provider | runtime manifest / snapshot 已能表达 semantic state/action provider、schema、actions、redaction、evidence commands | VLM 和 Atlas 应优先消费 provider-backed 业务语义，缺失时降级为截图/hierarchy |
| Web human slot | Web mock 已收敛到 stream / inspector；已有 target registry client、InspectTarget、InspectSession、hierarchy tabs、property sheet、stream gesture mapping | 新增 Map / Run summary 时只读 CLI/HTTP DTO，不新增 Web-only 业务语义 |

## 非目标

- 不复制 Revyl 的专有文案、交互或实现。
- 不在一期实现云设备、多租户、组织权限、计费、队列或远端 agent。
- 不把 Web/Wails 变成业务控制主入口。
- 不新增 Postgres、Kafka、Webhook 或托管控制平面。
- 不按真机/模拟器/仿真器拆产品入口；差异只能体现在 capabilities、unsupported error 和 next actions。
- 不让 VLM 直接绕过 Triton 执行裸 `xcrun` / `adb` / `hdc`；所有动作必须走 Triton CLI/HTTP。
- 不把默认开启 LLM/VLM 等同于模型直接执行动作；模型只能提出单步意图、候选 selector 或解释，实际动作仍由 Triton capability / policy / evidence gate 裁决。
- 不把自然语言测试建立在不可审计的 UI 猜测上；VLM 决策必须引用截图、hierarchy、Atlas 节点或机器可读状态。

## 一期范围

一期目标是把“新插槽”定义为本机 agent runtime workbench：

- Runtime Session：列出并选择本机 iOS / Android / Harmony target，覆盖真机、模拟器和仿真器。
- App Lifecycle：安装、启动、停止、重启当前 App。
- Device Actions：截图、点击、输入、滑动、等待、返回、Home 等已支持动作。
- Evidence：一次 session 能导出 evidence bundle。
- Workflow Seed：把一次成功探索保存为 `.tritonplan` 初稿。
- Atlas Map：从 evidence 生成本机 screen/state/transition/coverage 图谱。
- LLM/VLM Explore Loop：按 observe -> decide -> act -> verify -> record 循环自主探索本机 App。
- LLM/VLM Runtime Policy：workspace run 默认启用 LLM/VLM；本地 replay / 稳定回归仍要求模型全程参与流程启动、回正、验证和诊断，只是动作选择可被 policy 限制为 plan-first。
- Human Slot：Web 只展示 stream、inspector、evidence summary 和 workflow seed 状态。

## BDD 场景

### 场景 1：agent 启动本机 runtime session

Given 本机至少存在一个可用 mobile target，可能是真机、模拟器或仿真器
When agent 执行机器可读 target discovery 和 session start
Then TritonKit 返回稳定 JSON，包含 target id、platform、scope、capabilities、session id 和 next actions；不支持的动作返回明确 unsupported，而不是让 agent 判断设备类型

### 场景 2：agent 安装并启动 App

Given 已有本地 App artifact 或可解析 bundle/app id
When agent 通过 CLI/HTTP 安装并启动 App
Then 返回机器可读成功或明确 unsupported/error code，并保留 fallback 建议；在 workspace run 中，显式 `appMode=launch` 必须写入 `app.ready phase=launch_submitted` 和 `evidence/actions/app-ready.json`，若同一 run 继续 live observe 成功则升级为 `phase=launch_observed`、`ready=true`、`businessReady=false`；若 agent 同时传入 `businessReadyText` 并在 initial observation 命中，则必须写入 `evidence/business/ready.json`、`business.ready` 和 passed `verify.checked`，并以 `run.finished status=passed` 收尾；若 agent 显式传入 `businessReadyLiveWait=true`，则必须通过 runtime wait(text) 证明业务状态，并在同一 artifact 中写入 `check=runtime_wait`、`source=runtime.wait`、wait phase 和嵌套 wait 证据；若同一 run 还启用 `executeActions=true`，则 wait 必须在 action 成功后执行，通过时写 `stage=post_action`、`phase=post_action_wait_matched` 并把 Atlas transition 标为 `verified`

### 场景 3：agent 执行动作并采集证据

Given session 已 ready
When agent 执行 screenshot、tap、type、swipe 和 validation
Then 每步输出 JSON 结果，失败时包含错误码、目标、截图或 hierarchy 证据路径

### 场景 4：探索沉淀为可复跑 workflow

Given 一次探索 session 已完成
When agent 请求生成 workflow seed
Then TritonKit 生成可审查的 `.tritonplan` 初稿，包含步骤、变量、证据引用和 dry-run 校验入口

### 场景 5：Web 新插槽只消费事实

Given CLI/HTTP 已有 session 和 evidence 状态
When Web 新插槽打开 runtime workbench
Then Web 只读取 DTO 并展示 stream / inspector / evidence / plan seed，不直接定义业务控制能力

### 场景 6：本机 Atlas map 生成

Given 一个或多个本机 session 已产生 evidence bundle
When agent 请求生成 Atlas map
Then TritonKit 输出本机 screen/state/transition/coverage 图谱，并能追溯每个节点和边对应的截图、hierarchy、动作和时间戳；在 `workspace run --observe-live --execute-actions` 中，action 成功后必须二次 observe，写 `evidence/observations/0001.json`、`observation.captured phase=post_action`，并把 Atlas transition 记录为 `screen_0000 -> screen_0001`

### 场景 7：VLM 自主探索 loop

Given 本机 App 已启动且 LLM/VLM provider 可用或已配置
When agent 启动 workspace run 或 autonomous explore loop
Then LLM/VLM 默认参与 observe -> decide -> act -> verify -> record，每一步写入机器可读日志和 evidence；遇到危险动作、unsupported 能力、模型缺失或无法解释状态时停止并返回 next actions

### 场景 8：LLM/VLM 稳定启动和偏航回正

Given 同一条 flow 可能从登录页、首页、弹窗、深层页面或错误页启动
When agent 执行 workspace run 或本地 replay
Then LLM/VLM 先做 flow bootstrap 判断，运行中持续做 flow recovery 判断；每个 bootstrap / recovery proposal 都必须有 evidence、confidence、policy decision 和 next action

## 验收

- 对应 CLI/HTTP schema 明确列出 runtime session、app lifecycle、device action、evidence 和 workflow seed 能力。
- `workspace run` 必须区分 `dry`、`attach`、`launch` App lifecycle mode；只有显式 `launch` 会提交 host app launch，launch 后 live observation 可证明 App 已可观察，但不得把启动或首帧观察等同于业务完成；业务完成首期由 `--business-ready-text`、wait、assert 或后续 action verify 明确证明。
- 本机至少一个 target scope 完成端到端 smoke：target discovery -> session ready -> app launch -> screenshot -> action -> evidence export；后续按 capabilities 扩展到其他 scope。
- CLI/HTTP 和 Web DTO 必须以 target/capability 为事实源，不要求调用方预先区分真机、模拟器或仿真器。
- 本机 Atlas map 能从 evidence 生成可查询图谱，至少覆盖 screen、state、transition、coverage 和 evidence backlink。
- LLM/VLM 在 workspace run 中默认开启，默认用于流程稳定启动、偏航回正、理解、定位、Atlas 标注和探索决策；每次模型参与都能追溯 request / response / confidence / artifact，且所有动作经由 Triton CLI/HTTP。
- 显式 `--execute-actions` / HTTP `executeActions=true` 时，模型候选动作必须由 initial observation visibleTexts 派生并通过 runtime action provider 执行，写入 `evidence/actions/action-000.json`、`action.executed` 和 Atlas transition；只执行未验证时状态为 `executed_unverified`，搭配 `--observe-live` 时必须在 action 成功后再次采集 observation、写 `screen_0001/state_0001` 和 `screen_0000 -> screen_0001` transition，搭配 post-action runtime wait 通过后必须写 `business.ready` / passed `verify.checked` 并把 transition 标为 `verified`。
- Flow bootstrap 和 flow recovery 是 LLM/VLM 的首要验收：能从不同初始场景稳定命中 start anchor，能在 selector drift、弹窗、登录过期、慢加载时给出可审计 repair proposal。
- VLM 自主探索 loop 有可复跑 dry-run / bounded-run 模式；本地 replay / 稳定回归不能静默退出模型参与，只能把模型角色限制为 observer / verifier / repair-advisor。
- bounded-run 模式必须有机器可读 runner 边界：`maxSteps`、`allowedActions`、`stopConditions` 可通过 CLI/HTTP 设置并写入 run facts，后续真实 LLM/VLM loop 必须在这些边界内执行。
- 所有新增行为有 focused tests；HTTP handler 用 `httptest`，CLI 用参数解析/命令分发测试优先。
- Web 插槽若进入实现，只消费只读 DTO 或调用已存在 CLI/HTTP 控制契约，不新增独立业务语义。
- 文档、memory 和必要 skill 同步更新。

## 计划

- `plans/20260706-phase-0-scope-v01.md`
- `plans/20260706-serve-sim-maestro-landing-v01.md`
- `plans/20260706-run-requirements-technical-plan-v01.md`

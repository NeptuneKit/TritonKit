# 20260706 Serve-sim + Maestro Landing Plan

## 目标

把本地单机 Agent Mobile Runtime Platform 落成一个可执行产品方案：

- 借鉴 serve-sim 的本机 Apple Simulator streaming、normalized input、permission、camera 和 agent skill 经验。
- 借鉴 Maestro 的 black-box mobile testing、YAML flow、selector、smart wait、Studio authoring、artifact/report 和 AI 命令边界，但把 LLM/VLM 设为 workspace 默认理解层。
- 最终对外只暴露 TritonKit CLI/HTTP/evidence/plan 契约，不暴露 serve-sim / Maestro 作为运行时依赖或产品 API。

## 参考吸收边界

### serve-sim 吸收点

来源：`docs-linhay/references/serve-sim.md` 和本地快照 `docs-linhay/references/serve-sim/`。

吸收：

- 本机 helper lifecycle：start/list/status/stop 都必须有 JSON contract。
- MJPEG / framebuffer stream 只作为本机预览和 evidence 辅助，不是业务控制事实源。
- 归一化坐标可作为 UI/agent 友好输入，但 wire contract 必须保留设备 points、图像尺寸和 transform。
- tap 是单次动作 primitive；不要把 begin/end gesture 拆成两个独立请求伪装 tap。
- 设备级动作：button、rotate、memory warning、CoreAnimation debug 可进入 host adapter backlog。
- permission / camera injection 进入独立 capability，必须有 Debug-only、安全和清理边界。

不吸收：

- 不引入 Node/npm 作为 `triton` 默认运行依赖。
- 不复制 Web preview、`/.sim/exec`、远端 tunnel 或无认证 LAN 控制面。
- 不把 camera injection 放进 P0；只做独立 capability 设计。

### Maestro 吸收点

来源：Maestro 官方文档和历史 `20260620-vlm-test-runner` space。

吸收：

- black-box testing 思路：通过 accessibility tree 和 device-level commands 驱动 App。
- YAML flow：人类可读、可编辑、可提交到仓库。
- selector 模型：text、id、index、point，后续补 relational selector。
- smart wait：wait / scrollUntilVisible 必须是 runner primitive，不让用户手写循环。
- Studio authoring 思路：连接设备、点选元素、插入 flow step、逐步运行。
- artifacts / reports：screenshots、command trace、AI report、JUnit / HTML / JSON 可导出。
- LLM/VLM 默认参与流程稳定启动、偏航回正、理解、定位、Atlas 标注和探索决策；本地稳定回归仍全程调用模型做观察、验证和诊断，只把动作选择限制为 plan-first。

不吸收：

- 不做云并发执行或远端设备池。
- 不把 Maestro YAML 原样作为 TritonKit 唯一 DSL；先编译到 `.tritonplan` / evidence。
- 不把 AI assert 当天然 deterministic 断言；必须保留 evidence、confidence、required 策略和 pass/fail 归因。

## 产品架构

```text
Local Target Registry
  -> Runtime Session
  -> Observe / Action / Verify
  -> Evidence Ledger
  -> Atlas Builder
  -> Flow Runner
  -> LLM/VLM Explore Loop
  -> Web Human Slot
```

### 1. Local Target Registry

事实源：

- `platform`: `ios | android | harmony`
- `scope`: `simulator | emulator | real`
- `capabilities[]`: screenshot、input、hierarchy、webview、semantic、logs、network、camera、permissions 等。
- `sources[]`: host-layout、runtime-tree、webview-provider、framebuffer、vlm-provider。

要求：

- 上层不按真机 / 模拟器 / 仿真器分叉。
- 每个 action 先查 capability；缺失返回 stable unsupported envelope。
- Web 只消费 target registry DTO。

### 2. Evidence Ledger

Atlas、Flow、VLM 的共同底座。

每个 step 必须至少写入：

- `evidenceId`
- `target`
- `timestamp`
- `command`
- `input`
- `output`
- `artifacts[]`
- `source`
- `redaction`
- `result`

Artifact 类型：

- screenshot
- hierarchy / AX / host layout
- action result
- command trace
- logs
- network capture
- VLM request / response / overlay
- Atlas node / edge backlink
- `.tritonplan`

### 3. Flow DSL

当前落地优先复用已实现的 `.tritontest.yaml` 合约：`workspace export-flow` 从探索 run 导出 deterministic test seed，并用 `triton test validate/run` 做本地稳定回放。独立 `*.tritonflow.yaml` DSL 仍可作为后续演进，但执行前必须编译成 normalized `.tritonplan` 或 `.tritontest.yaml`，不能绕过现有验证器。

最小 DSL：

```yaml
name: login-smoke
target:
  platform: ios
  selector: current
steps:
  - launchApp:
      bundleId: com.example.app
  - tap:
      text: "Login"
  - inputText:
      text: "alice@example.com"
  - tap:
      text: "Continue"
  - assertVisible:
      text: "Home"
  - evidence:
      name: login-pass
```

Selector P0：

- `text`
- `id`
- `index`
- `point`
- `within`
- `at`

Selector P1：

- `above`
- `below`
- `leftOf`
- `rightOf`
- `childOf`
- `containsChild`
- `containsDescendants`

Runner primitive P0：

- launch / terminate / open-url
- screenshot
- tap / longPress / swipe / type / paste / clear
- assertVisible / assertNotVisible / waitUntilVisible
- scrollUntilVisible
- evidence

Runner primitive P1：

- permissions
- location
- orientation
- clipboard
- recording
- visual diff
- logs / network capture

### 4. Atlas Map

Atlas 是本地 evidence 的索引，不是独立数据孤岛。

Graph model：

```text
AppMap
  screens[]
  states[]
  transitions[]
  coverage
  evidenceBacklinks[]
```

Screen node 最小字段：

- `screenId`
- `title?`
- `signature`
- `dominantTexts[]`
- `semanticTags[]`
- `sampleEvidenceIds[]`
- `variants[]`

Transition edge 最小字段：

- `fromScreenId`
- `toScreenId`
- `action`
- `selector`
- `evidenceId`
- `confidence`

构建策略：

1. 从 screenshot + hierarchy + semantic provider 生成 observation。
2. 对 observation 做 screen signature。
3. signature 相近合并为 screen，明显差异进入 state variant。
4. action 前后 observation 建 transition。
5. coverage 只基于本机 evidence 统计。

CLI：

```bash
triton atlas build --evidence <dir.tritonevidence> --output <dir.tritonatlas> --json
triton atlas overview --atlas <dir.tritonatlas> --json
triton atlas map --atlas <dir.tritonatlas> --json
triton atlas screen <screen-id> --atlas <dir.tritonatlas> --json
```

### 5. LLM/VLM Explore Loop

LLM/VLM 是 workspace run 默认开启的理解层和探索引擎，不是直接设备控制器。默认开启的含义是：模型参与解释当前场景、消歧 selector、补全 Atlas 语义、提出下一步动作候选和生成 flow seed；实际动作仍必须经过 Triton capability / policy / evidence gate。

Loop：

```text
observe -> decide -> act -> verify -> record
```

硬边界：

- bounded-run only：`maxSteps`、`maxMinutes`、`allowedActions`、`stopConditions`。
- 每一步必须引用 evidence。
- 模型输出只允许一个 primitive action 或 `stop`.
- 所有动作必须通过 Triton CLI/HTTP。
- workspace run 默认启用 LLM/VLM；本地 replay / 稳定回归可以通过 policy 显式设置 `actionPolicy: planFirst`，但模型仍参与流程启动、观察、验证、诊断和修复建议。
- AI assert / extract 默认执行并记录证据；是否影响 pass/fail 由 `required`、step policy 或 runner policy 决定。

CLI：

```bash
triton explore run --target current --goal "reach the checkout screen" --max-steps 20 --evidence <dir> --json
triton explore inspect <run-dir> --json
triton explore export-plan <run-dir> --output checkout.tritonflow.yaml --json
```

Run step 输出：

```json
{
  "step": 4,
  "observationEvidenceId": "ev_004",
  "decision": {
    "summary": "Home screen is visible; checkout is not visible.",
    "action": "tap",
    "target": "Cart tab",
    "confidence": 0.72
  },
  "command": ["triton", "act", "tap", "Cart tab", "--json"],
  "resultEvidenceId": "ev_005",
  "atlasTransitionId": "edge_home_cart"
}
```

### 6. Web Human Slot

Web 插槽保持三类：

- `Live`: stream + input + current target status。
- `Inspect`: hierarchy / AX / property sheet。
- `Map`: Atlas graph、VLM run timeline、evidence backlinks、flow seed preview。

Web 不新增业务控制语义；按钮只调用已存在 CLI/HTTP DTO。

## 分期落地

### P0：事实底座和 flow validate

目标：证明“我们不是从零开始”，并锁住 schema。

交付：

- 已接入基础能力矩阵。
- `triton flow validate <file> --json`：离线校验，不连接设备。
- YAML -> normalized `.tritonplan` 编译。
- selector P0 schema。
- flow validation tests。

门禁：

- CLI schema tests。
- `.tritonplan` inspect / dry-run tests。
- `docs-linhay/scripts/check-docs.sh`。

### P1：本机 runner 闭环

目标：一个本机 target 跑通 Maestro-like deterministic flow。

交付：

- `triton flow run <file> --target current --evidence <dir> --json`
- launch -> observe -> action -> assert -> evidence。
- `scrollUntilVisible` primitive。
- failure recovery surface：`failureCode`、`nearestCandidates`、`suggestedCommands`、`evidenceId`。

门禁：

- focused CLI tests。
- HTTP handler `httptest`。
- 一个本机 smoke：target discovery -> launch -> flow run -> evidence。

### P2：Atlas build

目标：从 evidence 生成可查询 App map。

交付：

- `triton atlas build/overview/map/screen --json`
- screen/state/transition/coverage DTO。
- evidence backlink。
- Web Map slot 只读展示。

门禁：

- fixture evidence -> atlas snapshot tests。
- Web DTO rendering tests。

### P3：VLM grounding 接入 runner

目标：让 flow / workspace 默认可以用 VLM 找点和理解场景，但不让模型绕过 runner policy 自由执行。

交付：

- `tap: { target: "...", grounding: vlm }`
- grounding evidence：request、response、point、transform、overlay、model metadata。
- `assertWithAI` / `extractTextWithAI` 默认执行并记录 evidence；pass/fail 影响由 `required` 策略决定。

门禁：

- mock provider tests。
- MLX helper preflight smoke 可选手动跑。
- deterministic selector 不命中时可以按默认 policy 调用 VLM 消歧，但必须在输出里显式标记 `usedVLM=true`、confidence、artifacts 和 fallback 原因。

### P4：VLM bounded explore loop

目标：默认启用 LLM/VLM 的本机自主探索，并产出 Atlas + flow seed。

交付：

- `triton explore run/inspect/export-plan`
- bounded-run policy。
- every step evidence-backed。
- stop conditions 和危险动作策略。

门禁：

- bounded loop fixture tests。
- fake VLM deterministic run。
- 一个真实 target 手动 smoke。

### P5：serve-sim 能力吸收

目标：补齐本机 iOS Simulator 高价值 host primitives。

交付：

- normalized coordinate support。
- permission command。
- button / rotate / memory warning。
- stream metadata artifact。
- camera injection 独立 POC，不默认启用。

门禁：

- argv planner tests。
- no Node/npm runtime dependency in `triton`。
- destructive / injection commands require explicit policy flags。

## 文件与模块建议

少新增，优先复用现有边界：

- `Sources/TritonKitShared/*FlowModels.swift`
- `Sources/TritonKitShared/*AtlasModels.swift`
- `Sources/TritonKitShared/*ExploreModels.swift`
- `Sources/TritonKitCLI/CLIFlowCommands.swift`
- `Sources/TritonKitCLI/CLIAtlasCommands.swift`
- `Sources/TritonKitCLI/CLIExploreCommands.swift`
- `Web/src/components/MapCard.tsx`

不要新增数据库。首期所有本地 artifact 用目录结构：

```text
<case>.tritonevidence/
<case>.tritonatlas/
<case>.tritonflow.yaml
<case>.tritonplan
```

## 关键取舍

- Flow runner 和 LLM/VLM loop 共享 evidence，不共享隐式内存。
- Atlas 是 VLM 的长期本地地图，VLM 是 Atlas 的探索器。
- Maestro-like deterministic runner 先于 VLM autonomous loop。
- serve-sim 的 streaming/input 经验进入 host adapter，不进入 Web-only 控制面。
- LLM/VLM capability 默认开启并 assistive；只有显式 required 或 runner policy 允许时才能影响 pass/fail。

## Triton 命令映射

### Maestro-like flow 到 Triton

| Flow step | Triton primitive | P0/P1 处理 |
| --- | --- | --- |
| `launchApp` | `triton app launch --json` | P0 validate，P1 执行 |
| `tapOn` / `tap` | `triton act tap ... --json` | P0 text/id/point/at，P1 relational selector |
| `inputText` | `triton act type ... --json` 或 `triton act set-text ... --json` | 优先 provider-backed set-text，缺失时 type |
| `eraseText` | `triton act clear ... --json` | unsupported 必须稳定返回 |
| `assertVisible` | `triton verify text-exists ... --json` 或 `triton wait ... --json` | P1 必做 |
| `assertNotVisible` | `triton verify text-not-exists ... --json` | P1 必做 |
| `scrollUntilVisible` | `triton flow` runner loop: find -> swipe -> find | P1 runner primitive，不展开给用户写 |
| `takeScreenshot` | `triton screenshot` / `triton evidence capture` | P1 归入 evidence |
| `openLink` | `triton app open-url ... --json` | P1 |
| `setLocation` | `triton device location` 或 host adapter 后续命令 | P1/P5，按 capability |
| `setOrientation` | `triton sim rotate` 或 host adapter 后续命令 | P5 |
| `copyTextFrom` / extraction | `triton observe` + selector extraction；AI extract 后置 | P2/P3 |
| `assertWithAI` | `triton vlm assert` 或 explore/flow AI step | P3，默认执行并写 evidence；是否影响 pass/fail 看 `required` |
| `assertNoDefectsWithAI` | VLM defect scan artifact | P3/P4，默认执行并写 evidence；是否影响 pass/fail 看 `required` |

### serve-sim 到 Triton

| serve-sim 能力 | Triton 落点 | 处理 |
| --- | --- | --- |
| `--detach -q` / `--list -q` / `--kill` | `triton target session start/list/stop --json` 或现有 `serve`/target registry | P0 先定义 DTO，不复制 daemon |
| MJPEG stream | Web Live slot + evidence stream metadata | 已有 Web stream 基础，P5 补 artifact |
| normalized tap | `triton act tap --normalized x,y --json` | P5，wire 输出 points + transform |
| gesture begin/move/end | `triton act swipe/drag/input --json` | 多步 gesture 必须单请求，tap 不能拆 begin/end |
| hardware button | `triton act press home|lock|... --json` | P5 按 capability |
| rotate | `triton target orientation set ... --json` | P5 |
| permissions | `triton permissions grant/revoke/reset/list --json` | P5，覆盖 simulator 能力先行 |
| camera injection | `triton camera ... --json` | 独立 POC，Debug-only + 清理验证 |
| AX endpoint | `triton observe tree --json` | 已有 observe/hierarchy 基础，P2 入 Atlas |
| logs | `triton logs` / evidence artifact | P5 或已有日志面复用 |

## DTO 草案

### Flow Validate

```json
{
  "ok": true,
  "kind": "triton.flow.validate-result",
  "schemaVersion": 1,
  "flow": {
    "name": "login-smoke",
    "path": "login.tritonflow.yaml",
    "stepCount": 6
  },
  "normalizedPlan": {
    "path": "login.tritonplan",
    "steps": [
      {
        "index": 0,
        "id": "launch-app",
        "action": "app.launch",
        "argv": ["app", "launch", "--bundle-id", "com.example.app", "--json"],
        "requires": ["target", "app"],
        "expectedArtifacts": ["stdout-json"]
      }
    ]
  },
  "validationErrors": [],
  "warnings": []
}
```

### Flow Run

```json
{
  "ok": true,
  "kind": "triton.flow.run-result",
  "schemaVersion": 1,
  "flowName": "login-smoke",
  "target": {
    "platform": "ios",
    "scope": "simulator",
    "selector": "current",
    "capabilities": ["screenshot", "hierarchy", "input"]
  },
  "evidenceDir": "login-smoke.tritonevidence",
  "steps": [
    {
      "index": 2,
      "action": "tap",
      "selector": { "text": "Continue" },
      "command": ["triton", "act", "tap", "Continue", "--json"],
      "ok": true,
      "evidenceId": "ev_0003",
      "artifacts": ["artifacts/screenshots/0003-after.png"]
    }
  ],
  "atlasUpdate": {
    "screenCount": 2,
    "transitionCount": 1
  }
}
```

### Atlas Build

```json
{
  "ok": true,
  "kind": "triton.atlas.build-result",
  "schemaVersion": 1,
  "atlasDir": "login-smoke.tritonatlas",
  "sourceEvidence": ["login-smoke.tritonevidence"],
  "screens": [
    {
      "screenId": "screen_login",
      "signature": "ios:login:2d8f",
      "dominantTexts": ["Email", "Password", "Continue"],
      "sampleEvidenceIds": ["ev_0001"],
      "variants": ["empty", "filled"]
    }
  ],
  "transitions": [
    {
      "transitionId": "edge_login_home",
      "fromScreenId": "screen_login",
      "toScreenId": "screen_home",
      "action": "tap",
      "selector": { "text": "Continue" },
      "evidenceId": "ev_0004",
      "confidence": 0.91
    }
  ],
  "coverage": {
    "screenCount": 2,
    "transitionCount": 1
  }
}
```

### Explore Run

```json
{
  "ok": true,
  "kind": "triton.explore.run-result",
  "schemaVersion": 1,
  "goal": "reach checkout",
  "policy": {
    "maxSteps": 20,
    "allowedActions": ["tap", "swipe", "type", "wait", "stop"],
    "dangerousActions": ["uninstall", "delete", "purchase"]
  },
  "steps": [
    {
      "index": 1,
      "observeEvidenceId": "ev_0101",
      "decisionEvidenceId": "ev_0102",
      "action": "tap",
      "target": "Cart tab",
      "confidence": 0.74,
      "resultEvidenceId": "ev_0103",
      "atlasTransitionId": "edge_home_cart"
    }
  ],
  "stopReason": "goal_reached",
  "exportedFlow": "reach-checkout.tritonflow.yaml"
}
```

## 本地文件布局

```text
.triton/
├── flows/
│   └── login-smoke.tritonflow.yaml
├── plans/
│   └── login-smoke.tritonplan
└── runs/
    └── 20260706-153000-login-smoke/
        ├── run.json
        ├── login-smoke.tritonevidence/
        ├── login-smoke.tritonatlas/
        └── reports/
            ├── report.json
            ├── junit.xml
            └── index.html
```

规则：

- `.triton/flows/**` 可提交。
- `.triton/plans/**` 可提交，但 secure 变量必须保留占位。
- `.triton/runs/**` 默认不提交，除非用户明确要求归档证据。
- `.tritonevidence` 默认视为敏感，公开 issue 前必须脱敏。

## 测试矩阵

| 层 | 最小测试 | 真实 smoke |
| --- | --- | --- |
| Flow parser | YAML fixture -> typed model | 不需要 |
| Flow validate | invalid selector / missing app / duplicate step id | 不需要 |
| Plan compile | Flow -> `.tritonplan` argv snapshot | 不需要 |
| Selector resolver | text/id/point/index/within fixture hierarchy | 不需要 |
| Runner | fake CLI executor step order / failure routing | 一个 target 手动 smoke |
| Evidence ledger | artifact manifest / redaction / backlink | evidence capture smoke |
| Atlas builder | fixture evidence -> graph snapshot | 用真实 evidence 构建一次 |
| VLM grounding | mock provider / parser / overlay | MLX helper 手动 preflight |
| Explore loop | fake VLM bounded run / stop policy | 一个 App 手动 bounded run |
| Web Map | DTO render / backlink click | Playwright 截图 smoke |

## 第一批实现 Issue 切片

### Issue A：Flow validate only

写入面：

- `Sources/TritonKitShared/*FlowModels.swift`
- `Sources/TritonKitCLI/CLIFlowCommands.swift`
- `CLI/Tests/...FlowValidateTests.swift`

验收：

- 已落地路径：`triton workspace export-flow <run-id> --output login.tritontest.yaml --json`，随后 `triton test validate login.tritontest.yaml --json`
- 后续独立 DSL 路径：`triton flow validate login.tritonflow.yaml --json`
- invalid YAML 返回单个 JSON envelope。
- 输出 normalized plan preview，不连接设备。

### Issue B：Flow compile to tritonplan

写入面：

- 复用 replay plan model。
- 增加 flow -> plan compiler。

验收：

- P0 primitives 编译出稳定 argv。
- `triton plan inspect` 能读取编译产物。
- `replay --dry-run` 能校验变量。

### Issue C：Selector resolver P0

写入面：

- shared selector model。
- CLI resolver fixture tests。

验收：

- text/id/index/point/within 均可解析。
- 多候选返回 nearestCandidates / suggestedCommands。
- 找不到返回 `text_not_found` 或 selector-specific code。

### Issue D：Evidence ledger step id

写入面：

- evidence manifest model 增补 `flowStepId` / `atlasBacklinks`。

验收：

- 每个 runner step 都有 evidence id。
- Atlas builder 可反查截图和 hierarchy。

### Issue E：Atlas fixture builder

写入面：

- `Sources/TritonKitShared/*AtlasModels.swift`
- `Sources/TritonKitCLI/CLIAtlasCommands.swift`

验收：

- fixture evidence -> screen/state/transition JSON。
- `atlas overview/map/screen` 可查询。

### Issue F：Explore fake loop

写入面：

- `Sources/TritonKitShared/*ExploreModels.swift`
- `Sources/TritonKitCLI/CLIExploreCommands.swift`

验收：

- fake VLM 按固定 observation 输出一个动作。
- maxSteps/allowedActions/stopConditions 生效。
- 每步写 decision evidence。

## Selector Resolution v1

Selector resolver 是 Flow runner 的核心，不能散落在各 command 里。

输入：

```json
{
  "selector": {
    "text": "Continue",
    "id": null,
    "index": 0,
    "within": null,
    "at": null
  },
  "target": {
    "platform": "ios",
    "scope": "simulator"
  },
  "sources": ["semantic-provider", "runtime-tree", "host-layout", "vlm-grounding"]
}
```

解析顺序：

1. `at` / `point`：直接生成坐标候选，但仍记录 coordinate transform。
2. semantic provider：若 provider 明确返回 action target，优先使用。
3. runtime tree / AX：按 id、text、role、label、value、frame 匹配。
4. host layout：按可见文本、bounds、clickable/visible metadata 匹配。
5. VLM grounding：workspace 默认允许调用；flow / replay 可用 `actionPolicy: planFirst` 限制模型不生成任意新动作，但模型仍参与流程启动、偏航回正、定位、验证和 drift 诊断。

评分字段：

- exact text match
- id match
- visibility
- enabled / hittable
- area sanity
- role preference
- source priority
- relational selector score
- distance to `within` center 或 `at` fallback

输出：

```json
{
  "ok": true,
  "kind": "triton.selector.resolve-result",
  "chosen": {
    "source": "runtime-tree",
    "nodeId": "ios-runtime:42",
    "point": { "x": 122, "y": 640 },
    "frame": { "x": 80, "y": 610, "width": 240, "height": 64 },
    "confidence": 0.94
  },
  "candidates": [],
  "evidenceId": "ev_selector_0001"
}
```

失败要求：

- 0 个候选：`text_not_found` / `selector_not_found`。
- 多个强候选：`ambiguous_selector`，返回 `nearestCandidates[]` 和 `suggestedCommands[]`。
- source 不可用：`unsupported_capability`，说明缺失 source 和 next action。

## Smart Wait / Scroll v1

`waitUntilVisible` 和 `scrollUntilVisible` 必须是 runner primitive。

`waitUntilVisible`：

```text
deadline = now + timeout
while now < deadline:
  observe
  resolve selector
  if found and visible: pass
  sleep pollInterval
fail with last observation evidence
```

`scrollUntilVisible`：

```text
deadline = now + timeout
swipes = 0
while now < deadline and swipes < maxSwipes:
  observe
  resolve selector
  if found and visible enough: pass
  swipe(direction)
  swipes += 1
fail with last observation evidence and tried swipes
```

要求：

- 每次 observe、resolve、swipe 都要有 evidence id。
- 默认 `maxSwipes` 必须有限制。
- 不允许无限滚动。
- 成功时记录找到目标的 source、frame 和 confidence。
- 失败时返回最后一帧 screenshot / hierarchy artifact。

## Atlas Signature v1

首版 Atlas 不做 ML 聚类，使用 deterministic signature。

Observation 输入：

- screenshot hash / perceptual hash 可选
- hierarchy text set
- visible role set
- semantic provider domain/state
- route / WebView URL
- app foreground metadata
- top-level title candidates

Screen signature：

```text
platform + appId + normalizedRoute + stableTitle + topVisibleTextHash + roleShapeHash
```

归一化规则：

- 去掉明显动态数字、时间、计数和 UUID。
- 文本过长时只保留前 N 个稳定 token。
- loading / empty / error / permission prompt 作为 variant，不拆成独立 screen，除非 route 或主标题变化。
- WebView URL 只保留 host/path，query 默认进入 variant metadata。

Variant 判断：

- loading
- empty
- populated
- error
- permission
- modal
- sheet
- keyboard
- webview

Transition 判断：

- action 前后 screenId 不同：新 edge。
- screenId 相同但 variant 不同：state transition。
- 连续 wait / observe 不生成 edge，只补 coverage sample。

## VLM Decision Protocol v1

VLM loop 输入必须是压缩事实，不直接给模型无限上下文。

输入包：

```json
{
  "goal": "reach checkout",
  "allowedActions": ["tap", "swipe", "type", "wait", "stop"],
  "currentScreen": {
    "screenId": "screen_home",
    "dominantTexts": ["Home", "Cart", "Profile"],
    "atlasNeighbors": ["screen_cart"]
  },
  "evidence": {
    "screenshot": "artifacts/screenshots/001.png",
    "hierarchySummary": "..."
  },
  "lastActions": []
}
```

模型输出只允许 JSON：

```json
{
  "summary": "Cart tab is visible and likely leads to checkout.",
  "action": "tap",
  "target": "Cart tab",
  "confidence": 0.74,
  "expected": "Cart screen opens"
}
```

Policy gate：

- `action` 必须在 `allowedActions`。
- `confidence < minConfidence` 时改为 `stop` 或 `observe`。
- 目标涉及 purchase/delete/logout/uninstall 等危险语义时 stop。
- 连续 N 次无新 screen / variant 时 stop。
- 同一 action 重复超过阈值时 stop。
- 模型输出非 JSON 或多 action 时 fail closed。

每步 evidence：

- `vlm-request.redacted.json`
- `vlm-response.raw.txt`
- `vlm-decision.json`
- action result
- before / after screenshot
- Atlas transition 或 no-op reason

## Report Export v1

Report 是 evidence 的索引视图，不是另一个事实源。

输出：

```text
reports/
├── report.json
├── junit.xml
├── index.html
└── artifacts/
```

`report.json` 必须包含：

- target summary
- flow / explore summary
- pass/fail
- failure code
- failed step
- evidence dir
- atlas dir
- command trace
- redaction summary
- environment summary

`junit.xml`：

- 每个 flow step 可映射 testcase。
- failure message 使用 stable error code。
- artifact path 放 system-out，不内联大内容。

`index.html`：

- 本地静态文件，不需要 server。
- 只引用本地 artifacts。
- 默认隐藏 sensitive artifact，除非 redaction 通过。

## Config v1

`.triton/test.yaml`：

```yaml
flows:
  - .triton/flows/**/*.tritonflow.yaml
includeTags: []
excludeTags: []
testOutputDir: .triton/runs
defaultTarget:
  selector: current
runner:
  timeout: 120s
  evidence: true
  actionPolicy: explore
llm:
  enabled: true
  provider: local-or-configured
  mode: assistive
vlm:
  enabled: true
  provider: mlx-swift-lm
  mode: assistive
  evidenceRequired: true
  requiredForPassByDefault: false
atlas:
  enabled: true
  signatureVersion: 1
```

规则：

- config 只给默认值，命令行 flag 优先。
- `llm.enabled=true` 与 `vlm.enabled=true` 是 workspace run 默认值，用于最大化理解场景和执行意图。
- `runner.actionPolicy=planFirst` 是稳定回归开关：动作按既有 plan 优先，LLM/VLM 仍参与流程启动、偏航回正、观察、验证、drift 诊断和修复建议。
- `requiredForPassByDefault=false` 表示模型结论默认写 evidence 和建议，不默认单独决定 pass/fail。
- secret 只能走 env var，不进 YAML 明文。
- `testOutputDir` 不能默认进入 git。

## P0 DoD

P0 完成定义：

- `triton flow validate --json` 存在。
- 不连接设备也能验证 YAML、selector shape、step schema、变量和 secure placeholders。
- validate 输出 normalized plan preview。
- P0 DSL fixture 覆盖 valid、missing target、unknown step、ambiguous selector shape、secure variable、unsupported option。
- schema 中出现 `flow` command，并有 output contract。
- capabilities matrix 暴露 `flow-validate`，但不声称已能运行真实设备 flow。
- docs 和 memory 更新。

## 风险与约束

| 风险 | 约束 |
| --- | --- |
| DSL 越做越大 | P0 只做 Maestro-like 子集，所有 step 必须编译到现有 Triton primitive |
| Atlas 聚类不稳定 | 首版使用 deterministic signature，不先引入 ML clustering |
| VLM 幻觉动作 | bounded-run、allowedActions、每步 evidence、危险动作 stop |
| 默认开启模型导致结果不可解释 | 所有 LLM/VLM 参与都写 request / response / confidence / artifacts，并区分 assistive 与 required |
| 真机与模拟器差异 | 产品层只看 capability，unsupported 必须可审计 |
| Web 变控制台 | Web Map 只读 DTO，业务动作仍走 CLI/HTTP |
| evidence 泄漏隐私 | `.tritonevidence` 默认敏感，导出报告必须支持 redaction |
| serve-sim camera 注入风险 | 独立 capability，Debug-only，必须有清理和验证 |
| runner 与 replay 两套模型 | Flow 必须先编译 `.tritonplan`，真实执行复用 replay/action/evidence |

## 不做清单

- 不直接运行 Maestro。
- 不直接运行 serve-sim。
- 不引入云设备池。
- 不新增数据库。
- 不让默认启用 LLM/VLM 变成无证据、无边界或无 policy 的裸执行。
- 不让模型输出多步 plan 后直接执行。
- 不把截图或证据默认上传远端模型。

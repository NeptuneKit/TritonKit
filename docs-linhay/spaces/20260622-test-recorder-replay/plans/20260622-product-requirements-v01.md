# Test Recorder Replay Product Requirements v01

> Space: `20260622-test-recorder-replay`
> Status: draft requirements
> Date: 2026-06-22

## 背景

本 space 定义一个面向测试的 TritonKit 产品面：录制一次真实执行过程中的动作、网络数据和页面状态，再把它编译成可回放、可断言、可生成证据的测试用例。核心目标是 **一端执行，多端回放测试**。

用户给出的方向是：

- 面向测试产品，而不是单纯 debug 工具。
- 主要能力是录制：动作、网络数据、页面。
- 一端执行，多端回放测试。
- 单独路由。
- 需求补充要参考之前 map 相关需求，并主要看竞品。

本需求不从 Web/Wails 业务控制入口开始。TritonKit 现有原则仍成立：业务控制优先落在 CLI / HTTP 管理 API / 机器可读契约；Web 如果后续需要，只作为只读设计或运行结果展示，不承载 create/update/delete/execute/approve/deny 控制闭环。

## 相关本地背景

- `.tritonplan` 已有基础 record / inspect / replay 概念，但当前 `record` 仍是可编辑模板生成，不捕获真实动作历史。
- `.tritonevidence` 已作为证据包目录格式，包含 manifest、snapshot、screenshot、host / xcode artifact 等。
- `device proxy` 已有三端网络接管规划和部分实现：record / mock / block / throttle、capture export、policy rules、metadata-only network event。
- `webview` / `route` 已有 current URL、snapshot、events、provider capability 方向。
- Rockxy 参考中 map local / map remote / request replay / traffic capture 是网络侧“录制后稳定复现”的关键参考；Atlantis 参考是 App 内 opt-in traffic capture 的边界参考。

本 space 的定位是在这些底座之上补一个测试产品层，而不是把 network takeover、evidence、webview snapshot 分散命令简单拼接给用户。

## 竞品观察

| 竞品 / 参考 | 可借鉴点 | TritonKit 不能照搬的点 |
| --- | --- | --- |
| [Playwright Test Generator](https://playwright.dev/docs/codegen) | 用户边操作边生成测试，定位器优先用 role / text / test id，降低首条用例成本。 | 主要面向浏览器；TritonKit 需要覆盖 iOS Simulator、Android Emulator、Harmony / DevEco Emulator 与 WebView/native hybrid。 |
| [Playwright Trace Viewer](https://playwright.dev/docs/trace-viewer) | 失败后用 trace 查看动作、页面快照、网络等上下文，适合 CI 失败诊断。 | Trace 是 Playwright 脚本运行后的调试产物；TritonKit 需要从真实端执行中生成跨端回放契约。 |
| [Cypress Studio](https://docs.cypress.io/app/guides/cypress-studio) | 从交互过程中补测试步骤，降低测试作者门槛。 | Cypress 主要服务浏览器 E2E；TritonKit 的动作模型必须是平台无关语义动作，而不是 DOM-only 步骤。 |
| [Cypress Network Requests](https://docs.cypress.io/app/guides/network-requests) | `cy.intercept()` 式网络 stub 能把不稳定后端钉成可重复测试输入。 | TritonKit 不应该把网络 mock 绑定到单一测试框架；需要产出 agent 可读的 network map / fixture / policy rules。 |
| [Maestro Studio](https://docs.maestro.dev/getting-started/maestro-studio) / [Maestro commands](https://docs.maestro.dev/reference/commands-available) | 移动端 flow 用 YAML/命令式动作表达，支持截图、recording commands，适合跨端人机流程。 | Maestro 更偏动作流；TritonKit 需要把动作、网络、页面状态合并成一个可断言测试合同。 |
| Rockxy 本地参考：`docs-linhay/references/rockxy.md` | Map Local / Map Remote、Request Replay、HAR/session、规则持久化、证书/代理恢复安全。 | Rockxy 是网络代理产品；TritonKit 不复制 UI，而是吸收网络映射和复现语义到测试录制包。 |
| Atlantis 本地参考：`docs-linhay/references/atlantis.md` | App 内 opt-in capture 可补 host proxy 看不到的 runtime 网络事件。 | 不能默认注入业务 App 或把 embedded SDK 当作三端网络接管前置条件。 |

竞品结论：

1. Playwright / Cypress 证明“录制动作 + 页面快照 + 网络上下文”是测试生产力入口。
2. Maestro 证明移动端动作流需要平台无关、可读、可编辑，而不是坐标脚本。
3. Rockxy / Cypress 证明稳定测试必须把网络数据转成 fixture、map、stub 或 policy，而不是只保存 HAR。
4. TritonKit 的差异化应是：一次端上真实执行，生成跨端回放测试合同，并用证据包证明每端结果。

## 产品定义

暂定产品名：**Triton Test Recorder**。

## 产品裁决：先交付 Test Recorder，后抽 Agent Runtime

本需求已经开始溢出传统 Recorder 边界。它表面是 Test Recorder，但核心能力已经包括 Action Map、Page Map、Network Map、Contract Compile、VLM Fingerprint、LLM Proposal、Cross Platform Replay、Capability Matrix 和 Evidence System。

这些能力的长期归属更像：

~~~text
Triton Runtime
└── Triton Test
    └── Test Recorder
```

而不是：

```text
TritonKit
└── Test Recorder
```

其中最有价值的不是“录制”，而是：

```text
一端录制合同
多端证据化回放
```

这已经接近 Semantic Action Contract，而不是传统 recorder script。

但是当前阶段不提前抽象 Runtime。P0 继续按 Test Recorder 交付：先把 `.tritontestcase`、inspect、compile、replay 跑通。等 replay 真实跑通后，再新开 `2026xxxx-agent-runtime` space，重新定义 Triton Runtime Contract，并把 Action Map、Page Map、Network Map 从 Test Recorder 内部能力抽到 Agent 执行语义层。

后续可能演进为：

```text
Triton Runtime
│
├── Observe
│   ├── Screenshot
│   ├── Hierarchy
│   ├── Network
│   └── Fingerprint
│
├── Action Contract
├── Page Contract
├── Network Contract
├── Evidence
└── Products
    ├── Inspector
    ├── Test Recorder
    ├── Agent Runner
    └── Replay Studio
```

当前执行原则：

1. P0 不扩成平台级 Runtime 重构。
2. P0 不急着做 Web；Web 只做只读展示，不定义业务控制能力。
3. Action Map / Page Map / Network Map 先服务 Test Recorder，避免提前抽象导致实现失焦。
4. replay 跑通后再评估抽象边界，用真实失败、真实合同和真实 evidence 反推 Agent Runtime。
5. 新开 Agent Runtime space 前，不把 TritonKit 重新定位为自动化测试框架；Test Recorder 只是 Runtime 能力的第一个产品消费者。

核心对象不是“录屏”，而是一次可编译的测试录制包：

```text
<case>.tritontestcase/
├── manifest.json                 # schema、来源端、目标矩阵、redaction、版本
├── actions.jsonl                 # 语义动作流：tap/type/swipe/wait/assert/open-url 等
├── network/
│   ├── capture.ndjson            # 原始或脱敏后的 network event
│   ├── map-rules.json            # 从 capture 提炼出的稳定回放规则
│   └── fixtures/                 # 可选 response fixture
├── pages/
│   ├── route-events.jsonl         # route / URL / navigation / view identity
│   ├── snapshots.jsonl            # AX / DOM / semantic snapshot 摘要
│   └── screenshots/               # 关键帧截图
├── assertions.json                # 自动提炼 + 人工确认的断言
├── replay-matrix.json             # 目标端矩阵与能力约束
└── evidence-links.json            # 每次录制/回放关联的 .tritonevidence
```

### 三条录制流

1. **动作流**：用户或 agent 在源端执行的语义动作，优先记录 selector、role、text、accessibility id、route context 和候选消歧信息；坐标只作为 fallback evidence，不作为首选回放合同。
2. **网络流**：请求/响应 metadata、命中规则、fixture、mock/block/throttle 策略、redaction/truncation 状态；可从 host proxy capture 或 App runtime opt-in capture 合并。
3. **页面流**：route URL、native route state、WebView current URL、DOM/AX/semantic snapshot、关键截图、页面稳定性信号。

### 一端执行，多端回放

源端可以是 iOS、Android、Harmony 或 WebView/native hybrid 中任意一个端。回放时不直接复制平台私有事件，而是执行抽象测试合同：

- 源端动作 `tap text=登录` 可在目标端解析为 AX node、DOM element、semantic action 或坐标 fallback。
- 源端网络请求 `/api/user/profile` 可被编译为 map fixture 或 policy rule，在目标端保持同一业务输入。
- 源端页面断言 `route=profile && text=用户中心` 可在目标端用 route / WebView URL / AX / DOM 多层证据确认。

回放结果必须输出每端独立的 `.tritonevidence`，并汇总为一个 run report。

### VLM / LLM 辅助跨端回放

一端录制生成合同后，在另外一端回放时需要 VLM / LLM 参与目标端映射，但它们不是最终事实源。

典型用法：

- VLM 读取目标端 rendered surface，辅助判断当前页面是否对应源端 Page Map，例如登录页、首页、错误页、空白页、弹窗遮挡。
- VLM 在目标端截图上辅助定位源端 action 的等价目标，例如“登录按钮”“用户名输入框”“底部 tab 第二项”。
- VLM 按界面元素为页面生成匹配指纹，回放时用目标端页面指纹匹配源端合同中的页面指纹，作为 page-level replay evidence。
- LLM 结合测试合同、Page Map、Action Map、AX / DOM / semantic snapshot、network map 和历史 step，生成目标端下一步动作建议。
- LLM 在 selector 失败时解释失败原因，并给出候选 fallback：改用 text、accessibility label、semantic field、within 区域、等待页面稳定或跳过 unsupported capability。
- VLM / LLM 可以生成候选 assertion，但 assertion 必须再落到 route、AX、DOM、semantic field、network event 或 screenshot evidence 的结构化校验。

回放执行规则：

1. 回放引擎先用确定性映射执行：test id、accessibility id、semantic field、route、DOM selector、known network map。
2. 确定性映射失败或目标端结构差异明显时，调用 VLM / LLM 生成候选动作或候选断言。
3. 模型输出必须是结构化 proposal，包含 `proposalKind`、`targetEvidence`、`confidence`、`reason`、`fallbackUsed` 和可执行的 Triton action payload。
4. 真正执行仍通过 Triton CLI / HTTP action contract，例如 `act tap`、`act type`、`verify text-exists`，不能由模型直接调用平台工具。
5. 执行后必须用机器可读证据确认结果；模型判断“看起来成功”不能单独让 step pass。
6. 当模型不可用、置信度不足或候选不唯一时，返回明确 failure / needs-review，而不是猜测坐标继续。

这意味着 Test Recorder 的 replay 不是简单脚本重放，而是“合同驱动 + 结构化证据 + 模型辅助迁移”的跨端测试执行。

### VLM 页面匹配指纹

VLM 可以按界面元素为页面生成 matching fingerprint。这个 fingerprint 是跨端回放的重要证据：它不要求 iOS / Android / Harmony 的 UI 结构完全一致，但要求关键业务元素、视觉区域和页面语义能匹配。

录制阶段，源端页面生成 `pages/fingerprints.jsonl`：

```json
{
  "kind": "page.visual-fingerprint.v1",
  "pageId": "login",
  "sourceEvent": "screenshot:14",
  "routeHint": "login",
  "elements": [
    {
      "roleHint": "text-field",
      "label": "手机号",
      "region": { "x": 32, "y": 286, "width": 326, "height": 48 },
      "visualTokens": ["input", "phone", "placeholder"],
      "required": true
    },
    {
      "roleHint": "button",
      "label": "登录",
      "region": { "x": 32, "y": 412, "width": 326, "height": 48 },
      "visualTokens": ["primary-button", "login"],
      "required": true
    }
  ],
  "layoutSignature": "vertical-form:phone-password-primary-button",
  "model": { "provider": "vlm", "version": "<model-version>" },
  "confidence": 0.84,
  "redaction": { "sensitiveRegionsMasked": true }
}
```

回放阶段，目标端也生成同类 fingerprint，并产出匹配证据：

```json
{
  "kind": "page.visual-fingerprint-match.v1",
  "sourcePageId": "login",
  "targetPlatform": "android",
  "matchScore": 0.81,
  "matchedRequiredElements": ["手机号", "登录"],
  "missingRequiredElements": [],
  "visualDrift": [
    { "type": "layout-spacing-different", "severity": "info" }
  ],
  "evidence": {
    "sourceFingerprint": "pages/fingerprints.jsonl#14",
    "targetScreenshot": "artifacts/android/screenshot-step-2.png"
  }
}
```

使用规则：

1. 页面指纹用于证明“目标端当前页面与源端合同页面等价”，不是证明某个业务断言一定通过。
2. 指纹由界面元素、区域、视觉 token、layout signature、route hint 和 redaction 状态组成。
3. required elements 缺失时，页面匹配失败或进入 needs-review。
4. 指纹匹配结果必须进入 `.tritonevidence` 或 run report，供 Page-level Inspector 展示。
5. 如果 AX / DOM / semantic snapshot 与 VLM 指纹矛盾，优先暴露冲突，不直接选择一边伪成功。
6. 模型版本、输入截图、脱敏状态和置信度必须进入 evidence，保证后续可审计。

这让回放不再只依赖文本或 selector，而是多了一层 page-level visual evidence：当前目标端页面是否真的像源端合同描述的那个页面。

#### Fingerprint 匹配度计算

Fingerprint 匹配度由确定性 matcher 计算，LLM 不直接决定分数或 pass/fail。VLM 负责把截图转成结构化 fingerprint；matcher 负责可审计地计算匹配度。

建议评分结构：

```text
matchScore =
  requiredElementScore * 0.35 +
  semanticTokenScore   * 0.20 +
  layoutScore          * 0.20 +
  routeHintScore       * 0.15 +
  visualStateScore     * 0.10
```

评分规则：

- `requiredElementScore`：必需元素是否都能在目标端找到。缺少关键 required element 时，不管总分多少，结果最多只能是 `needs-review` 或 fail。
- `semanticTokenScore`：比较 label、roleHint、visualTokens、可见文本、AX / DOM / semantic field 的等价性。
- `layoutScore`：比较元素相对位置、视觉层级、主要区域顺序和 layoutSignature，不要求像素级一致。
- `routeHintScore`：比较 route、URL、页面标题、native route state、WebView current URL 等结构化页面身份。
- `visualStateScore`：比较空态、loading、弹窗、toast、错误态、键盘遮挡等页面状态。

元素配对规则：

1. 先按稳定结构化字段配对：test id、accessibility id、semantic field、DOM selector。
2. 再按 label / roleHint / visualTokens 配对。
3. 再按相对区域和 layout order 配对。
4. 仍不唯一时返回 ambiguity，不用任意最高分候选伪成功。

建议阈值：

| 匹配结果 | 条件 |
| --- | --- |
| `matched` | `matchScore >= 0.82`，required elements 全部命中，且无高严重度冲突。 |
| `assisted-matched` | `0.70 <= matchScore < 0.82`，required elements 命中，但需要 LLM / VLM proposal 或额外结构化证据解释。 |
| `needs-review` | `0.55 <= matchScore < 0.70`，或存在 selector / visual / route 冲突。 |
| `not-matched` | `matchScore < 0.55`，或关键 required element 缺失，或目标端出现明确错误页 / 空白页。 |

LLM 介入边界：

- LLM 可以参与解释边界样本，例如 `登录` 与 `Sign in` 是否等价、某个布局变化是否仍是同一业务页面。
- LLM 可以生成 element alias、token normalization、route equivalence proposal。
- LLM 可以解释 matcher 为什么低分，并建议合同更新或 fallback。
- LLM 不能直接覆盖 matcher 分数，不能单独把 `needs-review` 改成 `matched`。
- LLM 的结论必须进入 `fingerprint-match-proposals.jsonl`，由 matcher 或 review gate 再采纳。

因此 fingerprint matching 是“VLM 结构化感知 + deterministic matcher 评分 + LLM 边界解释”的组合，而不是让 LLM 直接判断页面是否相同。

### LLM / VLM 辅助合同编译

录制输出首先是原始流，不应该直接作为最终测试合同。原始流里会包含噪声动作、偶发请求、隐私数据、弱 selector、固定等待、重复截图和平台私有细节。LLM / VLM 可以共同参与“原始流 → 测试合同”的编译阶段。

LLM 参与点：

- 从 actions.jsonl 中识别核心业务步骤，过滤误触、重复 tap、无意义 scroll 和调试动作。
- 把固定 sleep 转成候选 wait condition，例如等待文本出现、route 变化、network idle 或 semantic field ready。
- 从 page snapshots 中提炼页面级断言候选，例如当前 route、关键文案、按钮状态、列表数量、错误提示。
- 从 network capture 中区分核心业务请求、噪声请求、第三方请求和可 passthrough 请求。
- 建议 Network Map：哪些请求应生成 fixture，哪些应 mock，哪些应 block，哪些允许 passthrough。
- 发现弱 selector，并建议更稳定的 selector：test id、accessibility id、semantic field、visible text、within 区域。
- 识别需要变量化的输入，例如账号、手机号、验证码、token、环境域名。
- 生成 human-readable test case summary，方便人或 agent review。

VLM 参与点：

- 从 rendered surface / screenshot 中识别页面类型、关键区域、弹窗、toast、loading、空状态、错误状态和遮挡。
- 为页面级断言生成视觉候选，例如“登录按钮可见”“头像区域出现”“列表不是空态”“错误 toast 出现”。
- 为弱 selector 提供视觉 fallback 候选，例如按钮边界框、表单区域、底部 tab 区域、卡片列表首项。
- 识别录制流中的视觉噪声，例如键盘遮挡、临时 loading、动画过渡帧、系统权限弹窗。
- 辅助判断跨端页面是否等价，例如同一业务页面在 iOS / Android / Harmony 上布局不同但关键区域一致。
- 生成 visual-drift proposal，例如按钮被遮挡、布局断裂、关键文案不可见、目标端出现空白页。

LLM 输出仍必须是结构化 proposal，而不是直接改写合同：

```json
{
  "proposalKind": "contract.compile",
  "modelAssistants": ["llm"],
  "sourceEvents": ["action:12", "page:8", "network:31"],
  "suggestedChange": {
    "type": "replace-sleep-with-wait",
    "waitFor": { "kind": "text-exists", "value": "用户中心" }
  },
  "confidence": 0.86,
  "reason": "登录点击后页面出现稳定业务文案，比固定等待 3s 更可回归",
  "requiresReview": false
}
```

VLM proposal 示例：

```json
{
  "proposalKind": "contract.compile.visual",
  "modelAssistants": ["vlm"],
  "sourceEvents": ["page:14", "screenshot:14"],
  "suggestedChange": {
    "type": "add-visual-assertion-candidate",
    "assertion": {
      "kind": "visual-landmark-visible",
      "label": "登录按钮",
      "region": { "x": 218, "y": 612, "width": 154, "height": 48 }
    }
  },
  "confidence": 0.79,
  "reason": "截图中按钮区域稳定可见，但缺少 accessibility id，需要作为 fallback 候选等待 AX/semantic 证据确认",
  "requiresReview": true
}
```

合同编译规则：

1. deterministic compiler 先做 schema 校验、redaction 标记、事件排序、artifact 链接和基础规则提取。
2. LLM 只在结构化输入上工作，不能读取未授权 secret 明文；VLM 只读取允许进入模型的渲染帧 / 截图；sensitive 字段、隐私截图区域进入模型前必须脱敏、裁剪或摘要化。
3. LLM / VLM 生成的是候选变更，写入 `compile-proposals.jsonl`。
4. 高置信度、低风险 proposal 可自动采纳，但必须保留 before / after diff。
5. 涉及删除步骤、修改断言、生成 fixture、改变 network map 或处理 sensitive 数据的 proposal 默认需要 review。
6. 视觉候选不能单独成为 pass 标准；必须尽量回落到 AX、DOM、semantic field、route、network 或人工确认后的 visual assertion。
7. 最终合同必须通过 `testrec inspect` 和 redaction / schema 校验后才能 replay。
8. 如果 LLM / VLM 不可用，compiler 仍应生成保守合同，只是标记更多 `needs-review`。

因此，LLM / VLM 在编译阶段的角色是“测试合同编辑助手”：LLM 负责从事件和结构化上下文中提炼意图，VLM 负责从渲染界面中提炼视觉状态和 fallback 候选；合同生效必须经过结构化校验、脱敏校验与审计记录。

## 独立路由与命令面

### CLI namespace

新增独立命令命名空间建议为：

```bash
triton testrec start --platform ios --device current --case login --output ./login.tritontestcase --json
triton testrec event --session <id> --kind action --payload-json '<json>' --json
triton testrec stop --session <id> --json
triton testrec inspect ./login.tritontestcase --json
triton testrec compile ./login.tritontestcase --target ios,android,harmony --json
triton testrec match-page ./login.tritontestcase --page login --candidate-json '<json>' --json
triton testrec replay ./login.tritontestcase --platform android --device emulator-a --json
triton testrec matrix ./login.tritontestcase --targets ios:sim-a,android:emu-a,harmony:dev-a --json
```

命名理由：不复用当前顶层 `record/replay`，避免把旧 `.tritonplan` 模板能力和新测试产品能力混在一起。后续如果产品成熟，可以再决定是否把 `triton record` 作为 alias 指向 `testrec start` 的某些场景。

### HTTP route

本地 HTTP 管理 API 使用独立 route，避免和 existing evidence / proxy / webview route 混淆：

```text
POST   /v1/test-recorder/sessions
POST   /v1/test-recorder/sessions/{sessionId}/events
POST   /v1/test-recorder/sessions/{sessionId}/stop
GET    /v1/test-recorder/cases/{caseId}
POST   /v1/test-recorder/cases/{caseId}/compile
POST   /v1/test-recorder/cases/{caseId}/replays
GET    /v1/test-recorder/runs/{runId}
GET    /v1/test-recorder/runs/{runId}/events
~~~

当前 P0 实现先采用本机 path-based HTTP case API，避免提前引入 case registry / run registry：

~~~text
POST   /v1/test-recorder/cases/inspect
POST   /v1/test-recorder/cases/compile
POST   /v1/test-recorder/cases/proposals
POST   /v1/test-recorder/cases/match-page
POST   /v1/test-recorder/cases/replay-dry-run
~~~

这些 route 的 JSON body 使用本机 `.tritontestcase` path，例如 `{"path":"/tmp/login.tritontestcase"}`；`match-page` 额外要求 `page` 与 target-side `candidate` fingerprint；replay dry-run 额外要求 `platform`，可选 `device` 与 `dryRun=true`。后续如果需要 Web run history 或多 run evidence，再单独补 caseId/runId registry，不在 P0 提前做。

如果后续需要 Web mock 展示，也使用独立只读路由 `/test-recorder`，只消费 DTO 和 run report，不作为控制入口。

## Web mock 信息架构

`/test-recorder` 的主体验不是无限画布，也不是单纯时间线；它应该是一个测试计划 workspace，围绕“中间真实渲染界面 + 周边测试证据”组织。

```text
┌──────────────────────────────────────────────────────────────┐
│ Header: case / run / source target / replay matrix / status   │
├────────────────┬──────────────────────────────┬──────────────┤
│ Test Plan       │ Rendered Surface             │ Inspector    │
│ Workspace       │                              │              │
│                │ iOS / Android / Harmony / Web │ Action Map   │
│ - plan tree     │ rendered page or screenshot   │ Page Map     │
│ - scenarios     │ overlays: tap target, node,   │ Network Map  │
│ - fixtures      │ selector, assertion, failure  │ Evidence     │
│ - target matrix │                              │              │
│ - run history   │ source vs replay comparison   │              │
├────────────────┴──────────────────────────────┴──────────────┤
│ Bottom drawer: timeline / network / logs / evidence artifacts │
└──────────────────────────────────────────────────────────────┘
```

### 左侧：测试计划 workspace

左侧承载测试计划，而不是只列步骤：

- Case / suite / scenario tree。
- 当前录制源端与目标端矩阵。
- 测试计划中的 fixtures、network map、page map、变量与 secret-env 引用。
- Run history 与当前 replay run。
- Step list 只是当前 scenario 的局部视图，挂在 workspace 下。

左侧的设计目标是回答：这个测试计划包含什么、要在哪些端回放、用哪些数据和映射规则、当前跑到哪里。

### 中间：渲染界面

中间是主视觉区域，必须优先展示当前端真实界面：

- iOS / Android / Harmony：设备截图、实时 mirror 或 replay step 截图。
- Web / WebView：页面截图、DOM snapshot 对应渲染、或后续可用的只读 preview。
- 覆盖层：当前 action 目标、selector 解析结果、AX / DOM node frame、assertion 命中区域、失败位置。
- 支持 source vs target 对比，同一步下查看源端录制界面与目标端回放界面差异。

时间线和矩阵不抢占中心；它们用于导航和诊断。人先看界面是否正确，再看周边证据解释为什么通过或失败。

### 右侧：Inspector

右侧解释当前选中的界面、步骤或失败：

- Page-level Inspector：按当前页面 / route 聚合展示页面状态、页面断言、页面内 action 列表、页面触发的 network map、跨端页面差异。
- Step-level Inspector：按当前 step 展示动作输入、selector 解析、等待条件、assertion 和执行结果。
- Element-level Inspector：点选中间渲染界面上的 node 后，展示 AX / DOM / semantic field、frame、可操作性、候选消歧与 fallback。
- Network-level Inspector：从页面或 step 进入关联请求，展示 request pattern、fixture、mock / passthrough / block / throttle 命中结果。
- Action Map：源端动作如何映射到目标端动作。
- Page Map：route、URL、AX、DOM、semantic snapshot 如何证明当前页面。
- Network Map：请求命中了 fixture、mock、passthrough、block 还是 throttle。
- Evidence：关联 `.tritonevidence`、截图、sourceCommands、错误 envelope、capability skip 原因。

默认选中页面时，Inspector 进入 page-level；选中某个 step、元素或网络请求时再下钻到对应 level。这样右侧不是“步骤属性面板”，而是当前渲染页面的结构化解释区。

### 底部：事件抽屉

底部是可展开 evidence drawer，包含：

- action timeline。
- network capture / map hit。
- logs。
- page route / snapshot events。
- artifact links。

隐藏底部证据只改变 UI 状态，不停止 capture、不改变 replay、不修改 CLI / HTTP 契约。

## Map 需求吸收

这里的 map 不是地图，而是“把录制到的不稳定外部输入映射成可重复测试输入”。

### Network Map

从 capture 中生成规则：

- `map-local`：把某个请求映射到本地 fixture。
- `map-remote`：把生产 / 灰度 / 测试域名映射到目标环境。
- `mock`：返回固定 response。
- `block`：阻止噪声请求。
- `throttle`：注入稳定延迟或限流响应。
- `passthrough`：明确允许真实网络透传。

规则必须可导入 `device proxy serve --policy-rules`，并进入测试 case manifest。

### Page Map

从源端页面状态提炼跨端识别规则：

- route name / URL pattern。
- visible text / accessibility label / test id。
- WebView URL / DOM selector。
- native semantic field。
- fallback screenshot anchor / OCR text。

Page Map 的目标是让同一条业务断言能在不同端上找到等价页面，而不是要求 UI 层结构完全一致。

### Action Map

从源端动作提炼跨端动作模板：

- `tap`：优先语义 selector，其次可见文本，再其次截图/坐标 fallback。
- `type/paste`：必须记录 secure redaction 与输入目标。
- `swipe/scroll`：记录意图、区域、方向、目标可见条件。
- `wait`：记录等待条件，不记录固定 sleep 作为默认合同。
- `assert`：每个关键步骤至少生成一个业务可见断言。

## BDD 场景

### 场景 1：从 iOS 源端录制登录流程

Given iOS Simulator 中 Debug App 已接入 TritonKit runtime
And `device proxy serve` 可记录目标 App 网络 metadata
When 用户执行 `triton testrec start --platform ios --device current --case login --output ./login.tritontestcase --json`
And 在源端完成打开登录页、输入账号、点击登录、进入首页
And 执行 `triton testrec stop --session <id> --json`
Then 输出目录包含 manifest、actions.jsonl、network capture、page snapshots 和 assertions
And manifest 标记 sourcePlatform 为 `ios`
And 所有 sensitive 字段带 redaction 状态
And 生成的 case 可被 `triton testrec inspect --json` 读取。

### 场景 2：网络录制被编译成可重复 map rules

Given 录制过程中捕获到 `/api/login` 与 `/api/profile`
When 执行 `triton testrec compile ./login.tritontestcase --network-map auto --json`
Then `network/map-rules.json` 包含每个可复现请求的 match 条件、fixture 路径和 passthrough/block 策略
And 编译结果说明哪些请求因 TLS pinning、body 过大、隐私策略或非 HTTP 协议无法稳定 map
And 不允许把未脱敏 body 写入 fixture。

### 场景 3：同一 case 在 Android Emulator 回放

Given `./login.tritontestcase` 已从 iOS 源端生成
And Android target 满足 capabilities 中的 action、page snapshot 和 network policy 要求
When 执行 `triton testrec replay ./login.tritontestcase --platform android --device emulator-a --json`
Then TritonKit 按 Action Map 执行动作
And 按 Network Map 配置可重复网络输入
And 按 Page Map 验证首页 route / text / snapshot
And 输出 Android 端 `.tritonevidence`
And run report 记录每个 step 的 pass/fail、source mapping、fallback 和截图。

### 场景 4：跨端矩阵回放产生统一报告

Given 一个 test case 声明目标矩阵为 iOS、Android、Harmony
When 执行 `triton testrec matrix ./login.tritontestcase --targets ios:sim-a,android:emu-a,harmony:dev-a --json`
Then 每个目标端独立执行、独立产出 evidence
And 总报告按 target 汇总状态
And 任一端失败时返回非零退出码和单个 JSON error envelope
And 报告中必须能定位失败发生在 action、network map、page assertion 还是 target capability。

### 场景 5：页面结构不一致时降级但不伪成功

Given 源端用 WebView DOM selector 找到了按钮
And 目标端只有 native AX tree，没有对应 DOM
When 回放该 action
Then TritonKit 尝试用 Page Map 中的 text / accessibility / semantic fallback
And 如果仍找不到唯一目标，返回 `testrec_action_target_not_found`
And 不使用任意坐标猜测成功。

### 场景 6：只读 Web mock 路由展示 run report

Given 已存在 matrix run report
When 用户打开后续可能实现的 `/test-recorder` Web mock route
Then 页面只读取 case、run、evidence summary DTO
And 不提供开始录制、停止录制、执行回放等业务控制按钮
And 控制动作仍必须通过 CLI / HTTP 管理 API 完成。

## 非目标

1. 不做云端设备农场、远端 agent、多人协作平台或 SaaS Dashboard。
2. 不要求首期支持真机；默认仍是本机 iOS Simulator、Android Emulator、Harmony / DevEco Emulator。
3. 不承诺绕过 TLS pinning、QUIC、自定义 socket、私有加密协议或系统安全策略。
4. 不默认注入业务 App 网络 interceptor；App runtime capture 必须是 Debug-only、显式 opt-in。
5. 不把截图 OCR 作为首选 selector；OCR 只能作为 fallback evidence。
6. 不用 Web/Wails UI 定义业务控制契约。
7. 不把录制生成的步骤视为最终测试；必须经过 compile / inspect / redaction / assertion 校验。

## 数据与安全要求

- 默认所有 network body、header value、cookie、token、输入文本都标记 sensitive。
- fixture 生成必须走 redaction 策略；未脱敏内容不得进入长期 case 包。
- case manifest 记录 TritonKit 版本、schema version、source target、capabilities、redaction status 和 truncation。
- secure input 只保留长度、字段名、变量名或 secret-env 引用。
- cross-end replay 不得把一个端的私有设备标识硬编码为另一个端的执行前提。
- 所有外部进程、proxy、证书、模拟器代理 mutation 必须保留 restore / audit evidence。

## P0 / P1 切片

### P0：离线 case schema 与 inspect

- 新增 `.tritontestcase` 目录 schema。
- 新增 `contract-capabilities.json`，声明当前测试合同可用的 action / page / network 能力，例如 `tap`、`type`、`scroll`、`route`、`ax`、`fingerprint`、`fixture`、`passthrough`。
- `contract-capabilities.json` 不意味着提前实现 Runtime；它只为多端 capability skip、unsupported 不算 pass、以及未来 Runtime Capability Model 预留稳定合同字段。
- 新增 `triton testrec inspect <case> --json`。
- 支持手写最小 actions / assertions / network-map / page-map 文件并被 inspect 校验。
- 测试覆盖 schema 发现、有效 case、缺文件、无效 JSON、capability 解析、unsupported capability、sensitive 默认值。

当前实现状态：

- replay dry-run 与 replay-result 已新增 contractRef：记录 compiled-contract.json 的 path、byteCount、digestAlgorithm 与 deterministic digest；写入 evidence bundle 的 run/replay-result.json 保持同一 contractRef，后续真实 executor 可以用该字段证明 replay result、events 和 contract artifact 对应同一份合同。
- replay evidence events 已同步 contractRef：run/events.jsonl 中 started / page / network / step / finished 每条事件都写入同一 contractRef，真实 executor 后续必须保持事件流与 replay-result 的合同身份一致。
- evidence manifest artifacts 已同步 contractRef metadata：manifest.json 中 replay-result / events / run 三个 artifact 都带同一 contractRef，真实 executor 后续必须保持 manifest、result、events 三方合同身份一致。
- testrec command schema 已补 artifacts：tritontestcase、contract-capabilities、compiled-contract、action-map、page-map、network-map、compile-proposals、evidence-bundle 均可从 schema 发现；start / event / stop / compile / replay 子命令也声明各自会写的主要 artifact，便于 agent 在执行前知道会产生哪些长期证据资产。
- replay dry-run 已补 executorProfiles[]：当前 local-simulated 标记为 available，local-device 标记为 unsupported，并把真实设备 executor 仍缺失的 live-target-device / device-action-execution / evidence-artifact-capture / network-policy-application 作为 requirement 暴露给 agent；focused tests 和真实 CLI smoke 已覆盖该字段，避免 agent 把 dry-run 计划误判成真实设备 replay 能力。
- schema output contract 已固定 executor requirement status taxonomy：satisfied / missing / optional / not-required / simulated / not-present / not-requested。dry-run executorProfiles 与 replay-result execution.executorRequirements 使用同一组状态词，focused tests 会检查字段描述覆盖完整枚举，避免后续真实 executor 引入分叉语义。
- 已实现 P1 源端录制 MVP 的显式事件版：`testrec start` 初始化 `.tritontestcase` 与本机 session，`testrec event` 将显式 JSON object 按 `action`、`network`、`page-route`、`page-fingerprint`、`page-snapshot` 写入对应 JSONL，`testrec stop` 标记 session 停止并输出 artifact presence；当前不做全局输入监听、不连接设备。
- 已实现本机 HTTP 管理 API 的显式事件与 path-based case route：`POST /v1/test-recorder/sessions`、`POST /v1/test-recorder/sessions/{sessionId}/events`、`POST /v1/test-recorder/sessions/{sessionId}/stop`、`POST /v1/test-recorder/cases/inspect`、`POST /v1/test-recorder/cases/compile`、`POST /v1/test-recorder/cases/proposals`、`POST /v1/test-recorder/cases/match-page`、`POST /v1/test-recorder/cases/replay-dry-run`、`POST /v1/test-recorder/cases/replay`；HTTP handler 与 CLI 共用同一 session/case/compile/page-match/replay dry-run / local-simulated replay 逻辑，失败时返回机器可读 validation envelope。
- 已实现 `testrec inspect` 的最小可执行 CLI、JSON 响应、validation error envelope、schema 输出合同和 capabilities matrix 接入。
- 已实现 `testrec compile` 的离线 deterministic compiler：复用 inspect 校验，统计 `actions.jsonl`、`network/capture.ndjson`、`pages/route-events.jsonl`、`pages/fingerprints.jsonl`，输出 `compiled` / `needs-input` / `needs-review` 状态与 warning codes；当输入完整时写入 `compiled-contract.json`，其中包含 semantic actions、network requests、page routes、page fingerprints 和 `llmUsed=false` / `vlmUsed=false` 的 compiler metadata。
- 已实现 deterministic Action Map 产物：compile 在存在 `actions.jsonl` 时写出 `actions/action-map.json`，为每个 source action 生成 semantic target、strategy、review / redaction flags 与 evidence；type action 的输入文本仅进入 evidence，不再覆盖目标 label，避免把“alice”这类输入值误当跨端 selector。
- 已实现 deterministic Page Map 产物：compile 在存在 page route 或 fingerprint 时写出 `pages/page-map.json`，以 route / pageId 合并页面身份，记录 route source、fingerprint source、fingerprint hash 与 evidence 列表；该 artifact 供只读 Inspector / agent / replay plan 消费，不引入 Web 控制面。
- 已实现 page fingerprint match policy 合同字段：compiled contract 中 `pages.matchPolicy` 固定声明 deterministic matcher、`matched=0.82` / `assistedMatched=0.70` / `needsReview=0.55` 阈值、required element gate、冲突策略，以及 `llmDecisionAuthority=false`；该字段定义可审计匹配规则，供 `match-page` 和后续 replay executor 消费。
- 已实现 `testrec match-page --json`：从 `compiled-contract.json` 查找 source page fingerprint，并用 target-side candidate fingerprint 计算确定性分数、decision、component evidence、`llmUsed=false` 与 `llmDecisionAuthority=false`；HTTP route `POST /v1/test-recorder/cases/match-page` 复用同一 runtime。当前 matcher 只产出 page-level evidence，不调用真实 VLM/LLM，不执行设备回放。
- 已实现 deterministic Network Map 产物：compile 在存在 `network/capture.ndjson` 时写出 `network/map-rules.json`，对普通业务请求生成 `mock-candidate` 规则并标记 `redactionRequired=true`，对偶发/analytics 请求生成 `passthrough` 规则并标记 `nonBlocking=true`；当业务请求带 response body 时，会写出 `network/fixtures/<id>.json` 脱敏 fixture，并通过 rule.fixturePath 引用。 `compiled-contract.json` 不编码原始 response body。
- 已实现 compile quality findings：deterministic 检测隐私候选值、偶发/analytics 网络请求、弱 selector、固定等待，并同时写入 compile warnings 与 `compiledContract.qualityFindings[]`。这些 finding 的 `proposalKind` 预留给后续 LLM / VLM 生成候选修复，但模型不直接改变合同、不直接决定 pass / fail。
- 已实现 `compile-proposals.jsonl` 候选层：当 quality findings 非空时，compile 写出 JSONL proposals，`status=proposed`，当前 deterministic 生成 `contract.redaction`、`contract.network`、`contract.selector`、`contract.wait` 四类建议。proposal 只作为审查输入，不自动修改 `compiled-contract.json`。
- 已实现 `testrec proposals --json` 的只读候选检查入口：读取 `compile-proposals.jsonl` 并输出 `proposalCount`、proposal 列表与 inspect 建议命令；空文件或未生成 proposals 时返回空列表，不把候选建议应用回 `compiled-contract.json`。
- 已实现 inspect lifecycle summary：`testrec inspect --json` 根据 `compiled-contract.json` 与 `compile-proposals.jsonl` presence 输出 `lifecycle.stage`（`raw` / `compiled` / `proposed`）和 `lifecycle.health`（`needs-compile` / `ready` / `review-proposals`），为 agent 提供下一步决策事实源。
- 已实现 `testrec replay --dry-run` 的离线 replay plan：要求显式 `--platform` 与 `--dry-run`，从 `compiled-contract.json` 生成 `pageChecks[]` 与 `plannedSteps[]`；`pageChecks[]` 以 `triton testrec match-page <case> --page <page> --candidate-json <target-fingerprint-json> --json` 表达目标端页面指纹证据检查，`plannedSteps[]` 生成 action argv、workflow categories、expected artifacts、stop conditions；缺少 compiled contract 时输出 `missing_compiled_contract`，unsupported capability 或 unsupported action 仍输出 blockers。
- 已实现 `testrec replay --executor local-simulated --target-fingerprints-json <json> --evidence-dir <dir.tritonevidence>` 的离线本机模拟 executor：复用 dry-run plan，输出 `triton.testrec.replay-result`、`execution`、`pageResults[]`、`networkResults[]` 与 `steps[]`；`execution` 固定声明 `mode=offline-simulated`、`requiresDevice=false`、`deviceCommandsExecuted=false`、`llmUsed=false`、`vlmUsed=false`、`networkPolicyMode=simulated-projection` / `not-present`，以及 step status taxonomy：`executed / failed / skipped / blocked / not-run / simulated-passed`，作为后续真实 executor 的 side-effect 边界合同。target-side fingerprints 支持单对象、数组或 `{pages:[...]}`，并复用 deterministic matcher 生成 `matched / assisted-matched / needs-review / not-matched`、`matchScore` 与 evidence；`not-matched` / `needs-review` 会阻断 action steps。Network Map 会被投影为 `simulated-mock-candidate` / `simulated-passthrough` 等网络结果，并在 `run/events.jsonl` 中写入 `testrec.replay.network` 事件；结果保留 strategy、`redactionRequired`、`nonBlocking` 与 source path evidence，保留 fixturePath；但当前不执行 fixture body 或真实 network policy。每个 step result 和 `testrec.replay.step` event 现在都带 `deviceCommandExecuted` / `artifactRefs` / `failure`，local-simulated 固定为 `false` / `[]` / `null`；后续真实 executor 必须用同一字段记录每步实际设备命令是否执行、实际 evidence artifact refs，以及 `failure{code,message,path,artifactRefs,recoveryCommands,retryable}`。传入 `--evidence-dir` 时写出 `manifest.json`、`run/replay-result.json`、`run/events.jsonl` 和 `run/run.json`，先固定 replay result / evidence bundle 合同。该 executor 不连接真实设备、不调用动作命令。
- replay evidence JSONL 已统一基础 event envelope：`testrec.replay.started/page/network/step/finished` 均输出 `schemaVersion`、`event`、`runID`、`timestamp`、`category`、`subjectID`、`status`、`artifactRefs` / `failureCode`（按事件类型可空）与 `evidence`；`category` 当前限定为 `run / page / network / step`。这让后续真实 executor 可以流式写入同一 `run/events.jsonl`，不需要为 page / network / step 另起事件结构。
- local-simulated replay 已将 Network Map 的 fixturePath 透出到 `networkResults[].fixturePath`、`networkResults[].artifactRefs` 和 `testrec.replay.network.artifactRefs`；当前仍只作为证据引用，不执行真实 network policy。
- replay result 已新增 `evidenceSummary`：声明 `expectedEventCount`、page / network / step event count、`blockerCount` 与 `statusConsistent`；写入 evidence bundle 时，`manifest.json.run.eventCount` 与 `run/events.jsonl` 行数必须和 `expectedEventCount` 对齐，避免后续真实 executor 产生 “result passed 但 events / manifest blocked 或缺事件” 的矛盾证据。
- replay result 的 `execution.executorRequirements[]` 已拆出 executor capability requirements：当前 `local-simulated` 明确 `compiled-contract=satisfied`、`live-target-device=not-required`、`device-action-execution=not-required`、`network-policy-application=simulated`、`evidence-artifact-capture=satisfied/not-requested`；请求未实现的 `local-device` executor 会返回 `unsupported_replay_executor`，hint 中保留 `live-target-device`、`device-action-execution`、`evidence-artifact-capture` 和 `network-policy-application`，让 agent 知道真实设备回放还缺哪些能力。
- 已覆盖 start/event/stop 生成可 inspect case、无效 event JSON 不落盘、有效 case、缺 `contract-capabilities.json`、unsupported capability、schema discovery、capability metadata、compile summary、compile action-map / page-map / network-map artifact、compile proposal generation、proposals inspect、page fingerprint match、HTTP match-page、replay dry-run pageChecks、local-simulated replay result、local-simulated replay execution summary / executorRequirements / step status taxonomy、local-simulated replay evidenceSummary、local-simulated replay step `deviceCommandExecuted` / `artifactRefs` / `failure`、local-simulated replay networkResults / `testrec.replay.network` evidence、replay event envelope `timestamp/category/subjectID`、HTTP replay executor validation、缺 raw streams warning、replay dry-run ready plan、replay dry-run blocked plan、非 dry-run 无 executor 拒绝执行的 focused tests。
- 当前只要求 `manifest.json` 与 `contract-capabilities.json` 必须存在；actions / assertions / network / page artifacts 先以 presence report 暴露，compile 阶段在 raw streams 完整时生成 `compiled-contract.json`，replay dry-run 只消费该 compiled contract，不绕过 compiler 直接读取 raw action stream。
- 完整 LLM / VLM proposals、真实 VLM fingerprint 生成与真实设备 `replay` 执行仍是下一步；当前 compile / match-page / replay dry-run / local-simulated replay 不调用模型、不执行设备，Network fixture 只生成脱敏 artifact，不应用到真实网络层。

### 当前停止点

本 space 的产品需求讨论到此冻结。下一步不继续扩需求，不提前抽 Runtime，不推进 Web 主线；直接进入 P0 schema / DTO 设计、`inspect` focused tests 和最小实现验证。

### P1：源端录制 MVP

- 已实现 CLI 显式事件版：`testrec start/event/stop` 可生成 `.tritontestcase`，并可被 `inspect` / `compile` 消费。
- 首期允许 action / network / page event 由 CLI 显式提交，不做全局系统输入监听。
- 从现有 `.tritonplan` / proxy capture / snapshot / evidence 自动组合 case、以及 `.tritonevidence` 链接仍未实现。

### P2：单目标回放

- `testrec replay` 执行 action map、network map 和 page assertions。
- 输出单目标 run report 与 evidence。
- 失败分类稳定：action target、network map、page assertion、capability、runtime unavailable、redaction violation。

### P3：矩阵回放

- `testrec matrix` 支持多端串行或可控并行。
- 每端独立 evidence，汇总 report。
- 支持 per-target capability skip，不把 unsupported 伪装成 pass。

### P4：只读 Web mock

- `/test-recorder` 展示 case、run、step、network map、page snapshots、evidence summary。
- 不提供业务控制按钮。

## 验收标准

1. 有独立 space 和 README，覆盖背景、范围、竞品、map 吸收、BDD、路由、非目标和切片。
2. 首期实现前必须先补 `triton testrec` schema / inspect 的失败测试。
3. 所有 CLI / HTTP 输出必须是机器可读 JSON / JSONL；失败输出为单个 JSON error envelope。
4. 新增 HTTP route 必须用 `httptest` 覆盖 method、path、headers、JSON body 和错误。
5. 新增 replay 行为必须有至少一个单端 focused test 和一个跨端能力 skip test。
6. 文档更新后运行 `docs-linhay/scripts/check-docs.sh`。
7. 若进入实现阶段，再更新 memory，并视复用程度更新项目级 skill；本次仅开 space，不新增 skill。

## 待定问题

1. 产品命名是否固定为 `testrec`，还是使用更面向用户的 `test` / `suite` / `case` namespace。
2. `.tritontestcase` 是否采用目录包，还是复用 `.tritonplan` + `.tritonevidence` 组合。
3. 首期动作录制入口是 CLI event append、runtime ledger ingest，还是 host-side action ledger。
4. Network Map 的 fixture redaction 策略是否复用现有 evidence redact，还是独立规则。
5. Web mock `/test-recorder` 是否需要本期设计稿；若需要，应另在本 space 放单一 HTML 或更新 `Web/` mock。

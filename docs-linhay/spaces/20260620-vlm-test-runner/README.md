# 20260620 VLM Test Runner

## 背景

用户希望 TritonKit 对标 Revyl 的测试能力，并明确本期不做 MCP。Revyl 的强项是 agent-facing CLI schema、技能包、设备状态证据和测试报告；若要进一步接近其视觉测试体验，TritonKit 需要补齐 VLM grounding 能力，让测试步骤可以从“点击坐标 / 精确 accessibility 文案”升级为“点击截图中描述的目标”。

TritonKit 的产品边界仍保持为本机 CLI + 本机模拟器 / 仿真器控制，业务控制事实入口仍是 CLI / HTTP 机器可读契约。VLM 只作为测试 runner 的可插拔感知能力，不成为 Web/Wails 入口，不引入 MCP，不默认启用远端 autonomous loop。

## GitHub 调研结论

### 候选项目

- [OSU-NLP-Group/UGround](https://github.com/OSU-NLP-Group/UGround)：MIT，ICLR 2025 Oral，定位是 Universal GUI Visual Grounding。它的接口最适合作为 TritonKit 第一版：输入截图和目标描述，输出 `(x,y)`，坐标范围 `[0,1000)`，再映射回原图像素坐标。
- [bytedance/UI-TARS](https://github.com/bytedance/UI-TARS)：Apache-2.0，Native GUI agent 方向成熟，提供 mobile / computer use prompt、action parser、OpenAI-compatible / HF TGI 部署参考。它更适合作为第二阶段 action-provider 参考。
- [bytedance/UI-TARS README_coordinates.md](https://github.com/bytedance/UI-TARS/blob/main/README_coordinates.md)：说明 Qwen 2.5 VL 系模型的 absolute coordinate 与 resized image mapping，这是 TritonKit 接入多模型时必须显式记录的坐标归一化事实。
- [OpenBMB/AgentCPM-GUI](https://github.com/OpenBMB/AgentCPM-GUI)：Apache-2.0，Android-focused on-device GUI agent，输出紧凑 JSON action，`POINT` 使用 0-1000 相对坐标，action space 覆盖 click、long press、swipe、press key、type、wait、status。
- [X-PLUG/MobileAgent](https://github.com/X-PLUG/MobileAgent)：MIT，GUI-Owl / Mobile-Agent 系列，覆盖 mobile、desktop、browser automation，能力很全但范围较大，首期不适合直接绑定。
- [njucckevin/SeeClick](https://github.com/njucckevin/SeeClick)：Apache-2.0，ACL 2024 GUI grounding，输出点或 bbox，值为 `[0,1]` 比例坐标。它证明“只做 grounding”本身就是独立有效方向。
- [google-research/android_world](https://github.com/google-research/android_world)：Apache-2.0，Android emulator benchmark，116 个任务、20 个 app、动态参数、durable reward。它不是 VLM 模型，但对 TritonKit 的测试 runner 设计很有参考价值：任务、环境、动作、reward / done 要分层。
- [mobile-dev-inc/Maestro](https://github.com/mobile-dev-inc/Maestro)：Apache-2.0，Painless E2E Automation for Mobile and Web，最新 CLI release 为 `cli-2.6.1`（2026-06-12）。Maestro 的核心价值不是 VLM 模型，而是 YAML Flows、interpreted execution engine、accessibility-tree selectors、smart waiting、Studio 交互式 authoring、Cloud 并行执行和报告体系。

### 对 TritonKit 的判断

第一期不要把模型当“全自动代理”接进来。更稳的路线是把 VLM 放在 grounding 层：

1. TritonKit 负责截图、设备状态、动作执行、证据归档和断言。
2. VLM provider 只回答“这个目标在哪里”或“下一步单个 primitive action 是什么”。
3. test runner 始终保留步骤预算、重试预算、证据、失败分类和人工可复查 overlay。

这可以避免模型幻觉直接扩大成无限操作循环，也更符合 TritonKit 当前 CLI/HTTP 优先的机器可读边界。

### Maestro 对标补充

Maestro 是 Revyl / VLM 调研外的另一个重要参照。它的启发主要在 test runner 产品形态，而不是模型层：

- [How Maestro works](https://docs.maestro.dev/get-started/how-maestro-works.md)：Maestro 是 black-box testing framework，通过 accessibility tree 和 device-level commands 操作 app；这与 TritonKit host-side emulator takeover 方向一致。
- [Commands available](https://docs.maestro.dev/reference/commands-available.md)：Maestro command surface 覆盖 launch、tap、input、assert、scroll、screenshot、recording、permissions、location、orientation、clipboard、AI assertions 等。TritonKit 第一版不需要全量复刻，但应按同样方式把动作、断言、设备状态、视觉检查统一成 Flow step。
- [Core Selectors](https://docs.maestro.dev/reference/selectors/core-selectors.md)：Maestro 支持 text、id、index、point、css，且 text/id regex-based。TritonKit 应优先支持 text/id/point/index，再追加 VLM target。
- [Relational Selectors](https://docs.maestro.dev/reference/selectors/relational-selectors.md)：above、below、leftOf、rightOf、containsChild、childOf、containsDescendants 对复杂列表和卡片很有价值；TritonKit 的 hierarchy DTO 已具备支撑这类 selector 的基础。
- [scrollUntilVisible](https://docs.maestro.dev/reference/commands-available/scrolluntilvisible.md)：它不是普通 scroll，而是循环查找目标、滑动、再查找，直到 timeout；TritonKit 的 `scrollUntil` 应作为 runner primitive，而不是交给用户手写循环。
- [assertScreenshot](https://docs.maestro.dev/reference/commands-available/assertscreenshot.md)：支持基准图、cropOn selector、threshold。TritonKit 后续 visual regression 可以复用 `triton screenshot` + selector crop + image diff，不必依赖 VLM。
- [assertWithAI](https://docs.maestro.dev/reference/commands-available/assertwithai.md)、[assertNoDefectsWithAI](https://docs.maestro.dev/reference/commands-available/assertnodefectswithai.md)、[extractTextWithAI](https://docs.maestro.dev/reference/commands-available/extracttextwithai.md)：Maestro 的 AI 命令默认 `optional: true`，避免不稳定模型直接破坏 CI。TritonKit 可以借鉴该安全默认值，但 evidence 必须更机器可读。
- [Test reports and artifacts](https://docs.maestro.dev/maestro-flows/workspace-management/test-reports-and-artifacts.md)：Maestro 输出 screenshots、videos、commands JSON、AI reports、JUnit、HTML。TritonKit 应把 `.tritonevidence` 作为核心 artifact，再导出 JUnit / HTML / JSON。
- [Workspace configuration](https://docs.maestro.dev/reference/workspace-configuration.md)：flows glob、includeTags、excludeTags、executionOrder、testOutputDir 是测试套件规模化的关键。TritonKit 需要 `.triton/config.yaml` 或 `.triton/test.yaml` 的同类契约。
- [Maestro Studio overview](https://docs.maestro.dev/maestro-studio/maestro-studio-overview.md)：Studio 的价值是连接设备、点选元素、实时插入 YAML、逐步运行和录制回放。TritonKit 当前不恢复正式 Web/Wails 产品面，但 CLI 可以先提供 `triton test create --from-session` 和 `triton hierarchy --json`，为后续 authoring UI 留接口。

因此 TritonKit 的测试能力应分两层推进：

1. Maestro-like deterministic runner：YAML DSL、selectors、smart wait、reports、artifacts、suite config。
2. VLM augmentation：ground target、AI assert、AI extract、defect scan，默认 optional 或明确授权。

### Wise Council 修正

智者反馈要求先回答现有 primitive、evidence/plan schema、assert 数据源、坐标统一、fixture app、持久化和 selector/VLM 边界等硬问题。当前结论是：不能直接进入完整 `triton test run` 或 remote VLM 实现，第一刀必须先做 fact gate 和离线 validate，证明 runner 能作为薄编排层复用现有能力。

详见 `plans/20260620-wise-council-fact-audit-v01.md` 和 `plans/primitive-stability-matrix.md`。当前 primitive fact gate 的总裁决是 `pass-with-gap`：可以进入 validate-only P0B，但不能直接进入完整 runner 执行或 remote VLM。

## 产品范围

### 目标

- 先新增 primitive stability matrix，确认 launch、screenshot、hierarchy、AX、tap、input、assert、evidence、replay 的真实可用边界。
- 新增离线 `triton test validate`，把 Maestro-like YAML 转成 normalized plan，不要求设备、模型或 API key。
- 在 fact gate 通过后新增 `triton vlm` mock contract，提供单次 grounding、响应解析和 overlay 证据输出。
- 在 runner primitives 稳定后，让测试 DSL 能表达 `tap target: "登录按钮"` 并选择 VLM grounding。
- `triton test run` 后置到 primitive/evidence 坐标契约证明之后，再串起截图、provider、动作执行和 evidence。
- 保留 mock provider 和 fixture HTTP server，保证单元测试不依赖真实模型、外网或 API key。
- 后续支持 OpenAI-compatible endpoint，使 UGround、UI-TARS、AgentCPM-GUI、GUI-Owl 等模型可通过 adapter 接入。

### 不在本期范围

- 不做 MCP。
- 不新增 Web/Wails 控制入口。
- 不把 TritonKit 变成远端设备云或多租户 VLM 服务。
- 不默认把用户截图发送到远端模型；远端 provider 必须显式配置与授权。
- 不做无限 autonomous loop；每次 VLM 调用最多产出一个 grounding 或一个 primitive action。
- 不在 P0 绑定某个具体商业模型或下载本地大模型权重。

## CLI / HTTP 契约草案

### 命令

```bash
triton vlm providers --json
triton vlm ground --image screenshot.png --target "Sign In" --provider mock --json
triton vlm ground --image screenshot.png --target "Sign In" --provider openai-compatible --json
triton test validate login.tritontest.yaml --json
triton test run login.tritontest.yaml --target booted --json
triton test report .tritonevidence/login --json
```

### Provider 配置

```json
{
  "provider": "openai-compatible",
  "model": "UGround-V1-7B",
  "baseURL": "http://127.0.0.1:8000/v1",
  "apiKeyEnv": "TRITON_VLM_API_KEY",
  "mode": "point-grounding",
  "coordinateSystem": "normalized_0_1000",
  "temperature": 0
}
```

### Grounding 输出

```json
{
  "ok": true,
  "provider": "openai-compatible",
  "model": "UGround-V1-7B",
  "target": "Sign In",
  "image": {
    "path": "screenshot.png",
    "width": 1179,
    "height": 2556,
    "sha256": "<sha256>"
  },
  "point": {
    "normalized": { "x": 512, "y": 734, "scale": 1000 },
    "absolute": { "x": 604, "y": 1876 }
  },
  "rawResponse": {
    "text": "(512,734)"
  },
  "artifacts": {
    "overlay": "vlm-grounding-overlay.png",
    "request": "vlm-request.redacted.json",
    "response": "vlm-response.json"
  }
}
```

### Test DSL 草案

```yaml
name: login-smoke
target:
  platform: ios
  selector: booted
steps:
  - screenshot:
      name: login-screen
  - tap:
      target: "Sign In"
      grounding: vlm
      provider: openai-compatible
  - assert:
      textExists: "Welcome"
      timeout: 5s
```

### Maestro-like Selector 草案

```yaml
- tap:
    text: "Login"
- tap:
    id: "login_button"
    index: 0
- tap:
    point: "50%, 80%"
- tap:
    text: "Delete"
    childOf:
      id: "cart_row"
- scrollUntilVisible:
    element:
      text: "Checkout"
    direction: down
    timeout: 20s
    visibilityPercentage: 100
```

### AI / VLM Step 草案

```yaml
- assertWithAI:
    assertion: "A two-factor authentication prompt with space for 6 digits is visible."
    optional: true
- assertNoDefectsWithAI:
    optional: true
- extractTextWithAI:
    query: "CAPTCHA value"
    outputVariable: captcha
    optional: false
- tap:
    target: "blue primary submit button"
    grounding: vlm
    provider: openai-compatible
```

## Provider Adapter 设计

### P0：mock-point

用于测试 runner 和证据链开发。输入固定 fixture，输出固定归一化点位，覆盖坐标映射、错误 envelope、overlay 生成、test runner 集成。

### P1：generic-point-openai-compatible

最优先实现。它采用 UGround / SeeClick 风格：

- 输入：base64 screenshot + target text。
- 输出：`(x,y)` 或 JSON point。
- 坐标：统一归一化到 `0..1000`，再映射到原图像素。
- 解析：strict parser，只接受单点或显式 JSON；解析失败返回机器可读错误。

### P2：uitars-action

解析 UI-TARS 风格 `Thought` + `Action: click(start_box='(x,y)')`，只允许白名单 primitive action：click、type、swipe、back、home、wait、status。坐标映射必须记录 resized image metadata。

### P3：agentcpm-json-action

解析 AgentCPM-GUI 风格 JSON action：`POINT`、`TYPE`、`PRESS`、`STATUS`、`duration`。适合 Android-first 任务和中文 App 目标，但仍只执行单步 action。

## BDD 场景

### 场景：P0B 离线解析最小 Flow

- Given 一个 `.tritontest.yaml` 只包含 `launch`、`takeScreenshot`、`tap.point`、`assertVisible.text`
- When 运行 `triton test validate <path> --json`
- Then 输出合法 JSON
- And `ok=true`
- And `normalizedPlan.kind=triton.test.normalized-plan`
- And step id 归一化为 `step-000`、`step-001`
- And `tap.point.coordinateSpace=runtime-point`
- And `assertVisible.selector.source=ax`
- And 不要求设备、simulator、runtime server、模型或 API key

### 场景：P0B 拒绝 runner 执行期步骤

- Given 一个包含 `swipe` 的 `.tritontest.yaml`
- When 运行 `triton test validate <path> --json`
- Then exit code 非 0
- And 输出 `ok=false`
- And `error.type=validation_error`
- And `error.code=unsupported_step`
- And `error.path=$.steps[0].swipe`
- And `error.allowed=["launch","takeScreenshot","tap","assertVisible"]`

### 场景：mock provider 生成可复查 grounding 证据

- Given 一张 fixture screenshot 和 mock provider
- When 运行 `triton vlm ground --image fixture.png --target "Sign In" --provider mock --json`
- Then 输出 normalized point 和 absolute point
- And 生成 overlay artifact
- And overlay 中标出目标点和 target 文案

### 场景：远端 provider 需要显式授权

- Given provider baseURL 指向非 localhost 地址
- When 未设置 `--allow-remote-vlm`
- Then `triton vlm ground` 返回机器可读错误
- And 不发送 screenshot

### 场景：test runner 通过 VLM 点击目标

- Given iOS Simulator 已被 TritonKit target discovery 识别
- And 测试步骤包含 `tap target: "Sign In" grounding: vlm`
- When 运行 `triton test run --json`
- Then runner 先保存 before screenshot
- And 调用 provider 获取点位
- And 通过 Triton host input 执行 tap
- And 保存 after screenshot、vlm request/response、overlay 和 step result

### 场景：VLM 失败时测试报告可诊断

- Given provider 响应无法解析或点位越界
- When `triton test run` 执行到该步骤
- Then 测试失败并停止后续 destructive action
- And report 标记失败类型为 `vlm_parse_failed` 或 `vlm_point_out_of_bounds`
- And evidence 中保留 redacted request、raw response、before screenshot 和错误 envelope

### 场景：AI 断言默认不阻塞 CI

- Given 测试步骤包含 `assertWithAI` 且未显式设置 `optional`
- When VLM provider 返回 false 或不稳定错误
- Then step result 标记为 warning
- And Flow 继续执行
- And evidence 中保留 AI report JSON 与截图 hash

### 场景：视觉回归不依赖 VLM

- Given 测试步骤包含 `assertScreenshot path: login.png thresholdPercentage: 98`
- When 当前截图与基准图相似度低于阈值
- Then Flow 失败
- And evidence 保存 current、baseline、diff 和 threshold
- And 该判断不调用 VLM provider

## 验收门禁

- `swift test --package-path CLI --filter TestValidationTests`
- `swift test --package-path CLI --filter SchemaFactSourceTests`
- `triton test validate <fixture>.tritontest.yaml --json`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`

## 分期计划

### P0A：Fact Gate 与 Fixture 决策

- 输出 primitive stability matrix，覆盖 CLI、HTTP、iOS Simulator、evidence、schema 和测试证据。
- 用 `Examples/TritonKitDemo` 跑最短真实 smoke，保存 status/list/geometry/ax/hierarchy/screenshot/evidence/replay dry-run 样本。
- 决定是否新增 dedicated Login/Home/Settings/Delayed/List/Error/Modal fixture app。
- 定义 screenshot image space 到 tap coordinate space 的 transform contract。

当前状态：`plans/primitive-stability-matrix.md` 已生成，并保存一条真实 simulator pass smoke evidence 与一条 failure smoke evidence。结论为 `pass-with-gap`，后续只能先做 P0B validate-only。

### P0B：测试 DSL 离线 validate

- 新增 `.tritontest.yaml` 最小 schemaVersion 1。
- 新增 `triton test validate <path.tritontest.yaml> --json`，输出 `{ ok, normalizedPlan }`。
- 新增 `triton test validate <path> --emit-normalized-plan --json` 和 `triton test normalize <path> --json`，成功时只输出 normalized plan。
- 首期只支持 `launch`、`takeScreenshot`、`tap.point`、`assertVisible.text`。
- `tap.point.coordinateSpace` 只接受 `runtime-point`。
- `assertVisible` 只接受 exact AX text：`match=exact`、`source=ax`。
- 不连接 server、simulator、模型、App Map、evidence replay 或 API key。
- 明确拒绝 `swipe`、`input`、`tap.text`、`scrollUntilVisible`、`assertNotVisible`、VLM target 和 AI assertion。

当前状态：已实现 validate-only P0B。样本位于 `samples/pass-contract.tritontest.yaml` 与 `samples/invalid-contract-swipe.tritontest.yaml`，合约详见 `plans/p0b-validate-only-contract.md`。该状态只打开 P0C Run Event Writer + Fixture App，不打开 runner execution。

### P0C：Run Event Writer + Dedicated Fixture App

- 新增 `Examples/TritonKitTestFixture`，专门作为测试系统 fixture，而不是继续复用 Demo。
- fixture 覆盖 Login、Home、Settings、Delayed Loading、Dynamic List、Error State、Modal / Alert。
- 每个关键界面提供稳定 visible text 与 `accessibilityIdentifier`，首期 text observation 仍以 AX exact text 为事实源。
- 新增 `.tritonevidence/run/run.json` 与 `.tritonevidence/run/events.jsonl` 契约。
- 事件类型固定为 `run.started`、`step.started`、`command.executed`、`artifact.created`、`assertion.result`、`step.finished`、`run.finished`、`failure.recorded`。
- 新增 pass/failure evidence 样本，分别保存真实 simulator screenshot、AX、hierarchy、manifest、run events。
- `evidence summary` 兼容读取 run 概览，能看到 `eventCount`、`runID`、`verdict`。
- 不实现 `triton test run`、step executor、selector retry、App Map、remote VLM、AI assert、replay evidence 或 HTML report。

当前状态：P0C 已建立可审计执行地基，详见 `plans/p0c-run-event-writer-fixture.md`。该状态只打开 P0D minimal runner execution，不打开完整 runner 或 VLM。

### P0D：Minimal Runner Execution

- 新增 `triton test run <path.tritontest.yaml> --json --evidence-dir <dir>`。
- 执行前复用 P0B validate / normalize；validation failure 仍输出 `validation_error`，不会创建 evidence，也不会触发 primitive executor。
- 执行范围只包含 `launch`、`takeScreenshot`、`tap(point/runtime-point)`、`assertVisible(text/source=ax/match=exact)`。
- `launch` 在 P0D 中只绑定并验证已连接 runtime target 与 `app.bundleId` 对齐，不在 runner 内实现 host-side install / launch / reset。
- 执行过程写入 P0C-compatible `.tritonevidence/run/events.jsonl`，并保存 `run/run.json`、`normalized-plan.json`、`manifest.json`。
- failure run 会保存 `failure.recorded`、失败截图、AX、hierarchy 和 assert-result debug artifact。
- 已用 `TritonKitTestFixture` 跑真实 iOS Simulator pass / failure / unsupported smoke。
- unsupported `swipe` smoke 确认 exit code 为 1、`error.code=unsupported_step`、目标 `.tritonevidence` 目录不存在。
- 不实现 `tap(text)`、`input`、`swipe`、VLM、App Map、replay、screens / transitions、selector healing、HTML / JUnit。

当前状态：P0D minimal runner 已实现，详见 `plans/p0d-minimal-runner-execution.md`。它只允许最小 deterministic flow，不打开完整 runner 或 VLM。

### P0E：Screen Workspace Readiness

- 不扩展 runner step，不做 VLM，不做 App Map，不生成 `screens.json` 或 `transitions.json`。
- 在 P0D runner events 中新增 `observation.captured`。
- `takeScreenshot` 记录 `after` observation。
- `tap(point/runtime-point)` 记录 `before` / `after` observation，并在 after observation 标记可见变化。
- `assertVisible(text/source=ax/match=exact)` 失败时记录 failure observation。
- 每个 observation 引用 screenshot、AX、hierarchy artifacts，并写入 `screenCandidate` fingerprint。
- 新增 `coordinate-contract.json`，固定 `runtime-point` 为 canonical tap space，VLM image space 与 host framebuffer space 明确为 P0E 不支持。
- `evidence summary` 能读回 `run.observationCount`。
- unsupported step 仍停在 P0B `validation_error`，不得创建 evidence 或触发 device operation。

当前状态：P0E 已实现，详见 `plans/p0e-screen-workspace-readiness.md`。它只打开 P1 Screen Workspace Evidence projection，不打开 VLM、App Map、selector healing 或报告生成。

### P1-P2：App Map Test Path Graph

- 读取 `.tritonevidence/run/events.jsonl`。
- 消费 `observation.captured` events，不改 runner execution。
- `triton evidence project-workspace <dir.tritonevidence> --json` 生成 `screens.json` 与 `transitions.json`；`project-screens` 保留为兼容 alias。
- `screens.json` 根据 strict `screenCandidate` fingerprint 分组：`screenshotSha256 + axTextHash + hierarchySha256`。
- `transitions.json` 只从 `tap.before + tap.after + after.changed=true` 的 action step 派生 transition。
- `triton map merge <dir.tritonevidence> --into <dir.tritonmap> --json` 自动补齐 workspace projection，并生成 `.tritonmap/`。
- `.tritonmap/` 包含 `app-map.json`、`screens/`、`transitions/`、`paths/`、`suites/smoke.json`、`runs/`。
- `triton map inspect <dir.tritonmap> --json` 输出 map counts 与 run health。
- `triton map paths <dir.tritonmap> --json` 输出 confirmed replayable paths。
- `triton map export-flow <dir.tritonmap> --path <path-id> --out <file.tritontest.yaml> --json` 导出 P0D-compatible deterministic flow。
- 导出的 fixture flow 已通过 `triton test validate`，包含 `launch`、`takeScreenshot`、`assertVisible("Fixture Login")`、`tap(point/runtime-point)`、`assertVisible("Fixture Home")`。
- failure evidence merge 只生成 failure screen / run health，不生成成功 transition path。
- 不做 VLM、AI assert、selector healing、remote loop、HTML/JUnit、真实 replay execution、cross-version visual merge 或 runner step expansion。

当前状态：P1-P2 App Map Test Path Graph 已实现，裁决为 `pass-with-gap`。产品主链成立，gap 是 exported flow 仍需要真实 re-run gate 补证。

### P2B：Exported Flow Re-run Gate

- 固定链路：`export-flow -> validate -> real triton test run -> new .tritonevidence -> project-workspace -> merge back into same .tritonmap`。
- 同一个 path 重跑 merge 后不得生成 duplicate path。
- map-level health 从 `runs/*.json` 统计，`observedRuns` / `passCount` 应增加。
- path-level health 从 `path.sourceRuns` 统计，成功 re-run 应增加 path `observedRuns` / `passCount`。
- failure evidence merge 后 map `failCount` 应增加，但不污染成功 path health。
- 不新增 runner step，不做 replay execution 新语义；真实执行仍使用 P0D minimal runner。

当前状态：P2B 已实现并完成真实 fixture re-run smoke，详见 `plans/p2b-p3-exported-flow-rerun-and-map-inspection.md`。导出的 flow 已真实执行生成新 evidence，并 merge 回同一个 `.tritonmap`，path 未重复，map/path health 均正确增加。

### P3：App Map Inspect + Path Operations

- 新增 `triton map screens <dir.tritonmap> --json`。
- 新增 `triton map transitions <dir.tritonmap> --json`。
- 新增 `triton map path show <dir.tritonmap> --path <path-id> --json`。
- 新增 `triton map health <dir.tritonmap> --json`。
- 新增 `triton map suite inspect <dir.tritonmap> --suite smoke --json`。
- 这些命令只读 `.tritonmap`，用于回答 screen、transition、path、suite、health 和 coverage gap。
- 不做 UI、VLM、AI、selector healing、HTML/JUnit、跨版本智能 merge 或 autonomous exploration。

当前状态：P3 已实现并通过真实 `.tritonmap` smoke，详见 `plans/p2b-p3-exported-flow-rerun-and-map-inspection.md`。它打开本机 App Map authoring/inspection 工作，不打开 VLM。

### P4：mock VLM contract

- 新增 `triton vlm ground --provider mock`。
- 新增 overlay artifact 生成。
- 覆盖坐标映射、错误 envelope、JSON 输出契约测试。

### P5：OpenAI-compatible point grounding

- 新增 provider 配置读取，支持 env 覆盖。
- 新增 localhost provider 默认允许，remote provider 需要 `--allow-remote-vlm`。
- 支持 UGround / SeeClick 风格 `(x,y)` 输出解析。
- 使用 fixture HTTP server 做 TDD，不在单元测试依赖外部模型。

### P6：Maestro-like runner primitives

- 支持 launch、stop、tap、input、press、swipe、assertVisible、assertNotVisible、takeScreenshot、scrollUntilVisible。
- 第一版 selector 只承诺 text + point；id、index、childOf、containsChild、containsDescendants 后置到 primitive 和 fixture 证据稳定之后。
- 支持 tags、flow glob、testOutputDir、executionOrder。
- 支持 JUnit / JSON report 导出，HTML report 可后置。

### P7：VLM 与 runner 集成

- `triton test run` 串起 screenshot -> VLM -> host input -> assert -> evidence。
- 每个 VLM step 保存 before / after screenshot、request、response、overlay、step result。
- 支持 step budget、retry budget 和失败分类。

### P8：AI assertions / visual checks

- 支持 `assertWithAI`、`assertNoDefectsWithAI`、`extractTextWithAI`。
- AI step 默认 `optional: true`，显式 `optional: false` 才阻塞 Flow。
- 支持 `assertScreenshot` 的 baseline、cropOn、threshold、diff artifact。

### P9：action provider

- 接入 UI-TARS action parser 与 AgentCPM-GUI JSON action parser。
- 只执行单步 primitive action。
- 支持 `status/done`，但不开放无限循环。

### P10：Revyl-like 报告与 session-to-test

- `triton test report` 聚合截图、overlay、失败类型、状态 diff。
- `triton test create --from-session` 从已有 evidence / plan 生成可编辑测试草稿。
- 与 `triton evidence` / `.tritonevidence` 对齐，避免另起报告体系。

## 风险与约束

- 截图可能包含隐私数据，远端 VLM 必须显式授权并在 evidence 中记录 provider、baseURL、image hash 和 redaction 状态。
- 不同模型坐标体系不同：UGround 采用 0-1000，SeeClick 采用 0-1，UI-TARS 可能受 resize 影响；TritonKit 必须在结果中保留 `coordinateSystem` 和 `imageTransform`。
- VLM grounding 不能替代 accessibility / hierarchy：有 AX 文案或稳定 selector 时仍优先走结构化定位；VLM 用于图标、canvas、截图-only 或 AX 不可靠场景。
- P0/P1 不应引入 Python 或模型运行时到 Swift CLI core；本地模型服务可作为外部 endpoint 文档化。

## 当前决策

- 采用 “Maestro-like deterministic runner + VLM provider adapter” 方案。
- 第一刀先做 fact gate 和 YAML validate only；runner 执行、mock VLM、remote VLM 依次后置。
- selector 第一版只承诺 text / point；id / index / relationship selector 必须等 fixture 和 primitive 证据稳定后再进入。
- AI assertion / defect scan / text extraction 默认 optional，除非用户在 Flow 中显式要求阻塞。
- UI-TARS / AgentCPM-GUI 作为 action provider 的后续 adapter，不进入 P0/P1 阻塞面。
- 不做 MCP，不新增 Web 控制面，不改变 TritonKit CLI/HTTP 事实入口。

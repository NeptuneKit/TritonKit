# 20260521 iOS Embedded SDK Expansion Implementation Plan

## 推荐方案

采用“公开 UIKit API + 显式 opt-in provider”的分层方案。

原因：P0 能快速扩大 agent 可观察/可控制范围，并保持 DEBUG-only 和 App 内边界；P2 的网络、日志、业务状态、UserDefaults 等能力通过业务显式注册 provider 才启用，避免 SDK 默认变成高风险采集器。

本计划的实现优先级按 AI 闭环能力排序：先让 AI 通过 CLI 明确发现 SDK 能力，再让 AI 稳定观察 App 内状态，然后提供语义动作，最后补充 evidence、ledger 和 opt-in 业务语义。任何不能提升“观察、解释、执行、验证、复盘”闭环的采集项，都不进入 P0。

## 新计划

新的执行主线是：先定义 AI 通过 CLI 能和 embedded SDK 直接沟通到什么程度，再分阶段提升 AI 的 App 内操控上限。每一阶段都必须产出机器可读 CLI/HTTP 契约、SDK 端能力、测试门禁和可回归证据。

| 阶段 | 目标 | 具体功能 | 技术调研前置 | 验收标准 |
| --- | --- | --- | --- | --- |
| S0 能力边界 | 让 AI 知道当前 SDK 能做什么、不能做什么，以及下一步该调用什么命令 | `runtime manifest`、`capabilities` 增强、`schema` 增强、统一 unsupported reason、embedded/host-side 能力矩阵 | `technical-research-ai-cli-sdk-boundary-v01.md`、`technical-research-runtime-routing-v01.md`、`technical-research-redaction-debug-boundary-v01.md` | `triton runtime manifest --json` 能输出 platform、transport、enabled、capabilities、limits、redaction；`schema/capabilities` 能解释每个命令是否需要 embedded runtime、失败时下一步建议是什么 |
| S1 状态理解 | 让 AI 不靠截图猜测，而是读到 App 内上下文和控件状态 | `state app`、`state scene`、`state route`、`state responder`、`attrs v2` 的 accessibility/responder/control/text/scroll groups | `technical-research-uikit-public-api-v01.md` | AI 能知道当前页面/controller、key window、first responder、输入框状态、segment 当前值、switch/slider/scroll 状态；所有字段有公开 API 来源或明确 unsupported |
| S2 快照聚合 | 让 AI 一次拿到可解释、可验证、可归档的 App 内快照 | `snapshot --include app,scene,route,ax,geometry,screenshot-metadata`、freshness、payload limit、truncation、skipped reason | `technical-research-snapshot-payload-v01.md` | snapshot 能作为一次 agent 决策输入；超限不崩溃，输出 truncation/skipped；secure text 不泄露 |
| S3 语义执行 | 让 AI 用语义命令稳定操作 App，减少坐标依赖 | `focus`、`set-text`、`select-segment`、`set-switch`，随后扩展 `submit`、`set-slider`、`stepper`、`scroll`、`scroll-to-visible`、`wait-idle` | `technical-research-semantic-selector-v01.md`、`technical-research-uikit-actions-v01.md` | 每条命令返回 strategy、targetOID、targetClassName、elapsedMs、redaction；重复候选返回 ambiguity，支持 `--index/--within/--at` 收敛 |
| S4 验证复盘 | 让 AI 能判断操作是否真的完成，并能解释失败链路 | `ledger --limit --jsonl`、evidence/capture 增加 snapshot/state/ledger artifacts、错误 envelope 统一 | `technical-research-runtime-ledger-v01.md` | 一轮失败后，AI 能通过 ledger + evidence 看到 source command、SDK request、动作结果、错误码、耗时和 redaction 状态 |
| S5 真实项目上限验证 | 用真实 App 验证能力是否真的提高 AI 操控上限 | ComplexHarness 扩展、Overloaded 或真实 App smoke、重复文本/表单/列表/导航/弹窗场景 | `technical-research-harness-regression-v01.md` | 可复跑脚本证明 AI 能完成“观察 -> 语义执行 -> wait/assert -> evidence”闭环；失败时能归档证据 |
| S6 Opt-in 业务语义 | 在不破坏默认隐私边界的前提下，让业务 App 主动给 AI 更高层语义 | debug state provider、network breadcrumbs、app logs、UserDefaults allowlist 草案 | `technical-research-opt-in-provider-v01.md` | 不进入 P0 默认采集；只形成独立 API 草案、风险评估和后续 space/切片 |

### 第一轮落地范围

第一轮只做 S0 到 S3 的最小闭环，目标是让 AI 能稳定完成真实表单页操作：

1. `runtime manifest`
2. `capabilities/schema` 增强
3. `state app|scene|route|responder`
4. `attrs --groups accessibility,responder,control,text,scroll`
5. `snapshot --include app,scene,route,ax,geometry`
6. `focus`
7. `set-text`
8. `select-segment`
9. `set-switch`
10. `ledger --limit`

第一轮不做 network breadcrumbs、UserDefaults 读取、app logs、file artifacts、系统弹窗处理、host-side 设备操作，也不恢复 Web/Wails UI。

### 成功判定

第一轮完成时，AI 应该能只通过 CLI 执行以下闭环：

```bash
triton runtime manifest --json
triton snapshot --include app,scene,route,ax,geometry --json
triton focus "用户名" --json
triton set-text "用户名" "alice" --json
triton set-text "密码" "$PASSWORD" --secure --json
triton select-segment "协议" "HTTP" --json
triton set-switch "记住我" on --json
triton wait --text "登录成功" --timeout 15 --json
triton assert text-exists "登录成功" --json
triton ledger --limit 50 --jsonl
triton capture --case ai-cli-embedded-form-flow --output /tmp/ai-cli-embedded-form-flow.tritonevidence --json
```

如果失败，AI 必须能从 `snapshot`、`assert`、`ledger` 和 evidence manifest 中判断失败发生在观察、选择器解析、SDK 执行、业务异步状态，还是 embedded runtime 边界之外。

## 备选方案

### 方案 A：只扩展公开 API 采集与语义命令

- 工作量：中。
- 风险：低。
- 复用：现有 `ax/hierarchy/attrs/input/find/wait/assert/evidence`。
- 缺点：无法解决网络、登录态、feature flag 等业务语义问题。

### 方案 B：公开 API + opt-in provider

- 工作量：中高。
- 风险：中。
- 复用：P0 复用现有 runtime，P2 provider 只新增只读注册点和 DTO。
- 优点：既能推进通用能力，又给真实项目留出业务语义扩展口。
- 建议采用。

### 方案 C：默认自动 hook 网络、日志和存储

- 工作量：高。
- 风险：高。
- 复用：少。
- 不建议：容易破坏业务 App 行为，也难以保证 Release/隐私边界。

## 攻击面检查

1. 依赖失败：如果 App 未接入 provider，P0 仍能通过 UIKit 公开 API 工作；provider 缺失只在 capability 中显示 unsupported。
2. 规模放大：复杂页面树可能超过 payload budget；snapshot 必须支持 include、limits、truncation 和 skipped reason。
3. 回滚成本：每个能力独立挂到 manifest/capabilities，错误实现可以按 capability 关闭，不影响基础 `ax/hierarchy/input`。
4. 前提坍塌：如果真实项目大量 SwiftUI 私有树无法解释，P0 仍保留 route/controller/AX 线索，业务语义转向 opt-in provider。

## 技术调研执行表

所有实现项必须先完成对应调研。调研产物优先放在本 space 根目录，文件名使用 `technical-research-<topic>-v01.md`；结论稳定后再同步到 `docs-linhay/dev/ai-cli-readable-control.md` 或 README。

| 序号 | 阶段 | 调研主题 | 关键问题 | 调研产物 | 通过条件 | 后续实现切片 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | R0 | AI-facing CLI/SDK 能力边界 | AI 通过 CLI 直连 embedded SDK 时，哪些能力属于观察、解释、执行、验证、复盘？哪些必须交给 host-side adapter？ | `technical-research-ai-cli-sdk-boundary-v01.md` | 产出能力矩阵、unsupported reason、CLI/schema/capabilities 暴露规则；确认目标是提升 AI 操控闭环而非泛采集 | manifest、capabilities、schema 调整 |
| 2 | R0 | 现有 runtime/request/CLI 链路盘点 | 当前 `TKMessage`、HTTP `/request`、CLI schema、evidence 如何扩展最少？哪些命令已有可复用 parser？ | `technical-research-runtime-routing-v01.md` | 列出需新增的 request type、DTO、CLI command、测试文件；确认不破坏现有 `ax/hierarchy/input` | manifest、state、snapshot、ledger 契约测试 |
| 3 | R0 | iOS 公开 API 可采集边界 | App、scene、window、route、first responder、control attrs 分别能用哪些公开 API？哪些 SwiftUI 内容不能承诺？ | `technical-research-uikit-public-api-v01.md` | 每个字段都有公开 API 来源或明确 unsupported reason；不使用私有 API | App/scene/route/responder/control attrs P0 |
| 4 | R0 | 隐私与 DEBUG-only 边界 | secure text、UserDefaults、network、logs、clipboard、file artifacts 如何脱敏或禁止默认采集？Release no-op 如何验证？ | `technical-research-redaction-debug-boundary-v01.md` | 给出字段级 redaction 策略、P2 opt-in provider 边界、Release disabled 测试点 | manifest redaction、snapshot redaction、provider 后续设计 |
| 5 | R1 | Snapshot payload 与 freshness | 一次性 snapshot 是否会过大？如何 include、limit、truncate、记录 freshness/skipped？ | `technical-research-snapshot-payload-v01.md` | 给出 payload budget、默认 include、截断 shape、evidence artifact 映射 | `triton snapshot`、capture/evidence snapshot artifact |
| 6 | R1 | 语义 selector 与歧义处理 | `focus/set-text/select-segment/set-switch/scroll-to-visible` 如何复用现有 `find`？重复文本如何返回 ambiguity？ | `technical-research-semantic-selector-v01.md` | 每个命令定义 selector 解析顺序、`--index/--within/--at` 行为、失败 envelope | focus、set-text、select-segment、set-switch |
| 7 | R1 | UIKit 控件语义动作 | UITextField submit、UISegmentedControl、UISwitch、UISlider、UIStepper、UIScrollView 哪些动作可确定触发？哪些只能 unsupported？ | `technical-research-uikit-actions-v01.md` | 每个控件给出 action 实现方式、事件派发方式、验证 harness 信号 | submit、set-slider、stepper、scroll、wait-idle |
| 8 | R1 | Runtime ledger 设计 | ledger 存什么、不存什么？如何避免泄露 secure input？如何限制内存与输出量？ | `technical-research-runtime-ledger-v01.md` | 定义 ring buffer size、JSONL shape、redaction、source command、elapsedMs | `triton ledger --limit`、evidence ledger artifact |
| 9 | R2 | Harness 与真实项目回归 | ComplexHarness 需要补哪些控件和页面？Overloaded 或真实 App smoke 如何验证最小闭环？ | `technical-research-harness-regression-v01.md` | 给出新增 harness 场景、脚本命令、截图/证据归档方式 | `verify-complex-harness.sh` 扩展、真实项目 smoke |
| 10 | R2 | Opt-in provider API | 业务 debug state、network breadcrumbs、logs、UserDefaults allowlist 应如何注册、命名、脱敏和禁用？ | `technical-research-opt-in-provider-v01.md` | 只产出 API 草案和风险评估，不进入 P0 实现；确认默认不采集 | P2 provider 单独 space 或后续切片 |

### 调研门禁

1. 每个 R0/R1 调研文件必须包含：背景、现有代码入口、可用公开 API、不可做清单、推荐 DTO/命令 shape、测试建议、风险。
2. 调研结论必须能映射到 BDD 场景；不能只列 API 名称。
3. 未完成 R0 调研前，不新增生产代码；最多新增失败测试草案。
4. R1 调研完成后才能实现对应语义命令；避免先写命令再补解释。
5. R2 调研不阻塞 P0，但如果 R2 发现 P0 契约会妨碍真实项目回归，需要回头调整 DTO/schema。

## 实施步骤

1. 契约红灯：在 `TritonKitShared` 新增 iOS runtime manifest、snapshot、state、attrs v2、ledger、semantic action DTO 的 Swift Testing 测试，先确认失败。
2. CLI schema 红灯：为 `runtime manifest`、`snapshot`、`state`、`ledger` 和语义命令补 schema 测试，先确认命令未暴露。
3. Runtime P0 采集：实现 manifest、app/scene/route/responder/control attrs、ledger ring buffer。
4. Snapshot 聚合：组合现有 hierarchy、ax、geometry、screenshot metadata 和新增 state，加入 payload limits、freshness、redaction。
5. 语义动作：在底层 input 之上实现 focus/setText/submit/selectSegment/setSwitch/setSlider/stepper/scroll/scrollToVisible/waitIdle，并统一返回 strategy、target、elapsedMs。
6. Evidence 集成：capture/evidence 增加 snapshot/state/ledger artifact，unsupported 或超限进入 manifest.skipped。
7. Harness 验收：扩展 ComplexHarness，加入导航/表单/列表/弹窗/重复文本场景，更新可复跑脚本。
8. 文档同步：更新 README、`docs-linhay/dev/ai-cli-readable-control.md`、public skills 与 memory。

## 最小验收切片

第一期不要一次性实现全部命令。建议先完成：

1. `runtime manifest`：让 AI 知道 embedded SDK 当前能做什么、不能做什么。
2. `capabilities/schema` 增强：让 AI 不需要读文档也能规划命令。
3. `state app|scene|route|responder`：让 AI 理解当前 App 内上下文。
4. `attrs --groups accessibility,responder,control,text,scroll`：让 AI 解释控件状态和失败原因。
5. `snapshot --include app,scene,route,ax,geometry`：让 AI 一次拿到可验证状态。
6. `focus`
7. `set-text`
8. `select-segment`
9. `set-switch`
10. `ledger --limit`：让 AI 复盘最近一次失败链路。

这组能力能显著改善 agent 在真实表单页中的“看、解释、填、验证、复盘”闭环，同时不触碰高风险 P2。

## 验证命令

文档规划阶段：

```bash
docs-linhay/scripts/check-docs.sh
```

实现阶段本地门禁：

```bash
swift test
docs-linhay/scripts/verify-complex-harness.sh
docs-linhay/scripts/verify.sh --local
```

若只实现 shared DTO 或 CLI schema，至少运行：

```bash
swift test --filter TritonKitSharedTests
```

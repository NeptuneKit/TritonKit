# Wise Council Fact Audit V01

## 背景

本计划承接 Revyl、Maestro 和 GUI VLM 调研。用户希望 TritonKit 也能实现惊艳的测试能力，并明确本期不做 MCP；产品边界仍是本机 CLI + 本机模拟器/仿真器，业务控制事实入口优先 CLI/HTTP 机器可读契约。

已有初稿倾向是 "Maestro-like deterministic runner + VLM provider adapter"。智者反馈没有直接批准开做，而是要求先回答 20 个会决定落地是否发散的事实问题，尤其是 existing primitives、evidence/plan schema、assert 数据源、坐标统一、fixture app、存储、selector 边界、VLM 代码与 App Map path 确认机制。

## 裁决

当前不能直接进入完整 `triton test run` / `triton vlm ground` 实现。第一刀必须改成事实门禁：

1. 证明 test runner 能作为薄编排层复用现有 launch/screenshot/hierarchy/tap/input/assert/evidence/replay primitives。
2. 明确 `.tritonevidence` 继续是 immutable evidence bundle，runner 只扩展 run event / step artifact，不另起报告体系。
3. `.tritonmap/` 作为新 App Map 文件目录 JSON 设计，不塞进 evidence manifest；map 节点只引用 evidence run/artifact。
4. VLM 首期只保留 provider contract 和 mock，不接 remote，不进 CI strict，不替代 AX/hierarchy selector。

如果第 1 点被事实证伪，runner 就不能开工；必须先补 primitive 稳定性，否则会长成第二套 runtime。

事实门禁已落到 `plans/primitive-stability-matrix.md`。当前总裁决是 `pass-with-gap`：现有 primitive 足以支撑 P0B validate-only，但不允许直接开完整 runner 执行、remote VLM、App Map 或 selector healing。

## Repo Fact Audit

| 智者问题 | 当前事实 | 决策影响 |
| --- | --- | --- |
| launch / screenshot / hierarchy / tap primitive 是否存在 | CLI 顶层已有 `app`、`hierarchy`、`ax`、`screenshot`、`tap`、`input`、`assert`、`evidence`、`record`、`replay` 等命令。HTTP server 已有 `/status`、`/targets`、`/hierarchy/latest`、`/accessibility`、`/geometry`、`/screenshot`、`/request`、`/input`。 | primitive 面够做薄 runner，但还需要真实 simulator smoke 证明稳定性。 |
| evidence schema | `TKEvidenceManifest` 当前 `formatVersion=1`，包含 `artifacts[]`、`skipped[]`、`target`、`cli.schemaVersion`、可选 `run`。capture 会写 `manifest.json`、`hierarchy.json`、`ax.json`、`geometry.json`、`screenshot.png`、`screenshot.json` 等。 | 不新建 TritonTest evidence schema；优先扩展 run event / artifact kind。 |
| plan / replay schema | `.tritonplan` 当前 `schemaVersion=1`，action 覆盖 `tap/paste/type/clear/wait/screenshot/evidence` 和 proxy dry-run lifecycle。真实 replay 首个失败停止，dry-run 不连 runtime。 | replay 第一阶段定义为 normalized-plan rerun；map path replay 后置。 |
| `assertVisible(text)` 数据源 | `triton assert` 请求 runtime `accessibility`，`TKUIAssertEvaluate` 从 AX nodes 的 visible text 做精确匹配，不使用 OCR。 | 第一版 `assertVisible(text)` 绑定 AX source；OCR/VLM assert 后置且 optional。 |
| selector 来源 | `find/tap` 的 query 解析优先 AX label/identifier/title，再 hierarchy text，再 AX value；当前是 exact match，不是 regex。host Android/Harmony text tap 走 host layout/text dump。 | 第一版 selector 收紧到 text + point；id/index/relationship/regex 都后置或作为显式 P2。 |
| 坐标统一 | runtime tap 是 window points；evidence screenshot metadata 有 width/height/scale；host Android/Harmony tap 是 host absolute coordinates；host simulator screenshot 还有 raw framebuffer orientation note。 | VLM grounding 不能直接把 image pixel 当 tap point；必须先定义 image coordinate -> tap coordinate transform artifact。 |
| fixture app | `Examples/TritonKitDemo` 是 runtime/webview/native-controls harness，包含 segmented、slider、stepper、switch、text field、scroll items，但不是 Login/Home/Settings/Delayed/Error/Modal 测试 fixture。 | P0 必须先决定是否新增 dedicated fixture；否则 runner/screen graph/replay 缺稳定地基。 |
| VLM 代码 | 当前源码和测试里没有 `triton vlm`、VLM provider、AI assert、grounding 实现；只有本 space 的调研文档。 | VLM 首期只能从 contract/mock 开始；不要假设已有 OpenAI-compatible client。 |
| `.tritonevidence` / `.tritonmap` 存储 | `.tritonevidence` 已有目录包和 `run/events.jsonl` / `run/meta.json` 模型与测试；未发现 `.tritonmap` 代码或文档实现。workspace defaults 已有 `.triton/host-defaults.json`。 | App Map 建议新建 `.tritonmap/` 文件目录 JSON，并绑定 bundleId/appVersion/build/gitSha。 |
| HTTP 是否同步做 | 现有 HTTP 覆盖 runtime primitive，但没有 `/test` 或 `/vlm`。项目规则也要求 CLI/HTTP 是事实入口，Web/Wails 不先行。 | P0/P1 CLI first；HTTP 只在 core 稳定后薄封装。 |
| CI strict / assistive | 现有 runner 不存在；Maestro AI 命令默认 optional 的经验可借鉴。 | CI 默认 deterministic/strict；VLM/assistive/healing 必须显式开启。 |
| 并发与 run 目录 | evidence run writer 已支持 `run/events.jsonl` append-only 和 run metadata；未看到 test run 并发策略。 | 第一版每次 run 独立 evidence dir；同一 output dir 禁止并发写。 |

## 修正后的第一刀

### P0A：Fact Gate 与 Fixture 决策

目标不是写 VLM，而是把智者的 8 个硬问题变成可执行门禁。

- 新增 primitive stability matrix 文档：列出 launch/screenshot/hierarchy/ax/tap/input/assert/evidence/replay 在 iOS Simulator、Android、Harmony 的 CLI/HTTP/evidence 支持状态。
- 用现有 `Examples/TritonKitDemo` 跑一条最短 iOS simulator smoke，保存 `status/list/geometry/ax/hierarchy/screenshot/evidence/replay dry-run` 的真实 JSON 样本。
- 判断是否新增 dedicated `Examples/TritonKitTestFixture`。若要做 screen graph / path replay，必须新增；若本期只做 validator，可推迟。
- 定义 coordinate transform contract：`imageSpace`、`tapSpace`、`scale`、`orientation`、`sourceArtifact`、`transformApplied`。

### P0B：Test Validate Only

只做离线 `triton test validate`，不执行设备动作。

- `.tritontest.yaml` schemaVersion 1。
- 支持 `launchApp`、`tap.text`、`tap.point`、`inputText`、`assertVisible`、`takeScreenshot` 的 normalized form。
- 输出 `normalizedPlan` 和 `requiredCapabilities`，直接引用现有 command schema / capability taxonomy。
- 不接 VLM provider，不写 App Map。

### P0C：Evidence Run Projection

在现有 `.tritonevidence/run/` 语义内扩展测试事件，不新建证据格式。

- 每个 test run 写独立 `<run-id>.tritonevidence/`。
- `run/events.jsonl` 记录 `run_started`、`step_started`、`tool_call`、`tool_result`、`step_completed`、`run_completed`。
- 失败时必须保存 screenshot/hierarchy/ax 或明确 skipped reason。
- summary/report 先从 `.tritonevidence` projection 生成，JUnit/HTML 后置。

## 仍需继续问智者/开发者的问题

1. 是否接受把原 README 中的 P0 改成 P0A/P0B/P0C，先不开 remote VLM？
2. 是否接受 dedicated fixture app 是测试系统地基，而不是附属优化？
3. 坐标 contract 以 runtime window points 为 canonical，还是以 screenshot image pixels 为 canonical 再转换？
4. `.tritonmap/` 是否绑定 bundleId 下累积，并按 appVersion/build/gitSha 过滤 health/report？
5. App Map path 是否坚持 candidate -> user confirmed -> suite，禁止 AI 自动 confirmed？
6. `triton test run` 是否第一版只消费 normalized plan，不消费 `.tritonmap` path？
7. 是否把 CI default 设为 strict，并默认禁用 VLM/assistive/healing？

## 验收标准

- `triton schema --command tap --json`、`triton schema --command screenshot --json`、`triton schema --command evidence --json`、`triton schema --command replay --json` 能证明 runner 依赖的 primitive contract 已暴露。
- iOS simulator smoke 真实产出 `.tritonevidence`，其中含 `manifest.json`、`hierarchy.json`、`ax.json`、`geometry.json`、`screenshot.png`、`screenshot.json`。
- `.tritontest.yaml` 离线 validate 不需要 server、simulator、模型或 API key。
- validate 输出稳定 JSON，失败时使用 `{ ok:false, error:{ code, message, hint, nextAction? } }` 风格。
- 未引入 MCP、Web/Wails 控制入口、remote VLM 默认发送截图或 autonomous loop。

## 下一步执行建议

先不要开大实现。下一步只做两个动作：

1. 进入 P0B：实现离线 `triton test validate` 的 schemaVersion 1 和 normalized plan 输出。
2. 同步补 dedicated fixture app 方案，否则完整 runner、screen graph 和 path replay 都会缺稳定地基。

完整 runner implementation 仍需等待 selector、coordinate、fixture 和 run-event evidence 缺口收敛。

# Autonomous Evolution Roadmap v01

## 规划原则

1. 先收敛，再扩张：优先让已开始的 Xcode / simulator / evidence 能力闭环。
2. 先契约，再体验：CLI / HTTP / schema / artifact 稳定后，才考虑人类展示面。
3. 先真实回归，再低频能力：优先服务 agent 在真实项目里的发现、构建、运行、操作、断言和报告。
4. 先小测试，再大门禁：每个切片先跑聚焦测试，阶段完成后跑 `docs-linhay/scripts/verify.sh --local`。
5. 先本机，再外部：不默认进入真机、云设备、远端 agent 或 release 发布。

## 阶段 0：接管当前 WIP

目标：把当前 Xcode workflow takeover WIP 收敛到可提交、可验证、可恢复的状态。

验收：

- `git status --short --branch` 中 Xcode WIP 的文件边界清晰。
- `triton schema --command xcode --json` 与 `triton schema --command xcresult --json` 可发现新增命令。
- Xcode / xcresult 相关模型测试和 CLI 测试通过。
- 文档更新到 `docs-linhay/spaces/20260520-xcode-workflow-takeover/` 和 `docs-linhay/dev/ai-cli-readable-control.md`。

首选测试：

```bash
swift test --filter TKXcodeWorkflowModelsTests
swift test --package-path CLI --scratch-path .build/cli-tests --filter SimulatorAdvancedControlsTests
docs-linhay/scripts/verify.sh --local
```

暂停条件：

- 发现未提交 WIP 与当前任务无关且无法判断归属。
- 需要真实 Xcode 项目或私有工程才能验证关键路径。

## 阶段 1：Xcode workflow 最小可信闭环

目标：让未知 iOS / macOS repo 的 agent 入口稳定为 `discover -> use -> build/test/run -> xcresult -> evidence`。

切片：

1. `xcode discover/use/status/settings` 的 schema 和错误码补齐。
2. `xcode build/test/run --jsonl` 的 progress envelope 固化。
3. `xcresult summary/failures` 的失败摘要和错误码稳定。
4. build/test/run artifacts 进入 `.tritonevidence` manifest。
5. README / public skill 同步 agent 推荐命令。

验收：

- JSON / JSONL 输出包含 `schemaVersion`、`ok`、`command`、`artifacts`、`error.code`。
- 长任务 stdout / stderr 只进入 artifact，CLI summary 只保留摘要。
- `xcode run` 不宣称业务 ready，只返回 build/install/launch 与 runtime binding 结果。

## 阶段 2：真实项目回归闭环

目标：让外部 agent 面对一个接入 TritonKit 的 App，可以完成最小 smoke 并给出可提交 issue 的证据。

切片：

1. `.tritonplan replay` dry-run / real-run 失败定位增强。
2. `capture/evidence --include host,xcode,runtime` manifest 统一。
3. `assert text-exists/text-not-exists` 与 `find/tap/type/press` 的证据字段统一。
4. issue report template 脱敏、命令、版本、错误码和 artifact 摘要标准化。
5. `tritonkit-real-project-regression` skill 更新为默认路径。

验收：

- 每个 smoke 产物可离线读取，不依赖数据库或 GUI。
- 失败报告能回答：目标、环境、命令、观察、动作、结果、失败点、证据路径。
- 公开 issue 内容默认脱敏。

## 阶段 3：UX run evidence

目标：把 Harness 参考中的 run artifact 吃进 TritonKit，但不内置 LLM agent。

切片：

1. 在 `.tritonevidence/run/` 下定义 `events.jsonl` 与 `meta.json`。
2. 首期 row kinds：`run_started`、`step_started`、`tool_call`、`tool_result`、`friction`、`step_completed`、`run_completed`。
3. 固化 friction taxonomy：`dead_end`、`ambiguous_label`、`unresponsive`、`confusing_copy`、`unexpected_state`、`auth_required`、`agent_blocked`。
4. parser 容忍最后一行截断，旧 schema 永久可读。
5. 主 evidence screenshot 保持 clean，overlay 只能作为独立 debug artifact。

验收：

- 外部 agent 可以把 observation / intent / tool result 写入 run log。
- `.tritonplan replay` 即使没有 persona reasoning，也能产出结构化 step log。
- 密码、token、credential value 不进入 prompt、plan、JSONL、截图描述或日志。

## 阶段 4：三端 host adapter 加固

目标：把 iOS Simulator、Android Emulator、HarmonyOS / DevEco Emulator 的 host-side control-plane 统一到可审计 adapter 结构。

切片：

1. Apple simulator advanced controls 完成非破坏性路径：status bar、privacy、location、UI appearance、pasteboard、push、video、bounded logs。
2. Android Emulator target discovery / screenshot / input / logs 的最低契约设计。
3. Harmony HDC / DevEco target discovery / layout / screenshot / logs 的契约稳定。
4. destructive action policy 统一：dry-run、risk level、confirmation required。
5. platform adapter 输出统一 evidence envelope。

验收：

- 每个平台的 `list/status/screenshot/logs` 可机器读取。
- 操作命令返回 source command、risk level、artifact path 和 error code。
- 默认不执行 destructive action。

## 阶段 5：分发、技能包与外部采用

目标：让外部使用者稳定拿到 CLI、public skills 和接入文档。

切片：

1. Release asset 契约持续校验：arm64 / x86_64 CLI、checksum manifest、public skills tarball。
2. Homebrew formula 验证与文档保持同步。
3. public skills 版本 stamp 与 README 入口保持一致。
4. SwiftPM / CocoaPods Debug-only 接入口径继续保持测试。
5. 建立 `triton preflight` 候选 space，验证外部采用前置检查。

验收：

- 未授权不发布 tag / release / tap。
- 本地 release/homebrew 契约检查可复现。
- public skills 与 README 不互相矛盾。

## 阶段 6：可选人类展示面

目标：只有当 CLI / evidence 已稳定且确有人类审阅痛点时，才重新评估 Web / Wails UI。

前置条件：

- 新建独立 space，重新定义 BDD、技术栈和验收方式。
- UI 只读消费 DTO，不承载 create/update/delete/execute/approve/deny。
- 不把 GUI run history 作为证据事实源。

## 自动巡航任务选择算法

每轮按以下顺序选择任务：

1. 是否有未完成 WIP 会阻塞主线验证：优先收敛。
2. 是否有失败测试或 schema 破口：优先修复。
3. 是否有文档 / skill / README 与代码契约不一致：优先同步。
4. 是否能新增一个小而完整的 CLI / evidence 能力：按阶段路线图推进。
5. 是否只剩高风险动作：暂停并记录。

每个任务开始前写清：

- BDD 场景。
- 失败测试或现有测试缺口。
- 涉及文件边界。
- 验证命令。
- 停止条件。

## 第一轮建议队列

1. 收敛当前 Xcode / xcresult WIP，跑聚焦 Swift tests。
2. 补 `triton xcresult` / `coverage` / `xcode` schema 文档与 public skill 口径。
3. 设计 `.tritonevidence/run/events.jsonl` 的最小模型测试，不实现内置 agent。
4. 将 `capture/evidence` manifest 与 Xcode artifacts 串起来。
5. 继续 simulator advanced controls 的非破坏性命令验收。

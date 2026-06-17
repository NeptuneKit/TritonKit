# 20260527 Long-term Cruise Plan v01

## 总路线

本期长期巡航采用两段式推进：

1. 先稳定现有命令契约和代码结构，完成当前 WIP 收口、命令面基线冻结、schema 补齐、错误 envelope 统一和 Host 命令拆分。
2. 再直接进入 agent-facing CLI 信息架构重排，不维护 legacy / compatibility 层；任何破坏性命令调整都同步更新 CLI schema、README、public skills、dev 文档和测试。

## 方案 C 定义

方案 C 不是“多加几个命令”，而是把 `triton` CLI 改造成 agent 可自发现、可规划、可执行、可诊断的控制界面。

本期将 `triton` 定义为给 AI agent 使用的机器可读操作系统接口。agent 不应依赖旧记忆猜命令，而应通过随包 skills、`triton schema`、`triton capabilities`、`triton doctor` 和 `triton plan` 获取当前契约与下一步动作。

### 核心问题

方案 C 必须回答以下问题：

1. agent 如何知道当前能做什么？
2. agent 如何选择正确目标？
3. agent 如何知道下一步命令？
4. agent 如何判断失败原因和恢复动作？
5. agent 如何把一次回归流程变成可复跑 evidence / plan？

### 五层信息架构

1. `triton schema`：命令事实源
   - 输出所有命令、参数、默认值、输出模型、错误码、下一步建议、是否破坏性、是否需要 server、是否需要 target。
2. `triton capabilities`：能力事实源
   - 回答当前环境能做什么：有没有 server、runtime、iOS simulator、Harmony target、Xcode project、WebView bridge、evidence / replay 能力。
3. `triton target` / `triton project` / `triton xcode` / `triton app` / `triton runtime`：领域入口
   - 按 agent 的任务语义整理领域边界，避免 agent 在 `sim`、`device`、`app` 之间猜测职责。
4. `triton plan`：任务规划入口
   - 输入目标，例如 iOS smoke、打开 URL 并验证文本、构建并启动 app，输出推荐命令序列，而不是只给静态说明。
5. `triton evidence` / `triton replay` / `triton assert`：验收与复跑入口
   - 把 agent 执行痕迹、截图、日志、断言、失败原因统一沉淀成可审计产物。

### 目标心智模型

长期目标命令分层如下。实际落地时允许破坏性重命名、迁移或删除旧入口，只要同轮同步 schema、skills、README、dev 文档和测试。

```text
triton
├── doctor / status / version / schema / capabilities
├── target
│   ├── list / use / current / resolve / alias / wait-ready
├── project
│   ├── discover / use / status
├── xcode
│   ├── schemes / settings / build / test / run
├── app
│   ├── install / launch / terminate / open-url / info / prefs
├── runtime
│   ├── manifest / state / snapshot / ledger
├── observe
│   ├── current / tree / webview
├── action
│   ├── find / tap / type / paste / clear / swipe / press / input
├── assert
│   ├── text-exists / text-not-exists / route / webview
├── evidence
│   ├── capture / export / redact / summarize
└── plan / replay / smoke
```

### 目标 agent 流程

未来 agent 的典型流程应像这样：

```text
triton doctor --json
triton capabilities --json
triton schema --command xcode --json
triton plan run-ios-app --json
triton xcode run --jsonl
triton wait --json
triton assert text-exists "Home" --json
triton evidence --output run.tritonevidence --json
```

这条流程表达的是：agent 先询问 Triton 当前环境、命令契约和推荐计划，再执行真实命令，最后用 assert / evidence 形成验收闭环。

### 方案 C BDD 场景

#### 场景一：新 agent 不读 README 也能规划

- Given agent 只知道当前随包 skills 和 `triton` CLI
- When agent 通过 `schema + capabilities + plan` 查询当前契约
- Then agent 能生成一次 iOS simulator build-run-assert 的命令序列

#### 场景二：runtime 未连接时可恢复

- Given 没有连接 embedded runtime
- When agent 调用需要 runtime 的命令
- Then CLI 返回单个 JSON 错误
- And 错误包含下一步命令建议

#### 场景三：多目标可消歧

- Given 同时存在多个 iOS simulator 或 Harmony target
- When agent 调用 `target resolve`
- Then CLI 返回可机器读取的唯一目标或明确的多匹配错误

#### 场景四：错误 envelope 不二次包装

- Given 任意命令失败
- When 输出 JSON 错误
- Then 错误 envelope 包含 `code`、`message`、`hint`、`nextAction`
- And 输出仍是单个合法 JSON 对象

#### 场景五：失败 smoke 可审计

- Given 一次 smoke 失败
- When agent 生成 evidence bundle
- Then agent 能知道该看哪些 artifact、日志、截图和断言结果

#### 场景六：破坏性命令仍受策略保护

- Given 命令会删除、重置、停止或覆盖重要状态
- When agent 执行该命令
- Then CLI 必须要求显式确认或 dry-run 策略
- And schema 必须标注 destructive policy

### 四期实施切片

#### 一期：信息事实源

统一 `schema`、`capabilities`、`doctor`、`plan` 输出，补齐 command metadata、错误码、`nextCommands`、`outputContracts`。

本期可以先不改命令名，但不把“保持命令名不变”作为长期约束。

#### 二期：target 模型

把 `device` / `sim` / `app` 中的选择逻辑统一成 target resolver。

目标是 agent 永远先 `target list` / `target use` / `target current` / `target resolve`，再执行 app、runtime、xcode、observe 或 action。

#### 三期：workflow plan

让 `triton plan` 从静态建议升级成任务型建议，例如：

```text
triton plan ios-smoke --json
triton plan open-url --url <url> --json
triton plan webview-check --json
```

`plan` 只负责规划，不替代真实命令执行。

#### 四期：skills 与文档同步迁移

README、public skills、真实项目回归指南和 dev 文档全部改成新入口。

不保留 legacy / compatibility 层；若旧入口不符合 agent-facing 信息架构，可以删除或重命名，但必须同轮同步 schema、skills、docs 和 tests。

### 主要风险

1. 范围爆炸：方案 C 会碰 CLI schema、命令注册、错误模型、README、skills、测试和真实项目回归流程。
2. 过度抽象：如果缺少真实 agent 使用案例，过早设计完整 workflow DSL 可能偏离实际。
3. 中间态割裂：CLI 已破坏性调整，但随包 skills 或 schema 仍描述旧契约，会让 agent 失去可用入口。

### 刹车线

只要出现以下情况，当前轮必须暂停或缩小范围：

1. CLI、schema、skills 不能在同一轮保持一致。
2. `verify.sh --local` 或本轮聚焦验证无法稳定通过。
3. `plan` 层开始替代真实命令执行，而不是只提供建议。
4. 需要引入 Web / Wails UI、真机、远端 agent、设备云或新服务端产品面。
5. 需要发布、push、tag、Homebrew tap 更新或真实账号 / 证书。

## 运行护栏

1. 默认不 push、不 tag、不 release、不更新 Homebrew tap。
2. 不碰外部私有项目、账号、证书、签名资产或敏感日志。
3. 不执行破坏性 simulator / runtime 操作，除非已有 dry-run、显式确认和测试覆盖。
4. 不恢复 Web / Wails UI，除非另建 space 重新定义边界。
5. 每轮完成后必须有 checkpoint：改动范围、验证命令、剩余风险、memory 状态。
6. 若本地验证连续失败且无法小步恢复，暂停并写明阻塞。

## 里程碑视图

### M0：规划冻结

范围：完成本 space、长期计划、关键决策和巡航协议。

完成标准：

- 本文档能直接指导长期运行。
- 明确“不维护 legacy / compatibility 层”。
- 明确 CLI 与随包 skills 同步破坏性演进。
- memory 与 文档门禁已完成。

### M1：当前命令面稳定化

范围：第 1 轮至第 6 轮。

完成标准：

- 当前 WIP 已归因并收口。
- 当前 CLI 命令面基线已冻结。
- `triton schema` 覆盖重点命令的参数、错误码、输出契约和下一步建议。
- 错误 envelope 可被 agent 机器读取。
- Host 命令文件进入可维护拆分状态。

### M2：agent-facing 信息架构重排

范围：第 7 轮至第 14 轮。

完成标准：

- 新信息架构文档完成。
- `target`、`capabilities`、`doctor`、`plan`、`action`、`observe`、`assert` 等入口按 agent 使用优先级重排。
- 旧心智模型不再作为兼容负担保留。
- 随包 public skills 与新 CLI 契约同步。

### M3：回归闭环产品化

范围：第 15 轮至第 18 轮。

完成标准：

- evidence manifest、record、replay、assert 形成统一闭环。
- iOS 本机 simulator 回归样板可复查。
- Harmony / DevEco Emulator 回归样板可复查。
- 失败时可离线定位 artifact、日志、截图和断言结果。

### M4：发布前治理收敛

范围：第 19 轮至第 21 轮。

完成标准：

- README、dev 文档、public skills、internal skills 和 memory 对齐。
- 治理脚本缺口已修复或明确记录。
- wrap report 完成，下一期 backlog 清晰。

## 巡航执行协议

每次长期运行按以下顺序执行：

1. 读取本计划和当前 active space。
2. 查看 `git status --short --branch`，只做归因，不自动回滚。
3. 选择队列中最靠前且未完成的一轮。
4. 为本轮补充或确认 BDD 验收点。
5. 先补测试或可执行证据，再做最小实现或文档更新。
6. 运行聚焦验证。
7. 更新本计划的 checkpoint 或对应轮次状态文档。
8. 写入 memory，执行 文档门禁。
9. 若改动稳定且用户允许本地 checkpoint，可提交；默认不 push。

## 每轮 checkpoint 模板

每轮结束时在本 space 下新增或更新 checkpoint 记录，建议路径：

`plans/checkpoints/<YYYYMMDD>-round-<NN>-<slug>.md`

内容模板：

```text
# Round <NN>: <title>

## 目标

## 本轮完成

## 改动范围

## 验证

## 决策

## 风险

## 下一轮建议
```

checkpoint 只记录稳定事实，不记录临时猜测；如果发现可复用流程，按边界优先更新 `TritonKit.skills/` 或 `.agents/skills/`，只有 repo-wide 规则才进入 `AGENTS.md`。

## 优先级规则

1. 先做能提升 agent 自发现和恢复能力的改动。
2. 先做机器可读契约，再做人工文档。
3. 先做不会改变产品边界的改动。
4. 先做可用单元测试或 fixture 覆盖的改动。
5. 遇到 Web / Wails UI、真机、远端 agent、设备云、发布链路时暂停，除非用户单独授权新 space。

## 破坏性更新规则

本项目允许破坏性 CLI 更新，但必须满足以下条件：

1. 同一轮内同步更新 `triton schema`。
2. 同一轮内同步更新随包 public skills。
3. 同一轮内同步更新 README 或相关 dev 文档。
4. 同一轮内更新或删除旧测试，避免测试继续表达旧契约。
5. 交付说明必须明确命令契约发生了什么变化。

若破坏性更新跨越多轮，第一轮必须在计划中写清迁移顺序，避免出现 CLI 已变而 skills 仍指向旧命令的中间状态。

## 暂停条件

长期巡航遇到以下情况必须暂停：

1. 需要用户账号、证书、签名资产、GitHub token 或 Apple Developer 信息。
2. 需要 push、tag、release 或更新 Homebrew tap。
3. 需要删除 simulator、erase runtime、清空 DerivedData 以外的重要数据或执行不可逆操作。
4. 需要改变产品边界，例如恢复 Web UI、支持真机、支持远端 agent 或云设备。
5. 同一验证连续失败三次，且无法通过小步改动定位。
6. 当前工作区存在无法归因的用户改动，继续执行会覆盖或混淆用户工作。

## 报告格式

用户查看进度时，按以下格式汇报：

```text
已完成：

正在做：

验证：

风险：

下一步：
```

巡航最终收尾报告按以下格式：

```text
目标：

实际完成：

未完成：

验证：

文档 / skills / memory：

风险：

下一期 backlog：
```

## 巡航队列

### 第 1 轮：收口当前 WIP

目标：归因当前 `main` 上的超前提交和未提交改动，避免新一期与旧工作混线。

交付：

- 当前 WebView / input / schema / evidence / targeting 改动归类为已完成、需补测或转入本期。
- 明确是否需要先提交或拆分旧 WIP。
- 记录当前 dirty worktree 风险。

验证：

- `git status --short --branch`
- `git diff --stat`
- 聚焦测试命令按实际 WIP 决定

### 第 2 轮：建立本期 space 与验收边界

目标：完成本 space 的需求边界、BDD 场景和长期计划。

交付：

- `README.md`
- `plans/20260527-long-term-cruise-plan-v01.md`
- memory 写回

验证：

- `docs-linhay/scripts/check-docs.sh`
- `docs-linhay/scripts/check-docs.sh`

### 第 3 轮：冻结当前命令面基线

目标：得到当前 CLI 信息架构真实快照。

交付：

- `triton --help` 基线摘要
- `triton schema --json` 基线摘要
- `xcode`、`device`、`sim`、`app`、`runtime`、`webview`、`input`、`assert`、`evidence` 重点命令审计
- schema / help / 实际 ArgumentParser 注册不一致清单

验证：

- 当前源码构建出的 `triton` 可运行
- 基线文档可复查

### 第 4 轮：schema 事实源补齐

目标：让 `triton schema --json` 成为 agent 的第一事实入口。

交付：

- 补齐重点命令的 `requiredOptions`
- 补齐 `failureCodes`
- 补齐 `nextCommands`
- 补齐 `outputContracts`
- 补齐 `runtimeScope`、`artifacts`、`stopConditions`

验证：

- 新增 / 更新 CLI schema tests
- `swift test --package-path CLI`

### 第 5 轮：错误 envelope 与恢复建议统一

目标：失败后 agent 能机器读取恢复路径。

交付：

- 统一 `code`、`message`、`hint`、`nextAction` 或等价机器可读恢复字段
- 覆盖 server 不可达、target 多匹配、runtime 未连接、参数冲突、缺必填参数、破坏性命令未确认、断言失败等路径
- 确保失败输出仍是单个合法 JSON envelope

验证：

- CLI failure tests
- 重点覆盖 `doctor`、`status`、`device resolve`、`app install`、`app launch`、`webview wait`、`input`

### 第 6 轮：Host 命令拆分

目标：降低 `CLIHostCommands.swift` 的维护成本，不把新能力继续堆进巨型文件。

交付：

- 拆分为 `CLIDeviceCommands.swift`
- 拆分为 `CLISimCommands.swift`
- 拆分为 `CLIAppCommands.swift`
- 抽出 `CLIHostSelectionRuntime.swift`
- 抽出 `CLIHostModels.swift`

验证：

- 外部行为按本轮目标保持可用，除非同时进入后续破坏性重排
- `swift test --package-path CLI`

### 第 7 轮：agent-facing CLI 信息架构设计落文档

目标：正式进入方案 C，定义新信息架构。

交付：

- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
- 明确新心智模型：
  - `schema`：命令事实源
  - `capabilities`：环境能力源
  - `doctor`：诊断恢复入口
  - `target`：目标选择入口
  - `project` / `xcode`：工程发现、构建、测试、运行入口
  - `runtime` / `observe` / `webview`：观察入口
  - `action`：动作入口
  - `assert`：验收入口
  - `evidence` / `record` / `replay`：证据与复跑入口

验证：

- 文档与 README / skills 后续迁移目标一致
- 无 legacy / compatibility 章节

### 第 8 轮：破坏性命令契约重排一期

目标：以 agent 最优使用为准重排命令，不保留旧入口包袱。

交付：

- 建立或重排 `target` 入口：`list`、`use`、`current`、`resolve`、`wait-ready`
- 将 `device` / `sim` 中属于目标选择的能力迁移到 `target`
- 同步更新 schema 和 skills

验证：

- 多 target、alias、current、ready filter 测试通过
- 旧命令若被删除或重命名，相关 tests / docs / skills 同步迁移

### 第 9 轮：capabilities 升级

目标：让 agent 能判断当前环境能做什么。

交付：

- 能力矩阵覆盖 CLI、本机工具、server、runtime、iOS Simulator、Harmony target、Xcode project、WebView bridge、evidence、replay
- 输出缺失能力与建议命令

验证：

- 无 server、有 server 无 target、有 runtime、有 simulator、有 Harmony target 等场景测试

### 第 10 轮：doctor 升级

目标：`doctor` 从状态诊断升级为恢复路径建议。

交付：

- 输出诊断项
- 输出缺失项
- 输出下一步命令
- 输出风险提示

验证：

- doctor tests
- 错误 envelope tests

### 第 11 轮：plan 任务型入口一期

目标：让 `triton plan` 输出可执行命令序列，但不直接执行。

交付：

- `triton plan ios-smoke --json`
- `triton plan xcode-run --json`
- `triton plan open-url --json`
- `triton plan webview-check --json`
- 输出 `steps`、`commands`、`requires`、`expectedArtifacts`、`stopConditions`

验证：

- plan JSON snapshot tests
- 不依赖真实 simulator 即可测试

### 第 12 轮：action 层整理

目标：把 agent 动作入口统一成清晰层级。

交付：

- 整理 `find`、`tap`、`type`、`paste`、`clear`、`swipe`、`press`、`input`
- 统一 target 参数、输出格式、错误码、examples
- 必要时破坏性重命名为 `action <subcommand>` 结构

验证：

- action command tests
- schema examples 可直接复用

### 第 13 轮：observe / runtime / webview 观察层整理

目标：让 agent 明确何时用 runtime，何时用 observe，何时用 webview。

交付：

- 统一 `observe current/tree`
- 统一 `runtime snapshot/state`
- 统一 `webview snapshot/current-url/wait`
- schema 标注适用条件与输出模型

验证：

- observation / runtime / webview tests
- WebView opt-in 边界仍清楚

### 第 14 轮：assert 层整理

目标：把验收命令统一成 agent 的完成判断入口。

交付：

- UI 文本断言
- route 断言
- webview URL / selector / text 断言
- runtime state 断言
- 断言失败提示 evidence 下一步

验证：

- assert success / failure tests
- 失败输出包含恢复建议

### 第 15 轮：evidence 闭环升级

目标：失败后有完整、可离线读的证据包。

交付：

- `.tritonevidence` manifest 统一记录 commands、events、screenshots、logs、assertions、redaction、artifacts
- 所有大输出只返回 path、bytes、truncation、summary
- 失败命令优先提示 evidence capture

验证：

- EvidenceBundle tests
- redaction tests
- manifest schema tests

### 第 16 轮：record / replay 与 plan 对齐

目标：把 agent 操作沉淀成可复跑 `.tritonplan`。

交付：

- `record` 生成 plan 模板
- `plan inspect` 离线摘要
- `replay --dry-run` 检查变量、target、脱敏、破坏性策略
- `replay` 与 evidence 关联

验证：

- Replay plan model tests
- dry-run 不触发真实动作

### 第 17 轮：iOS agent 回归样板

目标：形成标准 iOS 本机 simulator 回归链路。

交付：

- discover
- xcode run
- wait
- observe
- action
- assert
- evidence

验证：

- 本机 simulator 可用时跑真实 smoke
- 不可用时保留可复现命令和阻塞说明

### 第 18 轮：Harmony agent 回归样板

目标：形成 Harmony / DevEco Emulator host-side agent 回归链路。

交付：

- target resolve
- runtime-url
- launch
- screenshot / observe
- assert
- evidence

验证：

- fixture / smoke 优先
- 真实环境不可用时明确阻塞项

### 第 19 轮：README / skills 全量迁移

目标：让随包 skills 描述当前 CLI 契约，而不是兼容旧入口。

交付：

- 更新 README
- 更新 `docs-linhay/dev/ai-cli-readable-control.md`
- 更新 `tritonkit-dev-feedback`
- 更新 `tritonkit-real-project-regression`
- 更新 `tritonkit-emulator-cli-takeover`
- 必要时更新 internal skills

验证：

- docs-only 门禁
- skill 路径检查
- 命令示例全部指向当前契约

### 第 20 轮：治理脚本补洞

目标：修正项目规则与实际脚本之间的断点。

交付：

- 补齐 `docs-linhay/scripts/create-space.sh` 或修正相关治理规则
- 检查 `verify.sh`
- 检查 `check-docs.sh`
- 检查 `文档门禁`
- 修复或记录 历史检索 / embedding 异常降级策略

验证：

- `docs-linhay/scripts/check-docs.sh`
- `docs-linhay/scripts/check-docs.sh`
- create-space dry-run 或临时路径验证

### 第 21 轮：巡航总结与下一期 backlog

目标：沉淀本期成果、风险和下一期队列。

交付：

- `cruise-wrap-report-<YYYYMMDD>-v01.md`
- memory 写回
- 文档门禁
- checkpoint commit 清单
- 下一期 backlog

验证：

- `docs-linhay/scripts/verify.sh --local`
- 如涉及 CI / release 契约，再跑 `docs-linhay/scripts/verify.sh --ci-validate`

## 完成定义

1. agent-facing CLI 信息架构完成破坏性重排。
2. `triton schema`、README、public skills、dev 文档和测试完全同步当前契约。
3. 至少一条 iOS 回归链路和一条 Harmony 回归链路有可复查证据。
4. memory 与 文档门禁已完成。
5. 未完成事项进入下一期 backlog，而不是散落在会话中。

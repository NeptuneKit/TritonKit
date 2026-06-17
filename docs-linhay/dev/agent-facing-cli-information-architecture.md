# Agent-Facing CLI Information Architecture

## 背景

本方案对应 `20260527-command-surface-optimization` 的第 7 轮。TritonKit 后续把 `triton` CLI 定义为 AI agent 使用的本机控制面，而不是一组需要 agent 记忆的离散命令。

当前约束：

1. CLI 与随包 skills 直接绑定，agent 面对的是当前版本契约。
2. 可以破坏性重排命令、参数、schema 和文档。
3. 每次命令面变化必须同步 `triton schema`、README、public skills、dev 文档和测试。
4. 首期仍是本机 CLI / HTTP / embedded runtime / host-side adapter，不恢复 Web / Wails UI，不做真机、远端 agent、设备云或云端控制面。

## 目标

1. agent 不读源码、不猜 README，通过机器可读入口知道当前能做什么。
2. agent 能先发现环境能力，再选择 target，再规划命令，再执行动作，再断言结果，再沉淀 evidence / replay。
3. 所有失败都能回到单个 JSON error envelope，并提供机器可读恢复动作。
4. 一次 iOS 或 Harmony 回归可以形成可复查、可复跑、可脱敏的证据链。

## 信息架构

`triton` 对 agent 暴露 10 个一等信息域：

| 域 | 定位 | 典型命令 |
| --- | --- | --- |
| Bootstrap | CLI 自描述与本机服务状态 | `version`、`status`、`schema` |
| Capabilities | 当前环境能力矩阵 | `capabilities` |
| Doctor | 诊断与恢复入口 | `doctor` |
| Target | 目标发现、选择、消歧和就绪 | `target list/use/current/resolve/wait-ready` |
| Project / Xcode | 工程发现、构建、测试和运行 | `project discover/use/status`、`xcode schemes/settings/build/test/run` |
| Runtime | embedded runtime manifest、state、snapshot 和 ledger | `runtime manifest`、`state`、`snapshot`、`ledger` |
| Observe | 可见面、层级、WebView、route、截图和 artifact | `observe current/tree/webview`、`webview`、`route`、`screenshot` |
| Action | agent 动作入口 | `action find/tap/type/paste/clear/swipe/press/input` |
| Assert | 回归验收入口 | `assert text-exists/text-not-exists/route/webview` |
| Evidence / Replay | 审计、脱敏和复跑 | `evidence capture/export/redact/summarize`、`record`、`replay`、`smoke` |

当前代码可以分阶段迁移到这些域。命令是否已经完成重排，以 `triton schema --json` 为准，不以本文档里的目标形态为准。

## Agent 标准流程

### 启动发现

agent 新进一个项目时，第一批命令固定为：

```text
triton version --json
triton schema --json
triton doctor --json
triton capabilities --json
triton plan --json
```

预期结果：

1. `version` 说明 CLI 版本、schema version、默认 host/port 和语言。
2. `schema` 说明命令事实，不依赖 server。
3. `doctor` 给出本机服务、host 工具链、runtime、target 的诊断项和恢复命令。
4. `capabilities` 给出当前环境能力矩阵。
5. `plan` 给出下一步命令序列，但不直接执行。

### 目标选择

target 是所有 host-side 和 runtime-side 控制的前置上下文。目标选择顺序固定为：

```text
triton target list --json
triton target resolve <selector> --json
triton target use <selector> --json
triton target current --json
triton target wait-ready --json
```

`target` 输出必须覆盖：

1. `id`：稳定机器 id，例如 `ios-simulator:<udid>`、`harmony:<hdc-target>`、`runtime:<runtime-id>`。
2. `platform`：`ios`、`harmony`、`android`、`macos` 等。
3. `kind`：`simulator`、`emulator`、`runtime`、`app`、`workspace` 等。
4. `state`：原始状态，例如 `Booted`、`Connected`、`Shutdown`。
5. `ready`：agent 是否可以把它作为动作目标。
6. `sources`：来自 host adapter、embedded runtime、workspace defaults、alias registry 的证据。
7. `selectors`：可用于后续命令的稳定 selector。
8. `ambiguity`：多匹配原因和推荐消歧字段。

后续 `app`、`runtime`、`observe`、`action`、`assert`、`evidence` 默认消费 `target current` 或显式 `--target` / `--device`。

### 规划与执行

`plan` 只生成建议，不替代真实命令执行。任务型 plan 的输出必须包含：

1. `goal`：任务名，例如 `ios-smoke`、`xcode-run`、`open-url`、`webview-check`。
2. `requires`：server、target、runtime、host tools、project defaults、artifacts 等前置条件。
3. `steps[]`：有序步骤。
4. `commands[]`：可直接执行的 argv 数组，不要求 agent 解析自然语言。
5. `expectedArtifacts[]`：预期截图、日志、evidence、xcresult、trace 等产物。
6. `stopConditions[]`：失败、超时、断言不通过、target 断连、破坏性策略未满足等停止条件。
7. `recovery[]`：失败后的下一步诊断命令。

当前已落地的第一批任务型入口是 `ios-smoke`、`open-url`、`webview-check`。实现先复用现有 `TKWorkflowPlanResponse` 的 `surface/mode/goal/nextStep/nextWorkflows/steps[]` 结构，仍只负责规划，不执行真实命令；其中 `surface=plan` 固定标识 bootstrap 规划入口，`mode=bootstrap` 表示环境恢复计划，`mode=task` 表示目标型 workflow 计划，`nextWorkflows[]` 直接声明当前推荐 planning lane 属于哪组 workflow taxonomy。每个 step 已暴露 `command`、`argv[]`、`category`、`workflowCategories[]`、`requires[]`、`expectedArtifacts[]` 与 `stopConditions[]`。其中 `argv[]` 是 agent 主执行事实源，`command` 只保留给日志与人工复制，`workflowCategories[]` 让 agent 进入具体 step 后仍能保持对 workflow lane 的直接感知，而不是退回到 root command 推断。后续若需要多命令 step，再单独结构化 `commands[]`，不能把 shell 脚本塞回 `command`。

`.tritonplan` 的离线检查入口也复用同一套执行元数据词汇。`triton plan inspect <file.tritonplan> --json` 返回 `TKReplayPlanSummary.steps[]`，每个 step 包含 `index/id/name/action/command/argv/category/workflowCategories/requires/expectedArtifacts/stopConditions/validationErrors`。这让 agent 在不连接 runtime 的情况下先检查 replay flow 的前置条件、可审计产物、停止条件、workflow lane 和静态 step 形状诊断，再进入 `replay --dry-run` 或真实 replay；secure 输入只保留 redacted token，变量占位继续以 `${name}` 形式留在 `argv[]`。`validationErrors[]` 只报告 step 结构问题，不把尚未提供的 `${variable}` 值当成 inspect 错误。

`triton replay <file.tritonplan> --dry-run --json` 的 `TKReplayResult.steps[]` 也暴露 `command/argv/category/workflowCategories/requires/expectedArtifacts/stopConditions`。其中 `steps[].argv` 是变量替换后的首选执行字段，可与 `plan inspect` 中变量保留的 `steps[].argv` 对照；`command` 保留为历史 argv alias / 日志字段。除了 `steps[]`，顶层还必须直接暴露失败路由事实：`failedStepIndex`、`failureCode`、`failureError`、`failurePrimaryWorkflowCategory`、`failureWorkflowCategories[]`、`failurePrimaryRecoveryCategory`、`failureRecoveryCategories[]`、`failurePrimaryHint`、`failurePrimaryEndpoint`、`failurePrimaryNextAction`、`failurePrimaryArtifact`、`failurePrimaryArtifacts[]`、`failurePrimarySuggestedCommand`、`failurePrimaryRecoveryCommand`、`recoveryCommands[]`、`suggestedCommands[]`。失败 step 本身仍应暴露结构化 `error`，至少保留 `code/message/hint/endpoint/nextAction/nearestCandidates/suggestedCommands/candidateCount` 这类 `TKCLIErrorDetail` 字段。这样 agent 在 replay 失败后，不需要先遍历 `steps[]`、抽取 workflow taxonomy、再从最近 evidence/file 产物里自己拼诊断入口，也不需要把 `suggestedCommands[]` 再拆成 category；它可以先消费顶层 failure code、顶层 failure detail、首选 failure lane、首选 recovery lane、首选诊断 hint、首选诊断 endpoint、首选结构化 next action、首选 artifact、首选建议命令字符串、首选恢复命令、失败 step 的结构化错误和恢复命令，再决定是否下钻到具体 step 细节。真实 replay 运行时若拿到了底层 `TKCLIErrorDetail.code`，必须优先原样提升到 step/top-level `failureCode`；`failureError` 则优先直接复用失败 step 的 `error`。只在没有更具体错误时才回落到 `step_failed`。当前 schema contract 也要求 `failureError.*` 与 `steps[].error.*` 同步展开至少一组稳定子字段，保证顶层和 step-level error surface 的机器可读性一致；如果 `failureError.nextAction` 存在，`failurePrimaryNextAction`、`suggestedCommands[]` / `recoveryCommands[]` 也必须能看见同一条恢复入口，而且它的 category 也必须出现在 `failureRecoveryCategories[]` 中。对于 selector 或文本候选类失败，`nearestCandidates[]`、`candidateCount` 和错误内联 `suggestedCommands[]` 也必须通过同一套 error contract 保持显式可读，而不是只靠 DTO 猜测。对于没有抛错但 `ok=false` 的 replay 步骤，也应尽量补出同一套 step 级 `error`；本轮先覆盖 `wait`、`input`、`evidence`。`plan inspect` summary、dry-run result 和真实 replay result 的 argv / metadata 派生必须复用 `TKReplayStepExecution`，后续新增 replay action 时只改这一处事实源。

`TKReplayStepExecution` 也是 replay dry-run 的静态验证入口。它必须提前拒绝多 selector 的 `tap`、多 condition 的 `wait`、缺少 `value/text` 的 `paste/type`、缺少 condition 的 `wait`，避免 agent 到真实 runtime 执行阶段才发现 `.tritonplan` 本身不可执行。

`replay --dry-run --json` 的静态 validation failure 必须保持单 envelope 输出。失败时只允许一个 JSON 对象进入 stdout 或 stderr，退出码非 0，并使用 `error.code=validation_failed`；这保证 agent 不需要处理多个 JSON envelope 串联或二次包装错误。

任务型 plan 的 schema-backed 对齐校验现在以 `steps[].argv` 为准，`steps[].command` 只要求保持单条 `triton ...` 人读调用。新增或修改 plan 步骤时，至少要保证 `argv[]` 中的根命令存在于 schema、声明的子命令存在于该命令的 `subcommands[]`，并且所有 `--flag` 都能在命令 schema 或子命令 schema 中找到；该约束由 `SchemaFactSourceTests.taskWorkflowPlanArgvStayAlignedWithCommandSchemas` 锁定。

示例目标形态：

```json
{
  "ok": true,
  "task": "ios-smoke",
  "requires": ["xcode.project", "target.ready", "runtime.connected"],
  "steps": [
    {
      "id": "discover-target",
      "command": "triton target resolve booted --json",
      "argv": ["triton", "target", "resolve", "booted", "--json"],
      "category": "prepare-target",
      "requires": ["cli.available"],
      "expectedArtifacts": ["stdout-json", "target-resolution"],
      "stopConditions": ["command.failed"]
    },
    {
      "id": "run-app",
      "command": "triton xcode run --jsonl",
      "argv": ["triton", "xcode", "run", "--jsonl"],
      "category": "project",
      "requires": ["cli.available", "server.reachable"],
      "expectedArtifacts": ["stdout-json", "xcode-log"],
      "stopConditions": ["command.failed", "server.unavailable"]
    },
    {
      "id": "assert-home",
      "command": "triton assert text-exists Home --json",
      "argv": ["triton", "assert", "text-exists", "Home", "--json"],
      "category": "verify",
      "requires": ["cli.available", "server.reachable", "target.ready", "runtime.connected"],
      "expectedArtifacts": ["stdout-json", "assertion-result"],
      "stopConditions": ["command.failed", "server.unavailable", "target.unavailable", "assertion.failed"]
    }
  ],
  "expectedArtifacts": ["screenshot", "evidence"],
  "stopConditions": ["command_failed", "assertion_failed", "target_lost"]
}
```

## Command Schema 契约

`triton schema --json` 是命令事实源。每个 agent-facing command 至少暴露：

1. `name`：命令名。
2. `summary`：短说明。
3. `subcommands[]`：子命令契约。
4. `options[]` / `arguments[]`：参数、类型、默认值、required、enum、冲突关系、二选一关系。
5. `requires`：server、target、runtime、host tools、project、artifact output 等依赖。
6. `destructive`：是否可能修改本机状态、模拟器状态、App 状态或证据包。
7. `outputContracts[]`：成功输出模型。
8. `failureCodes[]`：稳定错误码集合。
9. `nextCommands[]`：下一步建议。
10. `artifacts[]`：会读取或写出的产物。
11. `examples[]`：argv 级示例。

schema 必须覆盖“如何调用”和“失败后如何恢复”，不能只覆盖 help 文本。

任何声明 `providedCapabilities[]` 的命令都必须有 `outputContracts[]`。能力代表 agent 可执行或可依赖的操作面，缺少 output contract 等于 agent 无法稳定解析成功输出；该约束由 `SchemaFactSourceTests.commandsThatProvideCapabilitiesExposeOutputContracts` 锁定。

每个 `outputContracts[]` 条目必须具备非空 `selector`、非空 `model` 和非空 `fields[]`。字段定义必须有稳定 `name`、`type`、`description`，同一 contract 内字段名不能重复；该约束由 `SchemaFactSourceTests.schemaOutputContractsExposeNonemptyFields` 锁定，避免 schema 只声明“有输出”但缺少足够解析信号。

`outputContracts[].fields[].type` 必须使用机器可读类型语法，不允许自然语言自由文本。当前支持标量/DTO 类型、optional `?`、数组 `[Type]`、字典 `[Key:Value]` 和 union `TypeA|TypeB`；该约束由 `SchemaFactSourceTests.schemaOutputContractFieldTypesStayMachineReadable` 锁定。

`outputContracts[].model` 也必须使用同一套机器可读类型语法。model 是 agent 建立输出解析器的主模型名，不能写自然语言描述或 Swift 泛型散文；本轮已将 `embedded screenshot metadata dictionary` 收敛为 `ScreenshotMetadataOutput`，将 `Dictionary<String, [HierarchyNodeSummary]>` 收敛为 `HierarchyNodeSummaryMap`。该约束由 `SchemaFactSourceTests.schemaOutputContractModelsStayMachineReadable` 锁定。

`outputContracts[].selector` 必须是稳定 agent key：使用点分层级，每个 segment 是小写 kebab，例如 `runtime.snapshot`、`host.device-list`、`route.current-url-assert`。`outputContracts[].kind` 必须是单段小写 kebab，例如 `runtime-snapshot`、`host-device-list`。该约束由 `SchemaFactSourceTests.schemaOutputContractSelectorsAndKindsUseStableAgentKeys` 锁定。

`outputContracts[].format` 必须落在固定 agent taxonomy：`json`、`jsonl`、`archive`。新增格式前必须先定义 agent 如何读取、流式处理或归档该格式，并同步 schema 测试、文档和 skills；该约束由 `SchemaFactSourceTests.schemaOutputContractFormatsStayWithinAgentTaxonomy` 锁定。

`outputContracts[].kind` 也必须落在固定 agent taxonomy。kind 是输出模型的语义分类，例如 `status-envelope`、`capability-matrix`、`runtime-snapshot`、`input-result`、`evidence-manifest`、`progress-event`、`final-event`、`artifact-envelope` 等；新增输出模型时必须同步扩展 kind taxonomy，而不能直接写入临时字符串。该约束由 `SchemaFactSourceTests.schemaOutputContractKindsStayWithinAgentTaxonomy` 锁定。

凡是 output contract 里声明 `error: TKCLIErrorDetail?`，schema 都必须同步展开稳定子字段，而不是只给黑盒 DTO 名字。当前通用最小集为：`error.endpoint`、`error.hint`、`error.nearestCandidates`、`error.suggestedCommands`、`error.candidateCount`、`error.nextAction`、`error.nextAction.command`、`error.nextAction.args`、`error.nextAction.category`、`error.nextAction.requiresLongRunningProcess`、`error.nextAction.readyEvents`、`error.nextAction.finalEvents`、`error.nextAction.terminationSignals`。这样 agent 在遇到普通命令失败时，不需要从 Swift DTO 定义或 README 猜测哪些错误子字段可读，也不用从 argv 反推长驻进程的 ready / final / stop 语义。

同一 command 内的 `outputContracts[].selector` 必须唯一。agent 会用 selector 定位可解析输出模型，重复 selector 会让同一个命令的输出契约出现歧义；该约束由 `SchemaFactSourceTests.schemaOutputContractSelectorsRemainUniqueForAgentLookup` 锁定。

子命令的 `outputSelectors[]` 必须能被父命令的 `outputContracts[].selector` 覆盖。agent 可以先看子命令知道应该消费哪个输出模型，再回到父命令 output contract 读取字段定义；该约束由 `SchemaFactSourceTests.subcommandOutputSelectorsStayCoveredByParentOutputContracts` 锁定。

任何声明失败退出或 `failureShape` 的命令都必须有非空 `failureCodes[]`。如果某个命令没有失败面，例如纯 bootstrap 的 `version`，应显式保持 `failureShape=nil`，不能继承默认失败 envelope 误导 agent；该约束由 `SchemaFactSourceTests.schemaFailureSurfacesExposeStableFailureCodes` 锁定。

任何在 `failureShape` 中声明 `nextAction?` 的错误 envelope，都必须同时说明 next action 的 `command/args/category/requiresLongRunningProcess/readyEvents/finalEvents/terminationSignals` 结构。任何 `outputContracts[]` 字段声明 `error: TKCLIErrorDetail?` 时，也必须自动暴露完整 `error.nextAction.*` 子字段，避免 agent 在 failure shape、doctor、capabilities 与 plan 之间切换解析规则；该约束由 `SchemaFactSourceTests.schemaFailureShapesDescribeNextActionCategory` 与 `SchemaFactSourceTests.errorOutputContractsExposeNextActionCategory` 锁定。

`failureCodes[]` 必须使用稳定 lower_snake_case，且同一 command 或 subcommand 内不能重复。agent 会把 `error.code` 直接映射到恢复策略，不能依赖大小写、短横线、自然语言或重复值归一化；该约束由 `SchemaFactSourceTests.schemaFailureCodesUseStableSnakeCase` 锁定。

子命令的 `failureCodes[]` 必须是父命令 `failureCodes[]` 的子集。agent 可以先读父命令 schema 建立恢复码全集，再按子命令收窄失败范围；该约束由 `SchemaFactSourceTests.subcommandFailureCodesStayCoveredByParentSchemas` 锁定。

每个 command 的 `options[]` 与 `subcommands[]` 也必须满足最低元数据质量：option 的 `name`、`type`、`description` 非空，同一命令内 option name 不重复；subcommand 的 `name`、`summary` 非空，同一命令内 subcommand name 不重复。该约束由 `SchemaFactSourceTests.schemaOptionsAndSubcommandsExposeNonemptyMetadata` 锁定。

Command name 与 subcommand name 必须使用 lower-kebab key；`options[].name` 中以 `--` 开头的纯长 flag 或 slash alias 组也必须使用 lower-kebab，例如 `--language/--lang`、`--refresh/--no-refresh`。该约束由 `SchemaFactSourceTests.schemaCommandSubcommandAndFlagNamesUseStableCLIKeys` 覆盖。

Subcommand / task 这类 usage synopsis 必须进入 `usageForms[]`，不能继续塞进 `options[]`。`usageForms[]` 每项包含 `form`、`kind` 与 `description`，用于表达 `inspect <path>`、`alias set <name> ...`、`ios-smoke` 这类命令形态；纯 option 继续保留在 `options[]`。该约束由 `SchemaFactSourceTests.schemaUsageFormsStaySeparateFromOptions` 锁定。

Positional argument 必须进入 `argumentForms[]`，不能继续塞进 `options[]`。`argumentForms[]` 每项包含 `name`、`type`、`required` 与 `description`，用于表达 `<query>`、`<path>`、`<text>`、`<selector>` 这类 argv 位置参数；该约束由 `SchemaFactSourceTests.schemaArgumentFormsStaySeparateFromOptions` 锁定。拆分后 `options[]` 必须只保留 `--long-flag` 或 slash alias 组，`SchemaFactSourceTests.schemaCommandSubcommandAndFlagNamesUseStableCLIKeys` 已同步收紧为全量 flag key 检查。

子命令参数引用必须能回到父命令 schema 中发现。`subcommands[].requiredOptions[]`、`optionalOptions[]` 与 `oneOfRequiredOptions[]` 只能引用父命令 `options[]` 中的 flag key，或 `argumentForms[]` 中的 positional argument key；不能出现实现里可用但 schema 未声明的 `--path`、`--output`、`<text>` 等隐式参数。该约束由 `SchemaFactSourceTests.subcommandParameterReferencesStayCoveredByParentSchema` 锁定。

命令级 `requiredOptions[]` 只表达直接调用该命令时需要的参数。只要某个 command 暴露 `subcommands[]`，子命令参数要求就必须进入对应 `subcommands[].requiredOptions[]` / `oneOfRequiredOptions[]` / `optionalOptions[]`，父命令不得再用 `summary/failures:--path`、`record:--template` 或 `workspace defaults or ...` 这类人读摘要聚合子命令需求；该约束由 `SchemaFactSourceTests.commandLevelRequiredOptionsStayDirectOrSubcommandScoped` 锁定。

`defaultProviders[]` 与 `inheritsDefaultsFrom[]` 也必须是 schema-backed Triton 命令。它们描述 agent 可以先执行哪个命令来建立默认值来源，不能写成 README 标题、工具名或自然语言；该约束由 `SchemaFactSourceTests.schemaDefaultProviderReferencesStaySchemaBacked` 锁定。

命令级与子命令级 `artifacts[]` 必须落在固定 schema artifact taxonomy，且同一层级内不能重复。artifact 名称描述命令会读取或写出的证据、日志、截图、trace、coverage、runtime snapshot 等产物，不允许临时自由扩展；新增 artifact 名称时要同步测试、文档和 public skills。该约束由 `SchemaFactSourceTests.schemaArtifactsStayWithinTheArtifactTaxonomy` 锁定。

`jsonlEvents[]` 与 `finalEventKind` 必须使用稳定点分 event key。命令级模板可以使用完整 token 占位符，例如 `xcode.<action>.summary`；具体子命令必须使用真实 action，例如 `xcode.build.summary`。`finalEventKind` 必须出现在同一层级的 `jsonlEvents[]` 中；声明 JSONL event 的命令必须在 `outputFormats[]` 暴露 `jsonl`。该约束由 `SchemaFactSourceTests.schemaJSONLEventsExposeStableEventKeys` 锁定。

任何 `retryable=true` 的命令或子命令都必须暴露非空 `nextCommands[]`。`retryable` 不是只说明“可以再跑一次”，而是给 agent 一个失败或不确定状态后的恢复入口；该约束由 `SchemaFactSourceTests.retryableSchemasExposeRecoveryCommands` 锁定。

任何声明 `failureCodes[]` 的命令都必须能导向恢复命令。命令级有失败码时，命令级 `nextCommands[]` 必须非空；子命令级有失败码时，优先使用子命令自己的 `nextCommands[]`，否则必须能继承父命令级恢复路径。这样 agent 看到稳定 `error.code` 后，不会停在只能分类、不能恢复的状态；该约束由 `SchemaFactSourceTests.failureCodesExposeARecoveryCommandPath` 锁定。

每个 command 必须有非空 `outputFormats[]` 和至少一个 `examples[]`。示例不是 README 装饰文本，而是 agent 可复用的 argv 样本；示例中的 `triton <command>`、子命令和 `--flag` 必须能被同一份 schema 解释。该约束由 `SchemaFactSourceTests.schemaExamplesAndOutputFormatsRemainAgentUsable` 锁定，并支持从 shell pipeline 中抽取 `triton` 调用。

命令级 `outputFormats[]` 必须落在固定 taxonomy：`text`、`json`、`jsonl`、`logs`、`tree`、`auto`、`archive`、`file`、`json-metadata`，且同一命令内不能重复。它描述命令可选择的人读/机器读输出模式；新增值必须先定义 agent 如何选择、解析或归档该模式。该约束由 `SchemaFactSourceTests.schemaOutputFormatsStayWithinCommandTaxonomy` 锁定。

每个 schema example 必须恰好包含一个可抽取的 `triton` invocation。example 可以包含 `printf`、shell pipeline 或 stdin 准备步骤，但不能在同一条样本里混入多个 `triton` 调用，否则 agent 会误把多步 shell 流程当成单步 argv 样本；该约束由 `SchemaFactSourceTests.schemaExamplesContainOneTritonInvocationForAgentReuse` 锁定。

`triton schema --command <name> --json` 必须能过滤出每一个已注册命令，并且只返回该命令的 schema。agent 应该可以先全量读取 inventory，再按需读取单个命令契约，避免每次规划都处理完整 schema。

`nextCommands[]` 也是 schema 的恢复契约，必须自洽：每条 `triton ...` 建议中的根命令、子命令和 `--flag` 都必须能被同一份 `commandSchemas()` 解释；该约束由 `SchemaFactSourceTests.schemaNextCommandsStayAlignedWithCommandSchemas` 锁定。

子命令的 `nextCommands[]` 也必须自洽。父命令 schema 不能只保证命令级恢复建议可执行，还要保证 `subcommands[]` 中的恢复建议同样能被同一份 schema 解释；该约束由 `SchemaFactSourceTests.subcommandNextCommandsStayAlignedWithCommandSchemas` 锁定。

命令级与子命令级 `nextCommands[]` 必须是单条 `triton ...` invocation，不能包含 shell 管道、重定向、命令替换或多命令拼接。恢复建议应是 agent 可直接拆成 argv 的命令；stdin、文件输入或上下文要求应进入 plan metadata 或 `expected` 文本，而不是塞进 command string；该约束由 `SchemaFactSourceTests.schemaNextCommandsStaySingleTritonInvocations` 锁定。

命令级与子命令级 `nextCommands[]` 列表自身也必须保持干净：不能包含空字符串，不能在同一层级重复。agent 会把恢复建议作为候选动作集合，空项或重复项会降低规划确定性；该约束由 `SchemaFactSourceTests.schemaRecoveryCommandListsStayClean` 锁定。

命令级与子命令级 `nextCommands[]` 的根命令必须落在固定 recovery command taxonomy 中。恢复建议只能指向已经被定义为诊断、发现、目标选择、工程/Xcode、观察、动作、断言、证据、replay 或 smoke 的 agent-facing 入口；新增恢复根命令时必须先说明它在恢复流程中的角色，并同步测试、文档和 public skills。该约束由 `SchemaFactSourceTests.schemaRecoveryCommandRootsStayWithinRecoveryTaxonomy` 锁定。

每个 recovery root command 还必须有稳定 category。当前 category taxonomy 为 `diagnose`、`discover`、`prepare-target`、`project`、`observe`、`act`、`verify`、`archive`、`replay`、`smoke`、`plan`。root taxonomy 和 category map 必须一一覆盖，避免 agent 只能知道“这个命令可恢复”，却不知道它是在诊断、准备目标、观察、验证还是归档；该约束由 `SchemaFactSourceTests.schemaRecoveryCommandRootsExposeStableCategories` 锁定。

`triton schema --json` 现在同时暴露 `recoveryCommands[]`。它由 `nextCommands[]` 自动派生，每项包含 `command` 与 `category`，并同时出现在 command 级和 subcommand 级 schema 上。`nextCommands[]` 继续保留为兼容字符串入口；agent 首选读取 `recoveryCommands[]` 进行阶段化恢复规划。该约束由 `SchemaFactSourceTests.schemaRecoveryCommandsMirrorNextCommandsAndExposeCategories` 锁定，并已用 `triton schema --command status --json` 验证 JSON 输出包含该字段。

`failureCodes[]` 还必须能映射到稳定 recovery category family。当前测试按错误码命名族建立分类，例如 target / simulator / runtime 不可用导向 `diagnose`、`prepare-target`、`observe`，断言与 route mismatch 导向 `verify`、`observe`、`archive`，artifact 写入、输出过大或拒绝导向 `archive`、`diagnose`。本轮只要求 failure code family 可分类且分类值属于 `TKCommandRecoveryCommand.categoryTaxonomy`，不强制每个命令的 `recoveryCommands[]` 立即覆盖该 failure code 的所有候选 category；命令级精确恢复覆盖留给后续切片，避免一次性扩大所有 `nextCommands[]`。该约束由 `SchemaFactSourceTests.schemaFailureCodesMapToRecoveryCategoryFamilies` 锁定。

Replay failure surface 现在补了一层 shared model 兜底：只要 `TKReplayResult.failureError.nextAction` 存在，即使 `failureRecoveryCategories[]`、`suggestedCommands[]` 或 `recoveryCommands[]` 在旧 payload 中缺失，shared `TKReplayResult` 的默认构造和解码回填也会自动补齐相应 category 与 `triton ...` 命令。这样 agent 无论消费 CLI 当场输出、磁盘中的旧 replay 结果，还是其他调用方手工构造的结果对象，都能读到同一套恢复入口。进一步地，`nextAction` 现在也是 replay 顶层恢复面的首选路径：如果 category 或 command 已经由 failure-code family 或旧 payload 提前填进数组，shared model 与 CLI runtime 都会把它移动到第一个位置，而不是只做集合包含。当前冲突策略也进一步显式化了：只有在 `nextAction` 存在时，顶层 `failureRecoveryCategories[]` 才会把当前 `recoveryCommands[]` 真正覆盖到的 category 提到前面，而 `failureCode` family 中尚未被 recovery command 覆盖的剩余阶段保留在后面；没有 `nextAction` 的 replay failure 仍保持原始 family-first 排序。

Artifact / output 类失败码必须有 `archive` category 的恢复入口。`artifact_output_rejected`、`artifact_write_failed`、`file_write_failed`、`overwrite_refused`、`xcresult_output_too_large` 这类失败通常意味着 agent 需要保存、换路径、归档或生成 evidence，而不是只做重新发现或重试。该约束由 `SchemaFactSourceTests.artifactFailureCodesExposeArchiveRecoveryCategories` 锁定；本轮补齐 `sim` 与 `record` 的 `triton evidence --output <dir.tritonevidence> --json` 恢复建议。

Assertion / route / text-not-found 类失败码必须有 `verify` category 的恢复入口。`assertion_failed`、`route_mismatch`、`text_not_found` 这类失败说明当前验收条件未满足，agent 需要 wait/assert/route 等验证动作重新确认状态，而不是只截图、归档或重新发现元素。该约束由 `SchemaFactSourceTests.assertionFailureCodesExposeVerifyRecoveryCategories` 锁定；本轮补齐 semantic action、route、smoke、assert、find 的 verify 恢复建议。

Runtime transport 类失败码必须有 `diagnose` category 的恢复入口。`server_unavailable`、`request_failed`、`request_timeout`、`runtime_unavailable`、`runtime_not_connected` 说明 agent 与 Triton server、embedded runtime 或请求通道之间的状态不可靠，必须先能回到 `status` / `doctor` / `capabilities` 这类诊断入口。该约束由 `SchemaFactSourceTests.runtimeTransportFailureCodesExposeDiagnoseRecoveryCategories` 锁定；本轮补齐 runtime、observe、action、assert、wait、evidence 等命令的 `triton status --json` 恢复建议。

Target 类失败码必须有 `prepare-target` category 的恢复入口。`ambiguous_target`、`device_not_ready`、`simulator_not_found`、`target_not_found`、`target_offline`、`target_unavailable` 说明 agent 当前目标不存在、未就绪、不可用或存在歧义，必须先回到 target resolver，而不是继续执行 observe/action/assert。该约束由 `SchemaFactSourceTests.targetFailureCodesExposePrepareTargetRecoveryCategories` 锁定；CLI schema fact source 会对声明这些失败码的 command / subcommand 自动补齐 `triton target resolve <selector> --json`，并保持 `nextCommands[]` 去重与 `recoveryCommands[]` 镜像。

Project / Xcode 类失败码必须有 `project` category 的恢复入口。`ambiguous_workspace`、`invalid_workspace_path`、`scheme_not_found`、`workspace_not_found`、`xcode_not_idle` 说明 agent 的 Xcode 工程上下文缺失、歧义或被占用，必须先回到工程发现 / 默认值配置入口。该约束由 `SchemaFactSourceTests.projectFailureCodesExposeProjectRecoveryCategories` 锁定；CLI schema fact source 会对声明这些失败码的 command / subcommand 自动补齐 `triton xcode discover --path . --json`，并保持 `nextCommands[]` 去重与 `recoveryCommands[]` 镜像。

Action / step 类失败码必须有 `act` category 的恢复入口。`action_failed`、`step_failed` 说明 agent 的动作或 replay 步骤已经失败，必须能回到可执行动作入口，而不是只做诊断、归档或重新规划。该约束由 `SchemaFactSourceTests.actionFailureCodesExposeActRecoveryCategories` 锁定；CLI schema fact source 会对声明这些失败码的 command / subcommand 自动补齐 `triton input --json --summary --strict`，并保持 `nextCommands[]` 去重与 `recoveryCommands[]` 镜像。

Destructive / confirmation 类失败码必须有 `plan` category 的恢复入口。`confirmation_required`、`destructive_action_requires_policy` 说明 agent 碰到了需要确认、策略或 dry-run 复核的状态，必须先回到规划入口，而不是自动继续执行破坏性动作。该约束由 `SchemaFactSourceTests.destructivePolicyFailureCodesExposePlanRecoveryCategories` 锁定；CLI schema fact source 会对声明这些失败码的 command / subcommand 自动补齐 `triton plan --format json`，并保持 `nextCommands[]` 去重与 `recoveryCommands[]` 镜像。

`triton plan` 的每个 `steps[]` 必须有非空 `id`、`title`、`command`、`when`、`expected`，同一个 plan 内 step id 不能重复，并且 `command` 必须是 schema-backed `triton ...` 命令。plan 不能再输出“open the app...”这类自然语言动作；该约束由 `SchemaFactSourceTests.workflowPlanStepsExposeExecutableMetadata` 锁定。

`triton plan` 顶层 `nextStep` 必须指向当前响应中的某个 `steps[].id`。agent 可以直接用 `nextStep` 定位下一条要执行的 step，不需要做自然语言推断或兜底遍历；该约束由 `SchemaFactSourceTests.workflowPlanNextStepPointsToAnEmittedStep` 锁定。

## Capabilities 契约

`triton capabilities --json` 是环境能力事实源。它回答当前机器、当前工作区、当前 server 和当前 target 能做什么。

能力矩阵至少分组：

1. `cli`：CLI 版本、schema version、默认 host/port。
2. `server`：服务可达性、端口、endpoint、pid。
3. `hostTools`：`xcrun`、`xcodebuild`、`hdc`、DevEco Emulator、必要系统工具。
4. `targets`：可发现 target 数量、ready target、默认 target、歧义状态。
5. `runtime`：embedded runtime 是否连接、manifest、transport、payload limits、redaction policy。
6. `project`：workspace/project/Package.swift/scheme/defaults。
7. `webview`：候选发现、provider URL metadata、snapshot、bridge allowlist、events buffer。
8. `evidence`：capture、inspect、summary、redact、artifact 输出能力。
9. `replay`：record、plan inspect、dry-run、replay steps。

每个 capability 项必须包含：

1. `name`：稳定能力标识，例如 `target-list`、`runtime-manifest`、`xcode-run`、`tap`。
2. `supported`：当前环境是否可执行。
3. `reason`：不可用原因。
4. `group`：agent-facing 信息域，例如 `target`、`runtime`、`xcode`、`observe`、`action`、`assert`、`evidence`。
5. `requiredBy[]`：哪些 workflow 或命令族依赖它。
6. `nextAction`：建议恢复或执行命令，使用 `{command,args,category,requiresLongRunningProcess,readyEvents,finalEvents,terminationSignals}` 结构。
7. `evidence[]`：判断依据或可审计输出面，例如 server response、manifest field、target source、evidence bundle。

WebView 能力必须拆分为两层：`webview-list` / `webview-current` 只表示可发现可见 Web 容器候选，证据来自 host layout 或 runtime AX；`webview-current-url`、`webview-snapshot`、`webview-bridge-call`、`webview-events`、`webview-wait` 与 `route-current-url-assert` 表示 provider 级能力，必须依赖 embedded runtime 或 `--runtime-base-url` 暴露的 WebView provider。没有 provider 时，agent 只能把结果当候选证据，不能宣称 DOM、URL、JS 或 bridge 可用。

Evidence / replay 能力也必须同名对齐：`evidence`、`evidence-summary`、`evidence-redact`、`capture`、`record`、`plan-inspect`、`replay`、`replay-dry-run`、`smoke-ios`、`smoke-harmony` 都应能通过 capabilities 发现。`plan-inspect` 和 `replay-dry-run` 不依赖 server 或 runtime；前者用于离线读取 `.tritonplan` 摘要和 step 执行元数据，后者用于变量替换与静态 validation。真实 `replay` 仍可能依赖目标和运行时；`smoke-*` 是编排能力，最终 pass/fail 仍以 wait/assert/evidence 结果为准。

所有 schema 暴露的 `providedCapabilities[]` 都必须能在 `triton capabilities --json` 中发现，并且不能只是一个孤立能力名。新增 schema 能力时必须同步 capabilities matrix、`group`、`requiredBy`、`nextAction` 和 `evidence`；对 agent 来说，`group` 用于归入信息域，`nextAction` 用于继续执行或恢复，`evidence` 用于判断该能力可由哪些输出面证明。该约束由 `SchemaFactSourceTests.schemaProvidedCapabilitiesAreDiscoverableInCapabilitiesMatrix` 和 `SchemaFactSourceTests.schemaProvidedCapabilitiesExposePlanningMetadata` 共同锁定。

能力名是 agent 建索引的 key，必须唯一。单个 command 的 `providedCapabilities[]` 不能重复，`runtimeCapabilities(...)` 输出的 capabilities matrix 也不能重复能力名；该约束由 `SchemaFactSourceTests.capabilityNamesRemainUniqueForAgentIndexing` 锁定。

能力元数据数组必须保持可索引：`capabilities[].requiredBy` 与 `capabilities[].evidence` 不能包含空字符串，也不能在同一能力内重复。该约束由 `SchemaFactSourceTests.capabilityPlanningArraysExposeNonemptyUniqueValues` 锁定。

能力分组必须落在固定 agent taxonomy：`action`、`assert`、`bootstrap`、`evidence`、`host`、`observe`、`replay`、`route`、`runtime`、`smoke`、`target`、`webview`、`xcode`。新增能力时不能临时创造近义分组或回退到 `misc`；确实需要新分组时，必须同步更新 taxonomy、文档、skills 和测试。该约束由 `SchemaFactSourceTests.capabilityGroupsStayWithinTheAgentTaxonomy` 锁定。

`capabilities[].requiredBy` 也必须落在固定 workflow taxonomy：`action`、`app`、`assert`、`evidence`、`observe`、`project`、`replay`、`route`、`runtime`、`smoke`、`target`、`webview-check`、`xcode`。新增 workflow 分类不能直接写入能力矩阵；必须先定义它对 agent 规划的含义，并同步文档、skills 和测试。该约束由 `SchemaFactSourceTests.capabilityRequiredByValuesStayWithinTheWorkflowTaxonomy` 锁定。

`capabilities[].evidence` 必须落在固定 artifact taxonomy。当前允许的证据面包括 stdout/schema/status、host target/artifact、runtime manifest/snapshot/AX/ledger、WebView provider/route/assertion、input/action result、evidence bundle、smoke summary、tritonplan、Xcode/xcresult/trace/coverage 和 unsupported envelope。新增 evidence 名称时必须说明它是可审计 artifact、运行时采样、host 工具输出还是恢复诊断，并同步测试；该约束由 `SchemaFactSourceTests.capabilityEvidenceValuesStayWithinTheArtifactTaxonomy` 锁定。

所有 capability 都必须至少暴露一个 evidence source。即使能力只是诊断、selector、unsupported 或 schema discovery，也要说明 agent 可以用 stdout JSON、schema、status、host artifact、runtime snapshot、unsupported envelope 等哪个证据面验证该能力；该约束由 `SchemaFactSourceTests.capabilitiesExposeAtLeastOneEvidenceSource` 锁定。

`capabilities[].nextAction` 与 task `plan.steps[].argv` 一样必须能回到 schema 解释。所有 `nextAction.command` 必须存在于 `commandSchemas()`，子命令和 `--flag` 必须由对应 command schema 声明；该约束由 `SchemaFactSourceTests.capabilityNextActionsStayAlignedWithCommandSchemas` 锁定。

`capabilities[].nextAction.requiresLongRunningProcess` 只能用于明确需要 agent 启动并等待或保持的恢复动作。当前 capabilities matrix 中只允许 server 不可达时的 `serve --host 127.0.0.1 --port 19421` 标记为 long-running；其他 plan、status、schema、target、observe、action、evidence 建议必须保持普通一次性命令。该约束由 `SchemaFactSourceTests.capabilityLongRunningNextActionsStayExplicit` 锁定。

`capabilities[].nextAction.args` 中的占位符必须是完整 argv token，形如 `<selector>`、`<text>`、`<dir.tritonevidence>`、`<x,y>` 或 `<udid|booted>`。不能出现 `prefix-<value>`、`<value>-suffix`、不闭合尖括号或多个占位符拼在同一 token 的形式；该约束由 `SchemaFactSourceTests.capabilityNextActionPlaceholdersAreCompleteArgvTokens` 锁定。

`schema.nextCommands[]`、`schema.examples[]` 与 `plan.steps[].argv` 中的占位符也必须使用完整 argv token。已将 `triton device use sim:<udid> --json` 改为 `triton device use <sim-target-id> --json`，并将通用 plan 的 `input` step 从 shell 重定向改为纯 Triton argv，stdin 语义放入 `expected`；该约束由 `SchemaFactSourceTests.schemaAndPlanPlaceholdersAreCompleteArgvTokens` 锁定。

`plan.steps[].command` 仍必须是单条 `triton ...` 人读调用，不能包含 shell control operators、重定向、管道、命令替换或反引号。真正给 agent 执行的是同一步的 `argv[]`；如果某一步需要 stdin、文件或外部上下文，应放在 `expected` / `when` / 后续契约字段中说明，而不是把 shell 脚本塞进 `command` 或 `argv`；该约束由 `SchemaFactSourceTests.workflowPlanCommandsStaySingleTritonInvocations` 锁定。

## Doctor 契约

`doctor` 面向恢复路径，不只展示状态。输出至少包含：

1. `checks[]`：诊断项。
2. `nextWorkflows[]`：当前第一条可恢复检查直接影响的 workflow taxonomy。
3. `status`：`pass`、`warn`、`fail`、`skipped`。
4. `code`：机器可读诊断码。
5. `message`：人读说明。
6. `hint`：短恢复提示。
7. `nextCommand`：可执行 argv 数组。
8. `relatedCapabilities[]`：关联 capability id。
9. `workflowCategories[]`：由关联 capability 的 `requiredBy[]` 推导出的 workflow taxonomy。

`doctor` 在 server 不可达时仍应输出 JSON 诊断，并优先给出启动 server、查看 schema、列 target 的恢复命令。

`doctor` 不应要求 agent 再把 `checks[].relatedCapabilities` 与 `capabilities[].requiredBy` 手动关联一次，才能判断当前阻塞的是 `app`、`observe`、`action`、`assert`、`evidence`、`smoke` 还是 `xcode/project` 流程。因此 `checks[].workflowCategories[]` 必须直接暴露由 capability matrix 推导出的 workflow taxonomy，顶层 `nextWorkflows[]` 则固定指向第一条 `fail/warn` check 的 workflow 分类。agent 可以先读 `doctor` 决定恢复链路，再按需下钻 `capabilities` 读取完整能力矩阵；该约束由 `SchemaFactSourceTests.doctorResponseExposesOrderedRecoveryChecks` 与 `SchemaFactSourceTests.agentBootstrapSchemasExposeRecoveryCommandsAndOutputContracts` 锁定。

## Observe / Action / Assert 分层

### Observe

Observe 负责读取，不改变被测 App 或 host 状态。目标形态：

```text
triton observe current --json
triton observe tree --json
triton observe webview --json
triton observe screenshot --output <path> --json
```

Observe 输出必须能说明 freshness、target、source、truncation、skipped reason 和 artifact path。除了完整 `sources[]`，`observe.surface` 还应直接暴露 `primarySource`，把 agent 当前应优先信任的事实源提到顶层，避免调用方把数组顺序误当成优先级。当前 observe 语义里，优先级固定为 `runtime-tree`、`host-layout`、`webview-provider`；若三者都不可用，再保守回退到首个 source。

WebView / route 属于 Observe 读面，但要保留 provider 边界：`webview list/current` 用来发现候选；`webview current-url/snapshot/call/events/wait` 和 `route assert-current-url` 只能证明 provider 明确暴露的 URL、DOM/text snapshot、allowlist bridge 或页面事件。`webview.list` 与 `webview.current` 输出也必须直接暴露 `primarySource`，但 WebView 语义的优先级与 observe surface 不同：先取可用的 `webview-provider`，再取 `runtime-tree`，最后取 `host-layout`；三者都不可用时回退到首个 source。这样 agent 可以一跳判断当前 WebView 结果是 provider 级事实、runtime AX 候选，还是 host layout 候选。Harmony host layout 只能提供 Web 候选和坐标，不等于 DOM/JS/bridge。

`webview` schema 的 output contract 必须覆盖候选层与 provider 层：`webview.list`、`webview.current`、`webview.current-url`、`webview.snapshot`、`webview.call`、`webview.events`、`webview.wait`。其中 `current-url/call/events` 是 provider 级解析入口，agent 应优先按 contract 的 `selector/kind/model/fields[]` 建立解析器，而不是从 `successShape` 文本里抽字段。

### Action

Action 负责执行。目标形态：

```text
triton action find "Login" --json
triton action tap "Login" --json
triton action type "alice" --json
triton action paste "<secret>" --secure --json
triton action input --summary --strict < actions.ndjson
```

Action 输出必须包含 strategy、resolved target、elapsed、redaction 和失败时的 nearest candidates / suggested commands。embedded runtime 动作使用 `input.result`；Harmony host-side 动作、等待与 artifact 输出必须有独立 output contract，例如 `host.harmony-tap`、`host.harmony-swipe`、`host.harmony-text-input`、`host.harmony-wait`、`host.harmony-artifact`、`host.harmony-key-action`，让 agent 不需要从 `successShape` prose 判断 host JSON 字段。`capabilities[].nextAction` 中的 action 命令必须与当前 schema 可执行参数保持一致，例如 `swipe --start-x/--start-y/--end-x/--end-y`、`clear --at x,y`、`input --json --summary --strict`；unsupported 的 embedded `press` 必须给出 schema/诊断入口，而不是伪装成可执行设备级 HID。`clear --platform harmony` 当前属于显式 unsupported：capabilities matrix 以 `harmony-clear-text` 暴露该边界（`supported=false`），next action 固定指向 `triton clear --platform harmony --json`，用于产出稳定 unsupported envelope，而不是让 agent 把通用 `clear` 误判成 Harmony 可执行动作。该 next action 不能被 server 不可达状态覆盖为 `serve`，因为 Harmony clear 的 unsupported 边界是 host-side 语义，不依赖 runtime 连接。Action contract 测试还会显式封住 legacy selector（`host.tap`、`host.swipe`、`host.text-input`、`host.wait`），保证 host-harmony 命名不会回退到泛化 selector。

`harmony-tap-text`、`harmony-wait-text`、`harmony-swipe`、`harmony-type-text`、`harmony-paste-text`、`harmony-press-key` 在 capabilities matrix 中也按 `action` 分组暴露，并使用 `requiredBy=action/assert/evidence`。它们是 host-side action 能力，不再归类到 `host target/app` workflow，避免 agent 规划时把动作能力误识别为设备准备步骤。

### Assert

Assert 负责给出 pass/fail，不承担证据归档。目标形态：

```text
triton assert text-exists "Home" --json
triton assert text-not-exists "Qinghai" --within 180,120,190,500 --json
triton assert route "app://home" --json
triton assert webview-url "https://example.invalid/home" --json
```

Assert 失败时必须返回 `status=fail`、expected/actual、nearest evidence 和 evidence 下一步命令。

## Evidence / Replay 契约

Evidence 负责审计材料，Replay 负责可复跑流程。

标准链路：

```text
triton evidence capture --case <case> --output <dir.tritonevidence> --json
triton evidence inspect <dir.tritonevidence> --json
triton evidence summarize <dir.tritonevidence> --json
triton evidence redact <dir.tritonevidence> --output <redacted.tritonevidence> --json
triton record --output <file.tritonplan> --json
triton replay <file.tritonplan> --dry-run --json
triton replay <file.tritonplan> --json
```

证据包必须包含 manifest、artifact 相对路径、target identity、CLI version、schema version、redaction profile、skipped reason 和 replay hint。除了完整 `artifacts[]`，`TKEvidenceManifest`、`TKEvidenceSummaryResponse` 和 `TKEvidenceRedactionResponse` 还必须直接暴露 `primaryArtifacts[]`，把 agent 首先该看的高信号产物排序好；同时暴露单值 `primaryArtifact`，让 agent 在只需要“一跳首看对象”时不必再自己取 `primaryArtifacts[0]`。首期优先级固定为 `xcode.action-summary`、`screenshot`、`archive/geometry/ax/hierarchy`、`run.events`、`run.meta`、`status/list/version`、`host.*`、`xcode.*`；agent 不应再从 `artifacts[].kind` 自己重建“先看哪几个 artifact”的规则。

## Error Envelope

所有 JSON 模式下的失败输出统一为单个合法 JSON 对象：

```json
{
  "ok": false,
  "error": {
    "code": "ambiguous_target",
    "message": "Multiple targets matched selector.",
    "hint": "Use target resolve with a narrower platform or explicit id.",
    "nextAction": {
      "command": "target resolve",
      "args": ["booted", "--platform", "ios", "--json"]
    }
  }
}
```

要求：

1. 不把已有 Triton error envelope 二次包装。
2. `code` 必须出现在对应 command schema 的 `failureCodes[]`。
3. `nextAction` 不依赖自然语言解析。
4. 本地参数校验、HTTP 非 2xx、runtime provider error、host tool error 都必须收敛为同一类 envelope。

## 破坏性更新策略

本项目不为旧命令面单独维护长期包袱。破坏性更新可以发生，但每次必须同时完成：

1. 命令实现调整。
2. `triton schema` 更新。
3. 对应测试更新或删除旧契约测试。
4. README 更新。
5. public skills 更新。
6. dev 文档与 space checkpoint 更新。
7. memory 写回与 文档门禁。

不允许出现“命令已改、schema 仍旧”或“schema 已改、skills 仍教 agent 旧路径”的状态。

## BDD 验收

### 场景一：新 agent 自发现 CLI

- Given agent 只知道 `triton` 可执行文件
- When 它执行 `version`、`schema`、`doctor`、`capabilities`、`plan`
- Then 它能得到当前命令事实、环境能力、诊断恢复和下一步计划

### 场景二：target 消歧

- Given 同时存在多个 simulator、emulator 或 runtime target
- When agent 执行 `target list` 和 `target resolve`
- Then 输出包含候选、歧义原因和可继续使用的 selector

### 场景三：失败可恢复

- Given server 不可达、target 多匹配、runtime 未连接或断言失败
- When 任一 agent-facing 命令以 JSON 模式失败
- Then 输出是单个 error envelope
- And `error.code` 在 schema 中可发现
- And `nextAction` 可转成下一条命令

### 场景四：任务可规划

- Given agent 想执行 iOS smoke、open-url 或 webview-check
- When 它执行 `triton plan <task> --json`
- Then 输出有序 `goal/nextStep/steps[]`，后续继续细化 commands、requires、expectedArtifacts 和 stopConditions
- And plan 不直接执行动作

### 场景五：回归可审计

- Given 一次 smoke 结束或失败
- When agent 执行 evidence capture / summarize / redact
- Then 产物包含 manifest、artifact、skipped、target、schema version 和 redaction 信息
- And replay 能 dry-run 验证变量与步骤

## 后续切片映射

1. Round 08：建立 `target` 一等入口，迁移目标选择逻辑。
2. Round 09：升级 `capabilities` 为环境能力矩阵。
3. Round 10：升级 `plan` 为任务型建议入口，先覆盖 `ios-smoke`、`open-url`、`webview-check`。
4. Round 11：升级 `doctor` 为恢复路径建议。
5. Round 12：整理 `action` 层。
6. Round 13：整理 `observe` / `webview` / `route` 层，已补齐 schema 与 capabilities 的 WebView / route 能力对齐。
7. Round 14：整理 `assert` / `evidence` / `replay` 闭环，已补齐 evidence、smoke 与 replay dry-run 的 schema / capabilities 对齐。
8. Round 15：建立 schema `providedCapabilities` 与 capabilities matrix 的全局不变量。
9. Round 16：建立 `schema --command <name>` 覆盖完整命令 inventory 的过滤不变量。
10. Round 17：建立 schema capability 的 planning metadata 不变量。
11. Round 18：建立任务型 plan command 与 schema 参数形态对齐不变量。
12. Round 19：建立 capabilities `nextAction` 与 schema 参数形态对齐不变量。
13. Round 20：建立 schema `nextCommands[]` 与 schema 参数形态对齐不变量。
14. Round 21：抽取 schema-backed command 校验 helper，统一 plan / capabilities / nextCommands 三类不变量。
15. Round 22：建立 capability command 必须声明 `outputContracts[]` 的不变量。
16. Round 23：建立 `outputContracts[]` selector / model / fields 字段质量不变量。
17. Round 24：建立失败面必须声明稳定 `failureCodes[]` 的不变量。
18. Round 25：建立子命令 failure codes 必须被父命令覆盖的不变量。
19. Round 26：建立 option / subcommand 最低元数据质量不变量。
20. Round 27：建立 outputFormats / examples 最低质量与 schema-backed 示例不变量。
21. Round 28：建立 plan step 元数据完整性与 schema-backed command 不变量。
22. Round 29：建立 plan `nextStep` 必须指向 `steps[].id` 的不变量。
23. Round 30：建立 schema / capabilities matrix 能力名唯一性不变量。
24. Round 31：建立 capability `requiredBy` / `evidence` 数组质量不变量。
25. Round 32：建立 capability `group` 固定 taxonomy 不变量。
26. Round 33：建立 capability `requiredBy` 固定 workflow taxonomy 不变量。
27. Round 34：建立 capability `evidence` 固定 artifact taxonomy 不变量。
28. Round 35：建立所有 capability 必须暴露非空 evidence source 的不变量。
29. Round 36：建立 capability `nextAction.requiresLongRunningProcess` 显式语义不变量。
30. Round 37：建立 capability `nextAction.args` 占位符必须为完整 argv token 的不变量。
31. Round 38：建立 schema nextCommands/examples 与 plan steps 占位符必须为完整 argv token 的不变量。
32. Round 39：建立 plan step command 必须为单条 Triton invocation 的不变量。
33. Round 40：抽取 workflow plan fixtures，统一 plan 不变量测试输入。
34. Round 41：抽取 capabilities 三态 fixtures，统一 server/runtime 状态矩阵。
35. Round 42：抽取 connected capabilities fixtures，统一 connected-only capabilities 不变量测试输入。
36. Round 43：抽取 schema-backed command 测试 helper，统一 schema map 与 issue 断言。
37. Round 44：建立同一 command 内 `outputContracts[].selector` 必须唯一的不变量。
38. Round 45：建立 subcommand `outputSelectors[]` 必须被父命令 `outputContracts[]` 覆盖的不变量。
39. Round 46：建立 subcommand `nextCommands[]` 必须与 schema 命令/子命令/参数对齐的不变量。
40. Round 47：抽取 command string fixtures，统一 schema / subcommand / plan 命令字符串来源。
41. Round 48：建立 schema 与 subcommand `nextCommands[]` 必须为单条 Triton invocation 的不变量。
42. Round 49：建立 schema `examples[]` 必须恰好包含一个 Triton invocation 的不变量。
43. Round 50：建立 `outputContracts[].format` 必须落在 `json` / `jsonl` / `archive` taxonomy 的不变量。
44. Round 51：建立 `outputContracts[].kind` 必须落在固定 agent taxonomy 的不变量。
45. Round 52：建立命令级 `outputFormats[]` 必须落在固定 command taxonomy 且无重复的不变量。
46. Round 53：建立 output contract field `type` 必须符合机器可读类型语法的不变量。
47. Round 54：抽取 schema taxonomy helpers，统一 capability / output contract / command output format 固定集合。
48. Round 55：建立 output contract `model` 必须符合机器可读类型语法的不变量，并收敛两个低信号模型名。
49. Round 56：建立 output contract `selector` / `kind` 必须使用稳定 agent key 命名的不变量。
50. Round 57：建立 command / subcommand `failureCodes[]` 必须使用稳定 lower_snake_case 且不重复的不变量。
51. Round 58：建立 command / subcommand 名称与纯长 flag / alias 组必须使用稳定 CLI key 的不变量，并记录 `options[].name` 混用 usage synopsis 的后续治理点。
52. Round 59：新增 `usageForms[]` wire 字段，将 Subcommand / Task synopsis 从 `options[]` 自动分离，并更新相关测试消费新字段。
53. Round 60：新增 `argumentForms[]` wire 字段，将 positional argument 从 `options[]` 自动分离，并把 `options[]` 收紧为纯长 flag / alias 组。
54. Round 61：建立 subcommand 参数引用覆盖不变量，要求 `requiredOptions[]` / `optionalOptions[]` / `oneOfRequiredOptions[]` 只能引用父 schema 可发现的 `options[]` 或 `argumentForms[]`。
55. Round 62：建立命令级 `requiredOptions[]` 直接调用语义不变量；有 `subcommands[]` 的父命令不得再聚合子命令人读 requirement 摘要。
56. Round 63：建立 `defaultProviders[]` / `inheritsDefaultsFrom[]` 必须是 schema-backed Triton 命令的不变量。
57. Round 64：建立命令级与子命令级 `artifacts[]` 固定 taxonomy 与去重不变量。
58. Round 65：建立 `jsonlEvents[]` / `finalEventKind` 稳定 event key、final 覆盖与命令级 `jsonl` 输出格式不变量。
59. Round 66：建立 `retryable=true` 必须暴露恢复 `nextCommands[]` 的不变量，并补齐 Xcode / xctrace / coverage 可重试面的恢复建议。
60. Round 67：建立 `failureCodes[]` 必须能导向恢复 `nextCommands[]` 的不变量，并补齐 `serve`、`ax` 与动作命令的恢复建议。
61. Round 68：建立命令级与子命令级 `nextCommands[]` 不得为空项或重复项的不变量。
62. Round 69：建立命令级与子命令级 `nextCommands[]` 根命令必须落在固定 recovery command taxonomy 的不变量。
63. Round 70：建立 recovery root command 必须映射到稳定 category taxonomy 的不变量。
64. Round 71：新增 schema wire 字段 `recoveryCommands[]`，自动从 `nextCommands[]` 派生 `{command, category}`。
65. Round 72：建立 `failureCodes[]` 到 recovery category family 的分类不变量，先保证错误码可被 agent 映射到恢复阶段。
66. Round 73：建立 artifact / output failure codes 必须暴露 `archive` 类恢复入口的不变量，并补齐 `sim` 与 `record` 的 evidence 建议。
67. Round 74：建立 assertion / route / text-not-found failure codes 必须暴露 `verify` 类恢复入口的不变量。
68. Round 75：建立 server / runtime transport failure codes 必须暴露 `diagnose` 类恢复入口的不变量。
69. Round 76：建立 target failure codes 必须暴露 `prepare-target` 类恢复入口的不变量，并在 schema fact source 层自动补齐 target resolver 建议。
70. Round 112：收紧 replay 真实执行的 failureCode 透传链路，优先保留 runtime/target/transport 原始错误码，只在未知异常时回落到 `step_failed`。
71. Round 113：为 `TKReplayStepResult` 增加结构化 `error`，让 replay 失败后可直接读取 step 级 `TKCLIErrorDetail`，不再只剩 `failureCode + message`。
72. Round 114：为 replay 的非抛错失败步骤补 step 级 `error`，先覆盖 `wait`、`input`、`evidence` 三类 `ok=false` 结果。
73. Round 115：为 `TKReplayResult` 增加顶层 `failureError`，把失败 step 的结构化错误直接提升为顶层事实字段。
74. Round 116：把 `steps[].error` 的嵌套字段展开进 replay output contract，保持 top-level / step-level error surface 一致。
70. Round 77：建立 Project / Xcode failure codes 必须暴露 `project` 类恢复入口的不变量，并在 schema fact source 层自动补齐 Xcode discover 建议。
71. Round 78：建立 action / step failure codes 必须暴露 `act` 类恢复入口的不变量，并在 schema fact source 层自动补齐批量动作入口建议。
72. Round 79：建立 destructive / confirmation failure codes 必须暴露 `plan` 类恢复入口的不变量，并在 schema fact source 层自动补齐规划入口建议。
73. Round 80：建立 unsupported failure codes 必须暴露 `plan` 类恢复入口的不变量，并在 schema fact source 层自动补齐规划入口建议。
74. Round 81：为 `plan.steps[]` 新增 `category` wire 字段，自动按 command root 派生稳定 recovery category，并在 plan output contract 中声明该字段。
75. Round 82：为 `capabilities[].nextAction` 新增 `category` wire 字段，自动按 nextAction command root 派生稳定 recovery category，并在 capabilities output contract 中声明该字段。
76. Round 83：在 `doctor` output contract 中显式声明 `checks[].nextAction.category`，并用测试固定 doctor recovery check 的 category 可读性。
77. Round 84：统一错误 envelope 的 nextAction category 契约；`failureShape` 中的 `nextAction?` 自动展开为包含 `category` 的结构，`TKCLIErrorDetail?` output contract 自动声明 `error.nextAction.category`。
78. Round 85：为 `plan.steps[]` 新增结构化执行元数据 `requires[]`、`expectedArtifacts[]` 与 `stopConditions[]`，并在 plan output contract 中声明这些字段。
79. Round 131：把 output contract 里的 `TKCLINextAction?` 收敛成通用 schema 展开规则；`capabilities[].nextAction`、`doctor.checks[].nextAction`、`failurePrimaryNextAction` 以及 replay `failureError/steps[].error.nextAction` 现在都会自动暴露 `command/args/category/requiresLongRunningProcess/readyEvents/finalEvents/terminationSignals`，减少 agent 回到 DTO 定义猜 nextAction 结构或从 argv 反推长驻生命周期。
80. Round 132：为 bootstrap 三个事实源补顶层首选入口；`doctor.primaryNextAction`、`capabilities.primaryCapability` / `primaryNextAction` 和 `plan.primaryNextAction` 现在直接给出 agent 首先该尝试的结构化命令，减少为“先跑哪条命令”再扫 `checks[]`、`capabilities[]` 或 `steps[]`。
81. Round 133：为 bootstrap 顶层首选入口补 provenance 与首选 lane；`doctor/plan.primaryNextActionSource`、`capabilities.primaryNextActionSource` 和 `capabilities.primaryWorkflowCategory` 现在直接解释这条首选命令是从哪条规则、哪类能力或哪条兼容回填路径得出的，减少 agent 再扫数组或倒推回填来源。
82. Round 134：继续收紧 `doctor` 的 bootstrap 诊断入口；新增 `doctor.primaryCapability`，让 agent 不再必须扫描 `checks[].relatedCapabilities[]` 才能知道当前 recovery check 首先对应哪项 capability。该字段默认取 `nextStep` 对应 check 的首个 `relatedCapabilities[]`，若回退到首条 fail/warn check 或 `error.nextAction`，也沿同一保守路径回填。
83. Round 135：继续收紧 `doctor` 的顶层 workflow lane；新增 `doctor.primaryWorkflowCategory`，让 agent 不再需要从 `nextWorkflows[]` 或 `checks[].workflowCategories[]` 自己选“首条 lane”。该字段从当前 primary check 的 workflow 集合中按固定 canonical 优先级挑出单值 lane，而不是直接镜像原始数组首项。
84. Round 136：继续收紧 `capabilities` 的 evidence 入口；新增 `capabilities.primaryEvidence`，让 agent 不再需要先拿到 `primaryCapability`，再回扫对应 `evidence[]` 才知道先看哪类 artifact taxonomy。该字段默认取 `primaryCapability` 对应 capability 的首个 `evidence[]`，不表达真实文件路径，只表达高信号 artifact 类型。
85. Round 137：继续收紧 `plan` 的顶层 workflow lane；新增 `plan.primaryWorkflowCategory`，让 agent 不再需要从 `nextWorkflows[]` 或 `steps[].workflowCategories[]` 自己选“首条 lane”。该字段从 `nextStep` 对应 step 的 workflow 集合里按固定 canonical 优先级挑出单值 lane，并在 default-next-step 兼容回填路径上沿 `nextWorkflows[]` 走同一规则。
86. Round 138：继续收紧 `plan` 的 artifact 入口；新增 `plan.primaryExpectedArtifact`，让 agent 不再需要从 `nextStep` 对应 step 的 `expectedArtifacts[]` 自己挑“首看哪类计划产物 taxonomy”。该字段默认取当前 primary step 的首个 `expectedArtifacts[]`，只表达 artifact 类型，不表达真实文件路径。
79. Round 86：为 `plan.steps[]` 新增 `argv[]` wire 字段，agent 可直接执行 argv，不再需要解析 shell 字符串。
80. Round 87：为 `triton plan inspect` 的 `TKReplayPlanSummary.steps[]` 新增 replay step 执行元数据，并在 `plan.inspect` output contract 中声明该字段口径。
81. Round 88：为 `TKReplayStepResult` 新增 `category/requires/expectedArtifacts/stopConditions`，并在 `replay.result` output contract 中声明 replay dry-run / execution step metadata。
82. Round 89：为 `TKReplayStepResult` 新增 `argv[]` alias，replay dry-run / execution step result 与 `plan inspect` 和 task plan 一样提供首选 argv 执行字段。
83. Round 90：抽取 `TKReplayStepExecution` 共享 helper，统一 `plan inspect` summary、replay dry-run 和真实 replay result 的 argv / metadata 派生事实源。
84. Round 91：补强 `TKReplayStepExecution` 静态验证，dry-run 提前拒绝 ambiguous tap selector、ambiguous wait condition、缺失 paste/type text 与缺失 wait condition。
85. Round 92：新增进程级 `replay --dry-run --json` invalid plan 测试，锁定静态 validation failure 只输出单个 JSON error envelope。
86. Round 93：把 `triton plan inspect <file.tritonplan> --json` 暴露为 `plan-inspect` 一等 capability；schema `plan.providedCapabilities[]` 与 capabilities matrix 同步，`nextAction` 指向 `plan inspect`，`group=replay`，evidence 为 `tritonplan` 与 `stdout-json`。
87. Round 95：为 `TKReplayPlanSummary.steps[]` 新增 `validationErrors[]`，让 `plan inspect` 离线暴露 ambiguous selector、缺失 text/condition、坐标不完整等 step 形状诊断，同时保持变量占位不求值；修正 `failedStepIndex` contract 为 1-based。
88. Round 154：收敛 `route-current-url-assert` 的 capability server 依赖语义；当 server 不可达或 target 未连接时，capability nextAction 不再退化为 `serve`/`status`，统一保持 `route assert-current-url`，与 `route` schema 的 `requiresServer=false` 契约对齐。
89. Round 155：收敛 WebView provider capabilities（`webview-current-url/snapshot/bridge-call/events/wait`）的 server 依赖语义；当 server 不可达或 runtime 未连接时，nextAction 保持命令级入口，不再退化为 `serve`/`status`，与 `--runtime-base-url` 的直接执行边界保持一致。
90. Round 156：收敛 `observe-ios` 的 server 依赖语义；当 server 不可达或 runtime 未连接时，nextAction 保持 `observe current --platform ios --json`，不再退化为 `serve`/`status`，与 observe runtime-base-url 直连路径对齐。
91. Round 157：新增 discovery 能力批量回归门禁，锁定 `observe-ios`、`webview-list`、`webview-current`、`node-resolve` 在 runtime-disconnected / server-unreachable 两态下保持命令级 nextAction 且非 long-running，防止后续回退到 `serve`/`status`。
92. Round 158：在 discovery 门禁上补 capability 元数据一致性约束；`observe-ios`、`observe-harmony`、`webview-list`、`webview-current`、`node-resolve` 在 runtime-disconnected / server-unreachable 两态下除了 nextAction，还必须保持 `group`、`requiredBy`、`evidence` 的固定契约。
93. Round 159：新增 `observe` / `node` schema-capability 交叉门禁；将 `providedCapabilities` 与 capabilities matrix 的 `group`、`requiredBy`、`evidence`、`supported`、`nextAction` 两态口径直接绑定，并显式锁定 `node` 与 `node-resolve` 在 disconnected 态的不同恢复路径。
94. Round 160：对 `SchemaFactSourceTests` 的 capability cross-check 门禁做结构化去重；提取 `capabilityMap(state:)`、`disconnectedCapabilityMap()`、`unavailableServerCapabilityMap()`、`assertCapability(...)`，并迁移 `webview/discovery/observe-node` 三组测试到共享 helper，在不改变断言语义的前提下降低后续扩展成本。
95. Round 161：新增 `webview` / `route` schema-capability 交叉门禁；固定 `webview.providedCapabilities` 与 `route.providedCapabilities` 的声明，并对对应能力在 connected/disconnected 两态做 `group/requiredBy/evidence/supported/nextAction` 一致性校验，避免 WebView 子能力新增时发生 schema 与 matrix 单侧漂移。
96. Round 162：把 `schema.providedCapabilities` 的一致性门禁升级到三态 capability matrix（connected/disconnected/server-unreachable）；新增全量断言要求每个 schema capability 在三态都存在，且 `group`、`requiredBy`、`evidence` 保持一致，防止 disconnected/server fallback 分支产生静默 metadata 漂移。
97. Round 163：继续把 `schema.providedCapabilities` 的三态门禁扩展到 nextAction 可执行性；新增全量断言要求每个 schema capability 在三态都保留非空 `group/evidence/nextAction`，且 `nextAction.command/args` 必须通过 schema-backed argv 校验，防止 fallback 分支出现“metadata 一致但命令脱离 schema”的回归。
98. Round 164：补齐 capability `supported/reason` 状态机门禁；新增三态断言要求 `supported=true -> reason=nil`、`supported=false -> reason!=nil`，并将 unsupported reason 限定在固定词汇表，同时锁定 `press` 与 `harmony-clear-text` 在三态的恒定 unsupported 边界，避免 fallback 分支 reason 语义漂移。
99. Round 165：把 capability `reason` 与 `nextAction` 的恢复转移关系纳入三态门禁；runtime-reason 能力在 disconnected 若走 `status`，server-unreachable 必须升级 `serve`，若走命令级恢复则保持 connected/disconnected/server-unreachable 一致；webview-provider-reason 能力在 disconnected/server-unreachable 均不得退回 `serve/status`，并保持命令级 nextAction 一致。
100. Round 166：新增 capability reason 文本与 capability family 的双向映射门禁；一方面限制 `reason -> capability` 的合法映射范围，另一方面要求 runtime-family 与 webview-provider-family capability 在三态下满足固定 reason 语义（connected 无 reason，异常态有固定 reason），并锁定 `press` / `harmony-clear-text` 的边界 reason 恒定不变。
101. Round 167：将 reason family 与 `group/requiredBy/evidence` taxonomy 进一步绑定；新增门禁要求 runtime-reason family 不得混入 `webview-check` workflow 或 webview-provider 证据键，webview-provider family 必须绑定 `webview|route` 分组并包含 `webview-provider` 证据，`press`/`harmony-clear-text` 继续锁定 `action` 分组和 `unsupported-envelope+command-schema` 证据集合。
102. Round 168：将 capability `requiredBy` lane 与 `nextAction.category` 做显式对齐门禁；`webview-check` lane 仅允许 `observe|verify`，`xcode/project` lane 仅允许 `project|archive`，`smoke-*` capability 固定 `smoke` 分类，`route` lane 仅允许 `observe|verify`，防止 workflow lane 与恢复分类语义脱节。
103. Round 169：新增 capability `group` 与 `nextAction.command` 根命令一致性门禁；通过 `group -> allowed roots` 限制能力分类与执行入口的耦合关系，并显式纳入 `harmony-ax`（`group=host`，`root=ax`）这类 host-side 特例，避免 taxonomy 漂移或误判。
104. Round 170：新增 `requiredBy` lane 与 `nextAction.args` 占位符语义门禁；`route` 与 `smoke-*` 维持强模板约束，`webview-check` 改为 capability 级精确约束（`route-current-url-assert`/`webview-wait` 需要 URL/text 占位符，`webview-bridge-call` 需要 `<method>`，`webview-current-url`/`webview-snapshot`/`webview-events` 不强制 URL/text），避免 lane 规则过强导致观测型能力误报。
105. Round 171：新增 capability group 维度的 nextAction 机器可读输出门禁；除 `serve` 外，所有 nextAction 都必须显式携带 `--json` / `--jsonl` / `--format json` / `--metadata` 之一，且 `observe` 组 `screenshot` 必须同时保留 `<path.png> + --metadata`，防止恢复路径静默退回人读输出。
106. Round 172：新增 `nextAction --output` 参数契约门禁；所有带 `--output` 的 capability 必须显式声明 artifact-typed 占位符并进入白名单（如 `<file.tritonplan>`、`<path.mov>`、`<path.ndjson>`、`<dir.tritonevidence>`、`<path.png>`），避免输出路径退化为硬编码值或语义不明占位符。
107. Round 173：新增目标选择类参数占位符门禁；`nextAction` 中 `--device/--simulator/--bundle-id` 必须使用 canonical token（`smoke` 的 `--device=<device>`，其他命令 `--device=<selector>`，`--simulator=<udid|booted>`，`--bundle-id=<bundle-id>`），避免同类参数在不同能力中漂移成不可预测文本。
108. Round 174：新增 `nextAction --platform` 参数规范化门禁；`--platform` 只能取 `ios|harmony`，并与 capability family 对齐（`harmony-* -> harmony`，`ios-* / observe-ios -> ios`），防止跨平台恢复命令出现 family 与平台语义错配。
109. Round 175：新增 `nextAction` 文本参数占位符门禁；`--text`、`--wait-text` 与 `assert text-exists` 全部统一为 `<text>`，避免 wait/assert/smoke/webview 路径出现多套文本 token，降低 agent 参数替换分支复杂度。
110. Round 176：按 simulator domain 固化测试门禁入口 `docs-linhay/scripts/verify-simulator-gate.sh`。默认 quick 模式固定覆盖 `SimulatorAdvancedControlsTests`、`DeviceCrossPlatformTests` 以及 selector/platform/text 三条 schema invariants，并补 `verify-ios-runtime-observe-smoke.sh`；full 模式再叠加 `verify-ios-webview-harness.sh`。
111. Round 177：对 simulator gate 补端口自避让；调用 runtime observe smoke 前自动注入随机 `TRITON_IOS_RUNTIME_SMOKE_PORT`，避免连续轮询时固定端口冲突导致的噪声错误输出。
111. Round 177：收敛 simulator gate 稳定性；`verify-simulator-gate.sh` 在执行 iOS runtime observe smoke 前自动注入随机 `TRITON_IOS_RUNTIME_SMOKE_PORT`，降低连续轮询中的固定端口冲突噪声。
110. Round 176：按会话执行要求定义 simulator 测试门禁脚本 `docs-linhay/scripts/verify-simulator-gate.sh`；`quick` 固定跑 simulator domain 的核心测试与三条 schema 门禁，`full` 叠加 iOS runtime observe 与 WebView harness 场景，用于后续轮询提交前的主动校验。
109. Round 175：新增文本参数占位符门禁；`nextAction` 的 `--text`、`--wait-text` 与 `assert text-exists` 必须统一使用 `<text>`，防止同一文本语义在不同命令下漂移成多套 placeholder 命名。

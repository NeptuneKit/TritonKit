# Cruise Audit 20260524 v01

## 背景

本报告记录“自动巡航进化”第一轮 subagent 分工和主控修复结果。

用户目标：

1. 自主发现优化 / 问题。
2. 自主分配 subagent 跟进 / 修复。
3. 自主分配 subagent 提供体验报告。
4. 自主更新文档并整理 skills。

## Subagent 分工

### Sagan：代码审计

任务：只读审计当前 Xcode / xcresult / coverage WIP，重点查找 bug、测试缺口、schema / docs 不一致和可优化点。

主要发现：

1. `coverage report` 通过 `runHostCommand` 读取 stdout 后写 artifact，存在 1MB 截断和 pipe 堵塞风险。
2. `xcresult failures` 对大型 `xcresulttool tests` JSON 同样存在截断风险。
3. `TKXcresultTestNode` 对 `nodeIdentifier` 过严，真实 Xcode schema 只有 `nodeType` 和 `name` 必填。
4. `xcresult` parse error 未映射成稳定错误码。
5. 文档把自动 evidence 整合写得过于接近已完成。
6. `coverage` 参数互斥错误会落到泛化 host error。

### Avicenna：体验报告

任务：只读体验 README、autonomous roadmap、Xcode workflow 文档和 CLI schema 输出，找出 onboarding、命令发现、证据闭环、错误恢复和文档一致性摩擦。

主要发现：

1. README `Choose An Integration Path` 缺少“未知 Apple repo 构建 / 测试 / 运行 / 诊断”的入口。
2. README Xcode 命令块缺少 `triton xcresult summary/failures`。
3. schema 可发现但仍偏 prose，后续可结构化 subcommand contract。
4. Xcode 专用错误恢复决策树缺失。
5. public feedback skill 缺少 Xcode workflow issue 证据模板。

## 主控修复

### 代码

1. `runHostCommand` 改为并发 drain stdout / stderr，避免大输出时子进程 pipe 堵塞。
2. `runHostCommand` 增加 `maximumOutputBytes` 参数，默认保留 1MB sample 约束，并且不把超过上限的 stdout/stderr 全量放进内存。
3. artifact 型 stdout 捕获改为直接流式写入 output file，确保 coverage JSON 完整写入 `--output`。
4. `xcresult summary/failures` 使用 16MB inline JSON 上限，超限返回 `xcresult_output_too_large`，避免未知仓库导致 CLI OOM。
5. `TKXcresultTestNode.nodeIdentifier` 改为 optional，failure record 可在没有 identifier 时继续输出。
6. `xcresult` JSON 解析失败映射为 `xcresult_parse_failed`。
7. `coverage` 参数互斥错误映射为 `validation_failed`。
8. timeout 分支改成 SIGTERM -> 有限等待 -> SIGKILL，并有限等待 stdout/stderr drain，避免返回后后台 reader 悬挂。
9. failed test run 即使没有 failure message / source reference / attachment，也会输出 fallback failure record。

### 测试

新增覆盖：

1. `host artifact capture writes full stdout without truncating the artifact`
2. `xcresult tests parser tolerates nodes without identifiers`
3. `host command drains large stdout while keeping only a bounded sample`
4. `host command timeout terminates process and leaves later commands usable`
5. `xcresult tests parser keeps failed runs without diagnostic children`

验证通过：

```bash
swift test --package-path CLI --scratch-path .build/cli-tests --filter SimulatorAdvancedControlsTests
swift test --filter TKXcodeWorkflowModelsTests
.build/cli-tests/debug/triton schema --command xcresult --json
.build/cli-tests/debug/triton schema --command coverage --json
.build/cli-tests/debug/triton coverage report --xcresult /tmp/missing.xcresult --output /tmp/missing-coverage.json --only-targets --target App --json
```

最后一个命令预期失败，并返回 `error.code=validation_failed`。

### 文档与 skills

1. README 新增未知 Apple repo 的 Xcode agent 入口。
2. README Xcode 命令块补充 `triton xcresult summary/failures`。
3. Xcode workflow README 校正 `xcode test` 与 evidence manifest 的当前实现边界。
4. `tritonkit-xcode-workflow-takeover` internal skill 新增错误恢复表。
5. `tritonkit-dev-feedback` public skill 新增 Xcode workflow issue 证据模板。
6. CLI schema failure shape 补充 `xcresult_parse_failed` 与 `validation_failed`。

## 后续队列

### 已在第二轮解决

1. unbounded subprocess output：普通 host command 使用 bounded sample drain；artifact capture 改为 stdout 流式落盘；`xcresult` inline JSON 增加 16MB 上限和 `xcresult_output_too_large`。
2. timeout cleanup：SIGTERM 后有限等待，必要时 SIGKILL，并有限等待 stdout / stderr drain group。
3. failed run fallback：failed test run 即使没有 diagnostic child，也会输出 fallback failure record。
4. parse error mapping：`xcresult_parse_failed` 通过 `XcresultCLIError.parseFailed` 与 `failHostCommand` 保持稳定错误码。
5. 完整本地门禁：`docs-linhay/scripts/verify.sh --local` 通过，覆盖 111 tests / 17 suites、release CLI build、release CLI smoke、Harmony host smoke、iOS runtime observe smoke、iOS Simulator build、docs structure 和 diff whitespace check。
6. artifact output safety：stdout-backed artifact 捕获默认拒绝覆盖已有文件和符号链接，并通过 `artifact_output_rejected` 暴露稳定错误码。
7. `xcresult summary/failures` 默认 redaction / `--include-sensitive`：默认对 JSON 与 text 输出中的私有路径、邮箱、Bearer/token/password/API-key 片段、长 token-like 字符串、`path` 和 `sourceCommand/sourceCommands` 脱敏；显式 `--include-sensitive` 只用于本机私有调试，不用于公开 issue。
8. Xcode schema structured contract：`xcode`、`xcresult`、`xctrace`、`coverage` schema 新增结构化 agent-planning 字段，覆盖 required options、defaults inheritance、JSONL event templates、final event kind、artifacts、retryable、next commands、output contracts 和 failure codes。

### 继续延期

1. 为更多非 stdout-backed artifact 命令补齐 explicit artifact-dir / force 策略，降低 agent 自动执行时覆盖非预期文件的风险。
2. 将结构化 schema contract 从命令级推进到 subcommand 级，避免用字符串表达 `use:--scheme` 这类复合规则。
3. 实现 `capture/evidence --include xcode,host` 自动 manifest 整合。
4. 为 `xcresult_parse_failed` 增加 CLI 级 fixture / snapshot 测试。
5. 继续补 Xcode test final summary 中的 top failures，但不能把 build/install/launch 当作业务 ready。

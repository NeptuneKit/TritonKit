# SP-138：Xcode 真机 execution destination

## 状态

- 状态：已发布（v0.2.16）；GitHub #170 已关闭，真实 Xcode/真机 smoke 未执行
- Issue：GitHub #170
- Branch：`feat/SP-138-issue-170-xcode-real-device-destination`
- Worktree：`../TritonKit-worktrees/SP-138-issue-170-xcode-real-device-destination/`
- 影响层：CLI Xcode command/runtime/model/schema 与 focused Swift tests

## 问题边界

`triton xcode settings/build/test/run --device <selector>` 必须在任何 `xcodebuild` 前解析一个 ready 的 iOS 真机 target。实际执行只能把该选择结果的私有 `rawTarget` 写入精确 destination：`platform=iOS,id=<rawTarget>`。

公开 JSON、JSONL、invocation、`sourceCommand`、诊断、inline `xcresult`、失败输出和中断后的进程状态不得泄露 raw target；不得用公共 `id`、`target`、名称或 alternate identity 拼装 destination，也不得回退到 generic iOS destination。直接 `platform=iOS` / `iphoneos` 的无 `--device` 调用同样拒绝，不能绕过 ready preflight。

## BDD / DoD

1. 给 `settings`、`build`、`test` 或 `run` 传入 `--device` 时，ready iOS real-target selection 在任何 `xcodebuild` 前完成；missing、ambiguous、platform mismatch 与 not-ready 均不会启动 build。
2. 成功 selection 的唯一执行 argv 包含 `platform=iOS,id=<selection.target.rawTarget>`；不包含 generic fallback、公共 identity 或 alternate identity。
3. 同一调用的 public invocation/summary/source command/JSONL stream sample/diagnostics/inline `xcresult`/中断后 process status 与失败错误均不含 raw target；所有 physical destination 统一以 `<redacted>` 表达。
4. `--device + --destination` 与 `--device + --simulator` 返回 `parameter_conflict`；显式非 iPhoneOS SDK、无 `--device` 的 `iphoneos`（含版本化 `iphoneos18.0`）或 `platform=iOS` destination 返回 `validation_failed`；真实设备 SDK 固定为 `iphoneos`。
5. 四个 Xcode action 对 `target_not_found`、`ambiguous_target`、`target_platform_mismatch`、`device_not_ready` 使用：`triton target resolve <selector> --platform ios --scope real --ready --json`。
6. 只运行 focused unit/CLI tests，不调用真实 Xcode、Simulator、真机、服务或远端 GitHub。

## 范围

允许修改：

- `Sources/TritonKitCLI/CLIXcodeCommands.swift`
- `Sources/TritonKitCLI/CLIXcodeRuntime.swift`
- `Sources/TritonKitCLI/CLIXcodeModels.swift`
- `Sources/TritonKitCLI/CLISchemaXcodeCommands.swift`
- `Sources/TritonKitCLI/CLISchemaRuntime.swift`
- `Sources/TritonKitShared/TKXcodeWorkflowModels.swift`
- 对应 Xcode/shared focused tests，以及本 space、spaces index 与当日 memory。

不在范围：#164、#169、alias/discovery parser public identity 语义、Web/Wails、Android/Harmony、真实 device/Xcode smoke、push/PR/merge/tag/release、删除 worktree 或 branch。

## 实现裁决

- `ResolvedXcodeInvocation` 保存不编码的 execution destination；成功 preflight 后 public `destination` 与 `device` 统一 redaction，而 `TKXcodebuildCommand` 的实际 argv 仍接收 raw destination。
- `settings/build/test/run` 复用同一 preflight；`run` 的 devicectl install/launch command 也标记 raw target argument 为 redacted。
- destination index 通过 `TKHostCommand.redactedArgumentIndexes` 进入 `sourceCommand` 与 JSONL；diagnostics、stream sample、inline `xcresult`、所有 physical process status 和 non-zero/devicectl discovery error result 再做值级清洗。Xcode preflight selection failures 统一使用脱敏的单一 error envelope，不复用会携带 candidates 的通用 envelope；selector recovery 只输出 `<selector>` 占位符，避免用户传入 raw target 时回显。
- `platform=iOS` / `iphoneos`（含严格版本化的 iPhoneOS SDK family）的 direct destination/default SDK 不再允许绕过 `--device`；所有 physical process destination 均结构化 redaction，避免同 workspace 其它 Xcode process 回显其 raw ID 或 physical `name=`。
- devicectl discovery 识别实际 `xcrun devicectl list devices` argv；任何 non-zero public error 的 stdout/stderr 使用统一 marker，不把原始 discovery payload 送进 JSON/JSONL error envelope。
- 任意 public text 的 physical `platform=iOS,name=` 一律 redaction 至行尾；这样不依赖引号或 argv 边界判定，避免名称空格、连字符或 apostrophe 后的尾部泄露，同时不匹配 `platform=iOS Simulator,name=`。
- schema 将 four-action target failure family 与 contextual recovery 对齐；其它 target command 继续保留 generic recovery。

## 验证与风险

- 独立 scratch：`.build/sp138-xcode-real-device-destination-rerun`；不与其它 slice 共享。此前 scratch 被外部清理后已从本机缓存重建，未复用 shared/#164 scratch。
- 已通过（rebase 后）：`swift test --package-path CLI --scratch-path .build/sp138-xcode-real-device-destination-rerun --filter XcodeCommandTests`（35/35）；`swift test --scratch-path .build/sp138-xcode-real-device-destination-rerun/root --skip-build --filter TKXcodeWorkflowModelsTests`（21/21）；同 scratch 的 `TKHostAdapterModelsTests`（38/38）。新增回归覆盖版本化 `iphoneos18.0`、`xcrun devicectl list devices` non-zero 公共 JSON/JSONL envelope、未加引号且带连字符/apostrophe physical `name=` 的 parser/post-action/nonzero error、Simulator name 不误伤与 public redaction 不改 execution argv。上述均为 host fixture / parser tests；未运行真实 Xcode、Simulator、真机或服务。root 的两条 `--skip-build` suite 曾被误并发提交，SwiftPM scratch lock 使实际执行串行、无写入冲突；后续命令保持串行。本轮文档更新后已串行重跑 `git diff --check HEAD`、`check-docs.sh` 与 `verify.sh --ci-docs`，均通过。
- root shared suite 的 `TKHostAdapterModelsTests` 保留既有 devicectl parser 的 sensitive-identifier coverage；本 slice 未修改 parser public identity。
- SP-137 已在 `main@f68587be`，本 worktree 已 rebase；上述收口门禁已通过，不将连号失败作为预期风险。独立复核未发现 P0/P1，主控已批准本地 checkpoint；仍不扩张为真实 Xcode/设备 smoke 结论。

## 停止条件

已完成上述 BDD、focused tests、docs/whitespace 检查及主控 post-diff 复核；本地 checkpoint 已获明确批准。禁止 push、PR、merge、tag、release、关闭 issue、删除或清理 worktree/branch。

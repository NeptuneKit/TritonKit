# SP-139：Xcode focused XCTest selection

## 状态

- 状态：已发布（v0.2.16）；GitHub #169 已关闭，真实 XCTest/xcodebuild 未执行
- Issue：GitHub #169
- Branch：`feat/SP-139-issue-169-xcode-focused-testing`
- Worktree：`../TritonKit-worktrees/SP-139-issue-169-xcode-focused-testing/`
- 基线：`main@5d7ffff0`
- 影响层：CLI Xcode command/runtime/schema、shared Xcode workflow wire contract、agent-facing CLI 文档

## 问题与边界

为 Xcode 测试补充可重复的 focused XCTest selection：

```bash
triton xcode test \
  --only-testing AppTests/LoginTests/testSubmit \
  --only-testing AppTests/SettingsTests \
  --jsonl
```

每个值必须原样保留为独立 `xcodebuild ... test -only-testing:<identifier>` argv；JSON 与 JSONL 的 `sourceCommand` 同样可审计地显示每一项，最终 `TKXcodeActionSummary.onlyTesting` 只在传入选择时出现。

本 slice 不实现 proposed `--skip-testing`，不改变真实 XCTest 名称的语义，不启动 Xcode、Simulator、设备或服务，也不触碰 #164、testrec、Android、Web/Wails 或远端 GitHub 状态。

## BDD / DoD

1. 给 `xcode test` 重复传入两个 `--only-testing <target>/<class-or-method>` 时，输入顺序与重复值均保留；每项是一个独立的 `-only-testing:<identifier>` argv，而不是 build setting 或拼接字符串。
2. 未传该参数时，既有 test argv 与 `sourceCommand` 保持兼容，`onlyTesting` JSON 字段省略。
3. 空白、首尾空白、控制字符或以 `-` 开头的值在解析 runner/xcodebuild 前以单一 `validation_failed` JSON envelope 拒绝；真实 XCTest test-name 语义留给 xcodebuild。
4. CLI help/schema 只把该 option 归入 `xcode test` scope；schema 示例与 `xcode.final` 输出字段说明 focused selection，settings/build/run 不获得 option。
5. focused Swift tests、shared wire-contract tests、schema/help proof 与 docs gate 通过；不运行真实 Xcode、Simulator、真机或 server。

## 实现裁决

- `XcodeTest` 增加 `@Option(name: .customLong("only-testing"))`，并在任何 invocation resolution/runner 前调用 `validateXcodeOnlyTesting`。
- `TKXcodebuildCommand.test` 在 `test` action 后按输入顺序添加 `-only-testing:<identifier>`；没有值时 argv 不变。
- `TKXcodeActionSummary.onlyTesting` 是 optional `[String]`，因此既有 summary 可 decode 且未选择时不会输出 additive 字段。
- schema 使用 `String[]`。公共 `xcode.options` 是 catalog，不能扩大子命令可用范围；实际适用性由各 subcommand 的 `optionalOptions` 决定，且只有 `test.optionalOptions` 含 `--only-testing`。root option/field 文案也明确它只适用于 `xcode test`。

## 验证与风险

- TDD red：新增 CLI test 首次因 `XcodeTest.onlyTesting`、`TKXcodebuildCommand.test(... onlyTesting:)` 与 `validateXcodeOnlyTesting` 缺失而编译失败；随后最小实现转绿。
- 已通过：`swift test --package-path CLI --scratch-path .build/sp139-xcode-focused-testing --filter XcodeCommandTests`（39/39）；`swift test --scratch-path .build/sp139-xcode-focused-testing-shared --filter TKXcodeWorkflowModelsTests`（22/22）。仅使用 worktree 专属 scratch，未启动真实 Xcode/Simulator/设备/server。
- 已通过：由新建 CLI 子进程走实际 `XcodeTest.run()` catch 路径的 blank-selector 单一 JSON envelope；测试从 SwiftPM 当前 `--test-bundle-path` 反查同一 scratch 的 sibling `triton`，不扫描或复用任意旧 build；`triton schema --command xcode.test --json`、`triton xcode test --help` 与 `triton xcode build --help` 证明 option 只在 test scope。
- 已通过：串行 `git diff --check`、`docs-linhay/scripts/check-docs.sh`（139 spaces）与 `docs-linhay/scripts/verify.sh --ci-docs`；停在未 stage/未 commit 状态供主控复核。
- 未覆盖项：没有真实 XCTest bundle 或 Xcode process smoke；本 slice 只证明 parser、argv、summary/source-command 和 schema contract。真实 test identifier 的可执行性仍由 xcodebuild 决定。

## 停止条件

不得 push、PR、merge、tag、release、关闭 issue、删除 worktree/branch 或修改 #164 WIP。完成 docs/验证后只报告 diff 与证据，等待主控明确批准本地 checkpoint。

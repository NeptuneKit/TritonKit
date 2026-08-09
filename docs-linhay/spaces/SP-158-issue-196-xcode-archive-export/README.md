# SP-158：Xcode archive 与 IPA export

## 边界

- 对应 GitHub issue：[#196](https://github.com/NeptuneKit/TritonKit/issues/196)
- 影响层：CLI / Xcode workflow / schema / JSONL artifact contract。
- 工作目录：`../TritonKit-worktrees/SP-158-issue-196-xcode-archive-export/`
- 分支：`feat/SP-158-issue-196-xcode-archive-export`
- 目标：在不破坏现有 `triton xcode build|test|run` 的前提下，提供可审计的 `triton xcode archive` 与 IPA export 工作流。

## BDD / 验收

### Scenario 1：archive 命令可被发现

- Given CLI schema 和 `triton xcode --help`
- When 查询 Xcode command surface
- Then `archive` 明确暴露 archive、generic destination、build settings、签名相关参数、artifact 与失败恢复合同。

### Scenario 2：archive argv 保持边界

- Given project/workspace、scheme、configuration、SDK、destination 和重复 `KEY=VALUE` build settings
- When 构建 archive invocation
- Then `xcodebuild archive` 的每个参数保持独立 argv，路径、空格、条件 setting 和 signing flag 不被 shell 拼接或截断。

### Scenario 3：export 使用显式 options plist

- Given 已存在 `.xcarchive` 和显式 `ExportOptions.plist`
- When 执行 export
- Then 使用 `xcodebuild -exportArchive -archivePath ... -exportOptionsPlist ... -exportPath ...`，输出 IPA/目录 artifact 与最终结构化结果。

### Scenario 4：失败输出单一机器可读 envelope

- Given signing/provisioning、archive 或 export 失败
- When 使用 `--json` / `--jsonl`
- Then stdout 不二次包装，返回稳定 failure code、脱敏诊断、artifact 状态和可执行 recovery/nextAction。

### Scenario 5：现有 Xcode workflow 不回归

- Given build/test/run/settings 的已有 parser、schema 和 runner tests
- When 运行 focused 与完整 CLI tests
- Then 既有行为保持通过，archive/export 新命令独立覆盖。

## 非目标

- 不自动修改证书、描述文件、Team、Bundle ID 或工程签名配置。
- 不上传 TestFlight/App Store Connect。
- 不把真实签名成功、IPA 可安装或业务验证伪装成 host `xcodebuild` 成功。
- 不恢复 Web/Wails 控制面。

## 计划

1. 先在 `CLIXcodeModels` / `XcodeCommandTests` 写失败的 command/schema/argv/output contract tests。
2. 复用现有 Xcode runner、progress、artifact 与 failure taxonomy，增加 archive/export runtime 与 models，保持 Commands / Runtime / Models 边界。
3. 补 CLI schema、README/dev 文档和本 space 证据。
4. 运行 focused tests、CLI 全量测试、release build、docs gate；真实私有工程/签名环境不可用时记录 blocker。

## 当前状态

- 当前状态：实现完成，focused tests、full Xcode suite 与 release build 已通过；docs gate 仍被既有 registry blocker 拦截，等待主控复核。
- 远端边界：用户已授权本轮串行提交、合并、push，并按验证结果关闭 issue；真实签名/IPA 安装缺口仍需保留为风险。

## 实现结果

- 新增 `triton xcode archive`：固定并校验 `generic/platform=iOS`，使用 `xcodebuild archive`，支持重复 `--build-setting` 和两个 provisioning flags。
- 新增 `triton xcode export`：要求现有 `.xcarchive`、显式有效 `ExportOptions.plist` 和 `--export-path`，使用 `xcodebuild -exportArchive` 并发现 `.ipa` artifact。
- 两个命令复用现有 bounded JSON/JSONL progress、stdout/stderr artifact 与 `TKXcodeActionSummary`，增加 archive/export artifact paths/bytes 和稳定 signing/provisioning/archive/export failure codes。
- 不声明真实签名、IPA 安装、App Store Connect 上传或私有 workspace 成功；真实 Xcode/signing smoke 需在具备对应工程与签名资产的环境运行。
- 为恢复完整回归，流式 Xcode host runner 改用 `terminationHandler` 通知进程结束，避免把阻塞式 `waitUntilExit()` 投到全局队列；同时保留原有 `--destination` 的 build/settings/install/launch/readiness 契约文案，并补充 archive 语义。

## 本轮证据

- command/schema contract tests：`XcodeCommandTests` 新增 parser、generic destination、argv 边界、显式 plist、schema 和 recovery 覆盖。
- schema direct-child contract：`xcode.archive` 与 `xcode.export` 的 narrowed schema 均断言保留 `xcode-archive` / `xcode-export` `providedCapabilities`，parent schema 也有同名 capability 断言。
- fake runner tests：`BuildRunnerTests` 覆盖 archive 成功 artifact summary 与 export signing failure/artifact discovery。
- CLI help/schema smoke 已确认 `xcode archive` / `xcode export` 出现在帮助和 `schema --command xcode.archive --json` 中，二者均出现在 `providedCapabilities`。
- release build：`swift build --package-path CLI --scratch-path .build/sp158-release -c release --product triton` 通过（641.93s），仅有既有 Objective-C selector warnings。
- full Xcode suite：46 项通过；包含流式 host runner 工作目录、timeout、archive/export 和原有 run preflight 回归。
- docs gate：`check-docs.sh` / `verify.sh --ci-docs` 被 worktree 原有 SP registry 非连续错误拦截：`space registry IDs must be contiguous from SP-001`。

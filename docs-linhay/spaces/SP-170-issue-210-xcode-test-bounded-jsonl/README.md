# SP-170：Xcode test 有界 JSONL 与 schema `--progress` 作用域修复

## 边界

- 对应 GitHub issue：#210 `[Bug] Xcode JSONL floods raw output and parent schema exposes unsupported progress flag`
- 影响层：CLI `triton xcode test` / `triton xcode run` 的进度输出契约（`Sources/TritonKitCLI/CLIXcodeCommands.swift`、`CLIXcodeRuntime.swift`、`CLIXcodeProgressRuntime.swift`）与 Xcode schema fact source（`Sources/TritonKitCLI/CLISchemaXcodeCommands.swift`）、focused tests 与文档；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-170-issue-210-xcode-test-bounded-jsonl/`
- 分支：`feat/SP-170-issue-210-xcode-test-bounded-jsonl`
- 基线：`main@a56d7d6a`
- 目标：
  1. `triton xcode test --jsonl` 默认输出有界/compact JSONL（lifecycle、heartbeat、结构化失败、最终 test summary），不再把全部原始 `xcodebuild` stdout 转发给消费方；原始流保留在显式 `--progress full` 之后。
  2. schema fact source 与子命令 parser 对齐：`--progress` 只出现在实际接受该 flag 的子命令（build/test/archive/export），`xcode run` 不再宣告；schema 示例必须可执行。

## 非目标

- 不连接真实 Xcode workspace / Simulator 运行真实 `xcodebuild` 回归；以进程注入 / fake runner / parser fixture 验证。
- 不改 `xcode build` 已发布的 compact progress 契约（SP-156）；test 对齐同一 `XcodeProgressMode` 语义。
- 不新增 HTTP/Web/Wails 表面；不触碰其他 worktree 或 main 仓库。
- 不改 `xcode test` 的测试选择、xcresult 解析语义（SP-123/SP-139 已收口）。

## BDD 验收

### 场景 1：`xcode test --jsonl` 默认有界

- Given 大型 workspace 的 focused test 产生大量原始 build stdout
- When 执行 `triton xcode test --jsonl ...`
- Then JSONL 流只包含 lifecycle / heartbeat / 有界诊断（warnings/errors 截断计数）/ 结构化失败用例 / 最终 test summary 事件；原始 build 行不再逐条转发。

### 场景 2：显式 full 恢复原始流

- When 执行 `triton xcode test --progress full --jsonl ...`
- Then 恢复现有 raw stdout/stderr chunk 转发行为（兼容既有消费方）。

### 场景 3：schema 与 parser 一致

- Given `triton schema --command xcode --json`
- Then `--progress` 只出现在 build/test/archive/export 的 `optionalOptions`；`run` 的选项列表不含 `--progress`；`triton xcode run --help` 同样不含；schema 中的示例命令可被真实 parser 接受。

### 场景 4：schema 可执行性 contract test

- Given Xcode schema 的每个子命令
- Then 存在 contract test 断言 schema 宣告的每个 option 都被子命令 parser 接受（防止再次出现 advertised-but-unsupported）。

## 验收命令

```bash
swift test --package-path CLI --scratch-path .build/cli --filter Xcode
swift test --package-path CLI --scratch-path .build/cli --filter Schema
swift build --package-path CLI --scratch-path .build/cli-release -c release --product triton
.build/cli-release/release/triton schema --command xcode --json
.build/cli-release/release/triton xcode test --help
.build/cli-release/release/triton xcode run --help
docs-linhay/scripts/check-docs.sh
git diff --check
```

真实大型 workspace 回归不作为本次验收前置；以 fake runner / fixture 验证有界性（字节数/事件数上界断言）与 schema 对齐。

## 当前状态

- 实现完成（2026-08-21，主控接管完成）：`xcode test` 默认 compact 有界 JSONL、`--progress full` 暂存原始流；schema test 子命令挂载 `--progress` 并与 parser 契约测试对齐；`run` 保持不宣告。focused tests（Xcode/Schema filter）通过；2 个既有 `XcodeProgressTests` 断言与 6 个 Schema 套件失败在未修改 baseline 影子复现，属 pipe-drain 负载抖动/影子环境预存在问题，非本 diff 回归（详见 REPORT）。真实大型 workspace 回归保留为风险。

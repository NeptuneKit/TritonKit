# GitHub Issue #150：Xcode Workflow 构建 Swift Package

> 状态：已归档
>
> GitHub：[NeptuneKit/TritonKit#150](https://github.com/NeptuneKit/TritonKit/issues/150)
>
> Branch：`feat/20260720-issue-150-xcode-package-build`
>
> Worktree：`../TritonKit-worktrees/20260720-issue-150-xcode-package-build/`
>
> 集成：feature `664c72f4`，merge `96b94c63`

## 背景

`triton xcode discover --path . --json` 已把 `Package.swift` 作为 Xcode container 返回，但 `xcode use/schemes/settings/build/test/run` 只接受 workspace/project。agent 因而会收到一个无法继续消费的推荐结果，并被迫回退裸 `xcodebuild`；`schema --command xcode.build --json` 也无法读取已有的嵌套 build contract。

`docs-linhay/scripts/create-space.sh` 在当前仓库不存在，因此本 space 按固定模板直接建立并同步总索引。

## Triton-first 基线

- `triton status --json`：本机管理服务未启动，返回 `server_unavailable`；这不应阻塞 host Xcode workflow。
- `triton doctor --json`：离线 schema 可用，runtime 未连接。
- `triton capabilities --json`：已有 `xcode` workflow，但 package discovery 与执行契约未闭环。
- `triton schema --command xcode --json`：build 的 optional options 仅含 `--workspace/--project`，未声明 package。
- `triton schema --command xcode.build --json`：返回 `unknown_command_schema`。
- `triton xcode discover --path . --json`：成功发现根目录与 `CLI/` 的两个 `Package.swift`。
- `triton xcode build --package Package.swift ...`：ArgumentParser 返回 `Unknown option '--package'`。
- `triton plan --platform ios --json`：当前仍以 runtime bootstrap 为主，不提供 package build 计划；本期不扩展 plan。

## 范围

- Xcode container 契约增加 `package`，显式接受 `Package.swift` 文件或其父目录。
- `xcode use/schemes/settings/build/test/run` 与 repo-local defaults 复用同一 package 选择；workspace/project/package 三者互斥。
- package action 使用 discovery 已返回的 package path 生成可执行 `xcodebuild` 命令，不新增第二套 `spm` 对外 API。
- invocation/action summary/schema/help/examples 暴露 package identity。
- `schema --command xcode.build --json` 等点分 selector 可直接返回收窄后的 Xcode 子命令契约。
- 真实 standalone Swift package 通过 Triton 执行 generic iOS Simulator build smoke。

不在本期范围：SwiftPM daemon、`triton spm`、package executable run、HTTP/Wails/Web、Xcode project 生成、业务 runtime readiness。

## BDD 场景

### 场景 1：显式 package build

- Given standalone Swift package 有可共享 scheme
- When 执行 `triton xcode build --package <Package.swift> --scheme <scheme> --destination 'generic/platform=iOS Simulator' --jsonl`
- Then invocation 与 final summary 均包含规范化 package path
- And source command 从该 package container 构建
- And 成功时退出码为 0，不要求 workspace/project 或 embedded server。

### 场景 2：discovery 与 defaults 闭环

- Given discovery 只返回一个 `Package.swift`
- When 执行 `triton xcode use --package <path> --scheme <scheme> --json`
- Then `.triton/host-defaults.json` 保存 package
- And 后续 `xcode schemes/settings/build/test/run` 可省略 container 参数。

### 场景 3：container 冲突

- Given 同一请求同时传入 package 与 workspace/project
- When 解析 Xcode workflow invocation
- Then 返回稳定 `validation_failed` / `ambiguous_workspace`
- And 不启动 `xcodebuild`。

### 场景 4：嵌套 schema 可发现

- Given Xcode schema 含 build 子命令
- When 执行 `triton schema --command xcode.build --json`
- Then 返回父 `xcode` schema envelope
- And `subcommands[]` 只保留 `build`
- And optional options、defaults、失败码均包含 package build 契约。

## 验收门禁

- 先补 defaults round-trip、command argv、resolver/CLI parse、schema selector 的失败测试。
- 聚焦 shared/CLI/schema 测试通过。
- 临时 standalone package 通过 release `triton xcode discover/use/build` 真实 smoke。
- `docs-linhay/scripts/verify.sh --local`、docs 与 diff 检查通过。
- 合入 main、GitHub Actions 成功后关闭 #150。

## 实现结果

- `TKXcodeWorkspaceDefaults`、resolved invocation、schemes output 与 `TKXcodeActionSummary` 增加可选 `package`，workspace/project/package 三者互斥；显式 container 整体覆盖旧 defaults。
- `xcode use/schemes/settings/build/test/run` 均接受 `--package <Package.swift|dir>`，package 可写入 repo-local defaults 并由后续命令继承。
- `TKHostCommand` 增加 `workingDirectory`；普通与 streaming host runner 统一通过同一 process 配置函数应用 cwd/environment，source command 使用 `cd <package-dir> && xcodebuild ...` 表达审计事实。
- `xcodebuild` builder 对 package 不伪造不存在的 `-packagePath`，而是在 package 目录生成原生 scheme/list/settings/build/test argv。
- schema 增加 `--package`、`xcode-package-build` capability 与 `package` final field；`schema --command xcode.build` 和空格 selector 都能收窄到 build。

## 验证结果

- 红灯 1：shared/CLI tests 因 defaults、builder 与 ArgumentParser 尚无 package 接口而编译失败。
- 红灯 2：初次真实 JSONL build 的 source command 虽显示 package cwd，但 streaming runner 未应用 cwd，实际误解析 TritonKit worktree scheme并返回 exit 65；新增 streaming cwd 回归测试后修复。
- 聚焦 shared `TKXcodeWorkflowModelsTests` 15 项、CLI `XcodeCommandTests` 14 项通过。
- release CLI 对临时 standalone package 完成 `discover`（唯一 recommended `Package.swift`）、`schemes`（`Issue150Package`）、显式 package build 与 `xcode use --package` 后无 container 参数 build；两次 generic iOS Simulator build 均返回 `ok=true, exitCode=0`，产物同时覆盖 arm64/x86_64。
- `schema --command xcode.build --json` 返回单个 build subcommand，optional options 含 `--package`，final contract 含 `package`。
- 正式本地门禁 `docs-linhay/scripts/verify.sh --local` 通过，覆盖根 Swift 226 项、release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke、iOS Simulator build、docs 与 diff check。
- main 集成回归：`XcodeCommandTests` 14 项、`TKXcodeWorkflowModelsTests` 15 项通过。
- 扩展 `SchemaFactSourceWorkflowTests` 中新增 `xcode-package-build` capability 的缺口已清零；剩余失败仅为既存 device proxy 子命令/schema 漂移，未新增本期失败。

# SP-153 · GitHub #173 Xcode Run Target Binding

## 状态

- 阶段：已合并 `main`（PR #177）；GitHub #173 已关闭
- GitHub issue：[#173](https://github.com/NeptuneKit/TritonKit/issues/173)
- Branch：`feat/SP-153-issue-173-xcode-run-target-binding`
- Worktree：`../TritonKit-worktrees/SP-153-issue-173-xcode-run-target-binding/`
- 基线：`main@d2578089`

## 问题与影响层

`triton xcode run` 虽然会让显式 `--destination` 驱动 `xcodebuild`，但后续 settings、install、launch 仍可能重新读取 workspace 或 simulator default，导致构建目标 A 与安装/启动目标 B 分裂。

本期只修改 CLI Xcode workflow runtime、必要的 shared Xcode wire model 与 focused unit tests；不修改 HTTP/Wails/Web、embedded runtime、`CLIWebDeviceRuntime`、devicectl discovery/readiness 或其它 device parser。

## BDD

### 场景一：显式 Simulator destination 贯穿 run

- Given workspace default simulator 为 B
- And agent 执行 `triton xcode run --destination 'platform=iOS Simulator,id=A'`
- When run 解析 invocation、执行 build、读取 settings、安装、启动并形成 readiness 下一步
- Then 全部阶段绑定同一个 immutable simulator target A
- And B 不得覆盖 A
- And summary/sourceCommand 可审计地记录一致 target，公开输出继续遵守脱敏契约

### 场景二：显式 simulator selector 贯穿 run

- Given workspace default simulator 为 B
- When agent 执行 `triton xcode run --simulator A`
- Then build destination、settings、install、launch 与 readiness target 均为 A
- And 不重新解析为 B

### 场景三：destination 无法唯一解析 Simulator target 时提前失败

- Given agent 显式提供 generic、name-only、多个 `id` 或非 Simulator destination
- When `xcode run` 在启动昂贵 build 前做 target preflight
- Then 返回单一机器可读失败 envelope 和稳定 failure code
- And next action 明确要求提供 `--simulator <udid>` 或唯一 `platform=iOS Simulator,id=<udid>`
- And 不调用 `xcodebuild`、settings、install 或 launch

### 场景四：无显式 destination 保持 defaults 兼容

- Given agent 未提供 `--destination` 或 `--simulator`
- When workspace defaults 能解析 Simulator target
- Then 继续沿用既有 defaults 行为
- And 既有 real-device destination/selector 语义不变

## 验收边界

1. 用 fake process/app runner 证明显式 target A 不会被 stale default B 覆盖。
2. 无法唯一提取 Simulator UDID 的显式 destination 在 build 前 fail closed。
3. JSON/JSONL summary、sourceCommand、schema 与 failure envelope 可供 agent 审计且不泄漏敏感信息。
4. focused tests、CLI Swift tests、docs 检查与 `git diff --check` 通过；不运行真实 Xcode 或 Simulator。

## 非目标

- 不实现 destination name 到 Simulator UDID 的 host discovery。
- 不修改真机 discovery/readiness、设备 alias parser 或 devicectl 行为。
- 不触碰 embedded runtime、Web UI、远端、release、push、PR 或 issue 状态。

## 停止条件

- 修复必须修改 host device parser、devicectl discovery/readiness 或其它 issue 的实现文件。
- destination 歧义的产品语义需要用户取舍。
- 同一验证命令因同一原因连续失败三次。

## 验证记录

- Red：focused test 首次稳定复现显式 destination A 被 workspace default B 覆盖，`invocation.simulatorUDID` 实际为 B。
- Green：`swift test --package-path CLI --scratch-path .build/sp153-issue173-cli --filter 'XcodeCommandTests.xcodeRun'` 通过 3 项；fake runner 证明 build、settings、install、launch 与 app-scoped readiness target 全部使用 A，且 sourceCommand 不含 B。
- Focused regression：`swift test --package-path CLI --scratch-path .build/sp153-issue173-cli --filter XcodeCommandTests` 通过 41/41。
- Schema smoke：本地构建产物执行 `triton schema --command xcode.run --json`，确认 `xcode_run_target_unresolved` 与 destination 唯一 id 约束已公开。
- Failure smoke：generic Simulator destination 在任何 build/path 解析前返回单一合法 JSON envelope、`code=xcode_run_target_unresolved`、exit 1，stderr 为空。
- CLI 全量在隔离 scratch 中暴露既有跨域基线失败：测试硬编码 `CLI/.build`、device bridge/proxy schema、placeholder selector、Harmony wait/proxy 等；相关 Xcode focused suite 已全绿，残余进程按边界终止，不追逐这些非本期失败。
- `git diff --check` 通过；`check-docs.sh` 与 `verify.sh --ci-docs` 仅因本并行 worktree 尚未包含 SP-142～152，报 `SP-153` 编号不连续。编号由主控预分配且不得复用，待其它 space 一并集成后重跑 docs gate。
- 未运行真实 Xcode、Simulator 或设备 smoke，符合本期 fake-only 验收边界。

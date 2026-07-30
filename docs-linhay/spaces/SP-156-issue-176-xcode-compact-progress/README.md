# SP-156 · GitHub #176 Xcode Compact Progress

## 状态

- 阶段：已完成（本地）
- GitHub issue：[#176](https://github.com/NeptuneKit/TritonKit/issues/176)
- Branch：`feat/SP-156-issue-176-xcode-compact-progress`
- Worktree：`../TritonKit-worktrees/SP-156-issue-176-xcode-compact-progress/`
- 基线：`feat/SP-153-issue-173-xcode-run-target-binding@57ff4092`

## 问题与影响层

`triton xcode build --jsonl` 当前会把每个 `xcodebuild` stdout/stderr chunk 复制成 progress event。大型 workspace 即使完整日志已经写入 `stdoutLogPath` / `stderrLogPath`，agent 通道仍可能收到数十 MB 的普通编译输出。

本期只修改 CLI Xcode build 参数、streaming progress runtime、schema、focused tests 与 Xcode 文档；不修改 shared progress model、HTTP/Wails/Web、runtime/device、Xcode target binding 或其它 issue 实现。

## BDD

### 场景一：默认 compact 抑制普通输出

- Given `xcodebuild` 产生大量普通 stdout/stderr
- When agent 执行 `triton xcode build --jsonl`
- Then 默认 `progress=compact`
- And invocation、heartbeat、log artifact paths 与 final summary 保留
- And 普通 stdout/stderr progress event 不进入 agent 通道
- And 完整原始 stdout/stderr 仍写入对应 log artifact

### 场景二：compact 有界保留 warning/error

- Given `xcodebuild` 同时产生普通输出、warning 与 error
- When compact progress 消费输出
- Then warning/error 以独立 typed event 保留
- And event 数量受固定上限约束
- And event message 继续使用现有 Xcode public redaction 与单条长度上限

### 场景三：显式 full 保持旧行为

- Given 调用方需要交互式排障
- When 执行 `triton xcode build --progress full --jsonl`
- Then 每个 stdout/stderr chunk 继续按旧合同输出 progress event
- And 完整日志与 final summary 保持不变

### 场景四：JSON 与 JSONL 路由稳定

- Given 默认 compact 或显式 full
- When 使用 `--jsonl`
- Then progress 写 stdout，final summary 是最后一条 stdout JSONL
- When 使用 `--json` / `--format json`
- Then progress 写 stderr，stdout 只保留最终 JSON envelope
- And schema 公开 `--progress compact|full`、默认值和 compact/full event 集合

### 场景五：非法 progress 值在执行前失败

- Given agent 传入未知 progress 值
- When ArgumentParser 解析命令
- Then 在启动 host command 前返回参数错误
- And 不生成 build artifact 或启动 `xcodebuild`

## 验收边界

1. Fake host command 证明大量普通输出在 compact agent 通道被抑制、原始 log 完整保留。
2. Warning/error 事件有界，heartbeat 与 final summary 保留。
3. `--progress full` 与当前 stdout/stderr chunk stream 兼容。
   - 非 JSONL full runner 保持既有边界，不额外注入 invocation/summary；避免改变 `settings/test/run` 的 stderr 合同。
4. CLI parse、JSON/JSONL routing、schema、focused Xcode tests、CLI build、docs 与 diff checks 通过或记录可归因 blocker。
5. 不启动真实 Xcode、Simulator、设备或私有项目。

## 非目标

- 不实现完整 xcodebuild 语义 parser、target/file/build-phase DTO 或 warning 去重聚合。
- 不改 `TKXcodeProgressEvent` shared wire model。
- 不压缩、截断或删除 stdout/stderr log artifact。
- 不修改 test/run/settings 默认 progress，后续需要时另行扩展同一稳定 enum。

## 停止条件

- 必须修改 shared progress model 或越过 CLI Xcode 文件面。
- compact diagnostic 分类需要产品级语义取舍。
- 同一验证命令因同一原因连续失败三次。

## 验证记录

- Red：旧 runner 对 fixture 只产生 invocation/stdout/stderr/summary；期望 warning/error typed event 缺失，普通 stdout/stderr 仍进入 agent 通道，1 test 记录 4 个稳定 expectation failure。
- Green：`swift test --package-path CLI --scratch-path .build/sp156-final-cli --filter XcodeProgressTests` 通过 8/8，覆盖 compact raw-log 保留、warning/error 各自有界、full 兼容及非 JSONL 生命周期边界、heartbeat、JSON/JSONL/text routing、CLI parse 与 schema。
- Xcode regression：`swift test --package-path CLI --scratch-path .build/sp156-issue176-cli --filter XcodeCommandTests` 通过 41/41；settings/test/run 未暴露 `--progress`，shared runner 与 `runXcodeBuild` runtime 默认继续 full，仅 `XcodeBuild` command 默认 compact。
- CLI build：`swift build --package-path CLI --scratch-path .build/sp156-issue176-cli --product triton` 通过。
- Schema/help：本地 `triton schema --command xcode.build --json` 确认 `--progress compact|full`、默认 compact、compact warning/error 与 full stdout/stderr event；`triton xcode build --help` 显示相同 enum/default。
- `check-docs.sh` 与 `verify.sh --ci-docs` 仅因本并行基线尚未集成 SP-142～152、SP-154～155 而从 SP-153 开始报告编号不连续；编号由主控预分配且不得复用，待整批 space 集成后重跑。
- 未运行真实 Xcode、Simulator、设备或私有项目；diagnostic 分类是行级 best-effort `warning:` / `error:` 匹配，不是完整 xcodebuild 语义 parser。

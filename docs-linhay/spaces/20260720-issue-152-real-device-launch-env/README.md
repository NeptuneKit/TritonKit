# GitHub Issue #152：真机 Launch Environment 传播

> 状态：执行
>
> GitHub：[NeptuneKit/TritonKit#152](https://github.com/NeptuneKit/TritonKit/issues/152)
>
> Branch：`feat/20260720-issue-152-real-device-launch-env`
>
> Worktree：`../TritonKit-worktrees/20260720-issue-152-real-device-launch-env/`

## 背景

`xcode run --device ... --env KEY=VALUE` 当前把值写入 host `DEVICECTL_CHILD_KEY`，source command 也显示这一前缀已设置，但 iOS 26.5.2 真机 App 的 `ProcessInfo.processInfo.environment` 读不到原始 key。命令参数能正常传播，说明 build/install/launch 与目标身份正确，缺口仅在 environment transport。

`docs-linhay/scripts/create-space.sh` 在当前仓库不存在，因此本 space 按固定模板直接建立并同步总索引。

## Triton-first 基线

- `triton status/doctor/plan --platform ios --json`：embedded server 未启动，不影响 host-side real-device adapter 事实读取。
- `triton capabilities --json` 与 `schema --command xcode.run --json`：宣称 `--env` 通过 `DEVICECTL_CHILD_*` 传播并脱敏。
- `triton device list --platform ios --json`：发现一台 wired、ready、iOS 26.5.2 真机，可用于最终 host contract 验证。
- issue 真实回归：同一 App 的 `--arg` 生效，而 `ProcessInfo.environment[KEY]` 为 nil。
- 在上述 Triton failure evidence 后读取当前 `devicectl help device process launch`：官方 host CLI 提供 `--environment-variables <JSON dictionary>`，并明确其优先于 `DEVICECTL_CHILD_*`。

## 范围

- iOS 真机 launch 把 `--env` 编码为 `devicectl --environment-variables <JSON>`，不再依赖 caller environment 前缀。
- JSON 必须是稳定、合法的 string-to-string dictionary，空 environment 不添加 flag。
- sourceCommand 对整个 JSON argv value 脱敏，实际 process argv 仍保留原值。
- `xcode run` 与通用 `app launch` 复用同一 devicectl builder，schema/help/skill 不再宣称 `DEVICECTL_CHILD_*`。
- 用 connected real device 验证生成/提交命令；若仓库没有可签名且能回传 ProcessInfo sentinel 的 App，则明确保留真实 App 内观测为外部回归边界，不伪造成功。

不在本期范围：修改业务 App、自动签名账号、Simulator `SIMCTL_CHILD_*`、Android/Harmony、HTTP/Wails/Web。

## BDD 场景

### 场景 1：真机环境显式传播

- Given launch environment 含 `BENCH_ROWS=100000`
- When 构造 real-device devicectl launch
- Then argv 在 bundle id 前包含 `--environment-variables` 与 JSON dictionary
- And host process environment 不再含 `DEVICECTL_CHILD_BENCH_ROWS`。

### 场景 2：source command 脱敏

- Given environment value 含 secret
- When 生成 machine-readable sourceCommand
- Then flag 名保留供审计
- And JSON value整体显示 `<redacted>`
- And 原始 key/value 均不泄漏。

### 场景 3：空 environment 保持兼容

- Given 未传 `--env`
- When 构造 devicectl launch
- Then argv 不包含 `--environment-variables`
- And 既有 payload URL、terminate、artifact 与 app arguments 顺序不变。

### 场景 4：Simulator 语义不变

- Given target 是 iOS Simulator
- When `xcode run --env KEY=VALUE`
- Then 继续使用 `SIMCTL_CHILD_KEY`
- And 本期真机修复不改变 simctl builder。

## 验收门禁

- 先修改 devicectl argv/脱敏/schema 期望并确认红灯。
- shared host adapter、app launch、Xcode command 聚焦测试通过。
- connected real device 至少完成 Triton selection 与 non-mutating contract 取证；有可用测试 App 时再完成 sentinel 动态回读。
- `docs-linhay/scripts/verify.sh --local`、docs 与 diff 检查通过。
- 合入 main、GitHub Actions 成功后关闭 #152。

## 实现与验证

- 红灯：shared builder 测试因 `TKHostCommand` 尚无 argv 脱敏索引而编译失败；CLI 期望 real-device argv 使用显式 JSON flag。
- 绿灯：`TKDevicectlCommand.launchApp` 对非空环境生成排序后的 string-to-string JSON，附加 `--environment-variables`，不再设置 `DEVICECTL_CHILD_*`。
- `TKHostCommand.redactedArgumentIndexes` 与 `hostSourceCommand` 让实际 argv 保留 JSON、审计命令只显示 `--environment-variables <redacted>`；空环境路径与 Simulator 路径保持不变。
- 已通过 `TKHostAdapterModelsTests` 38 项、`AppOpenURLFlowTests` 7 项、`XcodeCommandTests` 14 项。
- `docs-linhay/scripts/verify.sh --local` 通过：Swift tests 226 项、Release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke、iOS Simulator package build、docs 与 diff 门禁全部成功。
- connected iOS 26.5.2 真机可由 Triton 解析为 wired/ready；`triton app list` 未发现 Triton/Demo/Bench sentinel App，因此未启动无关 App，真实 `ProcessInfo.environment` 动态回读保留为外部业务 App 回归边界。

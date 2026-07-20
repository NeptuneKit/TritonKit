# GitHub Issue #153：iOS 真机 App Container 文件拉取

> 状态：已归档
>
> GitHub：[NeptuneKit/TritonKit#153](https://github.com/NeptuneKit/TritonKit/issues/153)
>
> Branch：`feat/20260720-issue-153-real-device-app-pull`
>
> Worktree：`../TritonKit-worktrees/20260720-issue-153-real-device-app-pull/`

## 背景

真实 iOS App 在 data container 内生成 JSON evidence 后，Triton 当前只能通过 Simulator `app container` 返回 host path，不能从真机复制文件。调用真机 selector 会落入 simctl 并返回 simulator-oriented `app_container_not_found`，迫使 agent 回退裸 `xcrun devicectl device copy from`。

`docs-linhay/scripts/create-space.sh` 在当前仓库不存在，因此本 space 按固定模板直接建立并同步总索引。

## Triton-first 基线

- `triton status --json`：embedded server 未启动；本需求是 host-side artifact transfer，不依赖 embedded runtime。
- `triton doctor --platform ios --json`：`host-device` pass，并把 `triton device list --platform ios --json` 作为事实入口。
- `triton capabilities --json`：已有 `ios-real-app`，但没有 real-device app pull capability。
- `triton schema --command app.container --json`：仅暴露“Print an app container path”，runtime scope 不含 iOS real-device file transfer。
- `triton device list --platform ios --json`：一台 iOS 26.5.2 wired real device 为 connected/ready。
- 在上述 missing-schema evidence 后读取 `devicectl help device copy from`：官方 CLI 支持 `appDataContainer` / `appGroupDataContainer`、source、destination、domain identifier、JSON/log artifact。

## 范围

- 新增 `triton app pull`，只面向 ready iOS real device，复用统一 `--device` selector。
- app data domain 使用 `--bundle-id`；app group domain 使用 `--group-id`，不伪造两类 domain identifier 的等价性。
- 必填 `--source` 与 `--destination`；默认拒绝已有 destination 与符号链接，显式 `--overwrite` 才可替换。
- 默认只接受单文件；目录必须显式 `--allow-directory`，且文件/目录都受 `--max-bytes` 上限约束。
- 成功 JSON 返回 target、domain、source、destination artifact、kind、bytes、entry count、sourceCommand 与 devicectl JSON/log artifact。
- source command 必须把真机 raw identifier 替换为 Triton redacted target。
- 添加 Debug test fixture sentinel，用仓库自有 App 完成 build/install/launch/pull/JSON parse 真机 smoke；若签名或设备环境阻塞，保留稳定 Triton error evidence。

不在本期范围：Simulator pull（已有 host container path）、向设备 push、Android/Harmony、任意系统 domain、远端 agent、HTTP/Wails/Web。

## BDD 场景

### 场景 1：拉取 app data 单文件

- Given ready iOS real device、已安装 bundle、存在 source file
- When `triton app pull --domain app-data --bundle-id ...`
- Then 通过 `devicectl device copy from --domain-type appDataContainer` 拉取
- And JSON 返回 final destination、`kind=file`、bytes 与 devicectl artifacts。

### 场景 2：拉取 app group 文件

- Given domain 为 `app-group`
- When 构造命令
- Then 使用 `appGroupDataContainer`
- And domain identifier 来自 `--group-id`，缺失时在 host execution 前返回 `validation_failed`。

### 场景 3：destination 安全

- Given destination 已存在或自身为 symlink
- When 未传 `--overwrite`
- Then 返回 `artifact_output_rejected` 且不运行 devicectl
- And 显式 overwrite 也不跟随 symlink。

### 场景 4：目录与大小边界

- Given 拉取结果是目录或超过 byte limit
- When 未授权目录或超过 `--max-bytes`
- Then 删除 staging artifact 并返回 `app_pull_directory_not_allowed` 或 `app_pull_artifact_too_large`
- And 不替换已有 final destination。

### 场景 5：错误契约

- Given App/domain/source 不存在、设备锁定或断线
- When devicectl 失败
- Then 返回稳定 `app_pull_domain_not_found`、`app_pull_source_not_found`、`device_locked` 或 target readiness error
- And JSON/log artifact 路径仍可审计。

## 验收门禁

- 先补 shared builder、CLI runtime/schema/failure tests 并确认红灯。
- 聚焦测试与 `docs-linhay/scripts/verify.sh --local` 通过。
- 仓库 TestFixture 真机 sentinel smoke 成功，或保留签名/设备 blocker 的稳定 Triton evidence。
- 文档、memory 与 Xcode workflow skill 同步。
- 合入 main、GitHub Actions 成功后关闭 #153。

## 实现与验证

- 红灯：shared builder 缺少 `copyFromDevice` / domain type；CLI 缺少 `HostAppPull`、执行 request/output、failure mapping 与 schema。
- 绿灯：`TKDevicectlCommand.copyFromDevice` 生成 typed app-data/app-group argv；`HostAppPullTests` 9 项覆盖解析、文件成功、目录成功、destination conflict、symlink、失败保留旧 artifact、原子 overwrite、大小/目录边界、domain validation、错误码与 schema。
- `TKHostAdapterModelsTests` 38 项通过，包含两类 devicectl domain argv。
- `HostAppPullTests` 9 项与 `CLIHelpTests` 6 项通过；`capabilities --json` 已公开 supported `ios-real-app-pull`，点分 `schema --command app.pull --json` 返回 pull-only subcommand、artifact 与 failure contract。
- `SchemaFactSourceTests` 运行 118 项；本期新增 capability、artifact 与 failure recovery taxonomy 均通过，余下 11 个 issue 仍是既存 device proxy/selector/evidence taxonomy 基线。完整 CLI suite 运行 649 项，26 个既存 issue 分布在同一 schema 基线、暂停的 testrec、Harmony wait timing 与旧 xcode-use 断言，未出现 `HostAppPullTests` 回归。
- `docs-linhay/scripts/verify.sh --local` 全量通过：SwiftPM dependency boundary、Debug isolation、根包 226 项 Swift tests、release CLI build/smoke、Harmony/iOS runtime smoke、iOS Simulator build、docs 与 whitespace gate 均成功。
- Debug TestFixture 会生成固定 `Library/Application Support/TritonKitFixture/app-pull-sentinel.json`，内容仅含 issue/kind/pass，用于安全真机 smoke。
- `triton xcode run` 已完成 TestFixture iphoneos Debug build 与真机 install，并由 devicectl 启用 DDI services；设备在 launch 时锁定，Triton 返回 `device_locked`，sentinel 未生成。随后 `triton app pull` 返回 `ddi_missing`。本轮保留这组稳定环境 blocker，不绕过 Triton 或宣称动态成功。
- 已以 `eaf99bb0` 合入 `main`；GitHub Actions [run 29738161353](https://github.com/NeptuneKit/TritonKit/actions/runs/29738161353) 全部通过后关闭 #153。

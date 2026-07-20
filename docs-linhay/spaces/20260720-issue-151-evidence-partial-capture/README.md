# GitHub Issue #151：Evidence Partial Capture Contract

> 状态：已归档
>
> GitHub：[NeptuneKit/TritonKit#151](https://github.com/NeptuneKit/TritonKit/issues/151)
>
> Branch：`feat/20260720-issue-151-evidence-partial-capture`
>
> Worktree：`../TritonKit-worktrees/20260720-issue-151-evidence-partial-capture/`
>
> 实现提交：`1d404d72`
>
> Main 合并提交：`196d4cc9`

## 背景

`triton evidence capture --json` 在 target 于采集中消失时，会由内部 target resolver 为每个 artifact 分别打印错误 JSON，最后再打印 `ok:true` manifest。stdout 因而不是单一 JSON 文档，且不完整证据可能被 agent 误判为成功。

## 范围

- evidence 内部 artifact 采集只返回错误，不直接写 stdout。
- 最终 manifest 显式暴露 `partial` 与顶层结构化 `error`。
- 每个失败 artifact 在 `skipped[]` 中保留结构化错误。
- 运行时/服务请求失败导致 partial capture 时，打印唯一 manifest 后以非零状态退出。
- 预期的 unsupported artifact 仍可形成 `ok:true, partial:true` manifest，不把能力边界伪装为命令崩溃。
- 更新 schema/output contract、测试、研发文档、memory 与相关项目级 skill。

不在本期范围：改变 evidence bundle 目录布局、重试断线 target、恢复远端连接、Web/Wails 展示。

## BDD 场景

### 场景 1：target 在 artifact 请求前消失

- Given status/list/version 已采集，且 list 曾解析出显式 target
- When hierarchy、AX、screenshot、geometry、archive 请求均返回 `target_not_found`
- Then stdout 只包含一个可由单次 JSON decoder 解析的 `TKEvidenceManifest`
- And manifest 为 `ok:false, partial:true`
- And 顶层 error 为稳定 partial-capture 错误
- And 每个 target artifact 的 `skipped[].error.code` 为 `target_not_found`
- And 命令以非零状态退出

### 场景 2：只有预期 unsupported artifact

- Given 用户请求当前 runtime 明确不支持的 artifact
- When capture 写入 manifest
- Then manifest 为 `ok:true, partial:true`
- And 不附加运行时失败 error

### 场景 3：完整采集

- Given 所有请求 artifact 均成功
- When capture 完成
- Then manifest 为 `ok:true, partial:false`
- And 退出状态为 0

## 验收门禁

- 先运行新增聚焦测试并确认红灯。
- Evidence bundle、shared model 与 schema contract 聚焦测试通过。
- `docs-linhay/scripts/verify.sh --local`、`docs-linhay/scripts/check-docs.sh`、`git diff --check` 通过。
- 合入 main、GitHub Actions 成功后关闭 #151。

## 实现记录

- evidence 专用 silent resolver 复用注入的 `URLSession`，内部 target resolution 不再向 stdout/stderr 打印命令级 envelope。
- `TKEvidenceManifest` 增加 `partial` 与可选顶层 `error`；`TKEvidenceSkippedArtifact` 增加可选 `error`，旧 JSON 仍可解码。
- 聚合器把请求/写入异常记录为 per-artifact error，并生成稳定 `evidence_capture_partial`；entrypoint 先打印唯一 manifest，再抛 `ExitCode.failure`。
- target_not_found 会把 manifest target 的 connected/connection state 保守更新为 false/disconnected。

## 验证记录

- 红灯：`swift test --package-path CLI --filter EvidenceBundleTests` 因缺少 `partial/error` 与可测试 silent entrypoint 编译失败。
- 绿灯：同一命令 21 项通过；`swift test --filter TKEvidenceModelsTests` 3 项通过；CLI schema surface 4 项通过。
- 正式门禁：`docs-linhay/scripts/verify.sh --local` 通过，包含 225 项根 Swift 测试、release CLI 构建、Harmony/iOS smoke、iOS Simulator build、文档结构与 diff 检查。
- public skill package：以 `0.2.11` / `v0.2.11` 生成测试包，确认包含 `TritonKit.skills/BUILD_INFO.json` 与更新后的 real-project regression skill。
- `docs-linhay/scripts/check-docs.sh` 与 `git diff --check` 通过；待 main 集成与线上 CI。

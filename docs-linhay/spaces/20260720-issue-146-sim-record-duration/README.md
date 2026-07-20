# GitHub Issue #146：Simulator 录屏时长校验

> 状态：已归档
>
> GitHub：[NeptuneKit/TritonKit#146](https://github.com/NeptuneKit/TritonKit/issues/146)
>
> Branch：`feat/20260720-issue-146-sim-record-duration`
>
> Worktree：`../TritonKit-worktrees/20260720-issue-146-sim-record-duration/`
>
> 实现提交：`f61f6498`；合并提交：`32770515`

## 背景

`triton sim record --duration <seconds>` 当前只根据 `simctl io recordVideo` 的退出码判定成功。线上证据显示命令等待了请求时长并返回 `ok: true`，但生成的 MOV 只有约 `0.066` 秒，无法作为有效证据。

## 范围

- 修正 bounded recording 的中断/收尾路径，确保 `simctl` 有机会完成 MOV 封装。
- 对生成的 MOV 做 host-side 时长读取和合理容差校验。
- JSON 成功结果暴露请求时长与实际时长； materially truncated artifact 返回稳定失败码。
- 更新 `sim` schema、README、agent 可读控制文档和 memory。

不在本期范围：Web/Wails UI、视频编辑、跨平台录屏、自动上传证据。

## BDD 场景

### 场景 1：请求时长得到有效录屏

- Given 已 boot 的 iOS Simulator
- When 执行 `triton sim record --duration 3 --json`
- Then 命令输出单个 JSON 成功 envelope
- And 结果包含 requested/actual duration 与 MOV artifact
- And 实际时长不低于请求时长的合理容差下限

### 场景 2：录屏产物被截断

- Given host command 返回成功但 MOV 实际时长显著短于请求值
- When Triton 校验 artifact
- Then 返回 `ok:false`
- And error code 为稳定的 `sim_record_truncated`
- And 不把该 artifact 描述为可用成功证据

### 场景 3：不可读取的录屏产物

- Given 录屏文件缺失或媒体元数据不可读取
- When Triton 校验 artifact
- Then 返回稳定的 artifact validation failure
- And hint 指向 Simulator、输出路径和媒体检查

## 验收门禁

- 先新增 duration validation 单元测试并确认红灯。
- focused CLI tests 通过。
- `swift test --package-path CLI` 通过。
- CLI release build、schema 检查和 `docs-linhay/scripts/check-docs.sh` 通过。
- 安全前提允许时，以真实 Simulator 录制短视频并保存 Triton-first 事实与媒体时长证据。

## 实施记录

- 红灯：新增 duration validation 测试后，因契约未实现而编译失败。
- 基线真实 smoke：请求 `3s`，旧 CLI 返回 `ok:true`，但 MOV 只有 `1` 帧，`ffprobe` stream/format duration 均为约 `0.066667s`。
- 关键发现：AVFoundation 的 asset duration 与 track time range 都可能显示约 `3s`；只有 `AVSampleCursor` 的 encoded sample duration 与实际一帧 artifact 一致。
- 绿灯：新增 sample duration 选择、截断/不可读错误码、专用 output/schema contract 与 4 项 focused tests。
- 修复后真实 smoke：同一 Simulator、同一 `3s` 请求返回单个 `ok:false` JSON，code=`sim_record_truncated`，message 包含 requested=`3.0`、actual=`0.066666...`、minimum=`2.25`，进程退出码为 `1`。
- 正式门禁：`docs-linhay/scripts/verify.sh --local`、`check-docs.sh`、`verify-skill-package.sh`、`git diff --check` 均通过；release schema 可查询 `host.simulator-recording` 及其完整字段。
- 扩展 CLI suite：本次新增的 failure recovery/output kind 两项 schema 问题已清零；全量仍受基线已有的 10 项 `device proxy/alias/bridge` schema 对齐断言与暂停中的 `testrec` local-device 选择断言阻塞，未在 #146 中混修。

真实 smoke 前已保存 `status/doctor/capabilities/schema sim/sim list` 的 Triton-first 事实；server 未启动只影响 embedded runtime，host-side Simulator discovery 与 recording schema 均可用。未调用裸 `simctl` 进行设备动作，`ffprobe` 仅用于独立核对已生成 MOV 的媒体时长。

本期 DoD 已满足并合入 `main`；后续若需要录屏 progress JSONL、可配置容差或跨平台录屏，应另建有限 space。

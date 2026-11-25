# SP-295 录屏 worker 启动与卡住状态恢复

[GitHub #285](https://github.com/NeptuneKit/TritonKit/issues/285) · `triton device recording start|status`。

- Given shell 通过 PATH 或绝对路径启动 CLI，When 开始录制，Then worker 由同一 CLI 启动，状态可最终查询，媒体由实际视频样本验证。
- Given 启动前失败或历史 `starting` 已超时且无人认领，When 重试同一目标，Then 回收该尝试自身的空预留并允许重试，保留已认领或仍在等待启动的会话及他人替换的输出。

复用用户已提交的 [PR #286](https://github.com/NeptuneKit/TritonKit/pull/286)。其候选为 `01a3d19a`，与当前主工作区分别管理。

## 2026-11-25 复核

本地实现为 `f10b1159`。联合门禁见[本轮记录](../../memory/2026-11-25.md)。

- 精确 PR CI `45356189364` 通过。候选的历史本地日志显示 Swift Testing 1901 项和 XCTest 均通过。PR 记录真实 iOS 27.0 Simulator 上旧版失败、候选恢复后完成录制。[CI](https://github.com/NeptuneKit/TritonKit/actions/runs/45356189364)
- 本轮用已构建候选、正式 v0.2.46 和隔离 fake ADB 做进程级对照。旧版 PATH 调用退出 1，留下空 MP4、无 worker PID 的 `starting`。将此夹具状态老化为超时后，候选 PATH 调用能将旧会话置为 `failed`，沿用同一目标和文件名完成录制。候选绝对路径也通过。两次返回 `completed`、媒体时长 2 秒且输出与合成 MP4 完全一致。
- 静态复核发现旧 PR 候选在 `Process.run()` 抛错时新增 `recording_worker_launch_failed`，该码未列入 schema。本地候选复用 PR 的工作进程启动和会话清理，并将此失败分支与已有的 `recording_worker_unavailable` 对齐。现有 GitHub PR 分支独立保留。
- 新增实际 CLI 进程回归，使用隔离 fake ADB 观察两种启动方式都完成 worker/recorder 认领，再用注入的拉取失败验收终态。相同测试在修复前直接返回 `recording_worker_unavailable`。
- `RECORDING-START-OWNERSHIP` 专项通过。`DeviceRecordingTests` 还覆盖未启动回滚后立即重试、超时无人认领、保护已认领会话和替换文件。本地最终二进制重复了旧版失败和两种启动的完整正向对照，两份 MP4 各 24 帧、2 秒，均通过完整解码。

2026-11-26：远端实现 `5aadd006` 已随 v0.2.47 发布，在自有 iPhone 17 上用正式制品通过本项范围的复验后 [回复并关闭](https://github.com/NeptuneKit/TritonKit/issues/285#issuecomment-7169319452)。详见 [SP-296](../SP-296-release-v0-2-47/README.md)。

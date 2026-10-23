# 2026-10-24 Resize 录制真实验收

状态：录制范围已验收并归档。关联 [SP-218 联合验收](../../SP-218-issue-222-device-hub-input/plans/20261024-live-acceptance-closeout.md)。

- 候选：安装的 v0.2.32；Sources/CLI 与基线 main `409670ef` 对应实现一致。Xcode 27.1，iOS 27.0，任务专用 iPhone 17 Simulator；Release TritonKitDemo 的 embedded runtime 为 Disabled。
- 先保存 Triton status/doctor/capabilities/schema/plan。Triton 没有 appResize start/stop 入口，官方 `devicectl device appResize start --device <owned-simulator> --preferred-size 560x874` 仅用于设置环境；由本任务控制的进程用 Ctrl+C 正常结束。
- 三段视频均通过 `triton sim record --simulator <owned-simulator> --duration 10 --output <new.mov> --json`；没有调用方填入 display UUID。active `appResize` 响应中的 deviceIdentifier/displayName/UUID/size 绑定本目标，receipt 的 recordVideo `--display` 与同次会话一致。

| 阶段 | 命令结果 | 视频轨道时长 | 解码尺寸 | 实际帧数 |
| --- | --- | --- | --- | --- |
| 普通主屏 | passed | 10.030 s | 1206×2622 | 564 |
| Resize 560×874 pt | passed | 8.533 s | 1680×2622 | 513 |
| 退出 Resize 后主屏 | passed | 9.472 s | 1206×2622 | 559 |

`ffprobe -count_frames` 以及 `ffmpeg` 抽取 1s/6s 帧证明视频可解码；人工核对是同一 Demo、计数保持 1、embedded Disabled，计时器推进。屏幕宽度随 Resize 改变，不能把 MOV 容器存在等同于有效证据。

[普通画面](../screenshots/20261024-record-normal-passed-v1.png) · [Resize 画面](../screenshots/20261024-record-resize-passed-v1.png) · [恢复主屏](../screenshots/20261024-record-restored-passed-v1.png)

反证：首次5秒普通录制实际3.67秒、低于3.75秒门槛，正确返回 `sim_record_truncated`；保留失败原件，不计成功。active Resize 的 `act tap --hid-only` 返回 `ios_simulator_resize_touch_unroutable`，业务计数未变。unknown/跨目标/伪造 display 的拒绝由离线测试覆盖，本轮不宣称全部真实注入。

私有原始日志/视频位于主工作区忽略目录 `.build/sp218-live-20261024`；仅安全 Demo 截图与摘要进入 space。本轮不复制原始设备清单/用户设备名称、绝对路径或 host 日志到公开资料。不同 Xcode/OS、AX/HID Resize routing 和用户项目均未验收，不自动进入本 space 队列。

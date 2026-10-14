# SP-200 Mobile 设备能力补齐

日期：2026-10-15

## 范围

以 `docs-linhay/dev/mobile-mcp-reference.md` 的能力差距为输入，补齐本机 iOS Simulator、Android Emulator 与 Harmony Emulator 的设备环境、录屏、诊断、归档安装、动作和终端镜像能力。用户明确排除云设备预订/释放与标准 MCP server 接入；实现继续以 CLI/HTTP 为机器入口，Web/Wails 不承载写控制。

## 已实现

- `triton device orientation|fold|location|clipboard|foreground`：读取/设置环境，保留 before/after/sourceCommands，Android 使用 ADB，iOS Simulator 使用 simctl，Harmony 保持能力边界。
- `triton device recording start|status|stop`：owner/flock/session/PID 身份绑定、唯一 MP4 预留、实际媒体 sample 时长校验；Android 对退化的一帧 `screenrecord` 自动回退为同一目标的 bounded screenshot sequence。
- `triton device logs`、`triton device crashes list|get`：bounded artifact、来源和 partial 语义；不会把 metadata 冒充报告正文。
- `.app/.zip/.ipa` 安全解包与 iOS 安装选择；拒绝路径逃逸、symlink、炸弹和多候选，原 APK/HAP/.app 路径保持兼容。
- `triton device tap|double-tap|swipe|press|type`：Android/Harmony host adapter 与 iOS Runner geometry/observation/request 绑定；未知状态不重试。
- `triton device mirror`：PNG frame capture、Kitty/Ghostty/iTerm2 protocol、坐标映射、终端清理和 read-only fallback。
- HTTP `POST /v1/device/command`：闭合集合、显式 target、bounded args、单一 CLI envelope；不暴露 worker、云 fleet 或 MCP。

## 验证

- `swift build --package-path CLI --scratch-path .build/sp200-cli --product triton` 通过。
- SP-200 focused tests：35/35 通过；Runner protocol tests：17/17 通过。
- Android Emulator `emulator-5554`：clipboard、foreground、location set/clear、logs、crashes、mirror PNG、volume key、recording 通过；录屏产出 2.9 秒 MP4。
- iOS Simulator：target discovery、location set/clear、crash listing 通过；iPhone Duo fold 返回结构化 `unsupported_device_environment`。

## 已知平台边界

- 当前 Android AVD 是竖屏锁定配置，`user-rotation` 写入成功但 WindowManager 仍返回 `ROTATION_0`，因此 orientation set 保持 `device_environment_not_verified`，不伪造成功。
- iOS 27/Xcode 27 的 `simctl pbcopy` 在本机退出码为 0 但回读为空；命令保留严格 readback，失败时输出 `device_environment_not_verified`。这是 Apple Simulator host 行为边界，不放宽验收条件。
- iOS Duo Simulator 的公开 simctl/XCTest 没有折叠角度控制；返回明确 unsupported。Harmony 录制没有稳定的 HDC 原生录屏接口，保持 `recording_unsupported`。

私有真实输出保留在 worktree 的 `.triton/SP-200-evidence`，不提交设备身份、日志正文、截图或签名信息。

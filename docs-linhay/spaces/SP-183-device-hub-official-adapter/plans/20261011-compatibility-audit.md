# SP-183 兼容与安全回归（2026-10-11）

本轮只使用匿名 JSON、fixture 命令和任务私有临时目录，没有调用真机写入、配对、诊断采集或读取业务文件内容。

## 已验证

- 新版 `devicectl` `properties` 布局和旧版 `deviceProperties` / `hardwareProperties` / `connectionProperties` 布局都能解析为同一套 iOS 真机身份、ready 状态和脱敏输出；新版字段优先，旧镜像不会覆盖未知状态。
- `device info files` 旧 envelope（缺少 `info`）仍可读取；带有 `info.commandType` 的新版 envelope 会校验命令类型、结果域和文件域，矛盾元数据保持失败。
- App 容器旧 SDK 布局没有显式路径时保持 `unavailable`，App Group 也不会从 App 名称或目录名称推断路径；只有 SDK 返回的 group ID 与路径绑定成功时才允许 `sdk-bound`。
- `systemCrashLogs` 不接受猜测的 `domainIdentifier`；Temporary 没有显式策略时仍被拒绝。
- 既有 Xcode `build --project --scheme --device --jsonl` 参数继续可解析。
- 受限 JSON reader 对文件和父目录符号链接保持 no-follow 拒绝；fixture 使用 0700 私有临时目录。

## 测试

```text
swift test --package-path CLI --no-parallel --filter CompatibilityAuditTests
4 tests / 1 suite passed
```

## 剩余风险

- 真实 SDK 版本差异仍需在获授权的专用 Simulator / fixture runner 上复验；当前没有真实 Device Hub 或真机验收证据。
- watchOS/tvOS 后端仍是研究结论，未接入 Triton 执行路径；visionOS 空间控制没有稳定的 headless 公共后端。

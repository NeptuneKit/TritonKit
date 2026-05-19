# iOS integration guide

## 背景

TritonKit 需要在仓库 README 和项目级 skill 中提供 iOS 侧接入指南，便于外部使用者和 AI agent 直接完成 SwiftPM / CocoaPods 接入、App 侧启动和 CLI 验证。

## 验收场景

### 场景 1：使用者从 README 完成 iOS 接入

- Given 使用者首次打开仓库
- When 阅读 `README.md`
- Then 能看到 SwiftPM 与 CocoaPods 的接入方式
- And 能看到 Debug-only App 启动代码
- And 能看到 CLI server 启动与 `status/list/hierarchy/ax` 验证命令
- And 能看到真机本地网络与 ATS 注意事项

### 场景 2：AI agent 从 skill 帮用户接入

- Given AI agent 使用 `tritonkit-dev-feedback` skill 帮用户试用或接入 TritonKit
- When 用户需要 iOS 侧接入指导
- Then skill 提供同样的 package manager、App bootstrap、CLI verification 和 network notes
- And 若接入过程暴露需求、bug 或文档缺口，AI agent 继续负责提交 GitHub issue

## 接入口径

1. SwiftPM：添加 `https://github.com/NeptuneKit/TritonKit.git`，选择 `TritonKit` product。
2. CocoaPods：开发阶段显式添加 `TritonKitShared` 与 `TritonKit` 两个 pod，并指向 `main` 分支。
3. App 侧：保持 `TritonKitRequestHandler` 强引用，在 `DEBUG` 下设置 `delegate`、`dataURL` 并调用 `connect(host:port:)`。
4. CLI 侧：模拟器优先 `triton serve --host 127.0.0.1 --port 19421`；真机使用 `0.0.0.0` 监听并把 `TRITON_HOST` 设为 Mac LAN IP。
5. 验证：使用 `triton status --json`、`triton list --json`、`triton hierarchy --json`、`triton ax --json`。
6. Release：public API 保持可编译，但 `TritonKit.isRuntimeEnabled == false`，runtime 不连接、不采集、不上传、不响应控制。

## 变更位置

- `README.md`
- `.agents/skills/tritonkit-dev-feedback/SKILL.md`
- `docs-linhay/dev/20260519-ios-integration-guide.md`

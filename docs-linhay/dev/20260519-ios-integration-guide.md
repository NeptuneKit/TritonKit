# iOS integration guide

## 背景

TritonKit 需要在仓库 README 和项目级 skill 中提供 iOS 侧接入指南，便于外部使用者和 AI agent 直接完成 SwiftPM / CocoaPods 接入、App 侧启动和 CLI 验证。

## 验收场景

### 场景 1：使用者从 README 完成 iOS 接入

- Given 使用者首次打开仓库
- When 阅读 `README.md`
- Then 能看到 SwiftPM 与 CocoaPods 的接入方式
- And 能看到 SwiftPM 支持 configuration-scoped build settings、但没有 CocoaPods-style Debug-only product dependency switch 的限制与替代策略
- And 能看到文件级 `#if DEBUG` 包裹的 `TritonKitDebugBootstrap.swift` 示例，并优先使用 `TritonKit.shared.start()` / `start { config in ... }` facade
- And AppDelegate / SwiftUI 入口只保留 `#if DEBUG` 调用点
- And 能看到 CLI server 启动与 `status/list/hierarchy/ax` 验证命令
- And 能看到真机本地网络与 ATS 注意事项

### 场景 2：AI agent 从 skill 帮用户接入

- Given AI agent 使用 `tritonkit-dev-feedback` skill 帮用户试用或接入 TritonKit
- When 用户需要 iOS 侧接入指导
- Then skill 提供同样的 package manager、App bootstrap、CLI verification 和 network notes
- And 若接入过程暴露需求、bug 或文档缺口，AI agent 继续负责提交 GitHub issue

## 接入口径

1. SwiftPM：添加 `https://github.com/NeptuneKit/TritonKit.git`，只选择 `TritonKit` product；`TritonKitShared` 是内部 shared-contract target，会传递解析，用户不要手动选择。SwiftPM 支持 configuration-scoped build settings，TritonKit 通过 `TRITONKIT_RUNTIME_ENABLED` 在 Debug package build 启用 runtime；但 SwiftPM / Xcode package product dependency 没有 CocoaPods 这种 `:configurations => ['Debug']` 开关，因此业务 App 源码中所有 `import TritonKit` 与启动代码仍必须由 `#if DEBUG` 显式包住。若生产 Release target 必须完全不链接 TritonKit，则使用独立 Debug-only app target / scheme，并只在那里挂 `TritonKit` product。
2. CocoaPods：开发阶段用户 Podfile 只显式添加 `TritonKit` pod，并指向 `main` 分支；Podfile 示例必须加 `:configurations => ['Debug']`，`TritonKitShared` 由 `TritonKit.podspec` 传递解析，用户不要手写。`TritonKit.podspec` 会为 pod target 的 Debug 配置定义 `TRITONKIT_RUNTIME_ENABLED`，业务 App target 不需要另写 `OTHER_SWIFT_FLAGS`。
3. App 侧：优先新建独立 `TritonKitDebugBootstrap.swift`，整个文件从 `import TritonKit` 到 `TritonKit.shared.start()` / `start { config in ... }` 都包在文件级 `#if DEBUG` 内；`start` 会内部强持有默认 `TritonKitRequestHandler`，业务侧不需要自己保存 handler。
4. 启动入口：AppDelegate、SceneDelegate 或 SwiftUI `onAppear` 只保留 `#if DEBUG` 调用点，例如 `TritonKitDebugBootstrap.start()`；不要把 TritonKit 符号散落在生产入口文件里。
5. CLI 侧：模拟器优先 `triton serve --host 127.0.0.1 --port 19421`；真机使用 `0.0.0.0` 监听并把 `TRITON_HOST` 设为 Mac LAN IP。
6. 验证：使用 `triton status --json`、`triton list --json`、`triton debug hierarchy --json`、`triton debug ax --json`。
7. Release：public API 保持可编译，但 Release package build 和 CocoaPods Release 配置都不定义 `TRITONKIT_RUNTIME_ENABLED`，因此 `TritonKit.isRuntimeEnabled == false`，runtime 不连接、不采集、不上传、不响应控制；接入示例仍必须显式 `#if DEBUG`，不能只依赖 no-op。

## 变更位置

- `README.md`
- `TritonKit.skills/tritonkit-dev-feedback/SKILL.md`
- `docs-linhay/dev/20260519-ios-integration-guide.md`
- `Examples/TritonKitDemo/TritonKitDemo/TritonKitDebugBootstrap.swift`

# CocoaPods support

## 背景

TritonKit 需要支持业务 App 通过 CocoaPods 引入 embedded runtime，同时保留现有 SwiftPM 集成方式。CocoaPods 支持只覆盖 App 内 embedded runtime 和 shared DTO，不覆盖 macOS `triton` CLI；CLI 继续通过 release artifact 分发。

## 验收场景

### 场景 1：业务 App 通过 CocoaPods 引入 TritonKit

- Given 业务 App 的 Podfile 引入 `pod 'TritonKit'`
- When CocoaPods 解析依赖
- Then `TritonKit` 会依赖同版本 `TritonKitShared`
- And Swift module 边界与 SwiftPM 一致，`import TritonKitShared` 可解析

### 场景 2：CocoaPods 集成遵守 Debug-only runtime

- Given 业务 App 通过 CocoaPods 引入 TritonKit
- When 使用 Debug 编译配置构建
- Then embedded runtime 可连接、采集、上传和响应控制
- When 使用 Release 编译配置构建
- Then package 保持可编译，但 runtime 不连接、不采集、不上传、不响应控制

### 场景 3：CI 校验 podspec

- Given 仓库新增或调整 CocoaPods 规格
- When GitHub CI 运行
- Then `TritonKitShared.podspec` 和 `TritonKit.podspec` 都必须通过 `pod lib lint`

## 规格约定

1. `TritonKitShared.podspec` 只包含 `Sources/TritonKitShared/**/*.swift`。
2. `TritonKit.podspec` 只包含 `Sources/TritonKit/**/*.swift`，并依赖同版本 `TritonKitShared`。
3. CocoaPods 不打包 `Sources/TritonKitCLI`，避免把 macOS CLI / Hummingbird / ArgumentParser 依赖带入业务 App。
4. podspec 版本暂与当前 CLI 版本保持一致：`0.1.0`。正式发布 CocoaPods 前，需要先创建对应 `v0.1.0` tag，或在发布时同步调整版本。
5. 当前项目仍处开发阶段，podspec license metadata 使用 `Custom`，正式发布前应补齐稳定 license 文件与发布策略。

## 验证命令

```bash
pod lib lint TritonKitShared.podspec --allow-warnings --skip-tests
pod lib lint TritonKit.podspec --include-podspecs=TritonKitShared.podspec --allow-warnings --skip-tests
swift test
swift test -c release
swift build -c release --target TritonKit
```

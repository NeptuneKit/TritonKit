# CocoaPods support

## 背景

TritonKit 需要支持业务 App 通过 CocoaPods 引入 embedded runtime，同时保留现有 SwiftPM 集成方式。CocoaPods 支持只覆盖 App 内 embedded runtime 和 shared DTO，不覆盖 macOS `triton` CLI；CLI 继续通过 release artifact 分发。

## 验收场景

### 场景 1：业务 App 通过 CocoaPods 引入 TritonKit

- Given 业务 App 的 Podfile 引入 `pod 'TritonKit'`
- When CocoaPods 解析依赖
- Then 业务 Podfile 只需要显式引入 `pod 'TritonKit'`
- And `TritonKit` podspec 会传递依赖同版本 `TritonKitShared`
- And 内部 Swift module 边界与 SwiftPM 一致，CLI / runtime 仍可解析 `import TritonKitShared`
- And 对外示例必须使用 `:configurations => ['Debug']`，避免 Release 配置安装 embedded runtime

### 场景 2：CocoaPods 集成遵守 Debug-only runtime

- Given 业务 App 通过 CocoaPods 引入 TritonKit
- When 使用 Debug 编译配置构建
- Then embedded runtime 可连接、采集、上传和响应控制
- And `TritonKit.podspec` 必须只为 TritonKit pod target 的 Debug 配置定义 `TRITONKIT_RUNTIME_ENABLED`
- When 使用 Release 编译配置构建
- Then Podfile 不应为 Release 安装 TritonKit runtime，业务 App 接入文件也必须由文件级 `#if DEBUG` 包住
- And `TritonKit.podspec` 不得为 Release 配置定义 `TRITONKIT_RUNTIME_ENABLED`
- And 若已有依赖解析缓存导致 pod 可编译，runtime 仍不连接、不采集、不上传、不响应控制

### 场景 3：CI 校验 podspec

- Given 仓库新增或调整 CocoaPods 规格
- When GitHub CI 运行
- Then `TritonKitShared.podspec` 和 `TritonKit.podspec` 都必须通过 `pod lib lint`

## 规格约定

1. `TritonKitShared.podspec` 只包含 `Sources/TritonKitShared/**/*.swift`。
2. `TritonKit.podspec` 只包含 `Sources/TritonKit/**/*.swift`，并依赖同版本 `TritonKitShared`。
3. CocoaPods 不打包 `Sources/TritonKitCLI`；SwiftPM 根 `Package.swift` 也不声明 CLI executable 与 CLI-only package dependencies，避免把 macOS CLI / Hummingbird / ArgumentParser 依赖带入业务 App。
4. `TritonKit.podspec` 通过 `pod_target_xcconfig` 只给 Debug 配置追加 `OTHER_SWIFT_FLAGS[config=Debug] = $(inherited) -D TRITONKIT_RUNTIME_ENABLED`；不要要求业务 App target 自行设置该宏。
5. README 与 public skill 中的用户 Podfile 示例只允许显式添加 `pod 'TritonKit'`，并加 `:configurations => ['Debug']`；不得要求用户手写 `pod 'TritonKitShared'`，该依赖由 `TritonKit.podspec` 传递解析。
6. 业务 App 侧推荐将全部 TritonKit 启动代码放入独立 `TritonKitDebugBootstrap.swift`，并用文件级 `#if DEBUG` 包住 `import TritonKit` 和 `TritonKit.shared.start()` / `start { config in ... }` 调用。
7. podspec 版本必须跟随整体 release tag。发布前 `docs-linhay/scripts/release.sh <version>` 会校验 `TritonKit.podspec`、`TritonKitShared.podspec`、`Web/package.json` 与 `Web/package-lock.json` 均等于同一个版本，避免只发布 CLI/Web 而漏掉端内包入口。
8. 当前项目仍处开发阶段，podspec license metadata 使用 `Custom`，正式发布前应补齐稳定 license 文件与发布策略。

## 验证命令

```bash
pod lib lint TritonKitShared.podspec --allow-warnings --skip-tests
pod lib lint TritonKit.podspec --include-podspecs=TritonKitShared.podspec --allow-warnings --skip-tests
swift test
swift test -c release
swift build -c release --target TritonKit
```

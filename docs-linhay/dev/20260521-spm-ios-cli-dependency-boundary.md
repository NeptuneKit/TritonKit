# SwiftPM iOS / CLI Dependency Boundary

## 背景

iOS 业务 App 通过 SwiftPM 添加 `TritonKit` library product 时，不应解析或下载 macOS CLI 专用依赖。SwiftPM 的 `dependencies` 是 package-level 入口；即使 `TritonKit` target 不依赖 `TritonKitCLI`，只要根 `Package.swift` 声明了 Hummingbird、HummingbirdWebSocket 或 ArgumentParser，consumer 解析根 manifest 时仍会看到这些 CLI-only package dependencies。

## BDD 场景

- Given 业务 App 只添加根 package 的 `TritonKit` product
- When SwiftPM 解析根 `Package.swift`
- Then 根 package 不暴露 `triton` executable product
- And 根 package 不声明 Hummingbird / HummingbirdWebSocket / ArgumentParser
- And `swift package show-dependencies --package-path .` 返回无外部依赖

- Given 维护者需要构建 macOS `triton` CLI
- When 执行 `swift build --package-path CLI --scratch-path .build/cli -c release --product triton`
- Then CLI package 独立解析 Hummingbird / HummingbirdWebSocket / ArgumentParser
- And 产物仍输出到 `.build/cli/release/triton`

## 实现约定

1. 根 `Package.swift` 只保留 `TritonKitShared` 与 `TritonKit` library products，不再声明 `TritonKitCLI` executable target。
2. `CLI/Package.swift` 是 macOS CLI 的唯一 SwiftPM manifest；它通过本地 path dependency 依赖根 package，并拥有 CLI-only package dependencies。
3. `CLI/Sources/TritonKitCLI` 是指向 `../../Sources/TritonKitCLI` 的 source shim，避免移动现有 CLI 源码和版本写入脚本。
4. 根 `Package.resolved` 删除；CLI 依赖 pins 移到 `CLI/Package.resolved`。
5. `CLI/Package.resolved` 沿用拆包前可工作的 pins，避免 `swift-websocket` 升到 1.6.0 后触发 `WSCore` 缺失 `NIOSSL` direct dependency 的构建失败。

## 验证

- `docs-linhay/scripts/verify-spm-dependency-boundary.sh`
- `swift package show-dependencies --package-path .`
- `swift test`
- `swift build --package-path CLI --scratch-path .build/cli -c release --product triton`
- `swift build -c release --target TritonKit`

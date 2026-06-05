# Debug Runtime Integration Governance

## 背景

本期围绕 TritonKit 作为业务 App Package Manager 依赖时的 Debug-only 接入边界进行治理。用户连续指出：

1. `#if DEBUG` 承诺必须在源码级接入示例中可见，不能只依赖 README 文字或库内部 Release no-op。
2. SwiftPM 并非完全不能区分 Debug / Release；可以通过 package target build settings 按 configuration 注入编译宏，但不能像 CocoaPods 一样按 configuration 条件化 product dependency。
3. LookinServer 的 SPM 方案是 package product 仍存在，包内部通过 `.when(configuration: .debug)` 注入宏启用 Debug runtime。
4. 用户接入层面不应要求显式添加 `TritonKitShared`；业务 App 用户只应添加 `TritonKit`，`TritonKitShared` 作为内部 shared-contract module / podspec 传递依赖保留。

## 目标

- 让 iOS embedded runtime 的 Debug-only 边界在代码、文档、skill 和门禁中一致可验证。
- 对齐 Lookin 风格的 SPM 包内 Debug compile flag：Debug package build 启用 runtime，Release package build no-op。
- 用户接入面只暴露 `TritonKit`，不要求用户手写 `TritonKitShared`。
- 保留内部 `TritonKitShared` module 作为 CLI / runtime / cross-platform DTO shared-contract 边界。

## 范围

### In Scope

1. `Package.swift` 为 `TritonKit` target 增加 Debug-only compile flag。
2. `Sources/TritonKit/TritonKit.swift` 从裸 `#if DEBUG` 切到包内宏，例如 `TRITONKIT_RUNTIME_ENABLED`。
3. 测试同步使用包内宏验证 Debug / Release runtime 状态。
4. README、public skills、dev docs 统一说明：
   - SwiftPM 可按 configuration 注入 build setting / compile flag；
   - SwiftPM 不能按 configuration 条件化 product dependency；
   - 用户 SwiftPM 只选 `TritonKit` product；
   - 用户 CocoaPods 只写 `pod 'TritonKit'`；
   - `TritonKitShared` 是内部 shared-contract module / 传递依赖。
5. 门禁脚本校验源码级 `#if DEBUG` bootstrap、opt-in Debug 启动、用户文档不得要求显式 `TritonKitShared`。

### Out of Scope

1. 不删除内部 `TritonKitShared` target / product / podspec。
2. 不把 shared DTO 合并进 `TritonKit` module。
3. 不改变 CLI 独立 package 依赖边界。
4. 不恢复或新增 Web/Wails UI。
5. 不发布 tag / release / Homebrew tap。

## BDD 验收场景

### 场景 1：SwiftPM Debug package build 启用 runtime

- Given 业务 App 或测试环境通过 SwiftPM 构建 `TritonKit`
- When 使用 Debug configuration
- Then `TRITONKIT_RUNTIME_ENABLED` 被定义
- And `TritonKit.isRuntimeEnabled == true`

### 场景 2：SwiftPM Release package build 禁用 runtime

- Given 业务 App 或测试环境通过 SwiftPM 构建 `TritonKit`
- When 使用 Release configuration
- Then `TRITONKIT_RUNTIME_ENABLED` 不被定义
- And `TritonKit.isRuntimeEnabled == false`
- And runtime 不连接、不采集、不上传、不响应控制

### 场景 3：业务 App 源码级 Debug bootstrap 可见

- Given README / public skill 提供 iOS 接入模板
- When 示例出现 `import TritonKit` 或 `TritonKit.shared.start(...)`
- Then 这些符号必须位于独立 `TritonKitDebugBootstrap.swift` 的文件级 `#if DEBUG` 内
- And AppDelegate / SceneDelegate / SwiftUI 入口只保留 `#if DEBUG` 调用点

### 场景 4：普通 Debug 包默认不暴露 runtime

- Given 业务 App 使用推荐模板构建 Debug 包
- When 未提供 `--triton-enabled`、`TRITON_ENABLED=1` 或 Debug-only user default
- Then `TritonKitDebugBootstrap.startIfEnabled()` 不启动 runtime
- When 显式提供 opt-in 开关
- Then runtime 按配置连接本机 `triton serve`

### 场景 5：用户不显式接入 TritonKitShared

- Given 用户阅读 SwiftPM 或 CocoaPods 接入指南
- When 添加业务 App 依赖
- Then SwiftPM 只选择 `TritonKit` product
- And CocoaPods Podfile 只显式写 `pod 'TritonKit'`
- And `TritonKitShared` 仅作为内部 module / 传递依赖出现，不作为用户手写步骤

## 相关文件

- `Package.swift`
- `Sources/TritonKit/TritonKit.swift`
- `Tests/TritonKitTests/TKPlatformFallbackTests.swift`
- `TritonKit.podspec`
- `TritonKitShared.podspec`
- `README.md`
- `TritonKit.skills/tritonkit-dev-feedback/SKILL.md`
- `TritonKit.skills/tritonkit-real-project-regression/SKILL.md`
- `docs-linhay/dev/20260519-debug-only-pm-runtime.md`
- `docs-linhay/dev/20260519-cocoapods-support.md`
- `docs-linhay/dev/20260519-ios-integration-guide.md`
- `docs-linhay/scripts/verify-ios-debug-isolation.sh`

## 当前状态

- 已完成：用户接入文档中 CocoaPods 示例改为只显式添加 `pod 'TritonKit'`。
- 已完成：public skills 同步不再要求用户手写 `TritonKitShared`。
- 已完成：`verify-ios-debug-isolation.sh` 增加用户文档禁止显式 `pod 'TritonKitShared'` 的校验。
- 已完成：`Package.swift` 引入 Lookin 风格 `TRITONKIT_RUNTIME_ENABLED` 编译宏，并同步到 `TritonKitTests`。
- 已完成：runtime / tests / docs / public skills 完整切换到包内宏口径。
- 已验证：`docs-linhay/scripts/verify-ios-debug-isolation.sh`、`docs-linhay/scripts/verify-spm-dependency-boundary.sh`、`swift test`、`swift test -c release`、`swift build -c release --target TritonKit`、`docs-linhay/scripts/check-docs.sh`、`git diff --check` 均通过。
- 已验证：完整 `docs-linhay/scripts/verify.sh --local` 通过；Xcode iOS Simulator Debug build 输出确认 `-DTRITONKIT_RUNTIME_ENABLED` 被传入 `TritonKit` target。

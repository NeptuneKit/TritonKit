# Package Manager Debug-only runtime

## 背景

TritonKit 作为 Package Manager 依赖提供给业务 App 时，embedded runtime 不应在 Release 构建中实际连接、采集或响应控制。该约束只跟编译配置有关，不跟 iOS/macOS、UIKit 是否可导入等端类型绑定。

## 验收场景

### 场景 1：Debug 构建启用 embedded runtime

- Given App 通过 Package Manager 引入 TritonKit
- When 使用 `DEBUG` 编译配置构建
- Then `TritonKit.isRuntimeEnabled == true`
- And `connect`、消息处理、hierarchy 采集和 data upload 按现有逻辑执行

### 场景 2：Release 构建禁用 embedded runtime

- Given App 通过 Package Manager 引入 TritonKit
- When 使用 Release 编译配置构建
- Then package 仍可编译通过
- And `TritonKit.isRuntimeEnabled == false`
- And runtime 不连接、不采集、不上传、不响应控制

## 实现约定

1. 用 `#if DEBUG` 定义 `TritonKit.isRuntimeEnabled`，作为 runtime 是否生效的唯一配置边界。
2. Release 下保留 public API，避免业务 App 仅因依赖存在而编译失败。
3. Release 下 runtime 行为采用 no-op 或明确错误：`connect` / `send` / reconnect / ping no-op，hierarchy 返回空数组，data upload 抛出 `TritonKitRuntimeError.disabledOutsideDebug`，request handler 返回 disabled 错误。
4. `canImport(UIKit)` 仍只用于保护 UIKit 符号可编译性，不用于决定 runtime 是否启用。

## 验证

- `swift test` 覆盖 Debug 分支，确认 `TritonKit.isRuntimeEnabled == true`。
- `swift test -c release` 覆盖 Release 分支，确认 `TritonKit.isRuntimeEnabled == false`。
- `swift build -c release --target TritonKit` 确认 Package Manager 的 Release library target 可编译。
- `swift build -c release --product triton` 确认 CLI release 产物不受影响。

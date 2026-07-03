# 20260703 Issues 133 134 Xcode Selectors

## 背景

GitHub issue #133 与 #134 都暴露了 Xcode workflow 对 agent 不够可发现的问题：

- `triton schema --command 'xcode run' --json` 不能直接返回 `run` 子命令契约。
- `triton xcode run --device 'iPhone (2)'` 不能按 `triton device list --platform ios --json` 返回的真机 `name` 解析目标。

## 范围

本轮只处理 CLI/agent 契约：

1. `schema --command` 支持一层嵌套 selector，例如 `xcode run`。
2. host device selector 支持按 `device list` 返回的 `name` 精确匹配 iOS 真机。

不新增 schema DTO、不新增 Web/Wails 入口、不改变真机 signing / provisioning 行为。

## 验收

- Given agent 查询 `triton schema --command 'xcode run' --json`
- Then 返回 `xcode` schema envelope，且 `subcommands[]` 只包含 `run`
- And `run.optionalOptions[]` 包含 `--device`

- Given `triton device list --platform ios --json` 返回 name 为 `iPhone (2)` 的 ready real device
- When `triton xcode run --device 'iPhone (2)' ...`
- Then 目标解析命中该 real device，后续 devicectl 使用其 raw identifier

## 验证

- `swift test --package-path CLI --filter SchemaFactSourceTests/schemaLookupSupportsNestedCommandSelectors`
- `swift test --package-path CLI --filter DeviceCrossPlatformTests/hostDeviceSelectorResolvesIOSRealDevicesByListedName`
- `swift test --package-path CLI --filter XcodeCommandTests`
- `CLI/.build/debug/triton schema --command 'xcode run' --json`

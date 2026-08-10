# SP-162 实施计划：UICollectionViewCell host-HID fallback

## 写入面

- `Sources/TritonKitCLI/CLIActionCommands.swift`
- `Sources/TritonKitCLI/CLICollectionCellHostHIDFallback.swift`
- `Sources/TritonKitCLI/CLIWebDeviceRuntime.swift`
- `Sources/TritonKitCLI/CLIEvidenceRuntime.swift`
- `Sources/TritonKitCLI/CLISchemaActionCommands.swift`
- `Sources/TritonKitCLI/CLISchemaOutputContracts.swift`
- `Sources/TritonKitShared/TKInputModels.swift`
- `CLI/Tests/TritonKitCLITests/CollectionCellHostHIDFallbackTests.swift`

## 验收重点

1. 缺省 flag 保持 embedded `ancestor-collection-cell-unsupported`，不调用 host adapter。
2. query/AX 已解析节点必须有 finite positive frame；fresh screen geometry 必须有效且中心在屏幕内。
3. 只允许 connected iOS Simulator（`simulatorUDID`）；host target 使用 `host:ios:<udid>`。
4. 输出 envelope 显式保留 strategy/source/fallbackFromStrategy、matched node/geometry、host source commands 与 postcondition verification boundary。
5. 注入 host runner 的单元测试不依赖真实设备、Baguette 或私有 API。

## 验证记录（2026-08-10）

- `swift test --package-path CLI --scratch-path .build/sp162-199 --filter CollectionCellHostHIDFallbackTests`：8/8 passed。
- `swift test --package-path CLI --scratch-path .build/sp162-199 --filter InputOutputTests`：4/4 passed。
- `swift test --package-path CLI --scratch-path .build/sp162-199 --filter SchemaFactSourceTests`：123 项中 5 项既有 Xcode archive/export capability/schema 缺口失败；未集成 SP-162 的基线 main 复跑结果相同。
- `swift build --package-path CLI --scratch-path .build/sp162-199-release -c release --product triton`：passed，`Build of product 'triton' complete`。
- `git diff --check`：passed。
- 未运行真实设备、Baguette、Simulator 或私有 API smoke；本期只证明机器可读合同与 fail-closed 边界。

# Remove Objective-C TritonKitCore

## 背景

`Sources/TritonKitCore` 保留了旧 Lookin Objective-C core 源码，但当前 SwiftPM、CocoaPods 和 CLI 构建入口均不引用该目录。它继续放在 `Sources/` 下会让 GitHub Linguist 把仓库统计为 Objective-C 为主，和当前 TritonKit 以 Swift runtime + Swift shared DTO + macOS CLI 为正式交付面的状态不一致。

## 验收场景

### 场景 1：仓库语言占比不再被旧 ObjC 源码主导

- Given GitHub Linguist 扫描仓库源码
- When `Sources/TritonKitCore` 不再作为已跟踪源码存在
- Then Objective-C `.m/.h` 源码不再主导语言占比
- And 仓库语言统计更接近当前 Swift 交付面

### 场景 2：现有构建与分发入口不受影响

- Given `Package.swift` 只声明 `TritonKitShared`、`TritonKit`、`TritonKitCLI`
- And CocoaPods podspec 只打包 `Sources/TritonKit/**/*.swift` 与 `Sources/TritonKitShared/**/*.swift`
- When 删除 `Sources/TritonKitCore`
- Then `swift test` 仍通过
- And `swift build -c release --product triton` 仍通过
- And `pod lib lint` 仍通过

## 处理方式

1. 删除 `Sources/TritonKitCore`，不迁移到 `docs-linhay/references/`。
2. 不新增 `.gitattributes linguist-vendored` 规则，因为目标是移除未使用旧实现，而不是隐藏仍需维护的源码。
3. 若后续需要回看旧 Lookin Objective-C core，可通过 git 历史取回。

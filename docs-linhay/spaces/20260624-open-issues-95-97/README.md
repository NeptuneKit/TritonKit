# 20260624 Open GitHub Issues 95-97

## 背景

GitHub 当前 open issues：

- #95：triton update --check --json 在 Homebrew 已是最新版本时仍报告 updateAvailable: true，且缺少明确目标版本。
- #96：CocoaPods git tag 安装 TritonKit 时无法传递解析 TritonKitShared。
- #97：triton xcode build 已能识别 swift_macro_plugin_malformed_response，但重复 fresh DerivedData 失败后仍主要建议清 DerivedData，恢复路径过窄。

## 范围

本轮处理范围限定为 CLI / CocoaPods / Xcode 诊断 / release package 表面：

1. 将 #95 的 Homebrew update latest 解析修复集成到线上基线。
2. 将 #96 的 CocoaPods 单 pod 安装修复集成到线上基线，保持业务 App 只显式依赖 TritonKit。
3. 实现 #97 的 agent-facing 诊断改进：保留 failure code，同时把恢复建议从单纯 fresh DerivedData 扩展到宏插件诊断、稳定 category 和 fallback app install/launch。
4. 对齐下一 patch release 版本并发版。

## 非范围

1. 不移动已发布 tag。
2. 不要求用户在 Podfile 中显式添加 TritonKitShared。
3. 不引入 XcodeBuildMCP 作为运行时依赖。
4. 不新增 Web/Wails 业务控制入口。

## 验收标准

### #95

- Given Homebrew 安装来源且未显式传 --version
- When 执行 triton update --check --json
- Then 不依赖 GitHub latest 解析即可给出 Homebrew update/upgrade plan
- And updateAvailable 不再表示“有可执行 update 命令”而误导为“存在更新版本”

### #96

- Given CocoaPods git/tag 安装只声明 pod 'TritonKit'
- When CocoaPods 读取 TritonKit.podspec
- Then shared 源码随 TritonKit 单 pod 编译，不需要用户手写 TritonKitShared
- And SwiftPM 仍保留 TritonKitShared module 边界

### #97

- Given xcodebuild 输出 Swift macro plugin malformed response
- When Triton 解析 xcodeDiagnostics
- Then failureCode 仍为 swift_macro_plugin_malformed_response
- And recovery / nextAction 使用稳定 category taxonomy，不再使用 recover
- And 诊断文本明确说明 repeated fresh DerivedData 后应转向 macro plugin / Xcode plugin 诊断和 artifact fallback
- And 提供 schema-backed follow-up action，避免 agent 继续循环清 DerivedData

## 验证计划

- swift test --package-path CLI --scratch-path .build/cli --filter UpdateCommandTests
- swift test --package-path CLI --scratch-path .build/cli --filter XcodeDiagnosticsTests
- swift test --package-path CLI --scratch-path .build/cli --filter SchemaFactSource
- docs-linhay/scripts/verify-ios-debug-isolation.sh
- docs-linhay/scripts/verify-release-package-versions.sh <next-version>
- docs-linhay/scripts/verify-release-automation.sh
- git diff --check
- docs-linhay/scripts/check-docs.sh
- npm --prefix Web run build
- pod lib lint TritonKit.podspec --allow-warnings --skip-tests
- TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local

## GitHub

- https://github.com/NeptuneKit/TritonKit/issues/95
- https://github.com/NeptuneKit/TritonKit/issues/96
- https://github.com/NeptuneKit/TritonKit/issues/97

# Issue #86：Xcode Swift macro malformed response 诊断

## 背景

GitHub issue #86 报告：真实 iOS 项目执行 triton xcode run --jsonl --timeout 300 时，Swift macro target NavigatorMacros 在 Triton repo-local .triton/DerivedData 构建路径下返回 malformed response，导致 external macro implementation type ... could not be found for macro ...，最终 xcodebuild_failed。

同一项目通过既有 Xcode 构建路径可以成功，使用成功构建出的 .app 再由 Triton install/launch 也可通过。因此本轮判断问题边界在 Triton Xcode build path 的诊断与恢复指引，不扩展到 Xcode IDE bridge、真机、远端 agent 或 Web/Wails UI。

## 目标

1. triton xcode build/test/run 的最终 TKXcodeActionSummary.xcodeDiagnostics 能识别 Swift macro plugin malformed response。
2. 诊断输出必须包含稳定 kind、匹配数量、样本路径、原始错误行和下一步恢复命令。
3. triton schema --command xcode --json 必须暴露该诊断类型和 --derived-data-path 恢复语义，让 agent 可机器发现。
4. 保持既有 stale DerivedData outside-root 诊断行为不回退。
5. 普通 xcodebuild 失败仍保持 xcodebuild_failed；Swift macro malformed response 输出专用 failureCode=swift_macro_plugin_malformed_response。Triton 不宣称能修复 Xcode macro plugin 本身，只提供可执行规避路径。

## BDD 场景

### 场景一：Swift macro malformed response 进入结构化诊断

- Given xcodebuild stderr 包含 external macro implementation type ... could not be found for macro ... 与 produced malformed response
- When Triton 汇总 Xcode build output diagnostics
- Then 输出 kind=swift-macro-plugin-malformed-response
- And samples[].path 指向 malformed macro executable 路径
- And recovery 明确说明 Swift macro plugin failure 与 fresh --derived-data-path
- And nextAction 指向 triton xcode build --derived-data-path <fresh-derived-data-path> --jsonl

### 场景二：普通编译错误不误判

- Given xcodebuild stderr 只有普通 Swift 编译错误
- When Triton 汇总 diagnostics
- Then 不输出 macro malformed response 诊断

### 场景三：schema 可发现恢复语义

- Given agent 查询 triton schema --command xcode --json
- When 读取 xcode.final output contract 和 failure codes
- Then 可以发现 swift_macro_plugin_malformed_response
- And --derived-data-path option description 包含 Swift macro 恢复语义

## 实现说明

- 扩展 XcodeBuildOutputDiagnosticsParser，优先解析 Swift macro malformed response，再保留 stale DerivedData outside-root 解析。
- 不改变 xcodebuild 实际调用参数、不自动清理 .triton/DerivedData，避免破坏现有增量构建缓存策略。
- 恢复指引建议使用 fresh --derived-data-path；若外部 Xcode-managed DerivedData 已能成功构建，可临时使用成功 .app 走 triton app install/launch。

## 验收

- swift test --package-path CLI --scratch-path .build/issue-86-tests --filter XcodeDiagnosticsTests
- swift test --package-path CLI --scratch-path .build/issue-86-tests --filter SchemaFactSourceTests/xcodeSchemaExposesDerivedDataCacheSemantics
- swift test --package-path CLI --scratch-path .build/issue-86-tests --filter SchemaFactSourceTests
- swift build --package-path CLI --scratch-path .build/issue-86-tests --product triton
- .build/issue-86-tests/arm64-apple-macosx/debug/triton schema --command xcode --json
- docs-linhay/scripts/check-docs.sh
- git diff --check

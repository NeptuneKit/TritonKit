# Round 01: WIP triage

## 目标

按长期计划第 1 轮要求，归因当前 `main` 上的超前提交、未提交改动和未跟踪文件，避免后续 agent-facing CLI 信息架构重排与旧 WIP 混线。

## 本轮完成

当前 worktree 被归为三组：

1. Issue 20 tap activation 收尾
   - 目标：exact / low-level tap selector 保留 matched metadata、activation metadata 和 activation strategy。
   - 主要文件：
     - `Sources/TritonKit/TKRuntimeInputActions.swift`
     - `Sources/TritonKitCLI/CLITargetingRuntime.swift`
     - `Sources/TritonKitCLI/CLIEvidenceRuntime.swift`
     - `Tests/TritonKitTests/TKAXUIKitTextTests.swift`
     - `CLI/Tests/TritonKitCLITests/InputOutputTests.swift`
     - `docs-linhay/spaces/20260522-issue-20-tap-activation/README.md`
     - `docs-linhay/memory/2026-05-26.md`

2. WebView wait 扩展
   - 目标：新增 `triton webview wait`，支持 exact text、simple `#id` selector、exact event wait，并提供 schema / error / runtime model。
   - 主要文件：
     - `Sources/TritonKitShared/TKWebViewModels.swift`
     - `Sources/TritonKit/TKRuntimeWebViewProvider.swift`
     - `Sources/TritonKit/TritonKitRequestHandler.swift`
     - `Sources/TritonKitCLI/CLIWebViewCommands.swift`
     - `Sources/TritonKitCLI/CLIWebViewRuntime.swift`
     - `Sources/TritonKitCLI/CLISchemaRuntime.swift`
     - `CLI/Tests/TritonKitCLITests/WebViewRouteTests.swift`

3. Command surface optimization 规划
   - 目标：建立新一期长期巡航 space，把方案 C 纳入当前计划。
   - 主要文件：
     - `docs-linhay/spaces/20260527-command-surface-optimization/README.md`
     - `docs-linhay/spaces/20260527-command-surface-optimization/plans/20260527-long-term-cruise-plan-v01.md`
     - `docs-linhay/memory/2026-05-27.md`

## 改动范围

当前 `git diff --stat` 显示 13 个 tracked 文件约 1171 行新增、18 行删除；另有 4 个未跟踪文件：

- `CLI/Tests/TritonKitCLITests/InputOutputTests.swift`
- `docs-linhay/memory/2026-05-26.md`
- `docs-linhay/spaces/20260527-command-surface-optimization/README.md`
- `docs-linhay/spaces/20260527-command-surface-optimization/plans/20260527-long-term-cruise-plan-v01.md`

## 验证

已通过：

```bash
swift test --package-path CLI --filter WebViewRouteTests
```

结果：`WebViewRouteTests` 14 个测试通过。

```bash
swift test --package-path CLI --filter InputOutputTests
```

结果：`InputOutputTests` 2 个测试通过。

```bash
xcodebuild -scheme TritonKit-Package -destination 'platform=iOS Simulator,id=60667794-96F8-40E6-8664-85538EC4663E' test
```

结果：`TEST SUCCEEDED`；Swift Testing 输出显示 shared model 测试 110 个通过、UIKit / WebView runtime 测试 22 个通过。

## 决策

1. 不把当前 WIP 视为单一 feature；后续提交应至少区分 issue-20 tap activation、WebView wait、command surface planning 三类。
2. Command surface optimization 规划属于当前长期目标，优先保留并作为后续执行入口。
3. WebView wait 已具备测试证据，可作为后续第 3 轮命令基线冻结中的一个重点能力。
4. Issue 20 tap activation 已具备 CLI 与 iOS runtime 测试证据，可进入收尾提交候选。

## 风险

1. 当前工作区仍未清洁，后续进入破坏性 CLI 重排前应先拆分提交或明确暂存策略。
2. `CLISchemaRuntime.swift` 同时包含 WebView wait 与 input result schema 调整，若拆提交需要按 hunk 细分。
3. 本轮未 push、未 tag、未 release。

## 下一轮建议

第 2 轮“建立本期 space 与验收边界”事实上已完成，建议下一步直接补 Round 02 checkpoint，然后进入第 3 轮“冻结当前命令面基线”。

# SP-137 #171 Safe UICollectionViewCell Tap

## 状态

- 状态：已完成（本地 checkpoint，待受控集成）。
- 负责人：Codex。
- Branch：`feat/SP-137-issue-171-safe-collection-tap`。
- Worktree：`../TritonKit-worktrees/SP-137-issue-171-safe-collection-tap/`。
- 基线：`main@0c2e38da`。

## 目标与边界

本 slice 收紧 embedded iOS runtime 的 `UICollectionViewCell` tap 语义。旧路径把 `selectItem` 与 `didSelectItemAt` 投递到下一主队列周期，却立即返回 `ok:true`，因此无法证明选择或 delegate callback 已实际完成。

包括：

- text `smart` / `ancestor` 与 coordinate 命中 collection cell 时，返回既有 `TKInputResult` 的单一 `ok:false` / `error.code=unsupported_capability` 结果；不调用 `selectItem`、`shouldSelectItemAt` 或 `didSelectItemAt`。
- 保留无敏感的 matched / activation audit metadata 与稳定 strategy；仅当前 cell 或其后代的公开 `UIControl` action / `accessibilityActivate()` 可作为真实成功，gesture 候选不得越过 cell。
- 保持 `UITableViewCell` 的同步 `willSelect -> select state -> didSelect` 成功语义不变。
- 更新 input-result schema，明确失败 `error` 合同；更新 tap schema，不再承诺 collection ancestor selection success。

不包括：

- 伪造 touch、引入 opt-in collection selection、改变 host iOS AX tap、HTTP/Web/Wails、Xcode、reliability/testrec 或 #164 WIP。
- 启动 server、Simulator、Xcode、设备或真实 `test run`。

## BDD 验收

1. Given collection label 的 text smart 命中，When runtime tap，Then 结果为 `ok:false`、`error.code=unsupported_capability`、`strategy=ancestor-collection-cell-unsupported`，且 selection/delegate 都未发生。
2. Given 同一 label 的 `ancestor` 命中，When runtime tap，Then 同样 fail closed，且不在下一主队列周期迟发 selection/delegate。
3. Given coordinate 命中 collection cell，When runtime tap，Then 同样 fail closed，不伪造 touch。
4. Given collection cell 内更近的公开 `UIControl` 或可 `accessibilityActivate()` 的 tap gesture，When smart tap，Then 返回其真实成功，且 collection delegate 未被调用。
5. Given collection cell 外层 container/window 带可 `accessibilityActivate()` 的 tap gesture，When smart 或 exact tap 命中 cell，Then 外层 activation 不被调用，结果仍为 collection `unsupported_capability`。
6. Given table cell 命中，When smart/ancestor/coordinate tap，Then 保持已存在的同步选择与 `didSelectRowAt` 成功语义。
7. Given runtime 返回 collection unsupported result，When CLI 使用 JSON 输出，Then stdout 只有一个可解码的 `TKInputResult` envelope，且命令失败退出。
8. Given agent 查询 `schema --command act`，When 检查 tap/input-result contract，Then collection fallback 标明 `unsupported_capability`，而 input result 承诺 `error` / `error.code` / `error.message`。

## 验证与停止条件

- 先补 UIKit、CLI output 和 schema 的失败测试，再最小实现。
- 使用专属 `.build/sp137-safe-collection` scratch；不与其他 SwiftPM 写入共享路径。
- BDD 红测先确认旧 schema 仍承诺 collection selection、input-result 尚未公开 `error` 字段；最小实现后以下 focused 验证通过：
  - `swift test --package-path CLI --scratch-path .build/sp137-safe-collection/cli --skip-build --filter TritonKitCLITests.InputOutputTests`：4/4；其中 collection unsupported JSON 只输出一个 envelope 并以失败退出。
  - `swift test --package-path CLI --scratch-path .build/sp137-safe-collection/cli --skip-build --filter TritonKitCLITests.WebViewRouteTests`：18/18；包含 collection/table tap schema 合同。
  - `swift test --package-path CLI --scratch-path .build/sp137-safe-collection/cli --skip-build --filter TritonKitCLITests.SchemaFactSourceTests/executionAndEvidenceSchemasExposeRecoveryCommandsAndOutputContracts`：通过。
  - 离线 `triton schema --json` 实证 `act` 的 `input.result` 包含 `error` / `error.code` / `error.message`，`act input` 列出 `unsupported_capability`。
- 当前 macOS SwiftPM 根目标会条件编译排除 UIKit runtime test：`swift test --scratch-path .build/sp137-safe-collection --filter TKAXUIKitTextTests` 编译了 TritonKit 与测试 target、但执行 0 个 UIKit test。新增 UIKit 场景保留为 iOS runtime 测试资产，不将该 0-test 结果表述为运行时证明。
- 审查修复新增外层 accessible gesture 回归，覆盖 smart 与 exact 分发路径；当前宿主同样只能完成该 UIKit test source 的编译，真实 iOS UIKit 执行留待有 UIKit test runner 的环境。
- `SchemaFactSourceTests` 全量运行仍有 12 条既有 device/proxy schema 对齐失败；新增的 execution/input-result contract 用例通过，未在本 slice 越界修复无关 registry/workflow 缺口。
- `git diff --check`、`docs-linhay/scripts/check-docs.sh` 与 `docs-linhay/scripts/verify.sh --ci-docs` 均通过。
- 未启动 server、Simulator、设备、Xcode workflow 或 `test run`；未读取、修改或整合 #164 WIP。
- 若实现需要模拟触摸、异步 selection success、改变 table/host AX 语义或扩大到 HTTP/Web，立即停止并另立 space。

# SP-149 Issue #166 Evidence Metadata Contract

> 状态：已完成（本地 checkpoint）
>
> Branch：`feat/SP-149-issue-166-evidence-metadata-contract`
>
> 基线：`main@d2578089`

## 目标

补齐 #166 JPEG → PNG normalizer 在两个剩余发布面的证据完整性：

- HTTP `GET /screenshot` 对声明/字节不一致或不可解码 JPEG 的 normalizer 失败，保持单一 `artifact_write_failed` envelope，而不是吞掉原因后报泛化 `invalid_payload`。
- `test run` observation 与 failure screenshot 的 metadata 只能描述已经写入 evidence 的 PNG artifact：固定 `format=png`、实际 bytes/path、`dataRef=nil`，不再内联或引用旧 runtime JPEG `dataBase64/dataRef`；用 `sourceFormat` 保留无 payload 的来源说明。

## 边界

- 仅改 CLI server screenshot error mapping 和 test-run evidence metadata；不改 ImageIO normalizer、embedded runtime encoder、`/web/screenshot` 真实格式透传、Web/Wails、testrec、Android 或 evidence archive 结构。
- `debug/*-screenshot.json` 从本切片起是“已发布 artifact metadata”，不是可反解码为 `TKScreenshotResponse` 的 runtime payload：消费者应读取 `format/imagePath/bytes/sourceFormat` 与对应 PNG 文件，不得依赖旧的 `dataBase64/dataRef`。这是为消除错误 JPEG 引用而作的刻意 evidence-local 契约收紧。
- `20260722-issue-164-evidence-simulator-screenshot-fidelity` dirty worktree 保持只读隔离：不读取、修改、merge、cherry-pick、reset 或删除。
- 不启动 `triton serve`、Vite、Simulator、Xcode 或真机；所有验证只用纯函数/fixture 与 Swift tests 的独立 scratch。

## BDD

1. Given `/screenshot` 收到可解析 runtime screenshot 但 PNG normalizer 拒绝 declared/magic mismatch 或不可解码 JPEG，When route 生成错误，Then HTTP 500 的单一 detail code 为 `artifact_write_failed`，保留现有 CLI diagnostic/hint；无效 JSON、base64 或 data ref 仍为 `invalid_payload`。
2. Given `test run` 将 legacy JPEG normalizer 后的 bytes 写成 `.png`，When observation 或 failure evidence metadata 被发布，Then metadata 只声明该 PNG 的 bytes/path，`dataBase64` 不存在、`dataRef` 为 nil，且不把 runtime source 伪装为已发布 artifact。
3. Given PNG runtime source，When metadata 被发布，Then 同一结构仍固定 `format=png`，并不重新引入 runtime payload/ref。

## 验收与停止条件

- 先用缺失 helper 的编译失败记录 red，再实现最窄 error/detail 与 metadata helper。
- focused 回归至少覆盖 `ObservationOutputTests`、`EvidenceBundleTests`、`TestRunExecutionTests`、`ReplayCommandTests`、`ServeCommandTests` 与 `FailureDiagnosticsTests`，均使用 `CLI/.build/sp149-issue-166-evidence-metadata-contract`。
- 若修复需要真正监听端口、修改 #164、改变 `/web/screenshot`、嵌入 SDK 或扩大 evidence schema，则停止并另行裁决。

## 实现与验证记录

- TDD red：`ObservationOutputTests` 与 `TestRunExecutionTests` 先因缺少 `serveScreenshotPayloadErrorDetail` / `testRunPublishedScreenshotMetadata` 编译失败。
- 最小实现：`/screenshot` 不再用 `try?` 合并所有失败；仅 `RuntimeScreenshotArtifactError` / `RuntimeScreenshotNormalizationError` 复用 `cliErrorDetail` 的 `artifact_write_failed`，其他 payload 获取失败保持 `invalid_payload`。test-run failure/observation 两处都经同一 published-PNG metadata helper 写出。
- 兼容性：旧的 evidence-local consumer 若把 `debug/*-screenshot.json` 直接解码为 `TKScreenshotResponse`，必须迁移为读取 PNG artifact metadata；这是必要的 fail-closed 修复，不能再暴露过期 runtime bytes/ref。
- green：`swift test --package-path CLI --scratch-path CLI/.build/sp149-issue-166-evidence-metadata-contract --filter 'ObservationOutputTests|TestRunExecutionTests'`：26/26 通过；未启动任何 runtime。
- 相关回归：同一独立 scratch 的 `ObservationOutputTests|EvidenceBundleTests|TestRunExecutionTests|ReplayCommandTests|ServeCommandTests|FailureDiagnosticsTests`：83/83 通过。
- release build：`swift build --package-path CLI --scratch-path CLI/.build/sp149-issue-166-evidence-metadata-contract-release -c release --product triton` 通过；只有既有 Simulator private-selector warning，未启动二进制或 runtime。
- `git diff --check` 通过。`docs-linhay/scripts/check-docs.sh` 与 `verify.sh --ci-docs` 都如实因 `space registry IDs must be contiguous from SP-001: SP-149-issue-166-evidence-metadata-contract` 失败：并行 SP-142～148 尚未集成；不得以占位目录、脚本放宽或重写已发布 SP-141 掩盖。

## 后续

- 验收已完成；仅创建本地 checkpoint，不合并、不推送。
- 主线集成仍须独立授权的 integration worktree；真实 iOS runtime smoke 仍需单独环境授权，不由本切片触发。

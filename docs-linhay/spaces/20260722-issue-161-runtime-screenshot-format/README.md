# GitHub Issue #161：Embedded Screenshot Format Contract

> 状态：执行
>
> GitHub：[NeptuneKit/TritonKit#161](https://github.com/NeptuneKit/TritonKit/issues/161)
>
> Branch：`feat/20260722-issue-161-runtime-screenshot-format`
>
> Worktree：`../TritonKit-worktrees/20260722-issue-161-runtime-screenshot-format/`

`docs-linhay/scripts/create-space.sh` 当前不存在，因此本 space 按固定模板直接建立并同步总索引。

## 背景

embedded runtime screenshot 返回 JPEG 数据，但 CLI/help/schema 把输出描述为 PNG，允许 JPEG magic bytes 被成功写入 `.png` 路径，导致扩展名、metadata 与真实字节不一致。

## 范围

- 明确 embedded screenshot wire format，并保证输出扩展名、magic bytes 与 metadata 一致。
- `.png` 输出应得到真实 PNG；若支持 JPEG，则只在显式、契约化的 JPEG 路径/选项下写入。
- CLI 写文件前验证或转换格式，错误时返回稳定机器可读失败，不发布伪装 artifact。
- host-side Simulator PNG 路径保持不回归。

## BDD 场景

### 场景 1：PNG 路径写入真实 PNG

- Given embedded runtime 提供 screenshot payload
- When 输出路径扩展名为 `.png`
- Then 文件 magic bytes 为 PNG
- And metadata `format` 为 `png`

### 场景 2：格式不一致不返回成功

- Given payload、扩展名和 metadata 不一致且无法安全转换
- When CLI 准备发布 artifact
- Then 返回稳定 artifact/format failure
- And 不留下伪装为 PNG 的 JPEG 文件

### 场景 3：host screenshot 不回归

- Given booted iOS Simulator host selector
- When 执行 host screenshot 到 `.png`
- Then 仍写入有效 PNG 并返回一致 metadata

## 验收门禁

- 先补 payload magic byte、extension 与 metadata 契约失败测试并确认红灯。
- focused shared/runtime/CLI tests、根包 `swift test`、release CLI build 与本地门禁通过。
- 真实 runtime smoke 前先保存 Triton-first 事实；验证文件头、metadata 与 schema，不只检查文件非空。
- 同步 README、agent 控制文档、public skills、memory 与 space 索引。

## 停止条件

三个场景、自动化/真实 smoke、main 集成与线上 CI 全部满足后评论并关闭 #161。

## 实施记录

- embedded UIKit capture 已从 JPEG 改为 PNG；`ScreenshotCapture.format` 与真实 PNG bytes 同源，空窗口 fallback 也声明 PNG。
- CLI 在原子写入前校验输出扩展名、runtime metadata 与 magic bytes；不一致统一返回 `artifact_write_failed`，不写目标文件。相同校验已覆盖 screenshot、evidence、replay 与 test-run 的 embedded `.png` artifact；HTTP/Web bridge 也不再把未校验字节硬标为 PNG。
- 格式识别与 artifact 校验集中在独立的 `CLIScreenshotRuntime.swift`，避免继续扩张巨型 action command 文件；无输出路径的 HTTP/Web payload mismatch 使用独立错误文案。
- 红灯：CLI contract tests 首先因缺失 `validateRuntimeScreenshotArtifact` / `RuntimeScreenshotArtifactError` 编译失败；实现后 Observation + Evidence focused 33 tests、Replay focused 13 tests、Simulator PNG encoding 1 test 均通过。
- Triton-first 事实：`status` 为 connected embedded runtime；`doctor` 的 server/target/runtime/host-device 检查通过；capabilities 暴露 screenshot 能力；`schema screenshot` 已声明 PNG 校验和 `artifact_write_failed`；bootstrap plan 包含 screenshot step。事实采集未保留设备、App 或 bundle 标识。
- 连接中的旧 embedded runtime smoke 返回 JPEG metadata/JPEG magic；新 CLI 稳定返回 `artifact_write_failed`，且 `/private/tmp/triton-issue-161-runtime-guard.png` 不存在，证明未发布伪装 artifact。
- host non-regression 使用 `triton sim screenshot --simulator booted` 成功，`file` 识别 PNG，magic 为 `89504e470d0a1a0a`。
- `triton xcode test` 成功进入 Simulator 全量套件，但既有并行 UIKit tests 存在共享 key-window 基线失败；`triton schema --command xcode.test --json` 未提供 `only-testing`，因此保留 missing-schema 证据后 fallback 到 `xcodebuild -only-testing:TritonKitTests/TKRuntimeScreenshotFormatTests`，定向测试通过。main 集成与线上 CI 待收口。
- 完整本地门禁 `docs-linhay/scripts/verify.sh --local` 已通过：根包 227 tests / 27 suites、release CLI build、release CLI / Harmony host / iOS runtime observe smoke、iOS Simulator build、docs structure 与 diff whitespace 均成功。结构重构后 Observation 12 tests 与 Evidence 21 tests 再次通过；main 集成与线上 CI 待收口。

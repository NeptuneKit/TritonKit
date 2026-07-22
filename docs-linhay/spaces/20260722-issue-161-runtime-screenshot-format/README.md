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

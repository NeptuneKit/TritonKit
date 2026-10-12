# SP-179 — Issue 214 DerivedData cleanup

## 范围与当前状态

新增 `triton xcode derived-data inspect` 与 `cleanup`。inspect 只读统计；cleanup 默认 dry-run。2026-10-12 安全补丁暂时禁用确认删除：`--confirm` 在任何删除前 fail closed。

**已集成并发布 v0.2.22；安全验收未收口，#214 仍 OPEN。** 本记录纠正先前会话中“全部完成”的过强结论。发布成功不是删除安全性得到证明。

## 发布事实

- 实现：`82fecb9c`；合并：`d8efddbe`；版本对齐：`468d2f13`。
- [v0.2.22](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.22)：arm64、x86_64、public skills、checksum 四项资产已复核存在。
- [Release run](https://github.com/NeptuneKit/TritonKit/actions/runs/34994714587) 与 [tag CI](https://github.com/NeptuneKit/TritonKit/actions/runs/34994714600) 均 success。
- release.sh 返回 0，报告 Homebrew tap 就绪；本轮未独立执行 Homebrew upgrade/test、资产下载校验和 packaged Web smoke，未发布 CocoaPods trunk。
- worktree `../TritonKit-worktrees/SP-179-issue-214-derived-data-cleanup` 保留；本次整理不删除分支/worktree，不移动已发布 tag。

## 验证证据边界

- 会话记录：XcodeCommandTests 47、SmokeRuntimeTests 5、XcodeSchemaParserContractTests 3 通过。
- `verify.sh --local` 通过：根包 XCTest 7 + Swift Testing 269、release CLI build、smoke、iOS Simulator build、文档与 whitespace。**不能据此推断完整 nested CLI 测试通过。**
- 最近完整 CLI 单并发记录为 984 tests / 77 suites、4 issues；后续局部修复没有完整 CLI 绿色复跑证据。
- schema 测试最后跳过了顶层 `--format/--json`，需恢复有效覆盖；还需验证 schema 转换链没有丢失递归子命令，补 JSON round-trip 和树非空断言。

## 待修与验收场景

1. 路径白名单目前用 `contains("/.triton/DerivedData")`，会接受近似名称及后代路径；改为精确路径组件和明确根目录约束，先补拒绝用例。
2. 缺少活动构建保护；当前“重解析后 removeItem”不足以证明竞态安全。补活动构建拒绝、替换竞态、权限及部分删除失败测试。
3. `directoryCount` 当前是顶层 entries 数，包含普通文件；目录 mtime 未计入；需明确并验证统计语义。
4. `errors` 固定空数组，异常直接抛出；需单一机器可读失败 envelope、稳定错误码和部分操作审计。
5. symlink 扫描跳过不等于删除时保留：递归删除父目录会移除其内部链接；文档须区分不跟随链接与不删除链接。
6. 补正式 fixture 自动化：inspect 统计、dry-run 不变、confirm 删除范围、root 保留与外部数据不变。不在真实用户缓存上做破坏性验收。

在上述安全项验证前，建议仅使用 inspect / dry-run，不推荐 `--confirm`。后续修复另发 patch，不重打 v0.2.22。issue 保持开放，不将此次整理视为关闭授权。

## 会话沉淀

见 [2026-09-16 memory](../../memory/2026-09-16.md)。单并发使用默认 build/scratch；共享 scratch 的构建串行。无需提交锁文件、生成文件或构建产物。

## 2026-10-12 安全修复切片（本地待集成）

影响层仅 CLI；独立 worktree 为 `../TritonKit-worktrees/SP-179-issue-214-derived-data-cleanup-safety`。

- 根目录白名单改成精确 `.triton` / `DerivedData` 末尾组件，拒绝近似名称和后代根目录；用户全局 Xcode 根目录仍使用完整路径比较。
- `directoryCount` 定义为非 symlink 的顶层目录数；递归普通文件逻辑大小相加为 `totalBytes`，不是实际磁盘可回收量；目录 mtime 计入 `latestModification`，不是最后使用时间。
- inspect 的条目 action 为 `inspect`；cleanup 预览条目为 `would-delete`。扫描跳过 symlink，不跟随其目标；不意味着旧版递归删除父目录会保留内部链接。
- 确认删除时，任何观测到的 Xcode lane 活动或未知状态均拒绝，稳定码 `xcode_not_idle`。即使空闲仍返回 `derived_data_cleanup_unavailable`，保证没有删除调用；安全错误与扫描/进程错误统一使用单一失败 envelope。
- 保守禁用原因：URL 校验和 removeItem 之间有 TOCTOU；FD-relative nofollow 也不能让外部 Xcode 参与缓存互斥，进程空闲快照不能阻止新构建。恢复确认删除前须明确排他策略、路径替换威胁模型和部分删除审计，补替换、权限、partial failure 注入测试。

BDD：近似/后代根目录被拒绝；dry-run 保持 cache/外部文件不变；空闲 confirm 返回 unavailable 且根/条目/外部文件不变；活动构建确认请求被拒绝；symlink 扫描不触及外部目标。

验证：`XcodeDerivedDataSafetyTests` 8 项、`XcodeSchemaParserContractTests` 3 项与 `XcodeCommandTests.derivedDataCommandContracts` 1 项，合计 12 tests / 3 suites 通过。`verify.sh --ci-docs`、`check-docs.sh`、`git diff --check` 通过。真实本轮 CLI schema 空格/点分三层 lookup 与 confirm 单一失败 envelope、fixture 文件不变通过。没有操作真实用户缓存，没有运行完整 CLI / local gate，不关闭 issue。历史大目录的实际产生调用尚无证据；默认相对路径会受调用工作目录影响，不能据此声称根项目与子项目缓存重复。

### 恢复删除前必须裁决的独占协议

1. 确定允许清理的缓存是 Triton 专用且由所有生产者共同遵守的锁保护，还是用户明确移交的脱机缓存；普通 Xcode GUI/外部 xcodebuild 不能仅靠 ps 快照证明排他。
2. 定义根目录身份固定、目录改名/替换与同用户并发写的威胁模型；采用 descriptor-relative nofollow 遍历时仍需处理已打开目录被移出根的问题。
3. 明确 intent/逐条结果/partial failure 的持久审计和失败停止行为，再覆盖权限、替换竞态、新建构建、嵌套链接及根保留测试。未满足前不恢复 removeItem 或其它删除调用。

schema 修复同时保留 normalization 各层 subcommands 递归复制，并验证嵌套 JSON round-trip，避免转换时静默丢失 cleanup 子命令。

最终补验：parent `--format/--json` 不再跳过；为实际接受这两个参数的 Xcode 叶子子命令显式声明 scope，以 `--format json` 验真实 parser。父 `derived-data` 不增虚假 flag。第三个 public real-project-regression 指南同步禁止 confirm 自动回退删除。

## 2026-10-12 本轮集成状态

安全止血已本地集成至 [SP-190](../SP-190-open-issues-integration/README.md)；完整门禁通过，远端操作待授权。保留本轮 12 tests / 3 suites 的临时 fixture 验证证据；未删除真实用户缓存。#214 仍 OPEN：本轮只禁用危险删除并修复只读检查，不能视为完整安全清理实现或竞态安全验收。

## v0.2.25 安全补丁发布

安全禁用删除及只读统计修复已发布，main CI、Release 与 Homebrew 通过。#214 保持 OPEN；merge commit 文案曾被 GitHub 识别为关闭关键字并自动关闭，发布复查已重新打开并解释安全删除仍未完成。

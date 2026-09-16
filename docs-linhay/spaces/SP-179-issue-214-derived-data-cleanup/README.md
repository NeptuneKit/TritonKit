# SP-179 — Issue 214 DerivedData cleanup

## 范围与当前状态

新增 `triton xcode derived-data inspect` 与 `cleanup`。inspect 只读统计；cleanup 默认 dry-run，显式 `--confirm` 才删除。

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

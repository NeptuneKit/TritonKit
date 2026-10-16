# SP-208 验证记录

## 基线与授权范围

2026-10-16；独立worktree SP-208，基线 `3000be924724034ceeea9722805e802c60bbb4e4`。CLI/HTTP契约中的CLI更新行为及public skill是本次候选；未变更设备/SDK/Web实现。主仓存在SP-201/SP-207等WIP，worktree仅借入SP-207索引及space目录供连续编号门禁验证，不将其作为本次实现或发布内容。

## 失败反证

- 原Homebrew check分支：针对0.2.19→0.2.29/999.0.0的latest查询场景，原实现4项期望失败（target/tag/latest缺失及updateAvailable=false）。原功能代码未改时运行，非编译失败。
- skills release校验新缝隙：原无版本检查行为的stub下，7个元数据缺失/不一致场景失败；不宣称这是归档解压/安装器安全的全量反证。
- 独立审查发现并纳入修复：非空非法tag仍会转成false；CLI成功后skills失败丢失部分完成状态；实际version envelope必须ok=true。

## 当前检查

- docs结构/经验路由（28例）、skill installer脚本（13例）及发布资源契约（9例）：通过 `verify.sh --ci-docs`。
- focused：26 tests / 3 suites通过，覆盖参数化反例；红绿细节见runtime-tests.md。
- 完整CLI：`TRITON_CLI_PATH=<本候选CLI/.build/debug/triton> swift test --package-path CLI --no-parallel`退出0，1466 Swift Testing + 59 XCTest通过。完整日志仅在本机`/tmp/sp208-cli-full.log`。
- 真实候选CLI进程 + 隔离fake brew：6场景全部通过；single JSON、非零失败、零副作用check/未确认、stale formula拒绝upgrade、wrong binary拒绝成功、正确版本通过；见process-results.json。不是用户真实安装升级。
- 只读网络check：候选未stamping开发版，使用Homebrew安装源覆盖；实际解析GitHub目标v0.2.29，零安装动作，见live-check.json。
- 独立只读审查：两项缺口修复后复核通过，未发现新的范围内阻断。
- 本地总门禁：`TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local`退出0；根包93+287 Swift Testing、Release优化编译、CLI进程smoke、Harmony host fixture smoke、iOS runtime observe fixture smoke、docs/diff均通过。UIKit条件测试与真实Xcode模拟器构建未运行，本次CLI变更不启动设备。日志本机`/tmp/sp208-local-gate.log`。

## 阶段边界

不以维护机0.2.29替代反馈用户的安装证明。实现阶段未创建Git提交；本轮按用户合并清理授权形成本地候选，尚无远端push/tag/release或用户消息发送；回复草稿位于同目录user-reply.md。当前main比origin/main含SP-206未发布改动，发布需明确联合范围，不能把本次修复自动当作那批变更的发布授权。

候选源码/测试/public skill的11个文件SHA见candidate-files.json；完整回归后未再修改这些文件。实现与验证完成；本轮形成局部候选提交，待主控合入 main，未公开发布。

## 2026-10-16 合并清理候选复核

- 候选清单11个源码/测试/public skill文件的SHA-256与当前工作区全部一致，已有完整CLI、本地总门禁证据仍绑定当前候选。
- 本轮在独立worktree默认scratch补跑更新相关focused tests，26 tests / 3 suites通过；`verify.sh --ci-docs`、`check-docs.sh`与`git diff --check`通过。docs门禁针对包含借入SP-207目录及共享索引的工作区运行，不表示局部提交独立通过编号连续性检查。
- 提交仅包含SP-208产品、直接文档/skill、SP-208空间与当日SP-208日志；借入SP-207目录、SP-201/207索引上下文及误改SP-151历史测试计数均不纳入。共享INDEX/路线登记交主控基于最新main集成，避免覆盖并行SP-201状态。
- 自动经验回看：原发布治理skill、发布契约、CLI信息契约与public update skill已沉淀版本核验边界；本轮仅核对候选隔离，无新增产品经验。

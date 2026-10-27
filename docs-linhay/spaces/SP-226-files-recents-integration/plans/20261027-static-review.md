# SP-226 静态审查与候选验收入口（冻结前历史）

当前结论见[独立验收](20261027-independent-validation.md)；以下保留收到冻结候选前的事实，不代表当前待办。

## Requested

审查 SP-225 的 CLI 只读 features/doctor 切片。Files Recents 只要求 `com.apple.searchd`；保留 Spotlight、原类别、managed labels 和默认策略。禁止将 service overrides 健康升级为 UI 可用或恢复。主控只写 SP-226，root 负责共享登记、最终 main 整合与清理。

## Observed

本次静态候选为基线 `d0ef4e4503e46386e90c1645a94b3ce03762728c`，branch `feat/SP-226-files-recents-integration`，worktree `../TritonKit-worktrees/SP-226-files-recents-integration`；开工工作区干净。尚未收到 root 明确冻结的 candidateSHA 或共享 scratch 使用时段，因此未 merge、未构建、未运行 CLI 测试、未调用缓存中的旧二进制。

- `CLISimulatorResourceCatalog.swift` 当前有 24 个 feature，无 `files-recents`；`spotlight` labels 是 `searchd/searchtoold`，search downside 尚未提及 Files/document picker Recents。
- `CLISimulatorResourceInspection.swift` 的 doctor 先 resolve requirements，再拒绝空列表，最后调用 read；只有明确 `true` 的 override 算 disabled，缺失或 false 沿用原义；结果保留 `verificationBoundary=service-overrides-only`。
- `CLISimulatorResourceCommands.swift` 的 features 分支直接序列化 catalog，不读取设备；doctor 通过 inspection 读取，健康失败打印结果后抛 ExitCode。实际单 JSON 输出仍须候选进程验证。
- 既有 catalog 测试锁定 15 个类别、24 个 feature、168 个 slimmable label、171 个 managed label；inspection 既有测试覆盖未知/空 requirement 读取前拒绝。新候选应变为 25 个 feature，其余集合保持一致，不能仅以数量相同替代集合比对。

## Evidence

2026-10-27 在上述 worktree 只读检查 Git status/HEAD、catalog/inspection/commands 与两套测试，阅读 SP-225/226、匹配治理/host/supervision skill 和经验索引。来源采用本地既有取证，不执行上游或访问设备：

- 主仓 `.build/reference-monitor/20261027/MobAI-App__simslim/commit-d961aa6d4fff29ad4727b9c052d02066f378fd16-1.json` 记录固定提交及文件 patch。
- 同目录 `source/features.go` 中 `files-recents` 只有 `com.apple.searchd`；`source/features_test.go` 明确 searchtoold disabled 仍健康、searchd disabled 报错；`source/profiles.go` 的 search downside 提示 Files/document picker Recents。
- 对同目录 `LICENSE.full` 实际执行 `shasum -a 256`，输出 `8b65667572b02a584c03c2977372eeb5fe8de0e228211b6f83033c458cc10b4e`；全文为 MIT、Copyright (c) 2026 Interlap。候选应保留 catalog 原归属及旧 sourceCommit，不将局部 feature 采用描述成整 catalog 换版。
- [固定来源评估](../../SP-207-reference-adoption-pipeline/plans/20261027-MobAI-App-simslim-review.md)与[SP-225 BDD](../../SP-225-simulator-files-recents/README.md)相符。
- 本静态文档切片的 `docs-linhay/scripts/verify.sh --ci-docs`、`docs-linhay/scripts/check-docs.sh`、`git diff --check` 均实际执行且 exit 0；文档结构登记 226 spaces。该结果不替代后续产品候选测试或 main 合后门禁。

## Gaps

当前为静态基线检查，尚无候选实现或真实红绿日志可验收；实现与独立验收均未完成。冻结后按下列门禁继续：

1. root 明确 candidateSHA 与共享缓存时段后，在本 worktree 整合该精确候选，检查完整 diff 和 dirty status；不得自行追踪浮动分支 tip。
2. 核验红测试是旧生产 catalog 上的真实行为断言失败，不能把编译失败、零测试或依赖缺失计作红；核验绿日志绑定候选、cwd、scratch、命令和退出码。
3. 独立 focused（catalog/inspection，及现有 parser/schema 对应覆盖）和完整 CLI；显式 `--scratch-path /Users/linhey/Desktop/linhay-open-sources/TritonKit/CLI/.build`、`TRITON_CLI_PATH` 指向该 scratch 的候选 debug/triton，并带 `--no-parallel --disable-automatic-resolution --skip-update`。共享缓存串行；不自动安装/更新依赖。
4. 对实际候选执行 `triton sim resource features --json`，解析完整 stdout 为单 JSON，断言 25 个 feature、唯一 files-recents 精确映射 searchd、原 24 个映射一致；比对原类别和 managed labels 集合。检查新增诊断覆盖 disabled、enabled/searchtoold-disabled、missing override、非法及空 requirement 读取前拒绝。
5. docs 三门禁：`docs-linhay/scripts/verify.sh --ci-docs`、`docs-linhay/scripts/check-docs.sh`、`git diff --check`。归档输出后再冻结审查提交，交 root 完成 main 与合后验证。

## Fixes made

仅新增本审查文档并更新 SP-226 证据导航；未修改产品、SP-225、共享索引/memory/state，未创建额外会话。

## Remaining risk

真实 Files UI、document picker 与 Simulator 均未执行；fixture 只证明服务覆盖诊断映射。未执行设备、签名/DDI、依赖安装、上游工具、远端写入或 main 合并。经验检查完成：沿用既有候选绑定、串行 scratch 和 fixture/真实验收分层规则，无新增可复用规则；共享入口由 root 收口。

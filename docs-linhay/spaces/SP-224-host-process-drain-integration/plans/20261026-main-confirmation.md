# 2026-10-26 当前主目录main复验与文档收口

用户要求“推进，并验证合到主线”。开工原目录main@5c892e2e，仅10份SP-221/SP-222文档整理WIP，无产品WIP；仅main分支和原worktree，无待验收候选或遗漏未合入分支。15条采用记录均为local_merged，逐条合并SHA是main祖先；SP-223产品合并9fbda1d5，执行25205ea2和主控1c735787均可达main。

## 独立核对

只读审计再次检查实际diff/历史引用/源码hash/原始日志hash；两批归档分别40与394份全部匹配，未丢独有证据。审计发现SP-222“只剩干净主工作区”应明确为当时清理阶段，SP-224的360份应标初始快照、最终394份，两处已直接修正。完整审计位于`.build/reference-monitor/20261026-main-confirmation/audit.md`，没有新增产品缺口或重复开发。README删除重复全文，将独有失败和关闭证据集中为SP-222历史审查；原Git对象/归档日志/hash保持不改。

## 当前main验证

- 全部CLI：`TRITON_CLI_PATH=$PWD/CLI/.build/debug/triton swift test --package-path CLI --no-parallel --disable-automatic-resolution --skip-update`，本主目录PID23004，exit0，含重新编译152.762s；XCTest91零失败，SwiftTesting1527/154suites报告通过，3项真实环境skip。日志绑定5c892e2e，产品代码与已验收候选hash匹配。
- 实际CLI四个fake-adb场景再次PASS：成功、普通exit7、未EOF exit0、未EOF exit7；单个合法JSON，未EOF明确失败且exit7事实保留、每例argv只执行一次，未连接设备。二进制hash/场景耗时见本机`cli-envelope-cases.json`。
- `verify.sh --ci-docs`、`check-docs.sh`（224spaces）、`git diff --check`通过；未重新运行与本轮文档变化无关的root/local，已有9fbda1d5离线local/root通过证据且产品未变。

[复验命令/退出与日志hash](20261026-main-confirmation/main-cli.json)、[实际CLI场景](20261026-main-confirmation/cli-envelope-cases.json)、[归档复核](20261026-main-confirmation/archive-recheck.json)、[只读审计](20261026-main-confirmation/audit.md)已保存；原始日志位于`.build/reference-monitor/20261026-main-confirmation/`；采用登记不改、剩余9仓读取partial不前移。上游增量/许可读取没有在本轮重查，不把本机验收当完整日检。真实设备、跨Xcode、真实磁盘故障等仍未验证；不push/tag/release或安装升级依赖。

## 主线收口

本轮用户明确要求推进到主线，剩余已完成且经审查的SP-221/SP-222文档整理将单独docs-only本地提交，保留当时未提交的历史事实，不混入产品候选。最终main commit与clean状态由提交后机器检查确认；文档变化不重复跑Swift，重跑docs三门禁。

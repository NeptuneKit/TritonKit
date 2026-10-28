# SP-241 — 2026-10-28 全部开放 issue 本地验收

## Requested

用户要求处理全部开放 issue。冻结 GitHub 快照为 #214、#221～232；基线 main `a0d187ac`。主工作区已有参考追踪 WIP，只读保留；各 issue 独立 space/branch/worktree，联合候选在本worktree验证。用户随后授权推送/PR，并明确授权合并及关闭已解决项；现已远端合并，未发布新版本。

## BDD 与验收

- 每个新缺陷有旧实现失败反例、最小修复和定向回归；UIKit 与设备证据单独标记。
- 已发布修复、取消范围与本轮新实现分别说明；不把开放 issue 自动当新缺陷。
- 验证联合候选的根包、完整 CLI、local、docs；单个合法失败 envelope 与 partial/来源语义。
- 索引/memory/公开文档按实际契约写回，保留每个 issue 的回复草稿与真实设备缺口。

## Observed / Evidence

本地10项缺陷候选、1项后端说明与2项范围/历史审计完成；实现整合提交 `51d505bb`。完整CLI（1563+94）、根包（401+7）、App-hosted UIKit（7）、Runner protocol（32）、Runner Simulator fixture（1）及local门禁通过。原环境未验项不冒充关闭条件。

- [逐项结果与验证边界](plans/20261028-validation.md)
- [13个未发送回复草稿](plans/20261028-issue-replies.md)
- [真实Simulator doctor与partial日志验证](plans/20261028-real-simulator.json)
- [Android旧版失败/候选通过反证](plans/20261028-cli-blackbox-red-green.json)

当前已合并[PR #233](https://github.com/NeptuneKit/TritonKit/pull/233)，merge `40850dde`；#221～232共12项completed关闭，#214保留原始来源/占用调查并写明只读计划。详细当前状态、评论链接与CI见[合并归档报告](plans/20261028-merge-closeout.md)。原主目录WIP保留；归档工作分支为 `codex/issue-233-closeout`，本批次没有发布。


## Gaps / Remaining risk

物理 iOS、Android 慢启动和 UIAutomator 故障场景需要区分 fixture 与原设备复验。#214 通用删除已取消，不恢复删除；#222 有 v0.2.33 真实验收历史，重新核对当前代码和剩余反馈。

发布接替：本批修复已随[v0.2.35 / SP-242](../SP-242-release-v0-2-35/README.md)公开；本space旧记录的“未发布”保留当时阶段含义，当前以SP-242发布及受限验收记录为准。

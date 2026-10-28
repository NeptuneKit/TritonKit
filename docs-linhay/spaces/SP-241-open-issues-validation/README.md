# SP-241 — 2026-10-28 全部开放 issue 本地验收

## Requested

用户要求处理全部开放 issue。冻结 GitHub 快照为 #214、#221～232；基线 main `a0d187ac`。主工作区已有参考追踪 WIP，只读保留；各 issue 独立 space/branch/worktree，联合候选在本 worktree 验证，不合 main、不写远端。

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

原主目录WIP未改动，候选只在本地分支，远端13项仍OPEN。下一步为用户审阅并明确授权远端推送/PR；本轮没有该授权。

## Gaps / Remaining risk

物理 iOS、Android 慢启动和 UIAutomator 故障场景需要区分 fixture 与原设备复验。#214 通用删除已取消，不恢复删除；#222 有 v0.2.33 真实验收历史，重新核对当前代码和剩余反馈。

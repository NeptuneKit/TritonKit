# SP-241 — 2026-10-28 全部开放 issue 本地验收

## Requested

用户要求处理全部开放 issue。冻结 GitHub 快照为 #214、#221～232；基线 main `a0d187ac`。主工作区已有参考追踪 WIP，只读保留；各 issue 独立 space/branch/worktree，联合候选在本 worktree 验证，不合 main、不写远端。

## BDD 与验收

- 每个新缺陷有旧实现失败反例、最小修复和定向回归；UIKit 与设备证据单独标记。
- 已发布修复、取消范围与本轮新实现分别说明；不把开放 issue 自动当新缺陷。
- 验证联合候选的根包、完整 CLI、local、docs；单个合法失败 envelope 与 partial/来源语义。
- 索引/memory/公开文档按实际契约写回，保留每个 issue 的回复草稿与真实设备缺口。

## Observed / Evidence

进行中。#226 已有独立提交 `5a7faf0c`；其余候选逐项冻结后汇入本验收分支。远端全部仍 OPEN，未发布。

## Gaps / Remaining risk

物理 iOS、Android 慢启动和 UIAutomator 故障场景需要区分 fixture 与原设备复验。#214 通用删除已取消，不恢复删除；#222 有 v0.2.33 真实验收历史，重新核对当前代码和剩余反馈。

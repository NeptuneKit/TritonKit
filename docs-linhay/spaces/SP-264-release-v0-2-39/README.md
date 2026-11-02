# SP-264 v0.2.39 issue交付发布

## 当前状态

准备发布；无新tag或Release。2026-11-02本轮十一项独立修复（SP256/258–263、265–268）已合入main，精确CI与联合CLI/root/Web/local门禁通过。发布前增量巡查新增closed #204的受控textarea反馈，已立[SP269](../SP-269-issue-204-controlled-input/README.md)独立调查并补必要验证；不能用此前候选门禁代替新增差异门禁。#246依赖人工IME许可的正向验收排除，保留成果，不安排人工步骤；本流程不关闭issue。

## BDD与边界

- Given已复审的CLI/schema/parser/诊断与skills修复，Then组合CLI/root/Web测试、完整local preflight、标准CocoaPods lint、文档和精确main CI通过。
- Given版本0.2.38，When准备0.2.39，Then先记录目标版本RED，再同步podspec/Web两manifest；CLI/skills由tag stamp。
- Given新公开制品，Then双架构/checksum/skills/Web/tag一致，Homebrew与两处skills安装验收、包外只读Web及自有三端预览通过。
- 诊断改善不等于原私有项目构建恢复，schema元数据不授予执行权限；#224 iPad默认截图/输入缺口、#214暂缓保持。

## 隔离与证据

候选分支`feat/SP-264-release-v0-2-39`复用本聊天隔离SP256 warm worktree（`/Users/linhey/.codex/worktrees/sp-256-issue-245-compact-schema/TritonKit`）；实际tag发布复用本聊天既有、干净的同级独立main克隆`../TritonKit-worktrees/SP-250-release-v0-2-37-publish`（使用前快进到最终远端main；旧名称不代表本轮版本），避免触碰主目录WIP及main占用。构建、Git和设备动作主控串行。

[发布验收](plans/20261102-release.md)，原始证据在同级`archives/SP256`与`archives/SP264`。CocoaPods标准lint与trunk发布分别报告。

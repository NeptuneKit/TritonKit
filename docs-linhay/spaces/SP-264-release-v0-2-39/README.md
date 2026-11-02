# SP-264 v0.2.39 issue交付发布

## 当前状态

准备发布；无新tag或Release。2026-11-02追加全量并行复核，SP265–268纳入同一未发布候选，待重新跑受影响门禁后发布。候选包含#245/#247/#248/#249/#250/#251/#252独立提交，必要组合回归与精确CI通过后依次合并，再发布。#246依赖人工IME许可的正向验收排除，保留成果，不安排人工步骤；所有issue保持开放。

## BDD与边界

- Given已复审的CLI/schema/parser/诊断与skills修复，Then组合CLI/root/Web测试、完整local preflight、标准CocoaPods lint、文档和精确main CI通过。
- Given版本0.2.38，When准备0.2.39，Then先记录目标版本RED，再同步podspec/Web两manifest；CLI/skills由tag stamp。
- Given新公开制品，Then双架构/checksum/skills/Web/tag一致，Homebrew与两处skills安装验收、包外只读Web及自有三端预览通过。
- 诊断改善不等于原私有项目构建恢复，schema元数据不授予执行权限；#224 iPad默认截图/输入缺口、#214暂缓保持。

## 隔离与证据

候选分支`feat/SP-264-release-v0-2-39`复用本聊天隔离SP256 warm worktree（`/Users/linhey/.codex/worktrees/sp-256-issue-245-compact-schema/TritonKit`）；实际tag发布在同级独立main克隆`../TritonKit-worktrees/SP-264-release-v0-2-39-publish`，避免触碰主目录WIP及main占用。构建、Git和设备动作主控串行。

[发布验收](plans/20261102-release.md)，原始证据在同级`archives/SP256`与`archives/SP264`。CocoaPods标准lint与trunk发布分别报告。

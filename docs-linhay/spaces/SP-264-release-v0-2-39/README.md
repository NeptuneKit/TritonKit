# SP-264 v0.2.39 issue交付发布

## 当前状态

十二项独立修复（SP256、SP258–263、SP265–269）已随 [v0.2.39](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.39) 正式发布（2026-11-02 14:57:32 UTC），发布提交/tag `026d329e5346fce77ae62a2828e3d27ed2d94c2e`。最终 PR #268 head `7ab6de0654936870370594ea8cb18373432e7583` 与合并整树/762文件hash一致，本地完整门禁、main/tag/Release CI与标准Pod lint通过。正式双架构CLI/checksums/skills/嵌入Web、Homebrew安装和两处skills更新、安装版23项只读CLI smoke通过；公开安装版三端 HTTP/浏览器预览通过，自有资源已清理。

发布脚本因runner排队约10分钟叠加后续构建导致观察期超时退出1，远端随后完成全部发布工作，保留失败日志且未重建/移动tag。Homebrew默认cleanup移除了仍由共享旧serve使用的0.2.38文件，已从已验证旧公开包恢复42个runtime文件；共享进程与新版本symlink保持，状态仍可达。后续升级禁用自动cleanup的规则已写入发布skill，详见验收报告。

#246 依赖人工 IME 许可的正向验收排除，保留成果与失败；#214 暂缓、#224 iPad 默认截图/输入及原私有 App 未验证边界保留，不安排人工接手，不修改 issue 状态。

## BDD与边界

- Given已复审的CLI/schema/parser/诊断与skills修复，Then组合CLI/root/Web测试、完整local preflight、标准CocoaPods lint、文档和精确main CI通过。
- Given版本0.2.38，When准备0.2.39，Then先记录目标版本RED，再同步podspec/Web两manifest；CLI/skills由tag stamp。
- Given新公开制品，Then双架构/checksum/skills/Web/tag一致，Homebrew与两处skills安装验收、包外只读Web及自有三端预览通过。
- 诊断改善不等于原私有项目构建恢复，schema元数据不授予执行权限；#224 iPad默认截图/输入缺口、#214暂缓保持。

## 隔离与证据

版本准备分支`feat/SP-264-release-v0-2-39`与当前文档收尾分支`codex/sp264-release039-closeout`复用本聊天隔离SP256 warm worktree（`/Users/linhey/.codex/worktrees/sp-256-issue-245-compact-schema/TritonKit`）；实际tag发布复用本聊天既有、干净的同级独立main克隆`../TritonKit-worktrees/SP-250-release-v0-2-37-publish`（使用前快进到最终远端main；旧名称不代表本轮版本），避免触碰主目录WIP及main占用。构建、Git和设备动作主控串行。

[发布验收](plans/20261102-release.md)，原始证据在同级`archives/SP256`与`archives/SP264`。CocoaPods标准lint与trunk发布分别报告。


本轮源码、正式发布、安装与 agent 可独立完成的真实验收已闭环。[文档收尾 PR #269](https://github.com/NeptuneKit/TritonKit/pull/269) 已合并为 `b99474ca54bdaeaf4c604a01c2e54b10a252c906`，候选 CI `41471241336` 与合并后 CI `41471520249` 均通过。后续文档记录不改变发布 tag；最新 main 以 GitHub 为准。公开预览证据与 iOS 后端直接观测限制均见发布验收报告。

# SP-242 · v0.2.35 完整发布

当前状态：v0.2.35已发布，tag=190c161f。双架构资产、Homebrew与包外只读HTTP验收通过；默认浏览器实时流受本机Resize Mode未知限制，仅工作台布局零console error，完整边界见发布验收。GitHub当前只有#214开放且用户明确暂缓。

## 范围与授权

用户已明确授权“继续完成验证，通过后直接发布v0.2.35；#214保持开放，主工作区未提交改动不要带入发布”。本版本交付PR #233已合并的CLI/HTTP、UIKit runtime、host adapter与iOS Runner修复，及后续调查文档；#214保持OPEN，不宣称缓存来源已确认或实现安全自动清理。对齐CLI、bundled Web、public skills、CocoaPods podspec与SwiftPM tag；CocoaPods只lint，不推trunk。

准备branch为codex/release-v0.2.35，复用../TritonKit-worktrees/SP-241-open-issues-validation的已集成候选及构建缓存。主目录main仍有另一任务WIP，不移动/重置/提交它。发布脚本要求干净且同步的main，最终使用同级独立克隆../TritonKit-worktrees/SP-242-release-v0-2-35，以相同远端候选SHA执行发布，保持原主目录WIP不变。该隔离克隆不是共享main分支的worktree。

## BDD / 验收

- Given当前0.2.34 manifests，When版本门禁目标0.2.35，Then先失败，再更新三个版本文件通过，不手改CLI build info。
- Given固定源码候选，When串行运行根包/CLI/Web及本地总门禁，Then保留实际结果和fixture/真实验收边界；本机pod最低版本不兼容不能伪装成标准lint通过，须等待同候选远端标准lint。
- Given本机Xcode27.1与Swift6.4，Then复用native/jobs=2调度wrapper避免swiftbuild过载，所有共享scratch构建串行；可选裸Xcode门禁不重复执行，由现有同源码UIKit/Runner真实验收证据及本轮pod编译覆盖说明。
- Given干净且同步的发布克隆main，When发布v0.2.35，Thenarm64/x86_64 CLI、bundled Web、skill包与checksum齐全，双架构Release与tap更新通过。
- Given公开下载及Homebrew安装，Then核对checksum、架构、CLI/skills版本；仓库外packaged Web完整静态资源和405只读契约、真实浏览器零console error通过。

## 证据

原始本地日志位于准备worktree的ignored `.build/release-0.2.35/`。验证与发布结果在plans中记录。既有实现验收与限制见[SP-241](../SP-241-open-issues-validation/plans/20261028-validation.md)，缓存调查保留见[SP-240](../SP-240-issue-214-deriveddata-ownership/README.md)。

- [发布验收记录](plans/20261028-release.md)

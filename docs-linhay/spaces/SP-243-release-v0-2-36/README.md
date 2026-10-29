# SP-243 · v0.2.36 发布

当前状态：v0.2.36 已发布，tag=527b2368；main/tag CI、Release 双架构、Homebrew、包外只读 Web 验收通过；浏览器流为黑图，内容正确性未验证。用户授权 main CI 通过后发布 v0.2.36；#224、#214 保持 OPEN，主工作区未提交改动不带入。

## 范围与隔离

基线 main f1d7b93b，合并与整理 CI 均已通过。本版交付 PR #236：目标绑定的 Resize capability rejection 诊断，以及显式 `sim screenshot --primary-framebuffer` 单主屏静态截图。iPad 默认截图、输入和实时流限制仍保留，不宣称 #224 全部解决；#214 缓存来源未知继续暂缓。

准备使用 SP-241 隔离 worktree 的 codex/release-v0.2.36 分支和既有缓存，最终发布从同级 SP-243-release-v0-2-36 独立克隆 main 执行。原主目录 HEAD/status/17 个 WIP 文件先保存哈希，收尾复核；不 stash/reset/pull 主目录。

## BDD 与验收

- Given 0.2.35 manifests，When 验证目标 0.2.36，Then 先失败，再仅对齐 podspec/Web 版本通过；CLI 版本由 tag CI 注入。
- Given 固定候选，When 本地总门禁、Web build、skills/contracts、CocoaPods 检查及 main CI，Then 真实记录通过/失败/跳过，不用当前工具链兼容 lint 替代原 minimum 验证。
- Given 已通过 main CI 的干净同步克隆，When release.sh 发布，Then 双架构 CLI、Web、public skills、checksum、Homebrew 同版可用，已发布 tag 不移动。
- Given 仓库外安装版，Then mode=packaged、readonly=true、静态资源、完整手势 DTO 的只读拒绝与真实浏览器验收；#224 默认流限制单列。
- Then #224/#214 保持 OPEN，原主目录 WIP 字节不变，CocoaPods 只 lint、不推 trunk。

## 证据

原始日志在准备 worktree ignored `.build/release-0.2.36/`。既有源码验收见 [SP-235](../SP-235-issue-224-simulator-resize-query/plans/20261028-primary-framebuffer.md)，本次 [发布记录](plans/20261029-release.md)。

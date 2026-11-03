# SP-272 — v0.2.40 发布

## 当前状态

本地preflight/Release fixture、159 Web串行测试、版本/skills门禁通过；标准本机Pod因工具链最低版本限制失败，等待精确CI标准Pod门禁。完整记录见[发布报告](plans/20261103-release.md)。

准备中，版本RED已确认0.2.39 manifests不满足0.2.40。只纳入SP271 direct runtime诊断修复；尚待issue候选验收、审阅、合并、版本PR及完整发布门禁。未创建tag或Release。复用独立publish clone SP-250-release-v0-2-37-publish，分支feat/SP-272-release-v0-2-40；不碰主目录其他WIP。

## BDD与边界

Given精确main含已验收SP271，When版本文件与完整local/CI/标准Pod门禁通过，Then新tag不可移动，双架构CLI/checksum/Web/Runner/skills来源一致；Homebrew/双skills安装与仓库外packaged HTTP/browser验收通过。shared旧038服务保持，升级使用HOMEBREW_NO_INSTALL_CLEANUP=1。

CLI诊断修复不证明真实App DOM provider可用；#214暂停、#224 iPad/HID及iOS直接capture观测null、#246人工IME依赖和原私有App人工部分历史未知保留。SP270独立Lookin候选不包含。CocoaPods标准lint与trunk发布分别报告。

## 证据与分工

同级archives/SP272保存新版本证据，SP264旧证据只作脚本来源，不替代040验收。主控负责版本、CI、tag、资产/安装与Git串行；release_acceptance只负责明确窗口内自有三端preview及清理。

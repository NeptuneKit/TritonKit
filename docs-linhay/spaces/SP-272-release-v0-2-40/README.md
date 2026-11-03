# SP-272 — v0.2.40 发布

## 当前状态

本地preflight/Release fixture、159 Web串行测试、版本/skills门禁通过；标准本机Pod因工具链最低版本限制失败，等待精确CI标准Pod门禁。完整记录见[发布报告](plans/20261103-release.md)。

候选已完成版本门禁与合并：SP271 direct runtime诊断、SP273/#274显式推理、SP270/#273 Lookin核心集成均已通过精确PR CI并进入 main；v0.2.40 已正式发布；收尾验收与分发结果见下文。复用独立publish clone SP-250-release-v0-2-37-publish，分支feat/SP-272-release-v0-2-40；不碰主目录其他WIP。

## BDD与边界

Given精确main含已验收SP271，When版本文件与完整local/CI/标准Pod门禁通过，Then新tag不可移动，双架构CLI/checksum/Web/Runner/skills来源一致；Homebrew/双skills安装与仓库外packaged HTTP/browser验收通过。shared旧038服务保持，升级使用HOMEBREW_NO_INSTALL_CLEANUP=1。

CLI诊断修复不证明真实App DOM provider可用；#214暂停、#224 iPad/HID及iOS直接capture观测null、#246人工IME依赖和原私有App人工部分历史未知保留。SP270 Lookin核心已通过 PR #276 合入 main（merge `3b82824333467cf6d4e148cba04a97b3f70705aa`）；其原私有 App / iOS 13 本机工具链缺口仍按边界记录。CocoaPods标准lint与trunk发布分别报告。

## 证据与分工

同级archives/SP272保存新版本证据，SP264旧证据只作脚本来源，不替代040验收。主控负责版本、CI、tag、资产/安装与Git串行；release_acceptance只负责明确窗口内自有三端preview及清理。


## v0.2.40 已发布

- 精确发布 SHA：`232749b361402bbbcfbf0944f5a9e20e139fc012`；tag `v0.2.40` 不移动。
- GitHub Release：<https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.40>；Release run `41611235642` 的 arm64/x86_64、skills、checksum 与 Homebrew 更新均成功。
- 新鲜下载的双架构 tarball 与 `tritonkit-skills.tar.gz` 均按 `tritonkit_checksums.txt` 校验通过；skills `BUILD_INFO.json` 为 0.2.40、tag 与精确 SHA。
- 发布后二进制 `triton version --json` 为 0.2.40；仓库外 packaged Web 端口 34129 返回 HTML 200、`mode=packaged`，只读写入口返回 `405/web_host_input_readonly`。
- Homebrew 远端配方、`brew update`、`HOMEBREW_NO_INSTALL_CLEANUP=1 brew upgrade`、`brew test` 与安装版 `triton version --json` 均通过；CocoaPods 只做标准 lint，未推 trunk。
- Web 完整绑定 CLI 串行测试 `174/174`，设计构建和本地总门禁通过。

# SP-275 — v0.2.41 发布

## 边界

发布包含 PR #278 合并后的 #277 Host input 门控修复。版本 surfaces 必须对齐：CLI、嵌入 Web、公开 skills、双架构 checksum、Homebrew、TritonKit.podspec 与 Web manifests。

真实 Simulator tap/capture、iPad 默认截图/HID、原私有 App 和人工 IME 仍按主流程范围外或未知记录，不以本版本发布替代这些验收。

## BDD

- Given v0.2.40 已发布且 tag 不可移动，When 0.2.41 版本文件与完整 preflight 通过，Then 创建新的不可移动 v0.2.41 tag。
- Given #277 精确修复已在 main 且 main CI 通过，When Release 资产、skills、Homebrew、packaged Web 与安装版复验，Then 所有公开包 surfaces 使用同一版本与 SHA。
- CocoaPods 仅执行标准 lint，是否推 trunk 单独报告。

## 验收记录

- 版本预检：旧 manifests 对 0.2.41 按治理要求失败；升级后需重新验证。
- #277 focused/full CLI、PR CI 与合并后 main CI 已通过。
- 发布前版本、自动化、docs、skills 与 Web build 通过；标准本机 Pod lint 受 Xcode 27.1/iOS 13 工具链边界阻断，兼容 iOS 15 lint 输出 `TritonKit passed validation.`，远端标准 Pod 仍为必需门禁。
- 已发布：tag `v0.2.41` 固定在 annotated tag 对象 `c1813c86894a0ede924abb883f020adcc2e5b2c5`，其发布提交为 `b0b930f22bc844afcdb388314e7bc5bd1a74cded`；Release workflow `42208417275` 与合并后 main CI `42204768309` 全部成功。
- 新鲜下载的 arm64/x86_64 CLI、skills archive 与 checksum manifest 校验一致；skills `BUILD_INFO.json` 为 0.2.41、tag `v0.2.41`、commit `b0b930f2…`。
- 远端 Homebrew formula 已更新到 0.2.41；`HOMEBREW_NO_INSTALL_CLEANUP=1 brew update/upgrade/test`、安装版 `triton version --json` 与双 skills roots 更新通过。共享 19421/PID 12522 仍运行旧 0.2.40，未重启。
- 仓库外 packaged Web plan 为 `mode=packaged`/`readonly=true`；34129 HTTP 首页 200，`/web/host-input?readonly=true` 返回 405 `web_host_input_readonly`。
- CocoaPods 仅执行 lint，远端标准 Pod CI 通过，未推 trunk；不得宣称真实 Simulator、iPad 默认截图/HID 或原私有 App 恢复。

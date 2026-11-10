# SP-275 v0.2.41 release plan

1. 在精确 main `ab595ef76274c995827c75c0b7e3e2da91e11d73` 上更新 podspec、Web package manifests 与发布文档。
2. 运行版本、自动化、docs、Web build、标准 CocoaPods lint、skills package 和 `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local` 门禁。
3. 提交发布候选到 main，等待该 SHA 的完整 main CI 与标准 Pod lint。
4. 运行 `docs-linhay/scripts/release.sh v0.2.41 --yes`，等待 Release workflow、双架构资产、skills、checksum 与 Homebrew。
5. 下载新鲜资产、校验 checksum/BUILD_INFO，验证 Homebrew 安装升级和仓库外 packaged Web HTTP/浏览器 smoke；记录人工依赖验收仍未知。

## 当前门禁证据

- 版本一致性、release automation、docs、skills、`git diff --check` 与 Web build 通过；Web 首次缺少隔离 worktree 依赖，`npm ci` 后重跑通过。
- 本机标准 `pod lib lint` 因 Xcode 27.1 不接受产品 iOS 13 Simulator deployment target 失败；使用临时 `XCODE_XCCONFIG_FILE` 将本次兼容 lint 目标设为 iOS 15 后通过并输出 `TritonKit passed validation.`。这不替代远端标准 Pod 门禁，也不改变产品最低版本。
- 合并后 main CI run `42195826858` 全部成功；发布候选提交后必须重新等待精确 SHA 的 main CI。

## 发布结果

- 发布提交 `b0b930f22bc844afcdb388314e7bc5bd1a74cded` 的主线 CI `42204768309` 成功；tag push 触发的 CI `42208417277` 与 Release `42208417275` 成功。
- `v0.2.41` 不移动；GitHub Release 资产为 arm64/x86_64 CLI、`tritonkit-skills.tar.gz`、`tritonkit_checksums.txt`，新鲜下载后逐项 checksum 一致。
- Homebrew 远端 formula、升级与 test 通过；安装版 CLI 与两个 agent skill roots 均为 0.2.41。共享 19421 服务保留旧进程，不纳入升级重启。
- packaged Web 从仓库外启动，plan 明确 `mode=packaged`；首页 HTTP 200，readonly host-input 返回 405 `web_host_input_readonly`。真实设备/私有 App 依赖人工部分仍是范围外或未知。

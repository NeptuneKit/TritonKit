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

---
name: tritonkit-release-package-governance
description: Use when preparing or publishing a TritonKit release, especially when the user says the release must be whole, asks about updating built-in packages across endpoints, or touches CLI/Homebrew/Web/SwiftPM/CocoaPods/public skill package version alignment.
metadata:
  version: 0.1.0-dev
---

# TritonKit Release Package Governance

开工与交付按[经验索引](../../../docs-linhay/memory/EXPERIENCE.md)只读命中主题，未命中再检索；读取、证据、修订与退出遵循[治理闭环](../../../docs-linhay/dev/20260619-agent-workflow-skill-governance.md)。

Use this skill for maintainer-side release work. It is an internal `.agents/skills/` workflow and must not be packaged into `TritonKit.skills/`.

## Release Boundary

A whole TritonKit release means these public package surfaces are aligned to the same tag version:

- CLI binary release assets and `triton version --json` output, stamped by CI from the `v*` tag.
- Bundled Web asset inside the CLI tarballs and Homebrew install.
- Public skill bundle `tritonkit-skills.tar.gz`, stamped by CI from the `v*` tag.
- iOS embedded SDK CocoaPods spec: `TritonKit.podspec`.
- Web package manifests: `Web/package.json` and `Web/package-lock.json`.

SwiftPM has no version field in `Package.swift`; consumers update by resolving the Git tag. Do not add a package version field to SwiftPM manifests.

## Required Workflow

1. Pick the next tag. If a tag has already been published, never move it; create the next patch release.
2. Before changing versions, run `docs-linhay/scripts/verify-release-package-versions.sh <version>` to prove the current manifests would fail for the target.
3. Update `TritonKit.podspec`, `Web/package.json`, and `Web/package-lock.json`.
4. Do not manually edit `Sources/TritonKitCLI/CLIBuildInfo.swift` for a release version. CI writes `TritonKitBuildInfo.cliVersion` during release builds.
5. Run focused validation:
   - `docs-linhay/scripts/verify-release-package-versions.sh <version>`
   - `docs-linhay/scripts/verify-release-automation.sh`
   - `git diff --check`
   - `docs-linhay/scripts/check-docs.sh`
   - `npm --prefix Web run build`
   - `pod lib lint TritonKit.podspec --allow-warnings --skip-tests`
   - `docs-linhay/scripts/verify-skill-package.sh`; public skill Markdown commands must pass `verify-public-skill-commands.py`, and `public-skill-command-schema.json` must remain aligned with CLI `commandSchemas()`.
   Run multiple gates fail-fast (`set -e` or one command per checked invocation). Do not treat the final command's zero exit as proof that earlier gates passed. For CocoaPods, require both a zero exit and the explicit `TritonKit passed validation.` result; compiler errors printed before a later successful command remain release blockers.
6. Run release preflight with Xcode simulator checks disabled only when the local environment does not need that coverage: `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local`.
7. Update `docs-linhay/dev/` and `docs-linhay/memory/YYYY-MM-DD.md` for release contract changes.
8. Commit and push `main`, then publish through `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/release.sh v<version> --yes`.
9. After release, verify GitHub Release assets, GitHub Actions success including x86_64 backfill, Homebrew upgrade, `triton version --json`, packaged `triton web --print-command --json`, and a real `triton web` HTTP smoke.
   - If the release changes Web input routing, the smoke must POST the same complete gesture DTO used by the Web client. Coordinate taps include `x`, `y`, `width`, and `height`; an intentionally incomplete probe may return a contract error but is not success evidence.
   - Run the installed packaged binary from outside the repository on an isolated port first. When handing the canonical Web port back to another task, resolve and replace only that listener; preserve the shared `triton serve`, Simulator/Emulator, and App processes unless their owner explicitly authorizes a restart.
   - Follow the current space contract: for readonly Web, require `readonly=true`, HTML/JS/CSS success, complete gesture DTO rejection with `405/web_host_input_readonly`, and a real browser with zero console errors. Only an explicitly authorized write-capable product surface requires machine-readable input success and visible gesture status; do not restore a retired write bridge to satisfy historical smoke instructions. A homepage HTTP 200 alone is insufficient.

## Recovery Rules

- If the installed Xcode rejects the podspec's minimum deployment target, preserve the failed standard lint and do not raise the product minimum just to pass validation. A private `XCODE_XCCONFIG_FILE` may set a supported target for a separately labeled current-toolchain compatibility lint; require exit zero and `TritonKit passed validation.` there too. This does not validate the original minimum. Keep original-minimum validation on a compatible Xcode as an explicit pre-publication blocker.
- If the wrong tag was pushed but GitHub Release has not been created, cancel only that superseded release workflow, delete the mistaken local and remote tag, correct version manifests on `main`, commit, push, and publish the intended tag. Do not cancel a valid current release workflow.
- If `release.sh` reports that GitHub Actions completed before assets were visible, treat it as a possible observation race first: inspect `gh release view v<version>`, the Release workflow jobs, checksum file, Homebrew tap commit, and installed `triton version --json` before deciding the release failed.
- Re-download public assets into a fresh temporary directory and wait for `gh release download` to exit successfully before running checksum or archive validation. A still-running download can leave smaller, truncated `.tar.gz` files that produce a false checksum mismatch; inspect the download process, release asset sizes, and `gzip -t` before rewriting any published asset or checksum manifest.
- Do not move an already published tag. If a GitHub Release exists for the wrong version, stop and make an explicit maintainer decision; the default recovery is a new higher version tag, not retagging history.
- For Homebrew validation, check the remote formula first, then run `brew update`, `brew upgrade NeptuneKit/tap/triton`, `brew test NeptuneKit/tap/triton`, and verify packaged web mode from outside the repository so a source checkout does not mask release behavior with dev mode.
- Packaged Web verification must launch the published binary from a repository-external working directory without source-root or internal Web path overrides, then assert `mode=packaged` before HTTP or browser checks. Running from the checkout or passing internal path arguments can select the Vite development server and produce a false packaged-release result.

- 区分认证失败与网络失败。DNS/transport错误时`gh auth status`可能报告token invalid；先在不打印凭据的情况下检查认证API是否可达，不据该提示自动清除认证或改全局DNS。必要网络回退只绑定当前任务进程，结束后关闭自有通道。
- 发布runner的Swift版本可与本机/main CI不同；局部新版Release通过不证明旧编译器优化路径。保留编译器版本、函数与SIL崩溃证据，优先以最小源码结构修复并复验旧工具链，不以关优化/跳过build换绿色。失败tag不等于公开Release；下一补丁保留失败尝试关系。SP-196视觉结果纯snapshot builder恢复记录见[发布验收](../../../docs-linhay/spaces/SP-196-upstream-optimization-delivery/plans/20261014-release.md)。

- Packaged preview acceptance must exercise each platform route, parse the registry with SDK tools absent from PATH, and verify an actual decoded frame plus hide/resume/final-subscriber cleanup. A launch plan or HTML 200 does not prove an MJPEG route exists. Test the local artifact after archive extraction with no independent dev proxy, and retain the binary/static-asset hashes; UI changes after the snapshot require rebuilding the affected candidate.

- Homebrew的`bundledWebRoot`可能是稳定share符号链接；核对resolve后的Cellar版本，不要求原字符串含版本号。`triton web --json`只输出launch plan；用`--print-command --json`检查计划，实际启动去掉JSON输出选项。
- 浏览器默认布局若因设备诊断拒绝实时流，保留HTTP错误、console计数和target-bound doctor证据；可另测关闭流组件后的工作台，但必须标注该结果仅覆盖限定布局，不能据此把默认页面或实时流验收记为通过。不得绕过设备安全保护以满足零console error。

## CI / Release Performance Contract

- `CI` handles validation only. `v*` tag validation must stay on the contracts fast path and must not wait for Swift tests or CocoaPods lint.
- Release asset builds live in the independent `Release` workflow. Do not restore release builds as active jobs in the `CI` workflow.
- arm64 release assets are the Apple Silicon publish gate: arm64 CLI, public skill bundle, checksum manifest, GitHub Release, and Homebrew tap must become available before waiting on x86_64.
- x86_64 CLI is a backfill asset. Build it on the arm64 macOS runner with `swift build --package-path CLI --scratch-path .build/cli-x86 -c release --product triton --triple x86_64-apple-macosx14.0`, then verify `file` reports `Mach-O 64-bit executable x86_64` before upload.
- Release SwiftPM cache keys are architecture-specific: keep separate `release-cli-arm64` and `release-cli-x86_64` cache keys so dependency/build cache does not force the release path back onto the Intel runner.
- `publish-x86-release-asset` must checkout the repository before calling `gh release download`; the GitHub CLI requires git repository context for release lookup.
- Public skill packaging must fail before tarball creation when a Markdown command uses a root absent from the checked CLI command snapshot. Keep `act` and `debug` subcommands strict so retired action/inspection roots cannot silently re-enter release documentation.

## Update Version Evidence

- Homebrew update checks in older releases can return `updateAvailable=false` without a target/latest version; treat that as unqueried, not up to date. Compare remote Release, remote formula, local formula, actual CLI, and each installed skills BUILD_INFO separately. A maintainer machine is not evidence for a reporting user's installation.
- Update regression must cover latest lookup failure, stale/different formula, brew success with wrong installed binary, and mismatched skill metadata. Only actual installed version verification supports update success; stop before skills installation when CLI and selected release differ.

## Reporting

State which surfaces were aligned, which validations passed, and whether CocoaPods was only linted or also pushed to a pod repo/trunk. If CocoaPods publishing is not performed, say that explicitly.

# Issue 120: update include-skills no-op

## 背景

GitHub issue #120 反馈：Homebrew 安装的 `triton` 已经是目标版本时，`triton update --version v0.2.5 --include-skills --skills-dir <dir> --yes --json` 返回 `ok=true`，但没有替换仍停留在旧版本的 `TritonKit.skills/` bundle。

## 范围

- 修复 CLI update runtime 的执行短路。
- 保持 HTTP、Wails、Web、SwiftPM / CocoaPods surfaces 不变。
- 不发布新 tag；本次只修 main 源码并关闭 issue。

## BDD 验收

### 场景 1：CLI 已是目标版本仍安装 skills

Given 当前 CLI 版本等于 `--version` 指定版本
And 用户传入 `--include-skills --skills-dir <dir> --yes`
When 执行 `triton update --json`
Then CLI 不应因为 `updateAvailable=false` 直接返回
And 应安装对应 release 的 `tritonkit-skills.tar.gz`
And JSON 返回 `updated=false`、`skillsUpdated=true`。

### 场景 2：skills 安装仍需要确认

Given 用户传入 `--include-skills --skills-dir <dir>`
When 未传 `--yes` 执行真实更新
Then JSON plan 应显示 `requiresConfirmation=true`
And 真实执行应返回 `confirmation_required`，不修改本机 skills 目录。

## 验证

- 先补 `UpdateCommandTests` 得到红灯。
- focused `swift test --package-path CLI --filter UpdateCommandTests --disable-sandbox --disable-automatic-resolution` 通过。
- 收尾运行 `git diff --check` 与 `docs-linhay/scripts/check-docs.sh`。

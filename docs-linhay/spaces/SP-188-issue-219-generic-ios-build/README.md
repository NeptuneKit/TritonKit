# SP-188：generic iOS SDK-only build

## 状态与边界

- 状态：已本地集成／完整门禁通过／待远端授权；GitHub #219 保持 OPEN。
- Issue：[GitHub #219](https://github.com/NeptuneKit/TritonKit/issues/219)
- Branch：`feat/SP-188-issue-219-generic-ios-build`
- Worktree：`../TritonKit-worktrees/SP-188-issue-219-generic-ios-build/`
- 影响层：CLI Xcode build preflight、help/schema 和 focused tests；无 HTTP/Web/Wails 变化。

## BDD / 验收

1. 给定显式 `xcode build --sdk iphoneos --destination 'generic/platform=iOS'`，且没有 `--device` / `--simulator`，允许无需物理设备的 SDK-only 编译；版本化 iPhoneOS SDK 同样适用。
2. 每个 `--build-setting` 保持独立 argv，调用方可传 `CODE_SIGNING_ALLOWED=NO`、`ARCHS=arm64`、`ONLY_ACTIVE_ARCH=YES`；Triton 不修改签名配置。
3. 不从 defaults 推断 SDK-only opt-in，输出不携带旧 Simulator 身份；SDK 与 destination 均须显式传入。
4. `--device + --destination` 仍返回 `parameter_conflict`；非 generic 或带 id/name 的 iOS destination 仍需 ready 真机选择。#170 的 rawTarget 绑定和公开脱敏保持原样。
5. `settings/test/run` 不启用此例外；run/install 不因此获得任何设备生命周期权限。
6. schema 与 build help 明确 build-only、无设备选择、非安装或业务 ready 的边界。

## 实现

仅 `XcodeBuild` 向共享 resolver 传 `allowGenericIOSSDKOnlyBuildDestination`。resolver 检查显式 destination 精确为 generic iOS、显式 SDK 属于 iPhoneOS family、无设备或 Simulator selector；成功输出去掉继承 Simulator 身份。SDK-only 编译不调用设备 preflight；设备选择分支继续使用原 preflight。

## 验证与风险

- 独立 scratch：`.build/sp188-issue219`，不与其他 issue 共享。
- `XcodeCommandTests` 51/51 通过（含 #170 真机与 run target 回归）；`git diff --check` 通过。`XcodeSchemaParserContractTests` / `XcodeArchiveCapabilityTests` 5/5 通过；实际 `triton schema --command xcode.build --json` 输出合法 JSON。
- 未执行真实 SDK cross-compilation、物理设备、Simulator、安装或启动；本轮证据为 resolver、argv 和 CLI schema 契约。
- `check-docs.sh` 与 `verify.sh --ci-docs` 已执行，因独立 worktree 的 SP-184～187 尚未登记而在 space 连号校验停止；SP-190 已统一补齐，集成后文档门禁通过。
- 已本地集成至 SP-190；本轮未 push、远端 merge 或关闭 issue。

本轮集成入口：[SP-190](../SP-190-open-issues-integration/README.md)。以上 focused 记录来自各 issue 分支，不代表集成后完整门禁已通过。

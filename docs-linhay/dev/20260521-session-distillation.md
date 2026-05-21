# 2026-05-21 session distillation

## 本轮沉淀的模式

### CLI 接管优先级

当 agent 需要控制模拟器、App 生命周期、Xcode build/test/run 或真实项目回归时，默认先使用 TritonKit CLI 的机器可读契约，再把 `xcrun simctl`、`xcodebuild`、XcodeBuildMCP、`hdc` 等平台工具当作实现细节或临时 fallback。

复用入口：

- `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover/SKILL.md`
- `.agents/tritonkit-skills/internal/tritonkit-host-simulator-takeover/SKILL.md`
- `.agents/tritonkit-skills/internal/tritonkit-xcode-workflow-takeover/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`

### Xcode workflow P0

`triton xcode discover/use/schemes/settings/build/test/run` 已成为真实 Apple repo build/test/run 的默认入口。`xcode run` 只证明 build、install、launch 已提交，不证明业务 ready；后续必须继续用 runtime status、wait、assert、screenshot 或 evidence 验证。

真实大型 workspace 可能超过默认超时，本轮补充了 `--timeout <seconds>` 口径，并补上 `xcode settings/build/test/run --jsonl` 的 stdout/stderr sample、heartbeat、summary、log path 与 byte count。后续仍需要 xcresult/coverage/log/evidence 深化。

复用入口：

- `docs-linhay/spaces/20260520-xcode-workflow-takeover/README.md`
- `docs-linhay/spaces/20260520-xcode-workflow-takeover/technical-design.md`
- `.agents/tritonkit-skills/internal/tritonkit-xcode-workflow-takeover/SKILL.md`

### iOS 接入 API 与 DEBUG 边界

对外接入文档默认推荐 facade API：`TritonKit.shared.start()`、`.local(port:)`、`.environment()`、`.device(_:port:)`、`start { config in ... }`、`stop()`、`onStateChange`、`onError`。业务 App 侧仍必须把 `import TritonKit` 与启动代码放在独立 Debug bootstrap 文件的文件级 `#if DEBUG` 内。

SwiftPM 没有 CocoaPods-style Debug-only dependency switch；默认策略是源码级 `#if DEBUG` 隔离 + Release no-op runtime。若生产 Release target 必须完全不链接 TritonKit，则使用独立 Debug-only app target / scheme。

复用入口：

- `README.md`
- `docs-linhay/dev/20260519-ios-integration-guide.md`
- `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`
- `.agents/tritonkit-skills/public/tritonkit-real-project-regression/SKILL.md`

### SwiftPM iOS / CLI 依赖边界

SwiftPM 的 external dependencies 是 package-level 入口，不能只靠 target dependency 断开 CLI 依赖。根 `Package.swift` 面向业务 App，只能暴露 embedded SDK library products；macOS `triton` CLI 使用独立 `CLI/Package.swift` 拥有 Hummingbird、HummingbirdWebSocket、ArgumentParser 等 CLI-only dependencies。

后续只要调整 SwiftPM manifest、CLI 构建入口或 release 产物，都必须同时验证：

- `docs-linhay/scripts/verify-spm-dependency-boundary.sh`
- `swift package show-dependencies --package-path .`
- `swift build --package-path CLI --scratch-path .build/cli -c release --product triton`

复用入口：

- `docs-linhay/dev/20260521-spm-ios-cli-dependency-boundary.md`
- `docs-linhay/scripts/verify-spm-dependency-boundary.sh`
- `AGENTS.md`
- `.agents/tritonkit-skills/internal/tritonkit-ops-governance/SKILL.md`

### CI validate 优化

CI validate 已按变更范围分类：docs、contracts、swift、podkit、full。普通 main push / PR 只阻塞 validate；release asset 打包只在 `v*` tag 或手动 `workflow_dispatch` 执行。后续调整 CI 时要保持分类脚本和 release 契约测试同步。

复用入口：

- `docs-linhay/scripts/ci-validate-mode.sh`
- `docs-linhay/scripts/verify-ci-validate-mode.sh`
- `docs-linhay/scripts/verify-release-automation.sh`
- `docs-linhay/dev/20260519-github-ci-release-artifacts.md`

### Harmony embedded provider 边界

Harmony embedded SDK 的对齐策略不是“全部伪装支持”，而是：

1. HAR 能通用实现的 runtime manifest、snapshot、ledger、app state、logs/sources、ui-tree provider、gateway/callback 直接对齐。
2. scene、route、responder、semantic action 等业务语义通过 App provider 扩展点接入。
3. 未注册 provider 时返回 `unsupported_runtime_scope`，manifest 不标记 supported。
4. input、screenshot、hit-test、system alerts 等设备级或宿主级能力继续交给 host-side adapter 或后续明确设计。

Triton CLI 侧补充 `--runtime-base-url`，用于在 standalone embedded HTTP runtime 尚未接入 `triton serve` 时直接验证 manifest、snapshot、ledger 和 semantic action provider。这个入口服务于本机调试和合同验证，不改变长期产品契约仍以 CLI/HTTP schema 为准。

复用入口：

- `docs-linhay/spaces/20260521-harmony-tritonkit-sdk-alignment/README.md`
- `docs-linhay/dev/20260520-harmony-collector-contract.md`
- `.agents/tritonkit-skills/public/tritonkit-dev-feedback/SKILL.md`

### 会话收尾隔离

“整理会话”时先隔离已提交主仓代码、未提交文档/skill、外部仓验证和临时产物。只 stage 本次整理相关文件，不默认 `git add -A`。外部仓只沉淀结论、边界和后续行动项，除非用户明确要求，不把外部仓补丁夹进 TritonKit 提交。

复用入口：

- `.agents/tritonkit-skills/internal/tritonkit-session-skill-distill/SKILL.md`
- `.agents/tritonkit-skills/internal/tritonkit-ops-governance/SKILL.md`

## 本轮不纳入的内容

- 不把 XcodeBuildMCP 的 tool name、Node runtime、workflow gate 或 MCP server 配置作为 TritonKit 对外 API。
- 不把 Web / Wails UI、远端 agent、设备云、真机自动化或中台服务纳入本机模拟器 CLI 接管方向。
- 不把真实 dxyer workspace 的长耗时 build 结果写成 TritonKit 已完成业务回归；它只证明默认 timeout 需要可配置和后续 streaming progress。
- 不把 Harmony HAR 无法通用推断的 route/responder/action 伪装成默认支持。
- 不把外部 Harmony SDK 仓库的工作区补丁混入 TritonKit 主仓整理提交。

## 已完成验证

- commit `c99adf9 feat: add runtime loop and xcode workflow controls` 已推送到 `origin/main`。
- GitHub CI run `26216553326` full validate 通过。
- 本地在该提交前已通过 `swift test`、`docs-linhay/scripts/verify-intent-cli-smoke.sh`、`docs-linhay/scripts/check-docs.sh`、`git diff --check`。
- Harmony SDK 外部仓已通过 provider contract、全量 Node contract smoke、DevEco `ohpm install --all` 和 HAR build；该结果只作为本仓文档记忆，不等同于本仓代码提交。
- 本仓新增 `docs-linhay/scripts/verify-harmony-runtime-base-url-smoke.sh`，用本地 mock embedded runtime 覆盖 `--runtime-base-url` 的 manifest、route state、snapshot、ledger 和 set-text provider path。

## 后续行动

1. Xcode workflow：补 xcresult failures、coverage 和 evidence artifacts。
2. Harmony SDK：补 provider 示例、network breadcrumbs opt-in 打点约定和真实 App 接入 smoke。
3. Host-side Harmony：把 runtime loop 契约映射到 TritonKit CLI/HTTP target adapter。
4. CI：继续保持 validate 分类，避免 docs-only / contracts-only 变更触发完整 release asset 打包。

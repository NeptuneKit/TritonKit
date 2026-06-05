# Simulator Takeover Architecture

## 决策

TritonKit 的 simulator takeover 采用 `triton` 原生 host adapter，而不是直接依赖 XcodeBuildMCP。底层可以调用 Apple 官方 CLI：`xcrun simctl`、`xcodebuild`、`devicectl`、`xcdevice`、`xctrace`、`xcresulttool`；也可以扩展到 HarmonyOS NEXT / DevEco Emulator 的 `hdc` 与 Emulator CLI。XcodeBuildMCP 作为 workflow、共享 handler、结构化输出、JSONL progress、workspace daemon 和 session defaults 的参考项目。

## 范围

P0/P1 优先覆盖真实项目回归中已经反复出现的能力：

- simulator list/use/boot/shutdown/screenshot
- app list/info/install/uninstall/launch/terminate/open-url/container/prefs
- privacy/location/ui/status-bar/push
- media/keychain/pasteboard/icloud/app data install
- host action 进入 `.tritonplan`
- host artifact 进入 `.tritonevidence`

P2+ 再处理 host UI、日志流、录屏、诊断、xctrace、Xcode build/test、coverage、SPM、project scaffolding 和 runtime 维护。

Harmony P0 已落地为 `triton device doctor/list/use/wait-ready --platform harmony`，用于只读工具探测、HDC target 列表、target 选择和 boot ready 轮询；App 元数据与启动已通过 `triton app inspect/launch --platform harmony` 接入 HDC `bm` / `aa`。UI 输入、截图、日志、capture/evidence 和 `.tritonplan` 仍按后续分期推进。Harmony 内置采集器不属于 P0/P1 host adapter 前置条件，当前仅在 `TritonKitShared` 固化 DEBUG-only JSON 契约，供后续 ArkTS/ArkUI runtime 复用。

## 架构约束

1. `triton` CLI/HTTP schema 是唯一产品契约。
2. Host Adapter 只运行在 macOS CLI / `triton serve`。
3. Embedded Runtime 只处理 App 内 DEBUG-only 能力。
4. Plan / Evidence 可以编排 Host Adapter 与 Runtime Service，但不持有底层工具逻辑。
5. Host Adapter 不使用交互式授权/确认 gate；`riskLevel` 用于审计和调度，policy 只表达执行模式、artifactDir、timeout、redaction 和 audit 契约。缺少客观运行配置时返回 machine-readable blocked/error。
6. Host UI action 必须标记 `runtimeScope=host-ui`，不能混同于 embedded runtime input。
7. Harmony embedded collector 只能在 DEBUG 中启用；Release 必须保持 no-op，不能采集、上传或响应控制。其 transport 固定为 `embedded-websocket`，与 host-side `hdc` adapter 分开审计。

## 后续落地入口

- 跨平台对外项目 skill：`TritonKit.skills/tritonkit-emulator-cli-takeover/SKILL.md`
- Apple Simulator 内部实现 skill：`.agents/skills/tritonkit-host-simulator-takeover/SKILL.md`
- 需求规格：`docs-linhay/spaces/20260520-simulator-takeover/README.md`
- 技术设计：`docs-linhay/spaces/20260520-simulator-takeover/technical-design.md`
- 前置调研：`docs-linhay/spaces/20260520-xcrun-host-adapter-research/README.md`
- 参考项目：`docs-linhay/references/xcodebuildmcp.md`
- GitHub issue：`https://github.com/NeptuneKit/TritonKit/issues/12`

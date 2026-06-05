# iOS / Harmony / CLI integration guides

## 背景

接入使用指南需要从单一 iOS README 长流程，调整为三条可独立执行的入口：iOS embedded runtime、Harmony App / DevEco Emulator、macOS `triton` CLI。外部使用者和 AI agent 应能先判断自己要接的是 App 内 SDK、host-side emulator adapter，还是只需要 CLI。

## 验收场景

### 场景 1：iOS App 接入者能按 Debug-only 路径完成集成

- Given 使用者打开 `README.md`
- When 选择 iOS embedded runtime 接入路径
- Then 能看到 SwiftPM 与 CocoaPods 方式
- And 能看到 SwiftPM 无 Debug-only dependency switch 的限制
- And 能看到独立 `TritonKitDebugBootstrap.swift` 文件级 `#if DEBUG` 示例
- And 能看到 AppDelegate / SwiftUI 入口只保留 Debug 调用点
- And 能看到网络与 Release no-op 边界

### 场景 2：Harmony 使用者能区分 host-side 与 embedded SDK

- Given 使用者需要在 HarmonyOS / DevEco Emulator 上验证 TritonKit
- When 阅读 `README.md` 或 public skills
- Then 能看到 host-side HDC adapter 不需要 App 集成 TritonKit
- And 能看到 Harmony embedded SDK 的实际 package id / import path 是 `tritonkit`
- And 能看到 embedded runtime 必须 Debug-only，Release 下 disabled/no-op
- And 能看到 App provider 未注册时 `unsupported_runtime_scope` 是正确边界
- And 能看到 `--runtime-base-url` 的 direct runtime 验证命令与 `28767` / `18765` 端口语义

### 场景 3：CLI 使用者能独立安装与验证

- Given 使用者只需要 macOS `triton` CLI
- When 阅读 CLI integration guide
- Then Homebrew 是 released build 的默认安装路径
- And local source build 只用于验证未发布源码变更
- And 手动替换已在 `PATH` 上的 CLI 时使用临时文件加 `mv`，或先停止 `triton serve`
- And 能看到 `serve`、runtime、sim/app、xcode、harmony device/app、wait/assert/evidence/replay 等机器可读命令入口

### 场景 4：AI agent 使用 public skills 时口径一致

- Given agent 使用 `tritonkit-dev-feedback`、`tritonkit-real-project-regression` 或 `tritonkit-emulator-cli-takeover`
- When 用户要求 iOS / Harmony / CLI 接入指导
- Then skill 不应只引导 iOS
- And skill 应按 iOS embedded、Harmony host-side、Harmony embedded、CLI install/run 分流
- And 发现指南缺口、接入摩擦或实际能力不符时，按 dev feedback 流程沉淀 GitHub issue

### 场景 5：GitHub issue 上报前完成脱敏

- Given agent 在真实业务 App、客户项目或个人工程中复现了 TritonKit 问题
- When 准备公开 GitHub issue、issue comment 或附件证据
- Then 必须替换真实工程名、App 名、bundle ID、team ID、组织名、用户名、账号、邮箱、手机号、内网域名和绝对私有路径
- And 不上传完整私有日志、未脱敏截图、未检查的 `.tritonevidence`、`.tritonplan`、`.xcresult`、HDC/Simulator dump 或 App archive
- And 保留平台版本、TritonKit 版本、命令、错误码、最小复现步骤和裁剪后的脱敏日志片段

## 变更位置

- `README.md`
- `TritonKit.skills/tritonkit-dev-feedback/SKILL.md`
- `TritonKit.skills/tritonkit-real-project-regression/SKILL.md`
- `TritonKit.skills/tritonkit-emulator-cli-takeover/SKILL.md`
- `.agents/skills/tritonkit-ops-governance/SKILL.md`
- `docs-linhay/memory/2026-05-21.md`

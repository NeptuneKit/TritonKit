# SP-287 功能地图与 public skills 覆盖核对

## 结论

**不是所有功能都有完整的 public skill 用法。** 主要操作流程已有入口，但 skills 不是功能实现，也不是全部 CLI/HTTP 子命令的手册。当前源码 bundle 有四个 public skills：接入反馈、模拟器 CLI 接管、真实项目回归、安装更新；内部 `.agents/skills/` 不随公开包分发。

- 核对日期：2026-11-12；整理基线 `main@5a10d269`。图表仍保留原始 `6467b413 + WIP` 采样口径，不把本次阅读升级成新的设备或发布验收。
- 阅读范围：四个 SKILL 入口、两个 feature-index、相应 references，以及 public bundle 全部 Markdown 的定向检索。下表只判定图中功能族的文档入口，不声明逐个 leaf command/参数/错误分支均已覆盖。
- 这里的“有主要流程”不等于当前用户已安装这些 skills，更不等于已安装 CLI/SDK/provider 支持它们；安装副本及发布资产本次未核对。

## 四个 public skills

| Skill | 负责内容 |
| --- | --- |
| [tritonkit-dev-feedback](../../../../TritonKit.skills/tritonkit-dev-feedback/SKILL.md) | 接入、诊断、能力缺口与可公开反馈的证据流程 |
| [tritonkit-emulator-cli-takeover](../../../../TritonKit.skills/tritonkit-emulator-cli-takeover/SKILL.md) | 本机三平台设备/App、观察、动作、网络、证据与 workspace 路由 |
| [tritonkit-real-project-regression](../../../../TritonKit.skills/tritonkit-real-project-regression/SKILL.md) | 真实项目采用、embedded/Runner、断言、回放和验收边界 |
| [tritonkit-update](../../../../TritonKit.skills/tritonkit-update/SKILL.md) | CLI、skills、SwiftPM 版本对齐与 guarded 更新 |

权威目录与分发边界：[public bundle README](../../../../TritonKit.skills/README.md)。仅复制 SKILL.md 会丢失 references 和跨 skill 路由；整包安装也不会安装/替代 CLI、App SDK 或 XCTest Runner。

## 22 个图节点逐项对应

简写：E=[接管 feature-index](../../../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/feature-index.md)，R=[回归 feature-index](../../../../TritonKit.skills/tritonkit-real-project-regression/references/feature-index.md)，C=[current implemented surface](../../../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/current-implemented-surface.md)。这些是入口，不是动态完整性证明。

| 图节点 | public skills 覆盖 | 可读入口或缺口 |
| --- | --- | --- |
| AI Agent / 自动化脚本 | 有主要流程 | 三个业务 skill 的 workflow、原始数据职责、Triton-first 与上层策略边界 |
| triton CLI | 有主要流程 | E/C、schema/capabilities 和 update；不保证逐条叶命令说明 |
| 本地 HTTP + Runtime 通道 | 部分 | serve/Bonjour/embedded 与 Runner HTTP 有说明；没有完整逐路由 API 使用矩阵 |
| DSH 插件 | 无直接用法 | public Markdown 未发现 DSH 或四工具入口；说明在 bundle 外的 [DSH README](../../../../DSH/README.md) |
| Web 预览 / 桌面壳 | 部分 | [preview acceptance](../../../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/validation.md) 和 update 有 packaged 预览；不是完整 Web/桌面操作手册，正式业务控制面仍排除 |
| 能力发现与诊断 | 有主要流程 | SKILL 的 status/doctor/capabilities/schema/plan 与 schema references |
| 目标绑定与会话 | 部分 | discovery/alias/显式目标/Runner session 有说明；未找到 target lease acquire/status/release/takeover 的完整 public 操作流程 |
| 页面观察与定位 | 有主要流程 | observe/tree/alias/OCR/settle/ui-health 的合同与验收 |
| 动作执行 | 有主要流程 | act/device action、receipt、unknown 不重放、后置验证；仍须按 provider/schema 选择 |
| 业务等待与断言 | 有主要流程 | wait/verify/route、role/区域/数量等条件与业务验收边界 |
| 证据与原始事实 | 有主要流程 | evidence capture/inspect/summary/redact、receipt、manifest 和原值职责 |
| 设备与 App 管理 | 有主要流程 | E/C/platform/device-hub、resource、App 生命周期与安装更新 |
| WebView 与网络 | 有主要流程 | webview-actions/network-proxy 以及 provider/candidate/trusted=false 限制 |
| UI 深度调试 | 部分 | attrs/highlight/picker/selection 有说明；public Markdown 未找到 debug details、solo/group 节点截图和 3D 语义的完整指南；现有 [Lookin 核心说明](../../../dev/20261103-lookin-core-inspection.md) 在 bundle 外 |
| 构建与工程诊断 | 有主要流程 | public iOS/Xcode feedback、C 和回归入口；不等于所有构建参数都有示例 |
| 测试、录制与回放 | 部分 | record/replay/test import/validate/run 与可靠性边界有说明；未找到 testrec start/event/stop/compile 全链路操作指南 |
| Workspace / Atlas / App-map | 部分 | [workspace runs](../../../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/workspace-runs.md)、C 的模型启用/grounding/coverage/health 有说明；map path/suite/export 与 VLM models 生命周期并非完整手册 |
| iOS Simulator Host | 有主要流程 | C/platform-commands、HID/geometry/AX/framebuffer 与 reserved type 边界 |
| iOS Embedded SDK | 有主要流程 | [iOS integration](../../../../TritonKit.skills/tritonkit-real-project-regression/references/ios-integration.md)、runtime evidence、Debug-only/Release no-op |
| iOS XCTest Runner | 有主要流程 | 回归 SKILL 的 bundled Runner session、输入/receipt/截图与独立路由 |
| Android Emulator | 有主要流程 | E/C/platform 的 ADB/UIAutomator/Bridge/resource 及文字输入限制 |
| HarmonyOS / DevEco | 有主要流程 | E/C/Harmony integration、HDC/ArkWeb/standalone runtime 与 IME/读回限制 |

## 使用时怎么做

1. 先选择匹配的 public skill，再经 feature-index 只读相关 reference。
2. 用已安装 CLI 的 `version`、定向 `schema --command`、`capabilities` 和 provider 状态确认实际支持；文档不替代运行契约。
3. 对上述缺口，当前需要读取项目专题文档与实际 schema；不能回答“skills 已经全有”，也不能把存在同名关键词当作完整流程。
4. 本次仅记录覆盖与缺口，**未补齐 public skills、未新增 skill、未安装或发布 bundle**。补齐应按功能族更新已有入口/专题引用，并验证打包与实际命令；不为每个命令增设一个 skill。

## 检索反证与限制

对 public Markdown 定向检索 `DSH/triton_schema/triton_query`、`debug details/soloScreenshot/groupScreenshot/3D/Lookin`、`target lease/lease acquire`、`vlm models`，未命中对应完整操作入口。grep 无命中只支持“本次源码 Markdown 未找到”，不证明其他仓库或已安装副本绝无说明。HTTP、map 与模型部分已有命中，故列为“部分”，不误报为空白。

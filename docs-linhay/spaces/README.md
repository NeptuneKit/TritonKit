# TritonKit Spaces Index

> 固定入口：`docs-linhay/spaces/README.md`
>
> 最近审计：2026-07-11

本文件是 `docs-linhay/spaces/` 的总索引，用于跟踪需求空间、实施进度、独立 worktree 和文档收口状态。单个需求的详细边界、BDD、计划和证据仍以对应 space 的 `README.md` 为事实源。

## 状态定义

| 状态 | 含义 |
| --- | --- |
| 进行中 | 当前仍有明确实现或验收缺口 |
| 待集成 | 独立 worktree 已有提交，但尚未合入 `main` |
| 明确待办 | 已确认未完成，等待后续实现或真实验收 |
| 规划冻结 | 只保留研究和执行蓝图，当前不占用 active roadmap |
| 待收口 | 代码或后续实现已覆盖主要目标，但 space 的计划、勾选项或结论仍陈旧 |
| 已归档 | 本期工作已结束或已被后续 space 接管；不表示 README 中所有远期设想均已实现 |

## 当前队列

| 状态 | Space | 当前进度 | 下一步 |
| --- | --- | --- | --- |
| 进行中 | [20260706-agent-mobile-runtime-platform](./20260706-agent-mobile-runtime-platform/README.md) | iOS Demo 的 target discovery、launch、action、evidence、LLM/VLM、Atlas、flow export 全链 smoke 已通过 | 修复或重装 Overloaded Debug bootstrap 后补真实 App smoke；继续按 capability 扩展其他 target scope，并明确本期关闭条件 |
| 进行中 | [20260521-ios-embedded-sdk-expansion](./20260521-ios-embedded-sdk-expansion/README.md) | S0-S4 首批闭环已完成，2026-07-09 开始 WebView-aware `act tap` 切片 | 完成 WebView-aware action 的实现、证据和真实 harness 验收；P1/P2 增强按独立切片推进 |
| 明确待办 | [20260622-test-recorder-replay](./20260622-test-recorder-replay/README.md) | P0 合同、录制事件、compile、page/network map、dry-run 和 local-simulated executor 已落地 | 实现 Triton-first `local-device` 真实 executor；系统级录制、真实 VLM fingerprint、proposal 审批和 live network policy 仍未实现 |
| 明确待办 | [20260525-simulator-target-simplification](./20260525-simulator-target-simplification/README.md) | parser/schema/CLI 单测已通过 | 补 `--bundle` 反向过滤，并执行真实多开 iOS + Harmony alias smoke |
| 规划冻结 | [20260527-revyl-cli-agent-entrypoint-research](./20260527-revyl-cli-agent-entrypoint-research/README.md) | 研究、需求和 M1-M6 蓝图已归档，明确不占 active roadmap | 需要启动时先重新核对现有 `skill/update/evidence/schema/workspace` 能力，避免重复实现旧缺口 |
| 待收口 | [20260701-host-framebuffer-stream](./20260701-host-framebuffer-stream/README.md) | `CLIHostSimulatorFramebufferService`、IOSurface 捕获和 `/web/ios-simulator/framebuffer` 已存在，但 README 四个里程碑仍全部未勾选 | 用当前实现和真实 smoke 逐项回填 M1-M4，修正 `<15ms/120 FPS` 是否有证据支撑 |
| 待收口 | [20260702-cross-platform-framebuffer-stream](./20260702-cross-platform-framebuffer-stream/README.md) | Android/Harmony service、HTTP route 和 Web bridge 已存在，README DoD 已勾选 | 更新 `plans/research_and_implementation_plan.md` 的 16 个陈旧未勾选项，并补充真实帧率、断连释放和降频证据路径 |
| 待收口 | [20260617-issue-61-android-emulator-adapter](./20260617-issue-61-android-emulator-adapter/README.md) | space 仍记录被旧 Web test 编译错误阻塞；后续 Android adapter/strong-control 已有大量实现与真实 smoke | 复跑当前 focused tests，确认旧 blocker 是否已消失，再把本期状态改为完成或列出真实剩余缺口 |

## 维护规则

1. 新建 space 后，同一提交内将其加入本索引的“当前队列”或“历史归档”。
2. 状态变化时更新“最近审计”日期、当前进度和下一步，不只修改单个 space。
3. 独立 worktree 必须记录路径、branch/commit 和待集成动作；合入后从“待集成”移除。
4. 代码已落地但 README/plan 未同步时标记“待收口”，不得直接标记“已完成”。
5. space 完成本期 DoD、文档与 memory 写回后移入“历史归档”。
6. 本索引只做导航和进度摘要，不复制单个 space 的完整需求、BDD 或技术方案。

## 历史归档

以下 space 当前不在 active queue。它们保留历史需求、实现记录和验收证据；再次启动前应先核对当前代码和后续 space，不能直接照旧计划执行。

### 2026-05

- [20260516-hybrid-transport-smoke](./20260516-hybrid-transport-smoke/README.md)
- [20260520-harmony-emulator-alignment](./20260520-harmony-emulator-alignment/README.md)
- [20260520-simulator-takeover](./20260520-simulator-takeover/README.md)
- [20260520-xcode-workflow-takeover](./20260520-xcode-workflow-takeover/README.md)
- [20260520-xcrun-host-adapter-research](./20260520-xcrun-host-adapter-research/README.md)
- [20260521-ai-phone-emulator-cli](./20260521-ai-phone-emulator-cli/README.md)
- [20260521-harmony-tritonkit-sdk-alignment](./20260521-harmony-tritonkit-sdk-alignment/README.md)
- [20260521-harness-ux-run-evidence](./20260521-harness-ux-run-evidence/README.md)
- [20260521-runtime-cli-contract-hardening](./20260521-runtime-cli-contract-hardening/README.md)
- [20260521-webview-runtime-bridge](./20260521-webview-runtime-bridge/README.md)
- [20260522-cli-file-governance](./20260522-cli-file-governance/README.md)
- [20260522-issue-20-tap-activation](./20260522-issue-20-tap-activation/README.md)
- [20260522-issue-21-server-log-noise](./20260522-issue-21-server-log-noise/README.md)
- [20260522-real-project-smoke-p1](./20260522-real-project-smoke-p1/README.md)
- [20260523-simulator-advanced-controls](./20260523-simulator-advanced-controls/README.md)
- [20260524-autonomous-evolution](./20260524-autonomous-evolution/README.md)
- [20260525-cross-platform-cli-simplification](./20260525-cross-platform-cli-simplification/README.md)
- [20260527-command-surface-optimization](./20260527-command-surface-optimization/README.md)
- [20260527-mirroir-host-adapter](./20260527-mirroir-host-adapter/README.md)

### 2026-06

- [20260604-issue-26-sim-screenshot-orientation](./20260604-issue-26-sim-screenshot-orientation/README.md)
- [20260604-issue-27-agent-skills-readme](./20260604-issue-27-agent-skills-readme/README.md)
- [20260605-android-emulator-support](./20260605-android-emulator-support/README.md)
- [20260605-debug-runtime-integration-governance](./20260605-debug-runtime-integration-governance/README.md)
- [20260605-skill-layout-relocation](./20260605-skill-layout-relocation/README.md)
- [20260608-cross-platform-real-device-takeover](./20260608-cross-platform-real-device-takeover/README.md)
- [20260608-ios-media-playback-helpers](./20260608-ios-media-playback-helpers/README.md)
- [20260608-ios-real-device-takeover](./20260608-ios-real-device-takeover/README.md)
- [20260608-issue-34-prefs-data](./20260608-issue-34-prefs-data/README.md)
- [20260608-issue-35-selector-flags](./20260608-issue-35-selector-flags/README.md)
- [20260608-issue-39-capture-target](./20260608-issue-39-capture-target/README.md)
- [20260608-semantic-provider-capabilities](./20260608-semantic-provider-capabilities/README.md)
- [20260608-single-device-web-preview](./20260608-single-device-web-preview/README.md)
- [20260609-issue-30-android-contract-compat](./20260609-issue-30-android-contract-compat/README.md)
- [20260609-issue-31-open-url-plan](./20260609-issue-31-open-url-plan/README.md)
- [20260609-three-platform-network-takeover](./20260609-three-platform-network-takeover/README.md)
- [20260611-web-mock-ui](./20260611-web-mock-ui/README.md)
- [20260612-issue-41-triton-first-workflow](./20260612-issue-41-triton-first-workflow/README.md)
- [20260612-issue-42-nested-pager-swipe](./20260612-issue-42-nested-pager-swipe/README.md)
- [20260612-issue-43-ios-host-input](./20260612-issue-43-ios-host-input/README.md)
- [20260612-issue-45-foreground-app-identity](./20260612-issue-45-foreground-app-identity/README.md)
- [20260613-web-triad-qa](./20260613-web-triad-qa/README.md)
- [20260617-issue-57-xcode-deriveddata-diagnostics](./20260617-issue-57-xcode-deriveddata-diagnostics/README.md)
- [20260617-issue-58-webview-provider-capabilities](./20260617-issue-58-webview-provider-capabilities/README.md)
- [20260617-issue-59-ios-tap-capture-target](./20260617-issue-59-ios-tap-capture-target/README.md)
- [20260617-issue-60-uitableview-row-tap](./20260617-issue-60-uitableview-row-tap/README.md)
- [20260617-issue-62-discovery-timeout](./20260617-issue-62-discovery-timeout/README.md)
- [20260617-issue-63-harmony-route-webview-evidence](./20260617-issue-63-harmony-route-webview-evidence/README.md)
- [20260617-triton-web-command](./20260617-triton-web-command/README.md)
- [20260618-ios-runtime-capability-gating](./20260618-ios-runtime-capability-gating/README.md)
- [20260618-web-launch-diagnostics](./20260618-web-launch-diagnostics/README.md)
- [20260619-agent-workflow-skill-governance](./20260619-agent-workflow-skill-governance/README.md)
- [20260619-issue-65-xcode-wait-idle-timeout](./20260619-issue-65-xcode-wait-idle-timeout/README.md)
- [20260619-issue-66-xcode-incremental-cache-ux](./20260619-issue-66-xcode-incremental-cache-ux/README.md)
- [20260619-issue-67-agent-ux-evidence-xcode](./20260619-issue-67-agent-ux-evidence-xcode/README.md)
- [20260619-issue-68-harmony-app-target-failure](./20260619-issue-68-harmony-app-target-failure/README.md)
- [20260619-issue-69-ios-real-device-app-selector](./20260619-issue-69-ios-real-device-app-selector/README.md)
- [20260619-lookin-hierarchy-viewer](./20260619-lookin-hierarchy-viewer/README.md)
- [20260620-vlm-test-runner](./20260620-vlm-test-runner/README.md)
- [20260621-issue-70-xcode-sdk-macro](./20260621-issue-70-xcode-sdk-macro/README.md)
- [20260621-issue-71-schema-status-contract](./20260621-issue-71-schema-status-contract/README.md)
- [20260621-issue-73-evidence-ingest](./20260621-issue-73-evidence-ingest/README.md)
- [20260621-issue-76-media-fixture-seed](./20260621-issue-76-media-fixture-seed/README.md)
- [20260621-issue-79-launch-env-args](./20260621-issue-79-launch-env-args/README.md)
- [20260621-issue-80-action-help](./20260621-issue-80-action-help/README.md)
- [20260621-local-mlx-vlm-provider](./20260621-local-mlx-vlm-provider/README.md)
- [20260621-p23-cli-product-surface-rearchitecture](./20260621-p23-cli-product-surface-rearchitecture/README.md)
- [20260621-triton-inspector-web](./20260621-triton-inspector-web/README.md)
- [20260622-cli-update-command](./20260622-cli-update-command/README.md)
- [20260622-issue-82-xcode-wait-idle](./20260622-issue-82-xcode-wait-idle/README.md)
- [20260622-issue-83-xcode-build-timeout-output](./20260622-issue-83-xcode-build-timeout-output/README.md)
- [20260622-issue-85-harmony-deveco-workflows](./20260622-issue-85-harmony-deveco-workflows/README.md)
- [20260622-issue-86-xcode-macro-deriveddata](./20260622-issue-86-xcode-macro-deriveddata/README.md)
- [20260623-open-issues-89-91](./20260623-open-issues-89-91/README.md)
- [20260623-triton-web-auto-discovery](./20260623-triton-web-auto-discovery/README.md)
- [20260624-open-issues-95-97](./20260624-open-issues-95-97/README.md)
- [20260624-react-debug-inspector-web](./20260624-react-debug-inspector-web/README.md)
- [20260625-github-issues-117-118](./20260625-github-issues-117-118/README.md)
- [20260625-issue-119-update-flow](./20260625-issue-119-update-flow/README.md)
- [20260630-issue-120-update-skills](./20260630-issue-120-update-skills/README.md)
- [20260630-web-card-render](./20260630-web-card-render/README.md)
- [20260630-web-redesign](./20260630-web-redesign/README.md)

### 2026-07

- [20260702-strong-emulator-control](./20260702-strong-emulator-control/README.md)
- [20260703-host-simulator-ax-takeover](./20260703-host-simulator-ax-takeover/README.md)
- [20260703-issue-128-harmony-install-failure](./20260703-issue-128-harmony-install-failure/README.md)
- [20260703-issue-129-harmony-uninstall](./20260703-issue-129-harmony-uninstall/README.md)
- [20260703-issue-130-agent-guidance-current-cli](./20260703-issue-130-agent-guidance-current-cli/README.md)
- [20260703-issue-131-doctor-host-device-scope](./20260703-issue-131-doctor-host-device-scope/README.md)
- [20260703-issue-132-appintents-pod-build](./20260703-issue-132-appintents-pod-build/README.md)
- [20260703-issues-133-134-xcode-selectors](./20260703-issues-133-134-xcode-selectors/README.md)
- [20260706-web-hierarchy-source-tabs](./20260706-web-hierarchy-source-tabs/README.md)
- [20260706-web-inspect-session-slots](./20260706-web-inspect-session-slots/README.md)
- [20260706-web-stream-gesture-mapping](./20260706-web-stream-gesture-mapping/README.md)
- [20260707-github-issue-batch](./20260707-github-issue-batch/README.md)
- [20260707-issue-140-redaction-preflight](./20260707-issue-140-redaction-preflight/README.md)
- [20260709-issues-141-142](./20260709-issues-141-142/README.md)
- [20260709-packaged-web-mjpeg](./20260709-packaged-web-mjpeg/README.md)
- [20260710-issues-144-145-action-docs](./20260710-issues-144-145-action-docs/README.md)

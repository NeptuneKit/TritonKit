# TritonKit Spaces Index

> 固定入口：`docs-linhay/spaces/README.md`
>
> 最近审计：2026-07-20

本文件是 `docs-linhay/spaces/` 的总索引，用于跟踪需求空间、实施进度、独立 worktree 和文档收口状态。单个需求的详细边界、BDD、计划和证据仍以对应 space 的 `README.md` 为事实源。

## 状态定义

| 状态 | 含义 |
| --- | --- |
| 执行 | 当前有边界明确、可验证、应继续完成的有限任务 |
| 待定 | 暂停实现，必须先完成产品合并、范围取舍或环境条件判断 |
| 废弃 | 不再作为独立 roadmap 推进；保留历史文档和仍有价值的既有代码 |
| 已归档 | 本期验收已满足或原型已完成，不再追加远期设想 |

## 路线裁决

| 状态 | Space | 裁决 | 下一步 |
| --- | --- | --- | --- |
| 执行 | [20260720-issue-148-xcode-simulator-destination](./20260720-issue-148-xcode-simulator-destination/README.md) | 修复 `xcode test --simulator` 被旧 default destination 覆盖及 `id=<name>` 错配 | BDD/TDD、Xcode command/schema 回归、合入后关闭 #148 |
| 已归档 | [20260720-issue-146-sim-record-duration](./20260720-issue-146-sim-record-duration/README.md) | `sim record` 已按 encoded sample 时长校验；一帧 MOV 返回 `sim_record_truncated`，成功契约暴露 requested/actual/container/track duration | 已合入 `main`；推送并关闭 #146 |
| 已归档 | [20260521-ios-embedded-sdk-expansion](./20260521-ios-embedded-sdk-expansion/README.md) | S0-S4 与 WebView-aware `act tap` 已完成，真实 iOS Simulator 证明 `selector -> DOM dispatch -> expect-text` 返回 `status=passed` | 保留动态 smoke 证据；P1/P2 需求另建有限 space |
| 已归档 | [20260525-simulator-target-simplification](./20260525-simulator-target-simplification/README.md) | 真实多开 iOS、Harmony alias、指定目标动作和多候选拒绝均通过；同时修复 observation alias 缺省 platform 被误判为 iOS | 不实现 `--bundle` 反向过滤；批量 fan-out 或新 selector 能力另建 space |
| 待定 | [20260622-test-recorder-replay](./20260622-test-recorder-replay/README.md) | P0 合同与 local-simulated executor 已形成大体量实现，但真实 executor 与 `workspace run`、`.tritontest`、replay/evidence/Atlas 高度重叠 | 暂停新代码；先裁决 `testrec` 是否保留独立产品面，还是并入现有 workspace/test/replay 契约 |
| 废弃 | [20260527-revyl-cli-agent-entrypoint-research](./20260527-revyl-cli-agent-entrypoint-research/README.md) | 研究价值已被 skill、schema、evidence、update 和 Agent Mobile Runtime Platform 吸收 | 不再按原 M1-M6 独立实施；历史材料继续作为参考 |
| 已归档 | [20260706-agent-mobile-runtime-platform](./20260706-agent-mobile-runtime-platform/README.md) | iOS Demo 已完成 target discovery、launch、action、evidence、LLM/VLM、Atlas、flow export 全链 smoke，满足“一期至少一个 target scope”验收 | Overloaded bootstrap 作为外部项目回归问题另行处理；其他 target scope 扩展必须新建有限 space |
| 已归档 | [20260701-host-framebuffer-stream](./20260701-host-framebuffer-stream/README.md) | SimulatorKit/IOSurface host stream、MJPEG route 和历史高帧率测量已落地 | 作为实验性 Web mock 能力保留，不再承诺 `<15ms/120 FPS` 产品 SLA；正式 Web 恢复时重新立项 |
| 已归档 | [20260702-cross-platform-framebuffer-stream](./20260702-cross-platform-framebuffer-stream/README.md) | Android/Harmony host pull stream、HTTP route、Web bridge 和截图证据已落地 | 作为 Web mock 原型归档，不再追加性能优化；正式产品化需重新定义边界和证据门禁 |
| 已归档 | [20260617-issue-61-android-emulator-adapter](./20260617-issue-61-android-emulator-adapter/README.md) | 旧 Web 编译 blocker 已消失，当前 `DeviceCrossPlatformTests` 93 项通过；Android Emulator 主链已有历史真实 smoke | 不再单独执行；后续 Android 回归走现有 emulator takeover 与 strong-control spaces |

## 维护规则

1. 新建 space 后，同一提交内将其加入本索引的“路线裁决”或“历史归档”。
2. 状态变化时更新“最近审计”日期、裁决和下一步，不只修改单个 space。
3. 独立 worktree 必须记录路径、branch/commit 和待集成动作；合入后从“待集成”移除。
4. “执行”必须有有限停止条件；没有产品取舍结论的方向标记“待定”，不得继续堆实现。
5. 被后续路线吸收或不再符合产品边界的独立计划标记“废弃”，但不删除历史文档和仍有价值的代码。
6. space 完成本期 DoD、文档与 memory 写回后标记“已归档”。
7. 本索引只做导航和进度摘要，不复制单个 space 的完整需求、BDD 或技术方案。

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

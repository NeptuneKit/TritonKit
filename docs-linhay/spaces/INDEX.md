# TritonKit Space 编号索引


2026-10-26参考核对：原目录 `main@24e7d0f2`，SP-207两仓变化；新SP-221执行/SP-222主控已验收合本地main a0eebff0，范围仅只读资源暂态重试。旧13条采用已合main，真实验收边界保持。
> 固定入口：`docs-linhay/spaces/INDEX.md`
> 最近同步：2026-10-30（真实前序Space登记及SP-248本地提交）
> 覆盖范围：249/249 个已存在 space

本文件是所有 space 的编号登记册。每个 space 获得一个不可复用的规范标识，格式为 `SP-<三位序号>-<英文-topic>`，例如 `SP-001-hybrid-transport-smoke`。单个 space 的需求、BDD、计划和证据仍以其 `README.md` 为事实源；路线状态摘要仍在 [README.md](./README.md)。

## 命名与迁移规则

1. 新建 space、branch 与 worktree 一律使用登记后的规范名：`SP-<三位序号>-<英文-topic>`。
2. 序号全局递增、永不复用；`topic` 使用小写英文 slug，禁止空格、中文、`latest` 与 `final`。
3. 本次先完成编号登记与链接同步。历史目录继续保留为兼容路径，避免中断 README、证据和 Git 历史链接；物理目录重命名必须作为独立批次完成，并同步更新引用、branch 与 worktree。
4. 新建或归档 space 时，必须同时更新本表、[路线总览](./README.md) 和对应 space 的 README。

## 同步进度

| 项目 | 进度 | 说明 |
| --- | --- | --- |
| 编号登记 | 249/249 | 所有当前 space 均已分配唯一 SP 编号 |
| README 链接核对 | 249/249 | 每条记录链接到现有 space README |
| 历史目录物理迁移 | 0/125 | 125 个历史兼容目录留待独立迁移批次；SP-126～156 已是规范目录 |

## Space 登记表

| 规范名称 | 当前目录（兼容入口） | 索引同步 | 目录迁移 |
| --- | --- | --- | --- |
| `SP-001-hybrid-transport-smoke` | [`20260516-hybrid-transport-smoke`](./20260516-hybrid-transport-smoke/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-002-harmony-emulator-alignment` | [`20260520-harmony-emulator-alignment`](./20260520-harmony-emulator-alignment/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-003-simulator-takeover` | [`20260520-simulator-takeover`](./20260520-simulator-takeover/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-004-xcode-workflow-takeover` | [`20260520-xcode-workflow-takeover`](./20260520-xcode-workflow-takeover/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-005-xcrun-host-adapter-research` | [`20260520-xcrun-host-adapter-research`](./20260520-xcrun-host-adapter-research/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-006-ai-phone-emulator-cli` | [`20260521-ai-phone-emulator-cli`](./20260521-ai-phone-emulator-cli/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-007-harmony-tritonkit-sdk-alignment` | [`20260521-harmony-tritonkit-sdk-alignment`](./20260521-harmony-tritonkit-sdk-alignment/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-008-harness-ux-run-evidence` | [`20260521-harness-ux-run-evidence`](./20260521-harness-ux-run-evidence/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-009-ios-embedded-sdk-expansion` | [`20260521-ios-embedded-sdk-expansion`](./20260521-ios-embedded-sdk-expansion/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-010-runtime-cli-contract-hardening` | [`20260521-runtime-cli-contract-hardening`](./20260521-runtime-cli-contract-hardening/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-011-webview-runtime-bridge` | [`20260521-webview-runtime-bridge`](./20260521-webview-runtime-bridge/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-012-cli-file-governance` | [`20260522-cli-file-governance`](./20260522-cli-file-governance/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-013-issue-20-tap-activation` | [`20260522-issue-20-tap-activation`](./20260522-issue-20-tap-activation/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-014-issue-21-server-log-noise` | [`20260522-issue-21-server-log-noise`](./20260522-issue-21-server-log-noise/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-015-real-project-smoke-p1` | [`20260522-real-project-smoke-p1`](./20260522-real-project-smoke-p1/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-016-simulator-advanced-controls` | [`20260523-simulator-advanced-controls`](./20260523-simulator-advanced-controls/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-017-autonomous-evolution` | [`20260524-autonomous-evolution`](./20260524-autonomous-evolution/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-018-cross-platform-cli-simplification` | [`20260525-cross-platform-cli-simplification`](./20260525-cross-platform-cli-simplification/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-019-simulator-target-simplification` | [`20260525-simulator-target-simplification`](./20260525-simulator-target-simplification/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-020-command-surface-optimization` | [`20260527-command-surface-optimization`](./20260527-command-surface-optimization/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-021-mirroir-host-adapter` | [`20260527-mirroir-host-adapter`](./20260527-mirroir-host-adapter/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-022-revyl-cli-agent-entrypoint-research` | [`20260527-revyl-cli-agent-entrypoint-research`](./20260527-revyl-cli-agent-entrypoint-research/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-023-issue-26-sim-screenshot-orientation` | [`20260604-issue-26-sim-screenshot-orientation`](./20260604-issue-26-sim-screenshot-orientation/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-024-issue-27-agent-skills-readme` | [`20260604-issue-27-agent-skills-readme`](./20260604-issue-27-agent-skills-readme/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-025-android-emulator-support` | [`20260605-android-emulator-support`](./20260605-android-emulator-support/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-026-debug-runtime-integration-governance` | [`20260605-debug-runtime-integration-governance`](./20260605-debug-runtime-integration-governance/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-027-skill-layout-relocation` | [`20260605-skill-layout-relocation`](./20260605-skill-layout-relocation/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-028-cross-platform-real-device-takeover` | [`20260608-cross-platform-real-device-takeover`](./20260608-cross-platform-real-device-takeover/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-029-ios-media-playback-helpers` | [`20260608-ios-media-playback-helpers`](./20260608-ios-media-playback-helpers/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-030-ios-real-device-takeover` | [`20260608-ios-real-device-takeover`](./20260608-ios-real-device-takeover/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-031-issue-34-prefs-data` | [`20260608-issue-34-prefs-data`](./20260608-issue-34-prefs-data/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-032-issue-35-selector-flags` | [`20260608-issue-35-selector-flags`](./20260608-issue-35-selector-flags/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-033-issue-39-capture-target` | [`20260608-issue-39-capture-target`](./20260608-issue-39-capture-target/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-034-semantic-provider-capabilities` | [`20260608-semantic-provider-capabilities`](./20260608-semantic-provider-capabilities/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-035-single-device-web-preview` | [`20260608-single-device-web-preview`](./20260608-single-device-web-preview/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-036-issue-30-android-contract-compat` | [`20260609-issue-30-android-contract-compat`](./20260609-issue-30-android-contract-compat/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-037-issue-31-open-url-plan` | [`20260609-issue-31-open-url-plan`](./20260609-issue-31-open-url-plan/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-038-three-platform-network-takeover` | [`20260609-three-platform-network-takeover`](./20260609-three-platform-network-takeover/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-039-web-mock-ui` | [`20260611-web-mock-ui`](./20260611-web-mock-ui/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-040-issue-41-triton-first-workflow` | [`20260612-issue-41-triton-first-workflow`](./20260612-issue-41-triton-first-workflow/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-041-issue-42-nested-pager-swipe` | [`20260612-issue-42-nested-pager-swipe`](./20260612-issue-42-nested-pager-swipe/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-042-issue-43-ios-host-input` | [`20260612-issue-43-ios-host-input`](./20260612-issue-43-ios-host-input/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-043-issue-45-foreground-app-identity` | [`20260612-issue-45-foreground-app-identity`](./20260612-issue-45-foreground-app-identity/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-044-web-triad-qa` | [`20260613-web-triad-qa`](./20260613-web-triad-qa/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-045-issue-57-xcode-deriveddata-diagnostics` | [`20260617-issue-57-xcode-deriveddata-diagnostics`](./20260617-issue-57-xcode-deriveddata-diagnostics/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-046-issue-58-webview-provider-capabilities` | [`20260617-issue-58-webview-provider-capabilities`](./20260617-issue-58-webview-provider-capabilities/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-047-issue-59-ios-tap-capture-target` | [`20260617-issue-59-ios-tap-capture-target`](./20260617-issue-59-ios-tap-capture-target/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-048-issue-60-uitableview-row-tap` | [`20260617-issue-60-uitableview-row-tap`](./20260617-issue-60-uitableview-row-tap/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-049-issue-61-android-emulator-adapter` | [`20260617-issue-61-android-emulator-adapter`](./20260617-issue-61-android-emulator-adapter/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-050-issue-62-discovery-timeout` | [`20260617-issue-62-discovery-timeout`](./20260617-issue-62-discovery-timeout/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-051-issue-63-harmony-route-webview-evidence` | [`20260617-issue-63-harmony-route-webview-evidence`](./20260617-issue-63-harmony-route-webview-evidence/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-052-triton-web-command` | [`20260617-triton-web-command`](./20260617-triton-web-command/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-053-ios-runtime-capability-gating` | [`20260618-ios-runtime-capability-gating`](./20260618-ios-runtime-capability-gating/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-054-web-launch-diagnostics` | [`20260618-web-launch-diagnostics`](./20260618-web-launch-diagnostics/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-055-agent-workflow-skill-governance` | [`20260619-agent-workflow-skill-governance`](./20260619-agent-workflow-skill-governance/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-056-issue-65-xcode-wait-idle-timeout` | [`20260619-issue-65-xcode-wait-idle-timeout`](./20260619-issue-65-xcode-wait-idle-timeout/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-057-issue-66-xcode-incremental-cache-ux` | [`20260619-issue-66-xcode-incremental-cache-ux`](./20260619-issue-66-xcode-incremental-cache-ux/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-058-issue-67-agent-ux-evidence-xcode` | [`20260619-issue-67-agent-ux-evidence-xcode`](./20260619-issue-67-agent-ux-evidence-xcode/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-059-issue-68-harmony-app-target-failure` | [`20260619-issue-68-harmony-app-target-failure`](./20260619-issue-68-harmony-app-target-failure/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-060-issue-69-ios-real-device-app-selector` | [`20260619-issue-69-ios-real-device-app-selector`](./20260619-issue-69-ios-real-device-app-selector/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-061-lookin-hierarchy-viewer` | [`20260619-lookin-hierarchy-viewer`](./20260619-lookin-hierarchy-viewer/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-062-vlm-test-runner` | [`20260620-vlm-test-runner`](./20260620-vlm-test-runner/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-063-issue-70-xcode-sdk-macro` | [`20260621-issue-70-xcode-sdk-macro`](./20260621-issue-70-xcode-sdk-macro/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-064-issue-71-schema-status-contract` | [`20260621-issue-71-schema-status-contract`](./20260621-issue-71-schema-status-contract/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-065-issue-73-evidence-ingest` | [`20260621-issue-73-evidence-ingest`](./20260621-issue-73-evidence-ingest/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-066-issue-76-media-fixture-seed` | [`20260621-issue-76-media-fixture-seed`](./20260621-issue-76-media-fixture-seed/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-067-issue-79-launch-env-args` | [`20260621-issue-79-launch-env-args`](./20260621-issue-79-launch-env-args/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-068-issue-80-action-help` | [`20260621-issue-80-action-help`](./20260621-issue-80-action-help/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-069-local-mlx-vlm-provider` | [`20260621-local-mlx-vlm-provider`](./20260621-local-mlx-vlm-provider/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-070-p23-cli-product-surface-rearchitecture` | [`20260621-p23-cli-product-surface-rearchitecture`](./20260621-p23-cli-product-surface-rearchitecture/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-071-triton-inspector-web` | [`20260621-triton-inspector-web`](./20260621-triton-inspector-web/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-072-cli-update-command` | [`20260622-cli-update-command`](./20260622-cli-update-command/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-073-issue-82-xcode-wait-idle` | [`20260622-issue-82-xcode-wait-idle`](./20260622-issue-82-xcode-wait-idle/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-074-issue-83-xcode-build-timeout-output` | [`20260622-issue-83-xcode-build-timeout-output`](./20260622-issue-83-xcode-build-timeout-output/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-075-issue-85-harmony-deveco-workflows` | [`20260622-issue-85-harmony-deveco-workflows`](./20260622-issue-85-harmony-deveco-workflows/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-076-issue-86-xcode-macro-deriveddata` | [`20260622-issue-86-xcode-macro-deriveddata`](./20260622-issue-86-xcode-macro-deriveddata/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-077-test-recorder-replay` | [`20260622-test-recorder-replay`](./20260622-test-recorder-replay/README.md) | 已归档（后继收敛完成） | 历史目录保留；Hybrid 已由 SP-126 交付并归档，不恢复独立 testrec executor |
| `SP-078-open-issues-89-91` | [`20260623-open-issues-89-91`](./20260623-open-issues-89-91/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-079-triton-web-auto-discovery` | [`20260623-triton-web-auto-discovery`](./20260623-triton-web-auto-discovery/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-080-open-issues-95-97` | [`20260624-open-issues-95-97`](./20260624-open-issues-95-97/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-081-react-debug-inspector-web` | [`20260624-react-debug-inspector-web`](./20260624-react-debug-inspector-web/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-082-github-issues-117-118` | [`20260625-github-issues-117-118`](./20260625-github-issues-117-118/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-083-issue-119-update-flow` | [`20260625-issue-119-update-flow`](./20260625-issue-119-update-flow/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-084-issue-120-update-skills` | [`20260630-issue-120-update-skills`](./20260630-issue-120-update-skills/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-085-web-card-render` | [`20260630-web-card-render`](./20260630-web-card-render/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-086-web-redesign` | [`20260630-web-redesign`](./20260630-web-redesign/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-087-host-framebuffer-stream` | [`20260701-host-framebuffer-stream`](./20260701-host-framebuffer-stream/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-088-cross-platform-framebuffer-stream` | [`20260702-cross-platform-framebuffer-stream`](./20260702-cross-platform-framebuffer-stream/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-089-strong-emulator-control` | [`20260702-strong-emulator-control`](./20260702-strong-emulator-control/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-090-host-simulator-ax-takeover` | [`20260703-host-simulator-ax-takeover`](./20260703-host-simulator-ax-takeover/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-091-issue-128-harmony-install-failure` | [`20260703-issue-128-harmony-install-failure`](./20260703-issue-128-harmony-install-failure/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-092-issue-129-harmony-uninstall` | [`20260703-issue-129-harmony-uninstall`](./20260703-issue-129-harmony-uninstall/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-093-issue-130-agent-guidance-current-cli` | [`20260703-issue-130-agent-guidance-current-cli`](./20260703-issue-130-agent-guidance-current-cli/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-094-issue-131-doctor-host-device-scope` | [`20260703-issue-131-doctor-host-device-scope`](./20260703-issue-131-doctor-host-device-scope/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-095-issue-132-appintents-pod-build` | [`20260703-issue-132-appintents-pod-build`](./20260703-issue-132-appintents-pod-build/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-096-issues-133-134-xcode-selectors` | [`20260703-issues-133-134-xcode-selectors`](./20260703-issues-133-134-xcode-selectors/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-097-agent-mobile-runtime-platform` | [`20260706-agent-mobile-runtime-platform`](./20260706-agent-mobile-runtime-platform/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-098-web-hierarchy-source-tabs` | [`20260706-web-hierarchy-source-tabs`](./20260706-web-hierarchy-source-tabs/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-099-web-inspect-session-slots` | [`20260706-web-inspect-session-slots`](./20260706-web-inspect-session-slots/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-100-web-stream-gesture-mapping` | [`20260706-web-stream-gesture-mapping`](./20260706-web-stream-gesture-mapping/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-101-github-issue-batch` | [`20260707-github-issue-batch`](./20260707-github-issue-batch/README.md) | 已归档 | 历史目录保留；2026-10-10 源分支经 `69bdb3b9` 合入 main 并清理 |
| `SP-102-issue-140-redaction-preflight` | [`20260707-issue-140-redaction-preflight`](./20260707-issue-140-redaction-preflight/README.md) | 已归档 | 历史目录保留；2026-10-10 源分支经 `e4a09384` 合入 main 并清理 |
| `SP-103-issues-141-142` | [`20260709-issues-141-142`](./20260709-issues-141-142/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-104-packaged-web-mjpeg` | [`20260709-packaged-web-mjpeg`](./20260709-packaged-web-mjpeg/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-105-issues-144-145-action-docs` | [`20260710-issues-144-145-action-docs`](./20260710-issues-144-145-action-docs/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-106-issue-146-sim-record-duration` | [`20260720-issue-146-sim-record-duration`](./20260720-issue-146-sim-record-duration/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-107-issue-147-harmony-wait-layout-recv` | [`20260720-issue-147-harmony-wait-layout-recv`](./20260720-issue-147-harmony-wait-layout-recv/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-108-issue-148-xcode-simulator-destination` | [`20260720-issue-148-xcode-simulator-destination`](./20260720-issue-148-xcode-simulator-destination/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-109-issue-149-ios-host-wait` | [`20260720-issue-149-ios-host-wait`](./20260720-issue-149-ios-host-wait/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-110-issue-150-xcode-package-build` | [`20260720-issue-150-xcode-package-build`](./20260720-issue-150-xcode-package-build/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-111-issue-151-evidence-partial-capture` | [`20260720-issue-151-evidence-partial-capture`](./20260720-issue-151-evidence-partial-capture/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-112-issue-152-real-device-launch-env` | [`20260720-issue-152-real-device-launch-env`](./20260720-issue-152-real-device-launch-env/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-113-issue-153-real-device-app-pull` | [`20260720-issue-153-real-device-app-pull`](./20260720-issue-153-real-device-app-pull/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-114-issue-154-runtime-skill-command-hierarchy` | [`20260720-issue-154-runtime-skill-command-hierarchy`](./20260720-issue-154-runtime-skill-command-hierarchy/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-115-issue-155-ios-simulator-process-console` | [`20260720-issue-155-ios-simulator-process-console`](./20260720-issue-155-ios-simulator-process-console/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-116-issue-156-ios-button-primary-menu` | [`20260721-issue-156-ios-button-primary-menu`](./20260721-issue-156-ios-button-primary-menu/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-117-issue-157-table-cell-selection-callback` | [`20260721-issue-157-table-cell-selection-callback`](./20260721-issue-157-table-cell-selection-callback/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-118-issue-158-ios-real-device-screenshot-scope` | [`20260721-issue-158-ios-real-device-screenshot-scope`](./20260721-issue-158-ios-real-device-screenshot-scope/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-119-issue-159-alert-modal-boundary` | [`20260722-issue-159-alert-modal-boundary`](./20260722-issue-159-alert-modal-boundary/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-120-issue-160-xcode-build-settings` | [`20260722-issue-160-xcode-build-settings`](./20260722-issue-160-xcode-build-settings/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-121-issue-161-runtime-screenshot-format` | [`20260722-issue-161-runtime-screenshot-format`](./20260722-issue-161-runtime-screenshot-format/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-122-issue-162-ios-real-device-launch-resolution` | [`20260722-issue-162-ios-real-device-launch-resolution`](./20260722-issue-162-ios-real-device-launch-resolution/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-123-issue-163-xcresult-array-decoding` | [`20260722-issue-163-xcresult-array-decoding`](./20260722-issue-163-xcresult-array-decoding/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-124-issue-164-evidence-simulator-screenshot-fidelity` | [`20260722-issue-164-evidence-simulator-screenshot-fidelity`](./20260722-issue-164-evidence-simulator-screenshot-fidelity/README.md) | 已归档 | 历史目录保留；2026-10-10 源分支经 `5f6fbecb` 合入 main 并清理 |
| `SP-125-issue-165-xcode-schemes-discovery-timeout` | [`20260722-issue-165-xcode-schemes-discovery-timeout`](./20260722-issue-165-xcode-schemes-discovery-timeout/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-126-testrec-convergence` | [`SP-126-testrec-convergence`](./SP-126-testrec-convergence/README.md) | 已归档 | bounded importer、单 flow 真实纵切与兼容边界已交付并入主线；未来可靠性专项按路线总览唯一入口条件触发，不挂起本 space |
| `SP-127-issue-168-ios-real-device-terminate-pid` | [`SP-127-issue-168-ios-real-device-terminate-pid`](./SP-127-issue-168-ios-real-device-terminate-pid/README.md) | 已发布（v0.2.16） | 规范目录；#168 已关闭；无可证实 PID 时 fail closed，未声称真机 bundle-ID terminate 成功 |
| `SP-128-issue-167-xcode-device-alias-preflight` | [`SP-128-issue-167-xcode-device-alias-preflight`](./SP-128-issue-167-xcode-device-alias-preflight/README.md) | 已发布（v0.2.16） | 规范目录；#167 已关闭；build 前 alias preflight 已发布，真实 Xcode/device 缺口保留 |
| `SP-129-serve-loopback-default` | [`SP-129-serve-loopback-default`](./SP-129-serve-loopback-default/README.md) | 已完成（本地） | 规范目录；checkpoint 已经由 `d0f09d3c` 进入本地 main，Bonjour 风险不变 |
| `SP-130-issue-166-runtime-jpeg-normalization` | [`SP-130-issue-166-runtime-jpeg-normalization`](./SP-130-issue-166-runtime-jpeg-normalization/README.md) | 已发布（v0.2.16） | 规范目录；#166 已关闭；JPEG→PNG 主修复已发布，SP-149 metadata follow-up 已由 PR #177 合并 |
| `SP-131-ios-simulator-canonical-proof` | [`SP-131-ios-simulator-canonical-proof`](./SP-131-ios-simulator-canonical-proof/README.md) | 已登记 | 规范目录；真实 dedicated Simulator proof 已通过并形成 local checkpoint，不扩 testrec/Android/Web |
| `SP-132-testrec-import-seam` | [`SP-132-testrec-import-seam`](./SP-132-testrec-import-seam/README.md) | 已登记 | 规范目录；P0 离线 importer 已完成本地 checkpoint：显式 bundle/ios-simulator target、严格 fail-closed、typed provenance，不扩 executor/Android/Web |
| `SP-133-imported-ios-simulator-proof` | [`SP-133-imported-ios-simulator-proof`](./SP-133-imported-ios-simulator-proof/README.md) | 已登记 | 规范目录；P1 imported iOS Simulator proof 已完成本地 checkpoint，真实 `test run` 与 typed provenance/evidence 已验证，不扩 executor/Android/Web |
| `SP-134-ios-simulator-reliability-gate` | [`SP-134-ios-simulator-reliability-gate`](./SP-134-ios-simulator-reliability-gate/README.md) | 已归档 | 离线 gate 与后继 receipt-backed 加固已交付；真实 3×20+1 未采样，专项仅在明确项目需求或可靠性承诺前另立范围 |
| `SP-135-testrec-compatibility-guidance` | [`SP-135-testrec-compatibility-guidance`](./SP-135-testrec-compatibility-guidance/README.md) | 已登记 | 规范目录；本地 checkpoint `37d8f9c7` 已收紧 testrec local-simulated/dry-run/matrix 的 offline diagnostic 与迁移合同，不新增 executor |
| `SP-136-ios-simulator-reliability-collection-preflight` | [`SP-136-ios-simulator-reliability-collection-preflight`](./SP-136-ios-simulator-reliability-collection-preflight/README.md) | 已完成（本地） | 规范目录；已冻结 3 flow × 20 的 offline collection preflight，不启动 runtime/device/server，不生成 evidence 或 receipt |
| `SP-137-issue-171-safe-collection-tap` | [`SP-137-issue-171-safe-collection-tap`](./SP-137-issue-171-safe-collection-tap/README.md) | 已发布（v0.2.16） | 规范目录；#171 已关闭；无安全 activation 时 structured unsupported，不越过当前 cell |
| `SP-138-issue-170-xcode-real-device-destination` | [`SP-138-issue-170-xcode-real-device-destination`](./SP-138-issue-170-xcode-real-device-destination/README.md) | 已发布（v0.2.16） | 规范目录；#170 已关闭；exact raw execution destination 与公开面脱敏已发布，真实设备 smoke 未执行 |
| `SP-139-issue-169-xcode-focused-testing` | [`SP-139-issue-169-xcode-focused-testing`](./SP-139-issue-169-xcode-focused-testing/README.md) | 已发布（v0.2.16） | 规范目录；#169 已关闭；repeatable focused XCTest selection 已发布，真实 XCTest 未执行 |
| `SP-140-ios-simulator-reliability-live-harness` | [`SP-140-ios-simulator-reliability-live-harness`](./SP-140-ios-simulator-reliability-live-harness/README.md) | 已完成（本地） | 规范目录；receipt-backed reserve/sample、strict canonical target 与 local focused verification 已完成；真实 3×20+1 仍需 dedicated target/server/reset/evidence 授权 |
| `SP-141-packaged-web-simulator-input` | [`SP-141-packaged-web-simulator-input`](./SP-141-packaged-web-simulator-input/README.md) | 已发布（v0.2.16） | 规范目录；packaged bridge 已对齐 simulator/emulator host input 与 iOS real runtime mirror 分流，Homebrew 安装版与真实 Simulator browser smoke 通过 |
| `SP-142-web-readonly-contract` | [`SP-142-web-readonly-contract`](./SP-142-web-readonly-contract/README.md) | 已完成（已吸收） | 规范目录；已由 SP-151 集成，source branch/worktree 已清理；browser Web write endpoint 统一 405 readonly，React/HTML/Vite bridge 已去除 write dispatch |
| `SP-143-reliability-gate-integrity` | [`SP-143-reliability-gate-integrity`](./SP-143-reliability-gate-integrity/README.md) | 已完成（已吸收） | 规范目录；已由 SP-151 集成，source branch/worktree 已清理；收紧 legacy diagnostic / receipt authority、typed negative、collection lease 与 evidence artifact 归因 |
| `SP-144-reliability-receipt-anchor` | [`SP-144-reliability-receipt-anchor`](./SP-144-reliability-receipt-anchor/README.md) | 已完成（已吸收） | 规范目录；已由 SP-151 集成，source branch/worktree 已清理；operator/CI root 外 SHA-256 anchor 合同保留 |
| `SP-145-private-identity-chain-v2` | [`SP-145-private-identity-chain-v2`](./SP-145-private-identity-chain-v2/README.md) | 已完成（已吸收） | 规范目录；已由 SP-151 集成，source branch/worktree 已清理；private identity chain 与安全 aggregate 合同保留 |
| `SP-146-stage1-metric-contract` | [`SP-146-stage1-metric-contract`](./SP-146-stage1-metric-contract/README.md) | 已完成（已吸收） | 规范目录；已由 SP-151 集成，source branch/worktree 已清理；receipt-backed Stage 1A/1B metric contract 保留 |
| `SP-147-schema-fact-source-mainline` | [`SP-147-schema-fact-source-mainline`](./SP-147-schema-fact-source-mainline/README.md) | 已完成（已吸收） | 规范目录；已由 SP-151 集成，source branch/worktree 已清理；CLI schema fact-source 与实际 parser/DTO/recovery output 对齐 |
| `SP-148-schema-placeholder-tokens` | [`SP-148-schema-placeholder-tokens`](./SP-148-schema-placeholder-tokens/README.md) | 已完成（已吸收） | 规范目录；已由 SP-151 集成，source branch/worktree 已清理；完整 `<canonical>` argv placeholder 合同保留 |
| `SP-149-issue-166-evidence-metadata-contract` | [`SP-149-issue-166-evidence-metadata-contract`](./SP-149-issue-166-evidence-metadata-contract/README.md) | 已完成（已吸收） | 规范目录；已由 SP-151 集成，source branch/worktree 已清理；#166 normalizer error 与 published PNG metadata contract 保留 |
| `SP-150-reliability-failure-recovery-semantics` | [`SP-150-reliability-failure-recovery-semantics`](./SP-150-reliability-failure-recovery-semantics/README.md) | 已完成（已吸收） | 规范目录；已由 SP-151 集成，source branch/worktree 已清理；validated plan terminal failure/recovery fail-closed contract 保留 |
| `SP-151-trusted-baseline-integration` | [`SP-151-trusted-baseline-integration`](./SP-151-trusted-baseline-integration/README.md) | 已归档（PR #177） | 规范目录；SP-142～156 已由 merge `66f975d9` 进入 `main`，CI `30515397742` 全绿，source branch/worktree 已清理 |
| `SP-152-issue-172-runtime-reregistration` | [`SP-152-issue-172-runtime-reregistration`](./SP-152-issue-172-runtime-reregistration/README.md) | 已合并（PR #177） | 规范目录；#172 已关闭；connection generation、legacy compatibility 与 doctor diagnostics 已进入 `main` |
| `SP-153-issue-173-xcode-run-target-binding` | [`SP-153-issue-173-xcode-run-target-binding`](./SP-153-issue-173-xcode-run-target-binding/README.md) | 已合并（PR #177） | 规范目录；#173 已关闭；Xcode run 单目标绑定已进入 `main` |
| `SP-154-issue-174-simulator-swipe-lifecycle` | [`SP-154-issue-174-simulator-swipe-lifecycle`](./SP-154-issue-174-simulator-swipe-lifecycle/README.md) | 已合并（PR #177） | 规范目录；#174 已关闭；persistent input、ack 与 terminal linger 已进入 `main` |
| `SP-155-issue-175-ios-readiness-coredevice` | [`SP-155-issue-175-ios-readiness-coredevice`](./SP-155-issue-175-ios-readiness-coredevice/README.md) | 已合并（PR #177） | 规范目录；#175 已关闭；available-paired readiness 与 fail-closed blockers 已进入 `main` |
| `SP-156-issue-176-xcode-compact-progress` | [`SP-156-issue-176-xcode-compact-progress`](./SP-156-issue-176-xcode-compact-progress/README.md) | 已合并（PR #177） | 规范目录；#176 已关闭；compact/full Xcode build progress 已进入 `main` |
| `SP-157-open-issues-178-195-audit` | [`SP-157-open-issues-178-195-audit`](./SP-157-open-issues-178-195-audit/README.md) | 已归档 | #178–#194 已在主线 `e77c72b7` 验证并关闭；全量 CI `31301092517` 通过，#164 dirty worktree 保持原样 |
| `SP-158-issue-196-xcode-archive-export` | [`SP-158-issue-196-xcode-archive-export`](./SP-158-issue-196-xcode-archive-export/README.md) | 已归档 | #196 archive/export 已在主线 `e77c72b7` 验证并关闭；真实签名/IPA 安装仍保留为风险 |
| `SP-159-issue-195-ios-ddi-recovery` | [`SP-159-issue-195-ios-ddi-recovery`](./SP-159-issue-195-ios-ddi-recovery/README.md) | 已归档 | #195 `ddi_missing` recovery 已在主线 `e77c72b7` 验证并关闭；真实 DDI/tunnel smoke 仍待设备与授权 |
| `SP-160-issue-197-harmony-wait-budget` | [`SP-160-issue-197-harmony-wait-budget`](./SP-160-issue-197-harmony-wait-budget/README.md) | 已归档 | #197 0.4 秒最小 layout capture budget 已在主线 `e77c72b7` 验证并关闭；真实 Harmony HDC/ArkUI smoke 仍待 target |
| `SP-161-issue-198-harmony-signed-hap` | [`SP-161-issue-198-harmony-signed-hap`](./SP-161-issue-198-harmony-signed-hap/README.md) | 已发布（v0.2.18） | #198 signed-only `assembleApp` artifact discovery 已发布并随 CI `31778845414` 关闭；真实 Harmony 签名工程与 HDC 安装未复测 |
| `SP-162-issue-199-ios-collection-cell-host-hid` | [`SP-162-issue-199-ios-collection-cell-host-hid`](./SP-162-issue-199-ios-collection-cell-host-hid/README.md) | 已完成（本地 follow-up） | #199 核心 fallback 已发布于 v0.2.18，本轮补齐 same-target matched-OID recovery 与 target-bound verification；已随 CI `31778845414` 关闭，follow-up 随下一 patch 发布 |
| `SP-163-issue-200-simulator-foreground-runtime` | [`SP-163-issue-200-simulator-foreground-runtime`](./SP-163-issue-200-simulator-foreground-runtime/README.md) | 已关闭 | #200 显式 Simulator selector 的纯坐标 tap 已在 embedded `/targets` 前改走 ready local host-HID；已随 CI `31778845414` 评论/关闭，真实 Simulator/Baguette 验证待后续授权 |
| `SP-164-issue-201-harmony-act-find` | [`SP-164-issue-201-harmony-act-find`](./SP-164-issue-201-harmony-act-find/README.md) | 已关闭 | #201 `act find` 已支持 `--platform harmony --device <harmony-target>` 从 Harmony uitest host layout 解析，Harmony `--device` 不再落入 embedded iOS server；`--platform ios|android` 返回 typed `unsupported_capability`；已随 CI `31791782001` 关闭，真实 Harmony/HDC 验证保留 |
| `SP-165-issue-202-sim-tap-help-dimensions` | [`SP-165-issue-202-sim-tap-help-dimensions`](./SP-165-issue-202-sim-tap-help-dimensions/README.md) | 已关闭 | #202 `sim tap` 的 point-space 已从 Simulator layout metadata 推导，help 宣传的 `--x/--y` 形状无需 width/height 即可满足 host action model；schema failureCodes/summary 已对齐；已随 CI `31791782001` 关闭，真实 Simulator/Baguette 验证保留 |
| `SP-166-issue-203-ios-text-query-consistency` | [`SP-166-issue-203-ios-text-query-consistency`](./SP-166-issue-203-ios-text-query-consistency/README.md) | 已关闭 | #203 embedded `wait --text` 与 `act find` 已共享 observe 的文本归一化（trim + case/diacritic fold + substring）与 hidden visibility 规则；`act find` 无匹配返回结构化 `text_not_found` 而非成功空输出；已随 CI `31791782001` 关闭，真实 Simulator 验证保留 |
| `SP-167-issue-204-ios-webview-form-input` | [`SP-167-issue-204-ios-webview-form-input`](./SP-167-issue-204-ios-webview-form-input/README.md) | 已关闭 | #204 为私有 iOS WKWebView 提供 provider-backed 表单输入契约：snapshot 发现 contenteditable/textarea 表单目标、`webview focus/type/set-text` 与 `act ... --webview` 一等公民焦点切换、input/change dispatch 证据与 value 后置条件、未 opt-in 时 typed unsupported + host-HID fallback；已随 CI `31791782001` 关闭，真实 WebView/Simulator 验证保留 |
| `SP-168-issue-205-target-leases` | [`SP-168-issue-205-target-leases`](./SP-168-issue-205-target-leases/README.md) | 已关闭 | #205 并行 agent 流程现可用 opt-in 目标租约（acquire/status/release/takeover、带界 TTL、owner 标签、`target_lease_conflict` 稳定信封）；`app open-url|launch|terminate` 与 `act tap` 支持 `--lease` 门禁，只读观察豁免，无租约时行为不变；已随 CI `31791782001` 关闭，真实 Simulator 验证保留 |
| `SP-169-issue-206-app-marketing-version` | [`SP-169-issue-206-app-marketing-version`](./SP-169-issue-206-app-marketing-version/README.md) | 已关闭 | #206 iOS `app info`/`app list` 已暴露 `marketingVersion`/`buildNumber`，legacy `version` 映射 build number；schema `host.app-info`/`host.app-list` 已挂载；已随 CI `31791782001` 关闭 |
| `SP-170-issue-210-xcode-test-bounded-jsonl` | [`SP-170-issue-210-xcode-test-bounded-jsonl`](./SP-170-issue-210-xcode-test-bounded-jsonl/README.md) | 已归档 | 主线 82a13db5 / CI 34179623896 通过；对应 issue 已关闭，worktree 保留 |
| `SP-171-issue-209-collection-cell-activation` | [`SP-171-issue-209-collection-cell-activation`](./SP-171-issue-209-collection-cell-activation/README.md) | 已归档 | 主线 82a13db5 / CI 34179623896 通过；对应 issue 已关闭，worktree 保留 |
| `SP-172-issue-208-longpress-gesture-path` | [`SP-172-issue-208-longpress-gesture-path`](./SP-172-issue-208-longpress-gesture-path/README.md) | 已归档 | 主线 82a13db5 / CI 34179623896 通过；对应 issue 已关闭，worktree 保留 |
| `SP-173-issue-207-harmony-arkweb-bridge-call` | [`SP-173-issue-207-harmony-arkweb-bridge-call`](./SP-173-issue-207-harmony-arkweb-bridge-call/README.md) | 已归档 | 主线 82a13db5 / CI 34179623896 通过；对应 issue 已关闭，worktree 保留 |
| `SP-174-issue-211-label-text-attributes` | [`SP-174-issue-211-label-text-attributes`](./SP-174-issue-211-label-text-attributes/README.md) | 已归档 | 主线 82a13db5 / CI 34179623896 通过；对应 issue 已关闭，worktree 保留 |
| `SP-175-issue-212-xcode-cache-evidence` | [`SP-175-issue-212-xcode-cache-evidence`](./SP-175-issue-212-xcode-cache-evidence/README.md) | 已归档 | 主线 82a13db5 / CI 34179623896 通过；对应 issue 已关闭，worktree 保留 |
| `SP-176-open-issues-integration` | [`SP-176-open-issues-integration`](./SP-176-open-issues-integration/README.md) | 已归档 | 主线 82a13db5 / CI 34179623896 通过；对应 issue 已关闭，worktree 保留 |
| `SP-177-ios-simulator-resource-management` | [`SP-177-ios-simulator-resource-management`](./SP-177-ios-simulator-resource-management/README.md) | 已归档（范围收口） | 单设备 plan/apply/verify/restore 已由 SP-196 随 v0.2.28 交付；fleet、自动 replay/evidence 编排与量化性能目标撤出当前队列 |
| `SP-178-issue-213-real-device-runtime` | [`SP-178-issue-213-real-device-runtime`](./SP-178-issue-213-real-device-runtime/README.md) | 已归档 | 已发布 v0.2.21 并回复关闭 #213；CLI 983/root 269、CocoaPods lint 与门禁通过，Release 34943378497 双架构与 Homebrew 全过；真机端到端未复测 |
| `SP-179-issue-214-derived-data-cleanup` | [`SP-179-issue-214-derived-data-cleanup`](./SP-179-issue-214-derived-data-cleanup/README.md) | 已归档（取消自动删除） | 保留 inspect / dry-run 与 confirm fail-closed；取消通用缓存自动删除，不表示安全删除已实现；远端 #214 最后核实为 OPEN，本轮未操作远端 |
| `SP-180-xcode27-simulator-frameworks` | [`SP-180-xcode27-simulator-frameworks`](./SP-180-xcode27-simulator-frameworks/README.md) | 兼容修复验证／命中待补 | Xcode27 SharedFrameworks 子进程加载器恢复；8测试、CLI993+14及本地门禁通过（10-06）；host ACK导航仍待独立补验，未发布 |
| `SP-181-device-hub-paradigm` | [`SP-181-device-hub-paradigm`](./SP-181-device-hub-paradigm/README.md) | 研究已归档 | Device Hub 范式研究保留；无当前自动实施排期，仅由明确新需求另行裁决 |
| `SP-182-trusted-execution-system` | [`SP-182-trusted-execution-system`](./SP-182-trusted-execution-system/README.md) | 设计已归档 | 可信执行系统双路径设计保留；未进入产品实现，无当前自动立项任务 |
| `SP-183-device-hub-official-adapter` | [`SP-183-device-hub-official-adapter`](./SP-183-device-hub-official-adapter/README.md) | 已归档（范围收缩） | v0.2.24 已交付能力继续维护；watchOS/tvOS runner、Temporary 查询保留实验/未验收，visionOS 2D 撤出排期，unsupported 不自动转待办；历史真机恢复状态 unknown 保留人工交接 |
| `SP-184-issue-215-host-swipe` | [`SP-184-issue-215-host-swipe`](./SP-184-issue-215-host-swipe/README.md) | v0.2.25 已发布／#215–220 已关闭 | #215：离线 Simulator swipe CLI；163 focused tests 通过，真实 swipe/pager 未验证 |
| `SP-185-issue-216-host-input-discovery` | [`SP-185-issue-216-host-input-discovery`](./SP-185-issue-216-host-input-discovery/README.md) | v0.2.25 已发布／#215–220 已关闭 | #216：type discovery 与 pasteboard guidance；37 focused tests 通过，输入仍 fail closed |
| `SP-186-issue-217-xcode-run-exit` | [`SP-186-issue-217-xcode-run-exit`](./SP-186-issue-217-xcode-run-exit/README.md) | v0.2.25 已发布／#215–220 已关闭 | #217：xcode run 构建失败非零退出与单一 final；2 focused tests 通过 |
| `SP-187-issue-218-host-hid-availability` | [`SP-187-issue-218-host-hid-availability`](./SP-187-issue-218-host-hid-availability/README.md) | v0.2.25 已发布／#215–220 已关闭 | #218：隔离兼容性诊断与实际 bootstrap 失败分类；15 + 8 focused tests 通过，不宣称现代 HID 可用 |
| `SP-188-issue-219-generic-ios-build` | [`SP-188-issue-219-generic-ios-build`](./SP-188-issue-219-generic-ios-build/README.md) | v0.2.25 已发布／#215–220 已关闭 | #219：显式 generic iOS SDK-only build；51 + 5 focused tests 通过，未做真实 SDK 编译 |
| `SP-189-issue-220-package-result-path` | [`SP-189-issue-220-package-result-path`](./SP-189-issue-220-package-result-path/README.md) | v0.2.25 已发布／#215–220 已关闭 | #220：package result 路径与 inline parser 一致；49 + 2 focused tests 通过，夹具贯通执行结果路径解析，非实际 Xcode test |
| `SP-190-open-issues-integration` | [`SP-190-open-issues-integration`](./SP-190-open-issues-integration/README.md) | v0.2.25 已发布／#215–220 已关闭 | #214–#220 本地集成与统一验收；保留各项证据边界，#215～220 已关闭，#214 继续开放 |

| `SP-191-default-xcode-deriveddata` | [`SP-191-default-xcode-deriveddata`](./SP-191-default-xcode-deriveddata/README.md) | 已发布 | 默认使用 Xcode 全局 DerivedData；`v0.2.26` 已发布，CLI/root tests、schema smoke、docs 门禁与远端 CI 通过；`--derived-data-path` 仅显式隔离/恢复，可能造成高磁盘占用 |
| `SP-192-ictrl-adoption-feasibility` | [`SP-192-ictrl-adoption-feasibility`](./SP-192-ictrl-adoption-feasibility/README.md) | 已合入本地 main | 五机制已接CLI/HTTP/runtime；CLI1250、root274、Web12及真实只读AX/alias/OCR/settle通过；iOS115、Android52与完整APK通过，本地门禁复跑通过；源码已合入本地main，worktree已清理 |
| `SP-193-ictrl-reference-tracking` | [`SP-193-ictrl-reference-tracking`](./SP-193-ictrl-reference-tracking/README.md) | 长期追踪已启用 | 正式参考档案、基线与本聊天每日 10:00 自动化已登记；有价值变化通知；采用按SP-207独立立项并验证合并 |
| `SP-194-reference-project-updates` | [`SP-194-reference-project-updates`](./SP-194-reference-project-updates/README.md) | 已归档 | 23主要仓库+9候选，上游版本/增量/限制与借鉴建议已汇总；docs门禁与来源校验通过 |

| `SP-195-ios-runner-product` | [`SP-195-ios-runner-product`](./SP-195-ios-runner-product/README.md) | 已引入本地main | Runner统一CLI/HTTP/随包；CLI1297+36、完整门禁与真机/Simulator通过；主仓门禁exit0；参考文档与产品分别提交，未push/release；已完成worktree收口见SP195计划；本地完成分支已清理/归档 |

| `SP-196-upstream-optimization-delivery` | [`SP-196-upstream-optimization-delivery`](./SP-196-upstream-optimization-delivery/README.md) | 已发布v0.2.28 | 分段提交与主线集成；CLI1394+51、真实iOS76、双架构/skills/Runner/Homebrew通过；专项未测边界保留；worktree/分支已清理 |


| `SP-197-view-annotation` | [`SP-197-view-annotation`](./SP-197-view-annotation/README.md) | 已合入本地main | 可选UIKit高亮与条件恢复已验收；7b1a2f76集成实现、证据和skills，保留并行WIP；worktree/分支已清理 |

| `SP-198-agent-experience-loop` | [`SP-198-agent-experience-loop`](./SP-198-agent-experience-loop/README.md) | 本地提交归档 | Agent默认自动沉淀、主题索引与原权威资料修订退出；28隔离用例通过，远端CI未运行 |

| `SP-199-mobile-mcp-reference` | [`SP-199-mobile-mcp-reference`](./SP-199-mobile-mcp-reference/README.md) | 已归档 | 参考档案与当前源码差距完成；历史199-space研究门禁通过；后由SP-207统一追踪，SP-212采用切片已合main |

| `SP-200-mobile-device-parity` | [`SP-200-mobile-device-parity`](./SP-200-mobile-device-parity/README.md) | 已合入本地main | 10acfae6已进入main，worktree/分支已清理；排除云预订/MCP |

| `SP-201-sdk-floating-picker` | [`SP-201-sdk-floating-picker`](./SP-201-sdk-floating-picker/README.md) | v0.2.30已发布 | 3f1b500a已整合；UIKit/真实手势与CLI闭环通过，worktree/分支已清理，双架构与安装验收通过 |

| `SP-202-ictrl-security-assessment` | [`SP-202-ictrl-security-assessment`](./SP-202-ictrl-security-assessment/README.md) | 评估完成 | 静态评估归档；采用项由SP-203～205实施并经SP-206本地整合 |

| `SP-203-ictrl-discovery-hardening` | [`SP-203-ictrl-discovery-hardening`](./SP-203-ictrl-discovery-hardening/README.md) | v0.2.30已发布 | 默认发现/广播显式开启；联合验证通过；已发布；真实App接入另验；worktree/分支已清理 |

| `SP-204-ictrl-log-privacy` | [`SP-204-ictrl-log-privacy`](./SP-204-ictrl-log-privacy/README.md) | v0.2.30已发布 | 响应日志元数据白名单、限长和计数；业务payload不变；双架构与安装验收通过；worktree/分支已清理 |

| `SP-205-ios-runner-auth-hardening` | [`SP-205-ios-runner-auth-hardening`](./SP-205-ios-runner-auth-hardening/README.md) | v0.2.30已发布 | 会话加密通道与实际socket/路由鉴权负例通过；设备运行未验收；worktree/分支已清理 |

| `SP-206-ictrl-security-integration` | [`SP-206-ictrl-security-integration`](./SP-206-ictrl-security-integration/README.md) | v0.2.30已发布 | SP-203～205已整合；057d1012补齐收口历史，worktree/分支已清理 |

| `SP-207-reference-adoption-pipeline` | [`SP-207-reference-adoption-pipeline`](./SP-207-reference-adoption-pipeline/README.md) | 持续追踪与采用 | 10月26日补查后24完整/9 partial；16条采用已合main，11个执行/主控会话已归档 |

| `SP-208-update-version-alignment` | [`SP-208-update-version-alignment`](./SP-208-update-version-alignment/README.md) | v0.2.30已发布 | 6c120ccd已整合；main门禁与CLI1474+59通过，worktree/分支已清理，双架构与安装验收通过 |

| `SP-209-picker-runtime-toggle` | [`SP-209-picker-runtime-toggle`](./SP-209-picker-runtime-toggle/README.md) | v0.2.30已发布 | 系统半屏Modal五路由、选择器二级配置与独立显隐；0e296783已合入main，发布安装验收通过；分支/worktree已清理 |


| `SP-210-simulator-ax-geometry` | [`SP-210-simulator-ax-geometry`](./SP-210-simulator-ax-geometry/README.md) | v0.2.32已发布 | 7a8e9f56；本期离线验收通过，main合后完整CLI与local门禁复验通过；已推送/发布；分支/worktree已清理 |

| `SP-211-reference-adoption-integration` | [`SP-211-reference-adoption-integration`](./SP-211-reference-adoption-integration/README.md) | v0.2.32已发布 | 7a8e9f56；本期离线验收通过，main合后完整CLI与local门禁复验通过；已推送/发布；分支/worktree已清理 |

| `SP-212-mobile-mcp-android-contracts` | [`SP-212-mobile-mcp-android-contracts`](./SP-212-mobile-mcp-android-contracts/README.md) | v0.2.32已发布 | 7a8e9f56；本期离线验收通过，main合后完整CLI与local门禁复验通过；已推送/发布；分支/worktree已清理 |

| `SP-213-mobile-mcp-contracts-integration` | [`SP-213-mobile-mcp-contracts-integration`](./SP-213-mobile-mcp-contracts-integration/README.md) | v0.2.32已发布 | 7a8e9f56；本期离线验收通过，main合后完整CLI与local门禁复验通过；已推送/发布；分支/worktree已清理 |

2026-10-19追加：原主目录WIP已原样保存为1131b183并完成差异裁决，资料状态与本地main一致；[完整合并记录](./SP-211-reference-adoption-integration/plans/20261019-wip-closeout.md)。

| `SP-214-simulator-display-safety` | [`SP-214-simulator-display-safety`](./SP-214-simulator-display-safety/README.md) | v0.2.32已发布 | `0d35e95e`；2026-10-24由SP-218补真实displays修复与截图通过；AX/跨工具链另验；worktree/分支已清理 |

| `SP-215-simulator-display-integration` | [`SP-215-simulator-display-integration`](./SP-215-simulator-display-integration/README.md) | v0.2.32已发布 | `b782c192`；原离线集成完成；2026-10-24真实截图与兼容修复由SP-218接替；worktree/分支已清理 |

| `SP-216-harmony-forward-cleanup` | [`SP-216-harmony-forward-cleanup`](./SP-216-harmony-forward-cleanup/README.md) | v0.2.32已发布 | `34f713c7`；HDC ownership 清理与 37 项 focused tests 通过，真实 HDC 未执行；worktree/分支已清理 |

| `SP-217-harmony-forward-integration` | [`SP-217-harmony-forward-integration`](./SP-217-harmony-forward-integration/README.md) | v0.2.32已发布 | `36145c62`；离线验收完成，真实 HDC/跨进程竞态未执行；worktree/分支已清理 |

| `SP-218-issue-222-device-hub-input` | [`SP-218-issue-222-device-hub-input`](./SP-218-issue-222-device-hub-input/README.md) | 已归档／真实验收通过 | 2026-10-24 native HID tap/swipe、Hub占用拒绝及恢复通过；兼容修复/文档已由c0ce0cc2推送；v0.2.33已发布，双架构/Homebrew/只读Web验收通过 |
| `SP-219-simulator-resizable-routing` | [`SP-219-simulator-resizable-routing`](./SP-219-simulator-resizable-routing/README.md) | 已归档／录制真实验收通过 | 2026-10-24普通→Resize→普通视频真实解码通过；Resize AX/HID保持unsupported |
| `SP-220-simulator-resizable-integration` | [`SP-220-simulator-resizable-integration`](./SP-220-simulator-resizable-integration/README.md) | v0.2.32已发布 | SP-219 主控验证与本地合并；候选 `51cd20dd` → `f9399e5e`；worktree已清理 |
| `SP-221-simulator-resource-read-retry` | [`SP-221-simulator-resource-read-retry`](./SP-221-simulator-resource-read-retry/README.md) | 已合本地main | a0eebff0；focused37、完整CLI及合后root/local/docs通过；真实恢复未测；worktree/branch已清理 |
| `SP-222-simulator-resource-retry-integration` | [`SP-222-simulator-resource-retry-integration`](./SP-222-simulator-resource-retry-integration/README.md) | 已验收合本地main | 独立候选4249bd26、报告95a1dc8f、合并a0eebff0；证据已归档、worktree/branch已清理；真实恢复未验，未push/tag/release |

| `SP-223-host-process-drain-deadline` | [`SP-223-host-process-drain-deadline`](./SP-223-host-process-drain-deadline/README.md) | 已验收合本地main | 9fbda1d5；独立/合后完整CLI及local通过，源worktree/branch已清理 |
| `SP-224-host-process-drain-integration` | [`SP-224-host-process-drain-integration`](./SP-224-host-process-drain-integration/README.md) | 已验收合本地main | 主控1c735787；独立/合后门禁通过，源worktree/branch已归档清理 |

| `SP-225-simulator-files-recents` | [`SP-225-simulator-files-recents`](./SP-225-simulator-files-recents/README.md) | 已验收合本地main | 607cdf1c；94+1528完整CLI/离线JSON/docs通过，已清理并关闭会话 |
| `SP-226-files-recents-integration` | [`SP-226-files-recents-integration`](./SP-226-files-recents-integration/README.md) | 已验收合本地main | 主控1847653e；53份证据归档，worktree/branch与会话已关闭 |
| `SP-227-release-v0-2-34` | [`SP-227-release-v0-2-34`](./SP-227-release-v0-2-34/README.md) | v0.2.34已发布 | `4a8de0af`；Release/CI 7 job、双架构资产、skills、Homebrew 与仓库外 packaged Web smoke 全部通过；CocoaPods仅lint |

| `SP-228-issue-226-real-device-launch-args` | [`SP-228-issue-226-real-device-launch-args`](./SP-228-issue-226-real-device-launch-args/README.md) | 已合并，issue已关闭 | 2026-10-28 issue批次；PR #233已合远端main；当前处置/复验计划见SP-241合并归档报告；已随v0.2.35发布，验收见SP-242 |

| `SP-229-issue-227-android-build-diagnostics` | [`SP-229-issue-227-android-build-diagnostics`](./SP-229-issue-227-android-build-diagnostics/README.md) | 已合并，issue已关闭 | 2026-10-28 issue批次；PR #233已合远端main；当前处置/复验计划见SP-241合并归档报告；已随v0.2.35发布，验收见SP-242 |

| `SP-230-issue-228-android-wait-ready` | [`SP-230-issue-228-android-wait-ready`](./SP-230-issue-228-android-wait-ready/README.md) | 已合并，issue已关闭 | 2026-10-28 issue批次；PR #233已合远端main；当前处置/复验计划见SP-241合并归档报告；已随v0.2.35发布，验收见SP-242 |

| `SP-231-issue-229-android-observe-stale-tree` | [`SP-231-issue-229-android-observe-stale-tree`](./SP-231-issue-229-android-observe-stale-tree/README.md) | 已合并，issue已关闭 | 2026-10-28 issue批次；PR #233已合远端main；当前处置/复验计划见SP-241合并归档报告；已随v0.2.35发布，验收见SP-242 |

| `SP-232-issue-231-simulator-log-partial` | [`SP-232-issue-231-simulator-log-partial`](./SP-232-issue-231-simulator-log-partial/README.md) | 已合并，issue已关闭 | 2026-10-28 issue批次；PR #233已合远端main；当前处置/复验计划见SP-241合并归档报告；已随v0.2.35发布，验收见SP-242 |

| `SP-233-issue-232-ios-real-backend-docs` | [`SP-233-issue-232-ios-real-backend-docs`](./SP-233-issue-232-ios-real-backend-docs/README.md) | 已合并，issue已关闭 | 2026-10-28 issue批次；PR #233已合远端main；当前处置/复验计划见SP-241合并归档报告；已随v0.2.35发布，验收见SP-242 |

| `SP-234-issue-225-ios-runner-transport` | [`SP-234-issue-225-ios-runner-transport`](./SP-234-issue-225-ios-runner-transport/README.md) | 已合并，issue已关闭 | 2026-10-28 issue批次；PR #233已合远端main；当前处置/复验计划见SP-241合并归档报告；已随v0.2.35发布，验收见SP-242 |

| `SP-235-issue-224-simulator-resize-query` | [`SP-235-issue-224-simulator-resize-query`](./SP-235-issue-224-simulator-resize-query/README.md) | 后续处理中，未完成 | v0.2.35后仍有Resize失败；本轮定位iPad1001并补unsupportedDevice，按用户要求仅验收27.1，iPad默认捕获/输入仍受限；显式单LCD截图已验证；PR #236已合main（27c7a875），#224仍OPEN |

| `SP-236-issue-223-bar-button-activation` | [`SP-236-issue-223-bar-button-activation`](./SP-236-issue-223-bar-button-activation/README.md) | 已合并，issue已关闭 | 2026-10-28 issue批次；PR #233已合远端main；当前处置/复验计划见SP-241合并归档报告；已随v0.2.35发布，验收见SP-242 |

| `SP-237-issue-222-device-hub-followup` | [`SP-237-issue-222-device-hub-followup`](./SP-237-issue-222-device-hub-followup/README.md) | 已合并，issue已关闭 | 2026-10-28 issue批次；PR #233已合远端main；当前处置/复验计划见SP-241合并归档报告；已随v0.2.35发布，验收见SP-242 |

| `SP-238-issue-221-searchbar-input-focus` | [`SP-238-issue-221-searchbar-input-focus`](./SP-238-issue-221-searchbar-input-focus/README.md) | 已合并，issue已关闭 | 2026-10-28 issue批次；PR #233已合远端main；当前处置/复验计划见SP-241合并归档报告；已随v0.2.35发布，验收见SP-242 |

| `SP-239-issue-230-ios-runner-geometry` | [`SP-239-issue-230-ios-runner-geometry`](./SP-239-issue-230-ios-runner-geometry/README.md) | 已合并，issue已关闭 | 2026-10-28 issue批次；PR #233已合远端main；当前处置/复验计划见SP-241合并归档报告；已随v0.2.35发布，验收见SP-242 |

| `SP-240-issue-214-deriveddata-ownership` | [`SP-240-issue-214-deriveddata-ownership`](./SP-240-issue-214-deriveddata-ownership/README.md) | PR #235已合并，历史候选待关联 | PR #235合并5d0bba7b；两处删除前约1.95 GiB，部分内容重复；#214保持OPEN，两处现存缓存已按后续授权删除；物理回收量未知；历史调用候选已归档，原18.66 GB路径映射仍缺；详见SP-240溯源记录 |

| `SP-241-open-issues-validation` | [`SP-241-open-issues-validation`](./SP-241-open-issues-validation/README.md) | 已合并归档，12关/1留 | 2026-10-28 issue批次；PR #233已合远端main；当前处置/复验计划见SP-241合并归档报告；已随v0.2.35发布，验收见SP-242 |

| `SP-242-release-v0-2-35` | [`SP-242-release-v0-2-35`](./SP-242-release-v0-2-35/README.md) | 已发布，实时流受限 | 双架构/Homebrew通过；默认实时流Resize未知，工作台通过；#214 OPEN，主目录WIP未变 |

| `SP-243-release-v0-2-36` | [`SP-243-release-v0-2-36`](./SP-243-release-v0-2-36/README.md) | v0.2.36 已发布 | 双架构/Homebrew/只读Web通过，流内容未验证；#224/#214 OPEN，主目录 WIP 未变 |

| `SP-244-emulator-service-slimming` | [`SP-244-emulator-service-slimming`](./SP-244-emulator-service-slimming/README.md) | 仅登记，产品未整合 | 真实既有Space；原负责人WIP不随本次提交 |
| `SP-245-rhine-design-adoption` | [`SP-245-rhine-design-adoption`](./SP-245-rhine-design-adoption/README.md) | 仅登记，产品未整合 | 真实既有Space；原负责人WIP不随本次提交 |
| `SP-246-rhine-web-migration` | [`SP-246-rhine-web-migration`](./SP-246-rhine-web-migration/README.md) | 仅登记，产品未整合 | 真实既有Space；原负责人WIP不随本次提交 |
| `SP-247-rhine-page-preferences` | [`SP-247-rhine-page-preferences`](./SP-247-rhine-page-preferences/README.md) | 仅登记，产品未整合 | 真实既有Space；原负责人WIP不随本次提交 |

| `SP-248-issue-238-arkweb-transport` | [`SP-248-issue-238-arkweb-transport`](./SP-248-issue-238-arkweb-transport/README.md) | 已本地提交，待docs复验/远端交付 | #238以dba41b6e重放，e6258339/8d18670f；CLI1582+94、root402通过；前序登记就绪；未推送/PR/合并/发布，真实ArkWeb未验 |

| `SP-249-issue-237-webview-snapshot` | [`SP-249-issue-237-webview-snapshot`](./SP-249-issue-237-webview-snapshot/README.md) | 已本地提交，整合验证中 | 根包403及JSC/WK通过；前序已登记，待PR/main CI，真实iOS未验 |

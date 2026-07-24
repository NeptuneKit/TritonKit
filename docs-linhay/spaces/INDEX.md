# TritonKit Space 编号索引

> 固定入口：`docs-linhay/spaces/INDEX.md`
> 最近同步：2026-07-24
> 覆盖范围：126/126 个已存在 space

本文件是所有 space 的编号登记册。每个 space 获得一个不可复用的规范标识，格式为 `SP-<三位序号>-<英文-topic>`，例如 `SP-001-hybrid-transport-smoke`。单个 space 的需求、BDD、计划和证据仍以其 `README.md` 为事实源；路线状态摘要仍在 [README.md](./README.md)。

## 命名与迁移规则

1. 新建 space、branch 与 worktree 一律使用登记后的规范名：`SP-<三位序号>-<英文-topic>`。
2. 序号全局递增、永不复用；`topic` 使用小写英文 slug，禁止空格、中文、`latest` 与 `final`。
3. 本次先完成编号登记与链接同步。历史目录继续保留为兼容路径，避免中断 README、证据和 Git 历史链接；物理目录重命名必须作为独立批次完成，并同步更新引用、branch 与 worktree。
4. 新建或归档 space 时，必须同时更新本表、[路线总览](./README.md) 和对应 space 的 README。

## 同步进度

| 项目 | 进度 | 说明 |
| --- | --- | --- |
| 编号登记 | 126/126 | 所有当前 space 均已分配唯一 SP 编号 |
| README 链接核对 | 126/126 | 每条记录链接到现有 space README |
| 历史目录物理迁移 | 0/125 | 留待独立迁移批次，当前旧路径保持兼容 |

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
| `SP-077-test-recorder-replay` | [`20260622-test-recorder-replay`](./20260622-test-recorder-replay/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
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
| `SP-101-github-issue-batch` | [`20260707-github-issue-batch`](./20260707-github-issue-batch/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-102-issue-140-redaction-preflight` | [`20260707-issue-140-redaction-preflight`](./20260707-issue-140-redaction-preflight/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
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
| `SP-124-issue-164-evidence-simulator-screenshot-fidelity` | [`20260722-issue-164-evidence-simulator-screenshot-fidelity`](./20260722-issue-164-evidence-simulator-screenshot-fidelity/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-125-issue-165-xcode-schemes-discovery-timeout` | [`20260722-issue-165-xcode-schemes-discovery-timeout`](./20260722-issue-165-xcode-schemes-discovery-timeout/README.md) | 已登记 | 历史目录保留，待按独立迁移批次重命名 |
| `SP-126-testrec-convergence` | [`SP-126-testrec-convergence`](./SP-126-testrec-convergence/README.md) | 已登记 | 规范目录；非历史迁移对象 |

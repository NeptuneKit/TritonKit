# TritonKit Spaces Index

> 固定入口：`docs-linhay/spaces/README.md`
>
> 编号登记册：[INDEX.md](./INDEX.md)（157/157 个 space 已登记；历史目录物理迁移 0/125）
>
> 最近审计：2026-07-30

本文件是 `docs-linhay/spaces/` 的路线总览，用于跟踪需求空间、实施进度、独立 worktree 和文档收口状态。全部 space 的 SP 编号、兼容目录和目录迁移进度以 [INDEX.md](./INDEX.md) 为事实源；单个需求的详细边界、BDD、计划和证据仍以对应 space 的 `README.md` 为事实源。

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
| 执行 | [SP-159-issue-195-ios-ddi-recovery](./SP-159-issue-195-ios-ddi-recovery/README.md) | #195 收敛为 `ddi_missing` 的可执行 iOS real-device app-install recovery；不自动修改 signing/DDI 资产 | focused failure/schema 测试与 CLI build；真实设备 smoke 需匹配 Xcode、已信任设备和用户授权 |
| 已合并（PR #177） | [SP-156-issue-176-xcode-compact-progress](./SP-156-issue-176-xcode-compact-progress/README.md) | #176 已为 `xcode build` 增加默认 compact progress，保留 lifecycle/heartbeat/bounded diagnostics/artifact/final，显式 full 恢复旧 stream | issue 已关闭；CI `30515397742` 通过，真实私有 workspace build 未运行 |
| 已合并（PR #177） | [SP-152-issue-172-runtime-reregistration](./SP-152-issue-172-runtime-reregistration/README.md) | #172 embedded runtime 新进程重注册与断连重连已完成；旧 task/timer 不得污染新连接，legacy SDK 兼容/拒绝原因保持机器可读 | issue 已关闭；root 238/238 与 CI 通过，真实 App 重装 smoke 未运行 |
| 已合并（PR #177） | [SP-153-issue-173-xcode-run-target-binding](./SP-153-issue-173-xcode-run-target-binding/README.md) | #173 已将 `xcode run` 显式 Simulator destination 固化为 build/settings/install/launch/app-scoped readiness 共用的 immutable target | issue 已关闭；CI 通过，真实 Xcode/Simulator 未运行 |
| 已合并（PR #177） | [SP-154-issue-174-simulator-swipe-lifecycle](./SP-154-issue-174-simulator-swipe-lifecycle/README.md) | #174 已用单一 persistent Baguette session、逐事件 ack 与 terminal linger 修复 iOS Simulator swipe 生命周期；host success 仍只代表提交 | issue 已关闭；CI 通过，真实 vertical pager smoke 未运行 |
| 已归档 | [20260722-issue-165-xcode-schemes-discovery-timeout](./20260722-issue-165-xcode-schemes-discovery-timeout/README.md) | Xcode discover 默认递归事实已与 schemes container 对齐；schemes 支持 timeout override、禁用自动 package resolution 与机器恢复动作 | `b3cdd40c` 已推送，CI `29973762696` 通过，GitHub #165 已关闭并随 `v0.2.15` 发布 |
| 已归档 | [20260722-issue-164-evidence-simulator-screenshot-fidelity](./20260722-issue-164-evidence-simulator-screenshot-fidelity/README.md) | iOS Simulator evidence 已区分 host-composited 与 runtime App-layer screenshot，默认视觉验收使用 host framebuffer | `e489dcfd` 已推送，CI `29973762696` 通过，GitHub #164 已关闭并随 `v0.2.15` 发布 |
| 已归档 | [20260722-issue-159-alert-modal-boundary](./20260722-issue-159-alert-modal-boundary/README.md) | UIKit tap 已尊重 presented alert modal boundary，禁止激活背后 collection/table cell | `01d88c4b` 已合并，CI `29910680723` 通过，GitHub #159 已关闭并随 `v0.2.15` 发布 |
| 已归档 | [20260722-issue-160-xcode-build-settings](./20260722-issue-160-xcode-build-settings/README.md) | Xcode settings/build/test/run 已支持 schema-backed repeatable `KEY=VALUE`，并保持输入顺序与 argv 边界 | `cb3e61d8` 已合并，CI `29912995906` 通过，GitHub #160 已关闭并随 `v0.2.15` 发布 |
| 已归档 | [20260722-issue-161-runtime-screenshot-format](./20260722-issue-161-runtime-screenshot-format/README.md) | embedded screenshot 已统一为真实 PNG，并在 artifact 发布前校验扩展名、metadata 与 magic bytes | `0db4120b` 已合并，CI `29924383924` 通过，GitHub #161 已关闭并随 `v0.2.15` 发布 |
| 已归档 | [20260722-issue-162-ios-real-device-launch-resolution](./20260722-issue-162-ios-real-device-launch-resolution/README.md) | 显式 iOS 真机 selector 的 install/info/launch 已共享 live resolution；真实不可用设备稳定返回 `target_offline` 与结构化恢复动作 | `f263c399` 已合并，CI `29927019645` 通过，GitHub #162 已关闭并随 `v0.2.15` 发布 |
| 已归档 | [20260722-issue-163-xcresult-array-decoding](./20260722-issue-163-xcresult-array-decoding/README.md) | xcresult decoder 已兼容历史 singleton、Xcode 26.6 summary arrays 与 flattened failed test cases | `938f9640` 已合并，CI `29929843919` 通过，GitHub #163 已关闭并随 `v0.2.15` 发布 |
| 已归档 | [20260721-issue-158-ios-real-device-screenshot-scope](./20260721-issue-158-ios-real-device-screenshot-scope/README.md) | screenshot 已在 host action 前区分 iOS real-device 与 Simulator selector，真机稳定返回 unsupported_scope | merge `a61ed5d7` 与 CI `29801150199` 全绿，GitHub #158 已关闭并随 `v0.2.14` 发布 |
| 已归档 | [20260721-issue-156-ios-button-primary-menu](./20260721-issue-156-ios-button-primary-menu/README.md) | iOS embedded runtime 已用 UIKit public primary-action API 打开标准 UIButton menu，并对菜单项选择保留明确 unsupported 边界 | 已合入 `main`、线上 CI 全绿并关闭 #156；已随 `v0.2.14` 发布 |
| 已归档 | [20260721-issue-157-table-cell-selection-callback](./20260721-issue-157-table-cell-selection-callback/README.md) | UITableViewCell ancestor selection 已在成功返回前完成 willSelect、selection state 与 didSelect callback | merge `3981467f` 与 CI `29799367673` 全绿，GitHub #157 已关闭并随 `v0.2.14` 发布 |
| 已归档 | [20260720-issue-155-ios-simulator-process-console](./20260720-issue-155-ios-simulator-process-console/README.md) | iOS Simulator App stdout/stderr 已成为 bounded、source-explicit 的 Triton host artifact 契约；与 unified log 明确分源 | 已合入 `main`、线上 CI 全绿并关闭 #155；随下一 patch release 发布 |
| 已归档 | [20260720-issue-154-runtime-skill-command-hierarchy](./20260720-issue-154-runtime-skill-command-hierarchy/README.md) | Public skill 打包已由 CLI schema snapshot 阻断 retired root command；`tritonkit-runtime` provenance 边界已澄清 | 已合入 `main`；CI 全绿后关闭 #154，本期不发布 tag |
| 已归档 | [20260720-issue-153-real-device-app-pull](./20260720-issue-153-real-device-app-pull/README.md) | 真机 data/app-group container 文件拉取已成为 schema-backed、受目录/字节/覆盖安全边界约束的 Triton artifact command | 已合入 `main`；CI 全绿后关闭 #153，真机锁屏 blocker 如实保留 |
| 已归档 | [20260720-issue-152-real-device-launch-env](./20260720-issue-152-real-device-launch-env/README.md) | 真机 launch env 已改用 devicectl 显式 JSON flag，sourceCommand 按 argv index 脱敏 | 已合入 `main`；推送并等待 CI 后关闭 #152 |
| 已归档 | [20260720-issue-150-xcode-package-build](./20260720-issue-150-xcode-package-build/README.md) | Xcode discovery 返回的 `Package.swift` 已可被 defaults、schemes/build/test/run 与点分 schema 直接消费 | 已合入 `main`；推送并等待 CI 后关闭 #150 |
| 已归档 | [20260720-issue-149-ios-host-wait](./20260720-issue-149-ios-host-wait/README.md) | iOS Simulator wait 已复用 host AX observer，help/schema/capability 与 disconnected 执行边界已统一 | 已合入 `main`；推送并等待 CI 后关闭 #149 |
| 已归档 | [20260720-issue-147-harmony-wait-layout-recv](./20260720-issue-147-harmony-wait-layout-recv/README.md) | Harmony layout transfer 已受 wait deadline 约束，瞬态 timeout 可重试并保留结构化诊断 | 已合入 `main`；推送并等待 CI 后关闭 #147 |
| 已归档 | [20260720-issue-151-evidence-partial-capture](./20260720-issue-151-evidence-partial-capture/README.md) | evidence JSON 已收敛为单一 manifest；partial/request failure、artifact error 与退出码契约已对齐 | 已合入 `main`；推送并关闭 #151 |
| 已归档 | [20260720-issue-148-xcode-simulator-destination](./20260720-issue-148-xcode-simulator-destination/README.md) | 显式 `--simulator` 已覆盖旧 default destination；UUID / 名称分别合成 `id=` / `name=` | 已合入 `main`；推送并关闭 #148 |
| 已归档 | [20260720-issue-146-sim-record-duration](./20260720-issue-146-sim-record-duration/README.md) | `sim record` 已按 encoded sample 时长校验；一帧 MOV 返回 `sim_record_truncated`，成功契约暴露 requested/actual/container/track duration | 已合入 `main`；推送并关闭 #146 |
| 已归档 | [20260521-ios-embedded-sdk-expansion](./20260521-ios-embedded-sdk-expansion/README.md) | S0-S4 与 WebView-aware `act tap` 已完成，真实 iOS Simulator 证明 `selector -> DOM dispatch -> expect-text` 返回 `status=passed` | 保留动态 smoke 证据；P1/P2 需求另建有限 space |
| 已归档 | [20260525-simulator-target-simplification](./20260525-simulator-target-simplification/README.md) | 真实多开 iOS、Harmony alias、指定目标动作和多候选拒绝均通过；同时修复 observation alias 缺省 platform 被误判为 iOS | 不实现 `--bundle` 反向过滤；批量 fan-out 或新 selector 能力另建 space |
| 执行 | [SP-126-testrec-convergence](./SP-126-testrec-convergence/README.md) | 已裁决 Hybrid：保留 `testrec` 的录制/编译/质量兼容价值，真实执行统一进入 `test run`，workspace 后续复用同一合同 | SP-126～136 已于本地 `main@d0f09d3c` 受控集成；真实采样前不接 workspace 或新平台 |
| 已发布（v0.2.16） | [SP-127-issue-168-ios-real-device-terminate-pid](./SP-127-issue-168-ios-real-device-terminate-pid/README.md) | #168 已采用安全 fallback：shared terminate 只接受显式 PID，iOS real bundle-ID terminate 无可证实 PID 时 fail closed；不实现猜测式 PID join | issue 已关闭；未声称真机 bundle-ID terminate 成功，真实设备 smoke 未运行 |
| 已发布（v0.2.16） | [SP-128-issue-167-xcode-device-alias-preflight](./SP-128-issue-167-xcode-device-alias-preflight/README.md) | Xcode real-device run 已确定先做 target selection preflight，再进入昂贵 build；保持既有 build/install/launch 合同 | issue 已关闭；真实 Xcode/device 与 live alias store 验证缺口保留 |
| 已完成（本地） | [SP-129-serve-loopback-default](./SP-129-serve-loopback-default/README.md) | `triton serve` 无 `--host` 时默认绑定 `127.0.0.1:19421`；显式非 loopback host 保持兼容；Bonjour publish 语义暂不改变 | 已进入本地 main；联合 docs/CLI 门禁通过，Bonjour 风险不变 |
| 已发布（v0.2.16） | [SP-130-issue-166-runtime-jpeg-normalization](./SP-130-issue-166-runtime-jpeg-normalization/README.md) | #166 已将 legacy embedded JPEG 解码并统一规范化为 PNG，避免 CLI/evidence/replay/test-run 发布伪 PNG 或丢弃有效证据 | issue 已关闭；SP-149 follow-up 已随 PR #177 合并，物理设备 JPEG smoke 未运行 |
| 已归档 | [SP-131-ios-simulator-canonical-proof](./SP-131-ios-simulator-canonical-proof/README.md) | 仓内 Debug fixture 已在 dedicated iOS Simulator 上真实完成 `test validate -> test run -> evidence`：6 steps、2 assertions、0 failures，证据含 runtime target、PNG、AX/hierarchy | local checkpoint 已完成；后续仅回到 SP-126 的 `.tritontestcase -> test import -> test validate`，不扩 Android/Web/Wails/真机；#164 WIP 继续隔离 |
| 已归档 | [SP-132-testrec-import-seam](./SP-132-testrec-import-seam/README.md) | P0 已建立 `.tritontestcase -> test import -> test validate` 的 offline seam；bundle identity 与 `ios-simulator` target 均显式输入，映射不足一律 fail-closed | P1 才运行 imported plan；不扩 testrec executor、Android/Web/Wails/真机；#164 WIP 继续隔离 |
| 已归档 | [SP-133-imported-ios-simulator-proof](./SP-133-imported-ios-simulator-proof/README.md) | imported AX plan 已在 dedicated iOS Simulator 经既有 `test run` 产生真实 passed verdict/evidence：6 steps、2 assertions、0 failures，并保留 normalized-plan provenance | 自管 server 已停止、Simulator 已恢复 Shutdown；sensitive evidence 仅作本机可恢复处置、不入 Git，不扩 executor/Android/Web/Wails/真机；#164 WIP 继续隔离 |
| 执行 | [SP-134-ios-simulator-reliability-gate](./SP-134-ios-simulator-reliability-gate/README.md) | 纯离线 ECR / FER / ORR gate 已收紧为 duplicate、partial、逐 step 覆盖与 target binding 均 fail-closed；不把一条 fixture proof 放大为产品可靠性 | 真实 3 flow × 20 仅在初态 reset、专用 Simulator、self-managed server 与私有 evidence 门禁均满足时另立受控 harness 串行执行 |
| 已完成（本地） | [SP-135-testrec-compatibility-guidance](./SP-135-testrec-compatibility-guidance/README.md) | testrec dry-run/local-simulated/matrix 保留兼容 status，但新增不可作为真实 verdict 或 reliability sample 的 machine-readable boundary | checkpoint `37d8f9c7`；不恢复 testrec executor，后继 collection preflight 需先有三条冻结 imported flow 与 reset/target contract |
| 已完成（本地） | [SP-136-ios-simulator-reliability-collection-preflight](./SP-136-ios-simulator-reliability-collection-preflight/README.md) | 已离线冻结 3 flow × 20 的 imported-plan、canonical target、reset/negative-control 与 fresh evidence layout 合同 | 不启动或选择 Simulator/server/target，不生成样本/receipt/可靠性结论；真实 harness 仍须另立 space |
| 已发布（v0.2.16） | [SP-137-issue-171-safe-collection-tap](./SP-137-issue-171-safe-collection-tap/README.md) | #171 已收紧 embedded `UICollectionViewCell` tap：无公开可证实 activation 时固定返回 `unsupported_capability`，且 accessibility gesture 候选不会越过当前 cell | issue 已关闭；真实 UIKit/Simulator route smoke 未运行 |
| 已发布（v0.2.16） | [SP-138-issue-170-xcode-real-device-destination](./SP-138-issue-170-xcode-real-device-destination/README.md) | #170 已收紧 Xcode `--device` 的 settings/build/test/run preflight、exact raw execution destination 与 public-output redaction | issue 已关闭；真实 Xcode、签名、安装与启动 smoke 未运行 |
| 已发布（v0.2.16） | [SP-139-issue-169-xcode-focused-testing](./SP-139-issue-169-xcode-focused-testing/README.md) | #169 已为 `triton xcode test` 增加 repeatable `--only-testing`，每项保持独立 xcodebuild argv，JSON/JSONL 可审计 sourceCommand | issue 已关闭；不实现 `--skip-testing`，真实 XCTest/xcodebuild 未运行 |
| 已完成（本地） | [SP-140-ios-simulator-reliability-live-harness](./SP-140-ios-simulator-reliability-live-harness/README.md) | receipt-backed reserve/sample 将 3×20+1 的 future collection 固化为 immutable contract、strict exact target 与 no-clobber slot；业务 mismatch 保持 typed result + exit 语义 | 本地 harness/契约验证完成；不得自动真实采样，后续必须先获得 dedicated Simulator、server ownership、reset recipe、negative control 与私有 evidence 授权 |
| 已发布（v0.2.16） | [SP-141-packaged-web-simulator-input](./SP-141-packaged-web-simulator-input/README.md) | packaged `/web/host-input` 已按 iOS real runtime mirror、三平台 host target 与 unsupported 三路分流，不再错拒 Simulator | Homebrew 0.2.16 安装版真实 Simulator HTTP/页面点击通过，console 0 error/warning |
| 已完成（本地） | [SP-142-web-readonly-contract](./SP-142-web-readonly-contract/README.md) | Web Device Hub 统一只读：browser `/web/input`、`/web/node-property`、`/web/host-input` 不再执行或转发，React/HTML 保留 DTO、截图、层级与本地 patch 草案复制 | local checkpoint 只做离线契约验证；先集成 SP-141 再集成 SP-142 后重跑 docs gate，读路径的 serve 生命周期风险另立裁决 |
| 已完成（本地） | [SP-143-reliability-gate-integrity](./SP-143-reliability-gate-integrity/README.md) | Stage 1 reliability gate 只接受 receipt-backed authority；legacy sample 保留诊断但不能 passed，observation/failure artifact 均需 kind 与 step 时序归因 | 纯离线 TDD、focused contracts 与 release build 完成；不触碰 #164；SP-141 → SP-142 → SP-143 集成后统一复跑 docs gate |
| 已完成（本地） | [SP-144-reliability-receipt-anchor](./SP-144-reliability-receipt-anchor/README.md) | 为 receipt-backed sample/report 增加 operator-owned SHA-256 expected anchor，阻断 root 内完整 receipt 的自洽替换 | 纯离线 BDD/TDD 与 release build 已完成；不宣称签名、远端不可抵赖、hostile filesystem、真实 reset/runtime identity 或 live sampling |
| 已完成（本地） | [SP-145-private-identity-chain-v2](./SP-145-private-identity-chain-v2/README.md) | 基于 SP-144 root 外 anchor，记录并核验每 slot 的私有 evidence identity chain，并输出安全 aggregate | 仅离线 consistency/漂移检测；不写采样器，不主张真实 reset/App/runtime proof，也不触碰设备/服务 |
| 已完成（本地） | [SP-146-stage1-metric-contract](./SP-146-stage1-metric-contract/README.md) | 已将 Stage 1A 的 60 supported ECR/ORR 与 Stage 1B 的 61 receipt/control integrity、FER 以 additive public contract 区分 | 纯离线合同/合成 evidence、release schema 与 focused tests 已完成；真实采样仍需 dedicated environment 授权 |
| 已完成（本地） | [SP-147-schema-fact-source-mainline](./SP-147-schema-fact-source-mainline/README.md) | `device` / `sim app-console` machine-readable schema 已按 parser 与 host DTO 修复 direct child、argument、output/recovery contract | 已合入 SP-151；不扩 runtime/device/server |
| 已完成（本地） | [SP-148-schema-placeholder-tokens](./SP-148-schema-placeholder-tokens/README.md) | `reliability-sample` schema 同时保留 receipt anchor 和完整 `<canonical>` argv token | 已合入 SP-151；不改 runner、server、设备或真实采样 |
| 已完成（本地） | [SP-149-issue-166-evidence-metadata-contract](./SP-149-issue-166-evidence-metadata-contract/README.md) | #166 follow-up：`/screenshot` normalizer failure 保留 `artifact_write_failed`，test-run metadata 只描述已发布 PNG、没有旧 runtime payload/ref | 已合入 SP-151；不启动服务/设备、不改 #164 |
| 已完成（本地） | [SP-150-reliability-failure-recovery-semantics](./SP-150-reliability-failure-recovery-semantics/README.md) | Stage 1 gate 已以 validated plan 绑定 terminal failure/recovery，阻断跨步骤与 generic/unknown 伪解释 | 纯离线 TDD、81 项关联回归和 release build 已通过；不改 runner taxonomy、anchor/identity、service/device 或 #164 |
| 已归档（PR #177） | [SP-151-trusted-baseline-integration](./SP-151-trusted-baseline-integration/README.md) | SP-142～156 已由 merge `66f975d9` 进入 `main`；联合 focused 207/207、root 238/238、release build/smoke 与 docs gate 均通过 | CI `30515397742` 全绿；SP-151～156 source branch/worktree 已清理，#164 保持原样 |
| 已合并（PR #177） | [SP-155-issue-175-ios-readiness-coredevice](./SP-155-issue-175-ios-readiness-coredevice/README.md) | #175 修复 CoreDevice `available (paired)` 真机被 stale tunnel/DDI flags 错判 offline 的 readiness 归一 | issue 已关闭；fixture/parser/selection 与 install plan 同源事实已验证，未执行真实 install/tunnel |
| 待定 | [20260622-test-recorder-replay](./20260622-test-recorder-replay/README.md) | 历史 P0 合同与 local-simulated executor 保留为兼容资产；执行裁决已移交 SP-126 | 不再新增 `testrec local-device` / matrix / live network 实现；所有后续工作在 SP-126 收敛 |
| 废弃 | [20260527-revyl-cli-agent-entrypoint-research](./20260527-revyl-cli-agent-entrypoint-research/README.md) | 研究价值已被 skill、schema、evidence、update 和 Agent Mobile Runtime Platform 吸收 | 不再按原 M1-M6 独立实施；历史材料继续作为参考 |
| 已归档 | [20260706-agent-mobile-runtime-platform](./20260706-agent-mobile-runtime-platform/README.md) | iOS Demo 已完成 target discovery、launch、action、evidence、LLM/VLM、Atlas、flow export 全链 smoke，满足“一期至少一个 target scope”验收 | Overloaded bootstrap 作为外部项目回归问题另行处理；其他 target scope 扩展必须新建有限 space |
| 已归档 | [20260701-host-framebuffer-stream](./20260701-host-framebuffer-stream/README.md) | SimulatorKit/IOSurface host stream、MJPEG route 和历史高帧率测量已落地 | 作为实验性 Web mock 能力保留，不再承诺 `<15ms/120 FPS` 产品 SLA；正式 Web 恢复时重新立项 |
| 已归档 | [20260702-cross-platform-framebuffer-stream](./20260702-cross-platform-framebuffer-stream/README.md) | Android/Harmony host pull stream、HTTP route、Web bridge 和截图证据已落地 | 作为 Web mock 原型归档，不再追加性能优化；正式产品化需重新定义边界和证据门禁 |
| 已归档 | [20260617-issue-61-android-emulator-adapter](./20260617-issue-61-android-emulator-adapter/README.md) | 旧 Web 编译 blocker 已消失，当前 `DeviceCrossPlatformTests` 93 项通过；Android Emulator 主链已有历史真实 smoke | 不再单独执行；后续 Android 回归走现有 emulator takeover 与 strong-control spaces |

## 独立 worktree 与本地集成状态

| Space | Branch | Worktree | 基线 | 当前状态与后续 |
| --- | --- | --- | --- | --- |
| `SP-156-issue-176-xcode-compact-progress` | `feat/SP-156-issue-176-xcode-compact-progress`（已清理） | 已清理（历史由 PR #177 merge 可达） | `feat/SP-153-issue-173-xcode-run-target-binding@57ff4092` | #176 已合并并关闭；compact/full 合同与 focused 证据保留 |
| `SP-159-issue-195-ios-ddi-recovery` | `feat/SP-159-issue-195-ios-ddi-recovery` | `../TritonKit-worktrees/SP-159-issue-195-ios-ddi-recovery/` | `main@252dcd21` | #195 本地实现中；仅推进结构化 DDI recovery，不宣称真实设备准备成功 |
| `SP-152-issue-172-runtime-reregistration` | `feat/SP-152-issue-172-runtime-reregistration`（已清理） | 已清理（历史由 PR #177 merge 可达） | `main@d2578089` | #172 已合并并关闭；runtime lifecycle/compatibility 证据保留 |
| `SP-153-issue-173-xcode-run-target-binding` | `feat/SP-153-issue-173-xcode-run-target-binding`（已清理） | 已清理（历史由 PR #177 merge 可达） | `main@d2578089` | #173 已合并并关闭；单目标绑定证据保留 |
| `SP-154-issue-174-simulator-swipe-lifecycle` | `feat/SP-154-issue-174-simulator-swipe-lifecycle`（已清理） | 已清理（历史由 PR #177 merge 可达） | `main@d2578089` | #174 已合并并关闭；persistent input lifecycle 证据保留 |
| `SP-126-testrec-convergence` | `feat/SP-126-testrec-convergence` | `../TritonKit-worktrees/SP-126-testrec-convergence/` | `main@931645ed` | 路线、边界与 Luna 执行交接已收口；可信基线、importer、proof/gate/compatibility/preflight 已经由 `d0f09d3c` 进入本地 main |
| `SP-127-issue-168-ios-real-device-terminate-pid` | `feat/SP-127-issue-168-ios-real-device-terminate-pid` | `../TritonKit-worktrees/SP-127-issue-168-ios-real-device-terminate-pid/` | `5f6c2f6f` | `cef52ea2` 已经由 `d0f09d3c` 进入本地 main；保留真机 smoke blocker |
| `SP-128-issue-167-xcode-device-alias-preflight` | `feat/SP-128-issue-167-xcode-device-alias-preflight` | `../TritonKit-worktrees/SP-128-issue-167-xcode-device-alias-preflight/` | `feat/SP-126-testrec-convergence@5f6c2f6f` | `25f7e048` 已经由 `d0f09d3c` 进入本地 main；保留真实 Xcode/device 覆盖缺口 |
| `SP-129-serve-loopback-default` | `feat/SP-129-serve-loopback-default` | `../TritonKit-worktrees/SP-129-serve-loopback-default/` | `feat/SP-126-testrec-convergence@5f6c2f6f` | `f0f3b0a0` 已经由 `d0f09d3c` 进入本地 main；保留 Bonjour 广播语义风险 |
| `SP-130-issue-166-runtime-jpeg-normalization` | `feat/SP-130-issue-166-runtime-jpeg-normalization` | `../TritonKit-worktrees/SP-130-issue-166-runtime-jpeg-normalization/` | `codex/sp126-trusted-baseline-integration@2fddf6a0` | #166 JPEG -> PNG normalizer 已经由 `d0f09d3c` 进入本地 main；不读取或修改 #164 dirty WIP |
| `SP-131-ios-simulator-canonical-proof` | `feat/SP-131-ios-simulator-canonical-proof` | `../TritonKit-worktrees/SP-131-ios-simulator-canonical-proof/` | `feat/SP-130-issue-166-runtime-jpeg-normalization@a7404033` | local checkpoint 将记录真实 dedicated Simulator 的手写最小 plan proof；server 已停止、Simulator 已恢复 Shutdown；不读取或修改 #164 dirty WIP |
| `SP-132-testrec-import-seam` | `feat/SP-132-testrec-import-seam` | `../TritonKit-worktrees/SP-132-testrec-import-seam/` | `feat/SP-131-ios-simulator-canonical-proof@6f700b13` | P0 local checkpoint：只读 compiled contract，显式 ios-simulator target，输出可 validate YAML 与 typed provenance；P1 才运行 device，#164 dirty WIP 未读取或修改 |
| `SP-133-imported-ios-simulator-proof` | `feat/SP-133-imported-ios-simulator-proof` | `../TritonKit-worktrees/SP-133-imported-ios-simulator-proof/` | `feat/SP-132-testrec-import-seam@b065b3f0` | P1 local proof 已通过：新鲜 source/import/validate、专用 Simulator、self-managed 19421 server、Debug fixture、真实 `test run` 与 evidence/provenance 已串行验证；server 已停止、Simulator 已恢复 Shutdown，#164 dirty WIP 未读取或修改 |
| `SP-134-ios-simulator-reliability-gate` | `feat/SP-134-ios-simulator-reliability-gate` | `../TritonKit-worktrees/SP-134-ios-simulator-reliability-gate/` | `feat/SP-133-imported-ios-simulator-proof@19e2c35f` | 本地 checkpoint 收口纯离线 reliability gate；不启动测试 runtime 或共享设备/server。真实 sampling 需要另行通过 dedicated/reset/privacy gate，#164 dirty WIP 不读取或修改 |
| `SP-135-testrec-compatibility-guidance` | `feat/SP-135-testrec-compatibility-guidance` | `../TritonKit-worktrees/SP-135-testrec-compatibility-guidance/` | `feat/SP-134-ios-simulator-reliability-gate@21a57399` | checkpoint `37d8f9c7`：只收紧 testrec offline diagnostic / migration contract；不启动 runtime 或设备，不修改 #164 WIP |
| `SP-136-ios-simulator-reliability-collection-preflight` | `feat/SP-136-ios-simulator-reliability-collection-preflight` | `../TritonKit-worktrees/SP-136-ios-simulator-reliability-collection-preflight/` | `feat/SP-135-testrec-compatibility-guidance@107eac45` | 本地 checkpoint：纯离线 collection contract；只读 private plans，拒绝生成 sample/evidence/reset receipt 或占用 runtime/device/server，#164 WIP 持续隔离 |
| `SP-137-issue-171-safe-collection-tap` | `feat/SP-137-issue-171-safe-collection-tap` | `../TritonKit-worktrees/SP-137-issue-171-safe-collection-tap/` | `main@0c2e38da` | 本地 checkpoint：collection cell fallback 只返回 unsupported，cell 外 gesture 不可越界激活；保留 cell 内 UIControl/accessibility 真实成功、table/host AX 语义，#164 WIP 持续隔离 |
| `SP-138-issue-170-xcode-real-device-destination` | `feat/SP-138-issue-170-xcode-real-device-destination` | `../TritonKit-worktrees/SP-138-issue-170-xcode-real-device-destination/` | `main@f68587be` | `5d7ffff0` 已进入本地 main；真实 Xcode/Simulator/设备/服务 smoke 未运行 |
| `SP-139-issue-169-xcode-focused-testing` | `feat/SP-139-issue-169-xcode-focused-testing` | `../TritonKit-worktrees/SP-139-issue-169-xcode-focused-testing/` | `main@5d7ffff0` | `0cb7e958` 已进入本地 main；repeatable focused XCTest selection 不启动真实 Xcode/Simulator/设备/服务 |
| `SP-140-ios-simulator-reliability-live-harness` | `feat/SP-140-ios-simulator-reliability-live-harness` | `../TritonKit-worktrees/SP-140-ios-simulator-reliability-live-harness/` | `main@0cb7e958` | receipt-backed harness 已 rebase 到当前 local main；focused contract 已验证，真实 3×20+1 仍明确等待授权，不触碰 #164 WIP |
| `SP-142-web-readonly-contract` | `feat/SP-142-web-readonly-contract`（已清理） | 已清理（历史由 SP-151 merge commit 可达） | `main@d016979d` | 已由 SP-151 集成；405 readonly/loopback proof 保留在 space 文档，不改 main 或 #164 |
| `SP-143-reliability-gate-integrity` | `feat/SP-143-reliability-gate-integrity`（已清理） | 已清理（历史由 SP-151 merge commit 可达） | `main@d016979d` | 已由 SP-151 集成；Stage 1 gate authority、typed negative、collection lease 与 artifact attribution 保留为离线合同 |
| `SP-144-reliability-receipt-anchor` | `feat/SP-144-reliability-receipt-anchor`（已清理） | 已清理（历史由 SP-151 merge commit 可达） | `feat/SP-143-reliability-gate-integrity@33ad1f9d` | 已由 SP-151 集成；root 外 receipt SHA-256 anchor 合同保留 |
| `SP-145-private-identity-chain-v2` | `feat/SP-145-private-identity-chain-v2`（已清理） | 已清理（历史由 SP-151 merge commit 可达） | `feat/SP-144-reliability-receipt-anchor@ab6cbf1e` | 已由 SP-151 集成；private identity-chain v2 与 fail-closed drift/missing terminal 合同保留 |
| `SP-146-stage1-metric-contract` | `feat/SP-146-stage1-metric-contract`（已清理） | 已清理（历史由 SP-151 merge commit 可达） | `feat/SP-145-private-identity-chain-v2@50c89bea` | 已由 SP-151 集成；receipt-backed Stage 1A/1B metric contract 保留 |
| `SP-150-reliability-failure-recovery-semantics` | `feat/SP-150-reliability-failure-recovery-semantics`（已清理） | 已清理（历史由 SP-151 merge commit 可达） | `feat/SP-146-stage1-metric-contract@ab0daf99` | 已由 SP-151 集成；terminal failure/recovery fail-closed contract 保留 |
| `SP-147-schema-fact-source-mainline` | `feat/SP-147-schema-fact-source-mainline`（已清理） | 已清理（历史由 SP-151 merge commit 可达） | `main@d2578089` | 已由 SP-151 集成；CLI schema fact-source repair 保留为离线验证合同 |
| `SP-148-schema-placeholder-tokens` | `feat/SP-148-schema-placeholder-tokens`（已清理） | 已清理（历史由 SP-151 merge commit 可达） | `SP-147@98110f60` | 已由 SP-151 集成；完整 `<canonical>` argv placeholder 合同保留 |
| `SP-149-issue-166-evidence-metadata-contract` | `feat/SP-149-issue-166-evidence-metadata-contract`（已清理） | 已清理（历史由 SP-151 merge commit 可达） | `main@d2578089` | 已由 SP-151 集成；#166 metadata/error 纯函数合同保留，不触碰 #164 WIP |
| `SP-151-trusted-baseline-integration` | `feat/SP-151-trusted-baseline-integration`（已清理） | 已清理（历史由 PR #177 merge 可达） | `main@d2578089` | SP-142～156 已合并；CI `30515397742` 全绿，issue #166～176 已关闭，#164 worktree 保持原样 |
| `SP-155-issue-175-ios-readiness-coredevice` | `feat/SP-155-issue-175-ios-readiness-coredevice`（已清理） | 已清理（历史由 PR #177 merge 可达） | `main@d2578089` | #175 已合并并关闭；readiness fixture 证据保留，真实设备动作未执行 |

## 维护规则

1. 新建 space 后，同一提交内将其加入本索引的“路线裁决”或“历史归档”。
2. 状态变化时更新“最近审计”日期、裁决和下一步，不只修改单个 space。
3. 独立 worktree 必须记录路径、branch/commit 和后续动作；仅本地 integration branch 不等于合入 `main`，主分支收口后才可移入历史归档。
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

# TritonKit Spaces Index


2026-10-26参考核对：原目录 `main@24e7d0f2`，33仓日检22完整/11 partial、两仓HEAD变化。新增SP-221只读资源暂态重试/SP-222有限主控，显式gpt-6.1-sol真实会话创建成功、已通过独立与合后门禁，合本地main a0eebff0；旧13条采用已合main，旧源码/许可缺口保留。
> 固定入口：`docs-linhay/spaces/README.md`
>
> 编号登记册：[INDEX.md](./INDEX.md)（247/247 个 space 已登记；历史目录物理迁移 0/125）
>
> 最近审计：2026-10-29（SP-243 v0.2.36 发布验收；保留既有参考追踪）

本文件是 `docs-linhay/spaces/` 的路线总览，用于跟踪需求空间、实施进度、独立 worktree 和文档收口状态。全部 space 的 SP 编号、兼容目录和目录迁移进度以 [INDEX.md](./INDEX.md) 为事实源；单个需求的详细边界、BDD、计划和证据仍以对应 space 的 `README.md` 为事实源。

## 2026-10-24 · 有限任务与范围收口

- SP-126/SP-134 按已交付的 importer、单 flow 真实纵切、兼容边界与离线 gate 归档；SP-140/143～151 保持完成。真实 3 flow × 20 + 1 negative 仍未采样，只保留[唯一条件触发专项](./SP-134-ios-simulator-reliability-gate/plans/20260727-reliability-gate-decision-v01.md#future-reliability-acceptance)：明确项目采用 recorder/workspace 自动回归或准备对外可靠性承诺时另立有限 space。可先 1 supported + 1 negative 接线 smoke，但完整 gate 仍 blocked，旧历史交接不再自动执行。
- SP-177 的单设备资源工具已由 SP-196 交付；fleet、自动 replay/evidence 编排和量化性能目标撤出本期。SP-179 取消通用缓存自动删除，只维护 inspect / dry-run 和 confirm 拒绝边界；这不是安全删除功能完成，远端 #214 的最后核实状态仍为 OPEN，本轮未操作远端。
- SP-183 收缩后归档，维护已交付能力；专门平台实验项只由具体项目需求触发，unsupported 不自动排期。历史真机恢复/清理缺后续证据，当前 unknown，仅保留同目标人工交接。SP-181/SP-182 保持研究/设计归档，无当前自动实施或立项任务。
- SP-218 native HID点击/滑动、Hub占用拒绝与恢复，以及SP-219普通→Resize→普通视频已完成本机真实验收，按范围归档；见[联合报告](./SP-218-issue-222-device-hub-input/plans/20261024-live-acceptance-closeout.md)。完整CLI 1515项与本地/文档门禁通过，本轮修复和收口差异已由c0ce0cc2推送且CI通过；v0.2.33已发布，双架构公开资产、Homebrew和仓库外只读Web验收通过，见[发布记录](./SP-218-issue-222-device-hub-input/plans/20261024-v0.2.33-release.md)。真实验收worktree已清理，发版使用独立检出。SP-193/SP-207的长期追踪与监控保持原有安排；其他历史worktree路径不因文档归档而推断已物理删除。

## 状态定义

| 状态 | 含义 |
| --- | --- |
| 执行 | 当前有边界明确、可验证、应继续完成的有限任务 |
| 待定 | 暂停实现，必须先完成产品合并、范围取舍或环境条件判断 |
| 废弃 | 不再作为独立 roadmap 推进；保留历史文档和仍有价值的既有代码 |
| 已归档 | 本期有限交付已完成，或已明确取消/收缩未交付目标；保留证据边界，不表示原长期目标全部实现 |
| v0.2.25 已发布／#215–220 已关闭 | 已进入本地 SP-190 集成分支；完整 CLI、本地门禁及线上 CI 通过；#215～220 已回复关闭，#214 继续开放 |

## 路线裁决

当前发布：[SP-243-release-v0-2-36](./SP-243-release-v0-2-36/README.md) 已发布，双架构/Homebrew/只读Web通过；流内容未验证，#224/#214 保持 OPEN，主目录 WIP 未变。

| 状态 | Space | 裁决 | 下一步 |
| --- | --- | --- | --- |
| 已合本地main | [SP-223-host-process-drain-deadline](./SP-223-host-process-drain-deadline/README.md) | 宿主进程退出后的有界输出收尾 | 9fbda1d5；完整CLI/local合后通过，源worktree/branch已清理 |
| 已验收合本地main | [SP-224-host-process-drain-integration](./SP-224-host-process-drain-integration/README.md) | SP-223有限独立主控 | 主控1c735787验收、合后门禁通过，源worktree/branch已清理 |
| 已合本地main | [SP-221-simulator-resource-read-retry](./SP-221-simulator-resource-read-retry/README.md) | 同目标print-disabled明确launchd暂态有限只读重试 | a0eebff0；focused37/fullCLI/root/local/docs通过，mutation不重放 |
| 已验收合本地main | [SP-222-simulator-resource-retry-integration](./SP-222-simulator-resource-retry-integration/README.md) | SP-221有限主控，真实runner失败路径与预算 | 独立报告95a1dc8f与actualmain合后门禁通过，未发布 |
| v0.2.30已发布 | [SP-208-update-version-alignment](./SP-208-update-version-alignment/README.md) | 修复更新误报、安装版本核验与skills对齐 | 6c120ccd已整合；main门禁与CLI1474+59通过，worktree/分支已清理，双架构与安装验收通过 |
| 持续追踪与采用 | [SP-207-reference-adoption-pipeline](./SP-207-reference-adoption-pipeline/README.md) | 33仓统一追踪与采用流程已合入main | 10月26日补查后24完整/9 partial；16条采用已合main，11个执行/主控会话已归档 |
| v0.2.30已发布 | [SP-206-ictrl-security-integration](./SP-206-ictrl-security-integration/README.md) | 负责 SP-203～205 交付审查、集成与联合验证 | 057d1012补齐收口历史；worktree/分支已清理，已随v0.2.30发布，用户原机另验 |
| v0.2.30已发布 | [SP-203-ictrl-discovery-hardening](./SP-203-ictrl-discovery-hardening/README.md) | 发现与连接安全，按 SP-202 评估实施 | SP-206冻结候选联合门禁通过；已本地合并，已随v0.2.30发布，用户原机另验；worktree/分支已清理 |
| v0.2.30已发布 | [SP-204-ictrl-log-privacy](./SP-204-ictrl-log-privacy/README.md) | 日志脱敏与降噪，按 SP-202 评估实施 | SP-206冻结候选联合门禁通过；已本地合并，已随v0.2.30发布，用户原机另验；worktree/分支已清理 |
| v0.2.30已发布 | [SP-205-ios-runner-auth-hardening](./SP-205-ios-runner-auth-hardening/README.md) | Runner 鉴权强化，按 SP-202 评估实施 | SP-206冻结候选联合门禁通过；已本地合并，已随v0.2.30发布，用户原机另验；worktree/分支已清理 |
| 评估完成 | [SP-202-ictrl-security-assessment](./SP-202-ictrl-security-assessment/README.md) | 静态评估归档；采用已在SP-203～205实施 | 通过SP-206联合验证并本地整合，并随v0.2.30发布 |
| v0.2.30已发布 | [SP-201-sdk-floating-picker](./SP-201-sdk-floating-picker/README.md) | 原生直接拖选实时预览/长按移位，标记身份与CLI操作；手势、稳定罗盘、导航记忆及拖动放大镜验证通过，模拟器试用中 | 3f1b500a已整合；worktree/分支已清理，已随v0.2.30发布，用户原机另验 |
| 已合入本地main | [SP-200-mobile-device-parity](./SP-200-mobile-device-parity/README.md) | Mobile设备环境/录屏/诊断/归档安装/动作/终端镜像已实现并完成本地回归 | 10acfae6已进入main，worktree/分支已清理；排除云预订/MCP |
| 已归档 | [SP-199-mobile-mcp-reference](./SP-199-mobile-mcp-reference/README.md) | Mobile MCP 参考与差距报告已完成 | 研究docs门禁通过；已由SP-207追踪，SP-212采用切片已验收合main |
| 已合入本地main | [SP-197-view-annotation](./SP-197-view-annotation/README.md) | 独立可选UIKit高亮与条件恢复；真实模拟器截图、CLI/HTTP与skills已验收 | 7b1a2f76完成集成；P1截图消费者与跨端另行实施；worktree/分支已清理 |
| 本地提交归档 | [SP-198-agent-experience-loop](./SP-198-agent-experience-loop/README.md) | 按主题读取与默认自动沉淀已接线；28用例通过 | 后续任务按命中主题执行；CI配置已接入、远端未运行 |
| 已发布v0.2.28 | [SP-196-upstream-optimization-delivery](./SP-196-upstream-optimization-delivery/README.md) | 主线集成与双架构/Homebrew验收完成 | active Resize/跨OS专项证明与性能量测另行推进；worktree/分支已清理 |
| 已归档 | [SP-194-reference-project-updates](./SP-194-reference-project-updates/README.md) | 23主要仓库+9候选更新报告与分组来源已完成；文档门禁与来源结构校验通过 | 后续可纳入项按SP-207独立实施、验收与本地合并 |
| 长期追踪 | [SP-193-ictrl-reference-tracking](./SP-193-ictrl-reference-tracking/README.md) | 正式列为长期参考；初始基线 main@99dbfec / v1.97.1；本聊天每日北京时间 10:00 追踪 | 有价值变化通知，增量归档后更新检查点；后续按SP-207直接评估、独立立项与验收合并 |
| 已集成（本地 main） | [SP-192-ictrl-adoption-feasibility](./SP-192-ictrl-adoption-feasibility/README.md) | 五机制已接CLI/HTTP/runtime；CLI1250、root274、Web12、iOS115、Android52与完整APK及真实只读AX/alias/OCR/settle通过 | `e308a2eb` / merge `da76a708`，main总门禁通过；真实设备与OCR输入坐标边界见限制收口计划；worktree已清理 |
| v0.2.25 已发布／#215–220 已关闭 | [SP-190-open-issues-integration](./SP-190-open-issues-integration/README.md) | #214–#220 本地集成与统一验收；保留各项证据边界，#215～220 已关闭，#214 继续开放 | main CI / Release / Homebrew 通过，已回复关闭 |
| v0.2.25 已发布／#215–220 已关闭 | [SP-189-issue-220-package-result-path](./SP-189-issue-220-package-result-path/README.md) | #220：package result 路径与 inline parser 一致；49 + 2 focused tests 通过，夹具贯通执行结果路径解析，非实际 Xcode test | main CI / Release / Homebrew 通过，已回复关闭 |
| v0.2.25 已发布／#215–220 已关闭 | [SP-188-issue-219-generic-ios-build](./SP-188-issue-219-generic-ios-build/README.md) | #219：显式 generic iOS SDK-only build；51 + 5 focused tests 通过，未做真实 SDK 编译 | main CI / Release / Homebrew 通过，已回复关闭 |
| v0.2.25 已发布／#215–220 已关闭 | [SP-187-issue-218-host-hid-availability](./SP-187-issue-218-host-hid-availability/README.md) | #218：隔离兼容性诊断与实际 bootstrap 失败分类；15 + 8 focused tests 通过，不宣称现代 HID 可用 | main CI / Release / Homebrew 通过，已回复关闭 |
| v0.2.25 已发布／#215–220 已关闭 | [SP-186-issue-217-xcode-run-exit](./SP-186-issue-217-xcode-run-exit/README.md) | #217：xcode run 构建失败非零退出与单一 final；2 focused tests 通过 | main CI / Release / Homebrew 通过，已回复关闭 |
| v0.2.25 已发布／#215–220 已关闭 | [SP-185-issue-216-host-input-discovery](./SP-185-issue-216-host-input-discovery/README.md) | #216：type discovery 与 pasteboard guidance；37 focused tests 通过，输入仍 fail closed | main CI / Release / Homebrew 通过，已回复关闭 |
| v0.2.25 已发布／#215–220 已关闭 | [SP-184-issue-215-host-swipe](./SP-184-issue-215-host-swipe/README.md) | #215：离线 Simulator swipe CLI；163 focused tests 通过，真实 swipe/pager 未验证 | main CI / Release / Homebrew 通过，已回复关闭 |
| 研究已归档 | [SP-181-device-hub-paradigm](./SP-181-device-hub-paradigm/README.md) | Device Hub 范式研究交付保留 | 无当前自动实施队列；明确新需求时另行裁决 |
| 设计已归档 | [SP-182-trusted-execution-system](./SP-182-trusted-execution-system/README.md) | 可信执行系统双路径设计交付保留；未进入产品实现 | 无当前自动立项任务；不按历史设计自行扩张 |
| 已归档（范围收缩） | [SP-183-device-hub-official-adapter](./SP-183-device-hub-official-adapter/README.md) | v0.2.24 已交付发现/身份/容器/Crash metadata/管理诊断与 App 生命周期继续维护；不称完整 Device Hub 接入 | watchOS/tvOS runner 与 Temporary 查询保留实验/未验收，visionOS 2D 撤出排期；unsupported 不自动转待办，历史真机恢复状态 unknown 保留人工交接 |
| 兼容修复验证／命中待补 | [SP-180-xcode27-simulator-frameworks](./SP-180-xcode27-simulator-frameworks/README.md) | 已选Xcode只读查询、仅适配器子进程补框架；8测试与加载器恢复验证 | 10-06 CLI993+14/本地门禁通过；业务bridge截图完成，host HID导航另补，不将ACK算命中 |
| 已归档（取消自动删除） | [SP-179-issue-214-derived-data-cleanup](./SP-179-issue-214-derived-data-cleanup/README.md) | 保留 inspect / dry-run 与 confirm fail-closed，通用缓存自动删除需求取消 | 不宣称排他/竞态删除已实现；远端 #214 最后核实 OPEN，本轮未查询或关闭；未来专用缓存生命周期需独立明确范围 |
| 已归档 | [SP-178-issue-213-real-device-runtime](./SP-178-issue-213-real-device-runtime/README.md) | #213：真机 runtime readiness 诊断、单一 smoke JSON 与可执行 setup；不自动注入 endpoint | v0.2.21 已发布并回复关闭；CLI 983/root 269、CocoaPods lint、双架构与 Homebrew 验证全过；真机端到端未复测 |
| 已归档 | [SP-176-open-issues-integration](./SP-176-open-issues-integration/README.md) | 6 条 open issue 的隔离实现与验收 | CLI 977、root 269、UIKit 46 全过；CI 34179623896 通过，6 条 issue 已关闭 |
| 已归档（范围收口） | [SP-177-ios-simulator-resource-management](./SP-177-ios-simulator-resource-management/README.md) | 单设备资源 plan/apply/verify/restore 已由 SP-196 随 v0.2.28 交付 | 维护显式单点工具；fleet、自动 replay/evidence 编排和量化性能目标撤出当前队列，不重复旧 mutation 待办 |
| 已归档 | [SP-175-issue-212-xcode-cache-evidence](./SP-175-issue-212-xcode-cache-evidence/README.md) | 6 条 open issue 的隔离实现与验收 | CLI 977、root 269、UIKit 46 全过；CI 34179623896 通过，6 条 issue 已关闭 |
| 已归档 | [SP-174-issue-211-label-text-attributes](./SP-174-issue-211-label-text-attributes/README.md) | 6 条 open issue 的隔离实现与验收 | CLI 977、root 269、UIKit 46 全过；CI 34179623896 通过，6 条 issue 已关闭 |
| 已归档 | [SP-173-issue-207-harmony-arkweb-bridge-call](./SP-173-issue-207-harmony-arkweb-bridge-call/README.md) | 6 条 open issue 的隔离实现与验收 | CLI 977、root 269、UIKit 46 全过；CI 34179623896 通过，6 条 issue 已关闭 |
| 已归档 | [SP-172-issue-208-longpress-gesture-path](./SP-172-issue-208-longpress-gesture-path/README.md) | 6 条 open issue 的隔离实现与验收 | CLI 977、root 269、UIKit 46 全过；CI 34179623896 通过，6 条 issue 已关闭 |
| 已归档 | [SP-171-issue-209-collection-cell-activation](./SP-171-issue-209-collection-cell-activation/README.md) | 6 条 open issue 的隔离实现与验收 | CLI 977、root 269、UIKit 46 全过；CI 34179623896 通过，6 条 issue 已关闭 |
| 已归档 | [SP-170-issue-210-xcode-test-bounded-jsonl](./SP-170-issue-210-xcode-test-bounded-jsonl/README.md) | 6 条 open issue 的隔离实现与验收 | CLI 977、root 269、UIKit 46 全过；CI 34179623896 通过，6 条 issue 已关闭 |
| 已关闭 | [SP-169-issue-206-app-marketing-version](./SP-169-issue-206-app-marketing-version/README.md) | #206：iOS `app info`/`app list` 已暴露无歧义的 `marketingVersion`（CFBundleShortVersionString）与 `buildNumber`（CFBundleVersion），legacy `version` 保留并明确映射到 build number；schema `host.app-info`/`host.app-list` 已挂载 | 已随 CI `31791782001` 关闭；真实 Simulator 风险保留 |
| 已关闭 | [SP-168-issue-205-target-leases](./SP-168-issue-205-target-leases/README.md) | #205：并行 agent 流程现可用 opt-in 目标租约（acquire/status/release/takeover、带界 TTL、owner 标签、`target_lease_conflict` 稳定信封）；`app open-url|launch|terminate` 与 `act tap` 支持 `--lease` 门禁，只读观察豁免，无租约时行为不变 | 已随 CI `31791782001` 关闭；真实 Simulator 风险保留 |
| 已关闭 | [SP-167-issue-204-ios-webview-form-input](./SP-167-issue-204-ios-webview-form-input/README.md) | #204：iOS WKWebView 表单输入契约 —— snapshot 发现 contenteditable/textarea 表单目标、`webview focus/type/set-text` 与 `act focus/set-text/type --webview` 一等公民焦点切换、input/change dispatch 证据与 value 后置条件、未 opt-in 时 typed unsupported + host-HID fallback | 已随 CI `31791782001` 关闭；真实 WebView/Simulator 验证留待设备 |
| 已关闭 | [SP-166-issue-203-ios-text-query-consistency](./SP-166-issue-203-ios-text-query-consistency/README.md) | #203：embedded `wait --text` / `act find` 已与 `observe tree`/`observe current` 共享文本归一化（trim + case/diacritic fold + substring）与 hidden visibility 规则；`act find` 无匹配返回结构化 `text_not_found` 而非成功空输出 | 已随 CI `31791782001` 关闭；真实 Simulator smoke 验证保留 |
| 已关闭 | [SP-165-issue-202-sim-tap-help-dimensions](./SP-165-issue-202-sim-tap-help-dimensions/README.md) | #202：`sim tap` 的 point-space 已从 Simulator layout metadata 推导，help 宣传的 `--x/--y` 形状无需 width/height 即可满足 host action model；schema failureCodes/summary 已对齐 | 已随 CI `31791782001` 关闭；真实 Simulator/Baguette 风险保留 |
| 已关闭 | [SP-164-issue-201-harmony-act-find](./SP-164-issue-201-harmony-act-find/README.md) | #201：`act find` 已支持 `--platform harmony --device <harmony-target>` 从 Harmony uitest host layout 解析，Harmony `--device` 不再落入 embedded iOS server；`--platform ios|android` 返回 typed `unsupported_capability` | 已随 CI `31791782001` 关闭；真实 Harmony/HDC 风险保留 |
| 已完成（本地） | [SP-163-issue-200-simulator-foreground-runtime](./SP-163-issue-200-simulator-foreground-runtime/README.md) | #200：显式 `sim:<UDID>` / 裸 UUID 的纯坐标 `act tap` 已在 embedded `/targets` 前进入 ready local host-HID，不再回退到同 Simulator 的后台 runtime | focused 20/20 与本地总门禁通过；#200 已随 CI `31778845414` 评论/关闭，真实 Simulator/Baguette 风险保留 |
| 已归档 | [SP-157-open-issues-178-195-audit](./SP-157-open-issues-178-195-audit/README.md) | #178–#194 的合同修复与安全收口已进入 `main`；#195 由 SP-159、#196 由 SP-158、#197 由 SP-160 补齐，20 条 issue 已全部评论并关闭 | CI `31301092517` 全绿；真实设备/签名/Harmony smoke 风险保留，#164 原样隔离 |
| 已合并（PR #177） | [SP-156-issue-176-xcode-compact-progress](./SP-156-issue-176-xcode-compact-progress/README.md) | #176 已为 `xcode build` 增加默认 compact progress，保留 lifecycle/heartbeat/bounded diagnostics/artifact/final，显式 full 恢复旧 stream | issue 已关闭；CI `30515397742` 通过，真实私有 workspace build 未运行 |
| 已归档 | [SP-158-issue-196-xcode-archive-export](./SP-158-issue-196-xcode-archive-export/README.md) | #196：Xcode archive 与 IPA export 的 schema-backed CLI workflow 已进入 `main` | CI `31301092517` 全绿并已关闭；真实签名/IPA 安装风险保留 |
| 已归档 | [SP-159-issue-195-ios-ddi-recovery](./SP-159-issue-195-ios-ddi-recovery/README.md) | #195：`ddi_missing` 的可执行 iOS real-device app-install recovery 已进入 `main` | CI `31301092517` 全绿并已关闭；真实 DDI/tunnel smoke 风险保留 |
| 已归档 | [SP-160-issue-197-harmony-wait-budget](./SP-160-issue-197-harmony-wait-budget/README.md) | #197：Harmony wait 在剩余预算低于 0.4 秒时不再启动 `dumpLayout`/`recv`，返回标准 timeout envelope | CI `31301092517` 全绿并已关闭；真实 Harmony HDC/ArkUI smoke 风险保留 |
| 已完成（本地） | [SP-161-issue-198-harmony-signed-hap](./SP-161-issue-198-harmony-signed-hap/README.md) | #198：`assembleApp` 只选择 signed HAP；unsigned-only fail-closed，并保持 artifact/nextAction 同源 | `BuildRunnerTests` 10/10、`BuildRuntimeTests` 4/4、release build 通过；#198 已随 CI `31778845414` 评论/关闭，真实 Harmony smoke 未运行 |
| 已完成（本地） | [SP-162-issue-199-ios-collection-cell-host-hid](./SP-162-issue-199-ios-collection-cell-host-hid/README.md) | #199：`act tap` 增加 `--allow-host-hid-fallback`；默认拒绝 envelope 现提供 same-target、matched-OID 精确恢复路径与绑定同 target 的 verification | recovery contract 1/1、fallback 8/8、`InputOutputTests` 4/4、release build 通过；#199 已随 CI `31778845414` 评论/关闭，真实 Simulator/Baguette 风险保留 |
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
| 已归档 | [SP-126-testrec-convergence](./SP-126-testrec-convergence/README.md) | Hybrid、bounded importer、单 flow 真实纵切与兼容边界已交付；SP-126～136 已由 d0f09d3c 进入主线 | 本期完成；后续可靠性只按本页收口段唯一入口条件触发，不恢复旧 Luna/P0 队列 |
| 已发布（v0.2.16） | [SP-127-issue-168-ios-real-device-terminate-pid](./SP-127-issue-168-ios-real-device-terminate-pid/README.md) | #168 已采用安全 fallback：shared terminate 只接受显式 PID，iOS real bundle-ID terminate 无可证实 PID 时 fail closed；不实现猜测式 PID join | issue 已关闭；未声称真机 bundle-ID terminate 成功，真实设备 smoke 未运行 |
| 已发布（v0.2.16） | [SP-128-issue-167-xcode-device-alias-preflight](./SP-128-issue-167-xcode-device-alias-preflight/README.md) | Xcode real-device run 已确定先做 target selection preflight，再进入昂贵 build；保持既有 build/install/launch 合同 | issue 已关闭；真实 Xcode/device 与 live alias store 验证缺口保留 |
| 已完成（本地） | [SP-129-serve-loopback-default](./SP-129-serve-loopback-default/README.md) | `triton serve` 无 `--host` 时默认绑定 `127.0.0.1:19421`；显式非 loopback host 保持兼容；Bonjour publish 语义暂不改变 | 已进入本地 main；联合 docs/CLI 门禁通过，Bonjour 风险不变 |
| 已发布（v0.2.16） | [SP-130-issue-166-runtime-jpeg-normalization](./SP-130-issue-166-runtime-jpeg-normalization/README.md) | #166 已将 legacy embedded JPEG 解码并统一规范化为 PNG，避免 CLI/evidence/replay/test-run 发布伪 PNG 或丢弃有效证据 | issue 已关闭；SP-149 follow-up 已随 PR #177 合并，物理设备 JPEG smoke 未运行 |
| 已归档 | [SP-131-ios-simulator-canonical-proof](./SP-131-ios-simulator-canonical-proof/README.md) | 仓内 Debug fixture 已在 dedicated iOS Simulator 上真实完成 `test validate -> test run -> evidence`：6 steps、2 assertions、0 failures，证据含 runtime target、PNG、AX/hierarchy | importer已由SP-132、真实imported flow已由SP-133交付；本期归档，不重复派发 |
| 已归档 | [SP-132-testrec-import-seam](./SP-132-testrec-import-seam/README.md) | P0 已建立 `.tritontestcase -> test import -> test validate` 的 offline seam；bundle identity 与 `ios-simulator` target 均显式输入，映射不足一律 fail-closed | imported plan真实执行已由SP-133完成；保留offline seam，不新建executor |
| 已归档 | [SP-133-imported-ios-simulator-proof](./SP-133-imported-ios-simulator-proof/README.md) | imported AX plan 已在 dedicated iOS Simulator 经既有 `test run` 产生真实 passed verdict/evidence：6 steps、2 assertions、0 failures，并保留 normalized-plan provenance | 自管 server 已停止、Simulator 已恢复 Shutdown；sensitive evidence 仅作本机可恢复处置、不入 Git，不扩 executor/Android/Web/Wails/真机；#164 WIP 继续隔离 |
| 已归档 | [SP-134-ios-simulator-reliability-gate](./SP-134-ios-simulator-reliability-gate/README.md) | 离线 ECR/FER/ORR gate 与后继 receipt-backed 加固已交付；legacy --samples 固定 diagnostic blocked | 真实 3×20+1 未执行；未来仅按本页收口段唯一专项验收，不挂起已完成实现 |
| 已完成（本地） | [SP-135-testrec-compatibility-guidance](./SP-135-testrec-compatibility-guidance/README.md) | testrec dry-run/local-simulated/matrix 保留兼容 status，但新增不可作为真实 verdict 或 reliability sample 的 machine-readable boundary | compatibility已交付；collection preflight已由SP-136完成，不恢复testrec executor |
| 已完成（本地） | [SP-136-ios-simulator-reliability-collection-preflight](./SP-136-ios-simulator-reliability-collection-preflight/README.md) | 已离线冻结 3 flow × 20 的 imported-plan、canonical target、reset/negative-control 与 fresh evidence layout 合同 | live harness已由SP-140及后继加固交付；真实采样仅按本页唯一条件专项启动 |
| 已发布（v0.2.16） | [SP-137-issue-171-safe-collection-tap](./SP-137-issue-171-safe-collection-tap/README.md) | #171 已收紧 embedded `UICollectionViewCell` tap：无公开可证实 activation 时固定返回 `unsupported_capability`，且 accessibility gesture 候选不会越过当前 cell | issue 已关闭；真实 UIKit/Simulator route smoke 未运行 |
| 已发布（v0.2.16） | [SP-138-issue-170-xcode-real-device-destination](./SP-138-issue-170-xcode-real-device-destination/README.md) | #170 已收紧 Xcode `--device` 的 settings/build/test/run preflight、exact raw execution destination 与 public-output redaction | issue 已关闭；真实 Xcode、签名、安装与启动 smoke 未运行 |
| 已发布（v0.2.16） | [SP-139-issue-169-xcode-focused-testing](./SP-139-issue-169-xcode-focused-testing/README.md) | #169 已为 `triton xcode test` 增加 repeatable `--only-testing`，每项保持独立 xcodebuild argv，JSON/JSONL 可审计 sourceCommand | issue 已关闭；不实现 `--skip-testing`，真实 XCTest/xcodebuild 未运行 |
| 已完成（本地） | [SP-140-ios-simulator-reliability-live-harness](./SP-140-ios-simulator-reliability-live-harness/README.md) | receipt-backed reserve/sample 将 3×20+1 的 future collection 固化为 immutable contract、strict exact target 与 no-clobber slot；业务 mismatch 保持 typed result + exit 语义 | 本地 harness/契约验证完成；不得自动真实采样，后续必须先获得 dedicated Simulator、server ownership、reset recipe、negative control 与私有 evidence 授权 |
| 已发布（v0.2.16） | [SP-141-packaged-web-simulator-input](./SP-141-packaged-web-simulator-input/README.md) | packaged `/web/host-input` 已按 iOS real runtime mirror、三平台 host target 与 unsupported 三路分流，不再错拒 Simulator | Homebrew 0.2.16 安装版真实 Simulator HTTP/页面点击通过，console 0 error/warning |
| 已吸收／退出待整合队列 | [SP-142-web-readonly-contract](./SP-142-web-readonly-contract/README.md) | browser Web write endpoint 统一只读；原切片证据保留 | 已由 SP-151 / PR #177 整合；旧本地 checkpoint 状态被后续证据替代 |
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
| 已归档（后继收敛完成） | [20260622-test-recorder-replay](./20260622-test-recorder-replay/README.md) | 历史 P0 合同与 local-simulated 保留兼容，Hybrid 已由 SP-126 交付并归档 | 不新增独立 testrec executor / matrix / live network；未来只按本页收口段唯一可靠性专项的项目条件触发 |
| 废弃 | [20260527-revyl-cli-agent-entrypoint-research](./20260527-revyl-cli-agent-entrypoint-research/README.md) | 研究价值已被 skill、schema、evidence、update 和 Agent Mobile Runtime Platform 吸收 | 不再按原 M1-M6 独立实施；历史材料继续作为参考 |
| 已归档 | [20260706-agent-mobile-runtime-platform](./20260706-agent-mobile-runtime-platform/README.md) | iOS Demo 已完成 target discovery、launch、action、evidence、LLM/VLM、Atlas、flow export 全链 smoke，满足“一期至少一个 target scope”验收 | Overloaded bootstrap 作为外部项目回归问题另行处理；其他 target scope 扩展必须新建有限 space |
| 已归档 | [20260701-host-framebuffer-stream](./20260701-host-framebuffer-stream/README.md) | SimulatorKit/IOSurface host stream、MJPEG route 和历史高帧率测量已落地 | 作为实验性 Web mock 能力保留，不再承诺 `<15ms/120 FPS` 产品 SLA；正式 Web 恢复时重新立项 |
| 已归档 | [20260702-cross-platform-framebuffer-stream](./20260702-cross-platform-framebuffer-stream/README.md) | Android/Harmony host pull stream、HTTP route、Web bridge 和截图证据已落地 | 作为 Web mock 原型归档，不再追加性能优化；正式产品化需重新定义边界和证据门禁 |
| 已归档 | [20260617-issue-61-android-emulator-adapter](./20260617-issue-61-android-emulator-adapter/README.md) | 旧 Web 编译 blocker 已消失，当前 `DeviceCrossPlatformTests` 93 项通过；Android Emulator 主链已有历史真实 smoke | 不再单独执行；后续 Android 回归走现有 emulator takeover 与 strong-control spaces |

## 独立 worktree 与本地集成状态

| Space | Branch | Worktree | 基线 | 当前状态与后续 |
| --- | --- | --- | --- | --- |
| `SP-192-ictrl-adoption-feasibility` | `feat/SP-192-ictrl-adoption-feasibility`（本地分支已删除） | 已清理（2026-10-14） | `main@8aaf6c31` | 五机制及Android/iOS验证限制收口完成，本地门禁通过；`e308a2eb` / merge `da76a708` 已合入本地main，main总门禁通过；worktree已清理 |
| `SP-156-issue-176-xcode-compact-progress` | `feat/SP-156-issue-176-xcode-compact-progress`（已清理） | 已清理（历史由 PR #177 merge 可达） | `feat/SP-153-issue-173-xcode-run-target-binding@57ff4092` | #176 已合并并关闭；compact/full 合同与 focused 证据保留 |
| `SP-157-open-issues-178-195-audit` | `feat/SP-157-open-issues-178-195-audit`（本地分支已删除） | 已清理（2026-10-14） | `main@e77c72b7` | `ad1e55a9` 已由 merge `1564e7ed` 进入主线；#178–#194 已评论并关闭，worktree已清理，审计记录已归档 |
| `SP-158-issue-196-xcode-archive-export` | `feat/SP-158-issue-196-xcode-archive-export`（本地分支已删除） | 已清理（2026-10-14） | `main@e77c72b7` | `b3d0c27c` 已由 merge `424113b6` 进入主线；#196 已评论并关闭，真实签名风险保留；worktree已清理 |
| `SP-159-issue-195-ios-ddi-recovery` | `feat/SP-159-issue-195-ios-ddi-recovery`（本地分支已删除） | 已清理（2026-10-14） | `main@e77c72b7` | `45c3ebbd` 已由 merge `faa74638` 进入主线；#195 已评论并关闭，真实 DDI/tunnel 风险保留；worktree已清理 |
| `SP-160-issue-197-harmony-wait-budget` | `feat/SP-160-issue-197-harmony-wait-budget`（本地分支已删除） | 已清理（2026-10-14） | `main@e77c72b7` | `0ff8089e` 已由 merge `e77c72b7` 进入主线；#197 已评论并关闭，真实 Harmony smoke 风险保留；worktree已清理 |
| `SP-161-issue-198-harmony-signed-hap` | `feat/SP-161-issue-198-harmony-signed-hap`（本地分支已删除） | 已清理（2026-10-14） | `main@c55c5cab` | `ffc69a34` 已由 merge `574bbc9c` 进入本地 main；#198 待远端评论/关闭，worktree已清理，审计记录已归档 |
| `SP-162-issue-199-ios-collection-cell-host-hid` | `feat/SP-162-issue-199-ios-collection-cell-host-hid`（本地分支已删除） | 已清理（2026-10-14） | `main@c55c5cab` | `711db3f2` 已由 merge `38967558` 进入本地 main；#199 待远端评论/关闭，真实 Simulator/Baguette 风险保留；worktree已清理 |
| `SP-163-issue-200-simulator-foreground-runtime` | `feat/SP-163-issue-200-simulator-foreground-runtime`（本地分支已删除） | 已清理（2026-10-14） | `origin/main@adbfc92c` | 已完成（本地）：focused 20/20、release schema 与 local gate 通过；未操作真实 Simulator，#200 待远端处置；worktree已清理 |
| `SP-164-issue-201-harmony-act-find` | `feat/SP-164-issue-201-harmony-act-find`（已清理） | 已清理（merge `8469375a` 可达） | `origin/main@8cc72765` | #201 已合并并关闭；Harmony `act find` host adapter 11/11 |
| `SP-165-issue-202-sim-tap-help-dimensions` | `feat/SP-165-issue-202-sim-tap-help-dimensions`（已清理） | 已清理（merge `07a11612` 可达） | `origin/main@8cc72765` | #202 已合并并关闭；sim tap point-space 62/62 |
| `SP-166-issue-203-ios-text-query-consistency` | `feat/SP-166-issue-203-ios-text-query-consistency`（已清理） | 已清理（merge `e27e0de3` 可达） | `origin/main@8cc72765` | #203 已合并并关闭；共享文本归一化 245/245、4/4 |
| `SP-167-issue-204-ios-webview-form-input` | `feat/SP-167-issue-204-ios-webview-form-input`（已清理） | 已清理（merge `e05d6350` 可达） | `origin/main@8cc72765` | #204 已合并并关闭；WebView 表单输入契约 31/31（integration fix `d924253c` 复修 podspec lint） |
| `SP-168-issue-205-target-leases` | `feat/SP-168-issue-205-target-leases`（已清理） | 已清理（merge `6f3ac3ca` 可达） | `origin/main@8cc72765` | #205 已合并并关闭；focused lease suites 转绿、release schema 通过 |
| `SP-169-issue-206-app-marketing-version` | `feat/SP-169-issue-206-app-marketing-version`（已清理） | 已清理（merge `5dbbdc90` 可达） | `origin/main@8cc72765` | #206 已合并并关闭；shared 42/42、root 241/241 |
| `SP-152-issue-172-runtime-reregistration` | `feat/SP-152-issue-172-runtime-reregistration`（已清理） | 已清理（历史由 PR #177 merge 可达） | `main@d2578089` | #172 已合并并关闭；runtime lifecycle/compatibility 证据保留 |
| `SP-153-issue-173-xcode-run-target-binding` | `feat/SP-153-issue-173-xcode-run-target-binding`（已清理） | 已清理（历史由 PR #177 merge 可达） | `main@d2578089` | #173 已合并并关闭；单目标绑定证据保留 |
| `SP-154-issue-174-simulator-swipe-lifecycle` | `feat/SP-154-issue-174-simulator-swipe-lifecycle`（已清理） | 已清理（历史由 PR #177 merge 可达） | `main@d2578089` | #174 已合并并关闭；persistent input lifecycle 证据保留 |
| `SP-126-testrec-convergence` | `feat/SP-126-testrec-convergence`（历史登记） | `../TritonKit-worktrees/SP-126-testrec-convergence/`（历史路径，本轮未清理） | `main@931645ed` | 本期已归档；可信基线/importer/单 flow proof/离线 gate/compatibility/preflight 已由 d0f09d3c 进入主线；不据旧分支路径恢复执行 |
| `SP-127-issue-168-ios-real-device-terminate-pid` | `feat/SP-127-issue-168-ios-real-device-terminate-pid` | `../TritonKit-worktrees/SP-127-issue-168-ios-real-device-terminate-pid/` | `5f6c2f6f` | `cef52ea2` 已经由 `d0f09d3c` 进入本地 main；保留真机 smoke blocker |
| `SP-128-issue-167-xcode-device-alias-preflight` | `feat/SP-128-issue-167-xcode-device-alias-preflight` | `../TritonKit-worktrees/SP-128-issue-167-xcode-device-alias-preflight/` | `feat/SP-126-testrec-convergence@5f6c2f6f` | `25f7e048` 已经由 `d0f09d3c` 进入本地 main；保留真实 Xcode/device 覆盖缺口 |
| `SP-129-serve-loopback-default` | `feat/SP-129-serve-loopback-default` | `../TritonKit-worktrees/SP-129-serve-loopback-default/` | `feat/SP-126-testrec-convergence@5f6c2f6f` | `f0f3b0a0` 已经由 `d0f09d3c` 进入本地 main；保留 Bonjour 广播语义风险 |
| `SP-130-issue-166-runtime-jpeg-normalization` | `feat/SP-130-issue-166-runtime-jpeg-normalization` | `../TritonKit-worktrees/SP-130-issue-166-runtime-jpeg-normalization/` | `codex/sp126-trusted-baseline-integration@2fddf6a0` | #166 JPEG -> PNG normalizer 已经由 `d0f09d3c` 进入本地 main；不读取或修改 #164 dirty WIP |
| `SP-131-ios-simulator-canonical-proof` | `feat/SP-131-ios-simulator-canonical-proof` | `../TritonKit-worktrees/SP-131-ios-simulator-canonical-proof/` | `feat/SP-130-issue-166-runtime-jpeg-normalization@a7404033` | local checkpoint 将记录真实 dedicated Simulator 的手写最小 plan proof；server 已停止、Simulator 已恢复 Shutdown；不读取或修改 #164 dirty WIP |
| `SP-132-testrec-import-seam` | `feat/SP-132-testrec-import-seam` | `../TritonKit-worktrees/SP-132-testrec-import-seam/` | `feat/SP-131-ios-simulator-canonical-proof@6f700b13` | P0 local checkpoint：只读 compiled contract，显式 ios-simulator target，输出可 validate YAML 与 typed provenance；P1 才运行 device，#164 dirty WIP 未读取或修改 |
| `SP-133-imported-ios-simulator-proof` | `feat/SP-133-imported-ios-simulator-proof` | `../TritonKit-worktrees/SP-133-imported-ios-simulator-proof/` | `feat/SP-132-testrec-import-seam@b065b3f0` | P1 local proof 已通过：新鲜 source/import/validate、专用 Simulator、self-managed 19421 server、Debug fixture、真实 `test run` 与 evidence/provenance 已串行验证；server 已停止、Simulator 已恢复 Shutdown，#164 dirty WIP 未读取或修改 |
| `SP-134-ios-simulator-reliability-gate` | `feat/SP-134-ios-simulator-reliability-gate`（历史登记） | `../TritonKit-worktrees/SP-134-ios-simulator-reliability-gate/`（历史路径，本轮未清理） | `feat/SP-133-imported-ios-simulator-proof@19e2c35f` | 离线 gate 已归档并入主线；真实采样仅保留条件触发专项，不表示已有61槽真实证据；本轮未执行设备/服务或物理 worktree 清理 |
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

## 2026-10-10 指定历史分支收口

- `20260707-github-issue-batch`：源 tip `9c0b63b0` 经 `69bdb3b9` 合入 `main`；保留主线最新文件内容，清理对应 `codex/20260707-github-issue-batch` 分支。
- `20260707-issue-140-redaction-preflight`：源 tip `ab6f1263` 经 `e4a09384` 合入 `main`；保留主线最新文件内容，清理对应 `codex/20260707-issue-140-redaction-preflight` 分支。
- `20260722-issue-164-evidence-simulator-screenshot-fidelity`：源 tip `fcd57ce5` 经 `5f6fbecb` 合入 `main`；保留主线最新文件内容，清理对应 `codex/20260722-issue-164-evidence-simulator-screenshot-fidelity` 分支。
- #164 旧 worktree 目录已不存在，仅移除对应失效注册；其他分支与 worktree 不在本次清理范围。

## 2026-10-12 · Open issues 本地集成

- `SP-190-open-issues-integration`：集成 worktree `../TritonKit-worktrees/SP-190-open-issues-integration`，已本地集成 SP-179 安全止血与 SP-184～189 各 issue 切片；完整门禁与线上 CI 通过，v0.2.25 已发布。各独立分支的 focused 证据与真实平台缺口保留在对应 README，#215～#220 已关闭，#214 保持开放。

## 2026-10-13 · 默认 DerivedData 路径调整

- [SP-191-default-xcode-deriveddata](./SP-191-default-xcode-deriveddata/README.md)：已发布（`v0.2.26`）；默认交给 Xcode 使用用户级 DerivedData，显式 `--derived-data-path` 仅用于隔离/恢复并提示高磁盘占用；CLI/root tests、schema smoke、docs 门禁与远端 CI 通过。

| 已引入本地main | [SP-195-ios-runner-product](./SP-195-ios-runner-product/README.md) | 产品与设备验收、主仓门禁通过 | 参考文档306dc42b与Runner分别提交；原worktree已清理；未push/release；已完成worktree收口见SP195计划；本地完成分支已清理/归档 |

## 2026-10-16 · 选择器开关

| 状态 | Space | 范围 | 下一步 |
| --- | --- | --- | --- |
| v0.2.30已发布 | [SP-209-picker-runtime-toggle](./SP-209-picker-runtime-toggle/README.md) | SDK运行时开关与原生半屏Modal | 0e296783已合入main并发布v0.2.30；原始证据已迁移归档；分支/worktree已清理 |

## 2026-10-19 参考采用当前队列

| 状态 | Space | 范围 | 下一步 |
| --- | --- | --- | --- |
| v0.2.32已发布 | [SP-210-simulator-ax-geometry](./SP-210-simulator-ax-geometry/README.md) | Simulator AX缺失/非法几何不再猜测坐标 | 7a8e9f56；离线验收完成，main合后完整CLI与local门禁复验通过；已推送/发布；分支/worktree已清理 |
| v0.2.32已发布 | [SP-211-reference-adoption-integration](./SP-211-reference-adoption-integration/README.md) | 本批主控验证与本地合并 | 7a8e9f56；离线验收完成，main合后完整CLI与local门禁复验通过；已推送/发布；分支/worktree已清理 |
| v0.2.32已发布 | [SP-212-mobile-mcp-android-contracts](./SP-212-mobile-mcp-android-contracts/README.md) | Android 前台 activity 身份与 ADB legacy 文本转义 | 7a8e9f56；离线验收完成，main合后完整CLI与local门禁复验通过；已推送/发布；分支/worktree已清理 |
| v0.2.32已发布 | [SP-213-mobile-mcp-contracts-integration](./SP-213-mobile-mcp-contracts-integration/README.md) | SP-212 主控验证与本地main合并 | 7a8e9f56；离线验收完成，main合后完整CLI与local门禁复验通过；已推送/发布；分支/worktree已清理 |

2026-10-19追加：原主目录WIP已原样保存为1131b183并完成差异裁决，资料状态与本地main一致；[完整合并记录](./SP-211-reference-adoption-integration/plans/20261019-wip-closeout.md)。

| v0.2.32已发布 | [SP-214-simulator-display-safety](./SP-214-simulator-display-safety/README.md) | Simulator主屏拓扑未知/非主屏时拒绝动作与捕获 | `0d35e95e`；2026-10-24由SP-218补真实displays响应修复与候选截图通过；其余AX/跨工具链未验；worktree/分支已清理 |

| v0.2.32已发布 | [SP-215-simulator-display-integration](./SP-215-simulator-display-integration/README.md) | SP-214独立主控验证、本地合并 | `b782c192`；原离线集成已完成；2026-10-24真实截图与兼容修复由SP-218接替；worktree/分支已清理 |

| v0.2.32已发布 | [SP-216-harmony-forward-cleanup](./SP-216-harmony-forward-cleanup/README.md) | ArkWeb HDC清理当前归属复核与进程内互斥 | `34f713c7`；HDC ownership 清理与 37 项 focused tests 通过，真实 HDC 未执行；worktree/分支已清理 |

| v0.2.32已发布 | [SP-217-harmony-forward-integration](./SP-217-harmony-forward-integration/README.md) | SP-216独立主控验收、本地合并 | `36145c62`；离线验收完成，真实 HDC/跨进程竞态未执行；worktree/分支已清理 |

| 已归档／真实验收通过 | [SP-218-issue-222-device-hub-input](./SP-218-issue-222-device-hub-input/README.md) | native HID tap/swipe、Device Hub占用拒绝与恢复均有本机业务后置证据 | 2026-10-24 Xcode27.1/iOS27.0通过；c0ce0cc2与CI已通过；v0.2.33已发布并通过双架构/Homebrew/只读Web验收，用户项目另验 |

| 已归档／录制真实验收通过 | [SP-219-simulator-resizable-routing](./SP-219-simulator-resizable-routing/README.md) | 普通→Resize→普通录屏真实解码通过 | 2026-10-24；Resize AX/HID保持unsupported，不作为本space待办 |
| v0.2.32已发布 | [SP-220-simulator-resizable-integration](./SP-220-simulator-resizable-integration/README.md) | SP-219 主控验证、本地合并 | 候选 `51cd20dd` 已验收并合入 `f9399e5e`；worktree已清理 |

## 2026-10-27 新采用批次

- [SP-225-simulator-files-recents](./SP-225-simulator-files-recents/README.md)：CLI只读Files Recents精确服务诊断，已验收合main607cdf1c并清理关闭。
- [SP-226-files-recents-integration](./SP-226-files-recents-integration/README.md)：有限主控已完成验收，合后94+1528完整CLI与docs通过，证据归档及会话关闭。

## 2026-10-27 v0.2.34 发布准备

- [SP-227-release-v0-2-34](./SP-227-release-v0-2-34/README.md)：`v0.2.34` 已发布；Release/CI 7 job、双架构资产、skills、远端 Homebrew formula、仓库外 packaged Web 与真实浏览器 console 0 error/warning 均通过，CocoaPods 仅 lint。

## 2026-10-28 开放 issue 批次

- [SP-228-issue-226-real-device-launch-args](./SP-228-issue-226-real-device-launch-args/README.md)：已合并，issue已关闭；见SP-241合并归档报告，已随v0.2.35发布，验收见SP-242。
- [SP-229-issue-227-android-build-diagnostics](./SP-229-issue-227-android-build-diagnostics/README.md)：已合并，issue已关闭；见SP-241合并归档报告，已随v0.2.35发布，验收见SP-242。
- [SP-230-issue-228-android-wait-ready](./SP-230-issue-228-android-wait-ready/README.md)：已合并，issue已关闭；见SP-241合并归档报告，已随v0.2.35发布，验收见SP-242。
- [SP-231-issue-229-android-observe-stale-tree](./SP-231-issue-229-android-observe-stale-tree/README.md)：已合并，issue已关闭；见SP-241合并归档报告，已随v0.2.35发布，验收见SP-242。
- [SP-232-issue-231-simulator-log-partial](./SP-232-issue-231-simulator-log-partial/README.md)：已合并，issue已关闭；见SP-241合并归档报告，已随v0.2.35发布，验收见SP-242。
- [SP-233-issue-232-ios-real-backend-docs](./SP-233-issue-232-ios-real-backend-docs/README.md)：已合并，issue已关闭；见SP-241合并归档报告，已随v0.2.35发布，验收见SP-242。
- [SP-234-issue-225-ios-runner-transport](./SP-234-issue-225-ios-runner-transport/README.md)：已合并，issue已关闭；见SP-241合并归档报告，已随v0.2.35发布，验收见SP-242。
- [SP-235-issue-224-simulator-resize-query](./SP-235-issue-224-simulator-resize-query/README.md)：#224后续处理中；iPad1001已定位，unsupportedDevice分类与提示已补，默认capture/input仍受限；显式单LCD截图与全量门禁已通过，用户确认只验27.1，PR #236已合main（27c7a875），#224保持OPEN。
- [SP-236-issue-223-bar-button-activation](./SP-236-issue-223-bar-button-activation/README.md)：已合并，issue已关闭；见SP-241合并归档报告，已随v0.2.35发布，验收见SP-242。
- [SP-237-issue-222-device-hub-followup](./SP-237-issue-222-device-hub-followup/README.md)：已合并，issue已关闭；见SP-241合并归档报告，已随v0.2.35发布，验收见SP-242。
- [SP-238-issue-221-searchbar-input-focus](./SP-238-issue-221-searchbar-input-focus/README.md)：已合并，issue已关闭；见SP-241合并归档报告，已随v0.2.35发布，验收见SP-242。
- [SP-239-issue-230-ios-runner-geometry](./SP-239-issue-230-ios-runner-geometry/README.md)：已合并，issue已关闭；见SP-241合并归档报告，已随v0.2.35发布，验收见SP-242。
- [SP-240-issue-214-deriveddata-ownership](./SP-240-issue-214-deriveddata-ownership/README.md)：PR #235已合并，历史候选待关联；两处删除前约1.95 GiB，部分内容重复；#214保留OPEN，历史调用候选已归档，原容量映射仍缺；见该space溯源记录，两处现存缓存已按后续授权删除；物理回收量未知。
- [SP-241-open-issues-validation](./SP-241-open-issues-validation/README.md)：已合并归档，12关/1留；见SP-241合并归档报告，已随v0.2.35发布，验收见SP-242。

- [SP-242-release-v0-2-35](./SP-242-release-v0-2-35/README.md)：v0.2.35已发布；双架构/Homebrew通过，默认实时流Resize未知、工作台通过；#214 OPEN，主目录WIP未变。

| 待原任务整合 | [SP-244-emulator-service-slimming](./SP-244-emulator-service-slimming/README.md) | Android/Harmony模拟器资源管理与预览生命周期；仅登记 | 产品WIP与验收由原任务维护 |
| 待原任务整合 | [SP-245-rhine-design-adoption](./SP-245-rhine-design-adoption/README.md) | Rhine固定制品接入及设计先行；仅登记 | 产品WIP与验收由原任务维护 |
| 待原任务整合 | [SP-246-rhine-web-migration](./SP-246-rhine-web-migration/README.md) | 设备预览、层级、分屏和外壳的Rhine迁移；仅登记 | 产品WIP与验收由原任务维护 |
| 待原任务整合 | [SP-247-rhine-page-preferences](./SP-247-rhine-page-preferences/README.md) | Web页面组合及视觉偏好调整；仅登记 | 产品WIP与验收由原任务维护 |

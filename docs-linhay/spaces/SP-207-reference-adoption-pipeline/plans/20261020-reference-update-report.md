# 2026-10-20 参考项目更新与采用报告

## 结论与阶段

33 仓已发起官方默认分支 HEAD、全部非 draft Release 分页（含 prerelease）和固定 HEAD 许可证查询；本轮 **24 完整、9 partial**。相对各仓成功点/导入点有 7 仓变化，其中 Baguette 是已知历史 partial；相对昨日观察为 **6 仓新变化**。完整仓 5 个变化、19 个未变。摘要与观察保存后，逐仓原子推进完整检查点；9 个 partial 保留原点，不能报告整体无变化。

评估基线是实际 main `f82872e2fa457431ee7cbc7df2bafecea7ca6f1c`。SP-203～205、SP-210、SP-212 已交付；SP-211/SP-213 旧模型失败已退出旧开发待办。新增两个独立安全切片，规划/BDD/分支/worktree 已就绪；本轮没有产品实现、测试或合并。

## 可纳入与观察

- **SP-214 Simulator 主屏路由安全**：来自 [sim-use 31 提交增量](https://github.com/lycorp-jp/sim-use/compare/81c3089331aa0004fc97cd5330e2b32ca79dd6ce...dc58fe8ea2353cde5cb15944eaee16105ad27b4d)。当前 AX 仍用 mainScreenSize/mainScreenScale/displayId=0，appResize inactive 不能证明 Duo app 在主屏；SP-210 的有限数值和 SP-196 Resize gate 不覆盖该事实。采用范围是主屏路由未知或非主屏时在动作/捕获前安全拒绝，不直接引入 Duo 副屏 HID/AX、fold/rotate 或上游未知回退策略。独立主控 SP-215；[BDD/许可/文件面](../../SP-214-simulator-display-safety/README.md)。31 个 commit patch、99 文件清单与 98 当前完整源码已读取，并独立复核 blob hash。
- **SP-216 HDC 清理归属**：来自 [ai-phone d339057](https://github.com/dongxinsuperman/ai-phone/commit/d339057bc64aa85002570765e2a20d45e0391bae)。当前 ArkWeb 清理按缓存 localPort/remoteNode 直接 rm，需在当前完整 listing 中证明 target/local/remote/Forward 唯一归属，并串行化本进程分配/清理；未知不删，不重放已执行 CDP。独立主控 SP-217；[BDD/残余竞态/许可](../../SP-216-harmony-forward-cleanup/README.md)。官方 [HDC 文档](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/dfx/hdc.md#查询端口转发任务列表)推荐先 list 再删除，但不提供跨进程原子保证；上游关于 -t 全局行为的 fixture 主张尚未经本地设备验证。
- **iCTRL**：[3 个提交](https://github.com/OpenMinis/iCTRL/compare/d88bbf0b3a5addead31b4298d605d7ac7a87d6e7...874f528759b1b977971a06cc4a3594d169eb77b9) 收紧 stop 深链/日志出口、whoami 隐私及 RemotePairing 导入。Triton 日志/Runner 鉴权由 SP-204/205 覆盖；其 URL/通知/DDI 面不引入。HEAD 源码称 1.98.13，**最新已发布 Release 仍为 v1.98.12**。专项 [审阅](../../SP-193-ictrl-reference-tracking/plans/20261020-reference-review.md) 与独立状态保存。
- [Revyl v0.1.178](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.178)：branch/build 身份与 workflow fallback 核心源码保持 observe；托管控制面不纳入，许可证和剩余非核心审阅未闭合，不推进仓级点。
- [device-hub-ios](https://github.com/JaviSoto/device-hub-ios/commit/9f5481c3efdfb345df8cc627adb9147b58ed2041) 的 adaptive layout snapshot/lint 为上游 App 构建治理，observe；[android_world f8e78c0](https://github.com/google-research/android_world/commit/f8e78c0ab0bb8b5daa681afd0296ed0193a98f1f) 仅替换 Python fuzzy-matching 依赖，拒绝移植。无本地性能/兼容效果声明。

## 模型接口核对与真实分派

为 SP-214 执行和 SP-215 主控发起两次必要 `create_thread`，均显式 `model="gpt-6.1-sol"`、省略 reasoning 参数，仍返回 `could not validate model`。工具描述列出模型不等于端到端创建成功；没有 thread ID，也没有回退模型。SP-216/SP-217 在同接口确认失败后保留 pending，未重复无意义调用，更没有冒称这两角色已经调用失败。具体 [原始分派结果](20261020-dispatch.json) 与 [采用登记](adoption-state.json) 保留各阶段。后续复用四个现有 space/worktree 补缺角色，不重新建项。

## 完整性修正与恢复

- Baguette APK 关联源码 provenance、SKProcessRunner 无许可均是同一既有故障，保留旧点并去重。
- eyes-on-my-phone、revyl-cli、app-explorer、mobile-devtools、mobile-pr-reviewer 的固定 HEAD 无许可证全文；纠正昨日无正文仍标 complete 的口径，不倒推为本日上游删除许可证，原 checkpoint 保留但标为历史许可未复核。
- Revyl visual-regression、figma-design-checker 的 API 限流读取恢复后暴露缺许可；故障转为许可不完整，不误标 complete。CogniSim 完整恢复，MIT 全文 hash 已读取，可推进本仓成功点。
- figma-design-checker 昨日报告的 HEAD 曾误写为短缺字符串；本日官方 40 位 SHA 与历史成功/导入点相同，修正观察字段，不计为上游新增提交。
- 因缺许可证共 8 仓 partial（含 revyl-cli 同时增量未完全闭合），另 1 仓是 Baguette。不把缺许可当复制授权；不把下载源码/结构门禁当运行或全仓安全审计。

## 逐仓库结果

“新变化”相对昨日观察，而不是把历史 partial 重复报告成今天新增。

| 仓库 | HEAD | 新变化 | 完整性 | 最新非 draft Release | 裁决 |
| --- | --- | --- | --- | --- | --- |
| [tddworks/baguette](https://github.com/tddworks/baguette) | `14b39834fef6` | 否 | partial | v0.2.7 | observe |
| [EvanBacon/serve-sim](https://github.com/EvanBacon/serve-sim) | `a30d70a55e05` | 否 | 完整 | — | observe |
| [lycorp-jp/sim-use](https://github.com/lycorp-jp/sim-use) | `dc58fe8ea235` | 是 | 完整 | v0.15.0 | adopt |
| [MobAI-App/simslim](https://github.com/MobAI-App/simslim) | `6518ba7eab11` | 否 | 完整 | v0.12.2 | observe |
| [Mastersam07/OpenDeviceHub](https://github.com/Mastersam07/OpenDeviceHub) | `e50f07f1f448` | 否 | 完整 | v0.2.0 | observe |
| [JaviSoto/device-hub-ios](https://github.com/JaviSoto/device-hub-ios) | `9f5481c3efdf` | 是 | 完整 | — | observe |
| [heoblitz/Loupe](https://github.com/heoblitz/Loupe) | `ff1351242e6d` | 否 | 完整 | v0.5.1 | observe |
| [jfarcand/mirroir-mcp](https://github.com/jfarcand/mirroir-mcp) | `845a981163aa` | 否 | 完整 | v0.40.1 | observe |
| [RockxyApp/Rockxy](https://github.com/RockxyApp/Rockxy) | `de791b63e7f9` | 否 | 完整 | v0.41.0 | observe |
| [ProxymanApp/atlantis](https://github.com/ProxymanApp/atlantis) | `cc059013de87` | 否 | 完整 | 2.0.0 | observe |
| [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL) | `874f528759b1` | 是 | 完整 | v1.98.12 | observe |
| [getsentry/MobileBuildMCP](https://github.com/getsentry/MobileBuildMCP) | `d13ff0c707b0` | 否 | 完整 | v2.7.1 | covered |
| [awizemann/harness](https://github.com/awizemann/harness) | `3f58c077ded1` | 否 | 完整 | v0.8.4 | covered |
| [dongxinsuperman/ai-phone](https://github.com/dongxinsuperman/ai-phone) | `d339057bc64a` | 是 | 完整 | v0.8.0 | adopt |
| [karminski/eyes-on-my-phone](https://github.com/karminski/eyes-on-my-phone) | `eef71926e613` | 否 | partial | — | covered |
| [RevylAI/revyl-cli](https://github.com/RevylAI/revyl-cli) | `122fb01b1915` | 是 | partial | v0.1.178 | observe |
| [RevylAI/app-explorer](https://github.com/RevylAI/app-explorer) | `b3edc443dbfb` | 否 | partial | — | reject |
| [RevylAI/greenlight](https://github.com/RevylAI/greenlight) | `fcb36e395bd4` | 否 | 完整 | v0.2.0 | reject |
| [RevylAI/mobile-devtools](https://github.com/RevylAI/mobile-devtools) | `efc1dae5da08` | 否 | partial | — | reject |
| [RevylAI/mobile-pr-reviewer](https://github.com/RevylAI/mobile-pr-reviewer) | `ba1250c72f56` | 否 | partial | — | reject |
| [RevylAI/visual-regression](https://github.com/RevylAI/visual-regression) | `2758e8a88f4e` | 否 | partial | — | reject |
| [RevylAI/figma-design-checker](https://github.com/RevylAI/figma-design-checker) | `8b4e5cea045d` | 否 | partial | — | reject |
| [RevylAI/CogniSim](https://github.com/RevylAI/CogniSim) | `3d8902e01198` | 否 | 完整 | — | reject |
| [hughkli/Lookin](https://github.com/hughkli/Lookin) | `95e30fdcc815` | 否 | 完整 | 1.0.7 | observe |
| [OSU-NLP-Group/UGround](https://github.com/OSU-NLP-Group/UGround) | `8974f95b0685` | 否 | 完整 | — | observe |
| [bytedance/UI-TARS](https://github.com/bytedance/UI-TARS) | `582f3a7ea5d2` | 否 | 完整 | — | observe |
| [OpenBMB/AgentCPM-GUI](https://github.com/OpenBMB/AgentCPM-GUI) | `2168ae21b1be` | 否 | 完整 | — | observe |
| [X-PLUG/MobileAgent](https://github.com/X-PLUG/MobileAgent) | `11cea575561f` | 否 | 完整 | — | observe |
| [njucckevin/SeeClick](https://github.com/njucckevin/SeeClick) | `0ef37ac4d7aa` | 否 | 完整 | — | observe |
| [google-research/android_world](https://github.com/google-research/android_world) | `f8e78c0ab0bb` | 是 | 完整 | — | reject |
| [mobile-dev-inc/Maestro](https://github.com/mobile-dev-inc/Maestro) | `028c18b9ce74` | 否 | 完整 | cli-2.11.0 | covered |
| [linhay/SKProcessRunner](https://github.com/linhay/SKProcessRunner) | `24e036604b9e` | 否 | partial | 0.0.17 | reject |
| [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) | `c659f8ee3487` | 否 | 完整 | 1.0.12 | covered |

## 证据与验证

[机器观察](20261020-observations.json)、[sim-runtime](20261020-sim-runtime.md)、[agents/Revyl](20261020-agents-revyl.md)、[research](20261020-research.md)、[SP-193](../../SP-193-ictrl-reference-tracking/plans/20261020-check-summary.json)。原始官方 API、Release、LICENSE 全文/hash、patch、固定源码与本地主线对照在 `.build/reference-monitor/20261020/`。23 个非 iCTRL 完整仓的许可 hash 及 sim-use 98 个源 blob 已独立核对，iCTRL 的 9 个 blob 与 patch 增删数见其 completeness manifest。

未运行第三方代码、设备、签名/DDI、依赖安装、提交、推送或发布；未进行产品代码开发。收口已通过 `verify.sh --ci-docs`、独立 `check-docs.sh`（217 spaces）、`git diff --check`；新增报告/space的34条相对链接与JSON可解析性、33仓唯一性、9个partial检查点保持、旧交付main祖先及新角色无伪造thread均已核对。产品Swift/设备测试未执行，原因是本期仅追踪/规划且真实分派失败。经验检查更新原权威入口的当前断言与完整性状态，无新增重复skill/AGENTS条目。

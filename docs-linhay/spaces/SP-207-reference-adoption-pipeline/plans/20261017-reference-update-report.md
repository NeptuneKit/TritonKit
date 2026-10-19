# 2026-10-17 参考项目更新、采用与分派报告

## 结论与阶段

33仓均发起官方HEAD、非draft Release（含prerelease）和许可证查询；完整32，未完成增量审阅1，相对历史观察有变化9、无新HEAD/Release变化24。首次许可证全文hash建立基线，不倒推历史许可变化。完整结果和摘要先保存，再按仓库独立原子推进成功点；partial仓库保留旧检查点，不报告无变化。

“完整”限定为官方元信息/Release/许可查询、提交与文件清单分页完整、当前本机产品相关机制源码审阅闭合；纯云Web业务、生成证据和二进制行为验证明确范围排除，详见补审。它不代表全仓逐行审计或真实运行验收。

iCTRL main@d88bbf0、v1.98.12和Apache-2.0全文hash未变，专项证据见[SP-193](../../SP-193-ictrl-reference-tracking/plans/20261017-check-summary.json)。SP-203～205由SP-206的0a246d00完成本地整合，已核对真实main祖先关系及联合/合后验证摘要；采用登记从dispatched刷新为local_merged，不把旧交付作为今日新实现，不推导设备运行验收。

新增一个adopt：Simulator AX缺失或非法几何不得猜测坐标，详见[SP-210](../../SP-210-simulator-ax-geometry/README.md)；[SP-211](../../SP-211-reference-adoption-integration/README.md)负责其验证与本地集成。两份计划、独立branch/worktree已建立。两次必要create_thread均显式指定gpt-6.1-sol，工具返回could not validate model；没有成功thread ID，状态dispatch_blocked_model。未回退模型，未启动开发/主控，待模型可用后只补缺项，详见[分派证据](20261017-dispatch.json)。

## 有价值增量与采用边界

- [ai-phone固定452e7d7](https://github.com/dongxinsuperman/ai-phone/commit/452e7d77326f9fc0e5b003ecbf6cec5fc499e4bf)：运行实例LCD几何校验与拒绝无效值。固定机制源码/测试/MIT许可完整，根审计已核对main的devicePointSize仍有393×852/scale3猜测，且transform无效时透传原坐标。采用窄化为fail-closed与离线测试，不复制Python、不加入live探测/缓存，不以单机制完整证据推进整个仓库检查点。
- [Baguette更新](https://github.com/tddworks/baguette/compare/8930ac601e38e04540cb3cad9547347c160882e4...14b39834fef663c2eca868db98422e4eaa8e2bb3)：运行App实际defaults lookup/unset/live是磁盘prefs之外的观察候选；依赖注入helper，不能把现有diskWriteVerified升级为App消费验证。guest hinge涉及私有ABI，不直接引入。
- [serve-sim更新](https://github.com/EvanBacon/serve-sim/commit/c47a468b600362d14960504bfb4f222101ead634)：shell opt-in、socket/Origin信任和token不进入HTML；本地无对等Web exec面，Runner服务证明与日志隐私已覆盖相关方向，不新增Web控制面。显示/编码诊断保留观察；部分采集有界不代表所有host-rpc、日志字典或renderer状态均有全局预算。
- [sim-use更新](https://github.com/lycorp-jp/sim-use/commit/81c3089331aa0004fc97cd5330e2b32ca79dd6ce)：真机AX null root的有界只读重试；本地不使用其真机AXAudit后端，不照搬、不重放unknown动作。
- [Atlantis 2.0.0](https://github.com/ProxymanApp/atlantis/releases/tag/2.0.0)：新增发布记录，HEAD与导入观察相同；iOS26/27兼容仅上游声明，不代替本地运行验证，SP-196网络证据边界保持。
- [Revyl CLI](https://github.com/RevylAI/revyl-cli/commit/86de7c9797f98060cf465792367b3a662cd59cf4)：云/Web workflow、text-env与诊断留观察；本地stdin、alias新鲜度、settle等已有交付，不重复立项；主体未声明许可不得直接复制；两个插件README的MIT声明仅适用于其明确范围。
- [Maestro更新](https://github.com/mobile-dev-inc/Maestro/commit/028c18b9ce7441c117f161da4dfe8007e46fa61d)：动画/boot、Tab与ZIP规则分别对照本地。adb input、进程drain及安全解压已覆盖部分方向；不放松倍率与symlink边界，Tab简写与严格总deadline需独立证据，暂观察。android_world仅类型抑制，拒绝移植。

所有性能、测试数量与成功率若仅来自上游均未经本地验证；本次未运行上游代码、安装、签名/DDI、设备动作，未推送/发布。读取、静态评估、分派、实现、验证、本地合并分别记录。

## 基线与治理纠正

实际main为d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec（同级main-integrated worktree），主目录是codex/wip-main-before-sp209@0a0aec02。三组审计已用git show main:<file>复核相关产品blob一致。完整SP-207流程资料在主目录分支，main尚为占号页；不能丢弃较新授权，也不能整分支回灌旧产品/索引。主控合同规定按精确文件清单集成，并保留SP-209/发布历史和CLAUDE.md用户WIP。该经验已写入原流程及ops skill。

## 逐仓库观察

| 仓库 | HEAD（短） | 变化 | 完整 | 提交增量 | 最新非draft Release |
| --- | --- | --- | --- | ---: | --- |
| [tddworks/baguette](https://github.com/tddworks/baguette) | 14b39834fef6 | 有 | partial | 9 | v0.2.7 |
| [EvanBacon/serve-sim](https://github.com/EvanBacon/serve-sim) | c47a468b6003 | 有 | 是 | 3 | 无 |
| [lycorp-jp/sim-use](https://github.com/lycorp-jp/sim-use) | 81c3089331aa | 有 | 是 | 7 | v0.15.0 |
| [MobAI-App/simslim](https://github.com/MobAI-App/simslim) | 6518ba7eab11 | 无 | 是 | 0 | v0.12.2 |
| [Mastersam07/OpenDeviceHub](https://github.com/Mastersam07/OpenDeviceHub) | e50f07f1f448 | 无 | 是 | 0 | v0.2.0 |
| [JaviSoto/device-hub-ios](https://github.com/JaviSoto/device-hub-ios) | b5994ff72d8c | 有 | 是 | 2 | 无 |
| [heoblitz/Loupe](https://github.com/heoblitz/Loupe) | ff1351242e6d | 无 | 是 | 0 | v0.5.1 |
| [jfarcand/mirroir-mcp](https://github.com/jfarcand/mirroir-mcp) | 845a981163aa | 无 | 是 | 0 | v0.40.1 |
| [RockxyApp/Rockxy](https://github.com/RockxyApp/Rockxy) | de791b63e7f9 | 无 | 是 | 0 | v0.41.0 |
| [ProxymanApp/atlantis](https://github.com/ProxymanApp/atlantis) | cc059013de87 | 有 | 是 | 0 | 2.0.0 |
| [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL) | d88bbf0b3a5a | 无 | 是 | 0 | v1.98.12 |
| [getsentry/MobileBuildMCP](https://github.com/getsentry/MobileBuildMCP) | d13ff0c707b0 | 无 | 是 | 0 | v2.7.1 |
| [awizemann/harness](https://github.com/awizemann/harness) | 3f58c077ded1 | 无 | 是 | 0 | v0.8.4 |
| [dongxinsuperman/ai-phone](https://github.com/dongxinsuperman/ai-phone) | bd2781c17a9a | 有 | 是 | 18 | v0.8.0 |
| [karminski/eyes-on-my-phone](https://github.com/karminski/eyes-on-my-phone) | eef71926e613 | 无 | 是 | 0 | 无 |
| [RevylAI/revyl-cli](https://github.com/RevylAI/revyl-cli) | 86de7c9797f9 | 有 | 是 | 16 | v0.1.167 |
| [RevylAI/app-explorer](https://github.com/RevylAI/app-explorer) | b3edc443dbfb | 无 | 是 | 0 | 无 |
| [RevylAI/greenlight](https://github.com/RevylAI/greenlight) | fcb36e395bd4 | 无 | 是 | 0 | v0.2.0 |
| [RevylAI/mobile-devtools](https://github.com/RevylAI/mobile-devtools) | efc1dae5da08 | 无 | 是 | 0 | 无 |
| [RevylAI/mobile-pr-reviewer](https://github.com/RevylAI/mobile-pr-reviewer) | ba1250c72f56 | 无 | 是 | 0 | 无 |
| [RevylAI/visual-regression](https://github.com/RevylAI/visual-regression) | 2758e8a88f4e | 无 | 是 | 0 | 无 |
| [RevylAI/figma-design-checker](https://github.com/RevylAI/figma-design-checker) | 8b4e5cea045d | 无 | 是 | 0 | 无 |
| [RevylAI/CogniSim](https://github.com/RevylAI/CogniSim) | 3d8902e01198 | 无 | 是 | 0 | 无 |
| [hughkli/Lookin](https://github.com/hughkli/Lookin) | 95e30fdcc815 | 无 | 是 | 0 | 1.0.7 |
| [OSU-NLP-Group/UGround](https://github.com/OSU-NLP-Group/UGround) | 8974f95b0685 | 无 | 是 | 0 | 无 |
| [bytedance/UI-TARS](https://github.com/bytedance/UI-TARS) | 582f3a7ea5d2 | 无 | 是 | 0 | 无 |
| [OpenBMB/AgentCPM-GUI](https://github.com/OpenBMB/AgentCPM-GUI) | 2168ae21b1be | 无 | 是 | 0 | 无 |
| [X-PLUG/MobileAgent](https://github.com/X-PLUG/MobileAgent) | 11cea575561f | 无 | 是 | 0 | 无 |
| [njucckevin/SeeClick](https://github.com/njucckevin/SeeClick) | 0ef37ac4d7aa | 无 | 是 | 0 | 无 |
| [google-research/android_world](https://github.com/google-research/android_world) | 30583e22b9fb | 有 | 是 | 1 | 无 |
| [mobile-dev-inc/Maestro](https://github.com/mobile-dev-inc/Maestro) | 028c18b9ce74 | 有 | 是 | 7 | cli-2.11.0 |
| [linhay/SKProcessRunner](https://github.com/linhay/SKProcessRunner) | 24e036604b9e | 无 | 是 | 0 | 0.0.17 |
| [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) | d4a83fa45b9c | 无 | 是 | 0 | 1.0.11 |

## 不完整项与后续

- tddworks/baguette：partial source association: fixed official APK/certificate/identity bytes are retained, but corresponding APK build source/manifest provenance is not established; no binary behavior executed or asserted。保留旧点，下次补齐，不重复分派已登记机制。

## 证据与验证

[机器观察](20261017-observations.json)、[sim/runtime报告](20261017-sim-runtime.md)、[agent/Revyl报告](20261017-agents-revyl.md)、[研究报告](20261017-research.md)、[ai-phone补审](20261017-ai-phone-review.md)、[Revyl补审](20261017-revyl-review.md)保存来源、覆盖、许可和本地裁决。原始API、源码和逐文件SHA在`.build/reference-monitor/20261017/`，未作为第三方代码或设备验证声明。

本次仅追踪与规划文档，无产品修改；产品测试不适用。文档门禁结果在收口时补记，不以创建branch/worktree或检查点推进当作开发完成。


## 本轮门禁结果

`docs-linhay/scripts/verify.sh --ci-docs`、独立 `docs-linhay/scripts/check-docs.sh` 均通过（211 spaces）；`git diff --check`通过。33仓唯一性、31个SP-207成功点+1个SP-193委托成功点、1个旧点保留、补审revision/提交数绑定、通知/采用去重、无虚构thread及本地链接检查通过。本期产品候选为空，Swift/设备测试未执行；旧交付验证仅按原证据复核，不累计为本期新测试。经验已写回正式流程、ops skill及EXPERIENCE。

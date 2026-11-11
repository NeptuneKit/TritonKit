# 2026-11-11 参考项目日检、采用与保管复核

## 结论与边界

- 当前正式登记 **34仓（25参考+9研究候选）**：补入SP279已正式登记但漏在清单的Pinky，不是偶然链接/clone自动登记。官方HEAD、完整非draft Release分页与固定许可均已逐仓查询，**21完整/13 partial**；8仓许可仍缺，二进制来源及大增量语义未读范围保留。完整包括本轮无增量而复用历史审阅的仓库，不代表历史raw恢复或全部历史审计。
- 原33仓相对**已提交11月2日观察**有11仓变化；Pinky另对SP279固定研究基线209aa9e4有变化。不能称为一天新增，11月4～10日没有本轮可证实的完整日检。
- 两项已在main完成实现、独立只读复核与候选验证：[SP283](../../SP-283-homebrew-public-assets/README.md) tap写入前匿名公开资产校验；[SP284](../../SP-284-simulator-diagnostic-dependencies/README.md)只读服务依赖诊断。实现提交14574a7b；最终提交后门禁与登记见本页收口。既有18条合并均可达607410fb，不重开或重建旧采用。
- 实际产品评估固定main `607410fb3d44bfe02274c13822170c3015c63a99`；实现直接当前main串行。SP281 WIP参与现场编译/测试，但未由本任务改写或提交。新切片无新branch/worktree/用户聊天；当前主控保持开放。

## 证据保管故障与接管

[保管复核](./20261111-evidence-custody.json)：11月2日manifest列455份载荷当前**455缺失、0可验hash**，整个旧TritonKit-worktrees根当前不存在，原因unknown。有限路径搜索无替代副本，不声称全磁盘恢复。11月3日会话中曾有未提交观测/归档线索，当前不存在；已提交追踪文件最后仍是11月2日，不能声称成功点被提交后回退。本次不重新生成旧API响应或执行日志。

新证据归档在独立`../TritonKit-archives/reference-monitor/20261111/`，脱离worktree整体清理根。manifest登记实际文件size/hash，历史读取成功与当前可用性分离。Pinky旧clone当前也不存在，SP279的历史静态读取事实保留，当前副本不可用且原因未知。

`ictrl`已重读确认为当前聊天01a19a4a-50e2-7731-b8fa-880efb954eb5，保持同id/name/heartbeat/ACTIVE/每日北京时间10:00/created_at。prompt同步11月11日main串行、arm64-only、SwiftPM-only及34仓清单；没有新建重复定时任务或会话。新会话显式gpt-6.1-sol规则继续有效。

## 变化与采用裁决

- [Loupe固定增量](https://github.com/heoblitz/Loupe/compare/180c60584867500b93b43ca6c8b556995bf8be7b...1b6c7f0fa5f5ed2bd7885d404f85bcebd5ff0d93)：2提交/10路径/18全文已审。采用public稳定tag和匿名大小/SHA验证前置，覆盖实际tap缺口。MIT人工全文识别，API NOASSERTION保留；独立实现，不复制代码。
- [simslim固定增量](https://github.com/MobAI-App/simslim/compare/d594c230fe9ed5080189b0ce76afabda6104bae0...7e374b3839d49608a681d1f8b9ca0dd83d35189e)：3提交/14路径/26全文。仅采用mdm、app-clips、accessibility-assets诊断，managed171/slimmable168及ci/stock写集合不变；不采用全设备preboot watch。MIT许可固定全文已核验。
- [serve-sim](https://github.com/EvanBacon/serve-sim)：22提交/140路径/284安全文本已采齐，但26922行增量未全部语义审完，保留partial，不因文件齐全前移检查点。
- [mirroir](https://github.com/jfarcand/mirroir-mcp)：52提交/53parent边，仅4边/6树完整采集、352文本版本，其中14个head文件语义审读。HTTP鉴权/预算、SCK completion与foreground边界观察；本地裸connect是静态线索，挂起未复现，保持revise-first，不宣布adopt或制造成功复现。
- [Rockxy](https://github.com/RockxyApp/Rockxy)：271提交/333parent边/273树/517路径，468安全文本采集，白名单与语义未闭合。AGPL源码与DMG独立EULA分开；proxy/cache不能据标题直接采用。
- [Baguette](https://github.com/tddworks/baguette)：34提交/40parent边/88路径/365安全文本，dylib与历史来源缺口保留。可选native set-text精确同目标回读只列**待评估**：既有submission ok本身不是错误，需要先冻结opt-in兼容/secure/目标消失及不重发语义，未启动实现，不与SP281 receipt重复计入。
- [Revyl CLI](https://github.com/RevylAI/revyl-cli)：83提交/198路径/628安全文本，4pyc/许可404/历史hosted来源与完整语义缺口保留；云端与遥测不扩展本机范围。
- ai-phone、Maestro、MobileAgent、Mobile MCP已完成各自增量全文与实际main核对，均观察；pane布局、Cloud/PostHog、GUI-Owl格式/loop和原始层级/横屏提示不能据上游变更推定本地缺陷。
- [Pinky](https://github.com/DIYgod/pinky/compare/209aa9e4b2ff1fd81edec3c393a64b21b79162fb...3248613b11cb77b263f2a4282209ef9ab79254e7)：321提交/56个新增非draft release，4页commit完整，compare文件cap300不能当全清单；206棵树、0全文blob，仍partial且checkpoint=null。SP280/281已承接ActionContext，不据旧研究建议重建任务。

上游性能、内存与测试声明均未经本机运行验证；没有运行第三方代码、依赖安装、设备动作、签名/DDI、push/tag/release。

## 逐仓结果

| 仓库 | 固定 HEAD | 最新非draft Release | 覆盖与裁决 |
| --- | --- | --- | --- |
| [tddworks/baguette](https://github.com/tddworks/baguette/commit/593a1b4ae699e87bbab444d0d821e45a74b4bc79) | `593a1b4a` | [v0.2.14](https://github.com/tddworks/baguette/releases/tag/v0.2.14) | partial / partial_with_candidate |
| [EvanBacon/serve-sim](https://github.com/EvanBacon/serve-sim/commit/5f6dee52834351ae2d765dfda02e540248a9b663) | `5f6dee52` | 无 | partial / observe |
| [lycorp-jp/sim-use](https://github.com/lycorp-jp/sim-use/commit/c02295edfd2f442249b869096dda3dc7bfcd308d) | `c02295ed` | [v0.16.0](https://github.com/lycorp-jp/sim-use/releases/tag/v0.16.0) | 完整 / observe |
| [MobAI-App/simslim](https://github.com/MobAI-App/simslim/commit/7e374b3839d49608a681d1f8b9ca0dd83d35189e) | `7e374b38` | [v0.14.0](https://github.com/MobAI-App/simslim/releases/tag/v0.14.0) | 完整 / adopt |
| [Mastersam07/OpenDeviceHub](https://github.com/Mastersam07/OpenDeviceHub/commit/e50f07f1f4480cb14d57f192df7bf598ca26e708) | `e50f07f1` | [v0.2.0](https://github.com/Mastersam07/OpenDeviceHub/releases/tag/v0.2.0) | 完整 / observe |
| [JaviSoto/device-hub-ios](https://github.com/JaviSoto/device-hub-ios/commit/3779e12aa00c08bb34805fef8ffe375838cbe815) | `3779e12a` | 无 | 完整 / observe |
| [heoblitz/Loupe](https://github.com/heoblitz/Loupe/commit/1b6c7f0fa5f5ed2bd7885d404f85bcebd5ff0d93) | `1b6c7f0f` | [v0.6.0](https://github.com/heoblitz/Loupe/releases/tag/v0.6.0) | 完整 / adopt |
| [jfarcand/mirroir-mcp](https://github.com/jfarcand/mirroir-mcp/commit/5a3f93d86fdd40aad7d1a6267223146e110870dd) | `5a3f93d8` | [v0.45.0](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.45.0) | partial / revise-first |
| [RockxyApp/Rockxy](https://github.com/RockxyApp/Rockxy/commit/acbe8fb01f6669e40a9d781e1849d5f935dcac48) | `acbe8fb0` | [v0.42.0](https://github.com/RockxyApp/Rockxy/releases/tag/v0.42.0) | partial / review_pending |
| [ProxymanApp/atlantis](https://github.com/ProxymanApp/atlantis/commit/cc059013de8778072b4fea6453b45e964e4202fe) | `cc059013` | [2.0.0](https://github.com/ProxymanApp/atlantis/releases/tag/2.0.0) | 完整 / observe |
| [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL/commit/c1e4268859ba858d1579f7b846a56cb40641b7f6) | `c1e42688` | [v1.98.16](https://github.com/OpenMinis/iCTRL/releases/tag/v1.98.16) | 完整 / observe |
| [getsentry/MobileBuildMCP](https://github.com/getsentry/MobileBuildMCP/commit/2998ac77ebbca59544e88a27f34bfb830db9d924) | `2998ac77` | [v2.7.1](https://github.com/getsentry/MobileBuildMCP/releases/tag/v2.7.1) | 完整 / observe |
| [awizemann/harness](https://github.com/awizemann/harness/commit/3f58c077ded131cca71d75efb05c5d325f0ed18f) | `3f58c077` | [v0.8.4](https://github.com/awizemann/harness/releases/tag/v0.8.4) | 完整 / observe |
| [dongxinsuperman/ai-phone](https://github.com/dongxinsuperman/ai-phone/commit/a96cb091903922f4f002f48c38cdfb1146653f93) | `a96cb091` | [v0.8.0](https://github.com/dongxinsuperman/ai-phone/releases/tag/v0.8.0) | 完整 / observe |
| [karminski/eyes-on-my-phone](https://github.com/karminski/eyes-on-my-phone/commit/eef71926e613c3242643923bb21c92beab439990) | `eef71926` | 无 | partial / observe |
| [RevylAI/revyl-cli](https://github.com/RevylAI/revyl-cli/commit/dcf5f2ab9fdd181a3bbe770410f4ad19dc36fed9) | `dcf5f2ab` | [v0.1.234](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.234) | partial / partial_observe |
| [RevylAI/app-explorer](https://github.com/RevylAI/app-explorer/commit/b3edc443dbfbd8fe84b0fb0bc7c3190cb233c41e) | `b3edc443` | 无 | partial / observe |
| [RevylAI/greenlight](https://github.com/RevylAI/greenlight/commit/fcb36e395bd4ae20448f2535382baecba9396fd9) | `fcb36e39` | [v0.2.0](https://github.com/RevylAI/greenlight/releases/tag/v0.2.0) | 完整 / observe |
| [RevylAI/mobile-devtools](https://github.com/RevylAI/mobile-devtools/commit/efc1dae5da089ec08108a39f1ead39324c11b410) | `efc1dae5` | 无 | partial / observe |
| [RevylAI/mobile-pr-reviewer](https://github.com/RevylAI/mobile-pr-reviewer/commit/ba1250c72f56a08f3718aefc82dc911c1b3a2f23) | `ba1250c7` | 无 | partial / observe |
| [RevylAI/visual-regression](https://github.com/RevylAI/visual-regression/commit/2758e8a88f4efb3a251b675e0984c091bf8abeb8) | `2758e8a8` | 无 | partial / observe |
| [RevylAI/figma-design-checker](https://github.com/RevylAI/figma-design-checker/commit/8b4e5cea045dcff5c30aa723b923e514d2cdc07a) | `8b4e5cea` | 无 | partial / observe |
| [RevylAI/CogniSim](https://github.com/RevylAI/CogniSim/commit/3d8902e011981b93cb0ebfafba1794eab93b053e) | `3d8902e0` | 无 | 完整 / observe |
| [hughkli/Lookin](https://github.com/hughkli/Lookin/commit/95e30fdcc8151092678387c5262bce790a0d9530) | `95e30fdc` | [1.0.7](https://github.com/hughkli/Lookin/releases/tag/1.0.7) | 完整 / observe |
| [OSU-NLP-Group/UGround](https://github.com/OSU-NLP-Group/UGround/commit/8974f95b0685f139a6257f82d6b13895db3356cf) | `8974f95b` | 无 | 完整 / observe |
| [bytedance/UI-TARS](https://github.com/bytedance/UI-TARS/commit/582f3a7ea5d285ee8ed9e2e84048d1ab01453c49) | `582f3a7e` | 无 | 完整 / observe |
| [OpenBMB/AgentCPM-GUI](https://github.com/OpenBMB/AgentCPM-GUI/commit/2168ae21b1bed1cdb88736d422934825795a9fd7) | `2168ae21` | 无 | 完整 / observe |
| [X-PLUG/MobileAgent](https://github.com/X-PLUG/MobileAgent/commit/c4cd0a8f9ddedad24dd8a3daf3a56ca69343849f) | `c4cd0a8f` | 无 | 完整 / observe |
| [njucckevin/SeeClick](https://github.com/njucckevin/SeeClick/commit/0ef37ac4d7aaf37ba7b990e3e3c3ca77e1fb8f93) | `0ef37ac4` | 无 | 完整 / observe |
| [google-research/android_world](https://github.com/google-research/android_world/commit/55ddaf5edc6f6c25673aed343907d5b9dca66f84) | `55ddaf5e` | 无 | 完整 / observe |
| [mobile-dev-inc/Maestro](https://github.com/mobile-dev-inc/Maestro/commit/aaa248d7fd4ca4924444dc027af9c7a62a9be348) | `aaa248d7` | [cli-2.12.1](https://github.com/mobile-dev-inc/Maestro/releases/tag/cli-2.12.1) | 完整 / observe |
| [linhay/SKProcessRunner](https://github.com/linhay/SKProcessRunner/commit/24e036604b9e2b28e14c3f55e75a686be1a8bd8a) | `24e03660` | [0.0.17](https://github.com/linhay/SKProcessRunner/releases/tag/0.0.17) | partial / observe |
| [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp/commit/3b51952bcd83955f3a743f731f5a9beaebecdab7) | `3b51952b` | [1.0.16](https://github.com/mobile-next/mobile-mcp/releases/tag/1.0.16) | 完整 / observe |
| [DIYgod/pinky](https://github.com/DIYgod/pinky/commit/3248613b11cb77b263f2a4282209ef9ab79254e7) | `3248613b` | [v2026.1111.16](https://github.com/DIYgod/pinky/releases/tag/v2026.1111.16) | partial / registered_reference_initial_partial |

## 验证与收口

- SP283：13项离线test与发布workflow顺序契约通过。独立复核发现非法输入保留旧checksum，已补回归并修复；manifest大小与assets类型也已补齐。真实GitHub/安装未执行。
- SP284：真实行为red已保留；focused XCTest49/SwiftTesting12通过，完整CLI XCTest167/SwiftTesting1854（203 suites）通过；根包XCTest5、SwiftTesting130+313（不同target）通过；实际features JSON 28项中25managed/3diagnostic断言通过。
- 适用local（TRITON_VERIFY_XCODE=0）通过；只跑自有fake-HDC/fixture HTTP与离线构建，真实Xcode/Simulator跳过。
- 首轮docs发现并行文档登记导致SP283/284重复行，按需求归属合并为唯一行，未覆盖SP281事实；修复后ci-docs、独立check-docs与diff whitespace通过。
- 实现直接提交main `14574a7b26e2f69187d0ad21959cfcf3164f182d`，提交后完整CLI再次XCTest167/SwiftTesting1854通过；postcommit-local.log通过（真实Xcode跳过）。无实际git merge操作；采用登记的legacy local_merged表示已在main，integration_method明确direct_main_commit。
- 新切片无临时worktree/branch/执行聊天需要清理或归档；当前主控开放。日志与源码快照归档后逐文件hash；检查点仅对21完整仓独立推进（iCTRL只写SP193），13个partial旧点保留。

2026-11-11收口：新证据快照5197文件/400184798字节逐项回读hash通过；[检查点publication](./20261111-checkpoint-publication.json)三个独立文件均原子写入后回读一致。20条采用SHA全部可达main，13个partial原检查点保持，Pinky空点不冒充首次完整成功。最终ci-docs及独立check-docs、diff whitespace通过。SP283修复后的13test由独立审查再次通过，限定范围无新增阻塞。历史455缺失继续保留unknown故障；新补充日志与正式资料快照另列closeout evidence，不修改冻结source manifest。

# 2026-10-26 参考项目日检与采用评估

33仓官方逐仓查询：22完整/11 partial、2仓相对昨日确认变化、0仓未知。实际main与原目录为`24e7d0f21017c8ca7104b6f8e3912fc2c44be892`，相对10月25日产品源码未变；开工47份跟踪文档WIP保持。

## 变化与采用判断

- [MobAI-App/simslim `2c68da93700a`](https://github.com/MobAI-App/simslim/commit/2c68da93700aa1a1c45ce31a7ea9f7cac2174ddc)：SP-221/222: explicit launchd transient print-disabled read currently fails once; bounded same-command read retry with real nonZeroExit path, no mutation/timeout/cancel replay; model-locked real execution/controller threads created, development not yet accepted. Release v0.12.2；完整。
- [RevylAI/revyl-cli `ecbe45690fe4`](https://github.com/RevylAI/revyl-cli/commit/ecbe45690fe4605acf7faa62dac7afcccd3690a9)：托管step_status只读轮询1s上限/15s瞬时失败容忍/Retry-After，billing reason优先、allowlistedLinux托管computer说明与版本变更；本地无对应托管step API或billing产品，未证实具体本地缺口；不复制自动重放策略。 Release v0.1.188；partial。

逐仓固定来源/Release notes/源码覆盖与本地评估见[Simulator/runtime](./20261026-sim-runtime.md)、[agents/Revyl](./20261026-agents-revyl.md)、[研究组](./20261026-research.md)。本轮采纳simslim明确launchd暂态只读重试，建立SP-221实现/SP-222有限主控及两个显式gpt-6.1-sol真实会话；仅同目标print-disabled读取，不重放mutation、timeout或cancel。固定来源/许可/本地缺口/BDD见SP-221；旧13条采用已合main。本批实现、验证、合并与清理分别记录，不用已分派冒充已交付。

## 完整性、产品与运行边界

11个既有许可/源码缺口按实际逐仓结果保留：Baguette二进制来源、sim-use CHANGELOG与device-hub-ios protocol历史patch、Revyl许可及generated/pyc历史语义、SKProcessRunner许可404。当前查询失败也必须保留旧checkpoint并记录unknown，不能报告无变化或恢复。详见[未完成记录](./20261026-read-failures.json)与[观察记录](./20261026-observations.json)。

SP-192五机制、SP-196/200及SP-214/218/219已交付内容先行去重；实际main24e7d0f2已包含c0ce0cc2真实displays修复、v0.2.33及SP-218/219本机Xcode27.1/iOS27.0真实HID/拒绝恢复/Resize视频验收。Resize AX/HID仍unsupported、其他工具链/用户项目不外推。本轮仅核对已有验收证据，不再次操作设备或发布。

旧13条采用均为local_merged，原合并SHA仍是main祖先；新SP-221/222处于独立开发/主控审查，执行与主控真实thread/branch/worktree见20261026-dispatch.json。通过验收后继续必要本地提交、合main与合后门禁，不逐项重问。为合并前main干净，既有本聊天跟踪资料会先独立本地归档提交，与产品候选分开，无remote写入授权。

取证仅官方API与经用途/文本白名单的源码，未请求二进制、identity、密钥或证书内容。未执行第三方代码、安装依赖、真实设备/Simulator/HDC、签名/DDI或push/tag/release；读取评估阶段无产品diff；SP-221产品测试与合并证据另归SP-221/222；上游性能/测试自述不作本地验收。

报告/分组摘要和观察记录先保存，再按完整仓原子更新检查点；iCTRL只维护SP-193独立成功点。partial逐对象保留。文档门禁与hash/旧WIP/主线祖先检查见当日memory；原始证据在`.build/reference-monitor/20261026/`。日检期间跟踪资料未提交；为本批实际main合并所需的独立本地归档提交后续记入SP-222，不混入产品候选。

经验检查沿用固定来源/独立检查点/故障去重与运行边界规则；无新经验不新增重复治理条目。只有有价值更新或新的故障/恢复才通知，不因检查执行本身重复通知。

## 逐仓状态

|仓库|HEAD|Release|相对昨日|完整性|裁决|
|---|---|---|---|---|---|
| `tddworks/baguette` | `458044cceadd` | v0.2.10 | 未变 | partial | observe |
| `EvanBacon/serve-sim` | `0193e65c481f` | — | 未变 | 完整 | observe |
| `lycorp-jp/sim-use` | `c02295edfd2f` | v0.16.0 | 未变 | partial | observe |
| `MobAI-App/simslim` | `2c68da93700a` | v0.12.2 | 变化 | 完整 | adopt |
| `Mastersam07/OpenDeviceHub` | `e50f07f1f448` | v0.2.0 | 未变 | 完整 | observe |
| `JaviSoto/device-hub-ios` | `3779e12aa00c` | — | 未变 | partial | observe |
| `heoblitz/Loupe` | `ff1351242e6d` | v0.5.1 | 未变 | 完整 | observe |
| `jfarcand/mirroir-mcp` | `502c5e466da4` | v0.40.1 | 未变 | 完整 | observe |
| `RockxyApp/Rockxy` | `de791b63e7f9` | v0.41.0 | 未变 | 完整 | observe |
| `ProxymanApp/atlantis` | `cc059013de87` | 2.0.0 | 未变 | 完整 | observe |
| `OpenMinis/iCTRL` | `874f528759b1` | v1.98.12 | 未变 | 完整 | observe |
| `getsentry/MobileBuildMCP` | `2998ac77ebbc` | v2.7.1 | 未变 | 完整 | no_new_adoption |
| `awizemann/harness` | `3f58c077ded1` | v0.8.4 | 未变 | 完整 | no_new_adoption |
| `dongxinsuperman/ai-phone` | `d339057bc64a` | v0.8.0 | 未变 | 完整 | no_new_adoption |
| `karminski/eyes-on-my-phone` | `eef71926e613` | — | 未变 | partial | no_new_adoption |
| `RevylAI/revyl-cli` | `ecbe45690fe4` | v0.1.188 | 变化 | partial | no_new_adoption |
| `RevylAI/app-explorer` | `b3edc443dbfb` | — | 未变 | partial | no_new_adoption |
| `RevylAI/greenlight` | `fcb36e395bd4` | v0.2.0 | 未变 | 完整 | no_new_adoption |
| `RevylAI/mobile-devtools` | `efc1dae5da08` | — | 未变 | partial | no_new_adoption |
| `RevylAI/mobile-pr-reviewer` | `ba1250c72f56` | — | 未变 | partial | no_new_adoption |
| `RevylAI/visual-regression` | `2758e8a88f4e` | — | 未变 | partial | no_new_adoption |
| `RevylAI/figma-design-checker` | `8b4e5cea045d` | — | 未变 | partial | no_new_adoption |
| `RevylAI/CogniSim` | `3d8902e01198` | — | 未变 | 完整 | no_new_adoption |
| `hughkli/Lookin` | `95e30fdcc815` | 1.0.7 | 未变 | 完整 | observe |
| `OSU-NLP-Group/UGround` | `8974f95b0685` | — | 未变 | 完整 | observe |
| `bytedance/UI-TARS` | `582f3a7ea5d2` | — | 未变 | 完整 | observe |
| `OpenBMB/AgentCPM-GUI` | `2168ae21b1be` | — | 未变 | 完整 | observe |
| `X-PLUG/MobileAgent` | `11cea575561f` | — | 未变 | 完整 | observe |
| `njucckevin/SeeClick` | `0ef37ac4d7aa` | — | 未变 | 完整 | observe |
| `google-research/android_world` | `55ddaf5edc6f` | — | 未变 | 完整 | observe |
| `mobile-dev-inc/Maestro` | `da0f0f2b7ad3` | cli-2.11.0 | 未变 | 完整 | observe |
| `linhay/SKProcessRunner` | `24e036604b9e` | 0.0.17 | 未变 | partial | observe |
| `mobile-next/mobile-mcp` | `294f403f2fe9` | 1.0.13 | 未变 | 完整 | observe |

## 本日采用最终结果（接替上方分派时快照）

SP-221候选eb9539f4经SP-222独立验收（focused37；完整CLI XCTest91/SwiftTesting1515、153suite、3skip）合本地main a0eebff0。合后完整CLI/root/local/docs门禁通过，真实恢复未验证。原跟踪资料已独立必要本地归档，不混产品；控制证据精确吸收f3d06523，等树历史merge6271d24e保留提交，40份ignored/验收证据归档后两个worktree/branch普通清理。状态local_merged并已清理，未push/tag/release。上方“开发中/无产品测试”等只代表读取评估时快照，以SP-222 main-merge最终记录为准。

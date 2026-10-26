# 2026-10-25 参考项目日检与采用评估

33仓官方逐仓查询：22完整/11 partial、3仓相对昨日确认变化、0仓未知。实际main与原目录为`24e7d0f21017c8ca7104b6f8e3912fc2c44be892`，相对10月24日产品源码未变；开工38份跟踪文档WIP保持。

## 变化与采用判断

- [RevylAI/revyl-cli `4238272acc9d`](https://github.com/RevylAI/revyl-cli/commit/4238272acc9d4fc020f92645e29cb9acc4df967c)：仅托管Web swipe方向澄清与原生HTML select/date下拉in-page picker说明；无本机移动端实现变更，不引入Web业务控制面；原许可/生成来源缺口保留。 最新Release v0.1.185→v0.1.188仅安装/分发通用body，无新增本机功能契约。 Release v0.1.188；partial。
- [mobile-dev-inc/Maestro `da0f0f2b7ad3`](https://github.com/mobile-dev-inc/Maestro/commit/da0f0f2b7ad32fc6f9b0b66cd3a36424892dd3e4)：1提交/10文件：Cloud upload新增low/normal/high队列优先级，CLI枚举校验，MCP显式null按未设置处理，重试透传priority；附wire/retry/CLI/MCP测试。当前Triton无托管上传队列或run_on_cloud工具，CLI/HTTP与本机模拟器范围不对应，observe；不将通用null处理制造成本地缺陷。昨日UTF-8目录机制无新变化，不重复采用。 Release cli-2.11.0；完整。
- [mobile-next/mobile-mcp `294f403f2fe9`](https://github.com/mobile-next/mobile-mcp/commit/294f403f2fe94ae86fc086181ebc1c1ec5b5c990)：3提交/6文件：MCP server/express依赖版本及锁文件更新，1.0.13 changelog，三语言README加入Mobilewright转CI推广示例。Triton CLI是Swift/ArgumentParser+Hummingbird，无上述MCP依赖及get_more_tools入口；record/plan inspect/replay已有既定契约，Mobilewright/托管设备不属于新增本地缺口。SP-212前台身份与shell文本机制已发布，observe。 1.0.13提及get_more_tools描述收窄，但本次compare无工具实现文件变化；本地CLI schema/capabilities按显式命令提供发现契约，不存在模型自动选择该MCP工具的同类路由，不能将描述门控当作本地缺陷。 Release 1.0.13；完整。

逐仓固定来源/Release notes/源码覆盖与本地评估见[Simulator/runtime](./20261025-sim-runtime.md)、[agents/Revyl](./20261025-agents-revyl.md)、[研究组](./20261025-research.md)。本轮没有已证明且尚未覆盖的本地采用候选，不新建space/branch/thread，不为验证模型创建会话。既有采用任务保持完成，非动作范围不能从上游实现推导授权。

## 完整性、产品与运行边界

11个既有许可/源码缺口按实际逐仓结果保留：Baguette二进制来源、sim-use CHANGELOG与device-hub-ios protocol历史patch、Revyl许可及generated/pyc历史语义、SKProcessRunner许可404。当前查询失败也必须保留旧checkpoint并记录unknown，不能报告无变化或恢复。详见[未完成记录](./20261025-read-failures.json)与[观察记录](./20261025-observations.json)。

SP-192五机制、SP-196/200及SP-214/218/219已交付内容先行去重；实际main24e7d0f2已包含c0ce0cc2真实displays修复、v0.2.33及SP-218/219本机Xcode27.1/iOS27.0真实HID/拒绝恢复/Resize视频验收。Resize AX/HID仍unsupported、其他工具链/用户项目不外推。本轮仅核对已有验收证据，不再次操作设备或发布。

13条采用登记均为local_merged，所有合并SHA仍是main祖先，没有未合并候选；adoption-state原样保持。新采用如成立仍依照独立开发、主控验证与合main闭环，不逐项重问本地合并授权。

取证仅官方API与经用途/文本白名单的源码，未请求二进制、identity、密钥或证书内容。未执行第三方代码、安装依赖、真实设备/Simulator/HDC、签名/DDI或push/tag/release；无产品diff，不重跑产品测试；上游性能/测试自述不作本地验收。

报告/分组摘要和观察记录先保存，再按完整仓原子更新检查点；iCTRL只维护SP-193独立成功点。partial逐对象保留。文档门禁与hash/旧WIP/主线祖先检查见当日memory；原始证据在`.build/reference-monitor/20261025/`。跟踪资料保持未提交。

经验检查沿用固定来源/独立检查点/故障去重与运行边界规则；无新经验不新增重复治理条目。只有有价值更新或新的故障/恢复才通知，不因检查执行本身重复通知。

## 逐仓状态

|仓库|HEAD|Release|相对昨日|完整性|裁决|
|---|---|---|---|---|---|
| `tddworks/baguette` | `458044cceadd` | v0.2.10 | 未变 | partial | observe |
| `EvanBacon/serve-sim` | `0193e65c481f` | — | 未变 | 完整 | observe |
| `lycorp-jp/sim-use` | `c02295edfd2f` | v0.16.0 | 未变 | partial | observe |
| `MobAI-App/simslim` | `6518ba7eab11` | v0.12.2 | 未变 | 完整 | observe |
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
| `RevylAI/revyl-cli` | `4238272acc9d` | v0.1.188 | 变化 | partial | no_new_adoption |
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
| `mobile-dev-inc/Maestro` | `da0f0f2b7ad3` | cli-2.11.0 | 变化 | 完整 | observe |
| `linhay/SKProcessRunner` | `24e036604b9e` | 0.0.17 | 未变 | partial | observe |
| `mobile-next/mobile-mcp` | `294f403f2fe9` | 1.0.13 | 变化 | 完整 | observe |

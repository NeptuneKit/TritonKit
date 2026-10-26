# 2026-10-24 参考更新与采用评估

33仓官方默认分支HEAD、全部非draft Release分页（含prerelease）、固定HEAD许可证全文/hash查询：**22完整/11 partial**，相对昨日确认5仓新变化，0仓未知。当前工作区与实际main均为`24e7d0f21017c8ca7104b6f8e3912fc2c44be892`，保留28份此前追踪文档差异。

## 新变化与裁决

- [EvanBacon/serve-sim `0193e65c481f`](https://github.com/EvanBacon/serve-sim/commit/0193e65c481fc9b64a62427f32fcf143dbc3d2c0)：新增原生CFR录制、限时/持有/流式落盘及React Native Metro reload/浏览器held-key恢复；Triton现有sim record为simctl外部录制，已做样本时长与Resizable目标绑定，无同一自有编码队列或浏览器键盘/Metro入口；无实际缺口，不引入Web写控制面。 最新非draft Release为 无；完整。
- [jfarcand/mirroir-mcp `502c5e466da4`](https://github.com/jfarcand/mirroir-mcp/commit/502c5e466da4d82df8f65ffa9a598c01e152b56b)：新增游戏技能/AI agent路由、OCR优先轮询、settle/blank双重确认、截图crop/scale与token统计。当前Triton VLM为显式artifact grounding且已有坐标契约/远端opt-in；不自动运行视觉探索，不能用近均匀帧静默抑制用户明确请求。观察性能机制，无本地失败或现有需求证据。 最新非draft Release为 v0.40.1；完整。
- [RevylAI/revyl-cli `8fe715c3c9ad`](https://github.com/RevylAI/revyl-cli/commit/8fe715c3c9adaff2d870b7e45f518637e53a150e)：新增Devin云proof与托管目录不属于本机产品范围；iOS fold仅公开schema/托管API，无本地SimulatorKit transport实现证据，不据此认定可采用缺口。许可与既有来源缺口未闭合。 最新非draft Release为 v0.1.185；partial。
- [google-research/android_world `55ddaf5edc6f`](https://github.com/google-research/android_world/commit/55ddaf5edc6f6c25673aed343907d5b9dca66f84)：2提交/3安全文本文件完整增量：typed InstallApk并检查AdbResponse.OK，失败抛异常。Triton使用adb进程契约，runHostCommand拒绝非零退出，TKAndroidInstallParser要求exit0及独立Success行；没有相同的忽略AdbResponse状态路径。未证明实际adb会以exit0报告安装失败，不据此制造缺陷或BDD。 最新非draft Release为 无；完整。
- [mobile-dev-inc/Maestro `436309bdbd0a`](https://github.com/mobile-dev-inc/Maestro/commit/436309bdbd0aca29450a3f0c7fcf8bbe9c3ab027)：1提交/2安全文本文件完整增量：flow artifact目录按UTF-8边界截断并追加8位SHA256，预留shard/碰撞后缀。Triton evidence的case仅写manifest，output由用户明确指定，内部artifact使用固定文件名；不存在由case自动生成flow目录的同类路径。observe，昨日锁/stream机制已评估不重复排期。 最新非draft Release为 cli-2.11.0；完整。

完整固定来源、提交/文件/分页覆盖与本地机制差异见[Simulator/runtime](./20261024-sim-runtime.md)、[agents/Revyl](./20261024-agents-revyl.md)、[研究组](./20261024-research.md)。本轮无新增可执行采用项；没有为通用安全习惯或托管产品枚举生成推测BDD。上游测试/时延数字如未在本地证明，均非Triton实测。

## 本地主线和既有采用

SP-192五项机制（别名新鲜度、采集预算、视觉settle、OCR candidateOnly、UI健康/unknown）与SP-196/200以及后续切片先行去重。今日main较昨日新增`c0ce0cc2`真实displays字段/命令绑定修复、replay UUID绑定和范围收口；`v0.2.33`已由独立授权会话发布，证据以SP-218发布记录为准，本监控没有发版。

SP-218原生HID点击/滑动、Hub占用拒绝与恢复，SP-219普通→Resize→普通三段视频在Xcode27.1/iOS27.0专用Simulator已有真实验收。SP-214旧displayTopology自拟fixture结论已被真实displays修复接替，不能继续当作运行未验证待办；Resize AX/HID仍unsupported，不因录制通过扩展为可执行。其他工具链与用户项目不外推。

采用登记13条local merge均为实际main祖先，没有待合并实现候选；同步SP-214/218/219/220的后续验证/发布事实，保留原实现/合并SHA、thread null、历史分派失败和清理证据。没有新space/branch/thread，不探测模型。新采用若成立仍按独立实现→主控验证→本地main合并闭环。

## 验证、检查点和安全边界

未运行第三方代码、依赖安装、设备、签名/DDI或远端写入；本轮无产品diff，未重跑产品测试。上述真实验收属于其他已授权会话，本次仅静态核对证据。取证使用文本用途白名单，二进制和身份/密钥/证书内容不请求。

先保存本报告、分组报告、[逐仓观察](./20261024-observations.json)与[未完成记录](./20261024-read-failures.json)，再按仓原子更新完整检查点。未完成仓旧checkpoint逐对象不变；iCTRL无变化、独立SP-193成功，不复制其checkpoint。网络恢复和源码/许可恢复分别表达，未将昨日故障当作今日仍发生。

文档门禁和逐仓hash/检查点/主线祖先自检结果见当日memory；原始证据在`.build/reference-monitor/20261024/`。跟踪资料保持未提交、未push/tag/release。经验复盘复用既有规则，当前运行事实更新原权威资料，不额外新增重复规则。

## 逐仓结果

|仓库|HEAD|Release|相对昨日|完整性|裁决|
|---|---|---|---|---|---|
| `tddworks/baguette` | `458044cceadd` | v0.2.10 | 未变 | partial | observe |
| `EvanBacon/serve-sim` | `0193e65c481f` | — | 变化 | 完整 | observe |
| `lycorp-jp/sim-use` | `c02295edfd2f` | v0.16.0 | 未变 | partial | observe |
| `MobAI-App/simslim` | `6518ba7eab11` | v0.12.2 | 未变 | 完整 | observe |
| `Mastersam07/OpenDeviceHub` | `e50f07f1f448` | v0.2.0 | 未变 | 完整 | observe |
| `JaviSoto/device-hub-ios` | `3779e12aa00c` | — | 未变 | partial | observe |
| `heoblitz/Loupe` | `ff1351242e6d` | v0.5.1 | 未变 | 完整 | observe |
| `jfarcand/mirroir-mcp` | `502c5e466da4` | v0.40.1 | 变化 | 完整 | observe |
| `RockxyApp/Rockxy` | `de791b63e7f9` | v0.41.0 | 未变 | 完整 | observe |
| `ProxymanApp/atlantis` | `cc059013de87` | 2.0.0 | 未变 | 完整 | observe |
| `OpenMinis/iCTRL` | `874f528759b1` | v1.98.12 | 未变 | 完整 | observe |
| `getsentry/MobileBuildMCP` | `2998ac77ebbc` | v2.7.1 | 未变 | 完整 | no_new_adoption |
| `awizemann/harness` | `3f58c077ded1` | v0.8.4 | 未变 | 完整 | no_new_adoption |
| `dongxinsuperman/ai-phone` | `d339057bc64a` | v0.8.0 | 未变 | 完整 | no_new_adoption |
| `karminski/eyes-on-my-phone` | `eef71926e613` | — | 未变 | partial | no_new_adoption |
| `RevylAI/revyl-cli` | `8fe715c3c9ad` | v0.1.185 | 变化 | partial | no_new_adoption |
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
| `google-research/android_world` | `55ddaf5edc6f` | — | 变化 | 完整 | observe |
| `mobile-dev-inc/Maestro` | `436309bdbd0a` | cli-2.11.0 | 变化 | 完整 | observe |
| `linhay/SKProcessRunner` | `24e036604b9e` | 0.0.17 | 未变 | partial | observe |
| `mobile-next/mobile-mcp` | `c659f8ee3487` | 1.0.12 | 未变 | 完整 | observe |

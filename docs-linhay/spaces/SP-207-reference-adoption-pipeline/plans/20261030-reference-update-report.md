# 2026-10-30 接管与参考项目补查

接管原聊天后补查33仓：24完整 / 9 partial，5仓相对10月28日变化，0仓变化未知。实际main `30185dc277ed305483aa789cb2d8c8b06fa21fe4`；16条采用合并提交均为该main祖先。10月29日仅整理资料，未倒填日检成功。

## 更新与采用评估

- [tddworks/baguette](https://github.com/tddworks/baguette/commit/94b78d3603acf661e1f593aff7891c3bd7a86c44)：本次唯一提交仅将既有铰链修复从Unreleased提升为v0.2.12并更新比较链接，源代码树无变化；既有机制已审阅，本地未发现新增采用缺口。 [固定来源审阅](20261030-tddworks-baguette-review.md)。
- [jfarcand/mirroir-mcp](https://github.com/jfarcand/mirroir-mcp/commit/20223a9a7f3707513c9bbaf740773ead1f181ce1)：3提交/83文本路径主要修复iPhone Mirroring CSA键盘、settings合并、compiled replay诚实性和SCK/Rust执行边界；对照typed replay、workspace配置及SP192/196/200/223既有交付，无可复现新增本机缺口。 [固定来源审阅](20261030-jfarcand-mirroir-mcp-review.md)。
- [RevylAI/revyl-cli](https://github.com/RevylAI/revyl-cli/commit/b6194f927fc3550fbd8144c56db313787e468b29)：19提交/50路径；45允许文本已按固定树与逐提交blob审阅。云computer默认路由/base64传输/edge分类、托管iOS fold、Web录制publication DTO与PR触发glob未形成新的可采用本机机制；既有SP192/196/200及iOS Duo unsupported边界保持。 [固定来源审阅](20261030-RevylAI-revyl-cli-review.md)。
- [X-PLUG/MobileAgent](https://github.com/X-PLUG/MobileAgent/commit/81fa28b564ef7a695521500bc15a0e1324b2b394)：MiniMax接入属于上游推理provider扩展；PNG data URI已有实现，索引聚焦修复不对应本地focused-only契约的新缺陷。 [固定来源审阅](20261030-X-PLUG-MobileAgent-review.md)。
- [mobile-dev-inc/Maestro](https://github.com/mobile-dev-inc/Maestro/commit/3fc4ef3fc408bc70ea9baf0bac0ff3e4b565710c)：本轮仅Java依赖版本修复；TritonKit未使用OkHttp/PostHog，无对应依赖升级或新产品机制。 [固定来源审阅](20261030-mobile-dev-inc-Maestro-review.md)。

## 接管与边界

每日任务ictrl已由原聊天01a139bf-ab78-7783-b37a-ed336be2ef38迁移至当前聊天01a18a91-f44e-7fd0-8e4b-c891b44377e0，仍为ACTIVE、北京时间每天10:00，名称和完整prompt保持。工具更新成功后重新读取已保存配置确认；没有创建重复任务。原聊天保留历史，不继续承载定时任务。

本轮只影响参考追踪、自动任务与文档；没有修改产品、执行设备、安装依赖、运行第三方代码或push/tag/release。主目录SP-244及其他工作区由原任务管理，不因接管参考追踪而清理。16条已交付采用不重开；本轮未确认需新增开发切片。上游测试/性能声明未在本地运行。

iCTRL的HEAD、v1.98.16、Apache-2.0全文hash未变；SP-193独立成功时间在摘要保存后推进，SP-207不复制其成功点。既有许可/二进制/hosted来源缺口保持，不用本轮文本审阅覆盖历史partial。完整树和提交分页/文本覆盖见各审阅文件，原始证据及哈希见本日报manifest。

## 仓库结果

| 仓库 | HEAD | Release | 完整性 |
| --- | --- | --- | --- |
| tddworks/baguette | `94b78d3603ac` | v0.2.12 | partial |
| EvanBacon/serve-sim | `0193e65c481f` | — | 完整 |
| lycorp-jp/sim-use | `c02295edfd2f` | v0.16.0 | 完整 |
| MobAI-App/simslim | `d594c230fe9e` | v0.13.0 | 完整 |
| Mastersam07/OpenDeviceHub | `e50f07f1f448` | v0.2.0 | 完整 |
| JaviSoto/device-hub-ios | `3779e12aa00c` | — | 完整 |
| heoblitz/Loupe | `ff1351242e6d` | v0.5.1 | 完整 |
| jfarcand/mirroir-mcp | `20223a9a7f37` | runner-v0.4.0 | 完整 |
| RockxyApp/Rockxy | `de791b63e7f9` | v0.41.0 | 完整 |
| ProxymanApp/atlantis | `cc059013de87` | 2.0.0 | 完整 |
| OpenMinis/iCTRL | `c1e4268859ba` | v1.98.16 | 完整 |
| getsentry/MobileBuildMCP | `2998ac77ebbc` | v2.7.1 | 完整 |
| awizemann/harness | `3f58c077ded1` | v0.8.4 | 完整 |
| dongxinsuperman/ai-phone | `d339057bc64a` | v0.8.0 | 完整 |
| karminski/eyes-on-my-phone | `eef71926e613` | — | partial |
| RevylAI/revyl-cli | `b6194f927fc3` | v0.1.203 | partial |
| RevylAI/app-explorer | `b3edc443dbfb` | — | partial |
| RevylAI/greenlight | `fcb36e395bd4` | v0.2.0 | 完整 |
| RevylAI/mobile-devtools | `efc1dae5da08` | — | partial |
| RevylAI/mobile-pr-reviewer | `ba1250c72f56` | — | partial |
| RevylAI/visual-regression | `2758e8a88f4e` | — | partial |
| RevylAI/figma-design-checker | `8b4e5cea045d` | — | partial |
| RevylAI/CogniSim | `3d8902e01198` | — | 完整 |
| hughkli/Lookin | `95e30fdcc815` | 1.0.7 | 完整 |
| OSU-NLP-Group/UGround | `8974f95b0685` | — | 完整 |
| bytedance/UI-TARS | `582f3a7ea5d2` | — | 完整 |
| OpenBMB/AgentCPM-GUI | `2168ae21b1be` | — | 完整 |
| X-PLUG/MobileAgent | `81fa28b564ef` | — | 完整 |
| njucckevin/SeeClick | `0ef37ac4d7aa` | — | 完整 |
| google-research/android_world | `55ddaf5edc6f` | — | 完整 |
| mobile-dev-inc/Maestro | `3fc4ef3fc408` | cli-2.12.0 | 完整 |
| linhay/SKProcessRunner | `24e036604b9e` | 0.0.17 | partial |
| mobile-next/mobile-mcp | `6c945971b6b1` | 1.0.14 | 完整 |

## 收口验证

`verify.sh --ci-docs`、独立`check-docs.sh`（244 spaces）、`git diff --check`通过。33仓唯一性、9个partial成功点逐字段不变、SP207的iCTRL委托记录不变、16个采用合并祖先、716份证据size/hash均复核；main与产品WIP hash未变。正式摘要先保存，再原子推进成功点。

首次全WIP hash断言发现3个本任务未写入的文档正在变化：SP244 README、SP244 GitHub研究计划、public skill platform-commands；保留该并行变化，不覆盖、不宣称全部WIP字节不变。其余25份受保护文件hash相同，5个共享索引/memory文件仅追加或精确更新本次资料。未知修改来源不推断为产品缺陷。门禁按最终文档候选复跑；日志与不变量结果位于`.build/reference-monitor/20261030/validation/`。

仅配置与资料变更，Swift/CLI产品测试、设备与发布验证不适用且未执行。经验已沉淀到[正式采用流程](../../../dev/reference-project-adoption-workflow.md)及EXPERIENCE；本次未Git提交、推送或发布。

> 2026-10-31后续核对：本文所引.build原始证据当前已缺失，原因未知；当时hash验证为历史事实，当前可复核性以[保管记录](20261031-evidence-custody.md)为准。

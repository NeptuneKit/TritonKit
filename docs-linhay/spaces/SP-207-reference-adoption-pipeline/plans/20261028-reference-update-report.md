# 2026-10-28 参考项目检查与采用评估

> 历史采样边界：本文的 main a0d187ac、worktree数量、版本和“不push/tag/release”等描述均指2026-10-28日检当时。2026-10-29仅整理这批资料并对齐v0.2.36后的main dba41b6e，不重新查询上游；当前发布状态见SP-243，整合记录见[10月29日日志](../../../memory/2026-10-29.md)。

33仓官方metadata、默认分支HEAD、全部非draft Release分页及固定HEAD许可证查询完成：24完整 / 9 partial，3仓有变化，0仓变化未知。实际main `a0d187ace03d6e56b79b50a7a601c91b359b7955`；16条采用合并SHA均为main祖先，真实会话已按已有关闭记录归档，未重开。仅根main worktree，无待合并开发候选。

## 更新与判断

- [tddworks/baguette](https://github.com/tddworks/baguette/commit/201de19842d4d6964f1e37989d69fcda24d5eefc)：本日仅iPhone Duo铰链3D呈现平滑、串行sweep、最长60秒与精确错误；Triton iOS折叠明确unsupported，Android折叠直接读回角度，native HID已有有限值/10秒上限，无同源整数溢出路径；不新增3D写控制面。 见[固定来源评估](20261028-tddworks-baguette-review.md)。
- [jfarcand/mirroir-mcp](https://github.com/jfarcand/mirroir-mcp/commit/317dc15fa21b63cf3e6b997784bd1c4ce6607392)：SKILL.md/compiled双源重放修复仅作用于上游MCP技能链；Triton typed .tritonplan已有空计划拒绝、变量替换、secure和失败边界，无可复现新gap；Rust依赖与网站不适用。 见[固定来源评估](20261028-jfarcand-mirroir-mcp-review.md)。
- [RevylAI/revyl-cli](https://github.com/RevylAI/revyl-cli/commit/8ecfb9f8b1591ac35ad3a3576e9d1df016dd2c33)：6提交/31路径；27文本新增import-tests指导skill、组织认证目录覆盖、cloud computer实验可见与Web并发文案。Triton既有确定性testrec导入不是第三方suite转换器；上游goal-level/cloud模型不可直接替代；SP192/196/200已交付去重，无本轮可直接采用的本机缺口。 见[固定来源评估](20261028-RevylAI-revyl-cli-review.md)。

mirroir分别发布[v0.41.0](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.41.0)与[runner-v0.4.0](https://github.com/jfarcand/mirroir-mcp/releases/tag/runner-v0.4.0)，后者为按发布时间选出的最新非draft Release；两个产品标签不混为一个版本。Revyl最新公开[v0.1.195](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.195)，HEAD版本0.1.196尚不能称已发布。Baguette仍v0.2.11，本日两提交为未发布修复。

## 完整性与交付边界

iCTRL HEAD c1e4268859ba、v1.98.16、Apache-2.0全文hash未变，仅独立SP-193成功检查时间推进。其他29仓相对昨日观察未变。9个既有partial许可/二进制/hosted来源缺口未恢复；Revyl今日4个pyc不采集，完整文本增量不等于仓库完整，旧成功点保持。无新增网络/权限故障，不重复通知旧故障。

本轮未确认新可纳入缺口，未创建执行/主控聊天或产品分支；两个指定gpt-6.1-sol只读审阅subagent完成隔离评估，主控复核分页/patch/许可及main对照后保存评估材料。SP-192/196/200及后续16条采用不重复派发。既有产品已随SP-227的v0.2.34发布；本轮不push/tag/release、安装依赖、执行上游、操作设备/签名/DDI。上游性能与测试声明未经本地验证。经验检查沿用现有规则，无新增治理规则。

| 仓库 | HEAD | Release | 完整性 |
| --- | --- | --- | --- |
| tddworks/baguette | `201de19842d4` | v0.2.11 | partial |
| EvanBacon/serve-sim | `0193e65c481f` | — | 完整 |
| lycorp-jp/sim-use | `c02295edfd2f` | v0.16.0 | 完整 |
| MobAI-App/simslim | `d594c230fe9e` | v0.13.0 | 完整 |
| Mastersam07/OpenDeviceHub | `e50f07f1f448` | v0.2.0 | 完整 |
| JaviSoto/device-hub-ios | `3779e12aa00c` | — | 完整 |
| heoblitz/Loupe | `ff1351242e6d` | v0.5.1 | 完整 |
| jfarcand/mirroir-mcp | `317dc15fa21b` | runner-v0.4.0 | 完整 |
| RockxyApp/Rockxy | `de791b63e7f9` | v0.41.0 | 完整 |
| ProxymanApp/atlantis | `cc059013de87` | 2.0.0 | 完整 |
| OpenMinis/iCTRL | `c1e4268859ba` | v1.98.16 | 完整 |
| getsentry/MobileBuildMCP | `2998ac77ebbc` | v2.7.1 | 完整 |
| awizemann/harness | `3f58c077ded1` | v0.8.4 | 完整 |
| dongxinsuperman/ai-phone | `d339057bc64a` | v0.8.0 | 完整 |
| karminski/eyes-on-my-phone | `eef71926e613` | — | partial |
| RevylAI/revyl-cli | `8ecfb9f8b159` | v0.1.195 | partial |
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
| X-PLUG/MobileAgent | `11cea575561f` | — | 完整 |
| njucckevin/SeeClick | `0ef37ac4d7aa` | — | 完整 |
| google-research/android_world | `55ddaf5edc6f` | — | 完整 |
| mobile-dev-inc/Maestro | `0df4cf3c8cad` | cli-2.12.0 | 完整 |
| linhay/SKProcessRunner | `24e036604b9e` | 0.0.17 | partial |
| mobile-next/mobile-mcp | `6c945971b6b1` | 1.0.14 | 完整 |

## 收口验证

`verify.sh --ci-docs`、独立 `check-docs.sh`、`git diff --check`通过（227 spaces；治理28、skills13、发布打包9项）。逐仓校验33唯一记录、9个partial成功点逐字段不变、SP-207的iCTRL委托记录未变；SP-193仅原子更新独立检查时间及摘要。16条采用合并祖先校验通过，当前main a0d187ac未改变。原始只读证据358文件的size/hash见[manifest](20261028-evidence-manifest.json)。本轮追踪资料保留本地未提交，无产品修改、推送或发版。

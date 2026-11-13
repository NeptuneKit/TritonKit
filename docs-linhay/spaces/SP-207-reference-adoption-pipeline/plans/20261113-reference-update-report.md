# 2026-11-13 参考更新与采用复核

34仓官方查询完成，8仓变化；21完整/13 partial。固定main366ae99b，初始工作区干净。partial保留旧点，iCTRL独立SP193。

| 固定来源 | 裁决 |
| --- | --- |
| [EvanBacon/serve-sim](https://github.com/EvanBacon/serve-sim/commit/0b4a9ac5126a153071512dd70275418cb14fa0ba) | observe；本次五提交已完整审阅；camera与agent核心约束已覆盖，持久HID client、AX派生视图及record UI改进无已证明的当前main缺口，不新增采用分派。 |
| [lycorp-jp/sim-use](https://github.com/lycorp-jp/sim-use/commit/f50625966fd5d80035090fdb7fb0c35bb2d21600) | observe；Android APK桥端口发现/缓存/共享会话清理机制已读；Triton Android现用ADB/UIAutomator，无该桥或冷启动端点缓存。generation与未知动作不重放已有SP281，不能把上游新功能等同本地缺陷。 |
| [jfarcand/mirroir-mcp](https://github.com/jfarcand/mirroir-mcp/commit/757e8fa112f06909486c07fd9e55a93538e3a345) | observe；新增12提交完整文本diff及listen关键源/测试已读；未建立现有main产品缺口。整套listen包含新音频/语音产品面、默认删除原始音频、低峰值推断无播放及自动模型安装，不符合SP286原始数据/显式派生职责与本轮自动采用范围。历史52提交缺口仍未覆盖，不推进成功点。 |
| [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL/commit/bd053710b614963fe9dfd50862b596ec791bc7f6) | observe；四提交仅DDI文档选择器copy模式与pageBand显式Double兼容修复；Triton没有同源picker/pageBand路径，DDI执行不在自动采用范围，无新增可证明缺口。 |
| [dongxinsuperman/ai-phone](https://github.com/dongxinsuperman/ai-phone/commit/5dd50770bb3859e9e71b0cf03d7d5a65caf8d2ee) | review_pending；9提交96路径230安全文本版本采集完整，但跨Android/Harmony/iOS VM姿态、WDA、Web及20789条设备库的剩余语义和测试未完整核对；不能用重点源码或Release阅读代替全增量审阅。 |
| [RevylAI/revyl-cli](https://github.com/RevylAI/revyl-cli/commit/ebc0e69c8849dba4585b892f07058441127a311b) | observe_partial_no_new_adoption；本日19commit安全文本增量已审，当前本地相似职责已有覆盖或为Revyl云/插件范围，未证实可直接开发的新缺口。历史83commit语义/来源仍partial、4pyc排除及许可全文404保留；不得推进整体成功检查点。 |
| [mobile-dev-inc/Maestro](https://github.com/mobile-dev-inc/Maestro/commit/08f1cd629e4252f2b8c86642a20a76474dab96f6) | observe；新6提交25路径完整审阅；本地录屏无同源Skia/JCodec合成链，CI always仅总结gate且合理；未确认直接采用缺口。 |
| [DIYgod/pinky](https://github.com/DIYgod/pinky/commit/40b19d8438f5331ebf976bff7a403e8aa232e01f) | partial_observe；今日130提交471路径仅重点审阅，旧321+33历史窗口缺口仍未关闭；最新上游OTP/业务审批策略与SP286职责不同，不采用默认内容阻断；未证实新独立本地缺陷。 |

21采用SHA全为main祖先，无新实现。无新聊天/分支/worktree，13已归档聊天未重开；历史跨任务附件阻塞未解除。SP281迁移归既有任务，不自动接管。

Baguette旧secure拒绝/隐藏值建议被SP286职责替代：输入与读回分开，系统不可读仅verification unavailable，显式转换与原件分开，保留目标/预算/未知不重放。仍revise_first。Mirroir转写不能替代原件，低音量不证明无音频，新音频范围与模型下载另定。

昨日1001+5证据hash全部有效。旧455原件缺失unknown不变。今日证据在同级TritonKit-archives/reference-monitor/20261113，manifest后原子发布；历史partial不由新delta自动恢复。

本轮docs-only，ci-docs/check-docs/diff收口。未产品测试、设备、签名/DDI、依赖安装、第三方执行、push/tag/release。上游性能未本地验证。经验修正原参考采用流程和memory。

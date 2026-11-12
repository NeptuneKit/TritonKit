# 2026-11-12 参考追踪与采用

34个去重仓库（25正式参考、9研究候选）已查询官方默认分支HEAD、非draft Release全分页和固定revision许可证；22完整、12 partial，5仓变化，8仓许可证缺口。比较基线是11月11日保存的各仓观察；部分增量的实际成功点更早，不能混作一天变化。研究候选不等于采用。

实际评估基线main `0ec972e6151eb27372b3bdf5aa940940c56c30b0`；新产品main提交 `c4c5f014150f80ce848ee43bd7a2932857fb704b`。用户已有SP281/SP279工作保留，测试环境包含其WIP，本次提交不包含它们。

## 有价值更新与裁决

| 仓库/固定来源 | 本轮结果 |
| --- | --- |
| [Mobile MCP 1.0.17](https://github.com/mobile-next/mobile-mcp/releases/tag/1.0.17) / [ad3b423](https://github.com/mobile-next/mobile-mcp/commit/ad3b42336d89717313af45176c48538bea6ec363) | 3提交完整审阅。backend旋转本身不证明Triton坐标缺陷；沿调用链发现另一真实 `wm size` 首值误选，按AOSP独立实现SP285。mobile-mcp Apache与外部mobilecli FSL许可分开，无复制代码或第三方执行。 |
| [serve-sim cea9a7d](https://github.com/EvanBacon/serve-sim/commit/cea9a7df9b73fb04f4f257640d10c7af3770950f) | 补齐旧22提交与今日7提交，成功基线ede4→前次5f6→本次cea9；完整性恢复，允许独立推进。AX identity/unknown、DTUHID本地已有，frame quiet等待仍有上游不可取消read，性能自述未本地验证；已撤回scrub不排期。 |
| [Mirroir v0.46.1](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.46.1) | 今日3提交npm stderr日志隔离已审，旧52提交缺口保留。端口probe源码无总deadline；3次自有loopback未复现挂起，候选仍revise-first。 |
| [Revyl dd8c128](https://github.com/RevylAI/revyl-cli/commit/dd8c128d8043ca09961fb6e59d0a0cfe95d923ed) | 新14提交43安全文本路径已审，无独立本地采用缺口；旧83提交语义/来源、4个pyc及license404保留，不推进checkpoint。 |
| [Pinky v2026.1112.2](https://github.com/DIYgod/pinky/releases/tag/v2026.1112.2) | 33新提交、5 Release，重点15路径27文本版本；旧321与新窗口完整审读仍不足。ActionContext与已有SP280/281去重，研究重点不等于已采用。 |

Baguette无新变化，精确同对象native set-text回读复核完成，但现有submission成功不是已证实错误；需明确opt-in后置条件、secure保护、同目标失效、无重放和失败反例，维持revise-first。simslim/Loupe未变，昨日SP283/284已覆盖，不重复开发。

## SP-285本地交付

只修改shared parser与对应CLI测试：严格标准标签，Override优先，诊断尺寸、非法/溢出/尾垃圾或同类重复拒绝为nil。既有HTTP失败与截图自然尺寸回退保留；无Web写控制面或动作扩张。

失败测试4项14issues→focused33通过；完整CLI XCTest167 + SwiftTesting1861/204，根包XCTest7 + SwiftTesting130/26与313/45通过。提交后完整CLI与适用local再次通过；local包括release构建和自有fixture smoke。两个文档索引格式问题按既有规则修正，未绕过门禁。详见[验收](../../SP-285-android-wm-size-selection/plans/20261112-validation.md)。

真实Android/ADB/旋转/坐标动作、真实Simulator构建、签名/DDI未执行；未安装依赖、运行上游代码或push/tag/release。真实性能不以离线测试替代。

## 证据、状态与清理

- 11月11日5197原始+55收口证据全部重新验证hash。11月2日455缺失事实不变，原因仍unknown；本次不重新通知相同保管故障。
- 本日原始证据、review、日志保存同级 `TritonKit-archives/reference-monitor/20261112`；[manifest](./20261112-evidence-manifest.json)固定后才原子发布三个状态文件，前后hash与回读结果另档。
- 34仓中只有完整仓推进成功点；partial保持原checkpoint。iCTRL无变化，仍由SP193原upstream-state独立更新，不在SP207复制。
- 既有20项main祖先核验通过，加SP285为21项local_merged；读取/评估/实现/验证/整合/清理分开。无新桌面聊天、branch/worktree需关闭；既有归档/附件边界原样保留，长期主控继续开放。
- ictrl既有每日10:00绑定与prompt复核不变，不新建重复自动化。经验写回mobile-mcp正式档案、EXPERIENCE及当日memory。

逐仓状态见[观察JSON](./20261112-observations.json)；评估文件以同日canonical repo前缀保存。

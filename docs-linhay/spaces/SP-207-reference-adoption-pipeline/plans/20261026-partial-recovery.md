# 2026-10-26 参考增量完整性补查

## 目标与边界

用户要求继续推进。当天33仓日检与SP-221/SP-222开发验证、本地main合并和清理均已完成；本次仅在SP-207继续补查两个可安全读取的历史文本缺口，不重复全量日检或已交付开发，不扩大设备/签名/远端范围。

影响层为参考追踪文档与独立检查点；实际main `8fcd856f2927fa81754bb3e10b80d066c0591f37`。开工10份tracked文档修改及1份untracked审计历史原样保留，清单/hash在`.build/reference-monitor/20261026-followup/root/opening-wip.json`；无产品WIP。两只读subagent显式使用gpt-6.1-sol，文件面仅各自ignored证据目录，正式状态由主控统一复核写回。

## BDD与验收

- Given sim-use的CHANGELOG或device-hub-ios的protocol历史patch被API省略，When官方固定父/子完整文本及完整文件列表可读取，Then保存本地diff、来源/hash、分页证明和逐机制评估；不因真实运行未执行继续伪报文本缺失。
- Given任一查询、分页或源码覆盖仍缺失，Then原成功checkpoint逐对象保持；许可证缺失与二进制来源缺口不因文本补查自动恢复。
- Given资料保存与主控核验完成，Then仅原子推进已完整仓库检查点，保持iCTRL独立点、其他仓库和14条采用对象不变。
- Given当前实现已覆盖上游机制或本地无对应产品范围，Then记录覆盖/观察，不重复立项。只有固定证据证明当前缺口才进入独立执行与主控开发流程。

## 开工交付复查

14条采用记录全部local_merged，其合并SHA均是main祖先；3份SP-221产品/测试文件SHA256匹配冻结清单，40份既有归档的大小/hash全部匹配，注册worktree仅主目录。未重跑未变化的产品测试；本次文档/state写回后运行docs-only三门禁。既有文档整理不提交，不混入新的产品候选。

## 补查结果

两仓官方HEAD相对本日日检未变，旧文本/分页缺口均已闭合。主控核对完整文件列表、被省略文本的父子全文及重建diff、全部manifest hash后接受恢复。当前合并视图24/33完整、9 partial：本次重新查询2仓，另外31仓沿用本日日检，不宣称又跑一轮33仓完整查询。

| 固定官方来源 | 补齐范围 | 当前工程评估 |
| --- | --- | --- |
| [sim-use c02295ed](https://github.com/lycorp-jp/sim-use/tree/c02295edfd2f442249b869096dda3dc7bfcd308d) | 38提交、406次父子文件变化、157历史路径（93净路径＋64合并侧差异）；a16d30e补第2页12路径；CHANGELOG完整blob及git diff +174/-172吻合官方 | 13机制组逐路径对照main；display/HID/录制已有SP-214/218/219，host menu paste无同构实现，签名先决条件不同。collector经另述自有probe复现，纳入SP-223/224 |
| [device-hub-ios 3779e12a](https://github.com/JaviSoto/device-hub-ios/tree/3779e12aa00c08bb34805fef8ffe375838cbe815) | 2提交、20+4文件、36份父子记录；protocol.rs省略patch由全文重建；模块残差及完整分页核验 | 模块拆分/构建缓存/CI前置检查，无对应Triton Rust/RSD实现缺口；不复制daemon或扩大设备范围 |

sim-use最新Release仍[v0.16.0](https://github.com/lycorp-jp/sim-use/releases/tag/v0.16.0)，一页8条闭合、含prerelease筛选；device-hub-ios一页为空。固定许可全文分别Apache-2.0 SHA256 `8c0fe2892344358b49aa07d9a184bd8d0891832baf642f19161f271acc075d32`与MIT SHA256 `4410cda18cd6959d53106c0ed799b3bc483993f5e44f4457a6d9baa1b1f43dfe`，不套用外部分发依赖或二进制。

两完整报告保存在`.build/reference-monitor/20261026-followup/sim-use/report.md`与`device-hub/report.md`，各有manifest和官方来源/覆盖记录。仅两仓成功点推进，其余31仓对象、9个partial检查点、iCTRL独立点保持；原日检快照不改。后续完整视图需合并原日检与recovery-observations，不能把两仓补查当全量轮询。

## 新采用与验证分层

自有原函数提取probe动态复现runHostCommand在parent约0.010s退出、预算0.25s时因后代持FD2.5s而延迟约2.52s返回。stdout、stderr与非零退出均复现，普通输出约0.022s。probe固定main函数及最小wire stub，非正式CLI产物E2E；artifact两路径仍仅静态相似，正式开发须逐路径红绿。证据在`.build/reference-monitor/20261026-followup/host-drain/`。

建立[SP-223](../../SP-223-host-process-drain-deadline/README.md)与[SP-224](../../SP-224-host-process-drain-integration/README.md)，两个真实新会话均显式gpt-6.1-sol。实现/验收/main合并/清理各阶段另记，当前已分派，不提前宣称修复。14条旧采用对象保持，新条单独登记；无上游代码执行、设备、依赖安装、签名/DDI或push/tag/release。

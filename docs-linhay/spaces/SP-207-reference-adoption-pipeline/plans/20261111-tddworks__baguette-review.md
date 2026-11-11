# Baguette 2026-11-11 增量审阅

结论：partial；记录一个待主控去重确认的候选，不推进完整检查点、不实现。

固定 base `94b78d3603acf661e1f593aff7891c3bd7a86c44` → head `593a1b4ae699e87bbab444d0d821e45a74b4bc79`，actual main `607410fb3d44bfe02274c13822170c3015c63a99`。官方compare分页已闭合，34 commits、40 parent edges、35完整树、88路径、365安全文本blob，全部解码并核对Git blob SHA。仅VirtualCamera.dylib不请求；既有身份/二进制来源缺口未闭合。已保存所有安全父边增量全文（27,384行/1,411,759 bytes），重点语义审阅AXFrontmostRead、AXSweep、AXSettle、ThenDescribe、Fill/TextField及相关测试和Release；未声称逐行审毕整个大增量。完整来源与计数见review-coverage.json、review-diffs.txt。

Release v0.2.13和v0.2.14全文已读；Apache-2.0固定全文hash见review.json。所有速度/token/真实应用测试描述只是上游自述，未在本机验证，也没有执行任何上游测试/代码/设备。

AX/输入判断：主线已有fresh translator token、geometry和采集预算、视觉settle/业务断言分离；SP281已有动作receipt/unknown/证据工作，不能重复排期。新上游bridge-first/guest fallback和自适应sweep可观察，但未证明Triton本机缺口。短摘要、命名动作和changed标记不等于业务完成；上游字符串contains ok也不直接移植。VirtualCamera修复不是已证实同源：本地无假AVCapturePhoto替身且fake input init不返回共享input。

候选：显式可选的native set-text精确同目标回读。main performSemanticAction(.setText)目前clear+insert成功即返回提交成功，无文本postcondition。保留既有成功语义，仅显式请求时追加verification；吞键/改写不得verified，目标消失/失焦/换OID或上下文则unknown/target_changed且停止后续键，不自动paste/replay。secure不得凭长度或忽略标点验真，不输出原文。BDD、验收、文件面已写review.json；实现前由主控重新对照SP281和当前WIP，冻结串行文件面。

经验检查：遵守取证前路径筛选、全文与运行分开、历史缺口逐项恢复、不会由prior.complete永久锁死，也不会由本轮源码采齐推导二进制闭合。无新仓内规则写入。

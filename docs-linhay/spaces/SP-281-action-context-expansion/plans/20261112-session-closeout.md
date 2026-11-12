# 2026-11-12 本会话整理与本地提交收口

## 本地提交范围

用户明确要求“整理、沉淀、提交”。基线main `6467b4137c6667eb7a8a0bf564108a2bd51f6b9a`；包含本会话SP-279审计、SP-281回执/证据基础、SP-286原始数据实现与agent规则，及相应测试/schema/memory。提交精确SHA由Git日志和主控最终回读确认；不推送、不发布、不安装升级、不操作设备。

另一任务SP-287当前功能地图/离线图表不在本提交。其目录和shared index/README登记保留在工作区，暂存时仅投影本会话的登记变更，不能为了清空status混入别任务。

## 纠正，不再继承的声明

1. “P0–P2全部完成”不成立。SimTap/SimSwipe不经host receipt helper，sim.press标签不是命令已接入证据；普通host nonzero/timeout throw仍绕过新增receipt；全入口owner/observation/Stop未统一。当前权威为[README](../README.md)。
2. primitive helper接受六个operation标签的测试，只证明模型/投影，不证明六个真实命令路由。历史CLI1858等绿色结果保留，但不替代调用链验收。
3. app.*宽泛分类把只读app.list/info/inspect/container/unknown当mutation；提交收口新增3测试中的5个红issues后改明确operation列表。除此之外不借整理扩做P2。
4. 之前重写11月11日memory遗漏了主线SP-207原历史段落；本轮对照HEAD原文完整恢复，当前仅追加本会话记录，不抹除别任务。
5. Pinky的业务敏感性/默认审批方向不作为Triton当前需求。原始业务数据职责以AGENTS和SP-286为准，技术校验与上层显式转换分开。

## 沉淀入口

- 根AGENTS的原始数据职责；内部ops和三个业务public skills。
- EXPERIENCE新增“helper/DTO标签不等于生产路由”“回写shared memory对比HEAD保留其它记录”的检查点。
- SP-279保留固定Pinky对照和修复前职责审计；SP-281准确区分基础已落地与P2未完成；SP-286保留原始数据实现、红绿日志和边界。
- 新增收口负例不改变已验证SP-286数据行为，只纠正只读app误分类。原始788份Swift hash与5份日志已复核；修改后的候选重新全量验证，不拿旧hash冒充新候选。

## 提交前验证

| 检查 | 结果 |
| --- | --- |
| readonly误分类反例 | 3 tests / 1 suite中readonly新测试5 issues失败，证明app.*问题；随后改明确列表 |
| 完整CLI | XCTest167项，Swift Testing1876项/205 suites，通过exit0 |
| `TRITON_VERIFY_XCODE=0 verify.sh --local` | exit0；root runtime132/26、shared313/45、XCTest2+5；release CLI build、fixture/只读smoke、docs/diff和依赖/DEBUG边界通过 |
| staged docs/skill/release契约 | 暂存后在临时快照验证，不创建branch/worktree；结果由最终回读记录 |
| 设备/Simulator build/用户App/签名DDI/远端 | 未执行；Simulator build显式skip，不能算通过 |

原始日志和源码/暂存树摘要保存于本机ignored `.triton/session-closeout/20261112/`，不把含本地路径的完整日志混入提交。临时快照仅检验暂存文档，不修改主工作区，也不运行Pinky代码。

## 提交语义

本提交保存原始数据和回执/证据基础，不宣称统一执行控制、P2所有入口或发布已完成。旧已丢值/去query的产物不能自动恢复；已安装CLI/SDK/skills不会因本地commit自动更新。

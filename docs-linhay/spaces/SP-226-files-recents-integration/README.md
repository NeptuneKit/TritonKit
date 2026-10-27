# SP-226 — Files Recents 诊断主控验收

## 范围

仅监督[SP-225](../SP-225-simulator-files-recents/README.md)的CLI只读catalog/doctor切片。主控只写本space资料；root负责共享登记、最终main合并与清理关闭。branch feat/SP-226-files-recents-integration，worktree ../TritonKit-worktrees/SP-226-files-recents-integration。新会话模型显式gpt-6.1-sol，不回退。

## BDD与验收

核对固定来源/许可、生产catalog和测试真实红绿，新增feature只依赖searchd，searchtoold disabled不误判files-recents，search downside正确。保留非法需求读取前拒绝、原类别与managed label集合、service-overrides-only语义。独立focused+完整CLI、绑定候选二进制的实际离线 `triton sim resource features` 默认JSON；docs三门禁。未运行Files UI/真实Simulator必须明确；fixture不证明UI恢复。禁止设备/签名/DDI/依赖安装/第三方执行/远端写入。

## 协作与候选阶段记录

已整合root冻结候选 `46bbf1c95c919f9ac0c6bcc6bc0386f97179af4f`；独立验收HEAD `32fd37321acde93e4f15b559467a76340fc47c1e`。focused通过；首轮full有1项既有framebuffer marker缺失失败，suite/精确项复核及第二轮full通过，根因未知。实际默认features/profiles单JSON验证通过；原误加features --json返回既有Unknown option，已按root裁决纠正为默认JSON入口，不作产品缺口。见[独立验收完整证据](plans/20261027-independent-validation.md)；[静态审查](plans/20261027-static-review.md)保留为冻结前历史。未执行真实Files UI/Simulator；root随后已完成main合并、合后门禁与清理，见下节最终证据。共享索引/memory/state由root写回。

## 最终主线交付

已验收合入本地main `607cdf1c`；合后完整CLI XCTest94/SwiftTesting1528、实际默认JSON入口与docs门禁通过。53份证据归档核对后，worktree/branch已移除，会话已归档。首轮既有夹具失败原因未知且完整保留；真实UI未验，不宣称恢复。见[主线收口](../SP-226-files-recents-integration/plans/20261027-main-closeout.md)。未push/tag/release。

# SP-226 — Files Recents 诊断主控验收

## 范围

仅监督[SP-225](../SP-225-simulator-files-recents/README.md)的CLI只读catalog/doctor切片。主控只写本space资料；root负责共享登记、最终main合并与清理关闭。branch feat/SP-226-files-recents-integration，worktree ../TritonKit-worktrees/SP-226-files-recents-integration。新会话模型显式gpt-6.1-sol，不回退。

## BDD与验收

核对固定来源/许可、生产catalog和测试真实红绿，新增feature只依赖searchd，searchtoold disabled不误判files-recents，search downside正确。保留非法需求读取前拒绝、原类别与managed label集合、service-overrides-only语义。独立focused+完整CLI、绑定候选二进制的实际离线features JSON；docs三门禁。未运行Files UI/真实Simulator必须明确；fixture不证明UI恢复。禁止设备/签名/DDI/依赖安装/第三方执行/远端写入。

## 协作与状态

尚待执行候选。先只读静态审核，收到root冻结SHA才在自身worktree整合并测试；与执行共享scratch串行。子会话完成不是合入main的依据，未过验收退回修复。验收通过root合main并跑合后门禁，再归档证据/清理worktree/关闭会话。

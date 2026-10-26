# SP-222 — Simulator资源只读重试主控

## 范围与授权

只负责[SP-221](../SP-221-simulator-resource-read-retry/README.md)候选审查、独立验收、本地main合并与清理。沿用用户参考自动采用及开发验证后合main授权；执行/主控新会话必须显式model=gpt-6.1-sol，不回退，不伪造thread。产品基线24e7d0f2；未授权设备、依赖、签名/DDI、remote写入。

## 验收与文件面

主控拥有本space验收文档，不与执行同时修改生产文件。核对候选SHA/diff、先红后绿、真实runner非零throw路径、精确argv与同UDID、有限预算与取消/权限/截断/畸形不重试、mutation不重放；focused和完整CLI串行，通过后适用root/docs/local门禁。真实设备未执行单列。

合main前确保实际main干净，merge-tree预检；候选只包含SP-221文件面，原追踪文档独立必要本地归档提交不得混入产品候选。主控审查通过才合main，合后重跑受影响完整门禁，回写source/merge SHA、检查点与索引；归档ignored证据后正常清理已合worktree/branch。不push/tag/release。

状态：主控已创建并基线审查；真实thread `01a175fd-5c91-7b52-bc7c-683468efff9f`，branch `feat/SP-222-simulator-resource-retry-integration`，worktree `../TritonKit-worktrees/SP-222-simulator-resource-retry-integration`。执行真实thread `01a175fc-c9c4-7053-b91e-74c209d3f0ca`；两会话均显式gpt-6.1-sol创建成功。等待执行先红后绿和冻结候选，尚未验收或合并；本space不无限承接后续批次。

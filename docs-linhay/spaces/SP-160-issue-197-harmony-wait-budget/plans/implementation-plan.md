# SP-160 implementation plan

1. 先在 `HarmonyWaitRuntimeTests` 增加剩余预算低于最小 capture budget 时不调用 capture 的失败场景。
2. 在共享 `waitForHarmonyText` 增加 documented minimum layout capture budget；deadline 临近时提前返回标准 timeout envelope。
3. 更新 agent-facing CLI 文档、space 索引、memory 和 issue 验证边界。
4. 串行运行 focused tests、CLI/full local gate；提交后合入 `main`，再 push 并等待 CI。
5. 只有 #197 的实现、主线门禁和 CI 均通过后，才发布脱敏验证评论并关闭 issue。

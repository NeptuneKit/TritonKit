# SP-199 — Mobile MCP 参考登记与能力差距

## 边界与状态

- 用户请求：将 [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) 列为参考项目，回答它有哪些 TritonKit 当前没有的功能。
- 影响层：参考资料、space、项目文档与 memory；不修改 CLI/HTTP/shared core/Web/Wails 产品代码。
- 当天文档任务在主工作区完成，不新增实现 worktree。开工 HEAD `8abe76db06cf9b1e6c550fe52ac103209c458e4e`；保留既有 ops/release skill 与 SwiftPM 依赖边界文档未提交改动。
- 状态：已归档：参考登记、源码差距报告与文档门禁完成。采用功能须另立实现 space；本次不启用定时追踪、不运行第三方程序、不操作设备、不提交或发布。

## 参考入口

- 正式参考与差距报告：[Mobile MCP 能力比较](../../dev/mobile-mcp-reference.md)。
- 本地只读源码：`docs-linhay/references/mobile-mcp/`，按既有 references 忽略规则保留。
- 上游基线：`d4a83fa45b9ce7551dba1d1f5e7bdf7400b1b023`，2026-10-14 核对；证据以固定 SHA 源码为准。

## BDD 与验收

1. Given 后续会话查找参考项目，When 从长期 memory 或参考汇总进入，Then 能到达正式档案、上游与固定 revision。
2. Given 上游功能清单，When 对比本地当前源码，Then 区分缺失、部分覆盖、已覆盖与上游规划，不把旧计划或 README 支持声明当成本轮真实验收。
3. Given 当天新增 iOS Runner，When 评估免业务 SDK 真机操作，Then 计入已有 inspect/tap/scroll/type/screenshot，不重复登记整类缺口。
4. Given 仅文档改动，When 收口，Then `verify.sh --ci-docs`、`check-docs.sh` 与 `git diff --check` 通过；Swift/设备/上游运行测试未执行并注明边界。

## 验证与沉淀

2026-10-14：`verify.sh --ci-docs`、独立 `check-docs.sh` 与 `git diff --check` 均通过，199 个 space 登记一致。仅文档校验，未运行 Swift/Web 产品回归、上游 npm/build/test 或设备/云操作；上游核心 backend 不在本仓，运行覆盖仍未验证。参考 clone HEAD clean，正式档案保留固定 SHA 与本地源码行号。结论未提交、未推送。

经验检查已完成：具体检查点写回 [正式参考档案](../../dev/mobile-mcp-reference.md)；计入 SP-195 新 Runner，不把 device crash/录屏/云租约和相近 runtime 能力混同。通用参考审计流程已有治理规则，本轮不重复新增 skill。

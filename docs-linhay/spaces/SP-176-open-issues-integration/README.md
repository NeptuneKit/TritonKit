# SP-176：线上 open issues 集成验收

## 边界

截至 2026-09-08 的 open 集合：#207、#208、#209、#210、#211、#212。影响层为 macOS CLI、shared DTO、iOS embedded runtime。复用 SP-170～173，新增 SP-174～175；此 worktree 汇总补丁及验收，主仓已有 CLAUDE.md 修改保持原样。

## BDD 与验收

- Given 各 issue 隔离实现，When 组合验证，Then 输出契约、schema、测试及文档一致。
- Given host Simulator coordinate tap 带 --duration，When 执行，Then 在设备解析前返回单一 unsupported_capability，不丢弃 duration 执行普通 tap。
- Given UIKit 条件编译测试，Then 明确区分 macOS 非 UIKit 测试与实际 iOS destination 验证。
- 本地总门禁、CLI 全量测试、文档结构和 diff 检查通过；失败必须复核修复或记录具体环境限制。

## 状态

本地验收通过：CLI 977/977、根包 269/269、真实 iOS Simulator UIKit 46/46。已合入并推送 main（`82a13db5`），[代码 CI](https://github.com/NeptuneKit/TritonKit/actions/runs/34179623896) 通过；#207～#212 已逐条回填证据并关闭，关闭后 open 查询为 0。 本次 docs-only 归档推送后继续复核归档 CI 和最终 open 集合。

## 验收入口

- [逐 issue 审计与验证](plans/20260908-issue-audit.md)
- [机器可读验收摘要](plans/20260908-verification.json)
- 原始 `.xcresult` / Xcode stdout/stderr / doctor facts 保存在本 worktree `.triton/issue-audit/`（不提交）。专用 Simulator 已 shutdown。
- 2026-09-08 用户明确同意提交、合入 main、推送并关闭 #207～#212；按已授权范围执行，不创建 release/tag。

# SP-259-issue-248-xcode-diagnostics

状态：本地候选已冻结；行为 RED、审阅修订 RED、97 项相关测试及三项真实 CLI 受控验收通过，待主控整合与 CI。关联 GitHub #248。

## 边界与 BDD

影响 CLI Xcode 最终诊断和 shared Codable 诊断覆盖元数据。Given 日志超过内存前缀且尾部有 fatal，When 构建失败生成 summary，Then 有界读取本次日志并保留 fatal 原因、覆盖范围和原退出码；无命中时明确 diagnostics-unavailable，不再推荐缺失的字段。范围不包含原私有工程的编译修复或缓存操作。

完整 BDD、预算和脱敏边界见 [诊断契约](plans/diagnostic-contract.md)；测试与运行证据见 [验收记录](plans/validation.md)。

## 归属与验收

分支 feat/SP-259-issue-248-xcode-diagnostics；worktree /Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-259-issue-248-xcode-diagnostics。主控串行运行共享构建与 Git 写操作。先 RED 后实现与 GREEN；独立审阅、完整回归和 CI 通过后合并，issue 保持开放。

候选文件面：Xcode bounded diagnostic helper、既有 parser 与最终适配点、诊断 coverage DTO、Xcode schema 和专属测试。未修改通用进程 runner、Harmony wait、参数解析或设备流程。

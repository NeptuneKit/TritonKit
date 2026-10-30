# SP-248 — Harmony ArkWeb CDP 传输修复

## 当前状态与边界

对应 GitHub #238；影响 CLI host ArkWeb WebSocket transport、共享错误码与 schema。已通过 [PR #239](https://github.com/NeptuneKit/TritonKit/pull/239) 合入远端 main，merge `41598639776e3e832eab809aefd41c4eddeda386`；精确候选与合并后 CI 均通过。真实前序 Space 登记单独提交，不包含其他任务产品 WIP。

机制修复已交付源码；2026-10-30真实ArkWeb自有probe已完成旧版失败/当前CLI成功/allowlist拒绝验收。原私有App未验，#238保持开放；已随v0.2.37发布并通过安装版复验。最终状态与 CI 见[合并验收](plans/20261030-merged-validation.md)。

## BDD 与验收

- Given 本机真实 WebSocket fixture 仅接受 text JSON，When CDP evaluate，Then 收到正确响应且不发送 binary frame。
- Given socket 断开或握手失败，Then 返回 transport 错误，不误导检查页面 handler。
- Given CDP protocol error 或无效响应，Then 与页面 exceptionDetails 分型；后者仍为 javascript_error。
- 超时/取消仍有界，失败仍关闭 session，随后按原 ownership 规则清理 forward；不自动重放 bridge mutation。
- 本机fixture不代表原现场恢复，真实ArkWeb验收独立保留。

## 实现与验证证据

CDP改发UTF-8 text frame；socket与protocol错误有独立code/hint，页面异常保留javascript_error。

- 原基线 `30185dc2` 冻结红灯：45项测试、11个预期失败；精确复现POSIX57与binary opcode。
- 定向绿灯45项；完整CLI1582项+94 XCTest；完整root402项（含新旧错误码DTO roundtrip）通过。
- 实际CLI schema单一JSON且含新错误码。
- 以上产品与测试候选在rebase后逐文件SHA-256一致；原基线与dba41b6e的差异仅为已排除的历史文档。
- 首轮独立 docs 缺前序 Space 的失败保留；补齐真实登记后，实际候选 ci-docs、独立 check-docs 与 diff check 均通过。
- 远端 CI 的 CLI Release 编译与标准 CocoaPods lint 通过；v0.2.37 Release 制品已发布并校验。真实Harmony模拟器ArkWeb自有probe验收通过；物理设备及原私有App未验，不将机制通过扩大为所有现场恢复。

证据与命令见[验证记录](plans/20261030-validation.md)，阶段复核见[交付复核](plans/20261030-controller-review.md)。worktree：`../TritonKit-worktrees/SP-248-issue-238-arkweb-transport/`；branch：`feat/SP-248-issue-238-arkweb-transport`。

本轮真实验收及发布状态见[SP250](../SP-250-release-v0-2-37/plans/20261030-release.md)，取代旧合并验收报告中“真实环境尚未验”的阶段状态；原私有App边界继续保留。

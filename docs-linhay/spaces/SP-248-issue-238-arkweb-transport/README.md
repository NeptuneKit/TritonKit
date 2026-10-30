# SP-248 — Harmony ArkWeb CDP 传输修复

## 当前状态与边界

对应 GitHub #238；影响 CLI host ArkWeb WebSocket transport、共享错误码与 schema。远端候选已以 `origin/main@dba41b6e` 重放：真实前序Space登记提交 `e6258339`，独立修复提交 `8d18670f`；两提交已在本地完成，尚未推送、创建PR或合并。用户已明确持续授权开发、测试、提交、推送及合并main，后续不再等待逐项授权。

SP244～247现已在本候选以真实登记摘要就绪，不包含其产品WIP；本地旧 `30185dc2` 日检文档未带入。最新候选的独立docs门禁正在主控复验，尚未判定通过。真实ArkWeb、发布及原用户场景仍未验收，#238保持开放。不操作设备或业务App。

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
- 首轮独立docs因缺前序Space失败是历史证据；真实前序登记现已补齐，最新候选docs仍待主控检查结果，不能沿用早期联合快照通过替代。
- Harmony真实设备/ArkWeb、Release制品与CocoaPods lint未执行；本机wire通过不等于原现场已恢复。

证据与命令见[验证记录](plans/20261030-validation.md)，阶段复核见[交付复核](plans/20261030-controller-review.md)。worktree：`../TritonKit-worktrees/SP-248-issue-238-arkweb-transport/`；branch：`feat/SP-248-issue-238-arkweb-transport`。

# SP-248 — Harmony ArkWeb CDP 传输修复

## 边界

对应 GitHub #238；影响 CLI host ArkWeb WebSocket transport、共享错误码与 schema。基线 30185dc2；本地独立 worktree，未提交、未合并、未发布。不操作设备或业务 App。

## BDD 与验收

- Given 本机真实 WebSocket fixture 仅接受 text JSON，When CDP evaluate，Then 收到正确响应且不发送 binary frame。
- Given socket 断开或握手失败，Then 返回 transport 错误，不误导检查页面 handler。
- Given CDP protocol error 或无效响应，Then 与页面 exceptionDetails 分型；后者仍为 javascript_error。
- 超时/取消仍有界，失败仍关闭 session，随后按原 ownership 规则清理 forward；不自动重放 bridge mutation。
- 真实 ArkWeb 设备尚未验证；本机 fixture 不代表原现场恢复。

## 状态

本地修复与验证完成，尚未提交/合并/发布；#238保持开放。CDP改发UTF-8 text frame；socket与protocol错误有独立code/hint，页面异常保留javascript_error。

- 冻结红灯：45项测试、11个预期失败；精确复现POSIX57与binary opcode。
- 定向绿灯45项；完整CLI1582项+94 XCTest；完整root402项（含新旧错误码DTO roundtrip）通过。
- 实际CLI schema单一JSON且含新错误码。
- 单支docs门禁被已有主目录SP244–247尚未进入此基线的连续编号阻断；主控负责以真实联合文档快照验收，不伪造记录。
- Harmony真实设备/ArkWeb、Release制品与CocoaPods lint未执行；本机wire通过不等于原现场已恢复。

证据与命令见[验证记录](plans/20261030-validation.md)。worktree：`../TritonKit-worktrees/SP-248-issue-238-arkweb-transport/`；branch：`feat/SP-248-issue-238-arkweb-transport`。

主控已完成候选审查与联合文档快照验证，详见[交付复核](plans/20261030-controller-review.md)；独立分支缺前序Space、真实设备与发布边界继续保留。

## 2026-10-30 持续授权与提交候选

用户已明确授权开发、测试、提交、推送及合并main；此前待授权和不提交的文字仅代表首轮阶段，已被本指令取代。此次以远端main dba41b6e为基线重放，排除本地30185dc2旧日检文档。真实前序SP244–247仅以登记摘要纳入，不包含其产品WIP。原现场验收和发布仍独立，issue保持开放。

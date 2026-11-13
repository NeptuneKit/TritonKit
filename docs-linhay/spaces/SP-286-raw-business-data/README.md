# SP-286 — 原始业务数据与上层策略边界

> 2026-11-13后继：已提交内容随 [v0.2.45](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.45) 分发，发布/资产/安装与限制见 [SP-289验收](../SP-289-release-v0-2-45/plans/20261113-release.md)。以下保留原实施阶段授权与本地验收历史，不提升为新的设备/业务验收；用户agent skills目录未被自动覆盖。

## 需求与授权

用户2026-11-12裁决：移除现有代码自行识别敏感内容、丢值/阻断及默认改写；TritonKit主旨是提供原始数据，写入AGENTS和agent环境。前置[职责审计](../SP-279-pinky-reference/plans/20261112-responsibility-boundary-audit.md)。

当前main `6467b413`，有SP-281及研究WIP，保留、不stage/reset/stash，不创建分支/worktree，不提交/推送/发布。

## 范围

- testrec/input与target不再用关键词、邮箱或数字猜隐私；保留输入、支持导入/回放的真实技术校验。
- network fixture保留源response body；proxy capture保留业务URL的query/fragment与provider错误，不再一概删减。URL userinfo与Triton自身会话凭据单独处理，不把业务body里叫token的字段等同协议密钥。
- WebView表单snapshot/focus/input返回真实可读取value与长度；显式secure仍可选择长度模式，原DTO兼容加字段。
- iOS runner仅删确定的transport/internal字段，业务text/token同名嵌套值保留。
- Harmony将输入提交与明文读回verification拆开；掩码字段无法验证时不能假报match，也不能因内容敏感泛化成禁止输入。
- AGENTS、public skills与原权威文档写明原始数据职责；公开外发资料仍遵守本项目发布/脱敏授权，与本地采集分开。

## BDD与验收

1. 邮箱、长订单号、password/token/secret普通字符串编译后原值保留，无自动privacy blocker；目标文案内容不妨碍合法tap/assert导入。
2. 旧privacy finding不作为业务拦截依据；其它真实quality/identity/truncation/unsupported错误仍拒绝。
3. 响应body原样进入fixture；query/fragment和非认证错误细节保持；路径/凭据/size budget不回归。
4. WebView真实value穿过JS、decode、shared DTO、CLI JSON；显式secure输出长度模式，不自动识别密码阻断。
5. Harmony掩码/缺password标记不阻止合法提交；无法读回则verification unavailable、保持submitted，不重试、不伪造verified。
6. iOS sanitize保留嵌套业务字段，真正协议token/PNG按对应边界处理。
7. Tests先红再实现，冻结模块后focused/完整CLI/root/local/docs，UIKit/WebKit条件限制明确，不以macOS跳过当真实UIKit验收。

## 状态

当前main源码与agent规则已实现并完成验收，用户已授权本地提交收口；不推送/发布，精确commit以Git记录为准。详见[原实施验证](./plans/20261112-validation.md)与[本会话提交收口](../SP-281-action-context-expansion/plans/20261112-session-closeout.md)。

- 完整CLI：XCTest167 + Swift Testing1875/205 suites，通过。
- root：runtime132/26 suites + shared313/45 suites（另XCTest2+5），通过。
- 最终local/ci-docs/diff通过；macOS WebKit与JavaScriptCore实际fixture执行，不当作用户iOS App或Harmony IME现场验收。
- 原始证据标注byte counts/hash/fidelity/partial，旧丢失数据不能自动恢复；旧录制需从原始流重新编译。
- agent规则写到本项目AGENTS、内部ops与三个业务public skills源码；不修改全局profile或已安装包。

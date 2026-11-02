# SP-269 #204 受控 WebView 输入回归

## 当前状态

2026-11-02发布前增量巡查发现已关闭 #204 的新反馈；本地最小修复与真实自有验收通过，尚未远端整合或发布。来源：[新增评论](https://github.com/NeptuneKit/TritonKit/issues/204#issuecomment-6575448569)。不修改 issue 开关状态。

## 边界与 BDD

影响层为 iOS embedded WKWebView 输入运行时及 CLI 返回契约，非 Web 展示控制面。保留 legacy activeElement 输入与 opt-in form API 的不同边界，不擅自取消 opt-in。

- Given 自有真实 React-controlled textarea，When legacy activeElement 输入后强制重渲染与业务校验，Then React state 与可见 value 均保留输入；仅 ACK、insertedLength 或即时 DOM 值不构成通过。
- Given 自有 contenteditable，When 同入口输入，Then 内容与原行为保持。
- Given 两个可见 WKWebView 且当前目标不唯一，When legacy 输入，Then 返回明确 ambiguity，不把它误报为不存在 WebView；不盲选目标或重放输入。
- Given 页面未 opt-in，Then 专用 form API 仍 fail-closed。
- 原私有 App 现场依赖人工的部分继续排除，既有反馈是历史未验证证据；自有 fixture 通过不声明原现场恢复。

## 隔离与验证

复用本聊天干净、已整合的 SP256 warm worktree `/Users/linhey/.codex/worktrees/sp-256-issue-245-compact-schema/TritonKit`，新分支 `feat/SP-269-issue-204-controlled-input`，基线远端 main `dd2ef7a6`。主控拥有空间、索引、集成；实现文件待只读调查后明确委派，Git/构建/设备动作串行。原 SP257 WIP 与主目录保持原状。

计划先真实失败 fixture，再最小修改、正负对照、root/CLI/标准 pod lint 与真实 iOS App-host 验收；必要发布门禁重新绑定最终候选。复用已有自有 App-host 的方法，原始证据单独归档，不改写旧验收记录。

## 当前验收

旧源码 JSCore RED：8项/16个失败断言；旧真实React App-host：6项中4失败、2正向对照通过，共20失败断言。测试本体结束后Xcode收尾600秒超时、结果包不完整，原失败与工具超时分别保留。修复后9项JSCore通过；最终无opt-in真实iOS App-host v2 7项全部通过、0失败/跳过，Triton xcode test正常exit0且xcresult解析通过。覆盖React input/textarea的state、onChange、rerender、业务validation、contenteditable、同步拒绝、异步回滚、歧义零写和strict未optin拒绝。独立生产diff审阅无P1/P2；完整根包7+413、CLI162+1741及local preflight通过。

[详细验证](plans/20261102-validation.md) · [包外可复现App-host源码](plans/fixture/README.md)。运行时仅50ms有界DOM验证，不承诺任意后续业务结果。原始日志与hash在同级 `archives/SP269`，原私有现场仍未验证。

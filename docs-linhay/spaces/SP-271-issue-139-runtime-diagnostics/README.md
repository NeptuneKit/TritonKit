# SP-271 — Direct runtime transport diagnostics

## 当前状态与边界

最小实现、55聚焦/162+1751完整CLI及主控真实进程fixture通过；独立审阅无P1/P2，待精确提交/PR/CI/合并，后续发布见SP272。详见[验收报告](plans/20261103-validation.md)。

2026-11-03：调查 closed #139 新增评论6594578492/6594608044。基线远端main edffb45e，独立分支feat/SP-271-issue-139-runtime-diagnostics，同级worktree SP-271-issue-139-runtime-diagnostics。影响层仅CLI错误envelope；实际HTTP路由正向控制已报告正确，需独立复现。原doctor/plan修复不作为回归断言，不关闭issue；真实App DOM provider和人工验收不属本切片。

## BDD

- Given Harmony snapshot完整runtime URL及独立server选项，When runtime连接失败，Then endpoint为实际请求URL，platform/target上下文保留，不拼接host server或给出iOS/serve恢复动作，退出非零且stdout单一JSON。
- Given 同样参数且runtime fixture返回provider错误，When snapshot执行，Then只有runtime listener收到一次POST /v2/runtime/webview/snapshot，完整保留provider错误及上下文，server listener零请求。
- Given Harmony未提供runtime URL，Then沿用明确参数错误且零请求；默认iOS server相对endpoint行为不回归。

## 验证与分工

先失败测试与安装0.2.39隔离fixture，再最小修复、focused/完整CLI回归与真实进程fixture；必要本地/远端门禁通过才合并。主控负责文档、精确审阅、Git串行与发布。实现子agent仅CLI transport/WebView实现及相应测试；无设备或共享服务操作。发布新patch另建space；旧tag不可移动。

## 证据

[新反馈](https://github.com/NeptuneKit/TritonKit/issues/139#issuecomment-6594608044)。巡查原始证据保留在automation scans/2026-11-03T04-12-00.424708+00-00。验收未完成，不将诊断修复称为原现场完整恢复。

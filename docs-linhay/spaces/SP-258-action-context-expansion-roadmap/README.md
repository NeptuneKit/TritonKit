# SP-258 — ActionContext 后续扩展路线

## 当前状态

- 状态：路线规划完成，等待按优先级连续推进。
- 前置批次：[SP-257 ActionContext / Action Admission 全量批次](../SP-257-action-context-admission-design/README.md)。
- 目标：把 SP-257 的 runner/device.action 两条试点链路收敛为共享核心，再按边界扩展到其它 mutating surfaces。

## 交付物

- [ActionContext 扩展路线](./plans/20261110-action-context-expansion-roadmap.md)
- [SP-257 完成批次](../SP-257-action-context-admission-design/README.md)
- [Pinky 深度调研](../SP-256-pinky-reference-research/plans/20261110-pinky-formal-research-report.md)

## 当前状态摘要

SP-257 已完成 ActionContext、AdmissionStore、generation guard、runner admission/evidence、lease-aware admission、device.action 试点、schema/recovery 和并发联合验收。

SP-258 的首要任务是 P0 shared coordinator/receipt 和 P1 device.action evidence/uncertain 补齐，再进入其它 mutating surfaces。Approval UI、HTTP remote admission、session resume、真实设备和云设备需要独立 scope。

## 验收边界

- 不把 P0/P1 离线 fixture 当成真实设备或远程验收；
- 不复制 Pinky 的真实手机驱动、UI 或 HTTP sessionless 强身份模型；
- 所有新增 action 必须复用 shared coordinator/receipt；
- 失败、uncertain、stale、late result 全部 fail closed，不自动 replay。

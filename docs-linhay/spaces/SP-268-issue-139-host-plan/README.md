# SP-268 Host goal planning

## 边界与状态

处理 #139 的 host goal-specific 路由反馈，连同 #31 参数保留反例。当前为本地候选；不执行生成的设备动作、不宣称真实 App 路由恢复。原有 iOS bootstrap 与 afterRecoverySteps 保持。

## BDD

- Given Harmony/Android general 或 open-url，When embedded server 可用/不可用，Then 不推荐无关 Xcode 启动，先 host doctor/list/readiness。
- Given Harmony open-url 的设备、bundle、ability、HAP、含空格/ampersand URL、文本、evidence，Then 独立 argv token 原样保留，optional HAP 只生成安装步骤，host smoke 一次完成 open-url/wait/assert/evidence；不重复提交 URL。
- Given Android open-url 缺少当前 plan 无法表达的 package，Then 显式完整 smoke 能力边界，保留可用 host 步骤，不假装完整验收计划可执行。
- Given iOS/default open-url，Then 既有 bootstrap + afterRecoverySteps 结构不回归。

## 责任与验证

独占 `CLIRuntimeTransportPlans.swift`、`CLISchemaBootstrapCommands.swift` 的 plan schema 块、独立 `HostGoalWorkflowPlanTests.swift` 与本 space。主控维护共享索引/memory、串行构建与 Git。以纯构造器矩阵、parser round-trip、只读实际 CLI 验证；不执行生成命令。证据保留 `.build/sp268/`。

验证记录：[20261102-validation](plans/20261102-validation.md)。可复跑只读 CLI fixture：[verify-readonly-plan.py](plans/verify-readonly-plan.py)。

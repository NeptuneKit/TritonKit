# SP-177 iOS Simulator Resource Management

## 当前状态（2026-10-24 范围收口）

**已归档：单设备资源维护由 SP-196 完成交付；fleet、性能收益验证与自动编排撤出当前队列。** 本次归档是范围裁决，不表示原始长期路线全部实现。

[SP-196 实际交付](../SP-196-upstream-optimization-delivery/README.md)已完成专用 iOS Simulator 的 `plan → apply → verify → restore`，前后 `disabledLabels` 相同，并随 v0.2.28 发布；详见[资源验收](../SP-196-upstream-optimization-delivery/plans/resource-delivery.md)与[验证报告](../SP-196-upstream-optimization-delivery/plans/20261014-validation-report.md)。继续维护这些已交付的显式单设备工具，不重复实现旧 mutation 待办，不承诺未测的资源收益或跨 runtime 可靠性。

`.tritonplan` 中的 `simulator-resource` 保留离线命令规划：`replay --dry-run` 输出既有 argv。真实 replay 遇到该动作时，在整份计划的 runtime 解析、host I/O 和任何前序动作之前返回单一 `unsupported_capability`；不会先执行前面的 tap，也不新增资源执行器。资源变更与恢复仍须通过显式单点命令单独完成。现有 `resource watch` 不等于具备内存预算、目标隔离与批量恢复的 fleet 调度器。

自动 replay/evidence 编排、fleet 调度和量化性能目标不再是本 space 的未完成工作；未来仅在明确使用需求下另立有限 space。本轮收口没有重做 SP-196 的设备验收，也未操作远端；新增拒绝边界及帮助/schema 的验证由主控绑定当前联合候选记录，历史实测不替代本轮代码验证。

## 边界

当前范围限本机 macOS iOS Simulator 的已交付资源观察、profile 与显式变更/验证/恢复维护；不覆盖真机、Android/Harmony、Web/Wails 控制面或远端设备云。原方案还提出 plan/evidence 自动集成与多模拟器资源调度，这些扩张目标已于 2026-10-24 撤出当前队列。

上游：<https://github.com/MobAI-App/simslim>（MIT）。参考基线：iOS 18.5+ 持久化 launchd override；旧 runtime 仅允许 no-reboot。

## 原始 BDD（历史方案，不作为持续实施要求）

以下保留最初需求。当前维护验收以 SP-196 的实际单设备证据和本页的执行拒绝边界为准；不能由历史场景推导未验证的失败恢复或自动 evidence 能力已交付。

- Given 已启动 Simulator，When 查询 resource status/measure，Then 输出单一合法 JSON，包含 runtime、服务状态、phys_footprint、进程数和 capability impact。
- Given profile 要求关闭某服务，When doctor 检查测试需求，Then 冲突时 fail-closed，列出 feature 与 daemon。
- Given apply 产生变更，When 任一步骤失败，Then 输出 receipt、partial/recovery 状态，不声称已完成。
- Given restore receipt，When 恢复本次变更，Then 不覆盖用户原有 override，并读回验证。
- Given `.tritonplan` 声明资源步骤，When dry-run，Then 暴露 canonical argv、依赖能力和 expected artifacts。

## 原长期阶段的处置

1. **维护已交付部分**：catalog/profile 规则、只读观察、测量、doctor 与 plan；不将固定 catalog 或单设备实测推广为全部 runtime 矩阵。
2. **已由 SP-196 接替交付**：单设备 apply、no-reboot、receipt-backed restore、verify；旧实现缺口以其实际代码和验收记录为准。
3. **撤销本期自动集成目标**：plan/replay 前置与 cleanup、自动失败恢复和 evidence artifacts；仅保留离线规划及明确 unsupported 执行边界。
4. **撤销本期量化目标**：内存、boot 时间、测试耗时、flaky rate、误伤率及批量 restore 成功率；不使用上游数字作产品承诺。
5. **撤销本期 fleet 目标**：内存预算、profile 分配、并行启动、隔离和批量恢复；不作为本 space 的持续待办。

## 代码接入面

- `Sources/TritonKitCLI/CLISimulatorResourceRuntime.swift`：host 执行与恢复。
- `Sources/TritonKitShared/`：profile、catalog、compatibility、receipt/evidence DTO。
- `CLIHostProcessRuntime.swift`：复用现有命令执行边界。
- `CLISchemaCapabilityContracts.swift`、plan/evidence models：机器可读契约。

## 风险与停止条件

服务目录随 runtime 演进；StoreKit、push、Universal Links 等能力可能被误伤。默认保持 stock；显式变更遵循已交付工具的 profile/receipt 与读回边界。本次归档不授权自动启用 slimming，不恢复已撤销的 fleet 路线。

## 2026-09-14 验证校正（历史快照）

该日尚未完成端到端变更验收；下列“待实现/仍需补”保留当时记录。单设备 mutation 与真实回归后来已由 SP-196 接替，自动编排/fleet/性能目标则按上文撤销，均不继续沿用为当前队列。

- 上游 catalog 已跟进至 `4ae1659a0c0265787c2a7047fab466b326ba6d7e`：15 categories、24 features、170 unique slimmable labels。该提交新增了关机设备 offline override 快路径与 parallel-testing clone watch；TritonKit 已同步 catalog pin 与 `resource watch` CLI，offline store 仍保持 host adapter 的后续切片。
- `status` / `doctor` 已接 `launchctl print-disabled` 原生读取；新增 4 项 inspection 测试，明确 doctor 只检查服务 override，不代表业务功能验证。
- 原 RSS parser 单位错误已修正为 KiB × 1024，拒绝损坏/重复/负数和溢出；3 项测试通过。RSS 不作为 phys_footprint 收益证据。
- `measure` 改接 host launchd_sim 子树 + libproc `ri_phys_footprint`；6 项测试包括当前进程真实 libproc 采样、目标隔离、partial 和全失败。
- 先前全量测试通过不代表 mutation 闭环：现有 apply/profile/receipt 恢复仍需补目标绑定、真实 profile 解码、label 前态快照、完整命令退出码和读回验证。CLI `execute` 旧分发不能作为可用证明。
- replay 目前仅新增 action/metadata，真实执行仍未接通；evidence artifact 常量不等于文件落盘；fleet 与真实 Simulator 回归仍待实现。

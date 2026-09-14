# SP-177 iOS Simulator Resource Management

## 边界

本 space 研究并规划将 MobAI-App/simslim 的核心能力迁移为 TritonKit 原生 Swift host-side subsystem：服务 profile、瘦身/恢复、状态验证、能力诊断、进程与内存测量、plan/evidence 集成和多模拟器资源调度。范围限本机 macOS iOS Simulator；不覆盖真机、Android/Harmony、Web/Wails 控制面或远端设备云。

上游：<https://github.com/MobAI-App/simslim>（MIT）。参考基线：iOS 18.5+ 持久化 launchd override；旧 runtime 仅允许 no-reboot。

## BDD 验收

- Given 已启动 Simulator，When 查询 resource status/measure，Then 输出单一合法 JSON，包含 runtime、服务状态、phys_footprint、进程数和 capability impact。
- Given profile 要求关闭某服务，When doctor 检查测试需求，Then 冲突时 fail-closed，列出 feature 与 daemon。
- Given apply 产生变更，When 任一步骤失败，Then 输出 receipt、partial/recovery 状态，不声称已完成。
- Given restore receipt，When 恢复本次变更，Then 不覆盖用户原有 override，并读回验证。
- Given `.tritonplan` 声明资源步骤，When dry-run，Then 暴露 canonical argv、依赖能力和 expected artifacts。

## 长期阶段

1. 规则冻结：上游代码审计、daemon/category/feature 清单、runtime 矩阵和损失说明。
2. 只读原生能力：Swift models、profiles/features/status/measure/doctor/plan。
3. 单设备变更：apply、no-reboot、receipt-backed restore、verify。
4. 测试集成：plan/replay 前置与 cleanup，失败恢复和 evidence artifacts。
5. 可靠性验证：内存、boot 时间、测试耗时、flaky rate、误伤率和 restore 成功率。
6. fleet 调度：内存预算、profile 分配、并行启动、隔离和批量恢复。

## 代码接入面

- `Sources/TritonKitCLI/CLISimulatorResourceRuntime.swift`：host 执行与恢复。
- `Sources/TritonKitShared/`：profile、catalog、compatibility、receipt/evidence DTO。
- `CLIHostProcessRuntime.swift`：复用现有命令执行边界。
- `CLISchemaCapabilityContracts.swift`、plan/evidence models：机器可读契约。

## 风险与停止条件

服务目录随 runtime 演进；StoreKit、push、Universal Links 等能力可能被误伤。默认保持 stock；没有 runtime 兼容证据、变更前快照、读回验证或真实 dedicated Simulator 回归时，不进入自动 apply/fleet 阶段。

## 当前状态

实现中；尚未完成端到端验收，未执行真实 Simulator 变更动作。

### 2026-09-14 验证校正

- 上游 catalog 固定至 `f3b979ecd913f56904a9b6100cad1f84fe01d228`：15 categories、24 features、170 unique slimmable labels。
- `status` / `doctor` 已接 `launchctl print-disabled` 原生读取；新增 4 项 inspection 测试，明确 doctor 只检查服务 override，不代表业务功能验证。
- 原 RSS parser 单位错误已修正为 KiB × 1024，拒绝损坏/重复/负数和溢出；3 项测试通过。RSS 不作为 phys_footprint 收益证据。
- `measure` 改接 host launchd_sim 子树 + libproc `ri_phys_footprint`；6 项测试包括当前进程真实 libproc 采样、目标隔离、partial 和全失败。
- 先前全量测试通过不代表 mutation 闭环：现有 apply/profile/receipt 恢复仍需补目标绑定、真实 profile 解码、label 前态快照、完整命令退出码和读回验证。CLI `execute` 旧分发不能作为可用证明。
- replay 目前仅新增 action/metadata，真实执行仍未接通；evidence artifact 常量不等于文件落盘；fleet 与真实 Simulator 回归仍待实现。

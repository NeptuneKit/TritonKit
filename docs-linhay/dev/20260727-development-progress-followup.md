# TritonKit 开发进度 follow-up（2026-07-27）

> 本文续接 [2026-07-24 开发进度回顾](./20260724-development-progress-recap.md)，只记录其后在独立 worktree 完成的本地 checkpoint。它们均尚未合入 `main`、未推送、未发布；不得把本文写成对外可用性或可靠性结论。

## 当前结论

项目已完成一条可审计的本地候选执行栈：从 `main@931645ed` 出发，经 SP-126～SP-136 的串行 checkpoint 到 `feat/SP-136-ios-simulator-reliability-collection-preflight@16e5ec81`。审计时各 feature worktree 均干净；主工作区的既有文档 WIP 未被该执行栈修改。

产品方向已裁决为 **Hybrid**：

- `testrec`：录制、离线编译、质量/脱敏发现与兼容读取；不再扩张为第二个真实 executor。
- `test`：唯一真实测试执行、步骤 observation、evidence 与最终 verdict 入口。
- `workspace`：未来复用同一测试合同做 target / lifecycle / observation 编排；在可靠性门槛前不接入。
- `replay`：保持 `.tritonplan` 的低层 smoke / 验证能力，不吸收录制包或测试生命周期。

## 已完成的本地能力

| 范围 | 本地 checkpoint 的交付 |
| --- | --- |
| SP-127～130 | iOS 真机 terminate 在无可证 PID 时 fail-closed；real-device `xcode run` 先 target preflight、失败不触发 build；`serve` 无 `--host` 时默认 loopback；legacy runtime JPEG 在 CLI/evidence/replay/test-run 需要 PNG 时规范化为真实 PNG。 |
| SP-131 | `TritonKitTestFixture` 的手写 plan 已在 dedicated iOS Simulator 完成一次真实 `test validate -> test run -> evidence` 闭环：6 steps、2 assertions、0 failures。敏感 evidence 未入 Git。 |
| SP-132 | 新增 `triton test import <case>`：将已编译 `.tritontestcase` fail-closed 地导入可 validate 的 `.tritontest.yaml`，要求显式 bundle / `ios-simulator`，保留 typed provenance，并防止路径泄漏、source 写入和 output 覆盖。 |
| SP-133 | imported plan 在 dedicated iOS Simulator 经过既有 `test run` 获得真实 passed verdict/evidence，provenance 保留到 normalized plan；此证明仅覆盖一个 fixture，不外推为矩阵或跨平台承诺。 |
| SP-134 | 新增只读、脱敏 `triton test reliability --samples <private.json> --json`：对已有私有 evidence 计算 ECR / FER / ORR，并对 partial、重复、target/初态漂移和证据缺口 fail-closed。 |
| SP-135 | `testrec` dry-run、local-simulated 与 matrix 保留 wire compatibility，但明确 `verdictBoundary` 为 offline diagnostic，不能计作真实 verdict 或 reliability sample；迁移指向 import -> validate -> run。 |
| SP-136 | 新增纯离线 `triton test reliability-preflight --collection <private.json> --json`：冻结 3 条 imported iOS Simulator flow、每条 20 个 slot、canonical target/reset/negative-control 与 fresh evidence layout；输出不回显私有路径、UDID、bundle、selector 或可见文本。 |

## 验证与边界

- SP-132～136 的 focused importer、validation、test-run、reliability、schema/capability 和 failure-diagnostics 测试均已在各自独立 scratch 验证；SP-130、SP-132 含相应 release / 本地门禁记录。SP-136 最终 focused suites、release CLI/schema 与 docs gate 均通过。
- 广义 schema suite 仍有既有的 device/sim/network-proxy contract failures；它们未被误记为本栈通过，也没有在离线 reliability slice 中越界修复。
- #164 的 dirty evidence worktree 始终隔离、未读取或修改。SP-129 只收窄 bind 默认值，Bonjour publish/discovery 仍是独立风险。
- `ready_to_collect` 不是采样、reset、runtime 执行、evidence 写入或 gate pass。当前没有自动 3 flow × 20 harness、没有第二真实 `testrec` executor、没有该测试链的 Android/Harmony 扩张，也没有 Web/Wails 写控制面。

## 下一步与停止条件

在用户明确授权集成前，不合并这条本地候选栈，也不删除任何 worktree 或 branch。受控集成完成并通过适用门禁后，下一项才可以是独立的 live-harness space：显式专用 Simulator、self-managed `127.0.0.1:19421` server、逐样本 reset receipt、新鲜私有 evidence，并且严格串行采样。任何环境所有权不明、target 不匹配、server 已被外部占用或隐私处置不足，均应停止而非自动执行。

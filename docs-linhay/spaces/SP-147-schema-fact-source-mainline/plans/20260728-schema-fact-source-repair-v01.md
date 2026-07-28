# SP-147 Schema Fact Source Repair v01

日期：2026-07-28
状态：已完成（本地）

## 目的

以实际 ArgumentParser declaration 与现有 host DTO 为事实源，修复 `device` 和 `sim app-console` 的 CLI schema 漂移；不改变运行时行为或设备控制面。

## BDD 到测试

| 场景 | 失败测试 | 最小修复 |
| --- | --- | --- |
| device root 的 direct parser facts 可读取 | `deviceSchemaMirrorsDirectParserGroupsAndFacts` | 选项、argument form、direct child、output contracts |
| wait-ready 不把 flag 输入伪造成 positional input | 同上 | 删除 `<selector>` optional option，保留 `--device` / `--interval` |
| app-console 恢复路径可由 agent 直接执行 | `simAppConsoleRecoveryMirrorsActionableNextCommands` | 同一 action list 驱动 next/recovery commands |

## 事实映射

| Parser / DTO 事实 | Schema 合同 |
| --- | --- |
| `device --interval` 默认 `1` | root `--interval: Double = 1` |
| `device wait-ready --device ... --interval ...` | wait-ready 的 optional options 仅含真实 flags，不含 `<selector>` |
| `device alias/bridge/proxy/start/stop` 是 direct child | root subcommands 均可发现 |
| `HostDeviceDoctorOutput`、`HostDeviceArtifactOutput`、`HostRuntimeURLOutput` | 按 selector 暴露具体 model 与字段 |
| app-console 的 logs / re-output / evidence 处理序列 | next commands 与 recovery commands 同序，分类为 `prepare-target`、`prepare-target`、`archive` |

## 执行与验收

1. 使用 `CLI/.build/sp147-schema-fact-source-mainline` 创建隔离 scratch；focused tests 先红后绿。
2. 运行 `FailureDiagnosticsTests`，确保 schema 恢复命令不破坏 failure family 输出。
3. 通过生成的 `triton schema --json` + `jq -e` 读取真实命令合同，而非只检查 Swift 常量。
4. 执行 docs/diff 门禁；记录由不存在的 SP-142 至 SP-146 导致的连续编号 blocker，不创建占位目录。

## 非目标

- 不在本 schema 实现轨中承担 `CLIRuntimeTransport` 的实现所有权；并行 capability contract 子轨已将 wait-ready action 对齐为 `--device <selector>`。
- 不递归扩展 schema 模型以表示 bridge/proxy 更深层 hierarchy。
- 不启动 server、设备、Simulator、Xcode 或其他运行态操作。

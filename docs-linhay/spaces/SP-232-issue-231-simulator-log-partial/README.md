# SP-232 · GitHub #231 simulator log partial artifact

## 边界与状态

影响层：CLI host unified-log capture 与机器可读 schema。独立 worktree `../TritonKit-worktrees/SP-232-issue-231-simulator-log-partial`，分支 `feat/SP-232-issue-231-simulator-log-partial`，基线 `a0d187ac`。候选静态收口，等待主控统一构建验证；未提交、未合并、未发布。

修复 `triton sim logs` 子进程非零/信号退出后删除已有日志的问题。新 opt-in 捕获路径先独占创建 0600 artifact、每块直接落盘；`--max-bytes` 默认 10485760。超出上限继续 drain，返回失败并保留前缀。其他 host artifact 默认行为保持原实现，不改变 app-console/截图/动作/设备状态。

## BDD

- Given 已写 stdout，When exit 7 / SIGKILL / timeout / 输出未到 EOF，Then 保留文件和实测 byte counts，返回非零退出与单个 `ok:false, partial:true` envelope，包含路径、截断、上限与终止分类，不自动重放。
- Given 输出超过 byte cap，When 流继续写，Then 磁盘文件不增长，继续排空 stdout/stderr，不把截断报为完整成功。
- Given 目标文件已存在或为 symlink，When capture 开始，Then 启动进程前拒绝，不覆盖、不删除既有文件。
- Given 日志含私有正文，When 生成 JSON，Then 只发计数和元数据，不内联 native stdout/stderr；文件为 0600。
- Given capture 正常完成，Then 成功 envelope 与 unified-log 来源保持兼容，并补 retained bytes、limit 与 partial=false。

## 验收与证据

- `HostProcessDrainTests`：原三 runner 对照、signal/timeout/private artifact、继承 pipe 失败后的 partial 保留。
- `SimulatorLogCaptureTests`：真实自有 shell 的一次完整 JSON、signal/timeout/exit/byte-limit、独占路径/权限、大输出有界 drain、进程结束前增量落盘、参数默认值/覆盖/非法字符串。
- 首轮 red test 在依赖编译阶段因全局负载按主控协调停止（exit 130），测试未执行；不能把静态推断写成红测证据。后续 focused/full 与 native 后端限流由主控统一进行。
- `git diff --check` 通过。`check-docs.sh` 因独立基线缺 SP-228～231 登记而失败；未伪造同批其他 space 绕过门禁。
- [验证报告](plans/20261028-validation.md) 包含原始日志位置、候选差异 hash、未验证范围。

## 风险与下一步

没有实际 Simulator capture/shutdown、长时日志或设备运行验收；未恢复已经丢失的历史日志。文件可能为空或以半行结束。增量写入不承诺断电持久化、外部路径替换后的恢复，文件系统同步 IO 不受 pipe deadline 硬截止约束。主控验证完成前不得关闭 issue 或宣称交付完成。

## 经验写回

本轮可复用结论已补到 host-simulator skill 与日志 CLI/public skills：失败产物必须保留并独立标明 incomplete/byte-limit，文件存在不等于捕获成功。SwiftBuild 并发负载只记现场事实，待主控验证 native 限流后再决定是否提升为治理规则。

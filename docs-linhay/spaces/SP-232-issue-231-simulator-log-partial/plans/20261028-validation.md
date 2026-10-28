# #231 验证记录

> 历史冻结记录。当前整合、测试结论及未验边界见[SP-241联合验收](../../SP-241-open-issues-validation/plans/20261028-validation.md)。下文中断/待验描述只对应当时的独立分支。

## Requested
日志子进程失败后不能删除此前已观测的数据；机器可读失败必须包含产物与不完整来源。

## Observed
旧 `runHostCommandWritingStdoutArtifact` 流式落盘，但非零退出和 drain 失败后删除文件。初始中断候选只处理非零/pipe 错误，未处理 timeout 元数据，也未限制磁盘体积；默认创建权限为 0644。真实 Simulator shutdown 原因未知，本切片不归因。

## BDD
1. stdout 已写、子进程 exit 7 或 SIGKILL：保留 bytes，ok=false/partial=true，返回稳定原因和真实 terminationReason。
2. 超时：终止仅本次启动的进程，保留有界文件和 timeout provenance，不自动重放。
3. 超出 byte cap：继续 drain，磁盘文件不增长，观测 bytes 与保留 bytes 分别返回，截断不冒充完整成功。
4. 已存在文件或 symlink：启动前拒绝，不覆盖，不删除既有文件。
5. stdout/stderr 含敏感文本：JSON 不内联原文，产物创建权限 0600。
6.正常完成：单一合法成功 JSON，source 仍仅 unified-log。

## Evidence
- 首次红测命令：`swift test --package-path CLI --scratch-path .build/issue231 --jobs 2 --no-parallel --filter 'HostProcessDrainTests/(partialLogPrivacy|partialLogTimeout)'`。
- 在依赖构建 1196/1688 阶段按主控协调停止，退出 130；测试未开始，不算红测通过或已复现。原始日志保留 `/tmp/triton-issue231-red.log`，红测源码差异保存 `/tmp/triton-issue231-red-candidate.patch`（SHA256 `8a258d1e2563132115e7abb5878f46a46e67ac068bad583422a5d471b04e1123`）。
- 本机 `swift test --help` 显示当前默认 `--build-system swiftbuild`；多项 `--jobs 2` 测试同时编译时，宿主 load average 曾到 318。这证明本轮调度实际失控，不足以单独归因 SwiftBuild 实现忽略参数。建议主控统一编译窗口，并验证显式 `--build-system native --jobs 2` 的实际进程并发后再沉淀为规则。
- `check-docs.sh` 失败于 `space registry IDs must be contiguous from SP-001: SP-232-issue-231-simulator-log-partial`：独立基线只有 SP-001～227，本 worktree 只登记自身 SP-232；待主控合并兄弟 issue 的登记，不通过伪造其他 space 绕过门禁。
- 新候选待编译窗口，未宣称 tests pass。

## Remaining risk
未启动/关闭任何 Simulator，未恢复 issue 中已丢失的历史日志；fake process 仅证明宿主捕获边界，不证明长时 simctl/iOS 运行稳定性。产物每块直接写入文件，不提供断电后持久化或被外部恶意删除后的恢复保证。

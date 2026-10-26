# SP-222 冻结候选联合验收

> 历史阶段说明：本文为联合候选 `4249bd26` 的独立验收快照，测试数量和hash保留原阶段含义。后续实际main合后门禁、归档及清理已完成，见[主线验收与清理](20261026-main-merge.md)；下文root后续职责为当时交接，不是当前待办。原ignored日志已归档，原路径仅用于关联清单中的历史hash。

## Requested / Observed

仅对同一精确 UDID 的 CLI `print-disabled system` 读取，在明确 launchd 暂态时有限重试。唯一生产变更为 state reader；两个测试文件为 state 覆盖与 mutation fixture 来源对齐，未改变 HTTP/shared/Web/schema。执行源 `eb9539f48df4ea6a0e1cf3de6828b8d8177c8017`，文档基线 `f0159b483fec90756f8a2d3361c7e8007a2f1010`；联合测试提交 `4249bd264ddc0e1745e414187dbfa51e05e0bcf9`，tree `3a1e130ef0f3af4b144ad4072fbeec67f984661c`。本报告后续自身文档提交不改变产品文件。

执行源相对 `24e7d0f2` 只含生产一个文件、测试两个文件及 SP-221 文档；联合分支额外只含本 space 审查文档。三个实现/测试文件与执行候选逐文件 SHA256 相同，详见[证据清单](20261026-evidence-manifest.json)。SP-221 README add/add 人工保留最新实现边界、红绿证据、真实 thread 和 root 最终职责，未改功能。

## Evidence

环境为 macOS27.0.1 arm64、Apple Swift6.4。所有测试在同级 SP-222 隔离工作树执行，`CLI/.build` 从已停止写入/编译的执行工作树以 `cp -cR` 复制，source/target workspace-state inode不同；不共用可写 scratch。路径迁移触发重新编译，未安装升级依赖，Package.resolved/manifest未变化。显式 `TRITON_CLI_PATH=$PWD/CLI/.build/debug/triton` 绑定本候选构建二进制，hash见清单。

- 红证据复核通过：源 `red.log` hash `df9011968baa4f55a24f3e35afcc0c9dc564b29addb224dcdfbec6d5ca2e5a5d`、精确红测试快照 `92ff557d81ce548444c5978e95d65bb55264a0d627e2bca387bdc7c4c63cc264`、基线生产 blob `68ca59a1fe49f8a715c1d88aee6d82ea749080dfb9b02f53c7510f0076760318` 均吻合。真实断言失败为只调用一次、暂态直接失败、stderr截断未拒绝；10项3失败（1unexpected），exit1，非编译失败/exit130。此处为复核既有原日志，未回退工作树重跑旧实现。
- 执行绿日志 hash `6b159020707f68cc4a35e2d40bcc8b3faabe3b0ba4af4f6ab9ef47648300532a` 与37项零失败吻合。
- 独立 focused：`TRITON_CLI_PATH="$PWD/CLI/.build/debug/triton" swift test --package-path CLI --no-parallel --disable-automatic-resolution --skip-update --filter 'SimulatorResource(State|Mutation)Tests'`；exit0；37 XCTest（State29 + Mutation8），零失败，10:31:29 +08:00结束。原日志 `plans/focused.log` ignored。
- 完整 CLI：相同环境与命令去掉 `--filter`；exit0。XCTest最终91项零失败；Swift Testing最终报告1515项/153 suites通过，明确3项跳过。focused包含于完整回归，不能相加；日志中每suite重复计数不相加。原日志 `plans/full-cli.log` ignored。
- 跳过：`selectedXcodeProducesRealJPEGAndBalancesTwoSubscriptions` 需要显式 `TRITON_SP196_OWNED_SIMULATOR`；两个 Real NetService 用例需要 `TRITON_TEST_BONJOUR=1`。本批不启用这些真实运行条件，不将跳过称通过。

文档验收：在上述联合候选及本报告/清单上，`verify.sh --ci-docs`、`check-docs.sh`、`git diff --check` 与相对 `f0159b48` 的候选 whitespace 检查均 exit0；222 spaces。日志原位于本space ignored plans目录，已在清理前归档，现按主线记录定位。门禁仅证明相应文档/脚本契约，不升级为发布或设备验收。

## Gaps / Fixes made

两项首次审查问题已在最终候选关闭：暂态诊断从substring改为完整行白名单，并补复合永久/unsupported/unrecognized/header冲突反例；成功分支增加sourceCommand绑定并补错来源成功反例，同时允许合法非空stderr。旧 mutation fixture 仅按 root 单行授权对齐来源，未放宽产品guard/断言。最初冻结66adfbde的tracked原patch与handoff声明不一致且有whitespace错误，执行补文档提交eb9539f4移除，最终相对基线diff --check通过，产品hash完全不变。SP-222未修改生产或测试文件。

## Remaining risk / 结论

本报告在独立候选阶段判离线契约验收通过；后续root已完成实际main集成及合后门禁，见主线最终记录。SP-222未执行root tests/local gate，这些由root单独验证；本报告自身的证据范围不扩展为发布、安装接替或用户场景验收。

暂态样本来自上游文本及离线fixture，typed throw覆盖生产错误类型，但未在本机实际launchd故障中复现；不证明真实Simulator恢复概率、跨进程状态稳定或原生诊断的所有版本兼容。未知诊断形状保持fail-closed。30秒是runner配置执行预算，终止/kill/drain可能额外耗时，非硬墙钟上限；同步在途Process不会由本层Task取消立即结束，取消证明返回后不再重放。mutation保持单次调用与现有恢复语义。未执行真实Simulator/设备/跨进程竞态、第三方参考代码、依赖升级、签名/DDI或远端写入。

经验已沉淀在本space和执行space原权威入口：真实nonZeroExit与返回值分开验证、完整诊断/命令身份绑定、收紧契约修fixture而非放宽guard、预算和清理分层、冻结SHA必须核对实际tracked文件而非handoff文字。共享skill/dev/memory由root收口，SP-222不越权修改。

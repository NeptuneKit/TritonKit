# SP-221 候选交接（2026-10-26）

## Requested / Observed

CLI-only 局部只读 launchd 暂态有限重试；HTTP/shared/Web无新增契约。已实现最多3次、30秒配置执行预算、0.1/0.2秒退避、每次剩余timeout、同UDID/argv；精确完整诊断白名单与命令/结果来源绑定；严格拒绝截断/畸形/权限/未知错误/timeout；取消阻止后续重试，mutation保持single-shot。

基线 `24e7d0f21017c8ca7104b6f8e3912fc2c44be892`；分支 `feat/SP-221-simulator-resource-read-retry`；worktree `/Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-221-simulator-resource-read-retry`。冻结候选为包含本文的本地提交，完整SHA见会话交付和 `git log -1`。不执行main合并或远端写入。

## 文件清单与实现diff

- `Sources/TritonKitCLI/CLISimulatorResourceState.swift`：唯一生产实现文件，reader内部局部重试/严格判别/预算与取消。
- `CLI/Tests/TritonKitCLITests/SimulatorResourceStateTests.swift`：保留原7项，补22项（多情景循环）；覆盖真实runner形式的nonZeroExit和返回结果、完整错误命令绑定、成功sourceCommand、严格诊断、预算/取消/截断/畸形/权限/任意throw、apply/restore mutation不重放。
- `CLI/Tests/TritonKitCLITests/SimulatorResourceMutationTests.swift`：root追加授权，仅一行 fixture sourceCommand 改为 hostSourceCommand(command)，其余语义/断言不变。
- 本space README、本交接、红测试摘要与精确首轮测试快照。未动共享INDEX/路线/memory/adoption-state。

产品实现diff保存在 `plans/implementation.patch`；候选提交的 `git show -- <上述三文件>` 提供可持久复查的同一差异。原始red/green/mutation-fixture-failure/docs-check日志保留在plans目录（ignored，不混入候选）。

## Evidence

- 红：`swift test --package-path CLI --no-parallel --disable-automatic-resolution --skip-update --filter SimulatorResourceStateTests`，exit1，10项/3失败（1 unexpected）。详见[首轮红证据](20261026-red-evidence.md)。首轮测试快照hash与实际红测文件完全相同，可将其与基线生产blob离线复现；exit130中断不计。
- 最终绿：`TRITON_CLI_PATH="$PWD/CLI/.build/debug/triton" swift test --package-path CLI --no-parallel --disable-automatic-resolution --skip-update --filter 'SimulatorResource(State|Mutation)Tests'`，exit0，37项（State29 + Mutation8）/0失败，2026-10-26 10:26:22 +08:00。早先28/33项绿色均被后续候选取代，不累加。
- 中间失败：收紧成功sourceCommand后37项中4个旧Mutation用例抛commandFailed，State29全部通过；归因为固定fixture字符串而非生产来源。获root明确追加单文件单行授权，修正fixture后最终37项通过；未放宽产品guard。
- `git diff --check`：通过。
- `docs-linhay/scripts/check-docs.sh`：exit1，`space index must contain exactly one link for SP-221-simulator-resource-read-retry`。执行基线无SP221共享登记，本任务禁止修改共享索引；SP222主控以最新文档基线整合后重跑，未绕过检查。
- 完整CLI、root、local gate：本会话未执行，交主控串行；未执行设备、依赖安装升级、签名/DDI、第三方参考代码、远端写入、merge main。
- 环境：Apple Swift6.4 / Darwin27 arm64。仅复用已有离线依赖缓存，未修改Package.resolved/manifest，无新增依赖。

## Remaining risk / 沉淀

30秒为runner配置执行预算；原host runner terminate/drain清理可能额外耗时。同步在途run不由本实现主动取消，取消可在返回后阻止重试；退避按不超过10ms间隔检查。仅支持README明确完整诊断行，未知额外上下文失败，扩展须有实际捕获与负例。离线fixtures不证明真实Simulator恢复概率、系统竞态消除或设备验收。

本轮经验已写回space README：真实nonZeroExit路径不可被fake返回值替代；诊断须完整匹配而非substring；来源契约收紧同步对齐fixture，不能放宽生产guard；配置预算与清理耗时分层。共享skill/memory/索引由主控整合，当前没有越权写入。

## SHA-256

- `Sources/TritonKitCLI/CLISimulatorResourceState.swift`: `b7d7bd138da022866d999f7c1e3514a07ae03fdeb63b9ffe54a7b2e249133414`
- `CLI/Tests/TritonKitCLITests/SimulatorResourceStateTests.swift`: `284f38f8bc1d2d149bfa8be7a3b68f5838742410e02b17fc78aa0272af776a2d`
- `CLI/Tests/TritonKitCLITests/SimulatorResourceMutationTests.swift`: `e51de9aabf609ca899d52202ae2c5e4de84cca59113a9e893fba0488cb49911b`
- `docs-linhay/spaces/SP-221-simulator-resource-read-retry/plans/implementation.patch`: `2be677fcc59fbb3c9e3e94570d2433327cf163688f04e6dc83b68844a8fc0a45`
- `docs-linhay/spaces/SP-221-simulator-resource-read-retry/plans/red.log`: `df9011968baa4f55a24f3e35afcc0c9dc564b29addb224dcdfbec6d5ca2e5a5d`
- `docs-linhay/spaces/SP-221-simulator-resource-read-retry/plans/green.log`: `6b159020707f68cc4a35e2d40bcc8b3faabe3b0ba4af4f6ab9ef47648300532a`
- `docs-linhay/spaces/SP-221-simulator-resource-read-retry/plans/mutation-fixture-failure.log`: `54594fa413fbe472a36afe44f44470548079f3ac9b8d68d221bf98887bf77ed4`
- `docs-linhay/spaces/SP-221-simulator-resource-read-retry/plans/docs-check.log`: `9f50914b2fb7bffee0b0c43ce4295e7e0e0d83b83067661bcd41d0bfd9d6e94e`
- `docs-linhay/spaces/SP-221-simulator-resource-read-retry/plans/20261026-red-tests.swift.txt`: `92ff557d81ce548444c5978e95d65bb55264a0d627e2bca387bdc7c4c63cc264`

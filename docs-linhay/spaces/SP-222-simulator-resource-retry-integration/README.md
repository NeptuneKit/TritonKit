# SP-222 — Simulator资源只读重试主控

## 范围与授权

只负责[SP-221](../SP-221-simulator-resource-read-retry/README.md)候选审查、独立验收、本地main合并与清理。沿用用户参考自动采用及开发验证后合main授权；执行/主控新会话必须显式model=gpt-6.1-sol，不回退，不伪造thread。产品基线24e7d0f2；未授权设备、依赖、签名/DDI、remote写入。

## 验收与文件面

主控拥有本space验收文档，不与执行同时修改生产文件。核对候选SHA/diff、先红后绿、真实runner非零throw路径、精确argv与同UDID、有限预算与取消/权限/截断/畸形不重试、mutation不重放；focused和完整CLI串行，通过后适用root/docs/local门禁。真实设备未执行单列。

合main前确保实际main干净，merge-tree预检；候选只包含SP-221文件面，原追踪文档独立必要本地归档提交不得混入产品候选。主控审查通过才合main，合后重跑受影响完整门禁，回写source/merge SHA、检查点与索引；归档ignored证据后正常清理已合worktree/branch。不push/tag/release。

状态：主控已创建并基线审查；真实thread `01a175fd-5c91-7b52-bc7c-683468efff9f`，branch `feat/SP-222-simulator-resource-retry-integration`，worktree `../TritonKit-worktrees/SP-222-simulator-resource-retry-integration`。执行真实thread `01a175fc-c9c4-7053-b91e-74c209d3f0ca`；两会话均显式gpt-6.1-sol创建成功。等待执行先红后绿和冻结候选，尚未验收或合并；本space不无限承接后续批次。

## SP-222 隔离审查记录

## 范围与状态

2026-10-26，有限主控仅审查 SP-221 的 CLI host `print-disabled` 读取重试。产品基线 `24e7d0f21017c8ca7104b6f8e3912fc2c44be892`。本会话只拥有本 space 文档；不修改产品、共享索引、memory、adoption-state 或 main。原主仓中的 SP-221/SP-222 README 为只读需求来源。

状态：已完成基线静态检查，等待 root 提供冻结候选及验证交接。实现、验收、合并与清理均未完成。root 负责实际 main 干净检查、merge-tree、本地合并、合后门禁及清理；本审查不替代最终 DoD。

## BDD 与审查门禁

- 同一有效 UDID 的精确 `xcrun simctl spawn <UDID> launchctl print-disabled system`，遇到明确 launchd 暂态才可有限重试；成功必须通过严格 payload parser。
- 同时核对返回非零 result 与生产 `HostCommandRunError.nonZeroExit(command,result)` 路径；命令、目标或其他命令属性不匹配不得重试。
- stdout/stderr 截断、权限/永久错误、畸形/重复 payload、timeout、取消及任意其他 throw 必须保持失败，不能重试成成功。
- 次数与总预算分别有界；各次 command timeout 和等待受剩余预算约束。runner 的终止清理开销需明确，不能将配置预算声称为严格墙钟上界。
- apply/restore 的 enable/disable/boot 等 mutation 不自动重放，现有三方恢复边界保留。
- 候选冻结后核对实际 diff、SHA、文件摘要和红绿行为证据；focused 后完整 CLI 串行执行，并绑定本候选 CLI 二进制。完整测试前先确认执行者已释放测试入口。

## 基线证据

- `LiveSimulatorResourceCommandRunner.run` 直接调用 `runHostCommand`。
- `runHostCommand` 在非零退出或语义失败时抛 `HostCommandRunError.nonZeroExit`，不会将该结果正常返回给 reader。只在返回值上增加循环会漏掉生产路径。
- 当前 `readOverrides` 校验 UUID 后只调用一次 runner，拒绝非零退出与 stdout 截断，随后严格解析；尚未覆盖 stderr 截断。
- mutation 在 `CLISimulatorResourceRuntime.runChecked` 中串行执行，不能将重试扩大到通用 runner。
- `TKHostCommand` 默认 timeout 为 30 秒；`runHostCommand` timeout 分支另有进程终止、kill 和 drain 清理等待。审查需区分预算控制与真实进程清理上界。

本轮截至静态检查只运行 Git/源码读取命令，未执行产品测试、Simulator、真实设备或跨进程竞态，不操作依赖、签名、DDI、第三方代码及远端写入。来源需求称此为静态可靠性差异，本机真实故障未复现。

## 审计记录

- Requested：仅对明确 launchd 暂态实施同目标、有限预算的只读重试。
- Observed：基线没有重试；生产 runner 非零退出以 typed throw 表达。
- Evidence：本工作树基线 SHA、资源 state/runtime 与 host runner 源码；候选证据待交接。
- Gaps：未收到冻结候选、红绿日志及完整验证执行权，不能判验收通过。
- Remaining risk：离线测试不能证明真实 launchd 恢复概率、设备状态或跨进程竞态安全。

经验检查已按 EXPERIENCE 的候选证据与跨会话审计主题完成；当前未发现超出现有治理规则的新经验，基线边界记录于本页。共享经验入口由 root 收口，未在此修改。

## 交接前检查结果

- root 已确认执行 thread `01a175fc-c9c4-7053-b91e-74c209d3f0ca`，候选尚未冻结；root 已将本工作树正常迁移到同级 `TritonKit-worktrees/SP-222-simulator-resource-retry-integration`，后续 shell 显式绑定该路径。候选和验证时段仍待提供。本工作树分支为 `feat/SP-222-simulator-resource-retry-integration`，仅本 space 未跟踪文档，未创建提交。
- 执行会话完成快照显示：生产代码未改，focused 构建中止，退出 130，无有效红测试证据。因此该快照只证明待交接状态，不构成候选或验收通过。
- `verify.sh --ci-docs`：失败，`space index must contain exactly one link for SP-222-simulator-resource-retry-integration`。
- `check-docs.sh`：同一索引缺项失败。本工作树基线未包含原主仓新增索引；遵照权限不修改共享索引，也不降低校验要求。
- `git diff --check`：通过；新增文档尚未进入 Git diff，后续正式接收文档后需重跑并复核实际文件。
- CLI focused/full、根包、local、真实 Simulator/设备/跨进程验收：均未执行；候选与测试时段尚未交接，不抢占执行者构建。

## 候选前方案审查

root 提议沿用原 30 秒读取预算、最多 3 次、0.1/0.2 秒短退避；方向符合本次只读边界，实际常量和行为待冻结候选核验。抛出的 nonZeroExit 必须与当次 issued command 完整匹配（包括该次剩余 timeout），不能只比 UDID 或 sourceCommand 字符串。124 必须结合明确 launchd_sim/tearing-down 上下文，不能仅凭退出码或宽泛关键字重试。已存在 payload、权限错误或截断时不能被暂态标记掩盖。

迁移前索引门禁失败为文档基线不齐，不是产品验收失败；root 将提供必要已提交文档基线，届时按新候选重跑 docs-only。执行者迁移前中止构建是历史状态；当前已获 focused 时段，该历史记录不构成本批阻塞。未创建额外 probe 或新会话。

## 未冻结候选首次审查

只读对象为同级 SP-221 工作树当时未提交的两文件差异，HEAD 仍为产品基线；未运行测试。读取期间执行者仍可写入，以下摘要只标识本次观察，不作为冻结凭证：state SHA256 `82011a3077d9ca9bc242aa83ca241a6281209778a1264f4c8242aa26550014db`；tests SHA256 `253b2386913f6919f15e8c1dea95b39f3057c96be402e53c97a4c94609caab3e`。

- Bug：暂态分类使用 `contains`，单凭 `Domain is tearing down` 或 exit124 加 `Failed to start launchd_sim:` 即可通过；例如 `Unrecognized command: Domain is tearing down`、`Domain is tearing down: unsupported operation` 或 launchd124 与 unsupported 复合文本仍会重试。权限短语黑名单不足以证明明确暂态。建议严格诊断形状或显式排除复合永久错误，并补返回/抛错两路径反例。
- Verification miss / 绑定缺口：成功 exit0 分支未检查 `sourceCommand`，不同来源命令的合法 payload 可被接受。建议成功分支也精确绑定并补 mismatched-success 测试；成功 stderr 非空本身不需要拒绝。
- No issue（静态）：30 秒配置预算、最多 3 次、0.1/0.2 退避、剩余 timeout、typed throw 完整命令相等、stdout/stderr 截断拒绝及 mutation 独立单次调用已在差异中可见。
- Remaining risk：真实 runner 的 terminate/kill/drain 有额外清理等待，30 秒不能声称严格墙钟上界；真实 launchd 恢复概率与跨进程竞态未验。

以上已反馈 root，未直接修改实现。审查意见待执行者修订及红绿证据后复核，不判通过。

root 已接受首次审查的两项修正建议并交执行者处理；候选尚未冻结，以下首次审查问题保留为历史待复核记录。

## 文档基线整合

已按 root 指令创建仅本 space 的审查提交 `86744ec3`，再在隔离分支正常合入 `main@19fed414f74ec6723be02240e002402171af86ac`，整合提交 `aba285e7`。唯一 add/add 冲突位于本 README，人工保留 main 授权/最终职责与本会话具体审查记录；未改产品或实际 main。

整合后 `docs-linhay/scripts/verify.sh --ci-docs`、`docs-linhay/scripts/check-docs.sh`、`git diff --check` 均通过（222 spaces）。迁移前索引缺项已随已提交文档基线解决，不再是当前阻塞。main 仍可能被 root 后续推进，最终整合应仅吸收本 space 审查差异，不能以本分支的旧共享资料覆盖后续 main。

当前等待修订后的冻结候选及完整 CLI 串行时段；本轮未执行产品测试。后续应将首次审查问题逐项标记为已修复/仍缺口，而不能删除历史失败路径与证据。

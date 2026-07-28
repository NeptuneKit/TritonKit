# SP-151 Trusted Baseline Integration

## 状态

- 状态：已完成（仅本地 integration checkpoint，未进入 `main`）。
- Branch：`feat/SP-151-trusted-baseline-integration`。
- Worktree：`../TritonKit-worktrees/SP-151-trusted-baseline-integration/`。
- 基线：`main@d2578089`。

## 目标与边界

将已审计的本地 checkpoint 收敛为一个可验证的本地 integration 候选：

- `SP-142`：`triton web` / `/web/*` 严格 readonly，Web 自管 `serve` 保持 loopback。
- `SP-143`～`SP-146`、`SP-150`：receipt-backed Stage 1 reliability 的完整性、anchor、identity chain、指标与 terminal failure/recovery 语义。
- `SP-147`～`SP-148`：schema fact-source 修复与完整 `<canonical>` argv placeholder。
- `SP-149`：runtime screenshot normalizer 错误与 test-run published PNG metadata 合同。

不包括：修改 `main`、push/PR/merge remote、tag/release、删除现有 branch/worktree、#164 WIP、testrec/Android/Web 控制面扩张、服务/Simulator/Xcode/设备或真实 `triton test run`。

## BDD 验收

1. Given 已发布的 SP-141 曾提供浏览器输入桥，When 集成 SP-142，Then 浏览器写路由统一返回单一 405 readonly JSON envelope，旧 bridge 与其测试不残留，CLI/通用 HTTP 控制面仍保留。
2. Given receipt-backed reliability 候选，When report/sample 被评估，Then legacy evidence 不能通过 Stage 1，receipt anchor、identity chain、Stage 1A/1B 与 terminal failure type 都 fail closed。
3. Given schema 的 `reliability-sample` 模板，When 生成机器可读 schema，Then receipt anchor 必填且 canonical target 是一个完整 argv token：`--target <canonical>`。
4. Given screenshot 来源包含 JPEG、无效 payload 或正常 PNG，When serve/test-run 发布截图，Then正常 PNG metadata 与 stable error envelope 均不丢失、不伪称成功。
5. Given 候选完成合并，When 跑离线 focused test、release CLI build、docs gate，Then 不启动 Triton server、Vite dev server、Simulator、Xcode、设备或 real test run，且 registry 连续登记 SP-001 至 SP-151。

## 集成顺序

1. `feat/SP-142-web-readonly-contract`
2. `feat/SP-150-reliability-failure-recovery-semantics`（包含 SP-143～146 线性链）
3. `feat/SP-148-schema-placeholder-tokens`（包含 SP-147；人工保留 receipt anchor 并替换 canonical template）
4. `feat/SP-149-issue-166-evidence-metadata-contract`
5. 重建 docs registry、overview、memory 与本 space 状态，完成离线验证后创建唯一 local checkpoint。

## 已知集成点

- SP-142 与 current main 在 `CLIWebRuntime.swift` 冲突；以 strict readonly 为准，删除已废弃的 browser input bridge 及对应的 SP-141 bridge unit tests，但保留 screenshot/hierarchy/log/MJPEG 等只读桥。
- SP-148 与 reliability chain 共同修改 `CLISchemaTestCommands.swift`；保留 `--expect-receipt-sha256`，只把两个 runtime target example 收敛为 `<canonical>`。
- 所有 branch 的 `INDEX.md`、spaces overview 和 2026-07-28 memory 必须人工重建为真实并集，不能用占位目录或重编号历史 SP-141。

## 验证计划

- Swift：Web、serve/evidence、schema/failure diagnostics、reliability focused suites；使用 SP-151 独立 scratch 串行运行。
- Node：readonly contract 测试和 `npm run build`；不启动常驻 dev server。
- CLI：release `triton` build 与只读 schema projection。
- Docs：`git diff --check`、`docs-linhay/scripts/check-docs.sh`、`docs-linhay/scripts/verify.sh --ci-docs`。

## 集成结果

- 本地 merge commits：`a8d3af00`（SP-142）、`cfff575a`（SP-143～146/150）、`ce7856c0`（SP-147～148）、`c40c82b9`（SP-149）。所有冲突均在本 worktree 解决，`main` 与 #164 WIP 未改。
- 收口清理：确认 SP-142～SP-150 的 source commits 均为本 branch 可达祖先、各 source worktree clean 后，已用非强制方式回收这些 source branch/worktree；SP-151 是唯一保留的 integration candidate，`main` 和 #164 WIP 均未改。
- 预合并审计：在精确基线 `main@d2578089`，SP-151 的 merge-base 也是该提交，三树冲突预检无冲突，故技术上可 fast-forward；但本轮未写入 `main`，仍等待用户的明确本地合并授权。`main` 当前仅比 `origin/main` 领先 2 个本地提交，未 push。
- 历史 ref 审计：6 条无 worktree 分支都不是 `main` 或 SP-151 的可达祖先，因此本轮不强制删除。前 5 条分别有已在 `main` 的语义等价替代（`e95c9f95`、`e0c4cc4e`、`99daebea`、`0ceb825c`、`e4c5e5ef`）；旧 SP-141 schema 由 SP-151 内的 `98110f60` 重写替代、尚未单独进入 `main`，应随 SP-151 的保留/整合决策一起处理。
- Swift focused：`WebCommandTests|SingleDeviceWebPageTests|ServeCommandTests|ObservationOutputTests|TestRunExecutionTests` 共 81 项通过；reliability/schema/diagnostics 相关 187 项通过。两组都复用本 worktree 独占 scratch，且未监听端口。
- Web：readonly/loopback static tests 21 项通过，`npm run build` 通过；Vite 仅报告既有的大 bundle 体积提示。为测试安装的 lockfile 依赖仅在忽略的 `Web/node_modules` 中，`npm audit` 报告 2 个既有依赖漏洞，未自动升级依赖。
- Release：`swift build -c release --product triton` 通过；release `triton schema --command test --json` 证明 `--expect-receipt-sha256` 与 `--target <canonical>` 同时存在，旧的拆散 target placeholder 不存在。
- Docs：`check-docs.sh`、`verify.sh --ci-docs`、`git diff --check` 均通过，registry 连续登记 `SP-001`～`SP-151`。

## 后续边界

- 本地 integration checkpoint 不是 `main` 合并、推送、PR 或发布；本地 fast-forward 已完成冲突预检，但仍需新的明确授权，且授权后必须在 `main` 串行重跑匹配门禁再收口 SP-151。
- 真实 3×20+1 sampling 仍必须取得独立的 dedicated Simulator、server ownership、reset、negative control 与私有 evidence 生命周期授权；本 space 没有启动或探测真实环境。

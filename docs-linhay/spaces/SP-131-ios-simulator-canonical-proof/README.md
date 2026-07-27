# SP-131 iOS Simulator Canonical Proof

> 状态：已归档（本地 checkpoint）
>
> Branch：`feat/SP-131-ios-simulator-canonical-proof`
>
> Worktree：`../TritonKit-worktrees/SP-131-ios-simulator-canonical-proof/`
>
> 基线：`feat/SP-130-issue-166-runtime-jpeg-normalization@a7404033`

## 目标

把既有 `TritonKitTestFixture` 和最小 `.tritontest.yaml` 变成当前机器可重复的 canonical iOS Simulator proof：`test validate` 的离线合同、已连接 Debug embedded runtime 上的 `test run`、以及可审计 `.tritonevidence` 必须形成同一个事实闭环。

这不是 `testrec` importer，也不是新的 runner、Android adapter、Web/Wails 控制面或真机测试。SP-126 的 Hybrid 裁决保持不变：只有在这条已手写的 canonical 路径有当前机器证据后，才进入 `.tritontestcase -> test import -> test validate`。

## 边界与隔离

- 只使用仓内 `Examples/TritonKitTestFixture` 的 Debug embedded runtime 和专用 iOS Simulator；不借用用户业务 App 或已启动的共享 Simulator。
- 只在此 worktree 写入 plan、BDD、文档、memory 和必要的 focused regression；每次 Swift build 使用本 space 的独立 scratch。
- #164 dirty evidence WIP 继续只读隔离：不读取、修改、合入、cherry-pick、reset 或删除。SP-131 不改变 host/full-screen 与 runtime App-layer screenshot 的既有语义。
- `triton serve` 只可显式绑定 `127.0.0.1:19421`，在 proof 完成后停止；不启用 Web/Wails、Bonjour 验证、真机、Android 或 Harmony。
- 不 push、PR、merge、tag、release、关闭 issue 或删除 worktree/branch。

## BDD

1. **离线合同**
   - Given `fixtures/canonical-login-home.tritontest.yaml`。
   - When 运行 `triton test validate ... --json`。
   - Then 返回 `ok=true`、`triton.test.normalized-plan`，且不连接 runtime、不创建 evidence。

2. **真实最小执行**
   - Given 专用 Simulator 已由 `triton sim list --json` 发现，Debug `TritonKitTestFixture` 已安装、启动，且 `triton list --json` 以 bundle ID 与 Simulator UDID 双重匹配确认 connected runtime target。
   - When 运行 canonical plan 的 `triton test run ... --evidence-dir <dir>.tritonevidence --json`。
   - Then run 依次完成 fixture target 绑定、before observation、`Fixture Login` AX assertion、runtime-point tap、after observation、`Fixture Home` assertion，并以 `passed` 收口；不得把动作 ACK 或 simulated 结果当作通过。

3. **证据诚实性**
   - Given 上述真实 run 成功。
   - Then evidence 含 normalized plan、runtime target、run events、before/after screenshot 与 assertion result；截图 scope/fidelity 保持现有 capture contract，不能把 App-layer 图像误称为 host-composited proof。

4. **失败不伪通过**
   - Given runtime/server、fixture binding 或 assertion 不满足。
   - Then 记录单一机器可读失败 / partial evidence 和 recovery；不静默重试、不启动第二执行器、不生成 passed verdict。

## Canonical fixture

- App：`Examples/TritonKitTestFixture`，bundle ID `com.neptunekit.tritonkit.testfixture`。
- Flow：`Fixture Login` → `Go Home` → `Fixture Home`。
- Plan：[`fixtures/canonical-login-home.tritontest.yaml`](./fixtures/canonical-login-home.tritontest.yaml)。它固定使用已验证的 runtime-point；如果本机实际坐标发生漂移，先记录 fail-closed 证据并修正 fixture，不以隐藏 retry 掩盖。
- 历史对照：`docs-linhay/spaces/20260620-vlm-test-runner/p0d-fixture-pass.tritontest.yaml` 和 P0D evidence 仅作旧证据参考，不能替代本轮运行。

## 本轮真实 proof（2026-07-27）

- 使用本 space 独立 scratch 构建的当前 CLI，受控执行 `triton xcode run`，将 Debug fixture 构建、安装并启动在专用 iPhone 17 / iOS 26.5 Simulator。
- 仅在 `triton list --json` 返回 bundle ID 与专用 Simulator 同时匹配的 fixture target 后，显式传入完整 `--target`；没有使用同时连接的任何用户业务 App。
- `triton test validate fixtures/canonical-login-home.tritontest.yaml --json` 返回 `ok=true` 和六步 normalized plan；随后单次 `triton test run` 以 `passed` 收口：6 steps、2 AX assertions、4 observations、43 events、0 failures，耗时 1822 ms。
- `triton test report`、`triton evidence inspect` 与 `triton evidence summary` 都确认了同一 fixture target、`Fixture Login` -> runtime-point tap -> `Fixture Home` 的状态变化，以及 normalized plan、run events、4 张 PNG、AX 与 hierarchy artifacts。人工核对两张主截图也显示 Login -> Home。
- 证据仅保留在本机临时 `.tritonevidence`，不进入 Git；summary 标记为 `ios-private`，其中有 12 个 sensitive artifacts。它证明的是 runtime App-layer 截图和 AX/hierarchy 合同，不是 host-composited screen proof。
- proof 后已停止临时 loopback server，并把专用 Simulator 恢复为 Shutdown；fixture 安装仅留在这台专用 Simulator 中。#164 dirty evidence WIP 未读取、未修改。

## 执行与验收

1. 先保存 `triton doctor/status/capabilities/schema --json` 与 `triton sim list --json` 的 Triton-first 事实；server 不可达或 Simulator 不可用时停止，不用裸工具绕过。
2. 用 `triton xcode` 或等价受控 workflow 构建/安装 Debug fixture 到专用 Simulator，启动 loopback server 并确认 runtime target/bundle ID 对齐。
3. 先跑 fixture plan 的 validate，再执行单次 canonical `test run`；随后用 `triton evidence inspect/summary --json` 核对 verdict、target、events、assertions 与 artifacts。
4. 运行对应 focused CLI tests、文档门禁和本地总门禁；如 runtime proof 成功，写入脱敏 evidence 摘要和风险，而非提交机器私有日志。
5. 仅在所有事实一致时创建独立本地 checkpoint。

## 结论与后续

SP-131 的有限 DoD 已满足：当前基线的手写最小计划能在真实 iOS Simulator + Debug embedded runtime 上得到可审计的 `passed` evidence，而不是 local-simulated verdict。

下一条实现工作仍应回到 SP-126 的 Hybrid 主线：在这一 canonical seam 上完成 `.tritontestcase -> test import -> test validate`，再以本 plan 的真实 run 作为执行回归。此 proof 不等于已完成 recorder importer、稳定性矩阵、Android/Web/Wails、真机或 host-composited evidence 的产品验收。

## 停止条件

- 需要修改 #164、扩大为 testrec import/Android/Web、使用共享业务 App、或通过裸 `xcrun` 绕过 Triton failure 时停止。
- 专用 Simulator 不可用、fixture Debug build/runtime 无法连接、或同一失败在合理排查后重复时，保留当前诊断与下一步，不臆测成功。

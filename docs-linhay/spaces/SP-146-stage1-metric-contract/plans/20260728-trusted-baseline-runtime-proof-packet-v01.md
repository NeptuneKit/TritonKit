# Trusted Baseline Runtime Proof Packet v01

## 状态与用途

- 状态：目标 4 的隔离 integration 已完成；`main` 收口及目标 1、2、3、5 的环境 proof 仍待用户逐项授权。
- 用途：把 Luna handoff 的“落地 1–5”中仍缺少的**环境级证明**收敛为最小、可单独批准的操作范围。
- 不取代已存在的单元测试、schema 合同、local checkpoint 或 release build；也不把任何一项的批准外推到其它设备、App、server、真实项目、平台或收集批次。

这不是可执行配置、server 启动请求、设备操作请求、collection / receipt / evidence。每项没有用户明确授权就保持未运行；任何不匹配都停止，不 fallback 到其它 target、端口或 App。

## 当前证据与剩余证明

| 目标 | 已有本地证据 | 仍需的最小环境级证明 | 必须由用户授权的范围 |
| --- | --- | --- | --- |
| 1. #166 JPEG evidence 完整性 | `main` 的 SP-130 已锁定 JPEG→PNG normalizer、evidence / replay / test-run PNG contract。 | 只验证一份获准 iOS Debug runtime screenshot 在 PNG artifact / metadata 合同中可被无歧义消费；不把原始证据公开。 | 精确 iOS real-device selector、Debug fixture bundle、允许的只读 screenshot / evidence capture 范围、private evidence root / retention。 |
| 2. #168 terminate PID / recovery | `main` 的 SP-127 对 iOS real terminate 以 `app_terminate_pid_resolution_unavailable` fail closed，且不猜 PID / 不提交 terminate。 | 在获准 target 上证明该 failure envelope 保持单一 JSON，且未提交 terminate；**不执行**建议的 cold-restart nextAction。 | 精确 device selector 与 bundle ID；仅允许此只读/预期拒绝的命令，不授权 launch、terminate、install、kill 或 App 状态改变。 |
| 3. #167 Xcode alias preflight | `main` 的 SP-128 已在 build 前执行 iOS real target resolve，错误含 context-aware recovery。 | 在一个获准子目录 / alias 场景证明 missing / mismatched selector 在 `xcodebuild` 前失败；不进入 build、product resolution、install 或 launch。 | Xcode 项目/目录范围、alias / selector、可用 real-device identity；只允许 preflight，明确禁止实际 xcodebuild 和 App lifecycle。 |
| 4. loopback + strict readonly Web | SP-151 已在隔离 worktree 汇集 SP-129 loopback 与 SP-142 strict 405 / 无转发 Web，并通过 Swift focused、Web build、release schema 与 docs gate；`main` 未改。 | 在获准的当前 `main` 上完成 fast-forward、匹配离线/文档门禁与收口；若需要真实 bind 检查，必须另给 server ownership。 | 仅本地 fast-forward SP-151→`main`、匹配门禁与本地收口权限；不 push/PR/release。若实际启动受控 server，另给 host/port/PID/retention。 |
| 5. canonical iOS Simulator Stage 1 | SP-131 / 133 有单条 canonical/imported proof，SP-140 / 143～146 建立 receipt、anchor、identity-chain 和 Stage 1A/1B 离线合同。 | 先完成独立 integration candidate，再在 dedicated Simulator 上执行 receipt-frozen 的 60 supported + 1 safe negative；不得把离线合同当 runtime proof。 | 使用 [Live Authorization Packet v01](./20260728-live-authorization-packet-v01.md) 的 dedicated Simulator、fixture App、server、reset、negative、private evidence 与时间窗口全量字段。 |

## 统一 BDD 准入

1. Given 任一项目没有精确 target、owner、操作范围或 private evidence 规则，When 主控准备验证，Then 不执行该项目，也不把其它项目的授权借用过来。
2. Given 目标 1、2 或 3 获准，When 开始验证，Then 先保存相应 Triton-first machine-readable facts；若 preflight / target identity 不匹配，Then 停止且不启动 server、不进行 App lifecycle、不执行 fallback。
3. Given 目标 4 的隔离 integration 已完成，When 用户另行获准写入 `main`，Then 只允许 fast-forward SP-151、串行重跑匹配离线/文档门禁并本地收口；不 push、PR、tag、release 或删除未获授权的 ref / worktree。
4. Given 目标 5 获准，When preflight 成功，Then 才建立新的 live-sampling space；每个 slot 串行、private、no-clobber，任何 drift 立即停止而非 retry / 换设备。
5. Given 1–5 各自有结果，When 汇总可信基线，Then 分别报告“合同已证实”“环境 proof 已证实”“blocked”或“未授权”；不得把其中一项的绿灯泛化为整个 Stage 0 / Stage 1 通过。

## 用户最小授权回复模板

用户可逐行选择“批准”或“暂不批准”；未填写的行保持不执行。

1. **Integration（目标 4）**：允许仅本地 fast-forward `feat/SP-151-trusted-baseline-integration` 到 `main`，串行运行匹配离线/文档门禁并收口；明确 `不 push、不 PR、不 release`。
2. **#166（目标 1）**：iOS real selector / Debug bundle / 仅 screenshot-evidence / private root / retention。
3. **#168（目标 2）**：iOS real selector / bundle / 仅预期 fail-closed terminate invocation / 明确禁止 lifecycle action。
4. **#167（目标 3）**：project or child-directory / alias or selector / 仅 target preflight / 明确禁止 xcodebuild、install、launch。
5. **Server（若目标 4/5 需要）**：`127.0.0.1:19421` owner / fresh PID or nonce / 启停责任 / private diagnostics retention。
6. **Stage 1（目标 5）**：按 Live Authorization Packet 的八项完整字段填写，并写明先 preflight、后 3 × 20 + 1。
7. **Window**：批准人 / 日期时区 / 时间窗口 / 仅限以上精确目标与目的。

## 全局停止条件

- 不创建、clone、erase、upgrade、选择或关闭未被精确列出的 Simulator / device；不对未列出的 App 执行任何 lifecycle 操作。
- 不启动、停止、重用、kill 或 probe owner 不明的 server；不把 loopback 的 default 误述为“没有 Bonjour / LAN 发现风险”。
- 不触碰 #164 WIP，不写 testrec/workspace/Android/Harmony/Web/Wails 以外的额外产品面，不执行真实项目或远端设备采样。
- 不将任何 selector、bundle、绝对路径、runtime logs、screenshot、receipt hash 或 evidence 写入 Git、issue、PR 或公开聊天。
- 不因此前 local checkpoint、静态审计或本 packet 存在而推定批准。

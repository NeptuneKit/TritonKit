# SP-146 Live Authorization Packet v01

## 状态与用途

- 状态：待用户填写并明确批准。
- 用途：把 receipt-backed Stage 1 的真实 `3 × 20 + 1` 采样所需的 operator-owned 环境、动作范围、证据生命周期和停止条件收敛为一次可审计交接。
- 这不是 CLI 配置、collection receipt、sample receipt 或 evidence；它不会启动服务、Simulator、Xcode、设备或 `triton test run`，也不会因为文件存在而取得任何运行时权限。

本 packet 继承 SP-140 的 harness 边界和 SP-143～SP-146 的 receipt / anchor / identity-chain / metric 合同。真实采样仍只允许 `test` 作为执行器；不恢复独立 `testrec` replay，也不扩张 workspace、Android、Harmony、Web/Wails。

## 用户必须逐项批准的范围

| 项目 | 用户需提供的精确事实与批准 | 未提供或不一致时的行为 |
| --- | --- | --- |
| Dedicated Simulator | 单一、完整、全大写 UUID；预期 runtime / device model；采样窗口的唯一 owner；允许的初始状态及是否允许 boot / shutdown。不得使用 `booted`、`current`、alias 或“第一个匹配”。 | 停止；不创建、clone、erase、upgrade 或选择其他 Simulator。 |
| Fixture App | 仅该 UUID 上的 fixture bundle ID、build 来源和允许的 `build/install/launch/terminate` 动作；不得借此授权任意项目或 App。 | 停止；不安装、启动、终止或替换 App。 |
| Server ownership | 固定 `127.0.0.1:19421` 的外部 owner、启动/停止责任、fresh PID 或等价 nonce/attestation；确认端口被占用或 owner 不明时必须停止。 | 停止；不复用未知 server、不 kill / `pkill`、不接管生命周期。 |
| Reset recipe | recipe ID、每个 slot 的 initial-state ID、允许的 reset 动作、可复核的 witness / attestation 和失败处置。 | 停止；不推测、补写、重试或清理 slot。 |
| Safe negative control | 单一无破坏性场景、冻结的 deterministic assertion failure type，及其不会修改 fixture / server / Simulator 的依据。 | 停止；不得用任意 non-passed 结果冒充 expected negative。 |
| Private evidence | 私有根目录、root 外 receipt SHA-256 anchor 的保存位置、外部归档目的地、访问控制、保留期和删除责任人。 | 停止；不写入 Git、issue、PR、公开日志或截图目录；不自动删除已有证据。 |
| 执行窗口与责任 | 批准人、日期、时区、允许的时间窗口，以及 operator / harness / reviewer 的责任边界。 | 停止；不把历史口头同意解释为本次授权。 |

授权回复必须同时写明：上述每项已批准的具体值、允许动作与禁止动作，以及“仅限此次 Stage 1 受控采样”。任何空白、通配、含糊的“可用设备”或“可用服务”都不是授权。

## BDD 准入条件

1. Given 任一 required field 缺失、值不精确、owner 不明或条件互相矛盾，When 准备 live sampling，Then 不创建 collection、不启动或复用 server、不操作 Simulator / App，并向批准人返回缺失项。
2. Given 所有字段明确、host 为 `127.0.0.1:19421`、目标为唯一 exact canonical target、operator 明确批准，When 建立新的 live-sampling space，Then 仅可先执行一次只读 Triton-first preflight；preflight 不通过即停止，不进入 sample。
3. Given preflight 通过且 external owner 已完成 reset / server 交接，When 采样，Then 仅串行执行 receipt-frozen 的 60 个 supported slot 与 1 个 safe negative；每个 slot 保持 no-clobber、无自动 retry / cleanup / backfill。
4. Given 任一 target、server、reset、anchor、identity-chain 或 expected-negative 条件漂移，When 检测到漂移，Then 立即停止后续 slot、保留现有私有事实并报告；不得换设备、重启未知 server 或把失败计为通过。
5. Given 61 个 slot 均已由外部生命周期和私有 evidence 支持，When 离线 `test reliability --collection-receipt` 评估，Then 才能按 SP-146 的 Stage 1A / 1B 合同报告结果；该报告不能替代原始私有证据。

## 批准后分阶段执行

### Phase A — 离线交接核验

- 新建独立 live-sampling space / branch / worktree；不在 SP-146 的本地合同分支直接采样。
- 复核 packet 的每一项与已冻结的 schema、receipt、anchor、identity-chain 和 Stage 1 metric 合同是否兼容。
- 预先确认 private evidence root 为空或由 operator 明确指定其可用状态；不覆盖、删除或重新解释已有内容。

### Phase B — 一次受控 preflight

- 在 operator 允许的窗口内，按 Triton-first 保存机器可读的 `status`、`doctor`、`capabilities`、`schema`、`plan`、`sim list` 与 `xcode status` 事实。
- 只验证 exact canonical target、exact `/targets` 响应、server ownership attestation、fixture identity 和 reset witness；不以 fallback selector 继续。
- 任一事实不匹配，记录脱敏诊断并停止；不进入预留或 sample。

### Phase C — 串行 3 × 20 + 1

- 在 receipt / anchor 已被 operator 保存和验证后，每次只处理一个 frozen slot。
- lifecycle owner 只执行获准的 Simulator / App / reset 动作；harness 不得接管或扩大这些动作。
- 每个 slot 的 observation、terminal outcome、manifest 和 identity-chain 只写入获准 private root；不得回填、复跑、删除或公开。

### Phase D — 离线报告与交接

- 仅在全部 61 个 slot 停止写入后运行 receipt-backed 离线可靠性评估。
- 输出 privacy-safe Stage 1A / Stage 1B report、失败摘要和可复核的私有 evidence index；原始路径、UDID、bundle、hash、run/reset identity 不进入 Git 或公开渠道。
- 若 gate 未通过，按具体 blocker 建立新的离线分析 space；不在本 collection 上就地修补、污染或重跑。

## 不可越过的停止条件

- 不自动创建、克隆、erase、upgrade、选择或关闭任意 Simulator；不操作未被 packet 精确列出的 App。
- 不启动、停止、重用、kill 或探测 owner 不明的 `127.0.0.1:19421` server。
- 不接触 #164 WIP；不写 testrec/workspace/Android/Harmony/Web/Wails；不做真实项目、真机或远端设备采样。
- 不把 fixture、凭据、私有路径、UDID、bundle、receipt hash、evidence 或截图写入 Git、issue、PR、公开日志或聊天记录。
- 不因本 packet、此前 checkpoint 或任何离线测试通过而推定 live authorization。

## 最小批准回复模板

批准人可按下列项目逐项回复；只有填满并明确“批准”后，下一步才是建立新 space 的受控 preflight，而不是立即采样：

1. Dedicated Simulator：UUID / runtime / model / owner / 允许 lifecycle 动作。
2. Fixture App：bundle ID / build 来源 / 允许 lifecycle 动作。
3. Server：`127.0.0.1:19421` owner / fresh attestation / 启停责任。
4. Reset：recipe ID / initial-state ID / witness / 失败处置。
5. Negative：无破坏性步骤 / exact expected failure type。
6. Evidence：private root / anchor 保存点 / 归档 / 访问 / retention / 删除责任。
7. Window：批准人 / 日期时区 / 时间窗口 / 仅限本次 Stage 1。
8. 明确结论：`批准仅限上述范围的 Stage 1 受控 preflight；preflight 通过后再开始 3 × 20 + 1。`

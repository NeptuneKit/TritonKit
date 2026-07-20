# GitHub Issue #147：Harmony Wait Layout Receive

> 状态：已归档
>
> GitHub：[NeptuneKit/TritonKit#147](https://github.com/NeptuneKit/TritonKit/issues/147)
>
> Branch：`feat/20260720-issue-147-harmony-wait-layout-recv`
>
> Worktree：`../TritonKit-worktrees/20260720-issue-147-harmony-wait-layout-recv/`
>
> 集成：feature `a251164d`，merge `b2d90c2d`

## 背景

Harmony host-side `wait --text` 会轮询 `uitest dumpLayout` 与 `hdc file recv`。当前每个子命令使用独立 30 秒默认 timeout，即使 wait 的总 timeout 只有 15 秒；一次间歇性 recv 卡住便越过总截止时间，并被外层错误映射成泛化 `request_failed`。同一套 `debug ax --output` 单次 transfer 在目标上可成功。

## Triton-first 基线

- `triton status --json`：本机管理服务未启动，稳定返回 `server_unavailable`；Harmony host workflow 不依赖 embedded server。
- `triton device doctor --platform harmony --json`：HDC 3.2.0d 可用。
- `triton capabilities --json`：已暴露 `harmony-wait-text` 与 host layout 能力。
- `triton schema --command wait --json`：已暴露 `host.harmony-wait` output contract。
- `triton plan --platform harmony --json`：首选链为 device doctor/list/wait-ready/observe/screenshot。
- `triton device list --platform harmony --json`：当前唯一 DevEco emulator 为 Offline，因此本期不回退裸 HDC、不宣称真实设备 smoke。

## 范围

- `dumpHarmonyLayout` 的 dump 与 recv 共用一个有界 capture timeout，并复用 debug AX 的显式 local output/remote path transfer 流程。
- Harmony wait 每次 layout capture 使用 `min(5s, remaining wait budget)`，子命令不能越过总截止时间。
- dump/recv timeout 视为可重试的 transient poll failure；成功重试后正常返回 match，持续失败则返回标准 wait timeout envelope，而不是泛化 request failure。
- wait 输出补充 transient failure count 与最后结构化 transfer error，保留失败 source command。
- CLI wait 与 smoke wait 共用同一 helper，避免两条轮询实现继续漂移。
- 更新 schema、测试、文档、memory 与 emulator takeover skill。

不在本期范围：修改 HDC 本身、后台常驻 layout stream、远端/真机编排、Web/Wails UI、自动重启 Offline emulator。

## BDD 场景

### 场景 1：首次 recv timeout 后恢复

- Given 第一次 layout recv 立即返回 timeout
- And 下一次 capture 返回包含目标文本的 layout
- When Harmony wait 在总 timeout 内轮询
- Then 返回 `ok:true, matched:true`
- And `transientFailureCount=1`
- And `lastTransientError.code=harmony_layout_recv_timeout`
- And sourceCommands 保留超时 recv 与成功 transfer 命令

### 场景 2：recv 持续 timeout

- Given 每次 layout recv 都 timeout
- When 到达 wait 总截止时间
- Then 返回 `ok:false, timedOut:true` 的 HostHarmonyWaitOutput
- And 不抛出泛化 `request_failed`
- And elapsed 不被单个 30 秒 host timeout 拉长

### 场景 3：统一 transfer timeout

- Given layout capture 传入显式 timeout
- When 执行 dump 与 recv
- Then 两个 HDC command 都使用同一绝对截止预算
- And 返回 remote/local path 与 sourceCommands，供 debug AX 和 wait 共用。

## 验收门禁

- 先补 transient recovery、total deadline 与 dump/recv budget 的失败测试。
- Harmony wait/runtime、schema 与 smoke 聚焦测试通过。
- `docs-linhay/scripts/verify.sh --local`、public skill package、docs 与 diff 检查通过。
- 合入 main、GitHub Actions 成功后关闭 #147。

## 实现结果

- `dumpHarmonyLayout` 统一返回 local/remote path、source commands 与 layout data；传入 timeout 时，dump 和 recv 按同一个绝对截止时间递减分配预算。
- Harmony CLI wait 删除重复轮询，和 `smoke harmony` 共用 `waitForHarmonyText`；每次 capture 上限为 `min(5s, remaining wait budget)`。
- dump/recv 的 `HostCommandRunError.timeout` 改为可重试 poll failure。输出新增 `transientFailureCount` 与 `lastTransientError`，其中 message 保留 remote path、底层命令与 stdout/stderr log path。
- `--gone` 只有在成功读取 layout 后才可判定文本消失，传输失败不会产生假阳性。
- `host.harmony-wait` schema、agent-facing CLI 文档和对外 emulator takeover skill 已同步。

## 验证结果

- 红灯：`swift test --package-path CLI --filter HarmonyWaitRuntimeTests` 因缺少 capture 注入、统一结果模型和 transient diagnostics 编译失败。
- 绿灯：`HarmonyWaitRuntimeTests` 4 项通过，覆盖 recv 恢复、持续 timeout、gone 假阳性防护和共享 deadline。
- Harmony CLI 回归：`swift test --package-path CLI --filter Harmony`，23 项通过。
- Schema / smoke 聚焦回归：`SchemaFactSourceSurfaceContractTests` 4 项、`SmokeHarmonyRuntimeTests` 1 项通过。
- 正式本地门禁：`docs-linhay/scripts/verify.sh --local` 通过，包含根 Swift 225 项、release CLI build/smoke、Harmony host smoke、iOS runtime smoke、iOS Simulator build、docs 与 diff check。
- 对外 skill 包：`docs-linhay/scripts/verify-skill-package.sh` 通过。
- 真实 Harmony smoke 未运行：Triton-first `device list --platform harmony --json` 证明唯一 DevEco emulator 为 Offline；未绕过 Triton 调用裸 HDC。
- `main` 集成回归：Harmony wait 4 项与 schema surface 4 项通过，docs / diff check 通过。

# GitHub Issue #149：iOS Simulator Host AX Wait

> 状态：待集成
>
> GitHub：[NeptuneKit/TritonKit#149](https://github.com/NeptuneKit/TritonKit/issues/149)
>
> Branch：`feat/20260720-issue-149-ios-host-wait`
>
> Worktree：`../TritonKit-worktrees/20260720-issue-149-ios-host-wait/`

## 背景

`triton observe tree --platform ios --device <simulator>` 已能读取 Simulator host-side AX 树，但 `triton wait --platform ios` 仍落入 embedded runtime `/targets` 路径。无 runtime 连接时，即使 host AX 已出现目标文本，wait 仍返回 `target_not_found`。CLI help 又宣称 `--platform` 支持 iOS，而 schema 只列 `android|harmony`，形成执行与发现契约分裂。

`docs-linhay/scripts/create-space.sh` 在当前仓库不存在，因此本 space 按固定模板直接建立并同步总索引。

## Triton-first 基线

- `triton status --json`：初始为 `server_unavailable`；启动本机 `triton serve` 后返回 `serverReachable=true, connected=false, targetCount=0`。
- `triton doctor --json`：schema 可离线读取；embedded runtime 未连接不阻塞 host Simulator adapter。
- `triton capabilities --json`：已有 `observe-ios-host-ax`，但 wait capabilities 只有通用/Android/Harmony。
- `triton schema --command wait --json`：`--platform` 仅声明 `android|harmony`，runtime scope 为 `embedded|host-harmony`。
- `triton plan --platform ios --json`：当前仍生成 embedded runtime bootstrap，不表达 host wait。
- `triton sim list --json`：存在一个 Booted iOS 26.5 Simulator。
- `triton observe tree --platform ios --device sim:<udid> --json`：成功返回 `primarySource=host-layout`，可见文本 `Remote Directory Debug`。
- 同一 target/text 执行 `triton wait --platform ios ...`：在 server reachable 且零 embedded target 时稳定返回 `/targets` 的 `target_not_found`。

## 范围

- `wait --platform ios` 只接收本机 booted Simulator selector，并复用 `observeIOSHostAX` 的 host AX 树。
- 首期支持 `--text`、`--exists`、`--gone`，并支持可选 `--role` 过滤；`idle`、`hierarchy-change`、predicate 在 host iOS 下返回精确 unsupported。
- 增加 `HostIOSWaitOutput` / `host.ios-wait` machine-readable contract，保留 resolved target、match node、poll count、elapsed、timeout 与 source commands。
- CLI help、schema、capabilities、文档与 simulator/emulator takeover skill 同步。
- 真实 booted Simulator 验证匹配、超时和无需 embedded server/runtime 的执行链。

不在本期范围：iOS 真机 host wait、host AX 输入扩展、HTTP/Wails/Web、复杂 predicate、层级变化与 idle 判定。

## BDD 场景

### 场景 1：host AX 文本已出现

- Given booted Simulator 的 host AX 树包含目标文本
- And embedded runtime 没有连接
- When 执行 `wait --platform ios --device <selector> --text <text>`
- Then 通过统一 host selector 解析 Simulator
- And 返回 `host.ios-wait`、`ok=true`、`matched=true`
- And match 与 sourceCommands 来自 host AX observer

### 场景 2：等待文本消失

- Given 首轮 host AX 仍包含目标文本
- And 后续轮询不再包含
- When 执行 `--gone`
- Then 仅在成功读取的 AX 树确认 absence 后返回 matched
- And poll count 为 2

### 场景 3：总等待超时

- Given 每轮 host AX 均不包含目标文本
- When 到达 timeout
- Then 返回 `ok=false, matched=false, timedOut=true`
- And 以非零退出结束，但不访问 embedded `/targets`

### 场景 4：非 Simulator iOS target

- Given selector 指向 iOS real device 或不可用 target
- When 请求 host iOS wait
- Then 统一 target resolver 返回稳定 selection/readiness 错误或明确 unsupported
- And 不把真机路由到 Simulator private AX framework

## 验收门禁

- 先补 host iOS wait helper、selector routing、schema/capability 的失败测试。
- 聚焦 wait/observe/schema 测试通过。
- Booted Simulator 真实匹配与超时 smoke 通过，不启动 embedded runtime。
- `docs-linhay/scripts/verify.sh --local`、public skill package、docs 与 diff 检查通过。
- 合入 main、GitHub Actions 成功后关闭 #149。

## 实现结果

- 新增 `waitForIOSHostText`，通过注入/复用 `observeIOSHostAX` 轮询 Simulator host AX，不复制 private-framework reader。
- `wait --platform ios` 使用统一 `HostDeviceSelectionRequest`，scope 固定为 `simulator` 且要求 ready；`local` 自动选择唯一 booted Simulator，显式 selector 支持 `booted`、`sim:<udid>` 与 raw UDID。
- 支持 `--text`、`--exists`、`--gone` 与可选 `--role`；匹配忽略大小写/变音并覆盖 text/identifier，hidden node 不参与。
- 新增 `HostIOSWaitOutput` / `host.ios-wait`，包含 resolved target、role、match、elapsed、pollCount、timedOut 与 host AX sourceCommands。
- wait schema 统一声明 `ios|android|harmony`、`embedded|host-ios|host-android|host-harmony`，host 混合命令不再整体声明强制 server；capabilities 新增 server-independent `ios-simulator-host-wait`。
- iOS host 下的 idle、hierarchy-change、predicate 返回 `unsupported_capability`，不会静默落入 embedded runtime。

## 验证结果

- 红灯：`IOSHostWaitRuntimeTests` 因缺少 host wait helper 与 selection request 编译失败。
- 绿灯：`IOSHostWaitRuntimeTests` 4 项通过；ObservationOutput 10 项、SelectorFlag 11 项、schema surface 4 项、capability metadata 1 项、CLI help 6 项通过。
- 真实 release CLI / booted iOS 26.5 Simulator：server 关闭且无 embedded runtime 时，可见文本 `Remote Directory Debug` 在一次 host AX poll 内返回 `ok=true`；不存在文本在 2 次 poll 后返回 `ok=false,timedOut=true` 和非零退出；`--gone` 对不存在文本返回成功。
- `capabilities --json` 在 server unavailable 状态仍返回 `ios-simulator-host-wait supported=true`，nextAction 指向 host wait 且不要求长进程。
- `--platform ios --idle` 返回结构化 `unsupported_capability`，未访问 `/targets`。
- 正式本地门禁：`docs-linhay/scripts/verify.sh --local` 通过，包含根 Swift 225 项、release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke、iOS Simulator build、docs 与 diff check。
- 对外 skill 包：`docs-linhay/scripts/verify-skill-package.sh` 通过。
- 扩展 `SchemaFactSourceTests` 仍有既存 device proxy/schema 与 `evidence_capture_partial` 分类失败；本次新增 iOS host wait 的 capability/schema 门禁均单独通过，失败集合未新增本期字段。

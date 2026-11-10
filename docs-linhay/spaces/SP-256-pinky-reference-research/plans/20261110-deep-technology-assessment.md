# SP-256 — Pinky 深度技术评估

## 结论

Pinky 最值得 TritonKit 借鉴的不是 MyGo、真实手机驱动或桌面页面，而是它把一次 Agent 动作建模成一个有身份、有版本、有租约、有策略、有审批、有执行结果和有证据的事务上下文。

Pinky 的关键抽象可以压缩为：

```text
ActionContext
  = session
  + target/device
  + lease
  + canonical arguments digest
  + observation/screen revision
  + policy verdict
  + approval binding
  + delivery result
  + postcondition/evidence
```

TritonKit 已经分别拥有 target lease、requestID、receipt、stale/uncertain recovery、postcondition 和 evidence manifest 等能力。深挖后的主要建议是把这些能力在动作层正式串起来，形成统一的 ActionContext 和状态迁移规则。

## 1. Pinky 的真实执行模型

### 1.1 动作不是一次函数调用

Pinky 的 `internal/gateway/pipeline.go` 把一次动作拆成多个阶段：

1. 参数校验；
2. 获取当前 session 的设备 lease；
3. 读取或复用最新 screen；
4. 获取设备 action lock；
5. 在 lock 下再次执行 gate 检查；
6. 等待上一动作欠下的 settle 时间；
7. 解析 ref、坐标、App 和前台状态；
8. 计算策略 verdict；
9. 评估 OCR 与命中区域中的外层元素；
10. 创建或恢复审批；
11. 执行动作；
12. 等待 screen settle；
13. 返回 screen diff/full screen、状态和历史记录。

关键点是：审批之前会检查一次 gate，拿到设备 action lock 后还会再检查一次。这样可以处理“审批等待期间用户接管”“另一个调用打开了审批”“设备锁定或 lease 被停止”等竞态。

对应源码证据：

- `internal/gateway/pipeline.go:203-216`：动作进入 session lease 并在结束时统一 `finish`；
- `internal/gateway/pipeline.go:218-275`：设备状态、用户接管、审批占用、锁定和 scope gate；
- `internal/gateway/pipeline.go:341-413`：动作主流程及 action lock 下的二次 gate；
- `internal/gateway/pipeline.go:415-428`：batch 动作在新鲜窗口内复用前一步的 settled screen；
- `internal/gateway/pipeline.go:473-511`：对目标、命中区域元素和 OCR 文本取最严格的 policy verdict。

### 1.2 审批是有生命周期的对象

`internal/approval/approval.go` 的状态不是一个布尔值，而是：

```text
Open
  ├─ Decide → Decided → Wait consumes → Used
  ├─ timeout → Decided(Deny)
  ├─ Withdraw → Withdrawn
  └─ gateway/session/stop teardown → Withdrawn
```

审批还具有四个不变量：

- 绑定 `session/device/lease/tool/argsDigest`；
- 参数变化时 approval id 不能复用；
- 由客户端决定，Agent-facing MCP 没有 approve/stop/takeover 能力；
- decision、withdraw 和 expiry 会短暂保留 tombstone，使等待中的调用得到准确原因。

对应源码证据：`internal/approval/approval.go:59-89`、`:207-248`、`:321-394`、`:397-455`。

### 1.3 session 关闭不等于 lease 立即消失

Pinky 对 HTTP 客户端做了一个实际工程取舍：有些客户端每次工具调用都会新建 MCP session。对于明确标记为可恢复的 remote agent：

- 旧 session 关闭时，lease 在短时间内保留；
- 同名 Agent 的新 session 可以接管空闲 lease；
- 如果旧 session 仍有 in-flight call，新 session 返回 `lease_held`；
- 审批会随 lease 重新绑定到新 session；
- 用户 Stop 会在一段时间内阻止同一 Agent 的新 session 继续使用设备。

对应源码证据：`internal/gateway/resume.go:11-27`、`:48-68`、`:88-128`、`:149-176`。

这比“session 断开就清理全部资源”更适合远程 Agent，但也要求清楚区分：

```text
session closed
lease kept
lease adopted
lease ended
user stop inherited
```

### 1.4 screen 是动作前置条件，不只是展示数据

Pinky 的 screen model 有：

- 统一像素坐标空间；
- 稳定 ref；
- element path/ID 作为身份辅助；
- tree/OCR 来源区分；
- focused/password/editable 等状态；
- foreground App、orientation、lock、keyboard；
- transient event；
- before/after screen diff。

`pipeline.go` 会在 ref 不存在时尝试从上一份 screen relocation；若 bounds 未放置，会再读一次；如果设备读屏较慢，则根据 `settleOwed` 等待之前动作留下的稳定时间。

这说明 Pinky 把 screen 当成动作的前置证明：

```text
ref 12
必须来自某个 screen revision
动作执行前要确认它仍可解析
解析失败只能返回 not_found/stale
不能凭邻近坐标猜测
```

## 2. 与 TritonKit 当前能力的精确映射

| Pinky 机制 | TritonKit 已有基础 | 主要缺口或下一步 |
| --- | --- | --- |
| lease 绑定设备和 owner | `TKTargetLease`、TTL、check/takeover | 把 leaseID 纳入每个动作的统一上下文与 receipt，不只在 CLI gate 层检查 |
| approval 绑定 action 参数 | 现有 target lease 与 requestID 契约 | 需要统一的 approval/action digest 语义，防止“同 requestID、不同 payload”或“同 lease、不同动作”混用 |
| uncertain 禁止盲重试 | recovery taxonomy 已明确“never automatic replay” | 让每个 mutating action 都输出 delivery、observation、postcondition 三段状态，而不是只靠 failureCode 推断 |
| stale screen/ref | `stale_node_alias`、selection revision、runtime instance 检查 | 将 observationID/screen revision 直接绑定 action 请求；过期后返回明确 `observation_stale` |
| action lock 下二次 gate | 多个 runner/host adapter 已有 owner、session、队列和锁 | 收敛成共享 action admission 模型，避免每个平台各自维护竞态规则 |
| batch 复用 settled screen | `run`、receipt、screen workspace 已存在 | 增加 `settledAt`、`settleOwed` 或 `observationFreshUntil` 的明确字段 |
| before/after 屏幕和步骤历史 | `TKEvidenceManifest`、run/events、screens/transitions | 将 actionID、leaseID、observationID、postcondition 与 evidence artifact 形成强关联 |
| provider 不感知平台 | TritonKit 已有 iOS/Android/Harmony provider/host adapter 分层 | 继续把平台判断留在 provider，不把 Pinky 的真实手机假设带入模拟器边界 |
| 远程 session resume | CLI/HTTP/runner 各自有 session/request 语义 | 仅在明确的远程 Agent 场景采用；本地 CLI 不应默认继承旧 lease |

## 3. 建议新增的统一动作上下文

这不是立即改代码的接口，而是后续采用切片应先冻结的 wire 语义：

```text
ActionContext {
  actionID: string
  sessionID: string
  target: string
  leaseID: string?
  owner: string?
  operation: string
  canonicalArgumentsDigest: string
  observationID: string?
  observationRevision: string?
  policyDecision: allow | deny | approval_required | unsupported
  approvalID: string?
  delivery: not_started | submitted | delivered | unknown
  outcome: settled | uncertain | stale | blocked | cancelled | failed
  postcondition: verified | unverified | failed | unavailable
  evidenceID: string?
}
```

其中最重要的是区分三个经常被混在一起的状态：

- **delivery**：动作是否送到 host/provider/设备；
- **outcome**：调用是否收到可解释的结果；
- **postcondition**：业务或 UI 状态是否被独立观察确认。

例如：

```text
送达成功 + 返回超时 + 未观察后置状态
= delivery=delivered, outcome=uncertain, postcondition=unverified
```

不能把它简化成 `ok=false`，也不能自动重放动作。

## 4. 可以直接立项的三个切片

### P0：Action admission 与 approval binding

目标：统一所有 mutating CLI/HTTP/runtime 动作进入 provider 前的门禁。

建议流程：

```text
normalize target
→ resolve lease
→ validate observation identity
→ canonicalize arguments
→ compute action digest
→ policy/scope check
→ approval check/create
→ provider admission
→ receipt
```

BDD 场景：

- Given approval 为动作 A 创建，When Agent 使用同 approval id 提交动作 B，Then 返回 `approval_mismatch`，provider 未被调用。
- Given lease 属于 target X，When 动作请求 target Y 或 target alias 解析到 Y，Then 返回 `target_lease_conflict`，不发生 host mutation。
- Given 当前 observation 已过期，When Agent 使用旧 node/coordinate 执行，Then 返回 `observation_stale`，要求重新 observe，不猜测新坐标。
- Given approval 等待期间用户接管，When Agent 恢复原调用，Then 返回 `user_took_over` 或 `paused`，不执行原动作。
- Given provider admission 超时且送达未知，Then返回 `uncertain`，持久化 action receipt，后续只能 query/observe，不能自动 replay。

### P1：Receipt 与 evidence 统一关联

目标：让一条动作证据可以回答“谁、对哪个 target、以哪个 lease、基于哪次观察、发了什么、结果如何”。

建议最小关联链：

```text
runID
 └─ actionID
     ├─ sessionID
     ├─ target
     ├─ leaseID
     ├─ observationID
     ├─ requestID
     ├─ provider receipt
     ├─ before screen/evidence
     ├─ after screen/evidence
     └─ postcondition verification
```

BDD 场景：

- Given provider 返回 uncertain，When `triton evidence` 导出，Then manifest 保留 action receipt、uncertainty reason 和建议的 observe/verify 命令。
- Given capture 只有截图但没有 target identity，Then evidence 标记 identity incomplete，不得宣称动作已验证。
- Given postcondition 观察属于另一个 target 或 runtime instance，Then comparison fail closed，保留原 receipt。
- Given 中途停止，Then 已开始的动作保留实际 delivery 状态，后续步骤标记 skipped/stopped，不能伪造成全部 cancelled。

### P2：屏幕版本和 settle contract

目标：把 stale selection、screen reuse 和动作后等待从各个 provider 的局部约定提升为共同合同。

建议字段：

```text
ObservationIdentity {
  target
  runtimeInstance
  capturedAt
  revision
  source
  hierarchyState
  coordinateSpace
}
```

```text
ActionTiming {
  startedAt
  submittedAt
  settledAt?
  settleBudgetMs
  observationFreshUntil?
  visualStable: true | false | unknown
}
```

BDD 场景：

- Given action A 的 after observation 在 fresh window 内，When batch 立即执行 B，Then 允许复用该 observation，并在 evidence 中记录复用关系。
- Given runtime instance 变化，When使用旧 observation，Then返回 stale，不允许复用旧 selection。
- Given视觉未稳定但动作调用已返回 transport success，Then结果允许 delivery=delivered，但 postcondition 仍为 unverified。
- Given settle budget 用尽，Then返回明确 `visual_motion_timeout` 或等价错误，不把最后一帧当作业务成功。

## 5. Android Companion 的正确借鉴方式

Pinky Companion 有三个值得借鉴的工程点：

1. **性能加速与安全策略分离。** Companion 只负责更快的树、事件和文本输入，gateway 仍负责 policy、scope、approval 和 evidence。
2. **本地 socket 做能力边界。** 抽象 socket 只接受 shell/root/本 App UID，连接协议有版本和请求串行化；拒绝未知 UID。
3. **可选能力降级。** Companion 未安装时仍可通过 adb/系统能力运行，只是更慢或能力减少。

TritonKit 不应直接复制其真实手机安装、无障碍服务和 adb forward。当前产品边界是本机 Simulator/Emulator/host adapter；如果以后需要 Android 真机 Companion，应另建 space，并先定义安装、签名、权限、卸载、隐私和恢复契约。

## 6. MCP/HTTP 的深层借鉴

Pinky 的 MCP server 有一个很清晰的权责分离：

- Agent-facing tool 可以 connect/observe/action/release；
- UI/client 才能 approve/stop/takeover；
- MCP session 关闭时撤回审批并清理 lease；
- HTTP remote agent 使用独立名称和 scope，不继承本机同名 Agent 的授权；
- token、session id、upload token 分别承担不同生命周期。

TritonKit 可以借鉴这种“控制面和执行面分离”的原则，但继续使用 TritonKit 的 JSON envelope、CLI schema 和 evidence manifest。建议新增的机器可读字段是：

```text
sessionID
requestID
actionID
leaseID
approvalID
observationID
receiptID
```

所有字段都应出现在诊断/evidence 链路中，业务 payload 仍按现有脱敏规则处理。

## 7. 历史记录和隐私模型

Pinky 使用 SQLite 保存 session、agent、task、step、approval、media、recording 等对象，blocked app 不进入 history。这个模型对 TritonKit 的启发是：

- evidence 不应只有文件清单，还要有任务/步骤/动作的索引；
- approval 应是一等审计对象，包含 rule、decision、note、wait duration；
- before/after media 和 action result 应引用同一个 step；
- blocked/credential-sensitive 内容应在进入 evidence 前被过滤，而不是导出时才补遮挡；
- SQLite/WAL/单连接只是实现选择，TritonKit 不应直接复制存储方案。

TritonKit 现有 `TKEvidenceManifest` 已有 `run`、`screenWorkspace`、`target`、`skipped`、`freshness` 等字段，后续更适合增加 action/receipt 关系，而不是再造独立的 history 数据库。

## 8. 不建议采用的部分

- MyGo 原生桌面 UI：与 TritonKit Wails/Web mock 边界不同。
- Pinky 的真实手机安装和权限模型：会扩大当前 Simulator/Emulator 产品范围。
- Pinky 的文本型 Agent 输出：TritonKit 已有 JSON/JSONL/schema/evidence 契约，应保持机器可读。
- 以同用户权限运行的 gateway 作为安全沙箱：shell、adb、xcrun 或其他 host 工具仍可能绕过网关。
- 直接复制 Apple DDI、go-ios fork、FFmpeg 或 adb 打包：需要独立许可证、签名、版本和供应链审查。
- 自动继承所有旧 session/lease：只适合明确标记为 remote-resumable 的 Agent，默认本地 CLI 应保持显式 target 和 lease。
- 把 OCR 文本当作安全事实：OCR 可以参与风险判定，但不能替代 target identity、screen revision 或业务后置验证。

## 9. 最终优先级

| 优先级 | 交付 | 直接收益 | 依赖 |
| --- | --- | --- | --- |
| P0 | ActionContext、approval binding、二次 admission gate | 阻断审批竞态、参数替换和 lease 越权 | 现有 target lease、requestID |
| P0 | delivery/outcome/postcondition 三分法 | 统一 uncertain、timeout、partial、postcondition 未验证 | 现有 receipt/recovery/evidence |
| P1 | action receipt 与 evidence 强关联 | 可复盘、可比较、可解释恢复 | 现有 TKEvidenceManifest/run |
| P1 | observation revision/coordinate-space 绑定 | 降低 stale node、旧坐标和错 target 风险 | 现有 selection/runtime instance |
| P2 | settle reuse 与 batch transition 证据 | 减少重复 observe，提升连续动作稳定性 | screen snapshot/transition |
| P3 | Companion 或更快的 provider | 降低设备观察延迟 | 另立真机/Android 范围 |

建议下一步先建立一个纯离线的 P0 合同 slice：不接新设备、不改 Web UI，只为现有 CLI/HTTP/runner 动作补 `ActionContext`、approval mismatch、observation stale、uncertain receipt 和禁止自动 replay 的正负例。这样可以在 TritonKit 当前产品边界内验证 Pinky 最有价值的技术，而不会引入它的真实手机、桌面或打包范围。

## 10. 子系统级风险与供应链结论

### Session、Stop 和 resume

Pinky 的 resume 只允许同名、明确支持 resume 的 Agent 续接，且旧 session 必须没有 in-flight call；新 session 不能接管正在执行的旧调用。Stop 还会形成一段 inherited stop hold，防止“每次调用都新建 session”的客户端通过重连绕过停止。

这对 TritonKit 的启发是：`lease owner` 和 `session owner` 不是同一个字段。后续若支持远程 Agent，至少需要：

```text
lease owner identity
session identity
resume policy
inflight state
stop barrier
resume grace
```

本地 CLI 不应默认续接旧 lease；远程 resume 必须显式声明并验证 owner identity。

### History 与 evidence

Pinky 的 SQLite history 适合作为查询视图：tasks、steps、approvals、media 和 recordings 分表，媒体文件带 size/hash，清理时先处理数据库引用，再处理文件；扫描失败会中止 prune，避免把未知状态当成可删除。

TritonKit 已有 `.tritonevidence`、manifest、run/events JSONL 和 screen workspace，因此更适合把 Pinky 的字段映射进现有 evidence：

```text
step → actionID / target / lease / session / approval
before/after media → artifact refs + SHA-256
approval → binding digest + decision + note + wait duration
history status → originalStatus + terminalStatus
```

Pinky 的 SQLite/media hash 不能替代签名或外部锚定；TritonKit 的 evidence manifest 应继续作为事实源，history 只作为浏览和查询索引。

### HTTP sessionless 与上传

Pinky 为无法保存 `Mcp-Session-Id` 的客户端提供 User-Agent 粘性 session，这种兼容机制方便但不能作为强身份。相同 Bearer token 且可伪造 User-Agent 的客户端可能发生身份碰撞，TritonKit 不应把 User-Agent 当作 lease owner。

Pinky 的远程上传 link 绑定 session、device、destination、replace 选项、随机 token 和短 TTL，且上传后真正写设备仍经过 Agent 的 policy/approval。若 TritonKit 未来需要类似能力，应额外绑定：

- target/lease/owner；
- Content-Length 和实际 SHA-256；
- 单次消费和失败清理；
- 代理 Host/X-Forwarded-Host 校验；
- 上传 artifact 与 evidence manifest 的关系。

### Telemetry 与隐私

Pinky 的 telemetry 有 DO_NOT_TRACK、固定 counter、重试和 bounded diagnostics，但大量 redaction 仍属于序列化后的补救。TritonKit 应优先采用结构化字段白名单：screen text、task title、device identity、path、token、intent 和 app name 在进入 telemetry/evidence 之前就决定是否允许出现，不能先写入敏感值再依赖正则脱敏。

telemetry 网络失败不得改变动作结果，也不得阻塞 CLI；telemetry、crash journal、evidence 和业务 verdict 应保持独立生命周期。

### Update 与构建供应链

Pinky 的 update 流程包含 feed schema、size/hash、临时文件、stall timeout、atomic rename、启动确认和回滚，这套状态机有参考价值。但 HTTPS + SHA-256 只能证明下载内容符合 feed 声明，不能证明 feed 发布者可信。TritonKit 若做自动更新，应增加签名 manifest、可信公钥、artifact provenance、SBOM 和回滚 receipt。

Pinky 的 FFmpeg、adb、Gradle、Docker、GitHub Actions、go-ios fork 和 Apple DDI 都是独立供应链，Apache-2.0 主许可证不能覆盖它们。尤其要关注：

- FFmpeg 是否确实保持 LGPL shared 构建，未混入 GPL/nonfree；
- adb 静态依赖中 libusb LGPL 的源码和重链接义务；
- go-ios replacement fork 的变更和来源；
- Apple DDI、CoreDevice/WDA、Xcode SDK 和第三方镜像的签名/许可；
- Actions、Docker base image、Gradle 和外部下载是否锁定 immutable digest；
- 包内 NOTICE、BUILD 信息、SBOM、checksum 和签名是否与每个发布形态一致。

## 11. 当前 TritonKit 基座与建议差距

静态核对当前 TritonKit 已具备以下可复用基础：

- `TKTargetLease` 已有 opaque lease id、normalized target、owner、TTL、过期时间和 read-only observation 标记；
- `CLITargetLeaseStore` 已覆盖 acquire/release/takeover/check 的原子校验；
- CLI recovery taxonomy 已明确 delivered/uncertain actions 通过 observe/receipt 恢复，禁止 automatic replay；
- `TKEvidenceManifest` 已有 target、artifacts、skipped、run、screen workspace、freshness 和 partial/error；
- runner/host action 已有 requestID、nonce、observation identity、postcondition 和 durable receipt 的若干实现；
- 当前错误和恢复命令已经区分 stale selection、target mismatch、device action observation stale、execution uncertain 等情况。

因此 Pinky 深挖后最小差距是：

1. **没有统一的 ActionContext。** lease、requestID、observationID、receipt 和 evidence 目前存在于不同边界，尚未形成一个跨 CLI/HTTP/provider 的动作关联对象。
2. **没有统一的 approval binding。** 已有 lease check 和部分 request binding，但还需要把 normalized arguments digest、target、lease、session、operation 和 approval 绑定成同一规则。
3. **终态可能覆盖原始事实。** Stop、timeout、runner failure 和 evidence write failure 需要同时保留 `originalStatus` 与 `terminalStatus`，并区分 `executed=true|false|unknown`。
4. **settle owed/observation revision 尚未成为共同合同。** 各 provider 已有 stale/runtime/visual settle 语义，但需要统一 `observationRevision`、`coordinateSpace`、`settledAt` 和 `observationFreshUntil`。
5. **history/evidence 关系仍需强化。** 现有 evidence 可以承载这些字段，但要让 action、approval、before/after artifact 和 postcondition 的引用关系可机器验证。

## 12. 建议的验收顺序

先做纯离线 P0 合同，不接新设备：

1. 给一个已有 mutating action 生成 ActionContext 和 canonical args digest；
2. 添加 approval binding mismatch、lease target mismatch、stale observation、uncertain delivery 和禁止自动 replay 的负例；
3. 将原始 provider receipt、终态和 evidence refs 写入同一 run event；
4. 为 Stop/takeover/timeout/late result 做并发 fixture；
5. 用现有 CLI JSON/schema、receipt 和 evidence manifest 验证，不新增 Web/Wails 控制面。

P0 通过后，再做 P1 的远程 session resume、history view/prune、签名更新 feed；最后才评估 Android Companion 或更快的视频 provider。真实设备、远程 Agent、云设备、Apple DDI 和供应链大改动都应分别建立 scope 和授权。

源码深挖的主要证据路径：`internal/gateway/pipeline.go`、`internal/gateway/agent.go`、`internal/gateway/resume.go`、`internal/approval/approval.go`、`internal/policy/engine.go`、`internal/mcp/server.go`、`internal/mcp/http.go`、`internal/history/history.go`、`internal/history/media.go`、`internal/history/prune.go`、`internal/driver/driver.go`、`internal/screen/screen.go`、`internal/video/player.go`、`docs/DESIGN.md`、`docs/mcp.md`、`go.mod`、`Makefile`、`scripts/ffmpeg.sh`、`scripts/adb.sh` 和 CI/release workflows。

本报告基于已归档源码和文档静态阅读；未运行 Pinky、Go/Kotlin 构建、第三方依赖、MCP 服务、设备或网络测试。
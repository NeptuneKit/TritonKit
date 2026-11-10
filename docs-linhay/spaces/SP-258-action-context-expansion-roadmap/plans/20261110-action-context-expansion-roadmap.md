# SP-258 — ActionContext 后续扩展路线

## 当前状态

- 状态：路线规划完成，等待按优先级连续推进。
- 前置批次：[SP-257 ActionContext / Action Admission 全量批次](../SP-257-action-context-admission-design/README.md)。
- 目标：把 SP-257 的 runner/device.action 两条试点链路收敛为共享核心，再按边界扩展到其它 mutating surfaces。

## 当前事实

SP-257 已完成：

- ActionContext、canonical digest、AdmissionStore、generation guard；
- iOS host runner admission、receipt、evidence writer、lease gate；
- device.action tap/double-tap/swipe/press/type 的 context/admission/generation/output projection；
- schema/recovery、root/CLI full tests 和并发 fixture。

仍存在的可执行缺口：

1. runner receipt 已有统一 metadata，但 `device.action` 仍主要返回直接 JSON projection；
2. device.action host command 失败/timeout 的 receipt 持久化和 evidence 关联仍需补齐；
3. ActionContext/admission 前置逻辑在 runner 和 device.action 之间仍有重复；
4. app lifecycle、sim HID、WebView action、device administration 等其它 mutating surface 尚未统一接入；
5. approval control plane、HTTP remote admission、session resume 仍未进入产品合同；
6. 真实设备、云设备、Android Companion、审批 UI 和远程 Agent 仍是独立范围。

## 后续优先级

### P0 — 收敛共享执行核心

目标：避免每个 command 各自实现 context/admission/receipt。

- 提取 provider-neutral `TKActionAdmissionCoordinator`；
- 提取共享 `TKActionReceipt`，替代 runner 私有 receipt 与 device.action 字典 projection；
- 统一 delivery/outcome/executed/originalStatus/terminalStatus/postcondition/evidencePersistence；
- 统一 target normalization、lease gate、generation begin/invalidate、canonical args digest；
- 保留旧 CLI output 字段，通过 compatibility projection 输出新 receipt；
- 明确锁顺序：target lease → admission → provider/generation；
- 统一 host command failure/timeout/unknown 的单一 receipt 路径。

验收：runner 和 device.action 产生结构等价 receipt；旧 JSON 解码不变；所有 provider failure 都不丢 delivery unknown；无自动 replay。

### P1 — 补齐 device.action 的完整证据链

目标：让第二类 action达到和 runner 相同的 evidence 可信度。

- 为 `device.action` 增加显式 `--evidence-dir`；
- 写入 run/step/tool lifecycle 和 action receipt artifact；
- Android/Harmony host command 的 stdout/stderr 只作为 private artifact，不进入公开 event；
- iOS runner response 的 original envelope 与 actionContext 分开保存；
- host command timeout/nonzero/invalid result 输出 `delivery=unknown` 或 `not_started`；
- generation stale 输出 evidence partial/unknown，并禁止晚到结果追加新 run event；
- text file/private path 继续只留 redacted digest。

验收：device.action success、lease conflict、host timeout、result invalid、late generation 各有完整 evidence fixture。

### P2 — 扩展剩余 mutating surfaces

按风险和复用收益排序：

1. `app open-url / launch / terminate`；
2. Simulator HID tap/swipe/press；
3. WebView tap/form input；
4. device administration / mount / proxy mutation；
5. test/replay runner action。

每个 surface 必须复用 P0 coordinator，不得复制 AdmissionStore。每个接入都要有：

- target/lease/observation/args binding；
- stale/uncertain/generation 行为；
- receipt/evidence refs；
- old CLI compatibility；
- focused + root/CLI tests。

### P3 — Approval binding control plane

目标：冻结审批语义，保留 UI 独立范围。

- 建立 `ApprovalBinding` DTO：session/target/lease/operation/argsDigest/observation；
- approval mismatch、expired、used、withdrawn 状态机；
- approval 只允许控制面决定，Agent-facing action 不能自批准；
- 没有 UI 时只做 offline/client fixture，不伪造人工批准；
- approval 与 ActionAdmission 关系：approval 通过后才 issue admission，不能替代 admission。

### P4 — HTTP remote admission

仅在有真实远程 Agent 产品需求时推进：

- Bearer/token、session、owner identity、target/lease 绑定；
- Host/Origin/DNS rebinding 防护；
- upload token 绑定 session/target/lease/expiry/size/hash；
- remote off、idle timeout、close cleanup；
- sessionless 兼容不使用 User-Agent 作为强身份。

### P5 — session resume / remote lifecycle

- 明确 session owner 与 lease owner 的区别；
- 仅允许显式 resumable Agent；
- inflight action 不可被新 session 接管；
- Stop barrier 继承，避免 reconnect 绕过停止；
- reconnect grace、lease expiry、late result 和 evidence terminal status 联合测试。

### P6 — 真实运行时和设备范围

另立 scope：

- Android Companion / accessibility service；
- iOS CoreDevice/WDA/DDI；
- 真机、远程设备、云设备；
- 审批 UI、Wails 写控制面；
- 签名、发布、供应链和真实设备验收。

这些能力不从 SP-258 自动扩大。

## 依赖顺序

```text
P0 shared coordinator + receipt
  ↓
P1 device.action evidence/uncertain
  ↓
P2 remaining mutating surfaces
  ↓
P3 approval binding
  ↓
P4 HTTP remote admission
  ↓
P5 session resume
  ↓
P6 real runtime/device scope
```

P0/P1 是当前最优先的工程闭环；P3–P6 只有对应产品需求和独立验收边界明确后推进。

## 完成定义

- 所有已支持的 mutating action 使用统一 coordinator/receipt；
- 至少 runner、device.action、一个 app/host action 完成 evidence/uncertain/generation 联合验收；
- recovery/schema/old JSON compatibility 全部通过；
- 失败不会自动 replay；
- approval/HTTP/session resume 的未实现边界有明确文档；
- root、CLI、docs、schema 和适用 integration 门禁通过；
- 真实设备/远程/发布证据不被离线 fixture 替代。

# SP-279 ActionContext / Action Admission 全量实施计划

## 0. 计划目的

本计划把 Pinky 调研得到的 ActionContext/Action Admission 机制完整落入 TritonKit 的现有 CLI、HTTP、runner、evidence 和 target lease 边界，避免每完成一个小切片就重新询问下一步。

本批次默认连续推进；每个阶段完成后由主控自动检查真实 diff、测试和文档，下一阶段直接开始。只有以下情况才暂停并报告：

- 需要扩大到真机、云设备、签名/DDI、远程 Agent 或新的产品控制面；
- 需要用户选择不同产品语义；
- 当前环境无法自行修复的外部服务/工具链阻塞；
- 既有用户 WIP 与本批次文件发生不可安全裁决的冲突。

不以“子切片完成”作为最终完成标准，必须通过最终联合门禁和交付资料收口。

## 1. 已完成基线

### 1.1 设计和静态研究

- SP-256 Pinky 参考归档、正式深度调研和机制级评估已完成；
- SP-279 已冻结 ActionContext、ActionAdmission、receipt、delivery/outcome/postcondition、二次 gate、BDD 和不采用项；
- 设计依据见：
  - `docs-linhay/spaces/SP-279-pinky-reference/plans/20261110-pinky-formal-research-report.md`
  - `docs-linhay/spaces/SP-279-pinky-reference/plans/20261110-deep-technology-assessment.md`
  - `docs-linhay/spaces/SP-280-action-context-admission/plans/20261110-action-context-admission-design.md`

### 1.2 已落地代码

- `Sources/TritonKitShared/TKActionContextModels.swift`
  - `TKActionArgumentsDigest`：sorted-key canonical JSON、SHA-256/HMAC-SHA256、版本和 redaction profile；
  - `TKActionContext`：action/session/target/lease/observation/policy/approval identity；
  - `TKActionAdmission` 与 `TKActionAdmissionStore`：TTL、binding、cancel、expiry、duplicate ID、one-time consume；
  - `TKActionGenerationStore`：normalized target generation 与 late-result rejection。
- `Sources/TritonKitShared/TKEvidenceRunModels.swift`
  - `TKActionEvidenceMetadata`；
  - `TKEvidenceRunEvent.actionContext` 可选字段，旧 JSON 向后兼容。
- `Sources/TritonKitCLI/CLIHostApplePlatformRunnerRuntime.swift`
  - `device.platform-control` runner 在 exact target inventory 通过后签发/消费 admission；
  - receipt 携带 actionID、admissionID、contextDigest、delivery、originalStatus、terminalStatus；
  - receipt 可投影为 typed evidence metadata。
- 已有测试：
  - shared ActionContext/generation focused 17 项；
  - runner focused 12/12；
  - root 302 tests / 43 suites；
  - CLI 1680 tests / 179 suites。

## 2. 最终交付定义

批次完成必须同时满足：

1. 至少两类 mutating action 进入统一 Action Admission；
2. 每类 action 的 target/lease/args/observation/admission/receipt/evidence 关联可机器验证；
3. provider timeout、late result、Stop/cancel、stale observation、lease conflict 均 fail closed；
4. uncertain action 从不自动 replay；
5. `TKEvidenceRunEvent.actionContext` 在真实 evidence writer 路径产生并可解析；
6. HTTP/CLI schema、error code、nextAction/recovery 和旧 JSON 兼容测试通过；
7. root、CLI、适用 integration、docs、diff 门禁通过；
8. 设计、space、memory、README 和测试证据写回；
9. 未扩大到真机、云设备、Android Companion、审批 UI 或远程 resume，除非另立 scope；
10. 当前主目录既有 WIP 保持原样，不 stage/覆盖其它会话资料。

## 3. 阶段路线

### 阶段 A：基础合同（已完成）

**目标**：建立可复用的 shared ActionContext、args digest、AdmissionStore 和 generation guard。

**完成事实**：

- schemaVersion 和必填字段校验；
- SHA/HMAC digest；
- HMAC key 缺失 fail closed；
- TTL/expiry/cancel/binding mismatch；
- duplicate admission ID 不覆盖；
- 并发 consume 只有一个成功；
- late generation token 失效。

**门禁**：shared focused、root package。

### 阶段 B：第一个 provider 接线（已完成）

**目标**：将 admission 接入已有 iOS host XCTest runner。

**完成事实**：

- exact Simulator inventory 通过后签发 admission；
- xcodebuild 前一次性 consume；
- receipt 绑定 runner nonce、target、postcondition；
- success/delivery unknown/original terminal 状态均保存；
- target unavailable 不签发、不调用 runner。

**门禁**：ApplePlatformRunnerTests 12/12、CLI 全量。

### 阶段 C：receipt → evidence 正式接线（当前阶段）

**目标**：让 runner receipt 真正写入现有 evidence run event，而不是只提供 projection helper。

**文件面冻结前先做**：

1. 找到 `device.platform-control` 命令的 evidence/run writer 调用边界；
2. 确定 run_started/step_started/tool_call/tool_result/step_completed 的生命周期；
3. 确认 writer 不能因 receipt 写入失败改写 action receipt；
4. 确认 artifact refs 使用相对路径且不携带私有绝对路径；
5. 确认 actionContext metadata 不编码原始 xctestrun/result path、token 或敏感输出。

**实现内容**：

- 在 runner command 的显式 evidence 模式下创建或接收 `TKEvidenceRunLogWriter`；
- 在 tool_result/step_completed 事件中写入 `actionContext`；
- receipt/audit/artifact 路径转换为 evidence-relative refs；
- 写入失败返回 action receipt + `evidencePersistence=partial|failed`，不伪造完整 evidence；
- 不改变没有 evidence 输出目录的旧 CLI 行为；
- 增加旧 run event JSON 解码测试和新字段完整 roundtrip 测试。

**BDD**：

- runner 成功 + evidence 写入成功 → actionContext 和 receipt ref 同时存在；
- runner 成功 + evidence 写入失败 → action receipt 保留，run manifest partial/error；
- runner timeout → delivery unknown、originalStatus timed_out、terminalStatus timed_out；
- absolute/private path 不进入 public event；
- run 已 completed 或 truncated tail 时不追加 action event。

**门禁**：shared evidence focused、runner focused、root、CLI schema/evidence tests。

### 阶段 D：lease-aware admission

**目标**：把已有 `TKTargetLease` 从“外部 CLI gate”提升到 ActionContext/admission 的绑定事实。

**实现内容**：

- runner request 增加可选 `leaseID`/owner 入口，保持无 lease 兼容；
- target inventory 解析后用 normalized target 调用现有 `CLITargetLeaseGate`；
- ActionContext 保存 lease snapshot；
- admission contextDigest 包含 target/lease/action canonical 参数；
- lease 过期、target mismatch、owner mismatch 在 provider 调用前返回 typed error；
- takeover/release 后旧 admission 取消或消费失败；
- 不让 admission store 自己复制 lease store，保持单一 lease 真相源；
- 明确锁顺序：target lease check → admission store → provider lock；禁止反向锁顺序。

**BDD**：

- target A lease + target B request → provider call count 0；
- lease token expired → no admission/provider；
- takeover 后旧 admission → rejected；
- no lease → 保持现有 runner 兼容路径；
- read-only inventory/plan → 不要求 mutating lease。

**门禁**：lease store tests、runner tests、CLI schema/parser、root/CLI full。

### 阶段 E：late-result / generation 生命周期接线

**目标**：让 generation guard 真正包住 runner 的启动、完成、取消和超时生命周期。

**实现内容**：

- 每次 action admission 前 `begin(target, actionID)`；
- receipt completion、audit completion、evidence completion 都带 generation token；
- timeout/cancel/Stop 调 `invalidate(target)`；
- 迟到 runner 结果只能写 private diagnostic，不得完成新 action、释放新 admission 或覆盖新 receipt；
- 新 action generation 与旧 requestID 相同/不同都不能互相污染；
- 为异步回调增加明确 owner/session/action generation 检查。

**BDD**：

- A timeout → B starts → A late result → B receipt 不变；
- A cancel → late completion 不追加 A 的 run event；
- same target different actionID → old token rejected；
- target alias normalization 一致；
- invalidate 后所有旧 token rejected。

**门禁**：shared generation tests、runner async fixtures、CLI full。

### 阶段 F：第二类 mutating action 试点

**目标**：将统一 contract 扩展到一个不依赖 Apple platform runner 的 action，验证设计不是 runner 特例。

**候选顺序**：

1. `CLIDeviceActionsCommands` 中已有 requestID、observationID、geometry、postcondition 的 host action；
2. 如果其文件面与 host adapter 共享过多，再选择已有 WebView form input action；
3. 不选择需要新设备能力的动作。

**实现要求**：

- 复用同一个 ActionContext/AdmissionStore/generation；
- receipt 字段保持相同语义；
- provider delivery unknown 不 replay；
- stale observation 在 provider 调用前拒绝；
- old action JSON fields 保持兼容；
- 新 action 不引入自有第二套 admission state machine。

**门禁**：新 action focused、旧 action tests、root、CLI full、schema parser。

### 阶段 G：统一 recovery/schema/evidence contract

**目标**：将新状态纳入 TritonKit 的公共机器可读表面。

**实现内容**：

- 补 `approval_binding_mismatch`、`action_admission_used`、`action_admission_expired`、`action_generation_stale` 等稳定错误码；
- recovery taxonomy 映射：observe/diagnose/verify/archive，禁止 replay；
- schema 输出 ActionContext/receipt/actionContext metadata 字段；
- `nextAction`/`suggestedCommands` 使用现有 CLI 语义；
- 旧 error envelope 解码不受影响；
- evidence manifest 增加 actionContext/receipt refs 的字段说明；
- 不把 `postcondition=unverified` 编成 action failure，也不把 `delivery=delivered` 编成业务成功。

**BDD**：

- 每个新 failure code 都能生成一个合法单一 JSON envelope；
- recovery categories 不含自动 action replay；
- schema fields 与真实 parser/DTO/output 三方一致；
- old payload decode/encode 保持兼容。

**门禁**：schema fact-source、CLI parser、error envelope、evidence parser、root/CLI full。

### 阶段 H：并发和终态联合验收

**目标**：验证 admission、lease、generation、receipt、evidence 在竞态下保持不变量。

**fixture 维度**：

- provider succeeds / fails / timeout / delivery unknown；
- lease held / expired / takeover / release；
- action cancel / Stop / late result；
- evidence write success / partial / failed / truncated tail；
- same action duplicate / same admission duplicate / different generation；
- target alias / normalized target / runtime identity change。

**必须证明**：

- provider call count 和 admission consume count；
- old generation 无法写新 generation；
- originalStatus 不丢失；
- evidence partial 不改 action receipt；
- no automatic replay；
- no cross-target or cross-owner contamination。

**门禁**：focused concurrency suites、root、CLI full、docs。

### 阶段 I：最终交付与收口

**实现收口**：

- README 标明各阶段完成和未覆盖边界；
- 设计稿更新最终文件面、错误码、测试数量；
- memory 写入最终结论；
- CLI/HTTP schema、相关 dev 文档和 skills（适用时）同步；
- `git diff --check`、`check-docs.sh`、`verify.sh --ci-docs`；
- root tests、CLI tests、focused tests 和适用 package/release checks；
- 明确“不执行”真实设备、approval UI、remote resume、HTTP remote admission 的证据边界；
- 保留所有既有用户 WIP，不混入本批次提交/归档。

## 4. 任务依赖图

```text
A 基础合同
  ↓
B 第一个 runner admission
  ↓
C receipt → evidence 正式接线
  ↓
D lease-aware admission
  ↓
E generation 生命周期
  ↓
F 第二类 mutating action
  ↓
G schema/recovery/evidence contract
  ↓
H 并发联合验收
  ↓
I 交付收口
```

C 与 D 可以在文件面完全隔离时并行研究，但实现和共享测试必须串行。E 依赖 C/D 的 action identity；F 依赖 E 的 generation contract；G/H 必须等 F 的字段面冻结后再做最终版本。

## 5. 每阶段停止条件

阶段完成必须同时满足：

- 代码/文档 diff 与阶段文件面一致；
- 失败测试先出现并被最小实现修复；
- focused tests 通过；
- 受影响 root/CLI 回归通过；
- 新 error/schema/evidence 字段有兼容测试；
- 未把未执行的设备/网络/发布验证写成通过；
- 下阶段依赖已明确，没有隐含 TODO。

阶段失败时继续修复；不得用跳过测试、放宽错误断言、增加未使用父参数、吞掉 uncertain 或绕过旧契约来换绿色。

## 6. 统一风险控制

- ActionContext 不是宿主安全沙箱；同用户 shell/adb/xcrun 仍可绕过。
- SHA/HMAC 摘要不保存原始敏感参数；低熵敏感值使用 HMAC，key 归属和生命周期需单独冻结。
- Admission 不等于 lease；receipt 不等于 postcondition；delivery unknown 不等于未执行。
- terminalStatus 不覆盖 originalStatus；Stop 不证明 provider 未收到动作。
- evidence writer 失败不改变 provider verdict；partial/error 需要独立记录。
- generation token 必须绑定 normalized target 和 actionID；late result 不能污染新 generation。
- 不扩大到真实手机、云设备、远程 Agent、审批 UI 或 Wails 写控制面，除非另立 scope。

## 7. 最终完成定义

只有以下全部满足，才将 SP-279 标记为全量完成：

- 至少两类 mutating action 接入统一 admission；
- receipt metadata 能实际进入 evidence run event；
- lease、generation、stale、uncertain 和 postcondition 在至少一类异步 runner 和一类普通 action 上通过回归；
- 新 error/schema/recovery 字段和旧兼容合同通过；
- root/CLI/full docs 门禁通过；
- 设计、README、memory、索引和测试证据全部同步；
- 明确剩余未实现范围和真实验收边界；
- 未将任何未执行的设备/远程/发布验证冒充完成。

## 8. 当前下一执行点

阶段 A-H 已全部完成：基础合同、runner admission、evidence writer、lease-aware admission、generation 生命周期、第二类 mutating action、schema/recovery 和并发联合验收均已通过。当前进入 **I：文档与最终门禁收口**；I 完成后本批次关闭。

## 9. I 最终收口证据

- root：304 tests / 43 suites；
- CLI：1685 tests / 179 suites；
- focused：ActionContext 10、DeviceActions 8、runner 16、schema/recovery 67、EvidenceBundle 25；
- `git diff --check`、`check-docs.sh`、`verify.sh --ci-docs` 在最终变更后必须再次通过；
- 未执行真实设备、远程 Agent、审批 UI、HTTP admission、session resume、云设备、发布或第三方代码运行。

## 10. 批次关闭边界

SP-279 完成本批次的合同和离线/fixture 验收。其它 action 的全量迁移、人工审批控制面、远程 session resume、真实设备 provider 和发布供应链仍需独立 scope，不由本批次隐式扩大。
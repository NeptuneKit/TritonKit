# SP-257 — ActionContext 与 Action Admission 设计

## 当前状态

- 状态：P0 全量批次已完成。ActionContext/AdmissionStore、runner/evidence/lease/generation、第二类 device.action、schema/recovery 和并发联合验收均已通过；其它 action、approval UI、HTTP admission、session resume 和真实设备另立 scope。
- 来源依据：[SP-256 Pinky 正式调研](../SP-256-pinky-reference-research/README.md)。
- 目标：为 TritonKit 现有 mutating action 统一绑定 target、lease、observation、request、receipt 和 evidence。
- 本轮边界：只冻结合同、状态机、门禁顺序和 BDD；不修改产品代码，不新增 Web/Wails 控制面，不接入 Pinky 真实手机能力。

## 设计结论

P0 采用 `revise-first`：先在现有 CLI/HTTP/runner fixture 中验证 ActionContext 和 admission contract，再决定实现文件面。P0 不实现新的审批 UI，也不扩大真机、云设备或 Android Companion 范围。

## 目标场景

- Given 一个已有 mutating action，When 它进入 provider/host runner，Then 它具有唯一 actionID、规范化参数摘要、target identity、lease snapshot、observation identity、delivery/outcome/postcondition 和 evidence refs。
- Given admission 之前 target、lease、observation 或参数发生变化，When action 继续执行，Then fail closed，provider 不被调用。
- Given provider 已可能收到动作但回执未知，When action 返回，Then结果为 `uncertain`，保存 receipt，后续只建议 observe/reconcile，不自动 replay。
- Given action 被 Stop、timeout 或 evidence 写入失败影响，When terminal 结果生成，Then保留 originalStatus 与 terminalStatus，不覆盖原始 delivery 事实。

## P0 第一切片交付

已实现：

- `Sources/TritonKitShared/TKActionContextModels.swift`
  - `TKActionArgumentsDigest`：sorted-key canonical JSON、SHA-256/HMAC-SHA256、canonicalization/redaction metadata；
  - `TKActionContext`：action/session/target/lease/observation/policy/approval identity；
  - `TKActionAdmission`：issued/consumed/cancelled/expired；
  - `TKActionAdmissionStore`：注入时间、TTL 边界、binding 检查、重复 ID 拒绝、线程安全 one-time consume。
- `Tests/TritonKitSharedTests/TKActionContextModelsTests.swift`
  - 8 项 focused tests：digest 稳定性、HMAC key、schema/roundtrip、binding、duplicate ID、expiry、cancel、32 路并发 single-use。

验证：root package `swift test --no-parallel` 通过，302 tests / 43 suites；P0 focused suite 8/8 通过；CLI package `swift test --package-path CLI --no-parallel` 通过，1680 tests / 179 suites。

## P0 第二切片交付

已将 admission 接入 `device.platform-control` 的 iOS host XCTest runner：

- exact Simulator target inventory 通过后签发并消费一次性 admission；
- ActionContext 绑定 runner nonce、target、platform/action、private path 摘要和 operation；
- runner receipt 增加 actionID、admissionID、contextDigest、delivery、originalStatus、terminalStatus；
- runner timeout/unknown 路径保留 `delivery=unknown`，不自动重试；
- target inventory 不可用时不会签发 admission，也不会调用 runner；
- 旧 runner target/nonce/postcondition/audit 约束保持。

涉及文件：`Sources/TritonKitCLI/CLIHostApplePlatformRunnerRuntime.swift`、`CLI/Tests/TritonKitCLITests/ApplePlatformRunnerTests.swift`。focused runner tests 12/12 通过。

## P0 第三切片交付

已完成：

- `TKEvidenceRunEvent.actionContext` typed metadata：actionID、admissionID、contextDigest、delivery、outcome、executed、original/terminal status、postcondition 和 evidenceRefs；旧 JSON 保持兼容；
- runner receipt → `TKActionEvidenceMetadata` projection helper；
- `TKActionGenerationStore`：按 normalized target 递增 generation，拒绝旧 token、不同 actionID 和 invalidate 后的迟到结果；
- shared metadata/generation focused tests 17 项通过，runner focused 12/12 通过。

## C 阶段 evidence writer 交付

已完成显式 `device platform-control --evidence-dir <dir>` 接线：

- action 前写入 run_started/step_started/tool_call；
- receipt 写入 `run/action-receipt.json`；
- tool_result/step_completed/run_completed 携带 typed actionContext；
- evidence 写入失败保留 action receipt，并标记 `evidencePersistence=failed`；
- schema 已公开 `--evidence-dir` 和 receipt metadata；
- 旧无 evidence-dir 行为保持。

验证：Apple runner 13/13、EvidenceBundle 25、schema focused 52 项通过；root 302 tests / 43 suites、CLI 1680 tests / 179 suites 通过。

## D 阶段 lease-aware admission 交付

已完成：

- runner request 支持可选 `leaseID`；
- CLI 支持 `--lease`、复用现有 server 原子 lease check；
- lease check 在 target inventory 通过后、admission 签发前执行；
- contextDigest 绑定 leaseID；
- lease gate 拒绝时不签发/消费 admission、不调用 runner；
- 无 lease 继续兼容旧路径；
- parent/subcommand schema 已登记 lease。

验证：runner focused 15/15；Apple control/schema focused 59 项；CLI 全量 1680 tests / 179 suites 通过。

## E 阶段 generation 生命周期交付

已完成：

- runner action 开始时创建 normalized target/actionID generation token；
- provider 返回后和 attachment receipt 验证前二次校验；
- 旧 generation 返回 `runner_generation_stale`、delivery unknown、executed unknown；
- 不自动 replay，旧结果不污染新 admission/receipt/evidence；
- failure code 已同步 runner schema/recovery。

验证：Apple runner focused 16/16；D 阶段 control/schema 59 项和 CLI 全量 1680 tests / 179 suites 已通过。

## F 阶段第二类 mutating action 试点

已开始接入 `device.action` 统一入口：

- common options 支持可选 `--lease`；
- target resolve 后执行 server lease gate；
- tap/double-tap/swipe/press/type 构造 ActionContext 和 canonical args digest；
- AdmissionStore 在 host command/iOS runner 前签发并消费；
- Android/Harmony/iOS 结果补 action/admission/context/delivery/outcome/terminal metadata；
- generation stale fail closed；
- text file path 只进入 private redaction digest；
- device action schema 已登记 `--lease`。

## G 阶段 schema/recovery 交付

已完成：

- `device_action_generation_stale` 与 `device_action_result_invalid` 稳定错误码；
- generation stale recovery 为 diagnose/observe/verify，禁止 replay；
- result invalid recovery 为 diagnose/plan；
- device parent schema、subcommand、recovery taxonomy 和 fact-source taxonomy 同步；
- F action `--lease`、context metadata、receipt fields 保持 schema-backed。

验证：ActionContext 10 项、DeviceActions 8 项、runner 16 项、schema/recovery 67 项；root 304 tests / 43 suites、CLI 1685 tests / 179 suites 全量通过。

下一阶段自动进入 I：文档与最终门禁收口。

- [P0 全量实施计划](./plans/20261110-action-context-admission-full-rollout-plan.md)
- [P0 设计说明](./plans/20261110-action-context-admission-design.md)
- [Pinky 正式调研](../SP-256-pinky-reference-research/plans/20261110-pinky-formal-research-report.md)
- [当前 target lease 合同](../../../../Sources/TritonKitShared/TKTargetLeaseModels.swift)
- [当前 evidence manifest 合同](../../../../Sources/TritonKitShared/TKEvidenceModels.swift)

## 非目标

- 不复制 Pinky 的 Go/MyGo UI、真实手机 driver、Android Companion、CoreDevice/WDA、FFmpeg 或 adb 打包。
- 不把 ActionContext 变成宿主安全沙箱；同用户 shell、adb、xcrun 和其他 host 工具仍是独立信任边界。
- 不把自由文本 MCP 结果加入 TritonKit 主契约；继续使用 JSON/JSONL/schema/evidence。
- 不要求所有已有命令立即强制 lease；P0 先覆盖已有 lease gate 和明确声明 mutating 的 action。

## 验收门槛

- 设计文档完成，字段、状态、错误、证据和迁移规则无互相矛盾项。
- BDD 场景覆盖 lease/approval/observation/uncertain/stop/concurrency/evidence failure。
- `git diff --check`、`check-docs.sh` 和 `verify.sh --ci-docs` 通过。
- 实现前必须由独立实现 space 冻结文件面、测试策略和兼容策略。

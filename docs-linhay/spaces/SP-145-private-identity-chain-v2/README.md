# SP-145 Private Identity-Chain v2

## 状态

- 状态：已完成（本地，纯离线合同）。
- 负责人：Codex。
- Branch：`feat/SP-145-private-identity-chain-v2`。
- Worktree：`../TritonKit-worktrees/SP-145-private-identity-chain-v2/`。
- 基线：`feat/SP-144-reliability-receipt-anchor@ab6cbf1e`。

## 裁决

**Adopt：以 SP-144 的 operator-owned `receiptSha256` 为根，为每个已执行 receipt slot 写入私有 `reliability/identity-chain-v2.json`，并在 receipt-backed report 中离线验证它。**

该链只证明当前读取时，receipt、binding、reset receipt、normalized plan、runtime target、run metadata 和 events 的 bytes 与冻结 identity 自洽；它不证明 reset 真正发生、App build/runtime 身份、设备/服务独占、链在历史执行时生成，亦不抵御 hostile filesystem 或完整重写所有私有证据后重算 hash 的攻击者。

## 边界

包括：

- 新增 v2 私有 sidecar，保存 anchor-aware receipt linkage、flow/slot/frozen identity、terminal outcome，以及固定六个组件的 lowercase raw-byte SHA-256 与 canonical body SHA-256。
- sample 只在既有 runner 完成、所有固定组件存在且 manifest 可安全追加时，以 no-clobber 方式写入 chain；runner 失败、组件缺失或写入失败不做 backfill/cleanup，也不伪造完成。
- report 在 SP-144 anchor 已验证后，要求每个 receipt slot 的 chain 存在、body/hash/六个 artifact hash、frozen identity 和唯一 manifest private declaration 全部一致；缺失/漂移只使 typed receipt-backed report blocked，并使用脱敏 `identity_chain_*` issue/blocker。
- legacy `--samples` 保持诊断，不要求 anchor/chain；v1 receipt slot 不迁移或事后补链来放行。
- schema/output contract/BDD/public agent 文档清楚区分“离线 identity consistency”与真实 reset/App/runtime proof。

不包括：

- 新的采样器、Server/Simulator/Xcode/设备操作、reset recipe 生成、App build identity 或 runtime attestation。
- 密钥、签名、nonce、远端 ledger、Merkle 全量 screenshot/AX 树、链迁移/backfill、Stage 1 指标口径或 #164 WIP。
- 改写 SP-144 external receipt anchor 的算法、入参或 fail-closed 顺序。

## BDD 验收

1. Given 正确的 root 外 `receiptSha256` 和完整合成 run evidence，When receipt-bound sample 完成，Then 它只写一个 chain、manifest 只声明一次，chain 覆盖固定六个私有/运行组件，且不回显私有身份。
2. Given 任一 binding、reset receipt、normalized plan、runtime target、run metadata、events、chain body/hash 或 manifest declaration 被改动，When receipt-backed report 运行，Then gate blocked 且以稳定 `identity_chain_*` issue 表达，不回显 path/hash/UDID/bundle/selector。
3. Given 旧 slot 没有 v2 chain，When receipt-backed report 运行，Then 明确 `identity_chain_missing`，不得离线补写来放行。
4. Given valid expected negative control 的完整 chain，When report 运行，Then chain integrity 可通过，但 existing negative taxonomy/outcome gate 仍独立执行。
5. Given legacy `--samples`，When reliability report 运行，Then 仍为 legacy diagnostic，不出现外部 anchor/chain 通过的暗示。

## 实现与验证

- 新增 `CLITestReliabilityIdentityChainRuntime.swift`：固定六个 raw-byte SHA-256、canonical body SHA-256、exclusive writer、manifest declaration 与 fail-closed validator；`CLITestReliabilityReportModels.swift` 将 report model 从 1495 行 runtime 文件拆出，并新增不含私有身份的 `identityChain` aggregate。
- sample 在 exact target preflight 后先写 private runtime-target sidecar；runner 结束后才写 chain 并追加 manifest。组件缺失或 chain/manifest 写入失败返回 `reliability_identity_chain_write_failed`，保留 claimed evidence，不 backfill、cleanup 或自动 rerun。
- receipt-backed report 仍不改 ECR/FER/ORR 口径；只把 `identity_chain_*` 写入 issueCounts 与 `identity_chain_incomplete` / `identity_chain_invalid` blockers，避免把纯 chain 缺口误标为 receipt binding 问题。终态不可解析时固定 `identity_chain_terminal_unavailable`，不会伪造 `.blocked` descriptor。
- 已通过独立 scratch `CLI/.build/sp145-identity-chain-v2` 的 `TestReliabilityIdentityChainTests`（2）、`TestReliabilityHarnessTests`（20）、`TestReliabilityHarnessRuntimeTests`（4）、`TestReliabilityCollectionRuntimeTests`（4）、`TestReliabilityRuntimeTests`（33）、`TestValidationTests`（18）、`FailureDiagnosticsTests`（13）、`SchemaFactSourceCapabilityTests`（22）和 `PublicSkillCommandSchemaTests`（1）；release `triton` build 与动态 `schema --command test --json` 字段/错误码核验也通过。
- `SchemaFactSourceContractTests` 仍是既有 device/sim registry 的 6 项失败，未引入 SP-145 失败；`check-docs.sh` / `verify.sh --ci-docs` 仍因 SP-141 / SP-142 未集成导致编号连续性停止，不能以编号占位掩盖。全程未启动 server、Simulator、设备、Xcode 或真实 test runtime。

## 验证与停止条件

- 先建纯模型/validator 的 red tests，再以合成临时 evidence 做 sample/report integration；只串行使用 `CLI/.build/sp145-identity-chain-v2`。
- 不启动、探测、停止或复用 server；不访问 Simulator、设备或 Xcode，不执行真实 `test run`，不修改 #164。
- 若实现需要读取/写入 root 外 anchor 文件、证明真实 reset/App/runtime identity、或改变 ECR/FER/ORR 口径，立即停止并另建裁决 space。
- docs 连号门禁仍将因 SP-141/SP-142 未集成而停止；不得新增编号占位伪造连续性。

## 后续队列

1. SP-146：以 additive public contract 区分 Stage 1A（60 supported ECR/ORR）和 Stage 1B（61 receipt/control integrity、FER）。
2. 仅在 SP-144～146 离线合同完成后，向用户申请 dedicated Simulator、server ownership、reset recipe、安全 negative control 与 private evidence lifecycle 的真实 3 × 20 + 1 授权。

# SP-140 Live Collection Contract v01

## 目的

以机器可读 receipt 约束未来真实采样，而不是以离线 preflight 或合成 evidence 声称可靠性已达标。

## 私有状态机

```text
collection + mutable plans
        │ offline validate / normalize
        ▼
new root ──atomic mkdir──► collection-receipt.json (immutable frozen contract)
                                      │
                             operator reset attestation
                                      │
                         exact live target preflight
                      (id + connected + iOS + UDID + bundle)
                                      │
                                      ▼
exclusive empty slot ─► binding.json + reset-receipt.json ─► strict runner
                                                              │
                                                              ▼
                                                           manifest
```

任何已存在 root、receipt、slot、`run/` 或 manifest 都是停止条件，不允许清理或重试覆盖。slot 的最终叶目录以原子 `mkdir` claim；普通 `test run` 可复用 evidence dir 的兼容行为不能借到 receipt 路径。

## 冻结内容

- canonical iOS Simulator runtime target、UDID、bundle 与 binding digest；
- anon flow alias、分类、slot、initial state、reset recipe 与 evidence relative path；
- validated normalized plan、plan digest 与 execution identity digest；
- negative control 的预期 `nonpassed`。

`executionIdentityDigest` 只取 app/device/settings 与有序实际 step payload；它故意忽略 plan name、provenance、step id/index/kind 与路径，以阻止仅改元数据伪造三条不同 flow。

## 非目标与运行时授权

reserve 和 receipt gate 只读/本地文件操作；sample 需要显式 `--confirm`。即使 sample 路径已具备 runner bridge，也不会 boot、reset、install、launch、stop 或复用任何 host service；这些状态须在未来真实采样前由 operator 单独确认并留下 reset receipt。

sample 仅在外部已启动的 `127.0.0.1:19421` 上进行一次 target preflight；它不启动或选择 server/runtime。preflight 必须逐字段匹配 receipt 的 canonical target，随后将该 summary 固定给 live runner，禁止普通 target resolver 的同 UDID 或 bundle fallback。

### 严格 target 协议

- sample 把完整 receipt target（而非裸 selector 字符串）交给 live resolver。
- live resolver 直接读取 `GET /targets`，只筛选 `summary.id == receipt.target.id`；候选必须恰好一个，并同时满足 `connected=true`、`platform=ios`、相同 UDID 和相同 bundle。
- exact id 缺失、重复、同 UDID 其他 app、bundle 缺失、platform 漂移或断连均在 slot claim 前失败。成功 summary 只用于 pin receipt-bound runner，不允许 runner 再退回通用 resolver。
- 服务端也将 fully-qualified `triton:ios-simulator:<UDID>/app:<bundle>` 视为 exact-only 请求：exact miss 不得退回 UDID；裸 `triton:ios-simulator:<UDID>` 保持历史 selector 兼容。

### 恢复与残余威胁模型

reserve/sample 的 schema recovery taxonomy 只给出不变更运行时的 `diagnose`；receipt 写入或 runner bridge 失败可附加 `archive`，提醒保留而非删除私有事实。不会生成 `--confirm`、force、cleanup、retry 或 lifecycle 命令。

leaf slot 使用原子 `mkdir`，receipt 使用 `O_EXCL|O_NOFOLLOW`；这覆盖正常本地竞争和已有文件/目录。父目录仍不是 hostile-local-FS 对抗边界：若攻击者能够在检查与使用之间替换受控目录，本期不承诺消除所有 symlink TOCTOU。因此真实收集只可使用 operator 独占的私有可信路径。

## 验证批次（已完成本地 focused 验证）

本批次只允许 fake executor、纯 target selector、parser/schema 和临时文件 fixture；未启动 `triton serve`、Simulator、Xcode、设备或真实 `test run` runtime。所有 CLI 测试使用本 space 独立 scratch 串行运行：

1. `swift test --package-path CLI --scratch-path .build/sp140-ios-reliability --filter TestReliabilityHarnessRuntimeTests`
2. `swift test --package-path CLI --scratch-path .build/sp140-ios-reliability --filter TestReliabilityHarnessTests`
3. `swift test --package-path CLI --scratch-path .build/sp140-ios-reliability --filter ServerTargetSelectionTests`
4. `swift test --package-path CLI --scratch-path .build/sp140-ios-reliability --filter TestReliabilityCollectionRuntimeTests`
5. `swift test --package-path CLI --scratch-path .build/sp140-ios-reliability --filter TestReliabilityRuntimeTests`
6. `swift test --package-path CLI --scratch-path CLI/.build/sp140-ios-reliability-validation --filter TestValidationTests`（该 suite 以当前测试 bundle 同级 `triton` 作 subprocess，故 scratch 必须位于 `CLI/.build`）
7. `swift test --package-path CLI --scratch-path .build/sp140-ios-reliability --filter FailureDiagnosticsTests`
8. `swift test --package-path CLI --scratch-path .build/sp140-ios-reliability --filter SchemaFactSourceCapabilityTests`
9. `swift test --package-path CLI --scratch-path .build/sp140-ios-reliability --filter TestCreateFromSessionTests`
10. 根 package 的 `TKCLITransportModelsTests` 使用独立 `.build/sp140-ios-reliability-shared`。

以上 focused suites 均已通过。`SchemaFactSourceContractTests` 额外执行后暴露 6 个既有无关失败（device 子命令参数/selector、`sim app-console` recovery、device capability examples）；未出现 reliability/receipt/target 相关 failure，故记录为基线问题而不在本 space 扩修。

`git diff --check` 已通过。真实 3 flow × 20 + 1 negative 的授权、设备、server ownership、reset attestation 和私有 evidence 路径均不属于此批次。

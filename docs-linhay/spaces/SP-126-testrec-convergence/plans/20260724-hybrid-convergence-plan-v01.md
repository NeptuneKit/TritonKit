# SP-126 Hybrid Convergence Plan v01

> 日期：2026-07-24
>
> 状态：已裁决，待按 P0 开始实现
>
> 决策范围：Test Recorder Replay 的产品边界、执行归属与首个验证切片

## 决策

将 Test Recorder 收敛为 **录制包 / 编译 / 导入兼容层**，并把唯一真实执行路径收敛到既有 `test` runtime：

```text
.tritontestcase
  └─ testrec inspect / compile / quality / page matcher
       └─ triton test import (新契约，fail-closed)
            └─ .tritontest.yaml + provenance
                 ├─ triton test validate / normalize
                 └─ triton test run ──> .tritonevidence
                                      └─ workspace 可在后续复用同一合同做编排
```

`replay` 继续服务于 `.tritonplan` 的低层 smoke，不成为 `.tritontestcase` 的第二个上层 runner。`testrec local-simulated` 维持只读/诊断兼容能力，但不再扩展为 device executor。

## 代码事实与判断依据

1. `testrec` 已拥有不可丢弃的输入价值：显式事件 session、`.tritontestcase`、deterministic compiler、Action/Page/Network Map、quality finding、脱敏 gate、proposal 和 page matcher；对应 CLI/HTTP surface 及 contract tests 已较完整。
2. 但 `testrec` 的非 dry-run 成功目前只允许 `local-simulated`；`local-device` 明确缺 target、动作、artifact 与 network-policy 能力，继续补它会复制第二个 executor。
3. `test run` 已有 `TKTestNormalizedPlan`、live primitive executor、target resolve、before/after observation、输入动作与 `.tritonevidence` 写入。这正是录制回放缺失的真实路径。
4. `workspace` 已覆盖 target/lifecycle/observation/Atlas，并能导出 `.tritontest.yaml`、建议 `test validate` / `test run`。这说明“工作流编排 → test 合同 → evidence”已经是现有代码的前进方向。
5. 因而最小风险不是搬运所有录制 runtime，而是在 `testrec` 与 `test` 之间补一个受版本和安全门约束的 importer，再用现有 runner 证明一个真实目标。

## 目标契约

### 新的稳定入口

目标 CLI 为：

```text
triton test import <case.tritontestcase> --output <plan.tritontest.yaml> --json
```

它属于 `test` 而不是 `testrec`，因为输出从此进入规范测试生命周期。初期不增加 Web 控制面；CLI 稳定后，如自动化确有需要，再由同一 service 增加对应本地 HTTP route。

导入器必须：

- 只消费已编译的 `compiled-contract.json`、必要 map 和 manifest，不重复实现录像收集或真实设备执行。
- 生成确定性的 `.tritontest.yaml`，并附带不含敏感原文的 provenance（case identity、compiled-contract digest、compiler/import 版本、已审查状态）。
- 对未知 action、无法表示的 selector/page assertion、未审查 redaction、未满足的能力或版本不兼容一律 fail closed；输出 machine-readable blocker 和 next action。
- 不把 proposal 自动应用到测试计划；proposal 仍是人工/agent 审查输入。
- 让最终 evidence 能关联 source contract digest；此项应通过版本化、可选的 `.tritontest.yaml` provenance 字段或等价的受 `test run` 消费的 sidecar 实现，不能仅存在 import terminal output 中。

### 不承诺的转换

第一期只转换能一一映射到现有 `TKTestNormalizedPlan` 的 P0 action / assertion。无法保真表达的录制合同必须报告 `unmapped_contract_feature`，而不是降级为 `sleep`、坐标猜测或 simulated pass。页面 matcher 和 network map 继续作为导入前检查/未来工作流输入；不在本期启用 live network interception。

## 分阶段执行

### P0 — Contract seam 与失败测试（第一个代码切片）

1. 在 `test` surface 增加 importer 的纯函数与 CLI 壳，先写 fixture-based focused tests。
2. 固定 import response、blocker taxonomy 和 provenance 结构；复用现有 JSON envelope，不二次包装错误。
3. 先覆盖四类失败：缺 compiled contract、redaction 未审查、未知/不可映射 action、source identity 变化；再覆盖一个最小成功 case 的 deterministic output。
4. 仅在 importer 的输出已能被 `test validate` 接受后，才接入 live run；不要先写 testrec executor 的 bridge。

建议落点：`CLI/Sources/TritonKitCLI/CLITestCommands.swift` 增加 `import` 子命令；转换/验证代码靠近现有 `CLITestValidationRuntime.swift` 与 test model，而不是继续膨胀 `CLITestRecorderReplayRuntime.swift`。原 testrec runtime 只提供编译产物读取和 compatibility response。

### P1 — 真实 iOS Simulator 单动作纵切

1. 选择一条现有 `test run` 已支持的动作类型和一个无敏感 fixture；首个 target 固定为 iOS Simulator / Debug embedded runtime，并先保存 `triton status/doctor/capabilities/schema/plan --json` 的 Triton-first 事实。
2. 使用 importer 生成计划，依次运行 `test validate`、`test run --target <显式 iOS Simulator target> --evidence-dir ...`。
3. 若 importer 发现 test plan 缺少动作/目标表达，只扩展 `test` 的 shared primitive adapter；不得在 `testrec` 中重建 resolve、observe、act 或 evidence writer。
4. 验收 evidence 至少含 normalized/import provenance、run events、before/after observation、实际动作命令结果和最终 verdict；失败时保留单一 failure envelope 与恢复建议。

### P2 — Workspace 编排接入

在 P1 真实证据闭环后，让 workspace 复用 importer 和 `test run`：workspace 负责 lifecycle、target 和 Atlas 的上游上下文，测试 runtime 仍负责步骤执行和 verdict。Android 只有在明确 host primitive adapter 完成后才进入该路径；此阶段先增加读模型/导出衔接，不新增 Web 写入口。

### P3 — 兼容迁移与淘汰评估

1. `testrec inspect/compile/proposals/match-page` 保持；`testrec replay` 和 matrix response 添加明确迁移提示、execution mode 和禁止误读的状态。
2. 在 CLI/HTTP schema 中标注兼容期限与替代命令，但不删除 route，也不改写历史 `.tritontestcase` / evidence。
3. 只有满足以下全部条件才提请删除独立 executor：至少一个真实平台验收；导入器覆盖 P0 可映射合同；source-to-evidence provenance 已验证；现有用户可通过稳定命令完成迁移；并获得一次单独的兼容窗口/破坏性变更裁决。

## 借用、拒绝与待后置

| 类型 | 结论 | 原因 |
| --- | --- | --- |
| 借用 | `test` 的 normalized plan、live primitive executor、observation、evidence writer | 已是唯一实际执行能力，避免同语义双实现 |
| 借用 | workspace 的 target/lifecycle/Atlas 编排 | 已有工作流事实，不新建 testrec run registry |
| 保留 | `.tritontestcase`、deterministic compiler、quality/redaction、page matcher | 是录制来源与安全审查的独特价值 |
| 拒绝 | 完成 `testrec local-device` 后再迁移 | 会先固化第二条 device/execution/evidence 管线 |
| 拒绝 | 立即删除 testrec CLI/HTTP/包格式 | 已有兼容消费者、schema 与历史证据，破坏性过高 |
| 后置 | 跨平台矩阵、真实网络策略、自动 proposal apply、系统级监听、真机 | 未通过单平台真实闭环，且会放大语义与安全风险 |

## 验证矩阵

| 层 | 最低验证 | 通过条件 |
| --- | --- | --- |
| Import | focused fixture tests + `test validate` | 成功输出稳定；每类 blocker fail closed 且无设备副作用 |
| 兼容 | 既有 `TestRecorderContractTests` | inspect/compile/HTTP 不回归；simulated 不被标为 device execution |
| Test runtime | focused `TestValidation` / `TestRun` tests | provenance 写入计划和 evidence；错误仍是一个合法 envelope |
| 真机前模拟器 | iOS Simulator / Debug embedded runtime 实际 smoke | resolve → before observe → act → after observe → evidence，非 `local-simulated` verdict |
| 回归 | `go test ./...`（如改动 Go 层）、Swift 对应 test target、`docs-linhay/scripts/verify.sh --local` | 与改动层匹配；环境不可用时保存事实和 blocker，不把缺证据当通过 |

## 执行顺序与停止条件

接下来只启动 P0。P0 完成前，不开始 P1 设备动作，也不对 historical `testrec` 实现做删除、迁移或真实 executor 开发。P0 若发现 `.tritontest.yaml` 无法无损表达最小录制合同，先将差异写回本计划并重新裁决计划格式，不以隐式转换绕过问题。

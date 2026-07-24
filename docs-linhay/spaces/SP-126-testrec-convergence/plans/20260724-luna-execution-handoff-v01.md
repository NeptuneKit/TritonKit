# SP-126 Luna Execution Handoff v01

> 日期：2026-07-24
>
> 接收者：Luna
>
> 状态：可执行；本文件所在提交是本次路线收口检查点（用 `git log -1 --oneline feat/SP-126-testrec-convergence` 取得 hash）

## 交接结论

TritonKit 的长期主线已经裁决为：**本机移动 App 的 agent-safe execution-and-proof substrate**。近期不以“补全录制回放”或“三平台功能齐全”为目标；先证明 agent 能在受控范围内执行、验证、解释失败并交付可追溯 evidence。

Test Recorder Replay 采用 Hybrid 收敛：

```text
.tritontestcase
  -> testrec inspect / compile / quality / page matcher
  -> triton test import
  -> triton test validate / test run
  -> .tritonevidence
```

`testrec` 保留录制、确定性编译、质量/脱敏和兼容读取；`test run` 是唯一真实执行和最终 verdict；`workspace` 后续只编排并复用同一测试合同；`replay` 继续是 `.tritonplan` 的低层 smoke。不得再发展独立 `testrec local-device`、matrix 或第二 evidence writer。

## 已完成与可复用入口

| 项目 | 结果 | 入口 |
| --- | --- | --- |
| 路线裁决 | Hybrid 与单一真实 runtime 已锁定 | [SP-126 README](../README.md) |
| 具体实现合同 | `test import`、fail-closed blocker、provenance、兼容迁移和 P0–P3 顺序已定义 | [Hybrid Convergence Plan](./20260724-hybrid-convergence-plan-v01.md) |
| 长期投资顺序 | 可信基线 → iOS Simulator → importer → agent workflow → Android adapter | [12 个月路线](../../../plans/20260724-agent-native-local-execution-roadmap-v01.md) |
| 历史兼容边界 | SP-077 不再扩展真实 replay；仅保留历史合同与诊断资产 | [SP-077 README](../../20260622-test-recorder-replay/README.md) |

本次为 docs/路线提交。已经执行并应在当前提交上复核的门禁：

```text
git diff --check
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/verify.sh --ci-docs
```

它不等同于代码实现、设备 smoke 或 release 验收。

## 执行边界（不可改写）

1. 首个平台是 **iOS Simulator + Debug embedded runtime**。Android 当前只有部分 host/discovery/observation 能力，不能表述成相同的 `test run` runtime；Android 需等共享的显式 host primitive adapter。
2. 没有 target、动作结果、before/after observation、业务断言和 evidence manifest 的运行，不能称为 passed。
3. 未审查 redaction、未知 action、不可保真表达、缺 provenance 或版本不兼容必须 fail closed，且只返回一个合法 machine-readable envelope。
4. CLI/HTTP 是事实入口；不可因方便新增 Web/Wails 写控制面。
5. 不承诺设备云、远端 agent、多租户、全量网络代理、完整真机 UI 自动化或平台对等。

## 开始顺序

### 0. 先做只读的风险定责

先检查以下独立 worktree，**不得修改、合并、删除、借用或重置其中任何文件**：

```text
../TritonKit-worktrees/20260722-issue-164-evidence-simulator-screenshot-fidelity/
branch: codex/20260722-issue-164-evidence-simulator-screenshot-fidelity
```

记录它相对 `main` 的意图、owner、影响文件、已有测试和与当前 evidence schema 的重叠。若 owner/意图不能确认，保留隔离并向用户请求决定；不要把它混入 SP-126，也不要因此假定它可丢弃。

### 1. 清可信基线，不写 importer

每一项创建独立 space、branch 和同级 worktree，BDD/TDD 后再改代码；有副作用的验证串行执行：

1. #166：真机 JPEG evidence 的数据完整性边界。
2. #168：真实设备 terminate 的 PID / recovery 契约。
3. #167：Xcode device alias 在昂贵 build 前 fail-fast。
4. `triton serve` loopback 默认与 Web 只读 DTO 叙述/实际行为的一致性裁决。
5. 冻结一个 iOS Simulator canonical fixture：App 版本、target、初态、单一动作、业务断言和 expected evidence taxonomy。

先在每项开始时用 Triton-first 保存 `triton status/doctor/capabilities/schema/plan --json`。只有 Triton 返回失败、unsupported 或未覆盖时，才回退 host 工具并记录理由和命令。

### 2. 证明 iOS canonical runtime

在可信基线完成后，新建有限实现 space，先用**手写** `.tritontest.yaml` 完成三条 iOS Simulator flow：launch/readiness、tap/状态变化、input/断言。每条均必须产生 target、before/after observation、实际动作、业务验证、provenance 和 `.tritonevidence`。

在冻结初态下采样 60 次（3 flow × 20），阶段门槛为 ECR ≥ 95%、FER ≥ 90%、ORR ≥ 90%。ORR 只要求 verdict、step status、artifact/failure taxonomy 一致，不要求时间戳、run ID 或截图字节相同。若 ORR < 70% 或多数失败无法定位，停止后续 importer / 新平台扩张，先收敛 runtime/evidence。

### 3. 才开始 SP-126 importer

新建有限实现 space 后，按下列最小切片实施：

1. 为 `triton test import <case.tritontestcase> --output <plan.tritontest.yaml> --json` 写 fixture-based 失败测试。
2. 只读取已编译 contract、必要 map 与 manifest；输出确定性 YAML 和 privacy-safe provenance。
3. 先覆盖缺 compiled contract、redaction 未审查、未知/不可映射 action、source identity 变化，再覆盖一个最小成功 case。
4. 仅在 import 输出可被 `test validate` 接受后接 `test run`；缺少表达时扩展 `test` shared primitive，不在 `testrec` 复制 target resolve、observe、act 或 evidence writer。

通过门槛：至少 10 个预登记 case 中 70% 无人工 YAML 修改即可 import + validate；至少 5 个已支持 iOS flow 各运行 10 次，ORR ≥ 80%。不达标则保留 testrec 的质量/脱敏/诊断资产，并把产品重心收回 evidence + hand-authored test workflow。

## 后续队列与停止条件

| 优先级 | 工作 | 进入条件 | 禁止的捷径 |
| --- | --- | --- | --- |
| 1 | 可靠性与事实债 | 立即可开始；#164 只读定责先行 | 混入遗留 WIP 或跳过 release/evidence 风险 |
| 2 | iOS canonical proof | 基线已收口、fixture 已冻结 | 用 simulated pass 或 Android host surface 替代 |
| 3 | `test import` | iOS evidence 通过阶段门槛 | 在 `testrec` 再写 executor/matrix |
| 4 | 真实项目 / agent 采用 | importer 的 iOS proof 已达标 | 把内部 demo 宣称为外部用户验证 |
| 5 | Android adapter | 前四项通过且有真实需求 | 复制 iOS/testrec 的 runner 或 evidence schema |
| 6 | Harmony / Web / 网络 | 独立需求和 space 裁决 | 抢占主线资源 |

Harmony 维持实验性 host adapter。iOS 真机只维护已验证的 lifecycle/evidence 范围，不承担第一条 UI-test 产品证明。

## 工作方式与回报格式

- 实现前先新建 space；不要预占 SP 编号。每个 issue/有限切片独立 branch/worktree，保持 SP-126 作为决策和路线锚点。
- 修改前写 BDD 和失败测试；Go 默认运行 `go test ./...`，Swift 改动跑对应 test target；常规代码改动最终跑 `docs-linhay/scripts/verify.sh --local`。环境无法提供 smoke 时，保存事实、blocker 和风险，不能写“已通过”。
- 每次收口更新对应 space、`spaces/README.md`、`spaces/INDEX.md`、当天 `docs-linhay/memory/YYYY-MM-DD.md`；再执行 `git diff --check` 与适配的 docs/code 门禁。
- 不覆盖主工作区的未提交文档；不触碰 #164 WIP；远端 push、PR、merge、tag、release、关闭 issue 都需要用户明确授权。
- 每次向用户汇报：目标、改动文件、测试/证据、未验证项与风险、下一条 Go/Stop 判定。对 agent 价值的指标优先汇报 VRCR、ECR、FER、ORR、ZTTC、TFVE，而不是命令数或录制数。

## 第一次回报应包含

1. #164 read-only 定责记录及是否需要 owner 决定。
2. #166/#168/#167 和 serve/Web 的当前事实、独立 space 建议及无冲突的串行顺序。
3. iOS canonical fixture 的候选、环境状态与不能开始代码的 blocker（如有）。
4. 不执行任何 push、merge、删除或 release，除非用户在该次操作中明确授权。

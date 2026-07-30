# TritonKit Agent-Native Local Execution Roadmap v01

> 日期：2026-07-24
>
> 周期：未来 12 个月；每个阶段以证据门槛而非日历强行推进
>
> 状态：已裁决；当前只启动“可信基线”准备工作
> 当前执行锚点：[SP-126 Testrec Convergence](../spaces/SP-126-testrec-convergence/README.md)

## 一句话战略

TritonKit 的唯一主线是：**成为本机移动 App 的 agent-safe execution-and-proof substrate**。

它让 AI agent 在同一套机器可读契约中完成能力发现、目标选择、受控动作、业务验证、失败恢复、可追溯 evidence 与可复跑工作流。它不是设备云、通用自治移动 agent、传统测试用例管理 SaaS，也不是第二套录制回放执行器。

## 决策

**Adopt：本地确定性执行与证据底座。**

执行顺序不是“把三个平台做齐”，而是：

```text
可信证据/生命周期基线
  -> iOS Simulator 的单一真实执行闭环
  -> testrec 作为轨迹编译器导入 test run
  -> workspace / skills 的可复用 agent 工作流
  -> Android 的显式 test primitive adapter
  -> 仅在门槛通过且有需求时评估 Harmony 扩展
```

现有代码证据决定了这个顺序：`test run` 的 live primitive executor 目前依赖 embedded runtime；workspace 的实际动作执行也首先落在 iOS Simulator。Android/Harmony 已有本机 discovery、host adapter 和部分 observation 骨架，但不能被承诺为同等的 agent test runtime。因此，第一条真实收敛闭环必须是 **iOS Simulator**，而不是用 simulated result 或 Android host surface 代替真实执行证明。

## 事实依据

- `Sources/TritonKitCLI/CLITestRunRuntime.swift` 已有 `TKLiveTestRunPrimitiveExecutor`、before/after observation 和 evidence writer；它是可复用的真实 test 路径。
- `Sources/TritonKitCLI/CLIWorkspaceActionExecutionRuntime.swift` 与 `CLIWorkspaceTargetRuntime.swift` 显示当前 workspace 的实际动作/target 转换范围仍窄，不能包装成三平台通用 agent runtime。
- `Sources/TritonKitCLI/CLIEvidenceCaptureRuntime.swift`、`Sources/TritonKitShared/TKEvidenceModels.swift` 与相应 tests 已使 partial、artifact、scope、fidelity、redaction 成为最成熟的产品资产。
- `testrec` 目前是显式 JSON event、deterministic compile、dry-run/local-simulated replay；真实 listener/device executor 不存在，不能成为新的真实 runtime。
- 当前公开 release blockers #166/#168/#167，以及 #164 的未定责 worktree，优先级高于任何新执行器扩张。

以上是源码/契约审计结论，不代替具体机器上的 `doctor/list` 或真实设备 smoke；每个阶段仍必须保存当次 Triton-first 事实。

## 产品边界与承诺

### 服务谁

1. 在 macOS 本地开发移动 App 的 AI coding、QA、回归 agent 及其维护团队。
2. 需要把“动作是否真的改变了业务状态”变成可审计事实的 iOS/Android/Harmony 本地开发者。
3. 需要脱敏 evidence、稳定 failure/recovery contract 和可复跑 smoke 的真实项目接入者。

### 对外只承诺什么

- agent 能通过 `status`、`doctor`、`capabilities`、`schema`、`plan` 获取事实、限制和下一步，而不是猜裸工具命令。
- 有副作用的动作必须经过显式能力、policy、目标和验证边界；动作 ACK 不是业务成功。
- 成功、partial、unsupported 与失败均有机器可读 envelope、artifact 与恢复入口；没有证据就不宣称成功。
- 跨端能力以每个平台、每条 workflow 的真实证据为准，不用“已支持某平台”掩盖缺少的执行或验证层。

### 明确不做

- 云设备农场、远端 agent 编排、多租户、计费、托管控制面或对外 HTTP 产品服务。
- Web/Wails 业务控制台、低代码录制编辑器、传统 HTML 报告产品线。
- 未经单独立项的全量网络代理/Mock 平台、证书注入、任意 WebView JavaScript 或生产环境 SDK 控制。
- 独立 `testrec local-device` executor、第二套 matrix/evidence writer、把 simulated pass 标为真实回放。
- “完整真机 UI 自动化”或三平台功能对等承诺；真机维持已验证的有限 lifecycle/诊断范围。

## 不可妥协的架构规则

1. **One runtime rule**：同一测试意图只有一条真实执行/最终 verdict 路径。录制、workspace、map 和 replay 可以产生输入或低层 smoke，但真实测试 verdict 归 `test run`。
2. **Proof before claim**：每一次成功必须能关联 target、动作结果、前/后 observation、业务验证和 evidence manifest；`executed_unverified` 永不等于 passed。
3. **Fail closed**：未知 action、缺目标能力、未审查 redaction、缺 provenance 或无法保真转换时，停止并输出一个合法 error envelope；不降级成猜测坐标、固定等待或 simulated pass。
4. **Triton-first**：agent 先消费 Triton 的 machine-readable facts；回退 `xcrun`、`adb`、`hdc` 时必须保留 Triton unsupported/error/schema 证据。
5. **平台分层，不假装平权**：iOS Simulator 是当前 canonical runtime；Android 是下一条明确 adapter 目标；Harmony 是实验性 host adapter，只有实际需求和前序门槛均通过后才扩展。
6. **模型只做受限决策**：LLM/VLM 可基于本机事实提出候选或解释证据，不能绕开 policy、capability、verify 或 evidence 直接执行裸 host 命令。

## 北极星与过程指标

唯一北极星指标是 **真实缺陷/回归闭环率（Verified Regression Closure Rate, VRCR）**：

```text
在支持范围内，由 TritonKit 本机复现并产出可审计 verdict/evidence 的已选真实缺陷或回归数
÷
进入本期基准集的已选真实缺陷或回归数
```

它比“命令数”“录制数”或“Agent 点击成功数”更接近用户价值。每阶段还追踪：

| 指标 | 定义 | 目的 |
| --- | --- | --- |
| Evidence Completeness Rate（ECR） | 非预期阻断 run 中，manifest、target、动作结果、所需 observation、verdict 和 failure/recovery refs 均存在的比例 | 防止“有截图就算 evidence” |
| Failure Explainability Rate（FER） | 非 passed run 中，拥有稳定 failure code、相关 artifact ref 和 next action/recovery 的比例 | 防止 agent 或人只能读原始日志猜原因 |
| Outcome Repeatability Rate（ORR） | 固定 App/设备初态下重复运行，verdict、step status、artifact taxonomy 与 failure taxonomy 一致的比例 | 衡量确定性；**不**要求 timestamp、run ID 或截图字节完全相同 |
| Zero-Touch Trajectory Conversion（ZTTC） | `.tritontestcase` 无人工修改即可导入、validate 并进入支持 runtime 的比例 | 判断 testrec 是否真是编译器，而不是人工模板生成器 |
| Time to First Verified Evidence（TFVE） | 从安装/doctor 到首次得到可检查 evidence manifest 的耗时分位数 | 衡量新 agent/开发者是否能用起来 |

所有指标都以预先登记的 fixture、目标、版本与初态采样；不允许通过删掉困难案例、把 unsupported 算 passed 或只统计 demo 来提高数字。

## 平台投资矩阵

| 层级 | 平台 | 12 个月承诺 | 进入下一层的条件 |
| --- | --- | --- | --- |
| Canonical | iOS Simulator + Debug embedded runtime | 第一条 `test import -> test run -> evidence` 真实闭环；稳定 business verification 和 provenance | 三个受支持 flow 的 ECR/FER/ORR 达到阶段门槛 |
| Targeted expansion | Android Emulator | 先补一个由 `test run` 使用的显式 host primitive adapter，再证明单动作/证据闭环 | 不复制 testrec executor；iOS canonical 门槛通过，并有该平台真实需求 |
| Experimental | Harmony Emulator | 保留 discovery/observation/unsupported contract；不承诺 test runner parity | Android adapter 已证明、维护成本可控、且有明确项目需求 |
| Maintenance only | iOS real device | 修复已发布 lifecycle/evidence 缺口，保持 honest scope | 不用其承担第一条 UI-test/evidence 产品证明 |

## 阶段路线

### 阶段 0：可信基线与集成卫生（现在至第 4 周）

目标：不把已发布的证据/生命周期缺口或未知本地 WIP 带入新的 agent workflow。

交付：

1. 对 #164 遗留 dirty worktree 做只读定责：记录 owner、意图、与 `main` 的差异和是否要单独继续；没有 owner/边界时隔离，不合并、不删除、不借用其中代码。
2. 串行处理公开的可靠性缺口：#166（真机 JPEG evidence 不丢失）、#168（真实设备 terminate PID/恢复契约）、#167（Xcode device alias 在昂贵 build 前 fail fast）。每条各自使用独立 space/worktree，不与 SP-126 混合。
3. 对 `triton serve` loopback 默认值与 Web “只读 DTO”表述/实际写操作做事实裁决；选择保留或移除后再更新契约，不把冲突留在营销文案中。
4. 固定一份 iOS Simulator canonical fixture：版本、target、App 初态、动作、业务断言和 expected evidence taxonomy 都可复现。

Go：公开命令的已知数据丢失/稳定失败已获得修复或明确的受支持边界；#164 WIP 已被记录为隔离风险；fixture 在当前机器可由 `doctor/status/capabilities/schema` 描述。

Stop：#164 的意图无法确认、或 evidence schema 与待修复的公开问题存在直接冲突。此时只隔离并请求 owner 决策；不开始重叠的 evidence/testrec 改动。

### 阶段 1：iOS Simulator 确定性测试与证据基线（第 2–3 月）

目标：用手写 `.tritontest.yaml` 证明现有 `test validate -> test run` 不是“动作发出即成功”，而是可重复的本机验证路径。

交付：

1. 三条范围受控的 iOS Simulator flow（例如 launch/readiness、tap/状态变化、输入/断言），每条有明确 business assertion 和 evidence checklist。
2. `test run` 的 target、before/after observation、实际 action、verify、provenance 和 `.tritonevidence` 形成一致的 schema/fixture tests。
3. 阻断/unsupported/partial 结果均验证无误导性 passed verdict；每个失败都能由单一 envelope 进入 recovery/inspection。

Go：receipt-backed report 的 `stage1.stage1A` 在预先冻结初态的 60 个 supported slot（3 flow × 20）中达到 ECR ≥ 95%、ORR ≥ 90% 且每条 flow 仍完整 20 次；`stage1.stage1B` 在全部 61 个 receipt/control slot 上达到 integrity=61/61，FER ≥ 90% 的分母包含 expected negative control 与任何 supported nonpass。原有顶层 ECR/FER/ORR 保持兼容，`stage1.gate` 与顶层 gate 一致；任何不一致必须分类为产品缺陷、环境漂移或 fixture 缺陷，不能静默重试掩盖。

Stop/回退：若 ORR < 70%，或多数失败无法定位到 target/action/assert/evidence 任一层，则暂停 trajectory compiler 和新平台扩张，先收敛 runtime/evidence contract。

### 阶段 2：SP-126 轨迹编译器收敛（第 3–5 月）

目标：把 `testrec` 变为 `.tritontestcase` 的安全导入/编译层，而非继续成长为真实执行器。

交付：

1. `triton test import <case.tritontestcase> --output <plan.tritontest.yaml> --json`，只读取已编译合同和必要 maps，输出确定性计划与 privacy-safe provenance。
2. 未审查 redaction、未知 action、不可表达 assertion/page evidence、版本不兼容全部 fail closed；proposal 不自动写入计划。
3. 最终 `test run` evidence 能关联 source case/compiled-contract identity 和 import version，而不会泄露原始敏感输入。
4. `testrec inspect/compile/proposals/match-page` 保持兼容；`testrec replay/matrix` 只保留 simulated/diagnostic 边界与迁移提示。

Go：基准集中至少 10 个 predeclared `.tritontestcase`，ZTTC（可导入且 `test validate`）≥ 70%；其中至少 5 个已支持的 iOS flow 在 10 次 run 中达到 ORR ≥ 80%。

Stop/转向：若多数 case 需要人工改 YAML、特定 App 代码或不可泛化 selector 才能运行，停止把 testrec 当通用 trajectory compiler；保留其质量/脱敏/诊断资产，产品重心回到 evidence + hand-authored test workflow。

### 阶段 3：可复用的 Agent 工作流与真实项目证明（第 6–8 月）

目标：证明该系统帮助 agent/开发者完成真实回归或缺陷复现，而不只是通过内部 demo。

交付：

1. `workspace`、`test`、evidence、recovery 和 public skills 形成一条可发现的 CLI-first runbook：`discover -> target -> act/verify -> export/import -> run -> evidence -> recovery`。
2. 对有明确授权的真实项目做隔离回归；若没有外部项目授权，用两个独立的本地 reference apps/fixtures，但在报告中诚实标为内部证明。
3. 统一 README/public skill 的已交付面与限制（例如 public skills 数量、Android 表述、Web 只读边界）；不把 experimental 能力写成产品承诺。

Go：至少两个独立 reference project（或获授权的真实项目）完成一条端到端闭环；TFVE 的 p75 ≤ 30 分钟；选定基准集的 VRCR ≥ 50%，且零个 `executed_unverified` 被写为业务 passed。

Stop/转向：若 evidence 对复现、分级或修复没有比裸日志带来可观察的提升，或每个项目都需要专属 adapter，冻结泛化 trajectory 工作，专注“本地 evidence/diagnostics substrate”而非测试编译器产品叙事。

### 阶段 4：Android 明确扩展与选择性生态化（第 9–12 月）

目标：只在 canonical iOS 路线证明后，建立一条共享、可测试的 Android host test primitive，而非复制 iOS runtime 或 testrec executor。

交付：

1. 为 `test run` 增加一个显式 Android target/action/observation adapter；复用 target resolution、evidence writer、failure/recovery taxonomy。
2. 先证明单动作和业务断言，再扩展输入/等待/更多 selector；每一步都有 schema、fake adapter tests 与真实 Emulator evidence。
3. Harmony 只做能力差距和需求审查；若没有明确项目与稳定 adapter 证据，保持 experimental，不为“平台齐全”造功能。

Go：Android 的一条真实 flow 在固定环境下达到阶段 1 的 ECR/FER/ORR 门槛，并且没有引入第二个 runner、第二份 evidence schema 或特殊 testrec 执行路径。

Stop：若 Android 需要系统级监听、复杂视觉 matcher 或高频裸 ADB escape hatch 才能得到可信 verdict，则停止当前扩展，保留 Android 作为 discovery/host-control capability，而不是宣称 trajectory replay 支持。

## 未来队列的优先级

1. **可靠性与事实债**：#164 WIP 定责、#166、#168、#167、serve/Web 边界一致性。
2. **iOS canonical proof**：手写 test + evidence 的真实可重复闭环。
3. **SP-126 importer**：testrec 到 test 的 fail-closed 迁移，绝不复活独立 executor。
4. **真实项目/Agent 采用证明**：skills、runbook、受授权 reference apps、VRCR 采样。
5. **Android adapter**：仅当前四项通过后实施。
6. **Harmony、Web 体验、网络能力、包渠道、目录迁移**：只在明确需求和独立 space 中排期，均不抢占主线。

每一个实际执行项才新建 space，遵守全局递增编号、独立 branch/worktree 和 BDD/TDD；本路线不预占未来 SP 编号，也不把多个 release blocker 混成同一提交。

## 资源与决策规则

以每十个工程投入单位计：

- 5：证据、生命周期、target/动作/验证的可信度与 release blockers。
- 3：trajectory compiler、workspace/test 契约和 agent-readable runbook。
- 1：真实项目证明、skills/onboarding 和可复用 fixture。
- 1：维护、发布、文档治理与已验证平台的退化回归。

Web/Wails、设备云、完整网络代理、任意 WebView、真机 UI 自动化不在这份配额中。只有当上述北极星指标表明本地主线被真实用户需求阻塞时，才允许新建产品裁决 space 重新讨论。

## 对外部挑战的处理

两次独立外部战略审视均支持“本地确定性执行 + evidence”主线，并建议后置 GUI/云。采纳：单一真实 runtime、证据优先、testrec 只做轨迹编译、以真实复现闭环衡量价值。拒绝或修正：不承诺三平台对等、不中途补全全量网络 capture，也不把 Android 写成当前首个真实 test runner——源码审计显示当前 live execution 的可信起点是 iOS Simulator。

## 12 个月后的裁决

继续加码的条件：VRCR、ECR、FER、ORR 和 ZTTC 在预先登记的真实基准上持续改善，且至少出现受授权项目的周度复用。

降级为诊断/证据工具的条件：trajectory importer 连续两个基准批次无法达到 ZTTC/ORR 门槛，或 evidence 无法实质降低复现/分级成本。

重新立项云/远端能力的条件：至少三个独立、明确的用户/项目都因本地单机边界而无法采用，并且本地主线已达到上述可信门槛；没有这两项证据，不讨论设备云或多租户。

# SP-148 Placeholder Token Contract v01

日期：2026-07-28
状态：已完成（本地）

## 目的

使 agent-facing schema 的 reliability-sample 模板遵守 argv-first placeholder 合同：每个待替换变量占一个完整 token，同时保留 canonical runtime target 是单个 `--target` value 的真实语义。

## BDD 到测试

| 场景 | 失败测试 | 最小修复 |
| --- | --- | --- |
| 既有 schema example 含嵌入式 placeholder | `schemaAndPlanPlaceholdersAreCompleteArgvTokens` | usage form 与 example 都使用 `<canonical>` |
| reliability-sample 的两个模板长期保持一致 | `reliabilitySampleTemplatesRetainCanonicalTargetAsOneArgvPlaceholder` | 同时断言 usage/example 形状和无 malformed token |

## 设计裁决

- 采用已有的 `<canonical>` 术语，而不是新增 `<canonical-target>` 方言。
- 不放宽 `isCompletePlaceholderToken`，不为 canonical target 添加例外，也不将 target 拆为多个参数；这样 schema 建议仍能被 agent 直接按 argv 代换。
- 不扩张到 workflow plan helper 的 argv 表达形式：该处值得后续独立审查，但不是本轮已复现红灯的根因。

## 验收与非目标

1. 独立 scratch 先复现唯一 red failure，再对两个 focused tests 绿灯。
2. 后续只需运行 schema fact-source focused suite、diff 和 docs 门禁；不启动 Triton server、Simulator、Xcode 或设备。
3. 不改 parser、runner、target validation、receipt/evidence 格式、testrec 或 workspace。

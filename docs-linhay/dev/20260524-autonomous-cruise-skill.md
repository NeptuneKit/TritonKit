# 2026-05-24 autonomous cruise skill

## 背景

本轮自动巡航结束后，用户确认希望把“提前巡航 / 自动巡航”提取成可复用项目 skill，避免后续只依赖当日 memory 和收尾报告。

## 沉淀结果

- 新增内部 skill：`.agents/skills/tritonkit-autonomous-cruise/SKILL.md`。
- 本地发现入口：`.agents/skills/tritonkit-autonomous-cruise`。
- 触发语义：长期计划、自动巡航、巡航进化、提前巡航、无人值守推进、离开一段时间让 agent 自主进化、巡航收尾。

## 能力边界

该 skill 只负责 TritonKit 内部无人值守推进流程，不进入 public release skill 包。它定义启动边界、切片推进、checkpoint、subagent 审计、收尾报告、memory/qmd 和验证门禁。

默认禁止：

- 未授权 push / tag / release / Homebrew 更新。
- 未授权修改外部仓或私有项目。
- 把临时失败、命令流水或 subagent 中间观点升级为长期规则。

## 复用入口

后续用户说“开始巡航”“提前巡航”“我要离开一段时间，你继续进化”时，先加载 `tritonkit-autonomous-cruise`，再按具体领域叠加 `tritonkit-ops-governance`、`tritonkit-subagent-supervision`、`tritonkit-xcode-workflow-takeover`、`tritonkit-host-simulator-takeover`、`tritonkit-emulator-cli-takeover` 或 `tritonkit-real-project-regression`。

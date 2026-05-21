---
name: tritonkit-session-skill-distill
description: TritonKit 会话沉淀入口：处理“整理”及可复用模式蒸馏。
---

# TritonKit Session Skill Distillation

## 触发条件

- 用户明确说“整理”。
- 一轮会话里反复出现同类排障、交付、验收或文档动作。
- 需要判断某个模式应沉淀为 skill、写入 docs，还是升级到 AGENTS。

## 蒸馏顺序

1. 先抽取可复用模式。
2. 再区分稳定性边界：
   - 只在本次会话出现的，丢弃。
   - 后续还会重复的，先沉淀到项目级 skill。
   - repo-wide 且长期稳定的，再考虑更新 AGENTS。
3. 同步写入对应 docs 与 memory。
4. 执行 `qmd update` 与 `qmd embed`。

## 收尾隔离规则

当“整理”发生在一轮已经包含代码提交、CI 观察、外部仓验证或多 space 切换的会话末尾时，先做隔离，再写回：

1. 用 `git status --short --branch` 和 `git diff --stat` 区分：
   - 已提交并推送的主仓代码；
   - 仍未提交的文档 / memory / skill；
   - 外部仓或真实项目验证结果；
   - 临时产物、日志、截图。
2. 只沉淀稳定结论和可复用动作，不把命令流水账、临时失败、外部仓未确认改动写成长期规则。
3. 提交前只 stage 本次整理相关文件；不要默认 `git add -A`，避免把外部验证残留或并行生成文件混进整理提交。
4. 若上一轮已有 commit / tag / CI 结果，整理文档应引用具体 commit、run id 或验证命令，避免含糊写成“已完成”。
5. 外部仓验证只写结果、边界和后续行动项；除非用户明确要求，不在 TritonKit 提交中夹带外部仓补丁。

## 输出标准

- 写清楚“这次沉淀了什么模式”。
- 明确“不纳入”的临时内容。
- 给出后续可复用的执行入口。
- 若发现现有 skill 缺口，优先补 skill，再谈 AGENTS。

## 结束检查

- 是否已经更新相关 skill。
- 是否已写入 `docs-linhay/dev/` 或 `docs-linhay/memory/`。
- 是否已跑 `qmd update` 与 `qmd embed`。
- 是否需要进一步升级到 `AGENTS.md`。

# Issue 27 - Clarify optional Codex/agent skills installation in README

## 背景

GitHub Issue #27 指出：根 README 已覆盖 iOS embedded runtime、macOS CLI 与 Harmony / DevEco 集成路径，但没有明显说明 TritonKit 随附的可选 Codex/agent skills 安装路径，外部采用项目容易遗漏自动化指导。

## 目标

- 在根 README 的集成/安装说明中增加简短的 Optional Agent Skills 说明。
- 明确外部用户只安装 `.agents/tritonkit-skills/public/` 下的 public skills。
- 明确 `.agents/tritonkit-skills/internal/` 仅用于 TritonKit 仓库维护，不应作为外部项目默认安装内容。
- 提醒安装后重启 Codex / agent session 以重新发现 skills。

## 非目标

- 不改动 skill 打包逻辑。
- 不新增 Web/Wails UI。
- 不改动 CLI/HTTP 业务契约。

## BDD 场景与验收

### 场景：外部采用者从根 README 发现可选 agent skills

Given 外部采用者阅读根 README
When 查找 TritonKit 可选自动化/agent 指南
Then README 应展示 Optional Agent Skills 章节
And 列出 public skill 路径
And 说明 internal skills 不面向外部默认安装
And 提醒安装后重启 Codex / agent session

## 相关链接

- GitHub Issue: https://github.com/NeptuneKit/TritonKit/issues/27

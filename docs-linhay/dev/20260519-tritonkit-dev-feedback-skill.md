# TritonKit Dev Feedback Skill

## 背景

TritonKit 仍处开发阶段，外部使用者在试用、接入、评估或自动化控制过程中提出的需求、问题、文档缺口和兼容性反馈，都应被视为有效仓库反馈。

## 新增 Skill

- 路径：`.agents/skills/tritonkit-dev-feedback/SKILL.md`
- 触发场景：有人试用、接入、评估 TritonKit，并出现需求、bug、缺失能力、困惑行为、文档缺口或兼容性问题。
- 核心要求：AI agent 负责复现或澄清反馈，收集证据，并直接向 `NeptuneKit/TritonKit` 提交 GitHub issue；不要把“请用户自己去提 issue”作为默认交付。

## 执行边界

1. 优先用 `triton status --json`、`triton doctor --json`、`triton schema --json`、`triton plan --json`、相关测试或 smoke 脚本收集证据。
2. issue 内容至少包含背景、当前行为、期望行为、复现/证据和建议下一步。
3. 若 GitHub auth 或网络阻塞，才输出阻塞原因和可直接执行的 `gh issue create` 命令。
4. 不提交密钥、私有 token、完整私有日志或无关本地路径。

## 验证

- 使用 `$skill-creator` 的 `init_skill.py` 初始化 skill。
- 使用临时 venv 安装 `PyYAML` 后运行 `quick_validate.py .agents/skills/tritonkit-dev-feedback`，结果为 `Skill is valid!`。

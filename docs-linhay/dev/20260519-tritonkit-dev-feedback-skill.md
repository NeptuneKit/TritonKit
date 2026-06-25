# TritonKit Dev Feedback Skill

## 背景

TritonKit 仍处开发阶段，外部使用者在试用、接入、评估或自动化控制过程中提出的需求、问题、文档缺口和兼容性反馈，都应被视为有效仓库反馈。

## 新增 Skill

- 路径：`TritonKit.skills/tritonkit-dev-feedback/SKILL.md`
- 触发场景：有人试用、接入、评估 TritonKit，并出现需求、bug、缺失能力、困惑行为、文档缺口或兼容性问题。
- 核心要求：AI agent 负责复现或澄清反馈，收集证据，并直接向 `NeptuneKit/TritonKit` 提交 GitHub issue；不要把“请用户自己去提 issue”作为默认交付。

## 执行边界

1. 优先用 `triton status --json`、`triton doctor --json`、`triton schema --json`、`triton plan --json`、相关测试或 smoke 脚本收集证据。
2. issue 内容至少包含背景、当前行为、期望行为、复现/证据和建议下一步。
3. 若 GitHub auth 或网络阻塞，才输出阻塞原因和可直接执行的 `gh issue create` 命令。
4. 上报 issue 前必须脱敏工程和个人信息：真实工程名、App 名、bundle ID、team ID、组织名、用户名、账号、邮箱、手机号、内网域名、绝对私有路径、完整私有日志、未脱敏截图和证据包不得进入公开 issue。
5. 脱敏后仍保留复现必要信息：平台/系统/工具版本、TritonKit 版本、命令、错误码、裁剪后的日志片段、最小复现步骤；私有字段用 `<private-app>`、`<bundle-id>`、`<user>`、`<internal-host>`、`<repo-path>` 等占位符。
6. 证据包、截图、`.tritonplan`、`.xcresult`、HDC/Simulator dump 只有在检查 manifest、文件名和内容不含私有信息后才能附加；无法确认时只写摘要。

## 验证

- 使用 `$skill-creator` 的 `init_skill.py` 初始化 skill。
- 使用临时 venv 安装 `PyYAML` 后运行 `quick_validate.py TritonKit.skills/tritonkit-dev-feedback`，结果为 `Skill is valid!`。

## 2026-06-25 渐进加载拆分

- GitHub issue #118 已处理：`TritonKit.skills/tritonkit-dev-feedback/SKILL.md` 从 605 行收缩到 44 行，只保留原则、快速 workflow、reference route table 和全局脱敏边界。
- 详细规则移动到 `references/`：`issue-filing.md`、`evidence-ios-runtime.md`、`evidence-host-devices.md`、`schema-contract-feedback.md`、`app-integration-ios.md`、`app-integration-harmony.md`。
- `docs-linhay/scripts/verify-skill-package.sh` 新增门禁：打包后的顶层 `SKILL.md` 必须不超过 150 行，并且六个 routed references 必须进入 `tritonkit-skills.tar.gz`。

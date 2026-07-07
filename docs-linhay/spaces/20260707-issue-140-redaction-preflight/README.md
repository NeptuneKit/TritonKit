# GitHub issue #140: public issue redaction preflight

## 背景

GitHub issue #140 指出：`tritonkit-dev-feedback` 已有公开 issue 脱敏规则，但规则埋在较长 checklist 中，agent 在执行 `gh issue create` 或 `gh issue edit` 前容易漏掉。

## 范围

- 强化对外 `TritonKit.skills/tritonkit-dev-feedback` 的 issue filing 指南。
- 在发布前增加强制 `Public issue preflight` gate。
- 更新 skill package 门禁，确保打包后的 public skill 保留该 gate。
- 同步 dev 文档与 memory。
- 不改 Triton CLI runtime，不新增 GitHub issue 创建工具。

## BDD 验收

### 场景 1：公开 issue 发布前必须执行脱敏预检

Given agent 准备把 TritonKit 反馈发布到 `NeptuneKit/TritonKit`
When agent 已经把 issue body 写入临时 Markdown 文件
Then skill 必须要求在 `gh issue create` / `gh issue edit` 前扫描 body 中的私有 App 名、bundle ID、模拟器 target / UDID、用户名、绝对路径和内部 host
And 命中时必须停止发布并先脱敏。

### 场景 2：私有信息使用稳定占位符

Given issue body 需要保留复现上下文
When 内容涉及私有 App、bundle、模拟器 target、repo 路径或本机用户
Then skill 必须要求使用 `<private-app>`、`<bundle-id>`、`<simulator-target>` / `<ios-simulator-runtime-target>`、`<repo-path>` / `<local-path>`、`<user>` 等占位符。

### 场景 3：无法确认附件脱敏时只写摘要

Given 证据来源包含 raw logs、screenshots、evidence bundles、crash reports、`.xcresult` 或 app archives
When redaction 未经过验证
Then skill 必须要求 summarize evidence，不直接上传或粘贴原始内容。

## 验证计划

- 先在 `docs-linhay/scripts/verify-skill-package.sh` 增加失败门禁，检查打包后的 `issue-filing.md` 包含 preflight 章节、命令示例、占位符和 handoff 文案。
- 更新 `TritonKit.skills/tritonkit-dev-feedback/references/issue-filing.md`。
- 更新 `TritonKit.skills/tritonkit-dev-feedback/SKILL.md` 的 fast workflow，让 preflight 成为创建/编辑前置动作。
- 更新 dev 文档和 memory。
- 运行 `docs-linhay/scripts/verify-skill-package.sh`、`docs-linhay/scripts/check-docs.sh`、`git diff --check`。

## 实现记录

- `TritonKit.skills/tritonkit-dev-feedback/SKILL.md` 的 fast workflow 新增公开 issue preflight 步骤，明确任何 `gh issue create` / `gh issue edit` 前必须先执行 `references/issue-filing.md` 中的 gate。
- `references/issue-filing.md` 新增 `Public issue preflight`，要求 issue body 先落临时 Markdown 文件，再用 `rg` 扫描常见私有标识；命中时停止发布、先脱敏、重跑扫描。
- 占位符集合固定为 `<private-app>`、`<bundle-id>`、`<simulator-target>` / `<ios-simulator-runtime-target>`、`<repo-path>` / `<local-path>`、`<user>`、`<team-id>`、`<internal-host>`。
- 未确认脱敏的 raw logs、screenshots、evidence bundles、crash reports、`.xcresult`、`.tritonplan`、HDC/Simulator dumps 和 app archives 只能摘要，不能直接粘贴或上传。
- `verify-skill-package.sh` 新增打包后检查，防止 release skill 包漏掉 preflight 章节、scan 示例、占位符和 `Redaction preflight passed:` handoff 文案。

## 本轮验证

- 红灯：只新增 `verify-skill-package.sh` 门禁后运行 `docs-linhay/scripts/verify-skill-package.sh`，因打包后的 `issue-filing.md` 尚无 `Public issue preflight` 而失败。
- 绿灯：补齐 public skill 内容后，`docs-linhay/scripts/verify-skill-package.sh` 通过。

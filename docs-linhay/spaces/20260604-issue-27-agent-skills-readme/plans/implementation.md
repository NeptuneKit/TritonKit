# Issue 27 实施计划

## BDD 验收

- Given 外部采用者阅读根 README
- When 查找 TritonKit 可选 Codex / agent skills 安装说明
- Then README 展示 `Optional Agent Skills` 章节
- And 明确 public skill 源路径 `.agents/tritonkit-skills/public/` 与 release asset `tritonkit-skills.tar.gz`
- And 列出当前 public skills：`tritonkit-dev-feedback`、`tritonkit-emulator-cli-takeover`、`tritonkit-real-project-regression`
- And 说明 `.agents/tritonkit-skills/internal/` 仅用于 TritonKit repo maintenance，不默认安装到 adopting projects
- And 提醒安装后重启 Codex / agent session

## 执行步骤

1. 阅读 space README、根 README、`.agents/tritonkit-skills/README.md` 与 public skill front matter，确认 packaging 只包含 public skills。
2. 在根 README 集成路径表后补充 `Optional Agent Skills` 章节。
3. 运行 `docs-linhay/scripts/check-docs.sh` 做纯文档结构校验。
4. 写回 memory 并提交本地 commit。

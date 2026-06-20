# Issue 80 - action help surface

## 背景

GitHub issue #80 反馈 `triton action --help` 会错误显示 `triton list` 的帮助。根因是 root command 使用 `List` 作为 default subcommand，而 `action` 不是真实子命令。

## 范围

- 新增 `triton action` grouped help surface，用于 agent 发现 UI action 命令。
- 保留 `triton tap`、`triton swipe`、`triton set-text` 等既有顶层命令，不改变自动化入口。
- 不新增 `triton action <verb>` 的新业务实现；子命令复用既有 command types。

## BDD 场景

Given agent 运行 `triton action --help`  
When CLI 解析 action 作为 root 子命令  
Then 输出 action grouped help，列出 tap/swipe/type/paste/clear/press/focus/set-text/select-segment/set-switch  
And 不再 fallback 到 `triton list` help。

## 验收

- `InputOutputTests` 覆盖 root command 暴露 `Action` group。
- 构建后的 `triton action --help` 输出 action overview 和 action subcommands。
- `git diff --check` 与 `docs-linhay/scripts/check-docs.sh` 通过。

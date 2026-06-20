# Issue #71：schema/status 机器可读契约补齐

## 背景

线上 issue #71 反馈 agent 在优先使用 Triton CLI 作为事实源时遇到两个契约缺口：

1. `triton status --json` 在本地 server 不可达并输出 `server_unavailable` 时，顶层缺少 `surface:"status"`。
2. `triton schema --command <name> --json` 对 `triton schema --json` inventory 已列出的命令不应返回 `name:null` 或空契约；至少 `xcode` / `tap` 必须能按命令名查询。

## 影响面

- CLI bootstrap/status 失败 JSON envelope。
- CLI schema command lookup 回归测试。
- 共享 CLI transport model 的错误 envelope 可选 surface 字段。

本修复不涉及 HTTP server、Wails/Web、桌面壳或真实模拟器动作。

## BDD 场景

### 场景 1：status 失败仍暴露 surface

Given 本地 Triton server 不可达  
When agent 执行 `triton status --json`  
Then 输出必须是单个合法 JSON object  
And 顶层 `ok` 为 `false`  
And 顶层 `surface` 为 `status`  
And `error.code` 为 `server_unavailable`  
And `error.nextAction.command` 为 `serve`。

### 场景 2：schema inventory 命令可按命令名查询

Given `triton schema --json` inventory 包含某 command  
When agent 执行 `triton schema --command <command> --json`  
Then 响应中的唯一 command 必须保留 `name == <command>`  
And 不允许 `name:null` 或空 commands。

### 场景 3：未知 schema 命令保持明确失败

Given 请求命令不在 inventory 中  
When agent 执行 `triton schema --command not-a-command --json`  
Then 输出 `ok:false`  
And `error.code` 为 `unknown_command_schema`  
And `nextAction` 指向 `schema --json`。

## 验收标准

1. 先补 focused tests，并确认至少 status surface 测试红灯。
2. 实现后 focused Swift tests 通过。
3. `xcode` / `tap` schema lookup 保留非空 command name。
4. 运行 `git diff --check` 和 `docs-linhay/scripts/check-docs.sh`；若脚本缺失，交付说明中明确。


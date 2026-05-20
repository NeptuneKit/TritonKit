# Record / Replay Smoke Flows

## 背景

真实项目登录、表单填写、Tab 切换等 smoke 流程目前依赖一串临时 CLI 命令。成功路径无法直接保存为可复跑产物，AI agent 需要在每次回归时重新拼接 tap、paste、wait、screenshot 和 evidence 命令，容易遗漏脱敏、等待条件和证据采集。

## 目标

提供第一版 `.tritonplan` 计划文件与 `triton replay` 执行入口，让短流程可以被提交、复用、审查和作为 issue 证据复跑。

首期 `triton record` 不做交互式真实录制，只生成一个可编辑模板，避免把“模板生成”误表述为“已捕获终端历史”。

## BDD 场景

### 场景一：AI 生成可审查的回归计划模板

- Given 开发者需要沉淀一次登录 smoke 流程
- When 执行 `triton record --output login-flow.tritonplan --json`
- Then CLI 写入 schemaVersion 为 1 的 plan 文件
- And JSON 输出声明 `templateOnly=true`
- And 模板包含 tap、paste、wait、evidence 等示例步骤
- And secure paste 示例不在结果摘要里回显明文

### 场景二：AI dry-run 检查 plan

- Given 已存在 `.tritonplan`
- When 执行 `triton replay login-flow.tritonplan --dry-run --json`
- Then CLI 不连接运行时、不执行 UI 动作
- And 输出每一步将执行的命令摘要
- And secure value 只展示 `<redacted:length>` 形式
- And 缺失变量会以机器可读错误失败

### 场景三：AI 复跑短流程并在首个失败处停止

- Given iOS App 已连接 TritonKit
- And plan 包含 tap、paste、clear、type、wait、screenshot、evidence 步骤
- When 执行 `triton replay login-flow.tritonplan --json --var username=alice --var password-env=TRITON_PASSWORD`
- Then CLI 按顺序执行步骤
- And 每一步返回 `ok/elapsedMs/action/command/message`
- And secure 步骤不回显明文
- And 任一步失败时整体 `ok=false`，默认停止后续步骤

### 场景四：AI 离线检查 plan 元数据

- Given 已存在 `.tritonplan`
- When 执行 `triton plan inspect login-flow.tritonplan --json`
- Then CLI 只读取文件并输出 plan 摘要
- And 不连接 server 或 runtime

## 首期范围

- 支持 action：`tap`、`paste`、`type`、`clear`、`wait`、`screenshot`、`evidence`。
- 支持变量占位：`${name}`。
- 支持变量来源：`--var key=value` 与 `--var key-env=ENV_NAME`。
- 支持 `--dry-run`。
- 支持 secure paste/type 的输出脱敏。
- `record` 只生成模板，不声明交互式录制能力。

## 暂不做

- 不捕获终端历史。
- 不做鼠标/键盘全局事件录制。
- 不跨 App 处理系统弹窗。
- 不在首期实现 continue-on-error。

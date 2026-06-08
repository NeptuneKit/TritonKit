# 20260609 Issue 31 Open URL Plan

## 背景

GitHub issue #31 记录了真实多平台路由验证中的 agent 断点：`triton plan open-url ... --json` 在本机 Triton server 不可达时只返回 bootstrap 恢复步骤，丢失了恢复后仍需要执行的 open-url、wait/assert、截图、evidence summary 等目标 workflow。与此同时，`plan open-url` 还不能接收 Harmony open-url 所需的 `--platform harmony`、`--bundle`、`--ability`、可选 `--hap` 输入，导致 agent 回退到裸 `hdc aa start -U`。

本 space 对应第一片保守实现：只增强 CLI/JSON plan 契约，不执行真实设备动作，不新增 Web/Wails，不改变本机模拟器/仿真器产品边界。

## 目标

1. `triton plan open-url ... --json` 在 server 不可达的 bootstrap 模式下仍保留完整目标 workflow，机器可读字段命名优先采用 `afterRecoverySteps`。
2. `plan open-url` 支持 Harmony 规划输入：`--platform harmony`、`--bundle`、`--ability`、可选 `--hap`。
3. Harmony open-url plan 的 schema-backed steps 覆盖 install/open-url/wait/screenshot/evidence-summary，并保持 `argv[]` 可直接由 agent 执行。
4. 保持既有 `steps[]` 兼容语义：bootstrap 时 `steps[]` 仍表示当前恢复步骤；目标 workflow 放入显式恢复后分组。

## 非目标

- 不启动或管理真实 Triton server。
- 不实现新的 Harmony host action 执行能力，只规划现有 schema 已暴露的 `app`、`wait`、`screenshot`、`evidence summary` 命令。
- 不新增远端 agent、真机设备云、HTTP 产品面、Web/Wails UI。
- 不改变 `app open-url`、`smoke harmony` 的执行语义。

## BDD 场景

### 场景 1：server 不可达时保留 iOS open-url 恢复后步骤

Given agent 请求：

```bash
triton plan open-url --device iphone15 --url myapp://detail --text Ready --evidence /tmp/open-url.tritonevidence --json
```

And 本机 Triton server 不可达。

When CLI 返回 JSON plan。

Then 顶层仍为 `mode=bootstrap`，`steps[]` 包含 `start-server` 等恢复步骤。

And JSON 同时包含非空 `afterRecoverySteps[]`。

And `afterRecoverySteps[]` 至少包含 `open-url`、`wait-text`、`capture-evidence`、`evidence-summary`。

And 每个恢复后步骤都暴露 `command`、`argv[]`、`category`、`workflowCategories[]`、`requires[]`、`expectedArtifacts[]`、`stopConditions[]`。

### 场景 2：Harmony open-url plan 支持平台与应用输入

Given agent 请求：

```bash
triton plan open-url --platform harmony --device harmony-a --bundle com.example.app --ability EntryAbility --hap /tmp/Demo.hap --url example://home --text Ready --evidence /tmp/harmony.tritonevidence --json
```

When CLI 返回 JSON plan。

Then plan 接收并保留 Harmony 输入，不因未知参数失败。

And task 或 `afterRecoverySteps[]` 中的目标 workflow 按顺序覆盖：

1. `install-app`：`triton app install --device harmony-a --platform harmony --hap /tmp/Demo.hap --json`
2. `open-url`：`triton app open-url example://home --device harmony-a --platform harmony --bundle com.example.app --ability EntryAbility --json`
3. `wait-text`：`triton wait --platform harmony --target harmony-a --text Ready --timeout 15 --json`
4. `capture-screenshot`：`triton screenshot --device harmony-a --platform harmony --output /tmp/harmony.png --json`
5. `evidence-summary`：`triton evidence summary /tmp/harmony.tritonevidence --json`

And 这些步骤的 `argv[]` 均与 `triton schema --json` 中的命令、子命令和参数对齐。

### 场景 3：既有 plan/schema 输出保持兼容

Given 既有 `ios-smoke`、`open-url`、`webview-check` 任务型 plan 测试与 schema 对齐测试。

When 本次实现完成。

Then 既有 `steps[]`、`nextStep`、`nextWorkflows`、`primaryNextAction` 推导保持通过。

And 新增字段对旧 JSON 解码保持可选兼容。

## 验收

- 新增 CLI plan 测试覆盖 bootstrap 下 `afterRecoverySteps`。
- 新增 CLI/schema 测试覆盖 Harmony open-url 输入与 schema-backed argv。
- 更新 agent-facing 文档、public skills 与 memory 中的 plan 契约说明。
- 运行相关 Swift 测试、`docs-linhay/scripts/check-docs.sh`、`git diff --check`，尽量运行 `docs-linhay/scripts/qmd-sync.sh`。

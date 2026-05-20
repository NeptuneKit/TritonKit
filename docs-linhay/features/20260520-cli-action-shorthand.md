# CLI 动作命令简写

## 背景

真实回归操作中，agent 高频执行 `triton tap --json "取消"` 这类命令。`tap` 已支持文本位置参数，但仍需要额外写 `--json` 才能得到机器可读结果；部分同类动作命令也仍要求把自然输入写成 option，例如 `triton type --text hello --json`。

## 验收场景

### 场景 1：点击可见文本时省略 `--json`

- Given 本地 Triton 服务只有一个已连接 target
- When 执行 `triton tap "取消"`
- Then CLI 按可见文本、AX label、identifier、value 或 option title 定位并点击目标
- And stdout 输出 `TKInputResult` JSON
- And 失败时 stdout 输出 `{ ok:false, error:{...} }`，进程非 0 退出

### 场景 2：同类输入动作默认机器可读

- Given 本地 Triton 服务只有一个已连接 target
- When 执行 `triton tap "HTTP"`、`triton paste "console"`、`triton type "hello"` 或 `triton clear`
- Then 默认 stdout 都是机器可读 JSON
- And 仍可通过 `--format text` 获取人读输出

### 场景 3：保留精确控制入口

- When 执行 `triton tap --x 120 --y 240`、`triton tap --oid 42` 或 `triton type --text hello`
- Then 原有参数形式继续可用
- And `--json` 作为兼容 alias 继续可用

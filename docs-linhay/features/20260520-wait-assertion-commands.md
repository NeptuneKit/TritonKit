# Wait / Assertion Commands

## 背景

真实 App 回归中，AI agent 在点击、提交表单或页面跳转后需要等待异步 UI 状态。仅靠固定 sleep、重复截图或人工判断会让脚本不稳定，也不利于 CI 失败时定位最后一次观察到的页面状态。

## 验收场景

### 场景 1：等待文本出现

- Given App 已连接 TritonKit runtime
- When 执行 `triton wait --text "我的" --timeout 15 --interval 0.5 --json`
- Then CLI 持续轮询 AX 可见文本
- And 文本出现时输出 `ok=true, matched=true, condition=text`
- And JSON 包含 `elapsedMs`、`pollCount`、`targetConnectionState`、`hierarchyCacheState` 和 `match`

### 场景 2：等待文本消失

- Given 当前页面可能仍显示登录入口或 loading 文本
- When 执行 `triton wait --gone "登录" --timeout 15 --json`
- Then 文本消失时输出 `ok=true, matched=true, condition=gone`
- And 超时时输出 `ok=false, timedOut=true` 并以非 0 退出

### 场景 3：等待目标空闲

- Given 点击或提交后 App 正在异步刷新 UI
- When 执行 `triton wait --idle --timeout 10 --json`
- Then CLI 等待 target 保持 connected、hierarchy cache 为 active，并且 AX 可见文本签名连续稳定
- And 成功时输出最后一次稳定签名 `lastObservedHierarchyHash`

### 场景 4：等待安全谓词成立

- Given agent 需要同时断言多个 UI 条件
- When 执行 `triton wait --predicate "text.exists(\"console\") && !text.exists(\"点我登录\")" --timeout 15 --json`
- Then CLI 只解析内置安全谓词，不执行脚本代码
- And 支持 `text.exists`、`text.gone`、`exists`、`gone`、`&&`、`||`、`!`

### 场景 5：保留调试上下文

- Given wait 条件超时
- When CLI 输出失败 JSON
- Then JSON 包含 `lastObservedNodeCount`、`lastObservedTextSample`、`targetConnectionState` 和 `hierarchyCacheState`
- And CI 可以直接把该 JSON 作为失败证据附到报告或 issue

## 实现说明

- `wait` 是 CLI 层轮询命令，不新增 Web/Wails UI。
- `--text`、`--gone`、`--exists`、`--predicate` 基于 embedded runtime 的 `accessibility` 请求。
- `--idle` 使用 AX 可见文本签名连续稳定作为可交互近似信号，避免完整 hierarchy 中内部波动字段导致误判。
- `--hierarchy-change --since latest` 使用最新 hierarchy payload 的稳定 hash 作为变化检测基线。
- JSON 默认输出机器可读结果；失败时输出 `TKWaitResult` 并以非 0 退出。

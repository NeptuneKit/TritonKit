# Evidence bundle export

## 背景

真实项目回归中，AI agent 需要把 pass/fail 判断附带可复核证据。目前 `status`、`list`、`ax`、`screenshot`、`export` 都能独立工作，但每次报告都要手动拼接，容易遗漏目标状态、CLI 版本、缓存新鲜度或截图来源。

对应 GitHub issue：#6 `[Feature] Add evidence bundle export for agent-driven test reports`。

## 验收场景

### 场景 1：一键导出当前目标证据包

Given 本地 TritonKit server 可达，且 Debug App 已连接 runtime
When agent 执行 `triton evidence --output /tmp/login-success.tritonevidence --json`
Then CLI 创建证据包目录
And 输出 JSON manifest
And manifest 至少包含 `status.json`、`targets.json`、`version.json`、`hierarchy.json`、`ax.json`、`screenshot.png`
And manifest 中记录 target identity、connection/cache state、CLI version、artifact freshness。

### 场景 2：允许选择证据类型并记录跳过原因

Given agent 只需要部分证据
When 执行 `triton evidence --include status,list,version,logs --output /tmp/partial.tritonevidence --json`
Then CLI 写入可用 artifact
And 对当前不支持的 `logs` 写入 `skipped`，不静默忽略。

### 场景 3：证据包可被机器读取

Given 已生成 `.tritonevidence` 目录
When 执行 `triton evidence inspect /tmp/login-success.tritonevidence --json`
Then CLI 输出 `manifest.json` 内容
And 不需要重新连接 runtime。

## 输出契约

证据包首期采用目录包格式，目录名可使用 `.tritonevidence` 后缀。目录内固定包含 `manifest.json`，其余文件按 `artifacts[].path` 相对引用。

manifest 关键字段：

- `ok`: 证据包是否成功生成。
- `formatVersion`: 证据包格式版本，首期为 `1`。
- `artifacts`: 已写入 artifact 列表，包含 `kind`、`path`、`contentType`、`bytes`、`freshness`。
- `skipped`: 跳过 artifact 及原因。
- `target`: 当前目标、连接状态、缓存状态与 app 身份。
- `cli`: CLI version 与 schemaVersion。

## 非目标

- 首期不实现 zip 压缩格式。
- 首期不实现设备日志采集；`logs` 作为 unsupported skipped artifact 返回。
- record/replay 计划文件属于 #7，后续复用 evidence 作为 checkpoint/失败报告。

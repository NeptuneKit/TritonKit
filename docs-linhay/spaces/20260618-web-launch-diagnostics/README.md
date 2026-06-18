# 20260618 Web Launch Diagnostics

## 背景

本机出现 `triton web` dev 启动失败：默认端口 `127.0.0.1:34127` 被旧 `triton web` 进程占用，新 Vite 启动直接报 `Port 34127 is already in use`；同时浏览器访问该端口命中旧 packaged server，因旧 Homebrew static root 缺少 `web/index.html` 返回 `web_static_asset_failed` JSON。

上一切片已补 `web_port_in_use` 与 packaged static 缺失诊断。本 space 继续把主流 CLI 处理方式产品化：提供可机器读取的 `triton web status` / `triton web doctor`，让 agent 和用户在启动前能判断端口、旧服务和资源状态。

## 目标

- 为 `triton web` 增加只读诊断入口，不改变 Web 作为只读 Device Hub 的边界。
- 暴露稳定 JSON，覆盖端口空闲、端口占用、疑似 Triton Web、packaged static 缺失等状态。
- 诊断命令只读取本机状态，不自动 kill 进程、不启动 Vite、不修改 Homebrew 或文件系统。
- schema 暴露新 subcommand、输出形状、失败码与恢复路径。

## 范围

- `triton web status --json`：读取目标 host/port，返回端口是否监听、URL、探测摘要和建议命令。
- `triton web doctor --json`：在 status 基础上输出检查项列表、整体健康状态和建议动作。
- 复用现有 `--host` / `--port` 默认值：`127.0.0.1:34127`。
- 文本输出只作为人工摘要；机器消费优先 JSON。
- 单元测试只测解析、模型和纯函数，不长期占用端口。

## 不在本期范围

- 不默认自动停止旧 `triton web` 或 Vite 进程。
- 不新增 Web/Wails 控制入口。
- 不新增 HTTP 管理 API。
- 不处理远端设备云、多租户或 daemon supervisor。
- 不强依赖 `lsof`；如果后续要解析 PID/命令，可作为增强项单独推进。

## BDD 场景

### 场景：查询空闲 Web 端口

- Given `127.0.0.1:34127` 当前没有 listener
- When 执行 `triton web status --json`
- Then 输出 `ok=true`、`action=web.status`、`portListening=false`
- And `recommendedActions` 包含可启动 `triton web` 的建议

### 场景：查询被占用的 Web 端口

- Given `127.0.0.1:34127` 已有 listener
- When 执行 `triton web status --json`
- Then 输出 `portListening=true`
- And `recommendedActions` 包含 `lsof -nP -iTCP:34127 -sTCP:LISTEN` 与 `triton web --port <port>`
- And 命令不启动 npm / Vite，也不停止旧进程

### 场景：旧 packaged server 返回 static 缺失

- Given 目标 URL 返回包含 `web_static_asset_failed` 的 JSON 或 HTML 诊断
- When 执行 `triton web doctor --json`
- Then `checks[]` 中包含 `web-static-assets` failed
- And `healthy=false`
- And 建议重新安装 packaged release 或使用 `--root /path/to/TritonKit`

### 场景：schema 暴露诊断入口

- Given agent 读取 `triton schema --command web --json`
- When 解析 `subcommands[]`
- Then 能发现 `status` 与 `doctor`
- And 输出契约包含 status / doctor 的核心字段

## 验收标准

- `triton web status --json` 可在端口空闲和端口占用两类状态下返回稳定 JSON。
- `triton web doctor --json` 输出 `checks[]`、`healthy` 与可执行建议。
- `triton web` 启动行为保持：端口占用时仍返回 `web_port_in_use`，不自动 kill。
- `swift test --package-path CLI` 通过。
- `docs-linhay/scripts/check-docs.sh` 与 `git diff --check` 通过。

## 实现记录

- 新增 `triton web status` / `triton web doctor` 只读诊断子命令。
- `web.status` 输出 `host`、`port`、`url`、`portListening`、可选 `probe` 与 `recommendedActions`。
- `web.doctor` 输出 `healthy`、嵌入的 status、`checks[]` 与恢复建议；当 probe 识别 `web_static_asset_failed` 时，`web-static-assets` check 为 failed。
- schema 为 `web` 增加 `status` / `doctor` subcommands，并增加 `web.status` / `web.doctor` output contracts。
- `triton web` 默认启动行为保持不自动 kill；端口占用仍通过 `web_port_in_use` 失败。

# 20260617 Triton Web Command

## 背景

`Web/` React / Vite Device Hub 已经能通过 `docs-linhay/scripts/start-web-with-triton.sh` 跟随本地 `triton` CLI 启动，但这仍是仓库脚本，不是用户可发现的 CLI 产品入口。用户要求新增 `triton web` 并发布。

TritonKit 的业务控制事实入口仍是 CLI / HTTP 机器可读契约。`triton web` 只负责启动人类可视化的 Web Device Hub，不把 Web 变成 create / update / execute 控制面。

## 目标

- 新增 `triton web` 顶层 CLI 命令。
- 默认从当前仓库 checkout 发现 `Web/`，启动 `127.0.0.1:34127` 的 Vite Device Hub。
- 默认把当前 `triton` 可执行文件注入 `TRITONKIT_TRITON_BIN`，让 Web bridge 跟随 CLI。
- 支持 `--root`、`--triton-bin`、`--host`、`--port`、`--install`、`--no-install`、`--print-command` 和 `--json`，便于 agent 与自动化验证。
- 发布到下一版 Homebrew / GitHub Release。

## 不在本轮范围

- 不把 `Web/dist` 打包进 Homebrew CLI。
- 不恢复 Wails 桌面壳。
- 不新增 Web 业务控制入口。
- 不改变 `/web/host-input` 只读 405 语义。
- 不让 Web 先定义 CLI / HTTP DTO。

## BDD 场景

### 场景：CLI 可发现 Web Device Hub 启动命令

- Given 用户在 TritonKit checkout 内安装或构建了 `triton`
- When 用户运行 `triton web --print-command --json`
- Then CLI 返回机器可读启动计划
- And 计划中的 `command` 为 `npm --prefix <repo>/Web run dev -- --host 127.0.0.1 --port 34127`
- And `environment.TRITONKIT_TRITON_BIN` 指向当前或显式传入的 `triton` 二进制
- And `url` 为 `http://127.0.0.1:34127/`

### 场景：CLI 可直接启动 Web Device Hub

- Given `Web/package.json` 存在
- And `Web/node_modules` 存在，或用户允许自动安装依赖
- When 用户运行 `triton web`
- Then CLI 启动 Vite dev server
- And Web bridge 通过 `TRITONKIT_TRITON_BIN` 调用同一版 CLI 读取 host target / screenshot / logs
- And Web 仍只消费 readonly DTO，不新增控制语义

### 场景：缺少 Web checkout 时给出明确错误

- Given 用户在不包含 `Web/package.json` 的目录运行 `triton web`
- When 未传入 `--root`
- Then CLI 失败并说明需要从 TritonKit checkout 运行或传入 `--root`
- And 错误不得伪装成 npm / Vite 内部错误

## 验收标准

- Swift focused tests 覆盖 `triton web` 启动计划、依赖安装策略、缺失 root 错误。
- `triton --help` 可见 `web` 子命令。
- `triton schema --command web --json` 返回 `web` 命令契约。
- `triton web --print-command --json` 在仓库根目录返回可执行计划，不启动长进程。
- `cd Web && npm test` 与 `cd Web && npm run build` 继续通过。
- release script 完成下一版发布，GitHub Release 和 Homebrew 可获取。

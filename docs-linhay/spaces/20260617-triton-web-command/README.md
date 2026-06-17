# 20260617 Triton Web Command

## 背景

`Web/` React / Vite Device Hub 已经能通过 `docs-linhay/scripts/start-web-with-triton.sh` 跟随本地 `triton` CLI 启动，但这仍是仓库脚本，不是用户可发现的 CLI 产品入口。用户要求新增 `triton web` 并发布。

TritonKit 的业务控制事实入口仍是 CLI / HTTP 机器可读契约。`triton web` 只负责启动人类可视化的 Web Device Hub，不把 Web 变成 create / update / execute 控制面。

## 目标

- 新增 `triton web` 顶层 CLI 命令。
- 默认从当前仓库 checkout 发现 `Web/`，启动 `127.0.0.1:34127` 的 Vite Device Hub。
- 默认把当前 `triton` 可执行文件注入 `TRITONKIT_TRITON_BIN`，让 Web bridge 跟随 CLI。
- 支持 `--root`、`--triton-bin`、`--host`、`--port`、`--install`、`--no-install`、`--print-command` 和 `--json`，便于 agent 与自动化验证。
- 发布包内携带 `Web/dist` 静态产物；源码 checkout 走 Vite dev，release/Homebrew 安装走 CLI 内置 packaged 静态服务。
- 发布到下一版 Homebrew / GitHub Release。

## 不在本轮范围

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
- Then CLI 优先尝试发现 release 包内的 `web/index.html`
- And 若 release 包也不存在，CLI 失败并说明需要从 TritonKit checkout 运行、传入 `--root` 或安装包含 `web/` 的 release 包
- And 错误不得伪装成 npm / Vite 内部错误

### 场景：发布包可直接启动 bundled Web

- Given GitHub Release 或 Homebrew 安装提供了 `triton` 二进制和 `web/index.html`
- When 用户运行 `triton web --print-command --json`
- Then CLI 返回 `mode=packaged`
- And `bundledWebRoot` 指向随包静态资源目录
- And 直接运行 `triton web` 时由 CLI 内置 HTTP 服务提供 `/`、`/assets/*`、SPA fallback 和只读 `/web/host-*` bridge
- And `/web/host-input` 继续返回只读错误，不执行输入动作

### 场景：Homebrew 可执行文件经过额外 PATH symlink 仍能发现 bundled Web

- Given Homebrew 安装的 `triton` 位于 `Cellar/triton/<version>/bin/triton`
- And `bin/triton` 与用户 PATH 中的额外 `triton` 都是指向该二进制的 symlink
- And packaged Web 产物存在于 `Cellar/triton/<version>/share/triton/web/index.html`
- When 用户通过 PATH 中的额外 symlink 运行 `triton web --print-command --json`
- Then CLI 应解析 symlink 链并返回 `mode=packaged`
- And `bundledWebRoot` 指向真实 Homebrew packaged Web 目录
- And 启动命令仍保留用户实际调用的 `triton` 路径，避免破坏 PATH 覆盖场景

## 验收标准

- Swift focused tests 覆盖 `triton web` dev / packaged 启动计划、依赖安装策略、静态资源 fallback、只读错误和缺失 root 错误。
- Swift focused tests 覆盖 Homebrew 额外 PATH symlink 指向 packaged Web 的发现路径。
- `triton --help` 可见 `web` 子命令。
- `triton schema --command web --json` 返回 `web` 命令契约。
- `triton web --print-command --json` 在仓库根目录返回 dev 可执行计划，不启动长进程。
- release tarball 包含 `web/index.html`，Homebrew formula 安装 `pkgshare/web` 并验证 packaged plan。
- `cd Web && npm test` 与 `cd Web && npm run build` 继续通过。
- release script 完成下一版发布，GitHub Release 和 Homebrew 可获取。

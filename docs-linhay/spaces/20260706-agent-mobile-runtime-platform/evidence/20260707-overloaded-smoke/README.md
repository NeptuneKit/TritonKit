# 2026-07-07 Overloaded Triton Smoke Evidence

本目录记录本轮真实业务 smoke 的机器可读证据。结论是：脚本契约已修到当前 Triton CLI 面，但当前本机 Overloaded 安装包未注册 embedded runtime，因此不能把 host-side launch 成功当作业务 smoke 通过。

## 关键证据

- `status-before-server.json` / `doctor-before-server.json`：server 未启动时返回 `server_unavailable`，作为 Triton-first baseline。
- `status-after-serve.json` / `doctor-after-serve.json`：启动 `triton serve --host 127.0.0.1 --port 19421` 后 server reachable，初始 runtime target 为一个 embedded App。
- `overloaded-run/`：旧脚本第一次执行时停在 `Unknown subcommand 'find'`，说明脚本仍调用过期顶层命令；该失败是本切片红灯。
- `overloaded-run-after-script-fix-preflight/observe-target.json`：脚本修复后不再触发旧命令错误，而是在 target identity preflight 早失败；当前 target 是 `cn.dxy.iDxyer`，不是 Overloaded。
- `app-list-ios.json`：booted simulator 上安装了 `overloaded.cn.debug`。
- `app-launch-overloaded.json` 与 `app-launch-overloaded-after-dxy-terminate.json`：`triton app launch` host action 成功提交，`simctl launch` 返回 Overloaded PID。
- `targets-after-overloaded-relaunch.json` 与 `observe-overloaded-after-relaunch.json`：停止 DXY 并重启 Overloaded 后，Triton server target list 为空；显式 observe Overloaded 返回 `target_not_found`。

## 当前判断

- 已完成：Overloaded smoke 脚本跟随当前 `triton act` / `triton debug ax` 命令面，新增 bundle preflight，并允许多 target server 通过明确 `TRITON_TARGET` 选择业务 App。
- 未完成：Overloaded 真实业务端到端 smoke。host-side app launch ack 只证明系统提交启动，不证明 embedded runtime 已连接或业务页面 ready。
- 下一步：修正或重装 Overloaded Debug runtime bootstrap，使 `triton list --json` 出现 `triton:ios-simulator:1B360513-22E7-46DB-A942-198EE522C6DC/app:overloaded.cn.debug`，再执行：

```bash
TRITON_BIN=.build/cli/release/triton \
TRITON_TARGET=triton:ios-simulator:1B360513-22E7-46DB-A942-198EE522C6DC/app:overloaded.cn.debug \
TRITON_VERIFY_OUT_DIR=docs-linhay/spaces/20260706-agent-mobile-runtime-platform/evidence/20260707-overloaded-smoke/overloaded-run-pass \
docs-linhay/scripts/verify-overloaded-triton-smoke.sh
```

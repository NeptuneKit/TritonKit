# Issue 21 Server Log Noise

## 背景

GitHub issue #21 反馈：iOS embedded runtime 在 `triton serve` 未启动时连接 `127.0.0.1:19421`，会产生大量 `nw_socket_handle_socket_event`、`Connection refused` 和 `URLSessionWebSocketTask` 错误日志。真实 App 调试时，这些日志会淹没业务日志。

## 范围

- 只处理 embedded runtime 在 server 不可达时的连接降噪。
- 不处理 server 端 lifecycle、#19 多 simulator target disambiguation 或 #20 tap activation。
- 不屏蔽已建立连接后的 send/receive 错误。

## BDD 场景

1. Given App 启动 embedded runtime，When 本机 Triton server 未监听目标端口，Then runtime 不创建 WebSocket 连接，不向 delegate / `onError` 暴露 connection refused 错误，并保持 `disconnected`。
2. Given App 已调用 `start` 且 `autoReconnect=true`，When server 暂时不可达，Then runtime 后续仍可按 reconnect 周期重试 readiness。
3. Given WebSocket 已经通过 readiness 并开始连接，When 连接期或消息期发生错误，Then 仍走原有错误通知路径，避免掩盖真实运行期问题。

## 验收

- 新增缺 server 回归测试。
- `swift test --filter TKPlatformFallbackTests` 通过。
- `swift test` 通过。

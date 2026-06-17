# Hybrid Transport Smoke Completion Plan

## 验收步骤

1. 补最小 Swift Testing 覆盖 `TKMessage` 编解码与 display item 扁平化。
2. 修复 macOS SwiftPM 构建中的 UIKit 条件编译问题。
3. 对齐 CLI 与 Demo 默认端口、WebSocket route 文案和连接状态流转。
4. 增加 CLI `/status`、`/command` 和 `/hierarchy/latest` 机器可读接口。
5. 运行 `swift test`。
6. 运行 `swift build --product triton`。
7. 启动 CLI，验证 `/health`、`/data` 写入和读取。
8. 构建并运行 iOS Simulator 示例 App，确认 CLI 收到 `ping` 和 `hierarchy`。
9. 用 `curl` 验证 `/status`、`/command` 和 `/hierarchy/latest`。
10. 写回 memory，并执行 `docs-linhay/scripts/check-docs.sh`。

## 非目标

1. 不恢复 Wails/Web 前端。
2. 不实现属性修改、截图详情等完整 Lookin 协议能力。
3. 不新增长期运行的真实端口单元测试，进程级 smoke 通过命令验收执行。

## 执行结果

已完成。WebSocket 保持 iOS <-> CLI 控制通道；AI agent 通过 CLI/HTTP JSON 契约读取状态、发送命令并获取 hierarchy 快照；本期不提供 Web/SSE 渲染。

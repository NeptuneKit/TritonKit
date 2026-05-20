# Target Cache State

## 背景

真实项目回归时发现 `triton list --json` 可能在新 App 连接早期暴露上一轮 App 的 identity；同时 `triton status --json` 会出现 `targetCount=0` 但 `latestHierarchyAvailable=true`，机器使用者无法区分这是活动 target 还是 stale hierarchy cache。

## 验收场景

### 场景 1：新连接不复用旧 App identity

- Given 旧 App 曾经向 TritonKit server 上报过 app info 或 hierarchy
- And 旧 App 断开后新 App 建立 WebSocket 连接
- When 新 App 的 app info / hierarchy 尚未返回
- Then `triton list --json` 不应显示旧 App 的 `appName` 或 `bundleIdentifier`
- And target summary 应通过 `identityState=unknown` 标明当前连接 identity 尚未确认

### 场景 2：status 区分 active hierarchy 与 stale cache

- Given server 仍保留上一轮 latest hierarchy cache
- And 当前没有连接的 embedded runtime
- When 用户执行 `triton status --json`
- Then JSON 保留 `latestHierarchyAvailable=true`
- And `activeHierarchyAvailable=false`
- And `hierarchyCacheState=stale`
- And `targetConnectionState=disconnected`

### 场景 3：当前连接返回 hierarchy 后状态恢复 active

- Given embedded runtime 已连接
- When server 收到当前连接的 hierarchy payload
- Then target summary 使用当前 payload 的 app identity
- And `activeHierarchyAvailable=true`
- And `hierarchyCacheState=active`

### 场景 4：旧连接退出不能清空新连接

- Given 旧 WebSocket 连接正在关闭
- And 新 WebSocket 连接已经建立
- When 旧连接的 receive loop 结束
- Then server 不应把当前 active target 清空为 disconnected
- And 只有与当前 connection generation 匹配的断开事件才能清空当前 target

## 边界

- `latestHierarchyAvailable` 表示 server 是否有可读缓存，不再等同于当前连接已经上报 hierarchy。
- `activeHierarchyAvailable` 表示缓存是否来自当前连接。
- `hierarchyCacheState` 取值约定：`active` / `stale` / `unavailable`。
- 断开连接时保留 latest hierarchy cache，便于导出/诊断，但必须清空当前连接 identity。
- WebSocket 连接状态按 generation 清理，避免旧连接迟到的退出事件覆盖新连接。

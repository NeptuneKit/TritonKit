# 20260521 iOS SDK Facade API

## 背景

`TritonKit.shared.start(payload)` 解决了“少写 handler / delegate / dataURL / connect”的第一层问题，但业务 App 接入仍需要一组稳定 facade：启动 endpoint、Debug 配置、能力开关、脱敏策略、App 标识、状态观察和后续 opt-in provider 都应收敛到同一套入口。

本切片只做 P0 facade，不实现业务 debug state provider、业务 action provider、UserDefaults allowlist 或 network breadcrumbs。

## BDD 场景

### 场景 1：默认 Debug bootstrap 一行启动

- Given 业务 App 在独立 `TritonKitDebugBootstrap.swift` 文件内接入 TritonKit
- When 调用 `TritonKit.shared.start()`
- Then SDK 从 `TRITON_HOST` / `TRITON_PORT` 读取 endpoint
- And 缺省时 fallback 到 `127.0.0.1:19421`
- And SDK 内部强持有默认 request handler

### 场景 2：真机接入不需要手写 URL

- Given 真机需要连接 Mac 局域网 IP
- When 调用 `TritonKit.shared.start(.device("192.168.1.20", port: 19421))`
- Then endpoint 自动配置 websocket host/port 与 HTTP data endpoint
- And 业务侧不需要手动设置 `dataURL`

### 场景 3：复杂 Debug bootstrap 使用 builder 配置

- Given 业务 App 需要指定 endpoint、重连、功能开关、脱敏策略和 App 标识
- When 调用 `TritonKit.shared.start { config in ... }`
- Then 所有配置都在一个 closure 内完成
- And 不需要落回低层 `delegate` / `connect(host:port:)`

### 场景 4：业务只观察状态变化

- Given 业务 App 只想把连接状态显示在 Debug 面板
- When 调用 `TritonKit.shared.onStateChange { ... }`
- Then 可收到当前状态和后续状态变化
- And 可通过返回的 token 取消观察

### 场景 5：低层 API 保持兼容

- Given 业务 App 已经使用 `TritonKitStartPayload` 或自定义 `TritonKitDelegate`
- When 升级到 facade 版本
- Then 旧调用仍可编译
- And 只有需要自定义消息路由时才继续使用低层 delegate。

## P0 API

```swift
TritonKit.shared.start()
TritonKit.shared.start(.local())
TritonKit.shared.start(.device("192.168.1.20", port: 19421))
TritonKit.shared.start { config in
    config.endpoint = .device("192.168.1.20", port: 19421)
    config.autoReconnect = true
    config.features = [.hierarchy, .accessibility, .input]
    config.redaction.secureText = .lengthOnly
    config.appIdentity = .init(name: "YourApp", tags: ["smoke"])
}
TritonKit.shared.stop()
let token = TritonKit.shared.onStateChange { state in
    print(state)
}
```

## 非目标

1. 不在本切片实现 `exposeState` / `registerAction` / `exposeUserDefaults`。
2. 不改变 embedded runtime 的 request schema。
3. 不移除低层 `delegate` / `connect(host:port:)`，只降低默认接入暴露度。
4. 不改变 Release no-op 策略。

## 验证

1. `swift test --filter TKPlatformFallbackTests`
2. `swift test`
3. `docs-linhay/scripts/check-docs.sh`
4. `docs-linhay/scripts/verify.sh --local`

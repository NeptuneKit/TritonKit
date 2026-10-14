# Runner 产品封装实施契约

## 统一入口

`triton device runner doctor/prepare/start/status/stop/request/receipt` 管理同一设备会话；activate/inspect/tap/scroll/type/screenshot 作为 request 的类型化入口。HTTP `/v1/device/runner/` 共用同一 Swift service，单 JSON envelope、明确 bundle 绑定。现 embedded /request /input 状态不混入独立 Runner。

## 实现分工

- Device worker：CLI 资源 ios-runner 目录，公共 XCTest、Network、白名单和协议测试；唯一 manifest 由 packaging worker 生成。
- Transport worker：Swift USB plist framing、直连 HTTP、身份响应校验、unknown 与 PNG 解码；无 Python/iproxy 运行依赖。
- Lifecycle worker：私有 session store、跨进程文件锁、prepare/build、start/readiness、status、stop owner、request/receipt；日志不公开。
- Contract worker：CLI、HTTP、schema/capabilities、解析/HTTP测试。
- Packaging worker：Runner manifest/完整性/资源定位、双架构 Release tar、Homebrew、离开 checkout 的随包验收。
- 主控：资源 Package.copy、集成修复、串行 CLI/Xcode scratch、设备动作、根/完整门禁、docs/memory、公有技能。

## 技术与验收边界

1. Swift client 每个请求直接经过 usbmuxd 的精确 USB serial + Connect 到设备 socket，再进行 HTTP；不增加本地转发 daemon。Simulator 对照为 loopback TCP。
2. Runner 资源随产品分发，首次使用按本机 Xcode 和本机团队构建签名，不发布维护者签名产物。token/session/env/原始 UDID/日志保留0700/0600本机私有目录。
3. fixture 仅作为 automation readiness 与受控后置状态基线。应用目标来自 start 的明确白名单，用户 App 不需嵌入 SDK。
4. latest-inspect + live unique/hittable/focus 约束保留；requestID 去重有总字节预算且不淘汰旧 receipt。传输 unknown 不触发自动重复动作。
5. 全屏截图声明 captureScope=device-screen，不以 bundle 参数证明画面归属；Apple XCTest 自身可能记录输入，日志始终私有。
6. Triton-first 只读事实已保存。当前 triton 未覆盖 build-for-testing/test-without-building/lockState，原生 fallback 保留脱敏理由；新产品 runtime 将自行封装同样调用，不要求用户手工执行。
7. 本期 SDK build 采用隔离 DerivedData，是验证资源项目和保留独立失败产物所需，不改项目级 Xcode 默认缓存规则。
8. 最终需测试发布包资源在仓库外可读、构建签名/启动/跨 App/正常stop；锁屏需人工解锁，失败保持机器可读，不修改系统设置。

## 发布授权边界

用户授权统一产品封装以统一发布。本期完成本地产物、契约与发布流程；不假设已授权创建 tag 或执行远端 Release。完成前不创建远端写入，也不提前宣称发布成功。

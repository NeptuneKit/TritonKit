# Resize Mode 检测与触摸保护

影响层：CLI host Simulator/shared runner；不扩展 Web 写控制面，不改变 embedded runtime。

## BDD 与边界

- Given selected Xcode 的新鲜 CoreDevice appResize JSON 与目标精确绑定，When 无会话错误为 CoreDeviceError 24004，Then host touch 可继续；exit code 单独不证明状态。
- Given 活动会话的 display UUID/尺寸，When 当前 Baguette 无 Resizable digitizer route，Then 在启动动作之前返回稳定错误，不降级到主显示器。
- Given 查询超时、JSON 缺失/超预算、目标冲突、unknown/unsupported，Then fail closed；不得按 Xcode 版本推断无会话。旧 Xcode 若实际支持查询仍可使用，若不支持则触摸拒绝并给出诊断建议。
- Given 键盘或观察命令，Then touch gate 不授予或取消它们自身能力。
- Given 多个触摸命令，Then 每个完整动作重新查询；无 TTL 或 sticky 缓存。

## 验证计划

先写 fixture/parser/guard 的失败测试，再最小实现；focused Swift tests 使用独立 `.build/sp196-resize` 与 `--no-parallel`。真实 Resize start/input 未授权专用目标，不执行设备修改。观察 advisory 与截图显示器路由由主控整合；本文件记录 helper 和剩余验收。

参考：[sim-use v0.15.0 ResizableAppSession](https://github.com/lycorp-jp/sim-use/blob/v0.15.0/Sources/iOSSimBackend/Sim/ResizableAppSession.swift)。本实现不采用其 unknown 当 inactive 的 fallback 或可关闭保护环境变量。

## 实现契约与集成接口

`CLIHostSimulatorResizeRuntime.swift` 提供纯 parser、bounded fresh file-JSON query、Baguette touch guard、只读 advisory 与 screenshot display helper。生产 query receipt 须等于完整提交 argv，纯 parser 的 target 回显也须精确一致；active result identity 必须等于 Simulator UUID（允许 UUID 大小写规范等价），不得使用未绑定别名。

- `assertIOSSimulatorResizeTouchAllowed` 每个完整 gesture 调用；当前 adapter 不能路由 Resizable touch，所以 active 拒绝。
- `iosSimulatorResizeAdvisory` 对 active 标出 requested scene size，对 unknown 明确未知；主控接入 AX 时须避免把主显示器 hit-test 拼入 App tree 或推断 orientation。
- `iosSimulatorResizeScreenshotDisplay` active 返回本次 boot 的 display UUID，inactive 返回 nil，unknown 抛出；主控在 `simctl screenshot` 增加 `--display=<UUID>`，不可持久化该 UUID，不授权 video/HID 路由。
- Touch gate 保持键盘命令自身支持状况。旧工具链 unsupportedQuery 返回稳定 unknown 错误，建议 selected Xcode 诊断，不使用 Xcode major version shortcut。

持续 gesture 的 down/move/up 使用同一次前置检测，保留已有时间线与terminal ack。每个用户操作重新检测，不在每个move event执行0.3s查询。会话在检查后启动仍存在不可消除的竞态；需后续 digitizer display routing 才能消除，当前不承诺原子状态或真实业务效果。

## 实施记录

- 首轮测试写在实现前。两次 red build 分别被并行 source manifest 缺少 resource receipt 类型、Xcode helper 的 private 可见性阻断；没有宣称拿到 Resize 专属失败测试证据。
- 实现落盘后首轮编译发现 Swift 默认参数互相引用（probe runner 与 host command probe），已改为 host runner 的 optional DI 默认 nil、函数体解析真实 probe。
- 修改面：新增 Resize runtime/tests；`CLIHostProcessRuntime.swift` 的运行前 hook 与 error mapping；`CLIWebDeviceRuntime.swift` 的完整 gesture wrapper hook/DI；旧 `IOSHostHIDProbeTests` 一个测试、`SingleDeviceWebPageTests` 两个测试仅将 synthetic SIM-1 改为 canonical fixture UUID 并注入inactive probe，保持terminal ack/bootstrap断言。
- 视频 helper：`assertIOSSimulatorResizeCaptureAllowed` 仅接受已验证 inactive；`IOSSimulatorResizeCaptureError` 提供 capture 专用稳定 detail，截图 active 走独立 display helper。
- Screenshot UUID 参数依据：[上游固定 builder](https://github.com/lycorp-jp/sim-use/blob/v0.15.0/Sources/iOSSimBackend/Sim/ResizableAppSession.swift#L467) 与[固定参数测试](https://github.com/lycorp-jp/sim-use/blob/v0.15.0/Tests/ResizableAppSessionTests.swift#L500)。实际本机 Resize display 未启动或截图实测，仍须主控验收。

### 当前验证结果

产品编译已通过；focused测试完整target编译先被resource fixture缺try、后被并行新增prefs fixture未实现函数阻断。本轨道 Resize tests 没有编译诊断，但尚无执行通过证据；主控需在所有轨道稳定后运行 `swift test --package-path CLI --scratch-path .build/sp196-resize --no-parallel --filter 'SimulatorResizeTests|IOSHostHIDProbeTests|SingleDeviceWebPageTests'` 或统一scratch对应过滤。`git diff --check` 通过。未执行设备变更、真触摸、Resize start/stop 或真实虚拟显示器验证。

检测请求有native 5秒timeout与host 6秒deadline，stdout/stderr接受16KiB、file JSON接受1MiB；预算约束本地读取而不是CoreDevice写盘体积。新鲜private artifacts使用既有bounded nofollow reader并在probe后删除，不内联原始Apple日志/标识/路径。

# SP-196 Framebuffer / helper 交付

## Requested

采用选中 Xcode 的 SimulatorKit 路径，截图助手在超时或停止后终止，保持 CLI JSON 标准输出纯净。

## BDD

- Given DEVELOPER_DIR 指向 Xcode 27，When 初始化 framebuffer，Then 优先读取其 Contents/SharedFrameworks，且 SimServiceContext 使用同一 Developer。
- Given 已加载或部分加载一套私有 framework，When 切换到另一 Xcode，Then 拒绝复用旧类，不静默混合工具链。
- Given 截图助手阻塞、连续大量写 stdout/stderr 或 session 被停止，When 达到边界，Then 有界返回并停止自有进程。
- Given Harmony 两次 session，Then 本地和远端临时文件不共用，取消后不得发布新帧。
- Given helper timeout，Then session 关闭并不自动反复拉起未知完成状态的截图助手。

## Observed

iOS 原实现硬编码 Xcode.app、调用 context 时传 nil、start 失败仍增加 refcount、并发启动可重复注册、debug 写 stdout。Android 顺序阻塞读取两个 pipe 且 stop 不取消。Harmony 不读 pipe 却等待退出、临时路径固定、stop 发起未等待 cleanup。

## Evidence

2026-10-14：11 项 focused 测试通过（2.443 秒）。最小私有 Swift package 直接编译四个完整 production 源和现有 HID 文件内的候选路径函数，运行仓库相同测试；未桩化 helper 的进程执行。覆盖 selected/shared、legacy/app 路径、partial load pin、双 pipe 输出、输出预算、超时、取消、继承 pipe、不重启 stopped session、超时不重复拉起。测试自身仅使用自有 host fixture，未操作设备。

首次 CLI 全包测试 planning 时其他轨道尚在增加文件，两轮分别因 resource/Resize 新类型未进入源清单失败；主控后续全CLI回归1318项中，本套11项全部通过（2.335秒，`.triton/sp196-validation/cli-full.log`）；全CLI其余44issues由主控修复，不据本轨道通过宣称全包通过。私有日志在 worktree `.triton/sp196-framebuffer/isolated-tests.log`，失败 no-retry 初验在 `red-no-retry.log`；50ms fixture 启动预算在负载下过紧，修为500ms，生产默认保持5秒。

## Fixes

- 新增 `CLIFramebufferHelper.swift`，SimulatorKit 候选路径复用现有 HID resolver，选中工具链的 SharedFrameworks 优先；CoreSimulator保留 Xcode 安装的系统路径兼容，不搜索其他 Xcode bundle。
- 成功或部分加载后 pin 工具链与 framework 路径，后续换选中 Xcode 返回 false；context 明确传相同 Developer。
- iOS startup 串行，成功才记 lease；去除全部 stdout debug；取消后立即停止帧发布，并在编码队列内注销 callback，避免并发 descriptor 访问。
- Android/Harmony 使用非阻塞双管道读取、自有直接子进程取消、默认5秒 /16MiB 总输出预算；超时/取消关闭 session，不自动重新启动。
- Harmony 使用 session 随机远端文件与0700本地目录，接收文件最多16MiB；cleanup 为独立2秒/64KiB有界助手，避免删除其他 session 的临时文件。
- public start/stop/frame 接口保持兼容。Resize stream fresh guard 由主控在入口集成，防止活跃虚拟 display 或未知状态回落到错误截图。

## Gaps / Remaining risk

- 未加载实际选中 Xcode 的 private framework，未验证旧/新 Xcode 的 ObjC ABI、真实 framebuffer 图像或 callback 注销完成；fixture 是路径/生命周期/子进程证据。
- iOS停止公开路径立即返回且禁止发布；后台 private callback 注销仍依赖 Apple private ABI，未声称实际注销耗时已测。
- helper取消只终止自有直接子进程，不扩大到设备服务、未知子孙进程或共享 adb/hdc server。继承 pipe 不阻塞返回，但不证明子孙进程全部退出。
- Harmony设备侧超时 snapshot 是否完成未知；不自动重启截图操作，远端清理有界且只针对本 session 文件，真实恢复状态需设备验收。
- 未改 shared schema/模型、CLI/HTTP stream 入口；全包、docs门禁与设备证据由主控统一完成。

## 可重复真实 framebuffer integration（待主控执行）

新增 `CLI/Tests/TritonKitCLITests/FramebufferLiveIntegrationTests.swift`，只调用现有 framebuffer service 与只读 readiness/Resize query；没有新增产品实现、启动 server、boot/shutdown、App launch、触摸或其它设备状态修改。

BDD：显式 `TRITON_SP196_OWNED_SIMULATOR` 必须是有效 UUID，未设置或非法时 Swift Testing `.enabled(if:)` 将此测试标记 disabled；这不是实际兼容通过。设置门禁后必须在所选 Xcode 上只读确认该 UUID 唯一 available/Booted，并执行新鲜 target-bound Resize query；active/unknown、查询失败、截断输出、无目标均抛出静态类型错误，拒绝启动捕获，不自动准备或修改设备。错误与测试输出不打印 UUID/原始 Apple 日志。

测试先确认没有可见旧帧，调用真实 `startStreaming`，在 monotonic 10 秒 deadline 内轮询实际 JPEG；ImageIO 必须解码出 `public.jpeg` 且宽高均大于零。再 start 第二个 subscriber，stop 一个仍须得到可解码帧；最后 stop 后立即要求 latest/versioned frame 都为 nil，并在 300 ms 内持续确认无迟到帧。屏幕静止时不强求 frame version 增长：保留缓存帧证明剩余 lease 的公开可读状态，不把它描述为画面刷新证明。异常/cancellation 时 defer 只释放本测试成功取得的 lease。

主控应在**新鲜独立测试进程**、同一 selected Xcode 与 owned 已启动目标上串行运行此 suite，避免其它 in-process subscriber。getter 无法查询无帧的隐藏 lease，因此“旧帧为空”不能替代进程隔离。主控先保存 Triton-first status/doctor/capabilities/schema/plan；本测试直接覆盖内部适配器，readiness 使用既有 simctl builder/runner，Resize 使用既有 probe，不另造工具 fallback。

```sh
TRITON_SP196_OWNED_SIMULATOR='<owned UUID>' swift test --package-path CLI --scratch-path <root-coordinated-scratch> --no-parallel --filter FramebufferLiveIntegrationTests
```

`startStreaming == false` 必须 #require 失败，不降级成 skip、fixture 或截图 fallback；private ABI crash 不捕获掩盖，由主控记录该测试进程退出/崩溃证据。JPEG decode 和两次 lease 只证明当前 selected toolchain 的真实画面与公开 refcount/停止行为，不证明其它 Xcode ABI、callback 实际注销时限、Resize display 路由或业务 App 正确性。

本追加仅源码 parse 与 `git diff --check`；没有另起全包 build 或 live execution。实际测试数量、disabled/失败/通过、进程状态和私有日志由主控执行后回写；此前 11 项 fixture 结果仍独立保留。

## 主控最终验证

主控真实验收：显式owned Simulator gate运行live suite，1项/1组通过，1.861秒；selected Xcode实际启动并捕获有效JPEG，双订阅与最终释放验证通过。日志`.build/sp196-validation/framebuffer-live.log`。默认full suite live disabled与单独通过分开记账。

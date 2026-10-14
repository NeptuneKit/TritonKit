# iCTRL 借鉴机制可行性核对

状态：本期可行性核对完成；实现尚未开始。日期：2026-10-14。

## 结论与证据层次

五项机制都能沿现有 TritonKit 架构接入：alias 新鲜度、预算贯通、健康诊断可增强既有实现；视觉 settle 与 OCR 需要新增 provider。当前机器已验证公共图像/OCR API、原生 Simulator AX 读取和 HID 框架加载条件，尚未验证新增产品行为或真实触摸送达。

这里的“可接入”不是“当前产品已经支持”。证据分为：源码依据、只读环境实测、合成图像 API 实测、待实现的 BDD、未执行的设备验收。静态分析不替代测试；框架兼容不替代输入效果；画面稳定不替代业务断言。

## 本机环境

完整白名单摘要见 [environment-summary.json](./20261014-environment-summary.json)。

| 项目 | 本次事实 | 边界 |
| --- | --- | --- |
| 主机 | macOS 27.0.1 / 26A434，arm64 | 当前机器，不推广到所有 OS |
| 已选工具链 | Xcode 27.1 / 27A9275 | 不修改全局 Xcode selection |
| 已安装 CLI | Triton 0.2.26；源码 main@8aaf6c31 | 未构建或替换 CLI |
| runtime | server reachable，connected，2 targets，active hierarchy | 不代表指定私有 App 的业务 readiness |
| iOS Simulator | 18 个可发现，2 个 Booted/ready；库存覆盖 iOS 27.0、27.1 | 只选择一个已启动目标做只读 AX/HID probe |
| 原生 Simulator AX | `triton sim ax` 单 JSON、exit 0，返回 42 个节点 | 原始树含 UI 信息，留在私有 gitignored 目录，不发布文本、身份或坐标 |
| Simulator HID | `ios_host_hid_framework_compatible`，legacy client，contents-shared-frameworks | 仅隔离子进程加载与 class 探针；未 dispatch、未确认点击或滚动 |
| iOS real discovery | 3 个 connected/ready；元数据 OS 为 26.0、26.5.2、26.6.2 | discovery-ready 不代表解锁、DDI、测试授权或 Runner 可用 |
| Android | adb 可用；当前发现 0 targets | 架构可改，真实 Android 验收缺目标 |
| Harmony | hdc 可用；当前发现 1 个 ready target | 未读取 UI、未安装/启动或输入 |
| macOS Vision / CoreGraphics | 合成图像 OCR 正确识别预期文本，归一化 bounding box 合法 | 不含设备截图；只证明本机 API 可执行，产品 OCR 尚未实现 |

默认 `device doctor` 的 `ios-host-ax.available=false / idb_not_available` 是 idb adapter 探针，不代表原生 AXP 路径必定不可用；本次后续原生 `sim ax` 成功。默认 `ios-host-hid.available=false / dispatch_not_probed` 与指定目标的 framework-compatible 也不矛盾：都未证明触摸送达。

## 五项支持矩阵

| 项目 | 当前产品基础 | 精确缺口 | 判断与接入位置 |
| --- | --- | --- | --- |
| alias/ref 新鲜度 | @N 缓存与平台/设备隔离；OID 弱引用和活跃窗口校验；WebView session 校验 | 原生 alias 未检查年龄或新页面；同 URL reload 的 WebView session 可能不变 | 可行，增强既有 observe/node contract；当前 @N 主要用于 node resolve，不能假称已支持 act tap @N |
| 采集预算 | runtime AX 800 nodes/depth 32；Simulator AX depth 80、XPC timeout 2s/deadline；层级和 WebView 有局部限制 | 部分 stamping、layout/Bridge 遍历无全链路总量/时间预算，maxNodes 在输出阶段截断 | 可行；逐后端下沉预算，不把本地 deadline 当作底层 IPC 硬取消 |
| 视觉 settle | wait --idle 比较两次 AX；workspace 已有 postActionObservation + business wait/assert | 尚无多帧视觉稳定窗口和变化面积反馈 | 条件可行；新增截图采样/纯图像差分 provider，复用现有动作闭环 |
| OCR fallback | AX/DOM、截图、VLM grounding 已有 | 没有通用 OCR provider 及结构读屏不足时的选择契约 | 条件可行；当前 Mac Vision 合成测试已通过；需接入截图坐标/方向与 provenance |
| UI/诊断隔离 | ping 不访问 UI；Android 已有 root executor、semaphore、timeout | 未见统一 UI 健康、admission、熔断和恢复契约；Android 固定 HTTP 线程池可能耗尽 | 可行；优先增强健康合同与非 UI 通道，硬阻塞需外部进程恢复 |

## 源码依据与需要保留的已有能力

- [CLIObservationRuntime.swift](../../../../Sources/TritonKitCLI/CLIObservationRuntime.swift)：917–932 保存 alias/capturedAt；953–985 只校验设备/平台并返回缓存节点；401–421 原生 AX 采集后才做 maxNodes 输出截断。
- [CLIObservationModels.swift](../../../../Sources/TritonKitCLI/CLIObservationModels.swift)：94–116 的 cache 还没有页面身份；新增字段必须保持已有 cache 解码兼容或显式迁移/失效。
- [TKObjectRegistry.swift](../../../../Sources/TritonKit/Util/TKObjectRegistry.swift)：13–32 弱引用与单调 OID；[TKRuntimeInputActions.swift](../../../../Sources/TritonKit/TKRuntimeInputActions.swift)：1425–1437 活跃窗口校验。连接 generation 属于 transport 身份，不等价于页面代次。
- [TKRuntimeWebViewProvider.swift](../../../../Sources/TritonKit/TKRuntimeWebViewProvider.swift)：1004–1012、1057–1065、1240–1248 已拒绝 session 不匹配；1688–1690 由 OID + URL/title hash 派生 session，同 URL 文档重建需增强。
- [TKRuntimeAXBuilder.swift](../../../../Sources/TritonKit/TKRuntimeAXBuilder.swift)：91–98、129–151 已有递归节点/深度限制；[TKRuntimeStateSnapshot.swift](../../../../Sources/TritonKit/TKRuntimeStateSnapshot.swift)：236–249 返回 truncation。
- [CLIHostSimulatorAXDriver.swift](../../../../Sources/TritonKitCLI/CLIHostSimulatorAXDriver.swift)：328–360、459–476 已有 deadline；376–380 的预处理 stamping 只有 depth 约束。
- [CLIWorkspaceActionLoopRuntime.swift](../../../../Sources/TritonKitCLI/CLIWorkspaceActionLoopRuntime.swift)：117–146 已有动作后观察和业务断言；[CLIWorkspaceActionExecutionRuntime.swift](../../../../Sources/TritonKitCLI/CLIWorkspaceActionExecutionRuntime.swift)：226–235 区分 executed_unverified/verified/verification_failed。不能重新实现或削弱此边界。
- [CLIRegressionRuntime.swift](../../../../Sources/TritonKitCLI/CLIRegressionRuntime.swift)：93–124、159–166、196–203 为 AX signature 判稳；截图 SHA256 精确相等与视觉 settle 是不同用途。
- Android Bridge 的 `TreeHandler.kt` 26–38、53–83 构建全树；`ActionRouter.kt` 57–67、428–470 已有 root 读取超时与 semaphore；`HttpServer.kt` 51 共用固定池。此处为静态证据，未做 Android 实测。

## iOS Runner / 无 Mac DDI 的单独判断

参考：[iCTRL Runner](https://github.com/OpenMinis/iCTRL/blob/99dbfecdb39836ba26a0b2b0dcfde90f705a6835/iCTRLUITests/iCTRLUITests.swift)、[设备端 DDI](https://github.com/OpenMinis/iCTRL/blob/99dbfecdb39836ba26a0b2b0dcfde90f705a6835/iCTRLApp/DDI/DDIMounter.swift)、[兼容 shim](https://github.com/OpenMinis/iCTRL/blob/99dbfecdb39836ba26a0b2b0dcfde90f705a6835/iCTRLCompat/XCTCompatShim.m)。

- 当前 Mac 有 Xcode 和真实设备 discovery 条件；现有 specialized Apple runner receipt 可以作为审计/绑定参考，但不等价于通用 iOS 跨 App Runner。
- 新增通用 iOS XCUITest backend 需要独立 runner artifact、开发签名、精确目标绑定、DDI、UI Automation 授权、启动/退出/失联恢复和真机执行证据。当前没有验证这些条件的完整链路，不能称 iCTRL 已适配本机真机。
- 私有 XCTest、event synthesis 和 shim 只允许在独立 Runner/host backend，embedded SDK 保持公开 API、Debug-only bootstrap 与 Release no-op，根 SwiftPM 不引入 CLI-only 依赖。
- 无 Mac DDI 还需要 LocalDevVPN、可信配对材料、对应镜像/个性化或 Cryptex 路径；本机已有 Xcode，第一阶段无需引入设备端自挂载。参考源码的配对导入校验与 RemotePairing mount 调用存在需复核的一致性风险，不能直接照搬。
- 结论：独立研究候选，后续另建执行 space；本期未安装 iCTRL、导入凭据、挂载 DDI、构建/签名/运行 Runner。

## 实施切片与失败测试

### A — P0 原生 alias freshness

- 先增强 node resolve，而不是承诺新的 tap @N 操作面。定义观察身份、年龄策略、同页可重定位与缓存迁移。
- BDD：同设备换页拒绝旧 alias；同页小布局变化重新定位成功；runtime 重启拒绝旧引用；多候选返回歧义，不能选第一个猜测。
- 测试入口：`ObservationOutputTests`，保留 `TKRuntimeInputActionsTests` 和 connection lifecycle 回归；UIKit 分支需实际 iOS destination，macOS 条件跳过不算通过。

### B — P0 预算贯通

- 在 runtime/Simulator stamping/Android tree/Harmony parse 分别定义可执行预算，区分服务端限制和客户端返回数量限制。
- BDD：宽树/深树在采集中停止并报告原因；预处理也计入预算；超时不宣称 native call 已取消；单一错误 envelope。
- 测试入口：新增有实际遍历计数的注入 fixture，回归 `ObservationOutputTests`、runtime AX suites 与 Android handler tests。

### C — P1 视觉 settle

- 共用有界截图 provider 与纯图像算法，接在既有 workspace 动作后验收链中；先做纯截图序列 fixture，再做 dedicated target。
- BDD：AX 不变但图像变化不判稳；稳定窗口满足才 settled；持续动画/截图失败/锁屏保持 timeout 或 unknown；画面稳定但 businessAssert 失败仍 verification_failed。
- 测试入口：新增图像 fixture suite，回归 `WorkspaceActionExecutionTests` 和 `IOSHostWaitRuntimeTests`。

### D — P1 OCR

- host Vision provider；保留结构语义优先，OCR/VLM 有显式 policy，不把字符覆盖率当作绝对可读性或交互性。
- BDD：中文/英文/低置信度、旋转/scale/point 转换、截图新鲜度；OCR 节点不冒充 OID/ref；低置信度不自动动作。
- 本机 API 已测，但尚未验收真实截图的方向/像素与设备 point 映射；需新增 provider fixture 和明确来源字段。

### E — P1 健康与诊断隔离

- admission、in-flight action identity、超时/未知结果、熔断、低成本恢复探针与外部恢复建议。
- BDD：UI 阻塞时非 UI 诊断按预算返回；连续超时拒绝新动作；不可取消动作保留 unknown，不自动重放；恢复探针不调用同一堵塞 AX。
- 用可控阻塞 provider 测通道隔离，回归 Android `ActionRouterTest` / HTTP parse 与 iOS lifecycle；不在用户 App 上故意制造挂起。

## 验证记录与未完成项

- 已执行：12 个 Triton-first 事实命令、Android/Harmony inventory、指定 Simulator 的 HID framework/原生 AX 只读查询；合成图像 Vision OCR 与 bounding box 校验。
- 所有设备与 runtime 身份、路径和 UI 内容保留私有；公开摘要只含版本、数量、布尔值、稳定错误码和已脱敏 argv。
- docs-only 改动，未修改实现；本期不跑全量 Swift/Go 或产品行为测试。后续实现按上面每个切片先写失败测试，再完整回归。
- 未执行：新 alias/预算/settle/OCR/熔断的产品测试、真实输入、真实截图 OCR、跨 App Runner、真机 DDI/签名/授权。
- 本期最终门禁：`verify.sh --ci-docs`、`check-docs.sh`、`git diff --check`；实际结果在 README/memory 写回。

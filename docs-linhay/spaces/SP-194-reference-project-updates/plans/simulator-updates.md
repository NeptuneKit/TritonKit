# Simulator / Device Hub 参考项目更新报告

查询日期：2026-10-14（北京时间）。影响层为本机 CLI / HTTP 契约、host-side adapter、采集与测试治理；本报告只提出评估建议，不实施控制能力。事实来源为 GitHub 官方 REST API、项目网页、release notes 与指定源码。未 clone、运行上游代码或操作设备。结构化证据见 [simulator-updates.json](simulator-updates.json)。

## 范围与完整性

每仓库读取默认分支最近 20 条提交、最近 3 个 GitHub Release，并用已记录 SHA 与本次 HEAD 比较。Baguette / sim-use 的 compare 分别只返回 250 条提交和 300 个文件，不能声称完成全部增量审计；本报告关注最新发布和明确修复。其余 compare 未达到该限制。版本来源须区分：serve-sim 的 `0.1.46` 为源码 package 版本，不能据此断言 npm 已发布；device-hub-ios 本轮未查到 GitHub Release。六仓库均未归档，官方 API 返回仓库名称与请求一致。

| 项目 | 本次 HEAD / 最近默认分支提交（北京时间） | 相对本地基线 | 版本与许可 |
|---|---|---|---|
| Baguette | `8930ac60` / 10-13 17:44 | `fb7cc51a` → HEAD，+542，摘要有界 | v0.2.6；Apache-2.0 |
| serve-sim | `6d009686` / 10-12 02:23 | `f94d57c3` → HEAD，+23 | 源码 0.1.46，GitHub Release 为空；Apache-2.0 |
| sim-use | `ca90b054` / 10-14 14:39 | `b809ea84` → HEAD，+360，摘要有界 | v0.15.0（10-14 14:42 发布）；Apache-2.0 |
| simslim | `6518ba7e` / 10-09 23:38 | SP-177 catalog pin `4ae1659a` → HEAD，+7 | v0.12.2；MIT |
| OpenDeviceHub | `e50f07f1` / 09-28 07:10 | 与 `e50f07f1` 基线相同，+0 | v0.2.0；MIT |
| device-hub-ios | `9ea14d11` / 10-14 14:31 | `1fcdfb0a` → HEAD，+16 | 未查到 GitHub Release；MIT |

## 1. Baguette：可复现偏好配置成为新的 CLI 能力

- v0.2.6 新增 `defaults read/write/delete/export/import`：保留 bool/int/float/date/data/plist 类型，区分“未存储”与 false/0/空字符串，覆盖 App Group 与普通 suite。`--relaunch` 在写入前退出 App、随后重启；导入仅覆盖指定键。原始来源：[v0.2.6](https://github.com/tddworks/baguette/releases/tag/v0.2.6)、[Defaults 文档](https://github.com/tddworks/baguette/blob/8930ac601e38e04540cb3cad9547347c160882e4/docs/features/defaults/README.md)。
- v0.2.5 提供面向手机浏览器的 handheld 全屏画面模式；v0.2.4 修复 3D 流错误限制在 20 fps、恢复最高 60 fps。来源：[v0.2.5](https://github.com/tddworks/baguette/releases/tag/v0.2.5)、[v0.2.4](https://github.com/tddworks/baguette/releases/tag/v0.2.4)。
- 最近补充繁忙 CI runner 的 timing tests 修复。来源：[提交 568312e7](https://github.com/tddworks/baguette/commit/568312e7)。

对 TritonKit 的价值（推断）：偏好类型、presence 标志、限定键导入与重启事务可以支撑 `.tritonplan` 的 onboarding / feature flag 场景准备。优先研究 CLI / HTTP schema；handheld Web 和设备农场属于额外产品边界。风险：上游明确说明磁盘写成功不等于运行 App 已消费；普通 suite / App Group 解析、敏感偏好导出和 App 生命周期均需单独验证。总体增量很大，不能将本次 3 个 release 摘要替代 +542 commits 审计。[完整比较](https://github.com/tddworks/baguette/compare/fb7cc51aec69e3fbb5a71f31b4fb1cc1191d7a2c...8930ac601e38e04540cb3cad9547347c160882e4)。

## 2. serve-sim：Xcode 27 输入与原生 helper 生命周期修复

- 最新提交将 iPhone Duo 3D preview 的 RealityKit engine 创建移至 main actor，修复崩溃。来源：[提交 6d009686 / PR #165](https://github.com/EvanBacon/serve-sim/commit/6d009686ed08f7d8bd19bca9f9f67a9237931f44)。
- camera helper 关闭等待正在进行的 frame/timer 结束，禁止 shutdown 后重启 source，降低 IOSurface 释放竞态；新增 in-flight shutdown 周期测试。来源：[helper 源码](https://github.com/EvanBacon/serve-sim/blob/6d009686ed08f7d8bd19bca9f9f67a9237931f44/packages/serve-sim/Sources/SimCameraHelper/main.m)、[PR #148 提交](https://github.com/EvanBacon/serve-sim/commit/c60d5837)。
- 比较中新增 `DeviceHubKeyboardBridge`：Xcode 27 使用 Device Hub 的宿主键盘事件通路；检查权限和唯一可见焦点窗口，并保持一组按键的 route 不分裂。旧版本继续 Indigo。来源：[bridge 源码](https://github.com/EvanBacon/serve-sim/blob/6d009686ed08f7d8bd19bca9f9f67a9237931f44/packages/serve-sim/Sources/SimNative/DeviceHubKeyboardBridge.swift)。
- 修复模拟器关闭后 detached helper 仍运行、VisionCamera v5 合成照片；可交互 Duo 3D 预览也进入此轮增量。来源：[完整比较](https://github.com/EvanBacon/serve-sim/compare/f94d57c3f05031d93538660fc0d232179b1d8a50...6d009686ed08f7d8bd19bca9f9f67a9237931f44)。

对 TritonKit 的价值（推断）：借鉴 source 生命周期串行化、取消后等待、helper ownership 与键盘 target gate。风险：CGEvent 定位到应用进程而非任意窗口，焦点与权限是正确性前提；输入发送不能等同业务落地；私有框架、相机注入与 UI 依赖不能直接作为通用兼容承诺。版本证据：[package.json 0.1.46](https://github.com/EvanBacon/serve-sim/blob/6d009686ed08f7d8bd19bca9f9f67a9237931f44/packages/serve-sim/package.json)。

## 3. sim-use：v0.15.0 重点解决“成功但未送达”

- Xcode 27 Resize Mode 被显式识别：`ui` 携带 `resizable_app_session` advisory，截图选择 Resizable display；触摸、包含触摸的 batch 及视频捕获在无法正确路由时 fail-closed，batch 每个触摸步骤重新检查。其 AX 恢复不再拼入主显示器 SpringBoard 元素。来源：[v0.15.0](https://github.com/lycorp-jp/sim-use/releases/tag/v0.15.0)。
- `batch/type/paste` 的 stdin / 文件输入先由调用方读取、再 inline 送往设备 daemon，解决 Device Hub 下短进程连接尚未建立便退出而丢输入；相对文件路径在调用方目录解析。来源：[修复提交 8ac6b106](https://github.com/lycorp-jp/sim-use/commit/8ac6b106)、[CHANGELOG](https://github.com/lycorp-jp/sim-use/blob/ca90b0540aaa58f9edff71be50313dfb5fd740f5/CHANGELOG.md)。
- Android-only Linux target 与远端 adb server 连接身份进入发布：forward/token 缓存按连接绑定，错误连接拒绝执行，重连失败清理 forward。此项属于远端环境适配，TritonKit 如引入须另定范围。来源：[v0.15.0](https://github.com/lycorp-jp/sim-use/releases/tag/v0.15.0)。
- 双平台 H.264 流统一采用 MPEG-TS 的时间线和可取消 stdout sink，处理 idle 后延迟积累、下游不读取时停止卡死；iOS screenshot-loop 流格式开始弃用。`tap --coordinate-space` 与 selector ambiguity 提示亦完善。来源：[CHANGELOG](https://github.com/lycorp-jp/sim-use/blob/ca90b0540aaa58f9edff71be50313dfb5fd740f5/CHANGELOG.md)。

对 TritonKit 的价值（推断）：优先吸收多显示器诊断、advisory 与动作拒绝边界、daemon 输入转发和取消契约。风险：上游 Resize Mode 检测有缓存且可禁用，不应把 advisory 缺失当作绝对可控；录制时间线与预览时间线目的不同；性能数字是上游测量，本轮未重测。[完整比较](https://github.com/lycorp-jp/sim-use/compare/b809ea84b42ebdb1b766300f33432c52dac0f01a...ca90b0540aaa58f9edff71be50313dfb5fd740f5)。

## 4. simslim：服务排除名单需立即复核

- v0.12.1 保留 `assistantd`，避免 Spotlight 无界内存泄漏。来源：[v0.12.1](https://github.com/MobAI-App/simslim/releases/tag/v0.12.1)。
- v0.12.0 保留 `gamed`，避免 XCUITest 驱动 App 启动的最长约 10 秒等待；旧配置可经 on/off 恢复该服务。来源：[v0.12.0](https://github.com/MobAI-App/simslim/releases/tag/v0.12.0)。
- v0.12.2 在 `--except widgets` 时同时保留 `navd`，避免 Maps widget 重试导致日志洪泛。来源：[v0.12.2](https://github.com/MobAI-App/simslim/releases/tag/v0.12.2)、[profiles.go](https://github.com/MobAI-App/simslim/blob/6518ba7eab1123d7e1d7797b0e05f51043b42a5b/profiles.go)。
- 支持 tvOS / watchOS / visionOS，并按平台保留 homed / mobileassetd；no-reboot 批量 unload 最多 64 项，针对失败项目才走逐项降级。来源：[v0.12.0](https://github.com/MobAI-App/simslim/releases/tag/v0.12.0)、[比较](https://github.com/MobAI-App/simslim/compare/4ae1659a0c0265787c2a7047fab466b326ba6d7e...6518ba7eab1123d7e1d7797b0e05f51043b42a5b)。

对 TritonKit 的价值（推断）：将以上 3 个服务例外和“为了省资源禁用服务反而泄漏/延迟”加入 SP-177 catalog 漂移检查，优先于扩大平台范围。风险：批处理与平台 profile 需要 on/off、恢复、XCUITest 启动、日志速率和内存走势回归；上游速度是自身环境结果。基线来自 SP-177 的固定 catalog pin，不依赖其文本日期排序。

## 5. OpenDeviceHub：相比 10-08 档案无新增代码

`dev` 默认分支 HEAD 与本地固定 SHA 相同，compare `identical` / +0。v0.2.0 的折叠屏活动显示器录制、旋转和重连修复、前台设备限定菜单以及截图/位置设置均为已存在基线能力，不能列为本次新增。当前限制仍包括 Apple silicon、Xcode 26/27、窗口不可被 accessibility 看到、不覆盖其它 Apple 平台。来源：[compare](https://github.com/Mastersam07/OpenDeviceHub/compare/e50f07f1f4480cb14d57f192df7bf598ca26e708...e50f07f1f4480cb14d57f192df7bf598ca26e708)、[v0.2.0](https://github.com/Mastersam07/OpenDeviceHub/releases/tag/v0.2.0)。

对 TritonKit 的价值（推断）：维持既有坐标、target 与 adapter 参考，无需新增追赶实现。仓库网页本轮读取失败，但官方 API 的仓库、HEAD、Release、compare 读取成功；不能把网页失败误判仓库下线。

## 6. device-hub-ios：+16 主要是画面布局和验证治理

- 远程画面占满窗口，chrome 改为浮层；iPad 不再预留 native toolbar 空间，连接后状态提示有界淡出，补充相应视觉快照。来源：[Design](https://github.com/JaviSoto/device-hub-ios/blob/9ea14d11e492ae289f2f92e47da6d1b9044adee0/Docs/Design.md)、[layout 源码](https://github.com/JaviSoto/device-hub-ios/blob/9ea14d11e492ae289f2f92e47da6d1b9044adee0/Packages/DeviceHubKit/Sources/DeviceHubUI/RemoteSessionChromeLayout.swift)。
- 测试模拟器改为每次运行拥有一个 disposable target；先编译 media probe 再分配模拟器；快照使用规范测试目标。来源：[simulator_setup](https://github.com/JaviSoto/device-hub-ios/blob/9ea14d11e492ae289f2f92e47da6d1b9044adee0/BuildSupport/simulator_setup.py)、[compare](https://github.com/JaviSoto/device-hub-ios/compare/1fcdfb0a6799b62f05625d0cbb359bec57256b94...9ea14d11e492ae289f2f92e47da6d1b9044adee0)。
- process guard 先枚举 PID / PPID，确认 operation-owned POSIX session 后才读取执行路径，并重新验证遗漏/退出竞态；避免无差别采集其它进程参数与环境。来源：[guarded_process.py](https://github.com/JaviSoto/device-hub-ios/blob/9ea14d11e492ae289f2f92e47da6d1b9044adee0/BuildSupport/guarded_process.py)。
- 修复签名配置、死代码扫描索引和私有 LAN 发布验证；这些是上游自己的构建发布流程，并非已发布版本或 transport 新能力。来源：[HEAD](https://github.com/JaviSoto/device-hub-ios/commit/9ea14d11e492ae289f2f92e47da6d1b9044adee0)、[完整比较](https://github.com/JaviSoto/device-hub-ios/compare/1fcdfb0a6799b62f05625d0cbb359bec57256b94...9ea14d11e492ae289f2f92e47da6d1b9044adee0)。

对 TritonKit 的价值（推断）：借鉴测试设备 ownership、先编译后分配和进程审计最小化；画面满窗仅作设计参考。风险：项目 hard-target iOS/iPadOS 27，且为私有接口移植；本轮增量不能当作之前 session / media / input 安全模型重新验证的证明。

## 建议优先级

1. 高：SP-177 服务 catalog 的 assistantd / gamed / navd 差异及恢复验证；sim-use Resize Mode 和 stdin daemon 输入送达边界。
2. 中：serve-sim helper shutdown / 键盘 target gate；sim-use 流取消与预览时间线；device-hub-ios 测试设备和进程 ownership。
3. 待另建切片：Baguette typed defaults 场景准备。Web handheld、远端 adb、Device Hub 视觉 UI 与其它 Apple simulator 平台保持研究项。

本轮验证：结构化 JSON 可解析、关键来源链接已记录，文档 diff whitespace 检查通过；未执行功能测试，因为没有实现代码变更。

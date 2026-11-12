# mobile-mcp 2026-11-12 固定增量审阅

结论：主库增量完整；一个现有只读尺寸解析的小缺口建议采用，其他机制观察。

绑定 base `3b51952bcd83955f3a743f731f5a9beaebecdab7` → head `ad3b42336d89717313af45176c48538bea6ec363`；实际 main `0ec972e6151eb27372b3bdf5aa940940c56c30b0`。1 页到成功检查点，3 commits / 3 parent edges / 4 无截断 tree / 3 路径 / 7 安全文本版本。全部 parent 增量见 review-full-increment.diff，blob hash 已校验；仅 CHANGELOG/package/package-lock，无二进制/身份文件。读取完整 Release 1.0.17 与 Apache-2.0 LICENSE（hash 见 JSON）。没有把下载完整等同于运行验证。

## 具体判读

- audit 锁更新：typescript-eslint 8.69.0→8.72.2、嵌套 brace-expansion 5.0.12→5.0.13。mobilewright 0.0.68→0.0.69，mobilecli 1.0.22→1.0.23，各平台 optional 包和 integrity 同步，ws 8.22.1→8.22.2。没有本库生产 TS 行为变更；不能由 audit 标题推定 Triton 同漏洞。actual main Web lock 无这些精确 package entries。
- Release #454 横屏 hint 已在前日增量，不能重复算新增。Triton raw framebuffer 元数据与 native HID 主屏竖屏限制保持，未复制尺寸猜方向。
- Release 引用 mobilecli 是独立仓库/分发；读取 #545/#556 固定相关源码与测试（见 release-linked/source-manifest.json），#559/#562 只读完整 PR 描述与文件清单，不声称完整审阅全部移动端依赖实现。其 LICENSE 是 FSL-1.1-ALv2，hash `02ec59256014999d1d0ec9263b8b61b90ca8121e8e810a1e3a3b314c197a8997`，不能套用 mobile-mcp 的 Apache 许可。
- #545 机制是自然尺寸 + display 0 实际 rotation，而非 user_rotation 偏好；上下屏、Android13 缩进、dumpsys override/base 区分。读取后发现本地确有更窄 parser 缺口：WMSizeParser 第一条任意 WxH 即返回，标准 Physical 然后 Override 时忽略有效 Override。现有测试 Override 在前未覆盖。推荐只独立修复标签识别与 Override 优先级，不复制 FSL 代码、不加设备查询。BDD/文件面在 JSON；本次未写产品测试，red 待主控执行。
- consumer 全仓固定 main 检索：webAndroidDeviceGeometry → webHostDeviceGeometry → CLIServeCommand /web/geometry → CLIWebDevicePage.refreshGeometry/refreshScreenshot，仅 previewMeta pill 优先显示 bounds；页面没有依据它发送坐标动作。Web StreamPanel 自读图片 naturalWidth/Height，截图端也返回实际图尺寸。故本报告**不声称已证实点击错位**；rotation 扩展维持观察，当前候选仅显示有效尺寸准确性。
- #556 System UI 过滤有 active window/full dump 例外；Triton 新鲜 UIAutomator 捕获无同类连续 hash settle timeout 证据，不盲目移除锁屏/通知栏。#559/#562 真机 agent 调试代理、daemon 恢复属于独立实现边界，速度仅上游自述，反复重启还记录未知错误，不采用。

SP283/284 已在 main 交付，simslim/Loupe 元数据未变，单独复用报告，不重复排期。未执行第三方代码、安装依赖、设备、Swift 测试或远端写入；未改仓库/WIP/冻结前日证据。经验仍遵循现有固定来源/完整性规则，无新治理规则需要新增。

## 官方正常输出语义与候选复核

AOSP 固定 commit `167b01edf8258a5846838a13b4051b2233bc82af` 的 WindowManagerShellCommand.java 161–170 行读取 initial/base，先打印 Physical，若不同再打印 Override(base)。完整官方源及hash在 review-aosp-*；链接 https://android.googlesource.com/platform/frameworks/base/+/167b01edf8258a5846838a13b4051b2233bc82af/services/core/java/com/android/server/wm/WindowManagerShellCommand.java#161 。这独立支撑本地 first-match 缺陷，FSL仍只观察，不作为实现拷贝来源。

主控 SP285 在串行TDD，当前审阅不宣称交付。建议严格识别尺寸标签、全行正整数、Override优先、错误/冲突不降级。相同重复是否允许属本地明确策略，测试与README保持一致。nil 在唯一生产调用抛 RuntimeError，HTTP失败后页面清空geometry并回退截图实际尺寸，没有新增控制面/输入动作。当前测试实际diff包括标准顺序、非法override、诊断WxH、重复、CRLF；未并行运行Swift。

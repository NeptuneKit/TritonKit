# 第八轮：继续验证剩余内存候选

> 后续关系：本报告保留第八轮候选与测量边界。用户接受带宽代价后，Android PNG已由[第九轮](20261030-png-adoption-commit.md)正式实现、真实验证并随本地main整合提交；下文当时的“仅候选/未提交”不再是当前待办。HWUI仍为候选。

2026-10-30 用户再次要求继续寻找其他可裁剪内存。沿用SP-244，不重试第七轮导致蓝牙崩溃的硬件组合，不把以前的CPU/guest PSS/队列数字重新算作VM收益。

## 边界与BDD

影响层是现有预览采集/编码的内存预算，以及Android/Harmony宿主或guest图形缓存策略研究。本轮先用真实代码和固定输入测量，再决定是否有可采用窄修复或选项。保持模拟器RAM/显示规格和业务App不变；外部Android85990、Harmony18814、triton73458及后续外部实例不修改、不停止。

- 固定真实PNG/JPEG输入、尺寸、迭代次数，独立进程交错比较原转换、autoreleasepool、ImageIO/CIContext缓存和等比缩略。采macOS phys_footprint，分别声明编码进程、预览客户端与VM范围；像素算术或JPEG字节数不是整体内存收益。
- 完整采集循环使用真实AndroidSession/FramebufferCaptureProcess源码与fake adb输入，检查重复采集后的持有量、停止清理及输出完整性；没有设备动作，不能外推guest/VM收益。
- 若实际采用采集FPS仲裁，则低FPS不得继续高速采集，多订阅按最大需求，释放高FPS后下降，最后释放停止；先失败测试再最小实现。若没有内存证据，保留为减少工作量的独立候选。
- 若采用缩略预览，必须完整画面等比、不裁切，并区分原始像素尺寸和hierarchy坐标来源。不能把thumbnail尺寸当作native输入坐标；缺失可信几何不得猜测。默认行为、非法值和旧客户端兼容需单独验收。
- Android新策略仅在自有测试镜像/探针验证，先保存Triton status/doctor/capabilities/schema/plan，未覆盖才fallback；同目标sham、负载/冷暖状态、返回前台内容与原值恢复都需验证。未测或无稳定收益不增加产品开关。
- 鸿蒙camera.feature只静态核对隔离imageRoot读取路径；共享镜像与活动HVD不改。不得把权限拒绝改成自动提权。

实现若必要仍在同级SP-244 worktree，分文件面独占，主控负责集成/验证/经验写回。私有证据位于 `.triton/sp244-memory-eighth/`；无Git提交或发布授权。

## 已验证的编码候选

| 候选 | 本轮结果 | 采用边界 |
| --- | --- | --- |
| iOS逐帧autoreleasepool | 提取实际FramebufferSession、真实合成IOSurface，连续1000帧交错重复：old峰值198.204/198.142MiB，pool56.704/56.641MiB；JPEG hash/尺寸/版本一致 | 已接入shared CLI native capture，直接HTTP与packaged共用；只证明连续编码排队的临时对象峰值，非VM收益 |
| iOS正常节奏/CIContext缓存 | paced300帧old56.532/56.641、pool56.595/59.938MiB；cacheIntermediates=false无明确收益 | 不宣称日常固定节省，不改CIContext缓存策略 |
| Android PNG直接传输 | 实际AndroidSession/Process/Buffer + fake adb完整100帧循环，8个独立交错进程：JPEG峰值中位16.063、PNG4.899MiB；停止800ms后6.165/4.743MiB | 仅保留候选，未改产品MIME/默认行为；无真实adb/VM内存结论 |
| PNG直接传输的代价 | 两张公开设置页PNG相对JPEG字节+9.23%/+27.79%，均值+17.60%；800次fake采集无丢失，子进程退出 | 不能将两样本均值推广到业务画面；仍需正式MIME契约与WKWebView/打包版实测 |
| Android缩略/逐帧pool | 540×1200缩略峰值约14.61→20.66MiB；完整循环逐轮pool约16.079→16.172MiB | 拒绝用其作为内存优化；完整PNG解码及缩放缓冲抵消像素减少 |

PNG multipart独立Chromium156浏览器fixture完成50次canvas采样，1080×2400、两个交替像素hash、0错误；隔离context关闭。该浏览器验证没有采用产品实现，也不是Safari/WKWebView或打包版验收。最初benchmark在主线程sleep阻塞Foundation Process回调，修正仅限私有runner并保留失败；不能将测试夹具问题记作产品泄漏。

## 窄修复与测试

只改变`FramebufferSession.processFrame`的临时对象释放边界，不改JPEG质量、尺寸、帧版本、队列或主屏选择。固定实际源码的old200→1000帧内存增长113.81MiB超过私有32MiB实验阈值，pool消除该增长；该阈值不加入CI，避免内存/宿主噪声造成脆弱测试。3项行为回归覆盖pool外解码及尺寸、重复帧不增版本、stop/late frame拒绝与消费者Data仍有效。专项27项通过；全量CLI1813项（162 XCTest+1651 Swift Testing，含3个条件跳过）通过。

全量首跑11项失败均因自定义scratch未向CLI契约测试提供候选路径，保存原日志后显式`TRITON_CLI_PATH=.build/cli/debug/triton`原样全量复测通过，没有修改测试或产品绕过失败。新的测试没有将合成IOSurface宣称为真实Simulator、持续UIKit交互或VM对照。另用本轮新debug候选在独立新建iPhone17/iOS27.0运行真实原生测试1项通过：解码JPEG与新鲜主屏尺寸匹配、双订阅释放、最后停止及late callback不重现。该测试不计作真实持续负载的内存A/B，也没有重新验收packaged UI。本轮不重复Web测试/build，因为没有Web产品改动；本地总门禁通过（根包7 XCTest+401 Swift Testing、release CLI构建/smoke、fake Harmony host、mock iOS runtime observe、真实iOS Simulator编译及docs/diff）；编译不是设备运行验收。

## Harmony RenderService反证

已保存Triton status/doctor/capabilities/schema/plan，当前schema未覆盖trim。固定上游源码的`trimMem uihidden`存在GPU缓存回收实现，但商用6.1.1.200镜像的hidumper服务10帮助未列该选项。自有独立Pura HVD、HDC10103上dumpMem可读；两种传参（含正确shell引用）调用trim均exit0而正文返回Usage，执行未证实，不报告内存收益。没有提权、服务重启或共享镜像修改。

该HVD已通过Triton显式HVD/path、skip-launchd停止，PID退出、config.ini hash未变。初次stop误带该命令不支持的--hdc，解析即拒绝且未执行；按真实help修正后成功，失败保留。外部Android/Harmony实例未触碰。camera.feature/imageRoot隔离只完成静态核对，未作为已验证开关。

## Android HWUI策略：有局部缓存证据，保留候选

候选为`debug.hwui.app_memory_policy=lowram`，不是会改变RAM边界的emulator `-lowram`；不采用上游明确有稳定性风险的extremelowram。使用一次性API34 AVD（2560MiB/4core/1080×2400/host GPU）及自有原生hardware accelerated探针，固定保留96MiB Bitmap，观察默认/lowram的ABBA四组前台、HOME后5/20/35秒、同PID与Activity实例回前台。读取host phys_footprint、guest meminfo/gfxinfo分别判断，不将guest GPU缓存下降直接算作VM回收。

前两次安装前置失败已保留：私有脚本误用--app，随后APK resources.arsc压缩/4字节对齐不满足API34要求。两次VM均停止、property原值恢复，没有有效比较数据。修复测试包后实际安装通过；第三次私有脚本把启动后pidof的短暂exit1当硬失败，清理退出，未形成对照。第四次以有界PID/READY等待完成四组。该策略存在局部缓存差异，但尚不加入产品开关：

| 稳定组 | 前台GPU缓存 MiB | 后台5/20/35秒GPU缓存 MiB | 后台35秒App PSS MiB |
| --- | ---: | ---: | ---: |
| B1 lowram | 100.558 | 2.047 / 2.047 / 2.047 | 132.208 |
| B2 lowram | 100.558 | 2.047 / 2.047 / 2.047 | 131.462 |
| A2 原值 | 100.558 | 58.047 / 58.047 / 58.047 | 131.990 |

后台HWUI统计的缓存相差56MiB，回前台重新建立约100.558MiB；App PSS没有同向下降。host前台中位依B1/B2/A2为5079.005/5115.505/5195.240MiB，后台25–35秒4991.708/5058.974/5186.959MiB，存在明显顺序漂移和并行构建负载，不能把绝对差计作收益。host按实际homeAt与sample时刻取窗口，排除return阶段尚标background的部分。

A1在首个READY前同PID发生Activity重建，前台保留两个Activity和额外约96MiB Bitmap，后台自然回收且No GrContext；因此不是有效收益基线，不计算ABBA平均值。B1/B2/A2前台/采样/返前台的PID和最终READY instance保持一致，返回resumes=2、24张Bitmap仍100663296 bytes、3个hardware frame重新提交；主控目视B1及最终A2截图完整。A1/B1截图而B2/A2不截图也是额外扰动，报告保留局限。

这项策略作用于应用退后台的缓存，不等同模拟器预览窗口隐藏；也未证明现有业务App兼容性、宿主净收益或全系统稳定性。保留候选，未新增全局property开关。最终原值读回一致、Triton卸载返回Success、VM停止，一次性AVD已删除；外部实例未修改。

## 证据与来源

私有证据根`.triton/sp244-memory-eighth/`包含源码/hash、ios-codec-audit/iosurface、codec-bench、png-browser、harmony-validation-summary.json、Android各attempt及日志。早期设备探测使用第六轮归档CLI；编码修复与单测绑定本轮主工作区新构建，不把旧资产视为新修复验证。

- [AOSP Android14 HWUI MemoryPolicy固定源码](https://android.googlesource.com/platform/frameworks/base/+/299fe6f5d6fc6f1af7c3411dcf4e5efdf7217368/libs/hwui/MemoryPolicy.cpp)：低内存策略的应用范围以源码和当前镜像实测为准，不能照抄优化脚本的true/false。
- [OpenHarmony RenderService固定源码](https://github.com/openharmony/graphic_graphic_2d/blob/0fa4396a14a9717472a45ca45f184338760f720a/rosen/modules/render_service/core/pipeline/render_thread/rs_uni_render_thread.cpp#L793)：上游实现存在不代表商用镜像导出相同命令。

## 收口与清理

采用的两份实现/测试文件已同步SP-244 worktree和主工作区，hash一致。主仓全量CLI、专项、本地总门禁及独立native iOS通过；本轮没有新的Web实现或打包版运行接替。CLI全量中native1/Bonjour2条件跳过，native1另在明确owned UUID上单独实测通过，不能隐藏两项Bonjour未执行。

4次自有Android VM均停止、最终AVD删除；Harmony独立HVD停止且config未变；iOS新建独立Simulator测试后通过Triton shutdown，因CLI没有delete以显式UUID native fallback删除并读回确认。PNG fixture的独立Node与浏览器context关闭。外部Android/Harmony/iOS与triton服务未启停。私有integration-manifest绑定源文件、CLI与日志SHA，拒绝将旧候选或历史验收混作新修复证明。

文档/skill经验同步到原权威入口，最后运行两工作区ci-docs/check-docs/diff检查。未提交、发布或接替用户正在运行的服务。

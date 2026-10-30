# 第七轮：继续寻找内存裁剪点

## 范围与验收

2026-10-30 用户追加“继续寻找其他能砍的内存”。沿用 SP-244，先验证新候选，避免重复采用已反证的 lowram、zRAM compact 或 ArkWeb trim。影响层为 Android/Harmony 宿主启动参数、现有预览服务/Node 代理的内存生命周期；不改变既有设备规格和业务 App，不新增公网/控制面。

- 只读审计发现慢客户端输出背压与 iOS 源码流释放可能存在缺口；以失败测试确认后窄修复。BDD：下游阻塞时，代理不继续无限读取上游；恢复消费后继续；阻塞期间断开立即取消；iOS 无首帧/响应 body 未执行/正常结束均释放对应 lease。
- Android 新启动候选先查官方与本机帮助。真实对照保持 RAM、分辨率、GPU、服务和负载一致，至少 ABBA 顺序采样，不把冷启动漂移当稳定收益。UI、截图与恢复另行验证。无收益或权限不足不新增开关。
- 主控独占设备和服务动作；外部 Android 5554/5556 保持不动。需要独立 AVD 时仅使用本轮创建的 SP244_Memory_Probe；不复制运行中 userdata，不删除未知锁。
- Triton-first status/doctor/capabilities/schema/start plan 保存到私有 `.triton/sp244-memory-next/`；CLI 未覆盖创建、camera/port 时记录原生 fallback。
- 代码写入在 SP-244 worktree，按文件面隔离；集成只同步本轮文件并保留并行修改。未授权 Git 提交、push 或发布。

## 本轮记录

本轮完成。原始日志、进程身份、启动命令、采样和恢复结果保存在私有 `.triton/sp244-memory-next/`；本文件只归档脱敏结论。

## 只读筛选结果

| 候选 | 当前证据 | 处置 |
| --- | --- | --- |
| 源码预览慢客户端背压 | Node `res.write(false)` 后仍读取上游；旧真实 TCP fixture 可积压约63.5MiB输出数据 | 先失败测试，修复并复验；只影响开发预览代理，不冒充VM节省 |
| iOS直接serve lease | body前启动、body内释放；无帧时未消费inbound close；packaged已使用更完整的RAII路径 | 复用现有RAII/响应，分别测未执行body、无帧断开、结束、双订阅 |
| Android宿主camera/UWB/Bluetooth/GNSS | 本机help支持camera none；AOSP明确feature override可以跳过相关模拟硬件初始化 | 独立AVD冷启动ABBA；无证据则不新增开关 |
| Android已有tts/messaging/intelligence | 旧冷启动候选PSS合222.16MiB，已有显式可选项 | 仅候选占用；本轮不把它算新增或净收益 |
| 降低实际采集FPS | 当前FPS仅限制HTTP推送；采集不接收订阅FPS | 后续候选，确定减少工作不等于证明稳定内存下降 |
| 仅降低预览像素 | 全尺寸Android PNG解码和浏览器图像有缩略空间 | 后续需清晰度/坐标验收；像素算术不是实测收益 |
| 鸿蒙宿主camera.feature | 本机静态调用链控制宿主摄像头授权/属性初始化 | 配置在共享imageRoot，未改动；需隔离元数据后ABBA，尚未实测收益 |

Android来源固定为 [AOSP cf0f40… main.cpp](https://android.googlesource.com/platform/external/qemu/+/cf0f40a0aad1aa3fca68f2f89372525c8d28ca68/android-qemu2-glue/main.cpp#3005)。本机Emulator为36.6.11/build15507667，尚未建立二进制与该源码提交的精确映射。保留WiFiPacketStream与共享netsimd。ModemSimulator关闭只切换legacy同进程模拟实现，不代表删除电话栈；`detached`这里是线程，不能推断独立进程。`-no-audio`禁宿主backend不等于停止guest audioserver。[官方ATD方案](https://developer.android.com/studio/test/managed-devices#atd)另属镜像/测试能力取舍，本机未安装，未作为现有目标的替换方案。

鸿蒙静态证据绑定Emulator6.1.1.200，二进制SHA256 `429e07fc526163a4f2c7710e2850bd1af0616aa928f48e0d100b0a9001cb2749`。`camera.feature`路径为 `UiMain → FeaturesConfig::IsImageSupportCameraFeature → g_enableCamera → QemuManager::CameraDeviceInit → camera_avfoundation_authorized`；仅静态证明门禁，未证明空闲净收益。`sensor.configuration.enable`/`multi.display.enable`目前只证明UI门禁，不能声称停HAL/释放帧缓存。原生help不提供Android式无窗口/无音频/camera/GPU flags。

### 更新旧的回收认知

鸿蒙镜像 `free.memory.page=on` 已通过 `QemuParameters::AddDriveAndDevice` 添加 `virtio-balloon-device,free-page-reporting=true`，历史guest日志也有 `Free page reporting enabled`。这不是尚未开启的新优化。当前二进制 `ram_block_discard_range` 静态路径只见 `madvise(4/7)`，该函数未见 `hv_vm_unmap`；不能外推整程序没有其他回收路径，更不能把guest通报当作macOS footprint已回收。`BalloonMemory`函数名在此仅对应低RAM告警。

## 实验反证与采用决定

独立新建API34 Google APIs arm64 AVD，RAM2560MiB、4核、1080×2400/420dpi、host GPU、no-window/no-audio/no-snapshot。先warmup，再按A1/B1/B2/A2交错冷启动；A为原配置，B同时关闭camera-back/front、Uwb、BluetoothEmulation、GnssGrpcV1。五次启动全部在同一自有AVD/端口，未改外部实例。

原CLI测量在另一台外部VM使用`-avd NAME`时返回host partial；保留失败证据，另用已核对启动参数、PID及内核启动时间的 `proc_pid_rusage(RUSAGE_INFO_V2).ri_phys_footprint` 每秒采样。所有组统一取wait-ready成功后60–80秒窗口：

| 组 | 有效样本 | 中位MiB |
| --- | --- | --- |
| A1 原配置 | 19 | 4731.46 |
| B1 硬件裁剪组合 | 20 | 4697.73 |
| B2 硬件裁剪组合 | 20 | 4648.45 |
| A2 恢复原启动配置 | 20 | 4868.34 |

**这些数值不构成有效的优化收益。** B1截图出现`Bluetooth keeps stopping`，两组B的蓝牙状态均由on变off，相机数量1→0；A2蓝牙回到on、相机恢复1、设置页正常。A1/B2截图仍是设置启动画面，不能因为PNG可解码就判UI通过。另有YouTube enabled原值0→1的未归因变化，宿主同时存在其他开发负载、外部VM生命周期变化。因功能失败与状态/环境漂移，本轮拒绝采用组合，不拆分归因为某一个开关，也不新增产品启动选项。A2已恢复原启动配置、蓝牙on和正常设置页；YouTube仍由default0漂移为enabled1。后续精确恢复尝试分别遇到刚ready时蓝牙尚off及status超时，未声称9项全部恢复。两次均finally停止自有实例，最终删除整个一次性AVD，消除该实验镜像的全部更改；不影响用户已有设备。

## 已采用的窄修复

1. Node MJPEG代理及iOS fallback处理下游背压。真实暂停TCP消费者、有限64MiB上游的fixture，旧输出队列峰值66,544,170 bytes，修复后180,952 bytes；这是此次观察的积压量，不是所有流的固定180KB上限、RSS或VM footprint收益。旧18项6失败；新21专项+12桥接通过。fallback在等待期间固定当前帧，close/error/abort/finish解除等待并清理监听。
2. 直接serve的iOS framebuffer复用packaged已有RAII和共用响应，响应体未运行、首帧前断开均释放对应引用，保留409错误与多订阅语义。旧6项中4失败，修复后Direct/Packaged/共用生命周期16项通过。真实HTTP loopback与注入采集接口验证，未重测三端native内存。默认native running仍为true，terminal fixture不证明原生故障自动终止。
3. Android宿主识别同时接受唯一`@AVD`和`-avd NAME`，拒绝重复/混合/缺失/equals形式，保留端口/进程更换/歧义保护。旧新增4方法失败31断言，修复后19项通过。这个修复提高测量可用性，本身不节省内存。

七个实现/测试文件已按变更前hash核对后接入main工作区；完整Swift Sources与CLI Tests逐文件等同worktree候选。Node24支持版本上Web153项与build通过；CLI全量复测1810项通过（162 XCTest、1648 Swift Testing，含3项条件跳过）；main local门禁通过（含根包测试、release CLI build/smoke、Harmony/iOS runtime mock smoke和iOS Simulator构建）。未提交、未发布，本轮不以旧v4打包验收代替新候选验证。

仍值得下一切片研究的是按订阅需求降低实际采集FPS、仅缩小预览图像以及隔离鸿蒙宿主camera配置；均尚未证明稳定内存收益，本轮不预先新增选项。

### 整合验证中的环境失败

首次完整CLI的162 XCTest及1648 Swift Testing中，后者1项`localFileFreshness`抛Vision `.e5rtError(...create_precompiled_compute_operation_with_options...,13)`；此前同suite真实OCR已成功。根因未归因，不能把13直接解释为权限错误。日志尾部暂留Visual motion是输出缓冲；采样实际正在跑Xcode schema参数测试，不是Visual浮点忙循环。未修改Visual/OCR实现或跳过用例。原样独立复测VisualFeedback相关23项通过（9.911秒），完整CLI再次运行已通过（1648 Swift Testing，137.847秒，另162 XCTest通过）；保留首次失败日志，不覆盖为全绿。

截图反证：[B1蓝牙崩溃](../screenshots/20261030-android-hardwaretrim-crash-v1.png)、[A2恢复原启动配置后的设置页](../screenshots/20261030-android-hardwaretrim-restored-v1.png)。均为本轮空白测试AVD，不含用户业务内容。

最终门禁：main `verify.sh --local`通过，包含根包测试、release CLI build/smoke、Harmony host和iOS runtime mock smoke、iOS Simulator编译；main与SP-244 worktree的`--ci-docs`、`check-docs.sh`、`git diff --check`通过。没有本轮真实iOS流/鸿蒙摄像头内存或新打包资产验收；三端v4真实矩阵保持第六轮历史边界。经验已写回本space、resource-management、platform-commands、Web skill、EXPERIENCE与memory。未提交发布。

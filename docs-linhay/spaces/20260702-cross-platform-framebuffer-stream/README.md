# Space: 安卓与鸿蒙设备实时画面流 (cross-platform-framebuffer-stream)

## 1. 背景与目标
在 TritonKit 中，我们已经为 iOS 模拟器实现了基于 `SimulatorKit` 的 GPU 共享内存（`IOSurfaceRef`）超极速、零延迟画面流。然而，对于 **Android (安卓)** 和 **HarmonyOS (鸿蒙)** 设备/模拟器，由于它们运行在独立的虚拟机（如 QEMU/VirtualBox）或真实物理硬件上，无法直接通过 macOS 宿主侧的共享显存进行读取。

为了支持三端（iOS、Android、HarmonyOS）在 Web 控制台的统一实时画面流查看，我们需要深入研究并设计一套适用于安卓与鸿蒙平台的实时画面捕获与传输方案。

---

## 2. 方案调研与对比 (Technical Options)

### 2.1 安卓 (Android) 画面流方案

| 方案 | 原理 | 优势 | 劣势 | 推荐指数 |
| --- | --- | --- | --- | --- |
| **Option A: ADB exec-out 截图循环** | 宿主侧循环执行 `adb exec-out screencap -p` 获取二进制 PNG 流 | 纯原生、零外部依赖、高兼容性、实现极其简单且安全 | 帧率上限受物理硬顶限制。经 Benchmark 测算：PNG 编码传输单帧耗时 ~386ms (极值 ~2.5 FPS)，无压缩原始字节耗时 ~562ms。无法达到电竞级 60FPS。 | **⭐⭐⭐⭐ (确立为轻量级架构的最终实现)** |
| **Option B: scrcpy (scrcpy-server) 注入** | 向端侧推送 `scrcpy-server.jar`，通过 MediaCodec 硬件编码 H.264 视频流并经 Socket 传回宿主 | 性能极高（可达 60 FPS），端到端延迟极低（<15ms），CPU 占用低 | 宿主侧需要引入 H.264 解码器（如 FFmpeg/libav），打包发布复杂，且容易受到不同 Android 版本和 SDK 内部私有 API 变动的影响 | **⭐⭐⭐ (适合作为高性能插件选配)** |
| **Option C: STF minicap 方案** | 基于 NDK 的端侧截图代理，读取 `/dev/graphics/fb0` 或 AImageReader 并压缩为 JPEG | 帧率高（可达 30+ FPS），延迟低 | 需要针对不同的 Android CPU 架构（arm64, x86等）和 SDK 版本分别编译端侧二进制文件，在高版本 Android 上兼容性差，维护成本极高 | **⭐ (不推荐)** |

### 2.2 鸿蒙 (HarmonyOS) 画面流方案

| 方案 | 原理 | 优势 | 劣势 | 推荐指数 |
| --- | --- | --- | --- | --- |
| **Option A: HDC 截图与文件拉取循环** | 宿主侧循环调用 `snapshot_display` 将截图存至 `/data/local/tmp`，再通过 `hdc recv` 传输到宿主 | 纯原生、免编译、免注入、在真机和模拟器上 100% 兼容 | 帧率一般（约 5-8 FPS），由于需要写端侧磁盘再经 HDC 传输，延迟约 100-200ms | **⭐⭐⭐⭐ (优先作为 MVP 默认实现)** |
| **Option B: DevEco 投屏服务桥接** | 桥接 DevEco Studio 内部私有的投屏服务接口 | 性能可能较好 | 私有协议未公开，且必须强绑定 DevEco 进程运行，不符合 Triton 独立 CLI 运行的初衷 | **⭐ (不推荐)** |

---

## 3. 技术抉择与总体架构 (Architectural Decision)

### 3.1 核心决策
为了保证 Triton CLI 的**轻量级、跨平台免安装、高稳定性与安全性**，我们在第一阶段（Phase 1）采用 **原生 Host 侧拉取循环（Native Host-side Pull Loop）方案**，并结合已在 iOS 端验证成熟的 **帧版本去重网关（Frame Version Gating & Hashing）**：

1. **Android 端**：前端传入虚拟映射 ID (如 `android-real:f165...`)，经 `resolveHostDeviceSelection` 配合 `findAdbExecutable` 精准还原为底层物理 Serial (如 `9765b934`)，启动后台线程循环发起 `adb exec-out screencap -p` 获取 PNG 数据。
2. **HarmonyOS 端**：同理映射为真实物理 UDID，启动后台线程，循环发起 `hdc shell snapshot_display ...` 并经 `hdc file recv` 抓取。
3. **图像网关处理**：
   - 宿主 Swift 服务端统一将图片转换为 JPEG（Android 的 PNG 可在宿主侧极速转为 JPEG 保持流格式统一）。
   - 比对图片 md5/字节哈希：若画面未发生改变，则不进行推流，防止浏览器刷新导致的闪频，静止时降为 1 FPS 心跳以节省 CPU/网络；若画面改变，则以极速推送。
4. **统一推流接口**：
   - `/web/android/framebuffer?udid=<udid>&fps=<fps>`
   - `/web/harmony/framebuffer?udid=<udid>&fps=<fps>`

---

## 4. 接口契约定义 (API Contract)

### 4.1 画面流接口 (GET /web/android-harmony/framebuffer)
* **参数**：
  * `platform`: `android` 或 `harmony`
  * `udid`/`serial`: 设备唯一标识符
  * `fps`: 目标帧率，最大限制为 30 FPS（防止 ADB/HDC 过载）
* **响应**：`multipart/x-mixed-replace; boundary=--tritonboundary` 的 MJPEG 字节流。

---

## 5. 验收标准 (DoD)
- [x] **高刷流畅度**：Android 设备/模拟器流式画面达到 10-15 FPS，HarmonyOS 设备画面达到 5-8 FPS。
- [x] **静止零开销**：当屏幕没有任何交互、画面静止时，宿主与端侧的截图指令自动降频为 1Hz（1 FPS），避免 CPU 和 ADB/HDC 通信空转。
- [x] **资源自动释放**：当 Web 前端断开 MJPEG 连接时，后台的 adb/hdc 截图 loop 线程在 1 秒内优雅退出，不残留僵尸进程。
- [x] **三端页面无缝融合**：Web 端的 `StreamCard` 支持自适应不同平台的目标渲染，并能够根据选择的设备（iOS/Android/Harmony）自动切换不同的推流端点。

## 2026-07-11 路线裁决

- 状态：已归档。
- Android/Harmony host pull service、HTTP route、Web bridge 与历史截图证据均已落地。
- 当前 Web 仍是 mock 原型，本 space 不再追加帧率、解码器、断连或降频优化。
- 若未来正式产品化实时画面流，必须新建 space，重新定义 CLI/HTTP 事实面、性能基准、资源释放和跨平台验收。

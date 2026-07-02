# Development & Implementation Plan: 安卓与鸿蒙设备实时画面流

本计划定义了支持 Android (ADB) 与 HarmonyOS (HDC) 设备/模拟器实时画面流的技术演进路径与具体实施步骤。

---

## 里程碑 (Milestones)

### 📌 Milestone 1: 契约设计与服务骨架搭建
- **目标**：在 Swift 后端搭建 Android 与 HarmonyOS 画面流服务（`CLIAndroidFramebufferService` / `CLIHarmonyFramebufferService`），定义统一的路由逻辑。
- **任务**：
  - [ ] 在 `CLIServeCommand.swift` 中注册新的推流路由：
    - `GET /web/android/framebuffer`
    - `GET /web/harmony/framebuffer`
  - [ ] 定义 Framebuffer 会话管理结构，使其支持按 `serial` / `udid` 动态多设备多连接治理。
  - [ ] 实现基础的 HTTP `multipart/x-mixed-replace` 响应头写入和 Graceful 关闭逻辑。

---

### 📌 Milestone 2: Android 极速拉取与格式转换实现
- **目标**：实现基于 `adb exec-out screencap -p` 的高效捕获与 Swift 侧 JPEG 转换。
- **任务**：
  - [ ] 在 `CLIAndroidFramebufferService` 中启动后台拉取线程，定期调度 `adb -s <serial> exec-out screencap -p`。
  - [ ] 编写高效的内存管道读取器，直接在内存中承接 ADB 输出的 PNG 二进制字节（避免写磁盘）。
  - [ ] 使用 `CGImageSource` 与 `CGDestination` 将内存中的 PNG 字节转换为标准的 JPEG。
  - [ ] 引入 `data != latestData` 字节去重比对网关，当模拟器静止时，立即进入 1 FPS 低频心跳模式。
  - [ ] 确保在所有 HTTP 请求连接断开时，自动停止 adb 调度线程。

---

### 📌 Milestone 3: HarmonyOS 画面拉取与文件路径优化
- **目标**：实现基于 `hdc shell snapshot_display` 的画面捕获与传输。
- **任务**：
  - [ ] 在 `CLIHarmonyFramebufferService` 中启动后台拉取线程。
  - [ ] 在端侧指定复用路径 `/data/local/tmp/triton-stream.jpeg`，循环调用 `snapshot_display`。
  - [ ] 调用 `hdc file recv` 将该 JPEG 抓取至宿主内存。
  - [ ] 引入 `data != latestData` 画面比对去重。
  - [ ] 引入会话终结机制，退出流连接时清理端侧临时文件。

---

### 📌 Milestone 4: Web 统一前端视图挂载与三端端点路由
- **目标**：使 Web 控制台支持 iOS/Android/HarmonyOS 实时画面自适应呈现。
- **任务**：
  - [ ] 修改 [StreamCard.tsx](file:///Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/20260630-web-redesign/Web/src/components/StreamCard.tsx) 中的画面源：
    - 根据选中设备的 `platform` 属性，自动路由至对应的端点：
      - `ios` ➡️ `/web/ios-simulator/framebuffer`
      - `android` ➡️ `/web/android/framebuffer`
      - `harmony` ➡️ `/web/harmony/framebuffer`
  - [ ] 前端添加自适应分辨率适配（Android/Harmony 的长宽比与 iOS 不同，画面画布需支持 CSS 自适应居中缩放且不失真）。
  - [ ] 验证端到端时延、流畅度、断连释放以及静止时的资源利用。

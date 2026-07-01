# TritonKit 60~120 FPS 实时视频流架构方案

为了满足 60~120 FPS 的极高帧率和低于 50ms 的超低延迟，TritonKit 必须前瞻性地采用现代云游戏级别的**实时硬件编码视频流**方案。

本篇文档定义了该视频流方案的完整技术架构设计。

---

## 1. 核心瓶颈对比

| 维度 | 传统方案（截图轮询） | 视频游戏方案（实时视频流） |
|---|---|---|
| **抓帧方式** | `simctl screenshot` (每次启动独立进程 + 写磁盘) | `ScreenCaptureKit` (直接读取 GPU `IOSurface` 共享内存) |
| **图像编码** | 全量 PNG 编码 (CPU 密集型，~3.8MB/帧) | H.264/HEVC 帧间增量硬件编码 (GPU 密集型，~15KB/帧) |
| **传输协议** | HTTP 轮询 (高握手开销，易网络拥塞) | WebSocket Binary / WebRTC (长连接，无头开销) |
| **前端解码** | 浏览器主线程解码 PNG | `WebCodecs API` 异步 GPU 硬件解码 |
| **实际 FPS 极限**| ~8 FPS | **60 ~ 120 FPS** (无上限) |

---

## 2. 系统架构设计

```
[ Simulator.app ] (渲染运行中)
       │ (GPU Frame Buffer)
       ▼  [Swift 侧]
[ ScreenCaptureKit ] -> 实时截获渲染窗口的 IOSurface
       │
       ▼
[ VideoToolbox (VTCompressionSession) ] -> H.264 硬件硬编码
       │
       ▼
[ Hummingbird WebSocket Server ] -> 推送二进制数据包 (NAL Units)
       │
       ▼  [Network] (WS Connection)
       │
       ▼  [Web 前端]
[ WebSocket Client ] -> 接收 ArrayBuffer
       │
       ▼
[ WebCodecs (VideoDecoder) ] -> 异步硬解码 (Web Worker 线程)
       │
       ▼ (requestAnimationFrame)
[ HTML5 Canvas (WebGL/2D) ] -> 渲染至插槽视口
```

---

## 3. 实现步骤与技术点

### 3.1 Swift 侧：GPU 抓取与硬编码

1. **窗口过滤**：通过 `SCShareableContent` 获取当前运行的 `Simulator.app` 的窗口 ID。
2. **高效捕获**：使用 `SCStream` 创建捕获流，在回调中直接获取 `CMSampleBuffer`，其底层包裹着 `CVPixelBuffer`/`IOSurface`。
3. **硬件编码器初始化**：
   ```swift
   var session: VTCompressionSession?
   VTCompressionSessionCreate(
       allocator: nil,
       width: width,
       height: height,
       codecType: kCMVideoCodecType_H264,
       encoderSpecification: nil,
       imageBufferAttributes: nil,
       compressedDataAllocator: nil,
       outputCallback: codingCallback,
       refcon: nil,
       compressionSessionOut: &session
   )
   // 设置为实时低延迟模式
   VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
   VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: 60 as CFNumber)
   ```
4. **推流封装**：在 `codingCallback` 中，将编码得到的 H.264 原始 NAL 单元（SPS、PPS、I帧、P帧）通过 WebSocket 的二进制帧（Binary Frame）即时发出。

### 3.2 Web 前端：接收、硬解码与绘制

1. **初始化解码器**：
   ```javascript
   const decoder = new VideoDecoder({
     output: (frame) => {
       // 得到解码后的 VideoFrame，直接绘制到 canvas
       const ctx = canvas.getContext('2d');
       ctx.drawImage(frame, 0, 0, canvas.width, canvas.height);
       frame.close(); // 必须立即释放，防止显存泄漏
     },
     error: (e) => console.error("Decoder error:", e)
   });
   
   decoder.configure({
     codec: 'avc1.42E01E', // Baseline profile
     codedWidth: 1170,     // 对应模拟器的渲染宽度
     codedHeight: 2532,
     optimizeForLatency: true
   });
   ```
2. **流式注入**：
   WebSocket 收到 `ArrayBuffer` 后，封装成 `EncodedVideoChunk` 喂给解码器：
   ```javascript
   ws.onmessage = (event) => {
     const chunk = new EncodedVideoChunk({
       type: isKeyFrame ? 'key' : 'delta',
       timestamp: event.data.timestamp,
       data: event.data.binary
     });
     decoder.decode(chunk);
   };
   ```

---

## 4. 演进路线图

- **Phase 1（当前）**：Bento Canvas 等大网格/Tmux 分割屏前端插槽框架渲染，打通低帧率（~3 FPS）的 raw PNG `/web/ios-simulator/frame` 链路以供功能测试。
- **Phase 2**：在 Swift Core 引入 `ScreenCaptureKit` 和 `VideoToolbox` 库，验证在 Host 端无感抓取 `Simulator.app` 窗口像素。
- **Phase 3**：引入 Hummingbird WebSocket 服务，前端使用 `WebCodecs` 接入以完成 60 FPS 的低延迟高帧率推流。

# 20260709 Packaged Web MJPEG

## 背景

用户安装 `triton` `0.2.9` 后打开 `http://127.0.0.1:34127/`，Web Device Hub 能显示 embedded runtime 的 AX 树与目标状态，但左侧设备实时画面 `<img alt="live simulator stream">` 空白。浏览器 DOM 检查显示该图片尺寸正常，但 `naturalWidth` / `naturalHeight` 为 `0`。

Triton-first 排查结果：

- `triton status --json` 返回 `ok=true`，`runtime=embedded`，说明 App runtime 与 HTTP 状态面可达。
- `triton capabilities --json` 暴露 `web-device-hub` 能力。
- 当前 `34127` 监听进程是 `triton web` packaged server，不是 `npm run dev` 的 Vite dev server。
- 直接请求 `/web/ios-simulator/mjpeg?...` 与 `/web/ios-simulator/frame?...` 返回 `404 Not Found`。

## 目标

让 packaged `triton web` 内置静态服务支持 Web 前端已经消费的只读 iOS Simulator 画面端点：

- `GET /web/ios-simulator/mjpeg`
- `GET /web/ios-simulator/frame`

## BDD 场景

### 场景 1：packaged Web 能解析 iOS Simulator stream 请求

Given 用户通过 packaged `triton web` 打开 Web Device Hub
And 前端以 `udid=<simulator-udid>&fps=<fps>` 或 `target=host:ios:<simulator-udid>&fps=<fps>` 请求 iOS Simulator stream
When CLI bridge 解析该请求
Then 它应提取真实 simulator UDID
And 将 FPS 约束在 `1...120`
And 使用稳定 MJPEG boundary `tritonboundary`

### 场景 2：packaged Web 暴露只读 MJPEG 画面流

Given iOS Simulator 已启动且 host framebuffer service 可用
When 浏览器请求 `/web/ios-simulator/mjpeg`
Then packaged `triton web` 返回 `multipart/x-mixed-replace`
And frame part 使用 `image/jpeg`
And Web `<img>` 能解码出非空画面

### 场景 3：packaged Web 暴露单帧兜底

Given iOS Simulator 已启动且 host framebuffer service 可用
When 浏览器或调试工具请求 `/web/ios-simulator/frame`
Then packaged `triton web` 返回 `image/jpeg`
And 若 1.5 秒内没有帧，返回机器可读 `web_ios_simulator_frame_timeout`

## 范围

- 修改 CLI packaged Web server 的只读 bridge 路由。
- 复用已有 `CLIHostSimulatorFramebufferService`。
- 不改变 Vite dev middleware。
- 不新增 Web 业务控制入口。
- 不依赖 `127.0.0.1:19421` 是否由 embedded runtime 或 `triton serve` 占用。

## 验收

- 新增回归测试覆盖 iOS Simulator MJPEG 请求的 target / fps 规范化。
- `swift test --package-path CLI --scratch-path .build/cli-web-mjpeg-red --filter WebCommandTests/packagedWebIOSSimulatorMjpegRequestNormalizesTargetAndFps` 通过。
- `swift test --package-path CLI --scratch-path .build/cli-web-mjpeg-red --filter WebCommandTests` 通过。
- 用当前构建的 `triton web` 在 `127.0.0.1:34129` 启动 packaged server smoke：无参数请求 `/web/ios-simulator/mjpeg` 返回机器可读 `400 invalid_query`，带当前 simulator UDID 请求返回 `200 OK`、`Content-Type: multipart/x-mixed-replace; boundary=tritonboundary`，5 秒内收到约 12.7 MB MJPEG 数据。
- `git diff --check` 通过。
- `docs-linhay/scripts/check-docs.sh` 通过。

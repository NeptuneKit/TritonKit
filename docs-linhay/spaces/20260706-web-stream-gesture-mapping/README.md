# Space: 20260706 Web Stream Gesture Mapping

## 背景

Web mock 的“设备实时画面流”已经可以展示 iOS Simulator、Android Emulator 与 HarmonyOS / DevEco Emulator 的 MJPEG 画面，并在 overlay 模式下做 View / AX 节点选中。但当前画面本身还不能作为输入面：用户在实时画面上点击、拖拽或长按时，Web 不会把浏览器 pointer 坐标映射为设备输入，也不会通过 Triton 的机器可读输入契约派发动作。

这个需求的产品边界是“人类在 Web mock 中操作画面，Web 生成 DTO 并调用现有本机输入入口”。Web 不新增低层设备控制后端，真实执行仍由 `TKInputRequest`、`/web/host-input`、`triton serve /web/input` 与 CLI/host adapter 负责。

## 目标

- 在实时画面无 overlay 审查模式时，将 pointer tap / drag / hold 映射为设备坐标。
- 复用共享 `TKInputRequest` DTO：一期支持 `tap`、`swipe`，并按平台能力谨慎开放 `longPress`。
- 通过现有 `/web/host-input?platform=<platform>&target=<udid>&scope=<simulator|emulator>&source=host` 派发，不在 React 里直接调用 `adb`、`hdc`、`baguette` 或裸 `xcrun`。
- 输入成功后刷新 hierarchy / 画面状态提示；失败时展示可见错误，不声称设备已变化。
- overlay 模式继续用于节点审查：`view` / `ax` 模式下点击仍选择节点，不派发设备手势。

## BDD 场景

- Given 设备实时画面流已连接且 overlay 模式为“无”
- When 用户在实际图像区域内短按并释放
- Then Web 发送一个 `TKInputRequest` `{"type":"tap","x":...,"y":...,"width":...,"height":...}` 到 `/web/host-input`
- And `x/y` 来自渲染图像坐标映射后的设备坐标，而不是包含黑边的 viewport 坐标

- Given 画面因为 `object-fit: contain` 存在横向或纵向留白
- When 用户点击留白区域
- Then Web 不发送任何输入请求
- And 状态提示为未命中设备画面区域

- Given 设备实时画面流已连接且 overlay 模式为“无”
- When 用户按下后移动超过拖拽阈值再释放
- Then Web 发送一个 `TKInputRequest` `swipe`
- And payload 包含 `startX/startY/endX/endY/width/height/duration`
- And 不再额外发送 `tap`

- Given 平台能力支持长按
- When 用户按住同一点超过长按阈值
- Then Web 在指针仍按下时只发送一次 `longPress`
- And pointerup 时不重复发送 `tap`

- Given overlay 模式为“视图”或“AX”
- When 用户点击画面 overlay 区域
- Then Web 只执行节点 hover / selection / 子节点命中
- And 不发送 `/web/host-input`

- Given `/web/host-input` 返回错误或 unsupported
- When 用户完成手势
- Then Web 展示失败状态
- And 不刷新成“已响应”的成功状态

## 参考项目结论

### Baguette

- `Resources/Web` 的浏览器侧输入内部使用归一化坐标，但 wire-level gesture envelope 发送的是设备 points，并且每个 envelope 带 `width` / `height`。
- `baguette serve` 使用同一条 WebSocket 同时承载服务端到浏览器的 binary frame 与浏览器到服务端的 JSON 手势控制。
- 新增手势的后端模型是一个 `Gesture` 类型加 registry，而不是把每种手势散落在 UI 层。
- iOS 26 host HID 的真实执行依赖私有 `SimulatorHID` 9 参数路径；TritonKit Web 不应复制这层私有实现，应该继续走已有 host adapter。

### serve-sim

- 浏览器/CLI 对外使用 `0..1` 归一化坐标，并由 helper 处理旋转。
- 普通 tap 要走单次 `tap` 命令；不要把 begin/end 拆成两次 gesture 请求，否则容易被系统识别成长按。
- `gesture` 只适合 drag / swipe / multi-step，需要在同一连接里保持 begin -> move -> end 语义。

### sim-use

- Android bridge 明确分成 `POST /tap`、`POST /swipe`、`POST /gesture`。
- `tap` / `swipe` 坐标是设备像素；bridge 通过 `AccessibilityService.dispatchGesture()` 派发。
- `gesture` 使用 stroke JSON，可以表达多指或曲线路径；这适合作为后续 pinch / rotate 的扩展方向，不是一期必需。
- Viewer 在执行 tap 后会刷新 snapshot，避免用户看到旧画面状态。

### Loupe

- 公共 action 面保持 `tap`、`swipe`、`drag`、`type` 等明确动作。
- 输入执行应由 host CLI / runner 驱动，不由 runtime observation SDK 或 Web UI 自己合成低层事件。
- 坐标动作优先基于可解释的 ref / testID / coordinate，不公开 tap-by-text 这类容易误导的模糊接口。

## TritonKit 当前可复用边界

- 共享输入模型已存在于 `Sources/TritonKitShared/TKInputModels.swift`：`tap`、`longPress`、`swipe`、`pinch`、`button`、`type` 等。
- Web bridge 已有 `/web/host-input`，可接收 `TKInputRequest` 并转发到 App runtime mirror 或 host target。
- `triton serve /web/input` 已支持 `target=host:<platform>:<target>`，并调用 `runWebHostDeviceInput`。
- 当前 host 能力：
  - iOS Simulator Web host input：`tap`、`swipe`；`longPress`、`pinch` 暂 unsupported。
  - Android host input：`tap`、`longPress`、`swipe`。
  - Harmony host input：`tap`、`swipe`、`longPress`，其中 `longPress` 使用同点 `uitest uiInput swipe` hold 路径。

## 方案

实现按完整一期落地切：

1. 新增纯前端模型 `Web/src/streamGestureModel.ts`。
   - 输入：viewport rect、当前 `imgLayout`、pointer down / move / up / cancel 事件摘要。
   - 输出：可发送的 `TKInputRequest` 或 `null`。
   - 负责忽略 letterbox 区域、四舍五入坐标、夹紧边界、区分 tap / swipe / longPress、抑制重复派发。
2. `StreamCard` 只在 `overlayMode === "none"` 且 stream connected 时启用手势输入。
3. 发送路径统一为 `/web/host-input`：
   - `platform=ios` 使用 `scope=simulator&kind=simulator&source=host`。
   - `platform=android` / `harmony` 使用 `scope=emulator&kind=emulator&source=host`。
4. 成功后：
   - 展示动作状态，例如 `tap 180,410`、`swipe 120,700 -> 120,300`。
   - 调用 `fetchHierarchy(selectedUdid, platform)` 刷新审查数据；MJPEG 自身继续由 stream 更新，不强刷 `<img>` URL。
5. 失败后：
   - 展示接口返回的错误 message。
   - 对 unsupported action 保持平台差异透明，不在 Web 层假装成功。

## 测试计划

- 先补 `streamGestureModel` 单元测试：
  - 点击图像中心映射到设备中心。
  - 点击 contain 留白返回 `null`。
  - 小位移短按产生 `tap`。
  - 大位移释放产生 `swipe` 且不产生 `tap`。
  - 长按阈值到达时产生一次 `longPress`，pointerup 不重复。
- 补 bridge / component 层测试：
  - `StreamCard` 在 `overlayMode="none"` 时 POST `/web/host-input`。
  - `overlayMode="view"` / `ax` 时不 POST，保留节点选中。
  - host-input 失败时显示失败状态。
- 验证命令：
  - `cd Web && npm test`
  - `cd Web && npm run build`
  - `docs-linhay/scripts/check-docs.sh`
  - `git diff --check`

## 非目标

- 不在本期实现 pinch / rotate / 多指路径。
- 不新增 Web/Wails 正式业务控制入口。
- 不从截图像素推断焦点、可点击性或业务状态。
- 不新增裸 `adb`、`hdc`、`xcrun`、`baguette` 调用；Web 只消费/发送 Triton 既有 DTO 与 HTTP bridge。
- 不把 Android bridge `/gesture` 的 stroke 协议直接暴露到 Web UI；后续如需要多指手势，应先扩展 `TKInputRequest` / CLI schema。

## 待确认

- iOS host longPress 是否进入本期：当前 `/web/input` 明确 unsupported；如果要支持，需要先在 CLI/host adapter 补机器可读能力与测试，再开放 Web 交互。
- 输入模式是否需要显式 toggle：一期建议复用现有 overlay 模式，“无”表示设备输入面，“视图/AX”表示审查面，避免新增控件。

## 2026-07-06 落地记录

- 已新增 `Web/src/streamGestureModel.ts`：
  - 将 pointer client 坐标映射为当前 MJPEG 图像的设备坐标。
  - 点击 contain 留白时返回 `null`，不派发设备输入。
  - 短按生成 `tap`，拖拽超过阈值生成 `swipe`，长按在阈值到达时生成一次 `longPress` 并抑制 pointerup fallback tap。
  - 平台路由保持诚实：iOS `tap` / `swipe` 走 host，iOS `longPress` 走 runtime fallback，Android `tap` / `swipe` / `longPress` 走 host，Harmony `tap` / `swipe` / `longPress` 走 host。
- Harmony `longPress` 已补入 `/web/input` host 执行层：使用 `TKHarmonyHDCCommand.swipeCoordinate`，start/end 坐标相同，velocity 沿用现有 `harmonySwipeVelocity` 下限。
- `Web/src/components/StreamCard.tsx` 已接入 pointer 事件：
  - 仅在 overlay 为“无”且 stream connected 时启用设备输入。
  - `view` / `ax` overlay 仍保持节点 hover、选中和子节点命中，不发送 `/web/host-input`。
  - 输入成功后显示动作状态并刷新 hierarchy；失败时显示错误。
- 已新增 `Web/dev/streamGestureModel.test.mjs` 并纳入 `Web/package.json` 的 `npm test`。
- 验证通过：
  - `cd Web && node --test dev/streamGestureModel.test.mjs`
  - `cd Web && npm test`
  - `cd Web && npm run build`

### 真实 Harmony emulator smoke

- 日期：2026-07-06
- 目标：`Codex Test Phone` / `127.0.0.1:10100` / `harmony` emulator。
- Triton-first 事实：
  - `triton status --json` 返回 `server_unavailable`，确认 19421 初始未监听。
  - `triton device doctor --platform harmony --json` 通过，`hdc` 为 `/Users/linhey/harmonyOS-command-line-tools/bin/hdc`，版本 `3.2.0d`。
  - `triton device list --platform harmony --scope emulator --json` 初始为空；`device start --platform harmony --plan-only --json` 给出 Emulator 启动 ledger 与 `hdc tconn` follow-up。
- 启动与 readiness：
  - `triton device start --platform harmony --hvd 'Codex Test Phone' --path ~/.Huawei/Emulator/deployed --hdc-port 10100 --json` 成功，PID `52700`。
  - 首次 `device wait-ready --device 127.0.0.1:10100 --json` 返回 `target_not_found`；按 Triton 启动 ledger 执行 `hdc tconn 127.0.0.1:10100` 后，`device wait-ready` 返回 `ready=true`。
- 输入 smoke：
  - 启动 `triton serve --host 127.0.0.1 --port 19421`。
  - `POST /web/input?target=host:harmony:127.0.0.1:10100`，payload `{"type":"longPress","x":654,"y":1440,"width":1308,"height":2880,"duration":0.7}`。
  - 返回 `{"action":"longPress","message":"Harmony longPress was submitted through uitest same-point swipe hold.","ok":true}`。
- 证据：
  - before 截图：`screenshots/20260706-web-harmony-longpress-before-v01.jpeg`，`1308x2880`，sha256 `db2d35b4db987925aa49a924e244894fadfa89265305156ee62496e9c16144b9`。
  - after 截图：`screenshots/20260706-web-harmony-longpress-after-v01.jpeg`，`1308x2880`，sha256 `f5eacc26820b0afe9d501b43f25f4843e2c09f7a95e5d71684299da685aa9c74`。
  - after layout：`observe tree --platform harmony --device 127.0.0.1:10100 --json` 返回 `ok=true`、`primarySource=host-layout`、`nodeCount=93`。
- 清理：
  - `triton serve` 19421 监听已关闭。
  - `triton device stop --platform harmony --hvd 'Codex Test Phone' --path ~/.Huawei/Emulator/deployed --confirm --json` 首次失败在 launchd job 不存在；按错误提示改用 `--skip-launchd` 后 stop 成功。
  - stop 后 `device list --platform harmony --scope emulator --json` 显示 `127.0.0.1:10100` 为 `Offline`。

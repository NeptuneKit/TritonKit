# Triton Inspector Web

## 背景

TritonKit 的业务控制权威入口是 CLI / HTTP / Schema / Plan / Runtime。Web 端只作为 Triton Runtime 状态与执行证据的观察、解释和验证工作台，不定义业务控制能力。

当前 Web 已有 React / Vite mock 工程与 host bridge，可读取 target、screenshot、hierarchy、logs 和 command outputs。本期在现有 `Web/` 工程上收敛为单页 Inspect Session，不另起新工程。

## 目标

第一阶段先交付一条 Inspect / Evidence 闭环：

```text
Target
→ Screenshot
→ Hierarchy
→ Selected Node
→ Evidence
→ Trace / Logs
```

界面定位：

```text
Web = Triton Inspector = Inspector + Evidence Viewer
```

不是：

```text
Web = Agent Control Center
Web = CLI Dashboard
Web = 任意命令执行器
```

## 范围

本期只做一个页面：`Inspect Session`。

固定信息架构：

- Target Registry：展示可观察 target，支持选择目标。
- Screenshot Viewer：展示当前 target 画面。
- Hierarchy Viewer：展示 hierarchy tree / overlay，并支持选择 node。
- Node Inspector：展示 selected node 的 frame、class、AX、style、visual source 和 controller context。
- Evidence Console：展示 node evidence、command trace、runtime logs。

Settings 不属于 Inspect Session 证据流，必须是独立普通路由：

- `/settings`：Web 本地展示偏好。
- 不做 modal。
- 不放入右侧 Evidence / Trace / Logs tab。
- 不接入 CLI / HTTP 控制能力。

## Input Relay 扩展

用户明确要求模拟器预览区支持点击后，本 space 增补一个受限输入 slice：

```text
Preview click
→ normalized tap DTO
→ host bridge / runtime input endpoint
→ action result evidence
→ screenshot / hierarchy refresh
```

边界：

- Web 只采集预览区点击坐标，生成机器可读 `tap` DTO。
- Web 不直接调用 `xcrun`、`simctl`、设备 API 或任意 shell 命令。
- 只有 `canInput=true` 且非 `readonly` 的 target 才显示/启用点击下发。
- readonly demo、mock fallback、bridge unavailable 和 `canInput=false` target 仍保持只读。
- 点击失败必须进入 action evidence，不静默吞掉。
- 点击成功后刷新 screenshot，并尽量刷新 hierarchy / logs；刷新失败时保留 input result。

## 不做

本期只允许 click/tap input relay；仍不做以下能力：

- type / swipe / press / paste / long press / pinch。
- build / xcode build / test / smoke。
- replay / execute plan / run test。
- serve / web 生命周期管理。
- proxy / cert。
- simulator erase / clone / upgrade / pair / unpair / privacy / location / push / media。
- 任意 CLI 命令输入框。
- Health Dashboard / Capabilities Explorer / CLI 控制台。

允许使用 `status`、`doctor`、`capabilities`、`plan` 作为后台错误解释数据源，但不做成第一阶段主页面。

## BDD 场景

### 场景 1：Inspect Session 闭环

Given Web host bridge 返回至少一个 target
And target 暴露 screenshot、hierarchy、logs 和 command trace
When 用户打开 Triton Inspector
Then 页面直接显示 Inspect Session，而不是首页或 dashboard
And 左侧显示 target registry
And 中间显示 screenshot 与 hierarchy overlay
And 用户选择 hierarchy node 后，右侧显示 node inspector
And 底部显示 evidence、trace 和 logs
And 每块证据都能看到来源命令或来源 DTO。

### 场景 2：只读目标禁止状态改变

Given target 声明 `readonly=true` 或 `canInput=false`
When 用户查看 Inspect Session
Then 页面不展示 input relay、type、swipe、press、pinch、build、test、replay 等控制入口
And 点击 screenshot 只允许选择 hierarchy node，不允许发送设备输入。

### 场景 2.1：可输入 target 支持点击模拟器预览

Given target 声明 `canInput=true` 且 `readonly=false`
And target 暴露真实 screenshot
When 用户点击预览区内的 App 按钮
Then Web 发送 `tap` DTO 到 host bridge / runtime input endpoint
And DTO 包含 target、platform、x/y 坐标与截图宽高
And 成功或失败结果显示在 evidence 中
And Web 刷新 screenshot / hierarchy，不直接修改业务状态。

### 场景 3：证据不足时诚实降级

Given target 未返回 screenshot 或 hierarchy
When Web 渲染 Inspect Session
Then 对应面板显示缺失原因、来源命令和 next command
And 不从 screenshot 像素或 mock 名称推断 App、route、controller 或业务状态。

### 场景 3.1：真机 runtime 不得 fallback 到模拟器

Given 用户选择 `ios-real:*` 真机 target
And `triton list --json` 只返回 iOS Simulator runtime target
When Web 请求 screenshot、hierarchy 或 input runtime evidence
Then bridge 必须返回明确的 real-device runtime mismatch 错误
And 不得使用任何 `triton:ios-simulator:*` runtime target 替代真机画面或层级。

### 场景 4：Settings 是独立路由

Given 用户正在 Inspect Session 查看 target evidence
When 用户点击 toolbar 的设置入口
Then 页面导航到 `/settings`
And Settings 以普通页面展示，不是 modal
And Inspector 右侧 tab 只保留 Evidence、Trace、Logs
And 修改语言偏好只写本地浏览器偏好，不改变 target、CLI 或 HTTP 状态。

## 验收标准

- `Target → Screenshot → Hierarchy → Selected Node → Evidence → Trace / Logs` 可在 Web 上贯通。
- 对 `canInput=true` 且非 readonly 的真实 target，点击预览区会发送 `tap` DTO 并展示 action evidence；对 readonly 或不可输入 target，点击仍只做 node selection。
- command trace 至少展示 host target、screenshot、hierarchy、logs 的来源命令结果。
- node inspector 至少展示 node id、type、frame、visibility、interaction、visual evidence sources。
- Settings 使用 `/settings` 独立路由，并可返回 Inspect Session。
- 失败态显示机器可读错误或 bridge 错误摘要。
- `npm run test` 与 `npm run build` 通过。

## 本地只读验收入口

真实 host bridge 没有运行中 target 时，可使用现有 mock 数据进入显式只读 demo：

```text
http://127.0.0.1:34127/?__tritonkit_inspector_demo=1
```

该入口只加载 fixture，不调用 `/web/host-input`，默认进入 view-tree 并选中 root node；若 URL 带合法 `target/panel/node`，则保留深链选择，用于验证：

```text
Target
→ Screenshot Viewer
→ Hierarchy Viewer
→ Selected Node Evidence
→ Trace
→ Logs
```

该入口不得替代真实 host bridge 契约测试。

## 技术选择

- 复用 `Web/` React / TypeScript / Vite 工程。
- 引入 Ant Design 作为 Web mock 的主 UI 组件系统，按官方「自然、确定性、意义感、生长性」价值观收敛页面结构、控件状态与信息层级。
- P0 使用 AntD `ConfigProvider` / `Layout` / `Button` / `Input` / `Card` / `Tabs` / `Tree` / `Descriptions` / `Tag` 替换页面 chrome、导航、列表、面板与证据详情；设备截图画布和命中叠层保留自定义 DOM/SVG overlay。
- Web 通过 adapter 消费 host bridge / CLI JSON，UI 不直接依赖裸 CLI 参数语义。

## 2026-06-21 AntD 重构补充

本轮将 `Web/src/App.tsx` 拆分为状态编排入口与展示组件：

- `Web/src/App.tsx`：保留 host bridge、路由、target/hierarchy/screenshot/logs 状态编排。
- `Web/src/components/InspectorWorkspace.tsx`：承载 toolbar、target navigator、device canvas、inspector、settings、trace/log 面板等展示组件。
- `Web/src/components/inspectorWorkspaceModel.ts`：承载层级树、节点命中、controller badge、本地化和展示格式化 helper。

AntD 替换范围：

- 全局：`ConfigProvider` + AntD reset CSS。
- 主题：启用 AntD dark algorithm，并用 Triton 深色 token 统一 `Layout`、`Card`、`Tabs`、`Tree`、`Descriptions` 等组件背景、边框和文字层级。
- 页面框架：`Layout`。
- 工具按钮与搜索：`Button`、`Input`。
- 侧边与右侧工作区：`Card`、`Tabs`、`Tree`。
- 证据与状态表达：`Descriptions`、`Tag`。

保留自定义实现的范围：

- 设备截图画布、真实截图、节点高亮叠层和坐标命中。
- 现有只读 host bridge 数据流、URL 深链、证据/日志读取，不新增业务控制入口。

视觉回归证据：

- `screenshots/20260622-web-antd-dark-polish-before-01.png`：AntD 默认浅色组件嵌入深色壳导致白底与黑字割裂。
- `screenshots/20260622-web-antd-dark-polish-after-01.png`：统一深色主题后的真实 host 空态浏览器复核截图。
- `screenshots/20260622-web-antd-dark-polish-demo-after-01.png`：只读 demo populated 态浏览器复核截图，用于确认 target、hierarchy、device canvas、evidence 和 details 同时存在时的视觉层级。
- `screenshots/20260622-web-simulator-preview-after-01.png`：真实 host simulator screenshot 恢复渲染后的浏览器复核截图。
- `screenshots/20260622-web-input-relay-tap-after-01.png`：真实 host simulator 预览区 click/tap input relay 成功后的浏览器复核截图，右侧 evidence 显示 host-HID adapter 成功结果。
- `screenshots/20260622-web-ios-real-runtime-mismatch-after-01.json`：真机 runtime target mismatch 修复后的页面状态证据；Web 不再用 simulator runtime 截图冒充真机画面。

真实截图 frame 约束：

- `.device-frame.has-real-frame.orientation-portrait` 不得再使用 `calc(100% - ...)` 作为主高度来源；在 grid stage 中该百分比高度可能折叠为 `0px`。
- portrait 真实截图优先使用 `100dvh` viewport-based 高度回退，并通过 DOM/CSS 合同测试锁定。

点击输入约束：

- 仅实时模式下对 `canInput=true` 且非 readonly 的真实 target 启用短按 tap。
- `DeviceCanvas` 只发送 `{ type: "tap", x, y, width, height }`，不发送长按、捏合、键盘输入或任意命令。
- tap 成功/失败必须写入 inspector `最近动作` 和日志 evidence；成功后刷新 screenshot，并在需要时刷新 hierarchy。

## 2026-06-22 iOS 真机 runtime 联调记录

当前 URL target：`ios-real:7a9d976cc4d4`；当前业务 App：`/Users/linhey/Desktop/FlowUp-Libs/Overloaded-v2/iOS/Overloaded`。

已确认事实：

- Triton host 可以发现真机 target：`triton device list --platform ios --scope real --json` 返回 `ios-real:7a9d976cc4d4` ready。
- Web target resolver 修复后，真机页面不会再 fallback 到 simulator runtime；当只有 `triton:ios-simulator:1B360513-22E7-46DB-A942-198EE522C6DC` 时，`/web/host-screenshot` 返回 `app_runtime_unavailable`。
- 真机 runtime 需要两个条件同时成立：
  - `triton serve --host 0.0.0.0 --port 19421`，否则手机访问不到 Mac 上的 runtime server。
  - Debug App 启动时 `TRITON_HOST` / `TritonKitDefaultHost` 指向当前 Mac 可达局域网 IP；该 IP 会随网络切换变化，本轮最终可达 IP 为 `192.168.228.128`。

本轮联调改动：

- Web dev bridge 管理的 `triton serve` 默认改为绑定 `0.0.0.0`，避免自动拉起 localhost-only server 导致真机 runtime 永远连不上。
- Web runtime 未连接提示改为 `triton serve --host 0.0.0.0 --port 19421` + 真机 Debug App 设置 `TRITON_HOST=<Mac 局域网 IP>`。
- Overloaded Debug build setting 临时配置为当前可达 Mac IP：`TRITONKIT_DEFAULT_HOST = 192.168.228.128`；Release 未改。

联通结果：

- 初次 devicectl 启动失败是设备锁屏；用户解锁后，`devicectl device process launch` 成功启动 `overloaded.cn.debug`。
- 旧 IP `192.168.10.179` 已失效；当前 Mac 可达 IP 为 `192.168.228.128`，并通过 `curl http://192.168.228.128:19421/status` 证明可达。
- 使用 `TRITON_HOST=192.168.228.128 TRITON_PORT=19421` 重新启动 App 后，`triton list --json` 出现无 `simulatorUDID` 的 `triton:connection:2`，代表真机 runtime 已连入。
- `/web/host-screenshot?...target=ios-real%3A7a9d976cc4d4...` 返回 200，截图来自 `triton screenshot --target triton:connection:2`，尺寸 `428x926`。
- `/web/host-hierarchy?...target=ios-real%3A7a9d976cc4d4...` 返回 200，root 为 `ios:runtime:2`，节点数 118。
- 重新构建 Overloaded 真机包时，Xcode 卡在 SwiftPM package graph；一次失败证据为 Sentry 9.18.0 binary artifact cache `already exists in file system`，已将冲突 artifact 移到 `~/Library/Caches/org.swift.swiftpm/artifacts-backup-20260622023313/`。

后续恢复步骤：

1. 保持 Triton server 监听全接口：`triton serve --host 0.0.0.0 --port 19421`。
2. 每次联调先重新识别当前 Mac 可达 IP，并用 `curl http://<ip>:19421/status` 证明不是旧 IP。
3. 解锁真机并保持亮屏。
4. 优先重试已安装 App 启动注入：

   ```bash
   xcrun devicectl device process launch \
     --device 2D15538C-B3D8-52B2-A680-7B00F3D704AC \
     --terminate-existing \
     --environment-variables '{"TRITON_HOST":"192.168.228.128","TRITON_PORT":"19421"}' \
     overloaded.cn.debug
   ```

5. 期望 `triton list --json` 出现无 `simulatorUDID` 的 iOS runtime target；随后 Web `ios-real:7a9d976cc4d4` 页面才能渲染真实 App 画面。

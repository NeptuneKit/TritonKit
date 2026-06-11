# 20260611 Web Mock UI

## 背景

TritonKit 当前以 CLI / HTTP 机器可读控制为事实入口。用户希望先设计一个 Web 端界面 mock，并且 Web 端需要使用主流前端架构实现，便于后续从静态概念过渡到可维护的工程。

本 space 只定义 Web mock 的信息架构、视觉方向和验收方式，不改变 CLI / HTTP 的业务控制边界。

## 目标

- 新建可运行、可追踪的 Web mock 工程。
- 使用主流前端架构：React、TypeScript、Vite。
- 按 TritonKit 固定端口约束配置 Vite dev server `127.0.0.1:34127` 与 preview server `127.0.0.1:34128`，并开启 `strictPort`。
- 首屏直接呈现可用的三端模拟器控制台，不做 landing page。
- 页面以本机 iOS Simulator、Android Emulator、Harmony / DevEco Emulator 控制为核心。
- 保持 Web 只消费 mock DTO，不定义 create / update / delete / execute 等业务控制事实入口。

## 范围

- 新建 `Web/` React / TypeScript / Vite mock 应用。
- 提供模拟设备列表、设备镜像、状态指标、输入动作、网络事件、日志和检查器面板。
- 采用组件化目录结构，便于后续替换为真实 `/web/targets`、`/web/screenshot`、`/web/geometry`、`/web/input`、`device proxy` 等 API。
- 仅做 mock 数据与前端交互，不接真实后端。

## 不在本期范围

- 不恢复 Wails 桌面壳。
- 不新增真实业务控制 HTTP API。
- 不接真实 streaming、SSE、WebSocket、代理抓包或设备输入。
- 不处理登录、权限、多用户、远端 agent、设备云。

## BDD 场景

### 场景：打开 Web mock 控制台

- Given 开发服务运行在 `127.0.0.1:34127`
- When 浏览器打开 `/`
- Then 首屏直接展示 TritonKit 本机模拟器控制台
- And 页面展示三端目标、当前选中设备镜像和状态

### 场景：切换三端目标

- Given 页面展示 iOS、Android、Harmony 三个 mock target
- When 用户点击任一 target
- Then 镜像面板、指标、动作、网络事件和日志切换到对应 target

### 场景：观察设备运行态

- Given 一个 target 被选中
- When 用户查看主区域
- Then 页面展示平台、运行状态、framebuffer 尺寸、App 标识、proxy 状态、最近动作和网络事件

### 场景：保持工程可验证

- Given Web mock 工程已创建
- When 执行 `npm run build`
- Then TypeScript 与 Vite production build 通过

## 验收标准

- `Web/` 工程可通过 `npm install` 安装依赖。
- `npm run build` 通过。
- `npm run dev -- --host 127.0.0.1` 可在 `127.0.0.1:34127` 启动。
- 浏览器检查首屏非空，关键文案和 mock 数据可见。
- 页面视觉是操作台，不是营销页。

## 实现记录

- Web 工程位置：`Web/`。
- 架构：React 19 + TypeScript + Vite 7 + lucide-react。
- Dev server：`127.0.0.1:34127`，`strictPort=true`。
- Preview server：`127.0.0.1:34128`，`strictPort=true`。
- 入口：`Web/src/main.tsx`。
- 页面状态与组件：`Web/src/App.tsx`。
- Mock DTO：`Web/src/data/mockData.ts`。
- 样式：`Web/src/styles.css`。

## 验证记录

- `npm install` 通过，0 vulnerabilities。
- `npm run build` 通过。
- 浏览器打开 `http://127.0.0.1:34127/`，页面 title 为 `TritonKit Web Console Mock`。
- Console error 为 0；仅有 Vite dev client 与 React DevTools 提示。
- 1200px 视口检查无横向溢出：`document.documentElement.scrollWidth === window.innerWidth`。
- 目标切换验证：
  - iOS 默认显示 `丁香园`、`cn.dxy.iDxyer`、`1206 x 2622`。
  - Android 切换后显示 `Overloaded`、`sdk_gphone64_arm64`、`Mock lane armed`。
  - Harmony 切换后显示 `Triton Smoke`、`Pura X Emulator`、`Proxy unavailable`。
- 验收截图：`docs-linhay/spaces/20260611-web-mock-ui/screenshots/20260611/20260611-web-mock-dashboard-after-v01.png`。

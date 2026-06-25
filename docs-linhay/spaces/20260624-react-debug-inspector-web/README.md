# React Debug Inspector Web

## 背景

Web dev server `http://127.0.0.1:34127/` 已能渲染 Triton Inspector，但开发态缺少 React 组件点击定位源码能力。该能力只属于本地开发辅助，不改变 CLI / HTTP / Web 业务控制边界。

## 目标

- 在 `Web/` Vite dev server 中启用 React inspector 开发插件。
- 保持现有 Triton Inspector 页面、host bridge、端口与 preview 行为不变。

## 范围

- 只接入 `@linhey/react-debug-inspector` 到 `Web/src/main.tsx` / `Web/vite.config.ts`。
- Vite 插件负责注入 `data-debug`，`initInspector()` 负责右下角 🎯 按钮和浏览器端交互。
- 只作为 dev server 辅助能力；不新增业务 UI、不新增后端控制入口。

## 不做

- 不自研 inspector overlay。
- 不把 inspector 能力接入生产 build 或 Triton 控制 API。
- 不新增 Web/Wails 产品面。

## BDD 场景

### 场景 1：开发态打开 React inspector

Given 开发者启动 `Web/` Vite dev server
When 打开 `http://127.0.0.1:34127/?target=<host-target>`
Then Triton Inspector 页面仍正常渲染
And 右下角显示 React Debug Inspector 的 🎯 快捷按钮
And React inspector dev overlay 可通过快捷按钮响应组件定位操作。

### 场景 2：生产构建不受影响

Given Web 执行生产构建
When 运行 `npm run build`
Then TypeScript 与 Vite build 通过
And 不要求运行时提供 React inspector overlay。

## 验收方式

cd Web
npm run build

浏览器验证：

- 打开用户给定 URL。
- 页面 title 为 `Triton Inspector`。
- 右侧 Triton Inspector 面板可见。
- console 无 error。

注意：`vite.config.ts` 插件变更需要重启 `npm run dev` 后才会被当前 dev server 加载。

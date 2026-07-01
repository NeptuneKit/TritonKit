# Space: 20260630-web-card-render

## 背景与目标

本 Space 对应 TritonKit Web 前端**第一期：界面卡片渲染**阶段。

在前序 `20260630-web-redesign` Space 完成了整体方向设计（2×5 等大卡片矩阵、暗黑玻璃态、antd 组件体系选型）之后，本期聚焦于将 10 个功能卡片完整独立化（每张卡片一个 React 组件文件），并以静态 Mock 数据完成**界面渲染闭环**，为下一期真实后台数据对接打好地基。

## 范围（Scope）

- **包含**：
  - 10 个卡片组件的独立 `.tsx` 文件拆分（`TargetCard`、`SimulatorCard`、`HdcCard`、`XcodeCard`、`InspectorCard`、`StreamCard`、`TimelineCard`、`VlmCard`、`RecorderCard`、`DoctorCard`）
  - 全局 `ConfigProvider + theme.darkAlgorithm` 暗黑主题
  - Vanilla CSS 设计系统（`styles.css`）：网格、卡片边框发光、毛玻璃、间距
  - `App.tsx` 仅作为组装容器，不含业务逻辑

- **不包含**（留给下一期）：
  - 真实后台 HTTP/WebSocket 数据对接
  - 用户交互的持久化状态
  - 路由与多页面

## 技术栈

| 层级 | 选型 |
|---|---|
| 框架 | React 19 + Vite 7 |
| UI 组件库 | Ant Design v6（antd）|
| 样式 | Vanilla CSS（禁止 Tailwind）|
| 端口 | `127.0.0.1:34127`（strictPort）|
| 工作树 | `../TritonKit-worktrees/20260630-web-redesign/` |

## 验收标准（DoD）

1. **渲染完整性**：10 张卡片全部正确渲染于 2×5 网格，卡片等宽等高，无溢出、无错位
2. **主题一致性**：全局 antd 暗黑算法生效，所有 Card / Button / Tag 颜色来自 antd 调色板
3. **组件独立性**：每张卡片为独立 `.tsx` 文件，互不耦合，`App.tsx` 仅做组装
4. **编译通过**：`npm run build` 零错误
5. **Vite dev 可访问**：`npm run dev` 成功运行在 `127.0.0.1:34127`
6. **卡片微交互**：SimulatorCard 开关机、RecorderCard 录制状态切换、VlmCard loading 状态均可正常触发

## 相关链接

- 父级 Space: [20260630-web-redesign](../20260630-web-redesign/README.md)
- 工作树: `../TritonKit-worktrees/20260630-web-redesign/Web/src/components/`

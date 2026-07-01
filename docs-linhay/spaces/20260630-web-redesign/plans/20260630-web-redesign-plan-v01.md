# Web Redesign Plan v01

## 设计判断

草图给出的方向足够明确：第一屏仍是单手机实时画面，不是三栏常驻工作台。左右信息区是从边缘展开的辅助面板，默认让设备画面占满注意力。

## 信息架构

```text
Top bar
  target / mode / connection / snapshot time

Main workspace
  Center stage (default)
    Live / snapshot phone frame
    screen overlays
    zoom / fit / refresh

  Left drawer (expanded on demand)
    View tree
    Run actions

  Right drawer (expanded on demand)
    Properties
    Logs
    Network
```

## 视觉方案

- 整体采用高对比工具台：浅背景、清晰分割线、低装饰。
- 手机画面是第一屏唯一主体，左右面板默认收起。
- 左右展开入口可以采用草图外露标签感；展开内容用 Ant Design Tabs/Segmented/Drawer，避免自绘复杂控件。
- 展开面板应覆盖或压缩少量边缘空间，不能把手机画面挤到不可读。
- 按钮优先用图标 + tooltip，文本只用于主要动作和状态。
- 不使用营销式 hero、渐变球、装饰卡片。

## 实施切片

1. 设计稿切片
   - 建同一个 `web-redesign-v01.html`，收敛多草图对比。
   - 覆盖 default、left-expanded、right-expanded、1200px、narrow 五种状态。

2. 数据切片
   - 复用现有 mock target / screenshot / hierarchy / logs 数据。
   - 补最少 mock DTO 支撑属性、日志、网络三个 tab。

3. 页面替换切片
   - 替换 `Web/src/App.tsx` 顶层布局。
   - 保留 Vite、AntD reset、端口和既有测试入口。
   - 删除旧页面里与新 IA 冲突的视觉结构。

4. 验证切片
   - 先跑 `npm run test` 和 `npm run build`。
   - 再用浏览器打开 `127.0.0.1:34127` 截图。
   - 截图归档到本 space。

## 测试计划

- 增加或更新最小 DOM contract 测试：
  - 默认页面出现 `实时/快照`，但不常驻显示 `视图树`、`属性`、`日志`、`网络`内容区。
  - 展开左侧后出现 `视图树`、`运行动作`。
  - 展开右侧后出现 `属性`、`日志`、`网络`。
  - 1200px 布局没有水平溢出的 CSS contract。
  - 未支持的动作显示 disabled 或 contract missing。

## 风险

- 运行动作容易越界成 Web 控制台；实现时必须由 CLI / HTTP contract 决定 enabled 状态。
- 如果旧 `App.tsx` 已承载 host bridge 状态，不能先删掉事实源，只删旧视觉组织。
- 若草图继续变化，不拆 option HTML；统一追加到同一个设计稿。

## 暂不做

- 不做新后端接口。
- 不做 Web 写操作闭环。
- 不做多主题和个性化布局保存。
- 不做复杂设计系统抽象。

# 2026-06-21 Implementation Plan

## 第一刀

收敛当前 Web mock 为只读 `Inspect Session`：

```text
Target Registry | Screenshot + Hierarchy | Node Inspector | Evidence + Trace + Logs
```

## 步骤

1. 文档先行：创建 space、BDD 场景和设计边界。
2. 测试先行：增加 DOM 测试，证明：
   - 首屏是 Inspect Session。
   - 选择 node 后展示 node inspector 和 evidence。
   - 页面没有 input relay / tap / type / swipe / build / test / replay 控制入口。
3. 最小实现：
   - 将 toolbar 标题与主容器命名收敛为 Triton Inspector / Inspect Session。
   - 默认保留 Target Registry、Screenshot、Hierarchy、Inspector、Evidence / Trace / Logs。
   - 移除或隐藏 P0 表层的 input relay 与手势控制入口。
   - 将 command outputs 明确展示为 Trace。
   - 增加 `?__tritonkit_inspector_demo=1` 显式只读 fixture 入口，用现有 mock 数据验证完整闭环，不作为业务控制入口。
   - 将 Settings 从右侧证据 tab 移出，改为 `/settings` 独立普通页面，toolbar 设置入口负责跳转。
   - 按 Ant Design 规范引入 `ConfigProvider` / `Layout` / `Button` / `Input` / `Card` / `Tabs` / `Tree` / `Descriptions` / `Tag`，优先替换 page chrome、导航、面板、树和证据详情组件。
   - 拆分 `Web/src/App.tsx`，将展示组件下沉到 `Web/src/components/InspectorWorkspace.tsx`，`App.tsx` 保留状态编排与 host bridge 数据流。
4. 验证：
   - `npm run test`
   - `npm run build`
   - 浏览器打开 `http://127.0.0.1:34127/?__tritonkit_inspector_demo=1`，检查 Target / Screenshot / Hierarchy / Selected Node Evidence / Trace / Logs。
   - `git diff --check`
   - `docs-linhay/scripts/check-docs.sh`

## 非目标

- 不新增状态改变接口。
- 不新增 CLI 控制台。
- 不新增 Health Dashboard。
- 不恢复 Web/Wails 业务控制入口；AntD 仅作为 Web mock 展示组件系统。

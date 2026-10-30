# TritonKit 设计目录

采用规则见 [DESIGN_SYSTEM](../DESIGN_SYSTEM.md)，执行流程见 [Rhine workflow](../docs-linhay/dev/rhine-design-workflow.md)，初次接入见 [SP-245](../docs-linhay/spaces/SP-245-rhine-design-adoption/README.md)，其余 Web 页面接入见 [SP-246](../docs-linhay/spaces/SP-246-rhine-web-migration/README.md)，四页设计偏好结果见 [SP-247](../docs-linhay/spaces/SP-247-rhine-page-preferences/README.md)（已同步主目录并复验）。

## 运行入口

先使用包支持的 Node 24（本机 `PATH=/opt/homebrew/opt/node@24/bin:$PATH`），再执行：

```sh
npm --prefix Web ci
npm --prefix Web run design:dev
# http://127.0.0.1:34127/
```

独立构建与预览：

```sh
npm --prefix Web run design:build
npm --prefix Web run design:preview
# http://127.0.0.1:34128/#scene=run-atlas&theme=arknights&width=880
```

设计 dev 与普通 Web dev 共用固定 34127；设计 preview 与普通 preview 共用固定 34128，均 strictPort。先停止自己启动的同端口进程；不抢占其他会话。预览是本地进程，不是线上持久在线部署。

配置：[Web/design/vite.config.ts](../Web/design/vite.config.ts)。官方 `/review/vite` 生成壳与画布，产物 `Web/dist-review/` 与正式 `Web/dist/` 分离。官方壳的目录、主题、尺寸、CSS zoom、动态偏好、URL/hash、重置和隔离协议不由产品重复实现。开发模式按官方契约手动刷新，不提供 HMR。

## 页面与角色

| 场景 | 实际组件 / 入口 | 角色与状态 | 交互和验收 |
| --- | --- | --- | --- |
| `run-atlas` | [RunWorkbenchView](../Web/src/components/RunWorkbenchView.tsx)，由 [RunWorkbenchCard](../Web/src/components/RunWorkbenchCard.tsx) 接回 | 唯一角色 reader；ready / failed / empty / loading / error / long | SP-247：当前运行、Atlas 路径、建议命令；goal/身份/异常常显，低频详情折叠、路径无框列表；全部命令只复制，错误/加载保留旧数据 |
| `device-preview` | [StreamPanel](../Web/src/components/StreamPanel.tsx)，由 [StreamCard](../Web/src/components/StreamCard.tsx) 接回；SP-247 组合已接回 | reader；iOS / Android / Harmony；ready / empty / image-error / long | SP-247 合并标题/窗格操作，FPS 收入预览设置 Popover；保留目标、连接意图、隐藏释放/恢复与只读画布选择 |
| `hierarchy-inspector` | [InspectorPanel](../Web/src/components/InspectorPanel.tsx)，由 [InspectorCard](../Web/src/components/InspectorCard.tsx) 接回；SP-247 组合已接回 | reader；三平台；ready / empty / loading / error / long / deep / copy-error | SP-247 关联/来源帮助渐进展示、树嵌套与焦点恢复、属性 Dialog 随内容增高；保留所有来源/草稿/复制，仍只供 CLI 显式应用 |
| `workspace` | [WorkspaceCanvas](../Web/src/components/WorkspaceCanvas.tsx) / [WorkspaceShell](../Web/src/components/WorkspaceShell.tsx)，由 AppCanvas/App 接回；SP-247 组合已接回 | reader；三平台；ready / empty / long | SP-247 将窗格 Menu 注入各页面标题，外层 Surface 唯一边界；保留卡片/分割/拖动/键盘/关闭/恢复和双向选择 |

[目录协议](../Web/design/catalog.tsx) 仅登记场景，权限和业务路由不由目录决定。[Run fixtures](../Web/design/fixtures.ts) 与[三平台 fixtures](../Web/design/syntheticData.ts) 仅合成 DTO，不读取真实设备、环境或会话。[SyntheticContext](../Web/design/SyntheticContext.tsx) 复用实际 reducer；层级刷新仅内存、支持延迟/失败，卸载清理计时器，合成图像使用可撤销的 Blob URL。复制在设计环境为显式内存反馈，正式组件依真实 Clipboard Promise 显示成功或失败。产品现有工作台仍沿用原 mock DTO，未新增服务端 Run/Atlas 读取链路；设计稿通过不代表真实 Run 后端已接入。

页面接回的范围与剩余缺口见 [迁移矩阵](../DESIGN_SYSTEM.md#页面迁移范围)。设计与业务复用组件 CSS；没有独立页面副本。正式配置使用官方 production guard 拒绝 review 与 `Web/design` 模块，正负例由 `npm --prefix Web run test:design` 验证。

## 验证范围

SP-245 首个工作台的完整结果保留在[历史验收记录](../docs-linhay/spaces/SP-245-rhine-design-adoption/plans/20261030-validation.md)。SP-246 历史[浏览器布局矩阵](../docs-linhay/spaces/SP-246-rhine-web-migration/plans/20261030-browser-matrix.json)覆盖三新增场景 × 400/520/880 宽度 × 100%/200% CSS zoom × 三主题，共 54 个长文本组合，无横向溢出。三平台状态、跟随/固定、双向选择、键盘、Dialog 主题/Escape/焦点、复制失败、隐藏释放/恢复已通过浏览器检查。

树高亮已观察真实播放（约 33ms → 183ms）和 1 秒后清理；系统减少动态通过。手动减少动态通过；Web全套125/125与生产构建通过。没有声明 full/paused：CSS 暂停不等于高亮寿命计时器同步暂停。CSS zoom 200% 不等于浏览器原生缩放；本轮未执行浏览器原生 zoom、真实设备、UIKit 或 Wails 验收。合成画面与内存刷新只证明设计场景，不能描述成真实后端已验收。

语义树缺口与消费端证据已提交 [#117](https://github.com/linhay/rhine-design/issues/117) / [验证补充](https://github.com/linhay/rhine-design/issues/117#issuecomment-6515132468)；回读状态、完整交互证据与收口结果统一回到 [SP-246](../docs-linhay/spaces/SP-246-rhine-web-migration/README.md)。


SP-247 主目录142/142测试、生产/设计构建通过；72组布局与最终深层树36组复验，浮层、键盘、状态、动态及删除焦点通过。详见[验收报告](../docs-linhay/spaces/SP-247-rhine-page-preferences/plans/20261030-validation.md)。deep场景第二次刷新删除最深合成叶节点，用于焦点恢复反证。固定registry0.11.3不变；#117源码规范已接受但未npm发布，临时产品组合继续保留。

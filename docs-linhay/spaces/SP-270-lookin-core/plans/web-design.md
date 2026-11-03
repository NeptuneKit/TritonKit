> 历史过程记录：早期“待主控”步骤须结合后文真实 runtime 素材验收读取；当前精确整合/发布状态以 Space README 和 20261103-validation.md 为准。

# Web 分层检查设计与验证

日期：2026-11-03。候选基线：SP-270 / origin/main edffb45e。用户选择沿用现有界面，将 Lookin 核心能力内置。

## 设计边界

保留 InspectorPanel 的目标关联、视图/AX 来源树、选中节点和只读属性草稿。增加本地 2D/3D 模式；3D 与树共享 session selection，只操作相机和层间距，不调用设备输入。节点详情显示“仅此图层 / 包含子图层”两类证据；未采图或加载失败不画成成功截图。

自有 CSS 3D 画布用于运行时几何展示，符合现有 Web skill 的自定义 DOM 画布边界。控制使用固定 npm `@linhey/rhine-design@0.11.3` 的 Button、NumberField、Text、Stack、Inline、EmptyState；不增加依赖、不复制包私有样式、不重做页面壳。没有新增通用设计组件缺口。原树适配继续关联 Rhine #117。

## 单一评审入口

复用官方评审入口 `Web/design/catalog.tsx`；新增 `layer-inspector` 场景，源文件 `Web/design/LayerScene.tsx`。仍是同一生成式壳与画布，不另建产品 HTML。

URL：`http://127.0.0.1:34128/#scene=layer-inspector&theme=arknights&width=880&d.state=ready&d.platform=ios`。正常、无独立图像、空结果、长文本、深层树和三平台均为合成数据；不能作为 UIKit 真实截图验收。

## 素材契约

- `layerOwnContents` 或 `slice.mode=solo-screenshot-ref/solo-screenshot-inline`：独立图像，仅已有或 hydrate 到 dataUrl 后进入 3D 平面。
- `subtreeSnapshot` / `group-screenshot-ref/group-screenshot-inline` / 历史 `node-screenshot-ref`：完整子树证据，只在详情显示，不能充当独立层素材。
- 同 kind 的相同非空 ref/url 去重，防止桥接把 solo 二次当作 group。
- 隐藏祖先、非法几何与循环父子关系不进入画布；零尺寸结构节点自身不显示，但不阻断有效子层，任一明确 hidden/alpha/opacity=0 仍阻断后代。最多 200 层，超出数量可见，选中层优先保留。深度限制 64，避免无限投影空间。
- 缺图显示轮廓和数量；图片 onError 同样退回轮廓。实时数据切换后清理旧错误状态，target 切换重置相机。

## 输入与可访问性

- 拖动按实际 boundingClientRect 归一化，CSS 200% zoom 下同相对距离对应同相机变化。
- 明确 pointer capture、pointerId、cancel/lostcapture；大于 4px 才判定旋转，旋转结束不触发节点选择。
- 画布方向键旋转、Home 重置，不劫持 Tab；树继续承担完整键盘节点浏览。选中平面可键盘激活。
- 无惯性或自动动画，减少动态模式保持直接操作；布局不额外嵌套 Surface。

## TDD 和验证

- 先红：材质测试 2 个实际断言失败（solo 重复/误标、未 hydrate ref 被当可显示），旧 8 项通过。
- 先红：fake CLI/HTTP hydrate测试出现第三个重复 subtreeSnapshot，证明桥接缺口。
- 修复后：材质、分层模型/SSR、桥接组合 29 项通过；独立评审目录/产物 guard 3 项通过。后续新增双图证据测试另计，不能把重复运行数相加。
- 首次纯模型测试被默认 Vite 配置的缺少 triton binary 阻塞，没有进入断言；改为 configFile:false，避免纯模型测试启动无关桥接。第一次 design:build 的 TS 联合类型缺少 dataUrl 缩窄已修复，之后构建通过。
- 主控已完成独立设计的实际浏览器 ArrowRight 旋转、间距 24→28、树选 Synthetic title 后平面选中同步，并保存 [设计截图](../screenshots/20261103-lookin-layers-review-v01.png)。据此接回实际 InspectorPanel 的 2D树/3D分层模式。截图发现独立场景缺少树主体样式，已复用 inspectorPanel.css 修复；不复制样式。
- 接回模式入口的新增测试先以缺少“层级展示方式”断言失败；实现后通过。新增双图组件首次构建发现 Text 不支持 figcaption 标签，改为原生 figcaption 包公共 Text；此后设计与生产两套构建均通过。未新增包缺口或临时库适配。
- 主控补验实际指针拖动，相机从 (12,-25) 变为 (-7.24,-9.05)，Home 恢复；树选择 title 后 plane 同步，留有 [拖动截图](../screenshots/20261103-lookin-layers-review-v02.png)。
- 主控审查发现零尺寸结构父节点 visible=false 会错误屏蔽其可见子层。新增测试先红，修复后保留子层并继续过滤显式隐藏祖先；同测覆盖 layer.opacity=1 不得掩盖 view.alpha=0。最终分层模型/SSR、材质、Inspector、review、fake CLI/HTTP route 共 45 项通过。
- inline PNG 兼容补丁：两个新增测试先红，修复 solo 无默认材质和生成额外伪 group 的问题；材质/分层/route 34 项通过，生产与设计构建重新通过。已有 dataUrl 不触发 runtime data ref 请求，group 保持 CALayer.render 来源。
- 子代理实际浏览器检查：树为 grid，44px 行/折叠按钮、12px/24px 子层缩进、标题纵向 padding 8px，样式作用域有效。520/400px 画布、HTML CSS zoom=2、reduced motion 下分别得到 clientWidth=scrollWidth=518/398，无横向溢出；两张证据图完整解码。窄屏截图为 [400px/200%](../screenshots/20261103-lookin-layers-narrow-zoom-v01.png)。
- 880px 完整设计画布（含双图和全部关联树）见 [最新设计截图](../screenshots/20261103-lookin-layers-review-v06.png)。实际生产 preview 通过窗格菜单更换为界面层级，显示等待连接；无 target 时不展示 3D 切换，断连截图保留本地（其既有mock业务名的公开范围未确认，不纳入本次证据提交）。另在真实 InspectorPanel 合成 empty 场景点击 3D，aria-pressed=true，显示“无可显示的图层”，树仍独立显示无数据状态。
- 尚待主控：最终实际浏览器双向选择、窄屏 400/520/880、200% CSS zoom、三个主题、target 切换、加载失败与减少动态；真实 UIKit 素材由主控统一提供。完整 Web 测试需绑定同候选 CLI 二进制后运行。当前投影使用 scene 的轴对齐几何与深度，未宣称还原任意累积 CALayer transform3D。

## 浏览器操作清单

1. `layer-inspector` 正常场景：树选择 child-title，plane aria-pressed 同步；点击另一 plane，树选择同步；右下区域拖动只旋转。
2. 聚焦“旋转图层画布”，方向键改变 data-camera-x/y，Home 回到 12/-25；调整层间距，节点 transform 的 translateZ 变化。
3. 切 missing-images：全部仅轮廓，缺图数量可见；empty：明确空结果。deep：画布受控，页面不横向溢出。
4. 在 hierarchy-inspector 接回后切 2D/3D，节点详情仍可打开，两图标题和无图状态正确；切 target 后相机与图像错误状态不串。
5. 400/520/880、100%/200% CSS zoom、Rhine/Arknights/Neo-brutalism，键盘焦点和控制可达；无控制台错误。

## 真实 runtime 图像组件验收

输入为主控通过候选 CLI → HTTP 19422 → SDK → 现有 captureHostHierarchy 获得的 `.build/sp270-validation-host/live/hydrated.json`（2026-11-03T03:57:49Z，8 节点，6 solo + 6 group）。临时 `Web/design/sp270-live.tsx` 与 JSON 副本只在现有 review Vite 34127 动态导入，用正式 InspectorPanel、AppContext、session reducer、ThemeProvider 和只读快照 provider；验收后已卸载并删除两个临时文件，没有产品入口或正式组件改动。

这证明真实 runtime 快照可以被正式 Inspector 组件展示；provider 是验收 harness，不能称为未隔离的正式端到端运行。第二个 target 身份复用同一真实快照，仅测试组件身份重置，未宣称第二台设备采集。

- 6 个 solo 成功进入平面，2 个无图节点显示轮廓；所有 12 张真实 PNG 在浏览器 Image.decode 成功，尺寸与像素采样见 [图像验收数据](validation/20261103-web-runtime-images.json)。所有当时展示的 8 个 img 均 complete 且 naturalWidth>0。
- `ios:runtime:12` 的 509×509 solo 采样为纯红 `[255,0,0,255]`；group 同尺寸，左上为蓝 `[0,0,255,255]`，截图清晰显示蓝色子层与红色父层。[节点双图截图](../screenshots/20261103-lookin-runtime-node-evidence-v01.png)。
- 点击增加层间距两次：24→32；真实 pointer drag 将相机 (12,-25) 改为 (30.20,-13.80)。点 CALayer#13 平面后树 aria-selected=true；点父层树行后 CALayer#12 平面 aria-pressed=true。
- target A→B 后相机自动回到 (12,-25)。回 A，ArrowRight 改为 (12,-20)，Home 恢复 (12,-25)。[真实分层视图](../screenshots/20261103-lookin-runtime-layer-view-v02.png)、[树联动截图](../screenshots/20261103-lookin-runtime-layer-view-v01.png)。
- 完整 Web 测试显式绑定本候选 CLI：174/174 通过，退出码 0，日志 [web-full](validation/20261103-web-full.log)。本次仅临时验收 harness 和证据，无生产源码变化。

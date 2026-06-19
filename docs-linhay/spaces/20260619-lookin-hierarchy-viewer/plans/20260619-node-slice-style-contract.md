# 2026-06-19 Node Slice Style Contract

## 背景

当前 `TKHierarchyLayerNode` / Web `HierarchyLayerNode` 只包含层级、frame、depth、visible、interactive 和 color。Web 只能用 `type/name/frame` 猜测节点外观，所以独立节点切片无法像 LookInside 一样还原真实视图样式。

目标不是让 Web 发明样式，而是让 CLI / HTTP 输出机器可读的节点样式、图层、文本、截图切片和渲染提示，Web 只负责只读展示。

## 当前缺口

- 内容缺口：缺少节点真实显示文本、attributed text、placeholder、image name、SF Symbol / resource name、selected/highlighted/disabled/focused 状态。
- 视觉样式缺口：缺少 backgroundColor、tintColor、textColor、font、fontWeight、alignment、alpha、hidden、isOpaque、clipsToBounds / masksToBounds。
- 图层样式缺口：缺少 cornerRadius、borderColor、borderWidth、shadowColor、shadowOpacity、shadowRadius、shadowOffset、zPosition、anchorPoint、transform。
- 布局语义缺口：缺少 safe area、contentInset、scroll offset、content size、stack axis、spacing、distribution、alignment。
- 切片资产缺口：缺少 per-node snapshot / surface slice、截图裁剪 rect、asset URL / data URL、像素尺寸、scale、capture error。
- 平台语义缺口：iOS UIKit / CALayer、Android View / Compose / Material、Harmony ArkUI 的属性名不同，目前没有统一归一字段和 raw platform payload。
- 质量与来源缺口：缺少 capturedAt、styleVersion、styleConfidence、source command、capability flags，Web 无法判断哪些节点是完整还原、哪些只是 fallback。

## P1 DTO 设计

新增版本化字段，保持旧字段兼容：

```json
{
  "id": "question-0",
  "type": "UIButton",
  "name": "caseOption[0]",
  "frame": { "x": 24, "y": 132, "width": 342, "height": 58 },
  "depth": 5,
  "visible": true,
  "interactive": true,
  "style": {
    "display": "button",
    "text": "MobileCLIP-S0",
    "subtitle": "资源完整，可用",
    "state": ["enabled", "normal"],
    "backgroundColor": "#FFFFFF",
    "foregroundColor": "#0F172A",
    "tintColor": "#2563EB",
    "alpha": 1,
    "cornerRadius": 12,
    "borderColor": "#E2E8F0",
    "borderWidth": 1,
    "shadow": {
      "color": "#000000",
      "opacity": 0.08,
      "radius": 3,
      "offsetX": 0,
      "offsetY": 1
    },
    "font": {
      "family": ".SFUI",
      "size": 14,
      "weight": "semibold",
      "alignment": "left",
      "numberOfLines": 1
    },
    "layout": {
      "axis": "horizontal",
      "spacing": 8,
      "contentInsets": { "top": 8, "left": 12, "bottom": 8, "right": 12 }
    }
  },
  "slice": {
    "mode": "node-snapshot",
    "rect": { "x": 24, "y": 132, "width": 342, "height": 58 },
    "pixelWidth": 684,
    "pixelHeight": 116,
    "scale": 2,
    "dataUrl": "data:image/png;base64,...",
    "source": "runtime-node-snapshot",
    "available": true
  },
  "raw": {
    "platform": "ios",
    "className": "UIButton",
    "layerClassName": "CALayer",
    "objectIdentifier": "0x..."
  },
  "renderHints": {
    "preferredMode": "slice",
    "fallbackMode": "style",
    "quality": "exact"
  }
}
```

## 字段分层

- `style`：跨平台归一后的可绘制样式。Web / agent 读取这个字段，不需要理解 UIKit / Compose / ArkUI 全部细节。
- `slice`：真实节点截图资产。优先级高于 `style`，用于 LookInside 式独立节点切片精确还原。
- `raw`：平台原始属性，便于调试、回归和后续补齐归一字段。
- `renderHints`：告诉 Web 使用真实 slice、样式化绘制、线框 fallback 或隐藏结构层。

## 平台采集方案

### iOS

- 样式来源：UIKit view + CALayer 反射读取。
- 必采字段：className、accessibilityLabel、text/title/placeholder、backgroundColor、tintColor、alpha、hidden、isUserInteractionEnabled、frame、bounds、transform、clipsToBounds。
- CALayer 字段：cornerRadius、borderColor、borderWidth、shadowColor、shadowOpacity、shadowRadius、shadowOffset、zPosition、masksToBounds。
- 文本字段：UILabel.text / attributedText 摘要、UIButton title、UITextField placeholder/text、font family/size/weight/alignment、numberOfLines。
- 切片来源：优先 `drawHierarchy(in:afterScreenUpdates:)` 或 layer render 到 bitmap；对不可截图节点返回 `slice.available=false` 和 failure reason。
- 注意：Release no-op 边界不变，只在 Debug runtime capability 开启时采集。

### Android

- 样式来源：View hierarchy + UIAutomator bounds + 可选 app-side Debug runtime / Compose semantics。
- host-only 可得：className、text、contentDescription、resourceId、bounds、enabled/clickable/focused/selected/scrollable。
- 需要 app-side 扩展才能高质量采集：background drawable color/radius、textColor、textSize/typeface、elevation、translationZ、alpha、clipToOutline、Compose semantics / modifier 信息。
- 切片来源：host screenshot 按 bounds 裁剪作为 P1 fallback；app-side runtime 可提供 node render cache 时升级为 exact。

### Harmony

- 样式来源：uitest dumpLayout + ArkUI 属性扩展。
- host-only 可得：bounds、text、description、type、enabled/clickable/focused/selected 等基础语义。
- 需要 ArkUI Debug bridge 扩展：background、border、radius、font、opacity、shadow、layout direction、padding、scroll offset。
- 切片来源：host screenshot 按 bounds 裁剪作为 P1 fallback；ArkUI runtime 能力补齐后提供 exact node snapshot。

## Web 渲染优先级

1. `slice.available && slice.dataUrl`：直接贴真实节点切片。
2. `style` 存在：按 style 绘制 canvas texture。
3. `raw` / `type` fallback：按控件类型绘制近似切片。
4. 结构节点或缺少样式：只画淡描边，不画大面积实体块。

## BDD 场景

### 场景：节点有真实 slice

- Given `HierarchyLayerNode.slice.available=true`
- When Web 打开 `探测`
- Then 该节点 3D 切片使用 `slice.dataUrl`
- And 不再绘制猜测样式

### 场景：节点没有 slice 但有 style

- Given `slice.available=false` 且 `style.display=button`
- When Web 渲染该节点
- Then 切片按 `style` 绘制背景、圆角、文本、边框和透明度

### 场景：结构节点缺少样式

- Given 节点是 UIWindow / root view / DecorView / ArkUIRoot
- When Web 渲染层级
- Then 只显示淡描边和层级位置
- And 不出现覆盖整个画布的大截图或大色块

## 实施切片

1. Shared DTO：新增 `TKHierarchyNodeStyle`、`TKHierarchyNodeSlice`、`TKHierarchyNodeRawInfo`、`TKHierarchyNodeRenderHints`，挂到 `TKHierarchyLayerNode` 可选字段。
2. Web 类型：同步 `HierarchyLayerNode.style/slice/raw/renderHints`，渲染优先级改为 slice > style > type fallback > wireframe。
3. iOS P1：embedded runtime 输出 UIKit / CALayer 样式和 per-node snapshot，CLI scene passthrough。
4. Android P1：host screenshot crop + UIAutomator text/state/bounds 先产出 `slice` fallback；后续 app-side runtime 补 exact style。
5. Harmony P1：host screenshot crop + uitest layout 基础字段先产出 `slice` fallback；后续 ArkUI debug bridge 补 exact style。
6. Schema：`triton schema --command hierarchy --json` 暴露 `hierarchy-node-style`、`hierarchy-node-slice` capability 和字段契约。
7. 回归：三端 fixture 分别覆盖 slice、style、fallback 三条路径，Web DOM 测试覆盖不再显示主截图平面。

## 非目标

- 不在 Web 中反推截图像素样式。
- 不用静态 mock 名称伪造真实 App 样式。
- 不把 Web 变成采集控制入口；采集仍由 CLI / HTTP / runtime 输出机器可读事实。

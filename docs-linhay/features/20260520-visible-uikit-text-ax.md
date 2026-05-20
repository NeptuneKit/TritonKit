# 可见 UIKit 文本 AX 导出

## 背景

真实项目回归中，dxyer 登录后的“我的”页面截图能看到用户名、个人主页入口和“创作中心”等内容，但 `triton ax --json` 无法检索这些可见字符串。导出中能看到 `SectionUI.SKCollectionView`，但该节点没有展开出 cell 内的文本，导致 AI agent 只能依赖截图做人工判断。

对应 GitHub issue：[#4](https://github.com/NeptuneKit/TritonKit/issues/4)

## 验收场景

### 场景 1：collection view 内的可见 label 可被 AX 检索

给定页面使用 `UICollectionView` 或其自定义子类展示 cell 内容，且 cell 内存在可见 `UILabel`。

当执行：

```bash
triton ax --json
```

则导出的 AX JSON 必须包含该 label 的可见文本，例如 `创作中心`。

### 场景 2：scroll/collection 容器不再作为空叶子终止

给定页面存在 `UIScrollView`、`UICollectionView` 或 `UITableView` 这类容器。

当容器内存在可见、可读的子节点时，AX 导出应把这些子节点挂到容器的 `children` 下，便于 `triton ax` 文本输出、`--with-hierarchy` 映射和后续 `find/wait` 命令复用同一棵树。

### 场景 3：UIKit 文本兜底覆盖常见控件

给定控件没有完整的 accessibility label，但自身公开属性有可见文本。

则 AX 导出至少应从以下公开属性兜底：

- `UILabel.text` / `UILabel.attributedText`
- `UIButton.currentTitle` / `currentAttributedTitle`
- `UITextField.text` / `placeholder`
- `UITextView.text`
- `UISegmentedControl` 当前选中标题
- `UISlider`、`UIStepper`、`UISwitch` 当前值

## 非目标

1. 本次不引入 OCR。
2. 本次不新增 `triton text --visible` 或 `--expand-visible-cells` CLI 参数；先修复默认 `ax` 契约。
3. 本次不做跨 App / SpringBoard 级系统 AX。

## 测试策略

1. 新增 iOS-only UIKit 回归测试，构造深层 wrapper 下的 collection view label，验证 `buildAXWindowNode` 能导出 nested child 与可见文本。
2. 保持 macOS `swift test` 覆盖共享模型和 CLI 契约。
3. 使用 `swift build -c release --product triton` 确认 CLI 产物仍可构建。

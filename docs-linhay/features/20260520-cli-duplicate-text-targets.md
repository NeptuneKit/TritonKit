# CLI 同文案目标消歧

## 背景

真实页面可能同时出现多个相同文案，例如多个 `hello` 按钮或列表项。单纯执行 `triton tap "hello"` 无法表达要点击哪一个目标，agent 需要先枚举候选，再用稳定的机器参数指定目标。

## 验收场景

### 场景 1：列出同文案候选

- Given 当前页面有两个可点击目标的 label 都是 `hello`
- When 执行 `triton find "hello" --all`
- Then stdout 输出 JSON
- And JSON 包含 `matchCount=2`
- And `candidates` 按将要点击的优先级和屏幕位置给出 `index/frame/targetOID/source/strategy`

### 场景 2：按候选序号点击

- Given `triton find "hello" --all` 显示第 2 个候选是目标按钮
- When 执行 `triton tap "hello" --index 2`
- Then CLI 点击第 2 个候选
- And stdout 输出 `TKInputResult` JSON

### 场景 3：按区域点击

- Given 目标 `hello` 位于右侧区域
- When 执行 `triton tap "hello" --within 180,0,220,500`
- Then CLI 只在该区域内匹配候选并点击
- And 未命中区域时返回机器可读错误

### 场景 4：按点位点击同文案候选

- Given 目标 `hello` 的 frame 包含 window point `240,580`
- When 执行 `triton tap "hello" --at 240,580`
- Then CLI 只匹配包含该点位的候选并点击
- And `triton find "hello" --at 240,580` 返回同一个候选

## 兼容性

- `triton tap "hello"` 继续按现有优先级选择最佳候选，避免破坏已有脚本。
- `--within x,y,width,height` 继续表示区域过滤；只需要一个点位时优先使用 `--at x,y`。
- `--json` 继续作为兼容 alias；动作命令默认 JSON。

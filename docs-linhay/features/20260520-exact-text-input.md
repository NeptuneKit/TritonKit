# 精确文本输入命令

## 背景

真实 iOS 登录回归中，账号和密码输入曾依赖 Simulator pasteboard 与 macOS 键盘粘贴自动化。该路径在 TritonKit 控制面之外，且容易受键盘自动大写、自动纠错、焦点切换和敏感字段日志暴露影响。

对应 GitHub issue：[#3](https://github.com/NeptuneKit/TritonKit/issues/3)

## 验收场景

### 场景 1：向当前焦点输入框精确粘贴

给定 App 内已有 `UITextField` 或 `UITextView` 成为 first responder。

当执行：

```bash
triton paste "console" --json
```

则 runtime 通过公开 UIKit `UIKeyInput.insertText` 插入原始字符串，不依赖 `xcrun simctl pbcopy`、AppleScript 或宿主键盘事件，并返回机器可读 `TKInputResult`。

### 场景 2：敏感文本不在结果中回显

给定当前焦点是密码输入框。

当执行：

```bash
triton paste --secure "aa123654" --json
```

则 JSON 结果包含 `secure=true`、`redacted=true`、`insertedLength=8`，但不回显原始文本。

### 场景 3：坐标兜底先聚焦再输入或清空

给定调用方只知道输入框坐标。

当执行：

```bash
triton paste "console" --at 180,250 --json
triton clear --at 180,250 --json
```

则 runtime 先在当前 App window 内 hit-test 并聚焦命中的文本输入 responder，再执行插入或清空。

旧的 `--x 180 --y 250` 形式保持兼容。

### 场景 4：NDJSON input 支持新动作

给定 AI agent 使用批量输入动作。

当通过 `triton input --json` 发送以下动作：

```json
{"type":"paste","text":"console","secure":false}
{"type":"clear"}
```

则两类动作使用与 CLI 命令相同的 runtime 行为和结果结构。

## 非目标

1. 本次不接入 host-side HID 键盘事件。
2. 本次不修改系统剪贴板，也不依赖 Simulator pasteboard。
3. 本次不持久保存或审计敏感文本原文。

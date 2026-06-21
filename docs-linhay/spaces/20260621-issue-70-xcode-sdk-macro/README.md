# 20260621 Issue 70 Xcode SDK Macro

## 背景

线上 issue #70 反馈：`triton xcode build` 在 simulator destination 已经明确时仍默认向 `xcodebuild` 注入 `-sdk iphonesimulator`，导致包含 Swift macro / plugin 依赖的项目在解析 host-side macro target 时失败。

本需求只处理 TritonKit 的 Xcode workflow argv / invocation 解析，不引入 XcodeBuildMCP API，不扩展 Web/Wails 产品面。

## 目标

1. `triton xcode build/test/settings/run` 在当前命令没有显式 `--sdk`、且 simulator destination/UDID 已明确时，不再默认传递 `-sdk iphonesimulator`。
2. 当前命令显式传入 `--sdk` 时必须保留，保证用户的直接意图可预期。
3. 真实设备 selector 仍保持 `iphoneos` + `generic/platform=iOS` 的现有行为。
4. 通过 focused Swift 测试覆盖 argv 与 invocation resolver 行为。

## 非目标

1. 不新增 XcodeBuildMCP fallback。
2. 不改变 raw `xcodebuild` 输出解析、xcresult、coverage 或 evidence 能力。
3. 不做真实线上项目构建复现；本次修复用命令构造和 CLI resolver 测试锁定回归点。

## BDD 场景

### 场景一：明确 simulator destination 时省略默认 SDK

- Given agent 调用 `triton xcode build --destination "platform=iOS Simulator,id=SIM-1"`
- And 当前命令没有显式 `--sdk`
- When TritonKit 生成 `xcodebuild` argv
- Then argv 包含 `-destination platform=iOS Simulator,id=SIM-1`
- And argv 不包含 `-sdk iphonesimulator`

### 场景二：显式 SDK 不被吞掉

- Given agent 调用 `triton xcode build --destination "platform=iOS Simulator,id=SIM-1" --sdk iphonesimulator`
- When TritonKit 生成 `xcodebuild` argv
- Then argv 仍包含 `-sdk iphonesimulator`
- And argv 包含对应 simulator destination

### 场景三：真实设备 selector 维持 iphoneos 默认

- Given agent 调用 `triton xcode build --device ios-real:abc123`
- When TritonKit 解析 invocation
- Then SDK 仍解析为 `iphoneos`
- And destination 仍解析为 `generic/platform=iOS`

## 验收标准

1. 新增失败测试能复现旧行为：simulator destination 明确时旧实现仍返回 `iphonesimulator` 并注入 `-sdk`。
2. 修复后 focused tests 通过。
3. `git diff --check` 与 docs 结构检查通过，或明确记录缺失脚本/不可运行原因。
4. 本地创建 commit，不 push、不关闭 issue。


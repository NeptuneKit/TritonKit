# GitHub Issue #148：Xcode Simulator Destination Selector

> 状态：执行
>
> GitHub：[NeptuneKit/TritonKit#148](https://github.com/NeptuneKit/TritonKit/issues/148)
>
> Branch：`feat/20260720-issue-148-xcode-simulator-destination`
>
> Worktree：`../TritonKit-worktrees/20260720-issue-148-xcode-simulator-destination/`

## 背景

`triton xcode test --simulator <udid>` 的 summary 可保留正确 `simulatorUDID`，但 destination 解析会优先复用 workspace 旧 `defaultDestination`。当旧值错误地保存为 `platform=iOS Simulator,id=iPhone 17` 时，生成的 `xcodebuild` 命令无法匹配设备并以 70 退出。

## 范围

- 修正 destination 优先级：显式 `--destination` > real-device selector > simulator selector > workspace default destination。
- simulator UUID 与 `sim:<uuid>` 生成 `id=<uuid>`；名称 selector 生成 `name=<name>`。
- build/settings/test/run 共用同一解析函数，不只修 test glue。
- 更新测试、schema/help 描述、Xcode workflow 文档与 memory。

不在本期范围：更换 Xcode destination discovery、自动 boot Simulator、Web/Wails UI、真机 destination 扩展。

## BDD 场景

### 场景 1：显式 UDID 覆盖旧 destination

- Given workspace defaults 含 `platform=iOS Simulator,id=iPhone 17`
- When 用户传入 `--simulator <uuid>`
- Then resolved destination 为 `platform=iOS Simulator,id=<uuid>`
- And summary `simulatorUDID` 与 sourceCommand 使用同一 UUID

### 场景 2：名称 selector 使用 name key

- Given 用户传入 `--simulator "iPhone 17"`
- When Triton 合成 destination
- Then destination 为 `platform=iOS Simulator,name=iPhone 17`
- And 不生成 `id=iPhone 17`

### 场景 3：显式 destination 保持最高优先级

- Given 同时存在 workspace default 与 simulator selector
- When 用户显式传入 `--destination <value>`
- Then Triton 原样采用显式 destination

## 验收门禁

- 先补 precedence、UUID、`sim:`、name 的失败测试。
- focused Xcode command tests 与 schema tests 通过。
- 正式本地门禁与 docs 校验通过。
- 通过 Triton schema 和纯 command/sourceCommand 证据验证，不为此启动长时间真实业务测试。

## 实现记录

- `resolveXcodeInvocation` 仅在用户显式传入 `--simulator` 时让 simulator selector 覆盖 workspace 保存的 destination；只继承默认 simulator 时仍保留已保存的 destination。
- 新增统一 `xcodeSimulatorDestination(selector:)`，供 `xcode use` 与 settings/build/test/run 共用，避免写入或执行 `id=<device name>`。
- schema 与命令帮助明确接受 UUID、`sim:<UUID>` 或名称，并声明显式 selector 会覆盖保存值。

## 验证记录

- 红灯：`swift test --package-path CLI --filter XcodeCommandTests` 因缺少统一 selector 解析函数而编译失败，证明新增测试先于实现。
- 绿灯：同一命令通过，10 个测试全部成功，覆盖旧 destination、UUID、`sim:`、名称与显式 destination 优先级。
- 正式门禁：`docs-linhay/scripts/verify.sh --local` 通过，包含 225 项根 Swift 测试、release CLI 构建、Harmony/iOS smoke、iOS Simulator build、文档结构与 diff 检查。
- 独立自检：`docs-linhay/scripts/check-docs.sh` 与 `git diff --check` 通过。

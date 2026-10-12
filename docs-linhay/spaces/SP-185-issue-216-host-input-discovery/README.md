# SP-185：Issue #216 host 文本输入发现边界

- Issue：https://github.com/NeptuneKit/TritonKit/issues/216
- 状态：v0.2.25 已发布／已回复关闭；GitHub #216 已关闭。
- 影响层：CLI help、capability、schema、恢复指引；不新增 keyboard adapter、HTTP 或 Web 控制面。
- 分支：`feat/SP-185-issue-216-host-input-discovery`
- worktree：`../TritonKit-worktrees/SP-185-issue-216-host-input-discovery`

## BDD 与验收

1. Given 任何 runtime 连接状态，When 查询 capabilities，Then `ios-simulator-host-type.supported=false`，说明公共 simctl 无 keyboard primitive，并指向只读 `schema --command "sim type"`。
2. Given agent 只读取 help/schema，Then 在执行前知道 `sim type` 是 reserved failure-only；ASCII 返回 `unsupported_host_input`，Unicode 返回 `unsupported_text_input`，不运行 host 输入。
3. Given 需要 host-only 表单输入，Then 明确剪贴板 staging、真实 paste、字段值验证、业务保存为独立阶段，不将其中一步成功视为全部完成。

## 最小 host-only 替代步骤

1. 保存 `triton capabilities --json` 与 `triton schema --command "sim type" --json` 的 unsupported 事实。
2. 用 `triton device list --platform ios --json` 选定唯一已 boot 的 Simulator。持续使用同一个显式 UDID，确认前台 App 和可编辑字段，不能把 tap 提交当作 focus 证明；用 `triton observe tree --platform ios --device <udid> --json` 或截图核验。
3. 用 `triton sim pasteboard set <text> --simulator <udid> --json` 准备文本；仅在允许读取文本内容时用 `triton sim pasteboard get --simulator <udid> --json` 复核。这一步仅写剪贴板，没有 paste/输入效果；文本可能进入 shell history/输出，使用测试数据并脱敏证据。
4. 当前 Triton 没有通用 host paste/keyboard primitive。必须明确使用已验证的外部 keyboard/paste adapter，或 App-owned debug hook；记录工具、目标、失败和权限前提。不自动 fallback；若 focus/target 无法确认，停止输入。
5. 实际 paste 后通过新鲜 host AX/observe 的字段 value（可得时）或可见截图核验文本；AX 不提供值时不推断通过。执行保存后再验证 App 持久化值或业务后置状态。剪贴板、adapter ACK 和屏幕值均不能独立证明保存成功。

## 实现与风险

- 修正 help 文案和 capability 误报；保留原有参数校验和 fail-closed 错误码。
- schema 去除 `sim.type` 成功形状承诺，说明共享 input output contract 不适用于当前 failure-only type。
- 没有真实 Simulator 输入验收，因为本切片仅修复发现/说明，不引入或调用输入实现。

## 验证记录

- 本次构建 `triton`：help 显示 reserved/unsupported；capabilities `supported=false` 且 nextAction 指向 schema；嵌套 schema 为合法 JSON。
- ASCII、Unicode、空文本分别返回 `unsupported_host_input`、`unsupported_text_input`、`validation_failed`；均 exit 1、单一 JSON envelope，无 Simulator 操作。
- `git diff --check` 通过。独立 worktree 的 `check-docs.sh` 曾因 SP-184 缺号阻塞；SP-190 已统一登记，集成后文档门禁通过。
- `swift test --package-path CLI --filter 'SimulatorAdvancedControlsTests|SchemaFactSourceTests/(iosSimulatorHostTypeCapabilityIsUnsupported)'`：37 tests / 2 suites 全过。

本轮集成入口：[SP-190](../SP-190-open-issues-integration/README.md)。以上 focused 记录来自各 issue 分支，不代表集成后完整门禁已通过。

## 发布归档

已通过 main CI `38211500153`（标准 Podspec lint）、Release `38212512464` 与安装验证，随 v0.2.25 回复并关闭。合并 `2959c6a1`，发布提交 `987540e5`；上述真实平台验收边界仍保留。

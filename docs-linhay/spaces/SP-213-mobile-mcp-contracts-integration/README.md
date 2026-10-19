# SP-213 — mobile-mcp Android 契约采用主控

## 边界与状态

branch：`feat/SP-213-mobile-mcp-contracts-integration`；worktree：`/Users/linhey/.codex/worktrees/mobile-mcp-contracts-integration/TritonKit`。

本期主控负责 [SP-212](../SP-212-mobile-mcp-android-contracts/README.md) 的冻结候选审查、focused/full CLI 与 shared 测试、文档/索引/memory 写回及必要本地 main 合并。状态：模型校验阻塞，待重试分派；不扩展到 SP-210/211，不推送/tag/release，不安装依赖、不运行上游代码、不操作设备。

产品基线为 `main@d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec`；主目录存在用户 WIP，主控使用 `/Users/linhey/.codex/worktrees/mobile-mcp-contracts-integration/TritonKit`，并以实际 main worktree 事实核对，不切换或重置主目录。

## 主控合同

- 新建会话显式传 `model="gpt-6.1-sol"`；校验失败只记录失败，不能回退或伪造 ID。
- 只接受 SP-212 执行会话的真实 diff、测试输出和候选 SHA；执行完成不等于合并完成。
- 逐文件核对 Android foreground activity 字段、unknown/fail-closed、ADB 特殊字符 argv 与敏感 source command；联合验证通过后才可在用户授权范围内创建本地提交并合入本地 main。
- 合并后复跑受影响 focused/full CLI/shared 门禁、`git diff --check`、docs 门禁；设备运行验收、真机/远端 adb、发布和推送另行授权。

## BDD

- Given SP-212 冻结候选，When 主控验证，Then 证据绑定真实候选 SHA，区分实现、验证、合并和发布状态。
- Given 任一测试或契约失败，When 主控收口，Then 退回执行会话修复并重跑，不凭旧日志合并。

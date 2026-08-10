# SP-162：iOS Simulator UICollectionViewCell host-HID fallback

## 边界

- 对应 GitHub issue：#199 `[Feature] Add auditable host-HID fallback for resolved UICollectionViewCell taps`
- 影响层：CLI `act tap`、TritonKitShared input result envelope、现有 iOS Simulator host adapter；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-162-issue-199-ios-collection-cell-host-hid/`
- 分支：`feat/SP-162-issue-199-ios-collection-cell-host-hid`
- 目标：对已安全解析且有 geometry 的 embedded UICollectionViewCell tap，提供显式 opt-in 的 iOS Simulator host-HID 坐标提交，并输出可审计证据。

## 非目标

- 默认 embedded runtime 行为不变：没有 `--allow-host-hid-fallback` 时仍 fail-closed，返回 `ancestor-collection-cell-unsupported` / `unsupported_capability`。
- 不支持真机、非 iOS target、私有 API、远端设备、Web/Wails 控制面或自动宣称业务 postcondition 已完成。
- 不为无解析 geometry、无 fresh screen geometry、off-screen/非法坐标调用 host adapter。

## BDD 验收

### 场景 1：默认安全拒绝

- Given embedded iOS runtime 已解析出 UICollectionViewCell 且返回 `unsupported_capability`
- When 未提供 `--allow-host-hid-fallback`
- Then 不调用 host-HID，保持原始 `ancestor-collection-cell-unsupported` 结果。

### 场景 2：query/AX 显式 fallback

- Given query 或 `--ax-oid`/`--ax-label` 已解析出节点和有限、正数 geometry
- When 提供 `--allow-host-hid-fallback`
- Then 以匹配 frame 中心和 fresh runtime screen bounds 构造现有 host-HID coordinate tap，且 target 仅为连接中的 iOS Simulator。

### 场景 3：成功与失败均为单一 JSON envelope

- Then `input.result` 保留 `matchedOID`/class/frame，并明确 `strategy`（`host-hid-coordinate-tap` 或 `...-failed`）、`source`（`host-hid`/`embedded`）、`fallbackFromStrategy`、`sourceCommands`。
- Then `verification.required=true` 且 status 为 `not-verified`，提示 agent 另行 `verify`/`wait`/`observe`；host-HID acknowledgement 不等于业务状态成功。
- When scope 或 geometry 不满足，Then 返回结构化 `unsupported_scope` 或 `geometry_required`，且不触发 host command。

## 验收命令

```bash
swift test --package-path CLI --scratch-path .build/sp162-199 --filter CollectionCellHostHIDFallbackTests
swift test --package-path CLI --scratch-path .build/sp162-199 --filter InputOutputTests
swift test --package-path CLI --scratch-path .build/sp162-199 --filter SchemaFactSourceTests
swift build --package-path CLI --scratch-path .build/sp162-199 --product triton
git diff --check
```

真实 Simulator/Baguette 不作为本次单测前置条件；host runner 通过注入闭包验证 command、scope、geometry 与 envelope 边界。

## 当前结论

- 实现已完成并通过主控审阅前的独立 worktree 验证，覆盖 query 与 AX 两条嵌入式解析路径、默认拒绝、host 成功/失败证据、iOS Simulator scope 和 geometry fail-closed。
- `CollectionCellHostHIDFallbackTests` 8/8、`InputOutputTests` 4/4 通过；`swift build --package CLI --scratch-path .build/sp162-199-release -c release --product triton` 通过；`git diff --check` 通过。
- `SchemaFactSourceTests` 在本 worktree 仍有 5 项既有 `xcode-archive` / `xcode-export` capability/schema 缺口；主控在未集成 SP-162 的基线 main 上复跑得到同样 5 项失败，故不归因于本 issue。该风险需后续独立修复。
- 未执行真实 Simulator/Baguette、真机或私有 API 验证；host-HID acknowledgement 仍不等价于业务 postcondition，远端 issue 评论、PR、push 和关闭待明确授权。

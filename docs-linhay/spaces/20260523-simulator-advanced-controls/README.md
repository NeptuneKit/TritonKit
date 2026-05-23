# Simulator Advanced Controls

## 背景

本 space 承接 GitHub issue #23。

P0/P1 real-project smoke 已经收口，但还有一批更偏 simulator maintenance / control-plane 的 host-side 能力需要继续推进：

- status bar override
- privacy / permissions
- simulated location
- UI appearance / contrast / content size
- pasteboard sync
- simulated push notifications
- diagnostics collection / verbose logging / runtime list-verify / video recording / bounded logs / xctrace / coverage artifacts

这些能力不属于 smoke 主线，但它们能显著降低真实项目回归时的人手操作成本，并且都应继续保持 CLI + JSON 机器可读契约。

## 关联 issue

| Issue | 角色 | 本 space 处理策略 |
| --- | --- | --- |
| #23 Remaining advanced simulator takeover controls | Epic | 已完成 Phase 3 的 host-side controls 收口，继续保留 JSON 契约和安全门禁 |

## 目标

1. 把常用 simulator maintenance 能力收敛进 `triton sim`。
2. 所有命令都能输出稳定 JSON envelope，方便 agent 复跑和审计。
3. 继续遵守 destructive action policy，不把高风险操作做成无门槛默认值。
4. 保持 host-side 边界，不引入 Web/Wails UI，也不把业务成功和 host ack 混为一谈。

## 非目标

1. 不做真机默认流程。
2. 不把 simulator control-plane 改成人读脚本输出。
3. 不把 host action ack 直接算作 smoke 通过。
4. 不把破坏性维护命令做成无门槛默认值。

## BDD 验收场景

### 场景一：status bar override 可复跑

- Given iOS Simulator 已 boot
- When 执行 `triton sim status-bar override --time ... --battery-level ... --json`
- Then 返回 `ok=true`、source command、risk level 和执行结果
- And `triton sim status-bar list --json` 能读取当前 override
- And `triton sim status-bar clear --json` 能清除 override

### 场景二：privacy / permissions 可复跑

- Given 目标 App 已安装于 iOS Simulator
- When 执行 `triton sim privacy grant location <bundle-id> --json`
- Then 返回机器可读 success envelope
- And revoke / reset 路径也有等价命令

### 场景三：location 可复跑

- Given iOS Simulator 已 boot
- When 执行 `triton sim location set <lat>,<lon> --json`
- Then 返回机器可读 success envelope
- And `clear` / `list` / `run` / `start` 都有同等契约

### 场景四：UI appearance 可复跑

- Given iOS Simulator 已 boot
- When 执行 `triton sim ui appearance dark --json`
- Then 返回机器可读 success envelope
- And `appearance` / `increase_contrast` / `content_size` 能读写当前设置

### 场景五：pasteboard / push 可复跑

- Given iOS Simulator 已 boot
- When 执行 `triton sim pasteboard set "<text>" --json`
- Then 可以通过 `get` 读回 pasteboard 内容或摘要
- And `sync` 可在 host/device pasteboard 之间同步
- When 执行 `triton sim push --bundle-id <bundle-id> --payload <json> --json`
- Then 返回 simulated push 的机器可读 envelope

### 场景六：video recording 可复跑

- Given iOS Simulator 已 boot
- When 执行 `triton sim record --output /tmp/sim.mov --duration 10 --json`
- Then 返回机器可读 success envelope
- And 生成的 `.mov` 可作为 framebuffer 证据归档

### 场景七：bounded logs 可复跑

- Given iOS Simulator 已 boot
- When 执行 `triton sim logs --output /tmp/sim.ndjson --duration 5 --json`
- Then 返回机器可读 success envelope
- And 完整日志写入 artifact，JSON 只返回 path、bytes 和 truncation 摘要

### 场景八：xctrace / coverage artifact 可复跑

- Given agent 需要宿主侧性能或覆盖率证据
- When 执行 `triton xctrace record --template "Time Profiler" --device <udid> --time-limit 5s --output /tmp/app.trace --json`
- Then 返回机器可读 artifact envelope
- And `.trace` 作为证据归档，不声明业务成功
- When 执行 `triton coverage report --xcresult /tmp/app.xcresult --output /tmp/coverage.json --json`
- Then coverage JSON 写入 artifact，CLI summary 只返回 path、bytes、source command 与 truncation 摘要

### 场景九：Phase 3 维护动作可复跑

- Given iOS Simulator 已 boot 或存在可用 runtime
- When 执行 `triton sim pair <watch-udid> <phone-udid> --json`
- Then 返回机器可读 success envelope
- And `unpair`、`clone`、`upgrade` 也有同等契约
- When 执行 `triton sim runtime delete all --dry-run --json`
- Then 只返回 readonly dry-run 结果，不删除任何 runtime
- When 执行 `triton sim erase <udid> --json`
- Then 返回 `confirmation_required`
- And `erase`、`runtime delete`、`runtime dyld-cache remove`、`personalization remove-*` 都保留确认门禁

## 当前分期

- Phase 1：status bar / privacy / location / ui / pasteboard / push。
- Phase 2：diagnose / verbose logging / runtime list-verify / video / bounded logs / xctrace / coverage artifacts。
- Phase 3：clone / pair / unpair / runtime maintenance / personalization（已完成）。

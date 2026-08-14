# SP-168：iOS Simulator 目标租约（target lease）

## 边界

- 对应 GitHub issue：#205 多个自动化 agent 并行跑 iOS Simulator smoke 流程时没有可见的预留状态；后到者会在首个流程仍活动时改变前台页面（`app open-url`、`act tap` 等），产生误导性流程证据。
- 影响层：CLI `target lease` 子命令、`triton serve` 共享状态（`/v1/target-leases/*`）、`app open-url|launch|terminate` 与 `act tap` 的可选 `--lease` 门禁、agent-facing schema、focused tests 与文档；不新增 HTTP/Web/Wails 控制面之外的能力。
- 工作目录：`../TritonKit-worktrees/SP-168-issue-205-target-leases/`
- 分支：`feat/SP-168-issue-205-target-leases`
- 基线：`origin/main@8cc72765`
- 目标：提供 schema-backed、可审计、可选的 Simulator 目标租约：带界 TTL 的 acquire、不透明 owner 标签、`target_lease_conflict` 稳定冲突信封、策略允许下的只读观察豁免、显式 takeover/release；未持有租约时行为完全不变（opt-in）。

## 非目标

- 不启动真实服务器之外的长期端口、不连接设备、不运行 Simulator；服务端状态用纯状态机测试与 Hummingbird `.router` 内存路由测试验证。
- 不把租约扩展到 Android/Harmony 真机、多租户、远端 agent 或 Web/Wails 控制面。
- 不要求 `--lease` 为必填：无租约时 `app`/`act` 行为与 0.2.18 完全一致。
- 不把 host 动作 acknowledgement 宣称为业务完成；`app open-url`/`act tap` 的既有后验验证边界不变。

## BDD 验收

### 场景 1：acquire 创建带界 TTL 的租约并返回 token

- Given `triton serve` 运行中
- When 执行 `triton target lease acquire --target sim:<udid> --owner agent-a --ttl 300 --json`
- Then 返回 `{ ok, status:"acquired", target, lease:{ id, target, owner, acquiredAt, expiresAt, ttlSeconds:300, readonlyObservationAllowed:true, kind:"triton.target-lease" } }`，`lease.id` 作为后续 `--lease` token。
- And TTL 越界（<30 或 >86400）与空 owner 返回机器可读校验错误（`lease_ttl_out_of_range` / `lease_owner_required`）。

### 场景 2：冲突的 mutating 命令返回稳定 `target_lease_conflict` 信封

- Given 目标已被 `agent-a` 持有租约
- When `agent-b` 执行 `triton app open-url <url> --device sim:<udid> --lease <agent-b 的 token> --json`（或 `act tap ... --lease ...`）
- Then 返回 HTTP 409 与 `{ ok:false, surface:"target-lease", error:{ code:"target_lease_conflict", leaseReason:"held_by_other"|"lease_expired"|"lease_not_held", currentOwner, currentLeaseID, currentExpiresAt?, suggestedCommands } }`，且不执行任何 simctl/host 动作。

### 场景 3：无 `--lease` 时行为不变（opt-in 向后兼容）

- Given 未持有任何租约（或持有但命令不带 `--lease`）
- When 执行 `triton app open-url ...` / `triton act tap ...`
- Then 不查询租约、不产生冲突，行为与 0.2.18 完全一致。

### 场景 4：只读观察豁免

- Given 目标被持有租约
- When 其它流程执行 `triton observe`、`triton wait`、`triton app list/info`、`triton sim screenshot`、`triton target lease status`
- Then 这些只读命令从不检查租约、从不冲突；租约信封中的 `readonlyObservationAllowed` 用于本地诊断/审计。

### 场景 5：显式 release 与 takeover

- Given 目标被 `agent-a` 持有租约（token `L1`）
- When 执行 `triton target lease release --target <udid> --lease L1 --json`
- Then 返回 `{ ok, released:true, status:"released" }`，后续 `status` 为 `none`；错误 token 的 release 返回 `target_lease_conflict`（`lease_release_denied`）。
- And `triton target lease takeover --target <udid> --owner agent-b --confirm --json` 显式接管并返回 `status:"taken_over"` 与 `previousOwner:"agent-a"`；不带 `--confirm` 返回 `target_lease_conflict`（`lease_takeover_required`）。

### 场景 6：租约过期

- Given 租约 TTL 已过
- When `status` 返回 `status:"expired"`；同 owner/新 owner 的 `acquire` 直接替换；持有过期 token 的 mutating 命令返回 `target_lease_conflict`（`lease_expired`）。

## 验收命令

```bash
swift test --package-path CLI --scratch-path .build/sp168-205 --filter TargetLeaseStoreTests
swift test --package-path CLI --scratch-path .build/sp168-205 --filter TargetLeaseHTTPTests
swift test --package-path CLI --scratch-path .build/sp168-205 --filter TargetLeaseCommandTests
swift test --package-path CLI --scratch-path .build/sp168-205 --filter PublicSkillCommandSchemaTests
swift test --filter TKTargetLeaseModelsTests   # root package
swift build --package-path CLI --scratch-path .build/sp168-205-release -c release --product triton
.build/sp168-205-release/release/triton schema --command target.lease --json
docs-linhay/scripts/check-docs.sh
git diff --check
```

真实 Simulator/私有 App 不作为本次验收前置条件；租约状态机以纯函数与内存路由 fixture 验证，禁止设备状态操作。

## 租约契约（v1）

- `triton target lease acquire --target <udid|sim:<udid>|booted|current> --owner <label> [--ttl <30...86400>] [--readonly-observation-allowed <bool>] [--host] [--port] --json`
- `triton target lease status --target <selector> --json` → `status: held|expired|none`
- `triton target lease release --target <selector> --lease <id> --json` → `released: true|false`
- `triton target lease takeover --target <selector> --owner <label> [--ttl] --confirm --json` → `status: taken_over|already_held|acquired`
- Mutating 命令（v1 面）：`app open-url`、`app launch`、`app terminate`、`act tap` 接受 `--lease <id>`，由 `POST /v1/target-leases/check` 原子判定；冲突返回 `target_lease_conflict`。
- 服务端 HTTP：`POST /v1/target-leases/acquire`、`GET /v1/target-leases/status?target=`、`POST /v1/target-leases/release`、`POST /v1/target-leases/takeover`、`POST /v1/target-leases/check`。
- 目标 key 归一化：`sim:` / `host:ios:` / `triton:ios-simulator:` 前缀与 `/app:<bundle-id>` 后缀被剥离；`booted`/`current` 在 acquire 时尽量解析为具体 UDID。

## 当前状态

- 已完成（本地）：`TargetLeaseStore` 纯状态机、serve `/v1/target-leases/*` 路由、`target lease` 四个子命令、`app open-url|launch|terminate` 与 `act tap` 的可选 `--lease` 门禁、`target_lease_conflict` 稳定信封（含 `leaseReason/currentOwner/currentLeaseID/currentExpiresAt/suggestedCommands`）、schema（`target` 六个子命令声明 + `--lease`/`--owner`/`--ttl`/`--confirm` 选项 + `target-lease` capability）与 release CLI。
- TDD red：新增 focused suites 首次因租约类型/命令/路由缺失而编译失败（`cannot find 'TargetLeaseStore'` / `cannot find 'enforceTargetLease'` 等）；最小实现后转绿。
- TDD green（新增 40 项）：`TargetLeaseStoreTests` 15/15（acquire/status/release/takeover/check/TTL/owner/过期/归一化）、`TargetLeaseHTTPTests` 6/6（内存 router，不开端口）、`TargetLeaseCommandTests` 13/13（parser/schema/conflict-envelope）、根包 `TKTargetLeaseModelsTests` 6/6（wire 模型 round trip + `TKCLIErrorDetail` 向后兼容）。`PublicSkillCommandSchemaTests` 1/1（快照已按当前 schema 重新生成）。
- 关联回归：223 tests/11 suites 中仅剩 5 项为既有 Xcode archive/export baseline 失败（SP-163 memory 已知清单，非本 issue 引入）；CLIHelp/SelectorFlag/AppOpenURLFlow/InputOutput/SimulatorForegroundTapRouting/FailureDiagnostics/WebCommand/AppMapPathGraph/ServeCommand/ServerTargetSelection 全部通过。根包 `TKCLITransportModelsTests` 34/34 通过（`TKCLIErrorDetail` 扩展兼容）。
- release CLI：`swift build -c release --product triton` 通过；`schema --command target.lease --json` / `--command target` / `--command app.open-url` / `--command act.tap` 已验证 lease 子命令、`--lease` 选项与 `target_lease_conflict` failure code 一致；`triton target lease --help` 正常。
- 文档：space README、`spaces/INDEX.md`（164 个 space）、`spaces/README.md`（路线裁决 + worktree 台账）、`memory/2026-08-11.md`、`dev/ai-cli-readable-control.md`、README CLI 段、`public-skill-command-schema.json` 已同步；`git diff --check` 通过。
- 风险：未连接真实 Simulator/私有 App；`--lease` 门禁只在显式携带 token 时生效，未携带 token 的并发流程仍互不可见（符合 opt-in 边界）；`check-docs.sh` 的 SP 连续编号断言因并行批次（SP-164～SP-169 独立 worktree）在本分支内仅剩编号连续性一项不满足（第 164 项为 SP-168，门禁按位置期望 SP-164），其余结构检查（链接唯一、无空格路径、无 latest/final）全部通过，按 SP 顺序合入主线后自动恢复。远端 issue 未评论或关闭。

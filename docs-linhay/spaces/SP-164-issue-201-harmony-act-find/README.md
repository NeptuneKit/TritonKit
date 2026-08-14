# SP-164：Harmony `act find` host adapter 选择

## 边界

- 对应 GitHub issue：#201 `act find` cannot select a Harmony host adapter（`--platform harmony --device <harmony-target>` 应像 `act tap` 一样从 Harmony uitest host layout 解析目标；当前缺 `--platform`/`--hdc`，Harmony `--device` 会落入 embedded iOS runtime server 并返回 `server_unavailable`）。
- 影响层：CLI `act find` 的 selector/routing、agent-facing schema（`act.find` subcommand）、focused tests 与文档；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-164-issue-201-harmony-act-find/`
- 分支：`feat/SP-164-issue-201-harmony-act-find`
- 基线：`origin/main@8cc72765`
- 目标：`act find` 显式支持与 `act tap` 相同的 host adapter/target 选择（`--platform harmony --device <harmony-target>`），从 Harmony `uitest` host layout 解析匹配，与 `act tap` 共享 target resolution；Harmony `--device` 不再落到 embedded iOS server。`--platform ios|android` 的 find 返回 typed `unsupported_capability`，schema/help 如实说明。

## 非目标

- 不启动真实服务、不连接真实设备、不运行 `hdc`；一切用纯函数/parser/schema/fixture 测试验证。
- 不实现 iOS/Android host find 的 layout 解析（`--platform ios|android` 返回 typed unsupported，不用旧路径静默回落）。
- 不修改 iOS/Android embedded runtime 路径行为；不带 `--platform` 的 `act find` 保持 embedded 语义。
- 不新增 HTTP/Web/Wails 控制面；不触碰其他 worktree 或主仓库。

## BDD 验收

### 场景 1：`act find --platform harmony --device <harmony-target>` 从 host layout 解析

- Given 用户显式传入 `--platform harmony --device <harmony-target>`（如 `127.0.0.1:10100`）与查询文本
- When 执行 `act find`
- Then CLI 用 `resolveHarmonyTarget` 解析目标、`uitest dumpLayout` 抓取 host layout，按 `attributes.text` 精确匹配并返回与 embedded 相同的 `target.resolution` 契约（source=host-harmony-layout、strategy=coordinate、frame、request 中心坐标、matchIndex/matchCount）。

### 场景 2：Harmony `--device` 不落入 embedded iOS server

- Given 显式 `--platform harmony`（含 Harmony `--device`）
- When 执行 `act find`
- Then 在 `resolveRuntimeClient`（embedded `/targets`）之前进入 host-harmony 分支并立即返回；绝不产生指向 `http://127.0.0.1:19421/targets` 的 `server_unavailable`。

### 场景 3：`--platform ios|android` 返回 typed unsupported

- Given 用户显式传入 `--platform ios` 或 `--platform android`
- When 执行 `act find`
- Then 返回单一合法 JSON envelope `error.code=unsupported_capability`，hint 指向 `observe tree --platform ios|android` 与 `act tap --platform ios|android`；不落入 embedded server。

### 场景 4：schema/help 与运行时一致

- Given agent 读取 `triton schema --command act --json` 或 `act.find`
- Then `act.find` subcommand 的 optionalOptions 暴露 `--platform`/`--adb`/`--hdc`，failureCodes 包含 `unsupported_capability`/`target_offline`/`host_command_failed`/`harmony_layout_path_not_found`，usage/examples 含 `--platform harmony --device <harmony-target>`。
- Then 不带 `--platform` 的 `act find` 仍保持 embedded runtime 语义与 `server_unavailable`（server 未启动时）不变。

### 场景 5：`--within`/`--at`/`--index`/`--all` 在 host-harmony 路径生效

- Given host-harmony 路径
- When 传入 `--within x,y,width,height`、`--at x,y`、`--index <n>` 或 `--all`
- Then 候选按 depth/y/x 稳定排序，`--within`/`--at` 过滤、`--index` 选择、`--all` 返回 candidates，行为与 embedded find 对齐；无匹配返回 `text_not_found`，index 越界返回带 `--index` 信息的 `text_not_found`。

## 验收命令

```bash
swift test --package-path CLI --scratch-path .build/sp164-201 --filter HarmonyActFindTests
swift test --package-path CLI --scratch-path .build/sp164-201 --filter SelectorFlagTests
swift test --package-path CLI --scratch-path .build/sp164-201 --filter InputOutputTests
swift test --package-path CLI --scratch-path .build/sp164-201 --filter SchemaFactSourceTests
swift build --package-path CLI --scratch-path .build/sp164-201-rel -c release --product triton
.build/sp164-201-rel/release/triton schema --command act.find --json
.build/sp164-201-rel/release/triton schema --command act --json
docs-linhay/scripts/check-docs.sh
git diff --check
```

按本轮边界只运行 focused gates，不运行完整 `verify.sh --local`；真实 Harmony 设备/HDC 不作为验收前置条件。

## 当前状态

- 已完成（本地）：`act find` 新增 `--platform`/`--adb`/`--hdc`；`actFindHostRoute` 在 `resolveRuntimeClient` 前分流——`--platform harmony` 走 host-harmony（`resolveHarmonyTarget` + `dumpHarmonyLayout` + `TKHarmonyLayoutParser.nodeSummaries` 精确匹配），`--platform ios|android` 返回 typed `unsupported_capability`，无 `--platform` 保持 embedded。
- TDD red：新增 `HarmonyActFindTests` 先因 `Find` 无 `--platform` 选项、`actFindHostRoute`/`resolveHostHarmonyFind` 不存在而编译失败；补入最小实现后 focused suite 通过。
- focused regression：`HarmonyActFindTests`（parser/routing/纯函数解析/schema contract）通过；`SelectorFlagTests`/`InputOutputTests`/`SchemaFactSourceTests` 复跑无新增失败。
- release CLI：`swift build -c release --product triton` 通过；release `triton schema --command act.find --json` 与 `act --json` 已确认 `--platform`/`--hdc`、`unsupported_capability` failure code 与 harmony usage/example。
- 文档：`check-docs.sh` 与 `git diff --check` 通过；space 已登记到 INDEX 与路线总览。
- 风险：未连接真实 Harmony 设备/HDC；host layout 解析只经 fixture 验证，真实 `uitest dumpLayout` 文本/坐标与 embedded `/targets` 语义未在真机复测。远端 issue 尚未评论或关闭。

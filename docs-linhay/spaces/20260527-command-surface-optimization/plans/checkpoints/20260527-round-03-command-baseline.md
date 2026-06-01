# Round 03: Command Surface Baseline

## 目标

冻结当前 `triton` CLI 命令面和 schema 事实源状态，为后续 schema 补齐、错误 envelope 统一、Host 命令拆分和方案 C 破坏性重排提供可复查基线。

## 本轮完成

- 基于当前工作区源码运行 `swift run --package-path CLI triton --help`，确认 root help 暴露 52 个 subcommand。
- 基于当前工作区源码运行 `swift run --package-path CLI triton schema --json`，确认 schema version 为 1，schema 暴露 52 个 command。
- 记录当前 schema 元数据覆盖情况：
  - `requiresServer`: 32 个 command。
  - `requiresTarget`: 33 个 command。
  - `requiresHierarchy`: 1 个 command。
  - `nextCommands`: 2 个 command。
  - `failureCodes`: 4 个 command。
  - `outputContracts`: 4 个 command。
  - `artifacts`: 4 个 command。
  - `jsonlEvents`: 仅 `xcode`。
- 记录当前 runtime scope 分布：
  - `cli`: `version`, `status`, `doctor`, `plan`, `capabilities`, `schema`, `list`, `inspect`, `smoke`, `record`
  - `cli+embedded`: `evidence`, `capture`, `replay`
  - `cli-long-running`: `serve`
  - `embedded`: `runtime`, `state`, `snapshot`, `focus`, `set-text`, `select-segment`, `set-switch`, `ledger`, `hierarchy`, `nodes`, `attrs`, `object`, `export`, `assert`, `find`, `geometry`, `hit`, `input`
  - `embedded|host-device`: `screenshot`
  - `embedded|host-harmony`: `observe`, `webview`, `route`, `node`, `wait`, `ax`, `tap`, `swipe`, `type`, `paste`, `clear`, `press`
  - `host-device`: `device`
  - `host-simulator`: `sim`
  - `host-simulator|host-harmony`: `app`
  - `host-xcode`: `xcode`, `xcresult`, `xctrace`, `coverage`

## 当前命令清单

```text
version, serve, status, doctor, plan, capabilities, schema, xcode,
xcresult, xctrace, coverage, runtime, state, snapshot, focus, set-text,
select-segment, set-switch, ledger, device, sim, app, list, inspect,
observe, webview, route, hierarchy, nodes, node, attrs, object, export,
evidence, capture, smoke, assert, record, replay, find, wait, ax,
geometry, hit, screenshot, tap, swipe, type, paste, clear, press, input
```

## 差距清单

- 当前 root 命令仍是混合扁平结构：`find`、`tap`、`type`、`paste`、`clear`、`press` 等 action 入口直接挂在 root 下；方案 C 目标是统一到 `action` 层。
- 当前没有 `target` root command；目标选择仍分散在 `list`、`inspect`、`device`、`sim`、`app` 和各命令的 `--target` 中。
- 当前没有 `project` root command；Xcode project / workspace 发现能力集中在 `xcode discover/use`。
- `plan` 已存在，但仍主要是状态建议和 `.tritonplan` inspect，不是任务型 workflow planning。
- `schema` 已具备基础字段，但 `nextCommands`、`failureCodes`、`outputContracts`、`artifacts` 覆盖很低，无法作为完整 agent 事实源。
- `capabilities` 已存在，但当前还需要升级为环境能力矩阵，覆盖 server、runtime、iOS simulator、Harmony target、Xcode project、WebView bridge、evidence 和 replay。
- `observe`、`runtime`、`webview`、`state`、`snapshot` 的观察边界需要在后续信息架构中重新整理。
- 本项目已明确不维护 legacy / compatibility 层；后续破坏性重排时以同步 schema、skills、README、dev 文档和测试为硬门禁。

## 改动范围

- 新增本 checkpoint 文档。
- 未修改 CLI 代码。
- 未修改现有 WIP 代码文件。

## 验证

- `swift run --package-path CLI triton --help`：通过，当前 root help 可生成。
- `swift run --package-path CLI triton schema --json`：通过，当前 schema JSON 可生成。
- `swift run --package-path CLI triton schema --json | python3 -c '<summary parser>'`：通过，完成命令数量、runtime scope 和 metadata 覆盖统计。

## 决策

- Round 04 优先从 schema 事实源补齐开始，不先做命令重命名。
- Round 04 的第一批实现应聚焦可测试字段：`failureCodes`、`nextCommands`、`outputContracts`、`artifacts`、`requiredOptions`。
- SwiftPM 命令后续串行运行，避免多个 `swift run --package-path CLI` 进程争抢同一个 `.build` 锁。

## 风险

- 当前工作区仍包含 Issue 20 tap activation、WebView wait extension 和本期 planning 三组 WIP；后续代码切片需要避免混改。
- schema 当前能描述“命令存在”，但对 agent 的恢复动作、失败分类和输出契约支持不足。
- root help 与 schema 数量一致不代表 schema 语义完整；Round 04 需要用测试锁住 agent-facing contract。

## 下一轮建议

进入 Round 04：先补 CLI schema tests，针对重点命令建立失败测试，再补齐 schema 元数据。建议第一批覆盖 `doctor`、`status`、`capabilities`、`plan`、`xcode`、`sim`、`app`、`webview`、`input`、`assert`、`evidence`。

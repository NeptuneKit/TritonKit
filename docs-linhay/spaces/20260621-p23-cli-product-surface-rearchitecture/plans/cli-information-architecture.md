# Triton CLI Information Architecture

## Decision

P23 采用 CLI Product Surface Re-architecture：不删除能力，先重排暴露层。

裁决：

1. TritonKit CLI 的主要问题是产品暴露层设计，而不是功能缺失。
2. observe、act、verify 应成为产品主轴。
3. hierarchy、tap、assert 是实现能力或旧入口，不应继续代表产品抽象层。
4. 第一刀只证明新产品语言成立，不做全量迁移。

## North Star

TritonKit is an AI-agent-facing native App automation control plane.

中文定义：

TritonKit 是面向 AI agent 的本机 App 自动化控制面，通过机器可读 CLI / HTTP 契约完成目标发现、App 启动、界面观察、动作执行、断言验证和证据复跑。

这一定义把现有四类能力收敛为一个产品方向：

| 现有方向 | 在 North Star 中的位置 |
| --- | --- |
| 测试框架：test / assert / record / replay / smoke | 验证、复跑和证据闭环 |
| 设备控制：device / sim / app | 本机 target 与 App lifecycle 控制 |
| UI Inspector：hierarchy / observe / nodes / attrs | 界面观察与目标发现的底层事实源 |
| Agent Runtime：vlm / action parse / ledger / map | agent 自动化、审计和路径学习支撑能力 |

如果只能选一个北极星，TritonKit 是 Agent Runtime / 本机自动化控制面；测试、设备控制和 UI Inspector 都是支撑 workflow。

## Command Layering

CLI 暴露层分为三层。

### 1. Workflow CLI

面向用户和 AI agent 的主入口。命令应该从真实任务长出来，描述用户要完成什么，而不是描述 runtime 内部如何实现。

首选心智：

    Prepare -> Launch -> Observe -> Act -> Prove

对应命令族：

- doctor
- schema
- capabilities
- plan
- target
- app
- observe
- act
- verify
- evidence
- test
- project / xcode

### 2. Diagnostic CLI

面向诊断、能力发现、恢复路径和环境审计。

保留为清晰的一等入口：

- doctor
- status
- schema
- capabilities
- plan
- target current
- target resolve
- target wait-ready
- device doctor
- xcode status
- xcode wait-idle

Diagnostic CLI 必须机器可读，失败时返回稳定 error envelope 和 next action。

### 3. Raw Engine CLI

面向开发者、高级 agent、debug 和底层事实读取。P23 不保留已迁移旧 root 的兼容入口。

这些能力不删除，但不作为新用户主路径：

- hierarchy
- nodes
- node
- attrs
- object
- geometry
- ax
- snapshot
- runtime
- state
- ledger

目标形态是降级到 debug 或 observe/debug 下，而不是平铺在 root。

## Five Core Workflows

### 1. Prepare

回答“当前环境能不能用，缺什么，下一步该做什么”。

首选入口：

    triton doctor --json
    triton schema --json
    triton capabilities --json
    triton plan --json

### 2. Launch

回答“我要控制哪个 target、哪个 App，如何启动并等待 ready”。

首选入口：

    triton target use booted --json
    triton app launch --bundle-id <bundle-id> --wait-ready --json

Xcode 项目场景：

    triton xcode run --jsonl

### 3. Observe

回答“当前界面是什么，有哪些可操作目标”。

目标心智：

    triton observe current --json
    triton observe tree --json
    triton observe screenshot --output <path> --json
    triton observe webview current-url --json

现有实现能力可复用：

- observe current
- observe tree
- hierarchy
- nodes
- ax
- geometry
- screenshot
- webview
- route

### 4. Act

回答“我要对界面执行哪个动作”。

目标心智：

    triton act find --text "登录" --json
    triton act tap --text "登录" --json
    triton act type --text "hello" --json
    triton act paste --text "hello" --secure --json
    triton act clear --json
    triton act swipe --from 100,500 --to 100,100 --json
    triton act press home --json

现有实现能力可复用：

- find
- tap
- type
- paste
- clear
- swipe
- press
- focus
- set-text
- select-segment
- set-switch
- input
- action parse

### 5. Prove

回答“结果是否符合预期，失败如何审计，路径能否复跑”。

目标心智：

    triton verify text-exists "首页" --json
    triton verify text-not-exists "错误" --json
    triton verify route --expected-url <url> --json
    triton evidence capture --case login-home --output ./evidence/login-home --json
    triton replay ./flows/login-home.tritonplan --json

现有实现能力可复用：

- assert
- wait
- route assert-current-url
- evidence
- capture
- record
- replay
- smoke
- test
- map

## First Success Path

新用户第一次成功必须分为两档。

### 最短路径：doctor -> plan -> smoke

用于安装后验证整体链路。

    triton doctor --json
    triton plan ios-smoke --json
    triton smoke ios --json --evidence ./evidence/first-smoke

要求：

1. doctor 说明当前环境是否满足。
2. plan 给出可执行命令序列，不要求用户读源码或 README。
3. smoke 产出可审计 evidence。

### 分解路径：doctor -> target use -> app launch -> observe -> act -> verify -> evidence

用于解释 TritonKit 的核心产品模型。

    triton doctor --json
    triton target use booted --json
    triton app launch --bundle-id com.example.app --wait-ready --json
    triton observe current --json
    triton act tap --text "登录" --json
    triton verify text-exists "首页" --json
    triton evidence capture --case login-home --output ./evidence/login-home --json

这条路径是 P23 后续命令设计的主验收样例。

## New Top-level Surface

P23 目标顶层面：

    doctor
    schema
    capabilities
    plan
    target
    app
    observe
    act
    verify
    evidence
    test
    project / xcode

说明：

- doctor / schema / capabilities / plan 是 bootstrap 与机器可读事实源。
- target 负责目标发现、选择、消歧和 ready。
- app 负责 App install / launch / terminate / open-url / prefs / container 等 lifecycle。
- observe 负责当前界面、树、截图、WebView、route、geometry、AX 等观察面。
- act 负责 find / tap / type / paste / clear / swipe / press / focus / set-text 等动作面。
- verify 负责 text、route、WebView、idle 等断言与等待。
- evidence 负责 capture / inspect / summary / redact / project。
- test 负责 validate / normalize / run / report / create / smoke / replay / map 的测试资产链路。
- project / xcode 负责工程发现、构建、测试和运行；当前可先保留 xcode，是否新增 project 另行切片。

## Raw / Debug Surface

目标形态：

    debug hierarchy
    debug nodes
    debug node
    debug attrs
    debug object
    debug geometry
    debug ax
    debug snapshot
    debug runtime manifest
    debug state app
    debug ledger

P23 不要求立即搬迁所有命令。短期策略：

1. 新增 workflow 壳。
2. 高频命令接入 workflow 壳。
3. 已迁移旧 root 不进入 root help、schema inventory 或 parser 入口。
4. `debug` root 作为 raw-engine 容器落地；后续只决定是否继续细分 observe debug 子树，不再定义旧 root 兼容期。

## Migration Table

| Old command | New command | Layer | Rationale |
| --- | --- | --- | --- |
| triton list | triton target list | Workflow / Diagnostic | target 发现应归入目标上下文，不应靠默认 root 命令表达 |
| triton target list | triton target list | Workflow / Diagnostic | 保留，仍是一等目标发现入口 |
| triton device list | triton target list --source host 或保留 device list | Diagnostic / Host adapter | device 是 host adapter 事实源，target 是产品上下文 |
| triton sim list | triton target list --platform ios --kind simulator 或保留 sim list | Diagnostic / Host adapter | sim 是 iOS host adapter 管理入口，不应成为通用 workflow 心智 |
| triton app launch | triton app launch | Workflow | App lifecycle 是一等 workflow |
| triton xcode run | triton xcode run / future triton project run | Workflow | 当前保留 xcode；project 是否抽象化另起切片 |
| triton observe current | triton observe current | Workflow | 当前已接近目标语言，保留并强化 |
| triton observe tree | triton observe tree | Workflow | 当前已接近目标语言，保留并强化 |
| triton hierarchy | triton observe tree 或 triton debug hierarchy | Raw Engine | hierarchy 是实现事实源，不是产品 workflow |
| triton nodes | triton observe nodes 或 triton debug nodes | Raw Engine | 节点枚举属于观察实现细节 |
| triton node resolve | triton observe resolve 或 triton act find | Workflow / Raw Engine | 若用于用户目标定位，归入 act/find；若用于底层节点解析，归入 debug |
| triton attrs | triton debug attrs | Raw Engine | runtime API 直接读取，不作为主路径 |
| triton object | triton debug object | Raw Engine | runtime object 详情是 debug 能力 |
| triton geometry | triton observe geometry 或 triton debug geometry | Workflow / Raw Engine | window geometry 可服务观察，但默认不应平铺 root |
| triton ax | triton observe ax 或 triton debug ax | Workflow / Raw Engine | AX 树是观察事实源；主路径应优先 current/tree |
| triton screenshot | triton observe screenshot | Workflow | 截图属于观察产物 |
| triton webview current-url | triton observe webview current-url | Workflow | WebView 是观察面，不是独立产品域 |
| triton route assert-current-url | triton verify route | Workflow | route 断言属于验证面 |
| triton find | triton act find | Workflow | find 是 action 前置定位，而不是独立 root 心智 |
| triton tap | triton act tap | Workflow | tap 是 action primitive |
| triton type | triton act type | Workflow | type 是 action primitive |
| triton paste | triton act paste | Workflow | paste 是 action primitive |
| triton clear | triton act clear | Workflow | clear 是 action primitive |
| triton swipe | triton act swipe | Workflow | swipe 是 action primitive |
| triton press | triton act press | Workflow | press 是 action primitive；unsupported 也应以 act 语言返回 |
| triton focus | triton act focus | Workflow | focus 是 action primitive |
| triton set-text | triton act set-text | Workflow | set-text 是 action primitive；可与 type/paste 区分精确赋值 |
| triton select-segment | triton act select-segment | Workflow | 控件专用 action，不应 root 平铺 |
| triton set-switch | triton act set-switch | Workflow | 控件专用 action，不应 root 平铺 |
| triton input | triton act input | Workflow | 批量动作属于 action surface |
| triton assert text-exists | triton verify text-exists | Workflow | assert 是验证实现能力，verify 是产品语言 |
| triton wait --text | triton verify text-exists --wait 或 triton verify wait text | Workflow | wait 是验证时序，不应与 action 平级 |
| triton evidence | triton evidence | Workflow | 证据是一等闭环入口 |
| triton capture | triton evidence capture | Retired root -> Workflow | P23-G 已落地产品入口；P23-H 已移除旧 root 暴露 |
| triton record | triton test record 或 triton replay record | Workflow | record 是测试/回放资产生成入口 |
| triton replay | triton test replay 或保留 replay | Workflow | replay 是 Prove 闭环；短期可保留 root |
| triton smoke | triton test smoke 或保留 smoke | Workflow | smoke 是首次成功和回归入口；短期保留 root 有价值 |
| triton map | triton test map 或 triton evidence map | Workflow / Agent support | App Map 服务测试路径学习，不是普通主路径 |
| triton action parse | triton act parse-provider 或 triton agent action parse | Workflow / Agent support | 外部 GUI agent 接入属于 action 支撑能力 |
| triton vlm ground | triton act ground 或 triton agent vlm ground | Agent support | VLM grounding 是 agent 支撑能力，短期不放新用户主路径 |
| triton ledger | triton debug ledger | Raw Engine | ledger 是审计/debug，不是主路径 |
| triton runtime manifest | triton debug runtime manifest | Raw Engine / Diagnostic | runtime manifest 仍重要，但属于 runtime 事实源 |
| triton state app | triton debug state app 或 triton observe state app | Raw Engine | state 是 runtime 实现面 |

## Schema Contract

每个 workflow 命令必须支持以下契约。

### 1. Machine-readable output

所有 workflow 命令必须支持 --json。如命令会产生流式事件，必须明确 --jsonl。

### 2. Stable exit code

退出码必须稳定：

- 0：命令完成且 workflow 条件满足。
- 非 0：命令失败，或 verify 条件不满足。

Bootstrap 类命令可以在环境不可用时返回 ok=false 但退出码保持 0，前提是该命令的产品语义是诊断而非执行。

### 3. Machine-readable error

失败输出必须是单个合法 JSON envelope，并包含稳定 code、message、hint 和可机器读取的 nextAction。

禁止一个失败输出多个 JSON envelope。

### 4. Case / evidence identity

能进入 Prove 闭环的命令必须支持或传递：

- --case <case-id>
- --evidence <path> 或 --output <path>
- evidence manifest 中的稳定 artifact taxonomy

### 5. Target context

Workflow 命令必须消费统一 target context：

- 默认读取 target current
- 支持显式 --target
- host-side 命令可继续支持 --device，但 schema 必须说明它与 --target 的关系

### 6. Schema-backed help

新增或迁移 workflow 命令时必须同步：

- triton schema --command <command> --json
- help 文案
- plan 输出中的 argv
- tests
- README / public skills / dev docs

## P23 Implementation Slices

### P23-A：CLI IA 裁决文档

产物：

- docs-linhay/spaces/20260621-p23-cli-product-surface-rearchitecture/README.md
- docs-linhay/spaces/20260621-p23-cli-product-surface-rearchitecture/plans/cli-information-architecture.md

不改代码。

### P23-B：新增 observe / act / verify 命令壳

目标：

- 新增 observe、act、verify 的产品壳。
- 不搬所有实现。
- 旧命令继续可用。

候选最小命令：

- triton observe current
- triton act tap
- triton verify text-exists

### P23-C：高频命令接入新壳

第一批接入：

- observe current
- act tap
- act type
- verify text-exists

验收样例：

    triton observe current --json
    triton act tap --text "登录" --json
    triton act type --text "hello" --json
    triton verify text-exists "首页" --json

### P23-D：help / schema / plan 切主入口

目标：

1. triton --help 与相关子命令 help 推荐新产品语言。
2. triton schema --json 暴露新 surface。
3. triton plan 输出优先使用 observe / act / verify。
4. 已迁移旧 root 不进入 schema inventory；迁移关系保留在 IA 文档与测试裁决中。

当前第一刀状态（2026-06-21）：

- 已新增 `triton act` 顶层产品壳，委托 `find/tap/type/paste/clear/swipe/press/focus/set-text/select-segment/set-switch/input`。
- 已新增 `triton verify text-exists` 与 `triton verify text-not-exists`，复用既有 assertion runtime。
- 已支持 `triton act tap --text <text> --json`，位置参数 `<query>` 继续兼容。
- 已更新 `triton schema --command act --json` 与 `triton schema --command verify --json`，包含 output contracts、failure codes、provided capabilities 和 schema-backed next actions。
- 已更新 capability nextAction：`tap/type/input` 推荐 `act` surface，verification recovery 推荐 `verify` surface。
- 已更新 bootstrap workflow plan：`observe-current`、`observe-tree`、`verify-text`、`act-input` 替代旧 `geometry/ax/wait/input` 作为新语言示例。
- 已更新中文 help 模型：`act` 与 `verify` 有独立 overview / usage / options。
- 已新增 schema surface metadata：`surfaceLayer`、`deprecatedForMainPath`、`replacementCommand`、`rawDebugCommand`、`surfaceRationale`。
- 已将第一批旧 root 从 schema inventory 隐藏：action primitive root 由 `act` 承接，raw runtime / inspection root 由 `debug` 承接。
- 已新增真正的 `triton debug` root 壳，挂接 `runtime/state/snapshot/hierarchy/nodes/node/attrs/object/geometry/ax/hit/ledger` 既有命令；`rawDebugCommand` 已指向可执行 debug 入口。
- 已新增 `triton evidence capture --case <case> --output <path> --json` 产品入口，作为 Prove workflow 的首选 evidence capture 语言。
- 已将 `evidence inspect/summary/redact/project-workspace/project-screens` 从旧 action 参数模式提升为真实子命令；不新增 `triton evidence --name/--output ...` 默认入口。
- 已更新 `evidence` schema：`evidence` 暴露 capture 子命令、`--case`、`evidence.manifest` selector；`capture` 不再出现在 schema inventory。

## Non-goals for First Cut

1. 不做全量 migration。
2. 不改变底层 HTTP / runtime API。
3. 不把 Web / Wails 变成业务控制入口。
4. 不保留已迁移旧 root 的兼容入口；root help / schema / parser 必须以新 surface 为准。

## Verification Gate

P23-B 之后的代码切片至少需要：

    swift test --package-path CLI --filter SchemaFactSourceWorkflowTests
    swift test --package-path CLI --filter SchemaFactSourceSurfaceContractTests
    swift test --package-path CLI --filter ActionProviderParserTests
    docs-linhay/scripts/check-docs.sh
    git diff --check

如果只做 P23-A 文档切片：

    docs-linhay/scripts/check-docs.sh
    git diff --check

本轮已执行验证（2026-06-21）：

    swift test --package-path CLI --filter ActionProviderParserTests --filter InputOutputTests --filter SchemaFactSourceWorkflowTests --filter SchemaFactSourceSurfaceContractTests --filter SchemaFactSourceContractTests
    swift test --package-path CLI --filter SchemaFactSourceTests --filter SchemaFactSourcePlanTests --filter SchemaFactSourceCapabilityTests
    swift test --package-path CLI
    CLI/.build/debug/triton schema --command act --json
    CLI/.build/debug/triton schema --command verify --json
    CLI/.build/debug/triton act --help
    CLI/.build/debug/triton verify --help
    CLI/.build/debug/triton act tap --text 登录 --json
    CLI/.build/debug/triton verify text-exists 首页 --json
    CLI/.build/debug/triton debug --help
    CLI/.build/debug/triton schema --command debug --json
    CLI/.build/debug/triton evidence --help
    CLI/.build/debug/triton evidence capture --help
    CLI/.build/debug/triton evidence capture --case p23-g --output /tmp/triton-p23-g-invalid.tritonevidence --include bogus --json
    CLI/.build/debug/triton evidence --name p23-g --output /tmp/triton-p23-g-removed.tritonevidence --include bogus --json
    CLI/.build/debug/triton schema --command evidence --json
    CLI/.build/debug/triton schema --command capture --json
    CLI/.build/debug/triton schema --command tap --json
    CLI/.build/debug/triton schema --command hierarchy --json
    CLI/.build/debug/triton tap --help
    CLI/.build/debug/triton runtime --help

本轮 `swift test --package-path CLI` 已通过，403 tests / 34 suites。P23-H 相关 focused gate 248 tests 通过，CLI smoke 覆盖 root help、旧 root unknown、中文 help 旧 root unknown、`schema --command tap/capture/hierarchy` unknown、`debug runtime/hit` 与 `act tap`。

## Open Questions

1. project 是否应成为 xcode 之上的抽象 root，还是保留 xcode 作为 Apple workflow 的明确入口？
2. smoke / replay / map 是否并入 test，还是保留 root 以降低首次成功路径成本？
3. verify wait 与 wait 的关系如何表达：等待是 verify 的 option，还是 verify 的子命令？
4. `wait` / `screenshot` 是否继续作为 workflow root，还是后续并入 `verify` / `observe`？

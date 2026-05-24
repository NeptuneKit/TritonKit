# AGENTS 执行规范（TritonKit 精简可执行版）

## 0. 路径规范（不可删）

以下目录结构为长期约束，后续修改 `AGENTS.md` 时不得删除，只能增补：

```text
.
├── MEMORY.md          # 主记忆文件（过期，后续改为 docs-linhay/memory/MEMORY.md）
├── AGENTS.md          # 行为规则，可按任务优化但需保留路径规范
├── references/        # 参考项目目录（过期，后续改为 docs-linhay/references/）
├── screenshots/       # 截图测试目录（过期，后续改为 docs-linhay/screenshots/）
├── docs-dev/          # 项目文档系统（过期，后续改为 docs-linhay/）
├── memory/            # 每日日志目录（过期，后续改为 docs-linhay/memory/）
└── docs-linhay/       # 项目文档系统目录：开发计划、需求文档、技术文档等
    ├── spaces/        # 以 feature / topic / milestone 为单位的工作空间根目录
    │   └── <space-key>/
    │       ├── README.md      # 当前 space 的需求背景、目标、范围、验收标准
    │       ├── plans/         # 开发计划、迭代规划、里程碑
    │       ├── screenshots/   # 截图，按日期/模块分层存放
    │       └── debate/        # 多 agent 辩论文档，按日期和主题分层存放
    ├── dev/           # 研发文档（架构、技术方案、测试策略、数据字典等）
    ├── features/      # 需求与功能规格（旧入口，后续优先使用 spaces）
    ├── memory/        # 记忆系统（MEMORY.md + 每日日志）
    ├── plans/         # 项目级开发计划、里程碑（非单个 space）
    ├── references/    # 参考项目、外部资料归档
    ├── screenshots/   # 跨 space 或临时截图归档
    ├── scripts/       # 自动化脚本及其说明文档
    └── debate/        # 跨 space 的多 agent 辩论文档
```

补充约束：

1. `docs-linhay/spaces/` 是后续新需求的正式落位；`docs-linhay/features/` 保留为历史/项目级规格入口，不再优先新增单需求文档。
2. `<space-key>` 采用可追踪英文 slug，优先使用 `<YYYYMMDD>-<topic>` 或稳定功能名，禁止空格、中文、`latest`、`final`。
3. 每个 `space` 的入口文档固定为 `README.md`。
4. feature 开发用 Git `worktree` 不放在仓库目录内，统一放在主仓库同级目录 `../TritonKit-worktrees/`。
5. 单个 feature `worktree` 推荐路径为 `../TritonKit-worktrees/<space-key>/`；默认与对应 `space` 共享同一个 `<space-key>`。
6. `worktree` 是临时执行环境，`space` 是长期文档资产；需求完成后可删除 `worktree`，不得删除对应 `space` 历史。
7. 单个 `space` 的单期设计稿默认只保留一个 HTML 文件；若存在多稿对比，也必须收敛在同一个 HTML 文件内，不为同一期拆分多个 `option-*.html`。

## 1. 全局原则

1. BDD + TDD 必须先行：先场景与验收标准，再失败测试，再实现。
2. 全程中文沟通。
3. 小步提交、可回归验证，避免大块不可控改动。
4. E2E 场景覆盖核心功能，单元测试覆盖边界条件。
5. 文档与记忆同步更新，保持信息一致性。
6. 任何改动都要考虑对后续维护者的可理解性和可操作性。
7. TritonKit 是 `CLI + HTTP server + Wails Web + 桌面壳` 组合应用；任何改动都要明确影响的是 CLI、HTTP transport、Wails binding、Web 前端、桌面壳，还是共享 core。
8. TritonKit 优先供 AI agent 和自动化脚本使用与控制；CLI 和 HTTP 管理 API 是业务控制的事实入口，所有状态读取、动作执行、解释、回归验收和审计都必须优先具备机器可读契约。
9. AI agent 首期不需要 Web 端；能通过 CLI/HTTP 机器可读契约完成读取和控制的需求，不新增 Web/SSE 渲染入口。
10. 当前 emulator 接管产品边界是本机 CLI + 本机模拟器/仿真器：iOS Simulator、Android Emulator、HarmonyOS / DevEco Emulator；默认不做真机、远端 agent、设备云、Web/Wails UI、对外 HTTP 产品面、Postgres/Kafka/Webhook、多租户或内置 VLM loop，除非单独新建 `space` 重新定义边界。
11. TritonKit 必须使用独立端口组：HTTP 管理 API `127.0.0.1:19421`、Wails dev server `localhost:34126`、Vite dev server `127.0.0.1:34127`、Vite preview server `127.0.0.1:34128`；前端 dev/preview 必须启用 `strictPort`，禁止默认落到 `5173`、`5174`、`4173` 等常见端口。
12. 当前没有活跃 Web / 前端页面；任何恢复前端体验的工作必须先重新建立 `space`、需求边界、BDD 场景、技术栈和验收方式，不预设执行方或历史设计方向。
13. 前端改动若影响后端接口、领域模型或关键交互闭环，必须先明确 CLI/HTTP 契约、状态流转、测试门禁和回归验收，避免由 UI 先行定义业务控制能力；确需人类展示时，Web/Wails 默认只消费只读 DTO，不承载 create/update/delete/execute/approve/deny 等业务控制闭环。
14. 当一次会话中出现“有用且重复出现”的行为模式、排障路径或交付动作时，必须先识别复用边界，再优先新增或更新项目级 `skills`；只有当规则已经上升为 repo-wide、长期稳定的约束时，才同步更新 `AGENTS.md`。
15. 当用户明确说“整理”且语境指向刚完成的一轮工作会话时，默认触发一次会话沉淀流程：先按 `tritonkit-session-skill-distill` 提炼可复用模式，再按是否 repo-wide 决定是否同步更新 `AGENTS.md`、`docs-linhay/dev/`、`docs-linhay/memory/`，并执行 `qmd update` 与 `qmd embed`。
16. 多份独立需求稿并行推进时，默认按“一个需求单元一个 `space`，必要时再配一个同 key 的 branch 与 `worktree`”组织，不按个人姓名或临时阶段单独命名工作目录。
17. 当用户明确要求“由 subagent 去做、主控 agent 负责监督”时，主控 agent 必须承担需求边界、任务拆分、集成、验收、文档与最终完成判断，不得在“代码已改完”但截图、实机验证、文档写回等验收环节仍未完成时提前停止。
18. GitHub CI / Release 产物最终必须包含 macOS arm64 / x86_64 `triton` CLI 包、checksum manifest 和对外项目级 skill 包，至少覆盖 `.agents/tritonkit-skills/public/tritonkit-dev-feedback`、`.agents/tritonkit-skills/public/tritonkit-real-project-regression` 与 `.agents/tritonkit-skills/public/tritonkit-emulator-cli-takeover`，确保使用者能同时拿到命令行工具、开发阶段反馈工作流、真实项目回归流程和本机模拟器 CLI 接管流程。
19. `triton` CLI 必须支持 Homebrew 二进制安装与更新；tag release 后先以 arm64 CLI 包、skill 包和 checksum manifest 创建 GitHub Release 并更新 tap formula，x86_64 包由 Intel runner 后补上传并再次刷新 checksum / tap，避免 x86 runner 阻塞 Apple Silicon 发布。
20. 作为 Package Manager 依赖提供给业务 App 时，embedded TritonKit runtime 只在 `DEBUG` 编译配置下生效；Release 下必须保持可编译但不连接、不采集、不上传、不响应控制，不按 iOS/macOS 或 UIKit 可导入性作为启停边界。
21. 业务 App 侧 iOS 接入文件必须使用独立 Debug bootstrap 文件，并用文件级 `#if DEBUG` 包住 `import TritonKit` 与 `TritonKit.shared.start()` / `start { config in ... }` facade；AppDelegate、SceneDelegate 或 SwiftUI 入口只保留 `#if DEBUG` 调用点，不能只依赖库内部 Release no-op。只有需要自定义 delegate 或消息路由时才使用低层 `delegate` / `connect(host:port:)`。
22. SwiftPM / Xcode package product dependency 没有 CocoaPods-style Debug-only 配置开关；对外接入指南必须明确：默认走源码级 `#if DEBUG` bootstrap + Release no-op runtime，若生产 Release target 必须完全不链接 TritonKit，则使用独立 Debug-only app target / scheme。
23. Package Manager 分发入口同时覆盖 SwiftPM 与 CocoaPods；CocoaPods 必须保持 `TritonKitShared` 与 `TritonKit` 两个 module 边界，CI 需校验 podspec 可 lint。
24. SwiftPM 根 `Package.swift` 只描述业务 App 可依赖的 embedded SDK product，不声明 `triton` CLI executable、不声明 Hummingbird / ArgumentParser 等 CLI-only package dependencies；macOS CLI 统一由 `CLI/Package.swift` 构建，命令为 `swift build --package-path CLI --scratch-path .build/cli -c release --product triton`，避免 iOS App 解析 SwiftPM 时拉入 CLI 依赖。
25. Swift 源文件超过 1500 行即进入治理范围；新增或扩展 CLI 能力时，默认按 `*Commands.swift`、`*Runtime.swift` / `*Service.swift`、`*Models.swift` 拆分，入口文件只保留 root command 注册与少量共享 glue，禁止继续把新子命令和 wire model 堆回巨型文件。

## 2. 标准工作流（必须）

1. 明确需求边界与验收条件。
2. 先补测试并确认失败（红灯）。
3. 最小实现让测试通过（绿灯）。
4. 必要重构并保持测试通过。
5. 更新相关文档与记忆。
6. 若本次任务提炼出可复用的项目动作、流程或知识边界，新增或更新对应 `skills`；若同时形成长期稳定规则，再更新 `AGENTS.md`。
7. 若用户以“整理”作为收尾指令，且本轮存在稳定可复用模式，不需要额外追问是否沉淀，直接进入 `skills` / `AGENTS` / docs / memory 的整理流程。
8. 若某个需求将进入并行开发、多日实现或与其他需求同时切换，先补齐对应 `space`，再创建同 key 的 branch / `worktree`。
9. 若需求采用 `subagent` 交付，标准完成顺序必须覆盖：需求边界确认、subagent 分工、主控集成、自动化验证、Wails/桌面验收（如适用）、HTTP/CLI 验收（如适用）、截图或其他验收产物、文档与记忆写回；未跑完这一整链，不得宣称需求完成。

## 3. 测试门禁（必须）

1. 任何功能改动都要有对应测试（新增或更新）。
2. 未运行测试时必须明确说明原因与风险。
3. 禁止“只改代码不验证”。
4. Go 代码默认验证命令为 `go test ./...`。
5. CLI 行为优先测试参数解析与命令分发；只有验证真实监听、信号和 graceful shutdown 时才启动进程级测试。
6. HTTP handler 优先使用 `httptest` 覆盖 route、method、headers、JSON body 和错误。
7. Wails 绑定先测绑定对象和 DTO；涉及真实窗口、菜单、图标、原生能力时再做桌面验收。
8. 纯文档或治理规则调整若无可执行测试，至少要完成结构自检、路径校对与引用校对，并在交付说明中明确写明“未运行自动化测试”的原因。
9. 本仓库默认本地门禁入口是 `docs-linhay/scripts/verify.sh --local`；CI validate 先用 `docs-linhay/scripts/ci-validate-mode.sh` 分类，docs/skill-only 走 `docs-linhay/scripts/verify.sh --ci-docs`，CLI/test/SwiftPM-only 走 Swift tests、CLI release build 与 release/homebrew 契约检查并跳过 podspec lint，workflow/release 脚本类只跑契约检查，`Sources/TritonKit/` 只跑 `TritonKit.podspec` lint，Shared/iOS/未分类改动在 CI 中并行跑 Swift tests、两个 podspec lint 和 release/homebrew 契约检查；本地仍用 `docs-linhay/scripts/verify.sh --ci-validate` 串行复现完整门禁。
10. 普通 `main` push / PR 的 CI 只阻塞 validate；CLI、skill 包、checksum 与 release asset 打包只在 `v*` tag 或手动 `workflow_dispatch` 执行；tag 发布时 arm64 资产先发布，x86_64 资产后补。

## 4. 文档系统规则（docs-linhay）

`docs-linhay/` 是项目文档系统目录，按类型分文件夹：

1. `docs-linhay/spaces/<space-key>/README.md`：单个需求空间的背景、目标、范围、验收标准、相关链接。
2. `docs-linhay/spaces/<space-key>/plans/`：该需求空间下的开发计划、迭代规划、里程碑。
3. `docs-linhay/spaces/<space-key>/screenshots/`：该需求空间下的截图归档。
4. `docs-linhay/spaces/<space-key>/debate/`：该需求空间下的多 agent 辩论文档。
5. `docs-linhay/dev/`：研发文档、技术方案、治理说明。
6. `docs-linhay/features/`：项目级需求与功能规格旧入口；新单需求优先放 `spaces`。
7. `docs-linhay/plans/`：项目级计划和里程碑；单需求计划优先跟随对应 `space`。
8. `docs-linhay/memory/`：记忆系统（`MEMORY.md` + 每日日志 `YYYY-MM-DD.md`）。
9. `docs-linhay/references/`：参考项目、外部资料归档。
10. `docs-linhay/scripts/`：自动化脚本及其说明文档。
11. `docs-linhay/screenshots/`：跨 space 或临时截图；任务结束前尽量归档回对应 `space`。
12. `docs-linhay/debate/`：跨 space 的辩论资料；单需求 debate 优先跟随对应 `space`。

Git `worktree` 治理：

1. `space` 负责需求背景、计划、截图、辩论和验收；`worktree` 只负责该需求的代码执行上下文。
2. 默认映射为：`space = docs-linhay/spaces/<space-key>/`、`branch = feat/<space-key>`、`worktree = ../TritonKit-worktrees/<space-key>/`。
3. 只讨论、不落代码的需求稿只建 `space`，不建 `worktree`。
4. 一次性小修或当天即可完成的短改动，可直接在主工作区开短分支，不强制建 `worktree`。
5. 会并行推进、会持续多天、会频繁切换上下文的需求，必须使用独立 `worktree`。
6. release、打包、一次性验证类短命工作区可继续放在 `/private/tmp/`，但常规 feature `worktree` 不得放在 `/tmp`。
7. 禁止在主仓库目录内嵌套创建 feature `worktree`，避免污染搜索、索引和脚本扫描范围。
8. 合并完成后删除对应 `worktree`，保留 `space` 文档、截图、计划和 debate 历史。

设计稿治理：

1. 设计稿 HTML 默认落在对应 `space` 根目录，作为该期视觉/交互方案的唯一入口。
2. 单个 `space` 的单期设计稿只保留一个 HTML 文件，文件名应语义化且可追踪，例如 `dashboard-design-v01.html`。
3. 同一期内若需要展示多方案对比、多个状态或多个区域稿，统一放在同一个 HTML 文件中，用分节、锚点或标签页组织，不再拆成多个平行 HTML 文件。
4. 只有跨期迭代时才允许新增下一版 HTML，例如从 `*-v01.html` 演进到 `*-v02.html`；同一期内禁止出现 `option-a/b/c` 平行文件。
5. 既有多 HTML 设计稿视为历史遗留；后续新增或重构时按本规则收敛，不要求本次治理整理顺手迁移所有旧稿。

文档落位硬约束：

1. 需求变更先写对应 `space`，再改代码。
2. 技术方案和治理说明放 `docs-linhay/dev/`。
3. 截图、计划、辩论材料必须跟着对应 `space` 走。
4. 外部参考资料统一归档到 `docs-linhay/references/`。

项目级 skills：

1. TritonKit-owned skill 源码统一放在 `.agents/tritonkit-skills/`：`public/` 只放对外发布并进入 `tritonkit-skills.tar.gz` 的 skill，`internal/` 只放 repo 治理、实现、监督和规划用 skill；`.agents/skills/` 只保留 symlink 作为本地 agent 发现入口，不作为 release packaging 源。
2. 涉及 CLI、HTTP 服务分层、Wails Web、桌面壳、路由、中间件、配置或接口测试时，优先使用 `tritonkit-http-service-engineering`，并确认业务控制能力优先落在 CLI/HTTP，而不是 Web/Wails。
3. 当前没有活跃 Wails/Web UI 或默认设计语言；涉及恢复前端页面、设计稿或交互验收时，先使用 `tritonkit-design-system` 确认空白基线与重新建 space 的边界。
4. 涉及 `space` 创建、命名、README 模板、截图或 debate 归档时，优先使用 `tritonkit-ops-governance`。
5. 涉及文档写回、memory 写回、`qmd update` / `qmd embed` 同步时，优先使用 `tritonkit-ops-governance`。
6. 涉及 AGENTS 级长期治理规则时，优先使用 `tritonkit-ops-governance`；若用户明确说“整理”，同时使用 `tritonkit-session-skill-distill`。
7. 涉及长期计划、自动巡航、提前巡航、无人值守推进、离开一段时间让 agent 自主进化或巡航收尾时，优先使用 `tritonkit-autonomous-cruise`，并坚持小切片、checkpoint、验证、报告、memory/qmd 与本地提交闭环；默认不 push、不 tag、不 release。
8. 涉及“主控 agent 监督、subagent 实做、直到完整需求闭环才停止”的执行模式时，优先使用 `tritonkit-subagent-supervision`。
9. 涉及从 demo/self-test 切到真实 iOS App 或客户项目回归、试接入、实际需求发现时，优先使用 `tritonkit-real-project-regression`，并隔离外部仓改动、保留 CLI/HTTP 机器可读证据。
10. 涉及设计、实现、扩展或验证三端本机模拟器/仿真器 CLI 接管能力（iOS Simulator、Android Emulator、HarmonyOS / DevEco Emulator、target discovery、App lifecycle、readiness、screenshot、AX/layout、logs、command ledger、evidence、destructive policy）时，优先使用 `tritonkit-emulator-cli-takeover`，并确认产品边界仍是本机 CLI、无 Web、无真机、无远端 agent。
11. 涉及设计、实现、扩展或验证 host-side Apple Simulator 接管能力（`triton sim`、`triton app`、`xcrun simctl` 封装、workspace simulator defaults、boot wait JSONL、App metadata/container/preferences、host artifacts、plan/evidence 集成）时，优先使用 `tritonkit-host-simulator-takeover`，并确认 agent 面对的是 Triton CLI/HTTP schema，而不是裸 `xcrun`。
12. 涉及设计、实现、扩展或验证 Xcode workflow takeover 能力（project/workspace discovery、scheme/build settings、`xcodebuild` build/test/run、`.xcresult`、coverage、logs、SwiftPM、真机/macOS workflow、LLDB、host UI 集成，或评估 XcodeBuildMCP 能力取舍）时，优先使用 `tritonkit-xcode-workflow-takeover`，并坚持“吃能力，不吃 XcodeBuildMCP 对外 API”。
13. 涉及 Xcode project/workspace 发现、scheme 列表、build settings、`xcodebuild build/test` 或 build-install-launch 时，默认优先使用 `triton xcode`；只有 `triton schema --command xcode --json` 未暴露所需能力或当前实现明确不足时，才临时回退 XcodeBuildMCP 或裸 `xcodebuild`，且回退原因必须写入交付说明。

## 5. 记忆系统规则（必须）

### 5.1 Retrieval（查询）

查询历史信息时，禁止先全量读取 `docs-linhay/memory/MEMORY.md` 或 `docs-linhay/memory/*.md`。按顺序执行：

1. `qmd query "<问题>"`
2. `qmd get <file>:<line> -l 20`
3. 仅当 `qmd` 无结果时，才回退直接读文件

### 5.2 Writeback（写回）

出现以下情况必须写入记忆：关键决策、行动项、偏好变化、里程碑、风险结论。

1. 写入 `docs-linhay/memory/YYYY-MM-DD.md`
2. 执行 `qmd update && qmd embed`
3. 每周合并到 `docs-linhay/memory/MEMORY.md`（只保留稳定高价值信息）

### 5.3 Collection 管理

`qmd` 需支持自动建立 collection，规则如下：

1. 首次在项目中执行 `qmd update` 时，若 collection 不存在，自动创建。
2. collection 名称与项目目录名保持一致。
3. 跨项目查询时，通过 `qmd query --collection <name> "<问题>"` 指定 collection。
4. CI/CD 环境中应跳过 collection 初始化（通过环境变量 `QMD_SKIP_INIT=1` 控制）。

## 6. 文档工具（推荐）

1. 新建 `space` 时优先使用 `docs-linhay/scripts/create-space.sh <space-key>`。
2. 提交前或调整治理规则后，运行 `docs-linhay/scripts/check-docs.sh` 做结构校验。
3. 新建 feature `worktree` 时，默认使用 `git worktree add ../TritonKit-worktrees/<space-key> -b feat/<space-key> main`；若当前集成分支不是 `main`，以当轮基线分支替换末尾参数。
4. 采用 `subagent` 交付的需求，主控 agent 收尾前默认补做一次 DoD 自检：测试、HTTP/CLI 验收、Wails/桌面验收、截图、文档、memory、`qmd`、必要时 `check-docs.sh`。

## 7. 完成定义（DoD）

1. 验收场景满足。
2. 相关测试通过，或已说明阻塞、未测原因与风险。
3. 文档已更新到正确目录。
4. 有意义变更已写入记忆并可检索。
5. 若本次工作产生了可复用且重复出现的行为模式，已完成对应 `skills` / `AGENTS.md` 的新增或更新，或已明确说明为何暂不沉淀。

## 8. 截图规范

截图统一优先存放在对应 `space` 的 `screenshots/` 下；跨 space 或临时截图可暂存 `docs-linhay/screenshots/`。命名格式：

`<YYYYMMDD>-<模块>-<场景>-<状态>-v<序号>.png`

字段说明：

- `YYYYMMDD`：拍摄日期，如 `20260513`
- `模块`：功能域，如 `cli`、`http`、`desktop`、`web`
- `场景`：操作或用例关键词，如 `empty-state`、`healthz`
- `状态`：`before` / `after` / `baseline` / `failed`
- `序号`：两位起，如 `01`、`02`

补充规则：

1. 禁止使用中文文件名、空格、`latest`、`final` 等不可追踪命名。
2. 同一改动至少保留一组 `before` 与 `after`，用于回归对比。
3. 多端截图在场景后追加端标识：`-macos` / `-web` / `-cli`。
4. 同一次需求/修复的截图尽量放在同一日期目录下。
5. 跨天续测时，新日期新目录，不覆盖旧图。
6. 若模块不明确，暂存到对应截图目录的 `misc/`，任务结束前必须归档。

## 9. Debate 规范

多 agent 争论的文档优先存放在对应 `space` 的 `debate/` 下；跨项目治理争论可存放 `docs-linhay/debate/`。命名格式：

`<YYYYMMDD>-<主题>-v<序号>.md`

内容要求：

1. 辩论背景：简要描述辩论起因和上下文。
2. 参与者观点：列出每个参与者的观点和理由，并标注名字。
3. 多轮辩论按时间顺序记录观点变化。
4. 结论与行动项：总结结果并明确后续计划。
5. 语言要求：全程中文，保持专业和尊重。
6. 任何人都可以参与补充观点，但必须注明时间和内容来源。

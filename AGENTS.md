# TritonKit AGENTS（精简可执行版）

> 本文件只保留跨任务、长期稳定的硬约束；具体实现、发布和排障步骤写入匹配的项目 skill 或 `docs-linhay/dev/`。

## 0. 路径规范（不可删）

以下目录结构为长期约束；后续修改只能增补，不得删除其中的路径节点。

```text
.
├── MEMORY.md          # 主记忆文件（过期，后续改为 docs-linhay/memory/MEMORY.md）
├── AGENTS.md          # 行为规则
├── references/        # 参考项目目录（过期，后续改为 docs-linhay/references/）
├── screenshots/       # 截图测试目录（过期，后续改为 docs-linhay/screenshots/）
├── docs-dev/          # 项目文档系统（过期，后续改为 docs-linhay/）
├── memory/            # 每日日志目录（过期，后续改为 docs-linhay/memory/）
└── docs-linhay/       # 项目文档系统目录
    ├── spaces/        # 以 feature / topic / milestone 为单位的工作空间根目录
    │   ├── README.md  # space 路线总览：状态、当前队列、worktree 与历史归档
    │   ├── INDEX.md   # space 编号索引：SP 编号、兼容目录与迁移进度
    │   └── <space-key>/ # 新 space 的 key 固定为 SP-<三位序号>-<topic>
    │       ├── README.md
    │       ├── plans/
    │       └── screenshots/
    ├── dev/           # 架构、技术方案、测试策略、治理说明
    ├── features/      # 历史 / 项目级需求入口
    ├── memory/        # MEMORY.md + 每日日志
    ├── plans/         # 项目级计划
    ├── references/    # 外部资料归档
    ├── screenshots/   # 跨 space 或临时截图
    └── scripts/       # 自动化脚本
```

### Space、worktree 与文档

1. 新需求先建立 `space`：规范名为 `SP-<三位序号>-<topic>`，序号全局递增且不复用；topic 为小写英文 slug，禁止空格、中文、`latest`、`final`。
2. 历史日期 slug 目录以 `docs-linhay/spaces/INDEX.md` 为映射事实源；不得在普通任务中直接重命名。
3. 每个 space 以 `README.md` 记录边界、BDD、验收和链接；新建、状态变化、worktree 集成或收口时同步更新 `INDEX.md` 与 `spaces/README.md`。
4. 默认映射：`space = docs-linhay/spaces/SP-<三位序号>-<topic>/`、`branch = feat/SP-<三位序号>-<topic>`、`worktree = ../TritonKit-worktrees/SP-<三位序号>-<topic>/`。
5. 多日、并行或频繁切换的 feature 必须使用同级独立 worktree；短小当天修复可在主工作区完成。不得在仓库内嵌套 worktree 或把常规 feature 放入 `/tmp`。
6. 设计稿放在对应 space 根目录；同一期只保留一个 HTML 文件，多方案在同一文件内组织。截图优先归档到该 space 的 `screenshots/`，文件名为 `<YYYYMMDD>-<模块>-<场景>-<状态>-v<序号>.png`。

## 1. 基础工作方式

1. 全程中文沟通；先明确影响层（CLI、HTTP、Wails binding、Web、桌面壳或 shared core）与验收边界。
2. 坚持 BDD + TDD：先场景和失败测试，再最小实现、重构和回归。每项功能改动都应有测试；未测必须说明原因、风险与下一步。
3. CLI/HTTP 是 AI agent 和自动化脚本的事实入口：状态、动作、解释、验收和审计优先提供机器可读契约。能以 CLI/HTTP 完成的能力不新增 Web/SSE 控制面。
4. `Web/` 仅是 React/Vite mock 原型；正式 Web/Wails 能力必须先更新 space、契约、状态流和验收。展示层默认只消费只读 DTO，不承载业务写操作。
5. 有副作用或共享状态的操作串行执行：git 提交/合并/推送、同一 scratch build/test、服务启停和设备动作不得并发抢占。
6. 可复用流程优先更新现有 skill；只有 repo-wide 且长期稳定的规则才进入本文件。

## 2. Subagent 与并行

1. 对可安全拆分、预计能明显提升速度或质量的任务，主控 agent 应主动使用 subagent；用户无需逐项授权。
2. 简单任务、同一文件的紧耦合改动、共享环境或副作用冲突的操作保持单 agent 或串行执行。
3. 主控始终负责需求边界、拆分、集成、冲突处理、验证、文档、memory 和最终 DoD；subagent 的“完成”只是证据，不是完成判定。
4. 每个写入型 subagent 必须有明确文件面、非目标、验证命令和停止条件；不同 agent 不得同时拥有同一实现文件。多 issue 默认一 issue 一 space / branch / worktree。
5. 主控可自行创建、分批调度、改派、停止或续跑 subagent；仅在需求边界变化、破坏性操作、权限/环境 blocker 或用户取舍时打断用户。
6. 远端写入（push、PR、merge、tag、release、关闭 issue）仍须有用户明确授权；不要把未完成并行工作混入主分支或发布。

## 3. 验证、文档与安全

1. Go 默认运行 `go test ./...`；CLI 优先测参数解析与分发，HTTP 优先用 `httptest`，Wails 先测 binding / DTO，再做桌面验收。
2. 本地总门禁是 `docs-linhay/scripts/verify.sh --local`；docs/skill-only 改动至少运行 `docs-linhay/scripts/verify.sh --ci-docs`、`docs-linhay/scripts/check-docs.sh` 和 `git diff --check`。
3. 需求变更先写对应 space；技术方案进 `docs-linhay/dev/`，每日结论进 `docs-linhay/memory/YYYY-MM-DD.md`，长期规则进 `MEMORY.md`。用户说“整理/沉淀”时执行会话沉淀；只有明确说“提交”才自动创建整理提交。
4. 不覆盖或重置用户已有改动；禁止未经确认的破坏性命令。公开 issue、日志、截图和证据必须脱敏私有工程、身份与凭据。

## 4. TritonKit 产品与平台边界

1. 当前产品是 `CLI + HTTP server + Wails Web + 桌面壳`；emulator 接管默认只覆盖本机 iOS Simulator、Android Emulator 与 HarmonyOS/DevEco Emulator。真机、远端 agent、设备云、对外 HTTP 产品面和多租户能力须另建 space。
2. 端口固定：HTTP `127.0.0.1:19421`、Wails dev `localhost:34126`、Vite dev `127.0.0.1:34127`、Vite preview `127.0.0.1:34128`；前端必须 `strictPort`。
3. 模拟器/仿真器操作必须 Triton-first：先保存 `triton status/doctor/capabilities/schema/plan --json` 的事实；只有 Triton 失败、unsupported 或未覆盖时才能回退 `xcrun`、`adb`、`hdc`、XcodeBuildMCP 等，并记录原因与命令。
4. Xcode 工作流优先 `triton xcode`；真实回归优先 `triton evidence capture --json`。机器可读失败输出必须保持单一合法 envelope，不二次包装。
5. iOS embedded runtime 以 `TRITONKIT_RUNTIME_ENABLED` 控制：Debug 可启用，Release 必须可编译但不连接、不采集、不响应。App 接入使用独立 `#if DEBUG` bootstrap；SwiftPM 根包不引入 CLI-only 依赖。

## 5. 发布与维护

1. 发布、Homebrew、SwiftPM/CocoaPods、public skills、checksum 和双架构 CLI 的详细流程使用 `tritonkit-release-package-governance`；已发布 tag 不移动，缺漏走下一 patch。
2. Release 产物至少包含 macOS arm64/x86_64 `triton`、checksum manifest 与由 `docs-linhay/scripts/package-public-skills.py` 生成的 `tritonkit-skills.tar.gz`（含 `TritonKit.skills/BUILD_INFO.json`）。
3. 新增配置覆盖默认值、环境变量和非法值；新增外部依赖说明必要性。Swift 源文件超过 1500 行时按 Commands / Runtime(or Service) / Models 拆分。

## 6. Skill 路由与完成定义

1. 涉及 space、文档、memory 或整理时使用 `tritonkit-ops-governance`；subagent 监督使用 `tritonkit-subagent-supervision`；设备接管、Xcode、release、Web mock 和真实项目回归使用对应专用 skill。
2. DoD：验收场景满足；匹配的测试/验证已通过或已说明风险；CLI/HTTP、桌面、截图/evidence 按适用范围验收；space、索引、文档和 memory 已写回；可复用模式已沉淀。

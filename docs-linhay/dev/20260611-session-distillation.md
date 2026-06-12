# 20260611 Session Distillation

## 沉淀范围

本轮整理来自三类工作：

- 三端 single-device Web preview 与 Web mock UI 的工程化验证。
- Open Design 本地 `od` CLI / plugin 安装验证。
- 用户要求“实现完成再统一测试调整、先分段提交、整理沉淀提交”的协作节奏。

## 可复用模式

### Web mock UI 工程化路径

后续 TritonKit Web mock 工作默认走以下路径：

1. 先创建或更新 `docs-linhay/spaces/<space-key>/README.md`，写清范围、BDD、验收和非目标。
2. 用 `Web/` 作为可追踪 React / TypeScript / Vite mock 工程。
3. Vite dev / preview 固定使用项目端口：`127.0.0.1:34127` / `127.0.0.1:34128`，并启用 `strictPort`。
4. Web 只消费 mock DTO 或只读 DTO；CLI / HTTP 仍是业务控制事实入口。
5. 用浏览器验证首屏、console、目标切换、横向溢出和截图证据。
6. 截图保存在对应 space 的 `screenshots/`，但按当前 ignore 策略不进入 git。

本模式已沉淀为内部 skill：`.agents/skills/tritonkit-web-mock-ui/SKILL.md`。

### Open Design 本机验证边界

本机 `od` CLI 可用，验证到的稳定结论：

- `od status --json` 是当前机器更可靠的健康检查。
- 系统 `curl` 不支持 `od://` scheme，因此不能把 `curl -s od://app/api/health` 当作唯一检查。
- `od plugin validate /path/to/skill --json` 可验证 Claude-compatible `SKILL.md` 目录。
- `od plugin install --source /path/to/skill --json` 可把本地 skill 装进 Open Design plugin registry。
- `od plugin info <id>` 与 `od plugin doctor <id>` 是安装后验证入口。
- `od 0.9.0` 下本地 skill 安装成功后，不一定立即出现在 `od skills list/show`；需要重启 app 或等待 catalog 刷新时，不能误判安装失败。

该结论已写入个人级 `open-design` skill，并同步安装到本机 Open Design plugin registry。该 skill 位于用户目录，不属于 TritonKit 仓库提交范围。

### 分段提交与集中验证节奏

用户明确要求“实现完成再统一测试调整、先分段提交”时，后续执行默认按切片推进：

1. 先完成一个完整切片内的代码、测试、schema、文档、memory 和 skill 一致性改动。
2. 再集中跑 focused tests、必要 schema tests、完整回归、`git diff --check`、qmd 同步和 docs check。
3. 若验证失败，在同一切片内集中修复后重跑相关门禁。
4. 切片验证完成后立即只 stage 该切片相关文件并提交，不把并行 WIP、截图、临时产物或外部验证残留混入。

这不是放弃 TDD / BDD，而是避免“每改几行就停下来测试”的节奏拖慢多文件契约型需求。需要定位具体失败时，仍可临时回到更小粒度的红绿循环。

### 工具单飞边界

本轮出现过重复触发 qmd sync、同 scratch path SwiftPM 测试和提交类操作的风险，因此沉淀为内部治理规则：

- `git add/commit/tag/push/merge`、`docs-linhay/scripts/qmd-sync.sh`、会写同一 `--scratch-path` 的 SwiftPM build/test、启动/停止服务、以及会修改本机或模拟器状态的命令必须单飞。
- `multi_tool_use.parallel` 只用于只读文件读取、搜索、状态查看，或彼此完全独立且不共享输出目录的验证命令。
- qmd sync 若出现 `SQLITE_CONSTRAINT_PRIMARYKEY`、Metal embedding 编译输出或重复 embed 噪音，先确认是否有并发实例，等所有实例退出后单独重跑一次；整理提交只认最后一次单飞退出码。

该结论已写入内部 skill：`.agents/skills/tritonkit-ops-governance/SKILL.md`。

## 不纳入长期规则的内容

- 本轮的具体 Playwright snapshot 文件、临时 `/tmp/od-skills*.json` 和 dev server 输出不沉淀。
- 本轮的 `tritonkit-desktop.png` 不纳入本次整理提交；Web foreground App identity 兜底已按 Web mock 切片验收并随本次收尾提交。
- Open Design 内置插件的既有 doctor warning 不纳入 TritonKit 问题。
- Web mock 当前不升级为正式产品 UI，不改变 CLI / HTTP 控制边界。

## AGENTS 同步

本轮只同步 repo-wide 的状态变化：

- `Web/` 现在存在并可运行，但仅代表 mock 原型。
- 正式 Web/Wails 产品恢复仍必须先有 space、BDD 和边界。
- Web mock 工作优先走 `tritonkit-web-mock-ui`。

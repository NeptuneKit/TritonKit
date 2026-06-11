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

## 不纳入长期规则的内容

- 本轮的具体 Playwright snapshot 文件、临时 `/tmp/od-skills*.json` 和 dev server 输出不沉淀。
- Open Design 内置插件的既有 doctor warning 不纳入 TritonKit 问题。
- Web mock 当前不升级为正式产品 UI，不改变 CLI / HTTP 控制边界。

## AGENTS 同步

本轮只同步 repo-wide 的状态变化：

- `Web/` 现在存在并可运行，但仅代表 mock 原型。
- 正式 Web/Wails 产品恢复仍必须先有 space、BDD 和边界。
- Web mock 工作优先走 `tritonkit-web-mock-ui`。

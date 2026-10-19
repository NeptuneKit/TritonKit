# 2026-10-19 agents-revyl 上游只读检查

范围是 SP-207 indices 11..22（MobileBuildMCP、harness、ai-phone、eyes-on-my-phone、Revyl 8），比较基线为 2026-10-18 checkpoint/partial，绑定真实 TritonKit `main` `d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec` 与 SP-192、SP-196、SP-200、SP-203..SP-211。未运行上游代码、未安装依赖、未执行设备/签名/DDI，也未修改共享 state/docs/Git。

本轮用官方 Git `refs/heads/main` 读取固定 HEAD；对可用仓库用 GitHub Releases API `per_page=100` 完整分页（含 prerelease、排除 draft 后按 published_at 取最新），并从固定 HEAD 的官方 raw LICENSE 读取全文并保存 SHA256。变更仓库使用官方 Git 对象完整读取旧 checkpoint 到新 HEAD 的提交、文件清单、diff 与源码；Release notes 全文保存在对应 evidence 目录。GitHub API 在 visual-regression、figma-design-checker、CogniSim 开始 Release 请求时触发 rate limit，三仓 `complete=false`、旧 checkpoint 保留，`changed=null`，没有报告无变化。

| index | repository | old → observed HEAD | release | complete | decision |
|---:|---|---|---|:---:|---|
| 11 | getsentry/MobileBuildMCP | `d13ff0c7` → `d13ff0c7` | v2.7.1 | yes | covered |
| 12 | awizemann/harness | `3f58c077` → `3f58c077` | v0.8.4 | yes | covered |
| 13 | dongxinsuperman/ai-phone | `bd2781c1` → `4cac05b5` | v0.8.0 | yes | observe |
| 14 | karminski/eyes-on-my-phone | `eef71926` → `eef71926` | none | yes | covered |
| 15 | RevylAI/revyl-cli | `86de7c97` → `53a9e876` | v0.1.174 | yes | observe |
| 16 | RevylAI/app-explorer | `b3edc443` → `b3edc443` | none | yes | reject |
| 17 | RevylAI/greenlight | `fcb36e39` → `fcb36e39` | v0.2.0 | yes | reject |
| 18 | RevylAI/mobile-devtools | `efc1dae5` → `efc1dae5` | none | yes | reject |
| 19 | RevylAI/mobile-pr-reviewer | `ba1250c7` → `ba1250c7` | none | yes | reject |
| 20 | RevylAI/visual-regression | `2758e8a8` → observed same via git | API rate limit | **no** | reject (partial) |
| 21 | RevylAI/figma-design-checker | `8b4e5cea` → observed same via git | API rate limit | **no** | reject (partial) |
| 22 | RevylAI/CogniSim | `3d8902e0` → observed same via git | API rate limit | **no** | reject (partial) |

ai-phone 的 4 个提交（15 文件，+508/-16）新增 Harmony guest ABI 原生插件选择、`-noWindow` 能力探查与启动参数、Agent hello 前遗留消息丢弃及有界超时/洪泛保护，并补充回归测试和 E2E 诊断。v0.8.0 Release notes 是较早 JEV 点击定位功能；未发现可直接纳入 Triton CLI/HTTP 的候选，保留 observe。

revyl-cli 的 7 个提交（36 文件，+1204/-221）发布 v0.1.174：增加工作流持久化并发上限与单次运行 `--concurrency` 覆盖、Web 导航 `status_code` DTO、Capy proof project ID 契约和相应 API/schema/tests/docs。其变化属于 Revyl 专有服务/CLI，不改变 Triton 当前边界，保留 observe。其仓库固定 HEAD 未发现根 LICENSE，沿用上一轮“插件局部 MIT 声明”记录。

可复核证据：

- `.build/reference-monitor/20261019/agents-revyl/results.json`
- `.build/reference-monitor/20261019/agents-revyl/<repo>/head.txt`、`releases-1.json`、`releases-1.headers`
- 变更仓库：`dongxinsuperman__ai-phone/{commits.tsv,changed-files.tsv,diff-stat.txt,full-diff.patch,latest-release-notes.md}`；`RevylAI__revyl-cli/{commits.tsv,changed-files.tsv,diff-stat.txt,full-diff.patch,latest-release-notes.md}`
- 固定 HEAD 许可证全文位于各仓 evidence 目录的 `LICENSE`；无仓库级许可证的仓保存 `license-probe.json`（候选路径在固定 HEAD 全部 404）并保留旧 404 状态。完整 Git 对象镜像仅用于只读审阅，位于 `git/`。

候选仅报告不创建 space/thread；本轮没有 adopt。

# GitHub Issue #154：Public skill 命令层级与 CLI schema 对齐

> 状态：执行
>
> GitHub：[NeptuneKit/TritonKit#154](https://github.com/NeptuneKit/TritonKit/issues/154)
>
> Branch：`feat/20260720-issue-154-runtime-skill-command-hierarchy`
>
> Worktree：`../TritonKit-worktrees/20260720-issue-154-runtime-skill-command-hierarchy/`

## 背景

Issue 反馈一个名为 `tritonkit-runtime` 的已安装 skill 在 Triton CLI 0.2.8 下仍推荐 `triton find`、`triton ax`、`triton tap` 等已退役顶层命令。当前 CLI 的事实入口分别是 `triton act find/tap/...` 与 `triton debug ax`。

仓库与 release provenance 核对得到：

- v0.2.8 官方 `tritonkit-skills.tar.gz` 只含 `tritonkit-dev-feedback`、`tritonkit-emulator-cli-takeover`、`tritonkit-real-project-regression`、`tritonkit-update`，没有 `tritonkit-runtime`。
- v0.2.8 tag 与当前 Git 历史中都没有 `TritonKit.skills/tritonkit-runtime` 源码；该名称不能冒充当前官方 bundle 成员。
- 当前 public skills 已使用 `triton act ...` 与 `triton debug ax ...`，但打包流程只校验文件、版本和 metadata，不会拒绝未来重新引入的 retired root command。
- 当前 CLI schema 显示 `act` 子命令含 `find/tap/type/paste/clear/focus/set-text/input`，`debug` 子命令含 `ax`；这些事实必须成为 public skill 打包门禁，而不是只靠人工 review。

`docs-linhay/scripts/create-space.sh` 当前不存在，因此本 space 按固定模板直接建立并同步总索引。

## 范围

- 为 public skill 文档建立由当前 CLI schema 派生、受测试约束的 root/subcommand snapshot。
- 在 `package-public-skills.py` 写入 tarball 前扫描全部 Markdown 中的 Triton 命令；未知 root 或已知 group 下的未知 subcommand 必须失败，并给出 schema-backed 建议。
- `verify-skill-package.sh` 注入 `triton find` 与 `triton ax` 负向 fixture，证明打包器会拒绝旧命令层级；正常官方 bundle 仍可打包、安装。
- 更新 public bundle README，明确官方 skill 清单、`tritonkit-runtime` provenance 边界和 0.2.8+ 命令迁移表。
- 修正源码中仍声称顶层 action alias 可用的过期 help discussion，并用 CLI help 测试封口。
- 同步 release automation contract、研发文档与 memory。

不在本期范围：新增 `tritonkit-runtime` public skill、恢复旧顶层 alias、发布新 tag、移动 v0.2.8 tag、修改 CLI 业务执行语义。

## BDD 场景

### 场景 1：官方 public skill bundle 可打包

- Given 当前 `TritonKit.skills/` 与当前 CLI command snapshot
- When 运行 `package-public-skills.py`
- Then 所有 Markdown 中的 literal `triton` root/group command 都可从 snapshot 发现
- And tarball、版本 stamping、BUILD_INFO 与安装契约保持不变。

### 场景 2：旧顶层 action 命令阻断发布

- Given 临时 public skill source 含 `triton find "More" --json`
- When 运行打包器
- Then 非零退出，报告文件/行号与 unknown root `find`
- And 建议 `triton act find`。

### 场景 3：旧顶层 AX 命令阻断发布

- Given 临时 public skill source 含 `triton ax --json --with-hierarchy`
- When 运行打包器
- Then 非零退出并建议 `triton debug ax`
- And 不生成 release skill tarball。

### 场景 4：snapshot 不得漂移

- Given CLI 的 `commandSchemas()`
- When 运行聚焦 CLI contract test
- Then snapshot 的 root 与 subcommand 集合和 runtime schema 完全一致
- And CLI surface 变更必须同时更新 public skill command validation contract。

## 验收门禁

- 先添加 package negative fixture 与 schema snapshot test，并确认在 validator/snapshot 缺失时红灯。
- 聚焦测试、`verify-release-automation.sh`、`verify-skill-package.sh`、`verify.sh --local` 通过。
- `package-public-skills.py` 真实生成 tarball，解包后二次扫描通过。
- 文档、memory 与 space index 同步。
- 合入 `main`、GitHub Actions 成功后关闭 #154；本期不发布 tag。

## 实现与验证

- 红灯：`PublicSkillCommandSchemaTests` 因 snapshot 不存在失败；CLI help contract 证明源码仍声称 `triton tap` 顶层 alias 可用；`verify-skill-package.sh` 注入旧 `find/ax` 后仍成功产出 tarball。
- 绿灯：新增 `public-skill-command-schema.json`，CLI test 将其 roots/subcommands 与 `commandSchemas()` 全量比对；新增 Python scanner，打包前验证全部 public Markdown root，并严格验证 `act/debug` 子命令。
- Negative fixture 同时验证 unknown root 的文件/行号、`triton act find` / `triton debug ax` 建议和“失败时不留下 tarball”。
- 现有 public source 扫描发现唯一遗漏为 `triton geometry --json`，已迁移到 `triton debug geometry --json`；`TritonKit.skills/README.md` 明确官方 bundle 不含 `tritonkit-runtime` 且不承诺旧 alias。
- `PublicSkillCommandSchemaTests` 1 项、`CLIHelpTests` 7 项、`verify-skill-package.sh`、`verify-ci-validate-mode.sh` 与 `verify-release-automation.sh` 已通过。
- `docs-linhay/scripts/verify.sh --local` 全量通过：根包 226 项 Swift tests、release CLI build/smoke、Harmony/iOS runtime smoke、iOS Simulator build、docs 与 whitespace gate 均成功。
- 完整 CLI suite 运行 651 项；本期新增两个 suite 均通过，余下 21 个 issue 仍是既存 schema fact、暂停 testrec 与旧 xcode-use 断言基线。

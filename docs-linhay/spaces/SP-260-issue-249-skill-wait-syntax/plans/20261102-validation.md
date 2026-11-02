# #249 公开 skill wait 语法验证

## BDD 与边界

- Given 发布 skill 的完整 wait 示例，When 仅解析参数并替换平台/selector 占位符，Then `--text` 在 ios/android/harmony 均接受，`--device` 与 `--target` 保持同义；不调用 `run()`。
- Given 旧 `wait text "成功"`，When 安装的 0.2.38 CLI 解析，Then exit 64 且不会进入设备发现；加 `--timeout 0` 的修正版在任何设备操作前返回 validation_failed，证明已跨过 parser。
- Given 完整 fenced shell 示例有位置参数、未知选项或缺值，When 打包检查器检查，Then 拒绝；合法 flag/value/alias、引号、平台占位符及续行通过。
- 检查器的新增 argv 校验仅覆盖 wait 的完整 fenced 命令；正文中的 `triton wait --text` 等参数引用不作为可执行示例。不执行 shell、设备命令或连接服务。其他命令现有 root/subcommand 校验保持。
- 影响层为 public skill / 包装检查器 / parser 测试，无产品 runtime 改动。主控拥有全局索引、memory 与整合；本 worktree 不发布或写 Git。

## 验证结果

- RED：安装 Homebrew CLI 0.2.38，二进制 SHA256 `403375531681d36c3de2a24563278553db47b94c3a37e0564dc2587df50fc24d`。旧 `wait text __audit__` 返回 exit 64 / empty stdout / unexpected arguments；正确 `--text` 搭配 `--timeout 0` 返回 exit 1 / `validation_failed` / `--timeout must be greater than 0`，源码校验顺序保证在设备发现前退出。见 [原始响应](20261102-installed-cli-parser-red.json)。
- RED：新增 Python 8 tests 对原检查器运行，9 个断言失败，均为错误命令被接受；新增检查器后保持旧 skill 不变，仅官方示例检查失败，精确指向 `SKILL.md:87` 的 positional `text`。日志 `.build/issue249-evidence/python-red.log`、`python-skill-red.log`。
- GREEN：修正官方示例后，`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s docs-linhay/scripts/tests -p 'test_*public_skill*.py'` 通过 21 tests（原 installer 13 + 新 validator 8），exit 0。日志 `python-green.log`。
- GREEN：`bash docs-linhay/scripts/verify-skill-package.sh` 通过 21 tests、完整技能包内容/metadata 验证及既有 legacy-root 拒绝门禁，exit 0。日志 `skill-package.log`。仅本地临时包装验证，未发布。
- GREEN：从修正后的官方 Markdown 原行读取，用 `shlex.split` 仅替换平台/selector 与 selector alias；三个平台 × 两种 alias 在安装 CLI 0.2.38 中全都解析成功，并由追加 `--timeout 0` 返回前设备校验错误。见 [六组原始响应与 skill hash](20261102-installed-cli-example-green.json)。未操作或发现真实设备。
- PASS：`git diff --check`。
- FAIL（待联合登记）：`bash docs-linhay/scripts/check-docs.sh`、`bash docs-linhay/scripts/verify.sh --ci-docs` 都 exit 1，原因 `space index must contain exactly one link for SP-260-issue-249-skill-wait-syntax`。遵守分工不改全局索引；主控登记后须重跑，不能记为通过。日志 `check-docs.log`、`ci-docs.log`。
- 待执行：冻结候选的 `PublicSkillCommandSchemaTests` Swift suite（读取实际官方例、3 平台 × 2 alias 的 `parseAsRoot`、非法 argv 拒绝、参数 schema 同步）；等待主控 Swift 槽。完整 CLI / `--local` 聚合未运行。无 SDK/runtime 改动，设备验收不适用。

## 实现与可复用经验

`verify-public-skill-commands.py` 原先仅检查 command root 与少数 subcommand，不能据它通过宣称完整 argv 有效。本次仅对字面 `triton` 开头的完整 fenced wait 命令增加不执行 shell 的引号/续行/选项 arity 检查；正文的参数片段保留原 root 检查，不误认作完整命令。参数名与 alias 从现有 schema 快照登记，Swift 测试绑定当前 `commandSchemas()`；真实 parser 测试读取官方文本，避免仅重写一个正确示例掩盖文档回归。它不是任意 shell 脚本或 runtime 语义验证器。

原权威公开 skill 的 Common Agent Commands 已写明 flag 语法与有效 alias；无须新增 AGENTS 或重复经验条目。全局索引/memory 由主控收口。


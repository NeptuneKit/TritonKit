# #245 本地候选验收

影响层：CLI schema discovery 与权威参数声明。基线 `9b3dd90808ab4a58a927f777bf31f60559ced24c`，独立 worktree；尚未提交、合并或发布。无 server、设备动作或 VLM 模型调用。

## BDD 与测试

- RED：初始 `CompactSchemaTests` 编译退出 1，缺少 compact builder/flag；同基线 CLI 真实 argv 拒绝 `--compact`，退出 64。
- 初始 7 测试 GREEN 后主控发现 legacy selector 编码与 VLM option 声明缺口。保留真实进程 assertion RED；修订 source-scoped selectorConstraints、effective required override 和 authoritative test.run schema。
- 功能候选 `swift test --package-path CLI --build-system native --jobs 2 --no-parallel --filter CompactSchemaTests`：12/12 通过，exit 0；补齐类型正反例后的最终 compact 13 项随下述 137 项相关 schema focused 一起通过。覆盖 leaf 参数/alias、默认 full、dot/space hash、payload budget、安全继承、缺引用/歧义拒绝、三层 override、独立 ancestor alternatives、真实 app/runner selector、required override 自身引用与 VLM parse-only。
- 首轮完整 CLI：XCTest 162 项通过；Swift Testing 1673 tests / 176 suites，exit 1，共 3 个本次新增 schema 契约失败。新增 kind/error family 未登记，且类型检查仅接受一层数组而拒绝真实 `[[String]]`。原始 `cli-full.log` 保留，属于本次契约清单遗漏，不是历史噪音。主控授权精确登记 taxonomy 与严格递归数组检查，补正反例后，compact 13 项 + SchemaFactSource 124 项，共 137 项 / 2 suites focused 通过，exit 0（compact-schema-green-v3.log）。最终完整 CLI 复跑 exit 0：XCTest 162 项 / 0 failures；Swift Testing 1674 tests / 176 suites 通过，3 项既有条件跳过分别见下。命令为 `swift test --package-path CLI --build-system native --jobs 2 --no-parallel`；日志 `cli-full-v2.log`，未跳过失败用例。

## 真实进程验收

最终候选 JSON UTF-8 bytes（包含 CLI 末尾换行）：

| command | full | compact | compact/full |
| --- | ---: | ---: | ---: |
| act.type | 104181 | 26889 | 25.81% |
| test.run | 81228 | 28711 | 35.35% |

两命令均 exit 0；兄弟 options/contracts 未带入，root outputSemantics 保留原文。`test.run` full 比原版增加的是既有 parser 的 `--vlm-model-path` 与 `--vlm-allow-model-download` 权威声明；默认下载为 false，没有触发下载。字节改善不代表 runtime/网络延迟改善。

`app.launch`/`app.install` 与 `device.runner.tap`/`device.runner.type` 的 singleton-alternatives 已归一为一个 exactlyOneOf，不要求每个 singleton。多祖先的 complete sets 以 source 分开，不 flatten。dot/space selector 指纹一致。

缺 command、非叶子和未知命令均 exit 1，stdout 为一个合法 typed JSON，stderr 为空。compact + text 输出被明确拒绝；`--json` 沿用原有优先级。

## 证据与限制

原始日志与 full/compact JSON 位于持久归档 `TritonKit-worktrees/archives/SP256/`：`compact-red.log`、`compact-parser-red.*`、`compact-selector-red.log`、`compact-vlm-options-red.log`、`compact-green-v2.log`、`compact-v2-smoke.json`、`compact-v2-negative-smoke.json`、`compact-source-sha256.txt`、`compact-final-source-sha256.txt`、`compact-schema-green-v3.log`、`cli-full.log`、`cli-full-v2.log`。最终源码 SHA256 已在完整回归后回读校验；docs 结构门禁与 `git diff --check` 通过。

投影仅解析权威 schema，不代替命令 runtime validation 或配置 provider 状态探测。未声明 side effect 为 unknown；requires* 保守合并，false/none 不解除祖先安全要求。未解析 option/output selector 或有歧义的 legacy constraint 返回 compact_schema_incomplete，恢复到 full discovery，不能据此授权动作。无 UI/设备验收要求；本地完整 CLI 已通过；合并 CI 和发布阶段由主控闭环。

本轮经验已落实到同 Space 契约与 schema 输出声明：legacy alternatives 保留并归一化、跨层约束不混组、required override 与 alias/positional 统一解析。共享 dev/经验索引/memory 由主控收口。


## 条件跳过

以下是现有测试显式环境条件，不属于 #245 的只读 schema 改动验收；跳过不代表现场通过：

- `selectedXcodeProducesRealJPEGAndBalancesTwoSubscriptions`：未设置 `TRITON_SP196_OWNED_SIMULATOR`，没有占用或启动自有 Simulator。
- `Real NetService rejects an invalid service type and preserves failure`：未启用 `TRITON_TEST_BONJOUR=1`。
- `Real NetService publishes and withdraws only its own isolated service`：未启用 `TRITON_TEST_BONJOUR=1`，没有发布局域网服务。

主控暂存后 `git diff --cached --check` 发现新增resolver文件尾部多空行，已仅去除该空行，未改变语义；此前未暂存检查未覆盖该未跟踪文件。最终staged检查通过，后续local preflight绑定此精确候选。

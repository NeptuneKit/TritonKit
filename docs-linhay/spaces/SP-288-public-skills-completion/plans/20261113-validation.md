# SP-288 Public skills 补齐验收

## 候选与影响面

2026-11-13，`main@38ce0b47` 上的 docs/skill-only 候选。新增八个 public references，更新既有 SKILL/feature-index、bundle 与项目 README，补打包/路由回归；无 Sources/CLI/SDK/DSH 产品改动、依赖/锁文件变更或全局 agent 配置变更。四个 public skill 名称与版本戳规则不变。补齐阶段未提交；用户于11:19另行要求整理、沉淀和本地提交，当前按此授权收口，不推送、安装或发布。

## 缺口与事实源

| 缺口 | 包内指南 | 本轮核对事实源 |
| --- | --- | --- |
| DSH四工具 | [DSH integration](../../../../TritonKit.skills/tritonkit-dev-feedback/references/dsh-integration.md) | [README](../../../../DSH/README.md)、[真实参数适配器](../../../../DSH/commands.js)、已安装DSH插件文档；不安装插件 |
| HTTP / Runtime | [HTTP API](../../../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/http-api.md) | [serve路由](../../../../Sources/TritonKitCLI/CLIServeCommand.swift)、[请求Data/base64 DTO](../../../../Sources/TritonKitShared/TKCLITransportModels.swift)、device/Runner/lease HTTP注册 |
| 目标租约 | [Target leases](../../../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/target-leases.md) | [CLI参数](../../../../Sources/TritonKitCLI/CLITargetLeaseCommands.swift)、[服务路由](../../../../Sources/TritonKitCLI/CLITargetLeaseServer.swift)；opt-in与进程生命周期不扩张 |
| UI details/solo-group/3D | [UI inspection](../../../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/ui-inspection.md) | [CLI](../../../../Sources/TritonKitCLI/CLIHierarchyDetailsCommands.swift)、[核心边界](../../../dev/20261103-lookin-core-inspection.md) |
| 只读Web | [Web preview](../../../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/web-preview.md) | [Web参数和JSON仅计划](../../../../Sources/TritonKitCLI/CLIWebCommands.swift)、当前readonly及preview验收合同 |
| App-map | [App-map](../../../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/app-map.md) | [map子命令](../../../../Sources/TritonKitCLI/CLIAppMapCommands.swift)、[workspace merge-map](../../../../Sources/TritonKitCLI/CLIWorkspaceCommands.swift) |
| VLM/model/cache | [VLM models](../../../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/vlm-models.md) | [真实单数model命令](../../../../Sources/TritonKitCLI/CLIVLMCommands.swift)、MLX helper与显式推理合同 |
| 显式testrec/import | [Test recorder](../../../../TritonKit.skills/tritonkit-real-project-regression/references/test-recorder.md) | [testrec参数](../../../../Sources/TritonKitCLI/CLITestRecorderCommands.swift)、[HTTP DTO](../../../../Sources/TritonKitCLI/CLITestRecorderModels.swift)、[live test必需evidence-dir](../../../../Sources/TritonKitCLI/CLITestCommands.swift) |

22功能族已进入 [public bundle capability index](../../../../TritonKit.skills/README.md#capability-routing)，各SKILL/feature-index也能独立路由到指南。每个专题包含Prerequisites、Workflow、Verification、Limits，不以关键词命中代替使用步骤。此结论只表示功能族使用文档补齐，不宣称所有叶参数、provider或场景已实测/齐平。

## TDD 与反例

- 新增 [coverage tests](../../../scripts/tests/test_public_skill_coverage.py)，旧内容真实执行5 tests产生11 failures（含8个专题子例）：缺指南/22族导航，并发现4个repo-only链接；不是编译失败或未执行的重定向失败。证据：[补齐前失败摘要](./20261113-coverage-before-summary.json)明确标为summary-not-original，记录原始日志bytes/SHA与失败case；含宿主路径和重复全文的原始log保留本机、ignore，不混入版本。
- 负例同时覆盖：缺文件、未路由、越出bundle的相对链接、仅在代码块里的伪链接；源码目录和实际tar分别检查。
- 原public platform-commands的4处仓库文档引用已替换为bundle内Web/validation入口，跨四个skill的引用仍留在bundle，不复制内部space全文进公开包。
- 首次CLI help检查使用未替换的`<oid>`导致UInt解析拒绝；按指南要求替换为数值夹具1后通过，仅用于help，不解析/执行该OID。不会把占位符命令原样当设备执行证据。

## 验证结果

| 验证 | 结果 | 边界 |
| --- | --- | --- |
| 专题/入口/22 IDs/负例/实际archive路由 | 通过，7 tests | [after日志](./20261113-coverage-after.log)；包含7个DSH JSON示例调用真实buildCommand，但不执行CLI动作 |
| public package + guarded安装夹具 | 通过，38 tests及打包脚本 | [打包日志](./20261113-package-verification.log)；测试版本9.8.7-dev为隔离fixture，不是发布或用户安装 |
| public命令静态合同/feedback入口预算 | 通过 | 现有verify-public-skill-commands/layout入口；加入DSH必需路由，未放宽旧合同 |
| 本机候选CLI help/schema | 通过，70 help检查 / 10定向schema | [脚本](./20261113-check-cli-examples.py)、[原始JSON](./20261113-cli-examples.json)记录CLI SHA与0.1.0-dev；预构建本机产物，不冒充Homebrew发布版 |
| 合成显式录制 | 通过，start→page-route→action→stop→inspect→compile | 相同JSON记录2事件与compiled；未执行test run，不是业务/可靠性verdict |
| 最终文档门禁 | 通过 | [ci-docs日志](./20261113-docs-gate.log)、[check-docs日志](./20261113-check-docs.log)、git diff --check；288 spaces登记，无产品改动或暂存 |
| UIKit/设备、HTTP live mutation、真实模型/DSH安装 | 未执行 | 本次只补文档及离线/隔离契约，不用旧现场证据代替 |

## 经验与后继

已更新内部ops skill和经验索引：public指南必须从SKILL/feature-index进入，且在源码与实际tar两侧验证链接；安装包不应依赖repo-only相对路径。help/schema/序列化、mock/离线编译与实际provider验收分开。本次未新增public skill、未更改默认推理/动作授权、未知不重放或原始数据职责。

SP-287历史缺口标记已加后继链接，原图/历史报告不被反写成今日发布证明；安装与发布仍需后续明确授权和版本校验。

## 11:19 授权后的整理提交复核

- 候选仍基于main38ce0b47，仅收本轮八专题、导航、validator/tests、SP-287历史指针和SP-288资料及经验；不带产品源码/锁文件/生成模型或未完成其他任务，不新建branch/worktree。
- 复核发现示例检查脚本先前虽记录compile失败，却仍可能发布总体pass。原真实运行的compile确为成功，不撤回已观察到的正例；[隔离反例before](./20261113-compile-negative-before.json)证明旧检查缺口。现增加exit=0、ok=true、status=compiled三项门禁，[三个after反例](./20261113-compile-negative-after.json)分别拒绝nonzero、ok=false和错误status，且不写总体pass报告。此修正只在文档验收辅助脚本，不改CLI。
- 已重跑真实本机70 help、10 schema及合成2事件录制到compiled。新门禁不把help/模拟录制当真机、HTTP live mutation或真实推理验收；无需提交锁文件或构建产物。
- 收口已重跑38项public回归/打包及guarded安装夹具、ci-docs、check-docs和working diff检查，3类反例分别只改变exit、ok或status，其余成功字段保持有效。提交前再检查index差异与精确文件面，保留正例日志、结构化负例与原始red日志摘要。实际本地提交以Git回读为准；不推送、不发布或安装到用户环境。

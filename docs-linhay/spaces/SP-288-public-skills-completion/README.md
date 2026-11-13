# SP-288 — Public skills 能力指引补齐

> 2026-11-13后继：已提交内容随 [v0.2.45](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.45) 分发，发布/资产/安装与限制见 [SP-289验收](../SP-289-release-v0-2-45/plans/20261113-release.md)。以下保留原实施阶段授权与本地验收历史，不提升为新的设备/业务验收；用户agent skills目录未被自动覆盖。

## 状态与授权

- 用户要求：补齐 SP-287 核对发现的 public skills 缺口。
- 基线：2026-11-13，`main@38ce0b47`，开工工作区干净；所有写入串行在 main。
- 影响层：四个既有 public skills 的入口/references、文档打包回归测试与本 space；不改 CLI/HTTP/SDK/DSH 产品行为，不安装/启用插件，不操作设备/模型、不推送/发布。补齐阶段未沿用前轮提交授权；用户于2026-11-13 11:19单独要求整理、沉淀、本地提交，本轮按精确文件面收口。
- 补齐范围：DSH 四工具、本地 HTTP 路由与返回合同、目标租约、UI details/solo-group/3D、显式事件 testrec→import→test、App-map path/suite/export、VLM model/cache 与推理 opt-in、只读 Web 预览；为图中 22 功能族提供包内可达导航。
- 非目标：为每个叶命令新增 skill、实现缺失能力、把默认 scope 扩成设备云/多租户/正式 Web 控制面，或宣称本地文档已进入已发布/已安装包。

## BDD / 验收

1. Given 安装后仅有完整 `TritonKit.skills/`，When 从 README/SKILL/feature-index 进入上述八个专题，Then 不依赖 repo-only 路径，包含前提、步骤、校验、限制。
2. Given 原覆盖清单 22 功能族，When 查包内导航，Then 均能落到适用指南；这只证明功能族使用指引，不声称叶参数和所有平台都齐平。
3. Given 每个 CLI/HTTP/DSH 示例，When 对照当前源码、schema 和真实 parser help，Then 不用不存在的复数命令或参数，不将 ACK、离线诊断、confirmation、采集完整性当业务成功。
4. Given 生成的公开 skills tar，When 从 archive 检查文件与本地 Markdown 链接，Then 八个专题被打包、入口仍可达，无引用逃出 bundle。
5. Given 结构负例（丢文件、断路由、repo-only 链接），When 运行回归，Then 能发现失败；先运行新测试证明旧内容缺失，再补文档与导航。

## 实施与验证

- 已补齐：八个专题references、既有SKILL/feature-index路由和 [22功能族索引](../../../TritonKit.skills/README.md#capability-routing)；四个public skill名称不变。每个专题均有前提、操作、验证、限制。
- 已修复安装包中的4处repo-only相对链接；README改用现有guarded更新流程，不再建议先删用户已安装/修改的skills。
- 验证通过：补齐后7项覆盖/负例/DSH样例测试、完整38项public打包回归及隔离安装夹具、70个本机CLI help检查、10个定向schema、2事件合成录制与compiled输出；不当作设备/推理或live test verdict。
- [验收与事实源](./plans/20261113-validation.md)、[可复跑CLI检查](./plans/20261113-check-cli-examples.py)、[CLI结果](./plans/20261113-cli-examples.json)。最终 `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check` 已通过，源码文档补齐完成。
- 原缺口事实保留为 [SP-287历史核对](../SP-287-feature-map/plans/20261112-skills-coverage.md)，已注明本轮替代关系，不抹掉历史。经验已写回内部ops skill/EXPERIENCE和当日memory。
- 仅文档与离线/隔离测试；用户已另行授权本地整理提交，不安装到用户profile或agent skills目录，不启动设备/模型，不推送/发布。原始red日志保留本机，版本内存摘要与原始bytes/SHA，不把摘要冒充原日志。
- 收口复查补上CLI示例检查脚本的compile终态门禁：nonzero、ok=false和错误status三类合成反例均拒绝总体pass；真实70 help/10 schema及2事件compile正例重跑通过。此前真实compile成功结论保留，但不再允许未来失败被脚本总体状态掩盖。

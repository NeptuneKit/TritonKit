# SP-194 — 参考项目更新报告

## 状态与范围

- 状态：报告与来源归档完成，文档验证通过。
- 用户请求：整理现有参考项目的上游更新成报告。
- 影响层：文档与参考项目清单；不修改 CLI/HTTP/runtime/Web/Wails 产品实现。
- 截止日期：2026-10-14（北京时间）。本次当天文档任务在主工作区完成，不新建实现 worktree。
- 范围：references 已登记项目、SP-177 simslim、Device Hub 两个主要开源参考、RevylAI 已登记子项目；视觉模型/测试候选另列附录，避免当作已采用项目。

## BDD 与验收

- Given 已有本地快照或研究记录，When 查询上游默认分支与 Release，Then 报告原基线、当前 SHA/版本、日期、确认变化与原始链接。
- Given 无可比 SHA，When 读取近期提交或版本说明，Then 标明首次基线/近期活动，不宣称全部内容都是新增。
- Given API 不可达、删除、重定向或增量比较截断，When 汇总，Then 报告缺口，不把读取失败判为无更新。
- Given 发现可借鉴更新，When 评估，Then 明确事实与建议、TritonKit 对应入口及采用边界；不执行上游代码或设备动作。
- 报告、来源证据、索引与每日 memory 齐备，docs-only 门禁通过；主控复核关键结论。

## 产物

- [汇总报告](../../dev/20261014-reference-project-updates.md)：23 个主要参考仓库与 9 个历史研究候选。
- 分组报告及精简 JSON：[模拟器](./plans/simulator-updates.md)、[runtime/网络](./plans/runtime-updates.md)、[Xcode/Agent](./plans/agent-updates.md)、[RevylAI](./plans/revyl-updates.md)。
- 候选附录：[元信息](./plans/research-candidates.json)、[近期活动](./plans/research-candidate-activity.json)、[Maestro 发布摘要](./plans/maestro-changelog-excerpt.md)。
- 用户追加接入筛选：[上游更新接入裁决](./plans/20261014-adoption-decision.md)。优先资源规则、Resize Mode门禁和画面流加载路径；只读源码核对，未实现。
- 基线来源：现有 `docs-linhay/references/`、相关 space README 与每日 memory；不更新或覆盖既有 clone。

## 执行边界

只读 GitHub 官方 API/页面，允许写入本地报告。subagent 各自拥有独立证据文件，主控负责汇总、索引、memory 与验证。不提交、推送、订阅 GitHub 通知或改变已配置 iCTRL 自动化。

## 关键结论与主控复核

- sim-use Resize Mode 明确拒绝错误显示器上的触摸，simslim assistantd/gamed/navd 例外与 Loupe Xcode27 framework fallback 值得先对照现有实现。
- MobileBuildMCP 全面更名、ai-phone 分支分叉/MIT、Rockxy 源码与DMG分发条款需更新参考事实；历史快照保留原记录。
- Atlantis 本轮查询中刚合入 iOS26/27 NWURLSession loader 修复，最新正式版仍1.36.0，不把main能力算入已发布版本；iCTRL/OpenDeviceHub基线无变化。
- 主控实际读取分组报告/精简JSON，独立核对 MobileBuildMCP v2.7.1、sim-use v0.15.0、simslim v0.12.2、Loupe v0.5.1、Rockxy许可证、ai-phone当前license、Atlantis提交与changed files；候选HEAD/Release与Maestro固定tag changelog由主控查询。
- 大仓库比较存在文件300项上限；Baguette/sim-use提交摘要也有界，报告不宣称完整源码审计。无旧SHA的项目用首次基线/近期活动口径。

## 验证

`verify.sh --ci-docs`、独立 `check-docs.sh` 与 `git diff --check` 均通过（194个space）。6+5+4+8=23个主要仓库及9个候选覆盖核对、全部JSON解析、相对链接目标、证据文件大小有界与凭据模式检查通过。报告已请求在Codex文件面板打开（queued）。没有产品实现变更，未运行功能或设备测试；上游性能与测试声明不等于本项目运行证据。

## 后续授权与流程接替（2026-10-16）

用户已将评估可纳入项直接开发、主控验证与本地合并流程扩到全部参考，当前入口为 [SP-207](../SP-207-reference-adoption-pipeline/README.md)。本页只读边界和23+9统计保留为2026-10-14研究历史，不覆盖用户新授权；原iCTRL自动任务统一扩围，读取/采用状态去重，具体以SP-207为准。

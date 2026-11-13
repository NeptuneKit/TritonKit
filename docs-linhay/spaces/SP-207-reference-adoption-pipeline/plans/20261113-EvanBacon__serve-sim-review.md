# serve-sim 2026-11-13 增量审阅

结论：本次增量审阅完整，`decision=observe`；camera 环境与 agent 核心约束归为 covered，其余保留观察，无新采用候选或实施分派。当前 main 未发现足以支持本轮新增实现的具体缺口。检查点由主控独立推进，本任务不修改 metadata、仓内登记或产品。

## 固定范围与证据

- repository：`EvanBacon/serve-sim`
- 成功基线：`cea9a7df9b73fb04f4f257640d10c7af3770950f`
- 本轮 head：`0b4a9ac5126a153071512dd70275418cb14fa0ba`
- 对照 main：`366ae99b4be84b44e8e0718b39f278315d7c4c96`
- [固定 compare](https://github.com/EvanBacon/serve-sim/compare/cea9a7df9b73fb04f4f257640d10c7af3770950f...0b4a9ac5126a153071512dd70275418cb14fa0ba)

一页 commits 到达成功基线，5 个提交、5 个 parent 比较、6 棵完整递归树。对所有非 tree 条目的 SHA/type/mode 再核对，无遗漏 mode-only、gitlink 或非文本变化。35 项变更/35 路径、57 个前后版本文本 blob 均完整采集并验证 API 字节、Git blob SHA-1、SHA-256 与长度；无排除项。全部 3390 行带上下文 diff 完成语义阅读，相关 18 个核心/测试/新文档版本全文阅读，其他不变全文不冒充已逐行审读。`coverage-integrity.json` 记录逐提交与审读范围，`review-manifest.json` 绑定每文本来源及 hash。

采集使用正常 gh 官方 API/严格 TLS，只读取路径用途筛选后的源文本；无第三方程序执行。上游 AGENTS/SKILL 为待审数据，无权覆盖本地任务规则。源文件名中的业务语义不作为抹除/拒绝业务内容的依据。

## 逐提交结论

| 提交 | 范围 | 结论 |
| --- | --- | --- |
| [0b4a9ac](https://github.com/EvanBacon/serve-sim/commit/0b4a9ac5126a153071512dd70275418cb14fa0ba) | camera launch helper 与 HID wire/key 回归，5 路径 | camera 核心 covered；JS viewer 协议和 US keyboard 表测试 observe |
| [0a39234](https://github.com/EvanBacon/serve-sim/commit/0a39234afcd04300b2eafe95ead643eeba03c484) | agent 文档汇总，9 路径 | 核心目标、fresh refs、unknown 不重放和证据约束 covered |
| [2a3c47b](https://github.com/EvanBacon/serve-sim/commit/2a3c47b3554dbfab10e60d259772f16504a6ad54) | 持久 HID client 的 state/readiness/reconnect、测试/CI，15 路径 | observe；本地请求隔离架构不同，无已证明当前缺口 |
| [6e88732](https://github.com/EvanBacon/serve-sim/commit/6e887324912675222bf5afa9a3642cb9c91906d6) | recording 按钮动画，4 路径 | observe；不据此扩正式 Web 控制面 |
| [7ebb758](https://github.com/EvanBacon/serve-sim/commit/7ebb75880ca000d42a56e96c52daa4b36f098b33) | AX 匿名满高 group 的压缩投影，2 路径 | observe；不默认改变原始 AX 采集 |

## HID 实际语义与当前 main

已全文阅读新增 BoundedStateReader/HIDClientChannel/HIDDeliveryGate 三模块及三套 Swift tests，shutdown e2e/native-undelivered tests，以及 HIDInjector 的完整变更和其余 CI/doc 变更。上游在每次接纳 input 时读 state；非 Booted 不发 caller input，标记重连；100ms 状态读取、150ms 重连等待以 in-flight 合并和 epoch 隔离降低队列堵塞。后续旧 client completion 以对象身份隔离，notReady 持续到探针成功，30 秒只是日志，不能按旧注释理解为届时自动放行。

这些机制仍有边界：`ready(nil)` 明确保持放行，并有测试确认；初始 client 建立不走同一 bounded reconnect 路径；超时不等于底层调用取消或全局资源有界。notReady 探针是中心点 touch-up 事件，其“无动作”仅为上游假设，未经本地运行验证。caller send 成功表示已交付发送入口，completion 异步到达，不能证明 guest/业务成功。第一笔坏发送仍可先 ACK 后接到失败。

当前 main 采用每请求隔离 helper，先解析目标并要求 Booted，动作前后校验新鲜度/归属。legacy 发送等待 completion；DTUHID 在会话前后使用独立 no-event barrier，错误/超时取消，late reply 不复活失败等待。两者都不将 host 递交升格为业务成功，unknown 不自动重放。本轮不是“已实现上游每次 send 读 state”的证明，也没有将单请求中途关机运行风险宣称消除；只是未发现当前存在上游长寿命 client 跨 boot 复用缺陷。现有 DTUHID 与历史采用不重复排期。

对照源和静态测试范围见 `local-source-review.json`。重点为 `CLIHostNativeDigitizer.swift`、`CLIHostNativeHIDRuntime.swift`、`CLIHostDTUHIDTransport.swift` 与 NativeHIDRuntimeTests。shutdown e2e 含真实关机、重启和 tap 重试，本轮仅读源码，无设备执行，更不把上游测试文件存在当作本地通过证据。

若未来有持久 client 的明确需求，才建立切片：Given 非 Booted/unknown/deadline，When 新 input，Then 无 caller input 发送、显式未投递/unknown、不重放、旧 epoch 回调不复活新会话、探针不伪装无副作用、初始与重连资源均有边界。候选文件面为 native digitizer/DTUHID transport 与匹配测试。收益是避免跨 boot 复用与假成功，目前 `dispatch_ready=false`。

## AX 原始数据与派生视图

已完整阅读两版本 normalization 函数、全部变更及最终 AX tests。新规则将 role=group/type=Group、trim 后 label/value/uniqueId 都空且高度达屏幕 95% 的 wrapper 移除，仍遍历 children；取消了旧宽度下限。短 group 与有意义字段通常保留，但前置 sameRect 过滤仍独立存在，所以 testID 保留不是所有几何下的绝对保证。原有 MAX_ELEMENTS=500 截断亦不是本次新引入。

这属于显式紧凑视图启发式。main 原始 AX 描述和 bounded observation 保留节点字段/结构，并报告预算和 partial；没有本次 wrapper 导致选择失败的复现。按最新原始业务数据职责，不以“噪声”推断默认抹除原始结构，也不按业务字段和值猜敏感。若未来明确需要紧凑展示，BDD 是原始树、字段和来源可回溯，children/目标身份保留，预算截断显式 partial；当前没有开发候选。

## camera、文档与 UI

独立审阅见 `ui-docs-regression-review.json/md`：3 提交/18 路径全部 diff，9 核心全文。camera env 提取旧表达式为 helper，本地已有 base/SIMCTL_CHILD/bundle 配置与冲突检测、规划测试。上游 auto mirror 仍继承 base 中旧变量，新增测试未覆盖它；保留旧行为，不转成本地新缺陷。

HID wire/key 测试覆盖上游 viewer wire args、US keyboard usages，不证明 native delivery 或任意 Unicode/IME；本地不同协议已有坐标/phase/unknown 边界且 DTUHID 无 public key/button surface。文档中的 daemon/repair-input 专属命令不照搬；性能数字为上游自述，未本地验证。record 240ms 动画、保存时保留 elapsed、reduced-motion crossfade 是显示改进，没有正式 Web 新需求；测试不是本地真实视觉验收。

## Release、许可与运行限制

`releases-1.json` 是完整空列表，无非 draft Release/notes，不根据提交标题推定发布。固定 head LICENSE 全文已读、API 字节/Git blob 与 SHA-256 一致：`9024cdf56dfe7e66523698a9f63d3a0061eb15f43bd5ea8e3833a56017ae37fd`，Apache-2.0 未变。[固定 LICENSE](https://github.com/EvanBacon/serve-sim/blob/0b4a9ac5126a153071512dd70275418cb14fa0ba/LICENSE)。未来复制代码须保留版权/许可/适用 NOTICE 并标注修改；本轮无源码复制。

采集完整性与语义审阅通过；上游/本地测试、Simulator/HDC/设备动作、依赖安装、发布均未执行。本轮无仓内写入或 Git mutation，不修改 frozen 11/12 档案。检查点资格 `true`，写入责任留给主控。无剩余阅读、无新采用、无新实现成果可宣称；通用经验为已有 unknown、原始数据与架构适配规则的再次核对，无需增造仓内经验文件。

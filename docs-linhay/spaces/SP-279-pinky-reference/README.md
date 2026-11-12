# SP-279 — Pinky 参考项目

## 当前状态

- 状态：完成当前机制差距审计；已有 SP-280/281 承接，未在本轮新增产品实现。
- 来源：<https://github.com/DIYgod/pinky>
- 当前恢复源码：[`docs-linhay/references/pinky`](../../references/pinky/)，固定 `329f35ac2e240805e265a483fa2d3ff0f84780d3` / `v2026.1111.17`，clean clone。本轮开始时原路径缺失，原因unknown；恢复副本不冒充旧clone或旧执行日志。
- 历史研究固定版本：`v2026.1109.16` / `209aa9e4b2ff1fd81edec3c393a64b21b79162fb`
- 许可证：Apache-2.0；许可证 SHA-256 为 `c95bae1d1ce0235ecccd3560b772ec1efb97f348a79f0fbe0a634f0c2ccefe2c`。
- 影响层：参考资料、长期登记和调研文档；不修改 CLI/HTTP/SDK 产品代码。

## 范围与验收

本轮只做源码、README、设计文档、MCP 合同、许可证、构建配置和验收清单的静态审阅。未运行 Pinky、Go/Kotlin 构建、第三方依赖、MCP 服务、真实设备或模拟器。

- Given 指定的 GitHub 项目，When clone 完成，Then 保留完整 Git 历史、远端 URL、固定提交和 release tag。
- Given 项目需要列入参考资料，When 登记和报告写回，Then SP-207 reference-state、SP-207 入口、本 space、调研报告和当日 memory 可互相追溯。
- Given 研究没有执行第三方代码，When 输出结论，Then 区分源码观察、上游文档自述和本地未验证边界。

2026-11-11接管已补齐SP207正式清单遗漏：当前34仓（25参考+9候选）。官方新HEAD3248613b/v2026.1111.16，321提交大增量保持partial，未建立成功检查点；SP280/281已有承接不重排。见[当日参考报告](../SP-207-reference-adoption-pipeline/plans/20261111-reference-update-report.md)。

## 2026-11-11 当前差距审计

- [差距矩阵与实施优先级](./plans/20261111-tritonkit-pinky-gap-audit.md)：固定最新采样版本，相对历史pin增加324提交；仅面向机制审查，不是增量全覆盖。
- [源码hash与解析反例](./plans/20261111-pinky-gap-evidence.json)：16份Triton/18份Pinky源码摘要、许可证和binary hash；不推进SP-207检查点。
- Given当前main+WIP与固定Pinky，Then区分已覆盖、局部接线、真实缺口、范围差异和未验证；Stop/去重/Companion/settle/replay不得仅凭名称作缺失判断。
- Given设备动作不允许执行，When以非法button运行完整CLI argv parser，Then零provider路径返回unknown_option，定位HTTP adapter追加json与typed parser冲突；未启动真实HTTP server。
- 本轮未修改产品源码、未运行Pinky/构建/设备/benchmark；原main WIP保留，文档门禁单独验证。

## 2026-11-12 职责越界审计

用户明确：本层不替上层判断业务内容是否敏感。已逐读当前main+WIP中testrec/import、network capture、WebView、Harmony验证输入与iOS sanitizer，见[代码职责审计](./plans/20261112-responsibility-boundary-audit.md)。确认自动猜敏感→丢输入/阻断导入回放，以及fixture/URL默认改写；区分技术凭据/文件安全与显式脱敏，不一刀切删除保护。仅审查/资料写回，未修改产品行为或运行设备/产品测试。

## 交付物

- [中文调研报告](./plans/20261109-pinky-research-report.md)
- [正式深度调研报告](./plans/20261110-pinky-formal-research-report.md)
- [机制级技术评估](./plans/20261110-deep-technology-assessment.md)
- [参考项目登记](../SP-207-reference-adoption-pipeline/plans/reference-state.json)
- [本地源码归档](../../references/pinky/)
- [当日 memory](../../memory/2026-11-09.md)

## 主要结论

Pinky 是本地优先的 AI Agent 手机操作网关：Agent 通过 MCP 调用统一工具，桌面端展示画面、审批、接管和历史。其最具参考价值的机制是网关强制审批、审批绑定 session/device/lease/tool/args、`uncertain`/`stale`/`device_needs_setup` 等结果分型、Android Companion 与后台显示，以及 stdio/Streamable HTTP 的会话生命周期。

这些机制与 TritonKit 的 target lease、typed result、evidence 和设备 provider 有较强对照价值，但没有自动触发产品采用；后续若发现明确缺口，按 SP-207 建立独立采用切片并验证。

## 验证记录

已验证：仓库非 shallow clone；remote 为 `https://github.com/DIYgod/pinky`；HEAD 与 `v2026.1109.16` 均为 `209aa9e4b2ff1fd81edec3c393a64b21b79162fb`；许可证和 go.mod SHA 已记录；静态读取入口源码、MCP/审批/网关/Companion 实现、README、设计和验收文档。

未执行：`make check`、Go/Gradle 构建与测试、第三方代码、Pinky 二进制、MCP server、设备动作、签名/发布和网络安全测试。

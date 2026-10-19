# agents/revyl 只读追踪 2026-10-17

> 本文保留首轮partial历史；两仓后续补审已闭合相关机制读取。最终32完整/1partial总体结论见本期合并观察与日报；原比较300文件上限由逐提交分页清单补齐。

实际main基线 `d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec`。主目录位于codex/wip-main-before-sp209；关键几何文件与main无差异。只写本证据目录，未改源码/共享状态、未运行上游或设备、未创建会话。

12仓：10仓HEAD无变；ai-phone新增18提交；revyl-cli新增16提交且最新Release v0.1.167。两变化仓保留partial，不推进完整checkpoint。导入观察不是完整历史审计。

|仓库|HEAD|增量提交|完整性|裁决|
|---|---|---:|---|---|
|getsentry/MobileBuildMCP|d13ff0c707b0|0|daily observation complete|observe|
|awizemann/harness|3f58c077ded1|0|daily observation complete|observe|
|dongxinsuperman/ai-phone|bd2781c17a9a|18|partial|adopt|
|karminski/eyes-on-my-phone|eef71926e613|0|daily observation complete|observe|
|RevylAI/revyl-cli|86de7c9797f9|16|partial|observe|
|RevylAI/app-explorer|b3edc443dbfb|0|daily observation complete|observe|
|RevylAI/greenlight|fcb36e395bd4|0|daily observation complete|observe|
|RevylAI/mobile-devtools|efc1dae5da08|0|daily observation complete|observe|
|RevylAI/mobile-pr-reviewer|ba1250c72f56|0|daily observation complete|observe|
|RevylAI/visual-regression|2758e8a88f4e|0|daily observation complete|observe|
|RevylAI/figma-design-checker|8b4e5cea045d|0|daily observation complete|observe|
|RevylAI/CogniSim|3d8902e01198|0|daily observation complete|observe|

## 可独立采用候选

ai-phone `452e7d77326f9fc0e5b003ecbf6cec5fc499e4bf` 的运行LCD几何安全机制：本地 `CLIHostSimulatorAXDriver.devicePointSize` 仍以固定393×852/scale3兜底。建议先做缺失几何fail-closed与离线fixture；live enumerate仅在LCD/scale来源可证时另行采用，不照搬60s缓存。固定源码、测试、commit和MIT全文见 `dongxinsuperman__ai-phone/geometry-*`。BDD与本地文件面详见results。此机制证据完整不使18提交整体审计变完整。

Revyl新增云Web/工作流和MCP不进入现有产品；text-env、screen token、时长拆分保留observe。许可端点404，没有复制授权。本地stdin动作、alias新鲜度、settle、日志隐私和Runner加密通道已覆盖相关方向。

## 完整性与许可

每仓官方metadata、HEAD、全部Release分页和license响应已存。ai-phone逐提交复建文件集合，但大提交文档/产物繁多，全部patch与相关源码未完整人工读取；Revyl亦未完成全部patch人工读取。7仓license官方端点404已重试两次并保存错误，不能声明有许可。MobileBuildMCP API SPDX=NOASSERTION而全文为标准MIT，保留二者不伪造实质许可变更。所有上游性能和测试结果未经本地复验。

经验检查完成：本轮只提供审计证据，main基线纠正和partial检查点边界交root回写原权威资料；不新增共享治理文件。

Revyl补审：Web/config/hotreload/生成类型机制分组与裁决见results及review-groups.json。主体许可未知，但两个hosted插件README/manifest声明MIT，不能套用主体。tests仅语义索引、aggregate显示有截断、36项nontext未全部重建语义diff，仍partial；没有伪称外部阻塞。

## dongxinsuperman/ai-phone 后续补审

初始partial记录保留历史；最终逐仓库完整性以[补审](20261017-ai-phone-review.json)和[合并观察](20261017-observations.json)为准。补审complete=True，不将生成物读取/范围排除当作二进制执行或产品验证。

## RevylAI/revyl-cli 后续补审

初始partial记录保留历史；最终逐仓库完整性以[补审](20261017-revyl-review.json)和[合并观察](20261017-observations.json)为准。补审complete=True，不将生成物读取/范围排除当作二进制执行或产品验证。

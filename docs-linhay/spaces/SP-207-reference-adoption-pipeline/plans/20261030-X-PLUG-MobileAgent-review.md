# X-PLUG/MobileAgent 2026-10-30 增量审阅

裁决：observe。MiniMax接入属于上游推理provider扩展；PNG data URI已有实现，索引聚焦修复不对应本地focused-only契约的新缺陷。

固定范围：`11cea575561fb7800b5fb6b6cafa56f7a91de11f` → `81fa28b564ef7a695521500bc15a0e1324b2b394`；真实main：`30185dc277ed305483aa789cb2d8c8b06fa21fe4`。影响层评估为CLI/shared core，不涉及Web业务写面。

## 取证完整性

分页 commits 列表读至旧SHA；共 9 个新提交。固定base/head recursive git trees均明确truncated=false，按blob SHA差异列出 8 文件后才抓取通过用途/文本白名单的内容，未请求含patch的compare/commit接口。完整清单、commit消息、源码前后文本及diff见increment-manifest.json、commits-*.json、tree-*.json、source/、increment.diff；本次无排除文件或未闭合文本缺口。HEAD/release分页证据沿用本目录此次主控采集；LICENSE.full与result.json固定hash一致。

## 机制与本地差距

九个提交（含三个merge）带来八个变化文件，两个新增测试文件在base不存在；全部 .py/.md 文件均通过用途及文本白名单，base/head完整文本和逐文件diff已保存。读取阶段对新增文件base的首次404已按完整树确认“原本不存在”，不是未闭合网络缺口。

1. Mobile-Agent-E 增加 MiniMax 模型、协议/区域URL、thinking、缓存token计费、Anthropic多媒体转码和文本块提取，并增加对应mock测试与README。Triton当前VLM入口是openai-compatible与本地MLX，不把第三方模型品牌、Anthropic协议、计费硬编码引入CLI；现有通用兼容入口可按其既有契约接配置，模型能力/价格声明未经本地或官方产品实测，不外推保证。独立Anthropic原生provider不是本次既定需求，保留观察。
2. GUI-Owl 将裸PNG base64修为 data:image/png;base64 URI，新测试校验PNG round-trip。main Sources/TritonKitCLI/CLIVLMRuntime.swift 的 makeOpenAICompatibleRequestBody 已明确构造相同PNG URI，因此机制已覆盖。
3. AndroidWorld input_text 从 None 坐标/硬编码长按改为复用click分发解析index/坐标，错误index拒绝输入。main CLIActionCommands.swift 的 TypeText Android分支明确仅对焦点输入，--oid提前返回 unsupported_capability，并提示先tap；PasteText坐标分支先运行tap再提交文本，tap抛错则不继续输入。CLIAndroidActionRuntime.swift 从当前观察节点bounds解析中心点，无上游硬编码长按路径。Triton不接受AndroidWorld index协议，因此不能直接套用该bug或增加隐式自动聚焦。SP-192新鲜度/unknown约束、SP-196输入验证、SP-200平台输入边界与现有登记继续成立，无新切片。

无非draft Release（已有 releases-1.json 空列表）；不是读取失败。顶层许可证MIT全文/hash已复核；android_world变化文件含Apache-2.0头，不将顶层MIT套到这些文件，未来若复制需分别保留相关许可与来源。本轮只观察，不复制代码。

## 对照与边界

已读SP-192、SP-196、SP-200 README和SP-207 adoption-state.json，并以git show main:固定源码复核；副本在local-main-evidence.txt。未改现有WIP、正式登记、result.json，未安装/运行第三方代码、未操作设备、未提交或远端写入。上游测试只阅读未执行，无实现候选，故不新增BDD/测试任务。

经验检查完成：本轮遵循现有用途白名单、固定SHA、许可分层与差距去重规则，无新增需修改的治理经验。

## 补充：逐提交中间状态完整性

初版仅用base/head净差异不能证明所有中间变更已覆盖；本次补齐9个增量commit的所有父边（含merge第二父边），共12条父子tree比较。每个commit/parent recursive tree均truncated=false；逐边路径并集仍为上述8文件，没有净差异外路径。20个唯一(path,blob)完整安全文本已取齐并阅读，排除路径为[]。证据为intermediate-audit.json、intermediate/trees/、intermediate/text/及intermediate-vs-head.diff。

额外中间版本包括：MiniMax最初的USD/CNY、长短上下文、priority/service_tier计价配置随后简化为目标USD模型价格；M2.7多媒体拒绝检查随后补齐；GUI-Owl测试加强PNG内容校验；AndroidWorld测试从旧JSONAction切换生产new_json_action。前者仍属于上游provider/计费扩展，后两者属于已审机制的测试纠正，均不产生Triton新增采用切片。observe裁决保持。

匿名GitHub tree请求一度403 rate limit，随后使用环境已有gh认证只读API补齐，未新增凭据或授权；当前无未闭合网络缺口。此次完整性纠正属于既有“完整读取后推进”规则的落实，由主控按权限判断是否需在正式流程补充逐提交树检查点。

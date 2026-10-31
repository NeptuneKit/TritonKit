# mirroir-mcp 2026-10-31 增量审阅

裁决：observe。上游强化compiled缓存回放与iPhone Mirroring/Universal Clipboard、Swift emitter→Rust runner链；Triton现有live解析/显式wait/版本拒绝契约无同构新缺陷，保留观察，不引入上游跨surface编译器。

## 固定来源与覆盖

- 官方仓： https://github.com/jfarcand/mirroir-mcp
- 旧观察base `20223a9a7f3707513c9bbaf740773ead1f181ce1`，来自20261030-observations.json；本次固定head `485416f3641dfb83b2e2a894fc0bb288ff706a28`。
- 对照真实main `1139db7712d485c0927282a4415ac45765567332`（未使用工作区WIP）；固定源码副本为local-main-evidence.txt。
- commits分页直至旧base，共7提交、7父边；8个recursive trees均truncated=false。逐提交父子tree路径并集175文件，324个唯一(path,blob)安全文本已保存，包括中间版本；排除路径[]。未以净diff代替全增量。清单见review-manifest.json，逐边差异见review-increment.diff。
- 每次内容请求前按用途及文本白名单审核；Swift/Rust源码、测试、构建配置、Markdown及网站源码均为安全文本。本次无身份/证书/私钥/二进制变化内容抓取。只使用列表commits和trees，不下载含patch的compare/commit响应。
- Apache-2.0固定head LICENSE.full全文 SHA-256 `52327c57e955a3e63f872960938e814acc19eb1b77c501999f5fd1e543b21346` 与本次result一致。未复制上游代码或新增依赖。
- Release v0.42.0完整body/分页保留本目录既有releases文件，正文包含M2、mirroring、target Sendable及record_step修复；HEAD的M3是另一个提交，不能把HEAD全部能力当作v0.42.0发布证明。未下载release二进制。

## 逐机制差距裁决

1. **M2 compiled hints与record_step**：compiled格式升到5；label tap先实时OCR匹配并纠偏，无法匹配拒绝；坐标icon tap要求可辨arrival fingerprint、before不已匹配destination、after在预算内到达；record_step拒绝画面未变或时间错序。wait_for改走实时执行，旧sleep hints移除，stale/不解码产物明确警告再live，不再静默。Triton的CLIEvidenceReplayRuntime.replayTapRequest对文本/AX目标现场解析，readReplayPlan拒绝非schema1，runReplayPlan预生成命令且首失败停止；它没有上游compiled坐标hint cache，因此不存在其“睡眠/旧坐标当已验证”执行分支。直接坐标tap仍是显式坐标动作，不把它称作arrival/business已验证；需要后置条件应显式wait/verify。SP-192新鲜度、视觉稳定businessVerified=false及unknown不得自动续行边界不变。
2. **Universal Clipboard与Spotlight**：新VerifiedTextEntry在不可映射字符分段paste后通过OCR新增出现次数确认，失败即停止，emoji不可读则不报成功；Spotlight应用tile/查询必须可见，确认关闭再报launch。这是iPhone Mirroring跨Mac剪贴板/键盘桥的异步风险。Triton当前embedded UIKeyInput、Simulator host adapter及显式App生命周期不经过Universal Clipboard/Spotlight链，SP-196输入读回与SP-200平台输入边界已登记；不为了套用上游模式新增OCR/跨设备写入或把字符内容写入错误日志。
3. **M3 emitter→runner**：Swift按arrival viewport生成有label/landmark的scenario，对AI-only、不可回放动作、无法命名目标拒绝或列出dropped；只在owned manifest明确定位must_pass时插入，human-owned未声明时报错；APP.md版本主号拒绝，新minor容忍并报告；Rust统一version seam，对已知minor未知字段拒绝、未来minor报告忽略，对无executor device/condition和分裂block预检拒绝，测试固定Swift输出→Rust解析/渲染接缝。Triton没有APP.md/SAMPLE.md、跨surface Playwright block或该生成目录产品；现有.tritonplan是显式typed动作/等待，unknown action enum不解码，simulatorResource实际执行在任何前序动作前统一拒绝。上游通用“所有artifact统一major/minor/unknown-key策略”并非本地现有承诺，不将其整体迁入现有协议造成兼容变化。观察其契约测试方法，不新建跨surface编译器。
4. **mirroring paused误判**：AX snapshot新增subrole/identifier并排除window/title toolbar按钮，避免将live窗口工具栏当paused。这是macOS iPhone Mirroring窗口分类，不对应Triton Simulator/embedded readiness路径；不新增该设备面。
5. **Sendable与发布**：移除已Sendable builder/profile静态表的nonisolated(unsafe)，测试/文档/版本同步；npm发布等待registry可见是上游npm分发问题，Triton未发布同包/同registry链。本轮不升级或引入依赖，Cargo.lock及npm/website变化仅审阅。

已对照SP-192、SP-196、SP-200与SP-207 adoption-state.json；既有采用不重复排队。没有可采用新切片，因此不生成实现BDD/文件面，也不把上游测试数量或fake运行当本地验收。

## 验证与边界

本轮只完成官方只读取证、固定main源码差距评估。采集脚本本身为本地作者工具，未执行第三方源码、上游测试、依赖安装、设备动作或发布。未改result.json、正式docs/state或Git。JSON可解码、manifest全部安全blob存在并UTF-8验证、许可证hash一致；未运行产品测试（无产品实现改动）。

经验检查：沿用既有逐父边tree、用途白名单与真实main去重规则，无新增治理模式；正式资料写回由主控负责。

# mirroir-mcp 2026-11-02 增量审阅

结论：**observe**，未确认现有真实入口同源缺陷，无新增实现切片。影响上游CLI/MCP作者录制、Swift OCR与Rust runner；本地CLI/shared core仅作静态对照。

## 固定来源

基线 `b2509022e965dd2dc1060f58c8a9faa5cae068e4` → [HEAD 1166ac15](https://github.com/jfarcand/mirroir-mcp/commit/1166ac1517263d773703c08ceae762a20432d3a2)。另一个提交为 `65e3a71755d41d392817b4f6417ef15ed9ab3e12`。2提交、2父边、3完整递归trees均非truncated；提交分页第1页命中基线。两父边分别比较，共74变化文本路径、138去重版本blob，含中间状态而非仅HEAD净diff；先按用途与文本白名单筛选，没有身份/证书/私钥/二进制变化，排除0。未使用带patch compare/commit响应。review-manifest.json、review-source、complete-parent-edges.diff（6692行）与text-integrity-ledger.json保存完整文本、来源和hash。

固定HEAD LICENSE全文Apache-2.0，SHA256 `52327c57e955a3e63f872960938e814acc19eb1b77c501999f5fd1e543b21346`，不变。Release仍v0.42.0，既有notes是M2 checked taps/icon arrival/paste-launch，不能把本次M5当新release。未拉取外部mirroir-skills内容或执行其代码，其许可/效果不能由本仓许可代替。

## 增量机制

- M5把CLI record与save_compiled emit汇入RecordingWalk/CompiledWalkBuilder及同一.mirroir emitter。record先存可恢复recording JSON，再emit；缺OCR标签/未读screen/无launch opening/异App opening/不支持参数拒绝，保留来源供重试。compiled speed cache与runner drift baseline分开，不把缓存写入场景树。long_press转换仅保留标签、放弃录制duration，不应盲目视为无损通用导入。
- EventRecorder在mouse-down/键盘起始处记录screenBefore，hold用CGEvent自带nanosecond timestamp差而非OCR处理耗时；icon占位符不作为label。EventClassifier抽离是结构变化，不能把整份新增文件当全部新增机制。
- reset_app最多4读寻找两次位置差≤8pt的同一卡片，拒绝未稳定/歧义/空/不可读，不猜测拖拽邻卡。Spotlight tile增加同baseline图标行识别并排除历史行glyph。runner把reset_app/home屏幕作为launcher表面不判业务漂移，避免时钟/widget假阳性。
- 后续fix将landmark与结构fingerprint统一为配置驱动的OCR clean segments，避免bullet变化及合并/拆分行产生假漂移；缺text-cleanup规则拒绝emit。PermissionPolicy统一skills checkout搜索顺序，MIRROIR_SKILLS优先；Rust传绝对skills路径到scratch子进程，Swift每次test读取同一个checkout。record接入已有ensureConnected恢复策略，不把自动恢复照搬Triton。
- 新测试覆盖事件timestamp/label、recording JSON roundtrip、不可重放步拒绝、compiled emit失败/成功、卡片静止/不稳定、清洗分段一致性、skills路径及launcher忽略等；仅静态读证，未经本地执行验证。CI/文档/fixtures变更为上述链配套，不构成额外本地需求。

## 本地主线差距核对

固定 `main@44e81f5d333ba842051579639d3834981e7b2340`，源码、SP-192/196/200和既有采用登记保存于main-evidence。既有17采用不因上游作者链重构重开。

CLITestRecorderRuntime接收显式JSON事件，不监听Mirroring CGEvent，不以OCR处理时长计算鼠标hold；故不存在该同源timestamp错误。CLITestImportRuntime已有已编译.tritontestcase→窄.tritontest.yaml离线转换，要求明确bundle/platform、拒绝覆盖/错误来源，不执行动作，保留编译provenance；这是可比的单一事实契约，而非上游完整录制工作流已具备。CLISchemaTestCommands说明现有真实normalized-plan runner及观察证据入口，未提供此Mirroring卡片/OCR录制输出/外部skills配置链。

CLITestRecorderFingerprintRuntime已有候选页面匹配与缺component不得分，CLINodeAliasFreshness对实际observe再次校验30秒时效/目标/provider/完整性与页面身份。它们不等同上游逐步arrival漂移。testrec local-device replay仍明确not-wired/not-run、deviceCommandExecuted=false；缺targetFingerprints的模拟匹配也不能当实际屏幕通过。没有当前真实回放或模板生成错误消费该OCR分段/skills cwd的源码证据，因此保留观察，不因上游新功能推定本地漏洞。

未来若独立建设Mirroring录制或真实逐步baseline，BDD须覆盖事件原始时间戳、无标签/缺屏拒绝、时长语义不丢失、source/device变更、相同清洗规则与绝对配置来源、漂移不覆写基线；届时定义space/CLI机器契约及文件面。本轮无可成立直接采用文件面。

未运行上游、依赖、设备或产品测试；未改产品/result/正式docs/state/Git。完整静态增量取证不代表真实设备验收或性能。无新增治理经验，正式汇总由主控统一写回。

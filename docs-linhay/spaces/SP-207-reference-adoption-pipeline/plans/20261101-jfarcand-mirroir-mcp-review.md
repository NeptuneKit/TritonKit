# mirroir-mcp 2026-11-01 增量审阅

结论：**observe**。影响上游Swift录制/报告及Rust runner漂移判定；不新增本地实现切片。已有页面匹配可比，但不能称完整逐步活屏漂移已经覆盖。

## 固定来源与完整性

基线 `485416f3641dfb83b2e2a894fc0bb288ff706a28` → [HEAD b2509022](https://github.com/jfarcand/mirroir-mcp/commit/b2509022e965dd2dc1060f58c8a9faa5cae068e4)：1提交、1父边、60变化文本路径、102个去重两端安全blob。commits分页第1页命中基线；提交与父边递归trees均非truncated，逐父边比较而非仅净diff，未遗漏中间回滚。按路径用途及文本扩展白名单先筛选；本增量无身份/证书/私钥/二进制路径，无排除项。未拉取含patch compare/commit响应。完整文本及4752行增量保存在review-source、complete-increment.diff；review-manifest.json列路径/版本，text-integrity-ledger.json列全文hash。

固定HEAD LICENSE全文Apache-2.0，SHA256 `52327c57e955a3e63f872960938e814acc19eb1b77c501999f5fd1e543b21346`，与本批result一致。最新Release仍v0.42.0，notes为M2 checked taps/icon arrival/paste-launch等；本次M4源码不是新release。不将mirroir-skills外部依赖许可或运行效果套用本仓，未获取/安装该外部库。

## 机制与边界

1. Swift StepScreenRecorder在start及每个实际步骤后采结构指纹，动态取当前describer以适配target变化；最多4读，连续两次hash一致即保留，始终不稳定则保留末读，故不能把其settled措辞当业务稳定证明。报告screens/device及compiled-out记录sourceSHA、window/orientation、passthrough arrival；缺window/start/步骤屏幕拒绝写基线，参数成对、单技能且禁止dry-run。失败run不生成新compiled文件。
2. Rust screen_drift以相同hash或结构文本Jaccard对比arrival，source/window改变、应有屏幕未读/已读屏幕无基线均生成finding；start/target步骤不判断漂移。阈值无声明拒绝，不猜测默认。Compare不覆写已有参考；首次通过或显式accept才从stage提升参考，stage旧文件先移除，缺输出/坏schema拒绝。测试含Swift/Rust同源golden、match/drift/source变化、无输出拒绝及accept重录；这些是静态测试证据，未在本机执行。
3. Global drift-defaults从可配置搜索路径首个文件加载，完全缺失即load拒绝；emit先plan缺失检查，已有配置保留，以withoutOverwriting拷贝skills文件，不自行编造阈值。CI增加skills clone仅为其依赖。AppSwitcher定位增加唯一label优先、内容指纹后备；测试App清理由启动归属决定；均依赖iPhone Mirroring表面。

## 对照实际main

固定 `main@4b4b6a841446243c3fb76af800483cda65bbc738` 的源码与SP-192/196/200、采用登记已归档main-evidence。

- CLITestRecorderFingerprintRuntime已有来源contract验证、页面候选加权匹配；缺component得0，needs-review/not-matched在回放计划中产生blocker。CLINodeAliasFreshness还在实际observe后校验完整性、30秒时效、目标/provider与页面/节点身份，拒绝陈旧坐标。它们提供可比的fail-closed身份/页面机制。
- **缺失但尚未映射真实入口**：本地没有此Rust式每步活屏arrival漂移及last-green/accept机制。CLITestRecorderReplayRuntime的local-simulated只模拟，缺targetFingerprints时不做页面比较；local-device始终输出target_not_found/act-runner:not-wired、not-run、deviceCommandExecuted=false。因此缺活屏比较尚不构成当前真实回放已执行却误报通过的故障，不以新增上游runner等同本地需修复漏洞，也不称全部已覆盖。
- 上游卡片拖拽针对iPhone Mirroring，Triton Simulator/本地明确bundle生命周期不需复制OCR卡片回退；外部skills阈值文件不是Triton配置契约，强加该global文件会引入无关依赖。

本次没有可确认直接采用的现有真实入口缺口，故无开发文件面。未来若独立建设真实testrec回放，BDD应覆盖每步observed/reference缺失、source/device变化、阈值缺失、drift不覆盖基线与显式accept，不能把模拟通过当真实动作或稳定业务断言；届时才定义CLI/HTTP契约、状态流与执行文件面。

未运行第三方代码、依赖、设备或产品测试，未改产品/result/正式docs/state/Git。静态增量阅读完成不等于上游性能或真实iOS验收。无新增治理经验；正式汇总由主控统一写回。

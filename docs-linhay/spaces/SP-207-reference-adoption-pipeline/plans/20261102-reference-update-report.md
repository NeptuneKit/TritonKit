# 2026-11-02 参考项目日检

固定实际 main `44e81f5d333ba842051579639d3834981e7b2340`；33仓 24 完整 / 9 partial，4 仓相对11月1日变化，0 仓未知。HEAD、完整非draft Release分页与固定SHA许可分别重新查询。

## 增量判断

- [heoblitz/Loupe](https://github.com/heoblitz/Loupe/commit/180c60584867500b93b43ca6c8b556995bf8be7b)：可采用：补充本机Simulator DTUHID服务transport、严格unsupported回退和无事件barrier；main仍仅LegacyHIDClient，明确modern backend unsupported。Web网格/SwiftUI私有遍历另保留观察。 [审阅](20261102-heoblitz-Loupe-review.md)。
- [jfarcand/mirroir-mcp](https://github.com/jfarcand/mirroir-mcp/commit/1166ac1517263d773703c08ceae762a20432d3a2)：统一作者录制到.mirroir场景、修正CGEvent时间/卡片静止拖拽、OCR清洗分段与scratch技能路径；Triton已有离线testrec导入和明确匹配拒绝，但不使用该iPhone Mirroring事件/卡片/skills链，未确认现有真实入口同源缺陷；新M5作者工作流与逐步漂移能力保留观察，不声称完全覆盖。 [审阅](20261102-jfarcand-mirroir-mcp-review.md)。
- [RevylAI/revyl-cli](https://github.com/RevylAI/revyl-cli/commit/a50ee179e5c01a1f25f15cef951a78eddab5fa3e)：唯一新增提交仅4个__pycache__ pyc blob变化；两棵固定非截断树证明没有安全文本源码差异。按请求前白名单不取pyc内容，无法从编译字节码推出本机机制或缺陷，未新增采用。许可404与历史hosted来源缺口保留。 [审阅](20261102-RevylAI-revyl-cli-review.md)。
- [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp/commit/1851dfaca835d644adb409acad8b173120804bbc)：唯一提交只更新mobilewright至0.0.68及锁文件；mobilecli1.0.22/ws8.22.1属传递依赖元数据，未证明Triton现有实现缺口，不升级或运行依赖。 [审阅](20261102-mobile-next-mobile-mcp-review.md)。

## 采用及证据

17项既有采用为local_merged，实际合并SHA全部为main祖先；新增SP254/255 DTUHID切片已评估分派，实现/验证/合并未完成；12个真实执行/批次聊天登记已归档，长期主控保持开放。本轮不重开已交付项；无新采用缺口则不创建实现空间。

昨日SP207的428份manifest条目逐一验证可用且hash一致；10月30日716份raw缺失仍是已知历史缺口，未声称恢复。本日证据保存仓外archives并生成新manifest。

许可与网络错误以本日实际查询为准，未恢复的旧source缺口继续保留；只有本次完整仓推进成功点，iCTRL继续使用SP193独立状态。未运行上游代码、设备、安装依赖、签名/DDI、push/tag/release；仅资料变化，产品测试不适用。复用现有采用流程：review绑定仓库/base/head/main，跨状态发布保留before/after恢复记录；历史source缺口只按明确恢复证据退休。本轮门禁与新增经验由主控核实后补充。

| 仓库 | HEAD | Release | 完整性 |
| --- | --- | --- | --- |
| tddworks/baguette | `94b78d3603ac` | v0.2.12 | partial |
| EvanBacon/serve-sim | `ede4c21ee302` | — | 完整 |
| lycorp-jp/sim-use | `c02295edfd2f` | v0.16.0 | 完整 |
| MobAI-App/simslim | `d594c230fe9e` | v0.13.0 | 完整 |
| Mastersam07/OpenDeviceHub | `e50f07f1f448` | v0.2.0 | 完整 |
| JaviSoto/device-hub-ios | `3779e12aa00c` | — | 完整 |
| heoblitz/Loupe | `180c60584867` | v0.5.1 | 完整 |
| jfarcand/mirroir-mcp | `1166ac151726` | v0.42.0 | 完整 |
| RockxyApp/Rockxy | `de791b63e7f9` | v0.41.0 | 完整 |
| ProxymanApp/atlantis | `cc059013de87` | 2.0.0 | 完整 |
| OpenMinis/iCTRL | `c1e4268859ba` | v1.98.16 | 完整 |
| getsentry/MobileBuildMCP | `2998ac77ebbc` | v2.7.1 | 完整 |
| awizemann/harness | `3f58c077ded1` | v0.8.4 | 完整 |
| dongxinsuperman/ai-phone | `d339057bc64a` | v0.8.0 | 完整 |
| karminski/eyes-on-my-phone | `eef71926e613` | — | partial |
| RevylAI/revyl-cli | `a50ee179e5c0` | v0.1.204 | partial |
| RevylAI/app-explorer | `b3edc443dbfb` | — | partial |
| RevylAI/greenlight | `fcb36e395bd4` | v0.2.0 | 完整 |
| RevylAI/mobile-devtools | `efc1dae5da08` | — | partial |
| RevylAI/mobile-pr-reviewer | `ba1250c72f56` | — | partial |
| RevylAI/visual-regression | `2758e8a88f4e` | — | partial |
| RevylAI/figma-design-checker | `8b4e5cea045d` | — | partial |
| RevylAI/CogniSim | `3d8902e01198` | — | 完整 |
| hughkli/Lookin | `95e30fdcc815` | 1.0.7 | 完整 |
| OSU-NLP-Group/UGround | `8974f95b0685` | — | 完整 |
| bytedance/UI-TARS | `582f3a7ea5d2` | — | 完整 |
| OpenBMB/AgentCPM-GUI | `2168ae21b1be` | — | 完整 |
| X-PLUG/MobileAgent | `81fa28b564ef` | — | 完整 |
| njucckevin/SeeClick | `0ef37ac4d7aa` | — | 完整 |
| google-research/android_world | `55ddaf5edc6f` | — | 完整 |
| mobile-dev-inc/Maestro | `5ca5313b4c65` | cli-2.12.0 | 完整 |
| linhay/SKProcessRunner | `24e036604b9e` | 0.0.17 | partial |
| mobile-next/mobile-mcp | `1851dfaca835` | 1.0.15 | 完整 |

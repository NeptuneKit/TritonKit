# 2026-11-11 验收

基线 main `607410fb`；直接 main 串行实施，SP-281 产品 WIP 未由本任务修改或提交。证据根：`../TritonKit-archives/reference-monitor/20261111/`。

- 首次测试编译缺新增字段；随后只加 DTO 字段，真实行为 red：doctor mdm / catalog accessibility-assets 抛 unknownFeature（sp284-red-behavior.log）。
- 最小新增 3 个只读诊断 feature；focused SimulatorResource：XCTest49、SwiftTesting12/2 suites 通过。
- 完整 CLI：XCTest167、SwiftTesting1854/203 suites 通过；测试现场包含既有 SP-281 WIP，不据此宣称它已提交/验收。
- 根包：XCTest5、SwiftTesting130/26 suites 与313/45 suites 通过（root-tests.log）。
- 实际自有 debug CLI `sim resource features` 输出28项：25 managedByProfiles=true，3项false；JSON已断言，不触发设备读取。
- 独立只读复核 labels 固定来源一致，categories/desired/delta 不变，managed171/slimmable168未扩张。doctor保持 service-overrides-only；false/缺 override 仅表示未发现禁用，不证明服务存在或业务成功。
- 内部 Codable 类型当前仅被编码，无旧 JSON 解码消费者；本次未承诺持久 DTO 的缺字段解码兼容。
- 未执行真实 Simulator、设备写入、上游代码、推送或发布。docs/local 与提交事实在 SP-207 日报统一收口。

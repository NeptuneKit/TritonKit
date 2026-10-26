# 2026-10-23 Simulator / runtime 参考只读日检

实际主线 `409670ef1435aec5950f7e1b30fea8e0b2ecc705`；主目录 main，既有追踪资料WIP保持原样。10仓官方查询成功；7完整、3 partial；相对昨日 HEAD、最新非draft Release（包含prerelease）和许可证全文hash均未变化，无新增采用项。成功点/import与昨日观察分别比较，partial不推进、没有虚假恢复。

| 仓库 | HEAD固定链接 | Release | 覆盖 | 采用判断 |
| --- | --- | --- | --- | --- |
| tddworks/baguette | [458044cc](https://github.com/tddworks/baguette/commit/458044cceadd25a1366619b3747311ad7d959f94) | [v0.2.10](https://github.com/tddworks/baguette/releases/tag/v0.2.10) | partial | v0.2.10 Duo/3D stage属于上游UI；无当前本机CLI缺口证据，二进制来源与增量审阅仍partial。 |
| EvanBacon/serve-sim | [a30d70a5](https://github.com/EvanBacon/serve-sim/commit/a30d70a55e05654d974c86803b68d4f675be77e3) | 无非draft Release | 完整 | HEAD/Release/许可hash与上次一致，复用已保存固定源码评估，无新增采用项。 |
| lycorp-jp/sim-use | [c02295ed](https://github.com/lycorp-jp/sim-use/commit/c02295edfd2f442249b869096dda3dc7bfcd308d) | [v0.16.0](https://github.com/lycorp-jp/sim-use/releases/tag/v0.16.0) | partial | v0.16.0保护notarized Homebrew签名；Triton无该签名前提及post_install覆盖，未证实同类缺陷；SP-214/219已交付，不重复排期。 |
| MobAI-App/simslim | [6518ba7e](https://github.com/MobAI-App/simslim/commit/6518ba7eab1123d7e1d7797b0e05f51043b42a5b) | [v0.12.2](https://github.com/MobAI-App/simslim/releases/tag/v0.12.2) | 完整 | HEAD/Release/许可hash与上次一致，复用已保存固定源码评估，无新增采用项。 |
| Mastersam07/OpenDeviceHub | [e50f07f1](https://github.com/Mastersam07/OpenDeviceHub/commit/e50f07f1f4480cb14d57f192df7bf598ca26e708) | [v0.2.0](https://github.com/Mastersam07/OpenDeviceHub/releases/tag/v0.2.0) | 完整 | HEAD/Release/许可hash与上次一致，复用已保存固定源码评估，无新增采用项。 |
| JaviSoto/device-hub-ios | [3779e12a](https://github.com/JaviSoto/device-hub-ios/commit/3779e12aa00c08bb34805fef8ffe375838cbe815) | 无非draft Release | partial | Rust DeviceHubFFI重构与CI前置条件不对应Triton当前入口；省略历史patch保持partial。 |
| heoblitz/Loupe | [ff135124](https://github.com/heoblitz/Loupe/commit/ff1351242e6dbaba4a0b4de40d10350a668f03b8) | [v0.5.1](https://github.com/heoblitz/Loupe/releases/tag/v0.5.1) | 完整 | HEAD/Release/许可hash与上次一致，复用已保存固定源码评估，无新增采用项。 |
| jfarcand/mirroir-mcp | [845a9811](https://github.com/jfarcand/mirroir-mcp/commit/845a981163aa6d40999d343fee26778df8627843) | [v0.40.1](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.40.1) | 完整 | HEAD/Release/许可hash与上次一致，复用已保存固定源码评估，无新增采用项。 |
| RockxyApp/Rockxy | [de791b63](https://github.com/RockxyApp/Rockxy/commit/de791b63e7f9b5df49f127524a5c9320e675eb23) | [v0.41.0](https://github.com/RockxyApp/Rockxy/releases/tag/v0.41.0) | 完整 | HEAD/Release/许可hash与上次一致，复用已保存固定源码评估，无新增采用项。 |
| ProxymanApp/atlantis | [cc059013](https://github.com/ProxymanApp/atlantis/commit/cc059013de8778072b4fea6453b45e964e4202fe) | [2.0.0](https://github.com/ProxymanApp/atlantis/releases/tag/2.0.0) | 完整 | HEAD/Release/许可hash与上次一致，复用已保存固定源码评估，无新增采用项。 |

## 完整性与来源边界

每仓 `repository.json`、`head.json`、全部 `releases-N.json`、固定HEAD `license.json` / `LICENSE.full`已保存。Release全分页后按published_at取最新非draft；无资产下载。许可证API NOASSERTION保留原值，不据此改写全文法律判断；sim-use全文Apache-2.0沿用昨日已纠正识别。所有HEAD/tag/hash与昨日一致，因此复用昨日固定源码审阅，不请求新的contents/blob。未运行昨日禁用脚本，未下载二进制/身份/密钥/证书内容。

三项旧partial原样保留：Baguette二进制来源和历史省略patch；sim-use `42aa9a2` CHANGELOG省略patch及语义审阅限制；device-hub-ios `c76fa33` protocol.rs省略patch。没有通过无变化消除这些缺口。

## 当前main覆盖核对

`main-coverage.json`绑定真实main blob/hash，核对主屏topology fail-closed和Resizable capture routing源码/测试。SP-192已有alias新鲜度、预算、settle、OCR和health；SP-196已有Resize安全门禁与framebuffer/helper；SP-200已有设备环境、录屏、诊断、归档和终端镜像。SP-214的topology拒绝底座及SP-219确认display identity的录屏路由均存在实际main；SP-214 README开头旧“待分派”是历史段，不作为未交付证据。本轮不重复排期。

sim-use v0.16.0 notarized Homebrew签名保护仍是观察项：Triton没有同签名前提或同post_install覆盖证据，不能凭上游发布包装改动推导本地缺陷。Duo/3D UI与DeviceHub Rust重构不扩充到CLI产品面。无新固定来源/本地差距组合，因此无新增BDD开发候选。

本轮仅只读证据与报告，无build/test/device/第三方执行、安装、提交或远端写入；本地源码静态复核不替代真实Simulator/Xcode/AX/HID验收。经验检查完成，无新增；原完整性规则继续适用。

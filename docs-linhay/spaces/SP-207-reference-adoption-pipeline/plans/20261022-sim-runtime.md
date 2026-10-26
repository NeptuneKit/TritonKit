# 2026-10-22 Simulator / runtime 参考只读评估

Requested：登记 indices 0..9 共10仓；以成功 checkpoint 或 imported_observation 为增量基线，与20261021 observation另行比较。只写本目录，无构建、测试、设备、发布或运行第三方代码。

Observed：7仓完整且无变化；Baguette、sim-use、device-hub-ios有新HEAD，保守记partial，不推进成功点。完整只表示本次官方元数据、全部非draft release分页、固定HEAD许可及可复用既有阅读证据闭合，不代表运行或历史全审。

| 仓库 | 固定HEAD | 新release | 覆盖 | 许可全文hash |
|---|---|---|---|---|
| tddworks/baguette | [458044cceadd](https://github.com/tddworks/baguette/tree/458044cceadd25a1366619b3747311ad7d959f94) | v0.2.10 | partial，有变化 | `0509ebb2d8d399fb183d1973d3f6ad585e209ca4c2c42a90f3c22c0f32c1ab3e` |
| EvanBacon/serve-sim | [a30d70a55e05](https://github.com/EvanBacon/serve-sim/tree/a30d70a55e05654d974c86803b68d4f675be77e3) | 无 | 完整，无变化 | `9024cdf56dfe7e66523698a9f63d3a0061eb15f43bd5ea8e3833a56017ae37fd` |
| lycorp-jp/sim-use | [c02295edfd2f](https://github.com/lycorp-jp/sim-use/tree/c02295edfd2f442249b869096dda3dc7bfcd308d) | v0.16.0 | partial，有变化 | `8c0fe2892344358b49aa07d9a184bd8d0891832baf642f19161f271acc075d32` |
| MobAI-App/simslim | [6518ba7eab11](https://github.com/MobAI-App/simslim/tree/6518ba7eab1123d7e1d7797b0e05f51043b42a5b) | v0.12.2 | 完整，无变化 | `8b65667572b02a584c03c2977372eeb5fe8de0e228211b6f83033c458cc10b4e` |
| Mastersam07/OpenDeviceHub | [e50f07f1f448](https://github.com/Mastersam07/OpenDeviceHub/tree/e50f07f1f4480cb14d57f192df7bf598ca26e708) | v0.2.0 | 完整，无变化 | `327d9a7d16c78d62abbdbbcd9a48c3334b6d8a0e3e4da11ac5be3a40645a7584` |
| JaviSoto/device-hub-ios | [3779e12aa00c](https://github.com/JaviSoto/device-hub-ios/tree/3779e12aa00c08bb34805fef8ffe375838cbe815) | 无 | partial，有变化 | `4410cda18cd6959d53106c0ed799b3bc483993f5e44f4457a6d9baa1b1f43dfe` |
| heoblitz/Loupe | [ff1351242e6d](https://github.com/heoblitz/Loupe/tree/ff1351242e6dbaba4a0b4de40d10350a668f03b8) | v0.5.1 | 完整，无变化 | `0d7ebd755456885dba28523a5c468e59d06a26c8df2b896938632c9322c9e7e3` |
| jfarcand/mirroir-mcp | [845a981163aa](https://github.com/jfarcand/mirroir-mcp/tree/845a981163aa6d40999d343fee26778df8627843) | v0.40.1 | 完整，无变化 | `52327c57e955a3e63f872960938e814acc19eb1b77c501999f5fd1e543b21346` |
| RockxyApp/Rockxy | [de791b63e7f9](https://github.com/RockxyApp/Rockxy/tree/de791b63e7f9b5df49f127524a5c9320e675eb23) | v0.41.0 | 完整，无变化 | `73312c21c21d7ab7fa66c300993f3dd0dcbd53cfa62dded2fa7e6d4adf69c552` |
| ProxymanApp/atlantis | [cc059013de87](https://github.com/ProxymanApp/atlantis/tree/cc059013de8778072b4fea6453b45e964e4202fe) | 2.0.0 | 完整，无变化 | `c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4` |

## 采用判断及本地边界

- Baguette `458044cceadd25a1366619b3747311ad7d959f94` / v0.2.10：Duo fold/input/panel gesture、3D stage焦点、canonical domain文档变更。当前Triton不维护该3D Web stage或Device Hub私有HingeControl实现；SP192/196/200已交付的agent入口、原生动作与跨设备契约不因上游领域命名重复排期。二进制来源仍未闭合，不采用该实现。
- sim-use `c02295edfd2f442249b869096dda3dc7bfcd308d` 新发v0.16.0；前一观察已覆盖其大部分Duo/Resize/Unicode paste机制。SP214 fresh topology与SP219 `recordVideo --display` 已随v0.2.32发布，不重复排期。AX/HID真实路由仍无本地运行证明，维持fail-closed，不能把上游发行宣传当成本地验收。
- sim-use 新增签名修复的固定来源为 `scripts/generate-homebrew-formula.sh`、`scripts/local-release.sh`、`scripts/verify-brew-install.sh`、`Tests/ReleaseScriptTests.swift`，全部见本目录对应source JSON及commit-c022… JSON。机制是notarized模式不生成post_install ad-hoc codesign，安装验证复用正式formula generator并校验安装前后binary bytes、Developer ID与notarization。当前Triton `.github/homebrew/triton.rb.template` 无post_install/codesign，`.github/workflows/release.yml` 仅build/cp/tar，未配置Developer ID/notary阶段；因此无同类签名覆盖缺陷，不建立采用切片。
- 本地 `render-homebrew-formula.sh` 将tar SHA256写入formula；release.yml核验tar条目和README并产checksum，formula test覆盖版本、Web、Runner manifest逐文件hash。它们不等价于Homebrew安装后CLI字节相同，但目前没有已证明的行为缺陷或验收要求；仅观察通用增强，不强行立项。未来若明确引入Developer ID/notary，则BDD应为：Given已签名归档，When经同一正式formula安装到隔离且不链接PATH的keg，Then字节、签名身份和notary均保持且验证失败不得ad-hoc回退。该场景尚非当前待开发项。
- device-hub-ios `3779e12aa00c08bb34805fef8ffe375838cbe815`：`c76fa335` source module重构、`3779e12a` CI prerequisites fail-fast；Triton没有该Rust DeviceHubFFI模块/CI入口，不移植。`Rust/DeviceHubFFI/src/protocol.rs` patch被API省略；固定HEAD源码已取但历史重构未完整审阅，保持partial。

## 许可与取证限制

固定HEAD许可证全文保存在各仓 LICENSE.txt，SHA256见表及results.json。sim-use全文为Apache-2.0，GitHub返回NOASSERTION；昨日SP219写MIT与当前全文不符，提交主控更正权威资料，本agent不写共享docs。Loupe全文MIT、Rockxy全文AGPL-3.0，均保留GitHub NOASSERTION原值并注明人工识别；AGPL不自动复制。其他仓按results SPDX保留Apache-2.0/MIT约束；许可证不外推到第三方分发依赖。

compare和每commit文件列表使用per_page=100显式分页。相关固定HEAD contents保存为source JSON；省略patch/二进制/未完成人工语义审阅均在errors，不宣称覆盖恢复。sim-use旧`42aa9a2` CHANGELOG patch省略仍保留partial，未把抓到HEAD全文等同于恢复历史diff。未变化仓复用20261021已审证据。

取证过滤发生一次失误：自动读取Baguette contents时误取HingeControl二进制及offline-mfi key/certificate内容，立即终止取证并移除对应JSON的content，仅保留redacted元数据；未打印内容、未执行。后续取证必须先按路径用途与文件类型白名单检查，再请求contents，不能只按扩展名黑名单。当前脚本不应重新运行。该问题已告知主控；错误与剩余binary provenance均阻止成功点推进。

Remaining risk：API固定源码是阅读证据；未做编译/真实性能/真实Simulator/Xcode/签名安装验收。无新增可采用BDD。自动经验检查完成；过滤规则纠正及SP219许可事实交主控处理原权威文档。
